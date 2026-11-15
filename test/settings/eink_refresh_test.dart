import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/platform/eink/eink_refresh.dart';

void main() {
  testWidgets('refresh uses the visible navigator and paints each stage', (
    tester,
  ) async {
    late BuildContext screen;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            screen = context;
            return const Scaffold(body: Text('Reader'));
          },
        ),
      ),
    );
    expect(await EinkRefresh.run(screen, EinkRefreshMode.none), isFalse);

    Finder flash(Color color) => find.byWidgetPredicate(
      (widget) =>
          widget is ColoredBox &&
          widget.color == color &&
          widget.child is SizedBox,
    );
    final full = EinkRefresh.run(screen, EinkRefreshMode.fullFlash, holdMs: 50);
    await tester.pump();
    expect(flash(Colors.white), findsOneWidget);
    expect(await EinkRefresh.run(screen, EinkRefreshMode.whiteFlash), isFalse);

    await tester.pump(const Duration(milliseconds: 50));
    expect(flash(Colors.black), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 50));
    expect(flash(Colors.white), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 50));
    expect(await full, isTrue);
    await tester.pump();
    expect(flash(Colors.white), findsNothing);

    final white = EinkRefresh.run(
      screen,
      EinkRefreshMode.whiteFlash,
      holdMs: 50,
    );
    await tester.pump();
    expect(flash(Colors.white), findsOneWidget);
    expect(flash(Colors.black), findsNothing);
    await tester.pump(const Duration(milliseconds: 50));
    expect(await white, isTrue);
  });
}
