import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/cubit/string_select.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comic_list/cubit/plugin_paged_comic_list_cubit.dart';
import 'package:zephyr/page/comic_list/models/comic_list_scene.dart';
import 'package:zephyr/page/comic_list/view/comic_list_page.dart';
import 'package:zephyr/page/comic_list/view/plugin_comic_grid_sliver.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search_result/bloc/search_bloc.dart';
import 'package:zephyr/page/search_result/models/comic_number.dart';
import 'package:zephyr/page/search_result/view/search_result_page.dart';
import 'package:zephyr/page/search_result/view/source_list_categories.dart';
import 'package:zephyr/page/search_result/view/source_search_detail_list.dart';
import 'package:zephyr/page/source_shell/source_list_presentation.dart';
import 'package:zephyr/page/source_shell/source_list_view_toggle.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';

import '../test_helper.dart';

const _copy = 'b28da416-f2d4-4208-a85e-8b4c7c648e48';

Map<String, dynamic> _entry(String id) => {
  'source': _copy,
  'id': id,
  'title': id,
  'subtitle': '',
  'finished': false,
  'likesCount': 0,
  'viewsCount': 0,
  'updatedAt': '',
  'cover': {'id': id, 'url': '', 'path': '', 'extern': {}},
  'metadata': [
    {
      'type': 'author',
      'name': '作者',
      'value': ['Fixture Author'],
    },
  ],
  'raw': {'brief': 'Fixture description'},
  'extern': <String, dynamic>{},
};

/// FRB's mock entrypoint does not load an FFI library. These three methods
/// replace the complete QJS boundary; no plugin JS or network is executed.
class _OfflineApi extends RustLibApi {
  final calls = <({String function, Map<String, dynamic> arguments})>[];

  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({
    required String name,
  }) async => true;

  @override
  Future<String> crateApiQjsQjsCurrentBundle({
    required String runtimeName,
  }) async => jsonEncode('offline-fixture');

