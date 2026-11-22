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

  test(
    'Hanime matches indexed and repeated tags without relaxing other criteria',
    () {
      final requested = Uri.https('hanime1.me', '/search', {
        'tags[]': ['A', 'B', 'C'],
        'broad': 'on',
        'genre': 'Fixture',
      });
      final returned = Uri.https('hanime1.me', '/search', {
        'tags[0]': 'C',
        'tags[1]': 'B',
        'tags[2]': 'A',
        'broad': 'on',
        'genre': 'Fixture',
      });
      expect(videoDocumentMatches(requested, returned), isTrue);
      for (final change in [
        {'tags[1]': 'D'},
        {'broad': 'off'},
        {'page': '2'},
        {'genre': 'Other'},
        {'tags[]': 'A'},
      ]) {
        expect(
          videoDocumentMatches(
            requested,
            returned.replace(
              queryParameters: {...returned.queryParameters, ...change},
            ),
          ),
          isFalse,
        );
      }
      expect(
        videoDocumentMatches(
          requested.replace(host: 'example.test'),
          returned.replace(host: 'example.test'),
        ),
        isFalse,
      );
    },
  );
}
