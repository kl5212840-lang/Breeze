import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/search_result/models/unified_plugin_search.dart';

void main() {
  Map<String, dynamic> item({dynamic id = '7', dynamic title = '作品'}) => {
    'id': id,
    'title': title,
    'raw': {'original': true},
  };

  test(
    'accepts explicit empty lists in current and legacy response shapes',
    () {
      for (final response in <Map<String, dynamic>>[
        {
          'data': {'items': []},
        },
        {'items': []},
        {'data': null, 'items': []},
        {'data': <String, dynamic>{}, 'items': []},
        {
          'data': {'message': '搜索完成'},
          'items': [],
        },
      ]) {
        expect(UnifiedPluginSearchResponse.fromMap(response).items, isEmpty);
      }
    },
  );

  test('preserves rows, paging and extern in current and legacy responses', () {
    for (final nested in [true, false]) {
      final body = {
        'items': [item(id: 7)],
        'paging': {'page': 2, 'pages': 3, 'total': 9, 'hasReachedMax': false},
      };
      final response = UnifiedPluginSearchResponse.fromMap({
        'source': 'plugin',
        'extern': {'sort': 'latest'},
        if (nested) 'data': body else ...body,
      });
      expect(response.source, 'plugin');
      expect(response.extern, {'sort': 'latest'});
      expect(response.items.single.id, '7');
      expect(response.items.single.title, '作品');
      expect(response.items.single.raw, {'original': true});
      expect(response.items.single.data['id'], 7);
      expect(response.paging.page, 2);
      expect(response.paging.pages, 3);
      expect(response.paging.total, 9);
      expect(response.paging.hasReachedMax, isFalse);
    }
  });

  test('preview continuation requires a declared next page or page range', () {
    UnifiedPluginSearchPaging paging(Map<String, dynamic> map) =>
        UnifiedPluginSearchPaging.fromMap(map);
    expect(paging({}).canContinueFrom(1), isFalse);
    expect(paging({}).reportedPage, isNull);
    expect(paging({'page': '2', 'pages': 3}).reportedPage, 2);
    expect(paging({'page': 2, 'pages': 3}).canContinueFrom(2), isTrue);
    expect(paging({'page': 3, 'pages': 3}).canContinueFrom(3), isFalse);
    expect(paging({'hasReachedMax': false}).canContinueFrom(1), isTrue);
    expect(
      paging({'pages': 9, 'hasReachedMax': true}).canContinueFrom(1),
      isFalse,
    );
  });

  test('missing or malformed lists cannot become successful empty results', () {
    for (final response in <Map<String, dynamic>>[
      {},
      {
        'data': {'message': 'temporary upstream error'},
      },
      {'items': null},
      {'items': {}},
      {'items': '[]'},
      {'data': 'error page', 'items': []},
      {
        'data': {'items': null},
        'items': [],
      },
      {
        'data': {'items': {}},
        'items': [item()],
      },
    ]) {
      expect(
        () => UnifiedPluginSearchResponse.fromMap(response),
        throwsFormatException,
      );
    }
  });

  test('explicit error envelopes fail even with an empty items list', () {
    for (final error in <Map<String, dynamic>>[
      {'ok': false},
      {'success': false},
      {'type': 'error'},
      {'status': 'error'},
      {'status': 'failed'},
      {'error': 'temporary upstream error'},
      {
        'error': {'message': 'temporary upstream error'},
      },
      {
        'errors': ['temporary upstream error'],
      },
    ]) {
      for (final nested in [false, true]) {
        final body = {'items': [], ...error};
        expect(
          () => UnifiedPluginSearchResponse.fromMap({
            if (nested) 'data': body else ...body,
          }),
          throwsFormatException,
        );
      }
    }
  });

  test(
    'non-error placeholders and success messages preserve legitimate empty',
    () {
      final response = UnifiedPluginSearchResponse.fromMap({
        'ok': true,
        'error': null,
        'errors': [],
        'message': '搜索完成',
        'data': {'items': [], 'error': '', 'errors': {}},
      });
      expect(response.items, isEmpty);
    },
  );

  test(
    'any malformed row fails the response without silently dropping rows',
    () {
      for (final invalid in <dynamic>[
        null,
        'error page',
        [],
        {},
        item(id: ''),
        item(id: '  '),
        item(id: {}),
        item(title: null),
        item(title: ''),
        item(title: []),
      ]) {
        for (final rows in [
          [invalid],
          [item(), invalid],
        ]) {
          expect(
            () => UnifiedPluginSearchResponse.fromMap({
              'data': {'items': rows},
            }),
            throwsFormatException,
          );
        }
      }
    },
  );
}
