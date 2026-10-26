import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/video/video_system_share.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('breeze.video.share');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });
  test(
    'share sends the canonical watch page and title, without session parameters',
    () async {
      MethodCall? received;
      messenger.setMockMethodCallHandler(channel, (call) async {
        received = call;
        return 'shared';
      });
      final result = await VideoSystemShare.share(
        video: Uri.parse(
          'https://hanime1.me/watch?v=42&__cf_chl_rt_tk=private&extra=value#fragment',
        ),
        title: '  Actual title  ',
        anchor: const Rect.fromLTWH(12, 40, 44, 44),
      );
      expect(result, VideoShareStatus.shared);
      expect(received!.method, 'share');
      expect(received!.arguments, {
        'url': 'https://hanime1.me/watch?v=42',
        'title': 'Actual title',
        'x': 12.0,
        'y': 40.0,
        'width': 44.0,
        'height': 44.0,
      });
    },
  );
  test(
    'only one sheet can be pending; cancelling does not report success',
    () async {
      var calls = 0;
      final pending = Completer<String>();
      messenger.setMockMethodCallHandler(channel, (_) {
        calls++;
        return pending.future;
      });
      Future<VideoShareStatus> share() => VideoSystemShare.share(
        video: Uri.parse('https://hanime1.me/watch?v=42'),
        title: 'Title',
        anchor: Rect.zero,
      );
      final first = share();
      expect(await share(), VideoShareStatus.busy);
      pending.complete('cancelled');
      expect(await first, VideoShareStatus.cancelled);
      expect(calls, 1);
    },
  );
  test(
    'invalid targets and unavailable platform do not invoke native sharing',
    () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (_) async {
        calls++;
        return 'shared';
      });
      for (final url in [
        'http://hanime1.me/watch?v=42',
        'https://user:secret@hanime1.me/watch?v=42',
        'https://hanime1.me/video.mp4',
        'https://hanime1.me/watch?v=no',
      ]) {
        expect(
          await VideoSystemShare.share(
            video: Uri.parse(url),
            title: 'Title',
            anchor: Rect.zero,
          ),
          VideoShareStatus.failed,
        );
      }
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(
        await VideoSystemShare.share(
          video: Uri.parse('https://hanime1.me/watch?v=42'),
          title: 'Title',
          anchor: Rect.zero,
        ),
        VideoShareStatus.unavailable,
      );
      expect(calls, 0);
    },
  );
  test(
    'Android uses the system chooser without asserting a completed share',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      MethodCall? received;
      messenger.setMockMethodCallHandler(channel, (call) async {
        received = call;
        return 'presented';
      });
      expect(
        await VideoSystemShare.share(
          video: Uri.parse('https://hanime1.me/watch?v=42&private=omit'),
          title: 'Title',
          anchor: Rect.zero,
        ),
        VideoShareStatus.presented,
      );
      expect(received!.arguments['url'], 'https://hanime1.me/watch?v=42');
    },
  );
  test('missing plugin and platform errors stay explicit failures', () async {
    Future<VideoShareStatus> share() => VideoSystemShare.share(
      video: Uri.parse('https://hanime1.me/watch?v=42'),
      title: 'Title',
      anchor: Rect.zero,
    );
    expect(await share(), VideoShareStatus.unavailable);
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'presentation'),
    );
    expect(await share(), VideoShareStatus.failed);
  });
}
