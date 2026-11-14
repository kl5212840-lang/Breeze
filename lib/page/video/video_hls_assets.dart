import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';

class HlsPortableBackupUnsupported implements Exception {
  const HlsPortableBackupUnsupported();
  @override
  String toString() => t.dataBackup.hlsNotPortable;
}

typedef VideoHlsSubtitle = ({String label, Uri fileUrl});

/// An ephemeral native read capability. Never serialize [fileUrl] or this
/// object into history, download metadata, settings, diagnostics or backups.
class VideoHlsPlaybackLease {
  VideoHlsPlaybackLease._(this.fileUrl, this.subtitles, this._releaseArguments);
  final Uri fileUrl;
  final List<VideoHlsSubtitle> subtitles;
  final Map<String, dynamic> _releaseArguments;
  Future<void>? _releasing;

  Future<void> release() => _releasing ??= () async {
    if (await VideoHlsAssets.channel.invokeMethod<Object?>(
          'releasePlayback',
          _releaseArguments,
        ) !=
        true) {
      throw StateError('HLS playback lease could not be released');
    }
  }();
}

/// Public metadata only. Native owns opaque, platform-specific HLS packages.
abstract final class VideoHlsAssets {
  static const channel = MethodChannel('breeze.video.hls');
  static bool get supported =>
      !kIsWeb &&
      const {
        TargetPlatform.iOS,
        TargetPlatform.android,
      }.contains(defaultTargetPlatform);

  static String identity(String source, Uri page, String quality) {
    final canonical = videoPlaybackIdentity(page);
    if (canonical == null || source.isEmpty || source.length > 200) {
      throw const FormatException('Invalid HLS resource identity');
    }
    return sha256
        .convert(utf8.encode('$source|$canonical|hls|$quality'))
        .toString();
  }

  static bool _token(Object? value) =>
      value is String && RegExp(r'^[A-Za-z0-9_-]{1,120}$').hasMatch(value);

  static Map<String, dynamic> validateRow(Object? value) {
    if (value is! Map) throw const FormatException('Invalid HLS metadata');
    final row = Map<String, dynamic>.from(value);
    final source = row['source'], page = row['url'], quality = row['quality'];
    final uri = page is String ? Uri.tryParse(page) : null;
    if (source is! String ||
        quality is! String ||
        quality.length > 80 ||
        uri == null ||
        videoPlaybackIdentity(uri)?.toString() != page ||
        row['resourceId'] != identity(source, uri, quality) ||
        !_token(row['assetId']) ||
        !_token(row['generation']) ||
        row['format'] != 'hls' ||
        row['title'] is! String ||
        (row['title'] as String).length > 300 ||
        row['bytes'] is! int ||
        (row['bytes'] as int) < 0 ||
        row['taskKey'] is! String ||
        row['showTask'] is! bool ||
        row['at'] is! int ||
        row['available'] is! bool ||
        row['filePresent'] is! bool) {
      throw const FormatException('Invalid HLS metadata');
    }
    // Whitelist prevents a native path or transport secret from becoming Dart
    // persistence, sync, diagnostics or a restored file authority.
    final result = <String, dynamic>{
      for (final key in const [
        'resourceId',
        'source',
        'url',
        'title',
        'quality',
        'bytes',
        'taskKey',
        'showTask',
        'at',
        'assetId',
        'generation',
        'format',
        'available',
        'filePresent',
      ])
        key: row[key],
    };
    final cover = row['cover'];
    final image = cover is String ? Uri.tryParse(cover) : null;
    if (image?.scheme == 'https' &&
        image?.host.isNotEmpty == true &&
        image?.userInfo.isEmpty == true &&
        image?.hasQuery == false &&
        image?.hasFragment == false) {
      result['cover'] = cover;
    }
    final duration = row['durationMs'], text = row['sourceDuration'];
    if (duration is int && duration > 0) result['durationMs'] = duration;
    if (text is String && text.trim().isNotEmpty && text.length <= 300)
      result['sourceDuration'] = text;
    return result;
  }

  static Future<List<Map<String, dynamic>>> read() async {
    if (!supported) return [];
    try {
      // Enumeration is read-only: a missing native reply must release the
      // caller's storage-read queue. Late replies carry no mutation authority.
      final result = await channel
          .invokeMethod<Object?>('list')
          .timeout(const Duration(seconds: 10));
      if (result is! List) throw const FormatException('Invalid HLS index');
      final rows = result.map(validateRow).toList();
      if (rows.map((row) => row['resourceId']).toSet().length != rows.length) {
        throw const FormatException('Duplicate HLS resource');
      }
      return rows;
    } on MissingPluginException {
      // Older native hosts have no HLS assets; MP4 storage remains usable.
      return [];
    }
  }

  static Map<String, dynamic> binding(Map<String, dynamic> row) => {
    'resourceId': row['resourceId'],
    'assetId': row['assetId'],
    'generation': row['generation'],
  };

  /// Only opaque bindings enter playback sessions. Native resolves a file URL
  /// after taking a generation-bound read hold when the player is created.
  static Uri playbackUri(Map<String, dynamic> row) => Uri(
    scheme: 'breeze-hls',
    host: row['assetId'] as String,
    pathSegments: [row['generation'] as String, row['resourceId'] as String],
  );

