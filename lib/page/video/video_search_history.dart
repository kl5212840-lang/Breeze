import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/method/search_history_entries.dart';

typedef VideoSearchHistoryEntry = ({String query, KeywordSearchScope? scope});

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

  static VideoSearchHistoryEntry? decode(String raw) {
    final saved = SearchHistoryEntries.decode(raw);
    final isVideoEntry = saved?.scope == 'video';
    final query = clean(isVideoEntry ? saved!.query : raw);
    if (query.isEmpty) return null;
    return (
      query: query,
      scope: isVideoEntry
          ? parseKeywordSearchScope(saved!.keywordScope?.name)
          : null,
    );
  }

  static List<VideoSearchHistoryEntry> _entries(
    SharedPreferences prefs,
    String key,
  ) {
    final seen = <String>{};
    return (prefs.getStringList(key) ?? const [])
        .map(decode)
        .nonNulls
        .where((entry) => seen.add(entry.query))
        .take(limit)
        .toList();
  }

  static Future<List<VideoSearchHistoryEntry>> readEntries(
    String source,
  ) async {
    final pending = _pending;
    if (pending != null) await pending.catchError((Object _) {});
    return _entries(await SharedPreferences.getInstance(), _key(source));
  }

  static Future<List<String>> read(String source) async =>
      (await readEntries(source)).map((entry) => entry.query).toList();

  static Future<void> _change(
    String source,
    List<VideoSearchHistoryEntry> Function(List<VideoSearchHistoryEntry>)
    change,
  ) {
    final key = _key(source);
    final job = (_pending ?? Future<void>.value())
        .catchError((Object _) {})
        .then((_) async {
          final prefs = await SharedPreferences.getInstance();
          final entries = change(_entries(prefs, key));
          if (!await prefs.setStringList(key, [
            for (final entry in entries)
              entry.scope == null
                  ? entry.query
                  : SearchHistoryEntries.add(
                      const [],
                      entry.query,
                      scope: 'video',
                      keywordScope: entry.scope,
                    ).single,
          ])) {
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

  static Future<void> add(
    String source,
    String query, {
    KeywordSearchScope? scope,
  }) => _change(source, (entries) {
    final word = clean(query);
    if (word.isEmpty) return entries;
    final existing = entries.where((entry) => entry.query == word).firstOrNull;
    return [
      (
        query: word,
        scope: parseKeywordSearchScope(scope?.name) ?? existing?.scope,
      ),
      ...entries.where((entry) => entry.query != word),
    ].take(limit).toList();
  });

  static Future<void> remove(String source, String word) =>
      removeMany(source, {word});
  static Future<void> removeMany(String source, Set<String> selected) =>
      _change(
        source,
        (entries) =>
            entries.where((entry) => !selected.contains(entry.query)).toList(),
      );
  static Future<void> clear(String source) => _change(source, (_) => []);
}
