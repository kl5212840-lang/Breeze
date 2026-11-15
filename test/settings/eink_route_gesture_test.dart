import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/router/router.dart';
import 'package:zephyr/page/video/video_page_route.dart';
import 'package:zephyr/platform/eink/eink_page_transitions.dart';

void main() {
  testWidgets('instant AutoRoute pages still respond to the iOS back swipe', (
    tester,
  ) async {
    eInkInstantRoutes = true;
    addTearDown(() {
      eInkInstantRoutes = false;
    });
    final router = RootStackRouter.build(
      defaultRouteType: AppRouter().defaultRouteType,
      routes: [
        NamedRouteDef(
          name: 'Root',
          path: '/',
          initial: true,
          builder: (_, _) => const Scaffold(body: Text('Root')),
        ),
        NamedRouteDef(
          name: 'Child',
          path: '/child',
          builder: (_, _) => const Scaffold(body: Text('Child')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router.config(),
        theme: ThemeData(pageTransitionsTheme: einkPageTransitionsTheme),
      ),
    );
    await tester.pumpAndSettle();
    router.pushPath('/child');
    await tester.pumpAndSettle();
    expect(find.text('Child'), findsOneWidget);
    final childRoute = ModalRoute.of(tester.element(find.text('Child')))!;
    expect(childRoute.transitionDuration, Duration.zero);
    expect(childRoute.reverseTransitionDuration, Duration.zero);
    await tester.dragFrom(const Offset(5, 300), const Offset(65, 0));
    await tester.pumpAndSettle();
    expect(find.text('Child'), findsOneWidget);
    await tester.dragFrom(const Offset(5, 300), const Offset(650, 0));
    await tester.pumpAndSettle();
    expect(find.text('Root'), findsOneWidget);
    expect(find.text('Child'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('standalone iOS page preserves the back swipe in e-ink mode', (
    tester,
  ) async {
    eInkInstantRoutes = true;
    addTearDown(() {
      eInkInstantRoutes = false;
    });
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('Root')),
      ),
    );
    final route = videoPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('Player')),
    );
    expect(route.transitionDuration, Duration.zero);
    navigator.currentState!.push(route);
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(5, 300), const Offset(650, 0));
    await tester.pumpAndSettle();
    expect(find.text('Root'), findsOneWidget);
    expect(find.text('Player'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Android instant pages still handle system back', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        theme: ThemeData(
          platform: TargetPlatform.android,
          pageTransitionsTheme: einkPageTransitionsTheme,
        ),
        home: const Scaffold(body: Text('Root')),
      ),
    );
    final route = MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('Child')),
    );
    navigator.currentState!.push(route);
    await tester.pumpAndSettle();
    expect(route.transitionDuration, Duration.zero);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Root'), findsOneWidget);
    expect(find.text('Child'), findsNothing);
  });
}
