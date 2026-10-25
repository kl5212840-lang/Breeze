import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/video/video_filter_schema_reader.dart';
import 'package:zephyr/page/video/video_search_filters.dart';
import 'package:zephyr/page/video/video_site_action_models.dart';

void main() {
  final home = Uri.parse('https://hanime1.me/');
  test(
    'observed indexed tags retain filters and canonicalize the next page',
    () {
      final officialNext = Uri.https('hanime1.me', '/search', {
        'genre': '泡麵番',
        'sort': '最新上市',
        'tags[0]': '1080p',
        'page': '2',
      });
      final filters = VideoSearchFilters.fromUri(officialNext);
      expect(filters.tags, ['1080p']);
      expect(filters.genre, '泡麵番');
      expect(filters.sort, '最新上市');
      expect(filters.page, 2);
      final canonicalNext = filters.toUri(home, pageNumber: 3);
      expect(canonicalNext.queryParametersAll, {
        'genre': ['泡麵番'],
        'sort': ['最新上市'],
        'tags[]': ['1080p'],
        'page': ['3'],
      });
      expect(
        VideoSearchFilters.fromUri(canonicalNext),
        filters.copyWith(page: 3),
      );
    },
  );

  test('canonical tags take precedence over indexed and legacy forms', () {
    expect(
      VideoSearchFilters.fromUri(
        Uri.https('hanime1.me', '/search', {
          'tags[]': ['B', 'A', 'A'],
          'tags[0]': 'Indexed',
          'tag': 'Legacy',
        }),
      ).tags,
      ['A', 'B'],
    );
    expect(
      VideoSearchFilters.fromUri(
        Uri.https('hanime1.me', '/search', {
          'tags[]': '',
          'tags[0]': 'Indexed',
          'tag': 'Legacy',
        }),
      ).tags,
      isEmpty,
    );
  });

  test('only numeric indexed tags are accepted with existing bounds', () {
    final filters = VideoSearchFilters.fromUri(
      Uri.https('hanime1.me', '/search', {
        'tags[3]': ' B ',
        'tags[0]': 'A',
        'tags[7]': 'A',
        'tags[foo]': 'Unknown',
        'tags[-1]': 'Negative',
        'tags[1][name]': 'Nested',
        'tag': 'Legacy',
      }),
    );
    expect(filters.tags, ['A', 'B']);
    expect(
      VideoSearchFilters.fromUri(
        Uri.https('hanime1.me', '/search', {'tags[0]': '', 'tag': 'Legacy'}),
      ).tags,
      isEmpty,
    );
    expect(filters.toUri(home).queryParametersAll.keys, ['tags[]']);
    final bounded = VideoSearchFilters.fromUri(
      Uri.https('hanime1.me', '/search', {
        for (var index = 0; index < 80; index++)
          'tags[$index]': 'Tag${index.toString().padLeft(2, '0')}',
      }),
    );
    expect(bounded.tags.length, 64);
    expect(bounded.tags.first, 'Tag00');
    expect(bounded.tags.last, 'Tag63');
    expect(
      VideoSearchFilters.fromUri(
        Uri.https('hanime1.me', '/search', {
          'tags[foo]': 'Unknown',
          'tag': 'Legacy',
        }),
      ).tags,
      ['Legacy'],
    );
  });

  test(
    'all filter fields round-trip with repeated tags and a canonical cache identity',
    () {
      final uri = Uri.parse(
        'https://hanime1.me/search?query=Series&genre=3DCG&sort=latest&date=2026+%E5%B9%B4+10+%E6%9C%88&duration=5+%E5%88%86%E9%90%98+%2B&tags%5B%5D=B&tags%5B%5D=A&tags%5B%5D=A&broad=on&type=artist&page=3',
      );
      final filters = VideoSearchFilters.fromUri(uri);
      expect(filters.tags, ['A', 'B']);
      expect(filters.page, 3);
      expect(filters.author, true);
      expect(filters.anyTag, true);
      expect(filters.toUri(home).queryParametersAll['tags[]'], ['A', 'B']);
      expect(filters.toUri(home).queryParameters['date'], '2026 年 10 月');
      expect(VideoSearchFilters.fromUri(filters.toUri(home)), filters);
      expect(
        filters.copyWith(tags: ['B', 'A']).toUri(home),
        filters.toUri(home),
      );
    },
  );
  test(
    'changing one condition resets paging while preserving every other field',
    () {
      const filters = VideoSearchFilters(
        query: 'Series',
        genre: 'old',
        sort: 'latest',
        date: 'past',
        duration: 'short',
        tags: ['A', 'B'],
        anyTag: true,
        author: true,
        page: 7,
      );
      final next = filters.change(VideoFilterSection.genre, 'new');
      expect(next, filters.copyWith(genre: 'new', page: 1));
      expect(next.removeTag('A'), next.copyWith(tags: ['B']));
      expect(next.toUri(home, pageNumber: 4).queryParametersAll['tags[]'], [
        'A',
        'B',
      ]);
      expect(next.toUri(home, pageNumber: 4).queryParameters['page'], '4');
      expect(const VideoSearchFilters().toUri(home).query, '');
    },
  );
  test(
    'invalid paging and control characters cannot become unrelated URL parameters',
    () {
      final filters = VideoSearchFilters.fromUri(
        Uri.parse(
          'https://hanime1.me/search?page=-2&query=a%00b&tags%5B%5D=%26sort%3Dx&foreign=secret',
        ),
      );
      expect(filters.page, 1);
      expect(filters.query, 'ab');
      expect(filters.toUri(home).queryParametersAll['tags[]'], ['&sort=x']);
      expect(filters.toUri(home).queryParameters.containsKey('sort'), false);
      expect(filters.toUri(home).queryParameters.containsKey('foreign'), false);
    },
  );
  test(
    'a schema refresh retains known groups when the current document has none',
    () {
      final base = VideoFilterSchema.fromWire({
        'options': {
          'genre': [
            {'value': '', 'label': 'All'},
            {'value': '3DCG', 'label': '3DCG'},
          ],
        },
        'tagGroups': {
          'Attributes': [
            {'value': '1080p', 'label': '1080p'},
            {'value': '1080p', 'label': 'Duplicate'},
          ],
        },
        'customDate': true,
        'years': ['2026', 'invalid'],
      });
      expect(base.tagGroups['Attributes']!.length, 1);
      expect(base.years, ['2026']);
      expect(base.merge(const VideoFilterSchema()), base);
      expect(base.options.keys, ['genre']);
    },
  );
  testWidgets(
    'read-only filter schema polling returns public controls and always cancels its job',
    (tester) async {
      var polls = 0, cancels = 0;
      final reader = VideoFilterSchemaReader(
        home: home,
        evaluate: (script) async {
          if (script.contains('delete jobs[')) {
            cancels++;
            return null;
          }
          if (script.contains('const origin =')) return {'status': 'pending'};
          polls++;
          return {
            'status': 'ok',
            'schema': {
              'tagGroups': {
                'Attributes': [
                  {'value': '1080p', 'label': '1080p'},
                ],
              },
            },
          };
        },
      );
      final pending = reader.read();
      await tester.pump(const Duration(milliseconds: 200));
      final result = await pending;
      expect(result.status, VideoSiteStatus.ok);
      expect(result.value!.tagGroups['Attributes']!.single.value, '1080p');
      expect(polls, 1);
      expect(cancels, 1);
      reader.dispose();
    },
  );
  testWidgets(
    'closing the filter panel aborts its read and ignores late results',
    (tester) async {
      final start = Completer<dynamic>();
      var cancels = 0;
      final reader = VideoFilterSchemaReader(
        home: home,
        evaluate: (script) async {
          if (script.contains('delete jobs[')) {
            cancels++;
            return null;
          }
          return start.future;
        },
      );
      final pending = reader.read();
      reader.dispose();
      start.complete({'status': 'ok', 'schema': {}});
      await tester.pump();
      expect((await pending).status, VideoSiteStatus.cancelled);
      expect(cancels, greaterThan(0));
    },
  );
}
