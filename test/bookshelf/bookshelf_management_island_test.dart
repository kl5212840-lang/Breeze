import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_management_island.dart';

class _Routes extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
  }
}

void main() {
  testWidgets(
    'short management content shrinks in a centered root island and outside tap cancels',
    (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = _Routes(), nested = _Routes();
      var opens = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [root],
          home: Navigator(
            observers: [nested],
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () {
                    opens++;
                    showBookshelfManagementIsland<void>(
                      context: context,
                      builder: (_) => const SizedBox(
                        width: 420,
                        height: 80,
                        child: Center(child: Text('短内容')),
                      ),
                    );
                  },
                  child: const Text('打开'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      final surface = find.byKey(const ValueKey('bookshelf.island.surface'));
      expect(tester.getSize(surface).width, 420);
      expect(tester.getSize(surface).height, lessThan(180));
      expect(tester.getCenter(surface).dx, closeTo(400, 1));
      expect(root.pushes, 2);
      expect(nested.pushes, 1);
      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(find.text('短内容'));
      await tester.pumpAndSettle();
      expect(surface, findsOneWidget);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(surface, findsNothing);
      expect(opens, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      '320 double text keyboard and high contrast retain bounded readable $brightness island',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                highContrast: true,
                disableAnimations: true,
                viewInsets: const EdgeInsets.only(bottom: 280),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showBookshelfManagementIsland<void>(
                    context: context,
                    builder: (_) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('管理'),
                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                for (var i = 0; i < 20; i++) Text('可读的插件名称 $i'),
                              ],
                            ),
                          ),
                        ),
                        FilledButton(
                          key: const ValueKey('island.fixture.done'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(44, 44),
                          ),
                          onPressed: () {},
                          child: const Text('完成'),
                        ),
                      ],
                    ),
                  ),
                  child: const Text('打开'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('打开'));
        await tester.pumpAndSettle();
        final surface = find.byKey(const ValueKey('bookshelf.island.surface'));
        final rect = tester.getRect(surface);
        expect(rect.left, greaterThanOrEqualTo(16));
        expect(rect.right, lessThanOrEqualTo(304));
        expect(rect.top, greaterThanOrEqualTo(16));
        expect(rect.bottom, lessThanOrEqualTo(460 - 16));
        expect(rect.height, lessThanOrEqualTo((740 - 280 - 32) * .72 + 1));
        final material = find
            .descendant(of: surface, matching: find.byType(Material))
            .first;
        expect(tester.widget<Material>(material).color!.a, 1);
        expect(
          tester
              .getSize(find.byKey(const ValueKey('island.fixture.done')))
              .height,
          greaterThanOrEqualTo(44),
        );
        expect(find.byType(UiKitView), findsNothing);
        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
