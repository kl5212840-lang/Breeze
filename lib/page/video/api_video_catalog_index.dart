import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/util/text/public_search_text.dart';

Set<String> _values(String value) => value
    .split(RegExp(r'[/,，、;；|]'))
    .map((value) => value.trim())
    .where((value) => value.isNotEmpty)
    .toSet();

/// Index only public metadata already returned for this exact catalog item.
/// Missing fields stay missing; watch/upload time never supplies a release year.
ShelfFacetEntry apiCatalogFacetEntry(
  ApiVideoItem item, {
  ApiVideoItem? detail,
}) {
  final valid =
      detail != null &&
          detail.id == item.id &&
          detail.detailUrl == item.detailUrl
      ? detail
      : null;
  Set<String> choose(String summary, String? full) =>
      _values(full?.trim().isNotEmpty == true ? full! : summary);
  final fields = <String, Set<String>>{
    'tags': choose(item.genres, valid?.genres),
    'category': choose(item.typeName, valid?.typeName),
    'year': choose(item.year, valid?.year),
    'area': choose(item.area, valid?.area),
    'language': choose(item.language, valid?.language),
  }..removeWhere((_, values) => values.isEmpty);
  return ShelfFacetEntry(
    key: item.id,
    source: item.detailUrl.origin,
    searchText: [
      item.title,
      item.alternateTitle,
      item.description,
      item.actors,
      item.directors,
      item.writers,
      if (valid != null) ...[
        valid.title,
        valid.alternateTitle,
        valid.description,
        valid.actors,
        valid.directors,
        valid.writers,
      ],
      ...fields.values.expand((values) => values),
    ].join(' ').toLowerCase(),
    fields: fields,
  );
}

List<ApiVideoItem> filterApiCatalogItems(
  List<ApiVideoItem> items, {
  String query = '',
  KeywordSearchScope scope = KeywordSearchScope.all,
  ShelfFacetSelection facets = const ShelfFacetSelection(),
  Map<String, ApiVideoItem> details = const {},
}) {
  if (query.trim().isEmpty && !facets.isActive) return items;
  final matchTitle = scope == KeywordSearchScope.title
      ? keywordTitleMatcher(query)
      : null;
  final words = matchTitle == null
      ? normalizePublicSearchText(
          query,
        ).split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList()
      : const <String>[];
  return items.where((item) {
    final detail = details[item.id];
    if (matchTitle != null &&
        !matchTitle([
          item.title,
          item.alternateTitle,
          if (detail != null && detail.detailUrl == item.detailUrl) ...[
            detail.title,
            detail.alternateTitle,
          ],
        ])) {
      return false;
    }
    if (words.isEmpty && !facets.isActive) return true;
    final entry = apiCatalogFacetEntry(item, detail: detail);
    return (words.isEmpty ||
            words.every(
              normalizePublicSearchText(entry.searchText).contains,
            )) &&
        shelfFacetMatches(entry, facets, currentFolder: null);
  }).toList();
}
