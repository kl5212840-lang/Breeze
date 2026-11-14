import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_download_choice.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/page/video/video_site_action_models.dart';
import 'package:zephyr/page/video/video_hls_assets.dart';

/// A snapshot of media already resolved for the selected episode. It never
/// invents a site's download API, decrypts DRM or treats HLS/DASH as an MP4.
/// Signed URLs and transport headers are held in memory only.
class VideoPlaybackDownloadAdapter {
  static VideoPlaybackDownloadAdapter? resolve(
    NativePlaybackSession session, {
    VideoPlaybackDownloadAdapter Function(NativePlaybackSession)? declared,
    bool hasWebsiteDownload = false,
  }) {
    if (declared != null) return declared(session);
    // Preserve a site's real quality/download page where one is integrated.
    if (hasWebsiteDownload) return null;
    final resolved = VideoPlaybackDownloadAdapter(session);
    return resolved.choices.isEmpty ? null : resolved;
  }

  VideoPlaybackDownloadAdapter(NativePlaybackSession session) {
    final page = videoPlaybackIdentity(session.watchUrl);
    if (page == null) return;
    final seen = <Uri>{};
    for (final source in session.sources) {
      final media = source.url;
      final hls =
          VideoHlsAssets.supported &&
          media.path.toLowerCase().endsWith('.m3u8');
      if (source.localResourceId != null ||
          !_https(media) ||
          media.hasFragment ||
          media.toString().length > 8192 ||
          (!media.path.toLowerCase().endsWith('.mp4') && !hls))
        continue;
      final headers = publicHeaders(source.headers, page);
      if (headers == null || !seen.add(media)) continue;
      var label = String.fromCharCodes(source.label.trim().runes.take(80));
      if (label.isEmpty) label = hls ? 'HLS' : 'MP4';
      if (_choices.any((c) => c.label == label)) {
        final suffix = ' · ${_choices.length + 1}';
        label =
            '${String.fromCharCodes(label.runes.take(80 - suffix.length))}$suffix';
      }
      _choices.add((label: label, url: media, format: hls ? 'hls' : 'mp4'));
      _headers[media] = Map.unmodifiable(headers);
    }
  }
  final _choices = <VideoDownloadChoice>[];
  final _headers = <Uri, Map<String, String>>{};
  List<VideoDownloadChoice> get choices => List.unmodifiable(_choices);
  Map<String, String> headersForChoice(VideoDownloadChoice choice) =>
      _headers[choice.url] ?? const {};
  Future<VideoSiteResult<List<VideoDownloadChoice>>> readChoices() async =>
      (status: VideoSiteStatus.ok, value: choices, writeUnconfirmed: false);

  static bool _https(Uri uri) =>
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      (!uri.hasPort || uri.port == 443);

  static Map<String, String>? publicHeaders(
    Map<String, String> input,
    Uri page,
  ) {
    final result = <String, String>{};
    for (final e in input.entries) {
      final name = switch (e.key.toLowerCase()) {
        'referer' => 'Referer',
        'origin' => 'Origin',
        'user-agent' => 'User-Agent',
        _ => null,
      };
      final value = e.value;
      if (name == null ||
          value.length > 2000 ||
          RegExp(r'[\x00-\x1f\x7f]').hasMatch(value))
        return null;
      if (name != 'User-Agent') {
        final uri = Uri.tryParse(value);
        if (uri == null ||
            !_https(uri) ||
            uri.origin != page.origin ||
            uri.hasFragment)
          return null;
        if (name == 'Origin') {
          if (uri.hasQuery || (uri.path.isNotEmpty && uri.path != '/'))
            return null;
          result[name] = uri.origin;
          continue;
        }
        // Do not forward private query parameters under the guise of Referer.
        if (uri.hasQuery &&
            videoPlaybackIdentity(uri) != uri &&
            videoPublicPage(uri) != uri)
          return null;
      }
      result[name] = value;
    }
    return result;
  }
}
