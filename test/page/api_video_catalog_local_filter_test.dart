import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/discover/service/discover_router.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_filter_panel.dart';
import 'package:zephyr/page/video/api_video_library_page.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/omofun_account_page.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';
import 'package:zephyr/page/video/video_search_page.dart';
import 'package:zephyr/page/video/video_site_browser.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/year_filter_picker.dart';

class _SearchWebPlatform extends InAppWebViewPlatform {
  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) => _SearchWebView(params);
}

class _SearchWebView extends PlatformInAppWebViewWidget {
  _SearchWebView(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      params.controllerFromPlatform!(controller) as T;

  @override
  void dispose() {}
}

void main() {
  testWidgets(
    'Discover Omo search opens a single editor before result filters',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => DiscoverRouter.route(
                  context,
                  currentFrom: 'omo-search-route-fixture',
                  action: const {
                    'type': 'openVideoLibrary',
                    'payload': {
                      'source': 'omo-search-route-fixture',
                      'url': 'https://www.omofuna.com/',
                      'protocol': 2,
                      'catalogFnPath': 'list',
                      'detailFnPath': 'detail',
                      'playbackFnPath': 'play',
                      'nativeSearch': true,
                      'openSearch': true,
                      'capabilities': {
                        'search': 'full',
                        'browserCatalog': true,
                        'year': true,
                        'yearOnSearch': false,
                        'filtersOnSearch': false,
                        'presentation': 'anime',
                        'yearTypePrefixes': ['type:', 'genre:'],
                      },
                    },
                  },
                ),
                child: const Text('Open Omo search'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open Omo search'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(find.text(t.search.history), findsOneWidget);
      expect(find.byType(ApiVideoFilterPanel), findsNothing);
      expect(find.byKey(const ValueKey('video-search.filters')), findsNothing);
      expect(find.text(t.videoLibrary.loadedResultScope), findsNothing);
      await tester.tap(find.byTooltip(t.videoSearch.cancel));
      await tester.pumpAndSettle();
      expect(find.text('Open Omo search'), findsOneWidget);
      expect(find.byType(ApiVideoLibraryPage), findsNothing);
    },
  );

  testWidgets('source search finishes leaving before its catalog enters', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => DiscoverRouter.route(
                context,
                currentFrom: 'website-search-route-fixture',
                action: const {
                  'type': 'openVideoLibrary',
                  'payload': {
                    'source': 'website-search-route-fixture',
                    'url': 'https://catalog.test/',
                    'protocol': 2,
                    'catalogFnPath': 'list',
                    'detailFnPath': 'detail',
                    'playbackFnPath': 'play',
                    'nativeSearch': true,
                    'openSearch': true,
                    'capabilities': {
                      'search': 'website',
                      'searchPath': '/search',
                    },
                  },
                },
              ),
              child: const Text('Open source search'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open source search'));
    await tester.pumpAndSettle();
    expect(find.text(t.videoLibrary.officialSearchHint), findsOneWidget);
    expect(find.byKey(const ValueKey('video-search.filters')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('video-search.input')),
      '词',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(find.byType(ApiVideoLibraryPage, skipOffstage: false), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byType(ApiVideoLibraryPage), findsOne);
    expect(find.byType(OmoSiteWebPage), findsNothing);
  });

  testWidgets(
    'remote search edits a filter draft before one filtered request',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final calls = <Map<String, dynamic>>[];
      final repo = ApiVideoRepository(
        source: 'remote-search-filter-fixture',
        home: Uri.parse('https://remote.test/'),
        catalogFn: 'list',
        detailFn: 'detail',
        playbackFn: 'play',
        pluginCall: (_, args) async {
          calls.add({...args});
          return {
            'data': {
              'items': [],
              'categories': [
                {'id': 'drama', 'name': 'Fixture drama'},
              ],
              'page': 1,
              'pageCount': 1,
              'total': 0,
            },
          };
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ApiVideoLibraryPage(repository: repo, title: 'Remote source'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(VideoSearchEntry));
      await tester.pumpAndSettle();
      final input = find.descendant(
        of: find.byType(VideoSearchEntry),
        matching: find.byType(TextField),
      );
      expect(find.byType(VideoSearchPage), findsNothing);
      final filters = find.byKey(const ValueKey('video-search.filters'));
      final panel = find.byType(ApiVideoFilterPanel);
      expect(panel, findsNothing);
      expect(filters, findsOneWidget);
      expect(calls, hasLength(1));
      await tester.enterText(input, 'Filtered title');

      Future<void> chooseYear() async {
        final year = tester.widget<YearFilterPicker>(
          find.byType(YearFilterPicker),
        );
        final wheel = tester.widget<CupertinoPicker>(
          find.byType(CupertinoPicker),
        );
        wheel.scrollController!.jumpToItem(
          year.options.keys.toList().indexOf('1999'),
        );
        await tester.pumpAndSettle();
      }

      await tester.tap(filters);
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
      expect(
        tester.widget<ApiVideoFilterPanel>(panel).categories.single.id,
        'drama',
      );
      expect(find.text(t.videoLibrary.loadedResultScope), findsNothing);
      await chooseYear();
      await tester.tap(find.byTooltip(t.common.close));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(filters);
      await tester.pumpAndSettle();
      expect(tester.widget<ApiVideoFilterPanel>(panel).initial.date, isEmpty);
      await chooseYear();
      await tester.tap(find.byKey(const ValueKey('api-filters.apply')));
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(calls, hasLength(1));
      await tester.tap(find.byTooltip(t.videoSearch.submit));
      await tester.pumpAndSettle();
      expect(calls, hasLength(2));
      expect(calls.last['query'], 'Filtered title');
      expect(calls.last['year'], '1999');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'website-only source searches loaded metadata without navigating',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final webPlatform = InAppWebViewPlatform.instance;
      InAppWebViewPlatform.instance = _SearchWebPlatform();
      addTearDown(() {
        if (webPlatform != null) InAppWebViewPlatform.instance = webPlatform;
      });
      final queries = <String>[];
      final repo = ApiVideoRepository(
        source: 'website-search-fixture',
        home: Uri.parse('https://catalog.test/'),
        catalogFn: 'list',
        detailFn: 'detail',
        playbackFn: 'play',
        capabilities: const ApiVideoCapabilities(
          search: 'website',
          searchPath: '/site/search',
        ),
        pluginCall: (path, args) async {
          expect(path, 'list');
          queries.add(args['query'] as String);
          return {
            'data': {
              'items': [
                {
                  'id': '1',
                  'title': 'First work',
                  'genres': 'Adventure',
                  'detailUrl': 'https://catalog.test/first',
                  'coverUrl': 'https://catalog.test/first.jpg',
                },
                {
                  'id': '2',
                  'title': 'Second work',
                  'genres': 'Comedy',
                  'detailUrl': 'https://catalog.test/second',
                  'coverUrl': 'https://catalog.test/second.jpg',
                },
              ],
              'page': 1,
              'pageCount': 1,
              'total': 2,
            },
          };
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ApiVideoLibraryPage(
            repository: repo,
            title: 'Website source',
            initialQuery: 'Adventure',
            initialKeywordScope: KeywordSearchScope.all,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OmoSiteWebPage), findsNothing);
      expect(find.byKey(const ValueKey('api-catalog.local-scope')), findsOne);
      ApiVideoCollection collection() =>
          tester.widget<ApiVideoCollection>(find.byType(ApiVideoCollection));
      expect(collection().items.map((item) => item.id), ['1']);
      expect(find.text(t.videoLibrary.officialSearch), findsOne);

      await tester.tap(find.byType(VideoSearchEntry));
      await tester.pumpAndSettle();
      final input = find.descendant(
        of: find.byType(VideoSearchEntry),
        matching: find.byType(TextField),
      );
      expect(find.byType(VideoSearchPage), findsNothing);
      expect(tester.widget<TextField>(input).controller?.text, 'Adventure');
      await tester.enterText(input, 'Comedy');
      await tester.tap(find.byTooltip(t.comicList.scope));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.sourceShell.searchScopeTitle).last);
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(collection().items, isEmpty);

      await tester.tap(find.byType(VideoSearchEntry));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(t.comicList.scope));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.common.all).last);
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(collection().items.map((item) => item.id), ['2']);
      expect(find.byType(OmoSiteWebPage), findsNothing);
      expect(queries, ['']);

      final websiteButton = find.byKey(
        const ValueKey('api-catalog.website-search'),
      );
      await tester.tap(websiteButton);
      await tester.pumpAndSettle();
      final website = find.byType(OmoSiteWebPage);
      expect(
        tester.widget<OmoSiteWebPage>(website).url.toString(),
        'https://catalog.test/site/search?wd=Comedy',
      );
      expect(
        tester.widget<VideoSiteBrowser>(find.byType(VideoSiteBrowser)).source,
        repo.source,
      );
      Navigator.of(tester.element(website)).pop();
      await tester.pumpAndSettle();
      expect(collection().items.map((item) => item.id), ['2']);
      expect(queries, ['']);
    },
  );

  for (final caps in [
    const ApiVideoCapabilities(),
    const ApiVideoCapabilities(year: false, recent: false, sourceSort: true),
    const ApiVideoCapabilities(year: true, recent: false),
    const ApiVideoCapabilities(year: false, recent: true),
  ]) {
    testWidgets(
      'remote-capable catalog retains its search/filter workflow without local controls $caps',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final preference = ValueNotifier('breeze');
        addTearDown(preference.dispose);
        final repository = ApiVideoRepository(
          source: 'remote-capable-fixture',
          home: Uri.parse('https://remote.test/'),
          catalogFn: 'list',
          detailFn: 'detail',
          playbackFn: 'play',
          capabilities: caps,
          pluginCall: (_, _) async => {
            'data': {
              'items': [],
              'categories': [],
              'page': 1,
              'pageCount': 1,
              'total': 0,
            },
          },
        );
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: preference,
            child: MaterialApp(
              home: ApiVideoLibraryPage(
                repository: repository,
                title: 'Remote fixture',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(VideoSearchEntry), findsOneWidget);
        expect(
          find.byKey(const ValueKey('api-catalog.local-query')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('api-catalog.local-filters')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('api-catalog.local-scope')),
          findsNothing,
        );
        if (caps.year || caps.sourceSort) {
          expect(
            find.byKey(const ValueKey('api-library.filters')),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'reviewed Omo discovery and weekly pages do not acquire the local catalog toolbar',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preference = ValueNotifier('breeze');
      addTearDown(preference.dispose);
      final home = Uri.parse('https://www.omofuna.com/');
      final types = <String>[];
      final client = OmoSiteClient(
        home: home,
        request: (_, _) async =>
            throw StateError('private operations are outside this fixture'),
      );
      addTearDown(client.dispose);
      final repository = ApiVideoRepository(
        source: 'omo-toolbar-fixture',
        home: home,
        catalogFn: 'list',
        detailFn: 'detail',
        playbackFn: 'play',
        capabilities: const ApiVideoCapabilities(
          presentation: 'anime',
          siteAccount: true,
          year: false,
          recent: false,
        ),
        pluginCall: (_, args) async {
          types.add('${args['typeId']}');
          return {
            'data': {
              'items': [],
              'categories': [
                {'id': 'week:0', 'parentId': 'week', 'name': '周一'},
              ],
              'page': 1,
              'pageCount': 1,
              'total': 0,
            },
          };
        },
      );
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: preference,
          child: MaterialApp(
            home: ApiVideoLibraryPage(
              repository: repository,
              title: 'Omo fixture',
              siteClient: client,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('api-catalog.local-query')),
        findsNothing,
      );
      // Weekly scheduling is the dedicated tab; the RSS feed is within it.
      await tester.tap(find.text(t.videoSource.weeklyTab));
      await tester.pumpAndSettle();
      expect(types.last, startsWith('week:'));
      expect(
        find.byKey(
          const ValueKey('api-catalog.local-query'),
          skipOffstage: false,
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('api-catalog.local-filters'),
          skipOffstage: false,
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'local catalog conditions preserve paging and bound explicit loading $style $brightness',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          await tester.binding.setSurfaceSize(const Size(400, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          final channels = <MethodChannel>[];
          final channelsByTooltip = <String, MethodChannel>{};
          messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
            call,
          ) async {
            if (call.method == 'create') {
              final args = call.arguments as Map;
              final channel = MethodChannel(
                '${args['viewType']}.${args['id']}',
              );
              channels.add(channel);
              messenger.setMockMethodCallHandler(channel, (update) async {
                if (update.method == 'update' && update.arguments is Map) {
                  final tooltip = (update.arguments as Map)['tooltip'];
                  if (tooltip is String) channelsByTooltip[tooltip] = channel;
                }
                return null;
              });
            }
            return null;
          });
          addTearDown(() {
            messenger.setMockMethodCallHandler(
              SystemChannels.platform_views,
              null,
            );
            for (final channel in channels) {
              messenger.setMockMethodCallHandler(channel, null);
            }
          });
          Future<void> pressControl(Finder control) async {
            final size = tester.getSize(control);
            expect(size.width, greaterThanOrEqualTo(44));
            expect(size.height, greaterThanOrEqualTo(44));
            if (style == 'system') {
              expect(size, const Size(44, 44));
            } else if (tester.widget(control).key ==
                const ValueKey('api-catalog.local-filters')) {
              final input = tester.getRect(
                find.byKey(const ValueKey('api-catalog.local-query')),
              );
              final button = tester.getRect(control);
              expect(button.center.dy, closeTo(input.center.dy, .01));
              expect(button.size, const Size(44, 44));
            }
            final native = find.descendant(
              of: control,
              matching: find.byType(UiKitView),
            );
            if (native.evaluate().isEmpty) {
              await tester.tap(control);
            } else {
              final params =
                  tester.widget<UiKitView>(native).creationParams as Map;
              final channel = channelsByTooltip[params['tooltip']];
              expect(
                channel,
                isNotNull,
                reason: 'use the actual native control bridge',
              );
              await messenger.handlePlatformMessage(
                channel!.name,
                const StandardMethodCodec().encodeMethodCall(
                  const MethodCall('press'),
                ),
                (_) {},
              );
            }
          }

          final pages = <int>[];
          final repo = ApiVideoRepository(
            source: 'local-catalog-$style-${brightness.name}',
            home: Uri.parse('https://catalog.test/'),
            catalogFn: 'list',
            detailFn: 'detail',
            playbackFn: 'play',
            capabilities: const ApiVideoCapabilities(
              search: 'none',
              year: false,
              recent: false,
            ),
            pluginCall: (fn, args) async {
              final page = args['page'] as int;
              pages.add(page);
              return {
                'data': {
                  'page': page,
                  'pageCount': 3,
                  'total': 60,
                  'items': [
                    for (var i = 0; i < 20; i++)
                      {
                        'id': '$page-$i',
                        'title': page == 2 && i == 0
                            ? 'target match'
                            : 'ordinary $page-$i',
                        'detailUrl': 'https://catalog.test/videos/$page-$i',
                        'genres': i.isEven ? '标签A' : '标签B',
                      },
                  ],
                  'categories': [],
                },
              };
            },
          );
          final preference = ValueNotifier(style);
          addTearDown(preference.dispose);
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: preference,
              child: MaterialApp(
                theme: ThemeData(
                  brightness: brightness,
                  platform: TargetPlatform.iOS,
                ),
                home: ApiVideoLibraryPage(repository: repo, title: 'Fixture'),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(pages, [1]);
          final catalog = find.byType(ApiVideoCollection).first;
          ApiVideoCollection collection() => tester.widget<ApiVideoCollection>(
            find.byType(ApiVideoCollection).first,
          );
          expect(collection().items, hasLength(20));
          final originalState = tester.state(catalog);
          ScrollPosition position() => tester
              .state<ScrollableState>(
                find
                    .descendant(
                      of: find.byType(ApiVideoCollection).first,
                      matching: find.byType(Scrollable),
                    )
                    .first,
              )
              .position;
          position().jumpTo(400);
          await tester.pumpAndSettle();
          final originalOffset = position().pixels;
          expect(originalOffset, greaterThan(0));
          await pressControl(
            find.byKey(const ValueKey('api-catalog.local-filters')),
          );
          await tester.pumpAndSettle();
          // The only dimension is already selected by the shared sheet.
          await tester.tap(find.byKey(const ValueKey('shelf-option-tags-标签A')));
          await tester.pumpAndSettle();
          // Cancelling the draft leaves the collection and current page intact.
          Navigator.of(
            tester.element(find.byKey(const ValueKey('shelf-filter-apply'))),
          ).pop();
          await tester.pumpAndSettle();
          expect(tester.state(catalog), same(originalState));
          expect(collection().items, hasLength(20));
          expect(pages, [1]);
          final field = find.descendant(
            of: find.byKey(const ValueKey('api-catalog.local-query')),
            matching: find.byType(TextField),
          );
          await tester.enterText(field, 'target');
          await tester.pumpAndSettle();
          expect(collection().items, isEmpty);
          expect(collection().onNearEnd, isNull);
          expect(
            find.text(t.videoLibrary.localCatalogNoMatches),
            findsOneWidget,
          );
          expect(pages, [1]);
          await tester.tap(
            find.byKey(const ValueKey('api-catalog.local-load-next')),
          );
          await tester.pumpAndSettle();
          expect(pages, [1, 2]);
          expect(collection().items.single.title, 'target match');
          expect(collection().onNearEnd, isNull);
          expect(
            find.text(
              t.videoLibrary.localCatalogScope(loaded: 40, total: 60, shown: 1),
            ),
            findsOneWidget,
          );
          // No background loop reads page 3 while waiting with sparse matches.
          await tester.pump(const Duration(seconds: 2));
          expect(pages, [1, 2]);
          await pressControl(
            find.byKey(const ValueKey('api-catalog.local-reset')),
          );
          await tester.pumpAndSettle();
          expect(collection().items, hasLength(40));
          expect(
            position().pixels,
            closeTo(originalOffset, 1),
            reason:
                'clearing local conditions restores the unfiltered reading position',
          );
          expect(pages, [1, 2]);
          await pressControl(
            find.byKey(const ValueKey('api-catalog.local-filters')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('shelf-option-tags-标签A')));
          await tester.tap(find.byKey(const ValueKey('shelf-filter-apply')));
          await tester.pumpAndSettle();
          expect(collection().items, hasLength(20));
          expect(pages, [1, 2]);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }
}
