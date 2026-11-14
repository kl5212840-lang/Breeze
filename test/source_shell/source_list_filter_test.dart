import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart';
import 'package:zephyr/page/comic_info/widgets/all_chip.dart';
import 'package:zephyr/page/search_result/view/source_list_categories.dart';
import 'package:zephyr/page/search_result/view/source_list_filter_bar.dart';
import 'package:zephyr/page/search_result/view/source_search_capabilities.dart';
import 'package:zephyr/page/search/widget/history.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_list_block_preferences.dart';
import 'package:zephyr/src/rust/frb_generated.dart';

import '../test_helper.dart';

class _CategoryConversionApi extends RustLibApi {
  @override
  String crateApiQjsOpenccConvert({
    required String text,
    required String config,
  }) => switch (config) {
    'tw2sp.json' => text.replaceAll('懸疑', '悬疑'),
    's2twp.json' => text.replaceAll('悬疑', '懸疑'),
    _ => text,
  };

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected test API ${invocation.memberName}');
}

class _CategoryWriteFailure extends InMemorySharedPreferencesStore {
  _CategoryWriteFailure(this.failedKey) : super.empty();
  final String failedKey;
  final finish = Completer<bool>();

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (key == 'flutter.$failedKey') return finish.future;
    return super.setValue(valueType, key, value);
  }
}

