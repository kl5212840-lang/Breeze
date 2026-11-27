import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:zephyr/page/navigation_bar.dart' as app;
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_navigation_bar.dart';
import 'package:zephyr/widgets/native_material_surface.dart';
import 'package:zephyr/widgets/breeze_theme_colors.dart';

const _destinations = [
  NavigationDestination(icon: Icon(Icons.explore_outlined), label: '发现'),
  NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: '书架'),
  NavigationDestination(icon: Icon(Icons.download_outlined), label: '下载'),
  NavigationDestination(icon: Icon(Icons.more_horiz_rounded), label: '更多'),
];

class _Page extends StatefulWidget {
  const _Page(this.name);
  final String name;
  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  final scroll = ScrollController();
  int count = 0;
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      key: ValueKey('list-${widget.name}'),
      controller: scroll,
      children: [
        TextButton(
          onPressed: () => setState(() => count++),
          child: Text('${widget.name}:$count'),
        ),
        for (var i = 0; i < 40; i++) ListTile(title: Text('${widget.name}-$i')),
      ],
    ),
  );
}

void main() {
  testWidgets(
    'Android System navigation floats above all five tabs and reserves its inset once',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 52, bottom: 24);
      tester.view.viewPadding = const FakeViewPadding(top: 52, bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetViewInsets);
      final controller = PersistentTabController();
      addTearDown(controller.dispose);
      const labels = ['发现', '书架', '追更', '下载', '更多'];
      const bodyKey = ValueKey('nav-body');

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final height = VideoNativeNavigation.androidFloatingHeightOf(
                context,
              );
              final media = MediaQuery.of(context);
              return app.MainNativeTabHost(
                controller: controller,
                floatingNavigation: true,
                navBarHeight: height,
                screens: [
                  for (final label in labels)
                    Builder(
                      builder: (context) => Scaffold(
                        body: ListView(
                          key: bodyKey,
                          padding: EdgeInsets.only(
                            bottom: NativeNavigationInset.scrollBottom(context),
                          ),
                          children: [
                            for (var i = 0; i < 32; i++)
                              ListTile(title: Text('$label-$i')),
                          ],
                        ),
                      ),
                    ),
                ],
                navigation: MediaQuery(
                  data: media,
                  child: VideoNativeNavigation(
                    items: [
                      for (final label in labels)
                        BottomNavigationBarItem(
                          icon: label == '追更'
                              ? const Badge(
                                  label: Text('4'),
                                  child: Icon(Icons.notifications),
                                )
                              : const Icon(Icons.home),
                          label: label,
                        ),
                    ],
                    symbols: const [],
                    currentIndex: controller.index,
                    onTap: controller.jumpToTab,
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final shell = find.byType(NativeMaterialSurface);
      final list = find.byKey(bodyKey).hitTestable();
      final nav = find.byType(VideoNativeNavigation);
      final destinations = find.byType(BreezeNavigationTab);
      final selection = find.byKey(
        const ValueKey('android-navigation-selection'),
      );
      expect(shell, findsOneWidget);
      expect(tester.widget<NativeMaterialSurface>(shell).androidGlass, isTrue);
      expect(tester.widget<NativeMaterialSurface>(shell).floating, isTrue);
      expect(
        find.descendant(of: shell, matching: find.byType(BackdropFilter)),
        findsNothing,
      );
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationDestination), findsNothing);
      expect(selection, findsOneWidget);
      final secondDestination = destinations.at(1);
      final destinationInk = find.descendant(
        of: secondDestination,
        matching: find.byWidgetPredicate((widget) => widget is InkResponse),
      );
      final ink = tester.widget<InkResponse>(destinationInk);
      expect(ink.splashFactory, NoSplash.splashFactory);
      expect(ink.highlightColor, Colors.transparent);
      expect(ink.focusColor!.a, greaterThan(0));
      final interrupted = await tester.startGesture(
        tester.getCenter(secondDestination),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.index, 0);
      await interrupted.cancel();
      await tester.pumpAndSettle();
      expect(controller.index, 0);
      expect(tester.getRect(shell), const Rect.fromLTRB(12, 732, 378, 812));
      expect(tester.getRect(list).bottom, 844);
      expect(NativeNavigationInset.of(tester.element(list)), 112);
      expect(find.text('4'), findsOneWidget);
      for (final (index, label) in labels.indexed) {
        final tab = find.descendant(of: nav, matching: find.text(label));
        expect(tab, findsOneWidget);
        final target = tester.getRect(destinations.at(index));
        expect(target.top, tester.getRect(shell).top);
        expect(target.bottom, tester.getRect(shell).bottom);
        await tester.tap(tab);
        await tester.pumpAndSettle();
        expect(tester.widget<VideoNativeNavigation>(nav).currentIndex, index);
        final plate = tester.getRect(selection);
        expect(plate.left, closeTo(target.left + 4, .01));
        expect(plate.right, closeTo(target.right - 4, .01));
        expect(plate.top, target.top + 5);
        expect(plate.bottom, target.bottom - 5);
        expect(plate.contains(tester.getCenter(tab)), isTrue);
        expect(find.text('$label-0').hitTestable(), findsOneWidget);
      }

      final scrollable = find.descendant(
        of: list,
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      final last = find.text('更多-31');
      expect(last.hitTestable(), findsOneWidget);
      expect(tester.getRect(last).bottom, lessThan(tester.getRect(shell).top));

      tester.view.padding = const FakeViewPadding(top: 52, bottom: 48);
      tester.view.viewPadding = const FakeViewPadding(top: 52, bottom: 48);
      await tester.pumpAndSettle();
      expect(tester.getRect(shell).bottom, 788);
      expect(NativeNavigationInset.of(tester.element(list)), 136);
      expect(tester.getRect(list).bottom, 844);

      tester.view.padding = const FakeViewPadding(top: 52);
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pumpAndSettle();
      expect(shell.hitTestable(), findsNothing);
      expect(NativeNavigationInset.of(tester.element(list)), 0);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'Android back respects tab modals and folder history before returning to Discover',
    (tester) async {
      final controller = PersistentTabController(initialIndex: 1);
      addTearDown(controller.dispose);
      var rootsReached = 0;
      var folderOpen = false;
      var dismissals = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: app.MainNativeTabHost(
            controller: controller,
            screens: [
              const Scaffold(body: Text('Discover')),
              StatefulBuilder(
                builder: (context, setState) => Scaffold(
                  body: Column(
                    children: [
                      Text(folderOpen ? 'Folder' : 'Bookshelf'),
                      TextButton(
                        onPressed: () {
                          ModalRoute.of(context)!.addLocalHistoryEntry(
                            LocalHistoryEntry(
                              onRemove: () =>
                                  setState(() => folderOpen = false),
                            ),
                          );
                          setState(() => folderOpen = true);
                        },
                        child: const Text('Open folder'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => StatefulBuilder(
                              builder: (context, setState) => PopScope(
                                canPop: dismissals != 0,
                                onPopInvokedWithResult: (didPop, _) {
                                  if (!didPop) setState(() => dismissals++);
                                },
                                child: Scaffold(
                                  body: Text(
                                    dismissals == 0
                                        ? 'Detail menu open'
                                        : 'Detail menu closed',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        child: const Text('Open work'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            navBarHeight: 64,
            floatingNavigation: false,
            navigation: const SizedBox(height: 64),
            onAndroidRootBack: () async {
              rootsReached++;
              controller.jumpToTab(0);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open folder'));
      await tester.pump();
      await tester.tap(find.text('Open work'));
      await tester.pumpAndSettle();
      expect(find.text('Detail menu open'), findsOneWidget);

      Future<void> backTo(String visible) async {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text(visible), findsOneWidget);
      }

      await backTo('Detail menu closed');
      await backTo('Folder');
      await backTo('Bookshelf');
      expect(controller.index, 1);
      expect(rootsReached, 0);
      await backTo('Discover');
      expect(rootsReached, 1);
      expect(controller.index, 0);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'style changes retain tab state, scroller and nested navigation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = PersistentTabController();
      final style = ValueNotifier('breeze');
      addTearDown(controller.dispose);
      addTearDown(style.dispose);
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: style,
          child: MaterialApp(
            home: ListenableBuilder(
              listenable: Listenable.merge([style, controller]),
              builder: (context, _) {
                final floating = style.value == 'system';
                return app.MainNativeTabHost(
                  controller: controller,
                  screens: const [
                    _Page('发现'),
                    _Page('书架'),
                    _Page('下载'),
                    _Page('更多'),
                  ],
                  navBarHeight: floating ? 84 : 64,
                  floatingNavigation: floating,
                  navigation: floating
                      ? const SizedBox(height: 84)
                      : BreezeNavigationBar(
                          contentHeight: 64,
                          destinations: _destinations,
                          selectedIndex: controller.index,
                          onSelected: controller.jumpToTab,
                        ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('发现:0'));
      await tester.pump();
      final state = tester.state<_PageState>(find.byType(_Page).first);
      await tester.drag(
        find.byKey(const ValueKey('list-发现')),
        const Offset(0, -320),
      );
      await tester.pumpAndSettle();
      final offset = state.scroll.offset;
      expect(offset, greaterThan(0));
      expect(
        NativeNavigationInset.of(tester.element(find.byType(_Page).first)),
        0,
      );
      style.value = 'system';
      await tester.pumpAndSettle();
      expect(tester.state<_PageState>(find.byType(_Page).first), same(state));
      expect(state.count, 1);
      expect(state.scroll.offset, offset);
      expect(
        NativeNavigationInset.of(tester.element(find.byType(_Page).first)),
        84,
      );
      style.value = 'breeze';
      await tester.pumpAndSettle();
      await tester.tap(find.text('下载'));
      await tester.pumpAndSettle();
      final downloadContext = tester.element(find.text('下载:0'));
      final navigator = Navigator.of(downloadContext);
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('下载详情')),
        ),
      );
      await tester.pumpAndSettle();
      style.value = 'system';
      await tester.pumpAndSettle();
      expect(find.text('下载详情'), findsOneWidget);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('下载:0'), findsOneWidget);
      expect(controller.index, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'main tab content, icons and labels switch together on the first frame',
    (tester) async {
      final controller = PersistentTabController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => app.MainNativeTabHost(
              controller: controller,
              screens: const [_Page('发现'), _Page('书架')],
              navBarHeight: 64,
              floatingNavigation: false,
              navigation: BreezeNavigationBar(
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.explore_outlined),
                    selectedIcon: Icon(Icons.explore),
                    label: '发现',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.menu_book_outlined),
                    selectedIcon: Icon(Icons.menu_book),
                    label: '书架',
                  ),
                ],
                selectedIndex: controller.index,
                onSelected: controller.jumpToTab,
                contentHeight: 64,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final bar = find.byType(BreezeNavigationBar);
      Finder label(String name) =>
          find.descendant(of: bar, matching: find.text(name));
      Color? color(String name) =>
          tester.widget<Text>(label(name)).style?.color;
      final first = tester.getRect(label('发现'));
      final next = tester.getRect(label('书架'));
      final selected = color('发现');
      final idle = color('书架');
      Finder icon(IconData glyph) =>
          find.descendant(of: bar, matching: find.byIcon(glyph));
      bool? isSelected(String name) => tester
          .widget<Semantics>(
            find.descendant(
              of: bar,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics && widget.properties.label == name,
              ),
            ),
          )
          .properties
          .selected;

      expect(selected, isNot(idle));
      expect(icon(Icons.explore), findsOneWidget);
      expect(isSelected('发现'), isTrue);
      expect(isSelected('书架'), isFalse);

      await tester.tap(label('书架'));
      await tester.pump();
      expect(find.text('书架:0'), findsOneWidget);
      expect(color('发现'), idle);
      expect(color('书架'), selected);
      expect(icon(Icons.explore), findsNothing);
      expect(icon(Icons.explore_outlined), findsOneWidget);
      final shelfIcon = icon(Icons.menu_book);
      expect(shelfIcon, findsOneWidget);
      expect(icon(Icons.menu_book_outlined), findsNothing);
      expect(IconTheme.of(tester.element(shelfIcon)).color, selected);
      expect(isSelected('发现'), isFalse);
      expect(isSelected('书架'), isTrue);
      expect(tester.getRect(label('发现')), first);
      expect(tester.getRect(label('书架')), next);

      await tester.tap(label('发现'));
      await tester.pump();
      expect(find.text('发现:0'), findsOneWidget);
      expect(icon(Icons.explore), findsOneWidget);
      expect(isSelected('发现'), isTrue);
      expect(color('发现'), selected);
      expect(color('书架'), idle);
      expect(tester.getRect(label('发现')), first);
      expect(tester.getRect(label('书架')), next);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('distant main tab taps only emphasize the actual endpoints', (
    tester,
  ) async {
    final controller = PersistentTabController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => app.MainNativeTabHost(
              controller: controller,
              screens: const [
                _Page('发现'),
                _Page('书架'),
                _Page('下载'),
                _Page('更多'),
              ],
              navBarHeight: 64,
              floatingNavigation: false,
              navigation: BreezeNavigationBar(
                destinations: _destinations,
                selectedIndex: controller.index,
                onSelected: controller.jumpToTab,
                contentHeight: 64,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final bar = find.byType(BreezeNavigationBar);
    Finder label(String name) =>
        find.descendant(of: bar, matching: find.text(name));
    Color? color(String name) => tester.widget<Text>(label(name)).style?.color;
    final initial = tester.getRect(label('发现'));
    final destination = tester.getRect(label('更多'));
    final selected = color('发现');
    final idle = color('更多');
    expect(initial.center.dx, greaterThan(destination.center.dx));
    final shelfIdle = color('书架');
    final downloadsIdle = color('下载');

    await tester.tap(label('更多'));
    await tester.pump();
    expect(find.text('更多:0').hitTestable(), findsOneWidget);
    expect(color('更多'), selected);
    expect(color('发现'), idle);
    expect(color('书架'), shelfIdle);
    expect(color('下载'), downloadsIdle);
    await tester.tap(label('发现'));
    await tester.pump();
    expect(find.text('发现:0').hitTestable(), findsOneWidget);
    expect(color('发现'), selected);
    expect(color('更多'), idle);
    expect(tester.getRect(label('发现')), initial);
    expect(tester.getRect(label('更多')), destination);
  });

  for (final direction in TextDirection.values) {
    for (final reduceMotion in [false, true]) {
      testWidgets('segment drag previews and commits once in $direction '
          '(reduced motion $reduceMotion)', (tester) async {
        final selected = ValueNotifier('list');
        addTearDown(selected.dispose);
        final changes = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: direction,
              child: MediaQuery(
                data: MediaQueryData(disableAnimations: reduceMotion),
                child: Scaffold(
                  body: ListView(
                    children: [
                      Center(
                        child: SizedBox(
                          width: 240,
                          child: ValueListenableBuilder(
                            valueListenable: selected,
                            builder: (context, value, _) =>
                                BreezeSectionSelector(
                                  options: const {
                                    'list': 'List',
                                    'grid': 'Grid',
                                  },
                                  selected: value,
                                  dragEnabled: true,
                                  onSelected: (value) {
                                    changes.add(value);
                                    selected.value = value;
                                  },
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 1000),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        final plate = find.byKey(const ValueKey('breeze.selection.plate'));
        final list = tester.getCenter(find.text('List'));
        final grid = tester.getCenter(find.text('Grid'));
        final initial = tester.getCenter(plate);
        final gridward = Offset.lerp(list, grid, .77)!;

        Future<TestGesture> preview() async {
          final drag = await tester.startGesture(list);
          await drag.moveTo(Offset.lerp(list, grid, .35)!);
          await drag.moveTo(gridward);
          await tester.pump();
          expect(changes, isEmpty);
          expect(selected.value, 'list');
          if (reduceMotion) {
            expect(tester.getCenter(plate), initial);
          } else {
            expect(tester.getCenter(plate).dx, closeTo(gridward.dx, 2));
          }
          return drag;
        }

        final cancelled = await preview();
        await cancelled.cancel();
        await tester.pumpAndSettle();
        expect(tester.getCenter(plate), initial);
        expect(changes, isEmpty);

        final accepted = await preview();
        await accepted.up();
        await tester.pump();
        expect(changes, ['grid']);
        expect(selected.value, 'grid');
        await tester.pumpAndSettle();
        expect(tester.getCenter(plate).dx, closeTo(grid.dx, .01));
        expect(tester.getCenter(find.text('Grid')), grid);
        expect(tester.getCenter(find.text('List')), list);
        await tester.dragFrom(grid, const Offset(0, -160));
        await tester.pumpAndSettle();
        final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
        expect(scroll.position.pixels, greaterThan(0));
        expect(changes, ['grid']);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final brightness in Brightness.values) {
    for (final seed in [const Color(0xff1257ba), const Color(0xff935492)]) {
      testWidgets(
        'semantic colors and large-text touch layout $brightness $seed',
        (tester) async {
          tester.view.physicalSize = const Size(320, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final palette = BreezeThemeColors.fromSeed(seed, brightness);
          var selected = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(colorScheme: palette),
              home: Scaffold(
                body: MediaQuery(
                  data: const MediaQueryData(
                    size: Size(320, 700),
                    padding: EdgeInsets.only(bottom: 34),
                    textScaler: TextScaler.linear(2),
                  ),
                  child: StatefulBuilder(
                    builder: (context, update) => Column(
                      children: [
                        BreezeSectionSelector(
                          options: const {0: '进行中', 1: '已完成', 2: '未完成'},
                          selected: selected,
                          onSelected: (value) => update(() => selected = value),
                        ),
                        const Spacer(),
                        BreezeNavigationBar(
                          destinations: _destinations,
                          selectedIndex: selected,
                          onSelected: (value) => update(() => selected = value),
                          contentHeight: BreezeNavigationBar.contentHeightOf(
                            context,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final navigation = find.byType(BreezeNavigationBar);
          final bars = find.descendant(
            of: navigation,
            matching: find.byType(Material),
          );
          expect(
            tester.widget<Material>(bars.first).color,
            isNot(palette.surfaceContainerLowest),
          );
          expect(
            BreezeThemeColors.contrast(
              tester.widget<Material>(bars.first).color!,
              palette.surface,
            ),
            inInclusiveRange(1.015, 1.3),
          );
          expect(
            find.descendant(
              of: navigation,
              matching: find.byKey(const ValueKey('breeze.selection.plate')),
            ),
            findsNothing,
          );
          double contrast(Color a, Color b) {
            final x = a.computeLuminance() + .05;
            final y = b.computeLuminance() + .05;
            return x > y ? x / y : y / x;
          }

          final activeText = find.descendant(
            of: navigation,
            matching: find.text('发现'),
          );
          final activeColor = tester.widget<Text>(activeText).style!.color!;
          expect(
            contrast(activeColor, palette.surfaceContainerLowest),
            greaterThanOrEqualTo(4.5),
          );
          final shelf = find.descendant(
            of: navigation,
            matching: find.text('书架'),
          );
          final idleColor = tester.widget<Text>(shelf).style!.color!;
          final shelfRect = tester.getRect(shelf);
          final tabButtons = find.descendant(
            of: navigation,
            matching: find.byType(InkWell),
          );
          for (var index = 0; index < _destinations.length; index++) {
            final size = tester.getSize(tabButtons.at(index));
            expect(size.width, greaterThanOrEqualTo(44));
            expect(size.height, greaterThanOrEqualTo(44));
          }
          for (final label in ['进行中', '已完成', '未完成']) {
            expect(
              tester.getSize(find.widgetWithText(TextButton, label)).height,
              greaterThanOrEqualTo(44),
            );
          }
          final segment = find.widgetWithText(TextButton, '已完成');
          final segmentLabel = find.text('已完成');
          final plate = find.byKey(const ValueKey('breeze.selection.plate'));
          final initialPlate = tester.getRect(plate);
          final initialButton = tester.getRect(segment);
          final initialLabel = tester.getCenter(segmentLabel);

          void expectTransparentPress() {
            final style = tester.widget<TextButton>(segment).style!;
            const pressed = {WidgetState.pressed};
            expect(style.backgroundColor?.resolve(pressed), Colors.transparent);
            expect(style.overlayColor?.resolve(pressed), Colors.transparent);
          }

          final held = await tester.startGesture(initialLabel);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 70));
          expectTransparentPress();
          expect(
            tester.getCenter(segmentLabel).dy,
            closeTo(initialLabel.dy + .6, .01),
          );
          expect(tester.getRect(segment), initialButton);
          expect(tester.getRect(plate), initialPlate);
          expect(selected, 0);
          await held.cancel();
          await tester.pumpAndSettle();
          expect(tester.getCenter(segmentLabel), initialLabel);
          expect(tester.getRect(plate), initialPlate);
          expect(selected, 0);

          await tester.tap(segment);
          await tester.pump();
          expect(selected, 1);
          await tester.pump(const Duration(milliseconds: 60));
          expectTransparentPress();
          expect(tester.getRect(plate).left, greaterThan(initialPlate.left));
          expect(tester.getRect(plate).left, lessThan(initialButton.left));
          await tester.pumpAndSettle();
          expect(tester.widget<Text>(shelf).style!.color, activeColor);
          expect(tester.widget<Text>(activeText).style!.color, idleColor);
          expect(tester.getRect(shelf), shelfRect);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
