import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/page/navigation_bar.dart' show MainNativeTabHost;
import 'package:zephyr/page/source_shell/models/source_shell_section.dart';
import 'package:zephyr/page/source_shell/view/source_shell_page.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_library_page.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/widgets/android_glass_plate.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

import '../test_helper.dart';

class _TestSettings extends GlobalSettingCubit {
  void useAutomatic(bool value) =>
      emit(state.copyWith(navigationHidesOnScroll: value));
  void setTransparency(int value) =>
      emit(state.copyWith(navigationTransparency: value));
}

const _mainBar = ValueKey('test-main-tab-bar');
const _content = ValueKey('test-main-scroll-content');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  final platforms = TargetPlatformVariant({
    TargetPlatform.iOS,
    TargetPlatform.android,
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'compact main tabs follow direct vertical intent with stable viewport and bar hit testing',
    (tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = _TestSettings();
      final tabs = PersistentTabController();
      final scroll = ScrollController();
      addTearDown(settings.close);
      addTearDown(tabs.dispose);
      addTearDown(scroll.dispose);
      var bodyTaps = 0;
      var navTaps = 0;
      late BuildContext tabContext;
      await tester.pumpWidget(
        BlocProvider<GlobalSettingCubit>.value(
          value: settings,
          child: MaterialApp(
            home: MainNativeTabHost(
              controller: tabs,
              navBarHeight: 60,
              floatingNavigation: false,
              screens: [
                Builder(
                  builder: (context) {
                    tabContext = context;
                    return ListView.builder(
                      key: _content,
                      controller: scroll,
                      itemExtent: 52,
                      itemCount: 35,
                      itemBuilder: (_, index) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => bodyTaps++,
                        child: Text('Item $index'),
                      ),
                    );
                  },
                ),
                const Center(child: Text('A different tab')),
              ],
              navigation: GestureDetector(
                key: _mainBar,
                behavior: HitTestBehavior.opaque,
                onTap: () => navTaps++,
                child: const ColoredBox(color: Colors.blue),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final list = find.byKey(_content);
      final bar = find.byKey(_mainBar);
      final shownRect = tester.getRect(bar);
      Future<void> drag(Offset offset) async {
        await tester.dragFrom(const Offset(200, 300), offset);
        await tester.pumpAndSettle();
      }

      expect(tester.getRect(list).bottom, shownRect.top);
      await drag(const Offset(0, -140));
      expect(tester.getRect(bar), shownRect);

      settings.useAutomatic(true);
      await tester.pumpAndSettle();
      final viewport = tester.getRect(list);
      final bottomExtent = scroll.position.maxScrollExtent;
      final barElement = tester.element(bar);
      expect(viewport.bottom, 600);
      expect(NativeNavigationInset.of(tester.element(list)), 60);

      await drag(const Offset(-160, 0));
      expect(tester.getRect(bar), shownRect);
      scroll.jumpTo(500);
      await tester.pumpAndSettle();
      expect(tester.getRect(bar), shownRect);

      final finger = await tester.startGesture(const Offset(200, 300));
      await finger.moveBy(const Offset(0, -30));
      await finger.moveBy(const Offset(0, -50));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      expect(tester.getRect(bar).top, inExclusiveRange(shownRect.top, 600));
      await tester.pumpAndSettle();
      expect(tester.getRect(bar).top, 600);
      expect(tester.getRect(list), viewport);
      expect(scroll.position.maxScrollExtent, bottomExtent);
      expect(tester.element(bar), same(barElement));
      expect(bar.hitTestable(), findsNothing);

      await finger.moveBy(const Offset(0, 16));
      await tester.pumpAndSettle();
      expect(tester.getRect(bar), shownRect);
      await finger.up();
      await tester.pumpAndSettle();

      await drag(const Offset(0, -110));
      expect(tester.getRect(bar).top, 600);
      await tester.tapAt(const Offset(200, 570));
      expect(bodyTaps, 1);
      expect(navTaps, 0);

      final route = Navigator.of(tabContext).push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Another page')),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(bar), shownRect);
      Navigator.of(tabContext).pop();
      await tester.pumpAndSettle();
      await route;
      expect(tester.getRect(bar), shownRect);

      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      await drag(const Offset(0, -140));
      expect(tester.getRect(bar), shownRect);

      await drag(const Offset(0, 140));
      await drag(const Offset(0, -100));
      expect(tester.getRect(bar).top, 600);
      tabs.jumpToTab(1);
      await tester.pumpAndSettle();
      expect(find.text('A different tab'), findsOneWidget);
      expect(tester.getRect(bar), shownRect);
      tabs.jumpToTab(0);
      await tester.pumpAndSettle();
      expect(tester.getRect(list), viewport);
      expect(tester.element(bar), same(barElement));

      await drag(const Offset(0, 140));
      await drag(const Offset(0, -110));
      expect(tester.getRect(bar).top, 600);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(tester.getRect(bar), shownRect);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await tester.pumpAndSettle();
      expect(bar.hitTestable(), findsNothing);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(tester.getRect(bar), shownRect);

      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(200, 300), const Offset(0, -140));
      await tester.pump();
      expect(tester.getRect(bar).top, 600);
      settings.useAutomatic(false);
      await tester.pumpAndSettle();
      expect(tester.getRect(bar), shownRect);
      expect(tester.getRect(list).bottom, shownRect.top);
      expect(tester.element(bar), same(barElement));
    },
    variant: platforms,
  );

  testWidgets(
    'source tabs slide their mounted bar while keeping the last action reachable',
    (tester) async {
      const lastAction = 'Action 31';
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = _TestSettings()..useAutomatic(true);
      final style = ValueNotifier('system');
      addTearDown(settings.close);
      addTearDown(style.dispose);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var nativeBarCreations = 0;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create' &&
            (call.arguments as Map)['viewType'] == 'breeze.video.navigation') {
          nativeBarCreations++;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          null,
        ),
      );
      await tester.pumpWidget(
        BlocProvider<GlobalSettingCubit>.value(
          value: settings,
          child: AppInterfaceStyleScope(
            style: style,
            child: MaterialApp(
              home: SourceShellPage(
                source: 'fixture-source',
                sourceName: 'Fixture source',
                sections: [
                  SourceShellSection.more(
                    title: 'Actions',
                    actions: [
                      for (var index = 0; index < 32; index++)
                        SourceShellAction(
                          title: 'Action $index',
                          action: const {},
                        ),
                    ],
                  ),
                  const SourceShellSection(
                    id: 'second',
                    title: 'Second',
                    scene: null,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final nav = find.byType(VideoNativeNavigation);
      final shownRect = tester.getRect(nav);
      final element = tester.element(nav);
      final list = find.byType(ListView).first;
      final viewport = tester.getRect(list);
      final scroll = tester
          .state<ScrollableState>(
            find.descendant(of: list, matching: find.byType(Scrollable)).first,
          )
          .position;
      final reservedBottom = MediaQuery.paddingOf(tester.element(list)).bottom;
      expect(reservedBottom, shownRect.height);
      if (defaultTargetPlatform == TargetPlatform.android) {
        settings.useAutomatic(false);
        settings.setTransparency(50);
        await tester.pumpAndSettle();
        expect(tester.getRect(list), viewport);
        expect(viewport.bottom, greaterThan(shownRect.top));
        expect(
          MediaQuery.paddingOf(tester.element(list)).bottom,
          reservedBottom,
        );
        final plate = tester.widget<AndroidGlassPlate>(
          find.byWidgetPredicate(
            (widget) =>
                widget is AndroidGlassPlate &&
                widget.role == AndroidGlassRole.navigation,
          ),
        );
        expect(plate.androidNavigationTransparency, 50);
        expect(plate.role, AndroidGlassRole.navigation);
        settings.useAutomatic(true);
        await tester.pumpAndSettle();
      }
      await tester.drag(list, const Offset(0, -140));
      await tester.pumpAndSettle();
      expect(tester.getRect(nav).top, 600);
      expect(tester.getRect(list), viewport);
      expect(MediaQuery.paddingOf(tester.element(list)).bottom, reservedBottom);

      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text(lastAction).hitTestable(), findsOneWidget);
      await tester.drag(list, const Offset(0, 55));
      await tester.pumpAndSettle();
      expect(tester.getRect(nav), shownRect);
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text(lastAction)).bottom,
        lessThan(shownRect.top),
      );

      expect(tester.element(nav), same(element));
      expect(
        nativeBarCreations,
        defaultTargetPlatform == TargetPlatform.iOS ? 1 : 0,
      );

      style.value = 'breeze';
      await tester.pumpAndSettle();
      await tester.drag(list, const Offset(0, 130));
      await tester.pumpAndSettle();
      await tester.drag(list, const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(tester.getRect(nav).top, 600);
      expect(tester.getRect(list), viewport);
    },
    variant: platforms,
  );

  testWidgets(
    'standalone API library follows the option and an embedded library defers to its host',
    (tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = _TestSettings()..useAutomatic(true);
      final style = ValueNotifier('breeze');
      addTearDown(settings.close);
      addTearDown(style.dispose);
      final home = Uri.parse('https://video.test/');
      final repository = ApiVideoRepository(
        source: 'scrolling-api-fixture',
        home: home,
        catalogFn: 'catalog',
        detailFn: 'detail',
        playbackFn: 'play',
        capabilities: const ApiVideoCapabilities(
          search: 'none',
          year: false,
          recent: false,
        ),
        pluginCall: (_, _) async => {
          'data': {
            'page': 1,
            'pageCount': 1,
            'total': 30,
            'items': [
              for (var index = 1; index <= 30; index++)
                ApiVideoItem(
                  id: '$index',
                  title: 'Video $index',
                  detailUrl: home.resolve('/video/$index'),
                ).toLibraryJson(),
            ],
          },
        },
      );
      Future<void> show({required bool embedded}) async {
        await tester.pumpWidget(
          BlocProvider<GlobalSettingCubit>.value(
            value: settings,
            child: AppInterfaceStyleScope(
              style: style,
              child: MaterialApp(
                home: ApiVideoLibraryPage(
                  key: ValueKey(embedded),
                  repository: repository,
                  title: 'Video source',
                  embedded: embedded,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show(embedded: false);
      final catalog = find.byType(ApiVideoCollection).first;
      final nav = find.byType(VideoNativeNavigation);
      final shown = tester.getRect(nav);
      expect(find.text('Video 1'), findsOneWidget);
      await tester.drag(catalog, const Offset(0, -150));
      await tester.pumpAndSettle();
      expect(tester.getRect(nav).top, 600);
      await tester.drag(catalog, const Offset(0, 70));
      await tester.pumpAndSettle();
      expect(tester.getRect(nav), shown);

      await show(embedded: true);
      expect(nav, findsNothing);
      expect(find.text('Video 1'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
