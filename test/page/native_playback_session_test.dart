import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/video/native_playback_session.dart';

void main() {
  final watchUrl = Uri.parse('https://hanime1.me/watch?v=408773');

  test(
    'episode labels use explicit title tokens rather than IDs or positions',
    () {
      for (final entry in {
        '作品 第 03 集': '第 03 集',
        '作品 第十一話': '第十一話',
        'Series Episode 2': 'Episode 2',
        'Series Ep. 12': 'Ep. 12',
        '作品 番外篇': '番外篇',
        'Series OVA': 'OVA',
        '作品 1080p 2026': '',
        '作品 003': '',
        'Series Episode 1 & 2': '',
        '作品 第1集 第2集': '',
        'Specialist 2026': '',
      }.entries) {
        expect(
          NativeVideoCard.labelFromTitle(entry.key),
          entry.value,
          reason: entry.key,
        );
      }
      final session = NativePlaybackSession.fromDetailResponse({
        'data': {
          'title': 'Current',
          'episodes': [
            {
              'title': 'Series Episode 2',
              'watchUrl': 'https://hanime1.me/watch?v=99',
            },
            {
              'title': 'Series OVA',
              'watchUrl': 'https://hanime1.me/watch?v=42',
            },
            {
              'title': 'Unnumbered title',
              'watchUrl': 'https://hanime1.me/watch?v=1',
            },
          ],
          'related': [
            {
              'title': 'Other Episode 1',
              'watchUrl': 'https://hanime1.me/watch?v=2',
            },
          ],
        },
      }, watchUrl: Uri.parse('https://hanime1.me/watch?v=42'));
      expect(session.episodes.map((card) => card.episodeLabel), [
        'Episode 2',
        'OVA',
        '',
      ]);
      expect(
        session.episodes.map((card) => card.watchUrl.queryParameters['v']),
        ['99', '42', '1'],
      );
      expect(
        session.episodes[1].isCurrent(
          Uri.parse('https://hanime1.me/watch?v=42&from=list'),
        ),
        true,
      );
      expect(session.related.single.episodeLabel, '');
    },
  );

  test(
    'detail tag targets stay first-party and preserve the actual search parameters',
    () {
      final session = NativePlaybackSession.fromDetailResponse({
        'data': {
          'title': 'Current',
          'tagTargets': {
            'Displayed tag': 'https://hanime1.me/search?tags%5B%5D=Wire+tag',
            'Genre': 'https://hanime1.me/search?genre=3DCG',
            'Outside': 'https://other.test/search?tags%5B%5D=bad',
            'Profile': 'https://hanime1.me/user/7',
          },
        },
      }, watchUrl: watchUrl);
      expect(session.tagTargets.keys, ['Displayed tag', 'Genre']);
      expect(
        session.tagTargets['Displayed tag']!.queryParametersAll['tags[]'],
        ['Wire tag'],
      );
    },
  );

  test('keeps HTTPS media and safe site headers', () {
    final session = NativePlaybackSession.fromPluginResponse({
      'data': {
        'title': 'Sample',
        'description': 'Description',
        'tags': ['One', 'One', 'Two'],
        'sources': [
          {
            'url': 'https://cdn.example/video.m3u8',
            'quality': '1080p',
            'headers': {
              'Referer': watchUrl.toString(),
              'Cookie': 'secret=must-not-leak',
            },
          },
          {'url': 'http://cdn.example/insecure.mp4'},
        ],
      },
    }, watchUrl: watchUrl);

    expect(session.sources, hasLength(1));
    expect(session.description, 'Description');
    expect(session.tags, ['One', 'Two']);
    expect(session.sources.single.label, '1080p');
    expect(session.sources.single.headers, {'Referer': watchUrl.toString()});
  });

  test('rejects non-network or missing video sources', () {
    expect(
      () => NativePlaybackSession.fromPluginResponse({
        'data': {
          'sources': [
            {'url': 'blob:https://hanime1.me/opaque'},
          ],
        },
      }, watchUrl: watchUrl),
      throwsFormatException,
    );
  });

  test('creator avatar destinations are real first-party profiles only', () {
    for (final url in [
      'https://hanime1.me/user/42',
      'https://hanime1.me/search?query=Example',
      'https://other.example/user/42',
      'https://hanime1.me/user/42/edit',
    ]) {
      final session = NativePlaybackSession.fromDetailResponse({
        'data': {
          'title': 'Example',
          'creator': {'name': 'Example creator', 'url': url},
        },
      }, watchUrl: watchUrl);
      expect(session.creatorUrl != null, url == 'https://hanime1.me/user/42');
      expect(
        session.creator?.nameSearchUrl != null,
        url == 'https://hanime1.me/search?query=Example',
      );
    }
  });

  test(
    'a name-only creator keeps unresolved display data without lookup identity',
    () {
      final session = NativePlaybackSession.fromDetailResponse({
        'data': {
          'title': 'Example',
          'creator': {'name': 'Named artist', 'url': ''},
        },
      }, watchUrl: watchUrl);
      expect(session.creatorName, 'Named artist');
      expect(session.creatorUrl, isNull);
      expect(session.creator?.entityKey, isEmpty);
      expect(session.creator?.destination, isNull);
      expect(session.creator?.nameSearchUrl, isNull);
    },
  );

  test(
    'artist profile and actual name-search stay distinct through session parsing',
    () {
      final session = NativePlaybackSession.fromDetailResponse({
        'data': {
          'title': 'Example',
          'creator': {
            'name': 'Displayed artist',
            'artistId': '99',
            'profileId': '11',
            'profileUrl': 'https://hanime1.me/user/11',
            'nameSearchUrl':
                'https://hanime1.me/search?query=Actual&genre=ActualType',
            'avatarUrl': 'https://hanime1.me/artist-avatar.jpg',
          },
        },
      }, watchUrl: watchUrl);
      expect(session.creatorName, 'Displayed artist');
      expect(session.creatorUrl, Uri.parse('https://hanime1.me/user/11'));
      expect(session.creator?.entityKey, 'artist:99');
      expect(session.creator?.artistId, '99');
      expect(session.creator?.profileId, '11');
      expect(session.creator?.nameSearchUrl?.queryParameters, {
        'query': 'Actual',
        'genre': 'ActualType',
      });
      expect(
        session.creator?.avatarUrl,
        Uri.parse('https://hanime1.me/artist-avatar.jpg'),
      );
    },
  );

  test(
    'same artist and uploader name or avatar never collapses their roles',
    () {
      final session = NativePlaybackSession.fromDetailResponse({
        'data': {
          'title': 'Example',
          'creator': {
            'name': 'Same',
            'artistId': '99',
            'profileUrl': '/user/11',
            'avatarUrl': '/shared-avatar.jpg',
          },
          'uploader': {
            'name': 'Same',
            'profileUrl': '/user/22',
            'avatarUrl': '/shared-avatar.jpg',
          },
        },
      }, watchUrl: watchUrl);
      expect(session.creator?.entityKey, 'artist:99');
      expect(session.creator?.profileId, '11');
      expect(session.uploader?.entityKey, 'uploader-profile:22');
      expect(session.uploader?.profileId, '22');
      expect(session.uploader?.artistId, isNull);
      expect(session.creator?.avatarUrl, session.uploader?.avatarUrl);
      expect(session.creatorUrl, session.creator?.profileUrl);
    },
  );

  test('invalid uploader target cannot borrow the valid artist profile', () {
    final session = NativePlaybackSession.fromDetailResponse({
      'data': {
        'title': 'Example',
        'creator': {'name': 'Same', 'profileUrl': '/user/11'},
        'uploader': {
          'name': 'Same',
          'profileUrl': 'https://outside.test/user/22',
        },
      },
    }, watchUrl: watchUrl);
    expect(session.creatorUrl, Uri.parse('https://hanime1.me/user/11'));
    expect(session.uploader?.name, 'Same');
    expect(session.uploader?.entityKey, isEmpty);
    expect(session.uploader?.destination, isNull);
  });

  test('a valid detail survives when the media source is not ready', () {
    final detail = {
      'data': {
        'title': 'Still visible',
        'description': 'Episode summary',
        'coverUrl': 'https://hanime1.me/poster.jpg',
        'tags': ['Anime'],
        'episodes': [
          {'title': 'Next episode', 'watchUrl': 'https://hanime1.me/watch?v=2'},
        ],
      },
    };
    final session = NativePlaybackSession.fromDetailResponse(
      detail,
      watchUrl: watchUrl,
    );
    expect(session.title, 'Still visible');
    expect(session.description, 'Episode summary');
    expect(session.sources, isEmpty);
    expect(session.episodes.single.title, 'Next episode');
  });

  test('detail cards stay on the source site and keep episode order', () {
    final session = NativePlaybackSession.fromPluginResponse(
      {
        'data': {
          'title': 'Sample',
          'sources': [
            {'url': 'https://cdn.example/video.mp4'},
          ],
        },
      },
      watchUrl: watchUrl,
      detailResponse: {
        'data': {
          'coverUrl': 'https://hanime1.me/poster.jpg',
          'episodes': [
            {'title': 'First', 'watchUrl': 'https://hanime1.me/watch?v=1'},
            {
              'title': 'Advertisement',
              'watchUrl': 'https://other.example/watch?v=2',
            },
            {'title': 'Second', 'watchUrl': 'https://hanime1.me/watch?v=2'},
          ],
        },
      },
    );
    expect(session.coverUrl.toString(), 'https://hanime1.me/poster.jpg');
    expect(session.episodes.map((episode) => episode.title), [
      'First',
      'Second',
    ]);
  });
}
