import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/video/video_public_metadata.dart';

void main() {
  test(
    'approximate source counts stay labels and missing metrics stay null',
    () {
      final metadata = VideoPublicMetadata.fromWire({
        'viewCountRaw': '1.2万次',
        'publishedRelative': '• 19分鐘前',
      });
      expect(metadata.viewsLabel, '1.2万次');
      expect(metadata.viewCount, isNull);
      expect(metadata.ratingLabel, isNull);
      expect(metadata.totalVotes, isNull);
      expect(metadata.byline(creator: 'Author'), 'Author · 19分鐘前');
      expect(metadata.byline(showCreator: false), '19分鐘前');
      expect(VideoPublicMetadata.fromWire({}).isEmpty, isTrue);
    },
  );
  test('only explicit valid numbers and source dates survive', () {
    final metadata = VideoPublicMetadata.fromWire({
      'viewCount': 0,
      'totalVotes': 102,
      'positiveVotes': 100,
      'negativeVotes': 2,
      'ratingPercent': 98.04,
      'publishedDate': '2026-10-23',
      'duration': '1:02:03',
    });
    expect(metadata.viewsLabel, '0');
    expect(metadata.totalVotes, 102);
    expect(metadata.positiveVotes, 100);
    expect(metadata.negativeVotes, 2);
    expect(metadata.ratingLabel, '98.04%');
    expect(metadata.publishedDate, '2026-10-23');
    expect(metadata.durationSeconds, 3723);
    final invalid = VideoPublicMetadata.fromWire({
      'viewCount': '0',
      'positiveVotes': -1,
      'negativeVotes': double.nan,
      'ratingPercent': 101,
      'publishedDate': '2026-02-30',
      'duration': '1:99',
    });
    expect(invalid.viewCount, isNull);
    expect(invalid.positiveVotes, isNull);
    expect(invalid.negativeVotes, isNull);
    expect(invalid.ratingPercent, isNull);
    expect(invalid.publishedDate, isNull);
    expect(invalid.durationSeconds, isNull);
  });
}