  static Future<VideoHlsPlaybackLease> acquirePlayback(
    Uri source,
    String resourceId,
  ) async {
    if (!supported ||
        source.scheme != 'breeze-hls' ||
        !_token(source.host) ||
        source.userInfo.isNotEmpty ||
        source.hasPort ||
        source.hasQuery ||
        source.hasFragment ||
        source.pathSegments.length != 2 ||
        !_token(source.pathSegments.first) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(resourceId) ||
        source.pathSegments.last != resourceId) {
      throw const FormatException('Invalid HLS playback binding');
    }
    final arguments = <String, dynamic>{
      'resourceId': resourceId,
      'assetId': source.host,
      'generation': source.pathSegments.first,
    };
    final result = await channel.invokeMethod<Object?>(
      'acquirePlayback',
      arguments,
    );
    final token = result is Map ? result['leaseId'] : null;
    final rawUrl = result is Map ? result['fileURL'] : null;
    final uri = rawUrl is String ? Uri.tryParse(rawUrl) : null;
    if (!_token(token) ||
        uri == null ||
        uri.scheme != 'file' ||
        !uri.hasAbsolutePath ||
        uri.host.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (defaultTargetPlatform == TargetPlatform.android
            ? !uri.path.endsWith('/index.m3u8')
            : !uri.path.replaceFirst(RegExp(r'/+$'), '').endsWith('.movpkg'))) {
      if (_token(token)) {
        await channel.invokeMethod<Object?>('releasePlayback', {
          ...arguments,
          'leaseId': token,
        });
      }
      throw StateError('HLS playback capability is unavailable');
    }
    final subtitles = <VideoHlsSubtitle>[];
    if (defaultTargetPlatform == TargetPlatform.android &&
        result is Map &&
        result['subtitles'] is List) {
      for (final entry in (result['subtitles'] as List).take(8)) {
        if (entry is! Map ||
            entry['name'] is! String ||
            entry['fileURL'] is! String) {
          continue;
        }
        final label = entry['name'] as String;
        final file = Uri.tryParse(entry['fileURL'] as String);
        if (label.trim().isEmpty ||
            label.length > 128 ||
            file == null ||
            !RegExp(
              r'^subtitle-[1-8]\.vtt$',
            ).hasMatch(file.pathSegments.lastOrNull ?? '') ||
            file != uri.resolve(file.pathSegments.last) ||
            subtitles.any((track) => track.fileUrl == file)) {
          continue;
        }
        subtitles.add((label: label, fileUrl: file));
      }
    }
    return VideoHlsPlaybackLease._(uri, List.unmodifiable(subtitles), {
      ...arguments,
      'leaseId': token,
    });
  }

  static Future<Map<String, dynamic>> commit(Map result) async {
    if (!_token(result['assetId']) || !_token(result['generation'])) {
      throw const FormatException('Invalid HLS candidate');
    }
    final row = validateRow(
      await channel.invokeMethod<Object?>('commit', {
        'resourceId': result['resourceId'],
        'assetId': result['assetId'],
        'generation': result['generation'],
      }),
    );
    if (row['resourceId'] != result['resourceId'] ||
        row['available'] != true ||
        row['bytes'] <= 0) {
      throw const FormatException('HLS asset was not committed');
    }
    return row;
  }

  static Future<void> discard(Map result) async {
    if (_token(result['assetId']) && _token(result['generation'])) {
      await channel.invokeMethod<Object?>('discard', {
        'assetId': result['assetId'],
        'generation': result['generation'],
      });
    }
  }

  static Future<void> delete(Map<String, dynamic> row) async {
    if (await channel.invokeMethod<Object?>('delete', binding(row)) != true) {
      throw StateError('HLS resource changed before removal');
    }
  }

  static Future<void> hideTasks(Set<String> keys) async {
    if (!supported || keys.isEmpty) return;
    try {
      await channel.invokeMethod<Object?>('hideTasks', {'keys': keys.toList()});
    } on MissingPluginException {
      /* No assets in an older host. */
    }
  }

  static Future<String?> stageRemoval(
    String source,
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return null;
    final result = await channel.invokeMethod<Object?>('stageRemoval', {
      'source': source,
      'resources': rows.map(binding).toList(),
    });
    final token = result is Map ? result['token'] : result;
    if (!_token(token)) throw StateError('HLS removal was not staged');
    return token as String;
  }

  static Future<void> finishRemoval(
    String token, {
    required bool committed,
  }) async {
    if (await channel.invokeMethod<Object?>(
          committed ? 'commitRemoval' : 'rollbackRemoval',
          {'token': token},
        ) !=
        true) {
      throw StateError('HLS removal needs recovery');
    }
  }

  static Future<Map<String, dynamic>> openOffline(
    Map<String, dynamic> row, {
    required int positionMs,
    required bool autoplay,
    required double speed,
  }) async {
    final result = await channel.invokeMethod<Object?>('openOffline', {
      ...binding(row),
      'initialPositionMs': positionMs,
      'autoplay': autoplay,
      'speed': speed,
    });
    if (result is! Map ||
        result['positionMs'] is! int ||
        result['durationMs'] is! int ||
        result['positionMs'] < 0 ||
        result['durationMs'] <= 0 ||
        result['completed'] is! bool) {
      throw StateError('Offline HLS playback did not return valid progress');
    }
    return Map<String, dynamic>.from(result);
  }
}
