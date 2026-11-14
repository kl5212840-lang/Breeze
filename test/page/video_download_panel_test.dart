import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_download_panel.dart';
import 'package:zephyr/page/video/video_episode_download_picker.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_download.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'dart:convert';
import '../download_fixture.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Real filesystem setup belongs outside testWidgets' FakeAsync body.
    await useIsolatedDownloadFixture();
    VideoLocalResources.invalidate();
    await VideoLocalResources.read();
  });
  testWidgets('download details never manufacture total size', (tester) async {
    for (final values in [
      (received: 1024, total: null, media: null),
      (received: 1024, total: 4096, media: null),
      (received: 1024, total: 0, media: .4),
      (received: 1024, total: 512, media: null),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoDownloadProgressReadout(
              received: values.received,
              total: values.total,
              mediaProgress: values.media,
            ),
          ),
        ),
      );
      final text = tester
          .widget<Text>(
            find.byKey(const ValueKey('video-download.progress-details')),
          )
          .data!;
      expect(text.contains('/'), values.total == 4096);
      expect(text.contains('1.0 KB'), isTrue);
      expect(text.contains('40%'), values.media != null);
      expect(text.contains('25%'), values.total == 4096);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets(
    'unknown HLS bytes stay absent while real package bytes and media percentage are independent',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VideoDownloadProgressReadout(mediaProgress: .02),
          ),
        ),
      );
      var text = tester
          .widget<Text>(
            find.byKey(const ValueKey('video-download.progress-details')),
          )
          .data!;
      expect(text, '2%');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VideoDownloadProgressReadout(
              received: 2048,
              receivedSource: 'package',
              mediaProgress: .02,
            ),
          ),
        ),
      );
      text = tester
          .widget<Text>(
            find.byKey(const ValueKey('video-download.progress-details')),
          )
          .data!;
      expect(text, '2.0 KB · 2%');
      expect(text, isNot(contains('/')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'real HLS task separates network and package bytes without inventing a total',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VideoDownloadProgressReadout(
              row: {
                'key': 'hls-task',
                'attempt': 1,
                'status': 'downloading',
                'format': 'hls',
                'received': 8192,
                'receivedSource': 'package',
                'packageBytes': 8192,
                'networkBytes': 2048,
                'mediaProgress': .25,
              },
            ),
          ),
        ),
      );
      final text = tester
          .widget<Text>(
            find.byKey(const ValueKey('video-download.progress-details')),
          )
          .data!;
      expect(text, contains('2.0 KB'));
      expect(text, isNot(contains('8.2 KB')));
      expect(text, isNot(contains(t.download.cachedBytes(size: '8.2 KB'))));
      expect(text, contains('25%'));
      expect(text, isNot(contains('/s')));
      expect(text, isNot(contains('/ 8.2 KB')));
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        .25,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'single-transfer readout uses persisted task counters rather than legacy callbacks',
    (tester) async {
      late String key;
      await tester.runAsync(() async {
        key = await VideoExportRecords.beginTransfer(
          source: 'b28da416-f2d4-4208-a85e-8b4c7c648e48',
          video: Uri.parse(
            'https://fixture.test/voddetail/42.html?line=main&episode=one',
          ),
          title: 'Task progress',
          quality: 'main',
          format: 'hls',
          queued: true,
        );
        await VideoExportRecords.updateTransfer(
          key,
          status: 'downloading',
          received: 4096,
          receivedSource: 'package',
          packageBytes: 4096,
          mediaProgress: .5,
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: VideoDownloadTaskProgress(taskKey: key)),
        ),
      );
      final elapsed = Stopwatch()..start();
      final details = find.byKey(
        const ValueKey('video-download.progress-details'),
      );
      while (details.evaluate().isEmpty &&
          elapsed.elapsed < const Duration(seconds: 5)) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(details, findsOneWidget);
      final text = tester.widget<Text>(details).data!;
      expect(text, contains('4.1 KB'));
      expect(text, isNot(contains(t.download.cachedBytes(size: '4.1 KB'))));
      expect(text, contains('50%'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(
        () => VideoExportRecords.updateTransfer(
          key,
          received: 4096,
          status: 'cancelled',
          terminal: true,
        ),
      );
    },
  );

  testWidgets(
    'an unresolved failed episode has a real in-place retry and no link back to its own work',
    (tester) async {
      late String key;
      late SharedPreferences prefs;
      await tester.runAsync(() async {
        key = await VideoExportRecords.beginTransfer(
          source: 'inline-retry-fixture',
          video: Uri.parse(
            'https://fixture.test/voddetail/42.html?line=A&episode=1',
          ),
          title: 'Episode 1',
          quality: '',
          retryItemId: '42',
          queued: true,
        );
        await VideoExportRecords.updateTransfer(
          key,
          received: null,
          status: 'failed',
          terminal: true,
        );
        prefs = await SharedPreferences.getInstance();
      });
      var retries = 0, completed = false;
      Object? failure;
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VideoDownloadCurrentTasks(
                taskKeys: {key},
                allowSourceNavigation: false,
                onRetry: (row) async {
                  retries++;
                  try {
                    await VideoExportRecords.restartTransfer(row);
                  } catch (error) {
                    failure = error;
                  } finally {
                    completed = true;
                  }
                },
              ),
            ),
          ),
        );
        final elapsed = Stopwatch()..start();
        final retry = find.byKey(ValueKey('video-download-inline-retry.$key'));
        while (retry.evaluate().isEmpty &&
            elapsed.elapsed < const Duration(seconds: 5)) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(retry, findsOneWidget);
        expect(find.text(t.download.openSourceVideo), findsNothing);
        await tester.tap(retry);
        elapsed.reset();
        while (!completed && elapsed.elapsed < const Duration(seconds: 5)) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(completed, isTrue);
        expect(failure, isNull);
        expect(retries, 1);
        final row =
            (jsonDecode(prefs.getString(VideoExportRecords.taskStorageKey)!)
                    as List)
                .cast<Map>()
                .singleWhere((row) => row['key'] == key);
        expect(row['status'], 'preparing');
        expect(row['attempt'], 2);
        expect(find.byType(VideoDownloadCurrentTasks), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        completed = false;
        VideoExportRecords.updateTransfer(
          key,
          received: null,
          status: 'cancelled',
          terminal: true,
        ).then<void>(
          (_) => completed = true,
          onError: (Object error) {
            failure = error;
            completed = true;
          },
        );
        final elapsed = Stopwatch()..start();
        while (!completed && elapsed.elapsed < const Duration(seconds: 5)) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(completed, isTrue);
        expect(failure, isNull);
      }
    },
  );

  testWidgets(
    'a stale episode panel cancel cannot stop the replacement attempt',
    (tester) async {
      const source = 'inline-cancel-fixture';
      late String key;
      var cancellations = 0;
      Future<void> settle(bool Function() ready) async {
        final elapsed = Stopwatch()..start();
        while (!ready() && elapsed.elapsed < const Duration(seconds: 5)) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(ready(), isTrue);
      }

      await tester.runAsync(() async {
        key = await VideoExportRecords.beginTransfer(
          source: source,
          video: Uri.parse(
            'https://fixture.test/voddetail/42.html?line=B&episode=1',
          ),
          title: 'Episode 1 · Line B',
          quality: '720p',
          queued: true,
        );
      });
      addTearDown(() async {
        VideoSystemDownload.unregisterQueuedTask(key);
        if (VideoExportRecords.isLive(key)) {
          await VideoExportRecords.updateTransfer(
            key,
            received: null,
            status: 'cancelled',
            terminal: true,
          );
        }
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: VideoDownloadCurrentTasks(taskKeys: {key})),
        ),
      );
      final cancel = find.widgetWithText(TextButton, t.videoDownload.cancel);
      await settle(() => cancel.evaluate().isNotEmpty);
      final cancelFirstAttempt = tester.widget<TextButton>(cancel).onPressed!;

      late int replacement;
      await tester.runAsync(() async {
        final first = VideoExportRecords.currentAttempt(key)!;
        await VideoExportRecords.updateTransfer(
          key,
          received: null,
          status: 'cancelled',
          terminal: true,
          expectedAttempt: first,
        );
        final terminal = (await VideoExportRecords.readTaskSnapshot()).single;
        final restarted = await VideoExportRecords.restartTransfer(terminal);
        replacement = restarted!['attempt'] as int;
        VideoSystemDownload.registerQueuedTask(
          key,
          source,
          () async {
            cancellations++;
            await VideoExportRecords.updateTransfer(
              key,
              received: null,
              status: 'cancelled',
              terminal: true,
              expectedAttempt: replacement,
            );
          },
          attempt: replacement,
        );
      });

      // A FutureBuilder may retain the old row until its read resolves.
      cancelFirstAttempt();
      await tester.pump();
      expect(cancellations, 0);
      expect(VideoExportRecords.isAttemptCurrent(key, replacement), isTrue);

      final cancelReplacement = find.byKey(
        ValueKey('video-download-inline-cancel.$key.$replacement'),
      );
      await settle(() => cancelReplacement.evaluate().isNotEmpty);
      await tester.tap(cancelReplacement);
      await settle(
        () => find.text(t.download.videoCancelled).evaluate().isNotEmpty,
      );
      expect(cancellations, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(VideoExportRecords.flush);
    },
  );

  testWidgets(
    'episode selection starts explicitly then stays in the task panel',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Future<void> until(bool Function() ready, String stage) async {
        final elapsed = Stopwatch()..start();
        while (!ready() && elapsed.elapsed < const Duration(seconds: 5)) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(ready(), isTrue, reason: stage);
      }

      var enqueues = 0;
      String? taskKey;
      addTearDown(() {
        if (taskKey != null) VideoSystemDownload.unregisterQueuedTask(taskKey!);
      });
      final card = NativeVideoCard(
        title: '真实已选剧集',
        coverUrl: null,
        watchUrl: Uri.parse(
          'https://fixture.test/voddetail/42.html?line=a&episode=one',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoEpisodeDownloadPicker(
              episodes: [card],
              currentWatch: card.watchUrl,
              onEnqueue: (selected) async {
                enqueues++;
                expect(selected.single.watchUrl, card.watchUrl);
                const source = 'b28da416-f2d4-4208-a85e-8b4c7c648e48';
                final key = taskKey = await VideoExportRecords.beginTransfer(
                  source: source,
                  video: card.watchUrl,
                  title: card.title,
                  quality: '',
                  queued: true,
                );
                VideoSystemDownload.registerQueuedTask(
                  key,
                  source,
                  () => VideoExportRecords.updateTransfer(
                    key,
                    received: null,
                    status: 'cancelled',
                    terminal: true,
                  ),
                  attempt: VideoExportRecords.currentAttempt(key),
                );
                return [key];
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(enqueues, 0);
      await tester.tap(
        find.byKey(const ValueKey('download-episodes.select-all')),
      );
      await tester.pump();
      expect(enqueues, 0);
      await tester.tap(find.byKey(const ValueKey('download-episodes.submit')));
      // Submission intentionally mounts an indeterminate progress indicator.
      // Wait for the queue state, never for that animation to settle itself.
      await until(
        () => find.byType(VideoDownloadCurrentTasks).evaluate().isNotEmpty,
        'explicit enqueue completes and mounts its real task projection',
      );
      expect(enqueues, 1);
      expect(find.byType(VideoDownloadPanel), findsOneWidget);
      expect(find.byType(VideoDownloadCurrentTasks), findsOneWidget);
      expect(find.text(t.videoPlayback.downloadQueued), findsOneWidget);
      expect(
        find.byKey(const ValueKey('video-download-tasks')),
        findsOneWidget,
      );
      expect(find.text(t.download.videoForegroundNote), findsOneWidget);
      await until(
        () => find.text(card.title).evaluate().isNotEmpty,
        'the persisted queued row is read from the isolated real filesystem',
      );
      expect(find.text(card.title), findsOneWidget);
      expect(find.text(t.download.videoQueued), findsOneWidget);
      expect(
        find.byKey(const ValueKey('video-download.progress-details')),
        findsNothing,
        reason: 'a queued task does not claim a zero or estimated total size',
      );
      await tester.tap(find.text(t.videoDownload.cancel));
      await tester.pump();
      await until(
        () => find.text(t.download.videoCancelled).evaluate().isNotEmpty,
        'cancelTask dispatch commits and renders the terminal record',
      );
      expect(find.text(t.download.videoCancelled), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(VideoExportRecords.flush);
    },
  );
}
