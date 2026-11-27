import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_card_metadata.dart';
import 'package:zephyr/page/video/hanime_catalog_scope.dart';
import 'package:zephyr/page/video/hanime_work_facts.dart';
import 'package:zephyr/page/video/video_engagement.dart';
import 'package:zephyr/page/video/video_public_metadata.dart';
import 'package:zephyr/page/video/video_site_action_models.dart';

void main() {
  testWidgets('Hanime detailed rows retain the site vote split', (
    tester,
  ) async {
    const card = VideoPublicMetadata(ratingPercentRaw: '90%');
    const known = VideoPublicMetadata(
      positiveVotes: 9,
      negativeVotes: 1,
      totalVotes: 10,
    );
    Future<void> show(HanimeCatalogLayout layout) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) =>
                hanimeWorkStatistics(context, card, layout, known: known),
          ),
        ),
      ),
    );
    final votes = [
      t.videoMetadata.positiveVotes(count: 9),
      t.videoMetadata.negativeVotes(count: 1),
      t.videoMetadata.totalVotes(count: 10),
    ];
    await show(HanimeCatalogLayout.detail);
    for (final label in votes) {
      expect(find.text(label), findsOneWidget);
    }
    await show(HanimeCatalogLayout.compact);
    for (final label in votes) {
      expect(find.text(label), findsNothing);
    }
  });

  testWidgets(
    'card metadata distinguishes duration, rating, views and current episode at large text',
    (tester) async {
      final data = VideoPublicMetadata.fromWire({
        'duration': '01:24',
        'viewCountRaw': '1.2万次',
        'ratingPercentRaw': '99%',
        'publishedRelative': '• 2天前',
        'positiveVotes': 860,
        'totalVotes': 900,
      });
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SizedBox(
              width: 224,
              child: Column(
                children: [
                  SizedBox(
                    height: 126,
                    child: VideoCardCover(
                      url: '',
                      referrer: Uri.parse('https://hanime1.me/watch?v=1'),
                      metadata: data,
                      current: true,
                    ),
                  ),
                  VideoCardFacts(metadata: data, creator: 'Author'),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('1:24'), findsOneWidget);
      expect(find.text(t.videoPlayback.currentEpisode), findsOneWidget);
      expect(find.text('Author · 2天前'), findsOneWidget);
      expect(
        find.text(
          '${t.videoMetadata.views(value: '1.2万次')} · '
          '${t.videoMetadata.rating(value: '99%')} · '
          '${t.videoMetadata.positiveVotes(count: 860)} · '
          '${t.videoMetadata.totalVotes(count: 900)}',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'votes keep all three meanings and do not derive a percentage after a write',
    (tester) async {
      const data = VideoPublicMetadata(
        ratingPercentRaw: '98%',
        totalVotes: 102,
        positiveVotes: 100,
        negativeVotes: 2,
      );
      Future<void> mount(VideoInteractionState? state) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoVoteSummary(metadata: data, state: state),
          ),
        ),
      );
      await mount(null);
      for (final text in [
        t.videoMetadata.rating(value: '98%'),
        t.videoMetadata.totalVotes(count: 102),
        t.videoMetadata.positiveVotes(count: 100),
        t.videoMetadata.negativeVotes(count: 2),
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      await mount(
        const VideoInteractionState(
          totalVotes: 103,
          positiveVotes: 100,
          negativeVotes: 3,
        ),
      );
      expect(find.text(t.videoMetadata.rating(value: '98%')), findsNothing);
      expect(find.text(t.videoMetadata.totalVotes(count: 103)), findsOneWidget);
      expect(
        find.text(t.videoMetadata.negativeVotes(count: 3)),
        findsOneWidget,
      );
      await mount(
        VideoInteractionState.fromWire({
          'positiveVotes': 101,
          'negativeVotes': 2,
          'totalVotes': 103,
          'voteCountEstimated': true,
        }),
      );
      expect(find.text(t.videoMetadata.rating(value: '98%')), findsNothing);
      expect(find.text(t.videoMetadata.totalVotes(count: 103)), findsOneWidget);
      expect(
        find.text(t.videoMetadata.positiveVotes(count: 101)),
        findsOneWidget,
      );
      await mount(
        const VideoInteractionState(
          totalVotes: 109,
          positiveVotes: 107,
          negativeVotes: 2,
          ratingPercentRaw: '99%',
        ),
      );
      expect(find.text(t.videoMetadata.rating(value: '98%')), findsNothing);
      expect(find.text(t.videoMetadata.rating(value: '99%')), findsOneWidget);
      expect(find.text(t.videoMetadata.totalVotes(count: 109)), findsOneWidget);
      expect(
        find.text(t.videoMetadata.negativeVotes(count: 2)),
        findsOneWidget,
      );
      expect(find.text('97%'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
