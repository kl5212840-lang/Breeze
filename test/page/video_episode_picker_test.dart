import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_episode_sequence.dart';
import 'package:zephyr/page/video/video_episode_picker.dart';

void main() {
  testWidgets(
    'manual queue is a draft until applied and current identity is retained',
    (tester) async {
      var queue = VideoEpisodeSequence([
        for (final n in [3, 2, 1])
          NativeVideoCard(
            title: 'Series $n',
            watchUrl: Uri.parse('https://hanime1.me/watch?v=$n'),
            coverUrl: null,
          ),
      ]);
      final current = queue.items[1].watchUrl;
      var changes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: VideoEpisodePicker(
                sequence: queue,
                current: current,
                onChanged: (next) {
                  setState(() => queue = next);
                  changes++;
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text(t.videoPlayback.episodeManual));
      await tester.pump();
      tester
          .widget<ReorderableListView>(find.byType(ReorderableListView))
          .onReorderItem!(0, 2);
      await tester.pump();
      expect(changes, 0);
      expect(queue.items.first.title, 'Series 1');
      await tester.tap(find.text(t.common.cancel));
      await tester.pump();
      expect(changes, 0);
      await tester.tap(find.text(t.videoPlayback.episodeManual));
      await tester.pump();
      tester
          .widget<ReorderableListView>(find.byType(ReorderableListView))
          .onReorderItem!(0, 2);
      await tester.pump();
      await tester.tap(find.text(t.videoPlayback.episodeApplyOrder));
      await tester.pump();
      expect(changes, 1);
      expect(queue.items.last.title, 'Series 1');
      expect(queue.indexOf(current), 0);
      await tester.tap(find.text(t.videoPlayback.episodeSite));
      await tester.pump();
      expect(queue.items.first.title, 'Series 3');
      expect(tester.takeException(), null);
    },
  );
}
