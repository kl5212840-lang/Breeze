import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/video/video_back_gesture.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    VoidCallback onBack, {
    bool enabled = true,
    bool reducedMotion = false,
  }) => tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
        child: child!,
      ),
      home: VideoBackGesture(
        enabled: enabled,
        onBack: () async => onBack(),
        child: const ColoredBox(color: Colors.black),
      ),
    ),
  );

  testWidgets(
    'iOS leading-edge drag goes back once, not an ordinary content drag',
    (tester) async {
      var calls = 0;
      await mount(tester, () => calls++);
      await tester.dragFrom(const Offset(8, 200), const Offset(350, 0));
      await tester.pumpAndSettle();
      expect(calls, 1);
      await tester.dragFrom(const Offset(160, 200), const Offset(120, 0));
      expect(calls, 1);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('vertical, reversed and cancelled edge gestures do not go back', (
    tester,
  ) async {
    var calls = 0;
    await mount(tester, () => calls++);
    await tester.dragFrom(const Offset(8, 200), const Offset(0, 120));
    expect(calls, 0, reason: 'vertical');
    await tester.dragFrom(const Offset(8, 200), const Offset(-120, 0));
    expect(calls, 0, reason: 'reversed');
    final gesture = await tester.startGesture(const Offset(8, 200));
    await gesture.moveBy(const Offset(120, 0));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.dragFrom(const Offset(8, 200), const Offset(350, 0));
    await tester.pumpAndSettle();
    expect(calls, 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'root or disabled internal navigation does not intercept the edge',
    (tester) async {
      var calls = 0;
      await mount(tester, () => calls++, enabled: false);
      expect(
        find.byKey(const ValueKey('video-internal-back-edge')),
        findsNothing,
      );
      await tester.dragFrom(const Offset(8, 200), const Offset(120, 0));
      expect(calls, 0);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('edge back follows the finger and a short drag springs back', (
    tester,
  ) async {
    var calls = 0;
    await mount(tester, () => calls++);
    final gesture = await tester.startGesture(const Offset(8, 200));
    await gesture.moveBy(const Offset(80, 0));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    double offset() => tester
        .widget<Transform>(find.byKey(const ValueKey('video-back-transition')))
        .transform
        .getTranslation()
        .x;
    expect(offset(), greaterThan(0));
    expect(calls, 0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(offset(), 0);
    final complete = await tester.startGesture(const Offset(8, 200));
    await complete.moveBy(const Offset(350, 0));
    await tester.pump();
    await complete.up();
    expect(calls, 0, reason: 'navigation waits for the exit animation');
    await tester.pumpAndSettle();
    expect(calls, 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('reduced motion disables back preview parallax', (tester) async {
    var calls = 0;
    await mount(tester, () => calls++, reducedMotion: true);
    final gesture = await tester.startGesture(const Offset(8, 200));
    await gesture.moveBy(const Offset(80, 0));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    final preview = tester.widget<Transform>(
      find.byKey(const ValueKey('video-back-preview-transition')),
    );
    expect(preview.transform.getTranslation().x, 0);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(calls, 0);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
