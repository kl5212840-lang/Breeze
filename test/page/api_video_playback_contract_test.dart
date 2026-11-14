import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/routing/routing_observed_media.dart';
import 'package:zephyr/network/routing/plugin_routing_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/video_episode_sequence.dart';

void main() {
  final home = Uri.parse('https://www.ikunzy.com/');
  final watch = home.resolve('voddetail/7.html?line=one&episode=part');
  Map<String, dynamic> payload() => {
    'data': {
      'item': {
        'id': '7',
        'title': 'Movie',
        'detailUrl': home.resolve('voddetail/7.html').toString(),
        'lines': [
          {
            'id': 'one',
            'label': 'iKun',
            'episodes': [
              {
                'id': 'part',
                'title': '正片',
                'url': 'https://cdn.example/old.m3u8',
                'watchUrl': watch.toString(),
                'webPlaybackUrls': [
                  'https://www.ikdmjx.com/?url=https%3A%2F%2Fcdn.example%2Fold.m3u8',
                ],
              },
            ],
          },
        ],
      },
      'lineId': 'one',
      'episodeId': 'part',
      'watchUrl': watch.toString(),
      'sources': [
        {
          'url': 'https://cdn.example/fresh.m3u8',
          'quality': 'Fresh',
          'headers': {'Referer': home.toString(), 'Cookie': 'must-not-pass'},
        },
      ],
    },
  };
  ApiVideoRepository repo(Map<String, dynamic> data) => ApiVideoRepository(
    source: 'test',
    home: home,
    catalogFn: 'catalog',
    detailFn: 'item',
    playbackFn: 'play',
    pluginCall: (_, _) async => data,
  );

  TestWidgetsFlutterBinding.ensureInitialized();
  test('only an exact validated playback contributes fresh routing evidence', () async {
    SharedPreferences.setMockInitialValues({});
    final source = routingSources.first.id;
    ApiVideoRepository tracked(Future<Map<String, dynamic>> Function() response) => ApiVideoRepository(
      source: source, home: home, catalogFn: 'catalog', detailFn: 'item', playbackFn: 'play',
      pluginCall: (_, _) => response());
    Map<String, dynamic> dynamicMedia() {
      final data = payload();
      ((data['data'] as Map)['sources'] as List).single['url'] = 'https://dynamic.source.tv/media.m3u8?signature=SECRET';
      return data;
    }
    final wrong = dynamicMedia();
    (wrong['data'] as Map)['watchUrl'] = home.resolve('voddetail/8.html?line=one&episode=part').toString();
    await expectLater(tracked(() async => wrong).session('7', lineId: 'one', episodeId: 'part'), throwsFormatException);
    expect(await RoutingObservedMediaDomains.read(), isEmpty);
    await tracked(() async => dynamicMedia()).session('7', lineId: 'one', episodeId: 'part');
    expect((await RoutingObservedMediaDomains.read())[source]!.single.host, 'dynamic.source.tv');
    SharedPreferences.setMockInitialValues({});
    final pending = Completer<Map<String, dynamic>>();
    final stale = tracked(() => pending.future);
    final load = stale.session('7', lineId: 'one', episodeId: 'part');
    stale.clearTemporaryData();
    pending.complete(dynamicMedia());
    await load;
    expect(await RoutingObservedMediaDomains.read(), isEmpty);
  });

  test(
    'resource matching handles shifted IDs and refuses a missing episode',
    () {
      ApiVideoEpisode episode(String line, String id, String name) =>
          ApiVideoEpisode(
            id: id,
            title: name,
            url: null,
            watchUrl: home.resolve('voddetail/7.html?line=$line&episode=$id'),
          );
      final first = episode('a', '1', '第01集');
      final item = ApiVideoItem(
        id: '7',
        title: '剧集',
        detailUrl: home.resolve('voddetail/7.html'),
      );
      final shifted = ApiVideoLine(
        id: 'b',
        label: '备用',
        episodes: [episode('b', '1', '预告'), episode('b', '2', '第1集')],
      );
      expect(item.matchingEpisode(shifted, first)?.id, '2');
      expect(item.matchingEpisode(shifted, episode('a', '1', '1集'))?.id, '2');
      expect(item.matchingEpisode(shifted, episode('a', '1', '第一集'))?.id, '2');
      expect(item.matchingEpisode(shifted, episode('a', '1', 'Episode 1'))?.id, '2');
      expect(item.matchingEpisode(shifted, episode('a', '2', '第2集')), isNull);
      final duplicate = ApiVideoLine(
        id: 'b',
        label: '歧义',
        episodes: [episode('b', '1', '第1集'), episode('b', '2', '第1集')],
      );
      expect(item.matchingEpisode(duplicate, first), isNull);
      final equivalentDuplicate = ApiVideoLine(
        id: 'b',
        label: '歧义',
        episodes: [episode('b', '1', '第01集'), episode('b', '2', '第一集')],
      );
      expect(item.matchingEpisode(equivalentDuplicate, first), isNull);
      final ambiguousCurrentLine = ApiVideoLine(
        id: 'a',
        label: '主线路',
        episodes: [first, episode('a', '2', '第一集')],
      );
      final ambiguousItem = ApiVideoItem(
        id: '7',
        title: '剧集',
        detailUrl: home.resolve('voddetail/7.html'),
        lines: [ambiguousCurrentLine, shifted],
      );
      expect(ambiguousItem.matchingEpisode(shifted, first), isNull);
      expect(ambiguousItem.matchingEpisode(ambiguousCurrentLine, first), first);
      for (final (current, alternative) in [
        ('第1集', '第1集预告'),
        ('第1集特别篇', '第1集'),
        ('S1 Episode 1', 'S2 Episode 1'),
        ('Show 1', 'Other 1'),
      ]) {
        final line = ApiVideoLine(
          id: 'b',
          label: '备用',
          episodes: [episode('b', '1', alternative)],
        );
        expect(item.matchingEpisode(line, episode('a', '1', current)), isNull);
      }
    },
  );

  test(
    'the playback contract, not the cached item URL, supplies player sources',
    () async {
      final result = await repo(
        payload(),
      ).session('7', lineId: 'one', episodeId: 'part');
      expect(
        result.session.sources.single.url.toString(),
        'https://cdn.example/fresh.m3u8',
      );
      expect(result.session.sources.single.headers, {
        'Referer': home.toString(),
      });
      expect(result.session.watchUrl, watch);
    },
  );
  test(
    'unresolved details support navigation before fetching a fresh media URL',
    () async {
      final data = payload();
      final itemJson = (data['data'] as Map)['item'] as Map<String, dynamic>;
      final episode =
          ((itemJson['lines'] as List).single['episodes'] as List).single
              as Map<String, dynamic>;
      episode.remove('url');
      episode['resolveOnPlayback'] = true;
      final item = ApiVideoItem.fromJson(itemJson, home: home);
      expect(
        VideoEpisodeSequence(item.episodeCards('one')).items.single.watchUrl,
        watch,
      );
      expect(() => item.session('one', 'part'), throwsFormatException);
      final resolved = await repo(
        data,
      ).session('7', lineId: 'one', episodeId: 'part');
      expect(resolved.session.watchUrl, watch);
      expect(resolved.session.sources.single.url.host, 'cdn.example');
    },
  );
  test(
    'explicit invalid playback sources do not silently reuse stale media',
    () async {
      final data = payload();
      (data['data'] as Map)['sources'] = [
        {'url': 'http://cdn.example/insecure.m3u8'},
      ];
      await expectLater(
        repo(data).session('7', lineId: 'one', episodeId: 'part'),
        throwsFormatException,
      );
    },
  );
  test(
    'raw recovery is opt-in and preserves the same episode contract',
    () async {
      expect(ApiVideoCapabilities.fromJson({}).rawHlsRecovery, isFalse);
      expect(
        ApiVideoCapabilities.fromJson({'rawHlsRecovery': true}).rawHlsRecovery,
        isTrue,
      );
      final requests = <Map<String, dynamic>>[];
      final declared = ApiVideoRepository(
        source: 'raw-recovery-contract',
        home: home,
        catalogFn: 'catalog',
        detailFn: 'item',
        playbackFn: 'play',
        capabilities: const ApiVideoCapabilities(rawHlsRecovery: true),
        pluginCall: (path, args) async {
          requests.add(args);
          return payload();
        },
      );
      final normal = await declared.session(
        '7',
        lineId: 'one',
        episodeId: 'part',
      );
      expect(requests.last.containsKey('rawHlsRecovery'), isFalse);
      final recovered = await declared.session(
        '7',
        lineId: 'one',
        episodeId: 'part',
        rawHlsRecovery: true,
      );
      expect(requests.last['rawHlsRecovery'], isTrue);
      expect(recovered.session.watchUrl, normal.session.watchUrl);
      await expectLater(
        repo(
          payload(),
        ).session('7', lineId: 'one', episodeId: 'part', rawHlsRecovery: true),
        throwsUnsupportedError,
      );
      final wrong = payload();
      (wrong['data'] as Map)['episodeId'] = 'other';
      final mismatch = ApiVideoRepository(
        source: 'raw-wrong-episode',
        home: home,
        catalogFn: 'catalog',
        detailFn: 'item',
        playbackFn: 'play',
        capabilities: const ApiVideoCapabilities(rawHlsRecovery: true),
        pluginCall: (_, _) async => wrong,
      );
      await expectLater(
        mismatch.session(
          '7',
          lineId: 'one',
          episodeId: 'part',
          rawHlsRecovery: true,
        ),
        throwsFormatException,
      );
    },
  );
}
