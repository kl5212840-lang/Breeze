import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/models/source_shell_section.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/source_shell/view/source_video_content.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_favorites.dart';
import 'package:zephyr/page/video/api_video_history.dart';
import 'package:zephyr/page/video/api_video_library_page.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/page/video/video_search_page.dart';
import 'package:zephyr/page/video/video_search_history.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/widget/keyword_scope_menu.dart';
import 'package:zephyr/page/search/widget/search_input_dialog.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

import '../test_helper.dart';
import '../ui_preview_helper.dart';

const _bika = 'e9f18928-3ba8-4d86-a12e-b53a62f47933';

const _movieHome = 'https://movie.fixture/';
const _animeHome = 'https://animate.fixture/';

Map<String, dynamic> _row(
  String id, {
  String title = '作品',
  String home = _movieHome,
}) => {
  'id': id,
  'title': '$title$id',
  'detailUrl': '${home}videos/$id',
  'genres': '科幻',
  'year': '2026',
};

Map<String, dynamic> _page({int extraItems = 0, String home = _movieHome}) => {
  'data': {
    'items': [
      _row('one', home: home),
      _row('two', home: home),
      for (var index = 0; index < extraItems; index++)
        _row('extra-$index', home: home),
    ],
    'categories': [],
    'page': 1,
    'pageCount': 1,
    'total': 2 + extraItems,
  },
};

SourceShellAction _module(String name, {required String search}) =>
    SourceShellAction(
      title: name,
      action: {
        'type': 'openVideoLibrary',
        'payload': {
          'title': name,
          'url': 'https://$name.fixture/',
          'protocol': 2,
          'catalogFnPath': 'catalog',
          'detailFnPath': 'detail',
          'playbackFnPath': 'play',
          'capabilities': {
            'search': search,
            'year': false,
            'recent': false,
            'filtersOnSearch': false,
            'detailFromSnapshot': true,
            'itemNamespace': name,
          },
        },
      },
    );

