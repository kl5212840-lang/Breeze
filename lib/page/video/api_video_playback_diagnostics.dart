import 'package:zephyr/page/video/omo_network.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'dart:convert';
import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:zephyr/network/playback_trace.dart';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/http/wind_http.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/page/video/video_page_analysis.dart';

/// No account, response bodies, signed URL queries or raw exception text enter reports.
String apiPlaybackErrorSummary(String value) {
  if (value.isEmpty) return 'none';
  final lower = value.toLowerCase();
  final code = RegExp(
    r'(?<![0-9])-(?:1[0-9]{3,5})(?![0-9])',
  ).firstMatch(value)?.group(0);
  final category = lower.contains('timed') || lower.contains('timeout')
      ? 'timeout'
      : lower.contains('ssl') ||
            lower.contains('tls') ||
            lower.contains('certificate')
      ? 'tls'
      : lower.contains('format') || lower.contains('codec')
      ? 'format'
      : 'platform';
  return code == null ? category : '$category ($code)';
}

/// Only a bounded category leaves the resolver. No raw exception/URL is copied.
String apiResolutionErrorSummary(Object error) {
  if (error is ApiVideoStageFailure) {
    return '${error.stage}/${apiResolutionErrorSummary(error.cause)}';
  }
  if (error is PlatformException) {
    final safeCode = error.code
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '')
        .split('')
        .take(40)
        .join();
    return 'native_$safeCode/${apiPlaybackErrorSummary(error.message ?? '')}';
  }
  final value = error.toString();
  if (value.contains('Network session unavailable') ||
      value.contains('Network session closed')) {
    return 'session_closed';
  }
  if (RegExp(r'继续访问|安全验证|verification', caseSensitive: false).hasMatch(value)) {
    return 'site_verification';
  }
  final http = RegExp(
    r'\bHTTP\s*([45]\d{2})\b',
    caseSensitive: false,
  ).firstMatch(value);
  if (http != null) return 'http_${http.group(1)}';
  if (RegExp(
    r'超时|timeout|timed out|abort',
    caseSensitive: false,
  ).hasMatch(value)) {
    return 'timeout';
  }
  if (RegExp(r'未支持|已变化|模板|unsupported', caseSensitive: false).hasMatch(value)) {
    return 'unsupported_parser';
  }
  final kind = apiPlaybackErrorSummary(value);
  if (kind == 'platform') {
    if (error is StateError) return 'state_error';
    if (value.contains('Network session unavailable')) {
      return 'session_unavailable';
    }
    if (value.contains('target is not function')) {
      return 'plugin_function_missing';
    }
    if (value.contains('Dart') && value.contains('callback')) {
      return 'dart_bridge';
    }
    return 'runtime_error';
  }
  return kind;
}

Future<void> showApiResolutionAnalysis(
  BuildContext context, {
  required String source,
  required int lineCount,
  required List<String> attempts,
  PlaybackTrace? trace,
  Future<List<String>> Function()? recheck,
}) => showVideoTaskSheet<void>(
  context: context,
  builder: (_) => VideoPageAnalysis(
    title: t.videoPlayback.playbackAnalysis,
    analyze: () async {
      final current = recheck == null ? attempts : await recheck();
      return VideoPageAnalysisResult(
        mode: t.videoPlayback.nativeCatalog,
        page: t.videoPlayback.playbackAnalysis,
        status: current.isEmpty
            ? t.videoPlayback.playFailed
            : current.join('\n'),
        report: [
          'Breeze playback log v1',
          ...await _playbackEnvironment(),
          'source: $source',
          'resource_lines: $lineCount',
          'phase: resolution',
          ...current,
          '--- captured playback events ---',
          trace?.export() ?? 'No playback events captured.',
          'Resolution only; does not verify playback. Error messages and stacks are redacted. No request bodies, headers, account data, URL paths or queries are recorded. Local memory only; copied by user.',
        ].join('\n'),
      );
    },
    onCopy: (report) => Clipboard.setData(ClipboardData(text: report)),
  ),
);

Future<List<String>> _playbackEnvironment() async {
  String build = 'unavailable';
  try {
    final info = await PackageInfo.fromPlatform().timeout(
      const Duration(seconds: 2),
    );
    build = '${info.version}+${info.buildNumber}';
  } catch (_) {
    /* Environment lookup must never block copying an error. */
  }
  return [
    'client: $build',
    'os: ${sanitizePlaybackLog(Platform.operatingSystemVersion)}',
    'captured_at: ${DateTime.now().toUtc().toIso8601String()}',
  ];
}

class ApiProbeResponse {
  const ApiProbeResponse(this.status, [this.body = '', this.finalUrl]);
  final int status;
  final String body;
  final Uri? finalUrl;
}

typedef ApiPlaybackProbeFetch =
    Future<ApiProbeResponse> Function(Uri uri, String method);

bool _publicHttps(Uri uri) {
  if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
    return false;
  }
  final host = uri.host.toLowerCase();
  if (host == 'localhost' ||
      host.endsWith('.localhost') ||
      host.endsWith('.local')) {
    return false;
  }
  // Connectivity diagnostics are limited to public DNS names, never IP literals.
  return InternetAddress.tryParse(host) == null && host.contains('.');
}

