import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:zephyr/page/video/video_seek_preview_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('breeze.video.seek-preview');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final requests = <Map<Object?, Object?>>[];
  final preparations = <Map<Object?, Object?>>[];
  final replies = <Completer<Uint8List?>>[];
  final cancellations = <int>[];
  final closedSources = <int>[];

  setUp(() {
    requests.clear();
    preparations.clear();
    replies.clear();
    cancellations.clear();
    closedSources.clear();
    messenger.setMockMethodCallHandler(channel, (call) {
      if (call.method == 'prepare') {
        preparations.add((call.arguments as Map).cast<Object?, Object?>());
        return Future.value(null);
      }
      if (call.method == 'cancel') {
        cancellations.add(call.arguments as int);
        return Future.value(null);
      }
      if (call.method == 'close') {
        closedSources.add(call.arguments as int);
        return Future.value(null);
      }
      expectSync(call.method, 'frame');
      requests.add((call.arguments as Map).cast<Object?, Object?>());
      final reply = Completer<Uint8List?>();
      replies.add(reply);
      return reply.future;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  VideoPlayerController ready(VideoPlayerController player) {
    player.value = player.value.copyWith(
      isInitialized: true,
      duration: const Duration(seconds: 30),
    );
    addTearDown(player.dispose);
    return player;
  }

  testWidgets('warms a progressive index once and reuses its owner', (
    tester,
  ) async {
    final preview = VideoSeekPreviewController();
    addTearDown(preview.dispose);
    final progressive = ready(
      VideoPlayerController.networkUrl(
        Uri.parse('http://127.0.0.1:1234/active-lease.bin'),
      ),
    );
    final hls = ready(
      VideoPlayerController.networkUrl(
        Uri.parse('https://example.test/stream.m3u8'),
      ),
    );
    preview.prepare(hls);
    preview.prepare(progressive);
    preview.prepare(progressive);
    await tester.pump();
    expect(preparations, hasLength(1));
    expect(preparations.single['url'], progressive.dataSource);
    expect(requests, isEmpty);
    preview.update(progressive, const Duration(seconds: 7));
    await tester.pump(const Duration(milliseconds: 160));
    expect(requests.single['owner'], preparations.single['owner']);
    preview.setForeground(false);
    await tester.pump();
    expect(closedSources, [preparations.single['owner']]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Android reuses playback headers and cancels old source frames', (
    tester,
  ) async {
    final preview = VideoSeekPreviewController();
    addTearDown(preview.dispose);
    final online = ready(
      VideoPlayerController.networkUrl(
        Uri.parse('https://example.test/manifest'),
        formatHint: VideoFormat.hls,
        httpHeaders: const {'Referer': 'https://example.test/watch'},
      ),
    );
    final local = ready(VideoPlayerController.file(File('/media/episode.mp4')));
    final unsupported = ready(
      VideoPlayerController.networkUrl(Uri.parse('rtsp://example.test/video')),
    );
    expect(VideoSeekPreviewController.supports(online), isTrue);
    expect(VideoSeekPreviewController.supports(local), isTrue);
    expect(VideoSeekPreviewController.supports(unsupported), isFalse);

    preview.update(online, const Duration(seconds: 40));
    await tester.pump();
    final onlineRequest = requests.single;
    expect(onlineRequest['url'], online.dataSource);
    expect(onlineRequest['headers'], online.httpHeaders);
    expect(onlineRequest['streaming'], isTrue);
    expect(onlineRequest['milliseconds'], 29000);

    preview.update(local, const Duration(milliseconds: 4500));
    await tester.pump();
    expect(cancellations, [onlineRequest['id']]);
    expect(closedSources, [onlineRequest['owner']]);
    expect(requests.last['url'], local.dataSource);
    expect(requests.last['streaming'], isFalse);
    expect(requests.last['milliseconds'], 4000);
    replies.first.complete(Uint8List.fromList([1]));
    await tester.pump();
    expect(preview.frame, isNull);

    final localFrame = Uint8List.fromList([2]);
    replies.last.complete(localFrame);
    await tester.pump();
    expect(preview.frame, localFrame);
    preview.endScrub();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('preserves the current relay and headers, queues only latest, '
      'and reuses a frame in the same quantized bucket', (tester) async {
    final preview = VideoSeekPreviewController();
    addTearDown(preview.dispose);
    final player = ready(
      VideoPlayerController.networkUrl(
        Uri.parse('http://127.0.0.1:1234/active-lease.m3u8'),
        httpHeaders: {'Referer': 'https://example.test/watch'},
      ),
    );
    preview.update(player, const Duration(milliseconds: 1800));
    await tester.pump();
    expect(requests.single, {
      'id': isA<int>(),
      'owner': isA<int>(),
      'url': player.dataSource,
      'headers': player.httpHeaders,
      'milliseconds': 1000,
      'streaming': true,
      'wideThumbnail': false,
    });
    preview.update(player, const Duration(seconds: 8));
    preview.update(player, const Duration(seconds: 12));
    await tester.pump(const Duration(milliseconds: 100));
    expect(requests, hasLength(1));
    replies[0].complete(Uint8List.fromList([1]));
    await tester.pump();
    expect(preview.frame, isNull);
    await tester.pump(const Duration(milliseconds: 160));
    expect(requests.map((request) => request['milliseconds']), [1000, 12000]);
    replies[1].complete(Uint8List.fromList([12]));
    await tester.pump();
    expect(preview.frame, [12]);
    preview.update(player, const Duration(milliseconds: 1930));
    expect(preview.frame, [1]);
    await tester.pump(const Duration(milliseconds: 400));
    expect(requests, hasLength(2));
    expect(requests[1]['owner'], requests[0]['owner']);
    preview.update(player, const Duration(seconds: 26));
    await tester.pump();
    expect(requests, hasLength(3));
    expect(preview.frame, [1]);
    replies.last.complete(Uint8List.fromList([26]));
    await tester.pump();
    expect(preview.frame, [26]);
    preview.endScrub();
    expect(preview.frame, isNull);
    expect(closedSources, isEmpty);
    preview.update(player, const Duration(milliseconds: 1700));
    expect(preview.frame, [1]);
    preview.clear();
    await tester.pump();
    expect(closedSources, [requests[0]['owner']]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('a progressive frame survives a slow back-and-forth sweep', (
    tester,
  ) async {
    final preview = VideoSeekPreviewController();
    addTearDown(preview.dispose);
    final player = ready(
      VideoPlayerController.networkUrl(
        Uri.parse('http://127.0.0.1:1234/active-lease.bin'),
      ),
    );
    preview.update(player, const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 160));
    expect(requests.single['milliseconds'], 2000);

    for (final second in [8, 14, 10, 5, 2]) {
      preview.update(player, Duration(seconds: second));
      await tester.pump(const Duration(milliseconds: 330));
    }

    expect(cancellations, isEmpty);
    expect(requests, hasLength(1));
    replies.single.complete(Uint8List.fromList([2]));
    await tester.pump();
    expect(preview.frame, [2]);
    preview.endScrub();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('a settled progressive target replaces an obsolete read', (
    tester,
  ) async {
    final preview = VideoSeekPreviewController();
    addTearDown(preview.dispose);
    final player = ready(
      VideoPlayerController.networkUrl(
        Uri.parse('http://127.0.0.1:1234/active-lease.bin'),
      ),
    );
    preview.update(player, const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 80));
    preview.update(player, const Duration(seconds: 8));
    await tester.pump(const Duration(milliseconds: 80));
    expect(requests.single['milliseconds'], 8000);

    preview.update(player, const Duration(seconds: 20));
    await tester.pump(const Duration(milliseconds: 1799));
    expect(cancellations, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(cancellations, [requests.single['id']]);
    await tester.pump(const Duration(milliseconds: 160));
    expect(requests.last['milliseconds'], 20000);
    replies.last.complete(Uint8List.fromList([20]));
    await tester.pump();
    expect(preview.frame, [20]);
    preview.endScrub();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('progressive preview retries an empty bucket once without '
      'showing a distant frame', (tester) async {
    final preview = VideoSeekPreviewController();
    addTearDown(preview.dispose);
    final player = ready(
      VideoPlayerController.networkUrl(
        Uri.parse('http://127.0.0.1:1234/active-lease.bin'),
      ),
    );
    const interval = Duration(milliseconds: 160);
    preview.update(player, const Duration(seconds: 2));
    await tester.pump(interval);
    replies.last.complete(null);
    await tester.pump();
    await tester.pump(interval);
    expect(requests.map((request) => request['milliseconds']), [2000, 2000]);
    replies.last.complete(Uint8List.fromList([2]));
    await tester.pump();
    expect(preview.frame, [2]);
    preview.update(player, const Duration(seconds: 3));
    expect(preview.frame, [2]);
    preview.update(player, const Duration(seconds: 20));
    expect(preview.frame, isNull);
    await tester.pump(interval);
    replies.last.complete(null);
    await tester.pump();
    await tester.pump(interval);
    replies.last.complete(null);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(requests.map((request) => request['milliseconds']), [
      2000,
      2000,
      20000,
      20000,
    ]);
    expect(preview.frame, isNull);
    preview.endScrub();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('a quick progressive scrub commits without an origin fetch', (
    tester,
  ) async {
    final preview = VideoSeekPreviewController();
    addTearDown(preview.dispose);
    final player = ready(
      VideoPlayerController.networkUrl(
        Uri.parse('http://127.0.0.1:1234/active-lease.bin'),
      ),
    );
    preview.update(player, const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 40));
    preview.update(player, const Duration(seconds: 14));
    await tester.pump(const Duration(milliseconds: 40));
    preview.endScrub();
    await tester.pump(const Duration(seconds: 2));
    expect(requests, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('a settled online target supersedes a slow frame request', (
    tester,
  ) async {
    final preview = VideoSeekPreviewController();
    addTearDown(preview.dispose);
    final player = ready(
      VideoPlayerController.networkUrl(
        Uri.parse('https://example.test/vod.m3u8'),
      ),
    );
    preview.update(player, const Duration(seconds: 2));
    await tester.pump();
    preview.update(player, const Duration(seconds: 8));
    await tester.pump(const Duration(milliseconds: 100));
    preview.update(player, const Duration(seconds: 14));
    await tester.pump(const Duration(milliseconds: 159));
    expect(requests.map((request) => request['milliseconds']), [2000]);
    await tester.pump(const Duration(milliseconds: 1));
    expect(requests.map((request) => request['milliseconds']), [2000, 14000]);
    expect(cancellations, [requests[0]['id']]);
    replies[1].complete(Uint8List.fromList([14]));
    await tester.pump();
    expect(preview.frame, [14]);
    replies[0].complete(Uint8List.fromList([2]));
    await tester.pump();
    expect(preview.frame, [14]);
    preview.endScrub();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'cancels previous sources and ignores background and late frames',
    (tester) async {
      final preview = VideoSeekPreviewController();
      addTearDown(preview.dispose);
      final old = ready(VideoPlayerController.file(File('/private/old.mp4')));
      final current = ready(
        VideoPlayerController.file(File('/private/current.mp4')),
      );
      preview.update(old, const Duration(seconds: 3));
      await tester.pump();
      preview.update(current, const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 160));
      expect(cancellations, [requests[0]['id']]);
      expect(closedSources, [requests[0]['owner']]);
      expect(requests[1]['owner'], isNot(requests[0]['owner']));
      expect(requests[1]['url'], current.dataSource);
      replies[0].complete(Uint8List.fromList([3]));
      await tester.pump();
      expect(preview.frame, isNull);
      preview.setForeground(false);
      preview.update(current, const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 160));
      expect(cancellations, [requests[0]['id'], requests[1]['id']]);
      replies[1].complete(Uint8List.fromList([4]));
      await tester.pump();
      preview.setForeground(true);
      await tester.pump(const Duration(milliseconds: 160));
      expect(requests, hasLength(2));
      expect(preview.frame, isNull);
      preview.update(current, const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 160));
      replies[2].complete(Uint8List.fromList([6]));
      await tester.pump();
      expect(preview.frame, [6]);
      preview.clear();
      expect(preview.frame, isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('a stalled response is cancelled before the latest target runs', (
    tester,
  ) async {
    final preview = VideoSeekPreviewController();
    addTearDown(preview.dispose);
    final player = ready(
      VideoPlayerController.file(File('/private/movie.mp4')),
    );
    preview.update(player, const Duration(seconds: 3));
    preview.update(player, const Duration(seconds: 7));
    await tester.pump(const Duration(milliseconds: 2499));
    expect(requests, hasLength(1));
    expect(cancellations, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(cancellations, [requests[0]['id']]);
    expect(requests[1]['milliseconds'], 7000);
    replies[0].complete(Uint8List.fromList([3]));
    await tester.pump();
    expect(preview.frame, isNull);
    replies[1].complete(Uint8List.fromList([7]));
    await tester.pump(const Duration(milliseconds: 160));
    expect(preview.frame, [7]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('uninitialized players and unavailable previews stay time-only', (
    tester,
  ) async {
    final preview = VideoSeekPreviewController();
    addTearDown(preview.dispose);
    final player = VideoPlayerController.networkUrl(
      Uri.parse('https://example.test/normal.m3u8'),
    );
    preview.update(player, const Duration(seconds: 4));
    await tester.pump();
    expect(requests, isEmpty);
    ready(player);
    for (final second in [4, 5]) {
      preview.update(player, Duration(seconds: second));
      await tester.pump(const Duration(milliseconds: 160));
      replies.last.complete(null);
      await tester.pump();
    }
    preview.update(player, const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 500));
    expect(requests, hasLength(2));
    expect(preview.frame, isNull);
    preview.update(player, const Duration(seconds: 20));
    await tester.pump();
    expect(requests.last['milliseconds'], 20000);
    replies.last.complete(Uint8List.fromList([20]));
    await tester.pump();
    expect(preview.frame, [20]);
    preview.endScrub();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
