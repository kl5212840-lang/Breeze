import 'dart:async';
import 'dart:ui' show AppLifecycleState;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/page/donwload_task/service/download_center_removal.dart';
import 'package:zephyr/page/video/video_download.dart';
import 'package:zephyr/page/video/video_download_retry.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_hls_assets.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/service/download/download_admission.dart';
import '../download_fixture.dart';
import '../test_helper.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final connectivity = DownloadConnectivityFixture();
  tearDownAll(connectivity.close);
  const channel = MethodChannel('breeze.video.download');
  const capacity = MethodChannel('breeze.download.capacity');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final jobs = <String, Completer<Object?>>{};
  final arguments = <String, Map>{};
  final nativeCancellations = <String>[];
  final hlsRows = <Map<String, dynamic>>[];
  final futures = <Future<VideoDownloadStatus>>[];
  Map<String, dynamic>? hlsCandidate;
  var limit = 1, shuttingDown = false;
  Uri watch(int id) => Uri.parse('https://hanime1.me/watch?v=$id');
  Future<VideoDownloadStatus> save(
    VideoSystemDownload engine,
    int id, {
    bool hls = false,
    ValueChanged<VideoDownloadProgress>? progress,
  }) {
    final future = engine.save(
      source: 'parallel-download-fixture',
      video: watch(id),
      title: 'Work $id',
      choice: (
        label: '720p',
        format: hls ? 'HLS' : 'MP4',
        url: Uri.parse(
          'https://cdn.test/$id.${hls ? 'm3u8' : 'mp4'}?signature=temporary',
        ),
      ),
      onProgress: progress ?? (_) {},
    );
    futures.add(future);
    return future;
  }

  Future<void> starts(int count) async {
    for (var i = 0; i < 100 && arguments.length < count; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(arguments, hasLength(count));
  }

  String idFor(int id) => arguments.entries
      .singleWhere((entry) => entry.value['referer'] == watch(id).toString())
      .key;
  Future<void> progress(String id, int bytes) =>
      messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('progress', {'id': id, 'received': bytes, 'total': 1000}),
        ),
        (_) {},
      );

  setUp(() async {
    DownloadAdmission.instance.setWifiOnly(false);
    connectivity.set(ConnectivityResult.wifi);
    SharedPreferences.setMockInitialValues({});
    await useIsolatedDownloadFixture();
    VideoLocalResources.invalidate();
    jobs.clear();
    arguments.clear();
    nativeCancellations.clear();
    hlsRows.clear();
    hlsCandidate = null;
    futures.clear();
    shuttingDown = false;
    limit = 1;
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    VideoSystemDownload.concurrencyLimitForTesting = () => limit;
    addTearDown(() async {
      shuttingDown = true;
      for (final job in jobs.values) {
        if (!job.isCompleted) job.complete('cancelled');
      }
      VideoSystemDownload.notifyConcurrencyChanged();
      await Future.wait(futures);
      VideoSystemDownload.concurrencyLimitForTesting = null;
      debugDefaultTargetPlatformOverride = previous;
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(VideoHlsAssets.channel, null);
      messenger.setMockMethodCallHandler(capacity, null);
    });
    Future<Object?> handleNativeTransfer(MethodCall call) async {
      if (call.method == 'list') return hlsRows;
      final args = call.arguments as Map;
      if (call.method == 'start') {
        if (shuttingDown) return 'cancelled';
        final id = args['id'] as String;
        arguments[id] = args;
        return (jobs[id] = Completer<Object?>()).future;
      }
      if (call.method == 'cancel') {
        nativeCancellations.add(args['id'] as String);
        final job = jobs[args['id']];
        if (job != null && !job.isCompleted) job.complete('cancelled');
      }
      if (call.method == 'commit') {
        final candidate = hlsCandidate!;
        expect(args, VideoHlsAssets.binding(candidate));
        hlsRows.add(candidate);
        return candidate;
      }
      return null;
    }

    messenger.setMockMethodCallHandler(
      VideoHlsAssets.channel,
      handleNativeTransfer,
    );
    messenger.setMockMethodCallHandler(channel, handleNativeTransfer);
  });

  Future<Map<String, dynamic>> waitForTask(
    VideoSystemDownload engine,
    bool Function(Map<String, dynamic>) matches,
  ) async {
    for (var i = 0; i < 250; i++) {
      final row = (await VideoExportRecords.readTaskSnapshot())
          .where((row) => row['key'] == engine.lastTaskKey && matches(row))
          .firstOrNull;
      if (row != null) return row;
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    throw StateError('The download did not reach the expected state');
  }

  test('restoring a larger limit admits an already queued transfer', () async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    addTearDown(TestObjectBoxHelper.tearDownTestObjectBox);
    VideoSystemDownload.concurrencyLimitForTesting = null;
    final settings = GlobalSettingCubit();
    addTearDown(settings.close);
    await settings.initBox();

    final first = VideoSystemDownload();
    final next = VideoSystemDownload();
    final active = save(first, 301);
    await starts(1);
    final queued = save(next, 302);
    try {
      final row = await waitForTask(next, (_) => true);
      final key = row['key'] as String;
      final attempt = row['attempt'] as int;
      for (
        var i = 0;
        i < 100 && !VideoSystemDownload.canPrioritize(key, attempt);
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(VideoSystemDownload.canPrioritize(key, attempt), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(arguments, hasLength(1));

      settings.applySyncedState(
        settings.state.copyWith(videoDownloadConcurrency: 2),
      );

      await starts(2);
      expect(jobs[idFor(301)]!.isCompleted, isFalse);
    } finally {
      await first.cancel();
      await next.cancel();
      await Future.wait([active, queued]);
    }
  });

  test(
    'pausing video admission leaves the current transfer alone and resumes the prioritized attempt',
    () async {
      final admission = DownloadAdmission.instance;
      final active = VideoSystemDownload();
      final activeResult = save(active, 310);
      await starts(1);
      await admission.setQueuePaused(true);
      try {
        final first = VideoSystemDownload();
        final next = VideoSystemDownload();
        final firstResult = save(first, 311);
        final firstRow = await waitForTask(first, (_) => true);
        final nextResult = save(next, 312);
        final nextRow = await waitForTask(next, (_) => true);
        final key = nextRow['key'] as String;
        final attempt = nextRow['attempt'] as int;
        for (
          var i = 0;
          i < 100 && !VideoSystemDownload.canPrioritize(key, attempt);
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        expect(VideoSystemDownload.prioritize(key, attempt + 1), isFalse);
        expect(VideoSystemDownload.prioritize(key, attempt), isTrue);
        expect(jobs[idFor(310)]!.isCompleted, isFalse);
        await active.cancel();
        expect(await activeResult, VideoDownloadStatus.cancelled);
        expect(arguments, hasLength(1));
        expect(VideoExportRecords.isLive(firstRow['key'] as String), isTrue);
        await admission.setQueuePaused(false);
        await starts(2);
        expect(arguments.values.last['referer'], watch(312).toString());
        expect(VideoSystemDownload.canPrioritize(key, attempt), isFalse);
        await next.cancel();
        expect(await nextResult, VideoDownloadStatus.cancelled);
        await starts(3);
        expect(arguments.values.last['referer'], watch(311).toString());
        await first.cancel();
        expect(await firstResult, VideoDownloadStatus.cancelled);
      } finally {
        await admission.setQueuePaused(false);
      }
    },
  );

  test(
    'Wi-Fi waits before native transfer and cancel never restarts it',
    () async {
      connectivity.set(ConnectivityResult.mobile);
      DownloadAdmission.instance.setWifiOnly(true);
      final first = VideoSystemDownload();
      final result = save(first, 301);
      await waitForTask(first, (row) => row['failureReason'] == 'waitingWifi');
      expect(arguments, isEmpty);
      await first.cancel();
      expect(await result, VideoDownloadStatus.cancelled);
      final second = VideoSystemDownload();
      final resumed = save(second, 302);
      await waitForTask(second, (row) => row['failureReason'] == 'waitingWifi');
      connectivity.set(ConnectivityResult.wifi);
      await starts(1);
      expect(arguments.values.single['wifiOnly'], isTrue);
      expect(arguments.values.single['referer'], watch(302).toString());
      expect((await waitForTask(second, (_) => true))['failureReason'], isNull);
      await second.cancel();
      expect(await resumed, VideoDownloadStatus.cancelled);
    },
  );

  test(
    'network loss retires the old transfer and resolves the same attempt target',
    () async {
      const source = 'parallel-download-fixture';
      final resolved = <Map<String, dynamic>>[];
      final lease = VideoDownloadRetry.register(source, (row) async {
        resolved.add(row);
        return VideoDownloadRetryResolution(
          choices: [
            (
              label: '720p',
              format: 'MP4',
              url: Uri.parse(
                'https://cdn.test/fresh.mp4?signature=reconnected',
              ),
            ),
          ],
        );
      }, current: () => true);
      addTearDown(() => VideoDownloadRetry.unregister(source, lease));
      final engine = VideoSystemDownload();
      final initial = save(engine, 303);
      await starts(1);
      connectivity.set(ConnectivityResult.none);
      expect(await initial, VideoDownloadStatus.failed);
      final waiting = await waitForTask(
        engine,
        (row) => row['failureReason'] == 'waitingNetwork',
      );
      expect(resolved, isEmpty);
      connectivity.set(ConnectivityResult.wifi);
      await starts(2);
      expect(resolved.single['url'], watch(303).toString());
      expect(resolved.single['attempt'], (waiting['attempt'] as int) + 1);
      expect(arguments.values.last['url'], contains('signature=reconnected'));
      await VideoSystemDownload.cancelTask(engine.lastTaskKey!);
      await waitForTask(engine, (row) => row['status'] == 'cancelled');
    },
  );

  test(
    'background HLS leaves temporary loss and Wi-Fi enforcement to iOS, then commits',
    () async {
      DownloadAdmission.instance.setWifiOnly(true);
      final engine = VideoSystemDownload();
      final result = save(engine, 306, hls: true);
      await starts(1);
      final id = idFor(306), args = arguments[id]!;
      expect(args['wifiOnly'], isTrue);

      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      addTearDown(
        () => binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
      );
      connectivity.set(ConnectivityResult.none);
      await Future<void>.delayed(Duration.zero);
      connectivity.set(ConnectivityResult.mobile);
      await Future<void>.delayed(Duration.zero);
      expect(nativeCancellations, isEmpty);
      expect(VideoSystemDownload.hasActiveTransfer, isTrue);
      expect(arguments, hasLength(1));

      connectivity.set(ConnectivityResult.wifi);
      hlsCandidate = {
        'resourceId': args['managedId'],
        'assetId': 'offline-asset',
        'generation': 'first-generation',
        'format': 'hls',
        'source': args['source'],
        'url': args['video'],
        'title': args['title'],
        'quality': args['quality'],
        'bytes': 1200,
        'taskKey': args['taskKey'],
        'showTask': true,
        'at': 1,
        'available': true,
        'filePresent': true,
      };
      jobs[id]!.complete({'status': 'staged', ...hlsCandidate!});
      expect(await result, VideoDownloadStatus.saved);
      expect(hlsRows.single['taskKey'], engine.lastTaskKey);
      final saved = await waitForTask(
        engine,
        (row) => row['status'] == 'saved',
      );
      expect(saved['resourceId'], args['managedId']);
      expect(saved['failureReason'], isNull);
    },
  );

  test(
    'background HLS re-applies a changed Wi-Fi policy to the native attempt',
    () async {
      final engine = VideoSystemDownload();
      final result = save(engine, 307, hls: true);
      await starts(1);
      final id = idFor(307);
      expect(arguments[id]!.containsKey('wifiOnly'), isFalse);
      DownloadAdmission.instance.setWifiOnly(true);
      await Future<void>.delayed(Duration.zero);
      expect(nativeCancellations, [id]);
      expect(await result, VideoDownloadStatus.failed);
      expect(
        (await waitForTask(engine, (_) => true))['failureReason'],
        'waitingWifi',
      );
    },
  );

  test(
    'background HLS retries only after iOS reports a real network failure',
    () async {
      final resolved = <Map<String, dynamic>>[];
      const source = 'parallel-download-fixture';
      final lease = VideoDownloadRetry.register(source, (row) async {
        resolved.add(row);
        return VideoDownloadRetryResolution(
          choices: [
            (
              label: '720p',
              format: 'HLS',
              url: Uri.parse(
                'https://cdn.test/fresh.m3u8?signature=reconnected',
              ),
            ),
          ],
        );
      }, current: () => true);
      addTearDown(() => VideoDownloadRetry.unregister(source, lease));
      final engine = VideoSystemDownload();
      final result = save(engine, 308, hls: true);
      await starts(1);
      final id = idFor(308);
      connectivity.set(ConnectivityResult.none);
      await Future<void>.delayed(Duration.zero);
      expect(nativeCancellations, isEmpty);
      expect(resolved, isEmpty);

      jobs[id]!.complete({
        'status': 'failed',
        'failureStage': 'nativeTransfer',
        'reason': 'network',
      });
      expect(await result, VideoDownloadStatus.failed);
      final waiting = await waitForTask(
        engine,
        (row) => row['failureReason'] == 'waitingNetwork',
      );
      expect(resolved, isEmpty);
      connectivity.set(ConnectivityResult.wifi);
      await starts(2);
      expect(resolved.single['url'], watch(308).toString());
      expect(resolved.single['attempt'], (waiting['attempt'] as int) + 1);
      expect(arguments.values.last['url'], contains('signature=reconnected'));
      await VideoSystemDownload.cancelTask(engine.lastTaskKey!);
      await waitForTask(engine, (row) => row['status'] == 'cancelled');
    },
  );

  test(
    'known low space stops a managed video before native transfer',
    () async {
      messenger.setMockMethodCallHandler(capacity, (_) async => 1024);
      final engine = VideoSystemDownload();
      expect(await save(engine, 304), VideoDownloadStatus.failed);
      final row = await waitForTask(engine, (row) => row['status'] == 'failed');
      expect(row['failureReason'], 'outOfSpace');
      expect(arguments, isEmpty);
    },
  );

  test(
    'removing a parked transfer cannot recreate it on reconnection',
    () async {
      const source = 'parallel-download-fixture';
      var resolves = 0;
      final lease = VideoDownloadRetry.register(source, (_) async {
        resolves++;
        throw StateError('Removed intent reached the resolver');
      }, current: () => true);
      addTearDown(() => VideoDownloadRetry.unregister(source, lease));
      final engine = VideoSystemDownload();
      final initial = save(engine, 305);
      await starts(1);
      connectivity.set(ConnectivityResult.none);
      expect(await initial, VideoDownloadStatus.failed);
      final waiting = await waitForTask(
        engine,
        (row) => row['failureReason'] == 'waitingNetwork',
      );
      final token = await bindVideoDownloadRemoval(
        source: source,
        page: watch(305),
        quality: '720p',
        displayedTask: waiting,
      );
      await removeVideoDownload(
        source: source,
        page: watch(305),
        quality: '720p',
        expected: token,
      );
      connectivity.set(ConnectivityResult.wifi);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(resolves, 0);
      expect(arguments, hasLength(1));
      expect(
        (await VideoExportRecords.readTaskSnapshot()).where(
          (row) => row['key'] == waiting['key'],
        ),
        isEmpty,
      );
    },
  );

  test(
    'one engine rejects a second save before asynchronous admission begins',
    () async {
      limit = 2;
      final firstStarted = Completer<void>();
      final finishFirst = Completer<Object?>();
      final cancelAccepted = Completer<void>();
      var startsSeen = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'start') {
          startsSeen++;
          if (!firstStarted.isCompleted) firstStarted.complete();
          return finishFirst.future;
        }
        if (call.method == 'cancel') {
          if (!cancelAccepted.isCompleted) cancelAccepted.complete();
        }
        return null;
      });
      final engine = VideoSystemDownload();
      final first = save(engine, 301);
      final second = save(engine, 302);
      expect(await second, VideoDownloadStatus.busy);
      await firstStarted.future;
      expect(startsSeen, 1);
      var settled = false;
      first.then((_) => settled = true);
      await engine.cancel();
      await cancelAccepted.future;
      expect(
        settled,
        false,
        reason: 'cancel acceptance does not release the live native writer',
      );
      finishFirst.complete('cancelled');
      expect(await first, VideoDownloadStatus.cancelled);
      expect(startsSeen, 1);
    },
  );

  test(
    'an unrelated iOS transfer does not block exporting a local copy',
    () async {
      const source = 'parallel-download-fixture';
      final id = VideoLocalResources.identity(source, watch(401), '720p');
      final original = await VideoLocalResources.file(id);
      await original.parent.create(recursive: true);
      await original.writeAsBytes([0, 0, 0, 24, 102, 116, 121, 112]);
      final transfer = Completer<Object?>();
      final started = Completer<void>();
      final export = Completer<String>();
      final exportStarted = Completer<void>();
      addTearDown(() {
        if (!transfer.isCompleted) transfer.complete('cancelled');
        if (!export.isCompleted) export.complete('cancelled');
      });
      messenger.setMockMethodCallHandler(channel, (call) {
        if (call.method == 'start') {
          started.complete();
          return transfer.future;
        }
        expect(call.method, 'export');
        expect(call.arguments['resourceId'], id);
        exportStarted.complete();
        return export.future;
      });
      final downloading = save(VideoSystemDownload(), 402);
      await started.future;
      final exporting = VideoSystemDownload.exportLocal(id, 'Saved video');
      try {
        expect(
          await Future.any([
            exportStarted.future.then((_) => 'picker'),
            exporting,
          ]),
          'picker',
        );
        expect(
          await VideoSystemDownload.exportLocal(id, 'Saved video'),
          VideoDownloadStatus.busy,
        );
        expect(transfer.isCompleted, isFalse);
        export.complete('saved');
        expect(await exporting, VideoDownloadStatus.saved);
        expect(await original.exists(), isTrue);
      } finally {
        if (!export.isCompleted) export.complete('cancelled');
        transfer.complete('cancelled');
        await downloading;
      }
    },
  );

  test(
    'parallel progress is dispatched by id; cancelling A preserves B and lowering only blocks new tasks',
    () async {
      limit = 2;
      final a = VideoSystemDownload(), b = VideoSystemDownload();
      final aProgress = <int>[], bProgress = <int>[];
      final aResult = save(
        a,
        101,
        progress: (value) => aProgress.add(value.received),
      );
      final bResult = save(
        b,
        102,
        progress: (value) => bProgress.add(value.received),
      );
      await starts(2);
      await progress(idFor(102), 200);
      await progress(idFor(101), 100);
      expect(aProgress, [100]);
      expect(bProgress, [200]);
      await a.cancel();
      expect(await aResult, VideoDownloadStatus.cancelled);
      expect(jobs[idFor(102)]!.isCompleted, isFalse);
      await progress(idFor(102), 400);
      await progress(idFor(101), 999);
      expect(aProgress, [100]);
      expect(bProgress, [200, 400]);
      final cResult = save(VideoSystemDownload(), 103);
      await starts(3);
      limit = 1;
      VideoSystemDownload.notifyConcurrencyChanged();
      final dEngine = VideoSystemDownload();
      final dResult = save(dEngine, 104);
      for (var i = 0; i < 100 && dEngine.lastTaskKey == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(dEngine.lastTaskKey, isNotNull);
      jobs[idFor(103)]!.complete('failed');
      expect(await cResult, VideoDownloadStatus.failed);
      expect(arguments, hasLength(3));
      expect(jobs[idFor(102)]!.isCompleted, isFalse);
      jobs[idFor(102)]!.complete('failed');
      expect(await bResult, VideoDownloadStatus.failed);
      await starts(4);
      jobs[idFor(104)]!.complete('failed');
      expect(await dResult, VideoDownloadStatus.failed);
    },
  );

  test(
    'direct cancellation preserves recovery metadata and repeated admission reuses the exact episode attempt',
    () async {
      final first = save(VideoSystemDownload(), 201);
      await starts(1);
      final waiting = VideoSystemDownload();
      final cancelled = save(waiting, 202);
      for (var i = 0; i < 100 && waiting.lastTaskKey == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      final key = waiting.lastTaskKey!;
      await waiting.cancel();
      expect(await cancelled, VideoDownloadStatus.cancelled);
      final before = (await VideoExportRecords.readTaskSnapshot()).singleWhere(
        (row) => row['key'] == key,
      );
      expect(VideoDownloadRetry.canRecover(before), isTrue);
      expect(VideoDownloadRetry.canRetry(before), isTrue);
      expect(before['quality'], '720p');
      expect(
        before.values.any((value) => '$value'.contains('signature=')),
        isFalse,
      );
      expect(await save(VideoSystemDownload(), 201), VideoDownloadStatus.busy);
      final resumed = VideoSystemDownload();
      final next = save(resumed, 202);
      for (var i = 0; i < 100 && resumed.lastTaskKey == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(resumed.lastTaskKey, key);
      final after = (await VideoExportRecords.readTaskSnapshot()).singleWhere(
        (row) => row['key'] == key,
      );
      expect(after['attempt'], (before['attempt'] as int) + 1);
      jobs[idFor(201)]!.complete('failed');
      expect(await first, VideoDownloadStatus.failed);
      await starts(2);
      jobs[idFor(202)]!.complete('failed');
      expect(await next, VideoDownloadStatus.failed);
    },
  );
}
