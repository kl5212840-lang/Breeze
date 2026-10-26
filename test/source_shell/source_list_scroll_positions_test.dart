import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/comic_list/view/plugin_comic_grid_sliver.dart';
import 'package:zephyr/page/comic_list/view/plugin_paged_comic_list_view.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search_result/bloc/search_bloc.dart';
import 'package:zephyr/page/search_result/models/comic_number.dart';
import 'package:zephyr/page/search_result/view/search_result_page.dart';
import 'package:zephyr/page/search_result/view/source_search_detail_list.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';

import '../test_helper.dart';

Map<String, dynamic> _item(int index) => {
  'source': 'scroll-fixture',
  'id': 'comic-$index',
  'title': 'Comic $index',
  'subtitle': '',
  'finished': false,
  'likesCount': 0,
  'viewsCount': 0,
  'updatedAt': '',
  'cover': {'id': '$index', 'url': '', 'path': '', 'extern': {}},
  'metadata': index == 0
      ? [
          {
            'type': 'categories',
            'name': '分类',
            'value': ['blocked'],
          },
        ]
      : [],
  'raw': {},
  'extern': {},
};

Map<String, dynamic> _page({int count = 60}) => {
  'source': 'scroll-fixture',
  'data': {
    'paging': {'page': 1, 'pages': 3},
    'items': [for (var i = 0; i < count; i++) _item(i)],
  },
};

class _FixtureSearchBloc extends SearchBloc {
  final requests = <SearchEvent>[];
  @override
  void add(SearchEvent event) => requests.add(event);

  void show(SearchStates criteria) => emit(
    SearchState(
      status: SearchStatus.success,
      comics: [
        for (var i = 0; i < 60; i++)
          ComicNumber(
            buildNumber: i,
            comic: UnifiedComicListItem.fromJson(_item(i)),
          ),
      ],
      currentPage: 1,
      totalPages: 3,
      hasReachedMax: false,
      searchEvent: SearchEvent(searchStates: criteria),
    ),
  );
}

void main() {
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    objectbox.userSettingBox.put(UserSetting());
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'paged layouts remember separate positions without new page requests',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var detailed = true;
      var blocked = <String>{};
      var requests = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: Column(
                children: [
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => setState(() => detailed = !detailed),
                        child: const Text('Toggle'),
                      ),
                      TextButton(
                        onPressed: () => setState(() => blocked = {'blocked'}),
                        child: const Text('Filter'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: PluginPagedComicListView(
                      pluginId: 'scroll-fixture',
                      fnPath: 'fixtureList',
                      coreBuilder: (page) => {'page': page},
                      externBuilder: (_) => {},
                      detailedView: detailed,
                      blockedCategories: blocked,
                      requestPage: (_, _, _, _) async {
                        requests++;
                        return _page();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final detailController = tester
          .widget<SourceSearchDetailList>(find.byType(SourceSearchDetailList))
          .controller!;
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();
      final detailPixels = detailController.offset;
      expect(detailPixels, greaterThan(200));
      await tester.tap(find.text('Toggle'));
      await tester.pumpAndSettle();
      final gridController = tester
          .widget<PluginComicGridSliver>(find.byType(PluginComicGridSliver))
          .controller!;
      expect(
        gridController.offset,
        0,
        reason: 'an unvisited layout starts at its own beginning',
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();
      final gridPixels = gridController.offset;
      expect(gridPixels, greaterThan(100));
      await tester.tap(find.text('Toggle'));
      await tester.pumpAndSettle();
      expect(detailController.offset, closeTo(detailPixels, .1));
      await tester.tap(find.text('Toggle'));
      await tester.pumpAndSettle();
      expect(gridController.offset, closeTo(gridPixels, .1));
      expect(requests, 1);
      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      expect(gridController.offset, 0);
      await tester.tap(find.text('Toggle'));
      await tester.pumpAndSettle();
      expect(detailController.offset, 0);
      expect(
        requests,
        1,
        reason: 'local filtering and layout changes do not fetch',
      );
      await tester.tap(find.text('Toggle'));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: 'pending layout settlement must tolerate disposal',
      );
    },
  );

  testWidgets(
    'embedded detail lists honor the same scroll constraints as grids',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PluginPagedComicListView(
                pluginId: 'embedded-scroll-fixture',
                fnPath: 'fixtureList',
                coreBuilder: (page) => {'page': page},
                externBuilder: (_) => {},
                detailedView: true,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                requestPage: (_, _, _, _) async => _page(count: 1),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final list = tester.widget<SourceSearchDetailList>(
        find.byType(SourceSearchDetailList),
      );
      expect(list.shrinkWrap, isTrue);
      expect(list.physics, isA<NeverScrollableScrollPhysics>());
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'search layout changes preserve positions and criteria changes reset both',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final criteria = SearchCubit(const SearchStates(from: ''));
      final bloc = _FixtureSearchBloc()..show(criteria.state);
      final settings = GlobalSettingCubit();
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<SearchCubit>.value(value: criteria),
            BlocProvider<SearchBloc>.value(value: bloc),
            BlocProvider<GlobalSettingCubit>.value(value: settings),
          ],
          child: const MaterialApp(
            home: SearchResultPage(
              searchEvent: SearchEvent(searchStates: SearchStates(from: '')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 2),
      );
      final details = tester
          .widget<SourceSearchDetailList>(find.byType(SourceSearchDetailList))
          .controller!;
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -450));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 2),
      );
      final detailPixels = details.offset;
      await tester.tap(find.byTooltip(t.comicList.switchToGrid));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 2),
      );
      final grid = tester
          .widget<PluginComicGridSliver>(find.byType(PluginComicGridSliver))
          .controller!;
      expect(grid.offset, 0);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -250));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 2),
      );
      final gridPixels = grid.offset;
      await tester.tap(find.byTooltip(t.comicList.switchToList));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 2),
      );
      expect(details.offset, closeTo(detailPixels, .1));
      expect(bloc.requests, isEmpty);
      criteria.update(criteria.state.copyWith(pluginExtern: {'region': '1'}));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 2),
      );
      expect(details.offset, 0);
      await tester.tap(find.byTooltip(t.comicList.switchToGrid));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 2),
      );
      expect(grid.offset, 0);
      expect(gridPixels, greaterThan(100));
      expect(bloc.requests, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 2),
      );
      expect(tester.takeException(), isNull);
      await criteria.close();
      await settings.close();
      final closing = bloc.close();
      await tester.pump(const Duration(milliseconds: 200));
      await closing;
    },
  );
}
