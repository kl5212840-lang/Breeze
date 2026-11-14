import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:zephyr/page/video/native_video_page.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/api_video_detail_page.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_selection_panel.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/page/video/omofun_discussion_panel.dart';

class _PreparationPlayer extends VideoPlayerPlatform {
  final events = StreamController<VideoEvent>.broadcast();
  final seeks = <Duration>[];
  @override
  Future<void> init() async {}
  @override
  Future<void> setMixWithOthers(bool value) async {}
  @override
  Future<int?> create(DataSource source) async {
    Timer.run(() {
      if (!events.isClosed)
        events.add(
          VideoEvent(
            eventType: VideoEventType.initialized,
            duration: const Duration(minutes: 2),
            size: const Size(1920, 1080),
          ),
        );
    });
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int id) => events.stream;
  @override
  Widget buildView(int id) => const ColoredBox(color: Colors.black);
  @override
  Future<void> dispose(int id) async {
    await events.close();
  }

  @override
  Future<void> setLooping(int id, bool value) async {}
  @override
  Future<void> setVolume(int id, double value) async {}
  @override
  Future<void> setPlaybackSpeed(int id, double value) async {}
  @override
  Future<void> play(int id) async {}
  @override
  Future<void> pause(int id) async {}
  @override
  Future<void> seekTo(int id, Duration value) async => seeks.add(value);
  @override
  Future<Duration> getPosition(int id) async => Duration.zero;
}

class _PendingLibrary extends VideoLibraryStore {
  _PendingLibrary(this.snapshot);

  final Future<VideoLibrarySnapshot> snapshot;

  @override
  Future<VideoLibrarySnapshot> read() => snapshot;
}

