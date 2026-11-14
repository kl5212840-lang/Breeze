import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/native_video_page.dart';
import 'package:zephyr/page/video/video_hls_assets.dart';
import 'package:zephyr/page/video/video_local_resources.dart';

import '../download_fixture.dart';

final _watch = Uri.parse(
  'https://fixture.test/voddetail/42.html?line=a&episode=1',
);
final _id = VideoHlsAssets.identity('hls-inline', _watch, '720p');
const _package = 'file:///fixture/Library/video/package.movpkg/';

class _HlsNative {
  final calls = <MethodCall>[];
  Completer<Object?>? acquiring;
  bool failAcquire = false;
  int get releases =>
      calls.where((call) => call.method == 'releasePlayback').length;
  int get acquires =>
      calls.where((call) => call.method == 'acquirePlayback').length;
  Future<Object?> invoke(MethodCall call) async {
    calls.add(call);
    switch (call.method) {
      case 'list':
        return [
          {
            'resourceId': _id,
            'assetId': 'asset-1',
            'generation': 'generation-1',
            'source': 'hls-inline',
            'url': _watch.toString(),
            'title': 'Offline episode',
            'quality': '720p',
            'bytes': 4096,
            'taskKey': 'task-1',
            'showTask': true,
            'at': 1700000000000,
            'format': 'hls',
            'available': true,
            'filePresent': true,
          },
        ];
      case 'acquirePlayback':
        if (failAcquire) throw PlatformException(code: 'unavailable');
        return acquires == 1 && acquiring != null
            ? acquiring!.future
            : capability;
      case 'releasePlayback':
      case 'delete':
        return true;
      default:
        throw MissingPluginException();
    }
  }

  Map<String, dynamic> get capability => {
    'leaseId': 'reader-$acquires',
    'fileURL': _package,
  };
}

class _FilePlatform extends VideoPlayerPlatform {
  final sources = <DataSource>[];
  final events = <int, StreamController<VideoEvent>>{};
  final disposing = <int>[];
  final disposal = Completer<void>();
  bool initialize = true;
  int plays = 0;
  @override
  Future<void> init() async {}
  @override
  Future<void> setMixWithOthers(bool value) async {}
  @override
  Future<int?> create(DataSource source) async {
    sources.add(source);
    final id = sources.length;
    final stream = StreamController<VideoEvent>.broadcast();
    events[id] = stream;
    Timer.run(() {
      if (initialize && !stream.isClosed) {
        stream.add(
          VideoEvent(
            eventType: VideoEventType.initialized,
            duration: const Duration(minutes: 2),
            size: const Size(640, 360),
          ),
        );
      }
    });
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int id) => events[id]!.stream;
  @override
  Widget buildView(int id) => const ColoredBox(color: Colors.black);
  @override
  Future<void> dispose(int id) async {
    disposing.add(id);
    await disposal.future;
    await events.remove(id)?.close();
  }

  @override
  Future<void> setLooping(int id, bool value) async {}
  @override
  Future<void> setVolume(int id, double value) async {}
  @override
  Future<void> setPlaybackSpeed(int id, double value) async {}
  @override
  Future<void> play(int id) async {
    plays++;
  }

  @override
  Future<void> pause(int id) async {}
  @override
  Future<void> seekTo(int id, Duration position) async {}
  @override
  Future<Duration> getPosition(int id) async => Duration.zero;
}

