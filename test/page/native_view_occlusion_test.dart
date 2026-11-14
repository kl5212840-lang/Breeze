import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/search/widget/search_field_surface.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/widgets/native_view_occlusion.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var creates = 0;
  setUp(() {
    creates = 0;
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') creates++;
      return null;
    });
  });
  tearDown(
    () =>
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null),
  );

  Widget source() => Scaffold(
    body: Stack(
      children: [
        const Positioned(
          left: 0,
          top: 140,
          width: 180,
          height: 48,
          child: SearchFieldSurface(child: Text('source')),
        ),
        Positioned(
          left: 300,
          top: 100,
          child: SourceChromeIconButton(
            icon: Icons.settings,
            symbol: 'gearshape',
            tooltip: 'source control',
            onPressed: () {},
          ),
        ),
      ],
    ),
  );

  int platformLayers(WidgetTester tester) {
    var count = 0;
    void visit(Layer layer) {
      if (layer is PlatformViewLayer) count++;
      if (layer is ContainerLayer) {
        var child = layer.firstChild;
        while (child != null) {
          visit(child);
          child = child.nextSibling;
        }
      }
    }

    visit(tester.binding.renderViews.single.debugLayer!);
    return count;
  }

  Future<void> run(
    WidgetTester tester, {
    bool nested = false,
    Brightness brightness = Brightness.light,
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        navigatorKey: navigator,
        navigatorObservers: [
          NativeCompositionObserver(
                  geometryBasedOcclusion: true,
            candidateRoutes: const {
              '/': {'candidate'},
            },
          ),
        ],
        home: nested
            ? Navigator(
                onGenerateRoute: (_) =>
                    MaterialPageRoute(builder: (_) => source()),
              )
            : source(),
      ),
    );
    await tester.pumpAndSettle();
    final states = tester
        .stateList(find.byType(UiKitView, skipOffstage: false))
        .toList();
    expect(states, hasLength(2));
    expect(platformLayers(tester), 2);
    final target = MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'candidate'),
      builder: (_) => const Scaffold(
        key: ValueKey('cover'),
        body: Text('opaque destination'),
      ),
    );
    navigator.currentState!.push(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    final cover = tester.getRect(find.byKey(const ValueKey('cover')));
    expect(cover.left, greaterThan(0));
    expect(cover.left, lessThan(100));
    // The wide search capsule is still partly visible at the leading edge;
    // only the completely covered source control leaves the paint scene.
    expect(platformLayers(tester), 1);
    expect(
      tester.stateList(find.byType(UiKitView, skipOffstage: false)),
      orderedEquals(states),
    );
    expect(creates, 2);
    // Reverse before completing the push, then return. The same views repaint.
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(platformLayers(tester), 2);
    expect(tester.stateList(find.byType(UiKitView)), orderedEquals(states));
    expect(creates, 2);
    // A translucent modal must retain the material below its barrier.
    showDialog<void>(
      context: navigator.currentContext!,
      builder: (_) => const AlertDialog(content: Text('dialog')),
    );
    await tester.pumpAndSettle();
    expect(platformLayers(tester), 2);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    navigator.currentState!.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'candidate'),
        builder: (_) => const Scaffold(body: Text('gesture destination')),
      ),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(const Offset(5, 300));
    await gesture.moveBy(
      const Offset(120, 0),
      timeStamp: const Duration(milliseconds: 100),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(
      const Offset(-110, 0),
      timeStamp: const Duration(milliseconds: 200),
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('gesture destination'), findsOneWidget);
    expect(
      tester.stateList(find.byType(UiKitView, skipOffstage: false)),
      orderedEquals(states),
    );
    expect(creates, 2);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(platformLayers(tester), 2);

    navigator.currentState!.push(
      PageRouteBuilder<void>(
        settings: const RouteSettings(name: 'candidate'),
        opaque: true,
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, _, _) =>
            const Scaffold(body: Text('fading destination')),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    expect(
      platformLayers(tester),
      2,
      reason: 'a translucent transition must not hide native material',
    );
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(platformLayers(tester), 2);
    expect(tester.takeException(), isNull);
  }

  testWidgets(
    'opaque slide culls covered paint and preserves partial native material',
    (tester) => run(tester),
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  testWidgets(
    'nested navigator native controls respect a root opaque slide',
    (tester) => run(tester, nested: true),
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  testWidgets(
    'dark system material keeps the same occlusion and return behavior',
    (tester) => run(tester, brightness: Brightness.dark),
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  for (final brightness in Brightness.values) {
    testWidgets(
      'Breeze $brightness retains its layout and controls on return',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final style = ValueNotifier('breeze');
        addTearDown(style.dispose);
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: style,
            child: MaterialApp(
              theme: ThemeData(brightness: brightness),
              navigatorKey: navigator,
              navigatorObservers: [
                NativeCompositionObserver(
                  geometryBasedOcclusion: true,
                  candidateRoutes: const {
                    '/': {'candidate'},
                  },
                ),
              ],
              home: source(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final control = tester.getRect(find.byType(SourceChromeIconButton));
        final field = tester.getRect(find.byType(SearchFieldSurface));
        expect(control.size, const Size(44, 44));
        expect(find.byType(UiKitView, skipOffstage: false), findsNothing);
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('destination')),
          ),
        );
        await tester.pumpAndSettle();
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byType(SourceChromeIconButton)), control);
        expect(tester.getRect(find.byType(SearchFieldSurface)), field);
        expect(find.byType(UiKitView, skipOffstage: false), findsNothing);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
}
