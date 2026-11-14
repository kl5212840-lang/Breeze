import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Per-source search words, included in portable application data.
/// They are never sent to a site except by an explicit search.
abstract final class VideoSearchHistory {
  static const limit = 12;
  static Future<void>? _pending;

  static Future<void> flush() async {
    await _pending?.catchError((Object _) {});
  }

  static String _key(String source) {
    if (source.isEmpty || source.length > 200) throw ArgumentError('source');
    return 'breeze.video.recentSearches.v1.$source';
  }

  static String clean(String value) {
    final text = value.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '').trim();
    return text.substring(0, text.length.clamp(0, 300));
  }

  static List<String> _words(SharedPreferences prefs, String key) =>
      (prefs.getStringList(key) ?? const [])
          .map(clean)
          .where((word) => word.isNotEmpty)
          .toSet()
          .take(limit)
          .toList();

  static Future<List<String>> read(String source) async {
    final pending = _pending;
    if (pending != null) await pending.catchError((Object _) {});
    return _words(await SharedPreferences.getInstance(), _key(source));
  }

  static Future<void> _change(
    String source,
    List<String> Function(List<String>) change,
  ) {
    final key = _key(source);
    final job = (_pending ?? Future<void>.value())
        .catchError((Object _) {})
        .then((_) async {
          final prefs = await SharedPreferences.getInstance();
          if (!await prefs.setStringList(key, change(_words(prefs, key)))) {
            throw StateError('Local search history not saved');
          }
        });
    _pending = job;
    void release() {
      if (identical(_pending, job)) _pending = null;
    }

    unawaited(
      job.then<void>(
        (_) => release(),
        onError: (Object _, StackTrace _) => release(),
      ),
    );
    return job;
  }

  static Future<void> add(String source, String query) =>
      _change(source, (words) {
        final word = clean(query);
        return [
          if (word.isNotEmpty) word,
          ...words.where((old) => old != word),
        ].take(limit).toList();
      });

  static Future<void> remove(String source, String word) =>
      _change(source, (words) => words.where((old) => old != word).toList());
  static Future<void> removeMany(String source, Set<String> selected) =>
      _change(
        source,
        (words) => words.where((old) => !selected.contains(old)).toList(),
      );
  static Future<void> clear(String source) => _change(source, (_) => []);
}
