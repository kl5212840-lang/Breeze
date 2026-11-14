import 'dart:async';

import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/native_video_page.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/video_page_route.dart';
import 'package:zephyr/page/video/video_playback_quick_panel.dart';
import 'package:zephyr/widgets/native_material_surface.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

class _InlinePlatform extends VideoPlayerPlatform {
  final sources = <DataSource>[];
  final events = <int, StreamController<VideoEvent>>{};
  int disposals = 0;
  int pauses = 0;
  @override
  Future<void> init() async {}
  @override
  Future<void> setMixWithOthers(bool value) async {}
  @override
  Future<int?> create(DataSource source) async {
    sources.add(source);
    final id = sources.length;
    final stream = StreamController<VideoEvent>.broadcast();
    events[id] = stream;
    Timer.run(() {
      if (!stream.isClosed) {
        stream.add(
          VideoEvent(
            eventType: VideoEventType.initialized,
            duration: const Duration(minutes: 2),
            size: const Size(1920, 1080),
          ),
        );
      }
    });
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int id) => events[id]!.stream;
  @override
  Widget buildView(int id) => const ColoredBox(color: Colors.black);
  @override
  Future<void> dispose(int id) async {
    disposals++;
    await events.remove(id)?.close();
  }

  @override
  Future<void> setLooping(int id, bool value) async {}
  @override
  Future<void> setVolume(int id, double value) async {}
  @override
  Future<void> setPlaybackSpeed(int id, double value) async {}
  @override
  Future<void> play(int id) async {}
  @override
  Future<void> pause(int id) async {
    pauses++;
  }

  @override
  Future<void> seekTo(int id, Duration value) async {}
  @override
  Future<Duration> getPosition(int id) async => Duration.zero;
}

List<Layer> _leaves(Layer layer) {
  if (layer is ContainerLayer) {
    final children = <Layer>[];
    var child = layer.firstChild;
    while (child != null) {
      children.addAll(_leaves(child));
      child = child.nextSibling;
    }
    return children;
  }
  return layer is PictureLayer || layer is PlatformViewLayer ? [layer] : [];
}

