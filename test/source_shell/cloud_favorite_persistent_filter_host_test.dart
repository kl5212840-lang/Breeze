import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/network/sync/plugin_portable_scope.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';
import 'package:zephyr/page/comic_list/cubit/jm_collection_metadata.dart';
import 'package:zephyr/page/comic_list/cubit/jm_collection_snapshots.dart';
import 'package:zephyr/page/comic_list/cubit/plugin_paged_comic_list_state.dart';
import 'package:zephyr/page/comic_list/view/plugin_paged_comic_list_view.dart';
import 'package:zephyr/page/search_result/source_result_filter_preferences.dart';
import 'package:zephyr/page/search_result/view/source_loaded_result_filter.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';
import '../test_helper.dart';
import 'jm_collection_persistence_test.dart' as fixture;

class _FailFilterClear extends InMemorySharedPreferencesStore {
  _FailFilterClear() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key.contains(SourceResultFilterPreferences.prefix) &&
        (jsonDecode(value as String)['values'] as Map).isEmpty) {
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    objectbox.userSettingBox.put(UserSetting());
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    JmCollectionSnapshots.instance.clear();
    // Metadata load futures belong to each widget test's FakeAsync zone.
    JmCollectionMetadata.instance.clearMemory();
    fixture.account('confirmed');
  });
  tearDown(() async {
    await JmCollectionSnapshots.instance.flush();
    await SourceResultFilterPreferences.flush();
  });

  testWidgets('failed cloud facet clear restores the persisted selection', (
    tester,
  ) async {
    final previousStore = SharedPreferencesStorePlatform.instance;
    SharedPreferencesStorePlatform.instance = _FailFilterClear();
    addTearDown(() => SharedPreferencesStorePlatform.instance = previousStore);
    const scope = 'fixture|cloudFavorite|verified-owner|folder';
    const applied = ShelfFacetSelection(
      values: {
        'tags': {'red'},
      },
    );
    await SourceResultFilterPreferences.write(scope, applied);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SourceLoadedResultFilter(
            scope: scope,
            complete: true,
            entries: [fixture.item('one')],
            builder: (_, visible, controls) => controls,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final reset = find.byKey(const ValueKey('source-loaded.reset'));
    expect(reset, findsOneWidget);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(await SourceResultFilterPreferences.read(scope), applied);
    expect(reset, findsOneWidget);
    expect(find.text(t.error.saveFailed), findsOneWidget);
  });

  testWidgets(
    'cloud list restores facets and stops indexing when they are reset',
    (tester) async {
      final cache = JmCollectionSnapshots.instance;
      final key = cache.key(
        fixture.source,
        'getCloudFavoriteData',
        {'page': 1},
        {'folderId': ''},
      );
      final rows = [
        fixture
            .item('one')
            .copyWith(
              metadata: const [
                UnifiedComicMetadata(type: 'tags', name: '', value: ['red']),
              ],
            ),
        fixture
            .item('two')
            .copyWith(
              metadata: const [
                UnifiedComicMetadata(type: 'tags', name: '', value: ['blue']),
              ],
            ),
      ];
      cache.write(
        key,
        fixture.source,
        pluginSessionWriteFence.generation(fixture.source),
        PluginPagedComicListState(
          status: PluginPagedComicListStatus.success,
          list: rows,
          page: 1,
          knownTotal: 267,
          hasReachedMax: false,
        ),
      );
      await cache.flush();
      cache.clear(); // A new host has no resident list snapshot.
      final owner = cache.accountScope(fixture.source)!;
      final scope = '${fixture.source}|cloudFavorite|$owner|';
      await SourceResultFilterPreferences.write(
        scope,
        const ShelfFacetSelection(
          values: {
            'tags': {'red'},
          },
        ),
      );
      final pageTwo = Completer<Map<String, dynamic>>();
      final pages = <int>[];
      final settings = GlobalSettingCubit();
      addTearDown(settings.close);
      await tester.pumpWidget(
        BlocProvider<GlobalSettingCubit>.value(
          value: settings,
          child: MaterialApp(
            home: Scaffold(
              body: PluginPagedComicListView(
                pluginId: fixture.source,
                fnPath: 'getCloudFavoriteData',
                coreBuilder: (page) => {'page': page},
                externBuilder: (_) => {'folderId': ''},
                cloudFavorite: true,
                focusedFacets: true,
                requestPage: (_, __, core, ___) {
                  final page = core['page'] as int;
                  pages.add(page);
                  if (page == 1) {
                    return Future.value({
                      'data': {
                        'items': rows.map((e) => e.toJson()).toList(),
                        'total': 267,
                        'paging': {'pages': 134},
                      },
                    });
                  }
                  if (page == 2) return pageTwo.future;
                  return Future.value(fixture.page(['third-page']));
                },
              ),
            ),
          ),
        ),
      );
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      final filter = tester.widget<SourceLoadedResultFilter>(
        find.byType(SourceLoadedResultFilter),
      );
      expect(filter.entries.map((row) => row.id), ['one', 'two']);
      expect(filter.complete, isFalse);
      expect(filter.requireCompleteFacets, isFalse);
      expect(
        tester
            .widget<SourceChromeIconButton>(
              find.byKey(const ValueKey('source-loaded.filters')),
            )
            .onPressed,
        isNotNull,
      );
      expect(find.byKey(const ValueKey('source-loaded.reset')), findsOneWidget);
      expect(
        pages,
        [1, 2],
        reason:
            'Warm entry checks only the first page; restored filters request the unfinished index',
      );
      await tester.tap(find.byKey(const ValueKey('source-loaded.reset')));
      await tester.pump();
      await SourceResultFilterPreferences.flush();
      expect(
        (await SourceResultFilterPreferences.read(scope)).isActive,
        isFalse,
      );
      pageTwo.complete({
        'data': {
          'items': [fixture.item('next-page').toJson()],
          'total': 267,
          'paging': {'pages': 134},
        },
      });
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(pages, [1, 2], reason: 'Reset retires automatic index demand');
      final cleared = tester.widget<SourceLoadedResultFilter>(
        find.byType(SourceLoadedResultFilter),
      );
      expect(cleared.entries.map((row) => row.id), ['one', 'two', 'next-page']);
      expect(cleared.complete, isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      // The grid's image/visibility stream has a finite 100ms throttle tail.
      await tester.pump(const Duration(milliseconds: 200));
    },
  );

  testWidgets(
    'ordinary cached browsing stays paged; visibility probes and explicit search indexes',
    (tester) async {
      final cache = JmCollectionSnapshots.instance;
      final key = cache.key(
        fixture.source,
        'getCloudFavoriteData',
        {'page': 1},
        {'folderId': ''},
      );
      cache.write(
        key,
        fixture.source,
        pluginSessionWriteFence.generation(fixture.source),
        PluginPagedComicListState(
          status: PluginPagedComicListStatus.success,
          list: [fixture.item('one'), fixture.item('two')],
          page: 1,
          knownTotal: 4,
          hasReachedMax: false,
        ),
      );
      final settings = GlobalSettingCubit();
      final active = ValueNotifier(true);
      final query = TextEditingController();
      addTearDown(settings.close);
      addTearDown(active.dispose);
      addTearDown(query.dispose);
      final requests = <int>[];
      final body = PluginPagedComicListView(
        pluginId: fixture.source,
        fnPath: 'getCloudFavoriteData',
        coreBuilder: (page) => {'page': page},
        externBuilder: (_) => {'folderId': ''},
        cloudFavorite: true,
        focusedFacets: true,
        loadedSearchController: query,
        requestPage: (_, __, core, ___) async {
          final page = core['page'] as int;
          requests.add(page);
          return {
            'data': {
              'total': 4,
              'paging': {'pages': 2},
              'items': (page == 1 ? ['one', 'two'] : ['three', 'four'])
                  .map((id) => fixture.item(id).toJson())
                  .toList(),
            },
          };
        },
      );
      await tester.pumpWidget(
        BlocProvider.value(
          value: settings,
          child: MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<bool>(
                valueListenable: active,
                builder: (_, enabled, child) =>
                    TickerMode(enabled: enabled, child: child!),
                child: body,
              ),
            ),
          ),
        ),
      );
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 25));
      }
      expect(requests, [
        1,
      ], reason: 'ordinary entry only checks the cached first page');
      active.value = false;
      await tester.pump();
      active.value = true;
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 25));
      }
      expect(
        requests,
        [1, 1],
        reason:
            'a genuine re-entry checks warm data without waiting two minutes',
      );
      query.text = 'three';
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 25));
      }
      expect(requests, [
        1,
        1,
        2,
      ], reason: 'explicit local search opts into the unfinished index');
      expect(
        tester
            .widget<SourceLoadedResultFilter>(
              find.byType(SourceLoadedResultFilter),
            )
            .complete,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 200));
    },
  );

  test(
    'only validated choices are portable, with exact source ownership',
    () async {
      const scope = 'unknown-source|cloudFavorite|confirmed-owner|folder';
      await SourceResultFilterPreferences.write(
        scope,
        const ShelfFacetSelection(
          values: {
            'tags': {'real-tag'},
            'author': {'real-author'},
          },
        ),
      );
      final key = SourceResultFilterPreferences.key(scope);
      final snapshot = await PortablePreferences.capture();
      expect(PortablePreferences.owns(key), isTrue);
      final entry = snapshot.entries.values.singleWhere(
        (row) => row['key'] == key,
      );
      expect(pluginPortableScope(entry)!.source, 'unknown-source');
      expect((await SourceResultFilterPreferences.read(scope)).values['tags'], {
        'real-tag',
      });
      expect(
        (await SourceResultFilterPreferences.read(
          'other|cloudFavorite|confirmed-owner|folder',
        )).isActive,
        isFalse,
      );
      expect(
        SourceResultFilterPreferences.validValue(
          '{"version":1,"values":{"token":["secret"]}}',
        ),
        isFalse,
      );
      expect(
        PortablePreferences.owns('${JmCollectionSnapshots.prefix}snapshot'),
        isFalse,
      );
      expect(
        () => PortablePreferencesSnapshot.fromJson({
          'version': 1,
          'entries': {
            for (final e in snapshot.entries.entries)
              e.key: {
                ...e.value,
                if (e.value['key'] == key)
                  'value': '{"version":1,"values":{"tags":"invalid"}}',
              },
          },
        }),
        throwsFormatException,
      );
    },
  );
}
