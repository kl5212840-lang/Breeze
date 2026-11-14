import 'package:zephyr/page/video/video_thumbnail.dart';
import 'package:zephyr/page/video/video_episode_sequence.dart';
import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart' show VideoPlayerController;
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/native_material_surface.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/native_video_page.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/video_playback_preferences.dart';
import 'package:zephyr/page/video/video_playback_quick_panel.dart';
import 'package:zephyr/page/video/video_playback_settings_page.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/page/video/video_site_access.dart';
import 'package:zephyr/page/video/video_site_operations.dart';
import 'package:zephyr/page/video/video_download_sheet.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';

class _FakeVideoPlatform extends VideoPlayerPlatform {
  final _events = <int, StreamController<VideoEvent>>{};
  final seekTargets = <Duration>[];
  final speeds = <double>[];
  final urls = <String>[];
  final volumes = <double>[];
  int _nextId = 0;
  int playCount = 0;
  int pauseCount = 0;
  bool emitInitialized = true;
  bool stallSeek = false;
  bool failPause = false;
  String? failCommand;
  String? failMediaOnce;
  String? rejectPlayFor;
  String? stallPlayFor;
  Completer<void>? pendingPlay;
  final failedMedia = <String>{};
  final stalledMedia = <String>{};
  int maxNativePlayers = 0;
  Completer<void>? pendingSeek;
  Duration position = Duration.zero;

  @override
  Future<void> init() async {}
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<int?> create(DataSource dataSource) async {
    urls.add(dataSource.uri ?? '');
    final id = ++_nextId;
    final events = StreamController<VideoEvent>.broadcast();
    _events[id] = events;
    if (_events.length > maxNativePlayers) maxNativePlayers = _events.length;
    Timer.run(() {
      if ((dataSource.uri == failMediaOnce ||
              failedMedia.contains(dataSource.uri)) &&
          !events.isClosed) {
        failMediaOnce = null;
        events.addError(
          PlatformException(
            code: 'VideoError',
            message: 'Synthetic media initialization failure',
          ),
        );
        return;
      }
      if (emitInitialized &&
          !stalledMedia.contains(dataSource.uri) &&
          !events.isClosed) {
        events.add(
          VideoEvent(
            eventType: VideoEventType.initialized,
            duration: const Duration(minutes: 2),
            size: const Size(1920, 1080),
          ),
        );
      }
    });
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;

  @override
  Widget buildView(int playerId) => const ColoredBox(color: Colors.black);

  @override
  Future<void> dispose(int playerId) async => _events.remove(playerId)?.close();

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {
    if (failCommand == 'volume') {
      throw PlatformException(code: 'VolumeUnavailable');
    }
    volumes.add(volume);
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {
    if (failCommand == 'speed') {
      throw PlatformException(code: 'SpeedUnavailable');
    }
    speeds.add(speed);
  }

  @override
  Future<void> play(int playerId) async {
    playCount++;
    final media = urls[playerId - 1];
    if (media == rejectPlayFor)
      throw PlatformException(code: 'PlayUnavailable');
    if (media == stallPlayFor) await (pendingPlay ??= Completer<void>()).future;
    _events[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: true,
      ),
    );
  }

  @override
  Future<void> pause(int playerId) async {
    if (failPause || failCommand == 'pause') {
      throw PlatformException(code: 'PauseUnavailable');
    }
    pauseCount++;
    _events[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: false,
      ),
    );
  }

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    if (failCommand == 'seek') throw PlatformException(code: 'SeekUnavailable');
    this.position = position;
    seekTargets.add(position);
    if (stallSeek) await (pendingSeek ??= Completer<void>()).future;
  }

  @override
  Future<Duration> getPosition(int playerId) async => position;

  void send(VideoEvent event) => _events[_nextId]!.add(event);

  void failCurrentSource() {
    _events[_nextId]!.addError(
      PlatformException(code: 'VideoError', message: 'Source expired'),
    );
  }
}

Future<void> _openQuick(WidgetTester tester) async {
  await tester.tap(find.byTooltip(t.videoPlayback.playbackSettings));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 240));
  expect(find.byType(VideoPlaybackQuickPanel), findsOneWidget);
}

