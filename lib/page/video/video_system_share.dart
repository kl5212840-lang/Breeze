import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';

enum VideoShareStatus {
  shared,
  presented,
  cancelled,
  unavailable,
  busy,
  failed,
}

/// Dedicated native video sharing. Does not navigate the site, copy a link in
/// place of a share sheet, or include verification/session query parameters.
class VideoSystemShare {
  static const _channel = MethodChannel('breeze.video.share');
  static bool _pending = false;

  static Future<VideoShareStatus> share({
    required Uri video,
    required String title,
    required Rect anchor,
  }) async {
    if (kIsWeb ||
        ![
          TargetPlatform.iOS,
          TargetPlatform.android,
        ].contains(defaultTargetPlatform)) {
      return VideoShareStatus.unavailable;
    }
    if (_pending) return VideoShareStatus.busy;
    final canonical = videoPublicPage(video);
    if (canonical == null) {
      return VideoShareStatus.failed;
    }
    _pending = true;
    try {
      final result = await _channel.invokeMethod<String>('share', {
        'url': canonical.toString(),
        'title': title.trim().length > 300
            ? title.trim().substring(0, 300)
            : title.trim(),
        'x': anchor.left,
        'y': anchor.top,
        'width': anchor.width,
        'height': anchor.height,
      });
      return VideoShareStatus.values.firstWhere(
        (value) => value.name == result,
        orElse: () => VideoShareStatus.failed,
      );
    } on MissingPluginException {
      return VideoShareStatus.unavailable;
    } on PlatformException {
      return VideoShareStatus.failed;
    } finally {
      _pending = false;
    }
  }
}
