import 'dart:async';
import 'package:flutter/services.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/video/api_video_playback_diagnostics.dart';

void main() {
  test(
    'redirected playlist relatives use the actual final response directory',
    () async {
      final calls = <Uri>[];
      final result = await probeApiPlayback(
        Uri.parse('https://initial.example/old/master.m3u8?token=private'),
        fetch: (uri, method) async {
          calls.add(uri);
          if (calls.length == 1)
            return ApiProbeResponse(
              200,
              '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000\nvariant/index.m3u8\n',
              Uri.parse(
                'https://final.example/new/master.m3u8?signature=private',
              ),
            );
          if (calls.length == 2)
            return ApiProbeResponse(
              200,
              '#EXTM3U\n#EXTINF:2,\nsegment.ts?key=private\n',
              Uri.parse('https://segments.example/redirected/list.m3u8'),
            );
          return ApiProbeResponse(200, '', uri);
        },
      );
      expect(
        calls[1],
        Uri.parse('https://final.example/new/variant/index.m3u8'),
      );
      expect(
        calls[2],
        Uri.parse('https://segments.example/redirected/segment.ts?key=private'),
      );
      expect(result.join('\n'), contains('final_host final.example:443'));
      expect(result.join('\n'), isNot(contains('private')));
      expect(result.join('\n'), isNot(contains('/redirected/')));
    },
  );

  test(
    'a redirect to a private response address is not probed further',
    () async {
      var calls = 0;
      final result = await probeApiPlayback(
        Uri.parse('https://initial.example/master.m3u8'),
        fetch: (_, _) async {
          calls++;
          return ApiProbeResponse(
            200,
            '#EXTM3U\nsegment.ts\n',
            Uri.parse('https://127.0.0.1/private'),
          );
        },
      );
      expect(calls, 1);
      expect(result, contains('playlist: blocked response address'));
    },
  );

  test('resolution keeps safe failure stage and native code', () {
    expect(
      apiResolutionErrorSummary(
        ApiVideoStageFailure(
          'network_session',
          PlatformException(code: 'closed', message: 'private URL'),
        ),
      ),
      'network_session/native_closed/platform',
    );
    expect(
      apiResolutionErrorSummary(
        ApiVideoStageFailure(
          'plugin_resolution',
          StateError('HTTP 403 https://private.example/?secret=x'),
        ),
      ),
      'plugin_resolution/http_403',
    );
    expect(
      apiResolutionErrorSummary(
        PlatformException(code: 'bad / code', message: 'private'),
      ),
      'native_badcode/platform',
    );
  });
  test(
    'resolver diagnostics classify errors without copying secrets or URLs',
    () {
      expect(
        apiResolutionErrorSummary(
          StateError('HTTP 403 https://private.example/?token=secret'),
        ),
        'http_403',
      );
      expect(apiResolutionErrorSummary(StateError('播放解析服务连接超时')), 'timeout');
      expect(
        apiResolutionErrorSummary(StateError('播放器模板暂未支持')),
        'unsupported_parser',
      );
      expect(
        apiResolutionErrorSummary(
          StateError('https://private.example/?token=secret'),
        ),
        'state_error',
      );
    },
  );

  test(
    'follows the actual relative HLS variant and probes the first segment headers only',
    () async {
      final calls = <(Uri, String)>[];
      final result = await probeApiPlayback(
        Uri.parse('https://playlist.example/a/master.m3u8?secret=hidden'),
        fetch: (uri, method) async {
          calls.add((uri, method));
          return switch (calls.length) {
            1 => const ApiProbeResponse(
              200,
              '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000\nvideo/index.m3u8\n',
            ),
            2 => const ApiProbeResponse(
              200,
              '#EXTM3U\n#EXTINF:2.0,\nhttps://segment.example:65/one.ts?token=private\n',
            ),
            _ => const ApiProbeResponse(206),
          };
        },
      );
      expect(calls.map((call) => call.$2), ['GET', 'GET', 'HEAD']);
      expect(
        calls[1].$1.toString(),
        'https://playlist.example/a/video/index.m3u8',
      );
      expect(calls.last.$1.port, 65);
      expect(result.join('\n'), contains('segment.example:65 HTTP 206'));
      expect(result.join('\n'), isNot(contains('hidden')));
      expect(result.join('\n'), isNot(contains('private')));
    },
  );
  test('direct media playlist skips a redundant variant request', () async {
    var count = 0;
    await probeApiPlayback(
      Uri.parse('https://cdn.example/index.m3u8'),
      fetch: (_, method) async {
        count++;
        return method == 'GET'
            ? const ApiProbeResponse(200, '#EXTM3U\n#EXTINF:2,\npart.ts\n')
            : const ApiProbeResponse(200);
      },
    );
    expect(count, 2);
  });
  test(
    'HTTP failure and non-playlist HTML stop at the failing stage',
    () async {
      for (final response in [
        const ApiProbeResponse(403),
        const ApiProbeResponse(200, '<html>'),
      ]) {
        var count = 0;
        final value = await probeApiPlayback(
          Uri.parse('https://cdn.example/index.m3u8'),
          fetch: (_, _) async {
            count++;
            return response;
          },
        );
        expect(count, 1);
        expect(
          value.join(),
          response.status == 403
              ? contains('HTTP 403')
              : contains('invalid HLS'),
        );
      }
    },
  );
  test(
    'a timeout is actionable without leaking signed URLs or exception contents',
    () async {
      final result = await probeApiPlayback(
        Uri.parse('https://cdn.example/index.m3u8?token=secret'),
        fetch: (_, _) async => throw TimeoutException(
          'https://cdn.example/index.m3u8?token=secret Cookie=private',
        ),
      );
      expect(result.join(), contains('timeout'));
      expect(result.join(), isNot(contains('secret')));
      expect(result.join(), isNot(contains('Cookie')));
      expect(
        apiPlaybackErrorSummary(
          'CoreMediaErrorDomain -12889 URL=https://x/?token=private',
        ),
        'platform (-12889)',
      );
    },
  );
  test(
    'diagnostics never fetch loopback, private IP or insecure nested addresses',
    () async {
      var calls = 0;
      for (final target in [
        'http://cdn.example/a.m3u8',
        'https://127.0.0.1/a',
        'https://[::1]/a',
        'https://10.0.0.1/a',
        'https://[::ffff:127.0.0.1]/a',
      ]) {
        final result = await probeApiPlayback(
          Uri.parse(target),
          fetch: (_, _) async {
            calls++;
            return const ApiProbeResponse(200);
          },
        );
        expect(result.single, contains('blocked'));
      }
      expect(calls, 0);
    },
  );
}
