import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/sync/sync_service.dart'
    show runExclusiveStorageOperation;
import 'package:zephyr/page/donwload_task/service/download_center_projection.dart';
import 'package:zephyr/page/donwload_task/service/download_storage_usage.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_download.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_hls_assets.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_playback_download_adapter.dart';
import 'package:zephyr/page/setting/data_backup/method.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/util/get_path.dart';

import '../download_fixture.dart';

final _watch = Uri.parse(
  'https://site-fixture.test/voddetail/42.html?line=a&episode=one',
);
final _media = Uri.parse(
  'https://cdn-fixture.test/master.m3u8?signature=ephemeral-fixture',
);
const _source = 'hls-fixture';
const _quality = '720p';
String get _id => VideoHlsAssets.identity(_source, _watch, _quality);

Map<String, dynamic> _row({String generation = 'generation-1'}) => {
  'resourceId': _id,
  'assetId': 'asset-1',
  'generation': generation,
  'source': _source,
  'url': _watch.toString(),
  'title': 'HLS fixture',
  'quality': _quality,
  'bytes': 4096,
  'taskKey': 'seed-task',
  'showTask': true,
  'at': 1700000000000,
  'format': 'hls',
  'available': true,
  'filePresent': true,
  'durationMs': 120000,
  'cover': 'https://images-fixture.test/poster.jpg',
};

class _NativeAssets {
  final rows = <Map<String, dynamic>>[];
  final calls = <String>[];
  final hidden = <String>{};
  Map<String, dynamic>? candidate;
  Map<String, dynamic>? playbackArgs;
  bool failCommit = false;
  Completer<Object?>? pending;
  Future<void> Function(Map args)? onStart;
  Future<void> Function()? onList;
  final transactions = <String, List<String>>{};

