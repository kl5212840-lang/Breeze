import 'dart:async';

import 'package:zephyr/page/bookshelf/cubit/search_status.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/bookshelf/widgets/video_bookshelf_pane.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/source_shell/models/source_video_module.dart';
import 'package:zephyr/page/source_shell/view/source_profile_video_records.dart';
import 'package:zephyr/page/video/api_video_library_page.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/source_profile_video_preview.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/widgets/source_choice_menu.dart';

import '../video_local_fixture.dart';

Future<void> _until(WidgetTester tester, bool Function() ready, String reason) async {
  for (var n = 0; n < 180 && !ready(); n++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 8)));
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(ready(), isTrue, reason: reason);
}
Future<T> _drive<T>(WidgetTester tester, Future<T> value) async {
  var done = false;
  T? result;
  Object? failure;
  value.then((value) { result = value; done = true; }, onError: (Object error) { failure = error; done = true; });
  await _until(tester, () => done, 'The real local store read completes while file IO is driven');
  if (failure != null) throw failure!;
  return result as T;
}
SourceProfileVideoPreview _rail(WidgetTester tester, ShelfPageMode mode) => tester.widget<SourceProfileVideoPreview>(
  find.descendant(of: find.byKey(ValueKey('profile-video-${mode.name}')), matching: find.byType(SourceProfileVideoPreview)));
Future<void> _ready(WidgetTester tester) => _until(tester, () {
  final rails = tester.widgetList<SourceProfileVideoPreview>(find.byType(SourceProfileVideoPreview)).toList();
  return rails.length == 3 && rails.every((rail) => !rail.loading && !rail.failed);
}, 'All three source-local rails load without a source API or player');