Future<void> _frames(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 80 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(done(), isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _HlsNative native;
  late _FilePlatform platform;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await useIsolatedDownloadFixture();
    VideoLocalResources.invalidate();
    native = _HlsNative();
    platform = _FilePlatform();
    final previous = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = platform;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final viewChannels = <MethodChannel>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
      if (call.method == 'create') {
        final arguments = call.arguments as Map;
        final channel = MethodChannel('${arguments['viewType']}.${arguments['id']}');
        viewChannels.add(channel);
        messenger.setMockMethodCallHandler(channel, (_) async => null);
      }
      return null;
    });
    messenger.setMockMethodCallHandler(VideoHlsAssets.channel, native.invoke);
    messenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    addTearDown(() {
      VideoPlayerPlatform.instance = previous;
      messenger.setMockMethodCallHandler(VideoHlsAssets.channel, null);
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (final channel in viewChannels) {
        messenger.setMockMethodCallHandler(channel, null);
      }
    });
  });

  Future<void> host(WidgetTester tester, Future<void> Function() body) async {
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await body();
    } finally {
      if (!platform.disposal.isCompleted) platform.disposal.complete();
      if (native.acquiring?.isCompleted == false)
        native.acquiring!.complete(native.capability);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      debugDefaultTargetPlatformOverride = previous;
    }
  }

  for (final initialized in [true, false]) {
    testWidgets(
      'HLS ${initialized ? 'playing' : 'initializing'} uses app file player and releases after native dispose',
      (tester) => host(tester, () async {
        platform.initialize = initialized;
        late NativePlaybackSession session;
        await tester.runAsync(() async {
          session = await VideoLocalResources.playback(_id);
        });
        expect(session.sources.single.localResourceId, _id);
        expect(session.sources.single.url.scheme, 'breeze-hls');
        expect(
          session.sources.single.url.toString(),
          isNot(contains('Library')),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: NativeVideoPage(
              session: session,
              source: 'hls-inline',
              autoResourceFallback: false,
            ),
          ),
        );
        await _frames(tester, () => platform.sources.isNotEmpty);
        if (initialized) await _frames(tester, () => platform.plays > 0);
        expect(platform.sources.single.sourceType, DataSourceType.file);
        expect(platform.sources.single.uri, _package);
        expect(
          native.calls.any((call) => call.method == 'openOffline'),
          isFalse,
        );
        await tester.runAsync(
          () => expectLater(
            VideoLocalResources.remove(_id),
            throwsA(isA<ManagedVideoResourceBusy>()),
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await _frames(tester, () => platform.disposing.isNotEmpty);
        expect(native.releases, 0);
        expect(
          VideoLocalResources.requireNoReadLeases,
          throwsA(isA<ManagedVideoResourceBusy>()),
        );
        platform.disposal.complete();
        await _frames(tester, () => native.releases == 1);
        await tester.pump();
        VideoLocalResources.requireNoReadLeases();
        final arguments =
            native.calls
                    .firstWhere((call) => call.method == 'releasePlayback')
                    .arguments
                as Map;
        expect(arguments, {
          'resourceId': _id,
          'assetId': 'asset-1',
          'generation': 'generation-1',
          'leaseId': 'reader-1',
        });
        await tester.runAsync(() => VideoLocalResources.remove(_id));
        expect(tester.takeException(), isNull);
      }),
    );
  }

  testWidgets(
    'acquire arriving after page removal is released without initializing a platform player',
    (tester) => host(tester, () async {
      native.acquiring = Completer<Object?>();
      late NativePlaybackSession session;
      await tester.runAsync(() async {
        session = await VideoLocalResources.playback(_id);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: NativeVideoPage(
            session: session,
            source: 'hls-inline',
            autoResourceFallback: false,
          ),
        ),
      );
      await _frames(tester, () => native.acquires == 1);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(
        VideoLocalResources.requireNoReadLeases,
        throwsA(isA<ManagedVideoResourceBusy>()),
      );
      native.acquiring!.complete(native.capability);
      await _frames(tester, () => native.releases == 1);
      await tester.pump();
      expect(platform.sources, isEmpty);
      VideoLocalResources.requireNoReadLeases();
      expect(tester.takeException(), isNull);
    }),
  );

  testWidgets(
    'native acquire failure releases Dart hold and never falls through to network playback',
    (tester) => host(tester, () async {
      native.failAcquire = true;
      late NativePlaybackSession session;
      await tester.runAsync(() async {
        session = await VideoLocalResources.playback(_id);
      });
      var networkPlayers = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: NativeVideoPage(
            session: session,
            source: 'hls-inline',
            autoResourceFallback: false,
            playerFactory: (_) {
              networkPlayers++;
              throw StateError('unexpected network player');
            },
          ),
        ),
      );
      await _frames(tester, () => native.acquires == 1);
      await tester.pump(const Duration(milliseconds: 300));
      expect(platform.sources, isEmpty);
      expect(networkPlayers, 0);
      expect(native.releases, 0);
      VideoLocalResources.requireNoReadLeases();
      expect(tester.takeException(), isNull);
    }),
  );

  testWidgets(
    'a newer manual source wins over a delayed HLS acquire and keeps its own lease',
    (tester) => host(tester, () async {
      native.acquiring = Completer<Object?>();
      late NativePlaybackSession session;
      await tester.runAsync(() async {
        session = await VideoLocalResources.playback(_id);
      });
      final initial = session.sources.single;
      session = session.withSources([
        initial,
        NativePlaybackSource(
          url: initial.url.replace(pathSegments: ['generation-2', _id]),
          label: '1080p',
          headers: const {},
          localResourceId: _id,
        ),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: NativeVideoPage(
            session: session,
            source: 'hls-inline',
            autoResourceFallback: false,
          ),
        ),
      );
      await _frames(tester, () => native.acquires == 1);
      await tester.tap(find.byKey(const ValueKey('video-inline.sources')));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.widgetWithText(ListTile, '1080p'));
      await _frames(tester, () => platform.plays > 0);
      expect(native.acquires, 2);
      native.acquiring!.complete({'leaseId': 'reader-1', 'fileURL': _package});
      await _frames(tester, () => native.releases == 1);
      expect(platform.sources, hasLength(1));
      expect(
        (native.calls
                .firstWhere((call) => call.method == 'releasePlayback')
                .arguments
            as Map)['leaseId'],
        'reader-1',
      );
      expect(
        VideoLocalResources.requireNoReadLeases,
        throwsA(isA<ManagedVideoResourceBusy>()),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester, () => platform.disposing.isNotEmpty);
      expect(native.releases, 1);
      platform.disposal.complete();
      await _frames(tester, () => native.releases == 2);
      await tester.pump();
      VideoLocalResources.requireNoReadLeases();
      expect(tester.takeException(), isNull);
    }),
  );
}
