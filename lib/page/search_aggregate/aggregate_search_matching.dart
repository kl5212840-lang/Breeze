import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search_result/view/source_list_categories.dart';
import 'package:zephyr/page/source_shell/source_experience_preferences.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/util/text/public_search_text.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';

final _fieldSeparators = RegExp(r'[,，、/|；;]');
const _categoryFields = {'category', 'categories'};
const _comicFields = {..._categoryFields, 'tag', 'tags', 'author'};

/// Source-specific browse URLs and context cannot replace the new keyword.
Map<String, dynamic> aggregateComicSearchExtern(
  SearchStates search,
  String source,
) => {
  if (explicitKeywordSearchScope(search.pluginExtern) case final scope?)
    keywordSearchScopeKey: scope.name,
  if (source == search.from)
    for (final key in [
      'q_type',
      'main_tag',
      'sortBy',
      'categories',
      'blockedCategories',
      'settingsBlockedCategories',
    ])
      if (search.pluginExtern.containsKey(key)) key: search.pluginExtern[key],
};

Set<String> aggregateBlockedCategories(Map<String, dynamic> extern) => {
  ...blockedCategoryNames(extern['blockedCategories']),
  ...blockedCategoryNames(extern['settingsBlockedCategories']),
};

bool hasExplicitAggregateComicSearch(Map<String, dynamic> extern) =>
    blockedCategoryNames(extern['categories']).isNotEmpty ||
    extern['sortBy'] != null ||
    extern['main_tag'] != null ||
    (extern['q_type']?.toString().trim().isNotEmpty ?? false);

String? aggregateDeclaredCategory({
  required String source,
  required String query,
  required Iterable<String> options,
  required Map<String, dynamic> extern,
}) {
  if (!isBikaExperienceSource(source) ||
      explicitKeywordSearchScope(extern) == KeywordSearchScope.title ||
      hasExplicitAggregateComicSearch(extern)) {
    return null;
  }
  final needle = normalizePublicSearchText(query);
  if (needle.isEmpty ||
      aggregateBlockedCategories(
        extern,
      ).map(normalizePublicSearchText).contains(needle)) {
    return null;
  }
  final matches = options
      .where((name) => normalizePublicSearchText(name) == needle)
      .toSet();
  return matches.length == 1 ? matches.single : null;
}

SearchStates aggregateCategorySearch(
  SearchStates search,
  String source,
  String category,
) => search.copyWith(
  from: source,
  searchKeyword: '',
  pluginExtern: {
    ...aggregateComicSearchExtern(search, source),
    'categories': [category],
  },
);

List<UnifiedComicListItem> orderAggregateComics(
  List<UnifiedComicListItem> items,
  String query,
) => _orderPreview(
  items,
  query,
  (item) => [item.title],
  (item) => _comicValues(item, _comicFields),
);

Iterable<String> _comicValues(
  UnifiedComicListItem item,
  Set<String> fields,
) sync* {
  for (final field in item.metadata) {
    if (fields.contains(field.type.trim().toLowerCase())) {
      yield* field.value.whereType<String>();
    }
  }
}

bool aggregateComicHasCategory(UnifiedComicListItem item, String category) {
  final needle = normalizePublicSearchText(category);
  return _normalizeFields(
    _comicValues(
      item,
      _categoryFields,
    ).expand((value) => value.split(_fieldSeparators)),
  ).contains(needle);
}

List<ApiVideoItem> orderAggregateVideos(
  List<ApiVideoItem> items,
  String query,
) => _orderPreview(
  items,
  query,
  (item) => [item.title, item.alternateTitle],
  (item) => [
    item.typeName,
    item.genres,
    item.writers,
    item.directors,
    item.actors,
  ],
);

List<String> _normalizeFields(Iterable<String> values) =>
    normalizePublicSearchText(
      values.join('\n'),
    ).split('\n').map((value) => value.trim()).toList();

List<T> _orderPreview<T>(
  List<T> items,
  String query,
  Iterable<String> Function(T) titles,
  Iterable<String> Function(T) metadata,
) {
  if (items.length < 2) return items;
  final needle = normalizePublicSearchText(query);
  if (needle.isEmpty) return items;
  final ordered = List.generate(5, (_) => <T>[]);
  for (final item in items) {
    final names = _normalizeFields(titles(item));
    final fields = _normalizeFields(
      metadata(
        item,
      ).expand((value) => [value, ...value.split(_fieldSeparators)]),
    );
    final rank = names.contains(needle)
        ? 0
        : fields.contains(needle)
        ? 1
        : names.any((name) => name.contains(needle))
        ? 2
        : fields.any((field) => field.contains(needle))
        ? 3
        : 4;
    ordered[rank].add(item);
  }
  // A plug-in can match additional fields that its cards don't expose.
  return [for (final tier in ordered) ...tier];
}
