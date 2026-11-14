import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';

/// Applied user choices only. Public list/index caches have a separate local
/// prefix and are never included in portable preferences.
abstract final class SourceResultFilterPreferences {
  static const prefix = 'breeze.source.results-filters.v1.';
  static Future<void>? _tail;
  static String key(String scope) => '$prefix${Uri.encodeComponent(scope)}';
  static Future<void> flush() async {
    await _tail;
  }

  static bool validValue(Object? value) {
    if (value is! String || value.length > 64000) return false;
    try {
      final data = jsonDecode(value);
      return data is Map &&
          data.length == 2 &&
          data['version'] == 1 &&
          data['values'] is Map &&
          (data['values'] as Map).length <= 7 &&
          (data['values'] as Map).entries.every(
            (e) =>
                shelfFacetDimensions.contains(e.key) &&
                e.value is List &&
                (e.value as List).length <= 500 &&
                (e.value as List).every(
                  (v) => v is String && v.isNotEmpty && v.length <= 500,
                ),
          );
    } catch (_) {
      return false;
    }
  }

  static Future<ShelfFacetSelection> read(String scope) async {
    await _tail;
    final text = (await SharedPreferences.getInstance()).getString(key(scope));
    if (!validValue(text)) return const ShelfFacetSelection();
    final values = (jsonDecode(text!) as Map)['values'] as Map;
    return ShelfFacetSelection(
      values: {
        for (final e in values.entries)
          e.key as String: (e.value as List).cast<String>().toSet(),
      },
    );
  }

  static Future<void> write(String scope, ShelfFacetSelection value) {
    final encoded = jsonEncode({
      'version': 1,
      'values': {
        for (final e in value.values.entries)
          if (e.value.isNotEmpty) e.key: (e.value.toList()..sort()),
      },
    });
    if (!validValue(encoded))
      return Future.error(const FormatException('Invalid filters'));
    final task = (_tail ?? Future<void>.value()).then((_) async {
      final store = await SharedPreferences.getInstance();
      final storageKey = key(scope);
      final previous = store.getString(storageKey);
      try {
        if (!await store.setString(storageKey, encoded)) {
          throw StateError('Filter preferences were not saved');
        }
      } catch (_) {
        // SharedPreferences updates its process cache before disk reports
        // success. Restore only if this failed write still owns the value.
        if (store.getString(storageKey) == encoded) {
          try {
            if (previous == null) {
              await store.remove(storageKey);
            } else {
              await store.setString(storageKey, previous);
            }
          } catch (_) {
            // Report the original save failure.
          }
        }
        rethrow;
      }
    });
    final tail = task.then<void>((_) {}, onError: (Object _) {});
    _tail = tail;
    unawaited(
      tail.then((_) {
        if (identical(_tail, tail)) _tail = null;
      }),
    );
    return task;
  }
}