void main() {
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    objectbox.userSettingBox.put(UserSetting());
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  test('blocked categories persist independently by source and task', () async {
    SharedPreferences.setMockInitialValues({});
    await SourceListBlockPreferences.write('bika|cloudFavorite', {'短篇'});
    await SourceListBlockPreferences.write('bika|search', {'全彩'});
    expect(await SourceListBlockPreferences.read('bika|cloudFavorite'), {'短篇'});
    expect(await SourceListBlockPreferences.read('bika|search'), {'全彩'});
    expect(await SourceListBlockPreferences.read('other|cloudFavorite'), isNull);
    expect(await SourceListBlockPreferences.read('bika|profile:history'), isNull);
    final first = SourceListBlockPreferences.write('bika|cloudFavorite', {'同人'});
    final second = SourceListBlockPreferences.write('bika|cloudFavorite', {});
    await Future.wait([first, second]);
    expect(await SourceListBlockPreferences.read('bika|cloudFavorite'), isEmpty);
  });

  testWidgets('reopening a category scope restores exclusions without selecting filters', (tester) async {
    SharedPreferences.setMockInitialValues({});
    Widget host(String scope) => MaterialApp(home: Scaffold(body: SourceCategoryBlockScope(
      scope: scope,
      builder: (context, blocked, change) => SourceListFilterBar(
        categories: const ['短篇'], blockedCategories: blocked,
        onCategoryTap: (category) => change(blocked.contains(category) ? {} : {category}),
        onClearBlockedCategories: () => change({}),
        sortValue: '', sortOptions: const {}, onSortChanged: (_) {},
        detailedView: false, onViewChanged: (_) {},
      ),
    )));
    await tester.pumpWidget(host('bika|cloudFavorite'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category-短篇')));
    await tester.pumpAndSettle();
    expect(tester.widget<SourceListFilterBar>(find.byType(SourceListFilterBar)).blockedCategories, {'短篇'});
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(host('bika|cloudFavorite'));
    await tester.pumpAndSettle();
    expect(tester.widget<SourceListFilterBar>(find.byType(SourceListFilterBar)).blockedCategories, {'短篇'});
    await tester.pumpWidget(host('bika|search'));
    await tester.pumpAndSettle();
    expect(tester.widget<SourceListFilterBar>(find.byType(SourceListFilterBar)).blockedCategories, isEmpty);
    await tester.pumpWidget(host('bika|cloudFavorite'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('source-list.clear-blocked')));
    await tester.pumpAndSettle();
    expect(await SourceListBlockPreferences.read('bika|cloudFavorite'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed first save restores the original categories during other scope writes', (tester) async {
    const scope = 'bika|search';
    SharedPreferences.setMockInitialValues({});
    final previousStore = SharedPreferencesStorePlatform.instance;
    final store = _CategoryWriteFailure(SourceListBlockPreferences.key(scope));
    SharedPreferencesStorePlatform.instance = store;
    addTearDown(() => SharedPreferencesStorePlatform.instance = previousStore);
    Set<String> initial = {'原分类'};
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(
      builder: (context, setParent) => SourceCategoryBlockScope(
        scope: scope,
        initial: initial,
        onRestored: (value) => setParent(() => initial = value),
        builder: (context, blocked, change) => TextButton(
          onPressed: () {
            final next = {...blocked, '新分类'};
            change(next);
            // The search page feeds the optimistic choice back as its input.
            setParent(() => initial = next);
          },
          child: Text(blocked.join('、')),
        ),
      ),
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('原分类'));
    await tester.pump();
    expect(find.text('原分类、新分类'), findsOneWidget);
    await SourceListBlockPreferences.write('other|search', {'无关分类'});
    await tester.pump();
    store.finish.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('原分类'), findsOneWidget);
    expect(find.text(t.error.saveFailed), findsOneWidget);
    expect(await SourceListBlockPreferences.read(scope), isNull);
  });

  test('category blocking uses the same metadata as detailed result rows', () {
    final entry = UnifiedComicListItem.fromJson({
      'source': 'test',
      'id': '1',
      'title': '测试漫画',
      'subtitle': '',
      'finished': false,
      'likesCount': 0,
      'viewsCount': 0,
      'updatedAt': '',
      'cover': {'id': '1', 'url': '', 'path': '', 'extern': {}},
      'metadata': [
        {
          'type': 'categories',
          'name': '分类',
          'value': ['全彩', '短篇'],
        },
      ],
      'raw': <String, dynamic>{},
      'extern': <String, dynamic>{},
    });
    expect(isEntryBlockedByCategory(entry, {'短篇'}), isTrue);
    expect(isEntryBlockedByCategory(entry, {'长篇'}), isFalse);
    expect(filterEntriesByBlockedCategories([entry], {'短篇'}), isEmpty);
    expect(filterEntriesByBlockedCategories([entry], {'长篇'}), [entry]);
  });

  test('combined category text still respects the local blocklist', () {
    final entry = UnifiedComicListItem.fromJson({
      'source': 'jm',
      'id': '2',
      'title': '漫画',
      'subtitle': '',
      'finished': false,
      'likesCount': 0,
      'viewsCount': 0,
      'updatedAt': '',
      'cover': {'id': '2', 'url': '', 'path': '', 'extern': {}},
      'metadata': [
        {
          'type': 'categories',
          'name': '分类',
          'value': ['同人 · 同人'],
        },
      ],
      'raw': <String, dynamic>{},
      'extern': <String, dynamic>{},
    });
    expect(isEntryBlockedByCategory(entry, {'同人'}), isTrue);
  });

  test('blocklist accepts both source map and local list forms', () {
    expect(blockedCategoryNames(['同人']), {'同人'});
    expect(blockedCategoryNames({'同人': true, '短篇': false}), {'同人'});
  });

  testWidgets('conversion updates visible metadata without changing a saved category match', (
    tester,
  ) async {
    RustLib.initMock(api: _CategoryConversionApi());
    addTearDown(RustLib.dispose);
    final settings = GlobalSettingCubit();
    addTearDown(settings.close);
    await settings.initBox();
    final original = settings.state;
    addTearDown(() => settings.applySyncedState(original));

    final entry = UnifiedComicListItem.fromJson({
      'source': 'bika',
      'id': 'category-conversion',
      'title': '测试漫画',
      'cover': {'id': '', 'url': '', 'path': '', 'extern': {}},
      'metadata': [
        {'type': 'categories', 'name': '分类', 'value': ['懸疑']},
      ],
    });
    final metadata = ComicInfoMetadata(
      type: 'categories',
      name: '分类',
      value: [ComicInfoActionItem(name: '懸疑')],
    );
    await tester.pumpWidget(
      BlocProvider.value(
        value: settings,
        child: MaterialApp(
          home: Scaffold(
            body: AllChipWidget(
              comicId: entry.id,
              metadata: metadata,
              from: entry.source,
            ),
          ),
        ),
      ),
    );

    expect(find.text('懸疑'), findsOneWidget);
    expect(isEntryBlockedByCategory(entry, {'悬疑'}), isTrue);
    settings.updateState(
      (state) => state.copyWith(chineseConvertMode: ChineseConvertMode.simplified),
    );
    await tester.pumpAndSettle();
    expect(find.text('悬疑'), findsOneWidget);
    expect(isEntryBlockedByCategory(entry, {'悬疑'}), isTrue);
    expect(isEntryBlockedByCategory(entry, {'喜剧'}), isFalse);

    settings.updateState(
      (state) => state.copyWith(chineseConvertMode: ChineseConvertMode.traditional),
    );
    await tester.pumpAndSettle();
    expect(find.text('懸疑'), findsOneWidget);
    expect(isEntryBlockedByCategory(entry, {'悬疑'}), isTrue);
  });

  testWidgets('detail tags start in one line and can expand', (tester) async {
    final metadata = ComicInfoMetadata(
      type: 'tags',
      name: '标签',
      value: List.generate(
        12,
        (index) => ComicInfoActionItem(name: '标签$index'),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 340,
            child: AllChipWidget(
              comicId: '1',
              metadata: metadata,
              from: 'test',
            ),
          ),
        ),
      ),
    );
    expect(find.text('展开'), findsOneWidget);
    expect(find.text('收起'), findsNothing);
    await tester.tap(find.text('展开'));
    await tester.pump();
    expect(find.text('收起'), findsOneWidget);
    final firstChip = tester.getRect(find.text('标签0'));
    expect(firstChip.width, lessThan(100));
    final label = tester.getRect(find.text('标签'));
    expect((label.center.dy - firstChip.center.dy).abs(), lessThan(1));
  });

  testWidgets('a single author chip keeps content width', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 340,
            child: AllChipWidget(
              comicId: '1',
              metadata: const ComicInfoMetadata(
                type: 'author',
                name: '作者',
                value: [ComicInfoActionItem(name: '作者甲')],
              ),
              from: 'test',
            ),
          ),
        ),
      ),
    );
    final chip = tester.getRect(find.byType(AnimatedContainer));
    expect(chip.width, lessThan(150));
  });

  testWidgets('blocked-category toolbar stays usable on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 2000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SourceListFilterBar(
            categories: const ['短篇', '同人', '全彩'],
            blockedCategories: const {'短篇'},
            onCategoryTap: (_) {},
            onClearBlockedCategories: () {},
            sortValue: 'new',
            sortOptions: const {'new': '最新', 'old': '最早'},
            onSortChanged: (_) {},
            detailedView: true,
            onViewChanged: (_) {},
            pageLabel: '第1 / 12页',
            onPageTap: () {},
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.filter_alt_off_outlined), findsOneWidget);
    expect(find.text('第1 / 12页'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blocked chip keeps its label position and dimensions', (
    tester,
  ) async {
    var blocked = <String>{};
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return SourceListFilterBar(
                categories: const ['短篇'],
                blockedCategories: blocked,
                onCategoryTap: (_) {},
                sortValue: '',
                sortOptions: const {},
                onSortChanged: (_) {},
                detailedView: false,
                onViewChanged: (_) {},
              );
            },
          ),
        ),
      ),
    );
    final chip = find.byKey(const ValueKey('category-短篇'));
    final frame = tester.getRect(chip);
    final label = tester.getRect(find.text('短篇'));
    expect((label.center.dx - frame.center.dx).abs(), lessThan(1), reason: 'The category label is centered in its visible chip');
    update(() => blocked = {'短篇'});
    await tester.pumpAndSettle();
    expect(tester.getRect(chip), frame);
    expect(tester.getRect(find.text('短篇')), label);
    expect(find.byIcon(Icons.block), findsOneWidget);
  });

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets('source tools fit at 320pt and 2x text $style ${brightness.name}', (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final preference = ValueNotifier(style);
        addTearDown(preference.dispose);
        await tester.pumpWidget(AppInterfaceStyleScope(style: preference, child: MaterialApp(
          theme: ThemeData(brightness: brightness),
          builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)), child: child!),
          home: Scaffold(body: SourceListFilterBar(
            categories: const ['短篇', '同人'], blockedCategories: const {'短篇'},
            onCategoryTap: (_) {}, onClearBlockedCategories: () {},
            sortValue: 'dd', sortOptions: const {'dd': '收藏时间(新→旧)', 'da': '收藏时间(旧→新)'},
            onSortChanged: (_) {}, detailedView: true, onViewChanged: (_) {},
          )),
        )));
        await tester.pumpAndSettle();
        for (final key in ['source-list.sort', 'source-list.clear-blocked']) {
          final frame = tester.getRect(find.byKey(ValueKey(key)));
          expect(frame.height, greaterThanOrEqualTo(44));
          expect(frame.left, greaterThanOrEqualTo(0));
          expect(frame.right, lessThanOrEqualTo(320));
        }
        final chip = tester.getRect(find.byKey(const ValueKey('category-短篇')));
        final label = tester.getRect(find.text('短篇'));
        expect((label.center.dx - chip.center.dx).abs(), lessThan(1));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'large detail tags keep text inside the border and a 44pt target',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: AllChipWidget(
                comicId: '1',
                from: 'test',
                metadata: const ComicInfoMetadata(
                  type: 'tags',
                  name: '标签',
                  value: [
                    ComicInfoActionItem(name: '短'),
                    ComicInfoActionItem(name: '很长的标签名称测试大字'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      for (final expanded in [false, true]) {
        if (expanded) {
          await tester.tap(find.text('展开'));
          await tester.pumpAndSettle();
        }
        for (final element in find.byType(AnimatedContainer).evaluate()) {
          final border = tester.getRect(find.byWidget(element.widget));
          final label = find.descendant(
            of: find.byWidget(element.widget),
            matching: find.byType(Text),
          );
          final text = tester.getRect(label);
          expect(text.top - border.top, greaterThanOrEqualTo(8));
          expect(border.bottom - text.bottom, greaterThanOrEqualTo(8));
        }
        final targets = find.ancestor(
          of: find.text('短'),
          matching: find.byType(GestureDetector),
        );
        expect(tester.getSize(targets.first).width, greaterThanOrEqualTo(44));
        expect(tester.getSize(targets.first).height, greaterThanOrEqualTo(44));
        expect(tester.takeException(), isNull);
      }
    },
  );

  test('source sort labels come from its own advanced-search scheme', () {
    expect(
      sourceSortOptions(const [
        {
          'key': 'sortBy',
          'options': [
            {'value': 1, 'label': '从新到旧'},
            {'value': 2, 'label': '最多观看'},
          ],
        },
      ]),
      {'1': '从新到旧', '2': '最多观看'},
    );
  });

  testWidgets('clearing search history requires confirmation', (tester) async {
    final settings = GlobalSettingCubit()
      ..updateState((state) => state.copyWith(searchHistory: ['露出', '同人']));
    addTearDown(settings.close);
    await tester.pumpWidget(
      BlocProvider.value(
        value: settings,
        child: const MaterialApp(home: Scaffold(body: HistoryWidget())),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('search-history.clear')));
    await tester.pumpAndSettle();
    expect(settings.state.searchHistory, ['露出', '同人']);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(settings.state.searchHistory, ['露出', '同人']);
    await tester.tap(find.byKey(const ValueKey('search-history.clear')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清空历史').last);
    await tester.pumpAndSettle();
    expect(settings.state.searchHistory, isEmpty);
  });
}
