import 'package:zephyr/network/sync/portable_preferences.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef DiscoverVisibilityRead = Future<List<String>> Function();
typedef DiscoverVisibilityWrite = Future<bool> Function(List<String> ids);

/// Local presentation preferences only. This never edits a plugin's runtime,
/// installation, account or searchable sources. Unknown IDs are retained so
/// updating or reinstalling the same plugin does not reset its visibility.
class DiscoverPluginVisibility extends ChangeNotifier {
  DiscoverPluginVisibility({
    DiscoverVisibilityRead? read,
    DiscoverVisibilityWrite? write,
  }) : _read = read ?? _readPreferences,
       _write = write ?? _writePreferences {
    PortablePreferences.changes.addListener(_portableRestored);
  }

  void _portableRestored() => unawaited(_reloadPortable());
  Future<void> _reloadPortable() async {
    await _loading?.catchError((Object _) {});
    if (_disposed) return;
    loaded = false;
    await load();
  }

  static const preferenceKey = 'discover_hidden_plugin_ids_v1';
  final DiscoverVisibilityRead _read;
  final DiscoverVisibilityWrite _write;
  Set<String> _hiddenIds = const {};
  Future<void>? _loading;
  Future<void>? _writes;
  bool _disposed = false;
  bool loaded = false;
  Object? loadError;

  Set<String> get hiddenIds => Set.unmodifiable(_hiddenIds);
  bool isVisible(String id) => !_hiddenIds.contains(id);

  static Future<List<String>> _readPreferences() async =>
      (await SharedPreferences.getInstance()).getStringList(preferenceKey) ??
      const [];

  static Future<bool> _writePreferences(List<String> ids) async =>
      (await SharedPreferences.getInstance()).setStringList(preferenceKey, ids);

  static Set<String> _validIds(Iterable<String> ids) => {
    for (final id in ids)
      if (id.isNotEmpty && id.length <= 200 && id.trim() == id) id,
  };

  Future<void> load() {
    if (loaded) return Future.value();
    final pending = _loading;
    if (pending != null) return pending;
    loadError = null;
    final job = _load();
    _loading = job;
    if (!_disposed) notifyListeners();
    return job;
  }

  Future<void> _load() async {
    try {
      final ids = await Future<List<String>>.sync(_read);
      if (_disposed) return;
      _hiddenIds = _validIds(ids);
      loaded = true;
      loadError = null;
    } catch (error) {
      if (!_disposed) loadError = error;
      rethrow;
    } finally {
      _loading = null;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> saveHiddenIds(Set<String> ids) {
    final next = _validIds(ids);
    final job = (_writes ?? Future<void>.value())
        .catchError((Object _) {})
        .then((_) async {
          if (!loaded) await load();
          final persisted = next.toList()..sort();
          if (!await _write(persisted)) {
            throw StateError('Could not save Discover visibility');
          }
          if (!_disposed) {
            _hiddenIds = next;
            notifyListeners();
          }
        });
    _writes = job;
    unawaited(
      job.then<void>(
        (_) {
          if (identical(_writes, job)) _writes = null;
        },
        onError: (Object _, StackTrace _) {
          if (identical(_writes, job)) _writes = null;
        },
      ),
    );
    return job;
  }

  @override
  void dispose() {
    PortablePreferences.changes.removeListener(_portableRestored);
    _disposed = true;
    super.dispose();
  }
}
