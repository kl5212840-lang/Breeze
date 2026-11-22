import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/collection_press_feedback.dart';

const _surface = ValueKey('press-surface'), _paint = ValueKey('press-paint');

Future<void> _mount(
  WidgetTester tester, {
  required VoidCallback onTap,
  required VoidCallback onHold,
  bool reduceMotion = false,
  bool enabled = true,
  bool scrolling = false,
  bool surface = false,
  String interfaceStyle = 'system',
}) async {
  final style = ValueNotifier(interfaceStyle);
  addTearDown(style.dispose);
  Widget card() {
    final content = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onHold,
      child: const ColoredBox(key: _paint, color: Colors.blue),
    );
    return SizedBox(
      width: 200,
      height: 150,
      child: surface
          ? CollectionPressFeedback.surface(
              key: _surface,
              enabled: enabled,
              child: content,
            )
          : CollectionPressFeedback(
              key: _surface,
              enabled: enabled,
              child: content,
            ),
    );
  }

  await tester.pumpWidget(
    AppInterfaceStyleScope(
      style: style,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: Scaffold(
          body: scrolling
              ? ListView(children: [card(), const SizedBox(height: 1500)])
              : Align(alignment: Alignment.topLeft, child: card()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'compact controls keep their existing press feedback and hit bounds',
    (tester) async {
      var taps = 0, holds = 0;
      await _mount(tester, onTap: () => taps++, onHold: () => holds++);
      final bounds = tester.getRect(find.byKey(_surface));
      final original = tester.getRect(find.byKey(_paint));
      final gesture = await tester.startGesture(bounds.center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final pressed = tester.getRect(find.byKey(_paint));
      expect(pressed.width, closeTo(original.width * .96, .01));
      expect(pressed.center.dy, closeTo(original.center.dy + .6, .01));
      expect(tester.getRect(find.byKey(_surface)), bounds);
      expect(holds, 0);
      await tester.pump(const Duration(milliseconds: 350));
      expect(holds, 1);
      expect(tester.getRect(find.byKey(_paint)), pressed);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 0);
      expect(holds, 1);
      expect(tester.getRect(find.byKey(_paint)), original);
      // The visually reduced region must not shrink the actual target.
      await tester.tapAt(bounds.topLeft + const Offset(1, 1));
      await tester.pumpAndSettle();
      expect(taps, 1);
    },
  );

  for (final style in ['system', 'breeze']) {
    testWidgets('a $style card settles into a light hold with no downshift', (
      tester,
    ) async {
      var taps = 0, holds = 0;
      await _mount(
        tester,
        onTap: () => taps++,
        onHold: () => holds++,
        surface: true,
        interfaceStyle: style,
      );
      final bounds = tester.getRect(find.byKey(_surface));
      final original = tester.getRect(find.byKey(_paint));
      final gesture = await tester.startGesture(bounds.center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final pressed = tester.getRect(find.byKey(_paint));
      expect(pressed.width, closeTo(original.width * .99, .01));
      expect(pressed.center.dy, closeTo(original.center.dy, .01));
      expect(tester.getRect(find.byKey(_surface)), bounds);
      await tester.pump(const Duration(milliseconds: 350));
      expect(holds, 1);
      expect(taps, 0);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(_paint)), original);
    });
  }

  testWidgets('scroll and cancel release feedback without triggering actions', (
    tester,
  ) async {
    var taps = 0, holds = 0;
    await _mount(
      tester,
      onTap: () => taps++,
      onHold: () => holds++,
      scrolling: true,
      surface: true,
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(_surface)),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.moveBy(const Offset(0, -35));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -35));
    await tester.pump(const Duration(milliseconds: 200));
    final rect = tester.getRect(find.byKey(_surface));
    expect(tester.getRect(find.byKey(_paint)).size, rect.size);
    await gesture.cancel();
    await tester.pump(const Duration(seconds: 1));
    expect(taps, 0);
    expect(holds, 0);
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      greaterThan(0),
    );
  });

  for (final enabled in [false, true]) {
    testWidgets(
      'reduced motion and secondary pointer respect enabled=$enabled',
      (tester) async {
        await _mount(
          tester,
          onTap: () {},
          onHold: () {},
          reduceMotion: true,
          enabled: enabled,
          surface: true,
        );
        final original = tester.getRect(find.byKey(_paint));
        final right = await tester.startGesture(
          original.center,
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryButton,
        );
        await tester.pump();
        expect(tester.getRect(find.byKey(_paint)), original);
        await right.up();
        final touch = await tester.startGesture(original.center);
        await tester.pump();
        await tester.pump();
        expect(tester.getRect(find.byKey(_paint)), original);
        final feedback = find.descendant(
          of: find.byKey(_surface),
          matching: find.byType(Opacity),
        );
        expect(tester.widget<Opacity>(feedback).opacity, enabled ? .97 : 1);
        await touch.cancel();
        await tester.pump();
        expect(tester.getRect(find.byKey(_paint)), original);
      },
    );
  }
}
