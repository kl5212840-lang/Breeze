import 'dart:convert';

import 'package:zephyr/page/search/method/keyword_search_scope.dart';

/// Keep the existing `List<String>` storage while giving new source searches an
/// explicit scope. Legacy plain words stay in combined search; their source is
/// unknown and must never be guessed or copied to an individual plugin.
abstract final class SearchHistoryEntries {
  static const _prefix = 'breeze.search.v2:';

  static ({String scope, String query, KeywordSearchScope? keywordScope})?
  decode(String raw) {
    if (!raw.startsWith(_prefix)) {
      final query = raw.trim();
      return query.isEmpty
          ? null
          : (scope: '', query: query, keywordScope: null);
    }
    try {
      final value = jsonDecode(raw.substring(_prefix.length));
      if (value is! Map ||
          value['scope'] is! String ||
          value['query'] is! String) {
        return null;
      }
      final query = (value['query'] as String).trim();
      if (query.isEmpty) return null;
      return (
        scope: value['scope'] as String,
        query: query,
        keywordScope: parseSourceKeywordSearchScope(value['keywordScope']),
      );
    } catch (_) {
      return null;
    }
  }

  static List<String> words(List<String> entries, {required String scope}) => [
    ...entries
        .map(decode)
        .nonNulls
        .where((entry) => entry.scope == scope)
        .map((entry) => entry.query)
        .toSet(),
  ];

  static KeywordSearchScope keywordScopeFor(
    List<String> entries,
    String query, {
    required String scope,
  }) =>
      entries
          .map(decode)
          .nonNulls
          .where((entry) => entry.scope == scope && entry.query == query)
          .firstOrNull
          ?.keywordScope ??
      KeywordSearchScope.all;

  static List<String> add(
    List<String> entries,
    String query, {
    required String scope,
    KeywordSearchScope? keywordScope,
    int limit = 300,
  }) {
    final word = query.trim();
    if (word.isEmpty) return List.of(entries);
    final encoded =
        scope.isEmpty &&
            (keywordScope == null || keywordScope == KeywordSearchScope.all)
        ? word
        : '$_prefix${jsonEncode({'scope': scope, 'query': word, if (keywordScope != null) 'keywordScope': keywordScope.name})}';
    return [
      encoded,
      ...entries.where((raw) {
        final entry = decode(raw);
        return entry == null || entry.scope != scope || entry.query != word;
      }),
    ].take(limit).toList();
  }

  static List<String> remove(
    List<String> entries,
    Set<String> selected, {
    required String scope,
  }) => entries.where((raw) {
    final entry = decode(raw);
    return entry == null ||
        entry.scope != scope ||
        !selected.contains(entry.query);
  }).toList();
}
