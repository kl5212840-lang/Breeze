import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/download/ios_download_continuation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_download.dart';
import 'package:zephyr/page/video/video_episode_download_queue.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_hls_assets.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import '../download_fixture.dart';

const _source = 'episode-download-fixture';
Uri _watch(int index) => Uri.parse(
  'https://episode-fixture.test/voddetail/42.html?line=main&episode=$index',
);
NativeVideoCard _episode(int index) => NativeVideoCard(
  title: 'Series',
  watchUrl: _watch(index),
  coverUrl: null,
  episodeLabel: 'Episode $index',
);

class _NativeQueueHost {
  final rows = <String, Map<String, dynamic>>{};
  final candidates = <String, Map<String, dynamic>>{};
  final started = <Uri>[];
  final firstStarted = Completer<void>();
  final firstResult = Completer<Object?>();
  final secondStarted = Completer<void>();
  final thirdStarted = Completer<void>();
  Completer<Object?>? secondResult;
  int concurrent = 0, maxConcurrent = 0, commits = 0, discards = 0;
  bool failSecond = false;

  Future<Object?> invoke(MethodCall call) async {
    final args = call.arguments is Map ? call.arguments as Map : const {};
    switch (call.method) {
      case 'list':
        return rows.values.toList();
      case 'start':
        concurrent++;
        if (concurrent > maxConcurrent) maxConcurrent = concurrent;
        final page = Uri.parse(args['video'] as String);
        started.add(page);
        try {
          if (started.length == 1) {
            firstStarted.complete();
            final result = await firstResult.future;
            if (result != null) return result;
          }
          if (page == _watch(2)) {
            if (!secondStarted.isCompleted) secondStarted.complete();
            final result = await secondResult?.future;
            if (result != null) return result;
          }
          if (page == _watch(3) && !thirdStarted.isCompleted) {
            thirdStarted.complete();
          }
          if (failSecond && page == _watch(2))
            return {
              'status': 'failed',
              'failureStage': 'nativeTransfer',
              'failureDomain': 'NSURLErrorDomain',
              'failureCode': -1009,
              'underlyingDomain': 'NSPOSIXErrorDomain',
              'underlyingCode': 54,
              'message': 'secret signed URL',
            };
          final id = args['managedId'] as String;
          final row = <String, dynamic>{
            'format': 'hls',
            'resourceId': id,
            'source': args['source'],
            'url': page.toString(),
            'title': args['title'],
            'quality': args['quality'],
            'bytes': 4096,
            'taskKey': args['taskKey'],
            'showTask': true,
            'at': DateTime.now().millisecondsSinceEpoch,
            'assetId': 'asset-${started.length}',
            'generation': 'generation-${started.length}',
            'available': true,
            'filePresent': true,
            'durationMs': 120000,
          };
          candidates[id] = row;
          return {...row, 'status': 'staged'};
        } finally {
          concurrent--;
        }
      case 'commit':
        commits++;
        final id = args['resourceId'] as String;
        rows[id] = candidates.remove(id)!;
        return rows[id];
      case 'discard':
        discards++;
        candidates.clear();
        return true;
      case 'cancel':
        if (!firstResult.isCompleted) firstResult.complete('cancelled');
        return null;
      default:
        throw MissingPluginException();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _NativeQueueHost native;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await useIsolatedDownloadFixture();
    VideoLocalResources.invalidate();
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = previous);
    native = _NativeQueueHost();
    messenger.setMockMethodCallHandler(VideoHlsAssets.channel, native.invoke);
    addTearDown(
      () => messenger.setMockMethodCallHandler(VideoHlsAssets.channel, null),
    );
  });

  Future<VideoResolvedEpisodeDownload> resolve(NativeVideoCard episode) async =>
      (
        session: NativePlaybackSession(
          title: episode.title,
          watchUrl: episode.watchUrl,
          sources: [
            NativePlaybackSource(
              label: '720p',
              headers: const {},
              url: Uri.parse(
                'https://cdn-fixture.test/video.m3u8?signature=ephemeral',
              ),
            ),
          ],
          description: '',
          tags: const [],
        ),
        sourceDuration: null,
      );

  test(
    'account change after activity registration finishes the exact queued attempt',
    () async {
      final binding = TestWidgetsFlutterBinding.instance;
      final previousLifecycle = binding.lifecycleState;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final calls = <MethodCall>[];
      var resolved = 0;
      VideoSystemDownload.concurrencyLimitForTesting = () => 1;
      messenger.setMockMethodCallHandler(IosDownloadContinuation.channel, (
        call,
      ) async {
        calls.add(call);
        if (call.method == 'begin') {
          // The owner is registered, but the queue has not entered its runner.
          pluginSessionWriteFence.advance(_source);
          return {'accepted': true};
        }
        return true;
      });
      try {
        final keys = await VideoEpisodeDownloadQueue.enqueue(
          source: _source,
          episodes: [_episode(1)],
          resolve: (episode) {
            resolved++;
            return resolve(episode);
          },
          userInitiated: true,
        );
        await VideoEpisodeDownloadQueue.flush();
        expect(resolved, 0);
        expect(native.started, isEmpty);
        final row = (await VideoExportRecords.readTaskSnapshot()).singleWhere(
          (row) => row['key'] == keys.single,
        );
        expect(row['status'], 'cancelled');
        expect(VideoSystemDownload.isQueuedTask(keys.single), isFalse);
        expect(calls.map((call) => call.method), ['begin', 'end']);
        final begin = calls.first.arguments as Map,
            end = calls.last.arguments as Map;
        expect(end, {
          'scope': 'video',
          'token': begin['token'],
          'success': false,
        });
        final available = await VideoSystemDownload.reserve(
          current: () => true,
        ).timeout(const Duration(seconds: 2));
        expect(available, isNotNull);
        available?.release();
      } finally {
        messenger.setMockMethodCallHandler(
          IosDownloadContinuation.channel,
          null,
        );
        VideoSystemDownload.concurrencyLimitForTesting = null;
        if (previousLifecycle != null)
          binding.handleAppLifecycleStateChanged(previousLifecycle);
      }
    },
  );

  test(
    'recovery preserves an explicit quality and never silently substitutes the first resolved option',
    () async {
      var released = 0;
      final keys = await VideoEpisodeDownloadQueue.enqueue(
        source: _source,
        episodes: [_episode(1)],
        preferredQuality: '1080p',
        preferredFormat: 'hls',
        resolve: resolve,
        release: () async {
          released++;
        },
      );
      await VideoEpisodeDownloadQueue.flush();
      expect(native.started, isEmpty);
      final row = (await VideoExportRecords.readTaskSnapshot()).singleWhere(
        (row) => row['key'] == keys.single,
      );
      expect(row['quality'], '1080p');
      expect(row['format'], 'hls');
      expect(row['status'], 'failed');
      expect(row['failureReason'], 'qualityUnavailable');
      expect(released, 1);
    },
  );

  test(
    'recovery coalesces only the requested live quality and format',
    () async {
      VideoSystemDownload.concurrencyLimitForTesting = () => 1;
      addTearDown(() => VideoSystemDownload.concurrencyLimitForTesting = null);
      Future<String> enqueue({String? quality, String? format}) async =>
          (await VideoEpisodeDownloadQueue.enqueue(
            source: _source,
            episodes: [_episode(1)],
            resolve: resolve,
            retryItemId: '42',
            preferredQuality: quality,
            preferredFormat: format,
          )).single;

      try {
        final original = await enqueue(quality: '720p', format: 'hls');
        await native.firstStarted.future.timeout(const Duration(seconds: 3));
        expect(await enqueue(), original);

        final otherQuality = await enqueue(quality: '1080p', format: 'hls');
        expect(otherQuality, isNot(original));
        final otherFormat = await enqueue(quality: '720p', format: 'mp4');
        expect(otherFormat, isNot(anyOf(original, otherQuality)));
        expect(await enqueue(quality: '1080p', format: 'hls'), otherQuality);
        expect(await enqueue(quality: '720p', format: 'mp4'), otherFormat);
        expect(await enqueue(quality: '720p'), original);

        final rows = await VideoExportRecords.readTaskSnapshot();
        final qualityRow = rows.singleWhere(
          (row) => row['key'] == otherQuality,
        );
        final formatRow = rows.singleWhere((row) => row['key'] == otherFormat);
        expect((qualityRow['quality'], qualityRow['format']), ('1080p', 'hls'));
        expect(
          (formatRow['quality'], formatRow['format'] ?? 'mp4'),
          ('720p', 'mp4'),
        );
      } finally {
        if (!native.firstResult.isCompleted) native.firstResult.complete(null);
        await VideoEpisodeDownloadQueue.flush();
      }
    },
  );

  test(
    'two iOS slots transfer the same work concurrently and admit the next episode as one slot frees',
    () async {
      VideoSystemDownload.concurrencyLimitForTesting = () => 2;
      addTearDown(() => VideoSystemDownload.concurrencyLimitForTesting = null);
      final second = native.secondResult = Completer<Object?>();
      final resolved = <Uri>[];
      final keys = await VideoEpisodeDownloadQueue.enqueue(
        source: _source,
        episodes: [for (var index = 1; index <= 3; index++) _episode(index)],
        resolve: (episode) async {
          resolved.add(episode.watchUrl);
          return resolve(episode);
        },
      );
      try {
        await native.secondStarted.future.timeout(const Duration(seconds: 3));
        expect(native.started, [_watch(1), _watch(2)]);
        expect(resolved, [_watch(1), _watch(2)]);
        expect(native.concurrent, 2);
        expect(native.firstResult.isCompleted, isFalse);
        second.complete(null);
        await native.thirdStarted.future.timeout(const Duration(seconds: 3));
        expect(native.started, [_watch(1), _watch(2), _watch(3)]);
        expect(native.firstResult.isCompleted, isFalse);
        expect(native.maxConcurrent, 2);
      } finally {
        if (!second.isCompleted) second.complete(null);
        native.firstResult.complete(null);
        await VideoEpisodeDownloadQueue.flush();
      }
      final tasks = await VideoExportRecords.readTaskSnapshot();
      expect(
        [
          for (final key in keys)
            tasks.singleWhere((row) => row['key'] == key)['status'],
        ],
        ['saved', 'saved', 'saved'],
      );
      expect(native.commits, 3);
    },
  );

  test(
    'selection persists public pending rows, resolves serially and continues after a failed episode',
    () async {
      final resolved = <Uri>[];
      var released = 0;
      native.failSecond = true;
      final keys = await VideoEpisodeDownloadQueue.enqueue(
        source: _source,
        episodes: [for (var i = 1; i <= 3; i++) _episode(i)],
        resolve: (episode) async {
          resolved.add(episode.watchUrl);
          return resolve(episode);
        },
        release: () async {
          released++;
        },
      );
      await native.firstStarted.future;
      expect(resolved, [_watch(1)]);
      final pending = await VideoExportRecords.readTasks();
      expect(pending, hasLength(3));
      expect(
        pending
            .where((row) => row['quality'] == '')
            .every((row) => row['received'] == null),
        isTrue,
      );
      final raw = (await SharedPreferences.getInstance()).getString(
        VideoExportRecords.taskStorageKey,
      )!;
      expect(raw, isNot(contains('signature')));
      expect(raw, isNot(contains('cdn-fixture')));
      expect(released, 0);
      native.firstResult.complete(null);
      await VideoEpisodeDownloadQueue.flush();
      expect(resolved, [_watch(1), _watch(2), _watch(3)]);
      expect(native.maxConcurrent, 1);
      expect(native.commits, 2);
      final tasks = await VideoExportRecords.readTasks();
      expect(
        [
          for (final key in keys)
            tasks.singleWhere((row) => row['key'] == key)['status'],
        ],
        ['saved', 'failed', 'saved'],
      );
      expect(released, 1);
      final failed = tasks.singleWhere((row) => row['key'] == keys[1]);
      expect(failed['failureStage'], 'nativeTransfer');
      expect(failed['failureDomain'], 'NSURLErrorDomain');
      expect(failed['failureCode'], -1009);
      expect(failed['underlyingDomain'], 'NSPOSIXErrorDomain');
      expect(failed['underlyingCode'], 54);
      final persisted = (await SharedPreferences.getInstance()).getString(
        VideoExportRecords.taskStorageKey,
      )!;
      expect(persisted, isNot(contains('secret signed URL')));
      final restarted = await VideoExportRecords.restartTransfer(failed);
      expect(restarted!['underlyingDomain'], isNull);
      expect(restarted['underlyingCode'], isNull);
      await VideoExportRecords.updateTransfer(
        keys[1],
        received: null,
        status: 'cancelled',
        terminal: true,
      );
    },
  );

  test('resolution failures record only a fixed stage', () async {
    final keys = await VideoEpisodeDownloadQueue.enqueue(
      source: _source,
      episodes: [_episode(1)],
      resolve: (_) async => throw StateError('private signed URL'),
    );
    await VideoEpisodeDownloadQueue.flush();
    final row = (await VideoExportRecords.readTaskSnapshot()).singleWhere(
      (row) => row['key'] == keys.single,
    );
    expect(row['status'], 'failed');
    expect(row['failureStage'], 'resolution');
    final persisted = (await SharedPreferences.getInstance()).getString(
      VideoExportRecords.taskStorageKey,
    )!;
    expect(persisted, isNot(contains('private signed URL')));
    final restarted = await VideoExportRecords.restartTransfer(row);
    expect(restarted, isNotNull);
    expect(restarted!['failureStage'], isNull);
    await VideoExportRecords.updateTransfer(
      keys.single,
      received: null,
      status: 'failed',
      terminal: true,
      failureStage: 'private signed URL',
      failureDomain: 'private domain',
      failureCode: 42,
      underlyingDomain: 'private underlying domain',
      underlyingCode: 43,
    );
    final updated = (await VideoExportRecords.readTaskSnapshot()).singleWhere(
      (row) => row['key'] == keys.single,
    );
    expect(updated['failureStage'], isNull);
    expect(updated['failureDomain'], isNull);
    expect(updated['failureCode'], isNull);
    expect(updated['underlyingDomain'], isNull);
    expect(updated['underlyingCode'], isNull);
  });

  test(
    'download-center cancellation stops only its exact episode and preserves its queued sibling',
    () async {
      final resolved = <Uri>[];
      var released = 0;
      final keys = await VideoEpisodeDownloadQueue.enqueue(
        source: _source,
        episodes: [_episode(1), _episode(2)],
        resolve: (episode) async {
          resolved.add(episode.watchUrl);
          return resolve(episode);
        },
        release: () async {
          released++;
        },
      );
      await native.firstStarted.future;
      await VideoSystemDownload.cancelTask(keys.first);
      await VideoEpisodeDownloadQueue.flush();
      expect(resolved, [_watch(1), _watch(2)]);
      expect(native.commits, 1);
      final rows = await VideoExportRecords.readTasks();
      expect(
        rows.singleWhere((row) => row['key'] == keys.first)['status'],
        'cancelled',
      );
      expect(
        rows.singleWhere((row) => row['key'] == keys.last)['status'],
        'saved',
      );
      expect(released, 1);
    },
  );

  test(
    'queue waits for an existing single download instead of losing episodes as busy',
    () async {
      final manual = VideoSystemDownload().save(
        choice: (
          label: '720p',
          url: Uri.parse('https://cdn-fixture.test/manual.m3u8'),
          format: 'hls',
        ),
        source: _source,
        video: _watch(0),
        title: 'Manual download',
        onProgress: (_) {},
      );
      await native.firstStarted.future;
      final resolved = <Uri>[];
      final keys = await VideoEpisodeDownloadQueue.enqueue(
        source: _source,
        episodes: [_episode(1), _episode(2)],
        resolve: (episode) async {
          resolved.add(episode.watchUrl);
          return resolve(episode);
        },
      );
      await Future<void>.delayed(Duration.zero);
      expect(resolved, isEmpty);
      native.firstResult.complete(null);
      expect(await manual, VideoDownloadStatus.saved);
      await VideoEpisodeDownloadQueue.flush();
      expect(native.started, [_watch(0), _watch(1), _watch(2)]);
      expect(native.maxConcurrent, 1);
      final tasks = await VideoExportRecords.readTasks();
      expect(
        keys.every(
          (key) =>
              tasks.singleWhere((row) => row['key'] == key)['status'] ==
              'saved',
        ),
        isTrue,
      );
    },
  );

  test(
    'different direct works persist before waiting and execute one native transfer at a time',
    () async {
      Future<VideoDownloadStatus> save(VideoSystemDownload engine, Uri page) =>
          engine.save(
            source: _source,
            video: page,
            title: 'Direct work',
            choice: (
              label: '720p',
              url: Uri.parse(
                'https://cdn-fixture.test/direct.m3u8?signature=temporary',
              ),
              format: 'hls',
            ),
            onProgress: (_) {},
          );
      final first = save(VideoSystemDownload(), _watch(0));
      await native.firstStarted.future;
      final otherPage = _watch(1).replace(path: '/voddetail/99.html');
      final second = save(VideoSystemDownload(), otherPage);
      addTearDown(() async {
        if (!native.firstResult.isCompleted)
          native.firstResult.complete('cancelled');
        await Future.wait([first, second]);
      });
      for (
        var i = 0;
        i < 30 && VideoExportRecords.sessionTaskSnapshot().length < 2;
        i++
      ) {
        await Future<void>.delayed(Duration.zero);
      }
      final pending = (await VideoExportRecords.readTaskSnapshot()).singleWhere(
        (row) => row['url'] == '$otherPage',
      );
      expect(pending['status'], 'preparing');
      expect(pending['received'], isNull);
      expect(pending['quality'], '720p');
      expect(pending['format'], 'hls');
      expect(pending.toString(), isNot(contains('signature=')));
      expect(native.started, [_watch(0)]);
      native.firstResult.complete(null);
      expect(await first, VideoDownloadStatus.saved);
      expect(await second, VideoDownloadStatus.saved);
      expect(native.started, [_watch(0), otherPage]);
      expect(native.maxConcurrent, 1);
    },
  );
  test(
    'cancelling a queued direct work does not cancel the active work or duplicate its task',
    () async {
      Future<VideoDownloadStatus> save(
        VideoSystemDownload engine,
        int episode,
      ) => engine.save(
        source: _source,
        video: _watch(episode),
        title: 'Direct work',
        choice: (
          label: '720p',
          url: Uri.parse('https://cdn-fixture.test/direct.m3u8'),
          format: 'hls',
        ),
        onProgress: (_) {},
      );
      final first = save(VideoSystemDownload(), 0);
      await native.firstStarted.future;
      final waiting = VideoSystemDownload();
      final second = save(waiting, 1);
      addTearDown(() async {
        if (!native.firstResult.isCompleted)
          native.firstResult.complete('cancelled');
        await Future.wait([first, second]);
      });
      for (var i = 0; i < 30 && waiting.lastTaskKey == null; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(waiting.lastTaskKey, isNotNull);
      expect(
        await save(VideoSystemDownload(), 0),
        VideoDownloadStatus.busy,
        reason:
            'a true same-resource duplicate remains distinct from another work waiting',
      );
      await VideoSystemDownload.cancelTask(waiting.lastTaskKey!);
      expect(await second, VideoDownloadStatus.cancelled);
      expect(native.firstResult.isCompleted, isFalse);
      expect(native.started, [_watch(0)]);
      final rows = await VideoExportRecords.readTaskSnapshot();
      expect(rows, hasLength(2));
      expect(
        rows.singleWhere((row) => row['key'] == waiting.lastTaskKey)['status'],
        'cancelled',
      );
      native.firstResult.complete(null);
      expect(await first, VideoDownloadStatus.saved);
    },
  );

  test(
    'restored pending public episode records are interrupted without resolving or resuming',
    () async {
      await (await SharedPreferences.getInstance()).setString(
        VideoExportRecords.taskStorageKey,
        jsonEncode([
          {
            'key': 'previous-process-episode',
            'kind': 'transfer',
            'source': _source,
            'title': 'Episode',
            'url': _watch(1).toString(),
            'quality': '',
            'received': null,
            'at': 1700000000000,
            'status': 'preparing',
          },
        ]),
      );
      final row = (await VideoExportRecords.readTasks()).single;
      expect(row['status'], 'interrupted');
      expect(row['received'], isNull);
      expect(native.started, isEmpty);
    },
  );

  test('only the matching recovered MP4 attempt remains active', () async {
    const key = 'previous-process-mp4';
    final prefs = await SharedPreferences.getInstance();
    final row = {
      'key': key,
      'kind': 'transfer',
      'source': _source,
      'title': 'Episode',
      'url': _watch(1).toString(),
      'quality': '720p',
      'at': 1700000000000,
      'status': 'downloading',
      'attempt': 2,
    };
    await prefs.setString(VideoExportRecords.taskStorageKey, jsonEncode([row]));
    addTearDown(() => VideoExportRecords.setRecoveredMp4Tasks({}));
    VideoExportRecords.setRecoveredMp4Tasks({key: 1});
    expect(
      (await VideoExportRecords.readTaskSnapshot()).single['status'],
      'interrupted',
    );
    VideoExportRecords.setRecoveredMp4Tasks({key: 2});
    expect(
      (await VideoExportRecords.readTaskSnapshot()).single['status'],
      'downloading',
    );
  });

  test(
    'installation epoch change discards the current package and cancels remaining episodes',
    () async {
      const source = 'c178d83c-153e-45a8-a93a-76ab4e2c3b0e';
      final state = LocalPluginInstallationState.instance;
      await state.reload();
      addTearDown(() async {
        await (await SharedPreferences.getInstance()).remove(
          LocalPluginInstallationState.storageKey,
        );
        await state.reload();
      });
      final resolved = <Uri>[];
      await VideoEpisodeDownloadQueue.enqueue(
        source: source,
        episodes: [_episode(1), _episode(2)],
        resolve: (episode) async {
          resolved.add(episode.watchUrl);
          return resolve(episode);
        },
      );
      await native.firstStarted.future;
      await state.setDataExclusions(source, {
        PluginDataScope.records,
      }, beforeWrite: (_) async {});
      native.firstResult.complete(null);
      await VideoEpisodeDownloadQueue.flush();
      expect(resolved, [_watch(1)]);
      expect(native.commits, 0);
      expect(native.discards, 1);
      expect(native.rows, isEmpty);
      expect(
        (await VideoExportRecords.readTasks()).every(
          (row) => row['status'] == 'cancelled',
        ),
        isTrue,
      );
    },
  );
}
