import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/source_network_policy.dart';
import 'package:zephyr/service/image_recovery.dart';
import 'package:zephyr/service/read_recovery.dart';
import 'package:zephyr/widgets/read_recovery_scope.dart';

void main() {
  testWidgets('changing one source route only reopens its failed read', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const first = '00000000-0000-4000-8000-000000000001';
    const second = '00000000-0000-4000-8000-000000000002';
    final hub = ImageRecoveryHub(listenToPlatform: false);
    addTearDown(hub.dispose);
    final calls = <String>[];
    for (final source in [first, second]) {
      late final ReadRecoveryController recovery;
      recovery = ReadRecoveryController(
        source: source,
        active: true,
        hub: hub,
        retry: () async {
          calls.add(source);
          recovery.succeeded();
        },
      );
      addTearDown(recovery.dispose);
      recovery.failed(const FormatException('unavailable on old route'));
    }
    await SourceNetworkPolicies.save(
      first,
      const SourceNetworkPreference(mode: SourceNetworkMode.system),
    );
    await tester.pump(Duration.zero);
    expect(calls, [first]);
  });

  test(
    'Retry-After supports seconds and HTTP dates without shortening deadlines',
    () {
      final now = DateTime.utc(2026, 11, 9, 10);
      expect(
        readRetryAfterDelay(Exception('HTTP 429 Retry-After: 120'), now: now),
        const Duration(seconds: 120),
      );
      expect(
        readRetryAfterDelay(
          Exception('HTTP 429 Retry-After: Mon, 09 Nov 2026 10:02:00 GMT'),
          now: now,
        ),
        const Duration(minutes: 2),
      );
      expect(
        readRetryAfterDelay(
          Exception('HTTP 429 Retry-After: Mon, 09 Nov 2026 09:59:00 GMT'),
          now: now,
        ),
        Duration.zero,
      );
      expect(
        readRetryAfterDelay(
          Exception('HTTP 429 Retry-After: invalid'),
          now: now,
        ),
        const Duration(seconds: 45),
      );
    },
  );

  test('only transient reads are eligible', () {
    for (final error in [
      StateError('connection reset'),
      const SocketLikeTimeout(),
      Exception('HTTP 503'),
      Exception('status:429 retry-after:60'),
    ]) {
      expect(readFailureIsTransient(error), isTrue, reason: '$error');
    }
    for (final error in [
      StateError('请先登录'),
      Exception('HTTP 403'),
      Exception('captcha required'),
      const FormatException('invalid response'),
      StateError('missing list configuration'),
    ]) {
      expect(readFailureIsTransient(error), isFalse, reason: '$error');
    }
  });

  testWidgets('a second page cannot shorten a source rate limit', (
    tester,
  ) async {
    final hub = ImageRecoveryHub(listenToPlatform: false);
    final first = ReadRecoveryController(
      source: 'shared-retry-after-test',
      hub: hub,
      retry: () async {},
    );
    var requests = 0;
    final second = ReadRecoveryController(
      source: 'shared-retry-after-test',
      hub: hub,
      active: true,
      retry: () async => requests++,
    );
    addTearDown(() {
      first.dispose();
      second.dispose();
      hub.dispose();
    });

    try {
      first.failed(Exception('HTTP 429 Retry-After: 120'));
      second.failed(Exception('HTTP 429 Retry-After: 0'));
      second.trigger();
      await tester.pump(Duration.zero);
      expect(requests, 0);
    } finally {
      first.dispose();
      second.dispose();
    }
  });

  testWidgets('failed visible reads back off, pause, and stop after success', (
    tester,
  ) async {
    final hub = ImageRecoveryHub(listenToPlatform: false);
    addTearDown(hub.dispose);
    var reads = 0;
    late ReadRecoveryController controller;
    controller = ReadRecoveryController(
      source: 'backoff-test',
      hub: hub,
      active: true,
      shortDelays: const [
        Duration(milliseconds: 10),
        Duration(milliseconds: 20),
      ],
      slowDelay: const Duration(seconds: 40),
      retry: () async {
        reads++;
        controller.failed(StateError('connection reset'));
      },
    );
    addTearDown(controller.dispose);
    controller.failed(StateError('connection reset'));
    await tester.pump(const Duration(milliseconds: 10));
    expect(reads, 1);
    await tester.pump(const Duration(milliseconds: 20));
    expect(reads, 2);
    await tester.pump(const Duration(seconds: 30));
    expect(reads, 2);
    controller.setActive(false);
    await tester.pump(const Duration(minutes: 2));
    expect(reads, 2);
    controller.setActive(true);
    await tester.pump(Duration.zero);
    expect(reads, 3);
    controller.succeeded();
    await tester.pump(const Duration(minutes: 2));
    expect(reads, 3);
    controller.dispose();
  });

  testWidgets(
    'a sustained outage uses one finite burst until the path changes',
    (tester) async {
      final hub = ImageRecoveryHub(listenToPlatform: false);
      addTearDown(hub.dispose);
      var reads = 0;
      final recovery = ReadRecoveryController(
        source: 'bounded-page-outage',
        hub: hub,
        active: true,
        shortDelays: const [Duration(milliseconds: 10)],
        slowDelay: const Duration(seconds: 1),
        retry: () async => reads++,
      );
      addTearDown(recovery.dispose);
      recovery.failed(const SocketLikeTimeout());
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump(const Duration(seconds: 7));
      expect(reads, 2);
      await tester.pump(const Duration(minutes: 10));
      expect(
        reads,
        2,
        reason: 'a failed foreground page must not poll forever',
      );
      recovery.setActive(false);
      recovery.setActive(true);
      await tester.pump();
      expect(
        reads,
        2,
        reason: 'switching tabs does not reopen an outage burst',
      );
      hub.updateConnectivity([ConnectivityResult.none]);
      hub.updateConnectivity([ConnectivityResult.wifi]);
      await tester.pump(Duration.zero);
      await tester.pump(Duration.zero);
      expect(
        reads,
        3,
        reason: 'a real reconnect can reopen automatic recovery',
      );
      recovery.succeeded();
      await tester.pump(const Duration(minutes: 10));
      expect(reads, 3);
    },
  );

  testWidgets(
    'image success is ignored; connectivity and foreground reopen demand',
    (tester) async {
      final hub = ImageRecoveryHub(listenToPlatform: false);
      addTearDown(hub.dispose);
      var reads = 0;
      final controller = ReadRecoveryController(
        source: 'signals-test',
        hub: hub,
        active: true,
        shortDelays: const [Duration(seconds: 20)],
        retry: () async {
          reads++;
        },
      );
      addTearDown(controller.dispose);
      controller.failed(StateError('network error'));
      hub.noteSuccessfulRequest(imageHost: 'images.example');
      await tester.pump(Duration.zero);
      expect(reads, 0);
      hub.updateConnectivity([ConnectivityResult.none]);
      await tester.pump(const Duration(seconds: 30));
      expect(reads, 0);
      hub.updateConnectivity([ConnectivityResult.wifi]);
      await tester.pump(Duration.zero);
      expect(reads, 1);
      hub.didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pump(const Duration(minutes: 1));
      expect(reads, 1);
      hub.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump(Duration.zero);
      expect(reads, 2);
      controller.dispose();
    },
  );

  testWidgets('signals in flight coalesce and admission serializes a source', (
    tester,
  ) async {
    final hub = ImageRecoveryHub(listenToPlatform: false);
    addTearDown(hub.dispose);
    final gate = Completer<void>();
    var firstReads = 0, secondReads = 0;
    final first = ReadRecoveryController(
      source: 'same-origin',
      hub: hub,
      active: true,
      retry: () async {
        firstReads++;
        if (firstReads == 1) await gate.future;
      },
    );
    final second = ReadRecoveryController(
      source: 'same-origin',
      hub: hub,
      active: true,
      retry: () async {
        secondReads++;
      },
    );
    addTearDown(() {
      first.dispose();
      second.dispose();
    });
    first.failed(StateError('connection reset'));
    second.failed(StateError('connection reset'));
    first.trigger();
    second.trigger();
    await tester.pump(Duration.zero);
    expect(firstReads, 1);
    expect(secondReads, 0);
    first.trigger();
    first.trigger();
    first.trigger();
    gate.complete();
    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);
    expect(firstReads, 2);
    expect(secondReads, 1);
    first.succeeded();
    second.succeeded();
    first.dispose();
    second.dispose();
  });

  testWidgets(
    'route host suspends reads beneath a pushed page and resumes on return',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final activity = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: ReadRecoveryHost(
            onActiveChanged: activity.add,
            child: const Scaffold(body: Text('source')),
          ),
        ),
      );
      final pushed = navigator.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('details')),
        ),
      );
      await tester.pumpAndSettle();
      expect(activity.last, isFalse);
      navigator.currentState!.pop();
      await pushed;
      await tester.pumpAndSettle();
      expect(activity.last, isTrue);
    },
  );

  testWidgets('host propagates hidden tab demand without recreating content', (
    tester,
  ) async {
    final activity = <bool>[];
    Widget host(bool active) => Directionality(
      textDirection: TextDirection.ltr,
      child: ReadRecoveryScope(
        active: active,
        child: ReadRecoveryHost(
          onActiveChanged: activity.add,
          child: const Text('kept'),
        ),
      ),
    );
    await tester.pumpWidget(host(true));
    await tester.pumpWidget(host(false));
    await tester.pumpWidget(host(true));
    expect(activity, [true, false, true]);
  });
}

class SocketLikeTimeout implements Exception {
  const SocketLikeTimeout();
  @override
  String toString() => 'timeout of 30000ms exceeded';
}
