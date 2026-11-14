import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';
import 'package:zephyr/page/video/api_video_catalog_index.dart';
import 'package:zephyr/page/video/api_video_models.dart';

ApiVideoItem item(String id, {String title = '作品', String genres = '', String year = '', String area = ''}) =>
    ApiVideoItem(id: id, title: title, detailUrl: Uri.parse('https://catalog.test/videos/$id'), genres: genres, year: year, area: area);

void main() {
  test('local keyword AND facets operate on loaded public records only', () {
    final items = [item('1', title: 'Space adventure', genres: '动作、科幻', year: '2026'),
      item('2', title: 'Space comedy', genres: '喜剧', year: '2026'), item('3', title: 'Adventure', genres: '科幻', year: '2025')];
    final visible = filterApiCatalogItems(items, query: 'space adventure', facets: const ShelfFacetSelection(values: {
      'tags': {'科幻', '喜剧'}, 'year': {'2026'},
    }));
    expect(visible.map((item) => item.id), ['1']);
    expect(items, hasLength(3));
    expect(filterApiCatalogItems(items), orderedEquals(items));
  });

  test('missing metadata stays unknown and exact matching detail can enrich it', () {
    final summary = item('1');
    expect(apiCatalogFacetEntry(summary).fields.containsKey('year'), isFalse);
    const selection = ShelfFacetSelection(values: {'tags': {'科幻'}});
    expect(filterApiCatalogItems([summary], facets: selection), isEmpty);
    expect(filterApiCatalogItems([summary], facets: selection, details: {'1': item('1', genres: '科幻')}), [summary]);
    final otherOrigin = ApiVideoItem(id: '1', title: 'Other', detailUrl: Uri.parse('https://other.test/videos/1'), genres: '科幻');
    expect(filterApiCatalogItems([summary], facets: selection, details: {'1': otherOrigin}), isEmpty);
    expect(filterApiCatalogItems([summary], facets: selection, details: {'1': item('2', genres: '科幻')}), isEmpty);
  });

  test('unknown plugins and reserved real metadata retain distinct values', () {
    final missing = item('1');
    final real = item('2', genres: shelfFacetUnknown);
    const selection = ShelfFacetSelection(values: {'tags': {shelfFacetUnknown}});
    expect(filterApiCatalogItems([missing, real], facets: selection), [missing]);
    final exact = ShelfFacetSelection(values: {'tags': {shelfFacetEncodeValue(shelfFacetUnknown)}});
    expect(filterApiCatalogItems([missing, real], facets: exact), [real]);
  });
}
