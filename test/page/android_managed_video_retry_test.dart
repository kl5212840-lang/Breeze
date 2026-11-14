import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/network/source_network_policy.dart';
import 'package:zephyr/page/video/android_managed_video_attempt.dart';
import 'package:zephyr/page/video/video_download.dart';
import 'package:zephyr/page/video/video_download_retry.dart';
import 'package:zephyr/page/video/video_episode_download_queue.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';

import '../download_fixture.dart';
import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = AndroidManagedVideoAttempt.channel;
  const source = 'android-native-video-retry';
  const quality = '720p';
  final watch = Uri.parse('https://fixture.test/videos/7?line=main&episode=7');
  final resourceId = VideoLocalResources.identity(source, watch, quality);
  final connectivity = DownloadConnectivityFixture();

  Future<Map<String, dynamic>> interrupted(String key) async {
    SharedPreferences.setMockInitialValues({
      VideoExportRecords.taskStorageKey: jsonEncode([
        {
          'kind': 'transfer',
          'key': key,
          'source': source,
          'url': watch.toString(),
          'title': 'Public video',
          'quality': quality,
          'at': 1000,
          'status': 'downloading',
          'resourceId': resourceId,
          'attempt': 2,
          'received': 300,
        },
      ]),
    });
    final row = (await VideoExportRecords.readTaskSnapshot()).single;
    expect(row['status'], 'interrupted');
    return row;
  }

  Future<Map<String, Object>> stage() async {
    final stageId = 'a' * 32;
    final stage = await VideoLocalResources.stagedFile(stageId);
    await stage.parent.create(recursive: true);
    await stage.writeAsBytes(
      Uint8List(4096)..setAll(0, [0, 0, 0, 24, 102, 116, 121, 112]),
    );
    return {
      'status': 'staged',
      'stageId': stageId,
      'resourceId': resourceId,
      'bytes': 4096,
    };
  }

  setUp(() async {
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await useIsolatedDownloadFixture();
    VideoLocalResources.invalidate();
    addTearDown(() async {
      await VideoEpisodeDownloadQueue.flush();
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = previous;
    });
  });
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await TestObjectBoxHelper.setUpTestObjectBox();
    await PluginRegistryService.I.init();
  });
  tearDownAll(connectivity.close);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  test(
    'retry claims the matching persisted Android attempt and commits its staged file',
    () async {
      final row = await interrupted('android-engine-recreated');
      final transferKey = AndroidManagedVideoAttempt.keyFor(
        row['key'] as String,
        2,
      );
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        final args = call.arguments as Map;
        expect(args['transferKey'], transferKey);
        expect(args['managedId'], resourceId);
        expect(args['scope'], AndroidManagedVideoAttempt.scopeFor(source));
        expect(args.containsKey('url'), isFalse);
        if (call.method == 'status') return 'settled';
        if (call.method == 'attach') return stage();
        fail('Unexpected Android bridge method ${call.method}');
      });

      expect(
        await VideoDownloadRetry.retry(
          row,
          fallback: (_) async {
            fail('A live Android attempt must not invoke the source resolver');
          },
        ),
        isTrue,
      );
      await VideoEpisodeDownloadQueue.flush();
      final saved = (await VideoExportRecords.readTaskSnapshot()).single;
      expect(saved['status'], 'saved');
      expect(saved['attempt'], 2);
      expect(saved['resourceId'], resourceId);
      expect(await (await VideoLocalResources.file(resourceId)).length(), 4096);
      expect(calls, ['status', 'attach']);
    },
  );

  test(
    'a missing Android owner resolves a fresh address on a new attempt',
    () async {
      final row = await interrupted('android-process-restarted');
      final key = row['key'] as String;
      final fresh = Uri.parse('https://cdn.test/video.mp4?token=fresh');
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        final args = call.arguments as Map;
        if (call.method == 'status') {
          expect(
            args['transferKey'],
            AndroidManagedVideoAttempt.keyFor(key, 2),
          );
          return null;
        }
        if (call.method == 'start') {
          expect(
            args['transferKey'],
            AndroidManagedVideoAttempt.keyFor(key, 3),
          );
          expect(args['url'], fresh.toString());
          return stage();
        }
        fail('Unexpected Android bridge method ${call.method}');
      });

      expect(
        await VideoDownloadRetry.retry(
          row,
          fallback: (_) async => VideoDownloadRetryResolution(
            choices: [(label: quality, url: fresh, format: 'mp4')],
          ),
        ),
        isTrue,
      );
      await VideoEpisodeDownloadQueue.flush();
      final saved = (await VideoExportRecords.readTaskSnapshot()).single;
      expect(saved['status'], 'saved');
      expect(saved['attempt'], 3);
      expect(calls, ['status', 'start']);
      expect(saved.toString(), isNot(contains('token=fresh')));
    },
  );

  test(
    'an existing Android subscriber prevents a competing engine from claiming the attempt',
    () async {
      final row = await interrupted('android-competing-engine');
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'status');
        return 'busy';
      });
      await expectLater(
        VideoDownloadRetry.retry(row),
        throwsA(isA<VideoDownloadRetryFailure>()),
      );
      final unchanged = (await VideoExportRecords.readTaskSnapshot()).single;
      expect(unchanged['status'], 'interrupted');
      expect(unchanged['attempt'], 2);
    },
  );

  test(
    'cancelling a reattached Android writer targets the original attempt',
    () async {
      final row = await interrupted('android-cancel-reattached');
      final key = row['key'] as String;
      final transferKey = AndroidManagedVideoAttempt.keyFor(key, 2);
      final started = Completer<void>();
      final pending = Completer<Object?>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect((call.arguments as Map)['transferKey'], transferKey);
        expect(
          (call.arguments as Map)['scope'],
          AndroidManagedVideoAttempt.scopeFor(source),
        );
        if (call.method == 'status') return 'active';
        if (call.method == 'attach') {
          started.complete();
          return pending.future;
        }
        if (call.method == 'cancel') {
          if (!pending.isCompleted) pending.complete('cancelled');
          return null;
        }
        fail('Unexpected Android bridge method ${call.method}');
      });
      expect(await VideoDownloadRetry.retry(row), isTrue);
      await started.future.timeout(const Duration(seconds: 3));
      await VideoSystemDownload.cancelTask(key);
      await VideoEpisodeDownloadQueue.flush();
      final cancelled = (await VideoExportRecords.readTaskSnapshot()).single;
      expect(cancelled['status'], 'cancelled');
      expect(cancelled['attempt'], 2);
      expect(
        await (await VideoLocalResources.file(resourceId)).exists(),
        isFalse,
      );
    },
  );

  test(
    'account and route changes change the ephemeral attachment scope',
    () async {
      const source = '7579e175-56d8-4430-8efe-1578294e7b75';
      await PluginRegistryService.I.upsert(
        PluginInfo(
          uuid: source,
          version: 'fixture',
          originScript: '',
          insertedAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          isEnabled: true,
          isDeleted: false,
          debug: false,
          lastLoadSuccess: true,
        ),
      );
      replaceActivePluginAccount(source, {'auth.token': 'test-token-a'});
      final first = AndroidManagedVideoAttempt.scopeFor(source);
      expect(first, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(AndroidManagedVideoAttempt.scopeFor(source), first);
      const proxy = 'http://proxy-one.test:8080';
      await SourceNetworkPolicies.save(
        source,
        const SourceNetworkPreference(
          mode: SourceNetworkMode.proxy,
          address: proxy,
        ),
      );
      final managed = VideoLocalResources.identity(source, watch, quality);
      final attempt = (await AndroidManagedVideoAttempt.interrupted({
        'status': 'interrupted',
        'key': 'route-scope',
        'attempt': 1,
        'source': source,
        'url': watch.toString(),
        'quality': quality,
        'resourceId': managed,
      }))!;
      expect(
        attempt.scope,
        AndroidManagedVideoAttempt.scopeFor(source, proxy: proxy),
      );
      expect(attempt.scope, isNot(first));
      expect(attempt.matchesCurrentScope(proxy), isTrue);
      expect(
        attempt.matchesCurrentScope('http://proxy-two.test:8080'),
        isFalse,
      );
      replaceActivePluginAccount(source, {'auth.token': 'test-token-b'});
      final next = AndroidManagedVideoAttempt.scopeFor(source);
      expect(next, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(next, isNot(first));
      expect(attempt.matchesCurrentScope(proxy), isFalse);
    },
  );
}
