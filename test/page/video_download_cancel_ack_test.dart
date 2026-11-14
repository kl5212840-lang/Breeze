import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/video/video_download.dart';
import 'package:zephyr/page/video/video_hls_assets.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import '../download_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await useIsolatedDownloadFixture();
    VideoLocalResources.invalidate();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    VideoSystemDownload.concurrencyLimitForTesting = () => 1;
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(VideoHlsAssets.channel, null);
    debugDefaultTargetPlatformOverride = null;
    VideoSystemDownload.concurrencyLimitForTesting = null;
  });
  test(
    'HLS cancellation retains transfer capacity until its exact native task settles',
    () async {
      final firstStarted = Completer<void>(), secondStarted = Completer<void>();
      final firstDone = Completer<Object?>(), secondDone = Completer<Object?>();
      final cancelAccepted = Completer<void>();
      final ids = <String>[];
      messenger.setMockMethodCallHandler(VideoHlsAssets.channel, (call) async {
        final args = call.arguments;
        if (call.method == 'list') return [];
        if (call.method == 'start') {
          ids.add((args as Map)['id'] as String);
          if (ids.length == 1) {
            firstStarted.complete();
            return firstDone.future;
          }
          secondStarted.complete();
          return secondDone.future;
        }
        if (call.method == 'cancel') {
          expect((args as Map)['id'], ids.first);
          if (!cancelAccepted.isCompleted) cancelAccepted.complete();
        }
        return null;
      });
      Future<VideoDownloadStatus> save(VideoSystemDownload engine, int id) =>
          engine.save(
            source: 'cancel-ack-fixture',
            video: Uri.parse('https://site.test/watch?v=$id'),
            title: 'Episode $id',
            choice: (
              label: '720p',
              format: 'HLS',
              url: Uri.parse('https://cdn.test/$id.m3u8'),
            ),
            onProgress: (_) {},
          );
      final first = VideoSystemDownload(), second = VideoSystemDownload();
      final a = save(first, 1);
      await firstStarted.future;
      await first.cancel();
      await cancelAccepted.future;
      final b = save(second, 2);
      await Future<void>.delayed(Duration.zero);
      expect(ids, hasLength(1));
      expect(VideoSystemDownload.hasActiveTransfer, true);
      firstDone.complete('cancelled');
      expect(await a, VideoDownloadStatus.cancelled);
      await secondStarted.future;
      expect(ids, hasLength(2));
      expect(ids[1], isNot(ids[0]));
      secondDone.complete('cancelled');
      expect(await b, VideoDownloadStatus.cancelled);
      expect(VideoSystemDownload.hasActiveTransfer, false);
    },
  );
}
