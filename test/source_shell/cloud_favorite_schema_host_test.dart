import 'package:zephyr/page/comic_list/view/plugin_paged_comic_list_view.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/widget/keyword_scope_menu.dart';
import 'package:zephyr/page/comic_list/cubit/jm_collection_snapshots.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/source_shell/view/jm_collection_toolbar.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comic_list/models/comic_list_scene.dart';
import 'package:zephyr/page/comic_list/models/list_filter_bundle.dart';
import 'package:zephyr/page/comic_list/scene_filter/cloud_favorite_filter.dart';
import 'package:zephyr/page/comic_list/scene_filter/plugin_list_filter_schema.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/page/comic_list/view/comic_list_page.dart';
import 'package:zephyr/page/search_result/view/source_list_filter_bar.dart';
import 'package:zephyr/widgets/source_choice_menu.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import '../test_helper.dart';

const _source = 'b28da416-f2d4-4208-a85e-8b4c7c648e48';

class _Api extends RustLibApi {
  final requests = <Map<String, dynamic>>[];
  String key = 'order', requestKey = 'sort';
  List<String> values = ['dd', 'da'];
  bool folders = false;
  bool pagedComics = false;
  int accountRevision = 0;
  Completer<void>? cloudGate;
  int collectionSize = 0;
  bool remoteConditions = false;

