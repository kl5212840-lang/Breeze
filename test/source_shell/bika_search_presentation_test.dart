import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search_result/bloc/search_bloc.dart';
import 'package:zephyr/page/search_result/method/get_plugin_result.dart';
import 'package:zephyr/page/search_result/models/unified_plugin_search.dart';
import 'package:zephyr/page/search_result/view/search_result_page.dart';
import 'package:zephyr/page/search_result/view/source_quick_category_bar.dart';
import 'package:zephyr/page/search_result/view/source_search_capabilities.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search_result/view/source_search_detail_list.dart';
import 'package:zephyr/page/source_shell/source_experience_preferences.dart';
import 'package:zephyr/page/source_shell/source_list_block_preferences.dart';
import 'package:zephyr/service/plugin_account_authentication.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';

import '../test_helper.dart';

class _SearchRequests extends SearchBloc {
  final requests = <SearchEvent>[];

  @override
  void add(SearchEvent event) => requests.add(event);
}

void main() {
  const connectivity = MethodChannel('dev.fluttercommunity.plus/connectivity');
  final messenger =
      TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(connectivity, (_) async => ['wifi']);
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(connectivity, null);
  });
  test('pagination hides contradictory totals from older plugins', () {
    expect(
      trustworthyTotalPages(
        const UnifiedPluginSearchPaging(
          page: 1,
          pages: 1,
          total: 400,
          hasReachedMax: false,
        ),
      ),
      0,
    );
    expect(
      trustworthyTotalPages(
        const UnifiedPluginSearchPaging(
          page: 1,
          pages: 20,
          total: 400,
          hasReachedMax: false,
        ),
      ),
      20,
    );
  });

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

  test(
    'replacement failure retries the failed filters rather than the last successful query',
    () {
      const old = SearchEvent(searchStates: SearchStates(searchKeyword: 'old'));
      const failed = SearchState(
        status: SearchStatus.failure,
        searchEvent: SearchEvent(
          page: 3,
          searchStates: SearchStates(
            searchKeyword: 'new',
            pluginExtern: {'sortBy': 2},
          ),
        ),
      );
      final retry = searchRetryEvent(old, failed, SearchStatus.initial);
      expect(retry, failed.searchEvent);
    },
  );

  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    objectbox.userSettingBox.put(UserSetting());
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  test('Bika advanced filters omit the category controls', () {
    const query = SearchStates(from: bikaPlusSourceId, searchKeyword: '作品');
    expect(
      uniqueAdvancedFields(query.from, const [
        {'key': 'categories'},
        {'key': 'blockedCategories'},
        {'key': 'extra'},
      ]),
      const [
        {'key': 'extra'},
      ],
    );
    final random = query.copyWith(
      searchKeyword: '',
      pluginExtern: const {'url': 'https://fixture.test/comics/random'},
    );
    expect(isBikaRandomResult(random), isTrue);
    expect(isBikaRandomResult(random.copyWith(from: 'other-source')), isFalse);
  });

  testWidgets(
    'Bika keeps its category strip and page control on a narrow screen',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 740);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final search = SearchCubit(
        const SearchStates(from: bikaPlusSourceId, searchKeyword: '作品'),
      );
      final results = _SearchRequests();
      addTearDown(search.close);
      addTearDown(results.close);
      var jumped = 0;
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: search),
            BlocProvider<SearchBloc>.value(value: results),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2.2)),
              child: child!,
            ),
            home: Scaffold(
              body: SourceQuickCategoryBar(
                categories: const ['同人', '短篇', '3D'],
                detailedView: true,
                pageLabel: '第 1 / 79 页',
                onPageTap: () => jumped++,
                onViewChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final quick = find.byKey(
        const ValueKey('search-result.quick-categories'),
      );
      final filter = find.byKey(const ValueKey('search-result.filter'));
      final page = find.byKey(const ValueKey('search-result.page-progress'));
      final scope = find.byKey(const ValueKey('search-result.scope'));
      final stripTop = tester.getTopLeft(quick).dy;
      for (final state in [
        search.state,
        search.state.copyWith(pluginExtern: {keywordSearchScopeKey: 'author'}),
        search.state.copyWith(
          pluginExtern: {'url': 'https://fixture.test/comics?c=短篇'},
        ),
      ]) {
        search.update(state);
        await tester.pumpAndSettle();
        expect(scope, findsNothing);
        expect(filter, findsNothing);
        expect(
          find.byKey(const ValueKey('search-result.filter-options')),
          findsNothing,
        );
        expect(page.hitTestable(), findsOneWidget);
        expect(tester.getSize(page).height, greaterThanOrEqualTo(44));
        expect(tester.getTopLeft(quick).dy, stripTop);
        expect(tester.getTopLeft(page).dy, greaterThan(stripTop));
        await tester.tap(page);
      }
      expect(jumped, 3);
      expect(results.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('JM keeps its quick exclusions local on a narrow RTL page', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 740);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final breeze = ValueNotifier('breeze');
    addTearDown(breeze.dispose);
    final search = SearchCubit(
      const SearchStates(
        from: PluginAccountAuthenticationService.jm,
        searchKeyword: '作品',
      ),
    );
    addTearDown(search.close);
    final results = _SearchRequests();
    addTearDown(results.close);
    var jumped = false;
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: search),
          BlocProvider<SearchBloc>.value(value: results),
        ],
        child: AppInterfaceStyleScope(
          style: breeze,
          child: MaterialApp(
            builder: (context, child) => Directionality(
              textDirection: TextDirection.rtl,
              child: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2.2)),
                child: child!,
              ),
            ),
            home: Scaffold(
              body: SourceQuickCategoryBar(
                categories: const ['同人', '短篇', '3D'],
                detailedView: true,
                pageLabel: '第 1 / 79 页',
                onPageTap: () => jumped = true,
                onViewChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final quick = find.byKey(const ValueKey('search-result.quick-categories'));
    final scope = find.byKey(const ValueKey('search-result.scope'));
    final page = find.byKey(const ValueKey('search-result.page-progress'));
    expect(
      find.descendant(
        of: quick,
        matching: find.text(t.searchResult.blockCategories),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(page).dy,
      greaterThan(tester.getTopLeft(quick).dy),
    );
    expect(scope, findsNothing);
    await tester.tap(page);
    expect(jumped, isTrue);
    await tester.tap(find.byKey(const ValueKey('category-同人')));
    await tester.pump(const Duration(milliseconds: 330));
    expect(search.state.pluginExtern['blockedCategories'], ['同人']);
    expect(results.requests, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await SourceListBlockPreferences.flush();
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
      'raw': {'description': '这里是一段简介', 'pagesCount': 120},
      'extern': <String, dynamic>{},
    });

    final search = SearchCubit(const SearchStates());
    final results = SearchBloc();
    addTearDown(search.close);
    addTearDown(results.close);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: search),
          BlocProvider.value(value: results),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SourceQuickCategoryBar(
                  categories: const ['短篇'],
                  detailedView: true,
                  onViewChanged: (_) {},
                  pageLabel: '第1 / 39页',
                  onPageTap: () {},
                ),
                SourceSearchDetailTile(entry: item),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final cover = find
        .descendant(
          of: find.byType(SourceSearchDetailTile),
          matching: find.byType(ClipRRect),
        )
        .first;
    final progress = find.text('第1 / 39页');
    final toolbar = find.byKey(const ValueKey('search-result.toolbar'));
    final filter = find.byKey(const ValueKey('search-result.filter'));
    expect(tester.getTopLeft(progress).dx, tester.getTopLeft(cover).dx);
    expect(tester.getCenter(progress).dy, tester.getCenter(filter).dy);
    expect(tester.getSize(toolbar).height, lessThanOrEqualTo(48));
    expect(find.text('一本漫画标题'), findsOneWidget);
    expect(find.text('作者甲'), findsOneWidget);
    expect(find.text('短篇 · 同人 · 奇幻'), findsOneWidget);
    expect(find.text('这里是一段简介'), findsNothing);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('120 页'), findsOneWidget);
    await tester.tap(find.byTooltip(t.download.workDetails));
    await tester.pumpAndSettle();
    expect(find.text('奇幻'), findsOneWidget);
    expect(find.text('这里是一段简介'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
