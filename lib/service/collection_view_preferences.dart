import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local presentation preferences. Callers supply a complete collection scope;
/// media, section and plugin modules must not share a key accidentally.
abstract final class CollectionViewPreferences {
  static const prefix = 'breeze.collection.view.v1.';
  static final changes = ValueNotifier<int>(0);
  static final _writes = <String, Future<void>>{};
  static final _epochs = <String, int>{};

  static String keyFor(String scope) => '$prefix${Uri.encodeComponent(scope)}';

  static bool _valid(Object? value) => value == 'grid' || value == 'list';

  /// Legacy values are read-only defaults, so the first new choice remains
  /// independent of other hosts that used the older, broader scope.
  static Future<String?> read(
    String scope, {
    String? legacyKey,
    String? legacyDetailedKey,
  }) async {
    if (scope.isEmpty) return null;
    while (true) {
      final epoch = _epochs[scope] ?? 0;
      await _writes[scope];
      final store = await SharedPreferences.getInstance();
      if (epoch != (_epochs[scope] ?? 0)) continue;
      final value = store.get(keyFor(scope));
      if (_valid(value)) return value as String;
      final legacy = legacyKey == null ? null : store.get(legacyKey);
      if (_valid(legacy)) return legacy as String;
      final detailed = legacyDetailedKey == null
          ? null
          : store.get(legacyDetailedKey);
      return detailed is bool ? (detailed ? 'list' : 'grid') : null;
    }
  }

  static Future<void> write(String scope, String view) {
    if (scope.isEmpty || !_valid(view)) {
      throw ArgumentError('A collection scope and grid/list view are required');
    }
    _epochs[scope] = (_epochs[scope] ?? 0) + 1;
    final operation = (_writes[scope] ?? Future<void>.value()).then((_) async {
      final store = await SharedPreferences.getInstance();
      final key = keyFor(scope), previous = store.get(key);
      try {
        if (!await store.setString(key, view)) {
          throw StateError('Collection view was not saved');
        }
      } catch (_) {
        // Legacy preferences change their cache before the backing write. Undo
        // only our value, preserving a newer restore or another scope's data.
        if (store.get(key) == view) {
          try {
            await switch (previous) {
              String value => store.setString(key, value),
              bool value => store.setBool(key, value),
              int value => store.setInt(key, value),
              double value => store.setDouble(key, value),
              List<String> value => store.setStringList(key, value),
              _ => store.remove(key),
            };
          } catch (_) {
            // The cache is restored synchronously even if storage is down.
          }
        }
        rethrow;
      }
      changes.value++;
    });
    final tail = operation.then<void>((_) {}, onError: (Object _) {});
    _writes[scope] = tail;
    unawaited(
      tail.then((_) {
        if (identical(_writes[scope], tail)) _writes.remove(scope);
      }),
    );
    return operation;
  }

  static Future<void> flush() async {
    await Future.wait(_writes.values.toList());
  }
}
