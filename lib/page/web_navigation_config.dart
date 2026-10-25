import 'dart:convert';

/// Optional, host-owned controls for a plugin web page. Only same-origin HTTPS
/// destinations are accepted, so plugin metadata cannot turn a shortcut into
/// an unexpected external site.
class WebNavigationConfig {
  const WebNavigationConfig({
    required this.homeUrl,
    this.searchUrl,
    this.playback,
  });

  final Uri homeUrl;
  final Uri? searchUrl;
  final WebPlaybackConfig? playback;

  static WebNavigationConfig? fromRouteInfo(List<String> info) {
    if (info.length < 3) return null;
    final initial = Uri.tryParse(info.length > 1 ? info[1] : '');
    if (initial == null || initial.scheme != 'https' || initial.host.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(info[2]);
      if (decoded is! Map) return null;
      Uri? validUrl(Object? value) {
        if (value is! String) return null;
        final uri = Uri.tryParse(value.trim());
        if (uri == null ||
            uri.scheme != 'https' ||
            uri.host != initial.host ||
            uri.userInfo.isNotEmpty ||
            uri.hasFragment) {
          return null;
        }
        return uri;
      }

      final home = validUrl(decoded['homeUrl']);
      if (home == null) return null;
      final playbackMap = decoded['playback'];
      WebPlaybackConfig? playback;
      if (playbackMap is Map) {
        final source = playbackMap['source']?.toString().trim() ?? '';
        final fnPath = playbackMap['fnPath']?.toString().trim() ?? '';
        final selector = playbackMap['videoSelector']?.toString().trim() ?? '';
        final playTriggerSelector =
            playbackMap['playTriggerSelector']?.toString().trim() ?? '';
        final watchPath = playbackMap['watchPath']?.toString().trim() ?? '';
        if (RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(source) &&
            RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{0,63}$').hasMatch(fnPath) &&
            selector.isNotEmpty &&
            selector.length <= 80 &&
            playTriggerSelector.length <= 120 &&
            watchPath.startsWith('/') &&
            watchPath.length <= 80 &&
            !watchPath.contains('?') &&
            !watchPath.contains('#')) {
          playback = WebPlaybackConfig(
            source: source,
            fnPath: fnPath,
            videoSelector: selector,
            playTriggerSelector: playTriggerSelector,
            watchPath: watchPath,
            origin: initial.origin,
          );
        }
      }
      return WebNavigationConfig(
        homeUrl: home,
        searchUrl: validUrl(decoded['searchUrl']),
        playback: playback,
      );
    } catch (_) {
      return null;
    }
  }
}

class WebPlaybackConfig {
  const WebPlaybackConfig({
    required this.source,
    required this.fnPath,
    required this.videoSelector,
    required this.playTriggerSelector,
    required this.watchPath,
    required this.origin,
  });

  final String source;
  final String fnPath;
  final String videoSelector;
  final String playTriggerSelector;
  final String watchPath;
  final String origin;

  bool matches(Uri? uri) =>
      uri != null &&
      uri.scheme == 'https' &&
      uri.origin == origin &&
      uri.path == watchPath;
}
