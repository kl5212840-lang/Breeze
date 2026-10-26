import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_verification_gate.dart';

void main() {
  testWidgets('verification opens only after a press and help is optional', (
    tester,
  ) async {
    var verifications = 0;
    var help = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoVerificationGate(
            onVerify: () => verifications++,
            onHelp: () => help++,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 10));
    expect(verifications, 0);
    expect(help, 0);
    await tester.tap(find.text(t.videoPlayback.verificationWindow));
    await tester.tap(find.text(t.videoPlayback.verificationHelp));
    expect(verifications, 1);
    expect(help, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VideoVerificationGate(onVerify: () {})),
      ),
    );
    expect(find.text(t.videoPlayback.verificationHelp), findsNothing);
  });

  testWidgets('active verification cannot open a second window', (
    tester,
  ) async {
    var verifications = 0;
    Widget gate(bool active) => MaterialApp(
      home: Scaffold(
        body: VideoVerificationGate(
          active: active,
          onVerify: () => verifications++,
        ),
      ),
    );
    await tester.pumpWidget(gate(false));
    final idleRect = tester.getRect(find.byType(FilledButton));
    await tester.pumpWidget(gate(true));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      null,
    );
    expect(tester.getRect(find.byType(FilledButton)), idleRect);
    await tester.tap(find.text(t.videoPlayback.verificationWindow));
    expect(verifications, 0);
    await tester.pumpWidget(gate(false));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text(t.videoPlayback.verificationWindow));
    expect(verifications, 1);
  });

  testWidgets('large text on a small screen can scroll to both actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var verifications = 0;
    var help = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(3)),
          child: child!,
        ),
        home: Scaffold(
          body: VideoVerificationGate(
            onVerify: () => verifications++,
            onHelp: () => help++,
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text(t.videoPlayback.verificationWindow),
      100,
    );
    await tester.tap(find.text(t.videoPlayback.verificationWindow));
    await tester.scrollUntilVisible(
      find.text(t.videoPlayback.verificationHelp),
      100,
    );
    await tester.tap(find.text(t.videoPlayback.verificationHelp));
    expect(tester.takeException(), isNull);
    expect(verifications, 1);
    expect(help, 1);
    for (final button in [find.byType(FilledButton), find.byType(TextButton)]) {
      expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
    }
  });

  testWidgets('wide screen keeps the gate compact and centered', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VideoVerificationGate(onVerify: () {})),
      ),
    );
    final bounds = tester.getRect(find.byType(VideoVerificationGate));
    final action = tester.getRect(find.byType(FilledButton));
    expect(action.width, 352);
    expect(action.center.dx, bounds.center.dx);
    expect(action.height, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
  });
}
