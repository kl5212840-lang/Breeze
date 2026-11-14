import 'dart:async';
import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:zephyr/widgets/year_filter_picker.dart';
import 'package:flutter/services.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_detail_page.dart';
import 'package:zephyr/page/video/api_video_filter_panel.dart';
import 'package:zephyr/page/video/api_video_library_page.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/omofun_account_page.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_search_page.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/video/video_search_filters.dart';

final home = Uri.parse('https://www.omofuna.com/');
Map<String, dynamic> work(
  String id, {
  String year = '2026',
  String remarks = '更新至4集',
}) => {
  'id': id,
  'title': '作品 $id',
  'detailUrl': '${home}anime/$id.html',
  'year': year,
  'remarks': remarks,
};
Map<String, dynamic> result(
  List<Map<String, dynamic>> items, {
  int page = 1,
  int pages = 1,
}) => {
  'data': {
    'page': page,
    'pageCount': pages,
    'total': pages * items.length,
    'items': items,
    'categories': [
      for (final (id, name) in [
        ('1', '日漫'),
        ('2', '国漫'),
        ('5', '动画'),
        ('24', '剧场'),
        ('4', '特摄'),
        ('3', '美漫'),
      ])
        {'id': 'type:$id', 'name': name, 'parentId': '0'},
    ],
  },
};
void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

