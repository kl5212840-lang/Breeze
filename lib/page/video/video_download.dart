import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:zephyr/page/video/video_download_choice.dart';

enum VideoDownloadStatus { saved, cancelled, unavailable, busy, failed }

typedef VideoDownloadProgress = ({int received, int? total, bool saving});

/// One user-initiated, foreground file transfer and system Files export.
/// Neither the signed media URL nor headers leave this transient invocation.
class VideoSystemDownload {
  static const _channel = MethodChannel('breeze.video.download');
  static int _sequence = 0;
  static VideoSystemDownload? _active;
  String? _job;

  static bool get available =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<VideoDownloadStatus> save({
    required VideoDownloadChoice choice,
    required Uri video,
    required String title,
    required ValueChanged<VideoDownloadProgress> onProgress,
  }) async {
    if (!available) return VideoDownloadStatus.unavailable;
    if (_active != null) return VideoDownloadStatus.busy;
    final media = choice.url;
    final id = video.queryParameters['v'];
    bool https(Uri value) =>
        value.scheme == 'https' &&
        value.host.isNotEmpty &&
        value.userInfo.isEmpty &&
        (!value.hasPort || value.port == 443) &&
        !value.hasFragment;
    if (!https(media) ||
        !media.path.toLowerCase().endsWith('.mp4') ||
        media.toString().length > 8192 ||
        !https(video) ||
        video.path != '/watch' ||
        !RegExp(r'^\d+$').hasMatch(id ?? '')) {
      return VideoDownloadStatus.failed;
    }
    final job = 'video-file-${++_sequence}';
    _job = job;
    _active = this;
    _channel.setMethodCallHandler((call) async {
      final args = call.arguments;
      if (call.method != 'progress' ||
          args is! Map ||
          args['id'] != job ||
          _job != job) {
        return;
      }
      final received = args['received'];
      final total = args['total'];
      if (received is! int || received < 0) return;
      onProgress((
        received: received,
        total: total is int && total > 0 ? total : null,
        saving: args['saving'] == true,
      ));
    });
    try {
      final result = await _channel.invokeMethod<String>('start', {
        'id': job,
        'url': media.toString(),
        // Never forward cookies, session parameters or CDN URL as Referer.
        'referer': video.replace(queryParameters: {'v': id!}).toString(),
        'title': title.length > 160 ? title.substring(0, 160) : title,
        'quality': choice.label,
      });
      return VideoDownloadStatus.values.firstWhere(
        (value) => value.name == result,
        orElse: () => VideoDownloadStatus.failed,
      );
    } on MissingPluginException {
      return VideoDownloadStatus.unavailable;
    } on PlatformException {
      // Native error text may contain the signed URL. Never surface or log it.
      return VideoDownloadStatus.failed;
    } finally {
      _job = null;
      _active = null;
      _channel.setMethodCallHandler(null);
    }
  }

  Future<void> cancel() async {
    final job = _job;
    if (job == null || !identical(_active, this)) return;
    try {
      await _channel.invokeMethod<void>('cancel', {'id': job});
    } on MissingPluginException {
      // The pending start invocation supplies the resulting unavailable status.
    } on PlatformException {
      // Remain pending until the native task resolves; do not report success.
    }
  }
}
