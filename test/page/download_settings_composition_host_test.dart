import 'package:auto_route/auto_route.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/router/router.dart';
import 'package:zephyr/page/donwload_task/service/download_center_resources.dart';
import 'package:zephyr/page/donwload_task/view/download_task.dart';
import 'package:zephyr/page/navigation_bar.dart' show MainNativeTabHost;
import 'package:zephyr/page/setting/download/download_settings_page.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/native_view_occlusion.dart';

import '../download_fixture.dart';
import '../test_helper.dart';

class _DownloadRouteHost extends AppRouter {
  _DownloadRouteHost(this.builder);

  final WidgetBuilder builder;

  @override
  List<AutoRoute> get routes => [
    NamedRouteDef(
      name: 'NavigationBar',
      path: '/',
      initial: true,
      builder: (context, _) => builder(context),
    ),
  ];
}

Map<int, PlatformViewLayer> _scene(WidgetTester tester) {
  final result = <int, PlatformViewLayer>{};
  void visit(Layer layer) {
    if (layer is PlatformViewLayer) result[layer.viewId] = layer;
    if (layer is ContainerLayer) {
      var child = layer.firstChild;
      while (child != null) {
        visit(child);
        child = child.nextSibling;
      }
    }
  }

  visit(tester.binding.renderViews.single.debugLayer!);
  return result;
}

ContainerLayer _firstClip(PlatformViewLayer layer) {
  var ancestor = layer.parent!;
  while (ancestor is! ClipRSuperellipseLayer && ancestor is! ClipRectLayer) {
    ancestor = ancestor.parent!;
  }
  return ancestor;
}