RenderUiKitView _nativeRender(WidgetTester tester, Finder control) {
  final views = <RenderUiKitView>[];
  void visit(RenderObject render) {
    if (render is RenderUiKitView) views.add(render);
    render.visitChildren(visit);
  }

  visit(
    tester.renderObject(
      find.descendant(of: control, matching: find.byType(UiKitView)),
    ),
  );
  expect(views, hasLength(1));
  return views.single;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'inline body paints before one real native player, retaining geometry, hit regions and lifetime through rotation and edge cancellation',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'breeze.video.defaults.controlsStyle': 'system',
        'breeze.video.defaults.recordHistory': false,
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(440, 956);
      final previous = VideoPlayerPlatform.instance;
      final platform = _InlinePlatform();
      VideoPlayerPlatform.instance = platform;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final channels = <int, MethodChannel>{};
      messenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (_) async => null,
      );
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final args = call.arguments as Map;
          final id = args['id'] as int;
          final channel = MethodChannel('${args['viewType']}.$id');
          channels[id] = channel;
          messenger.setMockMethodCallHandler(channel, (_) async => null);
        }
        return null;
      });
      final style = ValueNotifier('system');
      final scale = ValueNotifier(1.0);
      final rightNotch = ValueNotifier(false);
      final bodyKey = GlobalKey();
      var bodyTaps = 0;
      final session = NativePlaybackSession(
        title: 'Inline composition fixture',
        watchUrl: Uri.parse('https://inline-fixture.test/watch?v=42'),
        sources: [
          NativePlaybackSource(
            url: Uri.parse('https://inline-fixture.test/video.mp4'),
            label: '720p',
            headers: const {},
          ),
        ],
        description: 'Local fixture body',
        tags: const [],
      );
      Future<void> frames([bool Function()? done]) async {
        for (var i = 0; i < 50; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump(const Duration(milliseconds: 16));
          if (done == null || done()) return;
        }
        expect(done!(), isTrue);
      }

      void expectPaintOrder() {
        final body =
            bodyKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final bodyLeaves = _leaves(body.debugLayer!);
        final scene = _leaves(tester.binding.renderViews.single.debugLayer!);
        final native = find.descendant(
          of: find.byKey(const ValueKey('video-gesture-surface')),
          matching: find.byType(UiKitView),
        );
        final ids = native.evaluate().map((element) {
          final views = <RenderUiKitView>[];
          void visit(RenderObject node) {
            if (node is RenderUiKitView) views.add(node);
            node.visitChildren(visit);
          }

          visit(element.findRenderObject()!);
          return views.single.viewController.id;
        }).toSet();
        final nativeIndices = [
          for (var i = 0; i < scene.length; i++)
            if (scene[i] is PlatformViewLayer &&
                ids.contains((scene[i] as PlatformViewLayer).viewId))
              i,
        ];
        expect(bodyLeaves.whereType<PictureLayer>(), isNotEmpty);
        expect(nativeIndices, isNotEmpty);
        for (final layer in bodyLeaves) {
          expect(
            scene.indexOf(layer),
            inInclusiveRange(0, nativeIndices.first - 1),
            reason:
                'Every actual detail pixel layer must precede the player native views',
          );
        }
      }

      Future<void> nativePress(Finder control) async {
        expect(control.hitTestable(), findsOneWidget);
        final id = _nativeRender(tester, control).viewController.id;
        await messenger.handlePlatformMessage(
          channels[id]!.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('press'),
          ),
          (_) {},
        );
        await tester.pump();
      }

      try {
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: style,
            child: MaterialApp(
              builder: (context, child) => ListenableBuilder(
                listenable: Listenable.merge([scale, rightNotch]),
                builder: (context, _) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    padding: EdgeInsets.only(top: 60, bottom: 34,
                      right: rightNotch.value ? 44 : 0),
                    viewPadding: EdgeInsets.only(top: 60, bottom: 34,
                      right: rightNotch.value ? 44 : 0),
                    textScaler: TextScaler.linear(scale.value),
                  ),
                  child: child!,
                ),
              ),
              onGenerateRoute: (_) => videoPageRoute<void>(
                builder: (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      key: const ValueKey('open-inline'),
                      onPressed: () => Navigator.of(context).push(
                        videoPageRoute<void>(
                          settings: const RouteSettings(
                            name: omoVideoDetailRouteName,
                          ),
                          builder: (_) => NativeVideoPage(
                            session: session,
                            detailBuilder: (_, _, _, _, _) => RepaintBoundary(
                              key: bodyKey,
                              child: ColoredBox(
                                color: Colors.purple,
                                child: Center(
                                  child: TextButton(
                                    key: const ValueKey('inline-body-action'),
                                    onPressed: () {
                                      bodyTaps++;
                                    },
                                    child: const Text('Body action'),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('open-inline')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await frames(() => find.byType(Slider).evaluate().isNotEmpty);
        final surface = find.byKey(const ValueKey('video-gesture-surface'));
        // The real UIKit branch sends its tooltip to the native control rather
        // than creating a Flutter Tooltip widget. Select that public host.
        final back = find.byWidgetPredicate(
          (widget) =>
              widget is NativeVideoIconButton &&
              widget.tooltip == t.common.back,
        );
        expect(back, findsOneWidget);
        final backNative = find.descendant(
          of: back,
          matching: find.byType(UiKitView),
        );
        await frames(
          () => backNative.evaluate().isNotEmpty && channels.isNotEmpty,
        );
        final backState = tester.state(backNative);
        final backId = _nativeRender(tester, back).viewController.id;
        expect(tester.getRect(surface), const Rect.fromLTWH(0, 60, 440, 247.5));
        expect(
          tester.getRect(find.byKey(const ValueKey('inline-body-action'))).top,
          greaterThanOrEqualTo(307.5),
        );
        expect(tester.getSize(back), const Size(44, 44));
        expect(
          tester.getRect(surface).contains(tester.getCenter(back)),
          isTrue,
        );
        expectPaintOrder();
        await tester.tap(find.byKey(const ValueKey('inline-body-action')));
        await tester.pump();
        expect(
          bodyTaps,
          1,
          reason: 'Last-painted player does not intercept detail hit regions',
        );
        final toggle = tester.getTopLeft(surface) + const Offset(180, 70);
        // The real surface supports double tap. A single tap is delivered only
        // after the recognizer's deadline, then its 180ms fade can complete.
        // Keep both gestures enabled rather than bypassing the surface callback.
        await tester.tapAt(toggle);
        await tester.pump(kDoubleTapTimeout);
        await tester.pump(const Duration(milliseconds: 200));
        expect(back.hitTestable(), findsNothing);
        await tester.tapAt(toggle);
        await tester.pump(kDoubleTapTimeout);
        await tester.pump(const Duration(milliseconds: 200));
        expect(back.hitTestable(), findsOneWidget);
        expect(tester.state(backNative), same(backState));
        scale.value = 2;
        tester.view.physicalSize = const Size(956, 440);
        await tester.pump();
        await frames();
        expect(tester.getRect(surface), Rect.fromLTWH(0, 60, 956 * 3 / 5, 346));
        expect(
          tester.getRect(find.byKey(const ValueKey('inline-body-action'))).left,
          greaterThanOrEqualTo(956 * 3 / 5),
        );
        expect(tester.getSize(back), const Size(44, 44));
        expect(_nativeRender(tester, back).viewController.id, backId);
        expect(tester.state(backNative), same(backState));
        expect(platform.sources, hasLength(1));
        expect(platform.disposals, 0);
        expectPaintOrder();
        expect(
          tester.takeException(),
          isNull,
          reason:
              'Large text inline landscape remains in the existing 3:2 safe viewport',
        );
        // Exercise the actual NativePage overlay, not just a bare selection
        // panel. Functional blocks avoid the notch; the shared depth reaches
        // the physical edge without an opaque full-height rectangle.
        rightNotch.value = true;
        await tester.pump();
        await frames();
        await nativePress(find.byWidgetPredicate((widget) =>
          widget is NativeVideoIconButton && widget.tooltip == t.videoPlayback.playbackSettings));
        await frames(() => find.byType(VideoPlaybackQuickPanel).evaluate().isNotEmpty);
        await tester.pump(const Duration(milliseconds: 300));
        final quick = find.byType(VideoPlaybackQuickPanel);
        final material = find.descendant(of: quick, matching: find.byType(NativeMaterialSurface)).first;
        final nativeMaterial = find.descendant(of: material,
          matching: find.byWidgetPredicate((widget) => widget is UiKitView &&
            widget.viewType == 'breeze.search.surface'));
        await frames(() => nativeMaterial.evaluate().isNotEmpty);
        expect(tester.getRect(quick).right, closeTo(956, .01));
        expect(tester.getRect(material).right, closeTo(956 - 44, .01));
        expect(tester.getRect(nativeMaterial).right, closeTo(956 - 44, .01));
        expect(tester.getRect(find.byKey(const ValueKey('video-panel.side-depth'))).right, closeTo(956, .01));
        final nativePaintBoxes = <RenderUiKitView>[];
        void visitSurface(RenderObject render) {
          if (render is RenderUiKitView) nativePaintBoxes.add(render);
          render.visitChildren(visitSurface);
        }
        visitSurface(tester.renderObject(nativeMaterial));
        expect(nativePaintBoxes, hasLength(1));
        final nativeBox = nativePaintBoxes.single;
        expect(nativeBox.localToGlobal(Offset(nativeBox.size.width, 0)).dx,
          closeTo(956 - 44, .01));
        expect(platform.sources, hasLength(1));
        expect(platform.disposals, 0);
        await tester.tap(find.descendant(of: quick,
          matching: find.byTooltip(t.common.close)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(VideoPlaybackQuickPanel), findsNothing);
        rightNotch.value = false;
        tester.view.physicalSize = const Size(440, 956);
        scale.value = 1;
        await tester.pump();
        await frames();
        expectPaintOrder();
        // Use the real Cupertino route edge recognizer, not a replacement route.
        final gesture = await tester.startGesture(const Offset(1, 500));
        await gesture.moveBy(const Offset(80, 0));
        await tester.pump(const Duration(milliseconds: 100));
        await gesture.moveBy(const Offset(40, 0));
        await tester.pump(const Duration(milliseconds: 100));
        final route = ModalRoute.of(
          tester.element(find.byType(NativeVideoPage)),
        )!;
        expect(route.popGestureInProgress, isTrue);
        expect(
          tester.getRect(surface).left,
          greaterThan(0),
          reason:
              'The actual route must move before this is a gesture cancellation check',
        );
        await tester.pump(const Duration(milliseconds: 200));
        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        expect(find.byType(NativeVideoPage), findsOneWidget);
        expect(tester.getRect(surface), const Rect.fromLTWH(0, 60, 440, 247.5));
        expect(platform.sources, hasLength(1));
        expect(platform.disposals, 0);
        expect(tester.state(backNative), same(backState));
        expectPaintOrder();
        await nativePress(back);
        await tester.pump(const Duration(milliseconds: 700));
        await frames(() => platform.disposals == 1);
        expect(find.byType(NativeVideoPage), findsNothing);
        expect(find.byKey(const ValueKey('open-inline')), findsOneWidget);
        expect(platform.sources, hasLength(1));
        expect(platform.disposals, 1);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 700));
        VideoPlayerPlatform.instance = previous;
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (final channel in channels.values) {
          messenger.setMockMethodCallHandler(channel, null);
        }
        style.dispose();
        scale.dispose();
        rightNotch.dispose();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
