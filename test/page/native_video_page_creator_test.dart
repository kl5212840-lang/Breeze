import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/native_video_page.dart';
import 'package:zephyr/page/video/video_thumbnail.dart';

/// Only replaces platform playback. This test does not contact or attest to
/// real profile navigation, image delivery, or server operations.
class _CreatorVideoPlatform extends VideoPlayerPlatform {
  final _events = <int, StreamController<VideoEvent>>{};
  final urls = <String>[];
  int _nextId = 0;

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
    Timer.run(() {
      if (!events.isClosed) {
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
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> play(int playerId) async {}
  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
}

void main() {
  final watch = Uri.parse('https://hanime1.me/watch?v=42');
  late VideoPlayerPlatform original;
  late _CreatorVideoPlatform platform;
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'breeze.video.defaults.controlsStyle': 'breeze',
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    original = VideoPlayerPlatform.instance;
    platform = _CreatorVideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });
  tearDown(() {
    VideoPlayerPlatform.instance = original;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets(
    'source-only refresh retains separate creator and uploader UI metadata',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final detail = NativePlaybackSession.fromDetailResponse({
        'data': {
          'title': 'Detail remains visible',
          'viewCountRaw': '6.2万次',
          'publishedDate': '2026-10-23',
          'ratingPercentRaw': '99%',
          'totalVotes': 210,
          'positiveVotes': 208,
          'negativeVotes': 2,
          'creator': {
            'name': 'Same display name',
            'artistId': '99',
            'profileUrl': '/user/11',
            'avatarUrl': '/creator-avatar.jpg',
          },
          'uploader': {
            'name': 'Same display name',
            'profileUrl': '/user/22',
            'avatarUrl': '/uploader-avatar.jpg',
          },
        },
      }, watchUrl: watch);
      var refreshes = 0, creatorOpens = 0, uploaderOpens = 0, worksOpens = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: NativeVideoPage(
            session: detail,
            onOpenCreator: () async {
              creatorOpens++;
            },
            onOpenUploader: () async {
              uploaderOpens++;
            },
            onOpenCreatorWorks: () async {
              worksOpens++;
            },
            refreshSession: () async {
              refreshes++;
              return NativePlaybackSession(
                title: 'Detail remains visible',
                watchUrl: watch,
                description: '',
                tags: const [],
                sources: [
                  NativePlaybackSource(
                    url: Uri.parse('https://fixture.test/refreshed.mp4'),
                    label: 'auto',
                    headers: const {},
                  ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final uploaderLabel = '${t.videoCommunity.uploader} · Same display name';
      expect(find.text('Same display name'), findsOneWidget);
      expect(find.text(uploaderLabel), findsOneWidget);
      expect(find.text(t.videoPlayback.playFailed), findsOneWidget);
      await tester.tap(find.text(t.common.retry));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(refreshes, 1);
      expect(platform.urls, ['https://fixture.test/refreshed.mp4']);
      expect(find.text(t.videoPlayback.playFailed), findsNothing);
      expect(find.text('Same display name'), findsOneWidget);
      expect(find.text(uploaderLabel), findsOneWidget);
      expect(find.text(t.videoMetadata.views(value: '6.2万次')), findsOneWidget);
      expect(find.text('2026-10-23'), findsOneWidget);
      expect(find.text(t.videoMetadata.totalVotes(count: 210)), findsOneWidget);
      expect(
        find.text(t.videoMetadata.positiveVotes(count: 208)),
        findsOneWidget,
      );
      expect(
        find.text(t.videoMetadata.negativeVotes(count: 2)),
        findsOneWidget,
      );
      final avatars = tester
          .widgetList<VideoThumbnail>(find.byType(VideoThumbnail))
          .map((widget) => widget.url)
          .toList();
      expect(
        avatars,
        containsAll([
          'https://hanime1.me/creator-avatar.jpg',
          'https://hanime1.me/uploader-avatar.jpg',
        ]),
      );
      await tester.ensureVisible(find.text('Same display name'));
      await tester.tap(find.text('Same display name'));
      await tester.ensureVisible(find.text(t.videoCommunity.viewCreatorWorks));
      await tester.tap(find.text(t.videoCommunity.viewCreatorWorks));
      await tester.ensureVisible(find.text(uploaderLabel));
      await tester.tap(find.text(uploaderLabel));
      expect(creatorOpens, 1);
      expect(worksOpens, 1);
      expect(uploaderOpens, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
