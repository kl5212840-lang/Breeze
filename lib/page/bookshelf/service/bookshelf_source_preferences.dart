import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

enum BookshelfSourceMedium { comic, video, download }

/// Source tabs are presentation preferences, never a filter on All's data.
class BookshelfSourcePreferences {
  BookshelfSourcePreferences({
    Iterable<String> order = const [],
    Iterable<String> hidden = const [],
  }) : order = List.unmodifiable(_ids(order)),
       hidden = Set.unmodifiable(_ids(hidden));
  final List<String> order;
  final Set<String> hidden;

  static List<String> _ids(Iterable<String> values) => values
      .map((v) => v.trim())
      .where(
        (v) =>
            v.isNotEmpty &&
            v.length <= 200 &&
            !RegExp(r'[\x00-\x1f\x7f]').hasMatch(v),
      )
      .toSet()
      .take(2000)
      .toList();

  factory BookshelfSourcePreferences.decode(String? raw) {
    try {
      if (raw == null || raw.length > 256000) {
        return BookshelfSourcePreferences();
      }
      final value = jsonDecode(raw);
      if (value is! Map ||
          value['version'] != 1 ||
          value['order'] is! List ||
          value['hidden'] is! List) {
        return BookshelfSourcePreferences();
      }
      return BookshelfSourcePreferences(
        order: (value['order'] as List).whereType<String>(),
        hidden: (value['hidden'] as List).whereType<String>(),
      );
    } catch (_) {
      return BookshelfSourcePreferences();
    }
  }

  String encode() => jsonEncode({
    'version': 1,
    'order': order,
    'hidden': hidden.toList()..sort(),
  });

  Map<String, String> arrange(
    Map<String, String> sources, {
    bool includeHidden = false,
  }) {
    final ids = {...order.where(sources.containsKey), ...sources.keys};
    return {
      for (final id in ids)
        if (includeHidden || !hidden.contains(id)) id: sources[id]!,
    };
  }

  BookshelfSourcePreferences withVisibility(String id, bool visible) =>
      BookshelfSourcePreferences(
        order: order,
        hidden: {...hidden}
          ..removeWhere((v) => v == id && visible)
          ..addAll(visible ? const [] : [id]),
      );

  /// Reorder the sources currently shown by the editor, retaining unavailable
  /// IDs in their original slots so uninstall/reinstall never loses preferences.
  BookshelfSourcePreferences withKnownOrder(Iterable<String> visibleIds) {
    final known = _ids(visibleIds);
    final knownSet = known.toSet();
    final slots = {...order, ...known};
    var index = 0;
    return BookshelfSourcePreferences(
      order: [
        for (final id in slots)
          if (knownSet.contains(id)) known[index++] else id,
      ],
      hidden: hidden,
    );
  }
}

class BookshelfSourcePreferenceStore {
  static final changes = ValueNotifier<int>(0);
  static final _pending = <BookshelfSourceMedium, Future<void>>{};
  static String key(BookshelfSourceMedium medium) =>
      'breeze.bookshelf.source-tabs.${medium.name}.v1';

  static Future<void> flush() async {
    await Future.wait(_pending.values.toList());
  }

  Future<BookshelfSourcePreferences> read(BookshelfSourceMedium medium) async {
    await _pending[medium]?.catchError((Object _) {});
    final prefs = await SharedPreferences.getInstance();
    return BookshelfSourcePreferences.decode(prefs.getString(key(medium)));
  }

  Future<void> save(
    BookshelfSourceMedium medium,
    BookshelfSourcePreferences value,
  ) {
    final operation = (_pending[medium] ?? Future<void>.value())
        .catchError((Object _) {})
        .then((_) async {
          final prefs = await SharedPreferences.getInstance(),
              data = value.encode();
          if (prefs.getString(key(medium)) == data) return;
          final storageKey = key(medium), previous = prefs.get(key(medium));
          try {
            if (!await prefs.setString(storageKey, data))
              throw StateError('source_tabs_save_failed');
          } catch (_) {
            if (prefs.get(storageKey) == data) {
              try {
                await switch (previous) {
                  String value => prefs.setString(storageKey, value),
                  bool value => prefs.setBool(storageKey, value),
                  int value => prefs.setInt(storageKey, value),
                  double value => prefs.setDouble(storageKey, value),
                  List<String> value => prefs.setStringList(storageKey, value),
                  _ => prefs.remove(storageKey),
                };
              } catch (_) {}
            }
            rethrow;
          }
          changes.value++;
        });
    _pending[medium] = operation;
    void release() {
      if (identical(_pending[medium], operation)) _pending.remove(medium);
    }

    unawaited(
      operation.then(
        (_) => release(),
        onError: (Object _, StackTrace _) => release(),
      ),
    );
    return operation;
  }
}
