import 'package:zephyr/service/plugin_account_identity.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/page/comic_list/cubit/jm_collection_snapshots.dart';
import 'package:zephyr/page/comic_list/cubit/jm_collection_metadata.dart';
import 'package:zephyr/page/comic_list/cubit/plugin_paged_comic_list_cubit.dart';
import 'package:zephyr/page/comic_list/cubit/plugin_paged_comic_list_state.dart';
import 'package:zephyr/page/comic_info/models/collect_comic.dart';
import 'package:zephyr/page/comic_info/models/favorite_workflow.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/source_shell/models/source_cloud_favorites.dart';
import 'package:zephyr/page/source_shell/source_experience_preferences.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/jm_list_like_counts.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';
import '../test_helper.dart';

const source = 'jm-durable-fixture';
void account(
  String uid, {
  String token = 'fixture-token',
  String pluginId = source,
}) {
  onSavePluginConfig(
    pluginId,
    'auth.account',
    jsonEncode('fixture-login-$uid'),
    fromRuntime: false,
  );
  onSavePluginConfig(
    pluginId,
    'auth.userInfo',
    jsonEncode({'uid': uid}),
    fromRuntime: false,
  );
  onSavePluginConfig(
    pluginId,
    'auth.jwt',
    jsonEncode(token),
    fromRuntime: false,
  );
  PluginAccountIdentities.confirm(
    pluginId,
    PluginAccountAuthentication(serverIdentity: uid),
    generation: pluginSessionWriteFence.generation(pluginId),
  );
}

UnifiedComicListItem item(String id) => UnifiedComicListItem(
  source: source,
  id: id,
  title: 'Public $id',
  subtitle: '',
  finished: false,
  likesCount: 0,
  viewsCount: 0,
  updatedAt: '',
  cover: UnifiedComicCover(id: id, url: '', path: '', extern: const {}),
  metadata: const [UnifiedComicMetadata(type: 'tags', name: '', value: [])],
  raw: const {'secret': 'not-portable'},
  extern: const {},
);
Map<String, dynamic> page(List<String> ids) => {
  'source': source,
  'data': {
    'total': ids.length,
    'hasReachedMax': true,
    'items': ids.map((id) => item(id).toJson()).toList(),
  },
};
PluginPagedComicListCubit cubit(PluginPageRequest request) =>
    PluginPagedComicListCubit(
      pluginId: source,
      fnPath: 'getCloudFavoriteData',
      privateCollection: true,
      jmSnapshotCache: true,
      coreBuilder: (p) => {'page': p},
      externBuilder: (_) => {'folderId': ''},
      requestPage: request,
    );

