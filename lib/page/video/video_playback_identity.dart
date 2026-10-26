import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Stable page identity, never a temporary CDN URL. Legacy Hanime identities
/// retain their original shape; API libraries carry explicit line/episode IDs.
Uri? videoPlaybackIdentity(Uri uri) {
  if (uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      (uri.hasPort && uri.port != 443)) {
    return null;
  }
  if (uri.path == '/watch') {
    final id = uri.queryParameters['v'] ?? '';
    if (!RegExp(r'^\d+$').hasMatch(id)) return null;
    return Uri(
      scheme: 'https',
      host: uri.host,
      path: '/watch',
      queryParameters: {'v': id},
    );
  }
  if (!RegExp(r'^/voddetail/[1-9][0-9]{0,14}\.html$').hasMatch(uri.path)) {
    return null;
  }
  final line = uri.queryParameters['line'];
  final episode = uri.queryParameters['episode'];
  if (line == null ||
      episode == null ||
      line.isEmpty ||
      episode.isEmpty ||
      line.length > 160 ||
      episode.length > 300 ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch('$line$episode')) {
    return null;
  }
  return Uri(
    scheme: 'https',
    host: uri.host,
    path: uri.path,
    queryParameters: {'line': line, 'episode': episode},
  );
}

String videoPlaybackProgressKey(Uri uri) {
  final canonical = videoPlaybackIdentity(uri);
  if (canonical?.path == '/watch') {
    return 'breeze.video.progress.${uri.host}.${canonical!.queryParameters['v']}';
  }
  final hash = sha256.convert(utf8.encode((canonical ?? uri).toString()));
  return 'breeze.video.progress.${uri.host}.$hash';
}

/// Share public detail pages only, without media or browser query tokens.
Uri? videoPublicPage(Uri uri) {
  final identity = videoPlaybackIdentity(uri);
  if (identity?.path == '/watch') return identity;
  if (uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      (!uri.hasPort || uri.port == 443) &&
      RegExp(r'^/voddetail/[1-9][0-9]{0,14}\.html$').hasMatch(uri.path)) {
    return Uri(scheme: 'https', host: uri.host, path: uri.path);
  }
  return null;
}
