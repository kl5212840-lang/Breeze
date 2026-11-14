import 'dart:async';
import 'dart:convert';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Starred tags are immediate presentation preferences, independent of filter drafts.
class ShelfFacetPreferences {
  static final changes = ValueNotifier<int>(0);
  static final _writes = <String, Future<void>>{};
  static Future<void>? _portableWrite;
  static String _key(String medium) =>
      'breeze.bookshelf.facet-tags.v1.${Uri.encodeComponent(medium)}';

  static Future<Set<String>> _read(String preferenceKey) async {
    final preferences = await SharedPreferences.getInstance();
    try {
      final raw = jsonDecode(
        preferences.getString(_key(preferenceKey)) ?? '[]',
      );
      if (raw is! List || raw.any((value) => value is! String))
        throw const FormatException('Invalid pinned tags');
      return raw
          .cast<String>()
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty && v != shelfFacetUnknown)
          .toSet();
    } catch (_) {
      throw const FormatException('Invalid pinned tags');
    }
  }

  static Future<Set<String>> load(String preferenceKey) async {
    await _writes[preferenceKey];
    return _read(preferenceKey);
  }

  static Future<T> _serialize<T>(
    String preferenceKey,
    Future<T> Function() action,
  ) {
    final operation = Future.wait<void>([
      ?_portableWrite,
      ?_writes[preferenceKey],
    ]).then((_) => action());
    // Keep a successful tail so one failed save cannot block later actions.
    final tail = operation.then<void>((_) {}, onError: (Object _) {});
    _writes[preferenceKey] = tail;
    unawaited(
      tail.then((_) {
        if (identical(_writes[preferenceKey], tail)) {
          _writes.remove(preferenceKey);
        }
      }),
    );
    return operation;
  }

  /// A restore replaces whole sets. Let earlier edits finish before taking its
  /// snapshot, then let later toggles read the newly restored set.
  static Future<T> serializePortableWrite<T>(Future<T> Function() action) {
    final operation = Future.wait<void>([
      ?_portableWrite,
      ..._writes.values,
    ]).then((_) => action());
    final tail = operation.then<void>((_) {}, onError: (Object _) {});
    _portableWrite = tail;
    unawaited(
      tail.then((_) {
        if (identical(_portableWrite, tail)) _portableWrite = null;
      }),
    );
    return operation;
  }

  static Future<void> _write(String preferenceKey, Set<String> tags) async {
    final preferences = await SharedPreferences.getInstance();
    final values =
        tags
            .map((v) => v.trim())
            .where((v) => v.isNotEmpty && v != shelfFacetUnknown)
            .toSet()
            .toList()
          ..sort();
    final key = _key(preferenceKey), encoded = jsonEncode(values);
    final previous = preferences.get(key);
    try {
      if (!await preferences.setString(key, encoded)) {
        throw StateError('标签收藏保存失败');
      }
    } catch (_) {
      // Legacy preferences update their cache before persistence completes.
      // Only undo our own value; a concurrent restore owns any newer value.
      if (preferences.get(key) == encoded) {
        try {
          await switch (previous) {
            String value => preferences.setString(key, value),
            bool value => preferences.setBool(key, value),
            int value => preferences.setInt(key, value),
            double value => preferences.setDouble(key, value),
            List<String> value => preferences.setStringList(key, value),
            _ => preferences.remove(key),
          };
        } catch (_) {
          // The key's cache is restored synchronously even if storage is down.
          // Keep the original save failure visible to the caller.
        }
      }
      rethrow;
    }
    changes.value++;
  }

  static Future<void> save(String preferenceKey, Set<String> tags) {
    final snapshot = {...tags};
    return _serialize(preferenceKey, () => _write(preferenceKey, snapshot));
  }

  /// Mutate the current persisted set, never an open sheet's old snapshot.
  static Future<Set<String>> toggle(String preferenceKey, String tag) {
    final value = tag.trim();
    if (value.isEmpty || value == shelfFacetUnknown)
      return Future.error(ArgumentError.value(tag, 'tag'));
    return _serialize(preferenceKey, () async {
      final tags = await _read(preferenceKey);
      tags.contains(value) ? tags.remove(value) : tags.add(value);
      await _write(preferenceKey, tags);
      return Set.unmodifiable(tags);
    });
  }

  static Future<void> flush() async {
    await Future.wait(_writes.values.toList());
  }
}
