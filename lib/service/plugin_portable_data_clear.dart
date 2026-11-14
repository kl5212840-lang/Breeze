import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/sync/plugin_portable_scope.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';

bool _same(Object? a, Object? b) => jsonEncode(a) == jsonEncode(b);
Future<bool> _write(SharedPreferences prefs, String key, Object? value) =>
    switch (value) {
      null => prefs.remove(key),
      String value => prefs.setString(key, value),
      List<String> value => prefs.setStringList(key, value),
      bool value => prefs.setBool(key, value),
      int value => prefs.setInt(key, value),
      double value => prefs.setDouble(key, value),
      _ => throw const FormatException('Unsupported local preference'),
    };

class PluginPortableDataClearPlan {
  PluginPortableDataClearPlan._(
    this.source,
    this.epoch,
    this.entryCount,
    this.preferenceKeyCount,
    this.historyCount,
    this._before,
    this._updates,
  );
  final String source;
  final int epoch, entryCount, preferenceKeyCount, historyCount;
  final Map<String, Object?> _before, _updates;

  void _guard() {
    final state = LocalPluginInstallationState.instance;
    if (state.installationEpoch(source) != epoch ||
        state.isInstalling(source)) {
      throw const PluginLifecycleChanged();
    }
  }

  Future<void> applyPreferences({
    required Future<void> Function(Map<String, dynamic>) beforeWrite,
  }) async {
    _guard();
    final prefs = await SharedPreferences.getInstance();
    for (final entry in _before.entries) {
      if (!_same(prefs.get(entry.key), entry.value)) {
        throw const PluginLifecycleChanged();
      }
    }
    await beforeWrite(Map<String, dynamic>.from(_updates));
    _guard();
    for (final entry in _before.entries) {
      if (!_same(prefs.get(entry.key), entry.value)) {
        throw const PluginLifecycleChanged();
      }
    }
    final saved = await Future.wait([
      for (final entry in _updates.entries)
        _write(prefs, entry.key, entry.value),
    ]);
    if (saved.any((value) => !value)) {
      throw StateError('Plugin personal preferences were not saved');
    }
    await PortablePreferences.notifyRestored(keys: _updates.keys.toSet());
  }
}

Future<PluginPortableDataClearPlan> preparePluginPortableDataClear(
  String source, {
  required Set<PluginDataScope> scopes,
  required bool cloudDelete,
  int? expectedEpoch,
  int? nowMs,
  PortablePreferencesSnapshot? knownCloudPortable,
}) async {
  source = source.trim();
  final state = LocalPluginInstallationState.instance;
  await state.load();
  final epoch = state.installationEpoch(source);
  if ((expectedEpoch != null && expectedEpoch != epoch) ||
      state.isInstalling(source)) {
    throw const PluginLifecycleChanged();
  }
  var snapshot = await PortablePreferences.capture(persist: false);
  if (cloudDelete && knownCloudPortable != null) {
    PortablePreferencesSnapshot.fromJson(knownCloudPortable.toJson());
    final cloudOwnership = pluginPortableScopes(knownCloudPortable.entries);
    final selectedCloud = PortablePreferencesSnapshot({
      for (final entry in cloudOwnership.entries)
        if (entry.value.source == source && scopes.contains(entry.value.scope))
          entry.key: knownCloudPortable.entries[entry.key]!,
    });
    snapshot = snapshot.merged(selectedCloud, preferOtherOnTie: true);
  }
  final ownership = pluginPortableScopes(snapshot.entries);
  final selected = <String, PluginPortableScope>{
    for (final entry in ownership.entries)
      if (entry.value.source == source && scopes.contains(entry.value.scope))
        entry.key: entry.value,
  };
  final prefs = await SharedPreferences.getInstance();
  var historyCount = 0;
  for (final id in selected.keys) {
    final row = snapshot.entries[id]!;
    if (row['kind'] != 'history' || row['deleted'] == true) continue;
    if (cloudDelete) {
      historyCount++;
      continue;
    }
    final raw = prefs.getString(row['key'] as String);
    if (raw == null) continue;
    final actual = jsonDecode(raw);
    final value = row['value'];
    if (actual is List &&
        value is Map &&
        actual.whereType<Map>().any(
          (item) => item['watchUrl'] == value['watchUrl'],
        )) {
      historyCount++;
    }
  }
  final updates = <String, Object?>{};
  final affectedKeys = selected.keys
      .map((id) => snapshot.entries[id]!['key'] as String)
      .toSet();
  for (final key in affectedKeys) {
    if (key == VideoExportRecords.storageKey) {
      final raw = prefs.getString(key);
      final rows = raw == null ? const [] : jsonDecode(raw);
      if (rows is! List) {
        throw const FormatException('Invalid local export records');
      }
      final kept = rows
          .where((row) => row is! Map || row['source'] != source)
          .toList();
      updates[key] = jsonEncode(kept);
    } else {
      updates[key] = null;
    }
  }
  final journal = Map<String, Map<String, dynamic>>.from(snapshot.entries);
  if (cloudDelete) {
    final clock = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    for (final entry in selected.entries) {
      final row = journal[entry.key]!;
      if (row['deleted'] == true) {
        continue; // Preserve ordinary prior deletions.
      }
      journal[entry.key] = pluginPortablePurgeTombstone(
        row,
        entry.value,
        nowMs: clock,
      );
    }
  }
  // Local-only deletion deliberately preserves the complete cloud projection.
  // Data masks stop capture from turning absent local values into cloud deletes.
  final next = PortablePreferencesSnapshot(journal);
  PortablePreferencesSnapshot.fromJson(
    next.toJson(includeLocalMetadata: true),
    allowLocalMetadata: true,
  );
  updates[PortablePreferences.journalKey] = jsonEncode(
    next.toJson(includeLocalMetadata: true),
  );
  final before = {for (final key in updates.keys) key: prefs.get(key)};
  return PluginPortableDataClearPlan._(
    source,
    epoch,
    selected.length,
    affectedKeys.length,
    historyCount,
    before,
    updates,
  );
}

/// Only exact local purge tombstones are withdrawn after successful reinstall.
/// This has no network side effects and does not resurrect removed values.
Future<void> discardPluginPortableDeletionTombstones(
  String source, {
  required int expectedEpoch,
  required Future<void> Function(Map<String, dynamic>) beforeWrite,
}) async {
  final state = LocalPluginInstallationState.instance;
  if (state.installationEpoch(source) != expectedEpoch) {
    throw const PluginLifecycleChanged();
  }
  final prefs = await SharedPreferences.getInstance();
  final original = prefs.getString(PortablePreferences.journalKey);
  if (original == null) return;
  final snapshot = PortablePreferencesSnapshot.fromJson(
    jsonDecode(original),
    allowLocalMetadata: true,
  );
  final remaining = Map<String, Map<String, dynamic>>.from(snapshot.entries);
  remaining.removeWhere(
    (_, row) =>
        validPluginPortablePurgeMarker(row) &&
        (row['localPurge'] as Map)['source'] == source,
  );
  if (remaining.length == snapshot.entries.length) return;
  final value = jsonEncode(
    PortablePreferencesSnapshot(remaining).toJson(includeLocalMetadata: true),
  );
  await beforeWrite({PortablePreferences.journalKey: value});
  if (state.installationEpoch(source) != expectedEpoch ||
      prefs.getString(PortablePreferences.journalKey) != original) {
    throw const PluginLifecycleChanged();
  }
  if (!await prefs.setString(PortablePreferences.journalKey, value)) {
    throw StateError('Plugin personal preference revisions were not saved');
  }
}
