import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/cubit/search_status.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/bookshelf/service/video_bookshelf_index.dart';
import 'package:zephyr/page/bookshelf/widgets/video_bookshelf_pane.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_favorites.dart';
import 'package:zephyr/page/video/api_video_history.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

const _source = 'hybrid-local-test';
ApiVideoItem _item(String id, String host, String tag) => ApiVideoItem(
  id: id,
  title: id,
  genres: tag,
  detailUrl: Uri.parse('https://$host/videos/${id.split(':').last}'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const connectivity = MethodChannel('dev.fluttercommunity.plus/connectivity');
  const connectivityChanges = MethodChannel(
    'dev.fluttercommunity.plus/connectivity_status',
  );
  setUp(() {
    messenger.setMockMethodCallHandler(connectivity, (_) async => ['wifi']);
    messenger.setMockMethodCallHandler(connectivityChanges, (_) async => null);
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(connectivity, null);
    messenger.setMockMethodCallHandler(connectivityChanges, null);
  });

  Future<void> waitReads(WidgetTester tester, bool Function() ready) async {
    for (var i = 0; i < 80; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (ready()) return;
    }
    fail('linked record hosts did not refresh');
  }

  Future<T> stored<T extends Object>(
    WidgetTester tester,
    String label,
    Future<T> Function() read,
  ) async => (await tester.runAsync(
    () => read().timeout(
      const Duration(seconds: 5),
      onTimeout: () =>
          throw StateError('$label did not complete in real persistence zone'),
    ),
  ))!;

  final local = find.byKey(const ValueKey('local-record-host'));
  final external = find.byKey(const ValueKey('external-record-host'));
  List<ApiVideoItem> externalItems(WidgetTester tester) => tester
      .widget<ApiVideoCollection>(
        find.descendant(
          of: external,
          matching: find.byType(ApiVideoCollection),
        ),
      )
      .items;

  Future<void> mount(
    WidgetTester tester,
    Widget child,
    ShelfPageMode mode,
  ) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final style = ValueNotifier('breeze');
    addTearDown(style.dispose);
    await tester.pumpWidget(
      AppInterfaceStyleScope(
        style: style,
        child: MaterialApp(
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                body: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        key: const ValueKey('local-record-host'),
                        child: child,
                      ),
                    ),
                    Expanded(
                      child: SizedBox(
                        key: const ValueKey('external-record-host'),
                        child: VideoBookshelfPane(
                          mode: mode,
                          search: const SearchStatusState(sources: [_source]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await waitReads(
      tester,
      () =>
          find
              .descendant(
                of: external,
                matching: find.byType(ApiVideoCollection),
              )
              .evaluate()
              .isNotEmpty &&
          !tester
              .widget<ApiVideoCollection>(
                find.descendant(
                  of: external,
                  matching: find.byType(ApiVideoCollection),
                ),
              )
              .loading,
    );
    await tester.pumpAndSettle();
  }

  Future<void> filterAction(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shelf-option-tags-Action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shelf-filter-apply')));
    await tester.pumpAndSettle();
  }

  Future<void> selectHistoryAction(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const ValueKey('api-history.manage')));
    await tester.pumpAndSettle();
    final option = find.descendant(
      of: find.byKey(const ValueKey('video-host-menu')),
      matching: find.text(label),
    );
    await tester.tap(option.hitTestable());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'flat internal favorites remove visible records from every folder and both hosts refresh without touching another module/source/exports',
    (tester) async {
      final store = VideoLibraryStore.shared;
      late String a, b;
      await stored(tester, 'favorite linked-host fixture', () async {
        SharedPreferences.setMockInitialValues({});
        a = await store.createFolder(_source, 'Outer A');
        b = await store.createFolder(_source, 'Outer B');
        await store.importFavorites(
          _source,
          [_item('movie:One', 'movie.test', 'Action')],
          folderIds: {a, b},
        );
        await store.importFavorites(
          _source,
          [_item('movie:Two', 'movie.test', 'Drama')],
          folderIds: {a},
        );
        await store.importFavorites(_source, [
          _item('animate:One', 'animate.test', 'Action'),
        ]);
        await store.importFavorites('other-source', [
          _item('other:One', 'other.test', 'Action'),
        ]);
        await VideoExportRecords.add(
          source: _source,
          video: Uri.parse('https://movie.test/videos/One'),
          title: 'Export',
          quality: 'HD',
        );
        await VideoBookshelfIndex.load(
          ShelfPageMode.favorite,
          const SearchStatusState(sources: [_source]),
        );
        return true;
      });
      final repository = ApiVideoRepository(
        source: _source,
        home: Uri.parse('https://movie.test'),
        catalogFn: 'catalog',
        detailFn: 'detail',
        playbackFn: 'play',
        capabilities: const ApiVideoCapabilities(itemNamespace: 'movie'),
      );
      await mount(
        tester,
        ApiVideoFavorites(
          source: _source,
          store: store,
          repository: repository,
          mode: ApiVideoView.grid,
          onOpen: (_) async {},
        ),
        ShelfPageMode.favorite,
      );
      expect(externalItems(tester), hasLength(3));
      expect(
        find.descendant(of: local, matching: find.text('Outer A')),
        findsNothing,
      );
      await filterAction(tester, 'local-favorites.filter');
      await tester.longPress(
        find.descendant(of: local, matching: find.text('movie:One')),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: local,
          matching: find.text(t.bookshelf.addToFolder),
        ),
        findsNothing,
      );
      await tester.tap(
        find.descendant(
          of: local,
          matching: find.widgetWithText(
            TextButton,
            t.videoLibrary.removeSelected,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining(t.videoLibrary.localFavoriteRemovalHint),
        findsOneWidget,
      );
      expect(
        Navigator.of(tester.element(find.byType(AlertDialog))),
        same(Navigator.of(tester.element(local), rootNavigator: true)),
      );
      expect(
        Navigator.of(tester.element(local)),
        isNot(same(Navigator.of(tester.element(local), rootNavigator: true))),
      );
      await tester.tap(find.widgetWithText(TextButton, t.common.remove));
      await waitReads(tester, () => externalItems(tester).length == 2);
      var snapshot = await stored(
        tester,
        'favorite snapshot after selected removal',
        store.read,
      );
      expect(snapshot.contains(_source, 'movie:One'), isFalse);
      expect(
        snapshot.foldersOf(VideoLibraryStore.itemKey(_source, 'movie:One')),
        isEmpty,
      );
      expect(snapshot.contains(_source, 'movie:Two'), isTrue);
      expect(snapshot.contains(_source, 'animate:One'), isTrue);
      expect(snapshot.contains('other-source', 'other:One'), isTrue);
      await tester.tap(
        find.byKey(const ValueKey('local-favorites.clear-filter')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('local-favorites.manage')));
      await tester.pumpAndSettle();
      expect(find.text(t.videoSource.manageFolders), findsNothing);
      await tester.tap(find.widgetWithText(ListTile, t.common.clear));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, t.common.remove));
      await waitReads(tester, () => externalItems(tester).length == 1);
      snapshot = await stored(
        tester,
        'favorite snapshot after visible clear',
        store.read,
      );
      expect(snapshot.contains(_source, 'animate:One'), isTrue);
      expect(snapshot.foldersFor(_source).keys, containsAll([a, b]));
      expect(
        await stored(tester, 'export records', VideoExportRecords.read),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'filtered internal history selection and clear delete matching watch identities and resume keys while linked shelf preserves other module/source',
    (tester) async {
      final movieA = Uri.parse(
        'https://movie.test/videos/One?line=1&episode=1',
      );
      final movieB = Uri.parse(
        'https://movie.test/videos/Two?line=1&episode=1',
      );
      final anime = Uri.parse(
        'https://animate.test/videos/One?line=1&episode=1',
      );
      final other = Uri.parse('https://other.test/videos/One?line=1&episode=1');
      await stored(tester, 'history linked-host fixture', () async {
        SharedPreferences.setMockInitialValues({});
        for (final (source, url, tag) in [
          (_source, movieA, 'Action'),
          (_source, movieB, 'Drama'),
          (_source, anime, 'Action'),
          ('other-source', other, 'Action'),
        ]) {
          await VideoWatchHistory.record(
            source,
            VideoWatchRecord(
              watchUrl: url,
              title: url.pathSegments.last,
              position: const Duration(seconds: 30),
              duration: const Duration(minutes: 10),
              updatedAt: DateTime.utc(2026),
              completed: false,
              metadata: {'genres': tag},
            ),
          );
          final preferences = await SharedPreferences.getInstance();
          await preferences.setInt(videoPlaybackProgressKey(url), 30000);
        }
        await VideoLibraryStore.shared.importFavorites(_source, [
          _item('movie:One', 'movie.test', 'Action'),
        ]);
        await VideoBookshelfIndex.load(
          ShelfPageMode.history,
          const SearchStatusState(sources: [_source]),
        );
        return true;
      });
      await mount(
        tester,
        ApiVideoHistory(
          source: _source,
          home: Uri.parse('https://movie.test'),
          itemNamespace: 'movie',
          mode: ApiVideoView.grid,
          onOpen: (_, _) async {},
        ),
        ShelfPageMode.history,
      );
      expect(externalItems(tester), hasLength(3));
      await filterAction(tester, 'api-history.filter');
      await selectHistoryAction(tester, t.videoSource.manage);
      await tester.tap(
        find.descendant(
          of: local,
          matching: find.widgetWithText(TextButton, t.videoLibrary.selectAll),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('api-history.delete-selected')),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining(t.videoLibrary.localHistoryRemovalHint),
        findsOneWidget,
      );
      expect(
        Navigator.of(tester.element(find.byType(AlertDialog))),
        same(Navigator.of(tester.element(local), rootNavigator: true)),
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, t.common.delete),
        ),
      );
      await waitReads(tester, () => externalItems(tester).length == 2);
      final preferences = await stored(
        tester,
        'preferences after history removal',
        SharedPreferences.getInstance,
      );
      expect(
        preferences.containsKey(videoPlaybackProgressKey(movieA)),
        isFalse,
      );
      expect(preferences.getInt(videoPlaybackProgressKey(movieB)), 30000);
      expect(preferences.getInt(videoPlaybackProgressKey(anime)), 30000);
      expect(preferences.getInt(videoPlaybackProgressKey(other)), 30000);
      await tester.tap(find.byKey(const ValueKey('api-history.clear-filter')));
      await tester.pumpAndSettle();
      await selectHistoryAction(tester, t.videoLibrary.clearHistory);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, t.common.delete),
        ),
      );
      await waitReads(tester, () => externalItems(tester).length == 1);
      expect(
        (await stored(
          tester,
          'module history after clear',
          () => VideoWatchHistory.read(_source),
        )).single.watchUrl.origin,
        'https://animate.test',
      );
      expect(
        await stored(
          tester,
          'other source history',
          () => VideoWatchHistory.read('other-source'),
        ),
        hasLength(1),
      );
      expect(
        (await stored(
          tester,
          'favorites after history clear',
          VideoLibraryStore.shared.read,
        )).contains(_source, 'movie:One'),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
