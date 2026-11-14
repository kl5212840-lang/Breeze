import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/widgets/comic_entry/models/unified_comic_list_item.dart';
import 'package:zephyr/widgets/comic_entry/models/unified_comic_list_item_mapper.dart';

import '../test_helper.dart';

void main() {
  test(
    'stored metadata projects actual author, categories, tags and description',
    () {
      final row = createTestFavorite('source:comic')
        ..description = '  A saved description.  '
        ..titleMeta = '[{"name":"浏览：1234"},{"name":"热度：13"}]'
        ..creator = jsonEncode({'name': 'Uploader'})
        ..metadata = jsonEncode([
          {
            'type': 'author',
            'value': [
              {'name': 'Actual author'},
            ],
          },
          {
            'type': 'categories',
            'value': ['Adventure'],
          },
          {
            'type': 'tag',
            'value': ['Travel', 'Travel', ''],
          },
          {
            'type': 'internal-debug',
            'value': ['Private value'],
          },
        ]);
      final info = unifiedComicFromUnifiedFavorite(row).toSimplifyEntryInfo();
      expect(info.description, 'A saved description.');
      expect(info.detailMetadata, 'Actual author · Adventure · Travel');
      expect(info.detailViewCount, 1234);
      expect(info.detailPopularity, 0);
      expect(info.detailMetadata, isNot(contains('Uploader')));
      expect(info.detailMetadata, isNot(contains('Private value')));
    },
  );

  test('history and download projection uses each stored record', () {
    const metadata = '[{"type":"tags","value":["Local tag"]}]';
    final history = createTestHistory('source:comic')
      ..description = 'History description'
      ..titleMeta = '[{"name":"热度：356"}]'
      ..metadata = metadata;
    final download = createTestDownload('source:comic')
      ..description = 'Download description'
      ..metadata = metadata;
    final historyInfo = unifiedComicFromUnifiedHistory(
      history,
    ).toSimplifyEntryInfo();
    final downloadInfo = unifiedComicFromUnifiedDownload(
      download,
    ).toSimplifyEntryInfo();
    expect(historyInfo.description, 'History description');
    expect(downloadInfo.description, 'Download description');
    expect(historyInfo.detailMetadata, 'Local tag');
    expect(historyInfo.detailViewCount, 0);
    expect(historyInfo.detailPopularity, 356);
    expect(downloadInfo.detailMetadata, 'Local tag');
  });

  for (final raw in [
    '',
    '{broken',
    '{}',
    '[null, 4]',
    '[{"type":"author","value":[{"id":"hidden"},null,true]}]',
  ]) {
    test('empty or malformed stored metadata stays absent: $raw', () {
      final row = createTestFavorite('source:comic')
        ..creator = jsonEncode({'name': 'Uploader'})
        ..metadata = raw;
      final info = unifiedComicFromUnifiedFavorite(row).toSimplifyEntryInfo();
      expect(info.description, isEmpty);
      expect(info.detailMetadata, isEmpty);
    });
  }

  test(
    'typed plugin metadata is usable without substituting subtitle as author',
    () {
      final item =
          unifiedComicFromUnifiedFavorite(
            createTestFavorite('source:comic'),
          ).copyWith(
            subtitle: 'An actual chapter title',
            raw: const {},
            metadata: const [
              UnifiedComicMetadata(type: 'author', name: '', value: ['Writer']),
              UnifiedComicMetadata(type: 'tags', name: '', value: ['Mystery']),
              UnifiedComicMetadata(
                type: 'unknown',
                name: '',
                value: ['Ignore'],
              ),
            ],
          );
      final info = item.toSimplifyEntryInfo();
      expect(info.detailMetadata, 'Writer · Mystery');
      expect(info.description, isEmpty);
    },
  );
}
