import 'package:zephyr/page/comic_list/cubit/comic_list_cubit.dart';
import 'package:zephyr/page/comic_list/models/comic_list_scene.dart';
import 'package:zephyr/page/old_page/old_home/old_home_page.dart';
import 'package:zephyr/page/old_page/old_ranking/old_ranking_page.dart';
import 'package:zephyr/page/comic_list/view/plugin_paged_comic_list_view.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';
import 'package:zephyr/page/comic_follow/cubit/comic_follow_cubit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worker_manager/worker_manager.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/cubit/plugin_registry_cubit.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/bookshelf/bloc/folder_shelf_bloc.dart';
import 'package:zephyr/page/bookshelf/service/comic_folder_service.dart';
import 'package:zephyr/page/bookshelf/view/bookshelf_page.dart';
import 'package:zephyr/page/bookshelf/widgets/folder_shelf_item.dart';
import 'package:zephyr/page/discover/cubit/discover_cubit.dart';
import 'package:zephyr/page/discover/view/discover_page.dart';
import 'package:zephyr/page/discover/widgets/plugin_card.dart';
import 'package:zephyr/page/discover/widgets/plugin_grid_tile.dart';
import 'package:zephyr/page/more/view/more.dart';
import 'package:zephyr/page/navigation_bar.dart' as app;
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/plugin/models/plugin_runtime_state.dart';
import 'package:zephyr/widgets/tab_reselect_scope.dart';
import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    debugShelfDbRootPath = TestObjectBoxHelper.tempPath;
    await workerManager.init(isolatesCount: 1);
    for (var i = 0; i < 18; i++) {
      ComicFolderService.createFolder('', 'Folder$i', ComicFolderType.favorite);
    }
  });
  tearDownAll(() async {
    await workerManager.dispose();
    debugShelfDbRootPath = null;
    await TestObjectBoxHelper.tearDownTestObjectBox();
  });
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channels = <MethodChannel>[];
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final args = call.arguments as Map;
        final channel = MethodChannel('${args['viewType']}.${args['id']}');
        channels.add(channel);
        messenger.setMockMethodCallHandler(channel, (_) async => null);
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    channels.clear();
  });
  for (final layout in ['list', 'grid']) {
    testWidgets(
      'real main $layout tabs draw behind the island and scroll endings above it',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'discover_plugin_layout_v1': layout,
        });
        tester.view.physicalSize = const Size(390, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = PersistentTabController();
        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => GlobalSettingCubit()),
              BlocProvider(create: (_) => PluginRegistryCubit()),
              BlocProvider(create: (_) => ComicFollowCubit()),
            ],
            child: MaterialApp(
              home: app.MainNativeTabHost(
                controller: controller,
                screens: const [DiscoverPage(), BookshelfPage(), MorePage()],
                navBarHeight: 84,
                navigation: VideoNativeNavigation(
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.explore),
                      label: 'Discover',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.book),
                      label: 'Bookshelf',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.more_horiz),
                      label: 'More',
                    ),
                  ],
                  symbols: const [
                    'safari',
                    'books.vertical',
                    'ellipsis.circle',
                  ],
                  currentIndex: 0,
                  onTap: controller.jumpToTab,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final cubit = tester
            .element(find.byType(DiscoverPage))
            .findRenderObject();
        expect(cubit, isNotNull);
        final discover = tester
            .element(find.byType(CustomScrollView).first)
            .read<DiscoverCubit>();
        final now = DateTime(2026);
        discover.emit(
          DiscoverState(
            plugins: {
              for (var i = 0; i < 18; i++)
                'plugin$i': PluginRuntimeState(
                  uuid: 'plugin$i',
                  version: '1',
                  originScript: '',
                  isEnabled: true,
                  isDeleted: false,
                  debug: false,
                  debugUrl: null,
                  lastLoadSuccess: true,
                  lastLoadError: null,
                  sortOrder: i,
                  insertedAt: now,
                  updatedAt: now,
                  deletedAt: null,
                ),
            },
            infoStates: {
              for (var i = 0; i < 18; i++)
                'plugin$i': DiscoverPluginInfoState(
                  loading: false,
                  data: {'name': 'Plugin$i', 'iconUrl': ''},
                ),
            },
          ),
        );
        await tester.pumpAndSettle();
        final nav = tester.getRect(find.byType(VideoNativeNavigation));
        final viewport = tester.getRect(find.byType(CustomScrollView));
        expect(
          viewport.bottom,
          740,
          reason: 'The real page must paint behind the native island',
        );
        expect(viewport.bottom, greaterThan(nav.top));
        // The dependency itself paints a full-width custom-bar decoration.
        final platform = find.descendant(
          of: find.byType(VideoNativeNavigation),
          matching: find.byType(UiKitView),
        );
        final deck = find
            .ancestor(of: platform, matching: find.byType(DecoratedBox))
            .first;
        expect(
          (tester.widget<DecoratedBox>(deck).decoration as BoxDecoration).color,
          Colors.transparent,
        );
        final scrollable = find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first;
        final lastCard = find.byWidgetPredicate(
          (widget) =>
              widget is PluginCard && widget.pluginState.uuid == 'plugin17' ||
              widget is PluginGridTile && widget.pluginState.uuid == 'plugin17',
        );
        await tester.scrollUntilVisible(lastCard, 350, scrollable: scrollable);
        final scroll = tester.state<ScrollableState>(scrollable).position;
        scroll.jumpTo(scroll.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(tester.getRect(lastCard).bottom, lessThanOrEqualTo(nav.top));
        tester.simulateStatusBarTap();
        await tester.pumpAndSettle();
        expect(scroll.pixels, scroll.minScrollExtent);
        scroll.jumpTo(scroll.maxScrollExtent);

        controller.jumpToTab(1);
        for (var i = 0; i < 8; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)),
          );
          await tester.pump();
        }
        final grid = find.byType(GridView).first;
        expect(tester.getRect(grid).bottom, 740);
        final shelfScroll = find
            .descendant(of: grid, matching: find.byType(Scrollable))
            .first;
        final shelfPosition = tester
            .state<ScrollableState>(shelfScroll)
            .position;
        shelfPosition.jumpTo(shelfPosition.maxScrollExtent);
        await tester.pump();
        final folders = find.byType(FolderShelfItem);
        expect(folders, findsWidgets);
        final lastFolderBottom = folders
            .evaluate()
            .map((e) => tester.getRect(find.byWidget(e.widget)).bottom)
            .reduce((a, b) => a > b ? a : b);
        expect(lastFolderBottom, lessThanOrEqualTo(nav.top));
        tester.simulateStatusBarTap();
        await tester.pumpAndSettle();
        expect(shelfPosition.pixels, shelfPosition.minScrollExtent);
        expect(scroll.pixels, scroll.maxScrollExtent);

        controller.jumpToTab(2);
        await tester.pumpAndSettle();
        final moreList = find.descendant(
          of: find.byType(MorePage),
          matching: find.byType(ListView),
        );
        expect(tester.getRect(moreList).bottom, 740);
        final moreScroll = find
            .descendant(of: moreList, matching: find.byType(Scrollable))
            .first;
        final morePosition = tester.state<ScrollableState>(moreScroll).position;
        morePosition.jumpTo(morePosition.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.widgetWithText(ListTile, t.about.title)).bottom,
          lessThanOrEqualTo(nav.top),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  testWidgets(
    'main reselect and iOS status-bar tap reach only the active eligible root',
    (tester) async {
      final tabs = PersistentTabController();
      final controllers = [ScrollController(), ScrollController()];
      final focus = FocusNode();
      final homes = [GlobalKey(), GlobalKey()];
      final history = LocalHistoryEntry();
      final nativeMenu = Object();
      addTearDown(() {
        TabReselectScope.setBlockingOverlay(nativeMenu, visible: false);
        focus.dispose();
        for (final controller in controllers) {
          controller.dispose();
        }
        tabs.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: app.MainNativeTabHost(
            controller: tabs,
            floatingNavigation: false,
            navBarHeight: 60,
            navigation: Builder(
              builder: (context) => Row(
                children: [
                  for (var i = 0; i < 2; i++)
                    TextButton(
                      onPressed: () {
                        if (tabs.index == i) {
                          app.MainNativeTabHost.requestCurrentTabReselection(
                            context,
                          );
                        } else {
                          tabs.jumpToTab(i);
                        }
                      },
                      child: Text('Tab $i'),
                    ),
                ],
              ),
            ),
            screens: [
              for (var i = 0; i < 2; i++)
                Builder(
                  key: homes[i],
                  builder: (context) => TabReselectListener(
                    onReselect: () =>
                        TabReselectScope.scrollToStart(context, controllers[i]),
                    child: Column(
                      children: [
                        if (i == 0)
                          Material(child: TextField(focusNode: focus)),
                        Expanded(
                          child: ListView.builder(
                            controller: controllers[i],
                            itemExtent: 60,
                            itemCount: 100,
                            itemBuilder: (_, j) => Text('$i - $j'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> tapTab(int i) async {
        await tester.tap(find.text('Tab $i'));
        await tester.pumpAndSettle();
      }

      controllers[0].jumpTo(360);
      await tapTab(1);
      controllers[1].jumpTo(420);
      await tapTab(0);
      tabs.jumpToTab(0);
      await tester.pumpAndSettle();
      expect(controllers[0].offset, 360);
      expect(controllers[1].offset, 420);

      focus.requestFocus();
      await tester.pumpAndSettle();
      tester.simulateStatusBarTap();
      await tester.pumpAndSettle();
      expect(controllers[0].offset, 360);
      expect(focus.hasFocus, isTrue);
      focus.unfocus();
      await tester.pumpAndSettle();

      TabReselectScope.setBlockingOverlay(nativeMenu, visible: true);
      await tapTab(0);
      tester.simulateStatusBarTap();
      await tester.pumpAndSettle();
      expect(controllers[0].offset, 360);
      TabReselectScope.setBlockingOverlay(nativeMenu, visible: false);

      ModalRoute.of(homes[0].currentContext!)!.addLocalHistoryEntry(history);
      await tapTab(0);
      expect(controllers[0].offset, 360);
      history.remove();

      final tabNavigator = Navigator.of(homes[0].currentContext!);
      tabNavigator.push<void>(
        MaterialPageRoute(builder: (_) => const Text('Secondary')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Secondary'), findsOneWidget);
      tester.simulateStatusBarTap();
      await tester.pumpAndSettle();
      expect(controllers[0].offset, 360);
      tabNavigator.pop();
      await tester.pumpAndSettle();

      final rootNavigator = Navigator.of(
        homes[0].currentContext!,
        rootNavigator: true,
      );
      showDialog<void>(
        context: homes[0].currentContext!,
        builder: (_) => const AlertDialog(content: Text('Blocking dialog')),
      );
      await tester.pumpAndSettle();
      tester.simulateStatusBarTap();
      await tester.pumpAndSettle();
      expect(controllers[0].offset, 360);
      rootNavigator.pop();
      await tester.pumpAndSettle();

      await tapTab(0);
      expect(controllers[0].offset, 0);
      expect(controllers[1].offset, 420);
      await tapTab(1);
      tester.simulateStatusBarTap();
      await tester.pump();
      expect(controllers[1].offset, 0);
      expect(controllers[0].offset, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'legacy main tabs keep their scroll endings and source switch above the island',
    (tester) async {
      tester.view.physicalSize = const Size(390, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = PersistentTabController();
      final registry = PluginRegistryCubit();
      final now = DateTime(2026);
      registry.emit({
        for (final id in [
          '0a0e5858-a467-4702-994a-79e608a4589d',
          'bf99008d-010b-4f17-ac7c-61a9b57dc3d9',
        ])
          id: PluginRuntimeState(
            uuid: id,
            version: 'fixture',
            originScript: '',
            isEnabled: true,
            isDeleted: false,
            debug: false,
            debugUrl: null,
            lastLoadSuccess: true,
            lastLoadError: null,
            sortOrder: 0,
            insertedAt: now,
            updatedAt: now,
            deletedAt: null,
          ),
      });
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => GlobalSettingCubit()),
            BlocProvider.value(value: registry),
            BlocProvider(create: (_) => ComicFollowCubit()),
          ],
          child: MaterialApp(
            home: app.MainNativeTabHost(
              controller: controller,
              screens: const [
                OldHomePage(),
                OldRankingPage(),
                BookshelfPage(),
                DiscoverPage(),
                MorePage(),
              ],
              navBarHeight: 84,
              navigation: VideoNativeNavigation(
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.star),
                    label: 'Ranking',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.book),
                    label: 'Bookshelf',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.explore),
                    label: 'Discover',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.more_horiz),
                    label: 'More',
                  ),
                ],
                symbols: const [
                  'house',
                  'chart.bar',
                  'books.vertical',
                  'safari',
                  'ellipsis.circle',
                ],
                currentIndex: 0,
                onTap: controller.jumpToTab,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 500));
      final navTop = tester.getRect(find.byType(VideoNativeNavigation)).top;
      final homeScroll = find.descendant(
        of: find.byType(OldHomePage),
        matching: find.byType(SingleChildScrollView),
      );
      expect(homeScroll, findsOneWidget);
      expect(tester.getRect(homeScroll).bottom, 400);
      final homePosition = tester
          .state<ScrollableState>(
            find
                .descendant(of: homeScroll, matching: find.byType(Scrollable))
                .first,
          )
          .position;
      homePosition.jumpTo(homePosition.maxScrollExtent);
      await tester.pump(const Duration(milliseconds: 500));
      final column = find
          .descendant(of: homeScroll, matching: find.byType(Column))
          .first;
      expect(tester.getRect(column).bottom, lessThanOrEqualTo(navTop));
      expect(
        tester.getRect(find.byType(FloatingActionButton)).bottom,
        lessThanOrEqualTo(navTop),
      );
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump(const Duration(milliseconds: 500));
      final otherHome = find.descendant(
        of: find.byType(OldHomePage),
        matching: find.byType(SingleChildScrollView),
      );
      expect(tester.getRect(otherHome).bottom, 400);
      final otherPosition = tester
          .state<ScrollableState>(
            find
                .descendant(of: otherHome, matching: find.byType(Scrollable))
                .first,
          )
          .position;
      otherPosition.jumpTo(otherPosition.maxScrollExtent);
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester
            .getRect(
              find
                  .descendant(of: otherHome, matching: find.byType(Column))
                  .first,
            )
            .bottom,
        lessThanOrEqualTo(navTop),
      );

      controller.jumpToTab(1);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 500));
      final listContext = tester.element(
        find
            .descendant(
              of: find.byType(OldRankingPage),
              matching: find.byType(AppBar),
            )
            .first,
      );
      final outerList = listContext.read<ComicListCubit>();
      for (final ranking in [false, true]) {
        final feedSource = ranking
            ? 'e9f18928-3ba8-4d86-a12e-b53a62f47933'
            : 'bf99008d-010b-4f17-ac7c-61a9b57dc3d9';
        outerList.emit(
          ComicListState(
            currentFrom: feedSource,
            scene: ComicListScene.fromMap({
              'title': 'Ranking fixture',
              'source': feedSource,
              'body': {
                'type': 'pluginPagedComicList',
                'request': {
                  'fnPath': ranking ? 'getRankingData' : 'getLibrary',
                  'core': {},
                  'extern': {},
                },
              },
            }),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        final paged = find.descendant(
          of: find.byType(OldRankingPage),
          matching: find.byType(PluginPagedComicListView),
        );
        final pagedContext = tester.element(
          find
              .descendant(of: paged, matching: find.byType(CustomScrollView))
              .first,
        );
        pagedContext.read<PluginPagedComicListCubit>().emit(
          PluginPagedComicListState(
            status: PluginPagedComicListStatus.success,
            hasReachedMax: true,
            list: [
              for (var i = 0; i < 12; i++)
                UnifiedComicListItem.fromJson({
                  'source': 'bf99008d-010b-4f17-ac7c-61a9b57dc3d9',
                  'id': 'rank$i',
                  'title': 'Rank$i',
                  'cover': {
                    'id': 'rank$i',
                    'url': '',
                    'path': '',
                    'extern': {},
                  },
                  'metadata': [],
                  'extern': {},
                  'raw': {},
                }),
            ],
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        final rankingScroll = find.descendant(
          of: find.byType(OldRankingPage),
          matching: find.byType(CustomScrollView),
        );
        expect(tester.getRect(rankingScroll).bottom, 400);
        final rankingPosition = tester
            .state<ScrollableState>(
              find
                  .descendant(
                    of: rankingScroll,
                    matching: find.byType(Scrollable),
                  )
                  .first,
            )
            .position;
        rankingPosition.jumpTo(rankingPosition.maxScrollExtent);
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          tester.getRect(find.text(t.oldHome.noMore)).bottom,
          lessThanOrEqualTo(navTop),
        );
        expect(
          tester.getRect(find.byType(FloatingActionButton)).bottom,
          lessThanOrEqualTo(navTop),
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await tester.runAsync(registry.close);
      await tester.pump(const Duration(milliseconds: 200));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
