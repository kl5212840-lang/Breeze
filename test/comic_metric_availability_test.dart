import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart';
import 'package:zephyr/page/comic_info/models/comic_metric_availability.dart';
import 'package:zephyr/page/comic_info/models/comic_detail_presentation.dart';

Map<String, dynamic> detail(Map<String, dynamic> counts) => {
  'comicInfo': {
    'id': '51',
    'title': 'fixture',
    'titleMeta': [],
    'description': '',
    'cover': {'id': '51', 'url': '', 'name': ''},
    'metadata': [],
  },
  'eps': [],
  'recommend': [],
  ...counts,
};

bool known(NormalComicAllInfo value, String name) =>
    comicMetricIsKnown(value.extern, name, switch (name) {
      'totalViews' => value.totalViews,
      'totalLikes' => value.totalLikes,
      _ => value.totalComments,
    });

void main() {
  test(
    'actual detail decoder preserves absent, invalid and explicit zero independently',
    () {
      final value = NormalComicAllInfo.fromJson(
        detail({'totalLikes': 0, 'totalComments': null}),
      );
      expect(value.totalViews, 0);
      expect(known(value, 'totalViews'), isFalse);
      expect(known(value, 'totalLikes'), isTrue);
      expect(known(value, 'totalComments'), isFalse);
      for (final invalid in ['', 'bad', -1, 1.5, true, {}, double.infinity]) {
        final malformed = NormalComicAllInfo.fromJson(
          detail({'totalViews': invalid}),
        );
        expect(malformed.totalViews, 0);
        expect(known(malformed, 'totalViews'), isFalse, reason: '$invalid');
      }
    },
  );

  test(
    'plugin unknown placeholders override numeric zero and survive actual JSON roundtrip',
    () {
      final value = NormalComicAllInfo.fromJson(
        detail({
          'totalViews': 0,
          'totalLikes': 0,
          'totalComments': 7,
          'extern': {
            'publicField': 'preserved',
            'metricAvailability': {'totalViews': false, 'totalLikes': false},
          },
        }),
      );
      final restored = NormalComicAllInfo.fromJson(
        jsonDecode(normalComicAllInfoToJson(value)) as Map<String, dynamic>,
      );
      expect(known(restored, 'totalViews'), isFalse);
      expect(known(restored, 'totalLikes'), isFalse);
      expect(known(restored, 'totalComments'), isTrue);
      expect(restored.totalComments, 7);
      expect(restored.extern['publicField'], 'preserved');
    },
  );

  test(
    'declared known cannot promote a missing field and other sources need no declaration',
    () {
      final absent = NormalComicAllInfo.fromJson(
        detail({
          'extern': {
            'metricAvailability': {'totalComments': true},
          },
        }),
      );
      expect(known(absent, 'totalComments'), isFalse);
      final publicCounts = NormalComicAllInfo.fromJson(
        detail({'totalViews': 123, 'totalLikes': '0', 'totalComments': 2}),
      );
      expect(known(publicCounts, 'totalViews'), isTrue);
      expect(known(publicCounts, 'totalLikes'), isTrue);
      expect(known(publicCounts, 'totalComments'), isTrue);
      expect(publicCounts.totalLikes, 0);
    },
  );
  test(
    'detail title tags suppress unknown metric numbers and preserve actual zero and unrelated information',
    () {
      NormalComicAllInfo info(Map<String, dynamic> values) {
        final raw = detail(values);
        (raw['comicInfo'] as Map<String, dynamic>)['titleMeta'] = [
          {'name': '浏览：0'},
          {
            'name': '0 likes',
            'extern': {'metric': 'totalLikes'},
          },
          {
            'name': '0 comments',
            'extern': {'metric': 'totalComments'},
          },
          {'name': '章节数：1'},
        ];
        return NormalComicAllInfo.fromJson(raw);
      }

      final unknown = info({});
      expect(
        comicInfoForDetailPresentation(
          unknown,
        ).titleMeta.map((item) => item.name),
        ['章节数：1'],
      );
      expect(
        unknown.comicInfo.titleMeta,
        hasLength(4),
        reason: 'presentation never rewrites the stored detail',
      );
      final zero = info({'totalViews': 0, 'totalLikes': 0, 'totalComments': 0});
      expect(comicInfoForDetailPresentation(zero).titleMeta, hasLength(4));
      final declaredUnknown = info({
        'totalViews': 0,
        'extern': {
          'metricAvailability': {'totalViews': false},
        },
      });
      expect(
        comicInfoForDetailPresentation(
          declaredUnknown,
        ).titleMeta.map((item) => item.name),
        ['章节数：1'],
      );
    },
  );

  test('only source-declared missing fields mark a detail partial', () {
    expect(
      comicDetailHasMissingFields(NormalComicAllInfo.fromJson(detail({}))),
      isFalse,
    );
    expect(
      comicDetailHasMissingFields(
        NormalComicAllInfo.fromJson(
          detail({
            'extern': {
              'fieldsMissing': ['description'],
            },
          }),
        ),
      ),
      isTrue,
    );
    expect(
      comicDetailHasMissingFields(
        NormalComicAllInfo.fromJson(
          detail({
            'extern': {
              'fieldsMissing': ['tags'],
            },
          }),
        ),
      ),
      isTrue,
    );
    expect(
      comicDetailHasMissingFields(
        NormalComicAllInfo.fromJson(
          detail({
            'extern': {
              'fieldsMissing': ['unrelated'],
            },
          }),
        ),
      ),
      isFalse,
    );
  });
}
