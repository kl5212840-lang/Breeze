import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/native_video_page.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_download.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_local_playback.dart';
import 'package:zephyr/page/video/downloaded_video_playback_queue.dart';
import 'package:zephyr/page/video/downloaded_video_playback_page.dart';
import 'package:zephyr/page/video/video_playback_preferences.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/network/sync/sync_service.dart'
    show runExclusiveStorageOperation;
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/page/video/video_playback_quick_panel.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/collection_cover_fit.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';

import '../download_fixture.dart';

class _FileVideoPlatform extends VideoPlayerPlatform {
  final sources = <DataSource>[];
  final events = <int, StreamController<VideoEvent>>{};
  Completer<void>? disposal;
  final disposing = <int>[];
  bool initialize = true, failInitialize = false;
  int plays = 0;
  Duration position = Duration.zero;
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
      if (failInitialize && !stream.isClosed) {
        stream.addError(
          PlatformException(
            code: 'SyntheticInitFailure',
            message: 'Synthetic media initialization failed',
          ),
        );
      } else if (initialize && !stream.isClosed)
        stream.add(
          VideoEvent(
            eventType: VideoEventType.initialized,
            duration: const Duration(minutes: 1),
            size: const Size(640, 360),
          ),
        );
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
    await disposal?.future;
    await events.remove(id)?.close();
  }

  @override
  Future<void> setLooping(int id, bool looping) async {}
  @override
  Future<void> setVolume(int id, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int id, double speed) async {}
  @override
  Future<void> play(int id) async {
    plays++;
  }

  @override
  Future<void> pause(int id) async {}
  @override
  Future<void> seekTo(int id, Duration position) async {
    this.position = position;
  }

  @override
  Future<Duration> getPosition(int id) async => position;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final page = Uri.parse('https://hanime1.me/watch?v=5');
  late String id;
  setUpAll(() async {
    // The downloaded player initializes both controllers. Their write queue
    // futures must outlive the widget test's FakeAsync zone because the
    // backup snapshot later waits for them from a plain test.
    await CollectionCoverFitController.instance.flush();
    await CollectionCoverPrivacyController.instance.flushStyle();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await useIsolatedDownloadFixture();
    VideoLocalResources.invalidate();
    id = VideoLocalResources.identity('local-source', page, '720p');
  });

  Future<File> seed() async {
    final file = await VideoLocalResources.file(id);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(
      Uint8List.fromList([
        0,
        0,
        0,
        24,
        102,
        116,
        121,
        112,
        ...List.filled(16, 0),
      ]),
    );
    await VideoLocalResources.saved(
      resourceId: id,
      bytes: 24,
      source: 'local-source',
      video: page,
      title: '离线作品',
      quality: '720p',
      taskKey: 'fixture-task',
    );
    return file;
  }

  for (final (recording, resume, completed) in [
    (true, true, false),
    (true, false, false),
    (false, true, false),
    (false, false, false),
    (true, true, true),
    (true, false, true),
    (false, true, true),
    (false, false, true),
  ]) {
    testWidgets(
      'local route respects record=$recording resume=$resume completed=$completed',
      (tester) async {
        final cover = Uri.parse('https://cover.test/fixture.jpg');
        await tester.runAsync(() async {
          await seed();
          await VideoPlaybackPreferences.save('recordHistory', recording);
          await VideoPlaybackPreferences.save('resumeProgress', resume);
          await VideoWatchHistory.record(
            'local-source',
            VideoWatchRecord(
              watchUrl: page,
              title: 'Previous record',
              coverUrl: cover,
              position: completed
                  ? const Duration(minutes: 1)
                  : const Duration(seconds: 17),
              duration: const Duration(minutes: 1),
              updatedAt: DateTime.utc(2026, 11, 4),
              completed: completed,
            ),
          );
        });
        final platform = _FileVideoPlatform();
        final previous = VideoPlayerPlatform.instance;
        VideoPlayerPlatform.instance = platform;
        addTearDown(() => VideoPlayerPlatform.instance = previous);
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (_) async => null,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        Future<DownloadedVideoPlaybackPlan>? observedPlan;
        Object? queueError;
        StackTrace? queueStack;
        var queueCompleted = false;
        Future<void> frames(
          bool Function() ready, {
          String phase = 'native disposal',
        }) async {
          // The public route now builds a queue from real managed files and
          // durable metadata before constructing NativeVideoPage. Fake frame
          // time alone cannot complete those OS I/O callbacks.
          for (var i = 0; i < 240 && !ready(); i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump(const Duration(milliseconds: 16));
            final plans = find.byType(
              FutureBuilder<DownloadedVideoPlaybackPlan>,
            );
            if (plans.evaluate().isNotEmpty) {
              final future = tester
                  .widget<FutureBuilder<DownloadedVideoPlaybackPlan>>(
                    plans.first,
                  )
                  .future;
              if (future != null && !identical(future, observedPlan)) {
                observedPlan = future;
                unawaited(
                  future.then<void>(
                    (_) {
                      queueCompleted = true;
                    },
                    onError: (Object error, StackTrace stack) {
                      queueError = error;
                      queueStack = stack;
                    },
                  ),
                );
              }
            }
            final error = tester.takeException();
            if (error != null)
              fail('$phase raised a framework exception: $error');
            if (queueError != null)
              fail('Downloaded queue failed: $queueError\n$queueStack');
          }
          expect(
            ready(),
            isTrue,
            reason:
                '$phase; queueCompleted=$queueCompleted; '
                'downloadPage=${find.byType(DownloadedVideoPlaybackPage).evaluate().length}; '
                'nativePage=${find.byType(NativeVideoPage).evaluate().length}; '
                'created=${platform.sources.length}; plays=${platform.plays}',
          );
        }

        try {
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => openLocalVideo(context, id),
                    child: const Text('Open local'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open local'));
          await frames(
            () => find.byType(NativeVideoPage).evaluate().isNotEmpty,
            phase: 'download queue and route',
          );
          await frames(
            () => platform.sources.isNotEmpty,
            phase: 'file controller creation',
          );
          await frames(
            () => platform.plays > 0,
            phase: 'history policy and playback',
          );
          final player = tester.widget<NativeVideoPage>(
            find.byType(NativeVideoPage),
          );
          expect(
            player.initialPosition,
            isNull,
            reason: 'persistent history must use the player resume policy',
          );
          expect(player.source, 'local-source');
          expect(player.session.watchUrl, page);
          expect(player.session.sources.single.localResourceId, id);
          expect(player.historyCoverUrl, cover);
          expect(
            platform.position,
            recording && resume && !completed
                ? const Duration(seconds: 17)
                : Duration.zero,
          );
          expect(platform.sources.single.sourceType, DataSourceType.file);
          expect(platform.sources, hasLength(1));
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await frames(() => platform.events.isEmpty);
          await tester.runAsync(VideoWatchHistory.flush);
          VideoLocalResources.requireNoReadLeases();
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'each authenticated local reader blocks deletion and tree replacement until its own release',
    () async {
      final file = await seed();
      final first = VideoLocalResources.acquireReadLease(file.uri, id);
      final second = VideoLocalResources.acquireReadLease(file.uri, id);
      expect(
        VideoLocalResources.requireNoReadLeases,
        throwsA(isA<ManagedVideoResourceBusy>()),
      );
      await expectLater(
        VideoLocalResources.remove(id),
        throwsA(isA<ManagedVideoResourceBusy>()),
      );
      expect(
        VideoLocalResources.acquireTreeMutationLease,
        throwsA(isA<ManagedVideoResourceBusy>()),
      );
      first.release();
      first.release();
      expect(
        VideoLocalResources.requireNoReadLeases,
        throwsA(isA<ManagedVideoResourceBusy>()),
      );
      second.release();
      final writer = VideoLocalResources.acquireTreeMutationLease();
      expect(
        () => VideoLocalResources.acquireReadLease(file.uri, id),
        throwsA(isA<ManagedVideoResourceBusy>()),
      );
      writer.release();
      writer.release();
      expect(
        () => VideoLocalResources.acquireReadLease(
          Uri.file('/unmanaged/$id.mp4'),
          id,
        ),
        throwsFormatException,
      );
      await VideoLocalResources.remove(id);
      expect(await file.exists(), isFalse);
    },
  );

  for (final initialize in [true, false]) {
    testWidgets(
      'actual managed player ${initialize ? 'playing' : 'initializing'} holds file until native dispose acknowledges',
      (tester) async {
        late NativePlaybackSession session;
        await tester.runAsync(() async {
          await seed();
          session = await VideoLocalResources.playback(id);
        });
        final platform = _FileVideoPlatform()
          ..initialize = initialize
          ..disposal = Completer<void>();
        final previous = VideoPlayerPlatform.instance;
        VideoPlayerPlatform.instance = platform;
        addTearDown(() => VideoPlayerPlatform.instance = previous);
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (_) async => null,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        Future<void> frames(bool Function() condition) async {
          for (var i = 0; i < 80 && !condition(); i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 5)),
            );
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(condition(), isTrue);
        }

        try {
          await tester.pumpWidget(
            MaterialApp(
              home: NativeVideoPage(
                session: session,
                source: 'local-source',
                autoResourceFallback: false,
              ),
            ),
          );
          await frames(() => platform.sources.isNotEmpty);
          if (initialize) await frames(() => platform.plays > 0);
          expect(
            VideoLocalResources.requireNoReadLeases,
            throwsA(isA<ManagedVideoResourceBusy>()),
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await frames(() => platform.disposing.isNotEmpty);
          expect(
            VideoLocalResources.requireNoReadLeases,
            throwsA(isA<ManagedVideoResourceBusy>()),
            reason: 'Widget disposal alone is not native file release.',
          );
          platform.disposal!.complete();
          await frames(() => platform.events.isEmpty);
          await tester.pump();
          VideoLocalResources.requireNoReadLeases();
          await tester.runAsync(() => VideoLocalResources.remove(id));
        } finally {
          if (!platform.disposal!.isCompleted) platform.disposal!.complete();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'managed initialization failure releases its file only through disposal',
    (tester) async {
      late NativePlaybackSession session;
      await tester.runAsync(() async {
        await seed();
        session = await VideoLocalResources.playback(id);
      });
      final platform = _FileVideoPlatform()..failInitialize = true;
      final previous = VideoPlayerPlatform.instance;
      VideoPlayerPlatform.instance = platform;
      addTearDown(() => VideoPlayerPlatform.instance = previous);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (_) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: NativeVideoPage(
              session: session,
              autoResourceFallback: false,
            ),
          ),
        );
        for (var i = 0; i < 80 && platform.disposing.isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(platform.disposing, isNotEmpty);
        for (var i = 0; i < 80 && platform.events.isNotEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(
          platform.events,
          isEmpty,
          reason: 'The failing native player must acknowledge disposal.',
        );
        await tester.pump();
        VideoLocalResources.requireNoReadLeases();
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        for (var i = 0; i < 80 && platform.events.isNotEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final episode in [false, true]) {
    testWidgets(
      'actual ${episode ? 'episode' : 'source'} selection retires the old file before opening the next local player',
      (tester) async {
        late NativePlaybackSession session;
        late NativePlaybackSession nextSession;
        late NativeVideoCard target;
        late String nextId;
        await tester.runAsync(() async {
          await seed();
          final first = await VideoLocalResources.playback(id);
          final nextPage = Uri.parse('https://hanime1.me/watch?v=6');
          nextId = VideoLocalResources.identity(
            'local-source',
            nextPage,
            '480p',
          );
          final next = await VideoLocalResources.file(nextId);
          await next.writeAsBytes(
            Uint8List.fromList([
              0,
              0,
              0,
              24,
              102,
              116,
              121,
              112,
              ...List.filled(16, 0),
            ]),
          );
          await VideoLocalResources.saved(
            resourceId: nextId,
            bytes: 24,
            source: 'local-source',
            video: nextPage,
            title: 'Next',
            quality: '480p',
            taskKey: 'next-task',
          );
          final second = await VideoLocalResources.playback(nextId);
          nextSession = second;
          target = NativeVideoCard(
            title: 'Next episode',
            watchUrl: second.watchUrl,
            coverUrl: null,
          );
          session = NativePlaybackSession(
            title: first.title,
            watchUrl: first.watchUrl,
            description: '',
            tags: [],
            episodes: [target],
            sources: episode
                ? [first.sources.single]
                : [first.sources.single, second.sources.single],
          );
        });
        final platform = _FileVideoPlatform(),
            previous = VideoPlayerPlatform.instance;
        VideoPlayerPlatform.instance = platform;
        addTearDown(() => VideoPlayerPlatform.instance = previous);
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (_) async => null,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        final style = ValueNotifier('breeze');
        addTearDown(style.dispose);
        Future<void> frames(bool Function() condition) async {
          for (var i = 0; i < 80 && !condition(); i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 5)),
            );
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(condition(), isTrue);
        }

        try {
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: style,
              child: MaterialApp(
                home: NativeVideoPage(
                  session: session,
                  preferredSource: 'auto',
                  autoResourceFallback: false,
                  loadEpisode: episode
                      ? (_) async => (session: nextSession, operations: null)
                      : null,
                ),
              ),
            ),
          );
          await frames(() => platform.plays == 1);
          final settings = find.byTooltip(t.videoPlayback.playbackSettings);
          expect(settings.hitTestable(), findsOneWidget);
          await tester.tap(settings);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 240));
          platform.disposal = Completer<void>();
          final panel = tester.widget<VideoPlaybackQuickPanel>(
            find.byType(VideoPlaybackQuickPanel),
          );
          if (episode) {
            panel.onEpisode!(target);
          } else {
            panel.onSource(1);
          }
          await frames(() => platform.disposing.isNotEmpty);
          expect(
            platform.sources,
            hasLength(1),
            reason: 'Native teardown still owns the old resource.',
          );
          await tester.runAsync(
            () => expectLater(
              VideoLocalResources.remove(id),
              throwsA(isA<ManagedVideoResourceBusy>()),
            ),
          );
          platform.disposal!.complete();
          await frames(() => platform.plays == 2);
          expect(platform.sources.last.uri, contains('$nextId.mp4'));
          await tester.runAsync(() => VideoLocalResources.remove(id));
          await tester.runAsync(
            () => expectLater(
              VideoLocalResources.remove(nextId),
              throwsA(isA<ManagedVideoResourceBusy>()),
            ),
          );
        } finally {
          if (platform.disposal?.isCompleted == false)
            platform.disposal!.complete();
          await tester.pumpWidget(const SizedBox.shrink());
          await frames(() => platform.events.isEmpty);
          await tester.pump();
        }
        VideoLocalResources.requireNoReadLeases();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('ordinary website playback holds no managed file lease', (
    tester,
  ) async {
    final platform = _FileVideoPlatform(),
        previous = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = platform;
    addTearDown(() => VideoPlayerPlatform.instance = previous);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: NativeVideoPage(
          autoResourceFallback: false,
          session: NativePlaybackSession(
            title: 'Network',
            watchUrl: page,
            description: '',
            tags: [],
            sources: [
              NativePlaybackSource(
                url: Uri.https('example.test', '/video.mp4'),
                label: 'Network',
                headers: {},
              ),
            ],
          ),
        ),
      ),
    );
    for (var i = 0; i < 80 && platform.plays == 0; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(platform.plays, 1);
    final tree = VideoLocalResources.acquireTreeMutationLease();
    tree.release();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });

  test(
    'managed index is relative and survives task clearing without deleting the resource',
    () async {
      final file = await seed();
      final index = File(
        '${(await VideoLocalResources.root()).path}/index.json',
      );
      final raw = await index.readAsString();
      expect(
        (await VideoLocalResources.read()).single,
        isNot(contains('durationMs')),
      );
      expect(
        (await VideoLocalResources.read()).single,
        isNot(contains('sourceDuration')),
      );
      expect(raw, isNot(contains(file.path)));
      expect(raw, isNot(contains('file://')));
      expect(raw, isNot(contains('available')));
      expect((await VideoExportRecords.readTasks()).single['local'], isTrue);
      final snapshot = await PortablePreferences.capture();
      expect(
        PortablePreferences.owns(VideoExportRecords.taskStorageKey),
        isFalse,
      );
      expect(jsonEncode(snapshot.toJson()), isNot(contains(id)));
      expect(jsonEncode(snapshot.toJson()), isNot(contains(file.path)));
      await VideoExportRecords.clearTaskRecords({'fixture-task'});
      expect(await file.exists(), isTrue);
      expect((await VideoLocalResources.read()).single['available'], isTrue);
      VideoLocalResources.invalidate();
      expect(
        await VideoExportRecords.readTasks(),
        isEmpty,
        reason:
            'Re-reading a backed-up resource index must not resurrect cleared task history.',
      );
    },
  );

  for (final duration in [125000, null]) {
    test(
      'request duration $duration survives task persistence, stage commit and task clearing',
      () async {
        final previousPlatform = debugDefaultTargetPlatformOverride;
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(
          () => debugDefaultTargetPlatformOverride = previousPlatform,
        );
        const channel = MethodChannel('breeze.video.download');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final stageId = List.filled(32, 'd').join();
        final stage = await VideoLocalResources.stagedFile(stageId);
        await stage.parent.create(recursive: true);
        await stage.writeAsBytes(
          Uint8List(40)..setAll(0, [0, 0, 0, 24, 102, 116, 121, 112]),
        );
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'start');
          // Timing metadata belongs to Dart storage, not the native transfer API.
          expect(call.arguments, isNot(contains('durationMs')));
          expect(call.arguments, isNot(contains('sourceDuration')));
          final prefs = await SharedPreferences.getInstance();
          final task =
              (jsonDecode(prefs.getString(VideoExportRecords.taskStorageKey)!)
                          as List)
                      .single
                  as Map;
          expect(task['durationMs'], duration);
          expect(task['sourceDuration'], '站点时长 2分06秒');
          return {
            'status': 'staged',
            'resourceId': id,
            'stageId': stageId,
            'bytes': 40,
          };
        });
        expect(
          await VideoSystemDownload().save(
            choice: (
              label: '720p',
              url: Uri.parse('https://media.example/video.mp4'),
              format: 'mp4',
            ),
            source: 'local-source',
            video: page,
            title: 'duration round trip',
            durationMs: duration,
            sourceDuration: '站点时长 2分06秒',
            onProgress: (_) {},
          ),
          VideoDownloadStatus.saved,
        );
        final task = (await VideoExportRecords.readTasks()).single;
        expect(task['durationMs'], duration);
        expect(task['sourceDuration'], '站点时长 2分06秒');
        final index = File(
          '${(await VideoLocalResources.root()).path}/index.json',
        );
        final payload = jsonDecode(await index.readAsString()) as Map;
        expect(payload['version'], 1);
        final stored = (payload['resources'] as List).single as Map;
        expect(stored['durationMs'], duration);
        expect(stored['sourceDuration'], '站点时长 2分06秒');
        if (duration == null) expect(stored, isNot(contains('durationMs')));
        await VideoExportRecords.clearTaskRecords({task['key'] as String});
        VideoLocalResources.invalidate();
        final restored = (await VideoLocalResources.read(fresh: true)).single;
        expect(restored['durationMs'], duration);
        expect(restored['sourceDuration'], '站点时长 2分06秒');
        expect(restored['available'], isTrue);
        expect(await VideoExportRecords.readTasks(), isEmpty);
      },
    );
  }

  test(
    'physical deletion retains resource metadata and marks the same task file removed',
    () async {
      final file = await seed();
      await VideoLocalResources.remove(id);
      expect(await file.exists(), isFalse);
      final resource = (await VideoLocalResources.read(fresh: true)).single;
      expect(resource['available'], isFalse);
      expect(resource['showTask'], isTrue);
      final task = (await VideoExportRecords.readTasks()).single;
      expect(task['status'], 'saved');
      expect(task['fileRemoved'], isTrue);
      expect(task['title'], '离线作品');
    },
  );

  test(
    'missing bytes, traversal, symlinks and future indexes cannot become playable resources',
    () async {
      await expectLater(
        VideoLocalResources.file('../outside'),
        throwsFormatException,
      );
      await expectLater(
        VideoLocalResources.saved(
          resourceId: id,
          bytes: 24,
          source: 'local-source',
          video: page,
          title: '不存在',
          quality: '720p',
          taskKey: 'x',
        ),
        throwsFormatException,
      );
      final file = await seed();
      final outside = File('${file.parent.path}/outside.bin');
      await outside.writeAsString('not a local video');
      await file.delete();
      await Link(file.path).create(outside.path);
      await expectLater(VideoLocalResources.file(id), throwsFormatException);
      await Link(file.path).delete();
      final index = File('${file.parent.path}/index.json');
      await index.writeAsString(
        jsonEncode({
          'format': 'breeze-local-video',
          'version': 2,
          'resources': [],
        }),
      );
      VideoLocalResources.invalidate();
      await expectLater(VideoLocalResources.read(), throwsFormatException);
      expect(jsonDecode(await index.readAsString())['version'], 2);
    },
  );

  test(
    'future index rejects staged commit before replacing an existing resource',
    () async {
      final file = await seed();
      final directory = await VideoLocalResources.root();
      final index = File('${directory.path}/index.json');
      await index.writeAsString(
        jsonEncode({
          'format': 'breeze-local-video',
          'version': 2,
          'resources': [],
        }),
      );
      final stageId = List.filled(32, 'c').join();
      final stage = await VideoLocalResources.stagedFile(stageId);
      await stage.parent.create(recursive: true);
      await stage.writeAsBytes(
        Uint8List(40)..setAll(0, [0, 0, 0, 24, 102, 116, 121, 112]),
      );
      VideoLocalResources.invalidate();
      await expectLater(
        VideoLocalResources.commitStaged(
          stageId: stageId,
          resourceId: id,
          bytes: 40,
          source: 'local-source',
          video: page,
          title: '新资料',
          quality: '720p',
          taskKey: 'new-task',
        ),
        throwsFormatException,
      );
      expect(await file.length(), 24);
      expect(await stage.exists(), isTrue);
      expect(jsonDecode(await index.readAsString())['version'], 2);
    },
  );

  test(
    'index write failure restores the previous playable video and index',
    () async {
      final stable = await seed();
      final original = await stable.readAsBytes();
      final index = File('${stable.parent.path}/index.json');
      final originalIndex = await index.readAsString();
      final stageId = List.filled(32, 'e').join();
      final stage = await VideoLocalResources.stagedFile(stageId);
      await stage.parent.create(recursive: true);
      await stage.writeAsBytes(
        Uint8List(40)..setAll(0, [0, 0, 0, 24, 102, 116, 121, 112]),
      );
      Directory? blockedIndexStage;
      await expectLater(
        VideoLocalResources.commitStaged(
          stageId: stageId,
          resourceId: id,
          bytes: 40,
          source: 'local-source',
          video: page,
          title: 'replacement',
          quality: '720p',
          taskKey: 'replacement-task',
          cancelled: () {
            if (stable.existsSync() &&
                stable.lengthSync() == 40 &&
                blockedIndexStage == null) {
              // Inject a real index-write failure only after stable replacement.
              // The retained file identifies this transaction's sequence without
              // a production test hook or assumptions about prior test order.
              final retained = stable.parent.listSync().singleWhere(
                (entry) => entry.path.contains('.replace-$stageId-'),
              );
              final sequence = int.parse(
                retained.path.split('-').last.split('.').first,
              );
              blockedIndexStage = Directory(
                '${stable.parent.path}/.index-${sequence + 1}.tmp',
              )..createSync();
            }
            return false;
          },
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(blockedIndexStage, isNotNull);
      await blockedIndexStage!.delete();
      expect(await stable.readAsBytes(), orderedEquals(original));
      expect(await index.readAsString(), originalIndex);
      expect(await stage.length(), 40);
      expect(
        (await VideoLocalResources.read(fresh: true)).single['available'],
        isTrue,
      );
      expect(
        (await VideoLocalResources.playback(id)).sources.single.url,
        stable.uri,
      );
      expect(
        stable.parent.listSync().where(
          (entry) => entry.path.contains('.replace-'),
        ),
        isEmpty,
      );
    },
  );

  for (final existing in [false, true]) {
    test(
      'cancellation after replacement restores ${existing ? 'existing video' : 'absence'}',
      () async {
        final stable = existing
            ? await seed()
            : await VideoLocalResources.file(id);
        final stageId = List.filled(32, existing ? 'f' : 'a').join();
        final stage = await VideoLocalResources.stagedFile(stageId);
        await stage.parent.create(recursive: true);
        await stage.writeAsBytes(
          Uint8List(40)..setAll(0, [0, 0, 0, 24, 102, 116, 121, 112]),
        );
        final result = await VideoLocalResources.commitStaged(
          stageId: stageId,
          resourceId: id,
          bytes: 40,
          source: 'local-source',
          video: page,
          title: 'cancelled replacement',
          quality: '720p',
          taskKey: 'cancelled-replacement',
          cancelled: () => stable.existsSync() && stable.lengthSync() == 40,
        );
        expect(result, isFalse);
        expect(await stage.length(), 40);
        expect(await stable.exists(), existing);
        final rows = await VideoLocalResources.read(fresh: true);
        if (existing) {
          expect(await stable.length(), 24);
          expect(rows.single['available'], isTrue);
          expect(rows.single['taskKey'], isNot('cancelled-replacement'));
        } else {
          expect(rows, isEmpty);
        }
        expect(
          stable.parent.listSync().where(
            (entry) => entry.path.contains('.replace-'),
          ),
          isEmpty,
        );
      },
    );
  }

  test(
    'successful replacement commits matching bytes and removes its retained file',
    () async {
      final stable = await seed();
      final stageId = List.filled(32, 'b').join();
      final stage = await VideoLocalResources.stagedFile(stageId);
      await stage.parent.create(recursive: true);
      await stage.writeAsBytes(
        Uint8List(40)..setAll(0, [0, 0, 0, 24, 102, 116, 121, 112]),
      );
      expect(
        await VideoLocalResources.commitStaged(
          stageId: stageId,
          resourceId: id,
          bytes: 40,
          source: 'local-source',
          video: page,
          title: 'new saved title',
          quality: '720p',
          taskKey: 'new-saved-task',
        ),
        isTrue,
      );
      expect(await stable.length(), 40);
      expect(await stage.exists(), isFalse);
      final row = (await VideoLocalResources.read(fresh: true)).single;
      expect(row['bytes'], 40);
      expect(row['taskKey'], 'new-saved-task');
      expect(row['available'], isTrue);
      expect(
        stable.parent.listSync().where(
          (entry) => entry.path.contains('.replace-'),
        ),
        isEmpty,
      );
    },
  );

  test(
    'a staged commit waiting behind backup honors cancellation before stable mutation',
    () async {
      final stageId = List.filled(32, 'd').join();
      final stage = await VideoLocalResources.stagedFile(stageId);
      await stage.parent.create(recursive: true);
      await stage.writeAsBytes(
        Uint8List.fromList([
          0,
          0,
          0,
          24,
          102,
          116,
          121,
          112,
          ...List.filled(16, 0),
        ]),
      );
      final stable = await VideoLocalResources.file(id);
      final gate = Completer<void>();
      final backup = runExclusiveStorageOperation(() => gate.future);
      var cancelled = false, finished = false;
      final pending =
          VideoLocalResources.commitStaged(
            stageId: stageId,
            resourceId: id,
            bytes: 24,
            source: 'local-source',
            video: page,
            title: '未提交任务',
            quality: '720p',
            taskKey: 'cancelled-stage',
            cancelled: () => cancelled,
          ).then((value) {
            finished = true;
            return value;
          });
      await Future<void>.delayed(Duration.zero);
      expect(finished, isFalse);
      cancelled = true;
      gate.complete();
      await backup;
      expect(await pending, isFalse);
      expect(await stable.exists(), isFalse);
      expect(await stage.exists(), isTrue);
      await VideoLocalResources.discardStage(stageId);
      expect(await stage.exists(), isFalse);
    },
  );

  testWidgets(
    'the actual existing player receives a managed file data source, never a network source',
    (tester) async {
      late NativePlaybackSession session;
      await tester.runAsync(() async {
        await seed();
        session = await VideoLocalResources.playback(id);
      });
      final platform = _FileVideoPlatform(),
          previous = VideoPlayerPlatform.instance;
      VideoPlayerPlatform.instance = platform;
      addTearDown(() => VideoPlayerPlatform.instance = previous);
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (_) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: style,
          child: MaterialApp(
            home: NativeVideoPage(
              session: session,
              source: 'local-source',
              autoResourceFallback: false,
            ),
          ),
        ),
      );
      for (var frame = 0; frame < 80 && platform.sources.isEmpty; frame++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(platform.sources, hasLength(1));
      expect(platform.sources.single.sourceType, DataSourceType.file);
      expect(platform.sources.single.uri, contains('$id.mp4'));
      expect(session.sources.single.localResourceId, id);
      expect(
        VideoLocalResources.authorizesFile(Uri.file('/outside/$id.mp4'), id),
        isFalse,
      );
      expect(
        () => NativePlaybackSession.fromPluginResponse({
          'data': {
            'sources': [
              {
                'url': session.sources.single.url.toString(),
                'label': 'forged',
                'localResourceId': id,
              },
            ],
          },
        }, watchUrl: page),
        throwsFormatException,
      );
      expect(
        session.coverUrl,
        isNull,
        reason: 'Offline player must not fetch a remote poster.',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    },
  );
}