void main() {
  setUpAll(() async {
    await loadUiPreviewFonts();
    await TestObjectBoxHelper.setUpTestObjectBox();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  testWidgets(
    'Bika search keeps its results and returns to the original directory',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      for (final word in ['older one', 'older two', 'older three']) {
        await VideoSearchHistory.add(_bika, word);
      }
      const query = 'movie keyword';
      const failedQuery = 'failing keyword';
      const pendingQuery = 'pending keyword';
      final lateSearch = Completer<Map<String, dynamic>>();
      final requests = <({String home, String query, bool refresh})>[];

      Map<String, dynamic> catalog(String id, {String home = _movieHome}) {
        final rows = [
          for (final suffix in ['one', 'two']) _row('$id-$suffix', home: home),
          if (id == 'initial')
            for (var i = 0; i < 24; i++) _row('movie-$i', home: home),
        ];
        return {
          'data': {
            'items': rows,
            'categories': [],
            'page': 1,
            'pageCount': 1,
            'total': rows.length,
          },
        };
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SourceVideoContent(
              source: _bika,
              leading: const Icon(Icons.chevron_left),
              actions: [
                _module('movie', search: 'full'),
                _module('animate', search: 'none'),
              ],
              pluginCall: (fn, args) async {
                final home = args['home'] as String;
                if (fn == 'detail')
                  return {'data': _row(args['id'].toString(), home: home)};
                final keyword = args['query'] as String;
                final refresh = args['refresh'] as bool;
                requests.add((home: home, query: keyword, refresh: refresh));
                expect(args['page'], 1);
                expect(args['typeId'], '');
                expect(args['year'], '');
                expect(args['recentHours'], 0);
                expect(args['cursor'], isNull);
                expect(args['sort'], isNull);
                expect(args['browseUrl'], isNull);
                if (home == _animeHome)
                  return catalog('anime', home: _animeHome);
                if (keyword == pendingQuery) return lateSearch.future;
                if (keyword == failedQuery && !refresh) {
                  throw StateError('fixture HTTP 502');
                }
                if (keyword.isEmpty) return catalog('initial');
                return catalog(refresh ? 'recovered' : 'search');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final entry = find.byType(VideoSearchEntry);
      final input = find.descendant(
        of: entry,
        matching: find.byType(TextField),
      );
      final modulePicker = find.byKey(const ValueKey('source-video.modules'));
      final scopeMenu = find.byType(KeywordScopeMenu);
      Iterable<String> visibleIds() => tester
          .widget<ApiVideoCollection>(find.byType(ApiVideoCollection))
          .items
          .map((item) => item.id);
      final directoryScroll = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!;
      directoryScroll.jumpTo(120);
      await tester.pumpAndSettle();
      expect(visibleIds().take(2), ['initial-one', 'initial-two']);
      expect(
        tester.widget<KeywordScopeMenu>(scopeMenu).scope,
        KeywordSearchScope.all,
      );
      tester
          .widget<KeywordScopeMenu>(scopeMenu)
          .onChanged(KeywordSearchScope.title);
      await tester.pumpAndSettle();
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(
        ModalRoute.of(tester.element(input))?.settings.name,
        'breeze.video.search-task',
      );
      expect(modulePicker, findsNothing);
      expect(find.byType(VideoNativeNavigation), findsNothing);
      expect(find.byType(ApiVideoCollection), findsNothing);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(
        tester.widget<KeywordScopeMenu>(scopeMenu).scope,
        KeywordSearchScope.title,
      );
      expect(requests, [(home: _movieHome, query: '', refresh: false)]);
      final historyPanel = find.byType(CatalogSearchOverlay);
      expect(tester.widget<CatalogSearchOverlay>(historyPanel).inPage, isTrue);
      expect(
        find.descendant(
          of: historyPanel,
          matching: find.byWidgetPredicate(
            (widget) => widget is Material && widget.elevation > 0,
          ),
        ),
        findsNothing,
      );
      expect(find.text(t.search.history), findsOneWidget);
      for (final word in ['older one', 'older two', 'older three']) {
        expect(find.text(word), findsOneWidget);
      }
      tester
          .widget<KeywordScopeMenu>(scopeMenu)
          .onChanged(KeywordSearchScope.all);
      await tester.pumpAndSettle();

      Future<void> submit(String keyword) async {
        await tester.tap(input);
        await tester.pumpAndSettle();
        await tester.enterText(input, keyword);
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }

      await submit(query);
      await tester.pumpAndSettle();
      expect(visibleIds(), ['search-one', 'search-two']);
      expect(tester.widget<TextField>(input).controller!.text, query);
      expect(find.text(t.search.history), findsNothing);
      expect(find.widgetWithText(InputChip, query), findsNothing);
      expect(find.text(t.videoLibrary.results(count: 2)), findsOneWidget);
      expect(
        find.byKey(const ValueKey('api-catalog.local-scope')),
        findsNothing,
      );

      await tester.tap(input);
      await tester.pumpAndSettle();
      await tester.enterText(input, 'discard edit');
      await tester.tap(find.byTooltip(t.videoSearch.cancel));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(input).controller!.text, query);
      expect(visibleIds(), ['search-one', 'search-two']);

      await submit(failedQuery);
      await tester.pumpAndSettle();
      expect(find.text(t.common.loadingFailed), findsOneWidget);
      expect(find.text(t.videoLibrary.results(count: 0)), findsNothing);
      await tester.tap(find.text(t.common.retry));
      await tester.pumpAndSettle();
      expect(visibleIds(), ['recovered-one', 'recovered-two']);

      await submit(pendingQuery);
      await tester.tap(
        find.descendant(of: entry, matching: find.byTooltip(t.common.clear)),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(input).controller!.text, isEmpty);
      expect(find.text(t.search.history), findsOneWidget);
      expect(find.byType(ApiVideoCollection), findsNothing);
      lateSearch.complete(catalog('late'));
      await tester.pumpAndSettle();
      expect(find.byType(ApiVideoCollection), findsNothing);

      await tester.tap(find.byTooltip(t.common.back));
      await tester.pumpAndSettle();
      expect(visibleIds().take(2), ['initial-one', 'initial-two']);
      expect(directoryScroll.offset, 120);
      expect(input, findsNothing);
      tester.widget<NativeVideoSegmentedControl>(modulePicker).onSelected!(
        _animeHome,
      );
      await tester.pumpAndSettle();
      expect(visibleIds(), ['anime-one', 'anime-two']);
      expect(
        find.byKey(const ValueKey('api-catalog.local-query')),
        findsOneWidget,
      );
      tester.widget<NativeVideoSegmentedControl>(modulePicker).onSelected!(
        _movieHome,
      );
      await tester.pumpAndSettle();
      expect(visibleIds().take(2), ['initial-one', 'initial-two']);
      expect(requests, [
        (home: _movieHome, query: '', refresh: false),
        (home: _movieHome, query: query, refresh: false),
        (home: _movieHome, query: failedQuery, refresh: false),
        (home: _movieHome, query: failedQuery, refresh: true),
        (home: _movieHome, query: pendingQuery, refresh: false),
        (home: _animeHome, query: '', refresh: false),
      ]);
    },
  );

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'Bika browsing has one query and opens loaded filters $style $brightness',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          await tester.binding.setSurfaceSize(const Size(320, 1100));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          final channels = <MethodChannel>[];
          final byTooltip = <String, MethodChannel>{};
          messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
            call,
          ) async {
            if (call.method == 'create') {
              final args = call.arguments as Map;
              final channel = MethodChannel(
                '${args['viewType']}.${args['id']}',
              );
              channels.add(channel);
              messenger.setMockMethodCallHandler(channel, (call) async {
                if (call.method == 'update' && call.arguments is Map) {
                  final tooltip = (call.arguments as Map)['tooltip'];
                  if (tooltip is String) byTooltip[tooltip] = channel;
                }
                return null;
              });
            }
            return null;
          });
          const network = MethodChannel('breeze.video.network');
          const connectivity = MethodChannel(
            'dev.fluttercommunity.plus/connectivity',
          );
          const connectivityChanges = MethodChannel(
            'dev.fluttercommunity.plus/connectivity_status',
          );
          messenger.setMockMethodCallHandler(network, (_) async => false);
          messenger.setMockMethodCallHandler(
            connectivity,
            (_) async => ['wifi'],
          );
          messenger.setMockMethodCallHandler(
            connectivityChanges,
            (_) async => null,
          );
          addTearDown(() {
            messenger.setMockMethodCallHandler(
              SystemChannels.platform_views,
              null,
            );
            messenger.setMockMethodCallHandler(network, null);
            messenger.setMockMethodCallHandler(connectivity, null);
            messenger.setMockMethodCallHandler(connectivityChanges, null);
            for (final channel in channels)
              messenger.setMockMethodCallHandler(channel, null);
          });
          final preference = ValueNotifier(style);
          addTearDown(preference.dispose);
          final textScale = ValueNotifier(2.0);
          addTearDown(textScale.dispose);
          final catalogs = <String>[];
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: preference,
              child: MaterialApp(
                theme: ThemeData(
                  brightness: brightness,
                  platform: TargetPlatform.iOS,
                  fontFamily: uiPreviewDirectory == null
                      ? null
                      : 'AccountPreview',
                ),
                builder: (context, child) => ValueListenableBuilder<double>(
                  valueListenable: textScale,
                  builder: (context, scale, _) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: RepaintBoundary(
                      key: const ValueKey('bika-browse-preview'),
                      child: child!,
                    ),
                  ),
                ),
                home: Scaffold(
                  body: SourceVideoContent(
                    source: _bika,
                    leading: const Icon(Icons.chevron_left),
                    actions: [
                      _module('movie', search: 'full'),
                      _module('animate', search: 'none'),
                    ],
                    pluginCall: (fn, args) async {
                      final home = args['home'] as String;
                      if (fn == 'detail') {
                        return {
                          'data': _row(args['id'].toString(), home: home),
                        };
                      }
                      catalogs.add(home);
                      return _page(extraItems: 18, home: home);
                    },
                  ),
                  bottomNavigationBar: VideoNativeNavigation(
                    currentIndex: 0,
                    onTap: (_) {},
                    symbols: const ['film', 'person'],
                    items: const [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.movie),
                        label: '视频',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.person),
                        label: '我的',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(VideoNativeNavigation), findsOneWidget);
          expect(find.byKey(const ValueKey('api-library.scope')), findsNothing);
          expect(find.byType(VideoSearchEntry), findsOneWidget);
          expect(find.byType(SearchQueryField), findsOneWidget);
          final more = tester.widget<NativeVideoMenu>(
            find.descendant(
              of: find.byType(SourceMoreButton),
              matching: find.byType(NativeVideoMenu),
            ),
          );
          expect(more.options, isNot(contains('search-loaded')));
          expect(more.options, isNot(contains('display')));
          final view = find.byKey(const ValueKey('api-catalog.view-mode'));
          CustomScrollView catalogScroll() => tester.widget<CustomScrollView>(
            find.ancestor(of: view, matching: find.byType(CustomScrollView)),
          );

          Future<void> checkViewToggle(double offset) async {
            final heading = find.text(t.videoLibrary.updatedFirst);
            final scroll = catalogScroll().controller!;
            scroll.jumpTo(offset);
            await tester.pumpAndSettle();
            final headerTop = tester.getTopLeft(heading).dy;
            expect(tester.getSize(view), const Size.square(44));
            expect(
              tester.getCenter(view).dy,
              closeTo(tester.getCenter(heading).dy, 1),
            );
            for (final mode in [ApiVideoView.list, ApiVideoView.grid]) {
              final native = find.descendant(
                of: view,
                matching: find.byType(UiKitView),
              );
              if (native.evaluate().isEmpty) {
                await tester.tap(view);
              } else {
                tester.widget<SourceChromeIconButton>(view).onPressed!();
              }
              await tester.pumpAndSettle();
              expect(
                tester
                    .widget<ApiVideoCollection>(find.byType(ApiVideoCollection))
                    .mode,
                mode,
              );
              expect(scroll.offset, closeTo(offset, 0.1));
              expect(tester.getTopLeft(heading).dy, closeTo(headerTop, 0.1));
              expect(view.hitTestable(), findsOneWidget);
            }
            scroll.jumpTo(0);
            await tester.pumpAndSettle();
          }

          await checkViewToggle(0);
          await checkViewToggle(12);
          final movieStorageKey = catalogScroll().key;
          expect(movieStorageKey, isA<PageStorageKey<String>>());
          expect(
            find.byType(ApiVideoFavorites, skipOffstage: false),
            findsNothing,
          );
          expect(
            find.byType(ApiVideoHistory, skipOffstage: false),
            findsNothing,
          );
          expect(find.byType(ApiVideoContinueEntry), findsNothing);
          await writeUiPreview(
            tester,
            const ValueKey('bika-browse-preview'),
            'bika-browse-$style-${brightness.name}-large',
          );
          textScale.value = 1;
          await tester.binding.setSurfaceSize(const Size(430, 932));
          await tester.pumpAndSettle();
          await writeUiPreview(
            tester,
            const ValueKey('bika-browse-preview'),
            'bika-browse-$style-${brightness.name}-standard',
          );
          textScale.value = 2;
          await tester.binding.setSurfaceSize(const Size(320, 1100));
          await tester.pumpAndSettle();
          final filter = find.byKey(const ValueKey('api-library.filters'));
          final native = find.descendant(
            of: filter,
            matching: find.byType(UiKitView),
          );
          if (native.evaluate().isEmpty) {
            await tester.tap(filter);
          } else {
            final tooltip =
                (tester.widget<UiKitView>(native).creationParams
                    as Map)['tooltip'];
            final channel = byTooltip[tooltip]!;
            await messenger.handlePlatformMessage(
              channel.name,
              const StandardMethodCodec().encodeMethodCall(
                const MethodCall('press'),
              ),
              (_) {},
            );
          }
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('shelf-facet-tags')),
            findsOneWidget,
          );
          await tester.tap(find.byKey(const ValueKey('shelf-facet-tags')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('shelf-option-tags-科幻')),
            findsOneWidget,
          );
          final query = find.byKey(const ValueKey('shelf-filter-work-query'));
          expect(query, findsOneWidget);
          expect(find.text(t.videoLibrary.loadedResultScope), findsOneWidget);
          expect(
            find.byKey(const ValueKey('shelf-scope-all-label')),
            findsNothing,
          );
          await tester.enterText(
            find.descendant(of: query, matching: find.byType(TextField)),
            'one',
          );
          await tester.pumpAndSettle();
          final apply = find.byKey(const ValueKey('shelf-filter-apply'));
          expect(find.text(t.bookshelf.facets.resultTitle(count: 1)), findsOne);
          await tester.tap(apply);
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<ApiVideoCollection>(find.byType(ApiVideoCollection))
                .items
                .map((item) => item.id),
            ['one'],
          );
          expect(catalogs, ['https://movie.fixture/']);
          tester
              .widget<NativeVideoSegmentedControl>(
                find.byKey(const ValueKey('source-video.modules')),
              )
              .onSelected!('https://animate.fixture/');
          await tester.pumpAndSettle();
          expect(find.byType(VideoSearchEntry), findsNothing);
          expect(find.byType(SearchQueryField), findsOneWidget);
          expect(
            find.byKey(const ValueKey('api-catalog.local-query')),
            findsOneWidget,
          );
          expect(catalogScroll().key, isA<PageStorageKey<String>>());
          expect(catalogScroll().key, isNot(movieStorageKey));
          await checkViewToggle(0);
          await checkViewToggle(12);
          expect(catalogs, [
            'https://movie.fixture/',
            'https://animate.fixture/',
          ]);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }

  for (final section in ['favorite', 'history']) {
    testWidgets(
      'a local $section task does not fetch the catalog or add navigation',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        var catalogReads = 0;
        final repo = ApiVideoRepository(
          source: 'local-task-$section',
          home: Uri.parse('https://local-task.fixture/'),
          catalogFn: 'catalog',
          detailFn: 'detail',
          playbackFn: 'play',
          capabilities: const ApiVideoCapabilities(year: false, recent: false),
          pluginCall: (fn, _) async {
            if (fn == 'catalog') catalogReads++;
            return _page();
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            home: ApiVideoLibraryPage(
              repository: repo,
              title: '本机记录',
              initialSection: section,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(catalogReads, 0);
        expect(find.byType(VideoNativeNavigation), findsNothing);
        expect(
          find.byKey(
            const ValueKey('api-catalog.local-scope'),
            skipOffstage: false,
          ),
          findsNothing,
        );
        expect(
          find.byType(
            section == 'favorite' ? ApiVideoFavorites : ApiVideoHistory,
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('refresh retry retains entries and awaits a single manual retry', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    var fail = false, reads = 0;
    Completer<Map<String, dynamic>>? retry;
    final repo = ApiVideoRepository(
      source: 'browse-retry-fixture',
      home: Uri.parse('https://movie.fixture/'),
      catalogFn: 'catalog',
      detailFn: 'detail',
      playbackFn: 'play',
      capabilities: const ApiVideoCapabilities(
        search: 'none',
        year: false,
        recent: false,
      ),
      pluginCall: (fn, args) async {
        if (fn == 'detail') return {'data': _row(args['id'].toString())};
        reads++;
        if (fail) throw StateError('offline');
        return retry == null ? _page() : retry.future;
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ApiVideoLibraryPage(
          repository: repo,
          title: '片库',
          embedded: true,
          browseOnly: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<ApiVideoCollection>(find.byType(ApiVideoCollection)).items,
      hasLength(2),
      reason:
          'The fixture must publish a successful same-origin snapshot before testing retention.',
    );
    fail = true;
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator).first)
        .onRefresh();
    await tester.pumpAndSettle();
    expect(
      tester.widget<ApiVideoCollection>(find.byType(ApiVideoCollection)).items,
      hasLength(2),
    );
    final beforeRetry = reads;
    fail = false;
    retry = Completer<Map<String, dynamic>>();
    await tester.tap(find.byKey(const ValueKey('api-catalog.refresh-retry')));
    await tester.pump();
    expect(reads, beforeRetry + 1);
    expect(
      tester.widget<ApiVideoCollection>(find.byType(ApiVideoCollection)).items,
      hasLength(2),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(reads, beforeRetry + 1);
    retry.complete(_page());
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('api-catalog.refresh-retry')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
