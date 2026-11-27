import 'dart:convert';
import 'dart:async';
import 'package:cbor/simple.dart' as cbor;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:auto_route/auto_route.dart';
import 'package:zephyr/config/router/router.gr.dart'
    show
        ComicInfoRoute,
        ComicInfoRouteArgs,
        SearchResultRoute,
        SearchResultRouteArgs;
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_navigation_bar.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/page/comic_list/scene_filter/plugin_list_filter_dialog.dart';
import 'package:zephyr/page/comic_list/scene_filter/plugin_list_filter_schema.dart';
import 'package:zephyr/widgets/comic_entry/comic_record_time.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/cubit/string_select.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show eventBus;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/comic_list/cubit/plugin_paged_comic_list_cubit.dart';
import 'package:zephyr/page/comic_list/cubit/comic_list_cubit.dart';
import 'package:zephyr/page/comic_list/models/comic_list_scene.dart';
import 'package:zephyr/page/comic_list/view/comic_list_page.dart';
import 'package:zephyr/page/comic_list/view/plugin_comic_grid_sliver.dart';
import 'package:zephyr/page/comic_list/view/plugin_paged_comic_list_view.dart'
    show PluginPagedComicListView;
import 'package:zephyr/page/comic_info/widgets/cover.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/method/search_scope_preferences.dart';
import 'package:zephyr/page/search/method/search_history_entries.dart';
import 'package:zephyr/page/search/widget/search_input_dialog.dart';
import 'package:zephyr/page/search/widget/search_field_decoration.dart';
import 'package:zephyr/page/search/widget/advanced_search_dialog.dart';
import 'package:zephyr/page/search_result/bloc/search_bloc.dart';
import 'package:zephyr/page/search_result/method/get_plugin_result.dart';
import 'package:zephyr/page/search_result/models/bloc_state.dart';
import 'package:zephyr/page/search_result/models/comic_number.dart';
import 'package:zephyr/page/search_result/view/search_result_page.dart';
import 'package:zephyr/page/search_result/view/source_list_categories.dart';
import 'package:zephyr/page/search_result/view/source_search_detail_list.dart';
import 'package:zephyr/page/source_shell/source_list_presentation.dart';
import 'package:zephyr/page/source_shell/source_list_view_toggle.dart';
import 'package:zephyr/page/source_shell/source_experience_preferences.dart';
import 'package:zephyr/page/source_shell/bika_content_block_rules.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/page/source_shell/source_list_block_preferences.dart';
import 'package:zephyr/page/source_shell/models/source_shell_section.dart';
import 'package:zephyr/page/source_shell/view/source_shell_page.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';
import 'package:zephyr/page/search/view/search_page.dart';
import 'package:zephyr/page/search/widget/search_bar.dart' as search_entry;
import 'package:zephyr/page/search_result/view/source_search_scope_control.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'package:zephyr/widgets/comic_simplify_entry/cover.dart';
import 'package:zephyr/widgets/picture_bloc/bloc/picture_bloc.dart';
import 'package:zephyr/widgets/picture_bloc/models/picture_info.dart';
import 'package:zephyr/widgets/toast.dart' show ToastEvent;

import '../test_helper.dart';

const _copy = 'b28da416-f2d4-4208-a85e-8b4c7c648e48';
const _jm = '6886291b-f524-441c-844b-c2efae9899a9';
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

/// FRB's mock entrypoint replaces QJS calls without loading an FFI library.
class _OfflineApi extends RustLibApi {
  final calls = <({String function, Map<String, dynamic> arguments})>[];
  int? bikaReportedPage;
  Completer<Map<String, dynamic>>? filterGate;
  Completer<void>? publicListGate;
  final imageRequests = <String>[];
  Uint8List? coverBytes;
  int coverFailureStatus = 503;

  @override
  String crateApiSimpleEncodePath({required String path}) =>
      Uri.encodeComponent(path);

  @override
  String crateApiQjsOpenccConvert({
    required String text,
    required String config,
  }) => text;

