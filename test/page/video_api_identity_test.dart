import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/page/video/video_watch_history.dart';

void main() {
  Uri episode(String id, String part, [String line = 'ikm3u8']) => Uri.https(
    'www.ikunzy.com',
    '/voddetail/$id.html',
    {'line': line, 'episode': part},
  );
  test('API film, line and episode each participate in identity', () {
    final one = NativeVideoCard(
      title: '第01集',
      watchUrl: episode('7', '1'),
      coverUrl: null,
    );
    expect(one.isCurrent(episode('7', '1')), isTrue);
    expect(one.isCurrent(episode('7', '2')), isFalse);
    expect(one.isCurrent(episode('8', '1')), isFalse);
    expect(one.isCurrent(episode('7', '1', 'backup')), isFalse);
    expect(
      videoPlaybackProgressKey(episode('7', '1')),
      isNot(videoPlaybackProgressKey(episode('7', '2'))),
    );
  });
  test('legacy Hanime canonical identity and key remain compatible', () {
    final uri = Uri.parse('https://hanime1.me/watch?v=123&tracking=x#extra');
    expect(
      VideoWatchRecord.canonicalUrl(uri).toString(),
      'https://hanime1.me/watch?v=123',
    );
    expect(
      videoPlaybackProgressKey(uri),
      'breeze.video.progress.hanime1.me.123',
    );
    expect(
      videoPlaybackIdentity(Uri.parse('https://hanime1.me/watch?v=x')),
      isNull,
    );
    expect(
      videoPlaybackIdentity(
        Uri.parse('https://www.ikunzy.com/voddetail/7.html'),
      ),
      isNull,
    );
  });
  test(
    'item metadata is sanitized and cloud export excludes playback URLs',
    () {
      final item = ApiVideoItem.fromJson({
        'id': '7',
        'title': '作品',
        'detailUrl': 'https://www.ikunzy.com/voddetail/7.html',
        'description': '<p>简介 &amp; 内容</p><script>bad()</script>',
        'sourceRating': 0,
        'sourceViews': 0,
        'plannedEpisodes': 12,
        'lines': [
          {
            'id': 'ikm3u8',
            'label': 'iKun',
            'episodes': [
              {
                'id': '第01集',
                'title': '第01集',
                'url': 'https://cdn.example.test/one.m3u8',
                'watchUrl': episode('7', '第01集').toString(),
              },
            ],
          },
        ],
      }, home: Uri.parse('https://www.ikunzy.com/'));
      expect(item.description, '简介 & 内容');
      expect(item.sourceRating, isNull);
      expect(item.lines.single.episodes.length, 1);
      expect(item.plannedEpisodes, 12);
      expect(item.toLibraryJson().toString(), isNot(contains('m3u8')));
      expect(
        item.session('ikm3u8', '第01集').episodes.single.episodeLabel,
        '第01集',
      );
    },
  );
}
