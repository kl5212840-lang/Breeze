import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_download_choice.dart';
import 'package:zephyr/page/video/video_download_sheet.dart';
import 'package:zephyr/page/video/video_site_action_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('breeze.video.download');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final video = Uri.parse('https://hanime1.me/watch?v=42');
  final choice = (
    label: '720p',
    url: Uri.parse('https://media.example/video.mp4?secure=ephemeral'),
    format: 'MP4',
  );

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  Future<void> mount(
    WidgetTester tester, {
    required Future<VideoSiteResult<List<VideoDownloadChoice>>> Function() read,
    VoidCallback? website,
    double scale = 1,
  }) => tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(320, 568),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: 320,
              height: 380,
              child: VideoDownloadSheet(
                readChoices: read,
                video: video,
                title: 'Example title',
                onClose: () {},
                onWebsite: website,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('reading quality options never starts a media transfer', (
    tester,
  ) async {
    var starts = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      starts++;
      return 'cancelled';
    });
    await mount(
      tester,
      read: () async => (
        status: VideoSiteStatus.ok,
        value: [choice],
        writeUnconfirmed: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('720p'), findsOneWidget);
    expect(starts, 0);
    await tester.tap(find.byKey(const ValueKey('video-download-choice-0')));
    await tester.pumpAndSettle();
    expect(starts, 1);
    expect(find.text(t.videoDownload.cancelled), findsOneWidget);
    expect(find.text(t.videoDownload.saved), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('failed URL is discarded and retry reads fresh choices', (
    tester,
  ) async {
    var reads = 0;
    messenger.setMockMethodCallHandler(channel, (_) async => 'failed');
    await mount(
      tester,
      read: () async {
        reads++;
        return (
          status: VideoSiteStatus.ok,
          value: [choice],
          writeUnconfirmed: false,
        );
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('video-download-choice-0')));
    await tester.pumpAndSettle();
    expect(find.text(t.videoDownload.failed), findsOneWidget);
    expect(find.text('720p'), findsNothing);
    expect(reads, 1);
    await tester.tap(find.text(t.videoDownload.reload));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('720p'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('closing the sheet cancels only its running transfer', (
    tester,
  ) async {
    final pending = Completer<String>();
    var cancelled = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'start') return pending.future;
      if (call.method == 'cancel') {
        cancelled = true;
        pending.complete('cancelled');
      }
      return null;
    });
    await mount(
      tester,
      read: () async => (
        status: VideoSiteStatus.ok,
        value: [choice],
        writeUnconfirmed: false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('video-download-choice-0')));
    await tester.pump();
    expect(
      find.text(t.videoDownload.downloading(quality: '720p')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(cancelled, isTrue);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'unsupported platform exposes website without reading signed links',
    (tester) async {
      var reads = 0, opens = 0;
      await mount(
        tester,
        scale: 2,
        read: () async {
          reads++;
          return (
            status: VideoSiteStatus.ok,
            value: [choice],
            writeUnconfirmed: false,
          );
        },
        website: () => opens++,
      );
      await tester.pumpAndSettle();
      expect(reads, 0);
      expect(find.text(t.videoDownload.unavailable), findsOneWidget);
      await tester.ensureVisible(find.text(t.videoDownload.website));
      await tester.tap(find.text(t.videoDownload.website));
      expect(opens, 1);
      expect(tester.takeException(), isNull);
    },
    // Android now supports native downloads too; Linux still uses the website.
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
}
