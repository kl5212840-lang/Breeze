import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
// ignore: depend_on_referenced_packages
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/service/image_recovery.dart';

class _ConnectivityFixture extends ConnectivityPlatform {
  final initial = Completer<List<ConnectivityResult>>();
  final changes = StreamController<List<ConnectivityResult>>(sync: true);
  Future<List<ConnectivityResult>>? current;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() =>
      current ?? initial.future;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => changes.stream;
}

void main() {
  testWidgets('image reconnect preserves the server Retry-After', (
    tester,
  ) async {
    final hub = ImageRecoveryHub(listenToPlatform: false);
    addTearDown(hub.dispose);
    var attempts = 0;
    final image = ImageRecoveryController(
      hub: hub,
      retry: () async => attempts++,
    );
    addTearDown(image.dispose);
    image.failed(const HttpException('HTTP 429 Retry-After: 120'));
    await tester.pump(const Duration(seconds: 3));
    hub.updateConnectivity([ConnectivityResult.none]);
    hub.updateConnectivity([ConnectivityResult.wifi]);
    await tester.pump(const Duration(seconds: 3));
    expect(attempts, 0);

    image.reset();
    image.failed(const HttpException('HTTP 429 Retry-After: 0'));
    await tester.pump(const Duration(milliseconds: 800));
    expect(attempts, 1);
    image.succeeded();
  });

  testWidgets('foreground rechecks transport after a missed reconnect', (
    tester,
  ) async {
    final previous = ConnectivityPlatform.instance;
    final platform = _ConnectivityFixture();
    ConnectivityPlatform.instance = platform;
    final hub = ImageRecoveryHub();
    final reasons = <String>[];
    final listener = hub.recovered.listen(
      (_) => reasons.add(hub.recoveryReason),
    );
    addTearDown(() async {
      await listener.cancel();
      await hub.dispose();
      await platform.changes.close();
      ConnectivityPlatform.instance = previous;
    });
    platform.initial.complete([ConnectivityResult.none]);
    await tester.pump();
    expect(hub.online, isFalse);
    hub.didChangeAppLifecycleState(AppLifecycleState.paused);
    platform.current = Future.value([ConnectivityResult.wifi]);
    hub.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(hub.online, isTrue);
    expect(reasons.where((reason) => reason == 'reconnect'), hasLength(1));

    // A newly delivered event supersedes an in-flight foreground sample.
    hub.didChangeAppLifecycleState(AppLifecycleState.paused);
    final stale = Completer<List<ConnectivityResult>>();
    platform.current = stale.future;
    hub.didChangeAppLifecycleState(AppLifecycleState.resumed);
    platform.changes.add([ConnectivityResult.none]);
    stale.complete([ConnectivityResult.wifi]);
    await tester.pump();
    expect(hub.online, isFalse);
  });

  testWidgets('initial offline sample cannot overwrite a newer network event', (
    tester,
  ) async {
    final previous = ConnectivityPlatform.instance;
    final platform = _ConnectivityFixture();
    ConnectivityPlatform.instance = platform;
    final hub = ImageRecoveryHub();
    addTearDown(() async {
      await hub.dispose();
      await platform.changes.close();
      ConnectivityPlatform.instance = previous;
    });
    platform.changes.add([ConnectivityResult.wifi]);
    platform.initial.complete([ConnectivityResult.none]);
    await tester.pump();
    expect(hub.online, isTrue);

    var attempts = 0;
    final image = ImageRecoveryController(
      hub: hub,
      retry: () async => attempts++,
    );
    addTearDown(image.dispose);
    image.failed(const SocketException('previous connection failed'));
    await tester.pump(const Duration(milliseconds: 800));
    expect(attempts, 1);
    image.succeeded();
  });

  test('terminal image errors do not spend automatic retries', () {
    for (final error in [
      const FormatException('HTML instead of image'),
      const HttpException('HTTP 404'),
      const HttpException('HTTP 422'),
      const HttpException('HTTP 401'),
      const HttpException('HTTP 403'),
      const ImageRecoverySuperseded(),
    ]) {
      expect(imageFailureIsTransient(error), false);
    }
    for (final error in [
      const SocketException('offline'),
      TimeoutException('transport'),
      const HttpException('HTTP 408'),
      const HttpException('HTTP 429'),
      const HttpException('HTTP 503'),
    ]) {
      expect(imageFailureIsTransient(error), true);
    }
  });
  test('slow covers leave capacity for a reader image', () async {
    final queue = ImageRequestQueue(concurrency: 2, maxCoverRequests: 1);
    final first = Completer<void>();
    var nextCoverStarted = false;
    final activeCover = queue.run<void>(
      'cover-1',
      () => first.future,
      cover: true,
    );
    final waitingCover = queue.run<void>('cover-2', () async {
      nextCoverStarted = true;
    }, cover: true);
    try {
      final page = await queue
          .run<int>('chapter-page', () async => 1)
          .timeout(const Duration(seconds: 1));
      expect(page, 1);
      expect(nextCoverStarted, isFalse);
    } finally {
      first.complete();
      await Future.wait([activeCover, waitingCover]);
    }
    expect(nextCoverStarted, isTrue);
  });

  test('timeout URLs are independent of the image HTTP status', () {
    const url = 'https://source.invalid/art/404/page.webp';
    expect(imageFailureIsTransient(TimeoutException('Timed out $url')), isTrue);
    expect(imageFailureIsTransient(Exception('请求超时 $url')), isTrue);
    expect(imageFailureIsTransient(Exception('HTTP 404 $url')), isFalse);
    expect(imageFailureIsTransient(Exception('HTTP 429 $url')), isTrue);
  });

  testWidgets('only an image from the same CDN renews its retry budget', (
    tester,
  ) async {
    final hub = ImageRecoveryHub(listenToPlatform: false);
    var matching = 0, unrelated = 0, detail = 0;
    ImageRecoveryController watch(String? host, VoidCallback attempt) {
      final controller = ImageRecoveryController(
        hub: hub,
        imageHost: host == null ? null : () => host,
        maxAutomaticAttempts: 1,
        retry: () async {
          attempt();
          throw const SocketException('request timeout');
        },
      );
      controller.failed(const SocketException('request timeout'));
      return controller;
    }

    final controllers = [
      watch('images-a.example', () => matching++),
      watch('images-b.example', () => unrelated++),
      watch(null, () => detail++),
    ];
    try {
      await tester.pump(const Duration(milliseconds: 800));
      expect((matching, unrelated, detail), (1, 1, 1));
      hub.noteSuccessfulRequest(imageHost: 'images-a.example');
      await tester.pump(const Duration(milliseconds: 800));
      expect((matching, unrelated, detail), (2, 1, 1));
    } finally {
      for (final controller in controllers) {
        controller.dispose();
      }
      await hub.dispose();
    }
  });
  test(
    'shared pending prefetch is promoted without duplicating its request',
    () async {
      final queue = ImageRequestQueue(concurrency: 1);
      final hold = Completer<void>();
      final first = queue.run<void>('running', () => hold.future);
      final order = <String>[];
      var calls = 0;
      final prefetch = queue.run<int>(
        'same-image',
        () async {
          calls++;
          order.add('visible');
          return 7;
        },
        priority: -1,
        current: () => false,
      );
      final other = queue.run<int>('other-image', () async {
        order.add('other');
        return 8;
      });
      final visible = queue.run<int>(
        'same-image',
        () async {
          throw StateError('must join');
        },
        priority: 1,
        current: () => true,
      );
      hold.complete();
      await first;
      expect(await visible, 7);
      expect(await prefetch, 7);
      expect(await other, 8);
      expect(calls, 1);
      expect(order, ['visible', 'other']);
    },
  );
  testWidgets(
    'two bounded retries, offline suspension, recovery and terminal success',
    (tester) async {
      final hub = ImageRecoveryHub(listenToPlatform: false);
      var calls = 0;
      late ImageRecoveryController controller;
      controller = ImageRecoveryController(
        hub: hub,
        retry: () async {
          calls++;
          controller.failed(const SocketException('offline'));
        },
      );
      controller.failed(const SocketException('offline'));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2400));
      await tester.pump();
      expect(calls, 2);
      expect(controller.recovering, false);
      await tester.pump(const Duration(minutes: 1));
      expect(calls, 2);
      hub.updateConnectivity([ConnectivityResult.none]);
      hub.updateConnectivity([ConnectivityResult.wifi]);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      expect(calls, 3);
      controller.succeeded();
      hub.didChangeAppLifecycleState(AppLifecycleState.paused);
      hub.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 5));
      expect(calls, 3);
      controller.dispose();
      await hub.dispose();
    },
  );
  testWidgets(
    'visible reader recovery continues slowly and pauses when hidden',
    (tester) async {
      final hub = ImageRecoveryHub(listenToPlatform: false);
      var calls = 0;
      final controller = ImageRecoveryController(
        hub: hub,
        retryIntervalAfterAttempts: const Duration(seconds: 30),
        retry: () async {
          calls++;
          throw const SocketException('temporary');
        },
      );
      controller.failed(const SocketException('temporary'));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 2400));
      expect(calls, 2);
      await tester.pump(const Duration(seconds: 29));
      expect(calls, 2);
      await tester.pump(const Duration(seconds: 1));
      expect(calls, 3);

      controller.setActive(false);
      expect(controller.hasPendingRecovery, true);
      expect(controller.recovering, false);
      await tester.pump(const Duration(minutes: 1));
      expect(calls, 3);
      controller.setActive(true);
      await tester.pump(const Duration(seconds: 30));
      expect(calls, 4);

      controller.failed(const FormatException('Invalid image data'));
      expect(controller.hasPendingRecovery, false);
      await tester.pump(const Duration(minutes: 1));
      expect(calls, 4);
      controller.dispose();
      await hub.dispose();
    },
  );
  testWidgets(
    'a real reconnect reopens exhausted retries after a recent recovery',
    (tester) async {
      final hub = ImageRecoveryHub(listenToPlatform: false);
      var calls = 0;
      final controller = ImageRecoveryController(
        hub: hub,
        maxAutomaticAttempts: 1,
        retry: () async {
          calls++;
          throw const SocketException('temporary');
        },
      );
      hub.updateConnectivity([ConnectivityResult.none]);
      controller.failed(const SocketException('temporary'));
      hub.updateConnectivity([ConnectivityResult.wifi]);
      await tester.pump(const Duration(milliseconds: 800));
      expect(calls, 1);
      expect(controller.recovering, false);

      hub.updateConnectivity([ConnectivityResult.none]);
      hub.updateConnectivity([ConnectivityResult.wifi]);
      await tester.pump(const Duration(milliseconds: 800));
      expect(calls, 2);
      expect(controller.recovering, false);
      controller.dispose();
      await hub.dispose();
    },
  );
  testWidgets(
    'hidden images keep a reconnect budget until they become visible',
    (tester) async {
      final hub = ImageRecoveryHub(listenToPlatform: false);
      var calls = 0;
      final controller = ImageRecoveryController(
        hub: hub,
        maxAutomaticAttempts: 1,
        retry: () async {
          calls++;
          throw const SocketException('temporary');
        },
      );
      controller.failed(const SocketException('temporary'));
      await tester.pump(const Duration(milliseconds: 800));
      expect(calls, 1);
      expect(controller.recovering, false);

      controller.setActive(false);
      hub.updateConnectivity([ConnectivityResult.none]);
      hub.updateConnectivity([ConnectivityResult.wifi]);
      await tester.pump(const Duration(seconds: 5));
      expect(calls, 1);

      controller.setActive(true);
      await tester.pump(const Duration(milliseconds: 800));
      expect(calls, 2);
      controller.dispose();
      await hub.dispose();
    },
  );
  testWidgets(
    'hidden or background failures spend no retry until visible and foreground',
    (tester) async {
      final hub = ImageRecoveryHub(listenToPlatform: false);
      var calls = 0;
      final controller = ImageRecoveryController(
        active: false,
        hub: hub,
        retry: () async {
          calls++;
        },
      );
      controller.failed(const SocketException('temporary'));
      await tester.pump(const Duration(seconds: 5));
      expect(calls, 0);
      hub.didChangeAppLifecycleState(AppLifecycleState.paused);
      controller.setActive(true);
      await tester.pump(const Duration(seconds: 5));
      expect(calls, 0);
      hub.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      expect(calls, 1);
      controller.dispose();
      await tester.pump(const Duration(seconds: 5));
      expect(calls, 1);
      await hub.dispose();
    },
  );

  testWidgets(
    'a reset discards recovery queued for the previous image identity',
    (tester) async {
      final hub = ImageRecoveryHub(listenToPlatform: false);
      final hold = Completer<void>();
      final blockers = [
        hub.retries.run<void>('block-one', () => hold.future),
        hub.retries.run<void>('block-two', () => hold.future),
      ];
      var calls = 0;
      final controller = ImageRecoveryController(
        hub: hub,
        retry: () async {
          calls++;
        },
      );
      controller.failed(const SocketException('previous image'));
      await tester.pump(const Duration(milliseconds: 800));
      controller.reset();
      controller.failed(const SocketException('current image'));
      hold.complete();
      await Future.wait(blockers);
      await tester.pump();
      expect(calls, 0);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      expect(calls, 1);
      controller.dispose();
      await hub.dispose();
    },
  );

  testWidgets(
    'hidden queued recovery keeps its budget for actual visible work',
    (tester) async {
      final hub = ImageRecoveryHub(listenToPlatform: false);
      final hold = Completer<void>();
      final blockers = [
        hub.retries.run<void>('block-one', () => hold.future),
        hub.retries.run<void>('block-two', () => hold.future),
      ];
      var calls = 0;
      final controller = ImageRecoveryController(
        hub: hub,
        maxAutomaticAttempts: 1,
        retry: () async {
          calls++;
        },
      );
      controller.failed(const SocketException('temporary'));
      await tester.pump(const Duration(milliseconds: 800));
      controller.setActive(false);
      hold.complete();
      await Future.wait(blockers);
      await tester.pump();
      expect(calls, 0);
      controller.setActive(true);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      expect(calls, 1);
      controller.dispose();
      await hub.dispose();
    },
  );
}
