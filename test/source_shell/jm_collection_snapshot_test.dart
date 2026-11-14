import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/comic_list/cubit/jm_collection_snapshots.dart';
import 'package:zephyr/page/comic_list/cubit/plugin_paged_comic_list_cubit.dart';
import 'package:zephyr/page/comic_list/cubit/plugin_paged_comic_list_state.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';

Map<String, dynamic> packet(
  String source,
  int page, {
  int total = 267,
  String version = 'old',
  bool empty = false,
  bool duplicate = false,
  bool? end,
}) {
  final first = duplicate ? 0 : (page - 1) * 20;
  final remaining = total - first;
  final count = empty || remaining <= 0 ? 0 : remaining.clamp(0, 20);
  return {
    'source': source,
    'data': {
      'total': total,
      'hasReachedMax': end ?? (first + count >= total),
      'items': [
        for (var index = first; index < first + count; index++)
          {
            'source': source,
            'id': '$version-$index',
            'title': '$version work $index',
            'subtitle': '',
            'finished': false,
            'likesCount': 0,
            'viewsCount': 0,
            'updatedAt': '',
            'cover': {'id': '$index', 'url': '', 'path': '', 'extern': {}},
            'metadata': [],
            'raw': {},
            'extern': {},
          },
      ],
    },
  };
}

PluginPagedComicListCubit collection(
  String source,
  PluginPageRequest request, {
  String folder = '',
  String sort = 'mr',
  String function = 'getCloudFavoriteData',
  bool reverseKeys = false,
}) => PluginPagedComicListCubit(
  pluginId: source,
  fnPath: function,
  coreBuilder: (page) => reverseKeys
      ? {
          'query': {'b': 2, 'a': 1},
          'page': page,
        }
      : {
          'page': page,
          'query': {'a': 1, 'b': 2},
        },
  externBuilder: (_) => {'folderId': folder, 'order': sort},
  requestPage: request,
  privateCollection: true,
  jmSnapshotCache: true,
);
Future<void> fill(PluginPagedComicListCubit cubit) async {
  await cubit.loadInitial();
  for (var index = 0; !cubit.state.hasReachedMax && index < 20; index++) {
    expect(cubit.state.status, PluginPagedComicListStatus.success);
    await cubit.loadMore();
  }
  expect(cubit.state.hasReachedMax, isTrue);
}

