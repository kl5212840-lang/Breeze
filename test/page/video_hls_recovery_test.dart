import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_hls_assets.dart';
import 'package:zephyr/page/video/video_hls_recovery.dart';

const _key = 'transfer|123|1', _source = 'fixture', _quality = '720p';
const _url = 'https://example.com/voddetail/42.html?line=one&episode=two';
final _resource = VideoHlsAssets.identity(_source, Uri.parse(_url), _quality);
final _scope = 'a' * 64;

Map<String, Object> _task({int attempt = 1}) => {
  'key': _key,
  'source': _source,
  'url': _url,
  'title': 'Video',
  'kind': 'transfer',
  'format': 'hls',
  'quality': _quality,
  'attempt': attempt,
  'at': 123,
  'resourceId': _resource,
  'status': 'downloading',
};

Map<String, Object> _receipt(String status) => {
  ..._task(),
  'taskKey': _key,
  'status': status,
  'wifiOnly': true,
  'recoveryScope': _scope,
  'assetId': 'asset',
  'generation': 'generation',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late VideoHlsRecovery recovery;
  late List<String> calls;
  late List<Map<String, Object>> native;
  late String scope;
  late bool wifi, failAck, liveOwner;
  late int capacityChanges;

  void seed({int attempt = 1}) => SharedPreferences.setMockInitialValues({
    VideoExportRecords.taskStorageKey: jsonEncode([_task(attempt: attempt)]),
  });

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    seed();
    calls = [];
    native = [];
    scope = _scope;
    wifi = true;
    failAck = false;
    liveOwner = false;
    capacityChanges = 0;
    recovery = VideoHlsRecovery(
      accountScope: (_) => scope,
      canUseDirectRoute: (_) async => true,
      wifiOnly: () => wifi,
      onCapacityChanged: () => capacityChanges++,
    );
    messenger.setMockMethodCallHandler(VideoHlsAssets.channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'recoverySnapshot':
          return liveOwner ? [] : native;
        case 'releaseRecovery':
          expect(call.arguments, VideoHlsAssets.binding(_receipt('staged')));
          liveOwner = false;
          return true;
        case 'cancelRecovery':
          expect(call.arguments, VideoHlsAssets.binding(_receipt('running')));
          native = [_receipt('cancelled')];
          return true;
        case 'commit':
          return {
            ..._receipt('staged'),
            'bytes': 4096,
            'available': true,
            'showTask': true,
            'filePresent': true,
          };
        case 'discard':
          return true;
        case 'ackRecovery':
          if (failAck) throw PlatformException(code: 'fixture');
          native = [];
          return true;
      }
      throw MissingPluginException();
    });
  });

  tearDown(() {
    VideoExportRecords.setRecoveredHlsTasks({});
    messenger.setMockMethodCallHandler(VideoHlsAssets.channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'a completed package is published once even when acknowledgment fails',
    () async {
      native = [_receipt('staged')];
      failAck = true;
      await recovery.refresh();
      final saved = (await VideoExportRecords.readTaskSnapshot()).single;
      expect(saved['status'], 'saved');
      expect(saved['hlsGeneration'], 'generation');
      expect(saved['received'], 4096);
      expect(native, hasLength(1));
      failAck = false;
      await recovery.refresh();
      expect(calls.where((call) => call == 'commit'), hasLength(1));
      expect(calls.where((call) => call == 'ackRecovery'), hasLength(2));
      expect((await VideoExportRecords.readTaskSnapshot()).single, saved);
    },
  );

  test(
    'failed acknowledgment can replay after the live owner releases',
    () async {
      native = [_receipt('staged')];
      liveOwner = true;
      failAck = true;
      await VideoHlsRecovery.acknowledge(native.single);
      await recovery.refresh();
      expect(calls, ['ackRecovery', 'recoverySnapshot']);

      await VideoHlsRecovery.releaseLiveReceipt(native.single);
      failAck = false;
      await recovery.refresh();
      expect(calls, [
        'ackRecovery',
        'recoverySnapshot',
        'releaseRecovery',
        'recoverySnapshot',
        'commit',
        'ackRecovery',
      ]);
      expect(
        (await VideoExportRecords.readTaskSnapshot()).single['status'],
        'saved',
      );
    },
  );

  test(
    'new attempts and changed accounts cannot publish old packages',
    () async {
      seed(attempt: 2);
      native = [_receipt('staged')];
      await recovery.refresh();
      expect(calls, contains('discard'));
      expect(calls, isNot(contains('commit')));
      expect(
        (await VideoExportRecords.readTaskSnapshot()).single['attempt'],
        2,
      );

      seed();
      calls.clear();
      scope = 'b' * 64;
      native = [_receipt('staged')];
      await recovery.refresh();
      expect(calls, contains('discard'));
      expect(calls, isNot(contains('commit')));
    },
  );

  test('a stale receipt leaves the already published package intact', () async {
    seed(attempt: 2);
    native = [
      {..._receipt('staged'), 'available': true},
    ];
    await recovery.refresh();
    expect(calls, ['recoverySnapshot', 'ackRecovery']);
    expect((await VideoExportRecords.readTaskSnapshot()).single['attempt'], 2);
  });

  test(
    'running work retains its exact cancellation owner and capacity',
    () async {
      native = [_receipt('running')];
      await recovery.refresh();
      expect(VideoExportRecords.isAttemptCurrent(_key, 1), isTrue);
      expect(VideoExportRecords.recoveredHlsCount, 1);
      expect(
        (await VideoExportRecords.readTaskSnapshot()).single['status'],
        'downloading',
      );
      await recovery.cancel(_key, 2);
      expect(calls, isNot(contains('cancelRecovery')));
      await recovery.cancel(_key, 1);
      expect(
        (await VideoExportRecords.readTaskSnapshot()).single['status'],
        'cancelled',
      );
      expect(VideoExportRecords.recoveredHlsCount, 0);
      expect(capacityChanges, 2);
    },
  );

  test('an incompatible Wi-Fi policy fences the running attempt', () async {
    native = [_receipt('running')];
    wifi = false;
    await recovery.refresh();
    expect(calls, contains('cancelRecovery'));
    expect(VideoExportRecords.recoveredHlsCount, 0);
    await recovery.refresh();
    expect(
      (await VideoExportRecords.readTaskSnapshot()).single['status'],
      'cancelled',
    );
  });

  test('a recovered task notifies work pages without a session row', () async {
    var notifications = 0;
    void onChange() => notifications++;
    final changes = VideoExportRecords.recoveredHlsChanges;
    changes.addListener(onChange);
    addTearDown(() => changes.removeListener(onChange));

    native = [_receipt('running')];
    await recovery.refresh();
    expect(notifications, 1);
    await recovery.refresh();
    expect(notifications, 1);
    expect(VideoExportRecords.sessionTaskSnapshot(), isEmpty);

    native = [_receipt('failed')];
    await recovery.refresh();
    expect(notifications, 3);
    expect(VideoExportRecords.sessionTaskSnapshot(), isEmpty);
    expect(
      (await VideoExportRecords.readTaskSnapshot()).single['status'],
      'failed',
    );
  });
}
