import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data' show BytesBuilder;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:zephyr/network/source_network_policy.dart';
import 'package:zephyr/network/playback_trace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/page/video/omo_network.dart';
import 'package:zephyr/page/video/video_download_resolution.dart';
import 'package:zephyr/page/video/video_seek_preview_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('breeze.video.network');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    OmoNetworkContext.active = null;
  });

  test(
    'HLS diagnostic roles distinguish keys, maps and actual media references',
    () {
      final roles = <String>[];
      final result = omoRewritePlaylist(
        '#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI="private.key"\n#EXT-X-MAP:URI="init.mp4"\n#EXTINF:1,\nsegment.m4s\n',
        Uri.parse('https://cdn.example/redacted/list.m3u8'),
        (_) => throw StateError('typed callback must own the rewrite'),
        localTyped: (_, role) {
          roles.add(role);
          return '/local';
        },
      );
      expect(roles, ['key', 'map', 'segment']);
      expect(result, isNot(contains('private.key')));
      expect(result, isNot(contains('cdn.example')));
    },
  );

  for (final failBody in [false, true]) {
    test(
      'actual relay GET records bounded body/failure evidence failBody=$failBody',
      () async {
        final overrides = HttpOverrides.current;
        HttpOverrides.global = null;
        var reads = 0;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'start')
            return {
              'status': 200,
              'url':
                  'https://final.example/private/segment.ts?token=never-copy',
              'headers': {'content-type': 'video/mp2t', 'content-length': '4'},
            };
          if (call.method == 'read') {
            if (failBody)
              throw PlatformException(
                code: 'network',
                message: 'Connection failed (-1005) secret=never-copy',
              );
            return reads++ == 0 ? Uint8List.fromList([1, 2, 3, 4]) : null;
          }
          return null;
        });
        final context = OmoNetworkContext('relay-private-token');
        final client = HttpClient()..findProxy = (_) => 'DIRECT';
        await context.prepare();
        final player = context.player(
          Uri.parse(
            'https://requested.example/private/segment.ts?token=never-copy',
          ),
          {},
        );
        try {
          final response = await (await client.getUrl(
            Uri.parse(player.dataSource),
          )).close();
          final body = await response.fold<List<int>>(
            [],
            (bytes, part) => bytes..addAll(part),
          );
          expect(response.statusCode, failBody ? 502 : 200);
          expect(body, failBody ? isEmpty : [1, 2, 3, 4]);
          final report = context.relayDiagnostics;
          expect(
            report,
            contains('begin; method=GET; host=requested.example:443'),
          );
          expect(report, contains('status=200; final_host=final.example:443'));
          if (failBody) {
            expect(
              report,
              contains('fail; category=native_-1005; body_bytes=0'),
            );
          } else {
            expect(report, contains('first_body_ms='));
            expect(report, contains('done; category=none; body_bytes=4'));
          }
          expect(report, isNot(contains('never-copy')));
          expect(report, isNot(contains('/private/')));
          expect(report, isNot(contains('relay-private-token')));
        } finally {
          await player.dispose();
          await context.close();
          client.close(force: true);
          HttpOverrides.global = overrides;
        }
      },
    );
  }

  test(
    'valid source fallback image remains displayable after redirect',
    () async {
      final context = OmoNetworkContext('source-fallback-image');
      final methods = <String>[];
      var reads = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        methods.add(call.method);
        if (call.method == 'start') {
          return {
            'status': 200,
            'url': 'https://as.cfhls.top/avatar/default_headimg.png',
            'headers': <String, String>{'content-type': 'image/png'},
          };
        }
        if (call.method == 'read' && reads++ == 0) {
          return Uint8List.fromList([1, 2, 3]);
        }
        return null;
      });
      expect(
        await context.bytes(
          Uri.parse('https://as.cfhls.top/upload/vod/missing.jpg'),
        ),
        [1, 2, 3],
      );
      expect(methods, contains('read'));
      expect(methods, contains('cancel'));
      await context.close();
    },
  );

  test(
    'bridge entry rejection retains exact pre-HTTP error and validation state',
    () async {
      final context = OmoNetworkContext('entry-diagnostics');
      final trace = PlaybackTrace();
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return null;
      });
      await trace.run(omoNetworkSource, () async {
        await expectLater(
          OmoNetworkContext.bridgeFetch(
            jsonEncode([
              'bundle:$omoNetworkSource',
              {
                'context': context.token,
                'request': 'invalid.request',
                'timeout': 8000,
                'url': 'https://site.example/private?token=never-record',
              },
            ]),
          ),
          throwsFormatException,
        );
      });
      expect(calls, isEmpty, reason: 'Validation rejected before native HTTP');
      final report = trace.export();
      expect(report, contains('sessionFound=true'));
      expect(report, contains('sourceMatches=true'));
      expect(report, contains('requestValid=false'));
      expect(report, contains('jobs=0'));
      expect(
        report,
        contains('dart_transport_entry FormatException: Invalid request'),
      );
      expect(report, isNot(contains('never-record')));
      await context.close();
    },
  );

  test(
    'overlapping visits share the source route with idempotent owners',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      SourceNetworkPolicies.initialize(() => const ProxySettingState());
      final opened = <Map>[];
      final closed = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'supported') return true;
        final args = call.arguments as Map;
        if (call.method == 'open') {
          opened.add(args);
          return 'native-${opened.length}';
        }
        if (call.method == 'close') closed.add(args['context'] as String);
        return null;
      });
      const otherSource = '00000000-0000-0000-0000-000000000002';
      Future<OmoNetworkContext?> open(String source) => OmoNetworkContext.open(
        null,
        source: source,
        siteOrigins: [Uri.parse('https://site.example/path')],
      );
      final visits = await Future.wait([
        open(omoNetworkSource),
        open(omoNetworkSource),
        open(otherSource),
      ]);
      final first = visits[0]!, second = visits[1]!, other = visits[2]!;
      expect(identical(first, second), isFalse);
      expect(first.token, second.token);
      expect(other.token, isNot(first.token));
      expect(opened.length, 2);
      expect(
        opened.every(
          (args) =>
              (args['siteOrigins'] as List).single == 'https://site.example',
        ),
        isTrue,
      );
      await SourceNetworkPolicies.save(
        omoNetworkSource,
        const SourceNetworkPreference(
          mode: SourceNetworkMode.proxy,
          address: 'proxy.example.invalid:17897',
        ),
      );
      final stillPinned = (await open(omoNetworkSource))!;
      expect(stillPinned.token, first.token);
      await first.close();
      await first.close();
      expect(closed, isEmpty);
      await second.close();
      expect(closed, isEmpty);
      await stillPinned.close();
      expect(closed, [first.token]);
      final reopened = (await open(omoNetworkSource))!;
      expect(opened.last['proxy'], 'http://proxy.example.invalid:17897');
      expect(reopened.token, isNot(first.token));
      await reopened.close();
      await other.close();
      expect(closed.length, 3);
    },
  );

  test(
    'policy resolves once, validates proxy endpoints and stays device-local',
    () async {
      const global = ProxySettingState(
        enabled: true,
        address: 'proxy.example.invalid:17897',
      );
      expect(
        const OmoNetworkPreference().effectiveProxy(global),
        'http://proxy.example.invalid:17897',
      );
      expect(
        const OmoNetworkPreference(
          mode: OmoNetworkMode.system,
        ).effectiveProxy(global),
        '',
      );
      const custom = OmoNetworkPreference(
        mode: OmoNetworkMode.proxy,
        address: '127.0.0.1:1082',
        socks: true,
      );
      expect(custom.effectiveProxy(global), 'socks5://127.0.0.1:1082');
      await custom.save();
      final restored = await OmoNetworkPreference.read();
      expect(restored.effectiveProxy(global), custom.effectiveProxy(global));
      for (final invalid in [
        'localhost',
        'localhost:0',
        'https://localhost:1082',
        'http://user:password@localhost:1082',
        'localhost:1082/path',
        'localhost:1082?q=secret',
      ]) {
        expect(
          () => OmoNetworkPreference.proxyUrl(invalid, false),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'HLS rewrites variants, audio, maps, keys and byte-range media after redirects',
    () {
      final upstream = <Uri>[];
      final body = omoRewritePlaylist(
        '''#EXTM3U
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="a",URI="../audio/index.m3u8?token=a"
#EXT-X-SESSION-KEY:METHOD=AES-128,URI="https://keys.example/key?id=1"
#EXT-X-STREAM-INF:BANDWIDTH=123,AUDIO="a"
variant/index.m3u8?t=v
#EXT-X-MAP:URI="init.mp4"
#EXT-X-KEY:METHOD=AES-128,URI="key.bin"
#EXT-X-BYTERANGE:64@0
segment.mp4?s=secret
#EXT-X-PART:DURATION=0.5,URI="part.m4s"
#EXT-X-PRELOAD-HINT:TYPE=PART,URI="next.m4s"
''',
        Uri.parse('https://redirect.example/final/master.m3u8'),
        (uri) {
          upstream.add(uri);
          return '/opaque${upstream.length}';
        },
      );
      expect(upstream, hasLength(8));
      expect(
        upstream.first.toString(),
        'https://redirect.example/audio/index.m3u8?token=a',
      );
      expect(
        upstream[2].toString(),
        'https://redirect.example/final/variant/index.m3u8?t=v',
      );
      expect(body, contains('#EXT-X-BYTERANGE:64@0'));
      expect(body, isNot(contains('https://')));
      expect(body, isNot(contains('secret')));
      for (final invalid in [
        '#EXTM3U\nhttp://cdn.example/video.ts',
        '#EXTM3U\n#EXT-X-CONTENT-STEERING:SERVER-URI="https://cdn.example/a.json"',
        '#EXTM3U\n#EXT-X-KEY:METHOD=SAMPLE-AES,URI="skd://key"',
        '#EXTM3U\n#EXT-X-DEFINE:NAME="host",VALUE="x"',
      ]) {
        expect(
          () => omoRewritePlaylist(
            invalid,
            Uri.parse('https://cdn.example/a.m3u8'),
            (_) => '/local',
          ),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'loopback reuses verified VOD segments without sharing keys or byte ranges',
    () async {
      final savedOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      final chunks = <String, List<Uint8List>>{};
      final starts = <Map<dynamic, dynamic>>[];
      final cancelled = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        final args = call.arguments as Map;
        if (call.method == 'close') return null;
        if (call.method == 'cancel') {
          cancelled.add(args['request'] as String);
          chunks.remove(args['request']);
          return null;
        }
        if (call.method == 'read') {
          final queue = chunks[args['request']]!;
          return queue.isEmpty ? null : queue.removeAt(0);
        }
        starts.add(args);
        expect(args['siteCookies'], isFalse);
        final url = Uri.parse(args['url'] as String);
        final master = url.path.endsWith('/master');
        final playlist = master || url.path.endsWith('.m3u8');
        final body = master
            ? '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=10\nvariant.m3u8\n'
            : url.path.endsWith('variant.m3u8')
            ? '#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI="key.bin"\n#EXTINF:1,\nseg.mp4\n#EXTINF:1,\nprivate.mp4\n#EXT-X-ENDLIST\n'
            : '12345678';
        chunks[args['request'] as String] = [
          Uint8List.fromList(utf8.encode(body)),
        ];
        final range = (args['headers'] as Map)['Range'];
        return {
          'status': range != null ? 206 : 200,
          'url': 'https://final.example/${url.pathSegments.last}',
          'headers': {
            'content-type': playlist
                ? 'application/vnd.apple.mpegurl'
                : 'video/mp4',
            'content-length': '${utf8.encode(body).length}',
            if (range != null) 'content-range': 'bytes 0-7/80',
            if (url.path.endsWith('private.mp4')) 'cache-control': 'no-store',
          },
        };
      });
      final context = OmoNetworkContext('visit');
      await context.prepare();
      final controller = context.player(
        Uri.parse('https://cdn.example/master?secret=1'),
        {'Referer': 'https://www.omofuna.com/'},
      );
      final client = HttpClient()..findProxy = (_) => 'DIRECT';
      Future<String> get(Uri url, {bool range = false}) async {
        final request = await client.getUrl(url);
        if (range) request.headers.set('Range', 'bytes=0-7');
        final response = await request.close();
        if (range) {
          expect(response.statusCode, 206);
          expect(response.headers.value('content-range'), 'bytes 0-7/80');
        }
        return utf8.decode(
          await response.fold<List<int>>([], (all, part) => all..addAll(part)),
        );
      }

      try {
        final root = Uri.parse(controller.dataSource);
        expect(root.host, '127.0.0.1');
        expect(root.toString(), isNot(contains('secret')));
        final master = await get(root);
        expect(await get(root), master);
        expect(controller.formatHint?.name, 'hls');
        final head = await (await client.headUrl(root)).close();
        expect(head.contentLength, utf8.encode(master).length);
        await head.drain<void>();
        final variantPath = master
            .split('\n')
            .firstWhere((line) => line.startsWith('/'));
        final variant = await get(root.resolve(variantPath));
        expect(await get(root.resolve(variantPath)), variant);
        final key = RegExp('URI="([^"]+)"').firstMatch(variant)![1]!;
        await get(root.resolve(key));
        await get(root.resolve(key));
        final segments = variant
            .split('\n')
            .where((line) => line.startsWith('/'))
            .toList();
        final segment = root.resolve(segments.first);
        expect(await get(segment, range: true), '12345678');
        expect(await get(segment, range: true), '12345678');
        expect(await get(segment), '12345678');
        await get(root.resolve(segments.last));
        await get(root.resolve(segments.last));
        expect(starts.every((args) => args['context'] == 'visit'), isTrue);
        expect(starts.map((args) => Uri.parse(args['url'] as String).host), [
          'cdn.example', // The multivariant playlist is fetched on each GET.
          'cdn.example',
          'cdn.example', // HEAD still verifies the current playlist.
          'final.example', // The VOD playlist itself is reusable.
          'final.example', // Encryption keys are requested each time.
          'final.example',
          'final.example', // The same segment and Range use the prior response.
          'final.example', // A whole segment has a distinct cache key.
          'final.example', // no-store applies to media segments as well.
          'final.example',
        ]);
        expect(
          starts.last['headers'],
          containsPair('Referer', 'https://www.omofuna.com/'),
        );
        expect(cancelled, hasLength(10));
        await controller.dispose();
        final expired = await (await client.getUrl(root)).close();
        expect(expired.statusCode, 404);
        await expired.drain<void>();
      } finally {
        client.close(force: true);
        await context.close();
        HttpOverrides.global = savedOverrides;
      }
    },
  );

  test(
    'loopback replays only fresh exact ranges within a progressive lease',
    () async {
      final savedOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      final chunks = <String, Uint8List>{};
      final ranges = <String>[];
      var tag = '"first"';
      var total = 32;
      var cacheControl = 'max-age=15';
      var mime = 'video/mp4';
      var malformed = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        final args = call.arguments as Map;
        if (call.method == 'close') return null;
        final id = args['request'] as String;
        if (call.method == 'read' || call.method == 'cancel') {
          final chunk = chunks.remove(id);
          return call.method == 'read' ? chunk : null;
        }
        final range = (args['headers'] as Map)['Range'] as String;
        ranges.add(range);
        final bounds = range.substring(6).split('-');
        final start = int.parse(bounds.first);
        final end = int.tryParse(bounds.last) ?? total - 1;
        chunks[id] = Uint8List.fromList(
          List.filled(end - start + 1, ranges.length),
        );
        return {
          'status': 206,
          'url': 'https://final.example/progressive',
          'headers': {
            'content-type': mime,
            'content-length': '${end - start + 1}',
            'content-range':
                'bytes ${malformed ? start + 1 : start}-$end/$total',
            'cache-control': cacheControl,
            'etag': tag,
          },
        };
      });
      final context = OmoNetworkContext('progressive');
      await context.prepare();
      final url = Uri.parse('https://cdn.example/progressive?token=test');
      final first = context.player(url, {});
      final second = context.player(url, {});
      final firstRoute = Uri.parse(first.dataSource);
      final secondRoute = Uri.parse(second.dataSource);
      final client = HttpClient()..findProxy = (_) => 'DIRECT';

      Future<(int, String?, List<int>)> get(
        Uri route,
        String range, {
        bool bypass = false,
      }) async {
        final request = await client.getUrl(route);
        request.headers.set('range', range);
        if (bypass) request.headers.set('cache-control', 'no-cache');
        final response = await request.close();
        final contentRange = response.headers.value('content-range');
        final body = await response.expand((chunk) => chunk).toList();
        return (response.statusCode, contentRange, body);
      }

      try {
        expect(firstRoute.path, endsWith('.bin'));
        final initial = await get(firstRoute, 'bytes=0-3');
        expect((initial.$1, initial.$2), (206, 'bytes 0-3/32'));
        expect(initial.$3, [1, 1, 1, 1]);
        expect((await get(firstRoute, 'bytes=0-3')).$3, [1, 1, 1, 1]);
        expect(ranges, ['bytes=0-3']);
        expect((await get(secondRoute, 'bytes=0-3')).$3.first, 2);
        expect((await get(firstRoute, 'bytes=28-')).$2, 'bytes 28-31/32');
        expect((await get(firstRoute, 'bytes=28-')).$3.first, 3);
        expect(ranges, hasLength(3));
        expect((await get(firstRoute, 'bytes=0-3', bypass: true)).$3.first, 4);
        expect((await get(firstRoute, 'bytes=0-3')).$3.first, 1);

        tag = '"replacement"';
        total = 33;
        expect((await get(firstRoute, 'bytes=4-7')).$3.first, 5);
        expect((await get(firstRoute, 'bytes=0-3')).$3.first, 6);
        expect((await get(secondRoute, 'bytes=0-3')).$3.first, 2);

        cacheControl = 'no-store';
        await get(firstRoute, 'bytes=8-11');
        await get(firstRoute, 'bytes=8-11');
        expect(ranges, hasLength(8));
        cacheControl = 'max-age=0';
        await get(firstRoute, 'bytes=12-15');
        await get(firstRoute, 'bytes=12-15');
        expect(ranges, hasLength(10));

        cacheControl = 'max-age=15';
        malformed = true;
        await get(firstRoute, 'bytes=16-19');
        await get(firstRoute, 'bytes=16-19');
        malformed = false;
        mime = 'application/octet-stream';
        await get(firstRoute, 'bytes=20-23');
        await get(firstRoute, 'bytes=20-23');
        expect(ranges, hasLength(14));

        await first.dispose();
        expect((await get(firstRoute, 'bytes=0-3')).$1, 404);
        expect((await get(secondRoute, 'bytes=0-3')).$3.first, 2);
        expect(ranges, hasLength(14));
      } finally {
        client.close(force: true);
        await second.dispose();
        await context.close();
        HttpOverrides.global = savedOverrides;
      }
    },
  );

  test('seek windows replay only complete TS from the active rendition', () async {
    final savedOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    final bodies = <String, Uint8List>{};
    final starts = <Uri>[];
    Uint8List ts(String name) => Uint8List.fromList([
      for (var packet = 0; packet < 3; packet++) ...[
        0x47,
        ...List.filled(187, name.codeUnits.fold(0, (a, b) => (a + b) % 256)),
      ],
    ]);
    final bulk = List.generate(35, (n) => 'bulk$n.ts');
    String vod(List<String> names, {String extra = ''}) =>
        '#EXTM3U\n$extra#EXT-X-TARGETDURATION:6\n'
        '${names.indexed.map((entry) => '#EXTINF:${entry.$1 == 1 ? 6 : 4},\n${entry.$2}\n').join()}'
        '#EXT-X-ENDLIST\n';
    messenger.setMockMethodCallHandler(channel, (call) async {
      final args = call.arguments as Map;
      if (call.method == 'close') return null;
      final id = args['request'] as String;
      if (call.method == 'cancel') {
        bodies.remove(id);
        return null;
      }
      if (call.method == 'read') return bodies.remove(id);
      final url = Uri.parse(args['url'] as String);
      starts.add(url);
      final name = url.pathSegments.last;
      final text = switch (name) {
        'master.m3u8' =>
          '#EXTM3U\n#EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=5,URI="storybook?token=hidden"\n'
              '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="A",URI="audio.m3u8"\n'
              '#EXT-X-STREAM-INF:BANDWIDTH=10\na.m3u8\n'
              '#EXT-X-STREAM-INF:BANDWIDTH=20\nb.m3u8\n',
        'storybook' => vod(['poster.ts'], extra: '#EXT-X-I-FRAMES-ONLY\n'),
        'audio.m3u8' => vod(['audio-only.ts']),
        'a.m3u8' => vod([
          'first.ts',
          'second.ts',
          'private.ts',
          'partial.ts',
          ...bulk,
        ]),
        'b.m3u8' => vod(['first-b.ts', 'second-b.ts']),
        'encrypted.m3u8' => vod([
          'encrypted.ts',
        ], extra: '#EXT-X-KEY:METHOD=AES-128,URI="key"\n'),
        'range.m3u8' => vod(['range.ts'], extra: '#EXT-X-BYTERANGE:564@0\n'),
        'discontinuous.m3u8' => vod([
          'discontinuous.ts',
        ], extra: '#EXT-X-DISCONTINUITY\n'),
        'live.m3u8' => '#EXTM3U\n#EXTINF:4,\nlive.ts\n',
        _ => null,
      };
      final data = text == null ? ts(name) : utf8.encode(text);
      final partial = name == 'partial.ts';
      final ranged = (args['headers'] as Map)['Range'] != null;
      bodies[id] = data;
      return {
        'status': partial || ranged ? 206 : 200,
        'url': url.toString(),
        'headers': {
          'content-type': text == null
              ? 'video/mp2t'
              : 'application/vnd.apple.mpegurl',
          'content-length': '${data.length}',
          if (partial || ranged)
            'content-range':
                'bytes 0-${data.length - 1}/${partial ? data.length * 2 : data.length}',
          if (name == 'private.ts') 'cache-control': 'no-store',
        },
      };
    });
    final context = OmoNetworkContext('seek-window');
    final client = HttpClient()..findProxy = (_) => 'DIRECT';
    Future<(int, Uint8List, HttpHeaders)> get(
      Uri url, {
      String? range,
      bool head = false,
    }) async {
      final request = await client.openUrl(head ? 'HEAD' : 'GET', url);
      if (range != null) request.headers.set('Range', range);
      final response = await request.close();
      final data = await response.fold(
        BytesBuilder(),
        (all, part) => all..add(part),
      );
      return (response.statusCode, data.takeBytes(), response.headers);
    }

    List<Uri> children(Uri base, Uint8List body) => [
      for (final line in const LineSplitter().convert(utf8.decode(body)))
        if (line.startsWith('/')) base.resolve(line),
    ];
    try {
      await context.prepare();
      final player = context.player(
        Uri.parse('https://cdn.example/master.m3u8'),
        {},
      );
      final root = Uri.parse(player.dataSource);
      expect(omoIFrameSeekTrack(player), isNull);
      final master = (await get(root)).$2;
      final variants = children(root, master);
      final iframe = omoIFrameSeekTrack(player)!;
      expect(iframe.host, '127.0.0.1');
      expect(iframe.path, endsWith('.m3u8'));
      expect(iframe.hasQuery, isFalse);
      expect(starts, hasLength(1));
      final a = children(root, (await get(variants.first)).$2);
      final b = children(root, (await get(variants.last)).$2);
      final audioPath = RegExp(
        r'#EXT-X-MEDIA:[^\n]*URI="([^"]+)"',
      ).firstMatch(utf8.decode(master))![1]!;
      final audioPlaylist = root.resolve(audioPath);
      final audio = children(
        audioPlaylist,
        (await get(audioPlaylist)).$2,
      ).single;
      expect((await get(audio)).$2, ts('audio-only.ts'));
      expect(omoCachedSeekWindow(player, Duration.zero), isNull);
      await get(b[1]);
      expect(
        omoCachedSeekWindow(player, const Duration(seconds: 5)),
        isNotNull,
      );
      await get(a[0]);
      expect(omoCachedSeekWindow(player, const Duration(seconds: 5)), isNull);
      await get(a[1], range: 'bytes=0-');
      await get(a[2]);
      await get(a[3], range: 'bytes=0-563');
      expect((await get(audio)).$2, ts('audio-only.ts'));
      expect(
        omoCachedSeekWindow(player, const Duration(seconds: 5)),
        isNotNull,
      );
      expect(omoCachedSeekWindow(player, const Duration(seconds: 10)), isNull);
      expect(omoCachedSeekWindow(player, const Duration(seconds: 14)), isNull);

      final startCount = starts.length;
      final first = omoCachedSeekWindow(
        player,
        const Duration(milliseconds: 1500),
      )!;
      final second = omoCachedSeekWindow(
        player,
        const Duration(milliseconds: 6500),
      )!;
      expect(first.position, const Duration(milliseconds: 1500));
      expect(second.position, const Duration(milliseconds: 2500));
      expect(first.url, isNot(second.url));
      expect(
        omoCachedSeekWindow(player, const Duration(seconds: 4))!.position,
        Duration.zero,
      );
      final firstManifest = await get(first.url);
      final secondManifest = await get(second.url);
      expect(firstManifest.$1, HttpStatus.ok);
      expect(utf8.decode(secondManifest.$2), contains('#EXTINF:6.0,'));
      final firstUri = children(first.url, firstManifest.$2).single;
      final secondUri = children(second.url, secondManifest.$2).single;
      expect((await get(firstUri)).$2, ts('first.ts'));
      expect((await get(secondUri)).$2, ts('second.ts'));
      final ranged = await get(secondUri, range: 'bytes=2-11');
      expect(ranged.$1, HttpStatus.partialContent);
      expect(ranged.$2, ts('second.ts').sublist(2, 12));
      expect(
        (await get(secondUri, head: true)).$3.value('content-length'),
        '564',
      );
      expect(
        (await get(secondUri, range: 'bytes=600-')).$1,
        HttpStatus.requestedRangeNotSatisfiable,
      );
      expect(
        (await get(root.resolve('/seek-preview/123.m3u8'))).$1,
        HttpStatus.notFound,
      );
      expect(starts, hasLength(startCount));
      final framePlaylist = await get(iframe);
      final frame = children(iframe, framePlaylist.$2).single;
      expect((await get(frame)).$2, ts('poster.ts'));
      expect(starts.skip(startCount).map((url) => url.path), [
        '/storybook',
        '/poster.ts',
      ]);
      expect((await get(firstUri)).$1, HttpStatus.ok);

      const previewChannel = MethodChannel('breeze.video.seek-preview');
      final preview = VideoSeekPreviewController();
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final previewRequests = <Map<Object?, Object?>>[];
      var rejectCached = false;
      messenger.setMockMethodCallHandler(previewChannel, (call) async {
        if (call.method != 'frame') return null;
        final arguments = (call.arguments as Map).cast<Object?, Object?>();
        previewRequests.add(arguments);
        if (rejectCached && arguments['cachedWindow'] == true) return null;
        return Uint8List.fromList([1]);
      });
      player.value = player.value.copyWith(
        isInitialized: true,
        duration: const Duration(seconds: 24),
      );

      Future<void> scrub(int seconds) async {
        final shown = Completer<void>();
        void observe() {
          if (preview.frame != null) shown.complete();
        }

        preview.addListener(observe);
        try {
          preview.update(player, Duration(seconds: seconds));
          await shown.future.timeout(const Duration(seconds: 2));
        } finally {
          preview.removeListener(observe);
          preview.endScrub();
        }
      }

      try {
        final beforePreview = starts.length;
        await scrub(6);
        expect(previewRequests.single['cachedWindow'], isTrue);
        expect(previewRequests.single['milliseconds'], 2000);
        expect(previewRequests.single['url'], second.url.toString());
        rejectCached = true;
        await scrub(1);
        expect(previewRequests[1]['cachedWindow'], isTrue);
        expect(previewRequests[2]['url'], player.dataSource);
        expect(previewRequests[2]['milliseconds'], 1000);
        await scrub(11);
        expect(previewRequests[3]['keyframeTrack'], isTrue);
        expect(previewRequests[3]['url'], player.dataSource);
        expect(starts, hasLength(beforePreview));
      } finally {
        preview.dispose();
        messenger.setMockMethodCallHandler(previewChannel, null);
        debugDefaultTargetPlatformOverride = previousPlatform;
      }

      for (final source in ['encrypted', 'range', 'discontinuous', 'live']) {
        final other = context.player(
          Uri.parse('https://cdn.example/$source.m3u8'),
          {},
        );
        final url = Uri.parse(other.dataSource);
        final segments = children(url, (await get(url)).$2);
        await get(segments.single);
        expect(
          omoCachedSeekWindow(other, Duration.zero),
          isNull,
          reason: source,
        );
        await other.dispose();
      }
      final otherLease = context.player(
        Uri.parse('https://cdn.example/a.m3u8'),
        {},
      );
      await get(Uri.parse(otherLease.dataSource));
      expect(omoCachedSeekWindow(otherLease, Duration.zero), isNull);
      await otherLease.dispose();

      for (final segment in a.skip(4)) {
        await get(segment);
      }
      final afterEviction = starts.length;
      expect((await get(firstUri)).$1, HttpStatus.notFound);
      expect(omoCachedSeekWindow(player, Duration.zero), isNull);
      expect(starts, hasLength(afterEviction));
      await get(variants.first);
      await get(a.first);
      final retired = omoCachedSeekWindow(player, Duration.zero)!.url;
      final beforeDispose = starts.length;
      await player.dispose();
      expect(omoIFrameSeekTrack(player), isNull);
      expect((await get(retired)).$1, HttpStatus.notFound);
      expect(omoCachedSeekWindow(player, Duration.zero), isNull);
      expect(starts, hasLength(beforeDispose));
    } finally {
      client.close(force: true);
      await context.close();
      HttpOverrides.global = savedOverrides;
    }
  });

  test(
    'disposing one loopback lease cancels its request before response headers',
    () async {
      final savedOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      final context = OmoNetworkContext('pending-relay-headers');
      final client = HttpClient()..findProxy = (_) => 'DIRECT';
      final retiringStarted = Completer<String>();
      final activeStarted = Completer<String>();
      final retiringHeaders = Completer<void>();
      final activeHeaders = Completer<void>();
      final cancelled = <String>[];
      final reads = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        final args = call.arguments as Map;
        if (call.method == 'close') return null;
        final id = args['request'] as String;
        if (call.method == 'cancel') {
          cancelled.add(id);
          if (id == await retiringStarted.future &&
              !retiringHeaders.isCompleted) {
            retiringHeaders.complete();
          }
          return null;
        }
        if (call.method == 'read') {
          final first = reads.isEmpty;
          reads.add(id);
          return first ? Uint8List.fromList([1, 2, 3, 4]) : null;
        }
        expect(call.method, 'start');
        final url = args['url'] as String;
        if (!retiringStarted.isCompleted) {
          retiringStarted.complete(id);
          await retiringHeaders.future;
          throw PlatformException(
            code: 'cancelled',
            message: 'Request cancelled',
          );
        }
        activeStarted.complete(id);
        await activeHeaders.future;
        return {
          'status': 200,
          'url': url,
          'headers': {'content-type': 'video/mp2t', 'content-length': '4'},
        };
      });

      await context.prepare();
      final url = Uri.parse('https://cdn.example/shared.ts');
      final retiring = context.player(url, {});
      final active = context.player(url, {});
      Future<HttpClientResponse> fetch(String endpoint) async =>
          (await client.getUrl(Uri.parse(endpoint))).close();
      try {
        final retiringResponse = fetch(retiring.dataSource);
        retiringResponse.ignore();
        final retiringId = await retiringStarted.future;
        final activeResponse = fetch(active.dataSource);
        activeResponse.ignore();
        final activeId = await activeStarted.future;
        expect(activeId, isNot(retiringId));

        await retiring.dispose();
        expect(cancelled, [retiringId]);
        final retired = await retiringResponse;
        expect(retired.statusCode, 502);
        await retired.drain<void>();
        expect(
          context.relayDiagnostics,
          contains('retired; category=cancelled'),
        );

        activeHeaders.complete();
        final response = await activeResponse;
        expect(response.statusCode, 200);
        expect(await response.expand((chunk) => chunk).toList(), [1, 2, 3, 4]);
        expect(reads, [activeId, activeId]);
        expect(cancelled, [retiringId, activeId]);
        final expired = await fetch(retiring.dataSource);
        expect(expired.statusCode, 404);
        await expired.drain<void>();
      } finally {
        if (!retiringHeaders.isCompleted) retiringHeaders.complete();
        if (!activeHeaders.isCompleted) activeHeaders.complete();
        await retiring.dispose();
        await active.dispose();
        await context.close();
        client.close(force: true);
        HttpOverrides.global = savedOverrides;
      }
    },
  );

  test(
    'legacy bridge consumers receive a final response and cannot fill eight orphan slots',
    () async {
      final context = OmoNetworkContext('legacy-consumer');
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'start') {
          return {
            'status': 200,
            'url': 'https://site.example/play',
            'headers': <String, String>{},
          };
        }
        return null;
      });
      try {
        for (var i = 0; i < 12; i++) {
          final result = jsonDecode(
            await OmoNetworkContext.bridgeFetch(
              jsonEncode([
                'bundle:$omoNetworkSource',
                {
                  'context': context.token,
                  'request': 'legacy-$i',
                  'url': 'https://site.example/play',
                },
              ]),
            ),
          );
          expect(
            result['status'],
            200,
            reason:
                'Unnegotiated callers expect HTTP metadata, never a pending envelope',
          );
        }
      } finally {
        await context.close();
      }
    },
  );

  test(
    'finished polling jobs cannot poison the active queue when a consumer disappears',
    () async {
      final context = OmoNetworkContext('abandoned-results');
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'start') {
          return {
            'status': 200,
            'url': 'https://site.example/play',
            'headers': <String, String>{},
          };
        }
        return null;
      });
      String input(int id) => jsonEncode([
        'bundle:$omoNetworkSource',
        {
          'context': context.token,
          'request': 'poll-$id',
          'url': 'https://site.example/play',
          'responseMode': 'poll-v1',
        },
      ]);
      try {
        for (var i = 0; i < 24; i++) {
          expect(jsonDecode(await OmoNetworkContext.bridgeFetch(input(i))), {
            'pending': true,
          });
          await Future<void>.delayed(Duration.zero);
        }
        expect(
          jsonDecode(
            await OmoNetworkContext.bridgeFetch(input(23), poll: true),
          )['status'],
          200,
        );
        await expectLater(
          OmoNetworkContext.bridgeFetch(input(0), poll: true),
          throwsStateError,
        );
      } finally {
        await context.close();
      }
    },
  );

  testWidgets('eight running jobs keep their bound and abandoned jobs expire', (
    tester,
  ) async {
    final context = OmoNetworkContext('expiring-jobs');
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'start') {
        return Completer<Map<String, dynamic>>().future;
      }
      return null;
    });
    String input(int id) => jsonEncode([
      'bundle:$omoNetworkSource',
      {
        'context': context.token,
        'request': 'waiting-$id',
        'url': 'https://site.example/play',
        'responseMode': 'poll-v1',
        'timeout': 1000,
      },
    ]);
    for (var i = 0; i < 8; i++) {
      await OmoNetworkContext.bridgeFetch(input(i));
    }
    await expectLater(
      OmoNetworkContext.bridgeFetch(input(8)),
      throwsStateError,
    );
    await tester.pump(const Duration(seconds: 7));
    await expectLater(
      OmoNetworkContext.bridgeFetch(input(0), poll: true),
      throwsStateError,
    );
    expect(jsonDecode(await OmoNetworkContext.bridgeFetch(input(9))), {
      'pending': true,
    });
    await context.close();
    await tester.pump(const Duration(seconds: 4));
  });

  test(
    'passive bridge cancellation only retires its native requests',
    () async {
      final context = OmoNetworkContext('shared-playback-visit');
      final probe = VideoDownloadResolutionOwner(
        omoNetworkSource,
        passive: true,
      );
      final newer = VideoDownloadResolutionOwner(
        omoNetworkSource,
        passive: true,
      );
      final alias = context.passiveBridgeToken(probe);
      final newerAlias = context.passiveBridgeToken(newer);
      final byPath = <String, String>{};
      final starts = <String, Completer<Map<String, dynamic>>>{};
      final cancelled = <String>[];
      final reads = <String>{};
      messenger.setMockMethodCallHandler(channel, (call) async {
        final args = call.arguments as Map;
        expect(args['context'], context.token);
        final id = args['request'] as String?;
        switch (call.method) {
          case 'start':
            final uri = Uri.parse(args['url'] as String);
            byPath[uri.path] = id!;
            final pending = starts[uri.path] =
                Completer<Map<String, dynamic>>();
            return pending.future;
          case 'read':
            reads.add(id!);
            return null;
          case 'cancel':
            cancelled.add(id!);
        }
        return null;
      });

      String input(String token, String path) => jsonEncode([
        'bundle:$omoNetworkSource',
        {
          'context': token,
          'request': 'reused-js-id',
          'url': 'https://site.example/$path',
          'responseMode': 'poll-v1',
        },
      ]);

      Future<void> finish(String path) async {
        starts['/$path']!.complete({
          'status': 200,
          'url': 'https://site.example/$path',
          'headers': <String, String>{},
        });
        await Future<void>.delayed(Duration.zero);
      }

      try {
        await OmoNetworkContext.bridgeFetch(input(context.token, 'play'));
        await OmoNetworkContext.bridgeFetch(input(alias, 'probe'));
        await OmoNetworkContext.bridgeFetch(input(newerAlias, 'newer'));
        expect(byPath.values.toSet(), hasLength(3));

        await probe.stop();
        await probe.stopped;
        expect(cancelled, [byPath['/probe']]);
        await expectLater(
          OmoNetworkContext.bridgeFetch(input(alias, 'late-probe')),
          throwsStateError,
        );
        await finish('probe');
        expect(reads, isNot(contains(byPath['/probe'])));
        expect(byPath, isNot(contains('/late-probe')));

        await finish('play');
        final playback = await OmoNetworkContext.bridgeFetch(
          input(context.token, 'play'),
          poll: true,
        );
        expect(jsonDecode(playback)['status'], 200);
        expect(reads, contains(byPath['/play']));
        expect(cancelled, isNot(contains(byPath['/newer'])));

        newer.close();
        await Future<void>.delayed(Duration.zero);
        expect(cancelled, contains(byPath['/newer']));
        await expectLater(
          OmoNetworkContext.bridgeFetch(input(newerAlias, 'late-newer')),
          throwsStateError,
        );
        await finish('newer');
        expect(reads, isNot(contains(byPath['/newer'])));
      } finally {
        probe.close();
        newer.close();
        await context.close();
      }
    },
  );

  test(
    'parser bridge rejects another runtime and never falls back on proxy errors',
    () async {
      final context = OmoNetworkContext('opaque');
      OmoNetworkContext.active = context;
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'start') {
          expect(
            (call.arguments as Map)['siteCookies'],
            isTrue,
            reason: 'Public parser HTML shares WebKit access verification',
          );
          throw PlatformException(code: 'network');
        }
        return null;
      });
      final payload = {
        'context': 'opaque',
        'request': 'test_request',
        'responseMode': 'poll-v1',
        'url': 'https://www.omofuna.com/anime/play.html',
      };
      await expectLater(
        OmoNetworkContext.bridgeFetch(
          jsonEncode(['bundle:other-plugin', payload]),
        ),
        throwsStateError,
      );
      expect(calls, isEmpty);
      expect(
        jsonDecode(
          await OmoNetworkContext.bridgeFetch(
            jsonEncode(['bundle:$omoNetworkSource', payload]),
          ),
        ),
        {'pending': true},
      );
      await Future<void>.delayed(Duration.zero);
      await expectLater(
        OmoNetworkContext.bridgeFetch(
          jsonEncode(['bundle:$omoNetworkSource', payload]),
          poll: true,
        ),
        throwsA(isA<PlatformException>()),
      );
      expect(calls, ['start', 'cancel']);
      await context.close();
    },
  );

  test(
    'parser bridge isolates tokens and source runtimes across visits',
    () async {
      const secondSource = '00000000-0000-0000-0000-000000000002';
      final first = OmoNetworkContext('source-a');
      final second = OmoNetworkContext('source-b', source: secondSource);
      final starts = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        final args = call.arguments as Map;
        if (call.method == 'start') {
          starts.add(args['context'] as String);
          expect(args['siteCookies'], isFalse);
          throw PlatformException(code: 'fixture');
        }
        return null;
      });
      String payload(String source, String token) => jsonEncode([
        'bundle:$source',
        {
          'context': token,
          'request': 'same-id',
          'responseMode': 'poll-v1',
          'url': 'https://cdn.example/file',
        },
      ]);
      try {
        await expectLater(
          OmoNetworkContext.bridgeFetch(
            payload(omoNetworkSource, second.token),
          ),
          throwsStateError,
        );
        expect(starts, isEmpty);
        await OmoNetworkContext.bridgeFetch(
          payload(omoNetworkSource, first.token),
        );
        await OmoNetworkContext.bridgeFetch(
          payload(secondSource, second.token),
        );
        await Future<void>.delayed(Duration.zero);
        expect(starts, ['source-a', 'source-b']);
        for (final entry in [
          (omoNetworkSource, first),
          (secondSource, second),
        ]) {
          await expectLater(
            OmoNetworkContext.bridgeFetch(
              payload(entry.$1, entry.$2.token),
              poll: true,
            ),
            throwsA(isA<PlatformException>()),
          );
        }
      } finally {
        await first.close();
        await second.close();
      }
    },
  );

  testWidgets(
    'polling retains an 18 second parser budget beyond the bridge ceiling',
    (tester) async {
      final context = OmoNetworkContext('long-parser');
      OmoNetworkContext.active = context;
      var read = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'start') {
          expect((call.arguments as Map)['timeout'], 18);
          await Future<void>.delayed(const Duration(seconds: 17));
          return {
            'status': 200,
            'url': 'https://parser.example/play',
            'headers': <String, String>{},
          };
        }
        if (call.method == 'read' && !read) {
          read = true;
          return Uint8List.fromList(utf8.encode('ready'));
        }
        return null;
      });
      final input = jsonEncode([
        'bundle:$omoNetworkSource',
        {
          'context': context.token,
          'request': 'long-parser-request',
          'responseMode': 'poll-v1',
          'url': 'https://parser.example/play',
          'timeout': 18000,
        },
      ]);
      expect(jsonDecode(await OmoNetworkContext.bridgeFetch(input)), {
        'pending': true,
      });
      await tester.pump(const Duration(seconds: 15));
      expect(
        jsonDecode(await OmoNetworkContext.bridgeFetch(input, poll: true)),
        {'pending': true},
      );
      await tester.pump(const Duration(seconds: 2));
      final result = jsonDecode(
        await OmoNetworkContext.bridgeFetch(input, poll: true),
      );
      expect(result['status'], 200);
      expect(result['body'], 'ready');
      await context.close();
      await tester.pump();
    },
  );
}
