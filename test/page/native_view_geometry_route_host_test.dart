import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:zephyr/page/navigation_bar.dart' show MainNativeTabHost;
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/widgets/native_view_occlusion.dart';

Set<int> _scene(WidgetTester tester) {
  final result = <int>{};
  void visit(Layer layer) {
    if (layer is PlatformViewLayer) result.add(layer.viewId);
    if (layer is ContainerLayer) {
      var child = layer.firstChild;
      while (child != null) { visit(child); child = child.nextSibling; }
    }
  }
  visit(tester.binding.renderViews.single.debugLayer!);
  return result;
}

Widget _button(String label) => SourceChromeIconButton(
  icon: Icons.star, symbol: 'star', tooltip: label, onPressed: () {},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real main tab observers cover plain pages, rebuilds and cancelled back while keeping tabs independent', (tester) async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final channels = <MethodChannel>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
      if (call.method == 'create') {
        final args = call.arguments as Map;
        final channel = MethodChannel('${args['viewType']}.${args['id']}');
        channels.add(channel);
        messenger.setMockMethodCallHandler(channel, (_) async => null);
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (final channel in channels) { messenger.setMockMethodCallHandler(channel, null); }
    });
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final root = GlobalKey<NavigatorState>();
    final controller = PersistentTabController();
    addTearDown(controller.dispose);
    final rebuild = ValueNotifier(0);
    addTearDown(rebuild.dispose);
    final tabNavigators = <int, NavigatorState>{};
    Widget screen(int index) => Builder(builder: (context) {
      tabNavigators[index] = Navigator.of(context);
      return Scaffold(body: Stack(children: [Positioned(left: 300, top: 100, child: _button('tab $index'))]));
    });
    final screens = [screen(0), screen(1)];
    await tester.pumpWidget(MaterialApp(navigatorKey: root, navigatorObservers: [NativeCompositionObserver(geometryBasedOcclusion: true)], home: ValueListenableBuilder<int>(valueListenable: rebuild, builder: (_, value, _) => MainNativeTabHost(
      controller: controller, screens: screens,
      navBarHeight: 64 + value.toDouble(),
      navigation: Align(alignment: Alignment.centerRight, child: _button('root chrome')),
    ))));
    await tester.pumpAndSettle();
    final original = tester.state(find.byType(UiKitView).first);
    expect(_scene(tester), hasLength(2));
    final tab0 = tabNavigators[0]!;
    tab0.push(CupertinoPageRoute<void>(builder: (_) => const Scaffold(body: Text('plain child'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    expect(_scene(tester), hasLength(1), reason: 'a target with zero native controls must still remove fully covered source paint');
    await tester.pumpAndSettle();
    rebuild.value++;
    await tester.pumpAndSettle();
    expect(tabNavigators[0], same(tab0));
    controller.jumpToTab(1);
    await tester.pumpAndSettle();
    expect(_scene(tester), hasLength(2), reason: 'tab 0 child does not cover tab 1 or root chrome');
    controller.jumpToTab(0);
    await tester.pumpAndSettle();
    expect(find.text('plain child'), findsOneWidget);
    expect(_scene(tester), hasLength(1));
    // Exercise the actual tab Navigator's interactive transition, rather than
    // substituting a root route or a route containing a native destination.
    final cancelledBack = await tester.startGesture(const Offset(5, 300));
    await cancelledBack.moveBy(
      const Offset(240, 0),
      timeStamp: const Duration(milliseconds: 200),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tab0.userGestureInProgress, isTrue);
    await cancelledBack.moveBy(
      const Offset(-235, 0),
      timeStamp: const Duration(milliseconds: 500),
    );
    await cancelledBack.up();
    await tester.pumpAndSettle();
    expect(tab0.userGestureInProgress, isFalse);
    expect(find.text('plain child'), findsOneWidget);
    expect(_scene(tester), hasLength(1),
        reason: 'cancelling nested back restores destination coverage without hiding root chrome');
    expect(tester.state(find.byType(UiKitView, skipOffstage: false).first), same(original));
    tab0.pop();
    await tester.pumpAndSettle();
    expect(_scene(tester), hasLength(2));
    expect(tester.state(find.byType(UiKitView).first), same(original));
    root.currentState!.push(CupertinoPageRoute<void>(builder: (_) => const Scaffold(body: Text('plain root'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    expect(_scene(tester), isEmpty, reason: 'root destination covers both nested content and root native chrome');
    root.currentState!.pop();
    await tester.pumpAndSettle();
    expect(_scene(tester), hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  for (final shape in ['translucent', 'fade', 'rotation']) {
    testWidgets('geometry preserves source material below $shape pages', (tester) async {
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (_) async => null);
      addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform_views, null));
      final navigator = GlobalKey<NavigatorState>();
      final samples = <Map<String, Object?>>[];
      await tester.pumpWidget(MaterialApp(navigatorKey: navigator, navigatorObservers: [NativeCompositionObserver(geometryBasedOcclusion: true, diagnostics: samples.add, diagnosticBudget: 256)], home: Scaffold(body: Center(child: _button('source')))));
      await tester.pumpAndSettle();
      final original = tester.state(find.byType(UiKitView));
      navigator.currentState!.push(PageRouteBuilder<void>(
        opaque: shape != 'translucent',
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, _, _) => const Scaffold(body: Text('destination')),
        transitionsBuilder: (_, animation, _, child) => shape == 'rotation'
            ? Transform.rotate(angle: .2, child: child)
            : FadeTransition(opacity: shape == 'fade' ? animation : const AlwaysStoppedAnimation(.5), child: child),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      expect(_scene(tester), hasLength(1));
      expect(samples.where((sample) => sample['event'] == 'control-paint').any((sample) => const {'covered', 'covered-offscreen', 'partly-visible'}.contains(sample['decision'])), isFalse);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(UiKitView)), same(original));
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }
  for (final rootPush in [false, true]) {
    for (final name in <String?>[null, 'breeze.download.video-work', 'breeze.download.comic-chapters', 'SearchRoute', 'breeze.video.catalog-content']) {
      testWidgets('geometry covers $name root=$rootPush without route admission and preserves target and root ownership', (tester) async {
        final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final channels = <MethodChannel>[];
        var creates = 0;
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
          if (call.method == 'create') {
            creates++;
            final args = call.arguments as Map;
            final channel = MethodChannel('${args['viewType']}.${args['id']}');
            channels.add(channel);
            messenger.setMockMethodCallHandler(channel, (_) async => null);
          }
          return null;
        });
        addTearDown(() {
          messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
          for (final channel in channels) { messenger.setMockMethodCallHandler(channel, null); }
        });
        await tester.binding.setSurfaceSize(const Size(400, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final root = GlobalKey<NavigatorState>(), nested = GlobalKey<NavigatorState>();
        final samples = <Map<String, Object?>>[];
        final observer = NativeCompositionObserver(geometryBasedOcclusion: true, diagnostics: samples.add, diagnosticBudget: 256);
        await tester.pumpWidget(MaterialApp(
          navigatorKey: root,
          navigatorObservers: [observer],
          home: Scaffold(body: Stack(children: [
            Positioned.fill(child: Navigator(key: nested, observers: [NativeCompositionObserver(geometryBasedOcclusion: true)], onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => Scaffold(body: Stack(children: [Positioned(left: 300, top: 100, child: _button('source'))]))))),
            Positioned(left: 300, top: 700, child: _button('root chrome')),
          ])),
        ));
        await tester.pumpAndSettle();
        expect(_scene(tester), hasLength(2));
        final original = tester.stateList(find.byType(UiKitView)).toList();
        final navigator = rootPush ? root : nested;
        navigator.currentState!.push(CupertinoPageRoute<void>(settings: RouteSettings(name: name), builder: (_) => Scaffold(body: Stack(children: [Positioned(left: 200, top: 50, child: _button('target'))]))));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 180));
        expect(_scene(tester), hasLength(rootPush ? 1 : 2), reason: 'covered source leaves the scene while target keeps its native layer; nested navigation cannot hide root chrome');
        expect(samples.any((sample) => sample['event'] == 'control-paint' && sample['decision'] == 'covered'), isTrue);
        expect(observer.candidateRoutes, isEmpty);
        expect(observer.candidateOpaqueDestinations, isEmpty);
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(_scene(tester), hasLength(2));
        expect(tester.stateList(find.byType(UiKitView)), orderedEquals(original));
        expect(creates, 3);
        await tester.pumpWidget(const SizedBox.shrink());
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
    }
  }
}
