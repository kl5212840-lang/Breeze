import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/video/video_content_transition.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    required int revision,
    bool ready = true,
    bool reduceMotion = false,
    bool enabled = true,
    VoidCallback? onTap,
  }) => tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: VideoContentTransition(
            revision: revision,
            ready: ready,
            enabled: enabled,
            child: TextButton(onPressed: onTap, child: Text('Page $revision')),
          ),
        ),
      ),
    ),
  );

  double opacity(WidgetTester tester) => tester
      .widget<FadeTransition>(
        find.descendant(
          of: find.byType(VideoContentTransition),
          matching: find.byType(FadeTransition),
        ),
      )
      .opacity
      .value;

  testWidgets('ready content is immediately interactive; latest change wins', (
    tester,
  ) async {
    var taps = 0;
    await mount(tester, revision: 0, ready: false);
    await mount(tester, revision: 1, onTap: () => taps++);
    expect(opacity(tester), 0.8);
    await tester.tap(find.text('Page 1'));
    expect(taps, 1);
    await tester.pump(const Duration(milliseconds: 50));
    expect(opacity(tester), greaterThan(0.8));
    await mount(tester, revision: 2);
    expect(find.text('Page 1'), findsNothing);
    expect(find.text('Page 2'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    expect(opacity(tester), 1);
    await mount(tester, revision: 2);
    expect(
      opacity(tester),
      1,
      reason: 'ordinary updates must not replay arrival',
    );
  });

  testWidgets(
    'reduced motion and an existing back transition do not animate twice',
    (tester) async {
      await mount(tester, revision: 0);
      await mount(tester, revision: 1, reduceMotion: true);
      expect(opacity(tester), 1);
      await mount(tester, revision: 2, enabled: false);
      expect(opacity(tester), 1);
      await mount(tester, revision: 3);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    },
  );
}
