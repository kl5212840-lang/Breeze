import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search_result/bloc/search_bloc.dart';
import 'package:zephyr/page/search_result/view/search_result_page.dart';
import 'package:zephyr/page/search_result/view/source_quick_category_bar.dart';
import 'package:zephyr/page/search_result/view/source_search_detail_list.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';

import '../test_helper.dart';

void main() {
  test(
    'failed next page retries that page instead of duplicating the previous page',
    () {
      const lastSuccessful = SearchEvent(page: 1);
      const failed = SearchState(
        status: SearchStatus.getMoreFailure,
        searchEvent: SearchEvent(page: 2),
      );
      expect(
        searchRetryEvent(lastSuccessful, failed, SearchStatus.loadingMore).page,
        2,
      );
      expect(
        searchRetryEvent(lastSuccessful, failed, SearchStatus.initial).page,
        1,
      );
    },
  );

  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    objectbox.userSettingBox.put(UserSetting());
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  testWidgets('category tap blocks instead of replacing inclusion filters', (
    tester,
  ) async {
    final searchCubit = SearchCubit(
      const SearchStates().copyWith(
        pluginExtern: {
          'categories': ['同人'],
          'blockedCategories': <String>[],
        },
      ),
    );
    final searchBloc = SearchBloc();
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<SearchCubit>.value(value: searchCubit),
          BlocProvider<SearchBloc>.value(value: searchBloc),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SourceQuickCategoryBar(
              categories: const ['短篇', '同人', '生肉'],
              detailedView: true,
              onViewChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('category-短篇')));
    await tester.pump();
    expect(searchCubit.state.pluginExtern['categories'], ['同人']);
    expect(searchCubit.state.pluginExtern['blockedCategories'], ['短篇']);
    expect(find.textContaining('已屏蔽'), findsOneWidget);

    await tester.tap(find.text('清除屏蔽 (1)'));
    await tester.pump();
    expect(
      searchCubit.state.pluginExtern.containsKey('blockedCategories'),
      isFalse,
    );

    await tester.tap(find.byKey(const ValueKey('category-短篇')));
    await tester.pump();
    expect(searchCubit.state.pluginExtern['blockedCategories'], ['短篇']);
    await tester.tap(find.byKey(const ValueKey('category-短篇')));
    await tester.pump();
    expect(searchCubit.state.pluginExtern['blockedCategories'], isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await searchCubit.close();
    await searchBloc.close();
  });

  testWidgets('detail row shows available metadata on phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1320, 2868);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final item = UnifiedComicListItem.fromJson({
      'source': 'personal-bika',
      'id': 'comic-1',
      'title': '一本漫画标题',
      'subtitle': '',
      'finished': true,
      'likesCount': 42,
      'viewsCount': 120,
      'updatedAt': '',
      'cover': {
        'id': 'comic-1',
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
          'value': ['短篇', '同人'],
        },
        {
          'type': 'tags',
          'name': '标签',
          'value': ['奇幻'],
        },
      ],
      'raw': {'description': '这里是一段简介'},
      'extern': <String, dynamic>{},
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SourceSearchDetailTile(entry: item)),
      ),
    );
    expect(find.text('一本漫画标题'), findsOneWidget);
    expect(find.text('作者甲'), findsOneWidget);
    expect(find.textContaining('短篇'), findsOneWidget);
    expect(find.text('奇幻'), findsOneWidget);
    expect(find.text('这里是一段简介'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 150));
  });
}
