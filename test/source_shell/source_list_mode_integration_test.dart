import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/page/comic_list/scene_filter/plugin_list_filter_dialog.dart';
import 'package:zephyr/page/comic_list/scene_filter/plugin_list_filter_schema.dart';
import 'package:zephyr/widgets/comic_entry/comic_record_time.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/cubit/string_select.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comic_list/cubit/plugin_paged_comic_list_cubit.dart';
import 'package:zephyr/page/comic_list/cubit/comic_list_cubit.dart';
import 'package:zephyr/page/comic_list/models/comic_list_scene.dart';
import 'package:zephyr/page/comic_list/view/comic_list_page.dart';
import 'package:zephyr/page/comic_list/view/plugin_comic_grid_sliver.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/widget/search_input_dialog.dart';
import 'package:zephyr/page/search_result/bloc/search_bloc.dart';
import 'package:zephyr/page/search_result/models/comic_number.dart';
import 'package:zephyr/page/search_result/view/search_result_page.dart';
import 'package:zephyr/page/search_result/view/source_list_categories.dart';
import 'package:zephyr/page/search_result/view/source_search_detail_list.dart';
import 'package:zephyr/page/source_shell/source_list_presentation.dart';
import 'package:zephyr/page/source_shell/source_list_view_toggle.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';
import 'package:zephyr/page/search/view/search_page.dart';
import 'package:zephyr/page/search/widget/search_bar.dart' as search_entry;
import 'package:zephyr/page/search_result/view/source_search_scope_control.dart';
import 'package:zephyr/widgets/source_choice_menu.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';

import '../test_helper.dart';

const _copy = 'b28da416-f2d4-4208-a85e-8b4c7c648e48';
const _advancedSource = 'c0fc7ca3-dac1-4c3a-899c-bee9a06a11a2';

Map<String, dynamic> _entry(String id, {String? category}) => {
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
    if (category != null)
      {
        'type': 'categories',
        'name': '题材',
        'value': [category],
      },
  ],
  'raw': {'brief': 'Fixture description'},
  'extern': <String, dynamic>{},
};

