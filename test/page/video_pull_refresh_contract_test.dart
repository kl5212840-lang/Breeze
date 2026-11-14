import 'package:zephyr/service/read_recovery.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_favorites.dart';
import 'package:zephyr/page/video/api_video_history.dart';
import 'package:zephyr/page/video/api_video_library_page.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

Future<void> _advanceRefreshFrames(
  WidgetTester tester,
  bool Function() started,
) async {
  for (var frame = 0; frame < 80 && !started(); frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

class _Store extends VideoLibraryStore {
  _Store() : super(deviceId: 'refresh-test', storageKey: 'refresh-test');
  final reads = <Completer<VideoLibrarySnapshot>>[];
  @override
  Future<VideoLibrarySnapshot> read() {
    final gate = Completer<VideoLibrarySnapshot>();
    reads.add(gate);
    return gate.future;
  }
}

Future<void> _mount(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final style = ValueNotifier('breeze');
  addTearDown(style.dispose);
  await tester.pumpWidget(
    AppInterfaceStyleScope(
      style: style,
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'empty local favorites really pull and await a local read; failure stays retryable',
    (tester) async {
      final store = _Store();
      addTearDown(store.dispose);
      await _mount(
        tester,
        ApiVideoFavorites(
          source: 'refresh-test',
          mode: ApiVideoView.grid,
          store: store,
          onOpen: (_) async {},
        ),
      );
      store.reads[0].complete(VideoLibrarySnapshot());
      await tester.pumpAndSettle();
      final scroll = find
          .descendant(
            of: find.byType(RefreshIndicator),
            matching: find.byType(Scrollable),
          )
          .first;
      final position = tester.state<ScrollableState>(scroll).position;
      expect(position.viewportDimension, greaterThan(0));
      expect(position.pixels, position.minScrollExtent);
      expect(position.physics.shouldAcceptUserOffset(position), isTrue);
      await tester.drag(scroll, const Offset(0, 350));
      await _advanceRefreshFrames(tester, () => store.reads.length >= 2);
      expect(
        store.reads,
        hasLength(2),
        reason:
            'The actual drag must read the store; viewport=${position.viewportDimension}, offset=${position.pixels}',
      );
      expect(find.byType(RefreshProgressIndicator), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      store.reads[1].completeError(StateError('local read fixture failed'));
      await tester.pumpAndSettle();
      expect(find.text(t.videoLibrary.favoritesEmpty), findsOneWidget);
      expect(find.text(t.common.refreshRetained), findsOneWidget);
      expect(find.widgetWithText(TextButton, t.common.retry), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, t.common.retry));
      await _advanceRefreshFrames(tester, () => store.reads.length >= 3);
      expect(store.reads, hasLength(3));
      store.reads[2].complete(VideoLibrarySnapshot());
      await tester.pumpAndSettle();
      expect(find.text(t.common.refreshRetained), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'history pull reads the current local record without changing its source or opening a site',
    (tester) async {
      const source = 'local-history-refresh';
      final home = Uri.parse('https://history-refresh.test/');
      VideoWatchRecord record(String id, String title) => VideoWatchRecord(
        watchUrl: home.resolve('/voddetail/$id.html?line=main&episode=1'),
        title: title,
        position: const Duration(minutes: 1),
        duration: const Duration(minutes: 20),
        updatedAt: DateTime.utc(2026, 11, 2),
        completed: false,
      );
      await VideoWatchHistory.record(
        source,
        record('1', 'retained local history'),
      );
      expect(await VideoWatchHistory.read(source), hasLength(1));
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getKeys().singleWhere((key) => key.endsWith(source));
      await _mount(
        tester,
        ApiVideoHistory(
          source: source,
          home: home,
          mode: ApiVideoView.list,
          onOpen: (_, _) async {},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('retained local history'), findsOneWidget);
      // Persist a fixture directly so the changes notifier cannot refresh for us.
      await prefs.setString(
        key,
        jsonEncode([record('2', 'fresh local history').toJson()]),
      );
      expect(find.text('retained local history'), findsOneWidget);
      final scroll = find
          .descendant(
            of: find.byType(RefreshIndicator),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.drag(scroll, const Offset(0, 350));
      await tester.pumpAndSettle();
      expect(find.text('fresh local history'), findsOneWidget);
      expect(find.text('retained local history'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'catalog refresh keeps its scroll host while detail generation changes',
    (tester) async {
      final gate = Completer<Map<String, dynamic>>();
      final requests = <Map<String, dynamic>>[];
      Map<String, dynamic> page(String year) => {
        'data': {
          'page': 1,
          'pageCount': 1,
          'total': 30,
          'items': [
            for (var i = 0; i < 30; i++)
              {
                'id': '$i',
                'title': 'Catalog $i',
                'detailUrl': 'https://catalog-refresh.test/videos/$i',
                'year': year,
              },
          ],
        },
      };
      final repository = ApiVideoRepository(
        source: 'catalog-refresh-contract',
        home: Uri.parse('https://catalog-refresh.test/'),
        catalogFn: 'list',
        detailFn: 'detail',
        playbackFn: 'play',
        capabilities: const ApiVideoCapabilities(
          search: 'none',
          year: false,
          recent: false,
        ),
        pluginCall: (_, args) async {
          requests.add(args);
          return args['refresh'] == true ? gate.future : page('2025');
        },
      );
      await _mount(
        tester,
        ApiVideoLibraryPage(repository: repository, title: 'Catalog fixture'),
      );
      await tester.pumpAndSettle();
      final collection = find.byType(ApiVideoCollection).first;
      final element = tester.element(collection);
      final scroll = find
          .descendant(of: collection, matching: find.byType(Scrollable))
          .first;
      final position = tester.state<ScrollableState>(scroll).position;
      position.jumpTo(250);
      await tester.pump();
      final pending = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator).first)
          .onRefresh();
      await tester.pump();
      expect(tester.element(collection), same(element));
      expect(position.pixels, closeTo(250, 1));
      expect(requests.last['refresh'], isTrue);
      gate.complete(page('2026'));
      await pending;
      await tester.pumpAndSettle();
      expect(tester.element(collection), same(element));
      expect(position.pixels, closeTo(250, 1));
      expect(
        tester.widget<ApiVideoCollection>(collection).items.first.year,
        '2026',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'API catalog pauses failed reads during verification and resumes with its query',
    (tester) async {
      final verification = ValueNotifier(false);
      addTearDown(verification.dispose);
      final requests = <Map<String, dynamic>>[];
      final automatic = <bool>[];
      final catalogPaths = <String>[];
      var detailRequests = 0;
      final repository = ApiVideoRepository(
        source: 'catalog-auto-recovery',
        home: Uri.parse('https://catalog-recovery.test/'),
        browserRecoveryAllowed: () => !verification.value,
        browserRecoveryActivity: verification,
        catalogFn: 'list',
        detailFn: 'detail',
        playbackFn: 'play',
        capabilities: const ApiVideoCapabilities(
          search: 'none',
          year: false,
          recent: false,
        ),
        pluginCall: (path, args) async {
          if (path == 'detail') {
            detailRequests++;
            return {
              'data': {
                'id': 'restored',
                'title': 'Restored catalog',
                'detailUrl': 'https://catalog-recovery.test/videos/restored',
              },
            };
          }
          catalogPaths.add(path);
          requests.add(args);
          automatic.add(isAutomaticReadRecovery);
          if (requests.length == 1) throw StateError('connection reset');
          return {
            'data': {
              'page': 1,
              'pageCount': 1,
              'total': 1,
              'items': [
                {
                  'id': 'restored',
                  'title': 'Restored catalog',
                  'detailUrl': 'https://catalog-recovery.test/videos/restored',
                },
              ],
            },
          };
        },
      );
      await _mount(
        tester,
        ApiVideoLibraryPage(
          repository: repository,
          title: 'Recovery fixture',
          initialQuery: 'kept query',
        ),
      );
      await tester.pumpAndSettle();
      expect(requests.length, 1);
      verification.value = true;
      await tester.pump(const Duration(seconds: 55));
      expect(
        requests.length,
        1,
        reason: 'An existing verification must receive no automatic requests',
      );
      expect(
        verification.hasListeners,
        isTrue,
        reason: 'The cloned repository must keep browser activity subscription',
      );
      verification.value = false;
      await tester.pump(Duration.zero);
      await tester.pumpAndSettle();
      expect(requests.length, 2);
      expect(requests.last['query'], 'kept query');
      expect(requests.last['refresh'], isTrue);
      expect(automatic, [false, true]);
      expect(catalogPaths, ['list', 'list']);
      expect(find.text('Restored catalog'), findsWidgets);
      expect(
        detailRequests,
        1,
        reason:
            'The card without a cover receives one existing detail enrichment read',
      );
      await tester.pump(const Duration(seconds: 55));
      expect(
        requests.length,
        2,
        reason: 'Healthy catalog must stop recovery reads',
      );
      expect(
        detailRequests,
        1,
        reason: 'Successful cover enrichment must not poll either',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
