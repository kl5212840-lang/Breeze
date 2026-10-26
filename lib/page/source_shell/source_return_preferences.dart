import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SourceReturnMode { byFunction, stepByStep }

/// App-wide source navigation preference. Site and player settings are separate.
abstract final class SourceReturnPreferences {
  static const storageKey = 'breeze.source.returnMode.v1';
  static final changes = ValueNotifier(SourceReturnMode.byFunction);
  static int _revision = 0;
  static Future<void> _writes = Future<void>.value();

  static bool get includesTabHistory =>
      changes.value == SourceReturnMode.stepByStep;

  static Future<void> load() async {
    final revision = _revision;
    try {
      final store = await SharedPreferences.getInstance();
      if (revision != _revision) return;
      changes.value = store.getString(storageKey) == 'stepByStep'
          ? SourceReturnMode.stepByStep
          : SourceReturnMode.byFunction;
    } catch (_) {
      // Navigation remains usable when preferences are temporarily unavailable.
    }
  }

  static Future<void> setMode(SourceReturnMode mode) async {
    final revision = ++_revision;
    final previous = changes.value;
    changes.value = mode;
    final write = _writes.catchError((Object _) {}).then((_) async {
      if (revision != _revision) return;
      final store = await SharedPreferences.getInstance();
      if (revision != _revision) return;
      if (!await store.setString(storageKey, mode.name)) {
        throw StateError('Could not save return mode');
      }
    });
    _writes = write;
    try {
      await write;
    } catch (_) {
      if (_revision == revision) changes.value = previous;
      rethrow;
    }
  }
}