ApiVideoRepository repository(
  Future<Map<String, dynamic>> Function(String, Map<String, dynamic>) call, {
  String source = 'flow',
}) {
  // A visible card without a cover legitimately reads its detail. Serve that
  // item from this fixture's observed catalog instead of returning a catalog
  // response for the detail function or counting it as a second list read.
  final items = <String, Map<String, dynamic>>{};
  return ApiVideoRepository(
    source: source,
    home: home,
    catalogFn: 'list',
    detailFn: 'item',
    playbackFn: 'play',
    pluginCall: (path, args) async {
      final item = items[args['id']?.toString()];
      if (path == 'item' && item != null) return {'data': item};
      final response = await call(path, args);
      if (path == 'list') {
        final data = response['data'];
        final rows = data is Map ? data['items'] : null;
        if (rows is List) {
          for (final row in rows.whereType<Map>()) {
            items[row['id'].toString()] = Map<String, dynamic>.from(row);
          }
        }
      }
      return response;
    },
    capabilities: const ApiVideoCapabilities(
      presentation: 'anime',
      recent: false,
      filtersOnSearch: false,
      yearOnSearch: false,
      yearTypePrefixes: ['type:', 'genre:'],
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'API source shell compact local year $style ${brightness.name}',
        (tester) async {
          phone(tester);
          final preference = ValueNotifier(style);
          addTearDown(preference.dispose);
          final nativeChannels = <MethodChannel>[];
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
            call,
          ) async {
            if (call.method == 'create') {
              final args = call.arguments as Map;
              final channel = MethodChannel(
                '${args['viewType']}.${args['id']}',
              );
              nativeChannels.add(channel);
              messenger.setMockMethodCallHandler(channel, (_) async => null);
            }
            return null;
          });
          addTearDown(() {
            messenger.setMockMethodCallHandler(
              SystemChannels.platform_views,
              null,
            );
            for (final channel in nativeChannels) {
              messenger.setMockMethodCallHandler(channel, null);
            }
          });
          final calls = <Map<String, dynamic>>[];
          final repo = repository((_, args) async {
            calls.add({...args});
            return result([work('a', year: '1999'), work('b')]);
          }, source: 'compact-$style-${brightness.name}');
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: preference,
              child: MaterialApp(
                theme: ThemeData(brightness: brightness),
                home: ApiVideoLibraryPage(
                  repository: repo,
                  title: 'OmoFun',
                  initialQuery: 'query',
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final filter = find.byKey(const ValueKey('api-library.filters'));
          if (style == 'system') {
            // UIKit is a host mock, so deliver its production action callback.
            tester.widget<SourceChromeIconButton>(filter).onPressed!();
          } else {
            await tester.tap(filter);
          }
          await tester.pumpAndSettle();
          expect(find.text(t.videoLibrary.loadedResultScope), findsOneWidget);
          expect(
            find.byKey(const ValueKey('api-filters.year.options')),
            findsNothing,
          );
          final wheel = find.byKey(const ValueKey('api-filters.year.wheel'));
          await tester.ensureVisible(wheel);
          await tester.pumpAndSettle();
          final field = tester.widget<YearFilterPicker>(
            find.byType(YearFilterPicker),
          );
          final picker = tester.widget<CupertinoPicker>(
            find.descendant(of: wheel, matching: find.byType(CupertinoPicker)),
          );
          picker.scrollController!.jumpToItem(
            field.options.keys.toList().indexOf('1999'),
          );
          await tester.pumpAndSettle();
          expect(calls, hasLength(1));
          await tester.tap(find.byKey(const ValueKey('api-filters.apply')));
          await tester.pumpAndSettle();
          expect(find.text('作品 a'), findsOneWidget);
          expect(find.text('作品 b'), findsNothing);
          expect(
            calls,
            hasLength(1),
            reason:
                'Local year selection must not send unsupported remote filters',
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }
  testWidgets(
    'remote year application, cancellation and clearing update real host results',
    (tester) async {
      phone(tester);
      final calls = <Map<String, dynamic>>[];
      final repo = repository((path, args) async {
        if (path != 'list') {
          throw StateError('Only catalog reads are part of this fixture');
        }
        calls.add({...args});
        final year = args['year'];
        return result(
          year == '2025'
              ? [work('selected-2025', year: '2025')]
              : year == '2024'
              ? [work('initial-2024', year: '2024')]
              : [work('all-recent'), work('selected-2025', year: '2025')],
        );
      }, source: 'remote-year-effect');
      await tester.pumpWidget(
        MaterialApp(
          home: ApiVideoLibraryPage(
            repository: repo,
            title: 'OmoFun',
            initialFilters: const VideoSearchFilters(
              genre: 'type:1',
              date: '2024',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, hasLength(1));
      expect(calls.single['year'], '2024');
      expect(find.text('作品 initial-2024'), findsOneWidget);
      Future<void> open() async {
        await tester.tap(find.byKey(const ValueKey('api-library.filters')));
        await tester.pumpAndSettle();
      }

      Future<void> year(String value) async {
        final field = tester.widget<YearFilterPicker>(
          find.byType(YearFilterPicker),
        );
        final picker = tester.widget<CupertinoPicker>(
          find.byType(CupertinoPicker),
        );
        picker.scrollController!.jumpToItem(
          field.options.keys.toList().indexOf(value),
        );
        await tester.pumpAndSettle();
      }

      await open();
      await year('2025');
      expect(calls, hasLength(1), reason: 'A draft must not issue a request');
      await tester.tap(find.byKey(const ValueKey('api-filters.apply')));
      await tester.pumpAndSettle();
      expect(calls, hasLength(2), reason: 'Apply issues exactly one request');
      expect(calls.last, containsPair('year', '2025'));
      expect(calls.last, containsPair('typeId', 'type:1'));
      expect(calls.last, containsPair('page', 1));
      expect(calls.last['cursor'], isNull);
      expect(find.text('作品 selected-2025'), findsOneWidget);
      expect(find.text('作品 initial-2024'), findsNothing);
      await open();
      await year('2026');
      await tester.tap(find.byTooltip(t.common.close));
      await tester.pumpAndSettle();
      expect(calls, hasLength(2));
      expect(find.text('作品 selected-2025'), findsOneWidget);
      await open();
      expect(
        tester.widget<YearFilterPicker>(find.byType(YearFilterPicker)).selected,
        '2025',
      );
      await tester.tap(find.byKey(const ValueKey('api-filters.year.all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('api-filters.apply')));
      await tester.pumpAndSettle();
      expect(calls, hasLength(3));
      expect(calls.last['year'], '');
      expect(calls.last['typeId'], 'type:1');
      expect(calls.last['page'], 1);
      expect(calls.last['cursor'], isNull);
      expect(find.text('作品 all-recent'), findsOneWidget);
      expect(find.text('作品 selected-2025'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'catalog loading keeps the first poster geometry and header when data arrives',
    (tester) async {
      phone(tester);
      final pending = Completer<Map<String, dynamic>>();
      final repo = repository((_, _) => pending.future);
      await tester.pumpWidget(
        MaterialApp(
          home: ApiVideoLibraryPage(repository: repo, title: 'OmoFun'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final before = tester.getRect(
        find.byKey(const ValueKey('api-skeleton.poster.0')),
      );
      pending.complete(result([work('a'), work('b'), work('c')]));
      await tester.pumpAndSettle();
      final after = tester.getRect(find.byType(ApiVideoPoster).first);
      expect(after.left, closeTo(before.left, .5));
      expect(after.top, closeTo(before.top, .5));
      expect(after.width, closeTo(before.width, .5));
      expect(after.height, closeTo(before.height, .5));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'search filters keep scope honest and zero matches can load the next source page',
    (tester) async {
      phone(tester);
      final calls = <Map<String, dynamic>>[];
      final repo = repository((_, args) async {
        calls.add({...args});
        return args['page'] == 1
            ? result([work('a'), work('b')], pages: 2)
            : result([work('c', remarks: '已完结')], page: 2, pages: 2);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: ApiVideoLibraryPage(
            repository: repo,
            title: 'OmoFun',
            initialQuery: 'query',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('api-library.filters')));
      await tester.pumpAndSettle();
      expect(find.text(t.videoLibrary.loadedResultScope), findsOneWidget);
      await tester.tap(
        find.widgetWithText(FilterChip, t.videoLibrary.completedOnly),
      );
      await tester.tap(
        find.widgetWithText(FilledButton, t.videoFilters.showResults),
      );
      await tester.pumpAndSettle();
      expect(
        calls.length,
        1,
        reason: 'A local filter must not send unsupported remote conditions',
      );
      expect(
        find.byKey(const ValueKey('api-catalog.local-load-next')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('api-catalog.local-load-next')),
      );
      await tester.pumpAndSettle();
      expect(calls.length, 2);
      expect(calls.last['page'], 2);
      expect(calls.last['year'], '');
      expect(calls.last['typeId'], '');
      expect(find.text('作品 c'), findsOneWidget);
      expect(find.text('作品 a'), findsNothing);
      expect(
        find.text(t.videoLibrary.filteredLoaded(shown: 1, loaded: 3)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'keyword input stays focused and result-only filters preserve cancellation',
    (tester) async {
      phone(tester);
      final calls = <Map<String, dynamic>>[];
      final repo = repository((_, args) async {
        calls.add({...args});
        return result([work('a', remarks: '完结'), work('b')]);
      }, source: 'form');
      await tester.pumpWidget(
        MaterialApp(
          home: ApiVideoLibraryPage(repository: repo, title: 'OmoFun'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(VideoSearchEntry));
      await tester.pumpAndSettle();
      expect(find.byType(ApiVideoFilterPanel), findsNothing);
      expect(find.text(t.videoLibrary.loadedResultScope), findsNothing);
      await tester.enterText(
        find.descendant(
          of: find.byType(VideoSearchEntry),
          matching: find.byType(TextField),
        ),
        '作品',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(calls.last['query'], '作品');
      expect(find.text('作品 a'), findsOneWidget);
      expect(find.text('作品 b'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('api-library.filters')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilterChip, t.videoLibrary.completedOnly),
      );
      await tester.tap(find.byKey(const ValueKey('api-filters.apply')));
      await tester.pumpAndSettle();
      expect(find.text('作品 b'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('api-library.filters')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilterChip, t.videoLibrary.completedOnly),
      );
      await tester.tap(find.byTooltip(t.common.close));
      await tester.pumpAndSettle();
      expect(find.text('作品 b'), findsNothing);
      expect(calls.length, 2);
      await tester.tap(find.byType(VideoSearchEntry));
      await tester.pumpAndSettle();
      expect(find.byType(ApiVideoFilterPanel), findsNothing);
      await tester.enterText(
        find.descendant(
          of: find.byType(VideoSearchEntry),
          matching: find.byType(TextField),
        ),
        '品',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(calls.last['query'], '品');
      expect(find.text('作品 b'), findsOneWidget);
      expect(calls.length, 3);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('title search can continue past a metadata-only first page', (
    tester,
  ) async {
    phone(tester);
    final pages = <Object?>[];
    final repo = repository((_, args) async {
      if (args['query'] == '目标') pages.add(args['page']);
      return args['page'] == 2
          ? result([work('目标')], page: 2, pages: 2)
          : result([work('其他')], pages: 2);
    }, source: 'title-scope-pages');
    await tester.pumpWidget(
      MaterialApp(
        home: ApiVideoLibraryPage(
          repository: repo,
          title: 'Source',
          initialKeywordScope: KeywordSearchScope.title,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(VideoSearchEntry));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(VideoSearchEntry),
        matching: find.byType(TextField),
      ),
      '目标',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(pages, [1]);
    expect(find.text('作品 其他'), findsNothing);
    expect(find.text(t.videoLibrary.loadedResultScope), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('api-catalog.local-load-next')));
    await tester.pumpAndSettle();
    expect(pages, [1, 2]);
    expect(find.text('作品 目标'), findsOneWidget);
    expect(find.text('作品 其他'), findsNothing);
  });
  testWidgets(
    'My reads account and one site following preview without a duplicate library',
    (tester) async {
      phone(tester);
      final operations = <String>[];
      final client = OmoSiteClient(
        home: home,
        request: (operation, args) async {
          operations.add(operation);
          if (operation == 'favorites')
            return {
              'kind': 'favorites',
              'rawCount': 0,
              'hasMore': false,
              'items': [],
            };
          return {
            'kind': 'account',
            'account': {'id': '1', 'name': '测试用户'},
          };
        },
      );
      addTearDown(client.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OmoAccountPage(
              client: client,
              active: true,
              onLocalHistory: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(operations, ['account', 'favorites']);
      expect(find.text(t.videoSource.siteFavorites), findsOneWidget);
      expect(find.byKey(const ValueKey('omo-my.follows-fold')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'saved state confirms in place without a persistent banner or shifting Share',
    (tester) async {
      phone(tester);
      final store = VideoLibraryStore(
        deviceId: 'flow',
        storageKey: 'save-in-place',
      );
      addTearDown(store.dispose);
      final data = work('a');
      final repo = repository(
        (_, _) async => {'data': data},
        source: 'save-in-place',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ApiVideoDetailPage(
            repository: repo,
            initialItem: ApiVideoItem.fromJson(data, home: home),
            store: store,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final share = find.byKey(const ValueKey('api-detail.share'));
      final before = tester.getRect(share);
      await tester.tap(find.byKey(const ValueKey('api-detail.favorite')));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text(t.videoLibrary.saved), findsOneWidget);
      expect(find.text(t.videoLibrary.classify), findsNothing);
      expect(tester.getRect(share), before);
      await tester.tap(find.byKey(const ValueKey('api-detail.favorite')));
      await tester.pumpAndSettle();
      expect((await store.read()).contains('flow', 'a'), isFalse);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text(t.videoLibrary.addFavorite), findsOneWidget);
      expect(tester.getRect(share), before);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'an unavailable account read is not presented as a confirmed sign-out',
    (tester) async {
      phone(tester);
      final client = OmoSiteClient(
        home: home,
        request: (_, _) async => throw const OmoSiteException('unavailable'),
      );
      addTearDown(client.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OmoAccountPage(
              client: client,
              active: true,
              onLocalHistory: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(t.videoSource.notSignedIn), findsNothing);
      expect(find.text(t.videoSource.login), findsNothing);
      final accountFailure = find.widgetWithText(
        ListTile,
        omoSiteError(const OmoSiteException('unavailable')),
      );
      expect(accountFailure, findsOneWidget);
      expect(
        find.descendant(
          of: accountFailure,
          matching: find.text(t.common.retry),
        ),
        findsOneWidget,
      );
      expect(find.text(t.videoSource.readFailed), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'completion filtering accepts explicit completed metadata and keeps unknown separate',
    () {
      expect(
        ApiVideoItem.fromJson(work('a', remarks: '完结'), home: home).finished,
        isTrue,
      );
      expect(
        ApiVideoItem.fromJson(work('a', remarks: '12集'), home: home).finished,
        isFalse,
      );
      expect(
        ApiVideoItem.fromJson(work('a', remarks: ''), home: home).finished,
        isFalse,
      );
      expect(
        ApiVideoItem.fromJson({
          ...work('a', remarks: '完结'),
          'finished': false,
        }, home: home).finished,
        isFalse,
      );
    },
  );
}