void main() {
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    objectbox.pluginConfigBox.removeAll();
    JmCollectionSnapshots.instance.clear();
    JmCollectionMetadata.instance.clearMemory();
    account('one');
  });
  tearDown(() async {
    await JmCollectionSnapshots.instance.flush();
    await JmCollectionMetadata.instance.settle();
  });

  test(
    'JM numbered collection accepts a terminal page in a partial range',
    () async {
      final jm = JmListLikeCounts.source;
      var lastId = 'last';
      final collection = PluginPagedComicListCubit(
        pluginId: jm,
        fnPath: 'getCloudFavoriteData',
        coreBuilder: (page) => {'page': page},
        externBuilder: (_) => const {},
        requestPage: (_, _, core, _) async {
          final page = core['page'] as int;
          return {
            'source': jm,
            'data': {
              'paging': {'page': page, 'pages': 3, 'total': 3},
              'items': [
                item(
                  page == 3 ? lastId : 'page-$page',
                ).copyWith(source: jm).toJson(),
              ],
            },
          };
        },
      );
      addTearDown(collection.close);
      await collection.loadInitial();
      expect(collection.sourcePageCount, 3);
      expect(await collection.jumpToSourcePage(3), isTrue);
      expect(collection.state.hasReachedMax, isTrue);
      expect(collection.state.list.map((row) => row.id), ['last']);
      lastId = 'new-last';
      expect(await collection.refresh(), isTrue);
      expect(collection.state.list.map((row) => row.id), ['new-last']);
      expect(await collection.jumpToSourcePage(2), isTrue);
      await collection.loadMore();
      expect(collection.state.hasReachedMax, isTrue);
      expect(collection.state.list.map((row) => row.id), [
        'page-2',
        'new-last',
      ]);
    },
  );

  for (final (plugin, function) in [
    (bikaPlusSourceId, 'getFavoriteData'),
    (source, 'fixture.numberedFavorites'),
  ]) {
    test(
      'numbered favorite jumps use real pages and preserve cache ($function)',
      () async {
        const scope = {'source': 'cloudFavorite', 'sort': 'dd'};
        final cache = JmCollectionSnapshots.instance;
        account('jump-bika-pages', pluginId: plugin);
        final issued = <int>[];
        final pending = Completer<Map<String, dynamic>>();
        var hold = false;
        Map<String, dynamic> packet(int page) => {
          'source': plugin,
          'data': {
            'paging': {'page': page, 'pages': 8, 'total': 8},
            'items': [item('page-$page').copyWith(source: plugin).toJson()],
          },
        };

        final cubit = PluginPagedComicListCubit(
          pluginId: plugin,
          fnPath: function,
          privateCollection: true,
          jmSnapshotCache: true,
          coreBuilder: (page) => {'page': page},
          externBuilder: (_) => scope,
          requestPage: (_, _, core, _) async {
            final page = core['page'] as int;
            issued.add(page);
            return hold ? pending.future : packet(page == 5 ? 4 : page);
          },
        );
        addTearDown(cubit.close);
        await cubit.loadInitial();
        await cubit.loadMore();
        expect(cubit.sourcePageCount, 8);
        expect(cubit.state.list.map(cubit.reportedPageOf), [1, 2]);
        expect(await cubit.jumpToSourcePage(2), isTrue);
        expect(await cubit.jumpToSourcePage(6), isTrue);
        expect(cubit.numberedRangeStart, 6);
        expect(cubit.state.list.map(cubit.reportedPageOf), [6]);
        await cubit.loadMore();
        expect(cubit.state.list.map(cubit.reportedPageOf), [6, 7]);
        expect(await cubit.jumpToSourcePage(9), isFalse);
        expect(await cubit.jumpToSourcePage(5), isFalse);
        expect(cubit.state.list.map(cubit.reportedPageOf), [6, 7]);
        expect(await cubit.refresh(), isTrue);
        expect(issued, [1, 2, 2, 6, 7, 5, 6, 7]);

        await cache.flush();
        final key = cache.key(plugin, function, const {'page': 1}, scope);
        expect(cache.read(key, plugin)!.list.map((entry) => entry.id), [
          'page-1',
          'page-2',
        ]);
        hold = true;
        final oldJump = cubit.jumpToSourcePage(8);
        pluginSessionWriteFence.advance(plugin);
        pending.complete(packet(8));
        expect(await oldJump, isFalse);
        expect(cubit.state.list, isEmpty);
        expect(cubit.sourcePageCount, isNull);
      },
    );
  }

  test(
    'numbered public catalogs refresh from the chosen source page',
    () async {
      final requests = <int>[];
      final cubit = PluginPagedComicListCubit(
        pluginId: source,
        fnPath: 'fixture.numberedCatalog',
        coreBuilder: (page) => {'page': page},
        externBuilder: (_) => const {},
        requestPage: (_, _, core, _) async {
          final page = core['page'] as int;
          requests.add(page);
          return {
            'source': source,
            'data': {
              'paging': {'page': page, 'pages': 5, 'total': 5},
              'items': [item('public-$page').toJson()],
            },
          };
        },
      );
      addTearDown(cubit.close);
      await cubit.loadInitial();
      expect(await cubit.jumpToSourcePage(3), isTrue);
      await cubit.loadMore();
      expect(await cubit.refresh(), isTrue);
      expect(requests, [1, 3, 4, 3, 4]);
      expect(cubit.state.list.map(cubit.reportedPageOf), [3, 4]);
    },
  );

  test(
    'totals, cursor feeds, and inconsistent page counts do not unlock jumps',
    () async {
      for (final paging in [
        {'total': 1000},
        {'page': 1, 'pages': 4, 'nextCursor': 'cursor-only'},
        {'page': 1, 'pages': 1, 'hasReachedMax': false},
      ]) {
        final requests = <int>[];
        final cubit = PluginPagedComicListCubit(
          pluginId: source,
          fnPath: 'fixture.unsafePaging',
          coreBuilder: (page) => {'page': page},
          externBuilder: (_) => const {},
          requestPage: (_, _, core, _) async {
            final page = core['page'] as int;
            requests.add(page);
            return {
              'source': source,
              'data': {
                'paging': paging,
                'items': [item('normal-row').toJson()],
              },
            };
          },
        );
        try {
          await cubit.loadInitial();
          expect(cubit.state.list.single.id, 'normal-row');
          expect(cubit.sourcePageCount, isNull);
          expect(cubit.hasVerifiedSourcePages, isFalse);
          expect(await cubit.jumpToSourcePage(2), isFalse);
          expect(requests, [1]);
        } finally {
          await cubit.close();
        }
      }
    },
  );

  test(
    'Bika stores reported boundaries but not locally shifted pages',
    () async {
      const plugin = bikaPlusSourceId;
      const function = 'getFavoriteData';
      const scope = {'source': 'cloudFavorite', 'sort': 'dd'};
      final cache = JmCollectionSnapshots.instance;
      account('reported-bika-pages', pluginId: plugin);
      final issuedPages = <int>[];
      PluginPagedComicListCubit open(PluginPageRequest request) =>
          PluginPagedComicListCubit(
            pluginId: plugin,
            fnPath: function,
            privateCollection: true,
            jmSnapshotCache: true,
            coreBuilder: (page) => {'page': page},
            externBuilder: (_) => scope,
            requestPage: request,
          );
      final original = open((_, _, core, _) async {
        final page = core['page'] as int;
        issuedPages.add(page);
        return {
          'source': plugin,
          'data': {
            'paging': {'page': page, 'pages': 2, 'total': 3},
            'items': [
              for (final id in page == 1 ? ['one', 'two'] : ['three'])
                item(id).copyWith(source: plugin).toJson(),
            ],
          },
        };
      });
      await original.loadInitial();
      await original.loadMore();
      expect(issuedPages, [1, 2]);
      expect(original.state.list.map(original.reportedPageOf), [1, 1, 2]);
      await original.close();
      await cache.flush();
      cache.clear();

      final warm = open((_, _, _, _) async => fail('Expected fresh snapshot'));
      addTearDown(warm.close);
      await warm.loadInitial();
      expect(warm.state.list.map(warm.reportedPageOf), [1, 1, 2]);
      expect(warm.sourcePageCount, 2);
      final otherSort = cache.key(
        plugin,
        function,
        const {'page': 1},
        {'source': 'cloudFavorite', 'sort': 'da'},
      );
      expect(cache.officialPageCount(otherSort), isNull);
      await cache.mutate(
        source: plugin,
        account: cache.accountScope(plugin)!,
        generation: pluginSessionWriteFence.generation(plugin),
        id: 'new',
        item: item('new').copyWith(source: plugin),
        favorited: true,
        previouslyFavorited: false,
      );
      expect(warm.state.list.map((row) => row.id), [
        'new',
        'one',
        'two',
        'three',
      ]);
      expect(warm.state.list.map(warm.reportedPageOf), everyElement(isNull));
      expect(warm.sourcePageCount, isNull);
      final key = cache.key(plugin, function, const {'page': 1}, scope);
      expect(cache.pageIdentities(key)[2], isNotEmpty);
      expect(cache.officialPages(key), isEmpty);
      await cache.flush();
      cache.clear();
      final restoredKey = cache.key(plugin, function, const {'page': 1}, scope);
      expect(await cache.restore(restoredKey, plugin), isNotNull);
      expect(cache.pageIdentities(restoredKey)[2], isNotEmpty);
      expect(cache.officialPages(restoredKey), isEmpty);
    },
  );

  test(
    'legacy favorites expose verified bounds before the tail probe',
    () async {
      final cache = JmCollectionSnapshots.instance;
      const query = {'source': 'cloudFavorite', 'sort': 'dd'};
      const function = 'getCloudFavoriteData';
      final generation = pluginSessionWriteFence.generation(source);
      final key = cache.key(source, function, const {'page': 1}, query);
      cache.write(
        key,
        source,
        generation,
        PluginPagedComicListState(
          status: PluginPagedComicListStatus.success,
          list: [item('first'), item('second')],
          page: 2,
          knownTotal: 3,
        ),
        pageIdentities: {
          1: ['$source:first'],
          2: ['$source:second'],
        },
      );
      final reachedTail = Completer<void>();
      final tail = Completer<Map<String, dynamic>>();
      Map<String, dynamic> packet(int page, String id) => {
        'source': source,
        'data': {
          'paging': {'page': page, 'pages': 3, 'total': 3},
          'items': [item(id).toJson()],
        },
      };
      final cubit = PluginPagedComicListCubit(
        pluginId: source,
        fnPath: function,
        privateCollection: true,
        jmSnapshotCache: true,
        coreBuilder: (page) => {'page': page},
        externBuilder: (_) => query,
        requestPage: (_, _, core, _) async {
          final page = core['page'] as int;
          if (page == 1) return packet(1, 'first');
          reachedTail.complete();
          return tail.future;
        },
      );
      addTearDown(cubit.close);
      await cubit.loadInitial();
      expect(cubit.sourcePageCount, isNull);
      final refresh = cubit.refresh();
      await reachedTail.future;
      expect(cubit.sourcePageCount, 3);
      expect(cubit.firstVerifiedSourcePage, 1);
      expect(cubit.state.list.map((row) => row.id), ['first', 'second']);
      tail.complete(packet(2, 'second'));
      expect(await refresh, isTrue);
      expect(cache.officialPageCount(key), 3);
    },
  );

  test(
    'a new verified owner retires an in-flight same-session collection',
    () async {
      final oldRefresh = Completer<Map<String, dynamic>>();
      var calls = 0;
      final current = cubit((_, __, ___, ____) async {
        if (++calls == 1) return page(['account-one-work']);
        if (calls == 2) return oldRefresh.future;
        return page(['account-two-work']);
      });
      addTearDown(() async {
        if (!oldRefresh.isCompleted) oldRefresh.complete(page([]));
        await current.close();
      });
      await current.loadInitial();
      expect(current.state.list.single.id, 'account-one-work');
      final pending = current.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(calls, 2);

      final generation = pluginSessionWriteFence.generation(source);
      expect(
        PluginAccountIdentities.confirm(
          source,
          const PluginAccountAuthentication(serverIdentity: 'two'),
          generation: generation,
        ),
        isTrue,
      );
      expect(pluginSessionWriteFence.generation(source), generation);
      expect(current.state.list, isEmpty);

      await current.loadInitial();
      expect(current.state.list.single.id, 'account-two-work');
      oldRefresh.complete(page(['late-account-one-work']));
      expect(await pending, isFalse);
      expect(current.state.list.single.id, 'account-two-work');
    },
  );
  test(
    'cold collection restores before gated refresh and a token refresh keeps its account scope',
    () async {
      final first = cubit((_, __, ___, ____) async => page(['one', 'two']));
      await first.loadInitial();
      await JmCollectionSnapshots.instance.flush();
      final oldScope = JmCollectionSnapshots.instance.accountScope(source);
      await first.close();
      JmCollectionSnapshots.instance
          .clear(); // Simulate discarded process memory.
      pluginSessionWriteFence.advance(source);
      account('one', token: 'refreshed-fixture-token');
      expect(JmCollectionSnapshots.instance.accountScope(source), oldScope);
      final refresh = Completer<Map<String, dynamic>>();
      final second = cubit((_, __, ___, ____) => refresh.future);
      await second.loadInitial();
      expect(second.state.list.map((e) => e.id), ['one', 'two']);
      expect(second.state.knownTotal, 2);
      expect(second.state.status, PluginPagedComicListStatus.success);
      expect(second.refreshing, isFalse);
      // Warm restoration performs no implicit all-page refresh.
      final refreshTask = second.refresh();
      final stored = (await SharedPreferences.getInstance()).getKeys().where(
        (k) => k.startsWith(JmCollectionSnapshots.prefix),
      );
      expect(stored, hasLength(1));
      expect(PortablePreferences.owns(stored.single), isFalse);
      expect(
        PortablePreferences.owns('${JmCollectionMetadata.prefix}$oldScope'),
        isFalse,
      );
      expect(
        (await SharedPreferences.getInstance()).getString(stored.single),
        isNot(contains('not-portable')),
      );
      refresh.completeError(StateError('fixture offline refresh'));
      await refreshTask;
      expect(second.state.list.map((e) => e.id), ['one', 'two']);
      expect(second.refreshError, isNotNull);
      await second.close();
    },
  );
  test('another account cannot read the former account snapshot', () async {
    final first = cubit((_, __, ___, ____) async => page(['account-one-work']));
    await first.loadInitial();
    await JmCollectionSnapshots.instance.flush();
    await first.close();
    JmCollectionSnapshots.instance.clear();
    pluginSessionWriteFence.beginSessionChange(source);
    // Simulate the completed account switch before any new list response.
    final owner = pluginSessionWriteFence.generation(source);
    pluginSessionWriteFence.seal(source, owner);
    account('two');
    final response = Completer<Map<String, dynamic>>(),
        reached = Completer<void>();
    final second = cubit((_, __, ___, ____) {
      reached.complete();
      return response.future;
    });
    final load = second.loadInitial();
    await reached.future;
    expect(second.state.list, isEmpty);
    response.complete(page(['account-two-work']));
    await load;
    expect(second.state.list.single.id, 'account-two-work');
    await second.close();
  });
  test(
    'confirmed removal and move patch only the matching account and official folder snapshots',
    () async {
      final cache = JmCollectionSnapshots.instance;
      final scope = cache.accountScope(source)!;
      String key(String folder) => cache.key(
        source,
        'getCloudFavoriteData',
        {'page': 1},
        {'folderId': folder},
      );
      final all = key(''), old = key('old'), next = key('next');
      final state = PluginPagedComicListState(
        status: PluginPagedComicListStatus.success,
        list: [item('one')],
        knownTotal: 1,
        hasReachedMax: true,
      );
      for (final k in [all, old])
        cache.write(
          k,
          source,
          pluginSessionWriteFence.generation(source),
          state,
        );
      cache.write(
        next,
        source,
        pluginSessionWriteFence.generation(source),
        state.copyWith(list: [], knownTotal: 0),
      );
      await cache.flush();
      cache.clear();
      await cache.mutate(
        source: source,
        account: scope,
        generation: pluginSessionWriteFence.generation(source),
        id: 'one',
        favorited: true,
        previouslyFavorited: true,
        item: item('one'),
        movedToFolder: 'next',
      );
      expect((await cache.restore(all, source))!.list.single.id, 'one');
      expect((await cache.restore(old, source))!.list, isEmpty);
      expect((await cache.restore(next, source))!.list.single.id, 'one');
      await cache.mutate(
        source: source,
        account: scope,
        generation: pluginSessionWriteFence.generation(source),
        id: 'one',
        favorited: false,
        previouslyFavorited: true,
      );
      expect((await cache.restore(all, source))!.knownTotal, 0);
      expect((await cache.restore(next, source))!.list, isEmpty);
    },
  );
  for (final committed in [true, false]) {
    testWidgets(
      'real favorite workflow confirmed response updates the durable snapshot (committed=$committed)',
      (tester) async {
        final cache = JmCollectionSnapshots.instance;
        final key = cache.key(
          source,
          'getCloudFavoriteData',
          {'page': 1},
          {'folderId': ''},
        );
        cache.write(
          key,
          source,
          pluginSessionWriteFence.generation(source),
          PluginPagedComicListState(
            status: PluginPagedComicListStatus.success,
            list: [item('one')],
            knownTotal: 1,
            hasReachedMax: true,
          ),
        );
        await cache.flush();
        late BuildContext context;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (c) {
                context = c;
                return const SizedBox();
              },
            ),
          ),
        );
        final result = await executeCloudFavoriteWorkflow(
          context: context,
          from: source,
          comicId: 'one',
          action: FavoriteWorkflowAction.removeAll,
          currentStatus: true,
          invokePlugin:
              ({
                required pluginId,
                required fnPath,
                required core,
                required extern,
              }) async => {
                'status': 'completed',
                'favorited': false,
                'committed': committed,
              },
        );
        expect(result.committed, committed);
        cache.clear();
        // Rebind the public request descriptor exactly as a new route does.
        cache.key(
          source,
          'getCloudFavoriteData',
          {'page': 1},
          {'folderId': ''},
        );
        final restored = await cache.restore(key, source);
        expect(restored!.list, isEmpty);
        expect(restored.knownTotal, 0);
      },
    );
  }
  test(
    'a stale unchanged collection checks its head and one recorded page',
    () async {
      Map<String, dynamic> response(int p) => {
        'source': source,
        'data': {
          'total': 4,
          'hasReachedMax': p == 2,
          'items': (p == 1 ? ['one', 'two'] : ['three', 'four'])
              .map((id) => item(id).toJson())
              .toList(),
        },
      };
      final first = cubit(
        (_, __, core, ___) async => response(core['page'] as int),
      );
      await first.loadInitial();
      await first.loadMore();
      await JmCollectionSnapshots.instance.flush();
      await first.close();
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getKeys().singleWhere(
        (key) => key.startsWith(JmCollectionSnapshots.prefix),
      );
      final raw = jsonDecode(prefs.getString(key)!) as Map<String, dynamic>;
      raw['savedAt'] = 0;
      await prefs.setString(key, jsonEncode(raw));
      JmCollectionSnapshots.instance.clear();
      final gate = Completer<Map<String, dynamic>>();
      final pages = <int>[];
      final second = cubit((_, __, core, ___) {
        final p = core['page'] as int;
        pages.add(p);
        return p == 1 ? gate.future : Future.value(response(p));
      });
      await second.loadInitial();
      expect(second.state.list.map((row) => row.id), [
        'one',
        'two',
        'three',
        'four',
      ]);
      final checking = second.refresh();
      gate.complete(response(1));
      expect(await checking, isTrue);
      expect(pages, [1, 2]);
      expect(second.state.page, 2);
      expect(second.state.hasReachedMax, isTrue);
      await second.close();
    },
  );

  test(
    'cold restore retains exact page boundaries and advances its bounded probe',
    () async {
      final requests = <int>[];
      Future<Map<String, dynamic>> request(
        String _,
        String __,
        Map<String, dynamic> core,
        Map<String, dynamic> ___,
      ) async {
        final p = core['page'] as int;
        requests.add(p);
        return {
          'source': source,
          'data': {
            'total': 6,
            'hasReachedMax': p == 3,
            'items': [
              for (var i = (p - 1) * 2; i < p * 2; i++) item('$i').toJson(),
            ],
          },
        };
      }

      final first = cubit(request);
      await first.loadInitial();
      await first.loadMore();
      await first.loadMore();
      requests.clear();
      expect(await first.checkForUpdates(), isTrue);
      expect(requests, [1, 2]);
      await first.close();
      await JmCollectionSnapshots.instance.flush();
      JmCollectionSnapshots.instance.clear();
      final second = cubit(request);
      requests.clear();
      final restoring = second.loadInitial();
      final checking = second.checkForUpdates();
      await restoring;
      expect(await checking, isTrue);
      expect(requests, [1, 3]);
      expect(second.state.list, hasLength(6));
      await second.close();
    },
  );

  test(
    'confirmed partial deletion retains invalid cursor through a failed check until retry repairs its range',
    () async {
      final requests = <int>[];
      var removed = false;
      final gate = Completer<Map<String, dynamic>>();
      Map<String, dynamic> response(int p) {
        final ids = removed
            ? ['one', 'three', 'four', 'five', 'six']
            : ['one', 'two', 'three', 'four', 'five', 'six'];
        return {
          'source': source,
          'data': {
            'total': ids.length,
            'hasReachedMax': p == 3,
            'items': ids
                .skip((p - 1) * 2)
                .take(2)
                .map((id) => item(id).toJson())
                .toList(),
          },
        };
      }

      var failProbe = true;
      final current = cubit((_, __, core, ___) {
        final p = core['page'] as int;
        requests.add(p);
        if (removed && failProbe) return gate.future;
        return Future.value(response(p));
      });
      await current.loadInitial();
      await current.loadMore();
      requests.clear();
      removed = true;
      await JmCollectionSnapshots.instance.mutate(
        source: source,
        account: JmCollectionSnapshots.instance.accountScope(source)!,
        generation: pluginSessionWriteFence.generation(source),
        id: 'two',
        favorited: false,
        previouslyFavorited: true,
      );
      final failed = current.refresh();
      gate.completeError(StateError('fixture failed boundary check'));
      expect(await failed, isFalse);
      expect(current.state.list.map((row) => row.id), ['one', 'three', 'four']);
      failProbe = false;
      expect(await current.refresh(), isTrue);
      expect(requests, [1, 1, 2]);
      expect(current.state.list.map((row) => row.id), [
        'one',
        'three',
        'four',
        'five',
      ]);
      await current.loadMore();
      expect(requests.last, 3);
      expect(current.state.list.map((row) => row.id), [
        'one',
        'three',
        'four',
        'five',
        'six',
      ]);
      await current.close();
    },
  );

  test(
    'legacy cache learns exact boundaries once then uses bounded checks',
    () async {
      final cache = JmCollectionSnapshots.instance;
      final key = cache.key(
        source,
        'getCloudFavoriteData',
        {'page': 1},
        {'folderId': ''},
      );
      cache.write(
        key,
        source,
        pluginSessionWriteFence.generation(source),
        PluginPagedComicListState(
          status: PluginPagedComicListStatus.success,
          list: [for (var i = 0; i < 6; i++) item('$i')],
          page: 3,
          knownTotal: 6,
          hasReachedMax: true,
        ),
      );
      final pages = <int>[];
      final current = cubit((_, __, core, ___) async {
        final p = core['page'] as int;
        pages.add(p);
        return {
          'source': source,
          'data': {
            'total': 6,
            'hasReachedMax': p == 3,
            'items': [
              for (var i = (p - 1) * 2; i < p * 2; i++) item('$i').toJson(),
            ],
          },
        };
      });
      await current.loadInitial();
      expect(await current.checkForUpdates(), isTrue);
      expect(pages, [1, 2, 3]);
      pages.clear();
      expect(await current.checkForUpdates(), isTrue);
      expect(pages, [1, 2]);
      await current.close();
    },
  );

  test(
    'stored UID is not proof and unmounted source caches are erased from disk',
    () async {
      final first = cubit((_, __, ___, ____) async => page(['one']));
      await first.loadInitial();
      await JmCollectionSnapshots.instance.flush();
      await first.close();
      JmCollectionSnapshots.instance.clear();
      PluginAccountIdentities.reject(
        source,
        generation: pluginSessionWriteFence.generation(source),
      );
      expect(JmCollectionSnapshots.instance.accountScope(source), isNull);
      final response = Completer<Map<String, dynamic>>(),
          requested = Completer<void>();
      final unconfirmed = cubit((_, __, ___, ____) {
        requested.complete();
        return response.future;
      });
      final loading = unconfirmed.loadInitial();
      await requested.future;
      expect(unconfirmed.state.list, isEmpty);
      response.complete(page(['fresh']));
      await loading;
      await unconfirmed.close();
      await JmCollectionSnapshots.instance.clearDisk(source: source);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where(
          (key) => key.startsWith(JmCollectionSnapshots.prefix),
        ),
        isEmpty,
      );
      expect(
        prefs.getKeys().where(
          (key) => key.startsWith(JmCollectionMetadata.prefix),
        ),
        isEmpty,
      );
    },
  );

  test(
    'rich cached facets and removed signed cover parameters do not trigger a full page rescan',
    () async {
      final cache = JmCollectionSnapshots.instance;
      final key = cache.key(
        source,
        'getCloudFavoriteData',
        {'page': 1},
        {'folderId': ''},
      );
      final rich = item('one').copyWith(
        metadata: const [
          UnifiedComicMetadata(
            type: 'tags',
            name: '',
            value: ['acquired-detail-tag'],
          ),
        ],
        cover: item(
          'one',
        ).cover.copyWith(url: 'https://example.invalid/cover?token=temporary'),
      );
      cache.write(
        key,
        source,
        pluginSessionWriteFence.generation(source),
        PluginPagedComicListState(
          status: PluginPagedComicListStatus.success,
          list: [rich, item('two')],
          page: 2,
          knownTotal: 2,
          hasReachedMax: true,
        ),
        pageIdentities: {
          1: ['$source:one'],
          2: ['$source:two'],
        },
      );
      await cache.flush();
      cache.clear();
      final prefs = await SharedPreferences.getInstance();
      final storageKey = '${JmCollectionSnapshots.prefix}$key';
      final raw =
          jsonDecode(prefs.getString(storageKey)!) as Map<String, dynamic>;
      raw['savedAt'] = 0;
      await prefs.setString(storageKey, jsonEncode(raw));
      final gate = Completer<Map<String, dynamic>>();
      final pages = <int>[];
      final next = cubit((_, __, core, ___) {
        pages.add(core['page'] as int);
        return core['page'] == 1
            ? gate.future
            : Future.value({
                'source': source,
                'data': {
                  'total': 2,
                  'hasReachedMax': true,
                  'items': [item('two').toJson()],
                },
              });
      });
      await next.loadInitial();
      final checking = next.refresh();
      final thin = rich.copyWith(metadata: const []);
      gate.complete({
        'source': source,
        'data': {
          'total': 2,
          'hasReachedMax': false,
          'items': [thin.toJson()],
        },
      });
      expect(await checking, isTrue);
      expect(pages, [1, 2]);
      expect(next.state.list, hasLength(2));
      expect(next.state.list.first.metadata.single.value, [
        'acquired-detail-tag',
      ]);
      await next.close();
    },
  );

  test(
    'a stale membership probe adopts explicit new first-page tags without fetching later pages',
    () async {
      final cache = JmCollectionSnapshots.instance;
      final key = cache.key(
        source,
        'getCloudFavoriteData',
        {'page': 1},
        {'folderId': ''},
      );
      final old = item('one').copyWith(
        metadata: const [
          UnifiedComicMetadata(type: 'tags', name: '', value: ['old-tag']),
          UnifiedComicMetadata(
            type: 'author',
            name: '',
            value: ['known-author'],
          ),
        ],
      );
      cache.write(
        key,
        source,
        pluginSessionWriteFence.generation(source),
        PluginPagedComicListState(
          status: PluginPagedComicListStatus.success,
          list: [old, item('two')],
          page: 2,
          knownTotal: 2,
          hasReachedMax: true,
        ),
        pageIdentities: {
          1: ['$source:one'],
          2: ['$source:two'],
        },
      );
      await cache.flush();
      cache.clear();
      final prefs = await SharedPreferences.getInstance();
      final storageKey = '${JmCollectionSnapshots.prefix}$key';
      final raw =
          jsonDecode(prefs.getString(storageKey)!) as Map<String, dynamic>;
      raw['savedAt'] = 0;
      await prefs.setString(storageKey, jsonEncode(raw));
      final gate = Completer<Map<String, dynamic>>();
      final pages = <int>[];
      final next = cubit((_, __, core, ___) {
        pages.add(core['page'] as int);
        return core['page'] == 1
            ? gate.future
            : Future.value({
                'source': source,
                'data': {
                  'total': 2,
                  'hasReachedMax': true,
                  'items': [item('two').toJson()],
                },
              });
      });
      await next.loadInitial();
      final checking = next.refresh(); // Joins the already-running stale probe.
      final fresh = item('one').copyWith(
        metadata: const [
          UnifiedComicMetadata(type: 'tags', name: '', value: ['new-tag']),
        ],
      );
      gate.complete({
        'source': source,
        'data': {
          'total': 2,
          'hasReachedMax': false,
          'items': [fresh.toJson()],
        },
      });
      expect(await checking, isTrue);
      expect(pages, [1, 2]);
      expect(next.state.list.map((row) => row.id), ['one', 'two']);
      expect(
        next.state.list.first.metadata
            .firstWhere((m) => m.type == 'tags')
            .value,
        ['new-tag'],
      );
      expect(
        next.state.list.first.metadata
            .firstWhere((m) => m.type == 'author')
            .value,
        ['known-author'],
      );
      expect(next.state.page, 2);
      await next.close();
    },
  );
  test(
    'warm and empty successful indexes do not reload on repeated initialization',
    () async {
      var requests = 0;
      final current = cubit((_, __, ___, ____) async {
        requests++;
        return page([]);
      });
      await current.loadInitial();
      await current.loadInitial();
      expect(requests, 1);
      await current.close();
      final reopened = cubit((_, __, ___, ____) async {
        requests++;
        return page([]);
      });
      await reopened.loadInitial();
      await reopened.loadInitial();
      expect(requests, 1);
      await reopened.refresh();
      expect(
        requests,
        2,
        reason: 'Explicit refresh still revalidates empty success',
      );
      await reopened.close();
    },
  );

  test(
    'nonempty warm index initialization does not rescan a successful list',
    () async {
      var requests = 0;
      final current = cubit((_, __, ___, ____) async {
        requests++;
        return page(['one']);
      });
      await current.loadInitial();
      await current.loadInitial();
      expect(requests, 1);
      await current.refresh();
      expect(requests, 2);
      await current.close();
    },
  );

  test(
    'failed stale check is not retried by every filter reentry, explicit refresh bypasses backoff',
    () async {
      final cache = JmCollectionSnapshots.instance;
      final key = cache.key(
        source,
        'getCloudFavoriteData',
        {'page': 1},
        {'folderId': ''},
      );
      cache.write(
        key,
        source,
        pluginSessionWriteFence.generation(source),
        PluginPagedComicListState(
          status: PluginPagedComicListStatus.success,
          list: [item('one')],
          knownTotal: 1,
          hasReachedMax: true,
        ),
        checkedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
      var requests = 0;
      Future<Map<String, dynamic>> offline(
        String _,
        String __,
        Map<String, dynamic> ___,
        Map<String, dynamic> ____,
      ) async {
        requests++;
        throw StateError('fixture offline');
      }

      final first = cubit(offline)..setReadActive(true);
      await first.loadInitial();
      await Future<void>.delayed(Duration.zero);
      expect(first.state.list.single.id, 'one');
      await first.close();
      final second = cubit(offline)..setReadActive(true);
      await second.loadInitial();
      await Future<void>.delayed(Duration.zero);
      expect(
        requests,
        1,
        reason: 'Changing condition must not hammer a failed request',
      );
      await second.refresh();
      expect(requests, 2);
      await second.close();
    },
  );

  test(
    'more than eight request indexes survive memory eviction and all receive confirmed removals',
    () async {
      final cache = JmCollectionSnapshots.instance;
      final keys = <String>[];
      for (var folder = 0; folder < 12; folder++) {
        final key = cache.key(
          source,
          'getCloudFavoriteData',
          {'page': 1},
          {'folderId': '$folder'},
        );
        keys.add(key);
        cache.write(
          key,
          source,
          pluginSessionWriteFence.generation(source),
          PluginPagedComicListState(
            status: PluginPagedComicListStatus.success,
            list: [item('one')],
            knownTotal: 1,
            hasReachedMax: true,
          ),
        );
      }
      await cache.flush();
      cache.clear();
      for (var folder = 0; folder < 12; folder++) {
        cache.key(
          source,
          'getCloudFavoriteData',
          {'page': 1},
          {'folderId': '$folder'},
        );
        expect((await cache.restore(keys[folder], source))?.knownTotal, 1);
      }
      await cache.mutate(
        source: source,
        account: cache.accountScope(source)!,
        generation: pluginSessionWriteFence.generation(source),
        id: 'one',
        favorited: false,
        previouslyFavorited: true,
      );
      cache.clear();
      for (var folder = 0; folder < 12; folder++) {
        cache.key(
          source,
          'getCloudFavoriteData',
          {'page': 1},
          {'folderId': '$folder'},
        );
        expect(
          (await cache.restore(keys[folder], source))!.knownTotal,
          0,
          reason: 'Unmounted and evicted folder $folder must be patched',
        );
      }
    },
  );

  for (final (plugin, function, sortKey, newest, other) in [
    (JmListLikeCounts.source, 'getCloudFavoriteData', 'order', 'mr', 'mp'),
    (bikaPlusSourceId, 'getFavoriteData', 'sort', 'dd', 'da'),
    (
      copyComicSourceId,
      'getCloudFavoriteData',
      'ordering',
      '-datetime_modifier',
      'datetime_modifier',
    ),
  ]) {
    test(
      'the confirmed add reaches the warm newest list ($sortKey=$newest)',
      () async {
        account('confirmed-default', pluginId: plugin);
        final cache = JmCollectionSnapshots.instance;
        final generation = pluginSessionWriteFence.generation(plugin);
        const sourceExtern = {'source': 'cloudFavorite'};
        String key(Map<String, dynamic> extern) =>
            cache.key(plugin, function, {'page': 1}, extern);
        final preview = key(sourceExtern);
        final newestKey = key({...sourceExtern, sortKey: newest});
        final otherKey = key({...sourceExtern, sortKey: other});
        final filteredKey = key({
          ...sourceExtern,
          sortKey: newest,
          'tag': 'red',
        });
        final first = item('one').copyWith(source: plugin);
        final pending = item('new').copyWith(source: plugin);
        final before = PluginPagedComicListState(
          status: PluginPagedComicListStatus.success,
          list: [first],
          knownTotal: 1,
          hasReachedMax: true,
        );
        for (final key in [preview, newestKey, otherKey, filteredKey]) {
          cache.write(key, plugin, generation, before);
        }
        final warm = PluginPagedComicListCubit(
          pluginId: plugin,
          fnPath: function,
          privateCollection: true,
          jmSnapshotCache: true,
          coreBuilder: (page) => {'page': page},
          externBuilder: (_) => {...sourceExtern, sortKey: newest},
          requestPage: (_, _, _, _) async => fail('Warm read was not needed'),
        );
        addTearDown(() async {
          if (!warm.isClosed) await warm.close();
        });
        await warm.loadInitial();
        await cache.mutate(
          source: plugin,
          account: cache.accountScope(plugin)!,
          generation: generation,
          id: pending.id,
          item: pending,
          favorited: true,
          previouslyFavorited: false,
        );
        expect(cache.read(preview, plugin)!.list.map((row) => row.id), [
          'new',
          'one',
        ]);
        expect(warm.state.list.map((row) => row.id), ['new', 'one']);
        expect(warm.state.knownTotal, 2);
        expect(cache.read(otherKey, plugin)!.list.map((row) => row.id), [
          'one',
        ]);
        expect(cache.read(filteredKey, plugin)!.list.map((row) => row.id), [
          'one',
        ]);
        expect(cache.read(filteredKey, plugin)!.knownTotal, isNull);
        expect(cache.requiresRebuild(otherKey), isTrue);

        await warm.close();
        cache.clear();
        final unmounted = item('unmounted').copyWith(source: plugin);
        await cache.mutate(
          source: plugin,
          account: cache.accountScope(plugin)!,
          generation: generation,
          id: unmounted.id,
          item: unmounted,
          favorited: true,
          previouslyFavorited: false,
        );
        expect(cache.read(newestKey, plugin)!.list.map((row) => row.id), [
          'unmounted',
          'new',
          'one',
        ]);
      },
    );
  }

  test(
    'unknown remote conditions never inherit the global favorite count delta',
    () async {
      final cache = JmCollectionSnapshots.instance;
      final key = cache.key(
        source,
        'getCloudFavoriteData',
        {'page': 1},
        {'tag': 'red'},
      );
      cache.write(
        key,
        source,
        pluginSessionWriteFence.generation(source),
        PluginPagedComicListState(
          status: PluginPagedComicListStatus.success,
          list: [item('one')],
          knownTotal: 1,
          hasReachedMax: true,
        ),
      );
      await cache.mutate(
        source: source,
        account: cache.accountScope(source)!,
        generation: pluginSessionWriteFence.generation(source),
        id: 'unseen',
        favorited: true,
        previouslyFavorited: false,
        item: item('unseen'),
      );
      final patched = cache.read(key, source)!;
      expect(patched.list.map((row) => row.id), ['one']);
      expect(
        patched.knownTotal,
        isNull,
        reason: 'The new work may not satisfy the remote condition',
      );
      expect(patched.hasReachedMax, isFalse);
    },
  );

  test(
    'invalidated sorted index rereads prior pages even when the first page is unchanged',
    () async {
      final cache = JmCollectionSnapshots.instance;
      final key = cache.key(
        source,
        'getCloudFavoriteData',
        {'page': 1},
        {'folderId': '', 'order': 'oldest'},
      );
      cache.write(
        key,
        source,
        pluginSessionWriteFence.generation(source),
        PluginPagedComicListState(
          status: PluginPagedComicListStatus.success,
          list: [item('one'), item('three')],
          page: 2,
          knownTotal: 2,
          hasReachedMax: true,
        ),
      );
      await cache.mutate(
        source: source,
        account: cache.accountScope(source)!,
        generation: pluginSessionWriteFence.generation(source),
        id: 'two',
        favorited: true,
        previouslyFavorited: false,
        item: item('two'),
      );
      expect(cache.read(key, source)!.hasReachedMax, isFalse);
      final requests = <int>[];
      final current = PluginPagedComicListCubit(
        pluginId: source,
        fnPath: 'getCloudFavoriteData',
        privateCollection: true,
        jmSnapshotCache: true,
        coreBuilder: (p) => {'page': p},
        externBuilder: (_) => {'folderId': '', 'order': 'oldest'},
        requestPage: (_, __, core, ___) async {
          final p = core['page'] as int;
          requests.add(p);
          return {
            'source': source,
            'data': {
              'total': 3,
              'hasReachedMax': p == 2,
              'items': (p == 1 ? [item('one')] : [item('two'), item('three')])
                  .map((e) => e.toJson())
                  .toList(),
            },
          };
        },
      );
      await current.loadInitial();
      await current.refresh();
      expect(requests, [1, 2]);
      expect(current.state.list.map((e) => e.id), ['one', 'two', 'three']);
      await current.close();
    },
  );
  test(
    'commits clear old cooldown, deduplicate operation IDs and fence late reads',
    () async {
      final cache = JmCollectionSnapshots.instance;
      final generation = pluginSessionWriteFence.generation(source);
      final key = cache.key(
        source,
        'getCloudFavoriteData',
        {'page': 1},
        {'folderId': ''},
      );
      final before = PluginPagedComicListState(
        status: PluginPagedComicListStatus.success,
        list: [item('one'), item('two')],
        knownTotal: 2,
        hasReachedMax: true,
      );
      cache.write(key, source, generation, before);
      final revision = cache.revision(source);
      cache.checkFailed(key);
      expect(cache.canCheck(key), isFalse);
      Future<void> commit() => cache.mutate(
        source: source,
        account: cache.accountScope(source)!,
        generation: generation,
        id: 'one',
        favorited: false,
        previouslyFavorited: true,
        operationId: 'confirmed-remove',
      );
      await commit();
      await commit();
      expect(cache.canCheck(key), isTrue);
      expect(cache.read(key, source)!.knownTotal, 1);
      expect(cache.revision(source), revision + 1);
      cache.write(key, source, generation, before, expectedRevision: revision);
      expect(cache.read(key, source)!.list.map((item) => item.id), ['two']);
      expect(
        cache.acceptsRemoteState(key, before),
        isFalse,
        reason:
            'An eventually consistent site read cannot immediately undo a confirmed removal',
      );
      expect(
        await cache.observePreview(
          key: key,
          source: source,
          generation: generation,
          expectedRevision: revision,
          items: before.list,
          total: 2,
        ),
        isNull,
      );
      cache.clear();
      cache.key(source, 'getCloudFavoriteData', {'page': 1}, {'folderId': ''});
      expect((await cache.restore(key, source))!.list.map((item) => item.id), [
        'two',
      ]);
    },
  );

  test(
    'an explicit target add preserves other folders and sorted totals stay exact',
    () async {
      final cache = JmCollectionSnapshots.instance;
      final generation = pluginSessionWriteFence.generation(source);
      String key(String folder) => cache.key(
        source,
        'getCloudFavoriteData',
        {'page': 1},
        {'folderId': folder, 'order': 'oldest'},
      );
      final old = key('old'), target = key('target'), all = key('');
      final full = PluginPagedComicListState(
        status: PluginPagedComicListStatus.success,
        list: [item('one')],
        knownTotal: 1,
        hasReachedMax: true,
      );
      cache.write(old, source, generation, full);
      cache.write(all, source, generation, full);
      cache.write(
        target,
        source,
        generation,
        full.copyWith(list: [], knownTotal: 0),
      );
      await cache.mutate(
        source: source,
        account: cache.accountScope(source)!,
        generation: generation,
        id: 'one',
        favorited: true,
        previouslyFavorited: true,
        item: item('one'),
        addedToFolder: 'target',
      );
      expect(cache.read(old, source)!.list.single.id, 'one');
      expect(cache.read(old, source)!.knownTotal, 1);
      expect(cache.read(all, source)!.knownTotal, 1);
      expect(cache.read(target, source)!.knownTotal, 1);
      expect(
        cache.read(target, source)!.list,
        isEmpty,
        reason:
            'A confirmed target does not establish the row position in an arbitrary sort',
      );
      expect(cache.requiresRebuild(target), isTrue);
    },
  );

  test(
    'unknown folder changes invalidate loaded members without guessing removal',
    () async {
      final cache = JmCollectionSnapshots.instance;
      final generation = pluginSessionWriteFence.generation(source);
      final key = cache.key(
        source,
        'getCloudFavoriteData',
        {'page': 1},
        {'folderId': 'old'},
      );
      cache.write(
        key,
        source,
        generation,
        PluginPagedComicListState(
          status: PluginPagedComicListStatus.success,
          list: [item('one')],
          knownTotal: 1,
          hasReachedMax: true,
        ),
      );
      await cache.mutate(
        source: source,
        account: cache.accountScope(source)!,
        generation: generation,
        id: 'one',
        favorited: true,
        previouslyFavorited: true,
      );
      expect(cache.read(key, source)!.list.single.id, 'one');
      expect(cache.read(key, source)!.knownTotal, isNull);
      expect(cache.requiresRebuild(key), isTrue);
    },
  );

  test(
    'first Copy profile preview checks the persisted equivalent default list',
    () async {
      const plugin = copyComicSourceId;
      account('same-copy-account', pluginId: plugin);
      final cache = JmCollectionSnapshots.instance;
      final generation = pluginSessionWriteFence.generation(plugin);
      final listKey = cache.key(
        plugin,
        'getCloudFavoriteData',
        {'page': 1},
        {'source': 'cloudFavorite', 'ordering': '-datetime_modifier'},
      );
      final previous = item('previous').copyWith(source: plugin);
      final newest = item('newest').copyWith(source: plugin);
      cache.write(
        listKey,
        plugin,
        generation,
        PluginPagedComicListState(
          status: PluginPagedComicListStatus.success,
          list: [previous],
          knownTotal: 1,
          hasReachedMax: true,
        ),
      );
      await cache.flush();
      cache.clear();
      final query = SourceCloudFavoriteQuery(
        plugin,
        functionPath: 'getCloudFavoriteData',
      );
      expect(query.key, isNot(listKey));
      expect(query.equivalentListKey, listKey);
      final revision = cache.revision(plugin);
      final observed = await cache.observePreview(
        key: query.key,
        equivalentListKey: query.equivalentListKey,
        source: plugin,
        generation: generation,
        expectedRevision: revision,
        items: [newest, previous],
        total: 2,
        headRead: cache.beginHeadRead(query.key),
      );
      expect(observed?.list.map((row) => row.id), ['newest', 'previous']);
      expect(cache.revision(plugin), revision + 1);
      expect(cache.requiresRebuild(listKey), isTrue);
      expect(cache.read(listKey, plugin)!.list.map((row) => row.id), [
        'previous',
      ]);
    },
  );

  test(
    'changed same-count previews dirty persisted variants and preserve loaded ranges',
    () async {
      final cache = JmCollectionSnapshots.instance;
      final generation = pluginSessionWriteFence.generation(source);
      String key(String folder, String sort) => cache.key(
        source,
        'getCloudFavoriteData',
        {'page': 1},
        {'source': 'cloudFavorite', 'folderId': folder, 'order': sort},
      );
      final main = key('', 'mr'),
          otherSort = key('', 'oldest'),
          folder = key('folder', 'mr');
      final full = PluginPagedComicListState(
        status: PluginPagedComicListStatus.success,
        list: [item('one'), item('two')],
        knownTotal: 2,
        page: 2,
        hasReachedMax: true,
      );
      for (final query in [main, otherSort, folder]) {
        cache.write(
          query,
          source,
          generation,
          full,
          pageIdentities: {
            1: ['$source:one'],
            2: ['$source:two'],
          },
        );
      }
      await cache.flush();
      cache.clear();
      key('', 'mr');
      key('', 'oldest');
      key('folder', 'mr');
      await cache.restore(main, source);
      final unchanged = await cache.observePreview(
        key: main,
        source: source,
        generation: generation,
        expectedRevision: cache.revision(source),
        items: [item('one')],
        total: 2,
      );
      expect(unchanged!.knownTotal, 2);
      expect(cache.requiresRebuild(main), isFalse);
      final changed = await cache.observePreview(
        key: main,
        source: source,
        generation: generation,
        expectedRevision: cache.revision(source),
        items: [item('new')],
        total: 2,
      );
      expect(changed!.list.single.id, 'new');
      expect(cache.read(main, source)!.list.map((item) => item.id), [
        'one',
        'two',
      ]);
      expect(cache.read(main, source)!.page, 2);
      expect(cache.isFresh(main, source), isFalse);
      final changedRevision = cache.revision(source);
      expect(
        (await cache.observePreview(
          key: main,
          source: source,
          generation: generation,
          expectedRevision: changedRevision,
          items: [item('new')],
          total: 2,
        ))!.list.single.id,
        'new',
      );
      expect(cache.revision(source), changedRevision);
      expect(
        await cache.observePreview(
          key: main,
          source: source,
          generation: generation,
          expectedRevision: changedRevision - 1,
          items: [item('one')],
          total: 2,
        ),
        isNull,
      );
      await cache.observePreview(
        key: main,
        source: source,
        generation: generation,
        expectedRevision: changedRevision,
        items: [item('one')],
        total: 2,
      );
      expect(
        cache.revision(source),
        changedRevision + 1,
        reason: 'A return to the old paged head is still a new site change',
      );
      cache.clear();
      for (final options in [('', 'mr'), ('', 'oldest'), ('folder', 'mr')]) {
        final query = key(options.$1, options.$2);
        expect((await cache.restore(query, source))!.page, 2);
        expect(cache.requiresRebuild(query), isTrue);
        expect(cache.isFresh(query, source), isFalse);
      }
    },
  );

  test(
    'an external observation reopens an already running cold folder',
    () async {
      final cache = JmCollectionSnapshots.instance;
      final generation = pluginSessionWriteFence.generation(source);
      final previewKey = cache.key(
        source,
        'getCloudFavoriteData',
        {'page': 1},
        {'folderId': '', 'order': 'mr'},
      );
      cache.write(
        previewKey,
        source,
        generation,
        PluginPagedComicListState(
          status: PluginPagedComicListStatus.success,
          list: [item('old-preview')],
          knownTotal: 1,
          hasReachedMax: true,
        ),
      );

      final firstStarted = Completer<void>();
      final firstResponse = Completer<Map<String, dynamic>>();
      final requestedPages = <int>[];
      final cold = PluginPagedComicListCubit(
        pluginId: source,
        fnPath: 'getCloudFavoriteData',
        privateCollection: true,
        jmSnapshotCache: true,
        coreBuilder: (page) => {'page': page},
        externBuilder: (_) => {'folderId': 'unopened-folder'},
        requestPage: (_, __, core, ___) {
          requestedPages.add(core['page'] as int);
          if (requestedPages.length == 1) {
            firstStarted.complete();
            return firstResponse.future;
          }
          return Future.value(page(['current-folder-work']));
        },
      )..setReadActive(true);
      addTearDown(cold.close);
      final published = <String>[];
      final subscription = cold.stream.listen(
        (state) => published.addAll(state.list.map((item) => item.id)),
      );
      addTearDown(subscription.cancel);
      final initial = cold.loadInitial();
      await firstStarted.future;
      await cache.observePreview(
        key: previewKey,
        source: source,
        generation: generation,
        expectedRevision: cache.revision(source),
        items: [item('changed-preview')],
        total: 1,
      );

      final recovered = cold.stream.firstWhere(
        (state) => state.status == PluginPagedComicListStatus.success,
      );
      firstResponse.complete(page(['retired-folder-work']));
      await initial;
      final state = await recovered.timeout(const Duration(seconds: 2));
      expect(state.list.single.id, 'current-folder-work');
      expect(published, ['current-folder-work']);
      expect(requestedPages, [1, 1]);
    },
  );

  for (final automaticRebuild in [true, false]) {
    test(
      'a pagination retry rebuilds an invalidated cursor first ($automaticRebuild)',
      () async {
        final cache = JmCollectionSnapshots.instance;
        final generation = pluginSessionWriteFence.generation(source);
        final previewKey = cache.key(
          source,
          'getCloudFavoriteData',
          {'page': 1},
          {'folderId': '', 'order': 'mr'},
        );
        cache.write(
          previewKey,
          source,
          generation,
          PluginPagedComicListState(
            status: PluginPagedComicListStatus.success,
            list: [item('old-preview')],
            knownTotal: 1,
            hasReachedMax: true,
          ),
        );
        var changed = false;
        final requestedPages = <int>[];
        final current = cubit((_, __, core, ___) async {
          final page = core['page'] as int;
          requestedPages.add(page);
          if (page == 2 && !changed) throw const FormatException('fixture');
          final id = page == 2
              ? 'fresh-tail'
              : changed
              ? 'fresh-head'
              : 'old-head';
          return {
            'source': source,
            'data': {
              'items': [item(id).toJson()],
              'total': 2,
              'hasReachedMax': page == 2,
            },
          };
        });
        addTearDown(current.close);
        await current.loadInitial();
        await current.loadMore();
        expect(
          current.state.status,
          PluginPagedComicListStatus.loadingMoreFailure,
        );

        current.setReadActive(automaticRebuild);
        final rebuilt = current.stream.firstWhere(
          (state) => state.list.firstOrNull?.id == 'fresh-head',
        );
        changed = true;
        await cache.observePreview(
          key: previewKey,
          source: source,
          generation: generation,
          expectedRevision: cache.revision(source),
          items: [item('changed-preview')],
          total: 1,
        );
        if (automaticRebuild) {
          final visible = await rebuilt.timeout(const Duration(seconds: 2));
          expect(visible.status, PluginPagedComicListStatus.loadingMoreFailure);
          expect(requestedPages, [1, 2, 1]);
          await Future<void>.delayed(Duration.zero);
        } else {
          final activeKey = cache.key(
            source,
            'getCloudFavoriteData',
            {'page': 1},
            {'folderId': ''},
          );
          expect(cache.requiresRebuild(activeKey), isTrue);
          for (var index = 0; index < 8; index++) {
            final other = cache.key(
              source,
              'getCloudFavoriteData',
              {'page': 1},
              {'folderId': 'unrelated-$index'},
            );
            cache.write(
              other,
              source,
              generation,
              const PluginPagedComicListState(),
            );
          }
          expect(cache.read(activeKey, source), isNull);
        }
        await current.retryLoadMore();
        expect(requestedPages, [1, 2, 1, 2]);
        expect(current.state.status, PluginPagedComicListStatus.success);
        expect(current.state.list.map((row) => row.id), [
          'fresh-head',
          'fresh-tail',
        ]);
      },
    );
  }

  testWidgets(
    'identical favorite taps share one write and a following intent uses committed status',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final first = Completer<Map<String, dynamic>>();
      final calls = <Map<String, dynamic>>[];
      Future<Map<String, dynamic>> invoke({
        required String pluginId,
        required String fnPath,
        required Map<String, dynamic> core,
        required Map<String, dynamic> extern,
      }) async {
        calls.add(core);
        return calls.length == 1
            ? first.future
            : {'status': 'completed', 'favorited': false, 'committed': true};
      }

      Future<FavoriteWorkflowExecutionResult> perform(
        FavoriteWorkflowAction action,
      ) => executeCloudFavoriteWorkflow(
        context: context,
        from: source,
        comicId: 'one',
        action: action,
        currentStatus: false,
        invokePlugin: invoke,
      );
      final add = perform(FavoriteWorkflowAction.add),
          duplicate = perform(FavoriteWorkflowAction.add);
      final remove = perform(FavoriteWorkflowAction.removeAll);
      expect(calls, hasLength(1));
      first.complete({
        'status': 'completed',
        'favorited': true,
        'committed': true,
      });
      expect((await add).favorited, isTrue);
      expect((await duplicate).favorited, isTrue);
      expect((await remove).favorited, isFalse);
      expect(calls, hasLength(2));
      expect(calls.last['currentFavorite'], isTrue);
    },
  );
}
