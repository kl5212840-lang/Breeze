import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/donwload_task/service/download_center_projection.dart';
import 'package:zephyr/page/donwload_task/service/download_center_resources.dart';
import 'package:zephyr/page/donwload_task/view/download_video_work_page.dart';
import 'package:zephyr/page/video/api_video_detail_page.dart';
import 'package:zephyr/page/video/downloaded_video_playback_page.dart';
import 'package:zephyr/page/video/native_video_page.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/page/video/video_cover_overlay.dart';
import 'package:zephyr/widgets/collection_cover_fit.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/widgets/soft_cover_background.dart';
import 'package:zephyr/util/get_path.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/video_playback_quick_panel.dart';
import 'package:zephyr/page/video/video_hls_assets.dart';
import 'package:zephyr/page/video/video_local_playback.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_public_metadata.dart';
import 'package:zephyr/page/video/video_site_browser.dart';
import 'package:zephyr/page/video/video_playback_preferences.dart';
import 'package:zephyr/page/video/video_watch_history.dart';

import '../download_fixture.dart';

class _NoNetwork extends HttpOverrides {
  int calls = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    calls++;
    throw StateError('Offline host must not create an HTTP client');
  }
}

class _Files extends VideoPlayerPlatform {
  final sources = <DataSource>[];
  final events = <int, StreamController<VideoEvent>>{};
  final disposed = <int>[];
  final positions = <int, Duration>{};
  int plays = 0;
  final seeks = <Duration>[];
  final speeds = <double>[];
  @override
  Future<void> init() async {}
  @override
  Future<void> setMixWithOthers(bool value) async {}
  @override
  Future<int?> create(DataSource source) async {
    sources.add(source);
    final id = sources.length;
    final stream = events[id] = StreamController<VideoEvent>.broadcast();
    Timer.run(() {
      if (!stream.isClosed)
        stream.add(
          VideoEvent(
            eventType: VideoEventType.initialized,
            duration: const Duration(minutes: 2),
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
    disposed.add(id);
    await events.remove(id)?.close();
  }

  @override
  Future<void> setLooping(int id, bool value) async {}
  @override
  Future<void> setVolume(int id, double value) async {}
  @override
  Future<void> setPlaybackSpeed(int id, double value) async {
    speeds.add(value);
  }

  @override
  Future<void> play(int id) async {
    plays++;
  }

  @override
  Future<void> pause(int id) async {}
  @override
  Future<void> seekTo(int id, Duration value) async {
    seeks.add(value);
  }

  @override
  Future<Duration> getPosition(int id) async => positions[id] ?? Duration.zero;
}

class _DownloadsOrigin extends StatefulWidget {
  const _DownloadsOrigin({required this.resourceId, this.resource});
  final String resourceId;
  final Map<String, dynamic>? resource;
  @override
  State<_DownloadsOrigin> createState() => _DownloadsOriginState();
}

class _DownloadsOriginState extends State<_DownloadsOrigin> {
  var filter = 'all';
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Text('Downloads filter $filter'),
        TextButton(
          onPressed: () => setState(() => filter = 'video'),
          child: const Text('Video filter'),
        ),
        TextButton(
          onPressed: () => openLocalVideo(
            context,
            widget.resourceId,
            resource: widget.resource,
          ),
          child: const Text('Open download'),
        ),
      ],
    ),
  );
}

Future<void> _until(
  WidgetTester tester,
  bool Function() done, {
  String? reason,
}) async {
  for (var i = 0; i < 120 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(done(), isTrue, reason: reason);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _Files platform;
  late _NoNetwork noNetwork;
  late VideoPlayerPlatform previousPlayer;
  late HttpOverrides? previousHttp;
  final nativeCalls = <MethodCall>[];
  final hlsRows = <Map<String, dynamic>>[];
  final viewChannels = <MethodChannel>[];
  final nativeControlChannels = <String, String>{};
  Map<String, dynamic>? seededRow;
  Completer<Object?>? pendingAssetList;
  Completer<void>? pendingAcquire;
  var failAcquire = false;
  const source = 'removed-source-offline-host';
  final watch = Uri.parse(
    'https://offline-fixture.test/voddetail/42.html?line=a&episode=1',
  );
  const package = 'file:///fixture/Library/video/offline.movpkg/';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await useIsolatedDownloadFixture();
    VideoLocalResources.invalidate();
    platform = _Files();
    noNetwork = _NoNetwork();
    previousPlayer = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = platform;
    previousHttp = HttpOverrides.current;
    HttpOverrides.global = noNetwork;
    nativeCalls.clear();
    hlsRows.clear();
    viewChannels.clear();
    nativeControlChannels.clear();
    seededRow = null;
    pendingAssetList = null;
    pendingAcquire = null;
    failAcquire = false;
    messenger.setMockMethodCallHandler(VideoHlsAssets.channel, (call) async {
      nativeCalls.add(call);
      if (call.method == 'list') return pendingAssetList?.future ?? hlsRows;
      if (call.method == 'acquirePlayback') {
        await pendingAcquire?.future;
        if (failAcquire) throw PlatformException(code: 'unavailable');
        return {'leaseId': 'offline-reader', 'fileURL': package};
      }
      if (call.method == 'releasePlayback') return true;
      throw MissingPluginException();
    });
    messenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final args = call.arguments as Map;
        final channel = MethodChannel('${args['viewType']}.${args['id']}');
        viewChannels.add(channel);
        if (args['viewType'] == 'breeze.video.control') {
          final raw = args['params'];
          final bytes = raw is ByteData
              ? raw
              : raw is Uint8List
              ? ByteData.sublistView(raw)
              : null;
          final decoded = bytes == null
              ? null
              : const StandardMessageCodec().decodeMessage(bytes);
          if (decoded is Map && decoded['tooltip'] is String) {
            nativeControlChannels[decoded['tooltip'] as String] = channel.name;
          }
        }
        messenger.setMockMethodCallHandler(channel, (_) async => null);
      }
      return null;
    });
    addTearDown(() {
      HttpOverrides.global = previousHttp;
      VideoPlayerPlatform.instance = previousPlayer;
      messenger.setMockMethodCallHandler(VideoHlsAssets.channel, null);
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (final channel in viewChannels) {
        messenger.setMockMethodCallHandler(channel, null);
      }
    });
  });

  Future<String> seed(bool hls, {String? sourceId, Uri? watchUrl}) async {
    final selectedSource = sourceId ?? source;
    final selectedWatch = watchUrl ?? watch;
    final id = hls
        ? VideoHlsAssets.identity(selectedSource, selectedWatch, '720p')
        : VideoLocalResources.identity(selectedSource, selectedWatch, '720p');
    if (hls) {
      hlsRows.add({
        'resourceId': id,
        'assetId': 'offline-asset',
        'generation': 'offline-generation',
        'source': selectedSource,
        'url': selectedWatch.toString(),
        'title': 'Legacy offline episode',
        'quality': '720p',
        'bytes': 4096,
        'taskKey': 'old-task',
        'showTask': true,
        'at': 1700000000000,
        'format': 'hls',
        'available': true,
        'filePresent': true,
        'cover': 'https://private-fixture.test/remote-image.png',
      });
    } else {
      final file = await VideoLocalResources.file(id);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(
        Uint8List(24)..setAll(0, [0, 0, 0, 24, 102, 116, 121, 112]),
      );
      await VideoLocalResources.saved(
        resourceId: id,
        bytes: 24,
        source: selectedSource,
        video: selectedWatch,
        title: 'Legacy offline episode',
        quality: '720p',
        taskKey: 'old-task',
        cover: 'https://private-fixture.test/remote-image.png',
      );
    }
    seededRow = hls
        ? hlsRows.single
        : {
            'resourceId': id,
            'source': selectedSource,
            'url': selectedWatch.toString(),
            'quality': '720p',
          };
    VideoLocalResources.invalidate();
    return id;
  }

  Future<void> host(WidgetTester tester, Future<void> Function() body) async {
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await body();
    } finally {
      try {
        await tester.pumpWidget(const SizedBox.shrink());
        // The route starts poster work and saves progress asynchronously.
        // Finish both while this test can still pump their I/O continuations.
        var drained = false;
        unawaited(
          Future.wait<void>([
            if (seededRow case final row?)
              VideoDownloadedDetails.ensureLocalPoster(row).then<void>((_) {}),
            VideoWatchHistory.flush(),
          ]).then<void>((_) {
            drained = true;
          }),
        );
        await _until(tester, () => drained, reason: 'Finish offline route I/O');
      } finally {
        debugDefaultTargetPlatformOverride = previous;
      }
    }
  }

  testWidgets(
    'work resume follows the latest played episode and exact offline variant on return',
    (tester) => host(tester, () async {
      final second = watch.replace(
        queryParameters: {'line': 'a', 'episode': '2'},
      );
      final latest = VideoLocalResources.identity(source, second, '1080p');
      Future<List<DownloadCenterItem>>
      readItems() async => projectDownloadCenter(
        tasks: [],
        comics: [],
        videos: [
          for (final row in await VideoLocalResources.read(fresh: true))
            if (row['source'] == source && row['available'] == true)
              {
                ...row,
                'key': row['taskKey'],
                'status': 'saved',
                'local': true,
                'publicWorkIdentity': 'work-42',
                'publicModuleNamespace': 'fixture',
                'publicWorkTitle': 'Fixture work',
                'publicEpisodeLabel':
                    'Episode ${Uri.parse(row['url'] as String).queryParameters['episode']}',
              },
        ],
      );
      late List<DownloadCenterItem> items;
      late File exactFile;
      await tester.runAsync(() async {
        for (final (url, quality) in [
          (watch, '720p'),
          (second, '720p'),
          (second, '1080p'),
        ]) {
          final id = VideoLocalResources.identity(source, url, quality);
          final file = await VideoLocalResources.file(id);
          if (id == latest) exactFile = file;
          await file.parent.create(recursive: true);
          await file.writeAsBytes(
            Uint8List(24)..setAll(0, [0, 0, 0, 24, 102, 116, 121, 112]),
          );
          await VideoLocalResources.saved(
            resourceId: id,
            bytes: 24,
            source: source,
            video: url,
            title: 'Fixture episode ${url.queryParameters['episode']}',
            quality: quality,
            taskKey: id,
          );
        }
        for (final (url, episode, position, updatedAt) in [
          (second, 2, 19, DateTime.utc(2019)),
          (watch, 1, 12, DateTime.utc(2020)),
        ]) {
          await VideoWatchHistory.record(
            source,
            VideoWatchRecord(
              watchUrl: url,
              title: 'Fixture episode $episode',
              position: Duration(seconds: position),
              duration: const Duration(minutes: 2),
              updatedAt: updatedAt,
              completed: false,
            ),
          );
        }
        items = await readItems();
      });
      expect(items, hasLength(3));
      final work = groupVideoDownloadItems(items, universe: items).single.work!;
      String? continued;
      Future<void> play(BuildContext context, DownloadCenterItem item) async {
        final row = item.video!;
        await openLocalVideo(
          context,
          row['resourceId'] as String,
          resource: row,
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: DownloadVideoWorkPage(
            initial: work,
            readItems: readItems,
            matches: (_) => true,
            onContinueWatching: (context, item) async {
              continued = item.video!['resourceId'] as String;
              await play(context, item);
            },
            rowBuilder: (context, item, _, resumeAt) => DownloadEpisodePlayRow(
              onPlay: () => play(context, item),
              title:
                  'Open ${item.video!['publicEpisodeLabel']} ${item.video!['quality']}',
              variant: item.video!['quality'] as String,
              resumeAt: resumeAt,
            ),
          ),
        ),
      );
      final card = find.byKey(const ValueKey('video-work-continue-watching'));
      final firstPosition = find.text('Episode 1 · 0:12');
      final secondPosition = find.text('Episode 2 · 0:03');
      Finder episodeProgress(String label) => find.descendant(
        of: find.ancestor(
          of: find.text(label),
          matching: find.byType(DownloadEpisodePlayRow),
        ),
        matching: find.byKey(const ValueKey('download-episode-watch-progress')),
      );
      await _until(tester, () => firstPosition.evaluate().length == 1);
      expect(card, findsOneWidget);

      final openSecond = find.text('Open Episode 2 1080p');
      await tester.ensureVisible(openSecond);
      await tester.pump();
      await tester.tap(openSecond);
      await _until(tester, () => platform.plays == 1);
      expect(platform.sources.single.uri, exactFile.uri.toString());
      expect(platform.seeks, isNot(contains(const Duration(seconds: 19))));
      platform.positions[1] = const Duration(seconds: 3);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.binding.handlePopRoute();
      await _until(
        tester,
        () => secondPosition.evaluate().length == 1,
        reason: 'Episode 2 should replace episode 1 after the player exits',
      );
      expect(firstPosition, findsNothing);
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text('1080p · MP4')),
        findsOneWidget,
      );
      expect(
        tester.widget<Text>(episodeProgress('Open Episode 1 720p')).data,
        contains('0:12'),
      );
      expect(
        tester.widget<Text>(episodeProgress('Open Episode 2 1080p')).data,
        contains('0:03'),
      );
      expect(episodeProgress('Open Episode 2 720p'), findsNothing);
      await tester.pumpAndSettle();
      final saved = await tester.runAsync(() => VideoWatchHistory.read(source));
      expect(saved?.first.localResourceId, latest);

      final otherVariant = find.text('Open Episode 2 720p');
      await tester.ensureVisible(otherVariant);
      await tester.pump();
      await tester.tap(otherVariant);
      await _until(tester, () => platform.plays == 2);
      expect(platform.sources.last.uri, isNot(exactFile.uri.toString()));
      expect(platform.seeks, isNot(contains(const Duration(seconds: 3))));
      await tester.binding.handlePopRoute();
      await _until(tester, () => secondPosition.evaluate().length == 1);
      await tester.pumpAndSettle();

      await tester.ensureVisible(card);
      await tester.pump();
      await tester.tap(card);
      await _until(tester, () => platform.plays == 3);
      expect(continued, latest);
      expect(platform.sources.last.uri, exactFile.uri.toString());
      expect(platform.seeks, contains(const Duration(seconds: 3)));
      platform.positions[3] = const Duration(seconds: 119);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.binding.handlePopRoute();
      await _until(
        tester,
        () => platform.disposed.contains(3) && card.evaluate().isEmpty,
        reason: 'A completed episode must not fall back to episode 1',
      );
      expect(
        tester.widget<Text>(episodeProgress('Open Episode 2 1080p')).data,
        'Watched',
      );

      await tester.runAsync(
        () => VideoWatchHistory.record(
          source,
          VideoWatchRecord(
            watchUrl: second,
            title: 'Fixture episode 2',
            position: const Duration(seconds: 20),
            duration: const Duration(minutes: 2),
            updatedAt: DateTime.now().toUtc(),
            completed: false,
            localResourceId: latest,
          ),
        ),
      );
      await _until(tester, () => card.evaluate().length == 1);
      await tester.runAsync(() async {
        await exactFile.delete();
        VideoLocalResources.invalidate();
      });
      await _until(
        tester,
        () => card.evaluate().isEmpty,
        reason: 'A missing file cannot substitute a different saved variant',
      );
      expect(otherVariant, findsOneWidget);
      expect(noNetwork.calls, 0);
      expect(tester.takeException(), isNull);
    }),
  );

  testWidgets(
    'MP4 playback opens without waiting for the other saved packages',
    (tester) => host(tester, () async {
      late String id;
      await tester.runAsync(() async => id = await seed(false));
      final pending = pendingAssetList = Completer<Object?>();
      try {
        await tester.pumpWidget(
          MaterialApp(home: _DownloadsOrigin(resourceId: id)),
        );
        await tester.tap(find.text('Open download'));
        await _until(tester, () => platform.plays > 0);
        expect(pending.isCompleted, isFalse);
        expect(find.text('Legacy offline episode'), findsWidgets);
        expect(noNetwork.calls, 0);
      } finally {
        pending.complete(hlsRows);
        pendingAssetList = null;
      }
    }),
  );

  testWidgets(
    'known HLS download shows local playback and acquires its exact generation before listing packages',
    (tester) =>
        host(tester, () async {
          late String id;
          await tester.runAsync(() async => id = await seed(true));
          final selected = DownloadCenterResources.mergeVideos([
            {
              'key': 'offline-task',
              'status': 'saved',
              'local': true,
              'resourceId': id,
            },
          ], hlsRows).single;
          final pendingList = pendingAssetList = Completer<Object?>();
          final acquire = pendingAcquire = Completer<void>();
          try {
            await tester.pumpWidget(
              MaterialApp(
                home: _DownloadsOrigin(resourceId: id, resource: selected),
              ),
            );
            await tester.tap(find.text('Open download'));
            await _until(
              tester,
              () => nativeCalls.any((c) => c.method == 'acquirePlayback'),
            );
            expect(find.text('Legacy offline episode'), findsWidgets);
            expect(find.text('Offline playback'), findsOneWidget);
            expect(find.text(t.videoDownload.title), findsNothing);
            expect(nativeCalls.any((c) => c.method == 'list'), isFalse);
            expect(platform.sources, isEmpty);
            expect(
              nativeCalls
                  .singleWhere((c) => c.method == 'acquirePlayback')
                  .arguments,
              {
                'resourceId': id,
                'assetId': 'offline-asset',
                'generation': 'offline-generation',
              },
            );
            acquire.complete();
            await _until(tester, () => platform.plays > 0);
            expect(pendingList.isCompleted, isFalse);
            final player = find.byType(NativeVideoPage);
            expect(tester.widget<NativeVideoPage>(player).loadEpisode, isNull);
            expect(platform.sources.single.uri, package);
            expect(noNetwork.calls, 0);
            await _until(
              tester,
              () => nativeCalls.any((call) => call.method == 'list'),
              reason: 'Enumerate the queue after the player starts',
            );
            expect(platform.sources, hasLength(1));
          } finally {
            if (!acquire.isCompleted) acquire.complete();
            pendingAcquire = null;
            if (!pendingList.isCompleted) pendingList.complete(hlsRows);
            pendingAssetList = null;
          }
        }),
  );

  for (final hls in [false, true]) {
    testWidgets(
      '${hls ? 'HLS' : 'MP4'} public download entry uses app file player with no source and returns to Downloads filter',
      (tester) => host(tester, () async {
        late String id;
        await tester.runAsync(() async {
          id = await seed(hls);
          await VideoWatchHistory.record(
            source,
            VideoWatchRecord(
              watchUrl: watch,
              title: 'Legacy offline episode',
              coverUrl: Uri.parse('https://own-history.test/previous.jpg'),
              metadata: const {'year': '2024', 'language': '原记录语言'},
              position: const Duration(seconds: 12),
              duration: const Duration(minutes: 2),
              updatedAt: DateTime.now(),
              completed: false,
            ),
          );
          await VideoWatchHistory.record(
            'another-source',
            VideoWatchRecord(
              watchUrl: watch,
              title: 'Unrelated source',
              coverUrl: Uri.parse('https://other-source.test/never-use.jpg'),
              metadata: const {'year': '1900'},
              position: Duration.zero,
              duration: const Duration(minutes: 2),
              updatedAt: DateTime.now(),
              completed: false,
            ),
          );
          await VideoPlaybackPreferences.save('defaultSpeed', 1.25);
        });
        await tester.pumpWidget(
          MaterialApp(home: _DownloadsOrigin(resourceId: id)),
        );
        await tester.tap(find.text('Video filter'));
        await tester.pump();
        await tester.tap(find.text('Open download'));
        await _until(tester, () => platform.plays > 0);
        expect(find.byType(DownloadedVideoPlaybackPage), findsOneWidget);
        expect(find.byType(NativeVideoPage), findsOneWidget);
        final player = tester.widget<NativeVideoPage>(
          find.byType(NativeVideoPage),
        );
        expect(
          player.historyCoverUrl,
          Uri.parse('https://private-fixture.test/remote-image.png'),
          reason: 'The indexed cover keeps priority as history-only metadata.',
        );
        expect(player.historyMetadata!(player.session), {
          'year': '2024',
          'language': '原记录语言',
        });
        expect(
          player.session.coverUrl,
          isNull,
          reason:
              'History cover preservation must never request a remote image offline.',
        );
        final localPoster = find.byKey(
          const ValueKey('downloaded-video.cover'),
        );
        expect(localPoster, findsOneWidget);
        expect(
          find.descendant(
            of: localPoster,
            matching: find.byIcon(Icons.play_arrow_rounded),
          ),
          findsWidgets,
        );
        expect(
          find.descendant(
            of: localPoster,
            matching: find.byIcon(Icons.movie_outlined),
          ),
          findsNothing,
        );
        expect(find.byType(ApiVideoDetailPage), findsNothing);
        expect(find.byType(VideoSiteBrowser), findsNothing);
        expect(platform.sources.single.sourceType, DataSourceType.file);
        expect(platform.seeks, contains(const Duration(seconds: 12)));
        expect(platform.speeds, contains(1.25));
        if (hls) {
          expect(platform.sources.single.uri, package);
          expect(
            nativeCalls
                .singleWhere((c) => c.method == 'acquirePlayback')
                .arguments,
            {
              'resourceId': id,
              'assetId': 'offline-asset',
              'generation': 'offline-generation',
            },
          );
        }
        expect(nativeCalls.any((c) => c.method == 'openOffline'), isFalse);
        await _until(
          tester,
          () => find
              .byKey(const ValueKey('downloaded-video.title'))
              .evaluate()
              .isNotEmpty,
        );
        expect(find.text('Legacy offline episode'), findsWidgets);
        expect(noNetwork.calls, 0);
        // System controls are genuine UiKitViews: their tooltip is native
        // creation metadata, not a Flutter Tooltip. Deliver the native button's
        // actual per-view press message, then assert the real panel opened.
        await _until(
          tester,
          () => nativeControlChannels.containsKey(
            t.videoPlayback.playbackSettings,
          ),
        );
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is NativeVideoIconButton &&
                widget.tooltip == t.videoPlayback.playbackSettings,
          ),
          findsOneWidget,
        );
        tester.binding.channelBuffers.push(
          nativeControlChannels[t.videoPlayback.playbackSettings]!,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('press'),
          ),
          (_) {},
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(VideoPlaybackQuickPanel), findsOneWidget);
        expect(find.text(t.videoPlayback.backToWeb), findsNothing);
        expect(find.text(t.sourceShell.exitSource), findsNothing);
        // Device back first dismisses the panel, then pops this one local route.
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(milliseconds: 300));
        if (find.byType(DownloadedVideoPlaybackPage).evaluate().isNotEmpty) {
          await tester.binding.handlePopRoute();
          await tester.pump(const Duration(milliseconds: 400));
        }
        expect(find.text('Downloads filter video'), findsOneWidget);
        await _until(tester, () => platform.disposed.isNotEmpty);
        if (hls)
          await _until(
            tester,
            () => nativeCalls.any((c) => c.method == 'releasePlayback'),
          );
        expect(noNetwork.calls, 0);
        expect(tester.takeException(), isNull);
      }),
    );
  }

  testWidgets(
    'Hanime offline detail labels the saved artist and omits duplicate dates',
    (tester) => host(tester, () async {
      const hanime = '1e600cff-8ebe-4517-8aa4-6678aec46424';
      final page = Uri.parse('https://hanime1.me/watch?v=42');
      late String id;
      await tester.runAsync(() async {
        id = await seed(true, sourceId: hanime, watchUrl: page);
        final day = DateTime.fromMillisecondsSinceEpoch(1700000000000);
        final date = day.toIso8601String().split('T').first;
        await VideoDownloadedDetails.saveSession(
          hanime,
          NativePlaybackSession(
            title: 'Saved title',
            watchUrl: page,
            sources: const [],
            description: 'Saved description',
            tags: const ['Saved tag (1)'],
            creatorName: 'Saved artist',
            metadata: VideoPublicMetadata(publishedDate: date),
          ),
        );
      });
      await tester.pumpWidget(
        MaterialApp(home: _DownloadsOrigin(resourceId: id)),
      );
      await tester.tap(find.text('Open download'));
      final creator = find.byKey(const ValueKey('downloaded-video.creator'));
      await _until(tester, () => creator.evaluate().isNotEmpty);
      expect(
        find.text('${t.bookshelf.facets.author} · Saved artist'),
        findsOneWidget,
      );
      expect(find.text('Saved tag'), findsOneWidget);
      expect(find.text('Saved tag (1)'), findsNothing);
      expect(find.textContaining('Published at'), findsNothing);
      expect(noNetwork.calls, 0);
    }),
  );

  testWidgets(
    'local poster obeys global fit and privacy in the actual downloaded player',
    (tester) => host(tester, () async {
      final privacy = CollectionCoverPrivacyController.instance;
      final previousPrivacy = privacy.state.value;
      final previousArtwork = privacy.localImagePath.value;
      final fit = CollectionCoverFitController.instance;
      await fit.ensureLoaded();
      final previousFit = fit.state.value;
      late String id, posterPath, replacementPath;
      Future<void> png(String path, Color color) async {
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder).drawColor(color, BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(16, 24);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(path).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
      }

      try {
        await tester.runAsync(() async {
          id = await seed(false);
          await VideoDownloadedDetails.saveSession(
            source,
            NativePlaybackSession(
              title: 'Protected local work',
              watchUrl: watch,
              sources: const [],
              description: 'Offline basic description',
              tags: const ['Local tag'],
            ),
          );
          final row = Map<String, dynamic>.from(
            (await VideoLocalResources.read()).single,
          )..remove('cover');
          await VideoDownloadedDetails.retainForResource(
            row,
            waitForPoster: true,
          );
          final saved =
              jsonDecode(
                    (await SharedPreferences.getInstance()).getString(
                      VideoDownloadedDetails.durableStorageKey,
                    )!,
                  )
                  as Map;
          final work = (saved['works'] as Map).keys.single;
          final directory = Directory(
            '${await getFilePath()}/video-download-covers',
          );
          await directory.create(recursive: true);
          posterPath = '${directory.path}/$work.png';
          replacementPath = '${directory.parent.path}/privacy-blue.png';
          await png(posterPath, const Color(0xffff0000));
          await png(replacementPath, const Color(0xff0000ff));
        });
        fit.state.value = BoxFit.contain;
        privacy.state.value = const CollectionCoverPrivacySettings(
          ready: true,
          enabled: true,
          style: CollectionCoverStyle.custom,
        );
        privacy.localImagePath.value = replacementPath;
        await tester.pumpWidget(
          MaterialApp(home: _DownloadsOrigin(resourceId: id)),
        );
        await tester.tap(find.text('Open download'));
        await _until(tester, () => platform.plays > 0);
        final cover = find.byKey(const ValueKey('downloaded-video.cover'));
        await _until(tester, () {
          final images = find
              .descendant(of: cover, matching: find.byType(RawImage))
              .evaluate();
          return images.length >= 3 &&
              images.every((e) => (e.widget as RawImage).image != null);
        });
        expect(tester.getSize(cover), const Size(80, 120));
        expect(
          find.descendant(
            of: cover,
            matching: find.byType(CollectionCoverPrivacy),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: cover, matching: find.byType(VideoCoverOverlay)),
          findsOneWidget,
        );
        final background = tester.widget<SoftCoverBackground>(
          find.descendant(
            of: cover,
            matching: find.byType(SoftCoverBackground),
          ),
        );
        expect(background.enabled, isTrue);
        final sized = background.image as ResizeImage;
        expect((sized.imageProvider as FileImage).file.path, posterPath);
        expect(sized.width, lessThanOrEqualTo(512));
        expect(sized.height, lessThanOrEqualTo(512));
        expect(
          CollectionCoverPrivacyScope.contains(
            tester.element(
              find.descendant(
                of: cover,
                matching: find.byType(CollectionCoverPrivacy),
              ),
            ),
          ),
          isTrue,
        );
        // Same real RepaintBoundary raster capture as the shared privacy tests.
        Future<List<int>> centerPixel() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(cover);
          return (await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            final at =
                ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;
            final pixel = bytes!.buffer.asUint8List().sublist(at, at + 4);
            image.dispose();
            return pixel;
          }))!;
        }

        final protected = await centerPixel();
        expect(protected[2], greaterThan(220));
        expect(protected[0], lessThan(30));
        privacy.state.value = privacy.state.value.copyWith(enabled: false);
        await tester.pump();
        final unprotected = await centerPixel();
        expect(unprotected[0], greaterThan(220));
        expect(unprotected[2], lessThan(30));
        expect(noNetwork.calls, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        privacy.state.value = previousPrivacy;
        privacy.localImagePath.value = previousArtwork;
        fit.state.value = previousFit;
      }
    }),
  );

  testWidgets(
    'local HLS acquisition failure exposes local retry without website or network fallback',
    (tester) => host(tester, () async {
      late String id;
      await tester.runAsync(() async {
        id = await seed(true);
      });
      failAcquire = true;
      await tester.pumpWidget(
        MaterialApp(home: _DownloadsOrigin(resourceId: id)),
      );
      await tester.tap(find.text('Open download'));
      await _until(
        tester,
        () => find.text(t.common.retry).evaluate().isNotEmpty,
      );
      expect(find.byType(NativeVideoPage), findsOneWidget);
      expect(find.text(t.videoPlayback.backToWeb), findsNothing);
      expect(find.text(t.videoPlayback.openWebsitePlayer), findsNothing);
      expect(platform.sources, isEmpty);
      expect(noNetwork.calls, 0);
      await tester.tap(find.text(t.common.retry).first);
      await _until(
        tester,
        () =>
            nativeCalls.where((c) => c.method == 'acquirePlayback').length >= 2,
      );
      expect(noNetwork.calls, 0);
      expect(platform.sources, isEmpty);
      expect(nativeCalls.any((c) => c.method == 'openOffline'), isFalse);
      expect(tester.takeException(), isNull);
    }),
  );
}