  @override
  String crateApiQjsOpenccConvert({
    required String text,
    required String config,
  }) => text;

  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({
    required String name,
  }) async => true;
  @override
  Future<String> crateApiQjsQjsCurrentBundle({
    required String runtimeName,
  }) async => jsonEncode('fixture');
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
    final args = jsonDecode(argsJson) as Map<String, dynamic>;
    final Map<String, dynamic> reply;
    if (fnPath == 'init') {
      reply = {
        'data': {'ok': true},
      };
    } else if (fnPath == 'getCloudFilter') {
      reply = {
        'source': _source,
        'scheme': {
          'title': '收藏筛选',
          'fields': [
            if (remoteConditions)
              {
                'key': 'opaqueCondition',
                'kind': 'choice',
                'label': '源站条件',
                'options': [
                  {
                    'value': '',
                    'label': '不限',
                    'result': {
                      'extern': {'remoteFlag': ''},
                    },
                  },
                  {
                    'value': 'chosen',
                    'label': '真实选项',
                    'result': {
                      'extern': {'remoteFlag': 'chosen'},
                    },
                  },
                ],
              },
            if (folders)
              {
                'key': 'folderId',
                'label': '收藏夹',
                'kind': 'choice',
                'options': [
                  {
                    'label': '默认收藏夹',
                    'value': '',
                    'result': {
                      'extern': {'folderId': ''},
                    },
                  },
                  {
                    'label': 'Fixture Folder',
                    'value': '7',
                    'result': {
                      'extern': {'folderId': '7'},
                    },
                  },
                ],
              },
            {
              'key': key,
              'label': '排序',
              'kind': 'choice',
              'options': [
                for (final value in values)
                  {
                    'label': 'Sort $value',
                    'value': value,
                    'result': {
                      'extern': {requestKey: value},
                    },
                  },
              ],
            },
          ],
        },
        'data': {
          'values': {key: values.first, if (folders) 'folderId': ''},
        },
      };
    } else if (fnPath == 'getCloudFavoriteData') {
      requests.add(args);
      final revision = accountRevision;
      final page = args['page'] as int;
      final gate = page == 2 ? cloudGate : null;
      if (gate != null) {
        cloudGate = null;
        await gate.future;
      }
      final id = page == 1 ? 'first' : 'second';
      reply = {
        'source': _source,
        'data': {
          'items': collectionSize > 0
              ? List.generate(
                  ((collectionSize - (page - 1) * 20).clamp(0, 20)),
                  (index) => {
                    'source': _source,
                    'id': 'item-${(page - 1) * 20 + index}',
                    'title': '作品${(page - 1) * 20 + index}',
                    'cover': {
                      'id': '$index',
                      'url': '',
                      'path': '',
                      'extern': {},
                    },
                    'metadata': [
                      {
                        'type': 'tags',
                        'name': '标签',
                        'value': [page == 14 ? '尾页标签' : '前页标签'],
                      },
                    ],
                  },
                )
              : [
                  if (pagedComics)
                    {
                      'source': _source,
                      'id': id,
                      'title': revision > 0
                          ? '新账号作品'
                          : page == 1
                          ? '已读第一部'
                          : '待查目标',
                      'subtitle': '',
                      'finished': false,
                      'likesCount': 0,
                      'viewsCount': 0,
                      'updatedAt': '',
                      'cover': {'id': id, 'url': '', 'path': '', 'extern': {}},
                      'metadata': [
                        {
                          'type': 'category',
                          'name': '分类',
                          'value': [page == 1 ? '短篇' : '长篇'],
                        },
                        {
                          'type': 'tags',
                          'name': '标签',
                          'value': ['真实标签'],
                        },
                      ],
                      'raw': {},
                      'extern': {},
                    },
                ],
          'hasReachedMax': collectionSize > 0
              ? page * 20 >= collectionSize
              : !pagedComics || revision > 0 || page >= 2,
        },
      };
    } else {
      throw StateError('Unexpected fixture call $fnPath');
    }
    return Uint8List.fromList(utf8.encode(jsonEncode(reply)));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = _Api();
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    RustLib.initMock(api: api);
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    JmCollectionSnapshots.instance.clear();
    SharedPreferences.setMockInitialValues({});
    api.requests.clear();
    api.collectionSize = 0;
    api.pagedComics = false;
    api.accountRevision = 0;
    api.cloudGate = null;
    api.remoteConditions = false;
  });
  test(
    'remote choice conditions take precedence without guessing their semantic names',
    () {
      ListFilterBundle bundle(List<Map<String, dynamic>> fields) =>
          ListFilterBundle(
            scheme: PluginListFilterSchema.fromMap({'fields': fields}),
            defaultSelections: {},
          );
      final ordering = {
        'key': 'order',
        'kind': 'choice',
        'options': [
          {'value': 'new', 'label': '新'},
        ],
      };
      final folder = {
        'key': 'folderId',
        'kind': 'choice',
        'options': [
          {'value': '', 'label': '默认'},
        ],
      };
      expect(
        cloudFavoriteHasRemoteResultFilters(bundle([ordering, folder])),
        isFalse,
      );
      expect(
        cloudFavoriteHasRemoteResultFilters(
          bundle([
            ordering,
            {
              'key': 'third_party_condition',
              'label': '源站条件',
              'kind': 'choice',
              'options': [
                {
                  'value': 'x',
                  'label': '真实选项',
                  'result': {
                    'extern': {'opaque': 'x'},
                  },
                },
              ],
            },
          ]),
        ),
        isTrue,
      );
      expect(
        cloudFavoriteNeedsFilterDialog(
          bundle([
            ordering,
            {
              'key': 'third_party_condition',
              'kind': 'choice',
              'options': [
                {'value': 'x', 'label': '真实选项'},
              ],
            },
          ]),
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'standalone cloud route clears private records and rejects old reads across a session boundary',
    (tester) async {
      api.pagedComics = true;
      final older = Completer<void>();
      api.cloudGate = older;
      final settings = GlobalSettingCubit();
      addTearDown(settings.close);
      const scene = ComicListScene(
        title: '云端收藏',
        from: _source,
        body: ComicListBodyConfig(
          request: ComicListRequestConfig(
            fnPath: 'getCloudFavoriteData',
            extern: {'source': 'cloudFavorite'},
          ),
        ),
      );
      await tester.pumpWidget(
        BlocProvider.value(
          value: settings,
          child: const MaterialApp(home: ComicListPage(scene: scene)),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.text('已读第一部'), findsOneWidget);
      final search = find.byKey(const ValueKey('source-loaded.search'));
      await tester.tap(find.byKey(const ValueKey('jm-collection.search')));
      await tester.pump();
      await tester.enterText(search, '已读第一部');
      await tester.pump();
      expect(api.requests.last['page'], 2);
      final owner = pluginSessionWriteFence.beginSessionChange(_source);
      addTearDown(() => pluginSessionWriteFence.seal(_source, owner));
      api.accountRevision = 1;
      // Deliver Cubit's stream event before drawing the boundary's first frame.
      await tester.idle();
      await tester.pump();
      expect(find.text('已读第一部'), findsNothing);
      final beforeSeal = api.requests.length;
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        api.requests.length,
        beforeSeal,
        reason: 'No private request starts while credentials are changing',
      );
      pluginSessionWriteFence.seal(_source, owner);
      await tester.pumpAndSettle();
      expect(search, findsNothing, reason: 'The old account query must close');
      expect(find.text('新账号作品'), findsOneWidget);
      older.complete();
      await tester.pumpAndSettle();
      expect(find.text('新账号作品'), findsOneWidget);
      expect(find.text('待查目标'), findsNothing);
      expect(find.text('已读第一部'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an opaque remote condition keeps its own controls without duplicate local tools',
    (tester) async {
      api.remoteConditions = true;
      final settings = GlobalSettingCubit();
      addTearDown(settings.close);
      const scene = ComicListScene(
        title: '云端收藏',
        from: _source,
        filter: ComicListRequestConfig(fnPath: 'getCloudFilter'),
        body: ComicListBodyConfig(
          request: ComicListRequestConfig(
            fnPath: 'getCloudFavoriteData',
            extern: {'source': 'cloudFavorite'},
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
      expect(find.byKey(const ValueKey('source-loaded.search')), findsNothing);
      expect(find.byKey(const ValueKey('source-loaded.filters')), findsNothing);
      tester
          .widget<NativeVideoMenu>(
            find.byKey(const ValueKey('jm-collection.more')),
          )
          .onSelected('remote-filter');
      await tester.pumpAndSettle();
      await tester.tap(find.text('真实选项'));
      await tester.tap(find.text(t.common.apply));
      await tester.pumpAndSettle();
      expect((api.requests.last['extern'] as Map)['remoteFlag'], 'chosen');
      expect(api.requests.last['page'], 1);
      expect(find.byKey(const ValueKey('source-loaded.search')), findsNothing);
      tester
          .widget<NativeVideoMenu>(
            find.byKey(const ValueKey('jm-collection.more')),
          )
          .onSelected('remote-filter');
      await tester.pumpAndSettle();
      final owner = pluginSessionWriteFence.beginSessionChange(_source);
      addTearDown(() => pluginSessionWriteFence.seal(_source, owner));
      await tester.idle();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.text('真实选项'),
        findsNothing,
        reason: 'Old account schema options cannot remain in an open sheet',
      );
      pluginSessionWriteFence.seal(_source, owner);
      await tester.pumpAndSettle();
      expect((api.requests.last['extern'] as Map)['remoteFlag'], '');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cloud filter cancellation never sends draft values and reset applies schema defaults',
    (tester) async {
      api.remoteConditions = true;
      final settings = GlobalSettingCubit();
      addTearDown(settings.close);
      const scene = ComicListScene(
        title: '云端收藏',
        from: _source,
        filter: ComicListRequestConfig(fnPath: 'getCloudFilter'),
        body: ComicListBodyConfig(
          request: ComicListRequestConfig(
            fnPath: 'getCloudFavoriteData',
            extern: {'source': 'cloudFavorite'},
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
      final initialRequests = api.requests.length;
      final menu = tester.widget<NativeVideoMenu>(
        find.byKey(const ValueKey('jm-collection.more')),
      );

      menu.onSelected('remote-filter');
      await tester.pumpAndSettle();
      await tester.tap(find.text('真实选项'));
      await tester.pump();
      await tester.tap(find.byTooltip(t.common.close));
      await tester.pumpAndSettle();
      // Returning from a modal can perform a freshness probe with the
      // original criteria. The draft itself must never reach the plugin.
      expect(
        api.requests
            .skip(initialRequests)
            .map((request) => (request['extern'] as Map)['remoteFlag']),
        everyElement(''),
      );
      expect(
        tester
            .widget<PluginPagedComicListView>(
              find.byType(PluginPagedComicListView),
            )
            .externBuilder(1)['remoteFlag'],
        '',
      );

      tester
          .widget<NativeVideoMenu>(
            find.byKey(const ValueKey('jm-collection.more')),
          )
          .onSelected('remote-filter');
      await tester.pumpAndSettle();
      await tester.tap(find.text('真实选项'));
      await tester.pump();
      await tester.tap(find.text(t.common.apply));
      await tester.pumpAndSettle();
      expect((api.requests.last['extern'] as Map)['remoteFlag'], 'chosen');

      tester
          .widget<NativeVideoMenu>(
            find.byKey(const ValueKey('jm-collection.more')),
          )
          .onSelected('remote-filter');
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.common.reset));
      await tester.pump();
      await tester.tap(find.text(t.common.apply));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PluginPagedComicListView>(
              find.byType(PluginPagedComicListView),
            )
            .externBuilder(1)['remoteFlag'],
        '',
      );
      final beforeRefresh = api.requests.length;
      final refresh = tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show();
      await tester.pumpAndSettle();
      await refresh;
      expect(api.requests.length, greaterThan(beforeRefresh));
      expect((api.requests.last['extern'] as Map)['remoteFlag'], '');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'cloud host searches only loaded pages and continues without losing query or identity',
    (tester) async {
      api.pagedComics = true;
      final settings = GlobalSettingCubit();
      addTearDown(settings.close);
      const scene = ComicListScene(
        title: '云端收藏',
        from: _source,
        body: ComicListBodyConfig(
          request: ComicListRequestConfig(
            fnPath: 'getCloudFavoriteData',
            extern: {'source': 'cloudFavorite'},
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
      expect(api.requests, hasLength(1));
      await tester.tap(find.byKey(const ValueKey('jm-collection.search')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<KeywordScopeMenu>(
              find.byKey(const ValueKey('source-loaded.search-scope')),
            )
            .scope,
        KeywordSearchScope.title,
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('source-loaded.search')),
        '待查目标',
      );
      await tester.pumpAndSettle();
      expect(
        api.requests,
        hasLength(2),
        reason: 'Explicit search completes the remaining page',
      );
      expect(find.text(t.videoLibrary.results(count: 1)), findsOneWidget);
      expect(
        find.byKey(const ValueKey('source-loaded.continue')),
        findsNothing,
      );
      await tester.pumpAndSettle();
      expect(api.requests, hasLength(2));
      expect(api.requests.last['page'], 2);
      expect((api.requests.last['extern'] as Map)['source'], 'cloudFavorite');
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == '待查目标',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('source-loaded.search')),
            )
            .controller!
            .text,
        '待查目标',
      );
      expect(find.text('已读第一部'), findsNothing);
      expect(
        find.byKey(const ValueKey('source-loaded.continue')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    '267 cloud favorites index remaining pages only after explicit search',
    (tester) async {
      api.collectionSize = 267;
      final settings = GlobalSettingCubit();
      addTearDown(settings.close);
      const scene = ComicListScene(
        title: '云端收藏',
        from: _source,
        body: ComicListBodyConfig(
          request: ComicListRequestConfig(
            fnPath: 'getCloudFavoriteData',
            extern: {'source': 'cloudFavorite'},
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
      expect(api.requests.map((r) => r['page']), [1]);
      expect(
        find.byKey(const ValueKey('source-loaded.continue')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('jm-collection.search')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<KeywordScopeMenu>(
              find.byKey(const ValueKey('source-loaded.search-scope')),
            )
            .scope,
        KeywordSearchScope.title,
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('source-loaded.search')),
        '作品266',
      );
      await tester.pumpAndSettle();
      expect(
        api.requests.map((r) => r['page']),
        List.generate(14, (i) => i + 1),
      );
      expect(
        find.byWidgetPredicate((w) => w is Text && w.data == '作品266'),
        findsOneWidget,
      );
      expect(find.text(t.videoLibrary.results(count: 1)), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('source-loaded.filters')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('shelf-focused-options')),
          matching: find.text('尾页标签'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'JM collection keeps one compact toolbar and opens focused filters',
    (tester) async {
      api.collectionSize = 267;
      api.folders = true;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = GlobalSettingCubit();
      addTearDown(settings.close);
      const scene = ComicListScene(
        title: '云端收藏',
        from: _source,
        filter: ComicListRequestConfig(fnPath: 'getCloudFilter'),
        body: ComicListBodyConfig(
          request: ComicListRequestConfig(
            fnPath: 'getCloudFavoriteData',
            extern: {'source': 'cloudFavorite'},
          ),
        ),
      );
      await tester.pumpWidget(
        BlocProvider.value(
          value: settings,
          child: const MaterialApp(
            home: ComicListPage(scene: scene, jmCollection: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.requests.map((r) => r['page']), [1]);
      expect(find.text(scene.title), findsOneWidget);
      expect(
        tester
            .widget<SourceChoiceMenu<String>>(
              find.byKey(const ValueKey('cloud-favorite.folder')),
            )
            .label,
        '默认收藏夹',
      );
      expect(find.byKey(const ValueKey('source-loaded.search')), findsNothing);
      expect(
        find.byKey(const ValueKey('source-loaded.filters')),
        findsOneWidget,
      );
      expect(find.byType(SourceListFilterBar), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(JmCollectionNavigationActions),
        ),
        findsOneWidget,
      );
      final more = tester.widget<NativeVideoMenu>(
        find.byKey(const ValueKey('jm-collection.more')),
      );
      expect(more.label, isEmpty);
      expect(more.symbol, 'ellipsis');
      expect(more.selectionIndicator, isFalse);
      expect(
        tester
            .widget<SourceChoiceMenu<String>>(
              find.byKey(const ValueKey('cloud-favorite.folder')),
            )
            .selectionIndicator,
        isFalse,
      );
      final tools = tester.getRect(
        find.byKey(const ValueKey('source-loaded.filters')),
      );
      final appBar = tester.getRect(find.byType(AppBar));
      expect(tools.bottom - appBar.bottom, lessThanOrEqualTo(52));
      expect(tools.width, 44);
      expect(tools.right, 378);
      await tester.tap(find.byKey(const ValueKey('jm-collection.search')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<KeywordScopeMenu>(
              find.byKey(const ValueKey('source-loaded.search-scope')),
            )
            .scope,
        KeywordSearchScope.title,
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('source-loaded.search')),
        '作品266',
      );
      await tester.pumpAndSettle();
      expect(find.text(t.videoLibrary.results(count: 1)), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == '作品266',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('jm-collection.search')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('source-loaded.search')), findsNothing);
      expect(find.text(t.videoLibrary.results(count: 267)), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('source-loaded.filters')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('shelf-focused-options')),
          matching: find.text('尾页标签'),
        ),
        findsOneWidget,
      );
      expect(find.text('全部记录'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final kind in ['bika', 'jm', 'copy']) {
    testWidgets(
      '$kind cloud host preserves schema request key, folder draft and reset',
      (tester) async {
        api.key = kind == 'copy' ? 'ordering' : 'order';
        api.requestKey = kind == 'bika' ? 'sort' : api.key;
        api.values = switch (kind) {
          'bika' => ['dd', 'da'],
          'jm' => ['mr', 'mp'],
          _ => ['-datetime_modifier', 'datetime_modifier', '-popular'],
        };
        api.folders = kind == 'jm';
        final settings = GlobalSettingCubit();
        addTearDown(settings.close);
        const scene = ComicListScene(
          title: '云端收藏',
          from: _source,
          filter: ComicListRequestConfig(fnPath: 'getCloudFilter'),
          body: ComicListBodyConfig(
            request: ComicListRequestConfig(
              fnPath: 'getCloudFavoriteData',
              extern: {'source': 'cloudFavorite'},
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
        var navigation = tester.widget<JmCollectionNavigationActions>(
          find.byType(JmCollectionNavigationActions),
        );
        expect(
          navigation.options.keys.where((key) => key.startsWith('sort.')),
          api.values.map((value) => 'sort.$value'),
        );
        expect(navigation.selected, 'sort.${api.values.first}');
        navigation.onSelected('sort.${api.values.last}');
        await tester.pumpAndSettle();
        expect(api.requests.last['page'], 1);
        expect(
          (api.requests.last['extern'] as Map)[api.requestKey],
          api.values.last,
        );
        expect((api.requests.last['extern'] as Map)['source'], 'cloudFavorite');
        expect(find.text('排序 · Sort ${api.values.last}'), findsNothing);
        if (kind == 'jm') {
          final folder = tester.widget<SourceChoiceMenu<String>>(
            find.byKey(const ValueKey('cloud-favorite.folder')),
          );
          folder.onChanged!('7');
          await tester.pumpAndSettle();
          expect((api.requests.last['extern'] as Map)['folderId'], '7');
          expect((api.requests.last['extern'] as Map)['order'], 'mp');
          final resetFolder = tester.widget<SourceChoiceMenu<String>>(
            find.byKey(const ValueKey('cloud-favorite.folder')),
          );
          resetFolder.onChanged!('');
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<PluginPagedComicListView>(
                  find.byType(PluginPagedComicListView),
                )
                .externBuilder(1)['folderId'],
            '',
          );
          // Returning to an already-read folder may restore its valid snapshot.
          // An explicit refresh must still call that exact official scope.
          final folderRefresh = tester
              .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
              .show();
          await tester.pumpAndSettle();
          await folderRefresh;
          expect((api.requests.last['extern'] as Map)['folderId'], '');
        }
        navigation = tester.widget<JmCollectionNavigationActions>(
          find.byType(JmCollectionNavigationActions),
        );
        navigation.onSelected('sort.${api.values.first}');
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<JmCollectionNavigationActions>(
                find.byType(JmCollectionNavigationActions),
              )
              .selected,
          'sort.${api.values.first}',
        );
        expect(
          tester
              .widget<PluginPagedComicListView>(
                find.byType(PluginPagedComicListView),
              )
              .externBuilder(1)[api.requestKey],
          api.values.first,
        );
        final sortRefresh = tester
            .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
            .show();
        await tester.pumpAndSettle();
        await sortRefresh;
        expect(
          (api.requests.last['extern'] as Map)[api.requestKey],
          api.values.first,
        );
        expect(api.requests.last['page'], 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
