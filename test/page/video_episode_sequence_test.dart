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
  test('manual queue order survives a same-work line change with new URLs', () {
    final original = VideoEpisodeSequence([
      card(1, '第1集'),
      card(2, '第2集'),
      card(3, '第3集'),
    ]).moved(0, 3);
    final next = original.reconciled([
      card(11, '第1集'),
      card(12, '第2集'),
      card(13, '第3集'),
      card(14, '第4集'),
    ]);
    expect(next.items.map((c) => c.title), ['第2集', '第3集', '第1集', '第4集']);
    expect(
      next.items.map((c) => c.watchUrl),
      [12, 13, 11, 14].map((id) => card(id, '').watchUrl),
    );
  });
  test('display sorting never changes playback neighbors', () {
    final sequence = VideoEpisodeSequence([
      card(3, '3集'),
      card(1, '1集'),
      card(2, '2集'),
    ]);
    expect(sequence.numbered, isTrue);
    expect(sequence.items.map((c) => c.title), ['1集', '2集', '3集']);
    for (final display in [
      sequence,
      sequence.sorted(VideoEpisodeOrder.descending),
      sequence.sorted(VideoEpisodeOrder.site),
      sequence.moved(0, 3),
    ]) {
      expect(display.adjacent(card(2, '').watchUrl, -1)!.title, '1集');
      expect(display.adjacent(card(2, '').watchUrl, 1)!.title, '3集');
      expect(display.playbackIndexOf(card(2, '').watchUrl), 1);
      expect(display.adjacent(card(99, '').watchUrl, 1), isNull);
    }
    final unclear = VideoEpisodeSequence([
      card(3, 'Special'),
      card(2, '2集'),
      card(1, '1集'),
    ]).sorted(VideoEpisodeOrder.descending);
    expect(unclear.items.map((c) => c.title), ['Special', '2集', '1集']);
    expect(unclear.adjacent(card(2, '').watchUrl, 1)!.title, '1集');
  });
  test('initial playback order survives display changes and line recovery', () {
    final cards = [card(3, '第3集'), card(1, '第1集'), card(2, '第2集')];
    for (final order in [
      VideoEpisodeOrder.site,
      VideoEpisodeOrder.descending,
    ]) {
      final initial = VideoEpisodeSequence(cards, order: order);
      final expected = initial.items.map((card) => card.title).toList();
      for (final display in [
        initial.sorted(VideoEpisodeOrder.ascending),
        initial.moved(0, 3),
      ]) {
        expect(display.playbackItems.map((card) => card.title), expected);
        final recovered = display.reconciled([
          card(13, '第3集'),
          card(11, '第1集'),
          card(12, '第2集'),
        ]);
        expect(recovered.playbackItems.map((card) => card.title), expected);
        expect(
          recovered.adjacent(recovered.playbackItems.first.watchUrl, 1),
          recovered.playbackItems[1],
        );
      }
    }
  });
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
      expect(VideoEpisodeSequence.number('1集'), 1);
      expect(VideoEpisodeSequence.number('作品 · 1集'), 1);
      expect(VideoEpisodeSequence.number('共12集'), isNull);
      expect(VideoEpisodeSequence.number('12集合集'), isNull);
      final s = VideoEpisodeSequence([
        card(3, 'Special'),
        card(2, 'Episode 2'),
        card(1, 'Episode 1'),
      ]);
      expect(s.items.first.title, 'Special');
      expect(s.numbered, false);
    },
  );
  test(
    'four digit explicit episodes sort while dates and years stay unclear',
    () {
      expect(VideoEpisodeSequence.number('第1000集'), 1000);
      expect(VideoEpisodeSequence.number('１２７０集'), 1270);
      expect(VideoEpisodeSequence.number('Episode 1270'), 1270);
      expect(VideoEpisodeSequence.number('Title 2026'), isNull);
      expect(VideoEpisodeSequence.number('2026-10-24'), isNull);
      final sequence = VideoEpisodeSequence([
        card(1270, '第1270集'),
        card(999, '第999集'),
        card(1000, '第1000集'),
      ]);
      expect(sequence.numbered, isTrue);
      expect(sequence.items.map((c) => c.title), ['第999集', '第1000集', '第1270集']);
      final mixed = VideoEpisodeSequence([
        card(1, '第1集'),
        card(2, '特别篇'),
        card(1000, '第1000集'),
      ]);
      expect(mixed.numbered, isFalse);
    },
  );
}
