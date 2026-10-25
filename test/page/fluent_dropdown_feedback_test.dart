import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/fluent_dropdown.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    bool reduced = false,
    ValueChanged<int>? changed,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: FluentDropdown<int>(
                  key: const ValueKey('setting-choice'),
                  value: 1,
                  displayValue: 'Current',
                  items: const {1: 'First', 2: 'Second'},
                  onChanged: changed ?? (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Finder arrow() => find.descendant(
    of: find.byKey(const ValueKey('setting-choice')),
    matching: find.byType(AnimatedRotation),
  );
  testWidgets('settings selection applies on tap before its exit animation', (
    tester,
  ) async {
    int? selected;
    await mount(tester, changed: (v) => selected = v);
    await tester.tap(find.text('Current'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second'));
    await tester.pump();
    expect(selected, 2);
    expect(tester.widget<AnimatedRotation>(arrow()).turns, 0);
    await tester.pumpAndSettle();
    expect(find.text('Second'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'outside dismissal updates arrow immediately and supports reopening',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text('Current'));
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedRotation>(arrow()).turns, .5);
      await tester.tapAt(const Offset(550, 500));
      await tester.pump();
      expect(tester.widget<AnimatedRotation>(arrow()).turns, 0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Current'));
      await tester.pumpAndSettle();
      expect(find.text('Second'), findsOneWidget);
      await tester.tapAt(const Offset(550, 500));
      await tester.pumpAndSettle();
      expect(find.text('Second'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('reduced motion and a 44pt trigger remain usable', (
    tester,
  ) async {
    await mount(tester, reduced: true);
    expect(
      tester.getSize(find.byKey(const ValueKey('setting-choice'))).height,
      greaterThanOrEqualTo(44),
    );
    await tester.tap(find.text('Current'));
    await tester.pump();
    expect(tester.widget<AnimatedRotation>(arrow()).duration, Duration.zero);
    final scale = tester.widget<ScaleTransition>(
      find
          .ancestor(
            of: find.text('Second'),
            matching: find.byType(ScaleTransition),
          )
          .first,
    );
    expect(scale.scale.value, 1);
    await tester.tapAt(const Offset(550, 500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