void main() {
  final home = Uri.parse('https://www.omofuna.com/');
  final detail = home.resolve('anime/1234567890abcdef.html');
  Map<String, dynamic> item({bool episodes = true}) => {
    'id': '1234567890abcdef',
    'title': '资料先显示的作品',
    'detailUrl': '$detail',
    'description': '公开简介在媒体解析期间仍然可读。',
    'lines': [
      if (episodes)
        for (final (id, label) in [('1', '精品'), ('2', '天堂')])
          {
            'id': id,
            'label': label,
            'episodes': [
              {
                'id': '1',
                'title': '第01集',
                'resolveOnPlayback': true,
                'watchUrl': '$detail?line=$id&episode=1',
              },
            ],
          },
    ],
  };
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final exact in [true, false]) {
    testWidgets('download recovery waits for a choice (exact=$exact)', (
      tester,
    ) async {
      final data = item();
      final resume = detail.replace(
        queryParameters: {'line': '2', 'episode': exact ? '1' : '999'},
      );
      final playback = <Map<String, dynamic>>[];
      final repository = ApiVideoRepository(
        source: 'download-recovery-$exact',
        home: home,
        catalogFn: 'list',
        detailFn: 'item',
        playbackFn: 'play',
        pluginCall: (method, args) async {
          if (method == 'item') return {'data': data};
          playback.add(Map<String, dynamic>.from(args));
          throw StateError('Fixture leaves playback unresolved');
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ApiVideoDetailPage(
            repository: repository,
            initialItem: ApiVideoItem.fromJson(data, home: home),
            resume: resume,
            forDownloadRecovery: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('资料先显示的作品'), findsWidgets);
      expect(playback, isEmpty);
      expect(find.text(t.download.downloadRecoverySelect), findsOneWidget);
      expect(find.text(t.download.downloadDetailsSelectEpisode), findsNothing);
      final play = find.widgetWithText(TextButton, t.videoPlayback.play);
      expect(play, exact ? findsOneWidget : findsNothing);
    });
  }

  testWidgets(
    'local public metadata is a coherent fallback after a failed detail read',
    (tester) async {
      const source = 'download-preview-fixture';
      final summary = ApiVideoItem.fromJson(
        item(episodes: false)..remove('description'),
        home: home,
      );
      await VideoDownloadedDetails.saveItem(
        source,
        ApiVideoItem.fromJson(
          item()..['description'] = 'Previously saved public synopsis',
          home: home,
        ),
      );
      final detailResponse = Completer<Map<String, dynamic>>();
      final calls = <String>[];
      final repository = ApiVideoRepository(
        source: source,
        home: home,
        catalogFn: 'list',
        detailFn: 'item',
        playbackFn: 'play',
        pluginCall: (method, args) {
          calls.add(method);
          return detailResponse.future;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ApiVideoDetailPage(
            repository: repository,
            initialItem: summary,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(calls, ['item']);
      expect(find.text('Previously saved public synopsis'), findsNothing);
      expect(
        find.byKey(const ValueKey('api-detail.initial-loading')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('api-detail.actions')), findsNothing);
      expect(find.text('第01集'), findsNothing);
      detailResponse.completeError(StateError('detail unavailable'));
      await tester.pumpAndSettle();
      expect(find.text('Previously saved public synopsis'), findsOneWidget);
      expect(find.byKey(const ValueKey('api-detail.actions')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('api-detail.action-host.download')),
        findsNothing,
      );
      expect(calls, ['item']);
    },
  );

  testWidgets(
    'first detail body and actions commit together while media is still pending',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final previousPlayer = VideoPlayerPlatform.instance;
      VideoPlayerPlatform.instance = _PreparationPlayer();
      addTearDown(() => VideoPlayerPlatform.instance = previousPlayer);
      const source = 'detail-first-commit-fixture';
      final response = Completer<Map<String, dynamic>>();
      final local = Completer<VideoLibrarySnapshot>();
      final media = Completer<Map<String, dynamic>>();
      final store = _PendingLibrary(local.future);
      final calls = <String>[];
      final data = item()..['vodId'] = '42';
      final summary = ApiVideoItem.fromJson(item(episodes: false), home: home);
      final siteRequests = <String>[];
      final client = OmoSiteClient(
        home: home,
        request: (operation, _) async {
          siteRequests.add(operation);
          throw StateError('Unexpected operation');
        },
      );
      addTearDown(client.dispose);
      final repository = ApiVideoRepository(
        source: source,
        home: home,
        catalogFn: 'list',
        detailFn: 'item',
        playbackFn: 'play',
        pluginCall: (method, args) {
          calls.add(method);
          return method == 'item' ? response.future : media.future;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ApiVideoDetailPage(
            repository: repository,
            initialItem: summary,
            store: store,
            siteClient: client,
          ),
        ),
      );
      final loading = find.byKey(const ValueKey('api-detail.initial-loading'));
      final actions = find.byKey(const ValueKey('api-detail.actions'));
      final heading = find.text(summary.title);
      expect(loading, findsOneWidget);
      expect(heading, findsNothing);
      expect(actions, findsNothing);
      response.complete({'data': data});
      await tester.pump();
      expect(heading, findsNothing);
      expect(actions, findsNothing);
      local.complete(VideoLibrarySnapshot());
      await tester.pump(const Duration(milliseconds: 100));
      expect(loading, findsNothing);
      expect(heading, findsOneWidget);
      expect(actions, findsOneWidget);
      expect(
        find.byKey(const ValueKey('api-detail.action-host.download')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('api-detail.site-follow')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('api-detail.follow')), findsNothing);
      expect(siteRequests, isEmpty);
      expect(find.byType(NativeVideoPage), findsNothing);
      expect(calls, ['item', 'play']);
      final firstActionsRect = tester.getRect(actions);
      media.complete({
        'data': {
          'item': {...data, 'title': 'Transport metadata title'},
          'lineId': '1',
          'episodeId': '1',
          'watchUrl': '$detail?line=1&episode=1',
          'sources': [
            {'url': 'https://fixture.test/first-commit.mp4', 'quality': 'A'},
          ],
        },
      });
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(NativeVideoPage), findsOneWidget);
      expect(heading, findsWidgets);
      expect(
        find.byKey(const ValueKey('api-detail.site-follow')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('api-detail.follow')), findsNothing);
      expect(siteRequests, isEmpty);
      expect(tester.getRect(actions), firstActionsRect);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  Future<List<String>> mountSections(
    WidgetTester tester, {
    bool reduced = false,
    TextDirection direction = TextDirection.ltr,
    bool related = false,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final data = item()..['vodId'] = '42';
    data['description'] = List.filled(30, '公开简介用于检查切换后的阅读位置。').join('\n');
    if (related) {
      data['related'] = [
        for (var index = 1; index <= 8; index++)
          {
            'id': index.toString().padLeft(16, '0'),
            'title': '推荐作品$index',
            'detailUrl':
                '${home}anime/${index.toString().padLeft(16, '0')}.html',
          },
      ];
    }
    final operations = <String>[];
    final client = OmoSiteClient(
      home: home,
      request: (operation, _) async {
        operations.add(operation);
        if (operation == 'account') {
          return {
            'kind': 'account',
            'account': {'id': 'fixture', 'name': 'Fixture'},
          };
        }
        if (operation == 'favoriteState') {
          return {'kind': 'favoriteState', 'favorite': false};
        }
        if (operation == 'comments') {
          return {
            'kind': 'comments',
            'hasMore': false,
            'items': [
              for (var index = 0; index < 24; index++)
                {
                  'id': '$index',
                  'author': '评论人',
                  'text': '评论正文 $index',
                  'createdAt': '2026-11-02 12:00',
                  'likes': 0,
                },
            ],
          };
        }
        throw StateError('Unexpected section fixture operation $operation');
      },
    );
    addTearDown(client.dispose);
    final repository = ApiVideoRepository(
      source: 'detail-sections-$direction-$reduced-$related',
      home: home,
      catalogFn: 'list',
      detailFn: 'item',
      playbackFn: 'play',
      pluginCall: (_, _) async => {'data': data},
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: Directionality(textDirection: direction, child: child!),
        ),
        home: ApiVideoDetailPage(
          repository: repository,
          initialItem: ApiVideoItem.fromJson(data, home: home),
          siteClient: client,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return operations;
  }

  PageController sectionPages(WidgetTester tester) => tester
      .widget<PageView>(find.byKey(const ValueKey('api-detail.section-pages')))
      .controller!;

  testWidgets(
    'a rapid click back before the page midpoint replaces the previous animation target',
    (tester) async {
      await mountSections(tester);
      final comments = find.byKey(const ValueKey('api-detail.comments'));
      final description = find.byKey(const ValueKey('api-detail.description'));
      await tester.tap(comments);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(sectionPages(tester).page, allOf(greaterThan(0), lessThan(.5)));
      await tester.tap(description);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(sectionPages(tester).page, closeTo(0, .001));
      final descriptionSelection = find.ancestor(
        of: description,
        matching: find.byType(Semantics),
      );
      expect(
        descriptionSelection.evaluate().any(
          (element) =>
              (element.widget as Semantics).properties.selected == true,
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'detail swipe shows drag progress, cancel returns, and lazy comments keep their reading position',
    (tester) async {
      final operations = await mountSections(tester);
      expect(
        operations.where((operation) => operation == 'discussions'),
        isEmpty,
      );
      final surface = find.byKey(const ValueKey('api-detail.section-swipe'));
      final rect = tester.getRect(surface);
      final gesture = await tester.startGesture(
        rect.center + const Offset(100, 0),
      );
      await gesture.moveBy(const Offset(-105, 0));
      await tester.pump();
      expect(sectionPages(tester).page, allOf(greaterThan(0), lessThan(1)));
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(sectionPages(tester).page, closeTo(0, .001));
      await tester.tap(find.byKey(const ValueKey('api-detail.comments')));
      await tester.pumpAndSettle();
      expect(sectionPages(tester).page, closeTo(1, .001));
      expect(
        operations.where((operation) => operation == 'comments'),
        hasLength(1),
      );
      final comments = find.descendant(
        of: find.byType(OmoDiscussionPanel),
        matching: find.byType(ListView),
      );
      final position = tester.widget<ListView>(comments).controller!;
      await tester.drag(comments, const Offset(0, -180));
      await tester.pumpAndSettle();
      final before = position.offset;
      expect(before, greaterThan(0));
      expect(
        sectionPages(tester).page,
        closeTo(1, .001),
        reason: 'Vertical comment scrolling must not select another section',
      );
      await tester.tap(find.byKey(const ValueKey('api-detail.description')));
      await tester.pumpAndSettle();
      expect(sectionPages(tester).page, closeTo(0, .001));
      await tester.tap(find.byKey(const ValueKey('api-detail.comments')));
      await tester.pumpAndSettle();
      expect(position.offset, closeTo(before, .1));
      expect(
        operations.where((operation) => operation == 'comments'),
        hasLength(1),
      );
      expect(
        operations.where(
          (operation) =>
              operation.startsWith('favoriteA') ||
              operation.startsWith('favoriteR'),
        ),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final direction in TextDirection.values) {
    testWidgets(
      'swipe and click agree with reduced motion in $direction and do not use route edges',
      (tester) async {
        await mountSections(tester, reduced: true, direction: direction);
        final rect = tester.getRect(
          find.byKey(const ValueKey('api-detail.section-swipe')),
        );
        final dx = direction == TextDirection.ltr ? -220.0 : 220.0;
        await tester.dragFrom(
          Offset(
            direction == TextDirection.ltr ? rect.right - 40 : rect.left + 40,
            rect.center.dy,
          ),
          Offset(dx, 0),
        );
        await tester.pumpAndSettle();
        expect(sectionPages(tester).page, closeTo(1, .001));
        await tester.dragFrom(
          Offset(
            direction == TextDirection.ltr ? rect.left + 4 : rect.right - 4,
            rect.center.dy,
          ),
          Offset(-dx, 0),
        );
        await tester.pumpAndSettle();
        expect(sectionPages(tester).page, closeTo(1, .001));
        await tester.tap(find.byKey(const ValueKey('api-detail.description')));
        await tester.pump();
        expect(sectionPages(tester).page, closeTo(0, .001));
        final small = await tester.startGesture(rect.center);
        await small.moveBy(const Offset(6, 0));
        await small.up();
        await tester.pumpAndSettle();
        expect(sectionPages(tester).page, closeTo(0, .001));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'player area and nested related-work scroller do not change the description section',
    (tester) async {
      await mountSections(tester, related: true);
      await tester.dragFrom(const Offset(290, 110), const Offset(-220, 0));
      await tester.pumpAndSettle();
      expect(sectionPages(tester).page, closeTo(0, .001));
      final related = find.text(t.videoPlayback.related);
      await tester.ensureVisible(related);
      await tester.pumpAndSettle();
      final horizontal = find.byWidgetPredicate(
        (widget) =>
            widget is ListView && widget.scrollDirection == Axis.horizontal,
      );
      await tester.drag(horizontal, const Offset(-220, 0));
      await tester.pumpAndSettle();
      expect(sectionPages(tester).page, closeTo(0, .001));
      expect(tester.takeException(), isNull);
    },
  );

  for (final (valid, fallback, label) in [
    (true, false, 'resolves the exact episode'),
    (false, false, 'never substitutes another episode'),
    (true, true, 'keeps resume progress when the same episode changes line'),
  ]) {
    testWidgets('explicit site history $label', (tester) async {
      final platform = _PreparationPlayer(),
          previous = VideoPlayerPlatform.instance;
      VideoPlayerPlatform.instance = platform;
      final plays = <Map<String, dynamic>>[];
      final data = item();
      final target = detail.replace(
        queryParameters: {'line': '2', 'episode': valid ? '1' : '999'},
      );
      final source = 'history-exact-$valid-$fallback';
      if (fallback) {
        await VideoWatchHistory.record(
          source,
          VideoWatchRecord(
            watchUrl: target,
            title: '资料先显示的作品',
            position: const Duration(seconds: 31),
            duration: const Duration(minutes: 2),
            updatedAt: DateTime.utc(2026, 11, 10),
            completed: false,
          ),
        );
      }
      final repo = ApiVideoRepository(
        source: source,
        home: home,
        catalogFn: 'list',
        detailFn: 'item',
        playbackFn: 'play',
        pluginCall: (path, args) async {
          if (path == 'item') return {'data': data};
          plays.add(Map<String, dynamic>.from(args));
          if (fallback && args['lineId'] == '2') {
            throw StateError('Original line is temporarily unavailable');
          }
          return {
            'data': {
              'item': data,
              'lineId': args['lineId'],
              'episodeId': args['episodeId'],
              'watchUrl':
                  '$detail?line=${args['lineId']}&episode=${args['episodeId']}',
              'sources': [
                {'url': 'https://fixture.test/history.mp4', 'quality': 'A'},
              ],
            },
          };
        },
      );
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: ApiVideoDetailPage(
              repository: repo,
              initialItem: ApiVideoItem.fromJson(data, home: home),
              resume: target,
              requireExactResume: true,
            ),
          ),
        );
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          plays.map((args) => args['lineId']),
          fallback
              ? ['2', '1']
              : valid
              ? ['2']
              : isEmpty,
        );
        if (valid) {
          expect(plays.map((args) => args['episodeId']), everyElement('1'));
          if (fallback) expect(platform.seeks, [const Duration(seconds: 31)]);
          expect(
            tester
                .widget<NativeVideoPage>(find.byType(NativeVideoPage))
                .session
                .watchUrl,
            fallback
                ? target.replace(queryParameters: {'line': '1', 'episode': '1'})
                : target,
          );
        } else {
          expect(find.byType(NativeVideoPage), findsNothing);
          expect(
            find.text('The episode for this record is unavailable.'),
            findsOneWidget,
          );
          final description = find.text('公开简介在媒体解析期间仍然可读。');
          final details = find.byKey(
            const PageStorageKey('api-detail.1234567890abcdef'),
          );
          await tester.scrollUntilVisible(
            description,
            120,
            scrollable: find
                .descendant(of: details, matching: find.byType(Scrollable))
                .first,
          );
          await tester.ensureVisible(description);
          await tester.pumpAndSettle();
          expect(description.hitTestable(), findsOneWidget);
          expect(
            plays,
            isEmpty,
            reason:
                'Reading retained metadata must not resolve another episode',
          );
        }
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        VideoPlayerPlatform.instance = previous;
      }
    });
  }

  testWidgets(
    'initial resolver surface toggles chrome without blocking actions and hands visibility to the player',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final platform = _PreparationPlayer(),
          previous = VideoPlayerPlatform.instance;
      VideoPlayerPlatform.instance = platform;
      final media = Completer<Map<String, dynamic>>();
      final requests = <Map<String, dynamic>>[];
      final repo = ApiVideoRepository(
        source: 'initial-controls',
        home: home,
        catalogFn: 'list',
        detailFn: 'item',
        playbackFn: 'play',
        capabilities: const ApiVideoCapabilities(rawHlsRecovery: true),
        pluginCall: (path, args) async {
          if (path == 'item') return {'data': item()};
          requests.add(Map.of(args));
          return media.future;
        },
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (_) async => null,
      );
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: ApiVideoDetailPage(
              repository: repo,
              initialItem: ApiVideoItem.fromJson(item(), home: home),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final surface = find.byKey(
          const ValueKey('api-initial.gesture-surface'),
        );
        final point = tester.getRect(surface).topLeft + const Offset(130, 20);
        expect(
          find.byKey(const ValueKey('api-initial.cancel')).hitTestable(),
          findsOneWidget,
        );
        await tester.tapAt(point);
        await tester.pump(const Duration(milliseconds: 180));
        expect(find.byKey(const ValueKey('api-initial.cancel')), findsNothing);
        expect(
          find.byKey(const ValueKey('api-initial.back')).hitTestable(),
          findsNothing,
        );
        await tester.tapAt(point);
        await tester.pump(const Duration(milliseconds: 180));
        expect(
          find.byKey(const ValueKey('api-initial.cancel')).hitTestable(),
          findsOneWidget,
        );
        await tester.tapAt(point);
        await tester.pump(const Duration(milliseconds: 180));
        media.complete({
          'data': {
            'item': item(),
            'lineId': '1',
            'episodeId': '1',
            'watchUrl': '$detail?line=1&episode=1',
            'sources': [
              {'url': 'https://fixture.test/video.mp4', 'quality': 'A'},
            ],
          },
        });
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        final player = tester.widget<NativeVideoPage>(
          find.byType(NativeVideoPage),
        );
        expect(requests, hasLength(1));
        expect(requests.single.containsKey('rawHlsRecovery'), isFalse);
        expect(player.recoverCurrentResource, isNotNull);
        await player.recoverCurrentResource!(player.session);
        expect(requests, hasLength(2));
        expect(requests.last['rawHlsRecovery'], isTrue);
        expect(requests.last['refresh'], isTrue);
        expect(requests.last['lineId'], '1');
        expect(requests.last['episodeId'], '1');
        await player.refreshSession!();
        expect(requests, hasLength(3));
        expect(requests.last.containsKey('rawHlsRecovery'), isFalse);
        expect(requests.last['refresh'], isTrue);
        expect(player.initialControlsVisible, isFalse);
        expect(find.text('公开简介在媒体解析期间仍然可读。'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        if (!media.isCompleted)
          media.completeError(StateError('test cancelled'));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {});
        await tester.pump();
        VideoPlayerPlatform.instance = previous;
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      }
    },
  );

  testWidgets(
    'media wait and failure retain readable metadata and line choices',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final media = Completer<Map<String, dynamic>>();
      final requests = <String>[];
      final repo = ApiVideoRepository(
        source: 'detail-read',
        home: home,
        catalogFn: 'list',
        detailFn: 'item',
        playbackFn: 'play',
        pluginCall: (path, args) async {
          if (path == 'item') return {'data': item()};
          requests.add('${args['lineId']}');
          return media.future;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ApiVideoDetailPage(
            repository: repo,
            initialItem: ApiVideoItem.fromJson(item(), home: home),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('公开简介在媒体解析期间仍然可读。'), findsOneWidget);
      expect(find.byKey(const ValueKey('api-initial.lines')), findsOneWidget);
      media.completeError(StateError('Source parser unavailable'));
      await tester.pumpAndSettle();
      expect(find.text('公开简介在媒体解析期间仍然可读。'), findsOneWidget);
      expect(find.text(t.common.retry), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('api-initial.lines')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(VideoSelectionPanel),
          matching: find.text('天堂'),
        ),
        findsOneWidget,
      );
      expect(requests, ['1', '2']);
      expect(tester.takeException(), isNull);
    },
  );

  for (final picker in ['lines', 'episodes']) {
    testWidgets(
      'opening $picker preserves automatic recovery and dismiss is inert',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final first = Completer<Map<String, dynamic>>();
        final requests = <String>[];
        final repo = ApiVideoRepository(
          source: 'picker-$picker',
          home: home,
          catalogFn: 'list',
          detailFn: 'item',
          playbackFn: 'play',
          pluginCall: (path, args) async {
            if (path == 'item') return {'data': item()};
            requests.add('${args['lineId']}');
            if (requests.length == 1) return first.future;
            throw StateError('fixture parser failure');
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            home: ApiVideoDetailPage(
              repository: repo,
              initialItem: ApiVideoItem.fromJson(item(), home: home),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(requests, ['1']);
        await tester.tap(find.byKey(ValueKey('api-initial.$picker')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(VideoSelectionPanel), findsOneWidget);
        first.completeError(StateError('first parser failure'));
        await tester.pumpAndSettle();
        expect(requests, ['1', '2']);
        expect(find.text(t.videoSource.lineCancelled), findsNothing);
        await tester.tap(find.byTooltip(t.common.close));
        await tester.pumpAndSettle();
        expect(requests, ['1', '2']);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'pre-player long episode picker stays bounded and scrolls to the last episode',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = item();
      final lines = data['lines'] as List;
      lines.removeLast();
      lines.first['episodes'] = [
        for (var n = 1; n <= 187; n++)
          {
            'id': '$n',
            'title': '第$n集',
            'resolveOnPlayback': true,
            'watchUrl': '$detail?line=1&episode=$n',
          },
      ];
      final repo = ApiVideoRepository(
        source: 'long-picker',
        home: home,
        catalogFn: 'list',
        detailFn: 'item',
        playbackFn: 'play',
        pluginCall: (path, args) async {
          if (path == 'item') return {'data': data};
          throw StateError('fixture parser failure');
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ApiVideoDetailPage(
            repository: repo,
            initialItem: ApiVideoItem.fromJson(data, home: home),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final video = tester.getRect(
        find.byKey(const ValueKey('api-initial.gesture-surface')),
      );
      await tester.tap(find.byKey(const ValueKey('api-initial.episodes')));
      await tester.pumpAndSettle();
      final panel = tester.getRect(find.byType(VideoSelectionPanel));
      expect(panel.top, greaterThanOrEqualTo(video.bottom));
      expect(panel.bottom, lessThanOrEqualTo(844));
      expect(find.text(t.videoPlayback.episodeAscending), findsOneWidget);
      final finalRange = find.widgetWithText(ChoiceChip, '151-187');
      await tester.ensureVisible(finalRange);
      await tester.tap(finalRange);
      await tester.pumpAndSettle();
      final last = find.byKey(
        ValueKey('episode-queue.$detail?line=1&episode=187'),
      );
      final scrollable = find
          .descendant(
            of: find.byType(VideoSelectionPanel),
            matching: find.byType(Scrollable),
          )
          .last;
      expect(tester.getSize(scrollable).height, greaterThanOrEqualTo(44));
      await tester.scrollUntilVisible(
        last,
        1000,
        maxScrolls: 30,
        scrollable: scrollable,
      );
      await tester.ensureVisible(last);
      await tester.pumpAndSettle();
      expect(last.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final cancel in ['tap', 'background']) {
    testWidgets(
      'initial resolution $cancel ignores late results and does not start another line',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final pending = Completer<Map<String, dynamic>>();
        final requests = <String>[];
        final repo = ApiVideoRepository(
          source: 'initial-cancel-$cancel',
          home: home,
          catalogFn: 'list',
          detailFn: 'item',
          playbackFn: 'play',
          pluginCall: (path, args) async {
            if (path == 'item') return {'data': item()};
            requests.add('${args['lineId']}');
            return pending.future;
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            home: ApiVideoDetailPage(
              repository: repo,
              initialItem: ApiVideoItem.fromJson(item(), home: home),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        if (cancel == 'tap') {
          await tester.tap(find.byKey(const ValueKey('api-initial.cancel')));
        } else {
          for (final state in [
            AppLifecycleState.inactive,
            AppLifecycleState.hidden,
            AppLifecycleState.paused,
            AppLifecycleState.hidden,
            AppLifecycleState.inactive,
            AppLifecycleState.resumed,
          ]) {
            tester.binding.handleAppLifecycleStateChanged(state);
          }
        }
        pending.completeError(StateError('late result'));
        await tester.pumpAndSettle();
        expect(requests, ['1']);
        expect(find.text(t.videoSource.lineCancelled), findsOneWidget);
        expect(find.byKey(const ValueKey('api-initial.cancel')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a work with no playable episodes still shows its details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var mediaRequests = 0;
    final data = item(episodes: false);
    final repo = ApiVideoRepository(
      source: 'detail-no-episodes',
      home: home,
      catalogFn: 'list',
      detailFn: 'item',
      playbackFn: 'play',
      pluginCall: (path, args) async {
        if (path == 'play') mediaRequests++;
        return {'data': data};
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ApiVideoDetailPage(
          repository: repo,
          initialItem: ApiVideoItem.fromJson(data, home: home),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('公开简介在媒体解析期间仍然可读。'), findsOneWidget);
    expect(mediaRequests, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'initial failure visits every dynamic same-episode line once without a raw preflight',
    (tester) async {
      final data = item();
      data['lines'] = [
        for (var i = 1; i <= 5; i++)
          {
            'id': '$i',
            'label': '来源 $i',
            'episodes': [
              {
                'id': '1',
                'title': '第01集',
                'resolveOnPlayback': true,
                'watchUrl': '$detail?line=$i&episode=1',
              },
            ],
          },
      ];
      final requests = <String>[];
      final rawRequests = <bool>[];
      final repo = ApiVideoRepository(
        source: 'dynamic-five-lines',
        home: home,
        catalogFn: 'list',
        detailFn: 'item',
        playbackFn: 'play',
        capabilities: const ApiVideoCapabilities(rawHlsRecovery: true),
        pluginCall: (path, args) async {
          if (path == 'item') return {'data': data};
          requests.add('${args['lineId']}');
          rawRequests.add(args['rawHlsRecovery'] == true);
          throw StateError('read-only parser attempt failed');
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ApiVideoDetailPage(
            repository: repo,
            initialItem: ApiVideoItem.fromJson(data, home: home),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests, ['1', '2', '3', '4', '5']);
      expect(rawRequests, everyElement(isFalse));
      expect(find.text(t.videoPlayback.playFailed), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 1.7]) {
    testWidgets(
      'playback tools precede stable equal actions at text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final data = item()..['vodId'] = '42';
        final client = OmoSiteClient(
          home: home,
          request: (operation, args) async => operation == 'account'
              ? {
                  'kind': 'account',
                  'account': {'id': 'qa', 'name': '测试账户'},
                }
              : {'kind': 'favoriteState', 'favorite': false},
        );
        addTearDown(client.dispose);
        final repo = ApiVideoRepository(
          source: 'detail-action-layout-$scale',
          home: home,
          catalogFn: 'list',
          detailFn: 'item',
          playbackFn: 'play',
          pluginCall: (path, args) async {
            if (path == 'item') return {'data': data};
            throw StateError('No media in this layout-only fixture');
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: ApiVideoDetailPage(
              repository: repo,
              initialItem: ApiVideoItem.fromJson(data, home: home),
              siteClient: client,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.text(t.videoPlayback.playFailed)).dy,
          greaterThanOrEqualTo(
            tester
                .getBottomRight(find.byKey(const ValueKey('api-initial.back')))
                .dy,
          ),
        );
        final tools = find.byKey(const ValueKey('api-detail.playback-tools'));
        final actions = find.byKey(const ValueKey('api-detail.actions'));
        await tester.ensureVisible(actions);
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(tools).dy,
          lessThan(tester.getTopLeft(actions).dy),
        );
        final local = tester.getSize(
          find.byKey(const ValueKey('api-detail.favorite')),
        );
        expect(
          find.byKey(const ValueKey('api-detail.site-follow')),
          findsNothing,
        );
        final share = tester.getSize(
          find.byKey(const ValueKey('api-detail.share')),
        );
        expect(local.width, closeTo(share.width, .01));
        expect(local.height, greaterThanOrEqualTo(44));
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('pre-player resolution failure exposes safe copyable diagnostics', (
    tester,
  ) async {
    String? copied;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final data = item();
    final repo = ApiVideoRepository(
      source: 'resolution-diagnostics-fixture',
      home: home,
      catalogFn: 'list',
      detailFn: 'item',
      playbackFn: 'play',
      pluginCall: (path, args) async {
        if (path == 'item') return {'data': data};
        Error.throwWithStackTrace(
          StateError(
            'ReferenceError: fetchBridge is not defined; HTTP 403 https://cdn.example/video.m3u8?token=hidden',
          ),
          StackTrace.fromString('at resolveMedia (bundle.js:42:8)'),
        );
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ApiVideoDetailPage(
          repository: repo,
          initialItem: ApiVideoItem.fromJson(data, home: home),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('api-initial.analysis')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.videoPlayback.copyDiagnostic));
    await tester.pumpAndSettle();
    expect(copied, contains('Breeze playback log v1'));
    expect(copied, contains('resource_lines: 2'));
    expect(copied, contains('http_403'));
    expect(copied, contains('ReferenceError: fetchBridge is not defined'));
    expect(copied, contains('bundle.js:42:8'));
    expect(copied, contains('network_session'));
    expect(copied, contains('plugin_call'));
    expect(copied, isNot(contains('video.m3u8')));
    expect(copied, isNot(contains('hidden')));
    expect(tester.takeException(), isNull);
  });
  for (final result in ['shared', 'cancelled', 'failed', 'unavailable']) {
    testWidgets(
      'share $result uses native sheet and quiet short-lived feedback',
      (tester) async {
        final data = item(episodes: false);
        const channel = MethodChannel('breeze.video.share');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        MethodCall? received;
        messenger.setMockMethodCallHandler(channel, (call) async {
          received = call;
          return result;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final repo = ApiVideoRepository(
          source: 'share-action-$result',
          home: home,
          catalogFn: 'list',
          detailFn: 'item',
          playbackFn: 'play',
          pluginCall: (_, _) async => {'data': data},
        );
        await tester.pumpWidget(
          MaterialApp(
            home: ApiVideoDetailPage(
              repository: repo,
              initialItem: ApiVideoItem.fromJson(data, home: home),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // Only the share invocation uses the iOS channel. Rendering remains the
        // documented Material test fallback, without creating platform views.
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        try {
          await tester.tap(find.byKey(const ValueKey('api-detail.share')));
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
        await tester.pumpAndSettle();
        expect(received?.arguments['url'], detail.toString());
        expect(find.byType(SnackBar), findsNothing);
        final failed = result == 'failed' || result == 'unavailable';
        expect(
          find.byType(VideoActionNotice),
          failed ? findsOneWidget : findsNothing,
        );
        if (failed) {
          expect(find.text(t.videoCommunity.shareFailed), findsOneWidget);
          expect(find.text(t.videoCommunity.shareUnavailable), findsNothing);
          await tester.pump(const Duration(seconds: 3));
          await tester.pumpAndSettle();
          expect(find.byType(VideoActionNotice), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
