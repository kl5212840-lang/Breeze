import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Host diagnostic visibility is independent of plugin runtime development.
/// It is opt-in for each source and does not enable WebKit inspection itself.
abstract final class SourceDiagnosticPreferences {
  static const prefix = 'breeze.source.diagnostics.v1.';
  static final changes = ValueNotifier<int>(0);
  static final _revisions = <String, int>{};
  static final _writes = <String, Future<void>>{};

  static String storageKey(String source) => '$prefix$source';

  static Future<bool> enabled(String source) async {
    if (source.isEmpty) return false;
    try {
      await _writes[source]?.catchError((Object _) {});
      final store = await SharedPreferences.getInstance();
      return store.getBool(storageKey(source)) ?? false;
    } catch (_) {
      // A read failure must not unexpectedly expose diagnostic controls.
      return false;
    }
  }

  static Future<void> setEnabled(String source, bool enabled) async {
    if (source.isEmpty) throw ArgumentError.value(source, 'source');
    final revision = (_revisions[source] ?? 0) + 1;
    _revisions[source] = revision;
    final previous = _writes[source] ?? Future<void>.value();
    final write = previous.catchError((Object _) {}).then((_) async {
      if (_revisions[source] != revision) return;
      final store = await SharedPreferences.getInstance();
      if (_revisions[source] != revision) return;
      try {
        if (!await store.setBool(storageKey(source), enabled)) {
          throw StateError('Could not save diagnostic preference');
        }
      } catch (_) {
        // Legacy SharedPreferences updates its cache before persistence returns.
        // Restore the persisted value so a failed write cannot expose tools.
        try {
          await store.reload();
        } catch (_) {}
        rethrow;
      }
      changes.value++;
    });
    _writes[source] = write;
    try {
      await write;
    } finally {
      if (identical(_writes[source], write)) _writes.remove(source);
    }
  }
}
