import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/video/video_personal_page_window.dart';

void main() {
  test(
    'successful pages accumulate by URL, deduplicate and retain other collections',
    () {
      final pages = VideoPersonalPageWindow();
      final first = Uri.parse('https://hanime1.me/user/42/likes');
      final next = first.replace(queryParameters: {'page': '2'});
      Map<String, dynamic> data(List<String> ids, [String? next]) => {
        'videos': [
          for (final id in ids)
            {'title': id, 'watchUrl': 'https://hanime1.me/watch?v=$id'},
        ],
        'paging': {
          'page': next == null ? 2 : 1,
          if (next != null) 'nextUrl': next,
        },
      };
      pages.put('source|owner42|likes', first, data(['1', '2'], '$next'));
      pages.put('source|owner42|likes', next, data(['2', '3']));
      expect(pages.videos.map((v) => v['title']), ['1', '2', '3']);
      expect(pages.paging['nextUrl'], null);
      pages.put(
        'source|owner42|saves',
        first.replace(path: '/user/42/saves'),
        data(['9']),
      );
      expect(pages.videos.map((v) => v['title']), ['9']);
      pages.put('source|owner42|likes', first, data(['1', '2'], '$next'));
      expect(pages.videos.map((v) => v['title']), ['1', '2', '3']);
      pages.bind('source|owner99|likes');
      expect(pages.videos, isEmpty);
      pages.clear();
      pages.bind('source|owner42|likes');
      expect(pages.videos, isEmpty);
    },
  );
  test('playlist index identities survive without watch URLs', () {
    final pages = VideoPersonalPageWindow();
    final index = Uri.parse('https://hanime1.me/user/42/playlists');
    pages.put('source|owner42|playlists', index, {
      'videos': [
        {'title': 'A', 'pageUrl': 'https://hanime1.me/playlist?list=A'},
        {'title': 'B', 'pageUrl': 'https://hanime1.me/playlist?list=B'},
      ],
    });
    expect(pages.videos.map((v) => v['title']), ['A', 'B']);
  });
}
