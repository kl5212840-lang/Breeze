import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PluginDataScope { records, accountSettings }

class PluginLifecycleChanged implements Exception {
  const PluginLifecycleChanged();
  @override
  String toString() => 'plugin_lifecycle_changed';
}

typedef _InstallationDocument = ({
  Map<String, int> removed,
  Map<String, int> epochs,
  Map<String, Set<PluginDataScope>> masks,
});

class LocalPluginInstallationLease {
  LocalPluginInstallationLease._(this._owner, this.source);
  final LocalPluginInstallationState _owner;
  final String source;
  bool _released = false;
  void release() {
    if (_released) return;
    _released = true;
    final count = _owner._installing[source] ?? 0;
    if (count <= 1) {
      _owner._installing.remove(source);
    } else {
      _owner._installing[source] = count - 1;
    }
  }
}

/// Device-only installation and data-retention choices. Never Portable or cloud.
/// A recovery journal may snapshot this raw key only on the same device.
class LocalPluginInstallationState {
  LocalPluginInstallationState({
    Future<SharedPreferences> Function()? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance;
  static final instance = LocalPluginInstallationState();
  static const storageKey = 'breeze.local.plugin-removals.v1';
  final Future<SharedPreferences> Function() _preferences;
  final changes = ValueNotifier<int>(0);
  Map<String, int> _removed = {}, _epochs = {};
  Map<String, Set<PluginDataScope>> _masks = {};
  final Set<String> _pendingRemoval = {};
  final Map<String, int> _installing = {};
  Future<void> _tail = Future.value();
  bool _loaded = false;

  bool isRemoved(String uuid) =>
      _removed.containsKey(uuid.trim()) ||
      _pendingRemoval.contains(uuid.trim());
  int? removedAt(String uuid) => _removed[uuid.trim()];
  int installationEpoch(String uuid) => _epochs[uuid.trim()] ?? 0;
  bool isInstalling(String uuid) => (_installing[uuid.trim()] ?? 0) > 0;
  bool isDataExcluded(String uuid, PluginDataScope scope) =>
      _masks[uuid.trim()]?.contains(scope) == true;
  Set<String> excludedSources(PluginDataScope scope) => Set.unmodifiable(
    _masks.entries
        .where((entry) => entry.value.contains(scope))
        .map((entry) => entry.key),
  );
  Set<String> get removedUuids => Set.unmodifiable(_removed.keys);
  void beginRemoval(String uuid) {
    _check(uuid);
    _pendingRemoval.add(uuid.trim());
  }

  void endRemoval(String uuid) => _pendingRemoval.remove(uuid.trim());
  LocalPluginInstallationLease beginExplicitInstallation(String source) {
    _check(source);
    final key = source.trim();
    _installing[key] = (_installing[key] ?? 0) + 1;
    return LocalPluginInstallationLease._(this, key);
  }

  static void _check(String uuid) {
    final value = uuid.trim();
    if (value.isEmpty ||
        value.length > 200 ||
        value == '.' ||
        value == '..' ||
        RegExp(r'[/\\\x00-\x1f]').hasMatch(value)) {
      throw const FormatException('Invalid plugin identity');
    }
  }

  _InstallationDocument _decode(String? raw) {
    if (raw == null) return (removed: {}, epochs: {}, masks: {});
    if (raw.length > 262144) {
      throw const FormatException('Invalid local installation state');
    }
    final data = jsonDecode(raw);
    if (data is! Map ||
        data['version'] != 1 ||
        data['removed'] is! Map ||
        data.keys.any(
          (key) => !{'version', 'removed', 'epochs', 'dataMasks'}.contains(key),
        )) {
      throw const FormatException('Invalid local installation state');
    }
    Map<String, int> integers(dynamic value) {
      if (value == null) return {};
      if (value is! Map || value.length > 2000) {
        throw const FormatException('Invalid local installation state');
      }
      final result = <String, int>{};
      for (final entry in value.entries) {
        if (entry.key is! String ||
            entry.value is! int ||
            entry.value < 0 ||
            entry.value > 8640000000000000) {
          throw const FormatException('Invalid local installation state');
        }
        _check(entry.key as String);
        if (entry.key != (entry.key as String).trim()) {
          throw const FormatException('Invalid local plugin identity');
        }
        result[entry.key as String] = entry.value as int;
      }
      return result;
    }

    final removed = integers(data['removed']),
        epochs = integers(data['epochs']);
    for (final key in removed.keys) {
      epochs.putIfAbsent(key, () => 1);
    }
    final rawMasks = data['dataMasks'] ?? {};
    if (rawMasks is! Map || rawMasks.length > 2000) {
      throw const FormatException('Invalid data retention state');
    }
    final masks = <String, Set<PluginDataScope>>{};
    for (final entry in rawMasks.entries) {
      if (entry.key is! String ||
          entry.value is! List ||
          (entry.value as List).any(
            (value) =>
                !PluginDataScope.values.any((scope) => scope.name == value),
          )) {
        throw const FormatException('Invalid data retention scope');
      }
      _check(entry.key as String);
      masks[entry.key as String] = {
        for (final value in entry.value as List)
          PluginDataScope.values.firstWhere((scope) => scope.name == value),
      };
    }
    return (removed: removed, epochs: epochs, masks: masks);
  }

  Map<String, dynamic> _encode(_InstallationDocument value) => {
    'version': 1,
    'removed': value.removed,
    'epochs': value.epochs,
    'dataMasks': {
      for (final entry in value.masks.entries)
        entry.key: entry.value.map((scope) => scope.name).toList(),
    },
  };
  void _publish(_InstallationDocument value) {
    final changed =
        jsonEncode(
          _encode((removed: _removed, epochs: _epochs, masks: _masks)),
        ) !=
        jsonEncode(_encode(value));
    _removed = value.removed;
    _epochs = value.epochs;
    _masks = value.masks;
    _loaded = true;
    if (changed) changes.value++;
  }

  Future<void> load() async {
    if (!_loaded) await reload();
  }

  Future<void> reload() async =>
      _publish(_decode((await _preferences()).getString(storageKey)));
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _write(
    SharedPreferences prefs,
    _InstallationDocument value,
    Future<void> Function(Map<String, dynamic>)? beforeWrite, {
    bool Function()? isCurrent,
  }) async {
    final encoded = jsonEncode(_encode(value));
    _decode(encoded);
    final previous = prefs.getString(storageKey);
    await beforeWrite?.call({storageKey: encoded});
    if (isCurrent != null && !isCurrent()) throw const PluginLifecycleChanged();
    try {
      if (!await prefs.setString(storageKey, encoded)) {
        throw StateError('Local installation state was not saved');
      }
      if (isCurrent != null && !isCurrent()) {
        // An explicit install can begin while the platform preference write is
        // awaiting its reply. Keep the old removal unpublished and withdraw
        // only this serialized write before the install enters storage queue.
        final saved = previous == null
            ? await prefs.remove(storageKey)
            : await prefs.setString(storageKey, previous);
        if (!saved) {
          throw StateError('Local installation rollback was not saved');
        }
        throw const PluginLifecycleChanged();
      }
    } catch (_) {
      try {
        await prefs.reload();
      } catch (_) {}
      rethrow;
    }
    _publish(value);
  }

  Future<void> markRemoved(
    String uuid, {
    int revision = 0,
    int? expectedEpoch,
    Future<void> Function(Map<String, dynamic>)? beforeWrite,
  }) => _serial(() async {
    _check(uuid);
    await load();
    final epoch = installationEpoch(uuid);
    if ((expectedEpoch != null && epoch != expectedEpoch) ||
        isInstalling(uuid)) {
      throw const PluginLifecycleChanged();
    }
    final prefs = await _preferences(), key = uuid.trim();
    final next = _decode(prefs.getString(storageKey));
    next.removed[key] = [
      DateTime.now().millisecondsSinceEpoch,
      revision + 1,
      (next.removed[key] ?? 0) + 1,
    ].reduce((a, b) => a > b ? a : b);
    next.epochs[key] = (next.epochs[key] ?? 0) + 1;
    await _write(
      prefs,
      next,
      beforeWrite,
      isCurrent: () => installationEpoch(key) == epoch && !isInstalling(key),
    );
  });
  Future<int> setDataExclusions(
    String source,
    Set<PluginDataScope> scopes, {
    required Future<void> Function(Map<String, dynamic>) beforeWrite,
  }) => _serial(() async {
    _check(source);
    final prefs = await _preferences(), key = source.trim();
    final next = _decode(prefs.getString(storageKey));
    next.masks[key] = {...?next.masks[key], ...scopes};
    next.epochs[key] = (next.epochs[key] ?? 0) + 1;
    await _write(prefs, next, beforeWrite);
    return next.epochs[key]!;
  });
  Future<void> clearForExplicitRestore(
    Iterable<String> uuids, {
    required Future<void> Function(Map<String, dynamic>) beforeWrite,
  }) => _clear(
    uuids,
    clearInstallation: true,
    clearData: true,
    beforeWrite: beforeWrite,
  );
  Future<void> clearDataExclusionsForExplicitRestore(
    Iterable<String> uuids, {
    required Future<void> Function(Map<String, dynamic>) beforeWrite,
  }) => _clear(
    uuids,
    clearInstallation: false,
    clearData: true,
    beforeWrite: beforeWrite,
  );
  Future<void> completeExplicitInstallation(
    String uuid, {
    Future<void> Function(Map<String, dynamic>)? beforeWrite,
  }) => _clear(
    [uuid],
    clearInstallation: true,
    clearData: false,
    beforeWrite: beforeWrite ?? (_) async {},
  );
  Future<void> _clear(
    Iterable<String> uuids, {
    required bool clearInstallation,
    required bool clearData,
    required Future<void> Function(Map<String, dynamic>) beforeWrite,
  }) => _serial(() async {
    final prefs = await _preferences();
    final next = _decode(prefs.getString(storageKey));
    for (final uuid in uuids) {
      _check(uuid);
      final key = uuid.trim();
      if (clearInstallation) next.removed.remove(key);
      if (clearData) next.masks.remove(key);
      next.epochs[key] = (next.epochs[key] ?? 0) + 1;
    }
    await _write(prefs, next, beforeWrite);
  });
}
