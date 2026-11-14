import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_episode_download_picker.dart';
import 'package:zephyr/page/video/video_episode_picker.dart';
import 'package:zephyr/page/video/video_episode_sequence.dart';

void main() {
  final episodes = [
    for (var i = 1; i <= 101; i++)
      NativeVideoCard(
        title: '第$i集',
        watchUrl: Uri.parse(
          'https://fixture.test/voddetail/42.html?line=a&episode=$i',
        ),
        coverUrl: null,
      ),
  ];

  testWidgets('playback opens current range and switches ranges', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoEpisodePicker(
            sequence: VideoEpisodeSequence(episodes),
            current: episodes[60].watchUrl,
            onChanged: (_) {},
            onSelected: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('第51集'), findsOneWidget);
    await tester.tap(find.text('1-50'));
    await tester.pumpAndSettle();
    expect(find.text('第1集'), findsOneWidget);
    expect(find.text('第51集'), findsNothing);
  });

  testWidgets('download selections persist across ranges', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    List<NativeVideoCard>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showVideoEpisodeDownloadPicker(
                  context,
                  episodes: episodes,
                  currentWatch: episodes.first.watchUrl,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('51-100').hitTestable(), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('download-episodes.select-all')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('51-100'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('download-episodes.select-all')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('1-50'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('download-episodes.select-all')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('download-episodes.submit')));
    await tester.pumpAndSettle();
    expect(result, episodes.sublist(50, 100));
  });

  for (final count in [50, 51]) {
    testWidgets('download range boundary at $count episodes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoEpisodeDownloadPicker(
              episodes: episodes.take(count).toList(),
              currentWatch: episodes.first.watchUrl,
            ),
          ),
        ),
      );
      expect(find.text('1-50'), count == 50 ? findsNothing : findsOneWidget);
      expect(find.text('51-51'), count == 50 ? findsNothing : findsOneWidget);
    });
  }

  testWidgets('download ranges preserve the source order', (tester) async {
    final sourceOrder = episodes.reversed.toList();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoEpisodeDownloadPicker(
            episodes: sourceOrder,
            currentWatch: sourceOrder.first.watchUrl,
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('download-episodes.order')), findsNothing);
    expect(find.text(t.videoPlayback.episodeOrderFallback), findsNothing);
    expect(find.text('第101集'), findsOneWidget);
    await tester.tap(find.text('51-100'));
    await tester.pumpAndSettle();
    expect(find.text('第51集'), findsOneWidget);
  });
}
