import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/service/download/download_admission.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('queue pause survives a new device admission instance', () async {
    SharedPreferences.setMockInitialValues({});
    final before = DownloadAdmission();
    final after = DownloadAdmission();
    final resumed = DownloadAdmission();
    addTearDown(before.dispose);
    addTearDown(after.dispose);
    addTearDown(resumed.dispose);
    await before.setQueuePaused(true);
    await after.initializeQueueState();
    expect(after.queuePaused, isTrue);
    await after.setQueuePaused(false);
    await resumed.initializeQueueState();
    expect(resumed.queuePaused, isFalse);
  });

  test('a live network event wins over a late initial read', () async {
    final initial = Completer<List<ConnectivityResult>>();
    final events = StreamController<List<ConnectivityResult>>();
    final cancelled = Completer<void>();
    final admission = DownloadAdmission(
      readNetwork: () => initial.future,
      networkEvents: events.stream,
    )..setWifiOnly(true);
    addTearDown(() async {
      admission.dispose();
      await events.close();
    });

    final started = admission.start();
    events.add([ConnectivityResult.mobile]);
    await Future<void>.delayed(Duration.zero);
    initial.complete([ConnectivityResult.wifi]);
    await started;
    expect(admission.networkWait, DownloadNetworkWait.wifi);
    final waiting = admission.waitForNetwork(cancelled.future);
    cancelled.complete();
    expect(await waiting, isFalse);
    events.add([ConnectivityResult.wifi]);
    await Future<void>.delayed(Duration.zero);
    expect(admission.networkWait, isNull);
  });

  test(
    'Android waits for an unambiguous Wi-Fi route in Wi-Fi-only mode',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final events = StreamController<List<ConnectivityResult>>();
      final admission = DownloadAdmission(
        readNetwork: () async => [
          ConnectivityResult.wifi,
          ConnectivityResult.vpn,
        ],
        networkEvents: events.stream,
      )..setWifiOnly(true);
      addTearDown(() async {
        admission.dispose();
        await events.close();
      });

      await admission.start();
      expect(admission.networkWait, DownloadNetworkWait.wifi);
      events.add([ConnectivityResult.wifi, ConnectivityResult.mobile]);
      await Future<void>.delayed(Duration.zero);
      expect(admission.networkWait, DownloadNetworkWait.wifi);
      events.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);
      expect(admission.networkWait, isNull);
    },
  );

  test('unknown storage does not act like a full volume', () async {
    int? free;
    final admission = DownloadAdmission(readFreeBytes: () async => free);
    addTearDown(admission.dispose);
    expect(await admission.hasSpace(), isTrue);
    free = 0;
    expect(await admission.hasSpace(), isFalse);
    free = DownloadAdmission.minimumFreeBytes;
    expect(await admission.hasSpace(), isTrue);
  });
}
