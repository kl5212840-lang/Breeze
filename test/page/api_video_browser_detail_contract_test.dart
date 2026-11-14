import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';

void main() {
  final home = Uri.parse('https://www.omofuna.com/');
  const id = '667b4dd8c5ce08e51e654188';
  final detail = home.resolve('anime/$id.html');
  final watch = detail.replace(query: 'line=2&episode=1');
  const capabilities = ApiVideoCapabilities(
    browserDetail: true,
    browserItemPrefix: '/anime/',
  );
  Map<String, dynamic> resolved() => {
    'data': {
      'item': {
        'id': id,
        'title': 'Public work',
        'detailUrl': '$detail',
        'lines': [
          {
            'id': '2',
            'label': 'Dynamic line',
            'episodes': [
              {
                'id': '1',
                'title': '第1集',
                'watchUrl': '$watch',
                'resolveOnPlayback': true,
              },
            ],
          },
        ],
      },
      'lineId': '2',
      'episodeId': '1',
      'watchUrl': '$watch',
      'sources': [
        {'url': 'https://cdn.example/fresh.m3u8'},
      ],
    },
  };
  test(
    'expired plugin detail is recovered once in the existing browser and retains requested identity',
    () async {
      var reads = 0;
      final calls = <Map<String, dynamic>>[];
      final repo = ApiVideoRepository(
        source: 'omo',
        home: home,
        catalogFn: 'list',
        detailFn: 'item',
        playbackFn: 'play',
        capabilities: capabilities,
        browserDetailRead: (url) async {
          expect(url, detail);
          reads++;
          return {
            'kind': 'public-detail',
            'url': '$url',
            'html': '<h1>Public work</h1>',
          };
        },
        pluginCall: (path, args) async {
          expect(path, 'play');
          calls.add(args);
          return args.containsKey('browserSnapshot')
              ? resolved()
              : {
                  'data': {
                    'browserDetailRequest': {'url': '$detail'},
                  },
                };
        },
      );
      final value = await repo.session(
        id,
        lineId: '2',
        episodeId: '1',
        refresh: true,
      );
      expect(value.session.watchUrl, watch);
      expect(reads, 1);
      expect(calls, hasLength(2));
      for (final call in calls) {
        expect(call['lineId'], '2');
        expect(call['episodeId'], '1');
        expect(call['refresh'], true);
        expect(call['browserDetailTransport'], true);
      }
    },
  );
  test(
    'repeated detail requests fail after one recovery without a retry loop',
    () async {
      var calls = 0, reads = 0;
      final repo = ApiVideoRepository(
        source: 'omo',
        home: home,
        catalogFn: 'list',
        detailFn: 'item',
        playbackFn: 'play',
        capabilities: capabilities,
        browserDetailRead: (url) async {
          reads++;
          return {
            'kind': 'public-detail',
            'url': '$url',
            'html': '<h1>Public work</h1>',
          };
        },
        pluginCall: (_, args) async {
          calls++;
          return {
            'data': {
              'browserDetailRequest': {'url': '$detail'},
            },
          };
        },
      );
      await expectLater(
        repo.session(id, lineId: '2', episodeId: '1'),
        throwsFormatException,
      );
      expect(calls, 2);
      expect(reads, 1);
    },
  );

  test('playback rejects explicit failure after browser recovery', () async {
    var calls = 0;
    final repo = ApiVideoRepository(
      source: 'omo',
      home: home,
      catalogFn: 'list',
      detailFn: 'item',
      playbackFn: 'play',
      capabilities: capabilities,
      browserDetailRead: (url) async => {
        'kind': 'public-detail',
        'url': '$url',
        'html': '<h1>Public work</h1>',
      },
      pluginCall: (_, args) async {
        calls++;
        return args.containsKey('browserSnapshot')
            ? {
                'data': {
                  ...resolved()['data'] as Map<String, dynamic>,
                  'success': false,
                },
              }
            : {
                'data': {
                  'browserDetailRequest': {'url': '$detail'},
                },
              };
      },
    );

    await expectLater(
      repo.session(id, lineId: '2', episodeId: '1'),
      throwsFormatException,
    );
    expect(calls, 2);
  });
}
