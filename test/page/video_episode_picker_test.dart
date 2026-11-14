import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_episode_sequence.dart';
import 'package:zephyr/page/video/video_episode_picker.dart';

void main() {
  testWidgets('descending reverses each fixed range and resets scroll', (
    tester,
  ) async {
    var queue = VideoEpisodeSequence([
      for (var n = 1; n <= 101; n++)
        NativeVideoCard(
          title: '第$n集',
          watchUrl: Uri.parse(
            'https://fixture.test/voddetail/42.html?line=a&episode=$n',
          ),
          coverUrl: null,
        ),
    ]);
    final current = queue.items[50].watchUrl;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: SizedBox(
              height: 500,
              child: VideoEpisodePicker(
                sequence: queue,
                current: current,
                onChanged: (next) => setState(() => queue = next),
              ),
            ),
          ),
        ),
      ),
    );
    final control = find.byKey(const ValueKey('episode-queue.order'));
    tester
        .widget<SettingChoiceTile<VideoEpisodeOrder>>(control)
        .onChanged(VideoEpisodeOrder.descending);
    await tester.pumpAndSettle();
    expect(find.text('第100集'), findsOneWidget);
    expect(find.text('第101集'), findsNothing);
    final list = find.byKey(const ValueKey('episode-queue.list'));
    await tester.drag(list, const Offset(0, -800));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1-50'));
    await tester.pumpAndSettle();
    expect(find.text('第50集'), findsOneWidget);
    expect(find.text('第100集'), findsNothing);
    expect(
      queue
          .adjacent(
            Uri.parse(
              'https://fixture.test/voddetail/42.html?line=a&episode=50',
            ),
            1,
          )!
          .title,
      '第51集',
    );
    await tester.tap(find.text('101-101'));
    await tester.pumpAndSettle();
    expect(find.text('第101集'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('unrecognized episode numbers show actual site order', (
    tester,
  ) async {
    final queue = VideoEpisodeSequence([
      NativeVideoCard(
        title: 'Special',
        watchUrl: Uri.parse('https://fixture.test/1'),
        coverUrl: null,
      ),
      NativeVideoCard(
        title: '第2集',
        watchUrl: Uri.parse('https://fixture.test/2'),
        coverUrl: null,
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoEpisodePicker(
            sequence: queue,
            current: queue.items.first.watchUrl,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    final control = tester.widget<SettingChoiceTile<VideoEpisodeOrder>>(
      find.byKey(const ValueKey('episode-queue.order')),
    );
    expect(control.value, VideoEpisodeOrder.site);
    expect(control.items.keys, [
      VideoEpisodeOrder.site,
      VideoEpisodeOrder.manual,
    ]);
    expect(find.text(t.videoPlayback.episodeOrderFallback), findsNothing);
    control.onChanged(VideoEpisodeOrder.manual);
    await tester.pump();
    expect(find.text(t.videoPlayback.episodeManualNote), findsOneWidget);
  });
  testWidgets('episode queue exposes sorting without a second line selector', (
    tester,
  ) async {
    final current = Uri.parse(
      'https://fixture.test/anime/1234567890abcdef.html?line=2&episode=3',
    );
    final queue = VideoEpisodeSequence([
      NativeVideoCard(title: 'Episode 3', watchUrl: current, coverUrl: null),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 350,
            child: VideoEpisodePicker(
              sequence: queue,
              current: current,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('episode-queue.order')), findsOneWidget);
    expect(find.text(t.videoPlayback.source), findsNothing);
    expect(
      tester
          .widget<ListTile>(find.byKey(ValueKey('episode-queue.$current')))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ListTile>(find.byKey(ValueKey('episode-queue.$current')))
          .leading,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'long episode queues remain usable on small screens with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final queue = VideoEpisodeSequence([
        for (var n = 1; n <= 187; n++)
          NativeVideoCard(
            title: '第$n集',
            watchUrl: Uri.parse('https://fixture.test/episode/$n'),
            coverUrl: null,
          ),
      ]);
      NativeVideoCard? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: Scaffold(
              body: SizedBox(
                height: 460,
                child: VideoEpisodePicker(
                  sequence: queue,
                  current: queue.items.first.watchUrl,
                  onChanged: (_) {},
                  onSelected: (card) => selected = card,
                ),
              ),
            ),
          ),
        ),
      );
      final last = find.byKey(
        ValueKey('episode-queue.${queue.items.last.watchUrl}'),
      );
      await tester.scrollUntilVisible(
        find.text('151-187'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('151-187'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        last,
        1000,
        maxScrolls: 30,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(last);
      expect(selected?.watchUrl, queue.items.last.watchUrl);
      expect(tester.takeException(), isNull);
    },
  );

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
      tester
          .widget<SettingChoiceTile<VideoEpisodeOrder>>(
            find.byKey(const ValueKey('episode-queue.order')),
          )
          .onChanged(VideoEpisodeOrder.manual);
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
      tester
          .widget<SettingChoiceTile<VideoEpisodeOrder>>(
            find.byKey(const ValueKey('episode-queue.order')),
          )
          .onChanged(VideoEpisodeOrder.manual);
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
      tester
          .widget<SettingChoiceTile<VideoEpisodeOrder>>(
            find.byKey(const ValueKey('episode-queue.order')),
          )
          .onChanged(VideoEpisodeOrder.site);
      await tester.pump();
      expect(queue.items.first.title, 'Series 3');
      expect(tester.takeException(), null);
    },
  );
}
