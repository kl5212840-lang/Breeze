import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/native_video_page.dart';
import 'package:zephyr/page/video/video_playback_preferences.dart';
import 'package:zephyr/page/video/video_playback_quick_panel.dart';

class _VideoPlatform extends VideoPlayerPlatform {
  final events = StreamController<VideoEvent>.broadcast();
  var disposed = false;

  @override
  Future<void> init() async {}
  @override
  Future<void> setMixWithOthers(bool value) async {}
  @override
  Future<int?> create(DataSource source) async {
    Timer.run(
      () => events.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(minutes: 2),
          size: const Size(1920, 1080),
        ),
      ),
    );
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events.stream;
  @override
  Widget buildView(int playerId) => const ColoredBox(color: Colors.black);
  @override
  Future<void> dispose(int playerId) async {
    disposed = true;
    await events.close();
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> play(int playerId) async => events.add(
    VideoEvent(eventType: VideoEventType.isPlayingStateUpdate, isPlaying: true),
  );
  @override
  Future<void> pause(int playerId) async => events.add(
    VideoEvent(
      eventType: VideoEventType.isPlayingStateUpdate,
      isPlaying: false,
    ),
  );
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
}

Future<void> _pumpPlayback(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final mode in ['inline', 'portrait', 'landscape']) {
    testWidgets(
      'More exit closes $mode player and skips nested source routes',
      (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await VideoPlaybackPreferences.save('controlsStyle', 'breeze');
        await VideoPlaybackPreferences.save('recordHistory', false);
        final platform = _VideoPlatform();
        final previousPlatform = VideoPlayerPlatform.instance;
        VideoPlayerPlatform.instance = platform;
        addTearDown(() => VideoPlayerPlatform.instance = previousPlatform);
        final uiCalls = <MethodCall>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            uiCalls.add(call);
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        var returns = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (discoverContext) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(discoverContext).push(
                    MaterialPageRoute<void>(
                      builder: (sourceContext) => Scaffold(
                        body: TextButton(
                          onPressed: () => Navigator.of(sourceContext).push(
                            MaterialPageRoute<void>(
                              builder: (_) => NativeVideoPage(
                                source: 'fixture',
                                session: NativePlaybackSession(
                                  title: 'Fixture video',
                                  watchUrl: Uri.parse(
                                    'https://fixture.test/watch?v=1',
                                  ),
                                  sources: [
                                    NativePlaybackSource(
                                      url: Uri.parse(
                                        'https://fixture.test/media.mp4',
                                      ),
                                      label: 'Fixture',
                                      headers: const {},
                                    ),
                                  ],
                                  description: '',
                                  tags: const [],
                                ),
                                onPlaybackExit: (_) => returns++,
                              ),
                            ),
                          ),
                          child: const Text('Open player'),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Discover'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Discover'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open player'));
        await _pumpPlayback(tester);
        if (mode != 'inline') {
          await tester.tap(
            find.byTooltip(
              mode == 'portrait'
                  ? t.videoPlayback.portraitFullscreen
                  : t.videoPlayback.fullscreen,
            ),
          );
          await _pumpPlayback(tester);
          if (mode == 'landscape') {
            tester.view.physicalSize = const Size(956, 440);
            await _pumpPlayback(tester);
          }
        }
        await tester.tap(find.byTooltip(t.videoPlayback.playbackSettings));
        await _pumpPlayback(tester);
        final panel = find.byType(VideoPlaybackQuickPanel);
        expect(panel, findsOneWidget);
        final exit = find.widgetWithText(ListTile, t.sourceShell.exitSource);
        await tester.scrollUntilVisible(
          exit,
          300,
          scrollable: find
              .descendant(of: panel, matching: find.byType(Scrollable))
              .first,
        );
        await tester.pumpAndSettle();
        expect(tester.getSize(exit).height, greaterThanOrEqualTo(44));
        expect(
          platform.events.hasListener,
          isTrue,
          reason: 'player is initialized before exit',
        );
        await tester.tap(exit);
        await tester.pumpAndSettle();
        // Stream cancellation can finish outside the fakeAsync zone; flush it
        // before asserting native teardown, without adding an arbitrary delay.
        await tester.runAsync(() async {});
        await tester.pump();
        expect(find.text('Discover'), findsOneWidget);
        expect(find.text('Open player'), findsNothing);
        expect(find.byType(NativeVideoPage), findsNothing);
        expect(panel, findsNothing);
        expect(VideoPlayerPlatform.instance, same(platform));
        expect(platform.disposed, isTrue);
        expect(returns, 1);
        if (mode != 'inline') {
          expect(
            uiCalls
                .where(
                  (call) =>
                      call.method == 'SystemChrome.setEnabledSystemUIMode',
                )
                .last
                .arguments,
            'SystemUiMode.edgeToEdge',
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