List<RenderUiKitView> _nativeRenders(WidgetTester tester, Finder finder) {
  final result = <RenderUiKitView>[];
  void visit(RenderObject render) {
    if (render is RenderUiKitView) result.add(render);
    render.visitChildren(visit);
  }

  for (final render in tester.renderObjectList(finder)) {
    visit(render);
  }
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await useIsolatedDownloadFixture();
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'nested download menu links root AutoRoute settings and retains target layers during $brightness transitions',
      (tester) async {
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        const capacity = MethodChannel('breeze.download.capacity');
        messenger.setMockMethodCallHandler(capacity, (_) async => 1 << 30);
        addTearDown(() => messenger.setMockMethodCallHandler(capacity, null));
        final channels = <MethodChannel>[];
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
        addTearDown(() {
          messenger.setMockMethodCallHandler(
            SystemChannels.platform_views,
            null,
          );
          for (final channel in channels) {
            messenger.setMockMethodCallHandler(channel, null);
          }
        });
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1;
        const safeArea = FakeViewPadding(top: 62, bottom: 34);
        tester.view.viewPadding = safeArea;
        tester.view.padding = safeArea;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewPadding);
        addTearDown(tester.view.resetPadding);
        final cubit = GlobalSettingCubit()
          ..updateALl(const GlobalSettingState());
        final style = ValueNotifier('system');
        final tabs = PersistentTabController();
        addTearDown(cubit.close);
        addTearDown(style.dispose);
        addTearDown(tabs.dispose);
        late ModalRoute<dynamic> rootSource;
        final router = _DownloadRouteHost((context) {
          rootSource = ModalRoute.of(context)!;
          return MainNativeTabHost(
            controller: tabs,
            screens: const [DownloadTaskPage(embedded: true)],
            navBarHeight: 83,
            navigation: const VideoNativeNavigation(
              items: [
                BottomNavigationBarItem(icon: Icon(Icons.download_outlined)),
              ],
              symbols: ['arrow.down.circle'],
              currentIndex: 0,
              onTap: null,
            ),
          );
        });
        addTearDown(router.dispose);
        final root = router.navigatorKey;
        final samples = <Map<String, Object?>>[];
        await tester.pumpWidget(
          BlocProvider.value(
            value: cubit,
            child: AppInterfaceStyleScope(
              style: style,
              child: MaterialApp.router(
                theme: ThemeData(brightness: brightness),
                routerConfig: router.config(
                  navigatorObservers: () => [
                    NativeCompositionObserver(
                      geometryBasedOcclusion: true,
                      diagnostics: samples.add,
                      diagnosticBudget: 256,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        // Let the actual saved-file read finish before settling route
        // animation. Advancing fake time alone does not service disk I/O.
        var loaded = false;
        Object? loadError;
        DownloadCenterResources.readVideos(waitForStorage: true).then<void>(
          (_) {
            loaded = true;
          },
          onError: (Object error) {
            loadError = error;
            loaded = true;
          },
        );
        final elapsed = Stopwatch()..start();
        while (!loaded && elapsed.elapsed < const Duration(seconds: 5)) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(loaded, isTrue);
        expect(loadError, isNull);
        await tester.pumpAndSettle();
        final sourceRoute = ModalRoute.of(
          tester.element(find.byType(DownloadTaskPage)),
        );
        expect(sourceRoute!.navigator, isNot(same(root.currentState)));
        final sourceViews = tester.stateList(find.byType(UiKitView)).toList();
        final navigation = find.byWidgetPredicate(
          (widget) =>
              widget is UiKitView &&
              widget.viewType == 'breeze.video.navigation',
        );
        final navigationId = _nativeRenders(
          tester,
          navigation,
        ).single.viewController.id;
        expect(_scene(tester).keys, contains(navigationId));
        final more = find.descendant(
          of: find.byKey(const ValueKey('download-more')),
          matching: find.byType(UiKitView),
        );
        final source = tester.widget<UiKitView>(more);
        final sourceId = _nativeRenders(tester, more).single.viewController.id;
        final sourceX = tester.getTopLeft(more).dx;
        final channel = MethodChannel('${source.viewType}.$sourceId');
        Future<void> native(String method, Object? args) =>
            messenger.handlePlatformMessage(
              channel.name,
              const StandardMethodCodec().encodeMethodCall(
                MethodCall(method, args),
              ),
              (_) {},
            );
        await native('menuOpened', {'generation': 1});
        await native('menuClosed', {'generation': 1});
        await native('select', 'download-settings');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 70));
        final target = find.byType(DownloadSettingsPage);
        expect(target, findsOneWidget);
        final targetRoute = ModalRoute.of(tester.element(target))!;
        expect(targetRoute.navigator, same(root.currentState));
        expect(targetRoute.settings.name, 'breeze.download.settings');
        expect(rootSource.secondaryAnimation!.value, greaterThan(0));
        expect(rootSource.secondaryAnimation!.value, lessThan(1));
        expect(tester.getTopLeft(more).dx, lessThan(sourceX));
        void checkSourceClip() {
          final destinationLeft = tester.getTopLeft(target).dx;
          expect(
            tester.getTopRight(navigation).dx,
            greaterThan(destinationLeft),
          );
          final clip = _firstClip(_scene(tester)[navigationId]!);
          final bounds = clip.describeClipBounds()!;
          expect(bounds.width, closeTo(destinationLeft, .01));
          expect(
            bounds.height,
            closeTo(tester.getSize(navigation).height, .01),
          );
          if (const bool.fromEnvironment(
            'BREEZE_DOWNLOAD_COMPOSITION_TRIAL',
            defaultValue: true,
          )) {
            expect(clip, isA<ClipRSuperellipseLayer>());
            final layer = clip as ClipRSuperellipseLayer;
            expect(layer.clipBehavior, Clip.hardEdge);
            expect(
              layer.clipRSuperellipse,
              RSuperellipse.fromRectAndRadius(bounds, Radius.zero),
            );
          } else {
            expect(clip, isA<ClipRectLayer>());
            expect((clip as ClipRectLayer).clipBehavior, Clip.hardEdge);
          }
        }

        checkSourceClip();
        final targetViews = find.descendant(
          of: target,
          matching: find.byType(UiKitView),
        );
        // Back and concurrency are native controls. The other rows use
        // Flutter switches, and completion alerts belong to Notifications.
        expect(targetViews, findsNWidgets(2));
        final identities = tester.stateList(targetViews).toList();
        final ids = _nativeRenders(
          tester,
          targetViews,
        ).map((view) => view.viewController.id).toSet();
        void checkTarget() {
          expect(_scene(tester).keys, containsAll(ids));
          expect(tester.stateList(targetViews), orderedEquals(identities));
          for (final view in _nativeRenders(tester, targetViews)) {
            RenderObject? ancestor = view.parent;
            while (ancestor != null) {
              if (ancestor is RenderClipRRect) {
                expect(ancestor.clipBehavior, Clip.none);
              }
              if (ancestor is RenderClipRSuperellipse) {
                expect(ancestor.clipBehavior, Clip.none);
              }
              if (ancestor is RenderClipOval) {
                expect(ancestor.clipBehavior, Clip.none);
              }
              if (ancestor is RenderClipPath) {
                expect(ancestor.clipBehavior, Clip.none);
              }
              if (ancestor is RenderPhysicalModel) {
                expect(ancestor.clipBehavior, Clip.none);
              }
              if (ancestor is RenderPhysicalShape) {
                expect(ancestor.clipBehavior, Clip.none);
              }
              ancestor = ancestor.parent;
            }
          }
        }

        checkTarget();
        for (var frame = 0; frame < 3; frame++) {
          await tester.pump(const Duration(milliseconds: 70));
          checkTarget();
        }
        await tester.pumpAndSettle();
        checkTarget();
        expect(_scene(tester).keys, isNot(contains(navigationId)));
        expect(
          samples.any(
            (sample) =>
                sample['event'] == 'route-added' &&
                sample['route'] == 'breeze.download.settings',
          ),
          isTrue,
        );
        final gesture = await tester.startGesture(const Offset(5, 350));
        await gesture.moveBy(
          const Offset(22, 0),
          timeStamp: const Duration(milliseconds: 30),
        );
        await gesture.moveBy(
          const Offset(180, 0),
          timeStamp: const Duration(milliseconds: 200),
        );
        await tester.pump(const Duration(milliseconds: 80));
        expect(root.currentState!.userGestureInProgress, isTrue);
        checkTarget();
        checkSourceClip();
        await gesture.moveBy(
          const Offset(-175, 0),
          timeStamp: const Duration(milliseconds: 500),
        );
        await gesture.up();
        await tester.pumpAndSettle();
        checkTarget();
        root.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        checkTarget();
        checkSourceClip();
        await tester.pumpAndSettle();
        expect(target, findsNothing);
        expect(
          tester.stateList(find.byType(UiKitView)),
          orderedEquals(sourceViews),
        );
        expect(_scene(tester).keys, contains(navigationId));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        // Drain the in-flight HLS inventory deadline on the widget test clock.
        await tester.pump(const Duration(seconds: 11));
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
}