  Future<Object?> invoke(MethodCall call) async {
    calls.add(call.method);
    final args = call.arguments is Map ? call.arguments as Map : const {};
    switch (call.method) {
      case 'list':
        await onList?.call();
        return [
          for (final row in rows)
            if (!hidden.contains(row['assetId'])) {...row},
        ];
      case 'start':
        candidate = {
          ..._row(generation: 'candidate-2'),
          'assetId': 'asset-2',
          'taskKey': args['taskKey'],
          'resourceId': args['managedId'],
          'source': args['source'],
          'url': args['video'],
          'sourceDuration': args['sourceDuration'] ?? '站点 2:03',
        };
        await onStart?.call(args);
        if (pending != null) return pending!.future;
        return {
          'status': 'staged',
          'resourceId': args['managedId'],
          'assetId': 'asset-2',
          'generation': 'candidate-2',
          'bytes': 4096,
          'durationMs': 120000,
        };
      case 'commit':
        if (failCommit) throw PlatformException(code: 'fixture-commit-failed');
        rows.removeWhere((row) => row['resourceId'] == args['resourceId']);
        rows.add(candidate!);
        candidate = null;
        return {...rows.last};
      case 'discard':
        candidate = null;
        return true;
      case 'cancel':
        if (pending?.isCompleted == false) pending!.complete('cancelled');
        candidate = null;
        return null;
      case 'hideTasks':
        for (final row in rows) {
          if ((args['keys'] as List).contains(row['taskKey']))
            row['showTask'] = false;
        }
        return true;
      case 'delete':
        final matches = rows.where(
          (row) =>
              row['resourceId'] == args['resourceId'] &&
              row['assetId'] == args['assetId'] &&
              row['generation'] == args['generation'],
        );
        if (matches.isEmpty) return false;
        rows.remove(matches.first);
        return true;
      case 'stageRemoval':
        final assets = (args['resources'] as List)
            .map((entry) => (entry as Map)['assetId'] as String)
            .toList();
        transactions['removal-1'] = assets;
        hidden.addAll(assets);
        return 'removal-1';
      case 'rollbackRemoval':
        hidden.removeAll(transactions[args['token']] ?? const []);
        return true;
      case 'commitRemoval':
        final assets = transactions[args['token']] ?? const [];
        rows.removeWhere((row) => assets.contains(row['assetId']));
        hidden.removeAll(assets);
        return true;
      case 'openOffline':
        playbackArgs = Map<String, dynamic>.from(args);
        return {'positionMs': 34000, 'durationMs': 120000, 'completed': false};
      default:
        throw MissingPluginException();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _NativeAssets native;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await useIsolatedDownloadFixture();
    VideoLocalResources.invalidate();
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = previous);
    native = _NativeAssets();
    messenger.setMockMethodCallHandler(VideoHlsAssets.channel, native.invoke);
    addTearDown(
      () => messenger.setMockMethodCallHandler(VideoHlsAssets.channel, null),
    );
  });

  test(
    'saved storage keeps measured bytes when one video inventory fails',
    () async {
      final mp4 = VideoLocalResources.identity(_source, _watch, _quality);
      final file = await VideoLocalResources.file(mp4);
      await file.parent.create(recursive: true);
      await file.writeAsBytes([
        0,
        0,
        0,
        24,
        102,
        116,
        121,
        112,
        ...List.filled(16, 0),
      ]);
      await VideoLocalResources.saved(
        resourceId: mp4,
        bytes: 24,
        source: _source,
        video: _watch,
        title: 'MP4 fixture',
        quality: _quality,
        taskKey: 'mp4-task',
      );
      native.rows.add(_row());
      Future<DownloadStorageUsage> measure() =>
          DownloadStorageUsage.read(comics: const [], current: () => true);

      final complete = await measure();
      expect(complete.knownBytes, 4120);
      expect(complete.partial, isFalse);

      native.onList = () async =>
          throw PlatformException(code: 'unreadable-hls');
      final mp4Only = await measure();
      expect(mp4Only.knownBytes, 24);
      expect(mp4Only.partial, isTrue);

      native.onList = null;
      await File('${file.parent.path}/index.json').writeAsString('malformed');
      final hlsOnly = await measure();
      expect(hlsOnly.knownBytes, 4096);
      expect(hlsOnly.partial, isTrue);
    },
  );

  test(
    'storage inventory reads without waiting for sync or creating a downloads tree',
    () async {
      final files = Directory(await getFilePath(create: false));
      expect(await files.exists(), isFalse);
      final busy = Completer<void>(), started = Completer<void>();
      final sync = runExclusiveStorageOperation(() async {
        started.complete();
        await busy.future;
      });
      await started.future;
      try {
        final usage = await DownloadStorageUsage.read(
          comics: const [],
          current: () => true,
        ).timeout(const Duration(seconds: 2));
        expect(usage.knownBytes, 0);
        expect(usage.partial, isFalse);
        expect(await files.exists(), isFalse);
      } finally {
        busy.complete();
        await sync;
      }
    },
  );

  test(
    'only iOS resolved HLS is exposed; unknown protocols and private headers remain excluded',
    () {
      NativePlaybackSession session(Map<String, String> headers) =>
          NativePlaybackSession(
            title: 'HLS',
            watchUrl: _watch,
            description: '',
            tags: const [],
            sources: [
              NativePlaybackSource(
                url: _media,
                label: _quality,
                headers: headers,
              ),
            ],
          );
      expect(
        VideoPlaybackDownloadAdapter.resolve(
          session(const {}),
        )!.choices.single.format,
        'hls',
      );
      expect(
        VideoPlaybackDownloadAdapter.resolve(
          session({'Cookie': 'fixture-private'}),
        ),
        isNull,
      );
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(VideoPlaybackDownloadAdapter.resolve(session(const {})), isNull);
    },
  );

  test(
    'native HLS package measurements persist separately from media duration and never invent a byte total',
    () async {
      native.onStart = (args) async {
        final response = Completer<void>();
        messenger.handlePlatformMessage(
          'breeze.video.hls',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('progress', {
              'id': args['id'],
              'received': 2048,
              'receivedSource': 'package',
              'packageBytes': 2048,
              'loadedTimeMs': 2400,
              'totalTimeMs': 120000,
              'saving': false,
            }),
          ),
          (_) => response.complete(),
        );
        await response.future;
        await VideoExportRecords.flush();
        final live = (await VideoExportRecords.readTasks()).single;
        expect(live['received'], 2048);
        expect(live['receivedSource'], 'package');
        expect(live['packageBytes'], 2048);
        expect(live['networkBytes'], isNull);
        expect(live['total'], isNull);
        expect(live['mediaProgress'], .02);
        // A system network measurement can coexist with a larger package
        // (metadata/container writes are not network bytes).
        final networkReply = Completer<void>();
        messenger.handlePlatformMessage(
          'breeze.video.hls',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('progress', {
              'id': args['id'],
              'received': 1024,
              'receivedSource': 'network',
              'networkBytes': 1024,
              'networkTotal': 8192,
              'total': 8192,
              'packageBytes': 3072,
              'loadedTimeMs': 2400,
              'totalTimeMs': 120000,
              'saving': false,
            }),
          ),
          (_) => networkReply.complete(),
        );
        await networkReply.future;
      };
      expect(
        await VideoSystemDownload().save(
          choice: (label: _quality, url: _media, format: 'hls'),
          source: _source,
          video: _watch,
          title: 'Measured HLS',
          onProgress: (_) {},
        ),
        VideoDownloadStatus.saved,
      );
      final saved = (await VideoExportRecords.readTasks()).single;
      expect(saved['received'], 4096);
      expect(saved['packageBytes'], 4096);
      expect(saved['networkBytes'], 1024);
      expect(saved['networkTotal'], 8192);
      expect(
        saved['total'],
        4096,
        reason:
            'the final validated package is the first authoritative complete size',
      );
    },
  );

  test(
    'a terminal queue wrapper retains the last measured bytes; a fresh attempt clears them',
    () async {
      final key = await VideoExportRecords.beginTransfer(
        source: _source,
        video: _watch,
        title: 'Partial package',
        quality: _quality,
        format: 'hls',
        queued: true,
      );
      addTearDown(
        () => VideoExportRecords.updateTransfer(
          key,
          received: null,
          status: 'cancelled',
          terminal: true,
        ),
      );
      await VideoExportRecords.updateTransfer(
        key,
        received: 2048,
        receivedSource: 'package',
        packageBytes: 2048,
        networkBytes: 1024,
        networkTotal: 4096,
        status: 'downloading',
        mediaProgress: .02,
      );
      await VideoExportRecords.updateTransfer(
        key,
        received: null,
        status: 'cancelled',
        terminal: true,
      );
      final row = (await VideoExportRecords.readTasks()).single;
      expect(row['received'], 2048);
      expect(row['receivedSource'], 'package');
      expect(row['packageBytes'], 2048);
      expect(row['networkBytes'], 1024);
      expect(row['networkTotal'], 4096);
      expect(row['total'], isNull);
      expect(row['mediaProgress'], .02);
      final restarted = await VideoExportRecords.restartTransfer(row);
      expect(restarted!['received'], isNull);
      expect(restarted['receivedSource'], isNull);
      expect(restarted['packageBytes'], isNull);
      expect(restarted['networkBytes'], isNull);
      expect(restarted['networkTotal'], isNull);
      expect(restarted['mediaProgress'], isNull);
    },
  );

  test(
    'HLS time progress, commit and task clearing preserve real package metadata without media credentials',
    () async {
      final fractions = <double>[];
      native.onStart = (args) async {
        expect(args['managedId'], _id);
        expect(args['video'], _watch.toString());
        final response = Completer<void>();
        messenger.handlePlatformMessage(
          'breeze.video.hls',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('progress', {
              'id': args['id'],
              'loadedTimeMs': 60000,
              'totalTimeMs': 120000,
              'saving': false,
            }),
          ),
          (_) => response.complete(),
        );
        await response.future;
        await VideoExportRecords.flush();
        final live = (await VideoExportRecords.readTasks()).single;
        final item = projectDownloadCenter(
          tasks: [],
          comics: [],
          videos: [live],
        ).single;
        expect(item.priority, 0);
        expect(item.video!['mediaProgress'], 0.5);
        expect(item.receivedBytes, isNull);
        expect(item.totalBytes, isNull);
      };
      final status = await VideoSystemDownload().save(
        choice: (label: _quality, url: _media, format: 'hls'),
        source: _source,
        video: _watch,
        title: 'HLS fixture',
        sourceDuration: '站点 2:03',
        onProgress: (_) {},
        onMediaProgress: fractions.add,
      );
      expect(status, VideoDownloadStatus.saved);
      expect(fractions, [0.5, 1]);
      final row = (await VideoLocalResources.read(fresh: true)).single;
      expect(row['format'], 'hls');
      expect(row['bytes'], 4096);
      expect(row['durationMs'], 120000);
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(VideoExportRecords.taskStorageKey)!;
      expect(raw, isNot(contains('signature')));
      expect(raw, isNot(contains('master.m3u8')));
      final task = (await VideoExportRecords.readTasks()).single;
      expect(task['mediaProgress'], 1);
      expect(task['total'], 4096);
      expect(
        (await VideoExportRecords.bindDownloadRemoval(_id)).hasManagedTransfer,
        isTrue,
      );
      final both = projectDownloadCenter(
        tasks: [],
        comics: [],
        videos: [
          {...task, ...row},
          {
            ...task,
            'key': 'mp4-same-page-quality',
            'format': 'mp4',
            'available': true,
            'filePresent': true,
            'resourceId': VideoLocalResources.identity(
              _source,
              _watch,
              _quality,
            ),
          },
        ],
      );
      expect(both, hasLength(2));
      await VideoExportRecords.clearTaskRecords({task['key'] as String});
      expect(await VideoExportRecords.readTasks(), isEmpty);
      expect(
        (await VideoLocalResources.read(fresh: true)).single['available'],
        isTrue,
      );
      expect(await (await VideoLocalResources.file(_id)).exists(), isFalse);
    },
  );

  test(
    'cancelling an existing-file check cannot publish saved or start a replacement',
    () async {
      native.rows.add(_row());
      final entered = Completer<void>(), release = Completer<void>();
      native.onList = () async {
        if (!entered.isCompleted) entered.complete();
        await release.future;
      };
      final transfer = VideoSystemDownload();
      final result = transfer.save(
        choice: (label: _quality, url: _media, format: 'hls'),
        source: _source,
        video: _watch,
        title: 'HLS fixture',
        onProgress: (_) {},
      );
      await entered.future;
      await transfer.cancel();
      release.complete();
      expect(await result, VideoDownloadStatus.cancelled);
      expect(native.calls, isNot(contains('start')));
      expect(await VideoExportRecords.readTaskSnapshot(), isEmpty);
      expect(native.rows.single['generation'], 'generation-1');
    },
  );

  test(
    'ordinary save reuses only an available exact HLS resource without a new task or native transfer',
    () async {
      native.rows.add(_row());
      final transfer = VideoSystemDownload();
      expect(
        await transfer.save(
          choice: (label: _quality, url: _media, format: 'hls'),
          source: _source,
          video: _watch,
          title: 'HLS fixture',
          onProgress: (_) {},
        ),
        VideoDownloadStatus.saved,
      );
      expect(native.calls, isNot(contains('start')));
      expect(native.calls, isNot(contains('commit')));
      expect(await VideoExportRecords.readTaskSnapshot(), isEmpty);
      expect(transfer.lastTaskKey, 'seed-task');
      expect(native.rows.single['generation'], 'generation-1');
    },
  );

  test(
    'failed replacement never becomes saved and discards only the new candidate',
    () async {
      native.rows.add(_row());
      native.failCommit = true;
      expect(
        await VideoSystemDownload().save(
          replaceExisting: true,
          choice: (label: _quality, url: _media, format: 'hls'),
          source: _source,
          video: _watch,
          title: 'HLS fixture',
          onProgress: (_) {},
        ),
        VideoDownloadStatus.failed,
      );
      expect(native.rows.single['generation'], 'generation-1');
      expect(native.calls, contains('discard'));
      expect(native.candidate, isNull);
      final tasks = await VideoExportRecords.readTasks();
      expect(tasks.where((row) => row['status'] == 'failed'), hasLength(1));
      // The old committed package remains a valid independent resource; its
      // recovery task must not disappear merely because replacement failed.
      expect(
        tasks.where((row) => row['status'] == 'saved').single['generation'],
        'generation-1',
      );
    },
  );

  test(
    'source removal blocks late start and discards a candidate from an older installation epoch',
    () async {
      const source = 'fc67190c-b87f-4fc4-9d4c-3d92a170b425';
      final state = LocalPluginInstallationState.instance;
      await state.reload();
      addTearDown(() async {
        state.endRemoval(source);
        await (await SharedPreferences.getInstance()).remove(
          LocalPluginInstallationState.storageKey,
        );
        await state.reload();
      });
      Future<VideoDownloadStatus> save() => VideoSystemDownload().save(
        choice: (label: _quality, url: _media, format: 'hls'),
        source: source,
        video: _watch,
        title: 'Lifecycle fixture',
        onProgress: (_) {},
      );
      native.onList = () async => state.beginRemoval(source);
      expect(await save(), VideoDownloadStatus.cancelled);
      expect(native.calls, isNot(contains('start')));
      native.onList = null;
      state.endRemoval(source);
      native.calls.clear();
      native.onStart = (_) async {
        await state.setDataExclusions(source, {
          PluginDataScope.records,
        }, beforeWrite: (_) async {});
      };
      expect(await save(), VideoDownloadStatus.cancelled);
      expect(native.calls, contains('start'));
      expect(native.calls, isNot(contains('commit')));
      expect(native.calls, contains('discard'));
      expect(native.candidate, isNull);
      expect(native.rows, isEmpty);
      expect(
        (await VideoExportRecords.readTasks()).every(
          (row) => row['status'] != 'saved',
        ),
        isTrue,
      );
    },
  );

  test(
    'cancel routes to the HLS native job and publishes no saved asset',
    () async {
      native.pending = Completer<Object?>();
      final started = Completer<void>();
      native.onStart = (_) async => started.complete();
      final transfer = VideoSystemDownload();
      final result = transfer.save(
        choice: (label: _quality, url: _media, format: 'hls'),
        source: _source,
        video: _watch,
        title: 'cancelled',
        onProgress: (_) {},
      );
      await started.future;
      await transfer.cancel();
      expect(await result, VideoDownloadStatus.cancelled);
      expect(native.rows, isEmpty);
      expect(native.calls, isNot(contains('commit')));
    },
  );

  test(
    'generation-bound removal rejects newer assets and active readers',
    () async {
      native.rows.add(_row());
      final version = await VideoLocalResources.bindRemovalVersion(_id);
      native.rows.single['generation'] = 'generation-2';
      await expectLater(
        VideoLocalResources.withRemovalLease(_id, (lease) async {
          lease.requireExpectedVersion(version);
          await lease.remove();
        }),
        throwsStateError,
      );
      expect(native.calls, isNot(contains('delete')));
      final reader = VideoLocalResources.acquireHlsReadLease(_id);
      await expectLater(
        VideoLocalResources.remove(_id),
        throwsA(isA<ManagedVideoResourceBusy>()),
      );
      reader.release();
      await VideoLocalResources.remove(_id);
      expect(native.rows, isEmpty);
    },
  );

  test(
    'source removal hides then restores on rollback and deletes only on commit',
    () async {
      native.rows.add(_row());
      final rollback = await PluginVideoRemovalPlan.prepare(_source);
      expect(rollback.resourceCount, 1);
      await rollback.stage(beforeFileMoves: (_) async {});
      expect(await VideoHlsAssets.read(), isEmpty);
      expect(await rollback.finish(committed: false), isTrue);
      expect((await VideoHlsAssets.read()).single['resourceId'], _id);
      final commit = await PluginVideoRemovalPlan.prepare(_source);
      await commit.stage(beforeFileMoves: (_) async {});
      expect(await commit.finish(committed: true), isTrue);
      expect(native.rows, isEmpty);
    },
  );

  test(
    'include-downloads backup refuses system HLS before creating an archive',
    () async {
      native.rows.add(_row());
      final target = File(
        '${(await VideoLocalResources.root()).parent.path}/hls-must-not-export.zip',
      );
      await expectLater(
        exportBreezeBackup(zipPath: target.path, includeDownloads: true),
        throwsA(isA<HlsPortableBackupUnsupported>()),
      );
      expect(await target.exists(), isFalse);
      expect(native.rows.single['available'], isTrue);
    },
  );
}