  @override
  Future<Uint8List> crateApiQjsQjsFetchImage({
    required String runtimeName,
    required String taskGroupKey,
    required bool isOnce,
    String? bundleJs,
    String? bundleUrl,
    required String fnPath,
    required String argsJson,
  }) async {
    final url = jsonDecode(argsJson)['url'] as String;
    imageRequests.add(url);
    final bytes = coverBytes;
    return Uint8List.fromList(
      cbor.cbor.encode({
        'version': 1,
        'bytes': bytes ?? Uint8List(0),
        'statusCode': bytes == null ? coverFailureStatus : 200,
        'responseBodyLength': bytes?.length,
        'error': bytes == null ? 'HTTP $coverFailureStatus' : null,
      }),
    );
  }

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
            if (runtimeName.startsWith(bikaPlusSourceId)) ...[
              {
                'key': 'categories',
                'kind': 'multiChoice',
                'options': [
                  for (final value in ['短篇', '全彩', '同人'])
                    {'label': value, 'value': value},
                ],
              },
              {
                'key': 'blockedCategories',
                'kind': 'multiChoice',
                'options': [],
              },
              {
                'key': 'sortBy',
                'kind': 'choice',
                'options': [
                  {'label': '最新', 'value': 1},
                  {'label': '最早', 'value': 2},
                ],
              },
            ],
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
    } else if (fnPath == 'searchComic' &&
        runtimeName.startsWith(bikaPlusSourceId)) {
      reply = {
        'source': bikaPlusSourceId,
        'extern': {
          'blockedCategories': {'全彩': true},
        },
        'data': {
          'paging': {
            'page': bikaReportedPage ?? arguments['page'],
            'pages': 1,
            'hasReachedMax': true,
          },
          'items': [_entry('bika-search-work')],
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
    } else if (fnPath == 'getLatestData') {
      reply = {
        'source': _jm,
        'data': {
          'page': arguments['page'],
          'hasReachedMax': true,
          'items': [_entry('最新作品')..['source'] = _jm],
        },
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
            'semantic': 'theme',
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
      expect(find.text('one · two · three · four'), findsOneWidget);
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
    await PluginRegistryService.I.init();
    await PluginRegistryService.I.upsert(
      PluginInfo(
        uuid: bikaPlusSourceId,
        version: '0.2.1',
        originScript: '',
        insertedAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        isEnabled: true,
        isDeleted: false,
        lastLoadSuccess: true,
        debug: false,
        getInfoJson: jsonEncode({
          'breezeExperience': {
            'searchQuickCategories': ['短篇', '全彩', '同人', 'CG杂图'],
            'publicSearchFields': 1,
          },
        }),
      ),
    );
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api.calls.clear();
    api.bikaReportedPage = null;
    api.coverBytes = null;
    api.coverFailureStatus = 503;
    api.imageRequests.clear();
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

  test(
    'Bika search sends only current filters and ignores legacy block echoes',
    () async {
      final result = await getPluginSearchResult(
        const SearchEvent(
          searchStates: SearchStates(
            from: bikaPlusSourceId,
            searchKeyword: 'query',
            pluginExtern: {
              'categories': ['短篇'],
              'sortBy': 2,
              'blockedCategories': ['同人'],
              'settingsBlockedCategories': ['同人'],
            },
          ),
        ),
        BlocState(),
      );
      final request = api.calls.singleWhere(
        (call) => call.function == 'searchComic',
      );
      expect(request.arguments['extern'], {
        'categories': ['短篇'],
        'sortBy': 2,
      });
      expect(result.pluginExtern['blockedCategories'], ['同人']);
      expect(
        result.pluginExtern.containsKey('settingsBlockedCategories'),
        isFalse,
      );
      expect(result.comics.single.comic.id, 'bika-search-work');
      expect(result.pagesCount, 1);
      expect(result.comics.single.sourcePage, 1);
      final clean = await getPluginSearchResult(
        const SearchEvent(searchStates: SearchStates(from: bikaPlusSourceId)),
        BlocState(),
      );
      expect(clean.pluginExtern.containsKey('blockedCategories'), isFalse);
    },
  );

  test(
    'wrong page response cannot replace previously accepted results',
    () async {
      const event = SearchEvent(
        searchStates: SearchStates(
          from: bikaPlusSourceId,
          searchKeyword: 'query',
        ),
      );
      final first = await getPluginSearchResult(event, BlocState());
      api.bikaReportedPage = 3;
      await expectLater(
        getPluginSearchResult(event.copyWith(page: 4), first),
        throwsFormatException,
      );
      expect(
        api.calls
            .where((call) => call.function == 'searchComic')
            .map((call) => call.arguments['page']),
        [1, 4],
      );
      expect(first.pagesCount, 1);
      expect(first.comics.single.sourcePage, 1);
    },
  );

  for (final style in ['breeze', 'system']) {
    testWidgets(
      'Bika random has one shuffle and keeps the current batch while loading ($style)',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 700);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        const query = SearchStates(
          from: bikaPlusSourceId,
          pluginExtern: {'url': 'https://fixture.test/comics/random'},
        );
        const event = SearchEvent(searchStates: query);
        final criteria = SearchCubit(query);
        final settings = GlobalSettingCubit();
        final interface = ValueNotifier(style);
        final original = SearchState(
          status: SearchStatus.success,
          hasReachedMax: true,
          currentPage: 1,
          totalPages: 1,
          searchEvent: event,
          comics: [
            ComicNumber(
              buildNumber: 1,
              comic: UnifiedComicListItem.fromJson(_entry('first batch')),
            ),
          ],
        );
        final bloc = _SeededSearchBloc(original);
        addTearDown(criteria.close);
        addTearDown(settings.close);
        addTearDown(bloc.close);
        addTearDown(interface.dispose);
        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: criteria),
              BlocProvider<SearchBloc>.value(value: bloc),
              BlocProvider.value(value: settings),
            ],
            child: AppInterfaceStyleScope(
              style: interface,
              child: MaterialApp(
                theme: ThemeData.from(
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: style == 'system' ? Colors.purple : Colors.teal,
                    brightness: style == 'system'
                        ? Brightness.dark
                        : Brightness.light,
                  ),
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.8)),
                  child: child!,
                ),
                home: const SearchResultPage(searchEvent: event),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final shuffle = find.byKey(const ValueKey('search-result.shuffle'));
        expect(shuffle.hitTestable(), findsOneWidget);
        expect(tester.getSize(shuffle).height, greaterThanOrEqualTo(44));
        expect(find.byType(SourceListViewToggle), findsOneWidget);
        expect(
          find.byKey(const ValueKey('search-result.page-progress')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('search-result.filter')),
          findsNothing,
        );
        final quick = find.byKey(
          const ValueKey('search-result.quick-categories'),
        );
        expect(quick, findsOneWidget);
        expect(
          tester.getBottomLeft(quick).dy,
          lessThanOrEqualTo(
            tester
                .getTopLeft(find.byKey(const ValueKey('search-result.toolbar')))
                .dy,
          ),
        );
        expect(find.byType(SpeedDial), findsNothing);
        expect(
          api.calls.where((call) => call.function == 'getAdvancedSearchScheme'),
          isEmpty,
        );
        expect(find.text('first batch'), findsOneWidget);
        await tester.tap(shuffle);
        await tester.tap(shuffle);
        expect(bloc.events, [event]);
        bloc.publish(original.copyWith(status: SearchStatus.initial));
        await tester.pump();
        expect(find.text('first batch'), findsOneWidget);
        expect(tester.widget<TextButton>(shuffle).onPressed, isNull);
        bloc.publish(original.copyWith(comics: []));
        await tester.pumpAndSettle();
        expect(find.text(t.searchResult.noVisibleRandomWorks), findsOneWidget);
        expect(tester.widget<TextButton>(shuffle).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.android,
      }),
    );
  }

  testWidgets(
    'Bika random covers retry quietly and can recover in the same batch slot',
    (tester) async {
      const statusChannel = MethodChannel(
        'dev.fluttercommunity.plus/connectivity_status',
      );
      messenger.setMockMethodCallHandler(statusChannel, (_) async => null);
      addTearDown(
        () => messenger.setMockMethodCallHandler(statusChannel, null),
      );
      final visibility = VisibilityDetectorController.instance;
      final previousInterval = visibility.updateInterval;
      visibility.updateInterval = Duration.zero;
      addTearDown(() => visibility.updateInterval = previousInterval);
      const query = SearchStates(
        from: bikaPlusSourceId,
        pluginExtern: {'url': 'https://fixture.test/comics/random'},
      );
      const event = SearchEvent(searchStates: query);
      final criteria = SearchCubit(query);
      final settings = GlobalSettingCubit();
      const url = 'https://fixture.test/random-recovered.png';
      final original = SearchState(
        status: SearchStatus.success,
        hasReachedMax: true,
        currentPage: 1,
        totalPages: 1,
        searchEvent: event,
        comics: [
          ComicNumber(
            buildNumber: 1,
            comic: UnifiedComicListItem.fromJson({
              ..._entry('same work'),
              'source': bikaPlusSourceId,
              'cover': {
                'id': 'same work',
                'url': url,
                'path': 'random-recovered.png',
              },
            }),
          ),
        ],
      );
      final bloc = _SeededSearchBloc(original);
      final notices = <ToastEvent>[];
      final subscription = eventBus.on<ToastEvent>().listen(notices.add);
      addTearDown(criteria.close);
      addTearDown(settings.close);
      addTearDown(bloc.close);
      addTearDown(subscription.cancel);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: criteria),
            BlocProvider<SearchBloc>.value(value: bloc),
            BlocProvider.value(value: settings),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const SearchResultPage(searchEvent: event),
          ),
        ),
      );
      final cover = find.byType(CoverWidget);
      PictureBloc picture() => tester
          .element(
            find.descendant(
              of: cover,
              matching: find.byType(BlocBuilder<PictureBloc, PictureLoadState>),
            ),
          )
          .read<PictureBloc>();
      Future<void> waitFor(bool Function() ready) async {
        for (var i = 0; i < 100 && !ready(); i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        expect(ready(), isTrue);
      }

      await waitFor(
        () => api.imageRequests.length == 1 && !picture().isLoading,
      );
      await tester.pump(const Duration(milliseconds: 850));
      await waitFor(
        () => api.imageRequests.length == 2 && !picture().isLoading,
      );
      await tester.pump(const Duration(milliseconds: 2450));
      await waitFor(() => picture().state.status == PictureLoadStatus.failure);
      expect(api.imageRequests, [url, url, url]);
      expect(
        find.descendant(of: cover, matching: find.byIcon(Icons.refresh)),
        findsNothing,
      );
      expect(
        find.descendant(of: cover, matching: find.byIcon(Icons.image)),
        findsOneWidget,
      );
      final coverSize = tester.getSize(cover);

      await tester.tap(find.byKey(const ValueKey('search-result.shuffle')));
      bloc.publish(original.copyWith(status: SearchStatus.initial));
      await tester.pump();
      bloc.publish(
        original.copyWith(status: SearchStatus.failure, result: '连接哔咔超时'),
      );
      await tester.pumpAndSettle();
      expect(find.text(t.sourceShell.bikaConnectionNotice), findsOneWidget);
      expect(notices, isEmpty);
      await tester.tap(find.text(t.common.close));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('search-result.shuffle')));
      bloc.publish(original.copyWith(status: SearchStatus.initial));
      await tester.pump();
      bloc.publish(
        original.copyWith(status: SearchStatus.failure, result: '连接哔咔超时'),
      );
      await tester.pumpAndSettle();
      expect(find.text(t.sourceShell.bikaConnectionNotice), findsOneWidget);
      expect(notices, isEmpty);
      await tester.tap(find.text(t.common.retry));
      await tester.pumpAndSettle();
      api.coverBytes = (await rootBundle.load(
        'asset/image/assets/default_cover.png',
      )).buffer.asUint8List();
      bloc.publish(original.copyWith(status: SearchStatus.initial));
      await tester.pump();
      bloc.publish(
        original.copyWith(searchEvent: SearchEvent(searchStates: query)),
      );
      await waitFor(() => picture().state.status == PictureLoadStatus.success);
      expect(api.imageRequests, [url, url, url, url]);
      expect(tester.getSize(cover), coverSize);
      expect(find.text(t.sourceShell.bikaConnectionNotice), findsNothing);
      await tester.tap(find.byType(SourceListViewToggle));
      await tester.pumpAndSettle();
      await waitFor(() => picture().state.status == PictureLoadStatus.success);
      expect(api.imageRequests, [url, url, url, url]);
      expect(
        find.descendant(of: cover, matching: find.byIcon(Icons.refresh)),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Copy missing covers preserve card navigation and detail layout',
    (tester) async {
      final visibility = VisibilityDetectorController.instance;
      final previousInterval = visibility.updateInterval;
      visibility.updateInterval = Duration.zero;
      addTearDown(() => visibility.updateInterval = previousInterval);
      api.coverFailureStatus = 404;
      const url = 'https://fixture.test/copy-list-cover.png';
      const detailUrl = 'https://fixture.test/copy-detail-cover.png';
      final entry = UnifiedComicListItem.fromJson({
        ..._entry('copy-missing-cover'),
        'cover': {'id': 'missing', 'url': url, 'path': 'copy-list-cover.png'},
      });
      final router = RootStackRouter.build(
        routes: [
          NamedRouteDef(
            name: 'CopyCoverList',
            path: '/',
            initial: true,
            builder: (_, _) =>
                Scaffold(body: SourceSearchDetailTile(entry: entry)),
          ),
          NamedRouteDef(
            name: ComicInfoRoute.name,
            path: '/work',
            builder: (_, data) {
              final args = data.argsAs<ComicInfoRouteArgs>();
              expect(args.comicId, entry.id);
              expect(args.from, _copy);
              return const Scaffold(
                body: Cover(
                  pictureInfo: PictureInfo(
                    from: _copy,
                    url: detailUrl,
                    path: 'copy-detail-cover.png',
                    cartoonId: 'copy-missing-cover',
                    pictureType: PictureType.cover,
                  ),
                ),
              );
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router.config()),
      );

      Future<void> verifyPlaceholder(Finder owner) async {
        final builder = find.descendant(
          of: owner,
          matching: find.byType(BlocBuilder<PictureBloc, PictureLoadState>),
        );
        for (var i = 0; i < 100; i++) {
          if (builder.evaluate().isNotEmpty &&
              tester.element(builder).read<PictureBloc>().state.status ==
                  PictureLoadStatus.failure) {
            break;
          }
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(
          tester.element(builder).read<PictureBloc>().state.status,
          PictureLoadStatus.failure,
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: owner, matching: find.byIcon(Icons.image)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: owner, matching: find.byIcon(Icons.refresh)),
          findsNothing,
        );
      }

      final listCover = find.byType(CoverWidget);
      await verifyPlaceholder(listCover);
      await tester.tap(listCover);
      await tester.pump();
      final detailCover = find.byType(Cover);
      await verifyPlaceholder(detailCover);
      expect(tester.getSize(detailCover), const Size(135, 180));
      expect(api.imageRequests, [url, detailUrl]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Bika colored chips restore works locally without changing settings',
    (tester) async {
      const statusChannel = MethodChannel(
        'dev.fluttercommunity.plus/connectivity_status',
      );
      messenger.setMockMethodCallHandler(statusChannel, (_) async => null);
      addTearDown(
        () => messenger.setMockMethodCallHandler(statusChannel, null),
      );
      await savePluginConfigValue(
        bikaPlusSourceId,
        'search.blockedCategories',
        ['全彩'],
      );
      addTearDown(
        () => savePluginConfigValue(
          bikaPlusSourceId,
          'search.blockedCategories',
          [],
        ),
      );
      const initial = SearchStates(
        from: bikaPlusSourceId,
        searchKeyword: 'query',
      );
      const event = SearchEvent(searchStates: initial);
      final criteria = SearchCubit(initial);
      final bloc = _SeededSearchBloc(
        SearchState(
          status: SearchStatus.success,
          searchEvent: event,
          currentPage: 2,
          totalPages: 39,
          hasReachedMax: true,
          comics: [
            for (final (id, category) in [
              ('short work', '短篇'),
              ('colored work', '全彩'),
              ('other work', '同人'),
            ])
              ComicNumber(
                buildNumber: 2,
                sourcePage: 2,
                comic: UnifiedComicListItem.fromJson({
                  ..._entry(id, category: category),
                  'source': bikaPlusSourceId,
                  'metadata': [
                    {
                      'type': 'categories',
                      'name': '分类',
                      'value': [category],
                    },
                    {
                      'type': 'author',
                      'name': '作者',
                      'value': [id == 'short work' ? 'Author A' : 'Author B'],
                    },
                    {
                      'type': 'tags',
                      'name': '标签',
                      'value': [
                        'Fixture tag',
                        if (id == 'short work') ...['标签 A', ' 标签 A '],
                      ],
                    },
                    if (id == 'short work')
                      {
                        'type': 'team',
                        'name': '汉化组',
                        'value': ['Fixture team'],
                      },
                  ],
                }),
              ),
          ],
        ),
      );
      final settings = GlobalSettingCubit();
      addTearDown(criteria.close);
      addTearDown(bloc.close);
      addTearDown(settings.close);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: criteria),
            BlocProvider<SearchBloc>.value(value: bloc),
            BlocProvider.value(value: settings),
          ],
          child: const MaterialApp(home: SearchResultPage(searchEvent: event)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        bloc.events,
        isEmpty,
        reason: 'initial setup must not restart search',
      );
      final blockNotice = find.byKey(
        const ValueKey('search-result.category-blocks-applied'),
      );
      expect(blockNotice, findsNothing);
      final filter = find.byKey(const ValueKey('search-result.filter'));
      expect(filter, findsNothing);
      expect(find.byKey(const ValueKey('search-result.scope')), findsNothing);
      expect(
        find.byKey(const ValueKey('search-result.bika-categories')),
        findsNothing,
      );
      final quick = find.byKey(
        const ValueKey('search-result.quick-categories'),
      );
      final short = find.byKey(const ValueKey('category-短篇'));
      final locked = find.byKey(const ValueKey('category-全彩'));
      expect(
        tester.getBottomLeft(quick).dy,
        lessThanOrEqualTo(
          tester
              .getTopLeft(find.byKey(const ValueKey('search-result.toolbar')))
              .dy,
        ),
      );
      expect(
        tester.widget<ActionChip>(short).backgroundColor,
        isNot(Colors.transparent),
      );
      expect(tester.widget<ActionChip>(locked).onPressed, isNull);
      expect(find.text('short work'), findsOneWidget);
      expect(find.text('colored work'), findsNothing);
      await tester.tap(short);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('short work'), findsNothing);
      expect(find.text('other work'), findsOneWidget);
      expect(
        find.text(t.searchResult.pageProgress(page: 2, pages: 39)),
        findsOneWidget,
      );
      expect(bloc.events, isEmpty);
      await SourceListBlockPreferences.flush();
      expect(
        await SourceListBlockPreferences.read(
          '$bikaPlusSourceId|search|categoryBlock',
        ),
        {'短篇'},
      );
      await tester.tap(short);
      await tester.pumpAndSettle();
      expect(find.text('short work'), findsOneWidget);
      expect(bloc.events, isEmpty);

      await tester.runAsync(() async {
        await savePluginConfigValue(
          bikaPlusSourceId,
          BikaContentBlockField.title.configKey,
          ['other'],
        );
        await Future<void>.delayed(const Duration(milliseconds: 25));
      });
      await tester.pumpAndSettle();
      expect(find.text('other work'), findsNothing);
      expect(bloc.events, isEmpty);
      await tester.runAsync(() async {
        await savePluginConfigValue(
          bikaPlusSourceId,
          BikaContentBlockField.title.configKey,
          [],
        );
        await Future<void>.delayed(const Duration(milliseconds: 25));
      });
      await tester.pumpAndSettle();
      expect(find.text('other work'), findsOneWidget);

      final tagKey = BikaContentBlockField.tag.configKey;
      addTearDown(() => savePluginConfigValue(bikaPlusSourceId, tagKey, []));
      await tester.runAsync(() async {
        await savePluginConfigValue(bikaPlusSourceId, tagKey, ['标签 A']);
        await Future<void>.delayed(const Duration(milliseconds: 25));
      });
      await tester.pumpAndSettle();
      expect(find.text('short work'), findsNothing);
      expect(find.text('other work'), findsOneWidget);
      expect(
        find.text(t.searchResult.pageProgress(page: 2, pages: 39)),
        findsOneWidget,
      );
      expect(bloc.events, isEmpty);
      await tester.runAsync(() async {
        await savePluginConfigValue(bikaPlusSourceId, tagKey, []);
        await Future<void>.delayed(const Duration(milliseconds: 25));
      });
      await tester.pumpAndSettle();
      expect(find.text('short work'), findsOneWidget);

      tester
          .widget<NativeVideoMenu>(
            find.byKey(const ValueKey('search-result.sort')),
          )
          .onSelected('2');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 350));
      expect(bloc.events.last.searchStates.sortBy, 2);
      tester
          .widget<NativeVideoMenu>(
            find.byKey(const ValueKey('search-result.sort')),
          )
          .onSelected('1');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 350));
      expect(bloc.events, hasLength(2));
      expect(bloc.events.last.searchStates.sortBy, initial.sortBy);
      expect(bloc.events.last.searchStates.pluginExtern['categories'], isNull);
      expect(
        loadPluginConfigValue<List>(
          bikaPlusSourceId,
          'search.blockedCategories',
          fallback: [],
        ),
        ['全彩'],
      );
      expect(blockNotice, findsNothing);
      await tester.runAsync(() async {
        await savePluginConfigValue(
          bikaPlusSourceId,
          'search.blockedCategories',
          [],
        );
        await Future<void>.delayed(const Duration(milliseconds: 25));
      });
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 350));
      expect(bloc.events, hasLength(3));
      expect(find.text('colored work'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await SourceListBlockPreferences.flush();
    },
  );

  testWidgets(
    'a selected comic destination scrolls its own list without refetching',
    (tester) async {
      final settings = GlobalSettingCubit();
      final style = ValueNotifier('breeze');
      addTearDown(settings.close);
      addTearDown(style.dispose);
      SourceShellSection destination(String id) => SourceShellSection(
        id: id,
        title: id,
        scene: ComicListScene(
          title: id,
          from: _copy,
          body: ComicListBodyConfig(
            request: ComicListRequestConfig(
              fnPath: 'getCopyListFixture',
              core: {'genre': id},
            ),
          ),
        ),
      );
      await tester.pumpWidget(
        BlocProvider.value(
          value: settings,
          child: AppInterfaceStyleScope(
            style: style,
            child: MaterialApp(
              home: SourceShellPage(
                source: _copy,
                sourceName: 'Source fixture',
                sections: [destination('First'), destination('Second')],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final grid = find.byType(PluginComicGridSliver);
      ScrollPosition position() =>
          tester.widget<PluginComicGridSliver>(grid).controller!.position;
      Future<void> select(String title) async {
        await tester.tap(
          find.descendant(
            of: find.byType(BreezeNavigationBar),
            matching: find.text(title),
          ),
        );
        await tester.pumpAndSettle();
      }

      position().jumpTo(250);
      await tester.pumpAndSettle();
      expect(position().pixels, 250);

      await select('Second');
      position().jumpTo(310);
      await tester.pumpAndSettle();
      expect(position().pixels, 310);
      await select('First');
      expect(position().pixels, 250);
      final calls = api.calls.length;

      final listContext = tester.element(grid);
      unawaited(
        showDialog<void>(
          context: listContext,
          builder: (_) => const AlertDialog(title: Text('Modal')),
        ),
      );
      await tester.pumpAndSettle();
      tester
          .widget<VideoNativeNavigation>(find.byType(VideoNativeNavigation))
          .onTap!(0);
      await tester.pumpAndSettle();
      expect(position().pixels, 250);
      Navigator.of(listContext).pop();
      await tester.pumpAndSettle();

      await select('First');
      expect(position().pixels, position().minScrollExtent);
      await select('First');
      expect(position().pixels, position().minScrollExtent);
      position().jumpTo(250);
      await tester.pumpAndSettle();
      await messenger.handlePlatformMessage(
        SystemChannels.statusBar.name,
        SystemChannels.statusBar.codec.encodeMethodCall(
          const MethodCall('handleScrollToTop'),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(
        position().pixels,
        defaultTargetPlatform == TargetPlatform.iOS ? 0 : 250,
      );
      await select('Second');
      expect(position().pixels, 310);
      expect(api.calls.length, calls);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'source landing keeps native editing and history without a moved scope control',
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
          expect(find.byType(SourceSearchScopeControl), findsNothing);
          final input = find.byType(SearchQueryField);
          final back = find.byKey(const ValueKey('comic-search.back'));
          final submit = find.byType(SearchFieldSubmitButton);
          final center = tester.getCenter(input).dy;
          expect(tester.getCenter(back).dy, closeTo(center, .5));
          expect(tester.getCenter(submit).dy, closeTo(center, .5));
          expect(tester.widget<SourceChromeIconButton>(back).bare, isFalse);
          expect(find.byType(SourceMoreButton), findsNothing);
          expect(find.descendant(of: input, matching: submit), findsOneWidget);
          final submitButton = find.descendant(
            of: submit,
            matching: find.byType(IconButton),
          );
          expect(tester.widget<IconButton>(submitButton).onPressed, isNull);
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

  testWidgets(
    'dedicated Bika comic search dismisses keyboard without clearing the draft',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = GlobalSettingCubit();
      addTearDown(settings.close);
      for (final style in ['system', 'breeze']) {
        final preference = ValueNotifier(style);
        addTearDown(preference.dispose);
        await tester.pumpWidget(
          BlocProvider.value(
            value: settings,
            child: AppInterfaceStyleScope(
              style: preference,
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
                home: const SearchPage(
                  searchState: SearchStates(from: bikaPlusSourceId),
                  aggregateMode: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final field = find.byType(SearchQueryField);
        final scope = find.byType(SourceSearchScopeControl);
        final options = find.byKey(const ValueKey('comic-search.options-row'));
        final submit = find.descendant(
          of: field,
          matching: find.byType(SearchFieldSubmitButton),
        );
        final back = find.byKey(const ValueKey('comic-search.back'));
        expect(scope, findsNothing);
        expect(submit, findsOneWidget);
        expect(options, findsNothing);
        expect(tester.widget<SourceChromeIconButton>(back).bare, isFalse);
        final nativeBack = find.descendant(
          of: back,
          matching: find.byType(UiKitView),
        );
        expect(nativeBack, style == 'system' ? findsOneWidget : findsNothing);
        final center = tester.getCenter(field).dy;
        expect(tester.getCenter(back).dy, closeTo(center, .5));
        expect(tester.getCenter(submit).dy, closeTo(center, .5));
        await tester.enterText(find.byType(TextField), '现有草稿');
        await tester.pump();
        final submitButton = find.descendant(
          of: submit,
          matching: find.byType(IconButton),
        );
        expect(tester.widget<IconButton>(submitButton).onPressed, isNotNull);
        final editor = find.byType(EditableText);
        expect(tester.widget<EditableText>(editor).focusNode.hasFocus, isTrue);
        await tester.tap(find.text(t.search.history));
        await tester.pumpAndSettle();
        expect(tester.widget<EditableText>(editor).focusNode.hasFocus, isFalse);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '现有草稿',
        );
        expect(find.text(t.search.history), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'dedicated comic Search applies a default and preserves result and history scopes',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await SearchScopePreferences.save(
        source: _copy,
        surface: SearchScopePreferences.comic,
        value: KeywordSearchScope.title.name,
        supported: sourceKeywordSearchScopes(_copy).map((scope) => scope.name),
      );
      final settings = GlobalSettingCubit();
      settings.updateState(
        (current) => current.copyWith(
          searchHistory: SearchHistoryEntries.add(
            current.searchHistory,
            '历史作者',
            scope: _copy,
            keywordScope: KeywordSearchScope.author,
          ),
        ),
      );
      SearchResultRouteArgs? submitted;
      final router = RootStackRouter.build(
        routes: [
          NamedRouteDef(
            name: 'FixtureComicSearch',
            path: '/',
            initial: true,
            builder: (_, _) => const SearchPage(
              searchState: SearchStates(from: _copy),
              aggregateMode: false,
            ),
          ),
          NamedRouteDef(
            name: SearchResultRoute.name,
            path: '/matches',
            builder: (_, data) {
              submitted = data.argsAs<SearchResultRouteArgs>();
              return const Scaffold(body: Text('Opened comic results'));
            },
          ),
        ],
      );
      addTearDown(settings.close);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        BlocProvider.value(
          value: settings,
          child: MaterialApp.router(
            routerConfig: router.config(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(3)),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SourceSearchScopeControl), findsNothing);
      await tester.enterText(find.byType(TextField), '  独立搜索  ');
      await tester.pumpAndSettle();
      final submit = find.byType(SearchFieldSubmitButton);
      expect(
        find.descendant(of: find.byType(SearchQueryField), matching: submit),
        findsOneWidget,
      );
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Opened comic results'), findsOneWidget);
      expect(submitted?.searchEvent.searchStates.searchKeyword, '独立搜索');
      expect(
        submitted?.searchEvent.searchStates.pluginExtern[keywordSearchScopeKey],
        KeywordSearchScope.title.name,
      );
      router.pop();
      await tester.pumpAndSettle();
      await SearchScopePreferences.save(
        source: _copy,
        surface: SearchScopePreferences.comic,
        value: KeywordSearchScope.team.name,
        supported: sourceKeywordSearchScopes(_copy).map((scope) => scope.name),
      );
      await tester.enterText(find.byType(TextField), '更改关键词');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(submitted?.searchEvent.searchStates.searchKeyword, '更改关键词');
      expect(
        submitted?.searchEvent.searchStates.pluginExtern[keywordSearchScopeKey],
        KeywordSearchScope.title.name,
      );
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('历史作者'));
      await tester.pumpAndSettle();
      expect(submitted?.searchEvent.searchStates.searchKeyword, '历史作者');
      expect(
        submitted?.searchEvent.searchStates.pluginExtern[keywordSearchScopeKey],
        KeywordSearchScope.author.name,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
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
      final view = find.descendant(
        of: find.byType(SourceListViewToggle),
        matching: find.byType(SourceChromeIconButton),
      );
      expect(
        tester.widget<SourceChromeIconButton>(view).icon,
        Icons.view_list_outlined,
      );
      expect(tester.widget<SourceChromeIconButton>(view).symbol, 'list.bullet');
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
      expect(
        tester.widget<SourceChromeIconButton>(view).icon,
        Icons.grid_view_outlined,
      );
      expect(
        tester.widget<SourceChromeIconButton>(view).symbol,
        'square.grid.2x2',
      );
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
      expect(tester.getSize(filter).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(filter).height, greaterThanOrEqualTo(44));
      expect(
        tester.getCenter(filter).dy,
        closeTo(tester.getCenter(toggle).dy, .5),
      );
      expect(
        tester.getRect(toggle).left - tester.getRect(filter).right,
        closeTo(8, .5),
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
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(t.sourceShell.collectionLoadedCount(count: 4)),
        ),
        findsNothing,
      );
      expect(find.text(t.bookshelf.facets.allRecords), findsNothing);
      expect(
        find.byKey(const ValueKey('shelf-filter-more-metadata')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('shelf-option-category-奇幻')));
      await tester.tap(find.byKey(const ValueKey('shelf-focused-cancel')));
      await tester.pumpAndSettle();
      expect(ids(), ['fantasy-1', 'adventure-1', 'fantasy-2', 'adventure-2']);
      tester.widget<SourceChromeIconButton>(filter).onPressed!();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('shelf-option-category-奇幻')));
      await tester.tap(find.byKey(const ValueKey('shelf-filter-apply')));
      await tester.pumpAndSettle();
      expect(ids(), ['fantasy-1', 'fantasy-2']);
      expect(
        api.calls
            .where((call) => call.function == fnPath)
            .map((c) => c.arguments['page']),
        [1, 2],
      );
      expect(
        api.calls.where((call) => call.function.endsWith('FilterBundle')),
        isEmpty,
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
    'plugin shell and embedded result toolbar share safe-area edges',
    (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const scene = ComicListScene(
        title: '拷贝作品',
        from: _copy,
        body: ComicListBodyConfig(
          request: ComicListRequestConfig(fnPath: 'getHomeRecommend'),
        ),
      );

      for (final style in ['system', 'breeze']) {
        api.publicListGate = Completer<void>();
        final preference = ValueNotifier(style);
        addTearDown(preference.dispose);
        final settings = GlobalSettingCubit();
        addTearDown(settings.close);
        await tester.pumpWidget(
          BlocProvider.value(
            value: settings,
            child: AppInterfaceStyleScope(
              style: preference,
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    padding: const EdgeInsets.only(left: 24, right: 8),
                    viewPadding: const EdgeInsets.only(left: 24, right: 8),
                  ),
                  child: child!,
                ),
                home: const SourceShellPage(
                  source: _copy,
                  sourceName: '拷贝',
                  sections: [
                    SourceShellSection(
                      id: 'recommend',
                      title: '推荐',
                      scene: scene,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        api.publicListGate!.complete();
        await tester.pumpAndSettle();

        final appBar = tester.getRect(find.byType(AppBar));
        final more = tester.getRect(find.byType(SourceMoreButton));
        final viewToggle = tester.getRect(find.byType(SourceListViewToggle));
        expect(more.right, closeTo(appBar.right - 8 - 16, .5));
        expect(viewToggle.right, closeTo(more.right, .5));
        expect(viewToggle.center.dx, closeTo(more.center.dx, .5));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('embedded JM latest keeps the page and view tools together', (
    tester,
  ) async {
    final settings = GlobalSettingCubit();
    addTearDown(settings.close);
    const scene = ComicListScene(
      title: '最新',
      from: _jm,
      body: ComicListBodyConfig(
        request: ComicListRequestConfig(fnPath: 'getLatestData'),
      ),
    );
    await tester.pumpWidget(
      BlocProvider.value(
        value: settings,
        child: const MaterialApp(
          home: Scaffold(
            body: ComicListPage(
              scene: scene,
              embedded: true,
              titleInParent: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final progress = find.byKey(const ValueKey('plugin-list.page-progress'));
    final view = find.byType(SourceListViewToggle);
    expect(find.text('最新作品'), findsWidgets);
    expect(progress, findsOneWidget);
    expect(view, findsOneWidget);
    expect(
      tester.getCenter(progress).dy,
      closeTo(tester.getCenter(view).dy, 1),
    );
    expect(
      tester.widget<Text>(progress).data,
      t.searchResult.pageOnly(page: 1),
    );
    expect(tester.takeException(), isNull);
  });

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

  testWidgets(
    'browsing page follows visible rows and can jump to a read page',
    (tester) async {
      tester.view.physicalSize = const Size(440, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const query = SearchStates(
        from: bikaPlusSourceId,
        searchKeyword: 'query',
      );
      const event = SearchEvent(searchStates: query);
      final criteria = SearchCubit(query);
      final settings = GlobalSettingCubit();
      final initial = SearchState(
        status: SearchStatus.success,
        searchEvent: event,
        currentPage: 1,
        totalPages: 259,
        comics: [
          for (var index = 0; index < 3; index++)
            ComicNumber(
              buildNumber: 1,
              sourcePage: 1,
              comic: UnifiedComicListItem.fromJson(_entry('first-$index')),
            ),
        ],
      );
      final bloc = _SeededSearchBloc(initial);
      addTearDown(criteria.close);
      addTearDown(bloc.close);
      addTearDown(settings.close);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: criteria),
            BlocProvider<SearchBloc>.value(value: bloc),
            BlocProvider.value(value: settings),
          ],
          child: const MaterialApp(home: SearchResultPage(searchEvent: event)),
        ),
      );
      await tester.pumpAndSettle();
      bloc.publish(
        initial.copyWith(
          currentPage: 14,
          comics: [
            ...initial.comics,
            for (final page in [12, 14])
              for (var index = 0; index < 12; index++)
                ComicNumber(
                  buildNumber: page,
                  sourcePage: page,
                  comic: UnifiedComicListItem.fromJson(
                    _entry('page-$page-$index'),
                  ),
                ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      Finder header(int page) =>
          find.text(t.searchResult.pageProgress(page: page, pages: 259));
      expect(header(1), findsOneWidget);
      expect(header(14), findsNothing);
      final marker = find.byKey(const ValueKey(('result-page-divider', 3)));
      final list = tester.widget<SourceSearchDetailList>(
        find.byType(SourceSearchDetailList),
      );
      final scroller = find.byType(CustomScrollView);
      double revealOffset(Finder target) =>
          tester.getTopLeft(target).dy - tester.getTopLeft(scroller).dy;
      final pageControl = find.byKey(
        const ValueKey('search-result.page-progress'),
      );
      final pageBefore = tester.getRect(pageControl);
      list.controller!.jumpTo(revealOffset(marker));
      await tester.pumpAndSettle();
      expect(header(12), findsOneWidget);
      expect(tester.getRect(pageControl), pageBefore);
      expect(find.text(t.searchResult.pageOnly(page: 12)), findsNothing);

      await tester.tap(find.text(t.discover.gridLayout));
      await tester.pumpAndSettle();
      final grid = tester.widget<PluginComicGridSliver>(
        find.byType(PluginComicGridSliver),
      );
      expect(header(1), findsOneWidget);
      grid.controller!.jumpTo(
        revealOffset(find.byKey(const ValueKey('page-12-0'))),
      );
      await tester.pumpAndSettle();
      expect(header(12), findsOneWidget);
      expect(tester.getRect(pageControl), pageBefore);
      grid.controller!.jumpTo(0);
      await tester.pumpAndSettle();
      expect(header(1), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('search-result.page-progress')),
      );
      await tester.pumpAndSettle();
      final input = find.byType(TextField);
      expect(tester.widget<TextField>(input).controller!.text, '1');
      await tester.enterText(input, '14');
      await tester.tap(find.text(t.common.ok));
      await tester.pumpAndSettle();
      expect(bloc.events.last.status, SearchStatus.initial);
      expect(bloc.events.last.page, 14);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Bika cloud favorites divide reported pages after filtering', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 940);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pages = <int>[];
    final settings = GlobalSettingCubit();
    addTearDown(settings.close);
    Map<String, dynamic> entry(String id, {bool blocked = false}) => {
      ..._entry(id),
      'source': bikaPlusSourceId,
      if (blocked)
        'metadata': [
          ..._entry(id)['metadata'] as List,
          {
            'type': 'categories',
            'name': '分类',
            'value': ['Blocked fixture'],
          },
        ],
    };
    await tester.pumpWidget(
      BlocProvider.value(
        value: settings,
        child: MaterialApp(
          home: Scaffold(
            body: PluginPagedComicListView(
              pluginId: bikaPlusSourceId,
              fnPath: 'getFavoriteData',
              coreBuilder: (page) => {'page': page},
              externBuilder: (_) => {'source': 'cloudFavorite', 'sort': 'dd'},
              cloudFavorite: true,
              detailedView: true,
              blockedCategories: const {'Blocked fixture'},
              localResultTools: false,
              requestPage: (_, _, core, extern) async {
                final page = core['page'] as int;
                pages.add(page);
                expect(extern['sort'], 'dd');
                return {
                  'source': bikaPlusSourceId,
                  'data': {
                    'paging': {'page': page, 'pages': 2, 'total': 3},
                    'items': [
                      if (page == 1) ...[
                        entry('First official page'),
                        entry('Hidden official page item', blocked: true),
                      ] else
                        entry('Second official page'),
                    ],
                  },
                };
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final results = find.byType(SourceSearchDetailList);
    final cubit = tester.element(results).read<PluginPagedComicListCubit>();
    expect(tester.widget<SourceSearchDetailList>(results).pageBreaks, isEmpty);
    await cubit.loadMore();
    await tester.pumpAndSettle();
    final displayed = tester.widget<SourceSearchDetailList>(results);
    expect(pages, [1, 2]);
    expect(cubit.state.knownTotal, 3);
    expect(displayed.entries.map((row) => row.id), [
      'First official page',
      'Second official page',
    ]);
    expect(displayed.pageBreaks, {1});
    expect(
      find.byKey(const ValueKey(('result-page-divider', 1))),
      findsOneWidget,
    );
    expect(find.textContaining('第2页'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Bika skips blocked rows and continues by source page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 940);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final titleKey = BikaContentBlockField.title.configKey;
    final tagKey = BikaContentBlockField.tag.configKey;
    await savePluginConfigValue(bikaPlusSourceId, titleKey, ['hidden phrase']);
    await savePluginConfigValue(bikaPlusSourceId, tagKey, ['muted tag']);
    addTearDown(() async {
      await savePluginConfigValue(bikaPlusSourceId, titleKey, []);
      await savePluginConfigValue(bikaPlusSourceId, tagKey, []);
    });

    const query = SearchStates(from: bikaPlusSourceId, searchKeyword: 'works');
    const event = SearchEvent(searchStates: query);
    ComicNumber work(String name, int page, {String? tag}) {
      final item = _entry(name);
      return ComicNumber(
        buildNumber: page,
        sourcePage: page,
        comic: UnifiedComicListItem.fromJson({
          ...item,
          'source': bikaPlusSourceId,
          'metadata': [
            ...item['metadata'] as List,
            if (tag != null)
              {
                'type': 'tags',
                'name': '标签',
                'value': [tag],
              },
          ],
        }),
      );
    }

    final initial = SearchState(
      status: SearchStatus.success,
      currentPage: 10,
      totalPages: 259,
      searchEvent: event.copyWith(page: 10),
      comics: [work('Contains Hidden Phrase', 10)],
    );
    final bloc = _SeededSearchBloc(initial);
    final criteria = SearchCubit(query);
    final settings = GlobalSettingCubit();
    addTearDown(criteria.close);
    addTearDown(bloc.close);
    addTearDown(settings.close);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: criteria),
          BlocProvider<SearchBloc>.value(value: bloc),
          BlocProvider.value(value: settings),
        ],
        child: const MaterialApp(home: SearchResultPage(searchEvent: event)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Contains Hidden Phrase'), findsNothing);
    expect(find.byKey(const ValueKey('search-result.filter')), findsNothing);
    expect(bloc.events.map((event) => event.page), [11]);

    Future<void> accept(int page, ComicNumber entry) async {
      bloc.publish(bloc.state.copyWith(status: SearchStatus.loadingMore));
      await tester.pump();
      bloc.publish(
        bloc.state.copyWith(
          status: SearchStatus.success,
          currentPage: page,
          comics: [...bloc.state.comics, entry],
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    await accept(11, work('Exact tag hit', 11, tag: ' Muted Tag '));
    expect(bloc.events.map((event) => event.page), [11, 12]);
    await accept(12, work('Different tag', 12, tag: 'Muted Tag Extra'));
    await accept(13, work('No tag supplied', 13));
    final shown = tester.widget<SourceSearchDetailList>(
      find.byType(SourceSearchDetailList),
    );
    expect(shown.entries.map((entry) => entry.id), [
      'Different tag',
      'No tag supplied',
    ]);
    expect(shown.pageBreaks, {1});
    expect(
      find.text(t.searchResult.pageProgress(page: 12, pages: 259)),
      findsOneWidget,
    );
    expect(find.text(t.oldHome.loadMore), findsNothing);
    expect(bloc.events.map((event) => event.page).take(4), [11, 12, 13, 14]);

    bloc.publish(bloc.state.copyWith(status: SearchStatus.getMoreFailure));
    await tester.pumpAndSettle();
    expect(find.text('Different tag'), findsOneWidget);
    expect(find.text(t.oldHome.loadMoreFailed), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('search-result.page-progress')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '20');
    await tester.tap(find.text(t.common.ok));
    await tester.pumpAndSettle();
    expect(bloc.events.last.status, SearchStatus.initial);
    expect(bloc.events.last.page, 20);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a short first search page automatically requests page two once',
    (tester) async {
      tester.view.physicalSize = const Size(440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const searchState = SearchStates(from: _copy, searchKeyword: 'fixture');
      const event = SearchEvent(searchStates: searchState);
      final search = SearchCubit(searchState);
      final settings = GlobalSettingCubit();
      final selection = StringSelectCubit();
      final firstPage = SearchState(
        status: SearchStatus.success,
        searchEvent: event,
        currentPage: 1,
        totalPages: 10,
        comics: [
          for (var index = 0; index < 4; index++)
            ComicNumber(
              buildNumber: 1,
              comic: UnifiedComicListItem.fromJson(_entry('short-$index')),
            ),
        ],
      );
      final bloc = _SeededSearchBloc(firstPage);
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
      final list = tester.widget<SourceSearchDetailList>(
        find.byType(SourceSearchDetailList),
      );
      expect(list.controller!.position.maxScrollExtent, 0);
      expect(bloc.events, [
        event.copyWith(page: 2, status: SearchStatus.loadingMore),
      ]);

      bloc.publish(firstPage.copyWith(currentPage: 2));
      await tester.pumpAndSettle();
      expect(bloc.events, hasLength(1));
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
    'Copy keyword facets update quietly while preserving the search',
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
        currentPage: 2,
        totalPages: 3,
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
      const safePadding = EdgeInsets.only(left: 24, right: 8);
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
          child: MaterialApp(
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(padding: safePadding, viewPadding: safePadding),
                child: child!,
              );
            },
            home: const SearchResultPage(searchEvent: event),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(bloc.events, isEmpty);
      final filter = find.byKey(const ValueKey('source-loaded.filters'));
      final toggle = find.byType(SourceListViewToggle);
      final appBar = tester.getRect(find.byType(AppBar));
      expect(find.byType(SourceMoreButton), findsNothing);
      final filterBounds = tester.getRect(filter);
      final toggleBounds = tester.getRect(toggle);
      final extent = CollectionToolbarMetrics.actionExtentOf(
        tester.element(filter),
      );
      expect(filterBounds.center.dy, closeTo(toggleBounds.center.dy, .5));
      expect(filterBounds.size, Size.square(extent));
      expect(toggleBounds.size, Size.square(extent));
      expect(toggleBounds.left, closeTo(filterBounds.right, .5));
      expect(
        toggleBounds.right,
        closeTo(
          appBar.right -
              safePadding.right -
              CollectionToolbarMetrics.sourceContentInset,
          .5,
        ),
      );
      await tester.tap(filter);
      await tester.pumpAndSettle();
      expect(find.text(t.videoLibrary.loadedResultScope), findsNothing);
      expect(find.text(t.bookshelf.facets.allRecords), findsNothing);
      expect(
        find.byKey(const ValueKey('shelf-filter-more-metadata')),
        findsNothing,
      );
      expect(bloc.events, [
        event.copyWith(page: 3, status: SearchStatus.loadingMore),
      ]);
      await tester.tap(find.byKey(const ValueKey('shelf-option-category-奇幻')));
      bloc.publish(first.copyWith(status: SearchStatus.loadingMore));
      await tester.pump();
      bloc.publish(
        first.copyWith(
          currentPage: 3,
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
      await tester.tap(find.byKey(const ValueKey('shelf-filter-apply')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SourceSearchDetailList>(find.byType(SourceSearchDetailList))
            .entries
            .map((row) => row.id),
        ['fantasy-1', 'fantasy-2'],
      );
      expect(bloc.events, hasLength(1));
      expect(search.state, searchState);
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
    final completed = find.widgetWithText(SwitchListTile, '只看完结');
    expect(completed, findsOneWidget);
    expect(tester.widget<SwitchListTile>(completed).value, isFalse);
    await tester.tap(completed);
    await tester.pump();
    expect(tester.widget<SwitchListTile>(completed).value, isTrue);
    criteria.update(
      initial.copyWith(sortBy: 3, pluginExtern: {'q_type': '', 'sortBy': 3}),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, t.common.apply));
    await tester.pumpAndSettle();
    expect(find.byType(PluginAdvancedSearchDialog), findsNothing);
    expect(criteria.state.pluginExtern['completed'], isTrue);
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
      await tester.tap(find.byKey(const ValueKey('search-result.filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.search.advancedSearchOptions));
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