Future<void> _seed(List<SourceVideoModule> modules) async {
  for (var n = 0; n < modules.length; n++) {
    final module = modules[n], namespace = module.capabilities.itemNamespace;
    final page = module.home.resolve('/videos/${namespace}_same');
    final watch = page.replace(queryParameters: {'line': 'main', 'episode': '1'});
    final item = ApiVideoItem(id: '$namespace:${namespace}_same', title: 'Real long work title ${module.title} 第$n部', detailUrl: page, sourceDuration: '2:05');
    await VideoLibraryStore.shared.setFavorite(module.source, item, true);
    await VideoDownloadedDetails.saveItem(module.source, item);
    await VideoWatchHistory.record(module.source, VideoWatchRecord(watchUrl: watch, title: item.title,
      position: const Duration(seconds: 8), duration: const Duration(seconds: 125), updatedAt: DateTime.utc(2026, 11, n + 1), completed: false));
    final id = VideoLocalResources.identity(module.source, watch, '720p');
    final file = await VideoLocalResources.file(id);
    await file.parent.create(recursive: true);
    await file.writeAsBytes([0, 0, 0, 24, 102, 116, 121, 112, ...List.filled(16, 0)]);
    await VideoLocalResources.saved(resourceId: id, bytes: 24, source: module.source, video: watch, title: item.title, quality: '720p', taskKey: 'task-$namespace', durationMs: 125000);
  }
  await VideoLibraryStore.shared.setFavorite('foreign-source', ApiVideoItem(id: 'movie:foreign', title: 'Foreign source must stay out', detailUrl: modules.first.home.resolve('/videos/foreign')), true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const connectivity = MethodChannel('dev.fluttercommunity.plus/connectivity_status');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() => messenger.setMockMethodCallHandler(connectivity, (_) async => null));
  tearDown(() => messenger.setMockMethodCallHandler(connectivity, null));
  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets('unified video rails and all local queues stay inside the selected module $style $brightness', (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 1100);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final preference = ValueNotifier(style);
        addTearDown(preference.dispose);
        final modules = [
          for (final (namespace, title) in [('movie', '电影'), ('animate', '里番')])
            SourceVideoModule(source: 'profile-record-$style-${brightness.name}', title: title,
              home: Uri.parse('https://$namespace.fixture/'), catalogFn: 'catalogMustNotRun', detailFn: 'detail', playbackFn: 'play',
              capabilities: ApiVideoCapabilities(search: 'none', year: false, recent: false, itemNamespace: namespace)),
        ];
        await tester.runAsync(() async { await useIsolatedVideoResources(); await _seed(modules); });
        try {
          await tester.pumpWidget(AppInterfaceStyleScope(style: preference, child: MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)), child: child!),
            home: Scaffold(body: ListView(children: [SourceProfileVideoRecords(modules: modules)])),
          )));
          await _ready(tester);
          for (final mode in ShelfPageMode.values) {
            expect(_rail(tester, mode).items, hasLength(1));
            expect(_rail(tester, mode).responsivePreview, isTrue);
            expect(_rail(tester, mode).items.single.title, contains('电影'));
          }
          expect(find.byType(ApiVideoLibraryPage), findsNothing, reason: 'Reading previews cannot start a source catalog or player');
          tester.widget<SourceChoiceMenu<String>>(find.byKey(const ValueKey('profile-video-module'))).onChanged!(modules.last.id);
          await tester.pump(); await _ready(tester);
          for (final mode in ShelfPageMode.values) {
            final rail = _rail(tester, mode);
            expect(rail.items, hasLength(1)); expect(rail.items.single.title, contains('里番'));
            final action = find.descendant(of: find.byKey(ValueKey('profile-video-${mode.name}')), matching: find.widgetWithText(TextButton, '查看全部'));
            await tester.ensureVisible(action); await tester.pump();
            expect(action.hitTestable(), findsOneWidget); expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
            await tester.tap(action); await tester.pump(); await tester.pump(const Duration(milliseconds: 600));
            final pageFinder = find.byType(VideoBookshelfPane);
            await _until(tester, () => pageFinder.evaluate().isNotEmpty, 'View all opens the existing local shelf pane');
            final page = tester.widget<VideoBookshelfPane>(pageFinder);
            expect(page.mode, mode); expect(page.search.sources, [modules.last.source]);
            final rows = await _drive(tester, page.dataSource!.load(mode, SearchStatusState(sources: [modules.last.source])));
            expect(rows, hasLength(1));
            expect(rows.single.item.title, contains('里番')); expect(rows.single.item.detailUrl.origin, modules.last.home.origin);
            await _until(tester, () => find.byType(ApiVideoCollection).evaluate().isNotEmpty, 'The scoped data is actually consumed by the visible collection');
            final collection = tester.widget<ApiVideoCollection>(find.byType(ApiVideoCollection));
            expect(collection.items, hasLength(1)); expect(collection.items.single.title, contains('里番'));
            expect(find.byType(VideoNativeNavigation), findsNothing, reason: 'Source records never replace the page with global download navigation');
            Navigator.of(tester.element(pageFinder)).pop(); await tester.pump(); await tester.pump(const Duration(milliseconds: 600));
            await _ready(tester);
          }
          // An explicit history card keeps the exact public episode and uses
          // the existing module/browser/network library shell to open it.
          final history = _rail(tester, ShelfPageMode.history);
          final card = find.byKey(ValueKey('video-preview.${history.identity}.${history.items.single.id}'));
          await tester.ensureVisible(card); await tester.pump();
          expect(CollectionCoverPrivacyScope.contains(tester.element(card)), isTrue);
          await tester.tap(card); await tester.pump(); await tester.pump(const Duration(milliseconds: 600));
          final detail = tester.widget<ApiVideoLibraryPage>(find.byType(ApiVideoLibraryPage));
          expect(detail.repository.home, modules.last.home);
          expect(detail.repository.capabilities.itemNamespace, 'animate');
          expect(detail.bookshelfItem!.id, 'animate:animate_same');
          expect(detail.bookshelfResume, modules.last.home.resolve('/videos/animate_same?line=main&episode=1'));
          Navigator.of(tester.element(find.byType(ApiVideoLibraryPage))).pop();
          await tester.pump(); await tester.pump(const Duration(milliseconds: 600));
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink()); await tester.pump(const Duration(milliseconds: 700));
        }
      });
    }
  }

  testWidgets('same-origin modules require the real namespace rather than moving an unclassified history or file into both queues', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final modules = [for (final namespace in ['movie', 'animate']) SourceVideoModule(source: 'shared-origin', title: namespace,
      home: Uri.parse('https://shared.fixture/$namespace/'), catalogFn: 'catalogMustNotRun', detailFn: 'detail', playbackFn: 'play',
      capabilities: ApiVideoCapabilities(search: 'none', year: false, recent: false, itemNamespace: namespace))];
    await tester.runAsync(() async {
      await useIsolatedVideoResources();
      await _seed(modules);
      // This old public page has no module namespace proof. Sharing an origin
      // must not silently assign its history or managed file to either module.
      final page = Uri.parse('https://shared.fixture/videos/unclassified');
      final watch = page.replace(queryParameters: {'line': 'main', 'episode': '1'});
      await VideoLibraryStore.shared.setFavorite('shared-origin', ApiVideoItem(id: 'unclassified', title: 'Unclassified stays outside both modules', detailUrl: page), true);
      await VideoWatchHistory.record('shared-origin', VideoWatchRecord(watchUrl: watch, title: 'Unclassified stays outside both modules', position: const Duration(seconds: 8), duration: const Duration(seconds: 125), updatedAt: DateTime.utc(2026, 11, 3), completed: false));
      final id = VideoLocalResources.identity('shared-origin', watch, '720p');
      final file = await VideoLocalResources.file(id);
      await file.parent.create(recursive: true);
      await file.writeAsBytes([0, 0, 0, 24, 102, 116, 121, 112, ...List.filled(16, 0)]);
      await VideoLocalResources.saved(resourceId: id, bytes: 24, source: 'shared-origin', video: watch, title: 'Unclassified stays outside both modules', quality: '720p', taskKey: 'task-unclassified', durationMs: 125000);
    });
    try {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: ListView(children: [SourceProfileVideoRecords(modules: modules)]))));
      await _ready(tester);
      for (final mode in ShelfPageMode.values) expect(_rail(tester, mode).items.single.title, contains('movie'));
      tester.widget<SourceChoiceMenu<String>>(find.byKey(const ValueKey('profile-video-module'))).onChanged!(modules.last.id);
      await tester.pump(); await _ready(tester);
      for (final mode in ShelfPageMode.values) {
        expect(_rail(tester, mode).items, hasLength(1)); expect(_rail(tester, mode).items.single.title, contains('animate'));
      }
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink()); await tester.pump(const Duration(milliseconds: 700));
    }
  });
}
