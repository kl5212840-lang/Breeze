import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_download_choice.dart';
import 'package:zephyr/page/video/video_download_sheet.dart';
import 'package:zephyr/page/video/video_site_action_models.dart';
import 'package:zephyr/page/video/video_playback_download_adapter.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/service/download/download_admission.dart';

import '../download_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final connectivity = DownloadConnectivityFixture();
  tearDownAll(connectivity.close);
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await DownloadAdmission.instance.start();
  });
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
    Future<VideoPlaybackDownloadAdapter> Function()? refreshAdapter,
    bool choicesAreSnapshot = false,
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
                refreshAdapter: refreshAdapter,
                choicesAreSnapshot: choicesAreSnapshot,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> waitFor(
    WidgetTester tester,
    bool Function() ready,
    String stage,
  ) async {
    final elapsed = Stopwatch()..start();
    while (!ready() && elapsed.elapsed < const Duration(seconds: 5)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(ready(), isTrue, reason: stage);
  }

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
    await tester.pump();
    expect(starts, 0, reason: 'selection is separate from explicitly starting');
    await tester.tap(find.byKey(const ValueKey('video-download.start')));
    await waitFor(
      tester,
      () =>
          starts == 1 &&
          find.text(t.videoDownload.cancelled).evaluate().isNotEmpty,
      'native start and cancellation result',
    );
    expect(starts, 1);
    expect(find.text(t.videoDownload.cancelled), findsOneWidget);
    expect(find.text(t.videoDownload.saved), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('failed URL is discarded and retry reads fresh choices', (
    tester,
  ) async {
    var reads = 0;
    var starts = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'start') return null;
      starts++;
      return 'failed';
    });
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
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('video-download.start')));
    await waitFor(
      tester,
      () =>
          starts == 1 &&
          find.text(t.videoDownload.failed).evaluate().isNotEmpty,
      'native start and failure result',
    );
    expect(find.text(t.videoDownload.failed), findsOneWidget);
    expect(find.text('720p'), findsNothing);
    expect(reads, 1);
    await tester.tap(find.text(t.videoDownload.reload));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('720p'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'the retry button resolves fresh media and matching headers without leaving playback',
    (tester) async {
      final urls = <String>[];
      final referers = <String?>[];
      var refreshes = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method != 'start') return null;
        urls.add(call.arguments['url'] as String);
        referers.add(call.arguments['headers']?['Referer'] as String?);
        return urls.length == 1 ? 'failed' : 'cancelled';
      });
      await mount(
        tester,
        read: () async => (
          status: VideoSiteStatus.ok,
          value: [choice],
          writeUnconfirmed: false,
        ),
        choicesAreSnapshot: true,
        refreshAdapter: () async {
          refreshes++;
          return VideoPlaybackDownloadAdapter(
            NativePlaybackSession(
              title: 'Example title',
              watchUrl: video,
              description: '',
              tags: const [],
              sources: [
                NativePlaybackSource(
                  label: '720p',
                  url: Uri.parse('https://media.example/fresh.mp4?secure=new'),
                  headers: {'Referer': video.toString()},
                ),
              ],
            ),
          );
        },
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('video-download-choice-0')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('video-download.start')));
      await waitFor(
        tester,
        () =>
            urls.length == 1 &&
            find
                .byKey(const ValueKey('video-download.retry'))
                .evaluate()
                .isNotEmpty,
        'first native failure exposes retry',
      );
      expect(
        find.byKey(const ValueKey('video-download.retry')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('video-download.retry')));
      await waitFor(
        tester,
        () =>
            urls.length == 2 &&
            find.text(t.videoDownload.cancelled).evaluate().isNotEmpty,
        'retry reaches native with fresh media',
      );
      expect(refreshes, 1);
      expect(urls, [
        choice.url.toString(),
        'https://media.example/fresh.mp4?secure=new',
      ]);
      expect(referers.last, video.toString());
      expect(find.byType(VideoDownloadSheet), findsOneWidget);
      expect(find.text(t.download.openSourceVideo), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('closing the sheet leaves its real transfer running', (
    tester,
  ) async {
    final pending = Completer<String>();
    final started = Completer<void>();
    var cancelled = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'start') {
        started.complete();
        return pending.future;
      }
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
    try {
      await tester.tap(find.byKey(const ValueKey('video-download.start')));
      await waitFor(
        tester,
        () => started.isCompleted,
        'native transfer starts before closing',
      );
      expect(
        find.text(t.videoDownload.downloading(quality: '720p')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(pending.isCompleted, isFalse);
      expect(cancelled, isFalse);
    } finally {
      if (!pending.isCompleted) pending.complete('saved');
      await tester.pump();
    }
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
