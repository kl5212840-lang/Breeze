import 'dart:convert';
import 'dart:io';

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

class ApiProbeResponse {
  const ApiProbeResponse(this.status, [this.body = '']);
  final int status;
  final String body;
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

Future<ApiProbeResponse> _fetchProbe(Uri uri, String method) async {
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
      final next = uri.resolve(entries.first);
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
}) => showVideoTaskSheet<void>(
  context: context,
  builder: (_) => VideoPageAnalysis(
    analyze: () async {
      final media = session.sources.firstOrNull?.url;
      final steps = media == null
          ? ['playlist: unavailable']
          : await probeApiPlayback(media);
      final report = [
        'Breeze API playback',
        'source: $source',
        'resource_lines: $lineCount',
        'last_player_error: ${apiPlaybackErrorSummary(platformError)}',
        ...steps,
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
