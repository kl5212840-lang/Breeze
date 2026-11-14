import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_download.dart';
import 'package:zephyr/page/video/video_download_cancel_action.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/source_downloaded_video_groups.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import '../download_fixture.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await useIsolatedDownloadFixture();
  });
  const source = 'b28da416-f2d4-4208-a85e-8b4c7c648e48';
  testWidgets('source work queued episode uses the real shared cancel action', (tester) async {
    late String key;
    await tester.runAsync(() async {
      key = await VideoExportRecords.beginTransfer(source: source,
        video: Uri.parse('https://fixture.test/voddetail/42.html?line=A&episode=one'),
        title: 'Queued episode', quality: '720p', queued: true);
    });
    var cancelled = 0;
    final attempt = VideoExportRecords.currentAttempt(key)!;
    VideoSystemDownload.registerQueuedTask(key, source, () async {
      cancelled++;
      await VideoExportRecords.updateTransfer(key, received: null, status: 'cancelled', terminal: true);
    }, attempt: attempt);
    addTearDown(() => VideoSystemDownload.unregisterQueuedTask(key, attempt: attempt));
    final row = VideoExportRecords.sessionTaskSnapshot().singleWhere((row) => row['key'] == key);
    final item = sourceVideoDownloadItems([row], source).single;
    final style = ValueNotifier('breeze');
    addTearDown(style.dispose);
    await tester.pumpWidget(AppInterfaceStyleScope(style: style,
      child: MaterialApp(home: Scaffold(body: SourceDownloadedEpisodeRow(item: item)))));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('source-download-cancel.$key')));
    await tester.pumpAndSettle();
    expect(
      find.text(t.download.cancelTaskConfirm(comicName: 'Queued episode')),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, t.common.ok));
    await tester.pump();
    final elapsed = Stopwatch()..start();
    while (cancelled == 0 && elapsed.elapsed < const Duration(seconds: 5)) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(cancelled, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(VideoExportRecords.flush);
  });
  testWidgets('confirmation from an old attempt never cancels its replacement', (tester) async {
    late String key;
    await tester.runAsync(() async {
      key = await VideoExportRecords.beginTransfer(source: source,
        video: Uri.parse('https://fixture.test/voddetail/42.html?line=A&episode=one'),
        title: 'Queued episode', quality: '720p', queued: true);
    });
    final old = VideoExportRecords.sessionTaskSnapshot().singleWhere((row) => row['key'] == key);
    Future<bool>? result;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(body: TextButton(
      onPressed: () { result = confirmVideoDownloadCancellation(context, old, onConfirmed: () => fail('stale confirmation submitted')); },
      child: const Text('Cancel old'),
    )))));
    await tester.tap(find.text('Cancel old'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await VideoExportRecords.updateTransfer(key, received: null, status: 'failed', terminal: true);
      final failed = (await VideoExportRecords.readTaskSnapshot()).singleWhere((row) => row['key'] == key);
      final replacement = await VideoExportRecords.restartTransfer(failed);
      expect(replacement, isNotNull);
      expect(replacement!['attempt'], isNot(old['attempt']));
    });
    await tester.tap(find.widgetWithText(TextButton, t.common.ok));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
    expect(VideoExportRecords.isLive(key), isTrue);
    await tester.runAsync(() => VideoExportRecords.updateTransfer(key,
      received: null, status: 'cancelled', terminal: true));
  });
}
