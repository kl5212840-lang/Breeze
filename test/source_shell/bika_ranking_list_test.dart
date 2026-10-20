import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/comic_list/view/bika_ranking_list.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';

import '../test_helper.dart';

void main() {
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    objectbox.userSettingBox.put(UserSetting());
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  testWidgets('ranking shows order, author, category and period count', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1320, 2868);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final entry = UnifiedComicListItem.fromJson({
      'source': 'e9f18928-3ba8-4d86-a12e-b53a62f47933',
      'id': 'ranked-1',
      'title': '榜单作品',
      'subtitle': '',
      'finished': false,
      'likesCount': 8,
      'viewsCount': 999999,
      'updatedAt': '',
      'cover': {
        'id': 'ranked-1',
        'url': '',
        'path': '',
        'extern': <String, dynamic>{},
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
      'raw': {'leaderboardCount': 39682},
      'extern': <String, dynamic>{},
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BikaRankingList(
            entries: [entry],
            hasReachedMax: true,
            isLoadingMore: false,
            loadMoreFailed: false,
            onRetryLoadMore: () {},
            onLoadMore: () {},
          ),
        ),
      ),
    );
    expect(find.text('1'), findsOneWidget);
    expect(find.text('榜单作品'), findsOneWidget);
    expect(find.text('作者甲'), findsOneWidget);
    expect(find.text('短篇'), findsOneWidget);
    expect(find.text('指名次数  39682'), findsOneWidget);
    expect(find.textContaining('999999'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 150));

    tester.view.physicalSize = const Size(960, 2000);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.7)),
          child: child!,
        ),
        home: Scaffold(
          body: BikaRankingList(
            entries: [
              entry.copyWith(title: '这是一部标题非常长并且需要在较大字体下仍能完整布局的排行榜漫画作品'),
            ],
            hasReachedMax: true,
            isLoadingMore: false,
            loadMoreFailed: false,
            onRetryLoadMore: () {},
            onLoadMore: () {},
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