void main() {
  setUp(() => JmCollectionSnapshots.instance.clear());
  tearDown(() => JmCollectionSnapshots.instance.clear());
  test('unchanged explicit refresh checks at most two cached pages', () async {
    final pages = <int>[];
    final current = collection('bounded-manual-refresh', (
      source,
      _,
      core,
      extern,
    ) async {
      final p = core['page'] as int;
      pages.add(p);
      return packet(source, p);
    });
    await fill(current);
    pages.clear();
    expect(await current.refresh(), isTrue);
    expect(pages.length, lessThanOrEqualTo(2));
    expect(current.state.list, hasLength(267));
    expect(current.state.page, 14);
    await current.close();
  });

  test(
    'ordinary partial snapshots also use a bounded unchanged check',
    () async {
      final pages = <int>[];
      final current = collection('bounded-partial-refresh', (
        source,
        _,
        core,
        extern,
      ) async {
        final p = core['page'] as int;
        pages.add(p);
        return packet(source, p);
      });
      await current.loadInitial();
      await current.loadMore();
      await current.loadMore();
      pages.clear();
      expect(await current.refresh(), isTrue);
      expect(pages.length, lessThanOrEqualTo(2));
      expect(current.state.list, hasLength(60));
      expect(current.state.page, 3);
      expect(current.state.hasReachedMax, isFalse);
      await current.close();
    },
  );

  test(
    'warm automatic checks rotate through cached middle pages across reentry',
    () async {
      const source = 'external-middle-change';
      final pages = <int>[];
      var changed = false;
      Future<Map<String, dynamic>> request(
        String source,
        String _,
        Map<String, dynamic> core,
        Map<String, dynamic> extern,
      ) async {
        final p = core['page'] as int;
        pages.add(p);
        return packet(
          source,
          p,
          version: changed && p == 3 ? 'external' : 'old',
        );
      }

      final first = collection(source, request);
      await fill(first);
      pages.clear();
      expect(await first.checkForUpdates(), isTrue);
      expect(pages, [1, 2]);
      await first.close();
      final reopened = collection(source, request);
      await reopened.loadInitial();
      pages.clear();
      changed = true;
      expect(await reopened.checkForUpdates(), isTrue);
      expect(pages, [1, 3, 2, ...List.generate(11, (i) => i + 4)]);
      expect(reopened.state.list[40].id, 'external-40');
      expect(reopened.state.list, hasLength(267));
      await reopened.close();
    },
  );

  test(
    'automatic warm head additions rebuild only already loaded pages',
    () async {
      final pages = <int>[];
      var changed = false;
      final current = collection('warm-new-favorite', (
        source,
        _,
        core,
        extern,
      ) async {
        final p = core['page'] as int;
        pages.add(p);
        return packet(
          source,
          p,
          total: changed ? 268 : 267,
          version: changed ? 'new' : 'old',
        );
      });
      await current.loadInitial();
      await current.loadMore();
      pages.clear();
      changed = true;
      expect(await current.checkForUpdates(), isTrue);
      expect(pages, [1, 2]);
      expect(current.state.list, hasLength(40));
      expect(current.state.list.first.id, 'new-0');
      expect(current.state.knownTotal, 268);
      expect(current.state.hasReachedMax, isFalse);
      await current.close();
    },
  );

  test(
    'automatic visibility checks coalesce and keep old rows when offline',
    () async {
      final gate = Completer<Map<String, dynamic>>();
      var initial = true, calls = 0;
      final current = collection('coalesced-visible-check', (
        source,
        _,
        core,
        extern,
      ) {
        calls++;
        return initial
            ? Future.value(packet(source, 1, total: 1))
            : gate.future;
      });
      await current.loadInitial();
      initial = false;
      final check = current.checkForUpdates();
      final joined = current.checkForUpdates();
      expect(calls, 2);
      gate.completeError(StateError('fixture offline visibility'));
      expect(await check, isFalse);
      expect(await joined, isFalse);
      expect(current.state.list.single.id, 'old-0');
      expect(current.refreshError, isNotNull);
      await current.checkForUpdates();
      expect(calls, 2, reason: 'Automatic reentry respects failure backoff');
      await current.close();
    },
  );

  for (final changed in [false, true]) {
    test(
      'a partial failed index checks cached pages on reentry (${changed ? 'changed' : 'unchanged'})',
      () async {
        final pages = <int>[];
        var updating = false;
        final current = collection('partial-failed-check-$changed', (
          source,
          _,
          core,
          extern,
        ) async {
          final p = core['page'] as int;
          pages.add(p);
          if (p == 3) throw TimeoutException('fixture next page timeout');
          return packet(
            source,
            p,
            version: updating && changed ? 'new' : 'old',
          );
        });
        await current.loadInitial();
        await current.loadMore();
        await current.loadMore();
        expect(
          current.state.status,
          PluginPagedComicListStatus.loadingMoreFailure,
        );
        pages.clear();
        updating = true;
        expect(await current.checkForUpdates(), isTrue);
        expect(pages, [1, 2]);
        expect(current.state.list, hasLength(40));
        expect(current.state.list.first.id, changed ? 'new-0' : 'old-0');
        expect(current.state.page, 2);
        expect(
          current.state.status,
          PluginPagedComicListStatus.loadingMoreFailure,
        );
        await current.loadMore();
        expect(pages, [1, 2], reason: 'Reentry must not retry the failed page');
        await current.close();
      },
    );
  }

  test('visibility detection waits for an in-flight next page', () async {
    final pages = <int>[];
    final gate = Completer<Map<String, dynamic>>();
    final current = collection('check-during-append', (
      source,
      _,
      core,
      extern,
    ) {
      final p = core['page'] as int;
      pages.add(p);
      return p == 3 ? gate.future : Future.value(packet(source, p));
    });
    await current.loadInitial();
    await current.loadMore();
    pages.clear();
    final append = current.loadMore();
    final check = current.checkForUpdates();
    final joined = current.checkForUpdates();
    expect(pages, [3], reason: 'The current page must finish before probing');
    gate.complete(packet('check-during-append', 3));
    await append;
    expect(await check, isTrue);
    expect(await joined, isTrue);
    expect(pages, [3, 1, 2]);
    expect(current.state.list, hasLength(60));
    expect(current.state.page, 3);
    await current.close();
  });

  for (final savedPages in [1, 2]) {
    for (final initiallyComplete in [false, true]) {
      test(
        'unknown-total terminal boundary changes with identical rows ($savedPages pages, $initiallyComplete)',
        () async {
          var terminal = initiallyComplete;
          final current = collection(
            'terminal-only-$savedPages-$initiallyComplete',
            (source, _, core, extern) async {
              final page = core['page'] as int;
              final response = packet(
                source,
                page,
                total: savedPages * 20,
                end: page == savedPages && terminal,
              );
              (response['data'] as Map).remove('total');
              return response;
            },
          );
          await current.loadInitial();
          if (savedPages > 1) await current.loadMore();
          expect(current.state.hasReachedMax, initiallyComplete);
          terminal = !initiallyComplete;
          expect(await current.checkForUpdates(), isTrue);
          expect(current.state.list, hasLength(savedPages * 20));
          expect(current.state.hasReachedMax, !initiallyComplete);
          await current.close();
        },
      );
    }
  }

  test(
    'a changed explicit terminal boundary shrinks an unknown-total cache',
    () async {
      var shortened = false;
      final pages = <int>[];
      final current = collection('unknown-total-boundary', (
        source,
        _,
        core,
        extern,
      ) async {
        final p = core['page'] as int;
        pages.add(p);
        final result = packet(source, p, total: shortened ? 20 : 60);
        (result['data'] as Map).remove('total');
        return result;
      });
      await fill(current);
      expect(current.state.knownTotal, isNull);
      pages.clear();
      shortened = true;
      expect(await current.checkForUpdates(), isTrue);
      expect(pages, [1]);
      expect(current.state.list, hasLength(20));
      expect(current.state.page, 1);
      expect(current.state.hasReachedMax, isTrue);
      await current.close();
    },
  );

  test(
    '267 real rows retain their exact page cursor and complete cache reentry avoids fourteen more requests',
    () async {
      const source = 'jm-cache-full';
      final pages = <int>[];
      Future<Map<String, dynamic>> request(
        String source,
        String _,
        Map<String, dynamic> core,
        Map<String, dynamic> extern,
      ) async {
        final page = core['page'] as int;
        pages.add(page);
        return packet(source, page);
      }

      final first = collection(source, request);
      await fill(first);
      expect(first.state.list, hasLength(267));
      expect(first.state.knownTotal, 267);
      expect(first.state.page, 14);
      expect(pages, List.generate(14, (index) => index + 1));
      await first.close();
      final reentry = collection(source, request, reverseKeys: true);
      await reentry.loadInitial();
      expect(reentry.state.list, hasLength(267));
      expect(
        pages,
        hasLength(14),
        reason: 'Equivalent JSON maps and a detail/reentry do not refetch',
      );
      await reentry.close();
      final partial = collection(source, request, folder: '9');
      await partial.loadInitial();
      await partial.loadMore();
      await partial.close();
      final continued = collection(source, request, folder: '9');
      await continued.loadInitial();
      expect(continued.state.list, hasLength(40));
      expect(continued.state.page, 2);
      final before = pages.length;
      await continued.loadMore();
      expect(pages.length, before + 1);
      expect(pages.last, 3);
      expect(continued.state.list, hasLength(60));
      await continued.close();
    },
  );
  test(
    'source, folder, sort and function isolate snapshots; a session boundary clears unmounted entries',
    () async {
      var calls = 0, version = 'account-one';
      Future<Map<String, dynamic>> request(
        String source,
        String _,
        Map<String, dynamic> core,
        Map<String, dynamic> extern,
      ) async {
        calls++;
        return packet(source, core['page'] as int, total: 1, version: version);
      }

      for (final options in [
        ('', 'mr', 'getCloudFavoriteData'),
        ('9', 'mr', 'getCloudFavoriteData'),
        ('', 'mp', 'getCloudFavoriteData'),
        ('', 'mr', 'otherDeclaredList'),
      ]) {
        final cubit = collection(
          'jm-key-scope',
          request,
          folder: options.$1,
          sort: options.$2,
          function: options.$3,
        );
        await cubit.loadInitial();
        await cubit.close();
      }
      expect(calls, 4);
      final foreign = collection('another-source', request);
      await foreign.loadInitial();
      await foreign.close();
      expect(calls, 5);
      version = 'account-two';
      pluginSessionWriteFence.advance('jm-key-scope');
      final restored = collection('jm-key-scope', request);
      await restored.loadInitial();
      expect(calls, 6);
      expect(restored.state.list.single.id, 'account-two-0');
      await restored.close();
      final preserved = collection('another-source', request);
      await preserved.loadInitial();
      expect(calls, 6);
      expect(preserved.state.list.single.id, 'account-one-0');
      await preserved.close();
    },
  );
  test(
    'refresh stages the old fourteen-page range atomically and failure keeps its last good cache',
    () async {
      const source = 'jm-refresh-snapshot';
      var version = 'old', failPage = 0;
      Completer<Map<String, dynamic>>? last;
      final reachedLast = Completer<void>();
      Future<Map<String, dynamic>> request(
        String source,
        String _,
        Map<String, dynamic> core,
        Map<String, dynamic> extern,
      ) async {
        final page = core['page'] as int;
        if (page == failPage) throw StateError('bounded refresh failure');
        if (last != null && page == 14) {
          if (!reachedLast.isCompleted) reachedLast.complete();
          return last.future;
        }
        return packet(source, page, version: version);
      }

      final cubit = collection(source, request);
      await fill(cubit);
      final lengths = <int>[];
      final subscription = cubit.stream.listen(
        (state) => lengths.add(state.list.length),
      );
      version = 'fresh';
      last = Completer();
      final refresh = cubit.refresh();
      await reachedLast.future;
      expect(cubit.state.list, hasLength(267));
      expect(cubit.state.list.first.id, 'old-0');
      expect(cubit.refreshing, isTrue);
      last.complete(packet(source, 14, version: version));
      expect(await refresh, isTrue);
      last = null;
      expect(cubit.state.list.first.id, 'fresh-0');
      expect(
        lengths.every((count) => count == 267),
        isTrue,
        reason: 'No intermediate twenty-row replacement flashes',
      );
      failPage = 5;
      version = 'broken';
      expect(await cubit.refresh(), isFalse);
      expect(cubit.state.list, hasLength(267));
      expect(cubit.state.page, 14);
      expect(cubit.state.list.first.id, 'fresh-0');
      expect(cubit.refreshError, isNotEmpty);
      await subscription.cancel();
      await cubit.close();
      final reentry = collection(source, request);
      await reentry.loadInitial();
      expect(reentry.state.list.first.id, 'fresh-0');
      failPage = 0;
      version = 'retry';
      expect(await reentry.refresh(), isTrue);
      expect(reentry.state.list.first.id, 'retry-0');
      expect(reentry.refreshError, isNull);
      await reentry.close();
    },
  );
  for (final duplicate in [false, true]) {
    test(
      'a nonterminal ${duplicate ? 'duplicate' : 'empty'} page stays retryable, not falsely complete',
      () async {
        const source = 'jm-incomplete-page';
        var bad = true, calls = 0;
        Future<Map<String, dynamic>> request(
          String source,
          String _,
          Map<String, dynamic> core,
          Map<String, dynamic> extern,
        ) async {
          calls++;
          final page = core['page'] as int;
          return packet(
            source,
            page,
            total: 40,
            empty: page == 2 && bad && !duplicate,
            duplicate: page == 2 && bad && duplicate,
            end: page == 2 && bad ? false : null,
          );
        }

        final cubit = collection(source, request);
        await cubit.loadInitial();
        await cubit.loadMore();
        expect(cubit.state.list, hasLength(20));
        expect(cubit.state.page, 1);
        expect(cubit.state.hasReachedMax, isFalse);
        expect(cubit.state.knownTotal, 40);
        expect(
          cubit.state.status,
          PluginPagedComicListStatus.loadingMoreFailure,
        );
        await cubit.loadMore();
        expect(
          calls,
          2,
          reason: 'Failure never starts an automatic retry loop',
        );
        bad = false;
        await cubit.retryLoadMore();
        expect(calls, 3);
        expect(cubit.state.list, hasLength(40));
        expect(cubit.state.hasReachedMax, isTrue);
        await cubit.close();
      },
    );
  }
  test(
    'declared terminal duplicate is respected; known zero refresh is a real empty replacement',
    () async {
      const source = 'jm-terminal';
      var zero = false;
      final cubit = collection(
        source,
        (source, _, core, extern) async => zero
            ? packet(source, 1, total: 0)
            : packet(
                source,
                core['page'] as int,
                total: 40,
                duplicate: core['page'] == 2,
                end: core['page'] == 2,
              ),
      );
      await cubit.loadInitial();
      await cubit.loadMore();
      expect(cubit.state.hasReachedMax, isTrue);
      expect(cubit.state.list, hasLength(20));
      expect(cubit.state.knownTotal, 40);
      zero = true;
      expect(await cubit.refresh(), isTrue);
      expect(cubit.state.list, isEmpty);
      expect(cubit.state.knownTotal, 0);
      await cubit.close();
    },
  );
  test(
    'late old-account page cannot repopulate an evicted private snapshot',
    () async {
      const source = 'jm-late-account';
      final pending = Completer<Map<String, dynamic>>();
      final old = collection(
        source,
        (source, _, core, extern) async =>
            core['page'] == 1 ? packet(source, 1, total: 40) : pending.future,
      );
      await old.loadInitial();
      final next = old.loadMore();
      pluginSessionWriteFence.advance(source);
      expect(old.state.list, isEmpty);
      pending.complete(packet(source, 2, total: 40));
      await next;
      await old.close();
      var requests = 0;
      final current = collection(source, (source, _, core, extern) async {
        requests++;
        return packet(source, 1, total: 1, version: 'new-account');
      });
      await current.loadInitial();
      expect(requests, 1);
      expect(current.state.list.single.id, 'new-account-0');
      await current.close();
    },
  );
  test(
    'a tenth-page timeout caches 180 real rows and explicit retry resumes only page ten',
    () async {
      const source = 'jm-timeout-resume';
      var timeout = true;
      final pages = <int>[];
      Future<Map<String, dynamic>> request(
        String source,
        String _,
        Map<String, dynamic> core,
        Map<String, dynamic> extern,
      ) async {
        final page = core['page'] as int;
        pages.add(page);
        if (page == 10 && timeout)
          throw TimeoutException('bounded fixture timeout');
        return packet(source, page);
      }

      final first = collection(source, request);
      await first.loadInitial();
      for (var page = 2; page <= 10; page++) await first.loadMore();
      expect(first.state.list, hasLength(180));
      expect(first.state.page, 9);
      expect(first.state.knownTotal, 267);
      expect(first.state.hasReachedMax, isFalse);
      expect(first.state.status, PluginPagedComicListStatus.loadingMoreFailure);
      await first.close();
      final current = collection(source, request);
      await current.loadInitial();
      expect(pages, hasLength(10));
      expect(current.state.list, hasLength(180));
      expect(
        current.state.status,
        PluginPagedComicListStatus.loadingMoreFailure,
      );
      await current.loadMore();
      expect(pages, hasLength(10));
      timeout = false;
      await current.retryLoadMore();
      expect(pages, [...List.generate(10, (index) => index + 1), 10]);
      expect(current.state.list, hasLength(200));
      for (var page = 11; page <= 14; page++) await current.loadMore();
      expect(current.state.list, hasLength(267));
      expect(current.state.hasReachedMax, isTrue);
      await current.close();
    },
  );
  test(
    'only eight request snapshots remain resident without truncating the live list',
    () async {
      var requests = 0;
      Future<Map<String, dynamic>> request(
        String source,
        String _,
        Map<String, dynamic> core,
        Map<String, dynamic> extern,
      ) async {
        requests++;
        return packet(source, 1, total: 1);
      }

      for (var folder = 0; folder < 9; folder++) {
        final cubit = collection('jm-bounded', request, folder: '$folder');
        await cubit.loadInitial();
        await cubit.close();
      }
      final kept = collection('jm-bounded', request, folder: '8');
      await kept.loadInitial();
      expect(requests, 9);
      await kept.close();
      final evicted = collection('jm-bounded', request, folder: '0');
      await evicted.loadInitial();
      expect(requests, 10);
      await evicted.close();
    },
  );
}
