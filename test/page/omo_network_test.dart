import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:zephyr/network/source_network_policy.dart';
import 'package:zephyr/network/playback_trace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/page/video/omo_network.dart';

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
    'real loopback relay covers nested HLS, key and Range; disposing cancels and expires URLs',
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
        final playlist = url.path.endsWith('.m3u8');
        final body = url.path.endsWith('master.m3u8')
            ? '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=10\nvariant.m3u8\n'
            : url.path.endsWith('variant.m3u8')
            ? '#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI="key.bin"\n#EXTINF:1,\nseg.mp4\n'
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
          },
        };
      });
      final context = OmoNetworkContext('visit');
      await context.prepare();
      final controller = context.player(
        Uri.parse('https://cdn.example/master.m3u8?secret=1'),
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
        final head = await (await client.headUrl(root)).close();
        expect(head.contentLength, utf8.encode(master).length);
        await head.drain<void>();
        final variantPath = master
            .split('\n')
            .firstWhere((line) => line.startsWith('/'));
        final variant = await get(root.resolve(variantPath));
        final key = RegExp('URI="([^"]+)"').firstMatch(variant)![1]!;
        await get(root.resolve(key));
        final segment = variant
            .split('\n')
            .firstWhere((line) => line.startsWith('/'));
        expect(await get(root.resolve(segment), range: true), '12345678');
        expect(starts.every((args) => args['context'] == 'visit'), isTrue);
        expect(starts.map((args) => Uri.parse(args['url'] as String).host), [
          'cdn.example',
          'cdn.example',
          'final.example',
          'final.example',
          'final.example',
        ]);
        expect(
          starts.last['headers'],
          containsPair('Referer', 'https://www.omofuna.com/'),
        );
        expect(cancelled, hasLength(5));
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
