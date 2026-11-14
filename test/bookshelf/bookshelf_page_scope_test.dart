import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worker_manager/worker_manager.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/cubit/plugin_registry_cubit.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/object_box/model.dart' show ComicFolderType;
import 'package:zephyr/page/bookshelf/bloc/folder_shelf_bloc.dart';
import 'package:zephyr/page/bookshelf/cubit/bookshelf_search_cubit.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/bookshelf/service/bookshelf_source_preferences.dart';
import 'package:zephyr/page/bookshelf/service/comic_link_service.dart';
import 'package:zephyr/page/bookshelf/view/bookshelf_page.dart';
import 'package:zephyr/page/bookshelf/widgets/folder_shelf_page.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_content_toolbar.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_scope_controls.dart';
import 'package:zephyr/page/bookshelf/widgets/video_bookshelf_pane.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_navigation_bar.dart';
import 'package:zephyr/widgets/collection_command_icons.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import '../test_helper.dart';

class _ShelfMotionTextApi extends RustLibApi {
  @override
  String crateApiQjsOpenccConvert({
    required String text,
    required String config,
  }) => text;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    debugShelfDbRootPath = TestObjectBoxHelper.tempPath;
    await workerManager.init(isolatesCount: 1);
  });
  tearDownAll(() async {
    await workerManager.dispose();
    debugShelfDbRootPath = null;
    await TestObjectBoxHelper.tearDownTestObjectBox();
  });
  testWidgets(
    'Breeze bookshelf taps keep content stationary while the selected plate retargets',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      RustLib.initMock(api: _ShelfMotionTextApi());
      addTearDown(RustLib.dispose);
      const connectivity = MethodChannel(
        'dev.fluttercommunity.plus/connectivity',
      );
      const connectivityChanges = MethodChannel(
        'dev.fluttercommunity.plus/connectivity_status',
      );
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(connectivity, (_) async => ['none']);
      messenger.setMockMethodCallHandler(
        connectivityChanges,
        (_) async => null,
      );
      addTearDown(() {
        messenger.setMockMethodCallHandler(connectivity, null);
        messenger.setMockMethodCallHandler(connectivityChanges, null);
      });
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const favoriteSource = 'favorite-motion';
      const historySource = 'history-motion';
      final favorite = createTestFavorite('$favoriteSource|1')
        ..source = favoriteSource;
      final history = createTestHistory('$historySource|2')
        ..source = historySource;
      objectbox.unifiedFavoriteBox.put(favorite);
      objectbox.unifiedHistoryBox.put(history);
      final favoriteLink = ComicLinkService.addComic(
        favorite.uniqueKey,
        null,
        ComicFolderType.favorite,
      );
      addTearDown(() {
        objectbox.comicLinkBox.remove(favoriteLink.id);
        objectbox.unifiedFavoriteBox.remove(favorite.id);
        objectbox.unifiedHistoryBox.remove(history.id);
      });
      final style = ValueNotifier('breeze');
      final reduceMotion = ValueNotifier(false);
      addTearDown(style.dispose);
      addTearDown(reduceMotion.dispose);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => GlobalSettingCubit()),
            BlocProvider(create: (_) => PluginRegistryCubit()),
          ],
          child: MaterialApp(
            builder: (context, child) => ValueListenableBuilder(
              valueListenable: reduceMotion,
              builder: (context, reduced, _) => Directionality(
                textDirection: TextDirection.rtl,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    disableAnimations: reduced,
                    textScaler: const TextScaler.linear(2),
                  ),
                  child: child!,
                ),
              ),
            ),
            home: AppInterfaceStyleScope(
              style: style,
              child: const BookshelfPage(),
            ),
          ),
        ),
      );
      final records = find.byKey(const ValueKey('bookshelf.records'));
      final media = find.byWidgetPredicate(
        (widget) =>
            widget is BreezeSectionSelector<String> &&
            widget.options.containsKey('comic'),
      );
      Finder recordLabel(String label) =>
          find.descendant(of: records, matching: find.text(label));
      Finder mediaLabel(String label) =>
          find.descendant(of: media, matching: find.text(label));
      final favoriteTab = recordLabel(t.bookshelf.favorite);
      final historyTab = recordLabel(t.bookshelf.history);
      final recordPlate = find.descendant(
        of: records,
        matching: find.byKey(const ValueKey('breeze.selection.plate')),
      );
      final sourceRail = find.byType(BookshelfSourceNavigation);
      final viewport = find.byType(PageView).hitTestable();
      final favoriteContent = find.byKey(
        const ValueKey('comic-shelf.favorite'),
      );
      final historyContent = find.byKey(const ValueKey('comic-shelf.history'));
      double page() => tester.widget<PageView>(viewport).controller!.page!;
      List<String> sources() =>
          tester.widget<BookshelfSourceNavigation>(sourceRail).selected;
      Future<void> waitFor(Finder finder) async {
        for (var i = 0; i < 80 && finder.evaluate().isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(finder, findsOneWidget);
      }

      await waitFor(find.text(favorite.title));
      await waitFor(
        find.byKey(const ValueKey('bookshelf.source.$historySource')),
      );
      final comicScope = tester
          .element(favoriteContent)
          .read<BookshelfSearchCubit>();
      comicScope.setSources(ShelfPageMode.favorite, [favoriteSource]);
      comicScope.setSources(ShelfPageMode.history, [historySource]);
      await tester.pumpAndSettle();
      expect(sources(), [favoriteSource]);
      final originalPane = tester.element(favoriteContent);
      final viewportRect = tester.getRect(viewport);
      final historyRect = tester.getRect(historyTab);
      final sourceRect = tester.getRect(sourceRail);
      final favoriteCenter = tester.getCenter(favoriteTab).dx;
      double plateProgress() =>
          (tester.getCenter(recordPlate).dx - favoriteCenter) /
          (historyRect.center.dx - favoriteCenter);

      await tester.tap(historyTab);
      await tester.pump();
      expect(page(), 1);
      expect(tester.widget<FolderShelfPage>(historyContent).isActive, isTrue);
      expect(sources(), [historySource]);
      await tester.pump(const Duration(milliseconds: 45));
      expect(page(), 1);
      expect(plateProgress(), inExclusiveRange(0.0, 1.0));
      await tester.pump(const Duration(milliseconds: 135));
      await waitFor(find.text(history.title));

      await tester.tap(favoriteTab);
      await tester.pump();
      expect(page(), 0);
      expect(sources(), [favoriteSource]);
      await tester.pump(const Duration(milliseconds: 48));
      final reversingAt = plateProgress();
      expect(reversingAt, inExclusiveRange(0.0, 1.0));
      expect(page(), 0);
      await tester.tap(historyTab);
      await tester.pump();
      expect(page(), 1);
      expect(sources(), [historySource]);
      await tester.pump(const Duration(milliseconds: 48));
      expect(page(), 1);
      expect(plateProgress(), greaterThan(reversingAt));
      await tester.pumpAndSettle();
      expect(page(), 1);
      expect(plateProgress(), closeTo(1, .02));
      expect(tester.getRect(viewport), viewportRect);
      expect(tester.getRect(historyTab), historyRect);
      expect(tester.getRect(sourceRail), sourceRect);
      final originalHistoryPane = tester.element(historyContent);

      // The wide media switch changes the visible pane without moving either
      // label, even when a press lasts long enough to show its feedback.
      final comicTab = mediaLabel(t.bookshelf.mediaComics);
      final videoTab = mediaLabel(t.bookshelf.mediaVideos);
      final comicButton = find.ancestor(
        of: comicTab,
        matching: find.byType(TextButton),
      );
      final videoButton = find.ancestor(
        of: videoTab,
        matching: find.byType(TextButton),
      );
      final comicRect = tester.getRect(comicButton);
      final videoRect = tester.getRect(videoButton);
      final mediaPlate = find.descendant(
        of: media,
        matching: find.byKey(const ValueKey('breeze.selection.plate')),
      );
      final idleLabel = tester.getRect(videoTab);
      double mediaProgress() =>
          (tester.getCenter(mediaPlate).dx - comicRect.center.dx) /
          (videoRect.center.dx - comicRect.center.dx);
      final cancelled = await tester.startGesture(videoRect.center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.getRect(videoButton), videoRect);
      expect(tester.getRect(videoTab).width, lessThan(idleLabel.width));
      expect(mediaProgress(), closeTo(0, .01));
      await cancelled.cancel();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.getRect(videoTab), idleLabel);
      expect(
        tester.widget<BreezeSectionSelector<String>>(media).selected,
        'comic',
      );

      final accepted = await tester.startGesture(videoRect.center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 48));
      await accepted.up();
      await tester.pump();
      expect(find.byType(VideoBookshelfPane).hitTestable(), findsOneWidget);
      var previous = mediaProgress();
      for (var frame = 0; frame < 12; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        final current = mediaProgress();
        expect(current, greaterThanOrEqualTo(previous));
        expect(current - previous, lessThan(.20));
        expect(tester.getRect(videoButton), videoRect);
        expect(tester.getRect(comicButton), comicRect);
        expect(tester.getRect(viewport), viewportRect);
        previous = current;
      }
      expect(previous, closeTo(1, .01));
      await tester.tap(comicTab);
      await tester.pumpAndSettle();
      expect(tester.element(historyContent), same(originalHistoryPane));

      // Reduce motion must reach the actual pane as well as the segment.
      reduceMotion.value = true;
      await tester.pump();
      await tester.tap(favoriteTab);
      await tester.pump();
      expect(page(), 0);
      expect(plateProgress(), closeTo(0, .02));
      expect(sources(), [favoriteSource]);
      expect(tester.element(favoriteContent), same(originalPane));
      expect(find.text(favorite.title).hitTestable(), findsOneWidget);

      await tester.tap(mediaLabel(t.bookshelf.mediaVideos));
      await tester.pump();
      expect(find.byType(VideoBookshelfPane).hitTestable(), findsOneWidget);
      await tester.tap(mediaLabel(t.bookshelf.mediaComics));
      await tester.pump();
      expect(tester.element(favoriteContent), same(originalPane));
      expect(sources(), [favoriteSource]);

      await tester.dragFrom(
        Offset(viewportRect.left + 32, viewportRect.center.dy),
        const Offset(248, 0),
      );
      await tester.pumpAndSettle();
      expect(page(), 1, reason: 'RTL swipe still changes record scope');
      expect(sources(), [historySource]);
      expect(find.text(history.title).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'bookshelf keeps its main actions aligned in both interface styles',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final style = ValueNotifier('system');
      addTearDown(style.dispose);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (_) async => null,
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          null,
        ),
      );

      final search = find.byKey(const ValueKey('bookshelf.search'));
      final privacy = find.byKey(const ValueKey('bookshelf.cover-privacy'));
      final labels = find.byKey(const ValueKey('bookshelf.sources.manage'));
      final more = find.byKey(const ValueKey('comic-shelf.more'));
      final view = find.byKey(const ValueKey('comic-shelf.view'));
      final filter = find.byKey(const ValueKey('comic-shelf.filter'));
      final toolbar = find.byKey(const ValueKey('bookshelf.main-header'));
      const extent = CollectionToolbarMetrics.actionExtent;
      const trailingCenter =
          CollectionToolbarMetrics.sourceContentInset + extent / 2;

      for (final (width, scale, direction) in [
        (430.0, 1.0, TextDirection.ltr),
        (320.0, 2.0, TextDirection.rtl),
      ]) {
        tester.view.physicalSize = Size(width, 850);
        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => GlobalSettingCubit()),
              BlocProvider(create: (_) => PluginRegistryCubit()),
            ],
            child: MaterialApp(
              builder: (context, child) => Directionality(
                textDirection: direction,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    disableAnimations: true,
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: child!,
                ),
              ),
              home: AppInterfaceStyleScope(
                style: style,
                child: const BookshelfPage(),
              ),
            ),
          ),
        );
        for (
          var attempt = 0;
          more.evaluate().isEmpty && attempt < 40;
          attempt++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)),
          );
          await tester.pump(const Duration(milliseconds: 25));
        }

        for (final mode in ['system', 'breeze']) {
          style.value = mode;
          await tester.pump();
          await tester.pump();
          final expected = direction == TextDirection.ltr
              ? width - trailingCenter
              : trailingCenter;
          for (final action in [search, privacy, labels, more, view, filter]) {
            expect(tester.getSize(action).width, extent);
          }
          for (final (action, offset) in [
            (more, 0),
            (privacy, 1),
            (search, 2),
            (view, 0),
            (filter, 1),
            (labels, 0),
          ]) {
            final directionFactor = direction == TextDirection.ltr ? -1 : 1;
            expect(
              tester.getCenter(action).dx,
              closeTo(expected + directionFactor * offset * extent, .1),
            );
          }
          expect(
            tester.getCenter(view).dy,
            greaterThan(tester.getCenter(more).dy),
          );
          expect(
            tester.getCenter(labels).dy,
            greaterThan(tester.getCenter(view).dy),
          );

          final native = find.descendant(
            of: toolbar,
            matching: find.byType(UiKitView),
          );
          if (mode == 'system') {
            expect(native, findsNWidgets(3));
            for (final element in native.evaluate()) {
              final view = element.widget as UiKitView;
              final arguments = view.creationParams! as Map;
              expect(arguments['bare'], isFalse);
              expect(
                arguments['backgroundInset'],
                VideoControlMetrics.backgroundInset,
              );
              final rect = tester.getRect(find.byWidget(view));
              expect(
                tester.getSize(find.byWidget(view)),
                const Size.square(extent),
              );
              expect(rect.center.dy, closeTo(tester.getCenter(more).dy, .1));
            }
          } else {
            expect(native, findsNothing);
            final glyphs = find.descendant(
              of: toolbar,
              matching: find.byType(CollectionCommandGlyph),
            );
            expect(glyphs, findsNWidgets(3));
            for (final element in glyphs.evaluate()) {
              expect(
                tester.getCenter(find.byWidget(element.widget)).dy,
                closeTo(tester.getCenter(more).dy, .1),
              );
            }
          }
          expect(tester.takeException(), isNull);
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      // Darwin view disposals are queued after the route removes the widget.
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 200));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  testWidgets(
    'real bookshelf shell fits 320 double text and preserves both medium scopes',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'breeze.bookshelf.media.v1': 'video',
      });
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final media = find.byWidgetPredicate(
        (w) =>
            w is NativeVideoSegmentedControl && w.options.containsKey('comic'),
      );
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => GlobalSettingCubit()),
            BlocProvider(create: (_) => PluginRegistryCubit()),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: const BookshelfPage(),
          ),
        ),
      );
      for (final visible in tester.widgetList<NativeVideoSegmentedControl>(
        media,
      )) {
        expect(visible.selected, 'video');
      }
      Future<void> settleLocalReads() async {
        for (var i = 0; i < 6; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)),
          );
          await tester.pump(const Duration(milliseconds: 80));
        }
      }

      await settleLocalReads();
      Future<void> waitFor(bool Function() ready, String stage) async {
        for (var i = 0; i < 100; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          await tester.pump(const Duration(milliseconds: 20));
          if (ready()) return;
        }
        fail('Bookshelf did not reach $stage');
      }

      expect(
        tester.widget<NativeVideoSegmentedControl>(media).selected,
        'video',
      );
      final records = find.byKey(const ValueKey('bookshelf.records'));
      NativeVideoSegmentedControl recordControl() =>
          tester.widget<NativeVideoSegmentedControl>(records);
      final favoriteTab = find.descendant(
        of: records,
        matching: find.text(t.bookshelf.favorite),
      );
      final historyTab = find.descendant(
        of: records,
        matching: find.text(t.bookshelf.history),
      );
      expect(recordControl().selected, 'favorite');
      expect(recordControl().options.keys, ['favorite', 'history']);
      final sourceRail = find.byKey(const ValueKey('bookshelf.sources.scroll'));
      expect(
        tester.getRect(records).bottom,
        lessThanOrEqualTo(tester.getRect(sourceRail).top),
      );
      final largeTextWidth = tester.getSize(records).width;
      expect(largeTextWidth, lessThanOrEqualTo(296));
      tester.view.physicalSize = const Size(800, 740);
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(records).dy,
        closeTo(tester.getCenter(sourceRail).dy, .5),
      );
      expect(
        tester.getRect(records).right,
        lessThanOrEqualTo(tester.getRect(sourceRail).left),
      );
      tester.view.physicalSize = const Size(320, 740);
      await tester.pumpAndSettle();
      BookshelfContentToolbar videoToolbar() =>
          tester.widget<BookshelfContentToolbar>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is BookshelfContentToolbar &&
                  widget.keyPrefix == 'video-shelf',
            ),
          );
      await waitFor(
        () => videoToolbar().canRun?.call() == true,
        'the ready current video toolbar',
      );
      final videoMore = find.byKey(const ValueKey('video-shelf.more'));
      final initialMore = tester.widget<NativeVideoMenu>(videoMore);
      expect(initialMore.options, contains('__sort'));
      expect(initialMore.options, isNot(contains('__sources')));
      final comicCubit = tester
          .element(find.byType(FolderShelfPage, skipOffstage: false).first)
          .read<BookshelfSearchCubit>();
      final videoCubit = tester
          .element(find.byType(VideoBookshelfPane, skipOffstage: false).first)
          .read<BookshelfSearchCubit>();
      final oldSourceManager = tester
          .widget<SourceChromeIconButton>(
            find.byKey(const ValueKey('bookshelf.sources.manage')),
          )
          .onPressed;
      expect(oldSourceManager, isNotNull);
      if (find
          .descendant(of: videoMore, matching: find.byType(UiKitView))
          .evaluate()
          .isNotEmpty) {
        initialMore.onSelected('__sort');
      } else {
        await tester.tap(videoMore);
        await waitFor(
          () => find.text(initialMore.options['__sort']!).evaluate().isNotEmpty,
          'the More sort action',
        );
        // Appearance precedes the menu's completed entrance animation. Its
        // interaction contract intentionally rejects taps during that phase.
        await tester.pumpAndSettle();
        expect(
          videoToolbar().canRun?.call(),
          isTrue,
          reason: 'The current host must accept a menu action after entrance.',
        );
        await tester.tap(find.text(initialMore.options['__sort']!));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('video-host-menu')),
          findsNothing,
          reason:
              'The real sort choice must close its menu before opening the sheet.',
        );
      }
      final recentSort = find.byKey(
        const ValueKey('video-shelf.sort.__sort.dd'),
      );
      final oldSort = find.byKey(const ValueKey('video-shelf.sort.__sort.da'));
      await waitFor(
        () => recentSort.evaluate().isNotEmpty,
        'the compact sort sheet',
      );
      expect(tester.widget<ListTile>(recentSort).selected, isTrue);
      expect(tester.widget<ListTile>(oldSort).selected, isFalse);
      await tester.ensureVisible(oldSort);
      await waitFor(
        () => oldSort.hitTestable().evaluate().isNotEmpty,
        'the tappable old-favorites sort choice',
      );
      await tester.tap(oldSort);
      await waitFor(
        () =>
            videoCubit.state.favorite.sort == 'da' &&
            recentSort.evaluate().isEmpty,
        'the selected video sort',
      );
      await settleLocalReads();
      final oldVideoMenu = tester.widget<NativeVideoMenu>(videoMore).onSelected;
      comicCubit.setKeyword(ShelfPageMode.favorite, '漫画条件');
      comicCubit.setSort(ShelfPageMode.favorite, 'va');
      videoCubit.setKeyword(ShelfPageMode.favorite, '视频条件');
      videoCubit.setSources(ShelfPageMode.favorite, ['retained-video']);
      await tester.pump();
      await tester.tap(find.text(t.bookshelf.mediaComics));
      await settleLocalReads();
      expect(
        tester.widget<NativeVideoSegmentedControl>(media).selected,
        'comic',
      );
      expect(comicCubit.state.favorite.keyword, '漫画条件');
      expect(comicCubit.state.favorite.sort, 'va');
      expect(videoCubit.state.favorite.sort, 'da');
      oldVideoMenu('__sort');
      oldVideoMenu('__sources');
      oldSourceManager!();
      await tester.pump();
      expect(videoCubit.state.favorite.sort, 'da');
      expect(comicCubit.state.favorite.sort, 'va');
      expect(find.byKey(const ValueKey('source-manager.done')), findsNothing);
      expect(recentSort, findsNothing);
      await tester.tap(find.text(t.bookshelf.mediaVideos));
      await settleLocalReads();
      expect(videoCubit.state.favorite.keyword, '视频条件');
      expect(videoCubit.state.favorite.sources, ['retained-video']);
      final favoriteMenu = tester.widget<NativeVideoMenu>(videoMore).onSelected;
      await tester.tap(historyTab);
      await settleLocalReads();
      expect(recordControl().selected, 'history');
      favoriteMenu('__sort');
      favoriteMenu('__sources');
      await tester.pump();
      expect(videoCubit.state.favorite.sort, 'da');
      expect(videoCubit.state.history.sort, 'dd');
      expect(find.byKey(const ValueKey('source-manager.done')), findsNothing);
      expect(recentSort, findsNothing);
      await tester.tap(favoriteTab);
      await settleLocalReads();
      expect(recordControl().selected, 'favorite');
      // Returning to the same scope must not revive actions from before
      // the switch. Native callbacks may arrive after the trigger retired.
      favoriteMenu('__sort');
      await tester.pump();
      expect(recentSort, findsNothing);
      expect(videoCubit.state.favorite.sort, 'da');
      expect(comicCubit.state.favorite.sources, isEmpty);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'breeze.bookshelf.media.v1',
        ),
        'video',
      );
      videoCubit.setSources(ShelfPageMode.history, ['retained-video']);
      videoCubit.setSources(ShelfPageMode.download, ['another-video']);
      await tester.pump();
      final alternateSource = find.byKey(
        const ValueKey('bookshelf.source.another-video'),
      );
      await waitFor(
        () => alternateSource.evaluate().isNotEmpty,
        'the alternate video source',
      );
      final lateSourceSelection = tester
          .widget<NativeVideoTextButton>(alternateSource)
          .onPressed;
      await waitFor(
        () => videoMore.hitTestable().evaluate().isNotEmpty,
        'the active video toolbar',
      );
      final sourceManager = find.byKey(
        const ValueKey('bookshelf.sources.manage'),
      );
      final sourceButton = tester.widget<SourceChromeIconButton>(sourceManager);
      expect(sourceButton.onPressed, isNotNull);
      if (find
          .descendant(of: sourceManager, matching: find.byType(UiKitView))
          .evaluate()
          .isNotEmpty) {
        sourceButton.onPressed!();
      } else {
        await tester.tap(sourceManager);
      }
      await waitFor(
        () => find
            .byKey(const ValueKey('source-manager.done'))
            .evaluate()
            .isNotEmpty,
        'the source manager',
      );
      final coveredRecords = tester.widget<NativeVideoSegmentedControl>(
        find.byKey(const ValueKey('bookshelf.records'), skipOffstage: false),
      );
      expect(coveredRecords.enabled, isFalse);
      expect(coveredRecords.onSelected, isNull);
      lateSourceSelection!();
      expect(videoCubit.state.favorite.sources, ['retained-video']);
      await tester.tap(
        find.byKey(const ValueKey('source-manager.visible.retained-video')),
      );
      await tester.tap(find.byKey(const ValueKey('source-manager.done')));
      await waitFor(
        () =>
            find
                .byKey(const ValueKey('source-manager.done'))
                .evaluate()
                .isEmpty &&
            find
                .byKey(const ValueKey('bookshelf.source.retained-video'))
                .evaluate()
                .isEmpty,
        'saved source visibility',
      );
      expect(videoCubit.state.favorite.sources, isEmpty);
      expect(videoCubit.state.history.sources, isEmpty);
      expect(recordControl().onSelected, isNotNull);
      expect(videoCubit.state.download.sources, ['another-video']);
      expect(videoCubit.state.favorite.keyword, '视频条件');
      expect(comicCubit.state.favorite.keyword, '漫画条件');
      expect(comicCubit.state.favorite.sort, 'va');
      expect(
        find.byKey(const ValueKey('bookshelf.source.retained-video')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('bookshelf.source.')), findsOneWidget);
      expect(
        (await BookshelfSourcePreferenceStore().read(
          BookshelfSourceMedium.video,
        )).hidden,
        {'retained-video'},
      );
      expect(
        (await BookshelfSourcePreferenceStore().read(
          BookshelfSourceMedium.comic,
        )).hidden,
        isEmpty,
      );
      await tester.tap(historyTab);
      await settleLocalReads();
      expect(recordControl().selected, 'history');
      final view = tester.getRect(find.byType(PageView).hitTestable());
      await tester.dragFrom(
        Offset(view.left + 40, view.center.dy),
        const Offset(240, 0),
      );
      await settleLocalReads();
      await tester.pumpAndSettle();
      expect(recordControl().selected, 'favorite');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await settleLocalReads();
      await tester.pump(const Duration(seconds: 5));
    },
  );
}
