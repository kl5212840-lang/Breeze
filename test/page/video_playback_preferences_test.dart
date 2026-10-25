import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/video/video_playback_preferences.dart';

void main() {
  test(
    'restore is atomic, validates fields and retains the remote revision',
    () async {
      SharedPreferences.setMockInitialValues({
        'reader.speed': 9,
        'breeze.video.defaults.defaultSpeed': 1.25,
      });
      expect(await VideoPlaybackPreferences.modifiedAt(), 0);
      await VideoPlaybackPreferences.restore({
        'defaultSpeed': 2.0,
        'hideSeconds': 900,
        'reader.speed': 1,
        'password': 'not-a-video-field',
      }, updatedAt: 1234);
      expect((await VideoPlaybackPreferences.read()).defaultSpeed, 2);
      expect((await VideoPlaybackPreferences.read()).hideSeconds, 5);
      expect(await VideoPlaybackPreferences.modifiedAt(), 1234);
      final store = await SharedPreferences.getInstance();
      expect(store.getInt('reader.speed'), 9);
      expect(
        store.getString(VideoPlaybackPreferences.snapshotKey),
        isNot(contains('password')),
      );
      await Future.wait([
        VideoPlaybackPreferences.save('autoplay', false),
        VideoPlaybackPreferences.save('defaultSpeed', 1.5),
      ]);
      final p = await VideoPlaybackPreferences.read();
      expect(p.autoplay, isFalse);
      expect(p.defaultSpeed, 1.5);
    },
  );
  test(
    'every host preference persists and unsupported writes are rejected',
    () async {
      SharedPreferences.setMockInitialValues({});
      final values = <String, Object>{
        'autoplay': false,
        'resumeProgress': false,
        'recordHistory': false,
        'defaultSpeed': 1.25,
        'holdSpeed': 3.0,
        'doubleTap': 'off',
        'swipeSeek': false,
        'hideSeconds': 8,
        'cover': true,
        'fullscreenOrientation': 'portrait',
        'controlsStyle': 'breeze',
      };
      for (final entry in values.entries) {
        await VideoPlaybackPreferences.save(entry.key, entry.value);
      }
      final p = await VideoPlaybackPreferences.read();
      expect([
        p.autoplay,
        p.resumeProgress,
        p.recordHistory,
        p.swipeSeek,
      ], everyElement(isFalse));
      expect([p.defaultSpeed, p.holdSpeed, p.hideSeconds], [1.25, 3, 8]);
      expect(p.cover, isTrue);
      expect(p.doubleTap, 'off');
      expect(p.fullscreenOrientation, 'portrait');
      expect(p.controlsStyle, 'breeze');
      for (final entry in <String, Object>{
        'autoplay': 'yes',
        'hideSeconds': 900,
        'defaultSpeed': 100.0,
        'doubleTap': 'fake',
        'unknown': true,
        'controlsStyle': 'unrecognized',
      }.entries) {
        await expectLater(
          VideoPlaybackPreferences.save(entry.key, entry.value),
          throwsArgumentError,
        );
      }
    },
  );
  test(
    'video preferences persist independently of comic or plugin values',
    () async {
      SharedPreferences.setMockInitialValues({
        'reader.speed': 9,
        'video.defaultMode': 'website',
      });
      await VideoPlaybackPreferences.save('defaultSpeed', 1.5);
      await VideoPlaybackPreferences.save('autoplay', false);
      await VideoPlaybackPreferences.save('fullscreenOrientation', 'portrait');
      final preferences = await VideoPlaybackPreferences.read();
      expect(preferences.defaultSpeed, 1.5);
      expect(preferences.autoplay, isFalse);
      expect(preferences.fullscreenOrientation, 'portrait');
      expect(preferences.holdSpeed, 2);
      final store = await SharedPreferences.getInstance();
      expect(store.getInt('reader.speed'), 9);
      expect(store.getString('video.defaultMode'), 'website');
    },
  );

  test('unsupported settings cannot create unsafe playback values', () {
    final preferences = VideoPlaybackPreferences.fromValues({
      'defaultSpeed': 'bad',
      'holdSpeed': 900,
      'hideSeconds': -1,
      'fullscreenOrientation': 'auto-rotate',
      'controlsStyle': 'unsupported',
    });
    expect(preferences.defaultSpeed, 1);
    expect(preferences.holdSpeed, 2);
    expect(preferences.hideSeconds, 5);
    expect(preferences.fullscreenOrientation, 'landscape');
    expect(preferences.controlsStyle, 'system');
    final source = VideoSourceOptions.fromValues({
      'video.parseTimeoutSeconds': '900',
      'video.preferredSource': 'fake-line',
    });
    expect(source.parseTimeoutSeconds, 30);
    expect(source.preferredSource, 'auto');
  });
}