Future<void> _closeQuick(WidgetTester tester) async {
  await tester.tap(find.byTooltip(t.common.close));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _chooseQuickSpeed(WidgetTester tester, String label) async {
  await _closeQuick(tester);
  final speed = find.byTooltip(t.videoPlayback.speed);
  await tester.ensureVisible(speed);
  await tester.tap(speed);
  await tester.pumpAndSettle();
  expect(
    tester
        .widget<VideoPlaybackQuickPanel>(find.byType(VideoPlaybackQuickPanel))
        .section,
    VideoQuickSection.speed,
  );
  final choice = find.widgetWithText(ListTile, label);
  await _panelVisible(tester, choice);
  expect(choice.hitTestable(), findsOneWidget);
  await tester.tap(choice);
  await tester.pumpAndSettle();
  expect(find.byType(VideoPlaybackQuickPanel), findsNothing);
  // Return to settings for the caller's remaining controls/lifetime checks.
  await _openQuick(tester);
}

void _expectDockedPanel(WidgetTester tester, Rect panel, Size viewport) {
  final portrait = viewport.width <= viewport.height;
  expect(panel.right, closeTo(viewport.width, .01));
  expect(panel.bottom, closeTo(viewport.height, .01));
  if (portrait) {
    expect(panel.left, closeTo(0, .01));
    expect(panel.top, greaterThanOrEqualTo(viewport.width * 9 / 16));
  } else {
    expect(panel.left, greaterThan(0));
    expect(panel.top, closeTo(0, .01));
  }
  final close = find
      .ancestor(
        of: find.byTooltip(t.common.close),
        matching: find.byType(IconButton),
      )
      .hitTestable();
  expect(close, findsOneWidget);
  final hit = tester.getRect(close);
  expect(hit.width, greaterThanOrEqualTo(44));
  expect(hit.height, greaterThanOrEqualTo(44));
  expect(hit.right, lessThanOrEqualTo(panel.right - (portrait ? 8 : 12)));
  expect(hit.top, greaterThanOrEqualTo(panel.top + 4));
}

Future<void> _panelVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    120,
    scrollable: find
        .descendant(
          of: find.byType(VideoPlaybackQuickPanel),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _quickSeek(WidgetTester tester, int seconds) async {
  // The existing player gesture owns short jumps; quick settings no longer
  // duplicates these transport buttons.
  final rect = tester.getRect(
    find.byKey(const ValueKey('video-gesture-surface')),
  );
  final point = Offset(
    rect.left + rect.width * (seconds > 0 ? .85 : .15),
    rect.center.dy,
  );
  await tester.tapAt(point);
  await tester.pump(const Duration(milliseconds: 40));
  await tester.tapAt(point);
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  late VideoPlayerPlatform originalPlatform;
  late _FakeVideoPlatform platform;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    SharedPreferences.setMockInitialValues({});
    originalPlatform = VideoPlayerPlatform.instance;
    platform = _FakeVideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    VideoPlayerPlatform.instance = originalPlatform;
  });

  testWidgets(
    'loading controls accept hide and show taps and preserve intent after initialization',
    (tester) async {
      await VideoPlaybackPreferences.save('controlsStyle', 'breeze');
      await VideoPlaybackPreferences.save('recordHistory', false);
      platform.emitInitialized = false;
      await tester.pumpWidget(
        MaterialApp(
          home: NativeVideoPage(
            session: NativePlaybackSession(
              title: 'Loading controls',
              watchUrl: Uri.parse('https://fixture.test/watch?v=1'),
              sources: [
                NativePlaybackSource(
                  url: Uri.parse('https://fixture.test/video.mp4'),
                  label: 'A',
                  headers: const {},
                ),
              ],
              description: '',
              tags: const [],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final settings = find.byTooltip(t.videoPlayback.playbackSettings);
      double opacity() => tester
          .widget<AnimatedOpacity>(
            find
                .ancestor(of: settings, matching: find.byType(AnimatedOpacity))
                .first,
          )
          .opacity;
      expect(opacity(), 1);
      expect(
        find.byTooltip(t.videoPlayback.portraitFullscreen),
        findsOneWidget,
      );
      expect(find.byTooltip(t.videoPlayback.fullscreen), findsOneWidget);
      expect(find.byTooltip(t.videoPlayback.play), findsNothing);
      final center = tester.getCenter(
        find.byKey(const ValueKey('video-gesture-surface')),
      );
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        opacity(),
        0,
        reason: 'Loading cannot override the explicit visibility choice.',
      );
      platform.send(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(minutes: 2),
          size: const Size(1920, 1080),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(opacity(), 0);
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 350));
      expect(opacity(), 1);
      await _openQuick(tester);
      await _closeQuick(tester);
      expect(opacity(), 1);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  for (final format in ['mp4', 'm3u8']) {
    testWidgets(
      'resolved $format gets only its supported download entry without a declared adapter',
      (tester) async {
        final session = NativePlaybackSession(
          title: 'Resolved download host',
          watchUrl: Uri.parse('https://site-fixture.test/watch?v=42'),
          sources: [
            NativePlaybackSource(
              url: Uri.parse('https://cdn-fixture.test/media.$format'),
              label: '720p',
              headers: const {},
            ),
          ],
          description: '',
          tags: const [],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: NativeVideoPage(
              session: session,
              downloadSourceDuration: (_) => '站点 2:03',
            ),
          ),
        );
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        final entry = find.byKey(const ValueKey('video-inline.download'));
        expect(entry, findsOneWidget);
        await tester.ensureVisible(entry);
        await tester.tap(entry);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final sheet = tester.widget<VideoDownloadSheet>(
          find.byType(VideoDownloadSheet),
        );
        expect(sheet.durationMs, 120000);
        expect(sheet.sourceDuration, '站点 2:03');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets(
    'hold speed shows a top hint, vibrates once and restores on release or background',
    (tester) async {
      final haptics = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
            return null;
          });
      final session = NativePlaybackSession(
        title: 'Hold speed',
        watchUrl: Uri.parse('https://example.test/watch'),
        sources: [
          NativePlaybackSource(
            url: Uri.parse('https://example.test/video.mp4'),
            label: 'auto',
            headers: const {},
          ),
        ],
        description: '',
        tags: const [],
      );
      await tester.pumpWidget(
        MaterialApp(home: NativeVideoPage(session: session)),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final surface = find.byKey(const ValueKey('video-gesture-surface'));
      final rect = tester.getRect(surface);
      final gesture = await tester.startGesture(rect.center);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 200));
      final hint = find.byKey(const ValueKey('video-hold-speed-hint'));
      expect(hint, findsOneWidget);
      expect(tester.getRect(hint).center.dy, lessThan(rect.center.dy));
      expect(platform.speeds.last, 2);
      expect(haptics, hasLength(1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(haptics, hasLength(1));
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(platform.speeds.last, 1);
      expect(hint, findsNothing);
      final again = await tester.startGesture(rect.center);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(haptics, hasLength(2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(hint, findsNothing);
      await again.up();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.tap(find.byTooltip(t.videoPlayback.play));
      await tester.pump();
      expect(platform.speeds.last, 1);
      final cancelled = await tester.startGesture(rect.center);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(platform.speeds.last, 2);
      await cancelled.cancel();
      await tester.pump();
      expect(platform.speeds.last, 1);
      expect(haptics, hasLength(3));
    },
  );

  testWidgets('quick settings host fits above a keyboard inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final session = NativePlaybackSession(
      title: 'Inset host',
      watchUrl: Uri.parse('https://example.test/watch'),
      sources: [
        NativePlaybackSource(
          url: Uri.parse('https://example.test/video.mp4'),
          label: 'auto',
          headers: const {},
        ),
      ],
      description: '',
      tags: const [],
    );
    await tester.pumpWidget(
      MaterialApp(home: NativeVideoPage(session: session)),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _openQuick(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      tester.getRect(find.byType(VideoPlaybackQuickPanel)).bottom,
      lessThanOrEqualTo(844 - 260),
    );
    expect(find.byTooltip(t.common.close).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final outcome in [
    'recover',
    'cancel',
    'background',
    'exhaust',
    'exhaust-many',
    'media-recover-many',
  ]) {
    testWidgets(
      'API same-episode automatic recovery $outcome is bounded and preserves intent',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final cards = [
          for (final line in [
            'a',
            'b',
            'c',
            if (outcome.endsWith('-many')) ...['d', 'e'],
          ])
            NativeVideoCard(
              title: 'Same episode',
              episodeLabel: '第01集',
              coverUrl: null,
              watchUrl: Uri.parse(
                'https://fixture.test/voddetail/7.html?line=$line&episode=1',
              ),
            ),
        ];
        NativePlaybackSession session(
          NativeVideoCard card,
        ) => NativePlaybackSession(
          title: card.title,
          watchUrl: card.watchUrl,
          sources: [
            NativePlaybackSource(
              url: Uri.parse(
                'https://media.test/${card.watchUrl.queryParameters['line']}.mp4',
              ),
              label: 'auto',
              headers: const {},
            ),
          ],
          description: '',
          tags: const [],
          episodes: [card],
        );
        final requests = <Uri>[], changes = <NativeEpisodeLoad>[];
        final delayed = Completer<NativeEpisodeLoad>();
        if (outcome == 'media-recover-many') {
          platform.failedMedia.addAll([
            'https://media.test/b.mp4',
            'https://media.test/c.mp4',
          ]);
        }
        await tester.pumpWidget(
          MaterialApp(
            home: NativeVideoPage(
              session: session(cards.first),
              autoResourceFallback: true,
              initialPlaybackState: (
                position: const Duration(seconds: 10),
                playing: true,
              ),
              resourceLines: (current) => [
                for (final card in cards)
                  NativeVideoResourceLine(
                    id: card.watchUrl.queryParameters['line']!,
                    label: card.watchUrl.queryParameters['line']!,
                    current: card.watchUrl == current.watchUrl,
                    target: card,
                  ),
              ],
              loadEpisode: (url) async {
                requests.add(url);
                if (outcome.startsWith('exhaust')) {
                  throw StateError('Unavailable candidate');
                }
                if (outcome != 'recover' && outcome != 'media-recover-many') {
                  return delayed.future;
                }
                return (
                  session: session(
                    cards.firstWhere((card) => card.watchUrl == url),
                  ),
                  operations: null,
                );
              },
              onEpisodeChanged: changes.add,
            ),
          ),
        );
        for (var n = 0; n < 8; n++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pump(const Duration(milliseconds: 100));
        }
        platform.failCurrentSource();
        for (var n = 0; n < 8; n++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pump(const Duration(milliseconds: 100));
        }
        if (outcome == 'cancel' || outcome == 'background') {
          expect(requests, [cards[1].watchUrl]);
          expect(
            find.text(t.videoPlayback.playFailed),
            findsNothing,
            reason: 'Waiting and final failure must be exclusive',
          );
          if (outcome == 'cancel') {
            await tester.tap(find.byKey(const ValueKey('video-switch.cancel')));
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
          await tester.pump(const Duration(milliseconds: 100));
          delayed.complete((session: session(cards[1]), operations: null));
          for (var n = 0; n < 8; n++) {
            await tester.runAsync(() => Future<void>.delayed(Duration.zero));
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(requests, [cards[1].watchUrl]);
          expect(changes, isEmpty);
        } else if (outcome == 'recover' || outcome == 'media-recover-many') {
          expect(
            changes.single.session.watchUrl,
            cards[outcome == 'recover' ? 1 : 3].watchUrl,
          );
          if (outcome == 'media-recover-many') {
            expect(requests, [
              for (final card in cards.skip(1).take(3)) card.watchUrl,
            ]);
            expect(
              platform.urls.where((url) => url == 'https://media.test/a.mp4'),
              hasLength(1),
            );
          }
          expect(platform.seekTargets.last, const Duration(seconds: 10));
          expect(platform.maxNativePlayers, 1);
        } else {
          expect(requests, [for (final card in cards.skip(1)) card.watchUrl]);
          expect(changes, isEmpty);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      },
    );
  }

  for (final switching in ['automatic', 'manual', 'initial-prepare', 'retry']) {
    testWidgets(
      'latest manual resource choice interrupts $switching without overlapping native players',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final cards = [
          for (final line in ['a', 'b', 'c'])
            NativeVideoCard(
              title: 'Same episode',
              episodeLabel: '第01集',
              coverUrl: null,
              watchUrl: Uri.parse(
                'https://fixture.test/voddetail/7.html?line=$line&episode=1',
              ),
            ),
        ];
        NativePlaybackSession session(
          NativeVideoCard card,
        ) => NativePlaybackSession(
          title: card.title,
          watchUrl: card.watchUrl,
          sources: [
            NativePlaybackSource(
              url: Uri.parse(
                'https://media.test/${card.watchUrl.queryParameters['line']}.mp4',
              ),
              label: 'auto',
              headers: const {},
            ),
          ],
          description: '',
          tags: const [],
          episodes: [card],
        );
        final reads = <Uri>[], changes = <NativeEpisodeLoad>[];
        final delayed = Completer<NativeEpisodeLoad>();
        final refresh = Completer<NativePlaybackSession>();
        final cancellations = <Uri>[];
        if (switching == 'initial-prepare') {
          platform.stalledMedia.add('https://media.test/a.mp4');
        }
        await tester.pumpWidget(
          MaterialApp(
            home: NativeVideoPage(
              session: session(cards.first),
              autoResourceFallback: switching != 'retry',
              initialPlaybackState: (
                position: const Duration(seconds: 10),
                playing: true,
              ),
              resourceLines: (current) => [
                for (final card in cards)
                  NativeVideoResourceLine(
                    id: card.watchUrl.queryParameters['line']!,
                    label: card.watchUrl.queryParameters['line']!,
                    current: card.watchUrl == current.watchUrl,
                    target: card,
                  ),
              ],
              refreshSession: switching == 'retry'
                  ? () => refresh.future
                  : null,
              onResolutionCancelled: cancellations.add,
              loadEpisode: (url) async {
                reads.add(url);
                if (url == cards[1].watchUrl) return delayed.future;
                return (
                  session: session(cards.firstWhere((c) => c.watchUrl == url)),
                  operations: null,
                );
              },
              onEpisodeChanged: changes.add,
            ),
          ),
        );
        Future<void> settle() async {
          for (var n = 0; n < 8; n++) {
            await tester.runAsync(() => Future<void>.delayed(Duration.zero));
            await tester.pump(const Duration(milliseconds: 100));
          }
        }

        Future<void> choose(String id) async {
          final entry = find.byKey(const ValueKey('video-inline.sources'));
          await tester.ensureVisible(entry);
          await tester.tap(entry);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          final panelRect = tester.getRect(
            find.byType(VideoPlaybackQuickPanel),
          );
          expect(panelRect.height, lessThan(380));
          _expectDockedPanel(tester, panelRect, const Size(390, 844));
          final row = find.byKey(ValueKey('video-resource-line.$id'));
          await _panelVisible(tester, row);
          expect(tester.widget<ListTile>(row).onTap, isNotNull);
          await tester.tap(row);
          await settle();
        }

        await settle();
        if (switching == 'automatic') {
          platform.failCurrentSource();
          await settle();
        } else if (switching == 'manual') {
          await choose('b');
        }
        if (switching == 'retry') {
          platform.failCurrentSource();
          await settle();
          final retry = find.widgetWithText(TextButton, t.common.retry);
          expect(retry, findsOneWidget);
          tester.widget<TextButton>(retry).onPressed!();
          await tester.pump();
        } else if (switching != 'initial-prepare') {
          expect(reads, [cards[1].watchUrl]);
        }
        await choose('c');
        expect(reads.last, cards[2].watchUrl);
        expect(changes.single.session.watchUrl, cards[2].watchUrl);
        expect(platform.maxNativePlayers, 1);
        if (switching == 'retry') {
          expect(cancellations, contains(cards.first.watchUrl));
          refresh.complete(session(cards.first));
          await settle();
          expect(changes.single.session.watchUrl, cards[2].watchUrl);
          expect(platform.urls.last, 'https://media.test/c.mp4');
        } else if (switching != 'initial-prepare') {
          delayed.complete((session: session(cards[1]), operations: null));
          await settle();
          expect(changes.single.session.watchUrl, cards[2].watchUrl);
        }
        // A resumed seek target alone is not evidence that media advanced.
        await tester.tap(find.byKey(const ValueKey('video-inline.sources')));
        await tester.pump(const Duration(milliseconds: 250));
        final current = find.byKey(const ValueKey('video-resource-line.c'));
        expect(
          find.descendant(
            of: current,
            matching: find.textContaining(t.videoSource.lineReady),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: current,
            matching: find.textContaining(t.videoSource.linePlayed),
          ),
          findsNothing,
        );
        platform.position = const Duration(seconds: 11);
        await tester.pump(const Duration(seconds: 1));
        await settle();
        expect(
          find.descendant(
            of: current,
            matching: find.textContaining(t.videoSource.linePlayed),
          ),
          findsOneWidget,
          reason:
              'play=${platform.playCount}; pause=${platform.pauseCount}; position=${platform.position}; seeks=${platform.seekTargets}; text=${tester.widgetList<Text>(find.descendant(of: current, matching: find.byType(Text))).map((e) => e.data).join(" | ")}',
        );
        if (switching == 'automatic' || switching == 'manual') {
          final cancelled = find.byKey(const ValueKey('video-resource-line.b'));
          expect(
            find.descendant(
              of: cancelled,
              matching: find.textContaining(t.videoSource.lineCancelled),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: cancelled,
              matching: find.textContaining(t.videoSource.lineFailed),
            ),
            findsNothing,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      },
    );
  }

  for (final stall in [false, true]) {
    testWidgets(
      'resource recovery advances when candidate native play ${stall ? 'stalls' : 'rejects'}',
      (tester) async {
        List<NativeVideoCard> cards(String line) => [
          for (var n = 1; n <= 2; n++)
            NativeVideoCard(
              title: '第$n集',
              watchUrl: Uri.parse(
                'https://fixture.test/voddetail/7.html?line=$line&episode=$n',
              ),
              coverUrl: null,
            ),
        ];
        NativePlaybackSession session(Uri watch) {
          final line = watch.queryParameters['line']!;
          return NativePlaybackSession(
            title: 'Work',
            watchUrl: watch,
            sources: [
              NativePlaybackSource(
                url: Uri.parse('https://media.test/$line.mp4'),
                label: 'auto',
                headers: const {},
              ),
            ],
            description: '',
            tags: const [],
            episodes: cards(line),
          );
        }

        final reads = <Uri>[], commits = <Uri>[];
        const bad = 'https://media.test/b.mp4';
        if (stall) {
          platform.stallPlayFor = bad;
        } else {
          platform.rejectPlayFor = bad;
        }
        await tester.pumpWidget(
          MaterialApp(
            home: NativeVideoPage(
              session: session(cards('a').first.watchUrl),
              autoResourceFallback: true,
              initialPlaybackState: (
                position: const Duration(seconds: 10),
                playing: true,
              ),
              resourceLines: (current) => [
                for (final line in ['a', 'b', 'c'])
                  NativeVideoResourceLine(
                    id: line,
                    label: line,
                    current: current.watchUrl.queryParameters['line'] == line,
                    target: cards(line).first,
                  ),
              ],
              loadEpisode: (watch) async {
                reads.add(watch);
                return (session: session(watch), operations: null);
              },
              onEpisodeChanged: (result) =>
                  commits.add(result.session.watchUrl),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> drivePlayback() async {
          for (var i = 0; i < 8; i++) {
            await tester.runAsync(() => Future<void>.delayed(Duration.zero));
            await tester.pump(const Duration(milliseconds: 100));
          }
        }

        platform.failCurrentSource();
        await drivePlayback();
        if (stall) {
          expect(platform.pendingPlay, isNotNull);
          expect(commits, isEmpty);
          await tester.pump(const Duration(seconds: 26));
        }
        await drivePlayback();
        expect(reads, [cards('b').first.watchUrl, cards('c').first.watchUrl]);
        expect(commits, [cards('c').first.watchUrl]);
        expect(platform.maxNativePlayers, 1);
        if (stall) {
          platform.pendingPlay!.complete();
          await tester.pump();
          expect(commits, [cards('c').first.watchUrl]);
        }

        final episodeTool = find.byKey(const ValueKey('video-inline.episodes'));
        await tester.ensureVisible(episodeTool);
        await tester.tap(episodeTool);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, '第2集'));
        await drivePlayback();
        expect(commits, [cards('c').first.watchUrl, cards('c').last.watchUrl]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final buffering in ['paused', 'progressing', 'stalled']) {
    testWidgets('resource stall watchdog respects $buffering playback', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cards = [
        for (final line in ['a', 'b'])
          NativeVideoCard(
            title: 'Same episode',
            episodeLabel: '第01集',
            coverUrl: null,
            watchUrl: Uri.parse(
              'https://fixture.test/voddetail/7.html?line=$line&episode=1',
            ),
          ),
      ];
      NativePlaybackSession session(
        NativeVideoCard card,
      ) => NativePlaybackSession(
        title: card.title,
        watchUrl: card.watchUrl,
        sources: [
          NativePlaybackSource(
            url: Uri.parse(
              'https://media.test/${card.watchUrl.queryParameters['line']}.mp4',
            ),
            label: 'auto',
            headers: const {},
          ),
        ],
        description: '',
        tags: const [],
        episodes: [card],
      );
      final reads = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          home: NativeVideoPage(
            session: session(cards.first),
            autoResourceFallback: true,
            initialPlaybackState: (
              position: Duration.zero,
              playing: buffering != 'paused',
            ),
            resourceLines: (current) => [
              for (final card in cards)
                NativeVideoResourceLine(
                  id: card.watchUrl.queryParameters['line']!,
                  label: card.watchUrl.queryParameters['line']!,
                  current: card.watchUrl == current.watchUrl,
                  target: card,
                ),
            ],
            loadEpisode: (url) async {
              reads.add(url);
              return (session: session(cards[1]), operations: null);
            },
          ),
        ),
      );
      for (var n = 0; n < 8; n++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump(const Duration(milliseconds: 100));
      }
      platform.send(VideoEvent(eventType: VideoEventType.bufferingStart));
      await tester.pump();
      for (var n = 0; n < 6; n++) {
        if (buffering == 'progressing') {
          platform.position = Duration(seconds: n + 1);
        }
        await tester.pump(const Duration(seconds: 5));
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      }
      for (var n = 0; n < 8; n++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(reads, buffering == 'stalled' ? [cards[1].watchUrl] : isEmpty);
      expect(platform.maxNativePlayers, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    });
  }

  for (final failure in ['platform', 'buffering', 'fallback-unavailable']) {
    testWidgets(
      'API runtime $failure tries another verified URL on the same line before other lines',
      (tester) async {
        final current = NativeVideoCard(
          title: 'Same episode',
          episodeLabel: '第01集',
          coverUrl: null,
          watchUrl: Uri.parse(
            'https://fixture.test/voddetail/7.html?line=a&episode=1',
          ),
        );
        final other = NativeVideoCard(
          title: 'Same episode',
          episodeLabel: '第01集',
          coverUrl: null,
          watchUrl: Uri.parse(
            'https://fixture.test/voddetail/7.html?line=b&episode=1',
          ),
        );
        NativePlaybackSession session(
          NativeVideoCard card,
        ) => NativePlaybackSession(
          title: card.title,
          watchUrl: card.watchUrl,
          sources: [
            NativePlaybackSource(
              url: Uri.parse(
                'https://media.test/${card == current ? 'primary' : 'other'}.mp4',
              ),
              label: 'auto',
              headers: const {},
            ),
            if (card == current)
              NativePlaybackSource(
                url: Uri.parse('https://media.test/original.m3u8'),
                label: 'Original',
                headers: const {},
              ),
          ],
          description: '',
          tags: const [],
          episodes: [card],
        );
        final reads = <Uri>[], changes = <NativeEpisodeLoad>[];
        if (failure == 'fallback-unavailable') {
          platform.failedMedia.add('https://media.test/original.m3u8');
        }
        await tester.pumpWidget(
          MaterialApp(
            home: NativeVideoPage(
              session: session(current),
              autoResourceFallback: true,
              initialPlaybackState: (
                position: const Duration(seconds: 10),
                playing: true,
              ),
              resourceLines: (active) => [
                for (final card in [current, other])
                  NativeVideoResourceLine(
                    id: card.watchUrl.queryParameters['line']!,
                    label: card.watchUrl.queryParameters['line']!,
                    current: card.watchUrl == active.watchUrl,
                    target: card,
                  ),
              ],
              loadEpisode: (url) async {
                reads.add(url);
                return (session: session(other), operations: null);
              },
              onEpisodeChanged: changes.add,
            ),
          ),
        );
        Future<void> settle() async {
          for (var n = 0; n < 10; n++) {
            await tester.runAsync(() => Future<void>.delayed(Duration.zero));
            await tester.pump(const Duration(milliseconds: 100));
          }
        }

        await settle();
        if (failure == 'buffering') {
          platform.send(VideoEvent(eventType: VideoEventType.bufferingStart));
          await tester.pump();
          await tester.pump(const Duration(seconds: 21));
        } else {
          platform.failCurrentSource();
        }
        await settle();
        expect(platform.urls.take(2), [
          'https://media.test/primary.mp4',
          'https://media.test/original.m3u8',
        ]);
        expect(
          platform.urls.where((url) => url == 'https://media.test/primary.mp4'),
          hasLength(1),
        );
        if (failure == 'fallback-unavailable') {
          expect(reads, [other.watchUrl]);
          expect(platform.urls.last, 'https://media.test/other.mp4');
          expect(changes.single.session.watchUrl, other.watchUrl);
        } else {
          expect(reads, isEmpty);
          expect(changes, isEmpty);
          expect(platform.urls, hasLength(2));
        }
        expect(platform.seekTargets.last, const Duration(seconds: 10));
        expect(platform.maxNativePlayers, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      },
    );
  }

  for (final outcome in [
    'recover',
    'initial-failure',
    'no-new',
    'wrong-watch',
    'cancel',
    'replace',
    'timeout',
  ]) {
    testWidgets(
      'lazy same-line recovery $outcome is bounded and does not commit late or different identities',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final cards = [
          for (final line in ['a', 'b'])
            NativeVideoCard(
              title: 'Same episode',
              episodeLabel: '第01集',
              coverUrl: null,
              watchUrl: Uri.parse(
                'https://fixture.test/voddetail/7.html?line=$line&episode=1',
              ),
            ),
        ];
        NativePlaybackSession session(
          NativeVideoCard card, {
          bool raw = false,
        }) => NativePlaybackSession(
          title: card.title,
          watchUrl: card.watchUrl,
          sources: [
            NativePlaybackSource(
              url: Uri.parse(
                'https://media.test/${raw ? 'raw' : card.watchUrl.queryParameters['line']}.m3u8',
              ),
              label: 'auto',
              headers: const {},
            ),
          ],
          description: '',
          tags: const [],
          episodes: [card],
        );
        final pending = Completer<NativePlaybackSession?>();
        final reads = <Uri>[],
            cancelled = <Uri>[],
            changes = <NativeEpisodeLoad>[];
        var rawReads = 0;
        if (outcome == 'initial-failure') {
          platform.failMediaOnce = 'https://media.test/a.m3u8';
        }
        await tester.pumpWidget(
          MaterialApp(
            home: NativeVideoPage(
              session: session(cards.first),
              autoResourceFallback: true,
              initialPlaybackState: (
                position: const Duration(seconds: 10),
                playing: true,
              ),
              resourceLines: (current) => [
                for (final card in cards)
                  NativeVideoResourceLine(
                    id: card.watchUrl.queryParameters['line']!,
                    label: card.watchUrl.queryParameters['line']!,
                    current: card.watchUrl == current.watchUrl,
                    target: card,
                  ),
              ],
              recoverCurrentResource: (current) async {
                rawReads++;
                expect(current.watchUrl, cards.first.watchUrl);
                if (outcome == 'no-new') return current;
                if (outcome == 'wrong-watch') {
                  return session(cards[1], raw: true);
                }
                if (['cancel', 'replace', 'timeout'].contains(outcome)) {
                  return pending.future;
                }
                return session(cards.first, raw: true);
              },
              onResolutionCancelled: cancelled.add,
              loadEpisode: (url) async {
                reads.add(url);
                return (session: session(cards[1]), operations: null);
              },
              onEpisodeChanged: changes.add,
            ),
          ),
        );
        Future<void> settle() async {
          for (var n = 0; n < 10; n++) {
            await tester.runAsync(() => Future<void>.delayed(Duration.zero));
            await tester.pump(const Duration(milliseconds: 100));
          }
        }

        await settle();
        if (outcome != 'initial-failure') platform.failCurrentSource();
        await settle();
        expect(rawReads, 1);
        if (['cancel', 'replace', 'timeout'].contains(outcome)) {
          expect(
            find.text(t.videoPlayback.playFailed),
            findsNothing,
            reason: 'The pending fallback and final failure must be exclusive',
          );
          if (outcome == 'cancel') {
            await tester.tap(find.byKey(const ValueKey('video-switch.cancel')));
          } else if (outcome == 'replace') {
            final entry = find.byKey(const ValueKey('video-inline.sources'));
            await tester.ensureVisible(entry);
            await tester.tap(entry);
            await tester.pump(const Duration(milliseconds: 250));
            final choice = find.byKey(const ValueKey('video-resource-line.b'));
            await _panelVisible(tester, choice);
            await tester.tap(choice);
          } else {
            await tester.pump(const Duration(seconds: 11));
          }
          await settle();
          pending.complete(session(cards.first, raw: true));
          await settle();
          expect(cancelled, contains(cards.first.watchUrl));
          expect(platform.urls, isNot(contains('https://media.test/raw.m3u8')));
        }
        if (['recover', 'initial-failure'].contains(outcome)) {
          expect(platform.urls, [
            'https://media.test/a.m3u8',
            'https://media.test/raw.m3u8',
          ]);
          expect(reads, isEmpty);
          expect(changes, isEmpty);
          expect(platform.seekTargets.last, const Duration(seconds: 10));
          if (outcome == 'recover') {
            platform.failCurrentSource();
            await settle();
            expect(
              rawReads,
              1,
              reason: 'Lazy discovery must run once per watch',
            );
            expect(reads, [cards[1].watchUrl]);
          }
        } else if (outcome == 'cancel') {
          expect(reads, isEmpty);
          expect(changes, isEmpty);
          expect(platform.urls, ['https://media.test/a.m3u8']);
        } else {
          expect(reads, [cards[1].watchUrl]);
          expect(changes.single.session.watchUrl, cards[1].watchUrl);
          expect(platform.urls.last, 'https://media.test/b.m3u8');
        }
        expect(platform.maxNativePlayers, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      },
    );
  }

  for (final initiallyFailed in [false, true]) {
    testWidgets(
      'API episode loader has a manual picker without an external route; initial failure=$initiallyFailed',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'breeze.video.defaults.autoplay': false,
          'breeze.video.defaults.controlsStyle': 'breeze',
        });
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final cards = [
          for (final id in [1, 2])
            NativeVideoCard(
              title: 'Episode $id',
              episodeLabel: '第$id集',
              watchUrl: Uri.parse(
                'https://www.ikunzy.com/voddetail/7.html?line=a&episode=$id',
              ),
              coverUrl: null,
            ),
        ];
        NativePlaybackSession episode(int id) => NativePlaybackSession(
          title: 'Series',
          watchUrl: cards[id - 1].watchUrl,
          sources: [
            NativePlaybackSource(
              url: Uri.parse('https://fixture.test/$id.mp4'),
              label: 'auto',
              headers: const {},
            ),
          ],
          description: '',
          tags: const [],
          episodes: cards,
        );
        final reads = <Uri>[];
        var analyses = 0;
        if (initiallyFailed) {
          platform.failMediaOnce = 'https://fixture.test/1.mp4';
        }
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: initiallyFailed ? Brightness.dark : Brightness.light,
            ),
            home: NativeVideoPage(
              session: episode(1),
              analyzePlayback: initiallyFailed
                  ? (_, _, _) async {
                      analyses++;
                    }
                  : null,
              detailBuilder: (_, _, _, _, tools) =>
                  Column(children: [tools, const Text('API details')]),
              loadEpisode: (uri) async {
                reads.add(uri);
                return (
                  session: episode(int.parse(uri.queryParameters['episode']!)),
                  operations: null,
                );
              },
            ),
          ),
        );
        for (var n = 0; n < 8; n++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pump(const Duration(milliseconds: 100));
        }
        final picker = find.byKey(const ValueKey('video-inline.episodes'));
        expect(picker, findsOneWidget);
        final analysis = find.byKey(const ValueKey('video-failure.analysis'));
        if (initiallyFailed) {
          expect(analysis, findsOneWidget);
          await tester.tap(analysis);
          await tester.pump();
          expect(analyses, 1);
        } else {
          expect(analysis, findsNothing);
        }
        await tester.tap(picker);
        await tester.pump(const Duration(milliseconds: 260));
        final panel = find.byType(VideoPlaybackQuickPanel);
        expect(tester.getSize(panel).height, lessThan(350));
        final panelContext = tester.element(panel);
        expect(
          Theme.of(panelContext).brightness,
          initiallyFailed ? Brightness.dark : Brightness.light,
          reason: 'episode menus follow the app appearance in both themes',
        );
        final episodeRow = find.byKey(
          ValueKey('episode-queue.${cards[1].watchUrl}'),
        );
        await _panelVisible(tester, episodeRow);
        expect(episodeRow.hitTestable(), findsOneWidget);
        await tester.tap(episodeRow);
        for (var n = 0; n < 12; n++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(reads, [cards[1].watchUrl]);
        expect(platform.urls.last, 'https://fixture.test/2.mp4');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'detail actions, fullscreen and watch-later use one state without recreating playback',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'breeze.video.defaults.controlsStyle': 'breeze',
      });
      var liked = false, later = false, member = false;
      final writes = <String>[];
      final operations = VideoSiteOperations(
        page: Uri.parse('https://hanime1.me/watch?v=42'),
        evaluate: (script) async {
          final match = RegExp(
            r'const operation = "([^"]+)", payload = (.*);',
          ).firstMatch(script);
          if (match == null) return {'status': 'cancelled'};
          final operation = match[1]!, payload = jsonDecode(match[2]!) as Map;
          if (operation == 'playlists' || operation == 'savePlaylist') {
            if (operation == 'savePlaylist') {
              writes.add(operation);
              member = payload['enabled'] as bool;
            }
            return {
              'status': 'ok',
              'canCreate': true,
              'lists': [
                {'id': 'abc', 'title': 'My playlist', 'containsVideo': member},
              ],
            };
          }
          if (operation == 'comments') {
            return {'status': 'ok', 'items': [], 'canPost': true};
          }
          if (operation == 'like') {
            liked = payload['enabled'] as bool;
            writes.add(operation);
          }
          if (operation == 'watchLater') {
            later = payload['enabled'] as bool;
            writes.add(operation);
          }
          return {
            'status': 'ok',
            'signedIn': true,
            'canLike': true,
            'canFollow': true,
            'capabilities': {'watchLater': 'ready', 'playlists': 'ready'},
            'liked': liked,
            'following': false,
            'watchLater': later,
          };
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: NativeVideoPage(
            session: NativePlaybackSession(
              title: 'Video title',
              creatorName: 'Author name',
              watchUrl: operations.page,
              sources: [
                NativePlaybackSource(
                  url: Uri.parse('https://fixture.test/video.mp4'),
                  label: 'auto',
                  headers: const {},
                ),
              ],
              description: '',
              tags: const [],
            ),
            siteOperations: operations,
            onOpenCreator: () async {},
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        tester.getTopLeft(find.text('Author name')).dy,
        lessThan(tester.getTopLeft(find.text('Video title')).dy),
      );
      await tester.tap(find.byKey(const ValueKey('video-like')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('video-favorite')));
      await tester.pumpAndSettle();
      final playlistSurface = find.byKey(
        const ValueKey('video-playlist.material'),
      );
      expect(playlistSurface, findsOneWidget);
      final material = tester.widget<NativeMaterialSurface>(playlistSurface);
      expect(material.radius, 16);
      expect(material.floating, isTrue);
      expect(tester.getSize(playlistSurface).width, lessThanOrEqualTo(480));
      await tester.tap(find.text('My playlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(t.common.close));
      await tester.pumpAndSettle();
      expect(find.text(t.videoCommunity.favorited), findsOneWidget);
      final sectionSwipe = find.byKey(
        const ValueKey('video-detail.section-swipe'),
      );
      await tester.drag(sectionSwipe, const Offset(-280, 0));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PageView>(
              find.byKey(const ValueKey('video-detail.section-pages')),
            )
            .controller!
            .page,
        closeTo(1, .001),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Retain on tab switch');
      await tester.tap(find.text(t.videoCommunity.overview));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.videoCommunity.comments));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Retain on tab switch',
      );
      await tester.tap(find.text(t.videoCommunity.overview));
      await tester.pumpAndSettle();
      await _openQuick(tester);
      await tester.tap(find.text(t.videoCommunity.watchLater));
      await tester.pump();
      expect(find.text(t.videoCommunity.inWatchLater), findsOneWidget);
      await _closeQuick(tester);
      await tester.tap(find.byTooltip(t.videoPlayback.fullscreen));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(844, 390);
      await tester.pump();
      // The menu/rotation can finish after the ordinary controls timeout.
      if (find.byTooltip(t.videoCommunity.like).evaluate().isEmpty) {
        final rect = tester.getRect(
          find.byKey(const ValueKey('video-gesture-surface')),
        );
        await tester.tapAt(
          Offset(rect.left + rect.width * .2, rect.top + rect.height * .55),
        );
        await tester.pump(const Duration(milliseconds: 350));
      }
      expect(
        find.byTooltip(t.videoCommunity.like).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byTooltip(t.videoCommunity.favorite).hitTestable(),
        findsOneWidget,
      );
      expect(find.byTooltip(t.videoCommunity.share), findsOneWidget);
      expect(writes, ['like', 'savePlaylist', 'watchLater']);
      expect(platform.urls.length, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      operations.dispose();
    },
  );

  testWidgets(
    'quick settings keep current source choices and link to persisted gesture settings',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = NativePlaybackSession(
        title: 'Flat settings',
        watchUrl: Uri.parse('https://hanime1.me/watch?v=42'),
        sources: [
          for (final quality in ['720p', '1080p'])
            NativePlaybackSource(
              url: Uri.parse('https://fixture.test/$quality.mp4'),
              label: quality,
              headers: const {},
            ),
        ],
        description: '',
        tags: const [],
        episodes: [
          NativeVideoCard(
            title: 'Episode 2',
            watchUrl: Uri.parse('https://hanime1.me/watch?v=2'),
            coverUrl: null,
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: NativeVideoPage(session: session, onOpenVideo: (_) {}),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byTooltip(t.videoPlayback.speed), findsOneWidget);
      final episodeY = tester
          .getTopLeft(find.byKey(const ValueKey('video-inline.episodes')))
          .dy;
      final sourceY = tester
          .getTopLeft(find.byKey(const ValueKey('video-inline.sources')))
          .dy;
      expect(
        (episodeY - sourceY).abs(),
        lessThan(1),
        reason: 'normal portrait selectors share one tool row',
      );
      expect(
        (episodeY -
                tester
                    .getTopLeft(
                      find.byKey(const ValueKey('video-inline.download')),
                    )
                    .dy)
            .abs(),
        lessThan(1),
        reason: 'resolved downloads share the normal portrait tool row',
      );
      await _openQuick(tester);
      expect(find.byType(ExpansionTile), findsNothing);
      expect(
        find.descendant(
          of: find.byType(VideoPlaybackQuickPanel),
          matching: find.byIcon(Icons.arrow_back_rounded),
        ),
        findsNothing,
      );
      final swipeQuick = find.byKey(const ValueKey('video-quick.swipe-seek'));
      await _panelVisible(tester, swipeQuick);
      expect(
        tester.widget<SwitchListTile>(swipeQuick).value,
        (await VideoPlaybackPreferences.read()).swipeSeek,
      );
      await _closeQuick(tester);
      final sourceEntry = find.byKey(const ValueKey('video-inline.sources'));
      await tester.ensureVisible(sourceEntry);
      expect(sourceEntry.hitTestable(), findsOneWidget);
      await tester.tap(sourceEntry);
      await tester.pumpAndSettle();
      final source = find.widgetWithText(ListTile, '1080p');
      await _panelVisible(tester, source);
      expect(source.hitTestable(), findsOneWidget);
      await _closeQuick(tester);
      await _openQuick(tester);
      final settings = find.widgetWithText(
        ListTile,
        t.videoPlayback.allPlaybackSettings,
      );
      await _panelVisible(tester, settings);
      await tester.tap(settings);
      await tester.pumpAndSettle();
      expect(find.byType(VideoPlaybackSettingsPage), findsOneWidget);
      final swipe = find.widgetWithText(
        SwitchListTile,
        t.videoPlayback.swipeSeek,
      );
      await tester.scrollUntilVisible(
        swipe,
        160,
        scrollable: find
            .descendant(
              of: find.byType(VideoPlaybackSettingsPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final toggle = find.descendant(
        of: swipe,
        matching: find.byWidgetPredicate(
          (widget) => widget is Switch || widget is CupertinoSwitch,
        ),
      );
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect((await VideoPlaybackPreferences.read()).swipeSeek, false);
      expect(platform.urls.length, 1);
      // Return through the platform route contract; this test checks the
      // persisted setting and preserved player, not a platform back glyph.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'episodes show real labels, current identity and a full-title picker in site order',
    (tester) async {
      final watch = Uri.parse('https://hanime1.me/watch?v=42');
      final session = NativePlaybackSession.fromDetailResponse({
        'data': {
          'title': 'Series',
          'episodes': [
            {
              'title': 'Series Episode 2',
              'watchUrl': 'https://hanime1.me/watch?v=9',
            },
            {'title': 'Series OVA', 'watchUrl': watch.toString()},
            {
              'title': 'Unnumbered title',
              'watchUrl': 'https://hanime1.me/watch?v=1',
            },
          ],
        },
      }, watchUrl: watch);
      Uri? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: NativeVideoPage(
            session: session,
            onOpenVideo: (url) => opened = url,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('video-inline.episodes')));
      await tester.pumpAndSettle();
      final order = find.byKey(const ValueKey('episode-queue.order'));
      expect(
        tester.widget<SettingChoiceTile<VideoEpisodeOrder>>(order).value,
        VideoEpisodeOrder.site,
      );
      expect(
        tester.widget<SettingChoiceTile<VideoEpisodeOrder>>(order).items.keys,
        [VideoEpisodeOrder.site, VideoEpisodeOrder.manual],
      );
      final current = find.widgetWithText(ListTile, 'Series OVA');
      expect(tester.widget<ListTile>(current).selected, true);
      expect(tester.widget<ListTile>(current).onTap, isNull);
      expect(find.widgetWithText(ListTile, 'Unnumbered title'), findsOneWidget);
      final nextEpisode = find.widgetWithText(ListTile, 'Series Episode 2');
      await _panelVisible(tester, nextEpisode);
      expect(nextEpisode.hitTestable(), findsOneWidget);
      await tester.tap(nextEpisode);
      await tester.pumpAndSettle();
      expect(opened, Uri.parse('https://hanime1.me/watch?v=9'));
      expect(find.byType(VideoPlaybackQuickPanel), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'inline comment submission keeps its watch document until readback',
    (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      const connectivity = MethodChannel(
        'dev.fluttercommunity.plus/connectivity',
      );
      const connectivityStatus = MethodChannel(
        'dev.fluttercommunity.plus/connectivity_status',
      );
      messenger.setMockMethodCallHandler(connectivity, (_) async => ['wifi']);
      messenger.setMockMethodCallHandler(connectivityStatus, (_) async => null);
      addTearDown(() {
        messenger.setMockMethodCallHandler(connectivity, null);
        messenger.setMockMethodCallHandler(connectivityStatus, null);
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'breeze.video.defaults.controlsStyle': 'breeze',
      });
      final cards = [
        for (final id in [42, 43])
          NativeVideoCard(
            title: 'Episode $id',
            watchUrl: Uri.parse('https://hanime1.me/watch?v=$id'),
            coverUrl: null,
          ),
      ];
      NativePlaybackSession episode(
        NativeVideoCard card,
      ) => NativePlaybackSession(
        title: card.title,
        watchUrl: card.watchUrl,
        sources: [
          NativePlaybackSource(
            url: Uri.parse(
              'https://fixture.test/${card.watchUrl.queryParameters['v']}.mp4',
            ),
            label: 'auto',
            headers: const {},
          ),
        ],
        description: '',
        tags: const [],
        episodes: cards,
      );
      final readback = Completer<Map<String, dynamic>>();
      final operations = VideoSiteOperations(
        page: cards.first.watchUrl,
        evaluate: (script) async {
          if (script.contains('const operation = "comment"')) {
            return readback.future;
          }
          if (script.contains('const operation = "comments"')) {
            return {'status': 'ok', 'canPost': true, 'items': []};
          }
          return {'status': 'ok', 'actor': 'signedOut'};
        },
      );
      addTearDown(operations.dispose);
      final reads = <Uri>[], opened = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          home: NativeVideoPage(
            session: episode(cards.first),
            siteOperations: operations,
            onOpenVideo: opened.add,
            loadEpisode: (uri) async {
              reads.add(uri);
              return (session: episode(cards.last), operations: null);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.videoCommunity.comments));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Stay on this episode');
      await tester.tap(
        find.widgetWithText(FilledButton, t.videoCommunity.post),
      );
      await tester.pump();
      expect(operations.writeInFlight, isTrue);

      final picker = find.byKey(const ValueKey('video-inline.episodes'));
      final next = find.byKey(ValueKey('episode-queue.${cards.last.watchUrl}'));
      Future<void> chooseNext() async {
        expect(picker.hitTestable(), findsOneWidget);
        await tester.tap(picker);
        await tester.pumpAndSettle();
        expect(next.hitTestable(), findsOneWidget);
        await tester.tap(next);
        for (var i = 0; i < 6; i++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await chooseNext();
      expect(reads, isEmpty);
      expect(operations.writeInFlight, isTrue);
      await tester.tap(find.text(t.videoCommunity.overview));
      await tester.pumpAndSettle();
      final preview = find.byTooltip(cards.last.title);
      await tester.ensureVisible(preview);
      expect(preview.hitTestable(), findsOneWidget);
      await tester.tap(preview);
      await tester.pump();
      expect(opened, isEmpty);
      expect(operations.writeInFlight, isTrue);
      readback.complete({'status': 'ok', 'canPost': true, 'items': []});
      await tester.pumpAndSettle();
      expect(operations.writeInFlight, isFalse);
      await chooseNext();
      expect(reads, [cards.last.watchUrl]);
      expect(platform.urls.last, 'https://fixture.test/43.mp4');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'small-screen comment keyboard keeps the draft, focus, send action and active player',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final operations = VideoSiteOperations(
        page: Uri.parse('https://hanime1.me/watch?v=42'),
        evaluate: (script) async {
          if (script.contains('const operation = "comments"')) {
            return {'status': 'ok', 'canPost': true, 'items': []};
          }
          return {
            'status': 'ok',
            'signedIn': true,
            'canLike': true,
            'canFollow': true,
            'liked': false,
            'following': false,
          };
        },
      );
      final session = NativePlaybackSession(
        title: 'Keyboard fixture',
        watchUrl: operations.page,
        sources: [
          for (final label in ['720p', '1080p'])
            NativePlaybackSource(
              url: Uri.parse('https://fixture.test/$label.mp4'),
              label: label,
              headers: const {},
            ),
        ],
        description: '',
        tags: const [],
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: NativeVideoPage(
            session: session,
            siteOperations: operations,
            initialPosition: const Duration(seconds: 45),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.text(t.videoCommunity.comments));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Draft while typing');
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 340);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Draft while typing',
      );
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        true,
      );
      expect(
        find.widgetWithText(FilledButton, t.videoCommunity.post).hitTestable(),
        findsOneWidget,
      );
      expect(platform.urls.length, 1);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('video-gesture-surface')),
        findsOneWidget,
      );
      expect(platform.urls.length, 1);
      expect(platform.position, const Duration(seconds: 45));
      await tester.pumpWidget(const SizedBox.shrink());
      operations.dispose();
    },
  );

  for (final recovery in ['login', 'verification']) {
    testWidgets('nested replies return through the player for $recovery', (
      tester,
    ) async {
      final operations = VideoSiteOperations(
        page: Uri.parse('https://hanime1.me/watch?v=42'),
        evaluate: (script) async {
          if (script.contains('const operation = "comments"')) {
            return {
              'status': 'ok',
              'items': [
                {
                  'id': '12',
                  'author': 'Example',
                  'text': 'A comment',
                  'hasReplies': true,
                },
              ],
              'canPost': false,
            };
          }
          if (script.contains('const operation = "replies"')) {
            return {'status': recovery};
          }
          return {'status': 'ok'};
        },
      );
      var logins = 0;
      bool? website;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open player'),
                onPressed: () async {
                  website = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => NativeVideoPage(
                        session: NativePlaybackSession(
                          title: 'Community fixture',
                          watchUrl: operations.page,
                          sources: const [],
                          description: '',
                          tags: const [],
                        ),
                        siteOperations: operations,
                        onOpenAccount: () {
                          logins++;
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open player'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(t.videoCommunity.comments));
      await tester.tap(find.text(t.videoCommunity.comments));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.videoCommunity.viewReplies));
      await tester.pumpAndSettle();
      final replies = find.byKey(const ValueKey('video-inline-replies.12'));
      expect(replies, findsOneWidget);
      expect(find.text('A comment'), findsOneWidget);
      final action = find.descendant(
        of: replies,
        matching: find.widgetWithText(
          TextButton,
          recovery == 'login'
              ? t.videoCommunity.login
              : t.videoPlayback.backToWeb,
        ),
      );
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      expect(action.hitTestable(), findsOneWidget);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('Open player'), findsOneWidget);
      expect(find.byType(NativeVideoPage), findsNothing);
      expect(logins, recovery == 'login' ? 1 : 0);
      expect(website, recovery == 'login' ? isNull : isTrue);
      operations.dispose();
    });
  }

  for (final style in ['system', 'breeze']) {
    testWidgets(
      'inline $style controls preview horizontal seeking and commit only on release',
      (tester) async {
        tester.view.physicalSize = const Size(390, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({
          'breeze.video.defaults.controlsStyle': style,
        });
        await tester.pumpWidget(
          MaterialApp(
            home: NativeVideoPage(
              session: NativePlaybackSession(
                title: 'Gesture fixture',
                watchUrl: Uri.parse('https://hanime1.me/watch?v=42'),
                sources: [
                  NativePlaybackSource(
                    url: Uri.parse('https://fixture.test/video.mp4'),
                    label: 'auto',
                    headers: const {},
                  ),
                ],
                description: '',
                tags: const [],
              ),
              initialPosition: const Duration(seconds: 45),
            ),
          ),
        );
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        final surface = find.byKey(const ValueKey('video-gesture-surface'));
        final playCount = platform.playCount, pauseCount = platform.pauseCount;
        var count = platform.seekTargets.length;
        // Drag the video itself while the edge toolbar is visible.
        final gesture = await tester.startGesture(tester.getCenter(surface));
        await gesture.moveBy(const Offset(70, 0));
        await tester.pump();
        await gesture.moveBy(const Offset(30, 0));
        await tester.pump();
        expect(platform.seekTargets.length, count);
        expect(find.textContaining(' / 02:00'), findsNWidgets(2));
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 100));
        expect(platform.seekTargets.length, count + 1);
        expect(platform.position, greaterThan(const Duration(seconds: 45)));
        expect(platform.playCount, playCount);
        expect(platform.pauseCount, pauseCount);
        final position = platform.position;
        count = platform.seekTargets.length;
        final cancelled = await tester.startGesture(tester.getCenter(surface));
        await cancelled.moveBy(const Offset(-80, 0));
        await tester.pump();
        await cancelled.cancel();
        await tester.pump(const Duration(milliseconds: 100));
        expect(platform.seekTargets.length, count);
        expect(platform.position, position);
        final rect = tester.getRect(surface);
        await tester.dragFrom(
          rect.topLeft + Offset(2, rect.height / 2),
          const Offset(100, 0),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          platform.seekTargets.length,
          count,
          reason: 'the navigation edge is excluded from seek recognition',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'settings and sync preference changes reach an active player without returning a route',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NativeVideoPage(
            session: NativePlaybackSession(
              title: 'Live settings',
              watchUrl: Uri.parse('https://hanime1.me/watch?v=42'),
              sources: [
                NativePlaybackSource(
                  url: Uri.parse('https://cdn.example/video.mp4'),
                  label: 'Auto',
                  headers: const {},
                ),
              ],
              description: '',
              tags: const [],
            ),
            initialPosition: const Duration(seconds: 42),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      for (final style in ['breeze', 'system']) {
        await VideoPlaybackPreferences.save('controlsStyle', style);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<VideoControlAppearance>(
                find.byType(VideoControlAppearance),
              )
              .systemControls,
          style == 'system',
        );
        expect(platform.urls, hasLength(1));
        expect(platform.position, const Duration(seconds: 42));
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'quick source selection preserves playback and uses real source labels',
    (tester) async {
      NativePlaybackSession? analyzed;
      await tester.pumpWidget(
        MaterialApp(
          home: NativeVideoPage(
            session: NativePlaybackSession(
              title: 'Source selection',
              watchUrl: Uri.parse('https://hanime1.me/watch?v=42'),
              sources: [
                NativePlaybackSource(
                  url: Uri.parse('https://cdn.example/first.mp4'),
                  label: 'Auto',
                  headers: const {},
                ),
                NativePlaybackSource(
                  url: Uri.parse('https://cdn.example/1080.mp4'),
                  label: '1080p',
                  headers: const {},
                ),
              ],
              description: '',
              tags: const [],
            ),
            initialPosition: const Duration(seconds: 42),
            analyzePlayback: (_, current, _) async => analyzed = current,
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.byKey(const ValueKey('video-inline.sources')));
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(VideoPlaybackQuickPanel),
          matching: find.text(t.videoPlayback.sourceNumber(index: 1)),
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(ListTile, '1080p'));
      // Stream cancellation/disposal completes outside the simulated frame
      // clock. Flush that boundary instead of advancing to a 5-second timeout.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(platform.urls.last, 'https://cdn.example/1080.mp4');
      expect(platform.position, const Duration(seconds: 42));
      expect(find.byType(VideoPlaybackQuickPanel), findsNothing);
      expect(find.byType(NativeVideoPage), findsOneWidget);
      expect(find.text(t.videoPlayback.playFailed), findsNothing);
      await tester.tap(find.byTooltip(t.videoPlayback.playbackSettings));
      await tester.pump(const Duration(milliseconds: 260));
      final analysisEntry = find.byKey(const ValueKey('video-quick.analysis'));
      await _panelVisible(tester, analysisEntry);
      expect(analysisEntry.hitTestable(), findsOneWidget);
      await tester.tap(analysisEntry);
      await tester.pump(const Duration(milliseconds: 260));
      expect(
        analyzed?.sources.single.url.toString(),
        'https://cdn.example/1080.mp4',
      );
      expect(platform.position, const Duration(seconds: 42));
      expect(
        platform.urls,
        hasLength(2),
        reason: 'analysis does not recreate playback',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('global appearance changes keep the active player and position', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NativeVideoPage(
          session: NativePlaybackSession(
            title: 'Style fixture',
            watchUrl: Uri.parse('https://hanime1.me/watch?v=42'),
            sources: [
              NativePlaybackSource(
                url: Uri.parse('https://fixture.test/video.mp4'),
                label: 'auto',
                headers: const {},
              ),
            ],
            description: '',
            tags: const [],
          ),
          initialPosition: const Duration(seconds: 42),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final seeks = platform.seekTargets.length;
    await _openQuick(tester);
    for (final style in ['breeze', 'system', 'breeze', 'system']) {
      // The panel observes the same persisted preference as full settings.
      await VideoPlaybackPreferences.save('controlsStyle', style);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(
        tester
            .widget<SettingChoiceTile<String>>(
              find.byKey(const ValueKey('video-quick.controls-style')),
            )
            .value,
        style,
      );
      expect(
        tester
            .widget<VideoControlAppearance>(find.byType(VideoControlAppearance))
            .systemControls,
        style == 'system',
      );
      expect(platform.urls.length, 1);
      expect(platform.seekTargets.length, seeks);
      expect(platform.position, const Duration(seconds: 42));
    }
    expect(find.byType(VideoPlaybackSettingsPage), findsNothing);
    expect(find.byType(VideoPlaybackQuickPanel), findsOneWidget);
    expect((await VideoPlaybackPreferences.read()).controlsStyle, 'system');
    await _closeQuick(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final (recording, resume) in [
    (true, true),
    (true, false),
    (false, true),
    (false, false),
  ]) {
    testWidgets(
      'history and resume respect recording=$recording resume=$resume',
      (tester) async {
        final watch = Uri.parse('https://hanime1.me/watch?v=408773');
        final old = VideoWatchRecord(
          watchUrl: watch,
          title: 'Older title',
          position: const Duration(seconds: 42),
          duration: const Duration(minutes: 2),
          updatedAt: DateTime.utc(2026, 10, 22),
          completed: false,
        );
        SharedPreferences.setMockInitialValues({
          'breeze.video.defaults.recordHistory': recording,
          'breeze.video.defaults.resumeProgress': resume,
          'breeze.video.progress.hanime1.me.408773': 42000,
          'breeze.video.history.v1.source-one': jsonEncode([old.toJson()]),
        });
        final session = NativePlaybackSession(
          title: 'New title',
          watchUrl: watch,
          sources: [
            NativePlaybackSource(
              url: Uri.parse('https://cdn.example/video.mp4'),
              label: 'auto',
              headers: const {},
            ),
          ],
          description: '',
          tags: const [],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: NativeVideoPage(
              session: session,
              source: 'source-one',
              historyMetadata: (_) => const {
                'genres': 'Action',
                'year': '2024',
                'token': 'must-not-persist',
              },
            ),
          ),
        );
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          platform.position,
          recording && resume ? const Duration(seconds: 42) : Duration.zero,
        );
        platform.position = const Duration(seconds: 56);
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.byTooltip(t.videoPlayback.pause));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));
        final records = await VideoWatchHistory.read('source-one');
        expect(records.single.title, recording ? 'New title' : 'Older title');
        expect(records.single.position, Duration(seconds: recording ? 56 : 42));
        expect(
          records.single.metadata,
          recording ? {'genres': 'Action', 'year': '2024'} : isEmpty,
        );
        final store = await SharedPreferences.getInstance();
        if (recording) {
          expect(
            store.containsKey('breeze.video.progress.hanime1.me.408773'),
            isFalse,
          );
        }
      },
    );
  }

  for (final (resumeEnabled, completed, useLegacy) in [
    (true, false, false),
    (true, true, false),
    (false, false, false),
    (true, false, true),
  ]) {
    testWidgets('switching episodes restores target progress with '
        'resume=$resumeEnabled completed=$completed legacy=$useLegacy', (
      tester,
    ) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      const source = 'switch-episode-progress';
      const saved = Duration(seconds: 42);
      final cards = [
        for (final id in [1, 2])
          NativeVideoCard(
            title: 'Episode $id',
            watchUrl: Uri.parse(
              'https://fixture.test/voddetail/1.html?line=main&episode=$id',
            ),
            coverUrl: null,
          ),
      ];
      NativePlaybackSession episode(int index) => NativePlaybackSession(
        title: cards[index].title,
        watchUrl: cards[index].watchUrl,
        sources: [
          NativePlaybackSource(
            url: Uri.parse('https://cdn.example/$index.mp4'),
            label: 'auto',
            headers: const {},
          ),
        ],
        description: '',
        tags: const [],
        episodes: cards,
      );
      final record = VideoWatchRecord(
        watchUrl: cards[1].watchUrl,
        title: cards[1].title,
        position: completed ? const Duration(minutes: 2) : saved,
        duration: const Duration(minutes: 2),
        updatedAt: DateTime.utc(2026, 11, 10),
        completed: completed,
      );
      SharedPreferences.setMockInitialValues({
        'breeze.video.defaults.autoplay': false,
        'breeze.video.defaults.controlsStyle': 'breeze',
        'breeze.video.defaults.resumeProgress': resumeEnabled,
        record.legacyProgressKey: saved.inMilliseconds,
      });
      if (!useLegacy) {
        await VideoWatchHistory.record(source, record);
      }
      final changes = <NativeEpisodeLoad>[];
      await tester.pumpWidget(
        MaterialApp(
          home: NativeVideoPage(
            session: episode(0),
            source: source,
            onEpisodeChanged: changes.add,
            loadEpisode: (target) async => (
              session: episode(cards.indexWhere((c) => c.watchUrl == target)),
              operations: null,
            ),
          ),
        ),
      );
      Future<void> settleMedia() async {
        for (var n = 0; n < 12; n++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await settleMedia();
      expect(platform.seekTargets, isEmpty);
      await tester.tap(find.byKey(const ValueKey('video-inline.episodes')));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(
        find.byKey(ValueKey('episode-queue.${cards[1].watchUrl}')),
      );
      await settleMedia();
      expect(changes.single.session.watchUrl, cards[1].watchUrl);
      expect(platform.seekTargets, resumeEnabled && !completed ? [saved] : []);
      expect(platform.playCount, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  testWidgets(
    'popping saves the final checkpoint before the outgoing player is disposed',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      const source = 'progress-on-pop';
      const checkpoint = Duration(seconds: 15);
      const finalPosition = Duration(seconds: 18);
      final navigator = GlobalKey<NavigatorState>();
      final session = NativePlaybackSession(
        title: 'Route exit',
        watchUrl: Uri.parse('https://fixture.test/watch?v=1'),
        sources: [
          NativePlaybackSource(
            url: Uri.parse('https://cdn.example/video.mp4'),
            label: 'auto',
            headers: const {},
          ),
        ],
        description: '',
        tags: const [],
      );
      await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: const Scaffold()),
      );
      final route = PageRouteBuilder<void>(
        pageBuilder: (_, _, _) =>
            NativeVideoPage(session: session, source: source),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: const Duration(seconds: 2),
      );
      unawaited(navigator.currentState!.push(route));
      for (var n = 0; n < 6; n++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      platform.position = checkpoint;
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(
        (await VideoWatchHistory.read(source)).single.position,
        checkpoint,
      );
      platform.position = finalPosition;
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(
        (await VideoWatchHistory.read(source)).single.position,
        checkpoint,
      );

      navigator.currentState!.pop();
      await tester.pump(const Duration(milliseconds: 100));
      expect(route.animation!.status, AnimationStatus.reverse);
      expect(platform._events, hasLength(1));
      expect(
        (await VideoWatchHistory.read(source)).single.position,
        finalPosition,
      );
      expect(platform.pauseCount, greaterThan(0));

      await VideoWatchHistory.remove(source, session.watchUrl);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.byType(NativeVideoPage, skipOffstage: false), findsNothing);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(await VideoWatchHistory.read(source), isEmpty);
      expect(platform._events, isEmpty);
    },
  );

  testWidgets(
    'exiting after a platform error resumes from the last observed position',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      const source = 'progress-after-error';
      const lastCheckpoint = Duration(seconds: 15);
      const lastPosition = Duration(seconds: 18);
      final session = NativePlaybackSession(
        title: 'Interrupted video',
        watchUrl: Uri.parse('https://hanime1.me/watch?v=408773'),
        sources: [
          NativePlaybackSource(
            url: Uri.parse('https://cdn.example/video.mp4'),
            label: 'auto',
            headers: const {},
          ),
        ],
        description: '',
        tags: const [],
      );
      Future<void> open() async {
        await tester.pumpWidget(
          MaterialApp(
            home: NativeVideoPage(session: session, source: source),
          ),
        );
        for (var n = 0; n < 6; n++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await open();
      platform.position = lastCheckpoint;
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(
        (await VideoWatchHistory.read(source)).single.position,
        lastCheckpoint,
      );

      platform.position = lastPosition;
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(
        (await VideoWatchHistory.read(source)).single.position,
        lastCheckpoint,
      );
      platform.failCurrentSource();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text(t.videoPlayback.playFailed), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(
        (await VideoWatchHistory.read(source)).single.position,
        lastPosition,
      );

      platform.position = Duration.zero;
      platform.seekTargets.clear();
      await open();
      expect(platform.seekTargets, [lastPosition]);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'seek preview, buffering, sound, controls and replay remain usable',
    (tester) async {
      final session = NativePlaybackSession(
        title: 'Player states',
        watchUrl: Uri.parse('https://hanime1.me/watch?v=408773'),
        sources: [
          NativePlaybackSource(
            url: Uri.parse('https://cdn.example/video.mp4'),
            label: 'auto',
            headers: const {},
          ),
        ],
        description: '',
        tags: const [],
      );
      await tester.pumpWidget(
        MaterialApp(home: NativeVideoPage(session: session)),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final seekCount = platform.seekTargets.length;
      final slider = tester.getRect(find.byType(Slider));
      final drag = await tester.startGesture(
        slider.centerLeft + Offset(slider.width * .25, 0),
      );
      await drag.moveBy(Offset(slider.width * .1, 0));
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        platform.seekTargets,
        hasLength(seekCount),
        reason: 'dragging previews instead of seeking on every pixel',
      );
      await drag.up();
      await tester.pump(const Duration(milliseconds: 16));
      expect(platform.seekTargets, hasLength(seekCount + 1));

      platform.send(VideoEvent(eventType: VideoEventType.bufferingStart));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(t.videoPlayback.buffering), findsOneWidget);
      expect(find.text(t.videoPlayback.playFailed), findsNothing);
      await tester.tap(find.byTooltip(t.videoPlayback.pause));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byTooltip(t.videoPlayback.play), findsOneWidget);
      platform.send(VideoEvent(eventType: VideoEventType.bufferingEnd));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byTooltip(t.videoPlayback.play));
      await tester.pump(const Duration(milliseconds: 16));
      await _openQuick(tester);
      final mute = find.widgetWithText(SwitchListTile, t.videoPlayback.mute);
      await _panelVisible(tester, mute);
      await tester.tap(mute);
      await tester.pump(const Duration(milliseconds: 16));
      expect(platform.volumes.last, 0);
      await tester.tap(mute);
      await tester.pump(const Duration(milliseconds: 16));
      expect(platform.volumes.last, 1);
      await _closeQuick(tester);

      await tester.pump(const Duration(seconds: 6));
      expect(find.byTooltip(t.videoPlayback.pause).hitTestable(), findsNothing);
      final surface = tester.getRect(
        find.byKey(const ValueKey('video-gesture-surface')),
      );
      await tester.tapAt(surface.topLeft + const Offset(60, 20));
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        find.byTooltip(t.videoPlayback.pause).hitTestable(),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 1500));
      expect(
        find.byTooltip(t.videoPlayback.pause).hitTestable(),
        findsOneWidget,
        reason: 'revealing the controls starts a full new timeout',
      );
      await _openQuick(tester);
      platform.send(VideoEvent(eventType: VideoEventType.bufferingStart));
      await tester.pump(const Duration(milliseconds: 100));
      platform.send(VideoEvent(eventType: VideoEventType.bufferingEnd));
      await tester.pump(const Duration(seconds: 8));
      expect(
        find.byType(VideoPlaybackQuickPanel),
        findsOneWidget,
        reason: 'playback state events must not dismiss the active panel',
      );
      expect(
        find.byTooltip(t.videoPlayback.pause).hitTestable(),
        findsNothing,
        reason: 'ordinary controls recede behind the contextual panel',
      );
      await _chooseQuickSpeed(tester, '1.25×');
      await tester.pump(const Duration(milliseconds: 100));
      expect(platform.speeds.last, 1.25);
      expect(
        (await VideoPlaybackPreferences.read()).defaultSpeed,
        1,
        reason:
            'a current-video speed adjustment must not silently change the default',
      );
      await _closeQuick(tester);
      await tester.pump(const Duration(seconds: 4));
      expect(
        find.byTooltip(t.videoPlayback.pause).hitTestable(),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 2));
      expect(find.byTooltip(t.videoPlayback.pause).hitTestable(), findsNothing);
      platform.send(VideoEvent(eventType: VideoEventType.completed));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byTooltip(t.videoPlayback.replay), findsOneWidget);
      await tester.tap(find.byTooltip(t.videoPlayback.replay));
      await tester.pump(const Duration(milliseconds: 16));
      expect(platform.seekTargets.last, Duration.zero);
      expect(find.byTooltip(t.videoPlayback.pause), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  for (final command in ['pause', 'seek', 'speed', 'volume']) {
    testWidgets('platform $command failures have a visible recovery path', (
      tester,
    ) async {
      final session = NativePlaybackSession(
        title: 'Recoverable command',
        watchUrl: Uri.parse('https://hanime1.me/watch?v=408773'),
        sources: [
          NativePlaybackSource(
            url: Uri.parse('https://cdn.example/video.mp4'),
            label: 'auto',
            headers: const {},
          ),
        ],
        description: '',
        tags: const [],
      );
      await tester.pumpWidget(
        MaterialApp(home: NativeVideoPage(session: session)),
      );
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump(const Duration(milliseconds: 100));
      }
      platform.failCommand = command;
      if (command == 'speed') {
        await _openQuick(tester);
        await _chooseQuickSpeed(tester, '1.25×');
        await tester.pump();
        await _closeQuick(tester);
      } else if (command == 'seek') {
        await _quickSeek(tester, 10);
      } else if (command == 'volume') {
        await _openQuick(tester);
        final mute = find.widgetWithText(SwitchListTile, t.videoPlayback.mute);
        await _panelVisible(tester, mute);
        await tester.tap(mute);
        await tester.pump();
        await _closeQuick(tester);
      } else {
        await tester.tap(find.byTooltip(t.videoPlayback.pause));
      }
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      if (command == 'pause' || command == 'seek') {
        expect(find.text(t.videoPlayback.playFailed), findsOneWidget);
        platform.failCommand = null;
        final retry = find.widgetWithText(TextButton, t.common.retry);
        expect(retry.hitTestable(), findsOneWidget);
        await tester.tap(retry);
        for (var i = 0; i < 60 && platform.urls.length < 2; i++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump(const Duration(milliseconds: 100));
        expect(platform.urls.length, 2);
        expect(find.text(t.videoPlayback.playFailed), findsNothing);
      } else {
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text(t.videoPlayback.playFailed), findsNothing);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  testWidgets('screen reader users retain visible playback controls', (
    tester,
  ) async {
    final session = NativePlaybackSession(
      title: 'Accessible controls',
      watchUrl: Uri.parse('https://hanime1.me/watch?v=408773'),
      sources: [
        NativePlaybackSource(
          url: Uri.parse('https://cdn.example/video.mp4'),
          label: 'auto',
          headers: const {},
        ),
      ],
      description: '',
      tags: const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(accessibleNavigation: true),
          child: child!,
        ),
        home: NativeVideoPage(session: session),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 10));
    expect(find.byTooltip(t.videoPlayback.pause).hitTestable(), findsOneWidget);
    final surface = tester.getRect(
      find.byKey(const ValueKey('video-gesture-surface')),
    );
    await tester.tapAt(surface.topLeft + const Offset(60, 20));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byTooltip(t.videoPlayback.pause).hitTestable(), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'three-zone double tap and direct portrait fullscreen preserve playback',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = NativePlaybackSession(
        title: 'Gesture zones',
        watchUrl: Uri.parse('https://hanime1.me/watch?v=77'),
        sources: [
          NativePlaybackSource(
            url: Uri.parse('https://cdn.example/test.mp4'),
            label: 'auto',
            headers: const {},
          ),
        ],
        description: '',
        tags: const [],
      );
      await tester.pumpWidget(
        MaterialApp(home: NativeVideoPage(session: session)),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      Future<void> doubleTap(double fraction) async {
        final rect = tester.getRect(
          find.byKey(const ValueKey('video-gesture-surface')),
        );
        final point = Offset(rect.left + rect.width * fraction, rect.top + 52);
        await tester.tapAt(point);
        await tester.pump(const Duration(milliseconds: 80));
        await tester.tapAt(point);
        await tester.pump(const Duration(milliseconds: 350));
      }

      await doubleTap(0.1);
      expect(platform.seekTargets.last, Duration.zero);
      await doubleTap(0.9);
      expect(platform.seekTargets.last, const Duration(seconds: 10));
      final seeks = platform.seekTargets.length;
      final pauses = platform.pauseCount;
      await doubleTap(0.5);
      expect(platform.pauseCount, pauses + 1);
      expect(platform.seekTargets.length, seeks);
      final plays = platform.playCount;
      await doubleTap(0.5);
      expect(platform.playCount, plays + 1);
      await tester.tap(find.byTooltip(t.videoPlayback.portraitFullscreen));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byTooltip(t.videoPlayback.switchToLandscape), findsOneWidget);
      expect(platform.urls, hasLength(1));
      expect(platform.position, const Duration(seconds: 10));
      await doubleTap(0.5);
      expect(platform.pauseCount, pauses + 2);
      await tester.tap(find.byIcon(Icons.fullscreen_exit_rounded));
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        find.byTooltip(t.videoPlayback.portraitFullscreen),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('playback stays inline until fullscreen is requested', (
    tester,
  ) async {
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
    final session = NativePlaybackSession(
      title: 'Sample',
      watchUrl: Uri.parse('https://hanime1.me/watch?v=408773'),
      sources: [
        NativePlaybackSource(
          url: Uri.parse('https://cdn.example/video.mp4'),
          label: '1080p',
          headers: const {},
        ),
      ],
      description: '',
      tags: const [],
    );
    await tester.pumpWidget(
      MaterialApp(home: NativeVideoPage(session: session)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byTooltip(t.videoPlayback.fullscreen),
      findsOneWidget,
      reason: 'player should initialize; playCount=${platform.playCount}',
    );
    expect(find.byIcon(Icons.replay_10_rounded), findsNothing);
    expect(find.byIcon(Icons.forward_10_rounded), findsNothing);
    final initialPlayCount = platform.playCount;
    final initialPauseCount = platform.pauseCount;

    await tester.tap(find.byTooltip(t.videoPlayback.pause));
    await tester.pump(const Duration(milliseconds: 16));
    expect(platform.pauseCount, initialPauseCount + 1);
    expect(find.byTooltip(t.videoPlayback.play), findsOneWidget);

    await tester.tap(find.byTooltip(t.videoPlayback.play));
    await tester.pump(const Duration(milliseconds: 16));
    expect(platform.playCount, initialPlayCount + 1);
    expect(find.byTooltip(t.videoPlayback.pause), findsOneWidget);

    await _quickSeek(tester, 10);
    expect(platform.seekTargets.last, const Duration(seconds: 10));

    await _quickSeek(tester, -10);
    expect(platform.seekTargets.last, Duration.zero);

    await tester.tap(find.byTooltip(t.videoPlayback.fullscreen));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byIcon(Icons.fullscreen_exit_rounded), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));

    final surface = find.byKey(const ValueKey('video-gesture-surface'));
    final surfaceRect = tester.getRect(surface);
    final hold = await tester.startGesture(
      surfaceRect.topLeft + const Offset(200, 100),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(platform.speeds.last, 2);
    await hold.cancel();
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      platform.speeds.last,
      1,
      reason: 'an interrupted long press restores the chosen speed',
    );

    await tester.dragFrom(
      surfaceRect.topLeft + const Offset(120, 100),
      const Offset(160, 0),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(platform.seekTargets.last, greaterThan(Duration.zero));
    final swipePosition = platform.position;
    await tester.tap(find.byTooltip(t.videoPlayback.lockControls));
    await tester.pump(const Duration(milliseconds: 200));
    final seekCount = platform.seekTargets.length;
    await tester.dragFrom(
      surfaceRect.topLeft + const Offset(120, 100),
      const Offset(160, 0),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      platform.seekTargets.length,
      seekCount,
      reason: 'locked playback ignores seek gestures',
    );
    await tester.tap(find.byTooltip(t.videoPlayback.unlockControls));
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byIcon(Icons.fullscreen_exit_rounded));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byTooltip(t.videoPlayback.fullscreen), findsOneWidget);
    expect(
      platform.position,
      swipePosition,
      reason: 'leaving fullscreen must not replace or seek the player',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'rejected fullscreen request restores inline controls and can retry',
    (tester) async {
      var rejectFullscreen = true;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (rejectFullscreen &&
              call.method == 'SystemChrome.setEnabledSystemUIMode') {
            throw PlatformException(code: 'FullscreenUnavailable');
          }
          return null;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: NativeVideoPage(
            session: NativePlaybackSession(
              title: 'Sample',
              watchUrl: Uri.parse('https://example.com/watch'),
              sources: [
                NativePlaybackSource(
                  url: Uri.parse('https://cdn.example/video.mp4'),
                  label: '1080p',
                  headers: const {},
                ),
              ],
              description: '',
              tags: const [],
            ),
          ),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.byTooltip(t.videoPlayback.fullscreen));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
      expect(find.byTooltip(t.videoPlayback.fullscreen), findsOneWidget);
      expect(find.text(t.videoPlayback.actionFailed), findsOneWidget);
      expect(platform.urls, hasLength(1));
      rejectFullscreen = false;
      await tester.tap(find.byTooltip(t.videoPlayback.fullscreen));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byIcon(Icons.fullscreen_exit_rounded), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'native playback status and explicit website action are never confused',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Parent page'))),
      );
      bool? result;
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator
            .push<bool>(
              MaterialPageRoute(
                builder: (_) => NativeVideoPage(
                  session: NativePlaybackSession(
                    title: 'Example',
                    watchUrl: Uri.parse('https://hanime1.me/watch?v=1'),
                    sources: [
                      NativePlaybackSource(
                        url: Uri.parse('https://cdn.example/video.mp4'),
                        label: 'Auto',
                        headers: const {},
                      ),
                    ],
                    description: '',
                    tags: const [],
                  ),
                ),
              ),
            )
            .then((value) => result = value),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(NativeVideoPage), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(t.videoPlayback.website),
        ),
        findsNothing,
      );
      expect(result, isNull);
      await _openQuick(tester);
      await tester.pumpAndSettle();
      expect(result, isNull);
      final website = find.widgetWithText(ListTile, t.videoPlayback.backToWeb);
      await _panelVisible(tester, website);
      expect(find.text(t.videoPlayback.backToWeb), findsOneWidget);
      await tester.tap(website);
      await tester.pumpAndSettle();
      expect(result, true);
      expect(find.text('Parent page'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'API website fallback calls its owner and keeps the player route reusable',
    (tester) async {
      var opened = 0;
      final session = NativePlaybackSession(
        title: 'API movie',
        watchUrl: Uri.parse(
          'https://www.ikunzy.com/voddetail/7.html?line=one&episode=part',
        ),
        sources: const [],
        description: '',
        tags: const [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: NativeVideoPage(
            session: session,
            onOpenWebsite: () async {
              opened++;
            },
            extraFailureActions: (_, _, _) => [
              const Text('API recovery options'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('API recovery options'), findsOneWidget);
      await tester.tap(find.text(t.videoPlayback.openWebsitePlayer));
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(find.byType(NativeVideoPage), findsOneWidget);
      await tester.tap(find.text(t.videoPlayback.openWebsitePlayer));
      await tester.pumpAndSettle();
      expect(opened, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('a stalled source offers retry and website fallback', (
    tester,
  ) async {
    platform.emitInitialized = false;
    final session = NativePlaybackSession(
      title: 'Stalled',
      watchUrl: Uri.parse('https://hanime1.me/watch?v=408773'),
      sources: [
        NativePlaybackSource(
          url: Uri.parse('https://cdn.example/video.mp4'),
          label: 'auto',
          headers: const {},
        ),
      ],
      description: '',
      tags: const [],
    );
    await tester.pumpWidget(
      MaterialApp(home: NativeVideoPage(session: session)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(platform._events, isNotEmpty);
    for (var i = 0; i < 7; i++) {
      await tester.pump(const Duration(seconds: 5));
    }
    expect(
      find.text(t.videoPlayback.playFailed),
      findsOneWidget,
      reason:
          '${tester.widgetList<Text>(find.byType(Text)).map((text) => text.data).join(' | ')}; players=${platform._events.length}',
    );
    expect(find.text(t.common.retry), findsOneWidget);
    expect(find.text(t.videoPlayback.backToWeb), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'video defaults control autoplay, speed and available source choice',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'breeze.video.defaults.autoplay': false,
        'breeze.video.defaults.defaultSpeed': 1.5,
        'breeze.video.defaults.doubleTap': 'playPause',
      });
      final session = NativePlaybackSession(
        title: 'Personalized playback',
        watchUrl: Uri.parse('https://hanime1.me/watch?v=408773'),
        sources: [
          NativePlaybackSource(
            url: Uri.parse('https://cdn.example/720.mp4'),
            label: '720p',
            headers: const {},
          ),
          NativePlaybackSource(
            url: Uri.parse('https://cdn.example/1080.mp4'),
            label: '1080p',
            headers: const {},
          ),
        ],
        description: '',
        tags: const [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: NativeVideoPage(session: session, preferredSource: 'highest'),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(platform.playCount, 0);
      await _openQuick(tester);
      expect(
        tester
            .widget<VideoPlaybackQuickPanel>(
              find.byType(VideoPlaybackQuickPanel),
            )
            .speed,
        1.5,
      );
      await _closeQuick(tester);
      expect(platform.urls.single, 'https://cdn.example/1080.mp4');
      final surface = tester.getRect(
        find.byKey(const ValueKey('video-gesture-surface')),
      );
      final point = Offset(
        surface.left + surface.width * .2,
        surface.top + surface.height * .55,
      );
      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        platform.playCount,
        1,
        reason: 'the selected double-tap action plays instead of seeking',
      );
      expect(platform.seekTargets, isEmpty);
      expect(platform.speeds.last, 1.5);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('missing source keeps the detail and recovers after refresh', (
    tester,
  ) async {
    final watchUrl = Uri.parse('https://hanime1.me/watch?v=408773');
    final detailOnly = NativePlaybackSession.fromDetailResponse({
      'data': {
        'title': 'Still visible',
        'description': 'Episode summary',
        'tags': ['Anime'],
      },
    }, watchUrl: watchUrl);
    final recovered = NativePlaybackSession(
      title: 'Still visible',
      watchUrl: watchUrl,
      sources: [
        NativePlaybackSource(
          url: Uri.parse('https://cdn.example/video.mp4'),
          label: 'auto',
          headers: const {},
        ),
      ],
      description: '',
      tags: const [],
    );
    var refreshes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: NativeVideoPage(
          session: detailOnly,
          refreshSession: () async {
            refreshes++;
            return recovered;
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Still visible'), findsOneWidget);
    expect(find.text('Episode summary'), findsOneWidget);
    expect(find.text(t.videoPlayback.playFailed), findsOneWidget);
    expect(find.text(t.common.retry), findsOneWidget);
    expect(find.text(t.videoPlayback.backToWeb), findsWidgets);

    await tester.tap(find.text(t.common.retry));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(refreshes, 1);
    expect(find.byTooltip(t.videoPlayback.fullscreen), findsOneWidget);
    expect(find.text(t.videoPlayback.playFailed), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'automatic recovery skips a source whose controller cannot be created',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final sources = [
        for (final name in ['original', 'unavailable', 'working'])
          NativePlaybackSource(
            url: Uri.parse('https://cdn.example/$name.mp4'),
            label: name,
            headers: const {},
          ),
      ];
      final session = NativePlaybackSession(
        title: 'Player creation recovery',
        watchUrl: Uri.parse('https://hanime1.me/watch?v=408773'),
        sources: sources,
        description: '',
        tags: const [],
      );
      final created = <NativePlaybackSource>[];
      var rejectedOnce = false;
      await tester.pumpWidget(
        MaterialApp(
          home: NativeVideoPage(
            session: session,
            autoResourceFallback: true,
            playerFactory: (source) {
              created.add(source);
              if (source == sources[1] && !rejectedOnce) {
                rejectedOnce = true;
                throw StateError('Synthetic player creation failure');
              }
              return VideoPlayerController.networkUrl(
                source.url,
                videoPlayerOptions: VideoPlayerOptions(
                  allowBackgroundPlayback: true,
                ),
              );
            },
          ),
        ),
      );
      Future<void> settle() async {
        for (var n = 0; n < 10; n++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await settle();
      expect(platform.playCount, 1);
      platform.failCurrentSource();
      await settle();

      expect(created, sources);
      expect(platform.urls.last, sources.last.url.toString());
      expect(find.text(t.videoPlayback.playFailed), findsNothing);
      expect(platform.maxNativePlayers, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'expired source retry preserves position and ignores duplicate retry taps',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'breeze.video.defaults.defaultSpeed': 1.5,
      });
      final watch = Uri.parse('https://hanime1.me/watch?v=408773');
      NativePlaybackSession session(String address) => NativePlaybackSession(
        title: 'Resume after expiry',
        watchUrl: watch,
        sources: [
          NativePlaybackSource(
            url: Uri.parse(address),
            label: '1080p',
            headers: const {},
          ),
        ],
        description: '',
        tags: const [],
      );
      final refreshed = Completer<NativePlaybackSession>();
      var refreshCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: NativeVideoPage(
            session: session('https://cdn.example/expired.mp4'),
            refreshSession: () {
              refreshCount++;
              return refreshed.future;
            },
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump(const Duration(milliseconds: 100));
      }
      platform.position = const Duration(seconds: 42);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.tap(find.byTooltip(t.videoPlayback.fullscreen));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 100));
      platform.failCurrentSource();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text(t.videoPlayback.playFailed), findsOneWidget);
      expect(find.byTooltip(t.videoPlayback.exitFullscreen), findsOneWidget);
      await tester.tap(find.byTooltip(t.videoPlayback.exitFullscreen));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(NativeVideoPage), findsOneWidget);

      final retry = tester
          .widget<TextButton>(find.widgetWithText(TextButton, t.common.retry))
          .onPressed!;
      retry();
      retry();
      await tester.pump(const Duration(milliseconds: 16));
      expect(refreshCount, 1);
      refreshed.complete(session('https://cdn.example/refreshed.mp4'));
      for (
        var i = 0;
        i < 60 && platform.urls.last != 'https://cdn.example/refreshed.mp4';
        i++
      ) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(platform.urls.last, 'https://cdn.example/refreshed.mp4');
      expect(platform.seekTargets.last, const Duration(seconds: 42));
      expect(platform.speeds.last, 1.5);
      expect(find.text(t.videoPlayback.playFailed), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'source refresh requests human verification without losing position',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'breeze.video.defaults.recordHistory': false,
      });
      final session = NativePlaybackSession(
        title: 'Verification while playing',
        watchUrl: Uri.parse('https://hanime1.me/watch?v=408773'),
        sources: [
          NativePlaybackSource(
            url: Uri.parse('https://cdn.example/expired.mp4'),
            label: 'auto',
            headers: const {},
          ),
        ],
        description: '',
        tags: const [],
      );
      Duration? resume;
      var requests = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: NativeVideoPage(
            session: session,
            initialPosition: const Duration(seconds: 42),
            refreshSession: () async =>
                throw const VideoSiteVerificationRequired(),
            onVerifySite: (position) {
              resume = position;
              requests++;
            },
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(platform.seekTargets.last, const Duration(seconds: 42));
      platform.failCurrentSource();
      await tester.pump(const Duration(milliseconds: 16));
      platform.failPause = true;
      await tester.tap(find.widgetWithText(TextButton, t.common.retry));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text(t.videoPlayback.verificationRequired), findsOneWidget);
      expect(platform.urls, hasLength(1)); // Does not retry the expired source.
      final verify = tester
          .widget<TextButton>(
            find.widgetWithText(
              TextButton,
              t.videoPlayback.continueVerification,
            ),
          )
          .onPressed!;
      verify();
      verify();
      await tester.pump();
      expect(requests, 1);
      expect(resume, const Duration(seconds: 42));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'a stalled resume seek times out and cannot restart a replaced player',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'breeze.video.progress.hanime1.me.408773': 30000,
      });
      platform.stallSeek = true;
      final session = NativePlaybackSession(
        title: 'Stalled resume',
        watchUrl: Uri.parse('https://hanime1.me/watch?v=408773'),
        sources: [
          NativePlaybackSource(
            url: Uri.parse('https://cdn.example/video.mp4'),
            label: 'auto',
            headers: const {},
          ),
        ],
        description: '',
        tags: const [],
      );
      await tester.pumpWidget(
        MaterialApp(home: NativeVideoPage(session: session)),
      );
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(platform.pendingSeek, isNotNull);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 5));
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
      }
      expect(find.text(t.videoPlayback.playFailed), findsOneWidget);
      platform.stallSeek = false;
      await tester.tap(find.text(t.common.retry));
      for (var i = 0; i < 60 && platform.playCount == 0; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(platform.playCount, 1);
      expect(platform.position, const Duration(seconds: 30));
      platform.pendingSeek!.complete();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        platform.playCount,
        1,
        reason:
            'the old delayed seek cannot play after its load epoch was replaced',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'phone and tablet controls fit light and dark layouts with larger text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final session = NativePlaybackSession(
        title: 'Long video title for a responsive player',
        watchUrl: Uri.parse('https://hanime1.me/watch?v=408773'),
        sources: [
          NativePlaybackSource(
            url: Uri.parse('https://cdn.example/720.mp4'),
            label: '720p',
            headers: const {},
          ),
          NativePlaybackSource(
            url: Uri.parse('https://cdn.example/1080.mp4'),
            label: '1080p',
            headers: const {},
          ),
        ],
        description: 'Summary',
        tags: const ['Animation', '1080p'],
      );
      for (final style in ['system', 'breeze']) {
        SharedPreferences.setMockInitialValues({
          'breeze.video.defaults.controlsStyle': style,
        });
        for (final size in [
          const Size(320, 568),
          const Size(390, 844),
          const Size(1024, 1366),
        ]) {
          for (final brightness in Brightness.values) {
            tester.view.physicalSize = size;
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(brightness: brightness),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
                home: NativeVideoPage(
                  key: ValueKey('$style.$size.$brightness'),
                  session: session,
                ),
              ),
            );
            for (var i = 0; i < 5; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(
              tester.takeException(),
              isNull,
              reason: 'inline $size / $brightness',
            );
            expect(
              tester.getSize(find.byType(Slider)).height,
              greaterThanOrEqualTo(44),
            );
            final speedFinder = find.byType(NativeVideoTextButton).first;
            final speedContext = tester.element(speedFinder);
            final speedLabel = tester.widget<NativeVideoTextButton>(
              speedFinder,
            );
            final speedMeasure = TextPainter(
              text: TextSpan(
                text: speedLabel.label,
                style: Theme.of(
                  speedContext,
                ).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w600),
              ),
              textDirection: TextDirection.ltr,
              textScaler: MediaQuery.textScalerOf(speedContext),
            )..layout();
            expect(
              tester.getSize(speedFinder).width,
              greaterThanOrEqualTo(speedMeasure.width + 24),
              reason: 'scaled speed text must retain its content inset',
            );
            speedMeasure.dispose();
            await _openQuick(tester);
            expect(
              tester.takeException(),
              isNull,
              reason: 'large text quick panel $size / $brightness',
            );
            final portraitPanel = tester.getRect(
              find.byType(VideoPlaybackQuickPanel),
            );
            _expectDockedPanel(tester, portraitPanel, size);
            expect(portraitPanel.height, lessThan(size.height));
            expect(
              find.byTooltip(t.common.close).hitTestable(),
              findsOneWidget,
            );

            await tester.binding.handlePopRoute();
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));
            expect(find.byType(VideoPlaybackQuickPanel), findsNothing);
            expect(find.byType(NativeVideoPage), findsOneWidget);
            final slider = tester.widget<Slider>(find.byType(Slider));
            expect(slider.semanticFormatterCallback!(42000), '00:42');
            await tester.tap(find.byTooltip(t.videoPlayback.fullscreen));
            tester.view.physicalSize = Size(size.height, size.width);
            await tester.pump(const Duration(milliseconds: 100));
            expect(
              tester.takeException(),
              isNull,
              reason: 'fullscreen $size / $brightness',
            );
            await _openQuick(tester);
            expect(
              tester.takeException(),
              isNull,
              reason: 'landscape quick panel $size / $brightness',
            );
            final landscapePanel = tester.getRect(
              find.byType(VideoPlaybackQuickPanel),
            );
            _expectDockedPanel(
              tester,
              landscapePanel,
              Size(size.height, size.width),
            );
            expect(
              find.byTooltip(t.common.close).hitTestable(),
              findsOneWidget,
            );

            await tester.binding.handlePopRoute();
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));
            expect(find.byType(VideoPlaybackQuickPanel), findsNothing);
            expect(find.byIcon(Icons.fullscreen_exit_rounded), findsOneWidget);
            await tester.tap(find.byIcon(Icons.fullscreen_exit_rounded));
            await tester.pump(const Duration(milliseconds: 100));
            expect(
              tester.takeException(),
              isNull,
              reason:
                  'exit while viewport is still landscape $size / $brightness',
            );
            tester.view.physicalSize = size;
            await tester.pump(const Duration(milliseconds: 100));
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
          }
        }
      }
    },
  );

  testWidgets(
    'explicit fullscreen ignores portrait default and all three states retain playback',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'breeze.video.defaults.fullscreenOrientation': 'portrait',
        'breeze.video.defaults.cover': true,
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final session = NativePlaybackSession(
        title: 'Portrait viewing',
        watchUrl: Uri.parse('https://hanime1.me/watch?v=408773'),
        sources: [
          NativePlaybackSource(
            url: Uri.parse('https://cdn.example/video.mp4'),
            label: 'auto',
            headers: const {},
          ),
        ],
        description: '',
        tags: const [],
      );
      await tester.pumpWidget(
        MaterialApp(home: NativeVideoPage(session: session)),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(AppBar), findsNothing);
      expect(find.byTooltip(t.videoPlayback.switchToLandscape), findsNothing);
      await _quickSeek(tester, 10);
      await tester.tap(find.byTooltip(t.videoPlayback.fullscreen));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AppBar), findsNothing);
      expect(find.byTooltip(t.videoPlayback.switchToPortrait), findsOneWidget);
      await tester.tap(find.byTooltip(t.videoPlayback.switchToPortrait));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byTooltip(t.videoPlayback.switchToLandscape), findsOneWidget);
      expect(
        tester.widget<FittedBox>(find.byType(FittedBox)).fit,
        BoxFit.contain,
        reason: 'portrait fullscreen never crops a landscape video',
      );
      await tester.tap(find.byTooltip(t.videoPlayback.switchToLandscape));
      tester.view.physicalSize = const Size(844, 390);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byTooltip(t.videoPlayback.switchToPortrait), findsOneWidget);
      await tester.tap(find.byTooltip(t.videoPlayback.switchToPortrait));
      tester.view.physicalSize = const Size(390, 844);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byTooltip(t.videoPlayback.switchToLandscape), findsOneWidget);
      await tester.tap(find.byTooltip(t.videoPlayback.lockControls));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byTooltip(t.videoPlayback.unlockControls), findsOneWidget);
      await tester.tap(find.byTooltip(t.videoPlayback.unlockControls));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byIcon(Icons.fullscreen_exit_rounded));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AppBar), findsNothing);
      expect(platform.position, const Duration(seconds: 10));
      expect(platform.urls, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'backgrounding pauses playback and cancels temporary speed without auto-resume',
    (tester) async {
      final session = NativePlaybackSession(
        title: 'Background behavior',
        watchUrl: Uri.parse('https://hanime1.me/watch?v=408773'),
        sources: [
          NativePlaybackSource(
            url: Uri.parse('https://cdn.example/video.mp4'),
            label: 'auto',
            headers: const {},
          ),
        ],
        description: '',
        tags: const [],
      );
      await tester.pumpWidget(
        MaterialApp(home: NativeVideoPage(session: session)),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final surface = tester.getRect(
        find.byKey(const ValueKey('video-gesture-surface')),
      );
      final hold = await tester.startGesture(
        surface.topLeft + const Offset(70, 30),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(platform.speeds.last, 2);
      final pauses = platform.pauseCount;
      final plays = platform.playCount;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(milliseconds: 16));
      await hold.cancel();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 100));
      expect(platform.pauseCount, greaterThan(pauses));
      expect(platform.playCount, plays);
      await tester.tap(find.byTooltip(t.videoPlayback.play));
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        platform.speeds.last,
        1,
        reason: 'temporary speed is not retained after returning',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
  for (final size in [0, 1, 3]) {
    testWidgets(
      'site playlist keeps provider order at narrow large text, size=$size',
      (tester) async {
        final messenger = tester.binding.defaultBinaryMessenger;
        const connectivity = MethodChannel(
          'dev.fluttercommunity.plus/connectivity',
        );
        const status = MethodChannel(
          'dev.fluttercommunity.plus/connectivity_status',
        );
        messenger.setMockMethodCallHandler(connectivity, (_) async => ['wifi']);
        messenger.setMockMethodCallHandler(status, (_) async => null);
        addTearDown(() {
          messenger.setMockMethodCallHandler(connectivity, null);
          messenger.setMockMethodCallHandler(status, null);
        });
        SharedPreferences.setMockInitialValues({
          'breeze.video.defaults.portraitMode': 'episodes',
        });
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final cards = [
          for (final id in [31, 80, 11].take(size))
            NativeVideoCard(
              title: switch (id) {
                31 => 'A long current title from a different work Episode 30',
                80 =>
                  'Unrelated creator title Episode 2 that wraps in narrow layout',
                _ => 'Another independent title Episode 1',
              },
              watchUrl: Uri.parse('https://hanime1.me/watch?v=$id'),
              coverUrl: null,
            ),
        ];
        final watch = Uri.parse('https://hanime1.me/watch?v=31');
        NativePlaybackSession session(String media) => NativePlaybackSession(
          title: 'A playlist fixture',
          watchUrl: watch,
          sources: [
            NativePlaybackSource(
              url: Uri.parse(media),
              label: 'auto',
              headers: const {},
            ),
          ],
          description: '',
          tags: const [],
          sitePlaylist: cards,
        );
        final opens = <Uri>[];
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.55)),
              child: child!,
            ),
            home: NativeVideoPage(
              session: session('https://media.test/original.mp4'),
              refreshSession: () async =>
                  session('https://media.test/renewed.mp4'),
              onOpenVideo: opens.add,
            ),
          ),
        );
        for (var n = 0; n < 8; n++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pump(const Duration(milliseconds: 100));
        }
        final entry = find.byKey(const ValueKey('video-inline.episodes'));
        if (size == 0) {
          expect(entry, findsNothing);
        } else {
          if (size == 3) {
            platform.failCurrentSource();
            await tester.pump(const Duration(milliseconds: 100));
            final retry = find.widgetWithText(TextButton, t.common.retry);
            expect(retry, findsOneWidget);
            tester.widget<TextButton>(retry).onPressed!();
            for (var n = 0; n < 8; n++) {
              await tester.runAsync(() => Future<void>.delayed(Duration.zero));
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(platform.urls.last, 'https://media.test/renewed.mp4');
          }
          await tester.ensureVisible(entry);
          await tester.tap(entry);
          await tester.pumpAndSettle();
          final panel = find.byType(VideoPlaybackQuickPanel);
          expect(
            find.descendant(
              of: panel,
              matching: find.text(t.videoPlayback.sitePlaylist),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: panel,
              matching: find.text(t.videoPlayback.episodeAscending),
            ),
            findsNothing,
          );
          final current = find.byKey(const ValueKey('video-playlist.entry.0'));
          final title = find.descendant(
            of: current,
            matching: find.text(cards.first.title),
          );
          expect(tester.widget<Text>(title).maxLines, 2);
          expect(
            find.descendant(of: current, matching: find.byType(VideoThumbnail)),
            findsOneWidget,
          );
          expect(tester.widget<ListTile>(current).selected, isTrue);
          expect(tester.widget<ListTile>(current).onTap, isNull);
          if (size == 3) {
            final next = find.byKey(const ValueKey('video-playlist.entry.1'));
            await _panelVisible(tester, next);
            expect(
              find.descendant(of: next, matching: find.text(cards[1].title)),
              findsOneWidget,
            );
            await tester.tap(next);
            await tester.pumpAndSettle();
            expect(opens, [cards[1].watchUrl]);
            final portrait = find.byTooltip(t.videoPlayback.portraitFullscreen);
            await tester.ensureVisible(portrait);
            await tester.tap(portrait);
            await tester.pumpAndSettle();
            expect(find.byTooltip(t.videoPlayback.nextEpisode), findsNothing);
            final nextVideo = find.byTooltip(t.videoPlayback.nextPlaylistEntry);
            expect(nextVideo, findsOneWidget);
            await tester.tap(nextVideo);
            await tester.pump();
            expect(opens, [cards[1].watchUrl, cards[1].watchUrl]);
          }
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }

  testWidgets(
    'related navigation cancels a pending episode without late autoplay',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cards = [
        for (final line in ['original', 'alternate'])
          NativeVideoCard(
            title: line,
            episodeLabel: '第01集',
            coverUrl: null,
            watchUrl: Uri.parse(
              'https://fixture.test/voddetail/7.html?line=$line&episode=1',
            ),
          ),
      ];
      NativePlaybackSession session(NativeVideoCard card) =>
          NativePlaybackSession(
            title: card.title,
            watchUrl: card.watchUrl,
            sources: [
              NativePlaybackSource(
                url: Uri.parse('https://media.test/${card.title}.mp4'),
                label: 'auto',
                headers: const {},
              ),
            ],
            description: '',
            tags: const [],
            episodes: [card],
          );
      final pending = Completer<NativeEpisodeLoad>();
      final reads = <Uri>[],
          cancelled = <Uri>[],
          changes = <NativeEpisodeLoad>[];
      await tester.pumpWidget(
        MaterialApp(
          home: NativeVideoPage(
            session: session(cards.first),
            autoResourceFallback: true,
            resourceLines: (current) => [
              for (final card in cards)
                NativeVideoResourceLine(
                  id: card.title,
                  label: card.title,
                  current: card.isCurrent(current.watchUrl),
                  target: card,
                ),
            ],
            loadEpisode: (target) {
              reads.add(target);
              return pending.future;
            },
            onResolutionCancelled: cancelled.add,
            onEpisodeChanged: changes.add,
            detailBuilder: (context, current, showRelated, _, tools) => Column(
              children: [
                tools,
                TextButton(
                  onPressed: () => unawaited(
                    showRelated(
                      () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            body: Center(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Return from related'),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Open related during resolution'),
                ),
              ],
            ),
          ),
        ),
      );
      for (var n = 0; n < 8; n++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final source = find.byKey(const ValueKey('video-inline.sources'));
      await tester.ensureVisible(source);
      await tester.tap(source);
      await tester.pumpAndSettle();
      final alternate = find.byKey(
        const ValueKey('video-resource-line.alternate'),
      );
      await _panelVisible(tester, alternate);
      await tester.tap(alternate);
      for (var n = 0; n < 6; n++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(reads, [cards.last.watchUrl]);
      expect(pending.isCompleted, isFalse);
      final open = find.text('Open related during resolution');
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(find.text('Return from related'), findsOneWidget);
      expect(cancelled, [cards.last.watchUrl]);
      final plays = platform.playCount;
      pending.complete((session: session(cards.last), operations: null));
      await tester.pumpAndSettle();
      expect(platform.playCount, plays);
      expect(platform.urls, ['https://media.test/original.mp4']);
      expect(changes, isEmpty);
      await tester.tap(find.text('Return from related'));
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
      expect(platform.urls, ['https://media.test/original.mp4']);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  for (final lockWhileAway in [false, true]) {
    testWidgets(
      'related page only restores uninterrupted playback, lockWhileAway=$lockWhileAway',
      (tester) async {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        final session = NativePlaybackSession(
          title: 'Video with a related page',
          watchUrl: Uri.parse('https://hanime1.me/watch?v=408773'),
          sources: [
            NativePlaybackSource(
              url: Uri.parse('https://cdn.example/video.mp4'),
              label: 'auto',
              headers: const {},
            ),
          ],
          description: '',
          tags: const [],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: NativeVideoPage(
              session: session,
              detailBuilder: (context, _, showRelated, _, _) => Center(
                child: TextButton(
                  onPressed: () => unawaited(
                    showRelated(
                      () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (relatedContext) => Scaffold(
                            body: Center(
                              child: TextButton(
                                onPressed: () =>
                                    Navigator.of(relatedContext).pop(),
                                child: const Text('Return to video'),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Open related page'),
                ),
              ),
            ),
          ),
        );
        for (var n = 0; n < 6; n++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(platform.playCount, 1);
        await tester.tap(find.text('Open related page'));
        await tester.pumpAndSettle();
        expect(find.text('Return to video'), findsOneWidget);
        expect(platform.pauseCount, greaterThan(0));

        if (lockWhileAway) {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await tester.pump();
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump();
        }
        await tester.tap(find.text('Return to video'));
        await tester.pumpAndSettle();
        expect(platform.playCount, lockWhileAway ? 1 : 2);
        expect(platform.urls, hasLength(1));
        if (lockWhileAway) {
          await tester.tap(find.byTooltip(t.videoPlayback.play));
          await tester.pump(const Duration(milliseconds: 16));
          expect(platform.playCount, 2);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }

  testWidgets(
    'locking during media preparation cancels the previous autoplay intent',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      platform.emitInitialized = false;
      final session = NativePlaybackSession(
        title: 'Slow media',
        watchUrl: Uri.parse('https://hanime1.me/watch?v=408773'),
        sources: [
          NativePlaybackSource(
            url: Uri.parse('https://cdn.example/video.mp4'),
            label: 'auto',
            headers: const {},
          ),
        ],
        description: '',
        tags: const [],
      );
      await tester.pumpWidget(
        MaterialApp(home: NativeVideoPage(session: session)),
      );
      for (var n = 0; n < 6; n++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(platform.urls, hasLength(1));
      expect(platform.playCount, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      platform.send(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(minutes: 2),
          size: const Size(1920, 1080),
        ),
      );
      for (var n = 0; n < 6; n++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(platform.playCount, 0);
      await tester.tap(find.byTooltip(t.videoPlayback.play));
      await tester.pump(const Duration(milliseconds: 16));
      expect(platform.playCount, 1);
      expect(platform.urls, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
  for (final mode in ['initial', 'manual']) {
    for (final failure in ['creation', 'error', 'timeout']) {
      testWidgets('media fallback $mode $failure keeps target identity', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({
          'breeze.video.defaults.autoplay': false,
          'breeze.video.defaults.controlsStyle': 'breeze',
        });
        final cards = [
          for (final id in [1, 2])
            NativeVideoCard(
              title: 'Episode $id',
              watchUrl: Uri.parse('https://hanime1.me/watch?v=$id'),
              coverUrl: null,
            ),
        ];
        NativePlaybackSession episode(int id) => NativePlaybackSession(
          title: 'Episode $id',
          watchUrl: cards[id - 1].watchUrl,
          sources: [
            NativePlaybackSource(
              url: Uri.parse('https://fixture.test/$id.mp4'),
              label: 'Auto',
              headers: const {},
            ),
            NativePlaybackSource(
              url: Uri.parse('https://fixture.test/$id-480.mp4'),
              label: '480',
              headers: const {},
            ),
          ],
          description: '',
          tags: const [],
          episodes: cards,
        );
        final targetId = mode == 'initial' ? 1 : 2;
        final bad = 'https://fixture.test/$targetId.mp4';
        if (failure == 'error') {
          platform.failMediaOnce = bad;
        } else if (failure == 'timeout') {
          platform.stalledMedia.add(bad);
        }
        final changes = <NativeEpisodeLoad>[];
        final reads = <Uri>[];
        await tester.pumpWidget(
          MaterialApp(
            home: NativeVideoPage(
              session: episode(1),
              playerFactory: failure == 'creation'
                  ? (source) {
                      if (source.url.toString() == bad) {
                        throw StateError('Synthetic player creation failure');
                      }
                      return VideoPlayerController.networkUrl(source.url);
                    }
                  : null,
              onOpenVideo: (_) {},
              onEpisodeChanged: changes.add,
              loadEpisode: (url) async {
                reads.add(url);
                return (
                  session: episode(url == cards[1].watchUrl ? 2 : 1),
                  operations: null,
                );
              },
            ),
          ),
        );
        Future<void> settleMedia() async {
          for (var n = 0; n < 12; n++) {
            await tester.runAsync(() => Future<void>.delayed(Duration.zero));
            await tester.pump(const Duration(milliseconds: 100));
          }
        }

        await settleMedia();
        if (mode == 'manual') {
          await tester.tap(find.byKey(const ValueKey('video-inline.episodes')));
          await tester.pump(const Duration(milliseconds: 250));
          await tester.tap(
            find.byKey(ValueKey('episode-queue.${cards[1].watchUrl}')),
          );
          await settleMedia();
        }
        if (failure == 'timeout') {
          await tester.pump(const Duration(seconds: 26));
        }
        await settleMedia();
        expect(platform.urls.last, 'https://fixture.test/$targetId-480.mp4');
        expect(platform.maxNativePlayers, 1);
        expect(find.text(t.videoPlayback.episodeSwitchFailed), findsNothing);
        if (mode == 'manual') {
          expect(changes.single.session.watchUrl, cards[1].watchUrl);
          expect(
            reads,
            [cards[1].watchUrl],
            reason:
                'A bad target source cannot navigate back to the old episode before trying the remaining target sources',
          );
          expect(
            platform.seekTargets,
            isEmpty,
            reason:
                'A fresh target already starts at zero; do not wait on a redundant native seek',
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 6));
      });
    }
  }

  for (final outcome in [
    'success',
    'failure',
    'media-failure',
    'orientation-change',
  ]) {
    testWidgets(
      'manual episode $outcome is independent of removed swipe workflow',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'breeze.video.defaults.portraitMode': 'episodes',
          'breeze.video.defaults.autoplay': false,
          'breeze.video.defaults.controlsStyle': 'breeze',
        });
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final cards = [
          for (final id in [1, 2])
            NativeVideoCard(
              title: 'Episode $id',
              watchUrl: Uri.parse('https://hanime1.me/watch?v=$id'),
              coverUrl: null,
            ),
        ];
        NativePlaybackSession episode(
          int id, {
          bool refreshed = false,
        }) => NativePlaybackSession(
          title: 'Episode $id',
          watchUrl: cards[id - 1].watchUrl,
          sources: [
            NativePlaybackSource(
              url: Uri.parse(
                'https://fixture.test/$id${refreshed ? '-renewed' : ''}.mp4',
              ),
              label: '720p',
              headers: const {},
            ),
          ],
          description: '',
          tags: const [],
          episodes: cards,
        );
        final requests = <Uri>[];
        final changes = <NativeEpisodeLoad>[];
        final pending = Completer<NativeEpisodeLoad>();
        await tester.pumpWidget(
          MaterialApp(
            home: NativeVideoPage(
              session: episode(1),
              onOpenVideo: (_) {},
              onEpisodeChanged: changes.add,
              initialPlaybackState: (
                position: const Duration(seconds: 10),
                playing: false,
              ),
              loadEpisode: (url) async {
                requests.add(url);
                if (url == cards[0].watchUrl) {
                  return (
                    session: episode(1, refreshed: outcome == 'media-failure'),
                    operations: null,
                  );
                }
                if (outcome == 'failure') throw StateError('Read failed');
                if (outcome == 'orientation-change') return pending.future;
                return (session: episode(2), operations: null);
              },
            ),
          ),
        );
        for (var n = 0; n < 6; n++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.tap(find.byTooltip(t.videoPlayback.portraitFullscreen));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.drag(
          find.byKey(const ValueKey('video-gesture-surface')),
          const Offset(0, -200),
        );
        await tester.pump(const Duration(seconds: 1));
        expect(
          requests,
          isEmpty,
          reason:
              'Vertical swipes never change episodes, even with a saved legacy preference',
        );
        expect(platform.urls, ['https://fixture.test/1.mp4']);
        if (outcome == 'media-failure') {
          platform.failMediaOnce = 'https://fixture.test/2.mp4';
        }
        await tester.tap(find.byTooltip(t.videoPlayback.nextEpisode));
        await tester.pump(const Duration(milliseconds: 200));
        if (outcome == 'orientation-change') {
          await tester.tap(find.byIcon(Icons.fullscreen_exit_rounded));
          await tester.pump(const Duration(milliseconds: 200));
          pending.complete((session: episode(2), operations: null));
        }
        for (var n = 0; n < 8; n++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump(const Duration(milliseconds: 100));
        if (outcome == 'failure' || outcome == 'media-failure') {
          expect(changes, isEmpty);
          expect(requests, [cards[1].watchUrl, cards[0].watchUrl]);
          expect(
            platform.urls,
            outcome == 'failure'
                ? ['https://fixture.test/1.mp4']
                : [
                    'https://fixture.test/1.mp4',
                    'https://fixture.test/2.mp4',
                    'https://fixture.test/1-renewed.mp4',
                  ],
          );
          expect(platform.maxNativePlayers, 1);
          expect(platform.seekTargets.last, const Duration(seconds: 10));
          expect(
            find.text(t.videoPlayback.episodeSwitchFailed),
            findsOneWidget,
          );
          if (outcome == 'media-failure') {
            await tester.tap(find.widgetWithText(TextButton, t.common.retry));
            for (var n = 0; n < 8; n++) {
              await tester.runAsync(() => Future<void>.delayed(Duration.zero));
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(changes.single.session.watchUrl, cards[1].watchUrl);
            expect(platform.maxNativePlayers, 1);
          }
        } else {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          for (var n = 0; n < 5; n++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(changes.single.session.watchUrl, cards[1].watchUrl);
          expect(
            platform.playCount,
            0,
            reason: 'Paused intent survives a manual switch',
          );
          if (outcome != 'orientation-change') {
            final before = requests.length;
            await tester.tap(
              find.byTooltip(t.videoPlayback.nextEpisode),
              warnIfMissed: false,
            );
            await tester.pump();
            expect(requests.length, before, reason: 'Last episode never wraps');
            await tester.tap(find.byTooltip(t.videoPlayback.previousEpisode));
            for (var n = 0; n < 8; n++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            await tester.runAsync(() => Future<void>.delayed(Duration.zero));
            for (var n = 0; n < 8; n++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(changes.last.session.watchUrl, cards[0].watchUrl);
            expect(platform.seekTargets.last, const Duration(seconds: 10));
          }
        }
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          platform._events,
          hasLength(1),
          reason: 'Only the current native player is retained',
        );
        if (outcome == 'success') {
          await tester.tap(find.byTooltip(t.videoPlayback.play));
          await tester.pump(const Duration(milliseconds: 100));
          final played = platform.playCount;
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await tester.pump(const Duration(milliseconds: 100));
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump(const Duration(milliseconds: 100));
          expect(
            platform.playCount,
            played,
            reason:
                'A manually selected player follows the host pause policy and cannot auto resume',
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 6));
      },
    );
  }
  for (final scenario in [
    'empty',
    'single',
    'duplicate',
    'unknown',
    'first',
    'last',
  ]) {
    testWidgets(
      'manual episode boundary $scenario has no guessed or looping target',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'breeze.video.defaults.autoplay': false,
        });
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        NativeVideoCard card(int id) => NativeVideoCard(
          title: 'Episode $id',
          watchUrl: Uri.parse('https://hanime1.me/watch?v=$id'),
          coverUrl: null,
        );
        final id = scenario == 'unknown'
            ? 99
            : scenario == 'last'
            ? 2
            : 1;
        final cards = switch (scenario) {
          'empty' => <NativeVideoCard>[],
          'single' => [card(1)],
          'duplicate' => [card(1), card(1)],
          _ => [card(1), card(2)],
        };
        final requests = <Uri>[];
        await tester.pumpWidget(
          MaterialApp(
            home: NativeVideoPage(
              session: NativePlaybackSession(
                title: 'Episode $id',
                watchUrl: card(id).watchUrl,
                sources: [
                  NativePlaybackSource(
                    url: Uri.parse('https://fixture.test/$id.mp4'),
                    label: '720p',
                    headers: const {},
                  ),
                ],
                description: '',
                tags: const [],
                episodes: cards,
              ),
              onOpenVideo: requests.add,
            ),
          ),
        );
        for (var n = 0; n < 5; n++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.tap(find.byTooltip(t.videoPlayback.portraitFullscreen));
        await tester.pump(const Duration(milliseconds: 200));
        Finder button(String title) => find.byWidgetPredicate(
          (w) => w is NativeVideoIconButton && w.tooltip == title,
        );
        final previous = button(t.videoPlayback.previousEpisode),
            next = button(t.videoPlayback.nextEpisode);
        if (['empty', 'single', 'duplicate'].contains(scenario)) {
          expect(previous, findsNothing);
          expect(next, findsNothing);
          expect(find.text('1/1'), findsNothing);
        } else {
          expect(
            tester.widget<NativeVideoIconButton>(previous).onPressed == null,
            scenario != 'last',
          );
          expect(
            tester.widget<NativeVideoIconButton>(next).onPressed == null,
            scenario != 'first',
          );
        }
        expect(requests, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 6));
      },
    );
  }
  for (final mode in [
    'inline',
    'portrait-focus',
    'landscape',
    'portrait-legacy',
  ]) {
    testWidgets(
      'explicit episode selection commits in $mode and retry keeps intent',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'breeze.video.defaults.portraitMode': mode == 'portrait-legacy'
              ? 'episodes'
              : 'focus',
          'breeze.video.defaults.autoplay': false,
          'breeze.video.defaults.controlsStyle': 'breeze',
        });
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final cards = [
          for (final id in [1, 2])
            NativeVideoCard(
              title: 'Episode $id',
              watchUrl: Uri.parse('https://hanime1.me/watch?v=$id'),
              coverUrl: null,
            ),
        ];
        NativePlaybackSession episode(int id) => NativePlaybackSession(
          title: 'Episode $id',
          watchUrl: cards[id - 1].watchUrl,
          sources: [
            NativePlaybackSource(
              url: Uri.parse('https://fixture.test/$id.mp4'),
              label: '720p',
              headers: const {},
            ),
          ],
          description: '',
          tags: const [],
          episodes: cards,
        );
        var fail = true;
        final changes = <NativeEpisodeLoad>[];
        await tester.pumpWidget(
          MaterialApp(
            home: NativeVideoPage(
              session: episode(1),
              onOpenVideo: (_) {},
              onEpisodeChanged: changes.add,
              loadEpisode: (url) async {
                if (url == cards[1].watchUrl && fail) {
                  throw StateError('Temporary read failure');
                }
                return (
                  session: episode(url == cards[0].watchUrl ? 1 : 2),
                  operations: null,
                );
              },
            ),
          ),
        );
        for (var n = 0; n < 6; n++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        if (mode != 'inline') {
          await tester.tap(
            find.byTooltip(
              mode == 'landscape'
                  ? t.videoPlayback.fullscreen
                  : t.videoPlayback.portraitFullscreen,
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          if (mode == 'landscape') {
            tester.view.physicalSize = const Size(844, 390);
            await tester.pump(const Duration(milliseconds: 100));
          }
        }
        if (mode == 'inline') {
          await tester.tap(find.byKey(const ValueKey('video-inline.episodes')));
        } else {
          await tester.tap(find.byTooltip(t.videoPlayback.episodes));
        }
        await tester.pump(const Duration(milliseconds: 250));
        final target = find.byKey(
          ValueKey('episode-queue.${cards[1].watchUrl}'),
        );
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        for (var n = 0; n < 8; n++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(changes, isEmpty);
        expect(find.text(t.videoPlayback.episodeSwitchFailed), findsOneWidget);
        if (mode == 'portrait-focus' || mode == 'portrait-legacy') {
          expect(find.text(t.videoPlayback.minimizeShort), findsOneWidget);
          expect(find.text(t.videoPlayback.landscapeShort), findsOneWidget);
          expect(
            find.byTooltip(t.videoPlayback.exitFullscreen).last.hitTestable(),
            findsOneWidget,
          );
          expect(
            find.byTooltip(t.videoPlayback.switchToLandscape).hitTestable(),
            findsOneWidget,
          );
          final failure = tester.getRect(
            find.text(t.videoPlayback.episodeSwitchFailed),
          );
          final transport = tester.getRect(
            find.byKey(const ValueKey('video-controls.portrait-bottom')),
          );
          expect(
            failure.top,
            greaterThanOrEqualTo(
              tester
                      .getRect(
                        find.byTooltip(t.videoPlayback.exitFullscreen).first,
                      )
                      .bottom +
                  4,
            ),
            reason:
                'Error feedback must also clear the top navigation controls',
          );
          expect(
            failure.bottom,
            lessThan(transport.top),
            reason:
                'Failure feedback cannot cover the high frequency mode controls',
          );
        }
        fail = false;
        await tester.tap(find.widgetWithText(TextButton, t.common.retry));
        for (var n = 0; n < 8; n++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        for (var n = 0; n < 5; n++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          changes,
          hasLength(1),
          reason: 'Retry must retain manual intent',
        );
        expect(
          platform.maxNativePlayers,
          1,
          reason: 'Manual selection cannot retain a second live native player',
        );
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        for (var n = 0; n < 5; n++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(changes.single.session.watchUrl, cards[1].watchUrl);
        expect(platform.playCount, 0);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 6));
      },
    );
  }

  for (final style in ['breeze', 'system']) {
    testWidgets(
      'portrait focus $style single tap stays visible across gesture cancellation and ticks',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'breeze.video.defaults.portraitMode': 'episodes',
          'breeze.video.defaults.controlsStyle': style,
        });
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final session = NativePlaybackSession(
          title: 'Long episode',
          watchUrl: Uri.parse('https://hanime1.me/watch?v=1'),
          sources: [
            NativePlaybackSource(
              url: Uri.parse('https://fixture.test/long.mp4'),
              label: '720p',
              headers: const {},
            ),
          ],
          description: '',
          tags: const [],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: NativeVideoPage(
              session: session,
              loadEpisode: (_) async => (session: session, operations: null),
            ),
          ),
        );
        for (var n = 0; n < 6; n++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.tap(find.byTooltip(t.videoPlayback.portraitFullscreen));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(seconds: 6));
        final surface = find.byKey(const ValueKey('video-gesture-surface'));
        final point = tester.getRect(surface).topLeft + const Offset(180, 260);
        expect(
          find.byTooltip(t.videoPlayback.pause).hitTestable(),
          findsNothing,
        );
        await tester.tapAt(point);
        await tester.pump(const Duration(milliseconds: 100));
        platform.send(
          VideoEvent(
            eventType: VideoEventType.isPlayingStateUpdate,
            isPlaying: true,
          ),
        );
        await tester.pump(const Duration(milliseconds: 250));
        expect(
          find.byTooltip(t.videoPlayback.pause).hitTestable(),
          findsOneWidget,
          reason:
              'A tap cancelled by the unused vertical drag must not reveal then immediately hide controls',
        );
        await tester.pump(const Duration(seconds: 4));
        expect(
          find.byTooltip(t.videoPlayback.pause).hitTestable(),
          findsOneWidget,
          reason: 'A new reveal gets the full five second timeout',
        );
        await tester.pump(const Duration(seconds: 2));
        expect(
          find.byTooltip(t.videoPlayback.pause).hitTestable(),
          findsNothing,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 6));
      },
    );
  }
  testWidgets(
    'ordinary back collapses fullscreen then leaves and disposes the active player',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'breeze.video.defaults.recordHistory': false,
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => NativeVideoPage(
                      session: NativePlaybackSession(
                        title: 'Exit lifecycle',
                        watchUrl: Uri.parse('https://hanime1.me/watch?v=42'),
                        sources: [
                          NativePlaybackSource(
                            url: Uri.parse('https://fixture.test/exit.mp4'),
                            label: 'auto',
                            headers: const {},
                          ),
                        ],
                        description: '',
                        tags: const [],
                      ),
                    ),
                  ),
                ),
                child: const Text('App destination'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('App destination'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(platform._events, isNotEmpty);
      await tester.tap(
        find.byTooltip(t.videoPlayback.fullscreen).hitTestable().last,
      );
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(844, 390);
      await tester.pump();
      await tester.tap(
        find.byTooltip(t.videoPlayback.exitFullscreen).hitTestable().first,
      );
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(390, 844);
      await tester.pump();
      expect(find.byType(NativeVideoPage), findsOneWidget);
      expect(platform._events, isNotEmpty);
      expect(platform.urls, hasLength(1));
      await tester.tap(find.byTooltip(t.common.back).hitTestable().first);
      await tester.pumpAndSettle();
      expect(find.text('App destination'), findsOneWidget);
      expect(find.byType(NativeVideoPage), findsNothing);
      // VideoPlayer stream cancellation finishes outside the widget fake
      // clock; pumping frames alone does not let that teardown complete.
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      expect(
        find.byType(NativeVideoPage, skipOffstage: false),
        findsNothing,
        reason: 'the source route must be disposed, including offstage pages',
      );
      expect(platform._events, isEmpty);
    },
  );
}
