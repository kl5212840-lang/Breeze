import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/method/copy_search_topic.dart';
import 'package:zephyr/page/search_aggregate/aggregate_search_matching.dart';
import 'package:zephyr/page/search_aggregate/aggregate_video_search.dart';
import 'package:zephyr/page/search_aggregate/cubit/search_aggregate_cubit.dart';
import 'package:zephyr/page/search_result/bloc/search_bloc.dart';
import 'package:zephyr/page/search_result/models/unified_plugin_search.dart';
import 'package:zephyr/page/source_shell/source_experience_preferences.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';

import '../test_helper.dart';

class _TextApi extends RustLibApi {
  @override
  String crateApiQjsOpenccConvert({
    required String text,
    required String config,
  }) => config == 'tw2sp.json' ? text.replaceAll('雜', '杂') : text;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected test API ${invocation.memberName}');
}

UnifiedComicListItem _comic(
  String id,
  String title, {
  String? type,
  String label = '',
}) => UnifiedComicListItem.fromJson({
  'source': bikaPlusSourceId,
  'id': id,
  'title': title,
  'cover': {'id': id},
  'metadata': [
    if (type != null)
      {
        'type': type,
        'value': [label],
      },
  ],
  'raw': {
    'description': 'CG雜圖',
    'tags': ['CG雜圖'],
  },
});

AggregateVideoSearch _comicAdapter() => AggregateVideoSearch(
  info: (_) async => {
    'breezeExperience': {
      'aggregateMedia': 'comic',
      'searchQuickCategories': ['CG雜圖'],
    },
  },
);