Future<ApiProbeResponse> _fetchProbe(
  Uri uri,
  String method, {
  Map<String, String> headers = const {},
}) async {
  final response =
      await WindHttp(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 8),
        dangerAcceptInvalidCerts: false,
        followRedirects: false,
      ).fetch(
        uri.toString(),
        method: method,
        headers: {
          ...headers,
          if (method == 'GET') 'Range': 'bytes=0-524287',
          'Accept': '*/*',
        },
      );
  if (response.body.length > 524288) {
    throw const FormatException('Playlist too large');
  }
  return ApiProbeResponse(
    response.status,
    method == 'HEAD' ? '' : utf8.decode(response.body, allowMalformed: true),
    Uri.tryParse(response.url),
  );
}

/// A bounded, explicitly requested connection check. HEAD is connectivity evidence,
/// never a claim that the entire stream decoded or the device can sustain playback.
Future<List<String>> probeApiPlayback(
  Uri media, {
  ApiPlaybackProbeFetch? fetch,
}) async {
  final request = fetch ?? _fetchProbe;
  final lines = <String>[];
  var uri = media;
  for (var stage = 0; stage < 3; stage++) {
    final method = stage == 2 ? 'HEAD' : 'GET';
    final kind = stage == 0
        ? 'playlist'
        : stage == 1
        ? 'variant'
        : 'segment_headers';
    if (!_publicHttps(uri)) {
      lines.add('$kind: blocked address');
      break;
    }
    final watch = Stopwatch()..start();
    try {
      final response = await request(
        uri,
        method,
      ).timeout(const Duration(seconds: 8));
      lines.add(
        '$kind: ${uri.host}:${uri.port} HTTP ${response.status} ${watch.elapsedMilliseconds}ms',
      );
      final responseUrl = response.finalUrl ?? uri;
      if (!_publicHttps(responseUrl)) {
        lines.add('$kind: blocked response address');
        break;
      }
      if (responseUrl.host != uri.host) {
        lines.add('$kind: final_host ${responseUrl.host}:${responseUrl.port}');
      }
      if (response.status < 200 || response.status >= 300 || method == 'HEAD') {
        break;
      }
      if (!response.body.trimLeft().startsWith('#EXTM3U')) {
        lines.add('$kind: invalid HLS response');
        break;
      }
      final entries = const LineSplitter()
          .convert(response.body)
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty && !line.startsWith('#'));
      if (entries.isEmpty) {
        lines.add('$kind: no media entries');
        break;
      }
      final next = responseUrl.resolve(entries.first);
      if (response.body.contains('#EXTINF:')) {
        if (!_publicHttps(next)) {
          lines.add('segment_headers: blocked address');
          break;
        }
        final time = Stopwatch()..start();
        try {
          final segment = await request(
            next,
            'HEAD',
          ).timeout(const Duration(seconds: 8));
          lines.add(
            'segment_headers: ${next.host}:${next.port} HTTP ${segment.status} ${time.elapsedMilliseconds}ms',
          );
        } catch (error) {
          lines.add(
            'segment_headers: ${next.host}:${next.port} ${apiPlaybackErrorSummary(error.toString())} ${time.elapsedMilliseconds}ms',
          );
        }
        break;
      }
      uri = next;
    } catch (error) {
      lines.add(
        '$kind: ${uri.host}:${uri.port} ${apiPlaybackErrorSummary(error.toString())} ${watch.elapsedMilliseconds}ms',
      );
      break;
    }
  }
  return lines;
}

Future<void> showApiPlaybackAnalysis(
  BuildContext context, {
  required String source,
  required NativePlaybackSession session,
  required int lineCount,
  String platformError = '',
  OmoNetworkContext? network,
  PlaybackTrace? trace,
}) => showVideoTaskSheet<void>(
  context: context,
  builder: (_) => VideoPageAnalysis(
    title: t.videoPlayback.playbackAnalysis,
    analyze: () async {
      final media = session.sources.firstOrNull?.url;
      final steps = media == null
          ? ['playlist: unavailable']
          : await probeApiPlayback(
              media,
              fetch: (url, method) async {
                if (network == null) {
                  return _fetchProbe(
                    url,
                    method,
                    headers: session.sources.firstOrNull?.headers ?? const {},
                  );
                }
                final response = await network.start(
                  url,
                  method: method,
                  headers: session.sources.firstOrNull?.headers ?? const {},
                  timeout: const Duration(seconds: 8),
                );
                try {
                  return ApiProbeResponse(
                    response.status,
                    method == 'HEAD'
                        ? ''
                        : utf8.decode(
                            await response.bytes(524288),
                            allowMalformed: true,
                          ),
                    response.url,
                  );
                } finally {
                  await response.cancel();
                }
              },
            );
      final report = [
        'Breeze playback log v1',
        ...await _playbackEnvironment(),
        'source: $source',
        'resource_lines: $lineCount',
        'phase: playback',
        'last_player_error: ${apiPlaybackErrorSummary(platformError)}',
        'player_error_detail: ${sanitizePlaybackLog(platformError)}',
        ...steps,
        '--- captured playback events ---',
        trace?.export() ?? 'No playback events captured.',
        '--- actual player relay and setup ---',
        network?.relayDiagnostics ?? 'No source relay context available.',
        'transport_proxy: application explicit proxy only; the OS VPN/TUN route remains active.',
        'Connection checks do not verify full playback. Segment checks use HEAD; no account data, response bodies or URL queries included.',
      ].join('\n');
      return VideoPageAnalysisResult(
        mode: t.videoPlayback.nativeCatalog,
        page: t.videoPlayback.playbackAnalysis,
        status: steps.join('\n'),
        report: report,
        details: t.videoPlayback.playbackProbeNote,
      );
    },
    onCopy: (report) => Clipboard.setData(ClipboardData(text: report)),
  ),
);
