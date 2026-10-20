import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart';
import 'package:zephyr/page/comic_info/widgets/all_chip.dart';
import 'package:zephyr/page/search_result/view/source_list_categories.dart';
import 'package:zephyr/page/search_result/view/source_list_filter_bar.dart';
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
          ),
        ),
      ),
    );
    expect(find.text('清除屏蔽 (1)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
