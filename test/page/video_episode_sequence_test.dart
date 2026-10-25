import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_episode_sequence.dart';

void main() {
  NativeVideoCard card(int id, String title) => NativeVideoCard(
    title: title,
    watchUrl: Uri.parse('https://hanime1.me/watch?v=$id'),
    coverUrl: null,
  );
  test(
    'descending site series defaults ascending without changing identities',
    () {
      final s = VideoEpisodeSequence([
        card(10, '女神宿舍。10'),
        card(9, '女神宿舍。9'),
        card(8, '女神宿舍。8'),
      ]);
      expect(s.items.map((c) => c.title), ['女神宿舍。8', '女神宿舍。9', '女神宿舍。10']);
      expect(s.adjacent(s.items[1].watchUrl, 1)!.watchUrl, s.items[2].watchUrl);
      expect(s.sorted(VideoEpisodeOrder.site).items.first.title, '女神宿舍。10');
      expect(
        s.sorted(VideoEpisodeOrder.descending).items.first.title,
        '女神宿舍。10',
      );
      final manual = s.moved(0, 3);
      expect(manual.items.last.title, '女神宿舍。8');
      expect(manual.order, VideoEpisodeOrder.manual);
      expect(
        s.items.first.title,
        '女神宿舍。8',
        reason: 'manual drafts do not mutate the active queue',
      );
    },
  );
  test(
    'numbers are conservative and missing/ambiguous items preserve site order',
    () {
      for (final title in [
        '4K',
        '2026-10-24',
        'Title 1080p',
        'Title Episode1-2',
        '第1話 第2話',
      ]) {
        expect(VideoEpisodeSequence.number(title), null, reason: title);
      }
      expect(VideoEpisodeSequence.number('【第０９話】 [中文字幕]'), 9);
      expect(VideoEpisodeSequence.number('第十一集'), 11);
      final s = VideoEpisodeSequence([
        card(3, 'Special'),
        card(2, 'Episode 2'),
        card(1, 'Episode 1'),
      ]);
      expect(s.items.first.title, 'Special');
      expect(s.numbered, false);
    },
  );
}
