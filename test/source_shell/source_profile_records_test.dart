import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/comic_list/cubit/plugin_paged_comic_list_cubit.dart';
import 'package:zephyr/page/source_shell/models/source_cloud_favorites.dart';
import 'package:zephyr/page/source_shell/models/source_profile_records.dart';
import 'package:zephyr/page/source_shell/view/source_profile_records_view.dart';

import '../test_helper.dart';

void main() {
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    objectbox.userSettingBox.put(UserSetting());
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  tearDown(TestObjectBoxHelper.cleanComicFolderBoxes);

  test('cloud favorite preview retains metadata and cover', () {
    final items = parseSourceCloudFavoritePreview({
      'source': 'test',
      'data': {
        'items': [
          {
            'source': 'test',
            'id': 'remote-1',
            'title': '云端漫画',
            'subtitle': '',
            'finished': false,
            'likesCount': 8,
            'viewsCount': 100,
            'updatedAt': '',
            'cover': {
              'id': 'remote-1',
              'url': 'https://example.com',
              'path': 'remote-1.jpg',
              'extern': {},
            },
            'metadata': [
              {
                'type': 'author',
                'name': '作者',
                'value': ['作者甲'],
              },
              {
                'type': 'categories',
                'name': '分类',
                'value': ['短篇'],
              },
            ],
            'raw': {'description': '云端简介'},
            'extern': <String, dynamic>{},
          },
        ],
      },
    }, fallbackSource: 'fallback');

    expect(items.single.id, 'remote-1');
    expect(items.single.cover.cachePath, 'remote-1.jpg');
    expect(items.single.metadataValues('author'), ['作者甲']);
    expect(items.single.raw['description'], '云端简介');
  });

  test('cloud favorite respects nested paging end marker', () {
    expect(
      pluginListPageHasReachedMax(
        data: {
          'paging': {'page': 1, 'pages': 1, 'hasReachedMax': true},
        },
        page: 1,
        isEmpty: false,
      ),
      isTrue,
    );
    expect(
      pluginListPageHasReachedMax(
        data: {
          'paging': {'page': 1, 'pages': 2, 'hasReachedMax': false},
        },
        page: 1,
        isEmpty: false,
      ),
      isFalse,
    );
  });

  test('profile records filter source and deleted items, newest first', () {
    final old = DateTime.utc(2025, 1, 1);
    final recent = DateTime.utc(2025, 1, 2);
    objectbox.unifiedFavoriteBox.putMany([
      createTestFavorite('old', updatedAt: old),
      createTestFavorite('new', updatedAt: recent),
      createTestFavorite('deleted', deleted: true),
      createTestFavorite('other')..source = 'other',
    ]);
    objectbox.unifiedHistoryBox.put(createTestHistory('watched'));
    objectbox.unifiedDownloadBox.put(createTestDownload('saved'));

    final records = loadSourceProfileRecords(['test']);
    expect(records.favorites.map((e) => e.id), ['new', 'old']);
    expect(records.history.map((e) => e.id), ['watched']);
    expect(records.downloads.map((e) => e.id), ['saved']);
  });

  testWidgets('home preview shows up to three covers without opening a list', (
    tester,
  ) async {
    final entries = List.generate(4, (i) => createTestFavorite('comic-$i'));
    final records = entries.map((e) {
      objectbox.unifiedFavoriteBox.put(e);
      return e;
    }).toList();
    final items = loadSourceProfileRecords(['test']).favorites;
    expect(records.length, 4);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SourceProfilePreviewSection(
            mode: ShelfPageMode.favorite,
            entries: items,
            onViewAll: () {},
            onReturned: () {},
          ),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('profile-preview-favorite')),
      findsOneWidget,
    );
    expect(find.byType(AspectRatio), findsNWidgets(3));
    expect(find.text('查看全部'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('full records default to detailed list; grid is optional', (
    tester,
  ) async {
    objectbox.unifiedFavoriteBox.put(createTestFavorite('comic-1'));
    final entries = loadSourceProfileRecords(['test']).favorites;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SourceProfileRecordsView(
            mode: ShelfPageMode.favorite,
            entries: entries,
            onBack: () {},
            onRefresh: () {},
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('profile-detailed-list')), findsOneWidget);
    expect(find.text('Test Comic comic-1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile-grid-mode')));
    await tester.pump();
    expect(find.byKey(const ValueKey('profile-cover-grid')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  });
}