SearchEvent _event(String query, {Map<String, dynamic> extern = const {}}) =>
    SearchEvent(
      searchStates: SearchStates(
        from: bikaPlusSourceId,
        searchKeyword: query,
        pluginExtern: extern,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    RustLib.initMock(api: _TextApi());
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  test(
    'aggregate scope changes match metadata only in All for selected sources',
    () async {
      final titleHit = _comic('title', 'A needle');
      final metadataHit = _comic(
        'tag',
        'Different title',
        type: 'tags',
        label: 'needle',
      );
      final calls = <SearchEvent>[];
      final cubit = AggregateSearchCubit(
        _event('needle', extern: {keywordSearchScopeKey: 'title'}),
        initialSelectedSources: const {
          bikaPlusSourceId: true,
          'disabled': false,
        },
        videoSearch: _comicAdapter(),
        comicSearch: (event, _) async {
          calls.add(event);
          return AggregateComicPage([titleHit, metadataHit]);
        },
      );
      addTearDown(cubit.close);
      await cubit.search();
      expect(cubit.state.results[bikaPlusSourceId], [titleHit]);
      expect(cubit.state.filteredCounts[bikaPlusSourceId], 1);
      await cubit.applyKeywordScope(KeywordSearchScope.all);
      expect(
        cubit.state.results[bikaPlusSourceId],
        containsAll([titleHit, metadataHit]),
      );
      expect(calls.map((event) => event.searchStates.from), [
        bikaPlusSourceId,
        bikaPlusSourceId,
      ]);
      expect(
        calls.map(
          (event) => keywordSearchScope(event.searchStates.pluginExtern),
        ),
        [KeywordSearchScope.title, KeywordSearchScope.all],
      );
    },
  );

  test(
    'global keyword drops browse paths and preserves only same-source conditions',
    () {
      final search = _event(
        'new',
        extern: {
          'url': 'https://old.test/',
          'apiUrl': 'https://old.test/',
          'keyword': 'old',
          'mode': 'creator',
          'creatorId': 'old',
          'q_type': 'author',
          'categories': ['已选分类'],
          'blockedCategories': ['私有分类条件'],
        },
      ).searchStates;
      expect(aggregateComicSearchExtern(search, 'other-source'), isEmpty);
      expect(aggregateComicSearchExtern(search, bikaPlusSourceId), {
        'q_type': 'author',
        'categories': ['已选分类'],
        'blockedCategories': ['私有分类条件'],
      });
    },
  );

  test(
    'aggregate promotes returned public title, author, tag and category matches',
    () {
      final items = [
        _comic('server-only', 'Server match'),
        _comic('author', 'Other title', type: 'author', label: 'CG雜圖'),
        _comic('tag', 'Other title', type: 'tags', label: 'CG雜圖'),
        _comic('category', 'Other title', type: 'categories', label: 'CG雜圖'),
        _comic('title', 'CG雜圖'),
      ];
      expect(orderAggregateComics(items, ' cg杂圖 ').map((row) => row.id), [
        'title',
        'author',
        'tag',
        'category',
        'server-only',
      ]);

      ApiVideoItem item(
        String id, {
        String title = 'Other',
        String alt = '',
        String genres = '',
        String writers = '',
      }) => ApiVideoItem(
        id: id,
        title: title,
        alternateTitle: alt,
        genres: genres,
        writers: writers,
        detailUrl: Uri.parse('https://example.test/voddetail/$id.html'),
      );
      final videos = [
        item('1'),
        item('2', genres: 'Other、Animation'),
        item('3', writers: 'Animation'),
        item('4', alt: 'Animation'),
      ];
      expect(orderAggregateVideos(videos, 'animation').map((row) => row.id), [
        '4',
        '2',
        '3',
        '1',
      ]);
    },
  );

  test(
    'masking never joins separate title and metadata values into a match',
    () async {
      final settings = objectbox.userSettingBox.get(1)!;
      final previous = settings.globalSetting;
      final keywords = ['icebo', 'actual tag'];
      settings.globalSetting = previous.copyWith(maskedKeywords: keywords);
      objectbox.userSettingBox.put(settings);
      addTearDown(() {
        settings.globalSetting = previous;
        objectbox.userSettingBox.put(settings);
      });
      final partial = _comic('partial', 'Alice', type: 'author', label: 'Bob');
      final real = _comic('real', 'Other', type: 'tags', label: 'Actual Tag');
      final cubit = AggregateSearchCubit(
        _event('any'),
        initialSelectedSources: const {bikaPlusSourceId: true},
        videoSearch: _comicAdapter(),
        comicSearch: (_, _) async => AggregateComicPage([partial, real]),
      );
      addTearDown(cubit.close);
      await cubit.search();
      expect(cubit.state.results[bikaPlusSourceId]?.map((row) => row.id), [
        'partial',
      ]);
      expect(cubit.state.filteredCounts[bikaPlusSourceId], 1);

      final visible = await filterShieldedComicJsonList({
        'comics': [
          for (final row in [partial, real]) {'comic': row.toJson()},
        ],
        'maskedKeywords': keywords,
      });
      expect(visible.map((entry) => entry['comic']['id']), ['partial']);
    },
  );

  test(
    'exact declared Bika category gets one serial preview and exact continuation',
    () async {
      final entered = Completer<void>();
      final categoryResponse = Completer<AggregateComicPage>();
      final calls = <(SearchEvent, String)>[];
      final original = _comic('original', 'Keyword hit');
      final added = _comic(
        'added',
        'Another title',
        type: 'categories',
        label: 'CG雜圖',
      );
      final partial = _comic(
        'partial',
        'Not exact',
        type: 'categories',
        label: 'CG雜圖集',
      );
      final cubit = AggregateSearchCubit(
        _event(' cg杂圖 '),
        initialSelectedSources: const {bikaPlusSourceId: true},
        videoSearch: _comicAdapter(),
        comicSearch: (event, group) async {
          calls.add((event, group));
          if (calls.length == 1) return AggregateComicPage([original]);
          entered.complete();
          return categoryResponse.future;
        },
      );
      addTearDown(cubit.close);
      final work = cubit.search();
      await entered.future.timeout(const Duration(seconds: 3));
      expect(cubit.state.results[bikaPlusSourceId], [original]);
      expect(cubit.state.pendingSources, contains(bikaPlusSourceId));
      expect(calls, hasLength(2));
      expect(calls.first.$1.searchStates.searchKeyword, ' cg杂圖 ');
      expect(calls.last.$2, calls.first.$2);
      expect(calls.last.$1.page, 1);
      expect(
        calls.last.$1.searchStates,
        aggregateCategorySearch(
          calls.first.$1.searchStates,
          bikaPlusSourceId,
          'CG雜圖',
        ),
      );
      expect(calls.last.$1.searchStates.searchKeyword, isEmpty);
      expect(calls.last.$1.searchStates.pluginExtern, {
        'categories': ['CG雜圖'],
      });
      categoryResponse.complete(AggregateComicPage([original, partial, added]));
      await work;
      expect(cubit.state.categoryPreviews[bikaPlusSourceId]?.items, [added]);
      expect(cubit.state.categoryPreviews[bikaPlusSourceId]?.category, 'CG雜圖');
      expect(cubit.state.errors, isEmpty);
    },
  );

  test(
    'Copy All gives exact topic its own bounded preview and continuation',
    () async {
      const topic = (label: '競技', value: 'jingji');
      final keyword = List.generate(
        20,
        (index) => _comic('keyword-$index', 'Keyword result'),
      );
      final topicRows = List.generate(
        20,
        (index) => _comic('topic-$index', 'Topic result'),
      );
      final calls = <(SearchEvent, String)>[];
      final lookups = <(String, String?)>[];
      final base = SearchEvent(
        searchStates: const SearchStates(
          from: copyComicSourceId,
          searchKeyword: '竞技',
          pluginExtern: {keywordSearchScopeKey: 'all'},
        ),
      );
      final cubit = AggregateSearchCubit(
        base,
        initialSelectedSources: const {copyComicSourceId: true},
        videoSearch: AggregateVideoSearch(
          info: (_) async => {
            'breezeExperience': {'copyTopicSearch': 1},
          },
        ),
        copyTopicLookup: (query, {taskGroupKey}) async {
          lookups.add((query, taskGroupKey));
          return topic;
        },
        comicSearch: (event, group) async {
          calls.add((event, group));
          if (event.searchStates.pluginExtern[copySearchTopicKey] == 'jingji') {
            return AggregateComicPage([keyword.first, ...topicRows]);
          }
          return AggregateComicPage(keyword);
        },
      );
      addTearDown(cubit.close);
      await cubit.search();
      final preview = cubit.state.categoryPreviews[copyComicSourceId]!;
      expect(cubit.state.results[copyComicSourceId], hasLength(20));
      expect(preview.topic, topic);
      expect(preview.items, topicRows.take(10));
      expect(calls, hasLength(2));
      expect(lookups, [('竞技', calls.first.$2)]);
      expect(
        calls.last.$1.searchStates,
        copyTopicSearchState(base.searchStates, topic),
      );
      expect(calls.last.$1.page, 1);
      expect(calls.last.$2, calls.first.$2);
    },
  );

  test(
    'partial input keeps one request and explicit category or sort preserve source order',
    () async {
      final serverOrder = [
        _comic('server-first', 'Other title'),
        _comic('exact', 'CG雜圖'),
      ];
      for (final event in [
        _event('CG雜'),
        _event(
          'CG雜圖',
          extern: {
            'categories': ['已选分类'],
          },
        ),
        _event('CG雜圖', extern: {'sortBy': 4}),
      ]) {
        final calls = <SearchEvent>[];
        final cubit = AggregateSearchCubit(
          event,
          initialSelectedSources: const {bikaPlusSourceId: true},
          videoSearch: _comicAdapter(),
          comicSearch: (event, _) async {
            calls.add(event);
            return AggregateComicPage(serverOrder);
          },
        );
        try {
          await cubit.search();
          expect(calls.single.searchStates, event.searchStates);
          expect(cubit.state.categoryPreviews, isEmpty);
          expect(
            cubit.state.results[bikaPlusSourceId],
            event.searchStates.pluginExtern.isEmpty
                ? serverOrder.reversed.toList()
                : serverOrder,
          );
        } finally {
          await cubit.close();
        }
      }
    },
  );

  test(
    'a failed optional category read retains the primary source result',
    () async {
      var calls = 0;
      final original = _comic('original', 'Keyword hit');
      final cubit = AggregateSearchCubit(
        _event('CG雜圖'),
        initialSelectedSources: const {bikaPlusSourceId: true},
        videoSearch: _comicAdapter(),
        comicSearch: (_, _) async {
          if (++calls == 1) return AggregateComicPage([original]);
          throw TimeoutException('Category lookup failed');
        },
      );
      addTearDown(cubit.close);
      await cubit.search();
      expect(calls, 2);
      expect(cubit.state.results[bikaPlusSourceId], [original]);
      expect(cubit.state.categoryPreviews, isEmpty);
      expect(cubit.state.errors, isEmpty);
    },
  );

  test(
    'a large first page is ranked then capped without reading another page',
    () async {
      final calls = <int>[];
      final rows = [
        for (var index = 0; index < 79; index++) _comic('$index', 'Other'),
        _comic('exact', 'Needle'),
      ];
      final cubit = AggregateSearchCubit(
        _event('needle'),
        initialSelectedSources: const {bikaPlusSourceId: true},
        videoSearch: _comicAdapter(),
        comicSearch: (event, _) async {
          calls.add(event.page);
          return AggregateComicPage(
            rows,
            paging: UnifiedPluginSearchPaging.fromMap({'page': 1, 'pages': 10}),
          );
        },
      );
      addTearDown(cubit.close);
      await cubit.search();
      expect(calls, [1]);
      expect(cubit.state.results[bikaPlusSourceId], [
        rows.last,
        ...rows.take(29),
      ]);
      expect(cubit.state.filteredCounts[bikaPlusSourceId], 0);
    },
  );

  test(
    'comic preview publishes 14 matches then fills from pages using extern',
    () async {
      final nextPage = Completer<AggregateComicPage>();
      final entered = Completer<void>();
      final calls = <(SearchEvent, String)>[];
      final first = [for (var i = 0; i < 14; i++) _comic('a$i', 'Needle')];
      final more = [for (var i = 0; i < 17; i++) _comic('b$i', 'Needle')];
      final cubit = AggregateSearchCubit(
        _event('needle', extern: {keywordSearchScopeKey: 'title', 'sortBy': 4}),
        initialSelectedSources: const {bikaPlusSourceId: true},
        videoSearch: _comicAdapter(),
        comicSearch: (event, group) async {
          calls.add((event, group));
          switch (event.page) {
            case 1:
              return AggregateComicPage(
                [...first, _comic('filtered', 'Other')],
                paging: UnifiedPluginSearchPaging.fromMap({
                  'page': 1,
                  'pages': 1,
                  'hasReachedMax': false,
                }),
                extern: {
                  ...event.searchStates.pluginExtern,
                  'token': 'continuation',
                },
              );
            case 2:
              entered.complete();
              return nextPage.future;
            default:
              throw StateError('unexpected extra page');
          }
        },
      );
      addTearDown(cubit.close);
      final search = cubit.search();
      await entered.future.timeout(const Duration(seconds: 3));
      expect(cubit.state.pendingSources, contains(bikaPlusSourceId));
      expect(cubit.state.results[bikaPlusSourceId], first);
      expect(calls[1].$2, calls[0].$2);
      expect(calls[1].$1.searchStates.pluginExtern, {
        keywordSearchScopeKey: 'title',
        'sortBy': 4,
        'token': 'continuation',
      });

      nextPage.complete(
        AggregateComicPage([
          first.first,
          ...more,
          _comic('filtered2', 'Other'),
        ], paging: UnifiedPluginSearchPaging.fromMap({'page': 2, 'pages': 5})),
      );
      await search;
      expect(calls.map((call) => call.$1.page), [1, 2]);
      expect(cubit.state.results[bikaPlusSourceId], [
        ...first,
        ...more.take(16),
      ]);
      expect(cubit.state.filteredCounts[bikaPlusSourceId], 2);
      expect(cubit.state.errors, isEmpty);
    },
  );

  test(
    'comic preview request budget covers even empty or filtered pages',
    () async {
      final calls = <int>[];
      final cubit = AggregateSearchCubit(
        _event('needle', extern: {keywordSearchScopeKey: 'title'}),
        initialSelectedSources: const {bikaPlusSourceId: true},
        videoSearch: _comicAdapter(),
        comicSearch: (event, _) async {
          calls.add(event.page);
          return AggregateComicPage(
            event.page == 1 ? [] : [_comic('${event.page}', 'Other')],
            paging: UnifiedPluginSearchPaging.fromMap({
              'page': event.page,
              'pages': 20,
            }),
            extern: event.searchStates.pluginExtern,
          );
        },
      );
      addTearDown(cubit.close);
      await cubit.search();
      expect(calls, [1, 2, 3, 4]);
      expect(cubit.state.results[bikaPlusSourceId], isEmpty);
      expect(cubit.state.filteredCounts[bikaPlusSourceId], 3);
      expect(cubit.state.errors, isEmpty);
    },
  );

  test(
    'terminal or failed follow-ups preserve the successful comic preview',
    () async {
      final first = [for (var i = 0; i < 14; i++) _comic('$i', 'Needle')];
      for (final failure in [
        null,
        StateError('verification required'),
        StateError('HTTP 429'),
        const FormatException('malformed items'),
      ]) {
        final calls = <int>[];
        final cubit = AggregateSearchCubit(
          _event('needle'),
          initialSelectedSources: const {bikaPlusSourceId: true},
          videoSearch: _comicAdapter(),
          comicSearch: (event, _) async {
            calls.add(event.page);
            if (event.page == 2 && failure != null) throw failure;
            return AggregateComicPage(
              first,
              paging: UnifiedPluginSearchPaging.fromMap({
                'page': event.page,
                'pages': 10,
                'hasReachedMax': failure == null,
              }),
            );
          },
        );
        try {
          await cubit.search();
          expect(calls, failure == null ? [1] : [1, 2]);
          expect(cubit.state.results[bikaPlusSourceId], first);
          expect(cubit.state.errors, isEmpty);
        } finally {
          await cubit.close();
        }
      }
    },
  );

  test('category and keyword previews share one source limit', () async {
    final keyword = [for (var i = 0; i < 14; i++) _comic('a$i', 'Keyword')];
    final category = [
      for (var i = 0; i < 25; i++)
        _comic('b$i', 'Category', type: 'categories', label: 'CG雜圖'),
    ];
    final calls = <SearchEvent>[];
    final cubit = AggregateSearchCubit(
      _event('CG雜圖'),
      initialSelectedSources: const {bikaPlusSourceId: true},
      videoSearch: _comicAdapter(),
      comicSearch: (event, _) async {
        calls.add(event);
        return AggregateComicPage(
          event.searchStates.searchKeyword.isEmpty ? category : keyword,
          paging: UnifiedPluginSearchPaging.fromMap({'page': 1, 'pages': 10}),
        );
      },
    );
    addTearDown(cubit.close);
    await cubit.search();
    expect(calls.map((event) => event.page), [1, 1]);
    expect(cubit.state.results[bikaPlusSourceId], keyword);
    expect(
      cubit.state.categoryPreviews[bikaPlusSourceId]?.items,
      category.take(16),
    );
  });

  test(
    'retired comic continuation cannot publish or start another page',
    () async {
      final followUp = Completer<AggregateComicPage>();
      final entered = Completer<void>();
      final calls = <int>[];
      final first = _comic('first', 'Needle');
      final cubit = AggregateSearchCubit(
        _event('needle'),
        initialSelectedSources: const {bikaPlusSourceId: true},
        videoSearch: _comicAdapter(),
        comicSearch: (event, _) async {
          calls.add(event.page);
          if (event.page == 2) {
            entered.complete();
            return followUp.future;
          }
          return AggregateComicPage(
            [first],
            paging: UnifiedPluginSearchPaging.fromMap({'page': 1, 'pages': 4}),
          );
        },
      );
      addTearDown(cubit.close);
      final search = cubit.search();
      await entered.future.timeout(const Duration(seconds: 3));
      cubit.setReadActive(false);
      await search;
      followUp.complete(
        AggregateComicPage([
          _comic('late', 'Needle'),
        ], paging: UnifiedPluginSearchPaging.fromMap({'page': 2, 'pages': 4})),
      );
      await Future<void>.delayed(Duration.zero);
      cubit.setReadActive(true);
      expect(calls, [1, 2]);
      expect(cubit.state.results[bikaPlusSourceId], [first]);
      expect(cubit.state.pendingSources, isEmpty);
    },
  );
}
