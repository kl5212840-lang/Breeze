import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/native_video_page.dart';
import 'package:zephyr/page/video/video_playback_preferences.dart';
import 'package:zephyr/page/video/video_playback_quick_panel.dart';
import 'package:zephyr/widgets/native_material_surface.dart';

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

  for (final side in [false, true]) {
    testWidgets('quick controls omit duplicate selectors, side=$side', (tester) async {
      await tester.pumpWidget(MaterialApp(home: SizedBox(height: 600,
        child: VideoPlaybackQuickPanel(section: VideoQuickSection.playback,
          side: side, showSeekActions: !side,
          preferences: VideoPlaybackPreferences(),
          session: NativePlaybackSession(title: 'Video', watchUrl: Uri.parse('https://fixture.test/watch'),
            sources: [NativePlaybackSource(url: Uri.parse('https://fixture.test/a.mp4'), label: 'Line A', headers: const {})], description: '', tags: const []),
          sourceIndex: 0, speed: 1, muted: false, ready: true,
          onSpeed: (_) {}, onSource: (_) {}, onPreference: (_, _) {},
          onMute: () {}, onSeek: (_) {}, onClose: () {}, onFullSettings: () {},
          onWebsite: () {}, onExitSource: () {}))));
      await tester.pumpAndSettle();
      expect(find.text(t.videoPlayback.speed), findsNothing);
      expect(find.text(t.videoPlayback.source), findsNothing);
      expect(find.byKey(const ValueKey('video-quick.rewind')), side ? findsNothing : findsOneWidget);
      expect(find.widgetWithText(SwitchListTile, t.videoPlayback.mute), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('landscape speed keeps a transparent list with immediate selection', (tester) async {
    tester.view.physicalSize = const Size(240, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    double? selected; var closed = false;
    await tester.pumpWidget(MaterialApp(home: VideoPlaybackQuickPanel(
      section: VideoQuickSection.speed, side: true,
      preferences: VideoPlaybackPreferences(),
      session: NativePlaybackSession(title: 'Video', watchUrl: Uri.parse('https://fixture.test/watch'),
        sources: const [], description: '', tags: const []),
      sourceIndex: 0, speed: 1, muted: false, ready: true,
      onSpeed: (value) => selected = value, onSource: (_) {}, onPreference: (_, _) {},
      onMute: () {}, onSeek: (_) {}, onClose: () => closed = true, onFullSettings: () {},
      onWebsite: () {}, onExitSource: () {})));
    await tester.pumpAndSettle();
    expect(find.byType(NativeMaterialSurface), findsNothing);
    await tester.tap(find.widgetWithText(ListTile, '1.5×'));
    expect(selected, 1.5); expect(closed, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets('quick panel wraps large text in $style ${brightness.name}', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 480);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final changes = <(String, Object)>[];
        final seeks = <int>[];
        final session = NativePlaybackSession(
          title: 'Fixture video',
          watchUrl: Uri.parse('https://fixture.test/watch'),
          sources: [
            NativePlaybackSource(
              url: Uri.parse('https://fixture.test/1.mp4'),
              label: 'A source label long enough to wrap across several lines',
              headers: const {},
            ),
            NativePlaybackSource(
              url: Uri.parse('https://fixture.test/2.mp4'),
              label: 'Second source',
              headers: const {},
            ),
          ],
          description: '',
          tags: const [],
        );
        for (final section in VideoQuickSection.values) {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                brightness: brightness,
                platform: TargetPlatform.iOS,
              ),
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 480),
                  textScaler: TextScaler.linear(2.5),
                  viewInsets: EdgeInsets.only(bottom: 120),
                ),
                child: Scaffold(
                  body: SizedBox(
                    height: 340,
                    child: VideoPlaybackQuickPanel(
                      section: section,
                      preferences: VideoPlaybackPreferences(
                        controlsStyle: style,
                      ),
                      session: session,
                      sourceIndex: 0,
                      speed: 1,
                      muted: false,
                      ready: true,
                      onSpeed: (_) {},
                      onSource: (_) {},
                      onPreference: (key, value) => changes.add((key, value)),
                      onMute: () {},
                      onSeek: seeks.add,
                      onClose: () {},
                      onFullSettings: () {},
                      onWebsite: () {},
                      onExitSource: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byTooltip(t.common.close).hitTestable(), findsOneWidget);
          if (section == VideoQuickSection.speed) {
            expect(find.byType(ChoiceChip), findsNothing);
            expect(find.widgetWithText(ListTile, '1.25×'), findsOneWidget);
          }
          final scrollable = find.byType(Scrollable).first;
          if (section == VideoQuickSection.episodes) {
            expect(find.text(t.videoPlayback.source), findsNothing);
            expect(find.text('Second source'), findsNothing);
          }
          if (section == VideoQuickSection.playback) {
            for (final key in [
              'video-quick.rewind',
              'video-quick.forward',
              'video-quick.controls-style',
              'video-quick.swipe-seek',
              'video-quick.hold-speed',
              'video-quick.double-tap',
            ]) {
              final option = find.byKey(ValueKey(key));
              await tester.scrollUntilVisible(
                option,
                100,
                scrollable: scrollable,
              );
              await tester.pumpAndSettle();
              expect(option, findsOneWidget);
              expect(tester.getSize(option).height, greaterThanOrEqualTo(44));
              if (key == 'video-quick.rewind' || key == 'video-quick.forward') {
                await tester.tap(option);
                await tester.pumpAndSettle();
                expect(seeks.last, key == 'video-quick.rewind' ? -10 : 10);
              }
            }
            tester.state<ScrollableState>(scrollable).position.jumpTo(0);
            await tester.pumpAndSettle();
            final fit = find.widgetWithText(
              SwitchListTile,
              t.videoPlayback.coverVideo,
            );
            await tester.scrollUntilVisible(fit, 100, scrollable: scrollable);
            final fitSwitch = find.descendant(
              of: fit,
              matching: find.byWidgetPredicate(
                (widget) => widget is Switch || widget is CupertinoSwitch,
              ),
            );
            await tester.ensureVisible(fitSwitch);
            await tester.pumpAndSettle();
            expect(fitSwitch.hitTestable(), findsOneWidget);
            await tester.tap(fitSwitch);
            await tester.pump();
            expect(changes.last, ('cover', true));
            expect(tester.getSize(fit).height, greaterThanOrEqualTo(44));
            final exit = find.widgetWithText(
              ListTile,
              t.sourceShell.exitSource,
            );
            for (
              var step = 0;
              step < 50 && exit.hitTestable().evaluate().isEmpty;
              step++
            ) {
              await tester.drag(scrollable, const Offset(0, -100));
              await tester.pumpAndSettle();
            }
            expect(exit.hitTestable(), findsOneWidget);
            expect(
              find.byTooltip(t.common.close).hitTestable(),
              findsOneWidget,
            );
          }
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

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
        final panelRect = tester.getRect(panel);
        final viewport =
            tester.view.physicalSize / tester.view.devicePixelRatio;
        if (mode == 'landscape') {
          expect(panelRect.width, lessThanOrEqualTo(viewport.width * .45 + .01));
          expect(panelRect.left, greaterThanOrEqualTo(viewport.width * .55 - .01));
        } else {
          expect(panelRect.left, closeTo(0, .01));
        }
        expect(panelRect.right, closeTo(viewport.width, .01));
        expect(panelRect.bottom, closeTo(viewport.height, .01));
        if (mode != 'landscape') {
          expect(panelRect.top, greaterThanOrEqualTo(viewport.width * 9 / 16));
        }
        expect(tester.widget<VideoPlaybackQuickPanel>(panel).floating, isFalse);
        expect(tester.widget<VideoPlaybackQuickPanel>(panel).side, mode == 'landscape');
        expect(platform.disposed, isFalse);

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