/// FRB's mock entrypoint does not load an FFI library. These three methods
/// replace the complete QJS boundary; no plugin JS or network is executed.
class _OfflineApi extends RustLibApi {
  final calls = <({String function, Map<String, dynamic> arguments})>[];
  Completer<Map<String, dynamic>>? filterGate;
  Completer<void>? publicListGate;

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
        'scheme': {
          'fields': [
            {
              'key': 'q_type',
              'kind': 'choice',
              'options': [
                {'label': '全部', 'value': ''},
                {'label': '作者', 'value': 'author'},
              ],
            },
            if (runtimeName.startsWith(_advancedSource))
              {'key': 'completed', 'kind': 'switch', 'label': '只看完结'},
          ],
        },
      };
    } else if (fnPath == 'getScopedJmFilterFixture') {
      reply = {
        'scheme': {
          'title': 'Scoped filter',
          'optionLayout': 'wrap',
          'fields': [
            {
              'key': 'category',
              'kind': 'choice',
              'label': 'Subcategory',
              'options': [
                for (final (type, label) in [
                  ('single', 'All in this category'),
                  ('single_japanese', 'Japanese subcategory'),
                ])
                  {
                    'value': type,
                    'label': label,
                    'result': {
                      'extern': {'type': type},
                    },
                  },
              ],
            },
          ],
        },
        'data': {
          'values': {'category': 'single'},
        },
      };
    } else if (fnPath == 'getScopedJmListFixture') {
      final page = arguments['page'] as int;
      reply = {
        'source': _copy,
        'data': {
          'paging': {'page': page, 'pages': 2, 'hasReachedMax': page == 2},
          'items': List.generate(20, (i) => _entry('scope-$page-$i')),
        },
      };
    } else if (fnPath == 'getCopyFilterFixture') {
      reply = await filterGate!.future;
    } else if (fnPath == 'getCopyListFixture') {
      final page = arguments['page'] as int;
      reply = {
        'source': _copy,
        'data': {
          'paging': {'page': page, 'pages': 2, 'hasReachedMax': page == 2},
          'items': List.generate(20, (index) => _entry('copy-$page-$index')),
        },
      };
    } else if (const {
      'getHomeRecommend',
      'getHomeNewest',
      'getHomeDiscover',
    }.contains(fnPath)) {
      await publicListGate?.future;
      final page = arguments['page'] as int;
      reply = {
        'source': _copy,
        'data': {
          'paging': {'page': page, 'pages': 2, 'hasReachedMax': page == 2},
          'items': [
            _entry('fantasy-$page', category: '奇幻'),
            if ((arguments['extern'] as Map?)?['theme'] != 'fantasy')
              _entry('adventure-$page', category: '冒险'),
          ],
        },
      };
    } else if (fnPath == 'getHomeDiscoverFilterBundle') {
      reply = {
        'source': _copy,
        'scheme': {
          'title': '筛选漫画',
          'fields': [
            {
              'key': 'theme',
              'kind': 'choice',
              'label': '分类',
              'options': [
                for (final (value, label) in [('', '全部'), ('fantasy', '奇幻')])
                  {
                    'label': label,
                    'value': value,
                    'result': {
                      'extern': {'theme': value},
                    },
                  },
              ],
            },
          ],
        },
        'data': {
          'values': {'theme': ''},
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
  void publish(SearchState state) => emit(state);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _OfflineApi api;
  final nativeChannels = <MethodChannel>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  testWidgets(
    'scoped remote filters wrap short choices and keep the footer reachable',
    (tester) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final scheme = PluginListFilterSchema.fromMap({
        'optionLayout': 'wrap',
        'fields': [
          {
            'key': 'category',
            'kind': 'choice',
            'label': '子分类',
            'options': [
              for (final label in ['全部', '汉化', '日语', '青年漫'])
                {'value': label, 'label': label},
            ],
          },
          {
            'key': 'order',
            'kind': 'choice',
            'label': '排序',
            'options': [
              for (var index = 0; index < 18; index++)
                {'value': '$index', 'label': 'Sort $index'},
            ],
          },
        ],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PluginListFilterDialog(
              scheme: scheme,
              initialSelections: const {'category': '全部', 'order': '0'},
              favoriteScope: 'fixture|category',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final first = find.byKey(const ValueKey('filter-option-category-0-全部'));
      final second = find.byKey(const ValueKey('filter-option-category-0-汉化'));
      expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('filter-favorite-category-汉化')))
            .width,
        greaterThanOrEqualTo(44),
      );
      expect(find.text(t.common.reset).hitTestable(), findsOneWidget);
      expect(find.text(t.common.apply).hitTestable(), findsOneWidget);
    },
  );

  testWidgets(
    'JM detailed rows show response metadata and readable update time',
    (tester) async {
      const time = '1794534613';
      final expected = formatComicRecordTimestamp(
        DateTime.fromMillisecondsSinceEpoch(
          1794534613000,
          isUtc: true,
        ).toIso8601String(),
      );
      final item = UnifiedComicListItem.fromJson({
        ..._entry('fixture-work'),
        'source': '6886291b-f524-441c-844b-c2efae9899a9',
        'updatedAt': time,
        'likesCount': 23,
        'metadata': [
          {
            'type': 'author',
            'name': 'Author',
            'value': ['Fixture author'],
          },
          {
            'type': 'tags',
            'name': 'Tags',
            'value': ['one', 'two', 'three', 'four'],
          },
        ],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SourceSearchDetailTile(entry: item)),
        ),
      );
      await tester.pump();
      expect(find.text(t.comicEntry.updatedAt(time: expected)), findsOneWidget);
      expect(find.text('Fixture author'), findsOneWidget);
      expect(find.text('one · two · three'), findsOneWidget);
      expect(find.text('23'), findsOneWidget);
      expect(
        api.calls.where((call) => call.function == 'getComicDetail'),
        isEmpty,
      );
      expect(formatComicRecordTimestamp('42', epochSeconds: true), isEmpty);
      expect(formatComicRecordTimestamp(time), time);
    },
  );
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    api = _OfflineApi();
    RustLib.initMock(api: api);
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api.calls.clear();
    api.publicListGate = null;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final args = call.arguments as Map;
        final channel = MethodChannel('${args['viewType']}.${args['id']}');
        nativeChannels.add(channel);
        messenger.setMockMethodCallHandler(channel, (_) async => null);
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in nativeChannels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    nativeChannels.clear();
  });

  testWidgets(
    'source landing iOS style and theme matrix keeps scope in its toolbar',
    (tester) async {
      for (final style in ['system', 'breeze']) {
        for (final brightness in Brightness.values) {
          final preference = ValueNotifier(style);
          addTearDown(preference.dispose);
          final settings = GlobalSettingCubit();
          addTearDown(settings.close);
          settings.updateState((s) => s.copyWith(searchHistory: ['原综合搜索记录']));
          await tester.pumpWidget(
            BlocProvider.value(
              value: settings,
              child: AppInterfaceStyleScope(
                style: preference,
                child: MaterialApp(
                  theme: ThemeData(brightness: brightness),
                  home: const SearchPage(
                    searchState: SearchStates(from: _copy),
                    aggregateMode: false,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(t.search.history), findsOneWidget);
          expect(find.text(t.search.noHistory), findsOneWidget);
          expect(find.text(t.search.legacyHistoryHint), findsNothing);
          expect(find.text(t.search.currentSourceHistory), findsNothing);
          final scope = find.byType(SourceSearchScopeControl);
          expect(scope, findsOneWidget);
          expect(
            find.descendant(
              of: find.byType(search_entry.SearchBar),
              matching: scope,
            ),
            findsOneWidget,
          );
          expect(
            tester.getCenter(scope).dy,
            closeTo(tester.getCenter(find.byType(SearchQueryField)).dy, .5),
          );
          final context = tester.element(scope);
          final cubit = context.read<SearchCubit>();
          final menu = tester.widget<SourceChoiceMenu<KeywordSearchScope>>(
            find.descendant(
              of: scope,
              matching: find.byType(SourceChoiceMenu<KeywordSearchScope>),
            ),
          );
          expect(menu.value, KeywordSearchScope.title);
          expect(menu.options.keys, KeywordSearchScope.values);
          menu.onChanged!(KeywordSearchScope.all);
          await tester.pumpAndSettle();
          expect(cubit.state.pluginExtern[keywordSearchScopeKey], 'all');
          expect(
            api.calls.where((call) => call.function.contains('SearchData')),
            isEmpty,
          );
          expect(settings.state.searchHistory, ['原综合搜索记录']);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  for (final embedded in [true, false]) {
    testWidgets(
      'filter pressed while loading opens once ready (embedded $embedded)',
      (tester) async {
        api.filterGate = Completer<Map<String, dynamic>>();
        final settings = GlobalSettingCubit();
        addTearDown(settings.close);
        const scene = ComicListScene(
          title: '筛选入口',
          from: _copy,
          filter: ComicListRequestConfig(fnPath: 'getCopyFilterFixture'),
          body: ComicListBodyConfig(
            request: ComicListRequestConfig(fnPath: 'getCopyListFixture'),
          ),
        );
        await tester.pumpWidget(
          BlocProvider.value(
            value: settings,
            child: MaterialApp(
              home: Scaffold(
                body: ComicListPage(scene: scene, embedded: embedded),
              ),
            ),
          ),
        );
        await tester.pump();
        tester
            .widget<SourceChromeIconButton>(
              find.byWidgetPredicate(
                (w) =>
                    w is SourceChromeIconButton &&
                    w.tooltip == t.comicList.filter,
              ),
            )
            .onPressed!();
        await tester.pump();
        expect(
          tester
              .widget<SourceChromeIconButton>(
                find.byWidgetPredicate(
                  (w) =>
                      w is SourceChromeIconButton &&
                      w.tooltip == t.comicList.filter,
                ),
              )
              .onPressed,
          isNull,
        );
        await tester.pump();
        expect(find.byType(PluginListFilterDialog), findsNothing);
        api.filterGate!.complete({
          'source': _copy,
          'scheme': {
            'title': '筛选漫画',
            'fields': [
              {
                'key': 'theme',
                'label': '分类',
                'kind': 'choice',
                'options': [
                  {
                    'value': '',
                    'label': '全部',
                    'result': {
                      'extern': {'theme': ''},
                    },
                  },
                  {
                    'value': 'fantasy',
                    'label': '奇幻',
                    'result': {
                      'extern': {'theme': 'fantasy'},
                    },
                  },
                ],
              },
            ],
          },
          'data': {
            'values': {'theme': ''},
          },
        });
        await tester.pumpAndSettle();
        expect(find.byType(PluginListFilterDialog), findsOneWidget);
        expect(
          api.calls.where((c) => c.function == 'getCopyFilterFixture'),
          hasLength(1),
        );
        await tester.tap(find.byTooltip(t.common.close));
        await tester.pumpAndSettle();
        expect(find.byType(PluginListFilterDialog), findsNothing);
        tester
            .widget<SourceChromeIconButton>(
              find.byWidgetPredicate(
                (w) =>
                    w is SourceChromeIconButton &&
                    w.tooltip == t.comicList.filter,
              ),
            )
            .onPressed!();
        await tester.pumpAndSettle();
        expect(find.byType(PluginListFilterDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  testWidgets(
    'scoped category retains its title and request through refresh and reset',
    (tester) async {
      final settings = GlobalSettingCubit();
      addTearDown(settings.close);
      const scene = ComicListScene(
        title: 'Single parent scope',
        from: _copy,
        body: ComicListBodyConfig(
          request: ComicListRequestConfig(
            fnPath: 'getScopedJmListFixture',
            extern: {'categoryScope': 'single', 'type': 'single'},
          ),
        ),
        filter: ComicListRequestConfig(
          fnPath: 'getScopedJmFilterFixture',
          extern: {'categoryScope': 'single', 'type': 'single'},
        ),
      );
      await tester.pumpWidget(
        BlocProvider.value(
          value: settings,
          child: const MaterialApp(home: ComicListPage(scene: scene)),
        ),
      );
      await tester.pumpAndSettle();
      final grid = find.byType(PluginComicGridSliver);
      final parent = tester.element(grid).read<ComicListCubit>();
      List<Map<String, dynamic>> requests() => api.calls
          .where((call) => call.function == 'getScopedJmListFixture')
          .map((call) => call.arguments)
          .toList();
      expect(requests().last['extern'], {
        'categoryScope': 'single',
        'type': 'single',
      });
      parent.applyFilterSelections({'category': 'doujin'});
      await tester.pumpAndSettle();
      expect(parent.state.filterSelections['category'], 'single');
      expect(requests().last['extern'], {
        'categoryScope': 'single',
        'type': 'single',
      });
      parent.applyFilterSelections({'category': 'single_japanese'});
      await tester.pumpAndSettle();
      final paged = tester.element(grid).read<PluginPagedComicListCubit>();
      await paged.loadMore();
      await tester.pumpAndSettle();
      await paged.refresh();
      await tester.pumpAndSettle();
      expect(requests().skip(1).map((args) => args['page']), [1, 2, 1]);
      expect(
        requests().skip(1).map((args) => args['extern']),
        everyElement({'categoryScope': 'single', 'type': 'single_japanese'}),
      );

      tester
          .widget<SourceChromeIconButton>(
            find.byWidgetPredicate(
              (w) =>
                  w is SourceChromeIconButton &&
                  w.tooltip == t.comicList.filter,
            ),
          )
          .onPressed!();
      await tester.pumpAndSettle();
      expect(find.text('Japanese subcategory'), findsWidgets);
      expect(find.text('doujin'), findsNothing);
      await tester.tap(find.text(t.common.reset));
      await tester.tap(find.text(t.common.apply));
      await tester.pumpAndSettle();
      expect(find.text('Single parent scope'), findsOneWidget);
      expect(requests().last['page'], 1);
      expect(requests().last['extern'], {
        'categoryScope': 'single',
        'type': 'single',
      });
      expect(tester.takeException(), isNull);
    },
  );

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
      final viewButton = tester.widget<SourceChromeIconButton>(
        find.descendant(
          of: find.byType(SourceListViewToggle),
          matching: find.byType(SourceChromeIconButton),
        ),
      );
      expect(viewButton.icon, Icons.view_list_outlined);
      expect(viewButton.symbol, 'list.bullet');
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

  for (final (fnPath, embedded) in [
    ('getHomeRecommend', true),
    ('getHomeNewest', false),
  ]) {
    testWidgets('Copy $fnPath filters loaded rows in its real toolbar', (
      tester,
    ) async {
      final settings = GlobalSettingCubit();
      addTearDown(settings.close);
      api.publicListGate = Completer<void>();
      tester.view.physicalSize = const Size(375, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final style = ValueNotifier(embedded ? 'breeze' : 'system');
      addTearDown(style.dispose);
      final scene = ComicListScene(
        title: '拷贝作品',
        from: _copy,
        body: ComicListBodyConfig(
          request: ComicListRequestConfig(fnPath: fnPath),
        ),
      );
      await tester.pumpWidget(
        BlocProvider.value(
          value: settings,
          child: AppInterfaceStyleScope(
            style: style,
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(1.5)),
                child: child!,
              ),
              home: Scaffold(
                body: ComicListPage(scene: scene, embedded: embedded),
              ),
            ),
          ),
        ),
      );
      final tools = find.byKey(
        const ValueKey('comic-list.public-loaded-tools'),
      );
      final filter = find.byKey(const ValueKey('source-loaded.filters'));
      final toggle = find.byType(SourceListViewToggle);
      await tester.pump();
      expect(filter, findsNothing);
      final toggleRight = tester.getRect(toggle).right;
      api.publicListGate!.complete();
      await tester.pumpAndSettle();
      expect(tester.getRect(toggle).right, toggleRight);
      expect(find.descendant(of: tools, matching: filter), findsOneWidget);
      expect(find.descendant(of: tools, matching: toggle), findsOneWidget);
      expect(tester.getSize(filter), const Size(44, 44));
      expect(
        tester.getCenter(filter).dy,
        closeTo(tester.getCenter(toggle).dy, .5),
      );
      expect(
        tester.getRect(filter).right,
        closeTo(tester.getRect(toggle).left, .5),
      );
      expect(find.byType(TextField), findsNothing);
      final grid = find.byType(PluginComicGridSliver);
      List<String> ids() => tester
          .widget<PluginComicGridSliver>(grid)
          .entries
          .map((row) => row.id)
          .toList();
      expect(ids(), ['fantasy-1', 'adventure-1']);
      tester.widget<SourceChromeIconButton>(filter).onPressed!();
      await tester.pumpAndSettle();
      expect(
        find.text(t.sourceShell.collectionLoadedCount(count: 2)),
        findsWidgets,
      );
      expect(find.text(t.bookshelf.facets.allRecords), findsNothing);
      await tester.tap(find.byKey(const ValueKey('shelf-option-category-奇幻')));
      await tester.tap(find.byKey(const ValueKey('shelf-focused-cancel')));
      await tester.pumpAndSettle();
      expect(ids(), ['fantasy-1', 'adventure-1']);
      tester.widget<SourceChromeIconButton>(filter).onPressed!();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('shelf-option-category-奇幻')));
      await tester.tap(find.byKey(const ValueKey('shelf-filter-apply')));
      await tester.pumpAndSettle();
      expect(ids(), ['fantasy-1']);
      expect(
        api.calls
            .where((call) => call.function == fnPath)
            .map((c) => c.arguments['page']),
        [1],
      );
      expect(
        api.calls.where((call) => call.function.endsWith('FilterBundle')),
        isEmpty,
      );
      final cubit = tester.element(grid).read<PluginPagedComicListCubit>();
      await cubit.loadMore();
      await tester.pumpAndSettle();
      expect(ids(), ['fantasy-1', 'fantasy-2']);
      expect(
        api.calls
            .where((call) => call.function == fnPath)
            .map((c) => c.arguments['page']),
        [1, 2],
      );
      expect(
        api.calls
            .where((call) => call.function == fnPath)
            .map((c) => c.arguments['extern']),
        everyElement(isEmpty),
      );
      final store = await SharedPreferences.getInstance();
      expect(
        store.getKeys().where(
          (key) => key.startsWith('breeze.source.results-filters.v1.'),
        ),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  testWidgets(
    'Copy Discover still sends declared theme changes and restarts page one',
    (tester) async {
      final settings = GlobalSettingCubit();
      addTearDown(settings.close);
      const scene = ComicListScene(
        title: '发现',
        from: _copy,
        body: ComicListBodyConfig(
          request: ComicListRequestConfig(fnPath: 'getHomeDiscover'),
        ),
        filter: ComicListRequestConfig(fnPath: 'getHomeDiscoverFilterBundle'),
      );
      await tester.pumpWidget(
        BlocProvider.value(
          value: settings,
          child: const MaterialApp(home: ComicListPage(scene: scene)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('source-loaded.filters')), findsNothing);
      final grid = find.byType(PluginComicGridSliver);
      await tester.element(grid).read<PluginPagedComicListCubit>().loadMore();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(t.comicList.filter));
      await tester.pumpAndSettle();
      expect(find.byType(PluginListFilterDialog), findsOneWidget);
      await tester.tap(find.text('奇幻').last);
      await tester.tap(find.widgetWithText(FilledButton, t.common.apply));
      await tester.pumpAndSettle();
      final calls = api.calls
          .where((call) => call.function == 'getHomeDiscover')
          .toList();
      expect(calls.map((call) => call.arguments['page']), [1, 2, 1]);
      expect(calls.last.arguments['extern'], {'theme': 'fantasy'});
      expect(
        tester.widget<PluginComicGridSliver>(grid).entries.map((row) => row.id),
        ['fantasy-1'],
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('search quick actions follow reverse scroll and reduced motion', (
    tester,
  ) async {
    const searchState = SearchStates(from: _copy, searchKeyword: 'fixture');
    const event = SearchEvent(searchStates: searchState);
    final search = SearchCubit(searchState);
    final settings = GlobalSettingCubit();
    final selection = StringSelectCubit();
    final reduced = ValueNotifier(false);
    final bloc = _SeededSearchBloc(
      SearchState(
        status: SearchStatus.success,
        currentPage: 1,
        totalPages: 1,
        hasReachedMax: true,
        searchEvent: event,
        comics: List.generate(
          24,
          (index) => ComicNumber(
            buildNumber: 1,
            comic: UnifiedComicListItem.fromJson(_entry('fixture-$index')),
          ),
        ),
      ),
    );
    addTearDown(search.close);
    addTearDown(settings.close);
    addTearDown(selection.close);
    addTearDown(reduced.dispose);
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: search),
          BlocProvider.value(value: settings),
          BlocProvider.value(value: selection),
          BlocProvider<SearchBloc>.value(value: bloc),
        ],
        child: MaterialApp(
          builder: (context, child) => ValueListenableBuilder(
            valueListenable: reduced,
            builder: (context, value, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: value),
              child: child!,
            ),
            child: child,
          ),
          home: const SearchResultPage(searchEvent: event),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final list = find.descendant(
      of: find.byType(SourceSearchDetailList),
      matching: find.byType(CustomScrollView),
    );
    final actions = find.byType(SpeedDial);
    final slide = find
        .ancestor(of: actions, matching: find.byType(SlideTransition))
        .first;
    double travel() => tester.widget<SlideTransition>(slide).position.value.dy;
    expect(
      tester.widget<SpeedDial>(actions).animationDuration,
      const Duration(milliseconds: 300),
    );
    final gesture = await tester.startGesture(tester.getCenter(list));
    await gesture.moveBy(const Offset(0, -24));
    await gesture.moveBy(const Offset(0, -96));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final outward = travel();
    expect(outward, inExclusiveRange(0.0, 2.0));
    await gesture.moveBy(const Offset(0, 26));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 48));
    expect(travel(), lessThan(outward));

    await gesture.moveBy(const Offset(0, -130));
    await tester.pump();
    reduced.value = true;
    await tester.pump();
    expect(travel(), 2);
    await gesture.moveBy(const Offset(0, 28));
    await tester.pump();
    expect(travel(), 0);
    await gesture.up();
    await tester.pumpAndSettle();
    final control = tester.widget<SpeedDial>(actions);
    expect(control.animationDuration, Duration.zero);
    expect(control.useRotationAnimation, isFalse);
    final scroll = tester.widget<CustomScrollView>(list).controller!;
    expect(scroll.offset, greaterThan(0));
    control.children.first.onTap!();
    await tester.pump();
    expect(scroll.offset, 0);
    expect(bloc.events, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Copy keyword results apply local facets without changing search or paging',
    (tester) async {
      const searchState = SearchStates(
        from: _copy,
        searchKeyword: '作品',
        pluginExtern: {keywordSearchScopeKey: 'all'},
      );
      const event = SearchEvent(searchStates: searchState);
      final search = SearchCubit(searchState);
      final settings = GlobalSettingCubit();
      final selection = StringSelectCubit();
      final first = SearchState(
        status: SearchStatus.success,
        currentPage: 1,
        totalPages: 2,
        searchEvent: event,
        comics: [
          ComicNumber(
            buildNumber: 1,
            comic: UnifiedComicListItem.fromJson(
              _entry('fantasy-1', category: '奇幻'),
            ),
          ),
          ComicNumber(
            buildNumber: 1,
            comic: UnifiedComicListItem.fromJson(
              _entry('adventure-1', category: '冒险'),
            ),
          ),
        ],
      );
      final bloc = _SeededSearchBloc(first);
      addTearDown(search.close);
      addTearDown(settings.close);
      addTearDown(selection.close);
      addTearDown(bloc.close);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: search),
            BlocProvider.value(value: settings),
            BlocProvider.value(value: selection),
            BlocProvider<SearchBloc>.value(value: bloc),
          ],
          child: const MaterialApp(home: SearchResultPage(searchEvent: event)),
        ),
      );
      await tester.pumpAndSettle();
      final filter = find.byKey(const ValueKey('source-loaded.filters'));
      final toggle = find.byType(SourceListViewToggle);
      expect(
        tester.getCenter(filter).dy,
        closeTo(tester.getCenter(toggle).dy, .5),
      );
      expect(
        tester.getRect(filter).right,
        closeTo(tester.getRect(toggle).left, .5),
      );
      await tester.tap(filter);
      await tester.pumpAndSettle();
      expect(find.text(t.videoLibrary.loadedResultScope), findsOneWidget);
      expect(find.text(t.bookshelf.facets.allRecords), findsNothing);
      await tester.tap(find.byKey(const ValueKey('shelf-option-category-奇幻')));
      await tester.tap(find.byKey(const ValueKey('shelf-filter-apply')));
      await tester.pumpAndSettle();
      final details = find.byType(SourceSearchDetailList);
      List<String> ids() => tester
          .widget<SourceSearchDetailList>(details)
          .entries
          .map((row) => row.id)
          .toList();
      expect(ids(), ['fantasy-1']);
      expect(bloc.events, isEmpty);
      expect(search.state, searchState);
      tester.widget<SourceSearchDetailList>(details).onLoadMore();
      expect(bloc.events.single.page, 2);
      expect(bloc.events.single.searchStates.pluginExtern, {
        keywordSearchScopeKey: 'all',
      });
      bloc.publish(
        first.copyWith(
          currentPage: 2,
          hasReachedMax: true,
          comics: [
            ...first.comics,
            ComicNumber(
              buildNumber: 2,
              comic: UnifiedComicListItem.fromJson(
                _entry('fantasy-2', category: '奇幻'),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(ids(), ['fantasy-1', 'fantasy-2']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('source search entry applies only its own advanced fields', (
    tester,
  ) async {
    const initial = SearchStates(
      from: '$_advancedSource-entry',
      searchKeyword: 'query',
      sortBy: 1,
      pluginExtern: {'q_type': 'author', 'sortBy': 1},
    );
    final criteria = SearchCubit(initial);
    addTearDown(criteria.close);
    await tester.pumpWidget(
      BlocProvider.value(
        value: criteria,
        child: const MaterialApp(
          home: Scaffold(body: search_entry.SearchBar(aggregateMode: false)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.byWidgetPredicate(
      (w) =>
          w is SourceChromeIconButton &&
          w.tooltip == t.search.advancedSearchOptions,
    );
    tester.widget<SourceChromeIconButton>(button).onPressed!();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, '只看完结'));
    criteria.update(
      initial.copyWith(sortBy: 3, pluginExtern: {'q_type': '', 'sortBy': 3}),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, t.common.apply));
    await tester.pumpAndSettle();
    expect(criteria.state.sortBy, 3);
    expect(criteria.state.pluginExtern, {
      'q_type': '',
      'sortBy': 3,
      'completed': true,
    });
  });

  testWidgets(
    'advanced search applies its own fields without reverting a newer scope',
    (tester) async {
      const initial = SearchStates(
        from: _advancedSource,
        searchKeyword: 'query',
        sortBy: 1,
        pluginExtern: {'q_type': 'author', 'sortBy': 1},
      );
      const event = SearchEvent(searchStates: initial);
      final criteria = SearchCubit(initial);
      final bloc = _SeededSearchBloc(
        const SearchState(
          status: SearchStatus.success,
          hasReachedMax: true,
          searchEvent: event,
        ),
      );
      final settings = GlobalSettingCubit();
      final selection = StringSelectCubit();
      addTearDown(criteria.close);
      addTearDown(bloc.close);
      addTearDown(settings.close);
      addTearDown(selection.close);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: criteria),
            BlocProvider<SearchBloc>.value(value: bloc),
            BlocProvider.value(value: settings),
            BlocProvider.value(value: selection),
          ],
          child: const MaterialApp(home: SearchResultPage(searchEvent: event)),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byWidgetPredicate(
        (w) =>
            w is SourceChromeIconButton &&
            w.tooltip == t.search.advancedSearchOptions,
      );
      tester.widget<SourceChromeIconButton>(button).onPressed!();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, '只看完结'));
      criteria.update(
        initial.copyWith(sortBy: 3, pluginExtern: {'q_type': '', 'sortBy': 3}),
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, t.common.apply));
      await tester.pumpAndSettle();
      expect(bloc.events.single.searchStates.sortBy, 3);
      expect(bloc.events.single.searchStates.pluginExtern, {
        'q_type': '',
        'sortBy': 3,
        'completed': true,
      });
      await tester.pumpWidget(const SizedBox.shrink());
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
      addTearDown(bloc.close);
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
      await Future.wait([search.close(), settings.close(), selection.close()]);
    },
  );
}
