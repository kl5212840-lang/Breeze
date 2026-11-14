import 'package:flutter/rendering.dart';
import 'dart:convert';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/widgets/native_view_occlusion.dart';
import 'package:zephyr/page/video/video_page_route.dart';

class _PaintProbe extends SingleChildRenderObjectWidget {
  const _PaintProbe({required this.onPaint, required super.child});
  final VoidCallback onPaint;
  @override
  RenderObject createRenderObject(BuildContext context) => _ProbeBox(onPaint);
  @override
  void updateRenderObject(BuildContext context, _ProbeBox renderObject) {
    renderObject.onPaint = onPaint;
  }
}

class _ProbeBox extends RenderProxyBox {
  _ProbeBox(this.onPaint);
  VoidCallback onPaint;
  @override
  void paint(PaintingContext context, Offset offset) {
    onPaint();
    super.paint(context, offset);
  }
}

Set<int> _platformViewIds(WidgetTester tester) {
  final ids = <int>{};
  void visit(Layer layer) {
    if (layer is PlatformViewLayer) ids.add(layer.viewId);
    if (layer is ContainerLayer) {
      var child = layer.firstChild;
      while (child != null) {
        visit(child);
        child = child.nextSibling;
      }
    }
  }

  visit(tester.binding.renderViews.single.debugLayer!);
  return ids;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'route-parallax offscreen Back leaves the scene, then returns and keeps ordinary retained scrolling',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final channels = <MethodChannel>[];
      final created = <int>[];
      final samples = <Map<String, Object?>>[];
      final scroll = ScrollController();
      final navigator = GlobalKey<NavigatorState>();
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final args = call.arguments as Map;
          created.add(args['id'] as int);
          final channel = MethodChannel('${args['viewType']}.${args['id']}');
          channels.add(channel);
          messenger.setMockMethodCallHandler(channel, (_) async => null);
        }
        return null;
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 932);
      try {
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            navigatorObservers: [
              NativeCompositionObserver(
                  geometryBasedOcclusion: true,
                candidateOpaqueDestinations: const {omoVideoDetailRouteName},
                diagnostics: samples.add,
                diagnosticBudget: 256,
              ),
            ],
            onGenerateRoute: (_) => CupertinoPageRoute<void>(
              settings: const RouteSettings(name: apiVideoLibraryRouteName),
              builder: (_) => Scaffold(
                body: SingleChildScrollView(
                  controller: scroll,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RepaintBoundary(
                        child: SourceChromeIconButton(
                          key: const ValueKey('source-back'),
                          icon: Icons.arrow_back,
                          symbol: 'chevron.left',
                          tooltip: 'source Back',
                          onPressed: () {},
                        ),
                      ),
                      const SizedBox(height: 1000),
                      RepaintBoundary(
                        child: _PaintProbe(
                          onPaint: () {},
                          child: SizedBox(
                            height: 120,
                            child: SourceChromeIconButton(
                              icon: Icons.settings,
                              symbol: 'gearshape',
                              tooltip: 'retained scrolled action',
                              onPressed: () {},
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
        await tester.pumpAndSettle();
        expect(created, hasLength(2));
        final sourceIds = created.toSet();
        final backId = created.first;
        final backState = tester.state(
          find.descendant(
            of: find.byKey(const ValueKey('source-back')),
            matching: find.byType(UiKitView),
          ),
        );
        navigator.currentState!.push(
          CupertinoPageRoute<void>(
            settings: const RouteSettings(name: omoVideoDetailRouteName),
            builder: (_) => const Scaffold(
              body: SizedBox(
                width: 44,
                height: 44,
                child: UiKitView(viewType: 'breeze.fixture.unwrapped'),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 180));
        final backRect = tester.getRect(
          find.byKey(const ValueKey('source-back'), skipOffstage: false),
        );
        expect(backRect.right, lessThanOrEqualTo(0));
        expect(_platformViewIds(tester), isNot(contains(backId)));
        expect(
          samples.any(
            (sample) =>
                sample['decision'] == 'covered-offscreen' &&
                (sample['platformViews'] as List).contains(backId),
          ),
          isTrue,
        );
        await tester.pumpAndSettle();
        final audits = samples.where(
          (sample) => sample['event'] == 'native-scene-audit',
        );
        expect(
          audits.any(
            (sample) => (sample['mounted'] as List).cast<Map>().any(
              (view) =>
                  view['viewType'] == 'breeze.fixture.unwrapped' &&
                  view['wrapped'] == false,
            ),
          ),
          isTrue,
          reason:
              'The settled native scene audit must include the unwrapped destination. Safe audits: ${jsonEncode(audits.toList())}',
        );
        expect(
          audits.any(
            (sample) => (sample['paintedGeometry'] as List).cast<Map>().any(
              (view) =>
                  (view['rect'] as List).length == 4 &&
                  view['ancestorLayers'] is List,
            ),
          ),
          isTrue,
        );
        final gesture = await tester.startGesture(const Offset(5, 300));
        await gesture.moveBy(
          const Offset(120, 0),
          timeStamp: const Duration(milliseconds: 100),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await gesture.moveBy(
          const Offset(-115, 0),
          timeStamp: const Duration(milliseconds: 300),
        );
        await gesture.up();
        await tester.pumpAndSettle();
        expect(
          navigator.currentState!.canPop(),
          isTrue,
          reason: 'cancelled back gesture retains the destination',
        );
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(_platformViewIds(tester), contains(backId));
        expect(
          tester.state(
            find.descendant(
              of: find.byKey(const ValueKey('source-back')),
              matching: find.byType(UiKitView),
            ),
          ),
          same(backState),
        );
        scroll.jumpTo(600);
        await tester.pumpAndSettle();
        expect(
          _platformViewIds(tester).intersection(sourceIds),
          unorderedEquals(sourceIds),
        );
        scroll.jumpTo(0);
        await tester.pumpAndSettle();
        expect(_platformViewIds(tester), contains(backId));
        expect(created.take(2).toSet(), sourceIds);
        expect(
          created,
          hasLength(3),
          reason: 'source controls were not recreated after cull/return/scroll',
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        scroll.dispose();
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (final channel in channels) {
          messenger.setMockMethodCallHandler(channel, null);
        }
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  testWidgets(
    'initially offscreen native card enters the composed scene through a retained scrolling boundary',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final created = <int>[];
      final channels = <MethodChannel>[];
      final controller = ScrollController();
      var paints = 0;
      const cardKey = ValueKey('retained-native-card');
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final arguments = call.arguments as Map;
          final id = arguments['id'] as int;
          created.add(id);
          final channel = MethodChannel('${arguments['viewType']}.$id');
          channels.add(channel);
          messenger.setMockMethodCallHandler(channel, (_) async => null);
        }
        return null;
      });
      await tester.binding.setSurfaceSize(const Size(400, 800));
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.iOS),
            navigatorObservers: [NativeCompositionObserver()],
            home: Scaffold(
              body: SingleChildScrollView(
                controller: controller,
                clipBehavior: Clip.hardEdge,
                child: Column(
                  children: [
                    const SizedBox(height: 1000),
                    RepaintBoundary(
                      key: cardKey,
                      child: _PaintProbe(
                        onPaint: () => paints++,
                        child: SizedBox(
                          height: 120,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              SourceChromeIconButton(
                                icon: Icons.settings,
                                symbol: 'gearshape',
                                tooltip: 'card settings',
                                onPressed: () {},
                              ),
                              SourceChromeIconButton(
                                icon: Icons.search,
                                symbol: 'magnifyingglass',
                                tooltip: 'card search',
                                onPressed: () {},
                              ),
                              const SizedBox(width: 16),
                            ],
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
        );
        await tester.pumpAndSettle();
        expect(created, hasLength(2));
        final viewport = Offset.zero & const Size(400, 800);
        final initialRect = tester.getRect(find.byKey(cardKey));
        expect(initialRect.top, greaterThanOrEqualTo(viewport.bottom));
        expect(
          paints,
          greaterThan(0),
          reason:
              'The real boundary was painted offscreen before its transform changes; mere widget creation is insufficient.',
        );
        final before = paints;
        final initialIds = _platformViewIds(tester);

        controller.jumpTo(600);
        await tester.pumpAndSettle();
        final visibleRect = tester.getRect(find.byKey(cardKey));
        expect(viewport.contains(visibleRect.topLeft), isTrue);
        expect(
          viewport.contains(visibleRect.bottomRight - const Offset(1, 1)),
          isTrue,
        );
        final visibleIds = _platformViewIds(tester);
        expect(
          visibleIds.intersection(created.toSet()),
          unorderedEquals(created),
          reason:
              'Visible settings/search must have actual PlatformViewLayers. '
              'Initial layers=$initialIds, visible layers=$visibleIds, '
              'boundary paints before=$before after=$paints, bounds=$visibleRect. '
              'A retained empty layer must not remain blank merely because its transform changed.',
        );
        expect(
          created,
          hasLength(2),
          reason:
              'Scrolling must not recreate UIKit controls to repair missing paint.',
        );

        controller.jumpTo(0);
        await tester.pumpAndSettle();
        controller.jumpTo(600);
        await tester.pumpAndSettle();
        expect(
          _platformViewIds(tester).intersection(created.toSet()),
          unorderedEquals(created),
        );
        expect(created, hasLength(2));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (final channel in channels)
          messenger.setMockMethodCallHandler(channel, null);
        await tester.binding.setSurfaceSize(null);
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
