import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/video/video_download.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('breeze.video.download');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final video = Uri.parse('https://hanime1.me/watch?v=42&private=omit');
  final choice = (
    label: '720p',
    url: Uri.parse('https://media.example/video.mp4?secure=ephemeral'),
    format: 'MP4',
  );

  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'only explicit save hands the issued media to the native transfer',
    () async {
      MethodCall? received;
      messenger.setMockMethodCallHandler(channel, (call) async {
        received = call;
        return 'saved';
      });
      final transfer = VideoSystemDownload();
      expect(received, isNull);
      expect(
        await transfer.save(
          choice: choice,
          video: video,
          title: 'Actual title',
          onProgress: (_) {},
        ),
        VideoDownloadStatus.saved,
      );
      expect(received!.method, 'start');
      final args = received!.arguments as Map;
      expect(args['url'], choice.url.toString());
      expect(args['referer'], 'https://hanime1.me/watch?v=42');
      expect(args['title'], 'Actual title');
      expect(args['quality'], '720p');
      expect(
        args.keys,
        unorderedEquals(['id', 'url', 'referer', 'title', 'quality']),
      );
    },
  );

  test(
    'concurrent transfers are rejected and cancel resolves without saved',
    () async {
      final pending = Completer<String>();
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) {
        calls.add(call);
        if (call.method == 'start') return pending.future;
        pending.complete('cancelled');
        return Future.value();
      });
      final first = VideoSystemDownload();
      Future<VideoDownloadStatus> save(VideoSystemDownload transfer) =>
          transfer.save(
            choice: choice,
            video: video,
            title: 'Title',
            onProgress: (_) {},
          );
      final future = save(first);
      expect(await save(VideoSystemDownload()), VideoDownloadStatus.busy);
      await VideoSystemDownload().cancel();
      expect(calls.length, 1);
      await first.cancel();
      expect(await future, VideoDownloadStatus.cancelled);
      expect(calls.map((item) => item.method), ['start', 'cancel']);
      expect(calls.last.arguments['id'], calls.first.arguments['id']);
    },
  );

  test(
    'progress only accepts the current transfer and numeric counts',
    () async {
      final pending = Completer<String>();
      String? job;
      messenger.setMockMethodCallHandler(channel, (call) {
        job = call.arguments['id'];
        return pending.future;
      });
      final progress = <VideoDownloadProgress>[];
      final future = VideoSystemDownload().save(
        choice: choice,
        video: video,
        title: 'Title',
        onProgress: progress.add,
      );
      await Future<void>.delayed(Duration.zero);
      Future<void> send(Map<String, dynamic> values) async {
        await messenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('progress', values),
          ),
          (_) {},
        );
      }

      await send({'id': 'stale', 'received': 1, 'total': 5});
      await send({'id': job, 'received': -1, 'total': 5});
      await send({'id': job, 'received': 20, 'total': -1});
      await send({'id': job, 'received': 80, 'total': 100, 'saving': true});
      expect(progress, [
        (received: 20, total: null, saving: false),
        (received: 80, total: 100, saving: true),
      ]);
      pending.complete('cancelled');
      expect(await future, VideoDownloadStatus.cancelled);
      await send({'id': job, 'received': 100, 'total': 100, 'saving': true});
      expect(progress.length, 2);
    },
  );

  test(
    'invalid or unavailable targets never reach the native downloader',
    () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (_) async {
        calls++;
        return 'saved';
      });
      for (final url in [
        'http://media.example/video.mp4',
        'https://user:password@media.example/video.mp4',
        'https://media.example/video.mp4#fragment',
        'https://media.example/page.html',
        'https://media.example:8443/video.mp4',
      ]) {
        expect(
          await VideoSystemDownload().save(
            choice: (label: '720p', url: Uri.parse(url), format: 'MP4'),
            video: video,
            title: 'Title',
            onProgress: (_) {},
          ),
          VideoDownloadStatus.failed,
        );
      }
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(
        await VideoSystemDownload().save(
          choice: choice,
          video: video,
          title: 'Title',
          onProgress: (_) {},
        ),
        VideoDownloadStatus.unavailable,
      );
      expect(calls, 0);
    },
  );
  test(
    'Android export distinguishes a saved file from picker cancellation',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final replies = ['cancelled', 'saved'].iterator;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'start');
        expect(call.arguments['referer'], 'https://hanime1.me/watch?v=42');
        replies.moveNext();
        return replies.current;
      });
      for (final expected in [
        VideoDownloadStatus.cancelled,
        VideoDownloadStatus.saved,
      ]) {
        expect(
          await VideoSystemDownload().save(
            choice: choice,
            video: video,
            title: 'Title',
            onProgress: (_) {},
          ),
          expected,
        );
      }
    },
  );

  test(
    'platform failures stay failures and release the transfer lock',
    () async {
      Future<VideoDownloadStatus> save() => VideoSystemDownload().save(
        choice: choice,
        video: video,
        title: 'Title',
        onProgress: (_) {},
      );
      expect(await save(), VideoDownloadStatus.unavailable);
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(
          code: 'transport',
          message: 'must not be shown',
        );
      });
      expect(await save(), VideoDownloadStatus.failed);
      messenger.setMockMethodCallHandler(channel, (_) async => 'not-a-result');
      expect(await save(), VideoDownloadStatus.failed);
      messenger.setMockMethodCallHandler(channel, (_) async => 'cancelled');
      expect(await save(), VideoDownloadStatus.cancelled);
    },
  );
}
