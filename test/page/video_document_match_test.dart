import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/video/video_document_match.dart';

void main() {
  test('late document callbacks cannot complete a different tab or page', () {
    final ranking = Uri.parse('https://hanime1.me/search?sort=ranking');
    expect(
      videoDocumentMatches(ranking, Uri.parse('https://hanime1.me/')),
      isFalse,
    );
    expect(
      videoDocumentMatches(
        ranking,
        Uri.parse('https://hanime1.me/search?query=sample'),
      ),
      isFalse,
    );
    expect(
      videoDocumentMatches(
        ranking,
        Uri.parse('https://hanime1.me/search?sort=ranking&page=2'),
      ),
      isFalse,
    );
    expect(videoDocumentMatches(ranking, ranking), isTrue);
    expect(videoDocumentMatches(ranking, Uri.parse('about:blank')), isFalse);
    expect(
      videoDocumentMatches(
        Uri.parse('https://hanime1.me/watch?v=1'),
        Uri.parse('https://hanime1.me/watch?v=2'),
      ),
      isFalse,
    );
  });

  test('query order and anchors do not change the requested document', () {
    expect(
      videoDocumentMatches(
        Uri.parse('https://hanime1.me/search?query=sample&page=2'),
        Uri.parse('https://hanime1.me/search?page=2&query=sample#results'),
      ),
      isTrue,
    );
  });
}
