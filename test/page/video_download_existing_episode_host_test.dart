import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_download_sheet.dart';
import 'package:zephyr/page/video/video_download_availability.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_site_action_models.dart';
import 'package:zephyr/service/download/download_admission.dart';
import '../download_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final connectivity = DownloadConnectivityFixture();
  tearDownAll(connectivity.close);
  const source = 'existing-sheet-fixture';
  final watch = Uri.parse('https://fixture.test/watch?v=42');
  final id = VideoLocalResources.identity(source, watch, '720p');
  late File original;
  final originalBytes = [0,0,0,24,102,116,121,112,...List.filled(16,0)];
  const channel = MethodChannel('breeze.video.download');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DownloadAdmission.instance.start();
    await useIsolatedDownloadFixture();
    VideoLocalResources.invalidate();
    final key = await VideoExportRecords.beginTransfer(source: source, video: watch,
      title: 'Actual work', quality: '720p', resourceId: id, queued: true);
    original = await VideoLocalResources.file(id);
    await original.parent.create(recursive: true);
    await original.writeAsBytes(originalBytes);
    await VideoLocalResources.saved(resourceId: id, bytes: 24, source: source,
      video: watch, title: 'Actual work', quality: '720p', taskKey: key);
    await VideoExportRecords.updateTransfer(key, received: 24, total: 24,
      status: 'saved', resourceId: id, terminal: true);
    await VideoDownloadAvailability.read(source: source, watch: watch);
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  testWidgets('the work sheet marks only the downloaded version and preserves it through explicit redownload failure and retry', (tester) async {
    var starts = 0, reads = 0;
    final originalPresentAtStarts = <bool>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'start') { starts++; originalPresentAtStarts.add(original.existsSync()); return 'failed'; }
      return null;
    });
    Future<void> until(bool Function() ready, String stage) async {
      final elapsed = Stopwatch()..start();
      while (!ready() && elapsed.elapsed < const Duration(seconds: 5)) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(ready(), isTrue, reason: stage);
    }
    try {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: VideoDownloadSheet(
        source: source, video: watch, title: 'Actual work', onClose: () {},
        readChoices: () async {
          reads++;
          return (status: VideoSiteStatus.ok, value: [
            (label: '720p', url: Uri.parse('https://cdn.fixture/720.mp4?revision=$reads'), format: 'mp4'),
            (label: '1080p', url: Uri.parse('https://cdn.fixture/1080.mp4?revision=$reads'), format: 'mp4'),
          ], writeUnconfirmed: false);
        },
      ))));
      final savedChoice = find.byKey(const ValueKey('video-download-choice-0'));
      final otherChoice = find.byKey(const ValueKey('video-download-choice-1'));
      final downloadedLabel = find.textContaining(t.download.alreadyDownloaded);
      final savedLabel = find.descendant(
        of: savedChoice,
        matching: downloadedLabel,
      );
      await until(
        () => savedLabel.evaluate().isNotEmpty,
        'read real existing resource',
      );
      expect(savedLabel, findsOneWidget);
      expect(
        find.descendant(of: otherChoice, matching: downloadedLabel),
        findsNothing,
      );
      await tester.tap(savedChoice);
      await tester.pump();
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('video-download.start'))).onPressed, isNull);
      expect(starts, 0);
      await tester.tap(otherChoice);
      await tester.pump();
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('video-download.start'))).onPressed, isNotNull,
        reason: 'A different quality must not be disabled by the saved 720p file');
      await tester.tap(savedChoice);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('video-download.redownload')));
      await until(() => starts == 1 && find.byKey(const ValueKey('video-download.retry')).evaluate().isNotEmpty, 'explicit replacement fails');
      expect(await tester.runAsync(original.readAsBytes), originalBytes);
      expect(find.text(t.download.openSourceVideo), findsNothing);
      await tester.tap(find.byKey(const ValueKey('video-download.retry')));
      await until(() => starts == 2 && find.byKey(const ValueKey('video-download.retry')).evaluate().isNotEmpty, 'retry really starts a fresh replacement');
      expect(reads, 3);
      expect(originalPresentAtStarts, [true, true]);
      expect(await tester.runAsync(original.readAsBytes), originalBytes);
      // The retry action can be visible before its inventory refresh settles.
      var inventorySettled = false;
      final inventory = VideoDownloadAvailability.read(
        source: source,
        watch: watch,
      ).whenComplete(() => inventorySettled = true);
      await until(() => inventorySettled, 'inventory reads after retry settle');
      await inventory;
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
