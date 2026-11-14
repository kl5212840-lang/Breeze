import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/comic_list/cubit/jm_collection_snapshots.dart';
import 'package:zephyr/page/comic_list/view/plugin_paged_comic_list_view.dart';
import 'package:zephyr/page/search_result/view/source_list_filter_bar.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/plugin_account_identity.dart';
import 'package:zephyr/page/source_shell/source_list_block_preferences.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../test_helper.dart';

void main() {
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    objectbox.userSettingBox.put(UserSetting());
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    JmCollectionSnapshots.instance.clear();
  });
  tearDown(() => SourceListBlockPreferences.flush());

  testWidgets('category-only mode reuses colored block and restore chips', (
    tester,
  ) async {
    final blocked = <String>{'全彩'};
    final changes = <Set<String>>[];
    var clears = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SourceListFilterBar(
              categories: const ['全彩', '短篇'],
              blockedCategories: blocked,
              onCategoryTap: (category) {
                final next = {...blocked};
                if (!next.add(category)) next.remove(category);
                changes.add(next);
                setState(() {
                  blocked
                    ..clear()
                    ..addAll(next);
                });
              },
              onClearBlockedCategories: () {
                clears++;
                setState(blocked.clear);
              },
              sortValue: '',
              sortOptions: const {},
              onSortChanged: (_) {},
              detailedView: false,
              onViewChanged: (_) {},
              categoriesOnly: true,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('category-全彩')), findsOneWidget);
    expect(find.byKey(const ValueKey('category-短篇')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('source-list.clear-blocked')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('source-list.category-hint')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('category-全彩')));
    await tester.pump();
    expect(changes, [<String>{}]);
    await tester.tap(find.byKey(const ValueKey('category-短篇')));
    await tester.pump();
    expect(changes.last, {'短篇'});
    await tester.tap(find.byKey(const ValueKey('source-list.clear-blocked')));
    await tester.pump();
    expect(clears, 1);
  });

  testWidgets('Bika favorite category chips filter only loaded categories', (
    tester,
  ) async {
    const bika = 'e9f18928-3ba8-4d86-a12e-b53a62f47933';
    onSavePluginConfig(
      bika,
      'auth.account',
      jsonEncode('fixture-login-owner-one'),
      fromRuntime: false,
    );
    PluginAccountIdentities.confirm(
      bika,
      const PluginAccountAuthentication(serverIdentity: 'owner-one'),
      generation: pluginSessionWriteFence.generation(bika),
    );
    final owner = JmCollectionSnapshots.instance.accountScope(bika)!;
    final blockScope = '$bika|cloudFavorite|$owner|folder-a|categoryBlock';
    UnifiedComicListItem row(
      String id,
      String category,
    ) => UnifiedComicListItem(
      source: bika,
      id: id,
      title: id,
      subtitle: '',
      finished: false,
      likesCount: 0,
      viewsCount: 0,
      updatedAt: '',
      cover: UnifiedComicCover(id: id, url: '', path: '', extern: const {}),
      metadata: [
        const UnifiedComicMetadata(type: 'tags', name: '标签', value: ['测试标签']),
        UnifiedComicMetadata(type: 'categories', name: '分类', value: [category]),
      ],
      raw: const {},
      extern: const {},
    );
    final settings = GlobalSettingCubit();
    addTearDown(settings.close);
    await tester.pumpWidget(
      BlocProvider<GlobalSettingCubit>.value(
        value: settings,
        child: MaterialApp(
          home: Scaffold(
            body: PluginPagedComicListView(
              pluginId: bika,
              fnPath: 'getFavoriteData',
              coreBuilder: (page) => {'page': page},
              externBuilder: (_) => const {},
              cloudFavorite: true,
              collectionTargetId: 'folder-a',
              requestPage: (_, __, ___, ____) async => {
                'source': bika,
                'data': {
                  'total': 2,
                  'hasReachedMax': true,
                  'items': [
                    row('color-work', '全彩').toJson(),
                    row('short-work', '短篇').toJson(),
                  ],
                },
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('category-全彩')), findsOneWidget);
    expect(find.byKey(const ValueKey('category-短篇')), findsOneWidget);
    expect(find.text('color-work'), findsOneWidget);
    expect(find.text('short-work'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('source-loaded.search')),
      'work',
    );
    await tester.tap(find.byKey(const ValueKey('category-全彩')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('source-loaded.search')))
          .controller
          ?.text,
      'work',
      reason: 'Applying a category exclusion keeps the current query',
    );
    await SourceListBlockPreferences.flush();
    expect(await SourceListBlockPreferences.read(blockScope), {'全彩'});
    expect(
      await SourceListBlockPreferences.read(
        '$bika|cloudFavorite|$owner|folder-b|categoryBlock',
      ),
      isNull,
    );
    expect(
      await SourceListBlockPreferences.read(
        '$bika|cloudFavorite|another-owner|folder-a|categoryBlock',
      ),
      isNull,
    );
    expect(find.text('color-work'), findsNothing);
    expect(find.text('short-work'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('category-全彩')));
    await tester.pumpAndSettle();
    expect(find.text('color-work'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('category-全彩')));
    await tester.pumpAndSettle();
    final cubit = tester
        .element(find.byType(SourceListFilterBar))
        .read<PluginPagedComicListCubit>();

    // Change the verified account with the same list route still mounted.
    final generation = pluginSessionWriteFence.advance(bika);
    onSavePluginConfig(
      bika,
      'auth.account',
      jsonEncode('fixture-login-owner-two'),
      fromRuntime: false,
    );
    PluginAccountIdentities.confirm(
      bika,
      const PluginAccountAuthentication(serverIdentity: 'owner-two'),
      generation: generation,
    );
    final nextOwner = JmCollectionSnapshots.instance.accountScope(bika)!;
    expect(nextOwner, isNot(owner));
    final nextScope = '$bika|cloudFavorite|$nextOwner|folder-a|categoryBlock';
    await SourceListBlockPreferences.write(nextScope, {'短篇'});
    await cubit.loadInitial();
    await tester.pumpAndSettle();
    expect(find.text('color-work'), findsOneWidget);
    expect(find.text('short-work'), findsNothing);
    expect(await SourceListBlockPreferences.read(blockScope), {'全彩'});
    expect(await SourceListBlockPreferences.read(nextScope), {'短篇'});
  });
}
