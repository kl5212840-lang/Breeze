import 'package:zephyr/service/plugin_account_identity.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/comic_list/cubit/jm_collection_metadata.dart';
import 'package:zephyr/page/comic_list/cubit/jm_collection_snapshots.dart';
import 'package:zephyr/page/comic_list/cubit/plugin_paged_comic_list_cubit.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';
import 'package:zephyr/page/search_result/view/source_loaded_result_filter.dart';
import '../test_helper.dart';

const source = 'jm-metadata-fixture';
UnifiedComicListItem row(String id) => UnifiedComicListItem(
  source: source,
  id: id,
  title: id,
  subtitle: '',
  finished: false,
  likesCount: 0,
  viewsCount: 0,
  updatedAt: '',
  cover: UnifiedComicCover(id: id, url: '', path: '', extern: const {}),
  metadata: const [],
  raw: const {},
  extern: const {},
);
Map<String, dynamic> detail(
  String id, {
  bool missing = false,
  bool empty = false,
}) => {
  'source': source,
  'data': {
    'normal': {
      'comicInfo': {
        'id': id,
        'title': id,
        'metadata': [
          if (!missing && !empty)
            {
              'type': 'tags',
              'name': '标签',
              'value': [
                {'name': '真实标签-$id'},
              ],
            },
          {
            'type': 'author',
            'name': '作者',
            'value': [
              {'name': '实际作者'},
            ],
          },
        ],
      },
      'extern': {
        'fieldsMissing': [if (missing) 'tags'],
      },
    },
  },
};
void login(String uid) {
  onSavePluginConfig(
    source,
    'auth.account',
    jsonEncode('fixture-$uid'),
    fromRuntime: false,
  );
  onSavePluginConfig(
    source,
    'auth.userInfo',
    jsonEncode({'uid': uid}),
    fromRuntime: false,
  );
  PluginAccountIdentities.confirm(
    source,
    PluginAccountAuthentication(serverIdentity: uid),
    generation: pluginSessionWriteFence.generation(source),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    JmCollectionSnapshots.instance.clear();
    JmCollectionMetadata.instance.clearMemory();
    login('one');
  });
  tearDown(() async {
    await JmCollectionMetadata.instance.settle();
    await JmCollectionSnapshots.instance.flush();
  });

  test(
    'two-request bounded enrichment persists real tags, keeps missing unknown and reuses progress after memory loss',
    () async {
      final service = JmCollectionMetadata();
      final account = JmCollectionSnapshots.instance.accountScope(source)!;
      final firstTwo = Completer<void>(), thirdStarted = Completer<void>();
      final responses = <String, Completer<Map<String, dynamic>>>{};
      var active = 0, maximum = 0, requests = 0;
      var current = true;
      final rows = [row('one'), row('two'), row('three')];
      service.start(
        account: account,
        generation: 0,
        rows: rows,
        current: () => current,
        read: (id) async {
          requests++;
          active++;
          if (active > maximum) maximum = active;
          final gate = responses[id] = Completer();
          if (responses.length == 2) firstTwo.complete();
          if (id == 'three') thirdStarted.complete();
          try {
            return await gate.future;
          } finally {
            active--;
          }
        },
        onBatch: (_) {},
      );
      await firstTwo.future;
      expect(requests, 2);
      expect(maximum, 2);
      responses['one']!.complete(detail('one'));
      // Let a successful read reach its actual local persistence boundary.
      await Future<void>.delayed(Duration.zero);
      await service.flush();
      expect(
        (await SharedPreferences.getInstance()).getString(
          '${JmCollectionMetadata.prefix}$account',
        ),
        contains('真实标签-one'),
      );
      responses['two']!.complete(detail('two', empty: true));
      // Wait for the third actual read without racing the rate limiter.
      await thirdStarted.future.timeout(const Duration(seconds: 5));
      responses['three']!.complete(detail('three', missing: true));
      await service.settle();
      expect(maximum, 2);
      final enriched = await service.hydrate(account, rows);
      expect(sourceLoadedComicFacet(enriched[0]).fields['tags'], {'真实标签-one'});
      expect(
        sourceLoadedComicFacet(enriched[1]).fields.containsKey('tags'),
        isFalse,
      );
      expect(
        enriched[1].metadata.any((m) => m.type == 'tags' && m.value.isEmpty),
        isTrue,
      );
      expect(enriched[2].metadata.any((m) => m.type == 'tags'), isFalse);
      final previousRequests = requests;
      service.start(
        account: account,
        generation: 0,
        rows: rows,
        current: () => current,
        read: (_) async {
          requests++;
          throw StateError(
            'must not retry a missing response in the same pass',
          );
        },
        onBatch: (_) {},
      );
      await service.settle();
      expect(requests, previousRequests);
      service.clearMemory();
      final reloaded = await service.hydrate(account, rows);
      expect(sourceLoadedComicFacet(reloaded.first).fields['tags'], {
        '真实标签-one',
      });
      current = false;
    },
  );

  test(
    'closing the collection page keeps the account-owned read, while switching account fences a late result',
    () async {
      final gate = Completer<Map<String, dynamic>>(),
          started = Completer<void>();
      final cubit = PluginPagedComicListCubit(
        pluginId: source,
        fnPath: 'getCloudFavoriteData',
        privateCollection: true,
        jmSnapshotCache: true,
        coreBuilder: (page) => {'page': page},
        externBuilder: (_) => {},
        requestPage: (_, __, ___, ____) async => {
          'source': source,
          'data': {
            'total': 1,
            'hasReachedMax': true,
            'items': [row('one').toJson()],
          },
        },
        requestDetail: (_, __, ___, ____) {
          started.complete();
          return gate.future;
        },
      );
      await cubit.loadInitial();
      await started.future;
      await cubit.close();
      final account = JmCollectionSnapshots.instance.accountScope(source)!;
      gate.complete(detail('one'));
      await JmCollectionMetadata.instance.settle();
      expect(
        sourceLoadedComicFacet(
          (await JmCollectionMetadata.instance.hydrate(account, [
            row('one'),
          ])).single,
        ).fields['tags'],
        {'真实标签-one'},
      );

      final late = Completer<Map<String, dynamic>>(),
          lateStarted = Completer<void>();
      final generation = pluginSessionWriteFence.generation(source);
      JmCollectionMetadata.instance.start(
        account: account,
        generation: generation,
        rows: [row('late')],
        current: () =>
            generation == pluginSessionWriteFence.generation(source) &&
            JmCollectionSnapshots.instance.accountScope(source) == account,
        read: (_) {
          lateStarted.complete();
          return late.future;
        },
        onBatch: (_) {},
      );
      await lateStarted.future;
      pluginSessionWriteFence.advance(source);
      login('two');
      late.complete(detail('late'));
      await JmCollectionMetadata.instance.settle();
      final newAccount = JmCollectionSnapshots.instance.accountScope(source)!;
      expect(newAccount, isNot(account));
      final foreign = await JmCollectionMetadata.instance.hydrate(newAccount, [
        row('late'),
      ]);
      expect(foreign.single.metadata, isEmpty);
      expect(
        (await SharedPreferences.getInstance()).getString(
          '${JmCollectionMetadata.prefix}$account',
        ),
        isNot(contains('真实标签-late')),
      );
    },
  );
}
