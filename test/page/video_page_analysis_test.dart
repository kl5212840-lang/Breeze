import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_page_analysis.dart';

void main() {
  testWidgets(
    'copy requires completed analysis and copies that snapshot without reading again',
    (tester) async {
      var reads = 0;
      var pending = Completer<VideoPageAnalysisResult>();
      final copies = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoPageAnalysis(
              analyze: () {
                reads++;
                return pending.future;
              },
              onCopy: (text) async => copies.add(text),
            ),
          ),
        ),
      );
      expect(reads, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      pending.complete(
        const VideoPageAnalysisResult(
          mode: 'Website',
          page: '/search',
          status: 'Displayed',
          report: 'snapshot 1',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.videoPlayback.copyDiagnostic));
      await tester.pumpAndSettle();
      expect(copies, ['snapshot 1']);
      expect(find.text(t.videoPlayback.analysisCopied), findsOneWidget);
      expect(reads, 1);
      pending = Completer<VideoPageAnalysisResult>();
      await tester.tap(find.text(t.videoPlayback.analyzeAgain));
      await tester.pump();
      expect(reads, 2);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      pending.completeError(StateError('page changed'));
      await tester.pumpAndSettle();
      expect(find.text(t.videoPlayback.analysisFailed), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    },
  );

  testWidgets('analysis remains scrollable at narrow width and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: VideoPageAnalysis(
            analyze: () async => const VideoPageAnalysisResult(
              mode: 'Website',
              page: '/user/:id/edit',
              status: 'Awaiting site verification',
              report: 'safe report',
            ),
            onCopy: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(t.videoPlayback.copyDiagnostic),
      100,
    );
    expect(tester.takeException(), isNull);
    expect(
      find.text(t.videoPlayback.copyDiagnostic).hitTestable(),
      findsOneWidget,
    );
  });
  testWidgets(
    'failed clipboard write never reports copied and can be retried',
    (tester) async {
      var fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoPageAnalysis(
              analyze: () async => const VideoPageAnalysisResult(
                mode: 'Website',
                page: 'Home',
                status: 'Displayed',
                report: 'safe report',
              ),
              onCopy: (_) async {
                if (fail) throw StateError('clipboard unavailable');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.videoPlayback.copyDiagnostic));
      await tester.pumpAndSettle();
      expect(find.text(t.videoPlayback.analysisCopyFailed), findsOneWidget);
      expect(find.text(t.videoPlayback.analysisCopied), findsNothing);
      fail = false;
      await tester.tap(find.text(t.videoPlayback.copyDiagnostic));
      await tester.pumpAndSettle();
      expect(find.text(t.videoPlayback.analysisCopied), findsOneWidget);
      expect(find.text(t.videoPlayback.analysisCopyFailed), findsNothing);
    },
  );
}
