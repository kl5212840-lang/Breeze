import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/setting/common/setting_page_route.dart';
import 'package:zephyr/page/video/video_page_route.dart';

class _Observer extends NavigatorObserver {
  final pushes = <Route<dynamic>>[];
  final pops = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushes.add(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pops.add(route);
}

class _Parent extends StatefulWidget {
  const _Parent();
  @override
  State<_Parent> createState() => _ParentState();
}

class _ParentState extends State<_Parent> {
  int value = 0, returns = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Text('parent $value / $returns'),
        TextButton(
          onPressed: () => setState(() => value++),
          child: const Text('increment'),
        ),
        TextButton(
          onPressed: () async {
            await openSettingPage(
              context,
              route: const PageRouteInfo('Child'),
              builder: (_) => const _Child('navigator child'),
            );
            if (mounted) setState(() => returns++);
          },
          child: const Text('open child'),
        ),
      ],
    ),
  );
}

class _Child extends StatelessWidget {
  const _Child(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Text(title),
        TextButton(
          onPressed: () => openSettingPage(
            context,
            route: const PageRouteInfo('Grandchild'),
            builder: (_) => const _Leaf('navigator grandchild'),
          ),
          child: const Text('open grandchild'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('child back'),
        ),
      ],
    ),
  );
}

class _Leaf extends StatelessWidget {
  const _Leaf(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Text(title),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('grandchild back'),
        ),
      ],
    ),
  );
}

void main() {
  for (final host in ['router', 'navigator', 'pageless-with-router']) {
    testWidgets(
      'settings $host keeps its parent and navigator through two child levels',
      (tester) async {
        final observer = _Observer();
        RootStackRouter? router;
        if (host == 'navigator') {
          await tester.pumpWidget(
            MaterialApp(navigatorObservers: [observer], home: const _Parent()),
          );
        } else {
          router = RootStackRouter.build(
            routes: [
              NamedRouteDef(
                name: 'Home',
                path: '/',
                initial: true,
                builder: (_, _) => host == 'router'
                    ? const _Parent()
                    : const Scaffold(body: Text('router home')),
              ),
              NamedRouteDef(
                name: 'Child',
                path: '/child',
                builder: (_, _) => const _Child('router child'),
              ),
              NamedRouteDef(
                name: 'Grandchild',
                path: '/grandchild',
                builder: (_, _) => const _Leaf('router grandchild'),
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: router.config(navigatorObservers: () => [observer]),
            ),
          );
          await tester.pumpAndSettle();
          if (host == 'pageless-with-router') {
            final context = tester.element(find.text('router home'));
            Navigator.of(context).push<void>(
              videoPageRoute(
                settings: const RouteSettings(name: 'plain-parent'),
                builder: (_) => const _Parent(),
              ),
            );
          }
        }
        await tester.pumpAndSettle();
        final parent = tester.state(find.byType(_Parent));
        final parentContext = tester.element(find.byType(_Parent));
        if (host == 'pageless-with-router') {
          expect(
            parentContext.findAncestorWidgetOfExactType<RouterScope>(),
            isNotNull,
          );
          expect(
            ModalRoute.of(parentContext)!.settings,
            isNot(isA<AutoRoutePage>()),
          );
        }
        await tester.tap(find.text('increment'));
        await tester.pumpAndSettle();
        expect(find.text('parent 1 / 0'), findsOneWidget);
        final before = observer.pushes.length;
        await tester.tap(find.text('open child'));
        await tester.pumpAndSettle();
        expect(observer.pops, isEmpty);
        expect(observer.pushes, hasLength(before + 1));
        expect(observer.pushes.last.settings.name, 'Child');
        expect(
          find.text(host == 'router' ? 'router child' : 'navigator child'),
          findsOneWidget,
        );
        expect(
          tester.state(find.byType(_Parent, skipOffstage: false)),
          same(parent),
        );
        if (router != null) {
          expect(router.stack.length, host == 'router' ? 2 : 1);
        }
        await tester.tap(find.text('open grandchild'));
        await tester.pumpAndSettle();
        expect(observer.pops, isEmpty);
        expect(observer.pushes, hasLength(before + 2));
        expect(observer.pushes.last.settings.name, 'Grandchild');
        expect(
          find.text(
            host == 'router' ? 'router grandchild' : 'navigator grandchild',
          ),
          findsOneWidget,
        );
        if (router != null) {
          expect(router.stack.length, host == 'router' ? 3 : 1);
        }
        await tester.tap(find.text('grandchild back'));
        await tester.pumpAndSettle();
        expect(find.byType(_Child), findsOneWidget);
        expect(observer.pops, hasLength(1));
        await tester.tap(find.text('child back'));
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(_Parent)), same(parent));
        expect(find.text('parent 1 / 1'), findsOneWidget);
        expect(observer.pops, hasLength(2));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
}
