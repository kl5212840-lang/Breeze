import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart';
import 'package:zephyr/page/comic_info/widgets/all_chip.dart';
import 'package:zephyr/page/search_result/view/source_list_categories.dart';
import 'package:zephyr/page/search_result/view/source_list_filter_bar.dart';
import 'package:zephyr/page/search_result/view/source_search_capabilities.dart';
import 'package:zephyr/page/search/widget/history.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';

import '../test_helper.dart';

void main() {
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    objectbox.userSettingBox.put(UserSetting());
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  test('category blocking uses the same metadata as detailed result rows', () {
    final entry = UnifiedComicListItem.fromJson({
      'source': 'test',
      'id': '1',
      'title': '测试漫画',
      'subtitle': '',
      'finished': false,
      'likesCount': 0,
      'viewsCount': 0,
      'updatedAt': '',
      'cover': {'id': '1', 'url': '', 'path': '', 'extern': {}},
      'metadata': [
        {
          'type': 'categories',
          'name': '分类',
          'value': ['全彩', '短篇'],
        },
      ],
      'raw': <String, dynamic>{},
      'extern': <String, dynamic>{},
    });
    expect(isEntryBlockedByCategory(entry, {'短篇'}), isTrue);
    expect(isEntryBlockedByCategory(entry, {'长篇'}), isFalse);
    expect(filterEntriesByBlockedCategories([entry], {'短篇'}), isEmpty);
    expect(filterEntriesByBlockedCategories([entry], {'长篇'}), [entry]);
  });

  test('combined category text still respects the local blocklist', () {
    final entry = UnifiedComicListItem.fromJson({
      'source': 'jm',
      'id': '2',
      'title': '漫画',
      'subtitle': '',
      'finished': false,
      'likesCount': 0,
      'viewsCount': 0,
      'updatedAt': '',
      'cover': {'id': '2', 'url': '', 'path': '', 'extern': {}},
      'metadata': [
        {
          'type': 'categories',
          'name': '分类',
          'value': ['同人 · 同人'],
        },
      ],
      'raw': <String, dynamic>{},
      'extern': <String, dynamic>{},
    });
    expect(isEntryBlockedByCategory(entry, {'同人'}), isTrue);
  });

  test('blocklist accepts both source map and local list forms', () {
    expect(blockedCategoryNames(['同人']), {'同人'});
    expect(blockedCategoryNames({'同人': true, '短篇': false}), {'同人'});
  });

  testWidgets('detail tags start in one line and can expand', (tester) async {
    final metadata = ComicInfoMetadata(
      type: 'tags',
      name: '标签',
      value: List.generate(
        12,
        (index) => ComicInfoActionItem(name: '标签$index'),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 340,
            child: AllChipWidget(
              comicId: '1',
              metadata: metadata,
              from: 'test',
            ),
          ),
        ),
      ),
    );
    expect(find.text('展开'), findsOneWidget);
    expect(find.text('收起'), findsNothing);
    await tester.tap(find.text('展开'));
    await tester.pump();
    expect(find.text('收起'), findsOneWidget);
    final firstChip = tester.getRect(find.text('标签0'));
    expect(firstChip.width, lessThan(100));
    final label = tester.getRect(find.text('标签'));
    expect((label.center.dy - firstChip.center.dy).abs(), lessThan(1));
  });

  testWidgets('a single author chip keeps content width', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 340,
            child: AllChipWidget(
              comicId: '1',
              metadata: const ComicInfoMetadata(
                type: 'author',
                name: '作者',
                value: [ComicInfoActionItem(name: '作者甲')],
              ),
              from: 'test',
            ),
          ),
        ),
      ),
    );
    final chip = tester.getRect(find.byType(AnimatedContainer));
    expect(chip.width, lessThan(150));
  });

  testWidgets('blocked-category toolbar stays usable on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 2000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SourceListFilterBar(
            categories: const ['短篇', '同人', '全彩'],
            blockedCategories: const {'短篇'},
            onCategoryTap: (_) {},
            onClearBlockedCategories: () {},
            sortValue: 'new',
            sortOptions: const {'new': '最新', 'old': '最早'},
            onSortChanged: (_) {},
            detailedView: true,
            onViewChanged: (_) {},
            pageLabel: '第1 / 12页',
            onPageTap: () {},
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.filter_alt_off_outlined), findsOneWidget);
    expect(find.text('第1 / 12页'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('source sort labels come from its own advanced-search scheme', () {
    expect(sourceSortOptions(const [
      {
        'key': 'sortBy',
        'options': [
          {'value': 1, 'label': '从新到旧'},
          {'value': 2, 'label': '最多观看'},
        ],
      },
    ]), {'1': '从新到旧', '2': '最多观看'});
  });

  testWidgets('clearing search history requires confirmation', (tester) async {
    final settings = GlobalSettingCubit()
      ..updateState((state) => state.copyWith(searchHistory: ['露出', '同人']));
    addTearDown(settings.close);
    await tester.pumpWidget(
      BlocProvider.value(
        value: settings,
        child: const MaterialApp(home: Scaffold(body: HistoryWidget())),
      ),
    );
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(settings.state.searchHistory, ['露出', '同人']);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(settings.state.searchHistory, ['露出', '同人']);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清空历史').last);
    await tester.pumpAndSettle();
    expect(settings.state.searchHistory, isEmpty);
  });
}
