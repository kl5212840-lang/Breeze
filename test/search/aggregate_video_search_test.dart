import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search_aggregate/aggregate_video_search.dart';
import 'package:zephyr/page/search_aggregate/cubit/search_aggregate_cubit.dart';
import 'package:zephyr/page/search_result/bloc/search_bloc.dart';
import 'package:zephyr/page/video/api_video_models.dart';

import '../test_helper.dart';

Map<String, dynamic> info({
  String type = 'openVideoLibrary',
  Map<String, dynamic> caps = const {},
}) => {
  'sections': [
    {
      'action': {
        'type': type,
        'payload': {
          'source': 'v',
          'url': 'https://video.test/',
          'protocol': 2,
          'nativeSearch': true,
          'catalogFnPath': 'getLibrary',
          'detailFnPath': 'getItem',
          'playbackFnPath': 'getSession',
          'capabilities': caps,
        },
      },
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'metadata timeout stays attached until physical preparation finishes',
    (tester) async {
      final metadata = Completer<Map<String, dynamic>>();
      Object? failure;
      var settled = false;
      final adapter = AggregateVideoSearch(info: (_) => metadata.future);
      final task = adapter
          .prepare('source', 'keyword')
          .then<void>(
            (_) {
              settled = true;
            },
            onError: (Object error) {
              settled = true;
              failure = error;
            },
          );
      await tester.pump(const Duration(seconds: 13));
      expect(settled, isFalse);
      metadata.complete({'type': 'comic'});
      await tester.pump();
      await task;
      expect(settled, isTrue);
      expect(failure, isA<TimeoutException>());
    },
  );

  test('hybrid comic aggregate ignores secondary video modules', () async {
    final metadata = info();
    metadata['breezeExperience'] = {'aggregateMedia': 'comic'};
    metadata['breezeVideoModules'] = [info()['sections'][0]['action']];
    final adapter = AggregateVideoSearch(
      info: (_) async => metadata,
      call: (_, _, _) async => throw StateError('must keep comic search'),
    );
    expect(await adapter.prepare('hybrid', '漫画'), isNull);
  });
  test(
    'invalid video contracts cannot issue a truncated plugin function',
    () async {
      var calls = 0;
      final metadata = info();
      final payload = metadata['sections'][0]['action']['payload'];
      payload['catalogFnPath'] = 'a' * 121;
      final adapter = AggregateVideoSearch(
        info: (_) async => metadata,
        call: (_, _, _) async {
          calls++;
          return {};
        },
      );
      await expectLater(adapter.prepare('v', 'q'), throwsFormatException);
      expect(calls, 0);
    },
  );
  test(
    'video aggregate calls its declared catalog, never searchComic or playback',
    () async {
      final calls = <String>[];
      final adapter = AggregateVideoSearch(
        info: (_) async => info(),
        call: (source, path, args) async {
          calls.add(path);
          expect(args['query'], '关键词');
          expect(args['page'], 1);
          expect(args['clientProtocol'], 2);
          return {
            'data': {
              'items': [
                {
                  'id': '7',
                  'title': '视频',
                  'detailUrl': 'https://video.test/voddetail/7.html',
                },
              ],
              'categories': [],
              'page': 1,
              'pageCount': 1,
              'total': 1,
            },
          };
        },
      );
      final read = await adapter.prepare('v', ' 关键词 ');
      final result = await read!(1, null);
      expect(calls, ['getLibrary']);
      expect(result.items.single.id, '7');
    },
  );
  test(
    'browser-only and unsupported sources never issue a comic/network request',
    () async {
      for (final caps in [
        <String, dynamic>{'browserCatalog': true},
        {'search': 'none'},
      ]) {
        final adapter = AggregateVideoSearch(
          info: (_) async => info(caps: caps),
          call: (_, _, _) async => throw StateError('must not call'),
        );
        await expectLater(
          adapter.prepare('v', 'q'),
          throwsA(isA<AggregateSourceEntryRequired>()),
        );
      }
      final hanime = AggregateVideoSearch(
        info: (_) async => info(type: 'openVideoCatalog'),
        call: (_, _, _) async => throw StateError('must not call'),
      );
      await expectLater(
        hanime.prepare('h', 'q'),
        throwsA(isA<AggregateSourceEntryRequired>()),
      );
      expect(
        await AggregateVideoSearch(
          info: (_) async => {'type': 'comic'},
        ).prepare('comic', 'q'),
        isNull,
      );
    },
  );
  group('video preview pagination', () {
    setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
    tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

    Map<String, dynamic> videoPage(
      int page,
      Iterable<int> ids, {
      Map<String, dynamic>? cursor,
      int pageCount = 0,
    }) => {
      'data': {
        'items': [
          for (final id in ids)
            {
              'id': '$id',
              'title': 'Title $id',
              'detailUrl': 'https://video.test/voddetail/$id.html',
            },
        ],
        'page': page,
        'pageCount': pageCount,
        'nextCursor': cursor,
      },
    };

    testWidgets('video transport timeout retains physical source admission', (
      tester,
    ) async {
      final pending = <String, Completer<Map<String, dynamic>>>{};
      final adapter = AggregateVideoSearch(
        info: (_) async => info(),
        call: (source, _, _) {
          final reply = Completer<Map<String, dynamic>>();
          pending[source] = reply;
          return reply.future;
        },
      );
      final cubit = AggregateSearchCubit(
        const SearchEvent(searchStates: SearchStates(searchKeyword: 'test')),
        initialSelectedSources: const {
          'a': true,
          'b': true,
          'c': true,
          'd': true,
        },
        videoSearch: adapter,
      );
      addTearDown(cubit.close);
      void completePending() {
        for (final reply in pending.values) {
          if (!reply.isCompleted)
            reply.completeError(StateError('fixture drained'));
        }
      }

      final search = cubit.search();
      try {
        await tester.pump();
        expect(pending.keys, ['a', 'b', 'c']);

        await tester.pump(const Duration(seconds: 36));
        expect(pending.keys, ['a', 'b', 'c']);
        pending['a']!.complete(videoPage(1, [1]));
        await tester.pump();
        expect(pending.keys, ['a', 'b', 'c', 'd']);
        expect(cubit.state.errors, contains('a'));
        expect(cubit.state.results, isNot(contains('a')));

        completePending();
        await tester.pump();
        expect(cubit.state.pendingSources, isEmpty);
        expect(cubit.state.results, isEmpty);
        await search;
      } finally {
        // Retire queued work before releasing gates, even if an assertion fails.
        cubit.setReadActive(false);
        completePending();
        await tester.pump();
      }
    });

    test(
      'keeps the same query, passes the declared cursor and caps at 30',
      () async {
        const cursor = {
          'next': 'token',
          'data': [1, 2],
        };
        final calls = <Map<String, dynamic>>[];
        final pages = AggregateVideoSearch(
          info: (_) async => info(),
          call: (_, _, args) async {
            calls.add(args);
            return args['page'] == 1
                ? videoPage(1, List.generate(20, (i) => i + 1), cursor: cursor)
                : videoPage(
                    2,
                    List.generate(20, (i) => i + 20),
                    cursor: {'next': 'unused'},
                  );
          },
        );
        final cubit = AggregateSearchCubit(
          const SearchEvent(
            searchStates: SearchStates(searchKeyword: ' title '),
          ),
          initialSelectedSources: const {'v': true},
          videoSearch: pages,
        );
        addTearDown(cubit.close);
        await cubit.search();
        expect(calls.map((args) => args['query']), ['title', 'title']);
        expect(calls.map((args) => args['page']), [1, 2]);
        expect(calls.first['cursor'], isNull);
        expect(calls.last['cursor'], cursor);
        final results = cubit.state.results['v']!.cast<ApiVideoItem>();
        expect(
          results.map((item) => item.id),
          List.generate(30, (i) => '${i + 1}'),
        );
        expect(cubit.state.filteredCounts['v'], 0);
      },
    );

    test(
      'repeated cursor or terminal page stops a sparse video preview',
      () async {
        for (final terminal in [true, false]) {
          final calls = <int>[];
          final adapter = AggregateVideoSearch(
            info: (_) async => info(),
            call: (_, _, args) async {
              final page = args['page'] as int;
              calls.add(page);
              return videoPage(
                page,
                [page],
                cursor: {
                  'next': ['same'],
                },
                pageCount: terminal ? 1 : 10,
              );
            },
          );
          final cubit = AggregateSearchCubit(
            const SearchEvent(
              searchStates: SearchStates(searchKeyword: 'test'),
            ),
            initialSelectedSources: const {'v': true},
            videoSearch: adapter,
          );
          try {
            await cubit.search();
            expect(calls, terminal ? [1] : [1, 2]);
            expect(cubit.state.results['v'], hasLength(terminal ? 1 : 2));
            expect(cubit.state.errors, isEmpty);
          } finally {
            await cubit.close();
          }
        }
      },
    );
  });

  test(
    'aggregate limits concurrent requests and completes partial results',
    () async {
      var active = 0, peak = 0;
      final pending = <Completer<List<dynamic>>>[];
      final cubit = AggregateSearchCubit(
        const SearchEvent(),
        initialSelectedSources: {for (var i = 0; i < 8; i++) '$i': true},
        sourceSearch: (id, _) async {
          active++;
          if (active > peak) peak = active;
          final c = Completer<List<dynamic>>();
          pending.add(c);
          try {
            return await c.future;
          } finally {
            active--;
          }
        },
      );
      final run = cubit.search();
      await Future<void>.delayed(Duration.zero);
      expect(active, 3);
      while (cubit.state.status != AggregateSearchStatus.success) {
        final batch = [...pending];
        pending.clear();
        for (final p in batch) {
          p.complete(['result']);
        }
        await Future<void>.delayed(Duration.zero);
      }
      await run;
      expect(peak, 3);
      expect(cubit.state.results, hasLength(8));
      await cubit.close();
    },
  );
  test(
    'retry while other sources load is not overwritten by their completion',
    () async {
      var attempts = 0;
      final slow = Completer<List<dynamic>>();
      final cubit = AggregateSearchCubit(
        const SearchEvent(),
        initialSelectedSources: {'a': true, 'b': true},
        sourceSearch: (id, _) async {
          if (id == 'b') return slow.future;
          if (++attempts == 1) throw TimeoutException('network');
          return ['fixed'];
        },
      );
      final run = cubit.search();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.errors['a'], 'timeout');
      await cubit.refreshSource('a');
      slow.complete(['other']);
      await run;
      expect(cubit.state.results['a'], ['fixed']);
      expect(cubit.state.errors, isEmpty);
      await cubit.close();
    },
  );
  test(
    'late retries cannot restore deselected sources, internal errors stay private',
    () async {
      final pending = Completer<List<dynamic>>();
      var attempts = 0;
      final cubit = AggregateSearchCubit(
        const SearchEvent(),
        initialSelectedSources: {'a': true},
        sourceSearch: (_, _) async {
          if (++attempts == 1) {
            throw StateError('[bundle:private] fn:searchComic url=private');
          }
          return pending.future;
        },
      );
      await cubit.search();
      expect(cubit.state.errors['a'], 'unavailable');
      expect(cubit.state.showErrors, isFalse);
      final retry = cubit.refreshSource('a');
      await Future<void>.delayed(Duration.zero);
      await cubit.applySelectedSources({'a': false});
      pending.complete(['stale']);
      await retry;
      expect(cubit.state.results, isEmpty);
      expect(cubit.state.errors, isEmpty);
      await cubit.close();
    },
  );
  test(
    'browser continuation is a capability notice, not a failed request',
    () async {
      final cubit = AggregateSearchCubit(
        const SearchEvent(),
        initialSelectedSources: {'omo': true},
        sourceSearch: (_, _) async => throw const AggregateSourceEntryRequired(
          AggregateSourceNotice.inSource,
        ),
      );
      await cubit.search();
      expect(cubit.state.errors, isEmpty);
      expect(cubit.state.notices['omo'], AggregateSourceNotice.inSource);
      expect(cubit.state.status, AggregateSearchStatus.success);
      await cubit.close();
    },
  );
}