  @override
  Future<Uint8List> crateApiQjsQjsTaskCall({
    required String runtimeName,
    required String taskGroupKey,
    required bool isOnce,
    String? bundleJs,
    String? bundleUrl,
    required String fnPath,
    required String argsJson,
  }) async {
    final arguments = Map<String, dynamic>.from(jsonDecode(argsJson) as Map);
    calls.add((function: fnPath, arguments: arguments));
    final Object reply;
    if (fnPath == 'init') {
      reply = {
        'data': {'ok': true},
      };
    } else if (fnPath == 'getAdvancedSearchScheme') {
      reply = {
        'scheme': {'fields': <dynamic>[]},
      };
    } else if (fnPath == 'getCopyListFixture') {
      final page = arguments['page'] as int;
      reply = {
        'source': _copy,
        'data': {
          'paging': {'page': page, 'pages': 2, 'hasReachedMax': page == 2},
          'items': List.generate(20, (index) => _entry('copy-$page-$index')),
        },
      };
    } else {
      throw StateError('Unexpected fixture operation: $fnPath');
    }
    return Uint8List.fromList(utf8.encode(jsonEncode(reply)));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected native API: ${invocation.memberName}');
}

class _SeededSearchBloc extends SearchBloc {
  _SeededSearchBloc(SearchState initial) {
    emit(initial);
  }
  final events = <SearchEvent>[];
  @override
  void add(SearchEvent event) => events.add(event);
}

void main() {
  late _OfflineApi api;
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    api = _OfflineApi();
    RustLib.initMock(api: api);
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api.calls.clear();
  });

  testWidgets(
    'ordinary Copy list switches view without another request or losing loaded pages and filters',
    (tester) async {
      expect(sourceQuickCategories(_copy), isEmpty);
      final settings = GlobalSettingCubit();
      const scene = ComicListScene(
        title: 'Copy fixture list',
        from: _copy,
        body: ComicListBodyConfig(
          request: ComicListRequestConfig(
            fnPath: 'getCopyListFixture',
            core: {'genre': 'fantasy'},
            extern: {'q_type': 'author', 'order': '-datetime_updated'},
          ),
        ),
      );
      await tester.pumpWidget(
        BlocProvider.value(
          value: settings,
          child: const MaterialApp(home: ComicListPage(scene: scene)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SourceListViewToggle), findsOneWidget);
      expect(find.byType(PluginComicGridSliver), findsOneWidget);
      final cubit = tester
          .element(find.byType(PluginComicGridSliver))
          .read<PluginPagedComicListCubit>();
      await cubit.loadMore();
      await tester.pumpAndSettle();
      final loaded = cubit.state;
      expect(loaded.list.length, 40);
      expect(loaded.page, 2);
      final calls = api.calls.length;

      await tester.tap(find.byType(SourceListViewToggle));
      await tester.pumpAndSettle();
      expect(find.byType(SourceSearchDetailList), findsOneWidget);
      final after = tester
          .element(find.byType(SourceSearchDetailList))
          .read<PluginPagedComicListCubit>();
      expect(identical(after, cubit), isTrue);
      expect(identical(after.state, loaded), isTrue);
      expect(api.calls.length, calls);
      final pageCalls = api.calls
          .where((call) => call.function == 'getCopyListFixture')
          .toList();
      expect(pageCalls.map((call) => call.arguments['page']), [1, 2]);
      for (final call in pageCalls) {
        expect(call.arguments['genre'], 'fantasy');
        expect(call.arguments['extern'], {
          'q_type': 'author',
          'order': '-datetime_updated',
        });
      }
      expect(await SourceListPreferences.read(_copy), isTrue);
      await tester.tap(find.byType(SourceListViewToggle));
      await tester.pumpAndSettle();
      expect(api.calls.length, calls);
      expect(cubit.state.list.length, 40);
      expect(await SourceListPreferences.read(_copy), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await settings.close();
    },
  );

  testWidgets(
    'Copy search has a view toggle with no quick categories and keeps results and author scope',
    (tester) async {
      expect(sourceQuickCategories(_copy), isEmpty);
      const searchState = SearchStates(
        from: _copy,
        searchKeyword: 'Fixture author',
        sortBy: 3,
        pluginExtern: {'q_type': 'author', 'period': 'week'},
      );
      const event = SearchEvent(searchStates: searchState);
      final search = SearchCubit(searchState);
      final bloc = _SeededSearchBloc(
        SearchState(
          status: SearchStatus.success,
          currentPage: 2,
          totalPages: 2,
          hasReachedMax: true,
          searchEvent: event,
          comics: List.generate(
            24,
            (index) => ComicNumber(
              buildNumber: index,
              comic: UnifiedComicListItem.fromJson(_entry('search-$index')),
            ),
          ),
        ),
      );
      final settings = GlobalSettingCubit();
      final selection = StringSelectCubit();
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<SearchCubit>.value(value: search),
            BlocProvider<SearchBloc>.value(value: bloc),
            BlocProvider<GlobalSettingCubit>.value(value: settings),
            BlocProvider<StringSelectCubit>.value(value: selection),
          ],
          child: const MaterialApp(home: SearchResultPage(searchEvent: event)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      final before = bloc.state;
      final calls = api.calls.length;
      expect(find.byType(SourceSearchDetailList), findsOneWidget);
      expect(find.byTooltip(t.comicList.switchToGrid), findsOneWidget);
      await tester.tap(find.byTooltip(t.comicList.switchToGrid));
      await tester.pumpAndSettle();
      expect(find.byType(PluginComicGridSliver), findsOneWidget);
      expect(identical(bloc.state, before), isTrue);
      expect(search.state, searchState);
      expect(bloc.events, isEmpty);
      expect(api.calls.length, calls);
      expect(await SourceListPreferences.read(_copy), isFalse);
      await tester.tap(find.byTooltip(t.comicList.switchToList));
      await tester.pumpAndSettle();
      expect(find.byType(SourceSearchDetailList), findsOneWidget);
      expect(bloc.state.comics.length, 24);
      expect(search.state.pluginExtern, {'q_type': 'author', 'period': 'week'});
      expect(bloc.events, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await Future.wait([
        search.close(),
        bloc.close(),
        settings.close(),
        selection.close(),
      ]);
    },
  );
}
