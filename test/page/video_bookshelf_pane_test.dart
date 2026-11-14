import 'package:zephyr/page/bookshelf/widgets/bookshelf_content_toolbar.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_detailed_content.dart';
import 'package:flutter/services.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/collection_selection_mark.dart';
import 'package:zephyr/service/collection_view_preferences.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_content_layout.dart';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/cubit/search_status.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/bookshelf/service/video_bookshelf_index.dart';
import 'package:zephyr/page/bookshelf/widgets/video_bookshelf_pane.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_floating_selection_actions.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_selection_toolbar.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_folder_card.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import '../ui_preview_helper.dart';

VideoBookshelfRow _row(
  String source, {
  String id = '1',
  String progress = '',
  String sourceDuration = '',
  String remarks = '',
  String year = '',
  String quality = '',
  String typeName = '',
  String area = '',
  String sourceUpdatedAt = '',
  int? sourceViews,
  DateTime? watchedAt,
  Set<String> folderIds = const {},
}) => VideoBookshelfRow(
  key: 'key-$source-$id',
  source: source,
  item: ApiVideoItem(
    id: id,
    title: '作品$source$id',
    sourceDuration: sourceDuration,
    remarks: remarks,
    year: year,
    typeName: typeName,
    area: area,
    updatedAt: sourceUpdatedAt,
    sourceViews: sourceViews,
    detailUrl: Uri.parse('https://$source.example/voddetail/$id.html'),
  ),
  updatedAt: watchedAt ?? DateTime.utc(2026, 10, 28),
  folderIds: folderIds,
  recordKey: VideoLibraryStore.itemKey(source, id),
  watchUrl: Uri.parse(
    'https://$source.example/voddetail/$id.html?line=3&episode=7',
  ),
  progress: progress,
  facetFields: {
    if (quality.isNotEmpty) 'quality': {quality},
  },
);

class _Data {
  _Data(this.rows) {
    source = VideoBookshelfPaneDataSource(
      load: (mode, search) async =>
          loader == null ? rows : await loader!(mode, search),
      sourceNames: () async => {'a': '来源甲', 'b': '来源乙'},
      open: (_, row) async => opened.add(row),
      remove: (mode, selected) async {
        removed.add((mode, selected));
        final keys = selected.map((r) => r.key).toSet();
        rows = rows.where((r) => !keys.contains(r.key)).toList();
      },
      enrich: (row) async {
        enriched.add(row);
        return ApiVideoItem.fromJson({
          ...row.item.toLibraryJson(),
          'description': '详情${row.source}',
        }, home: row.item.detailUrl);
      },
      store: store,
      changes: changes,
    );
  }
  List<VideoBookshelfRow> rows;
  final store = VideoLibraryStore(
    deviceId: 'pane-test',
    storageKey: 'pane-test-library',
  );
  final changes = ValueNotifier<int>(0);
  final opened = <VideoBookshelfRow>[], enriched = <VideoBookshelfRow>[];
  final removed = <(ShelfPageMode, List<VideoBookshelfRow>)>[];
  Future<List<VideoBookshelfRow>> Function(ShelfPageMode, SearchStatusState)?
  loader;
  late final VideoBookshelfPaneDataSource source;
  void dispose() {
    store.dispose();
    changes.dispose();
  }
}

Future<void> _mount(
  WidgetTester tester,
  _Data data, {
  ShelfPageMode mode = ShelfPageMode.favorite,
  SearchStatusState search = const SearchStatusState(),
  bool active = true,
  bool showReturnToTop = false,
  int refresh = 0,
  double scale = 1,
  double bottomInset = 0,
  String interfaceStyle = 'system',
  Brightness brightness = Brightness.light,
  ValueChanged<bool>? selection,
}) async {
  tester.view.physicalSize = const Size(320, 844);
  tester.view.devicePixelRatio = 1;
  final preference = ValueNotifier(interfaceStyle);
  addTearDown(preference.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        brightness: brightness,
        fontFamily: uiPreviewDirectory == null ? null : 'AccountPreview',
      ),
      builder: (context, child) => AppInterfaceStyleScope(
        style: preference,
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: NativeNavigationInset(
            bottom: bottomInset,
            child: RepaintBoundary(
              key: const ValueKey('video-shelf.preview'),
              child: child!,
            ),
          ),
        ),
      ),
      home: Scaffold(
        body: VideoBookshelfPane(
          key: const ValueKey('pane'),
          mode: mode,
          search: search,
          dataSource: data.source,
          isActive: active,
          showReturnToTop: showReturnToTop,
          refreshSignal: refresh,
          onSelectionChanged: selection,
        ),
      ),
    ),
  );
  await tester.pump();
}

ApiVideoCollection _collection(WidgetTester tester) =>
    tester.widget<ApiVideoCollection>(find.byType(ApiVideoCollection));
bool _filterActive(WidgetTester tester) => tester
    .widget<BookshelfContentToolbar>(find.byType(BookshelfContentToolbar))
    .filterActive;

Finder _action(String id) => find.byKey(ValueKey('video-shelf.$id'));
VoidCallback? _actionCallback(WidgetTester tester, String id) {
  final control = find.descendant(
    of: _action(id),
    matching: find.byWidgetPredicate(
      (w) =>
          w is NativeVideoTextButton ||
          w is NativeVideoIconButton ||
          w is TextButton,
    ),
  );
  final widget = tester.widget(control);
  return switch (widget) {
    NativeVideoTextButton(:final onPressed) => onPressed,
    NativeVideoIconButton(:final onPressed) => onPressed,
    TextButton(:final onPressed) => onPressed,
    _ => null,
  };
}

void main() {
  testWidgets('video record menu omits the removed unfiled shortcut', (
    tester,
  ) async {
    final data = _Data([_row('a', sourceViews: 234)]);
    addTearDown(data.dispose);
    await _mount(tester, data);
    final toolbar = tester.widget<BookshelfContentToolbar>(
      find.byType(BookshelfContentToolbar),
    );
    expect(toolbar.moreOptions.containsKey('__unfiled'), isFalse);
    toolbar.onToggleView!();
    await tester.pumpAndSettle();
    expect(find.byType(BookshelfDetailedContent), findsOneWidget);
    expect(find.text(t.videoLibrary.sourceViews(count: 234)), findsOneWidget);
    expect(find.text('暂无简介'), findsNothing);
    expect(
      data.enriched,
      isEmpty,
      reason: 'local record rows do not fetch hidden browsing details',
    );
  });

  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadUiPreviewFonts);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channels = <MethodChannel>[];
  final channelsByTooltip = <String, MethodChannel>{};
  setUp(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final args = call.arguments as Map;
        final channel = MethodChannel('${args['viewType']}.${args['id']}');
        channels.add(channel);
        messenger.setMockMethodCallHandler(channel, (update) async {
          if (update.method == 'update' && update.arguments is Map) {
            final tooltip = (update.arguments as Map)['tooltip'];
            if (tooltip is String) channelsByTooltip[tooltip] = channel;
          }
          return null;
        });
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    channels.clear();
    channelsByTooltip.clear();
  });
  Future<void> pressControl(WidgetTester tester, Finder control) async {
    final native = find.descendant(
      of: control,
      matching: find.byType(UiKitView),
    );
    if (native.evaluate().isEmpty) {
      await tester.tap(control);
    } else {
      final args = tester.widget<UiKitView>(native).creationParams as Map;
      final channel = channelsByTooltip[args['tooltip']];
      expect(channel, isNotNull);
      await messenger.handlePlatformMessage(
        channel!.name,
        const StandardMethodCodec().encodeMethodCall(const MethodCall('press')),
        (_) {},
      );
    }
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> selectMore(WidgetTester tester, String value) async {
    final trigger = _action('more');
    final menu = tester.widget<NativeVideoMenu>(trigger);
    expect(menu.options, contains(value));
    if (find
        .descendant(of: trigger, matching: find.byType(UiKitView))
        .evaluate()
        .isNotEmpty) {
      menu.onSelected(value);
    } else {
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      final item = find.text(menu.options[value]!);
      await tester.ensureVisible(item);
      await tester.tap(item);
    }
    await tester.pumpAndSettle();
  }

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.single;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<void> openFilter(WidgetTester tester) async {
    await pressControl(tester, _action('filter'));
    await tester.pumpAndSettle();
  }

  Future<void> pickFacet(
    WidgetTester tester,
    String dimension,
    String value,
  ) async {
    final chip = find.byKey(ValueKey('shelf-facet-$dimension'));
    if (chip.evaluate().isNotEmpty) {
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }
    final option = find.byKey(ValueKey('shelf-option-$dimension-$value'));
    await tester.ensureVisible(option);
    await tester.tap(option);
    await tester.pumpAndSettle();
  }

  Future<void> pickYear(WidgetTester tester, String year) =>
      pickFacet(tester, 'year', year);

  Future<void> applyFilter(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('shelf-filter-apply')));
    await tester.pumpAndSettle();
  }

  Future<void> resetFilter(WidgetTester tester) async {
    await openFilter(tester);
    await tester.tap(find.byKey(const ValueKey('shelf-filter-reset')));
    await tester.pumpAndSettle();
    await applyFilter(tester);
  }

  testWidgets(
    'view layout is saved per video section and follows restored preferences',
    (tester) async {
      final data = _Data([_row('a')]);
      addTearDown(data.dispose);
      await _mount(tester, data, interfaceStyle: 'breeze');
      await tester.pumpAndSettle();
      expect(_collection(tester).mode, ApiVideoView.grid);
      await pressControl(tester, _action('view'));
      await tester.pumpAndSettle();
      expect(_collection(tester).mode, ApiVideoView.list);
      expect(
        await CollectionViewPreferences.read('public|video|favorite'),
        'list',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await _mount(tester, data, interfaceStyle: 'breeze');
      await tester.pumpAndSettle();
      expect(_collection(tester).mode, ApiVideoView.list);
      await _mount(
        tester,
        data,
        mode: ShelfPageMode.history,
        interfaceStyle: 'breeze',
      );
      await tester.pumpAndSettle();
      expect(_collection(tester).mode, ApiVideoView.grid);
      await _mount(tester, data, interfaceStyle: 'breeze');
      await tester.pumpAndSettle();
      expect(_collection(tester).mode, ApiVideoView.list);
      await CollectionViewPreferences.write('public|video|favorite', 'grid');
      await tester.pumpAndSettle();
      expect(_collection(tester).mode, ApiVideoView.grid);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'long hold selects one video and scrolling cancels the management gesture',
    (tester) async {
      final data = _Data([for (var i = 1; i <= 12; i++) _row('a', id: '$i')]);
      addTearDown(data.dispose);
      await _mount(tester, data, interfaceStyle: 'breeze');
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('api-video.key-a-1'));
      final restingRect = tester.getRect(card);
      final restingWidth = restingRect.width;
      final mark = find.descendant(
        of: card,
        matching: find.byType(CollectionSelectionMark),
      );
      expect(tester.widget<CollectionSelectionMark>(mark).visible, isFalse);
      final hold = await tester.startGesture(tester.getCenter(card));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(_collection(tester).selecting, isFalse);
      expect(tester.getRect(card).width, lessThan(restingWidth));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_collection(tester).selecting, isTrue);
      expect(_collection(tester).selected, {'key-a-1'});
      await hold.up();
      await tester.pumpAndSettle();
      expect(tester.getRect(card), restingRect);
      expect(tester.widget<CollectionSelectionMark>(mark).selected, isTrue);
      expect(
        tester.getSize(mark),
        const Size.square(CollectionSelectionMark.size),
      );
      expect(_collection(tester).selected, {'key-a-1'});
      expect(data.opened, isEmpty);
      tester
          .widget<BookshelfSelectionToolbar>(
            find.byType(BookshelfSelectionToolbar),
          )
          .onCancel!();
      await tester.pumpAndSettle();
      await tester.tap(_action('view'));
      await tester.pumpAndSettle();
      expect(_collection(tester).mode, ApiVideoView.list);
      final listRect = tester.getRect(card);
      final listWidth = listRect.width;
      final listHold = await tester.startGesture(tester.getCenter(card));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.getRect(card).width, lessThan(listWidth));
      expect(_collection(tester).selecting, isFalse);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_collection(tester).selected, {'key-a-1'});
      await listHold.up();
      await tester.pumpAndSettle();
      expect(tester.getRect(card), listRect);
      expect(tester.widget<CollectionSelectionMark>(mark).selected, isTrue);
      final toolbar = find.byType(BookshelfSelectionToolbar);
      tester.widget<BookshelfSelectionToolbar>(toolbar).onToggleAll!();
      await tester.pumpAndSettle();
      expect(_collection(tester).selected, hasLength(12));
      expect(tester.getRect(card), listRect);
      tester.widget<BookshelfSelectionToolbar>(toolbar).onToggleAll!();
      await tester.pumpAndSettle();
      expect(_collection(tester).selected, isEmpty);
      expect(tester.widget<CollectionSelectionMark>(mark).visible, isTrue);
      expect(tester.widget<CollectionSelectionMark>(mark).selected, isFalse);
      expect(tester.getRect(card), listRect);
      tester.widget<BookshelfSelectionToolbar>(toolbar).onCancel!();
      await tester.pumpAndSettle();
      expect(tester.widget<CollectionSelectionMark>(mark).visible, isFalse);
      expect(tester.getRect(card), listRect);
      final scroll = await tester.startGesture(tester.getCenter(card));
      await tester.pump(const Duration(milliseconds: 200));
      await scroll.moveBy(const Offset(0, -100));
      await tester.pump(const Duration(milliseconds: 350));
      await scroll.up();
      await tester.pumpAndSettle();
      expect(_collection(tester).selecting, isFalse);
      expect(data.opened, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'favorite facets submit, cancel and clear using all loaded third-party metadata',
    (tester) async {
      final data = _Data([
        for (var id = 1; id <= 12; id++)
          _row(
            'a',
            id: '$id',
            year: id == 12 ? '2024' : '2020',
            typeName: '第三方分类',
          ),
      ]);
      addTearDown(data.dispose);
      await data.store.createFolder('a', '无匹配片单');
      await _mount(
        tester,
        data,
        search: const SearchStatusState(sources: ['a']),
      );
      await tester.pumpAndSettle();
      expect(_collection(tester).items, hasLength(12));
      await openFilter(tester);
      expect(find.byKey(const ValueKey('shelf-facet-tags')), findsNothing);
      expect(
        find.byKey(const ValueKey('shelf-facet-category')),
        findsOneWidget,
      );
      await pickYear(tester, '2024');
      await tester.tap(find.byTooltip(t.common.cancel));
      await tester.pumpAndSettle();
      expect(_collection(tester).items, hasLength(12));
      expect(_filterActive(tester), false);
      await openFilter(tester);
      await pickYear(tester, '2024');
      await applyFilter(tester);
      expect(_collection(tester).items.single.id, 'key-a-12');
      expect(find.byType(BookshelfFolderCard), findsNothing);
      expect(_filterActive(tester), true);
      expect(_action('filter-status'), findsNothing);
      expect(_action('clear-filter'), findsNothing);
      expect(
        data.enriched,
        isEmpty,
        reason: 'local facets must not fetch missing details',
      );
      await resetFilter(tester);
      expect(_collection(tester).items, hasLength(12));
      expect(find.byType(BookshelfFolderCard), findsOneWidget);
      expect(data.removed, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'history facets cancel, apply, clear and delete only matching visible rows',
    (tester) async {
      final data = _Data([
        _row('a', id: '1', year: '2024'),
        _row('a', id: '2', year: '2025'),
        _row('b', id: '1', year: '2024'),
      ]);
      addTearDown(data.dispose);
      const search = SearchStatusState(
        sources: ['a'],
        keyword: '作品',
        sort: 'da',
      );
      await _mount(tester, data, mode: ShelfPageMode.history, search: search);
      await tester.pumpAndSettle();
      expect(_collection(tester).items, hasLength(2));
      await openFilter(tester);
      for (final scope in ['current', 'descendants', 'all']) {
        expect(find.byKey(ValueKey('shelf-scope-$scope')), findsNothing);
      }
      await pickYear(tester, '2024');
      await tester.tap(find.byTooltip(t.common.cancel));
      await tester.pumpAndSettle();
      expect(_collection(tester).items, hasLength(2));
      await openFilter(tester);
      await pickYear(tester, '2024');
      await applyFilter(tester);
      expect(_collection(tester).items.single.id, 'key-a-1');
      expect(_collection(tester).storageKey, contains('history.a.null.作品.da'));
      expect(_filterActive(tester), true);
      expect(find.byType(BookshelfFolderCard), findsNothing);
      _collection(tester).onLongPress!(_collection(tester).items.single);
      await tester.pumpAndSettle();
      await tester.tap(_action('select-all'));
      await tester.pumpAndSettle();
      expect(
        _collection(tester).selected,
        isEmpty,
        reason:
            'The only visible row was already selected by long press, so all/none first clears it',
      );
      await tester.tap(_action('select-all'));
      await tester.pumpAndSettle();
      expect(_collection(tester).selected, {'key-a-1'});
      await tester.tap(_action('remove'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(t.common.delete),
        ),
      );
      await tester.pumpAndSettle();
      expect(data.removed.single.$1, ShelfPageMode.history);
      expect(data.removed.single.$2.map((row) => row.key), ['key-a-1']);
      expect(data.rows.map((row) => row.key).toSet(), {'key-a-2', 'key-b-1'});
      expect(find.text(t.bookshelf.facets.noResults), findsOneWidget);
      await tester.tap(_action('clear-empty-filter'));
      await tester.pumpAndSettle();
      expect(_collection(tester).items.single.id, 'key-a-2');
      expect(data.enriched, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'download quality facets use real record fields, cancel, delete visible and clear zero results',
    (tester) async {
      final data = _Data([
        _row('a', id: '1', quality: '1080p'),
        _row('a', id: '2', quality: '720p'),
        _row('a', id: '3'),
        _row('b', id: '1', quality: '1080p'),
      ]);
      addTearDown(data.dispose);
      const search = SearchStatusState(
        sources: ['a'],
        keyword: '作品',
        sort: 'da',
      );
      await _mount(tester, data, mode: ShelfPageMode.download, search: search);
      await tester.pumpAndSettle();
      Future<void> draft() async {
        await openFilter(tester);
        for (final field in ['year', 'category', 'tags', 'area', 'language']) {
          expect(find.byKey(ValueKey('shelf-facet-$field')), findsNothing);
        }
        for (final scope in ['current', 'descendants', 'all']) {
          expect(find.byKey(ValueKey('shelf-scope-$scope')), findsNothing);
        }
        await pickFacet(tester, 'quality', '1080p');
      }

      await draft();
      await tester.tap(find.byTooltip(t.common.cancel));
      await tester.pumpAndSettle();
      expect(_collection(tester).items, hasLength(3));
      await draft();
      await applyFilter(tester);
      expect(_collection(tester).items.single.id, 'key-a-1');
      expect(_collection(tester).storageKey, contains('download.a.null.作品.da'));
      _collection(tester).onLongPress!(_collection(tester).items.single);
      await tester.pumpAndSettle();
      await tester.tap(_action('select-all'));
      await tester.pumpAndSettle();
      expect(
        _collection(tester).selected,
        isEmpty,
        reason:
            'The only visible row was already selected by long press, so all/none first clears it',
      );
      await tester.tap(_action('select-all'));
      await tester.pumpAndSettle();
      expect(_collection(tester).selected, {'key-a-1'});
      await tester.tap(_action('remove'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(t.common.delete),
        ),
      );
      await tester.pumpAndSettle();
      expect(data.removed.single.$1, ShelfPageMode.download);
      expect(data.removed.single.$2.map((row) => row.key), ['key-a-1']);
      expect(data.rows.map((row) => row.key).toSet(), {
        'key-a-2',
        'key-a-3',
        'key-b-1',
      });
      expect(find.text(t.bookshelf.facets.noResults), findsOneWidget);
      await tester.tap(_action('clear-empty-filter'));
      await tester.pumpAndSettle();
      expect(_collection(tester).items.map((item) => item.id).toSet(), {
        'key-a-2',
        'key-a-3',
      });
      expect(_filterActive(tester), false);
      expect(data.enriched, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final mode in [ShelfPageMode.favorite, ShelfPageMode.history]) {
    testWidgets(
      'source clock reaches grid and detailed poster once: ${mode.name}',
      (tester) async {
        final data = _Data([
          _row(
            'a',
            id: 'duration-short',
            remarks: '1:30',
            year: '2026',
            progress: mode == ShelfPageMode.history ? '0:12' : '',
          ),
          _row(
            'a',
            id: 'duration-long',
            sourceDuration: '02:42:25',
            year: '2025',
          ),
        ]);
        addTearDown(data.dispose);
        await _mount(tester, data, mode: mode, interfaceStyle: 'breeze');
        await tester.pumpAndSettle();
        expect(_collection(tester).mode, ApiVideoView.grid);
        expect(find.text('1:30'), findsOneWidget);
        expect(find.text('2:42:25'), findsOneWidget);
        expect(
          _collection(tester).items
              .firstWhere((item) => item.title.endsWith('duration-short'))
              .sourceDuration,
          '1:30',
        );
        final toolbar = tester.widget<BookshelfContentToolbar>(
          find.byType(BookshelfContentToolbar),
        );
        toolbar.onToggleView!();
        await tester.pumpAndSettle();
        expect(_collection(tester).mode, ApiVideoView.list);
        expect(find.text('1:30'), findsOneWidget);
        expect(find.text('2:42:25'), findsOneWidget);
        final details = tester.widgetList<BookshelfDetailedContent>(
          find.byType(BookshelfDetailedContent),
        );
        expect(details, hasLength(2));
        for (final detail in details) {
          expect(detail.metadata, isNot(contains('1:30')));
          expect(detail.metadata, isNot(contains('2:42:25')));
          expect(detail.metadata, anyOf(contains('2026'), contains('2025')));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final mode in ShelfPageMode.values) {
    testWidgets(
      '${mode.name} ignores an old draft after switching mode away and back',
      (tester) async {
        final data = _Data([
          _row(
            'a',
            id: '1',
            year: mode == ShelfPageMode.download ? '' : '2024',
            quality: mode == ShelfPageMode.download ? '1080p' : '',
          ),
          _row(
            'a',
            id: '2',
            year: mode == ShelfPageMode.download ? '' : '2025',
            quality: mode == ShelfPageMode.download ? '720p' : '',
          ),
        ]);
        addTearDown(data.dispose);
        const search = SearchStatusState(sources: ['a']);
        await _mount(tester, data, mode: mode, search: search);
        await tester.pumpAndSettle();
        await openFilter(tester);
        if (mode == ShelfPageMode.download) {
          await pickFacet(tester, 'quality', '1080p');
        } else {
          await pickYear(tester, '2024');
        }
        final otherMode = ShelfPageMode
            .values[(mode.index + 1) % ShelfPageMode.values.length];
        await _mount(tester, data, mode: otherMode, search: search);
        await tester.pumpAndSettle();
        await _mount(tester, data, mode: mode, search: search);
        await tester.pumpAndSettle();
        await applyFilter(tester);
        expect(
          _collection(tester).items,
          hasLength(2),
          reason: 'draft belongs to the previous mode visit',
        );
        expect(_filterActive(tester), false);
        expect(data.removed, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'flat folder facets distinguish current, all and unfiled without moving records',
    (tester) async {
      final data = _Data([]);
      addTearDown(data.dispose);
      final first = await data.store.createFolder('a', '当前片单');
      final second = await data.store.createFolder('a', '另一片单');
      data.rows = [
        _row('a', id: '1', year: '2024', folderIds: {first}),
        _row('a', id: '2', year: '2025', folderIds: {second}),
        _row('a', id: '3', year: '2026'),
      ];
      final before = (await data.store.read()).toJson();
      await _mount(
        tester,
        data,
        search: const SearchStatusState(sources: ['a']),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('video-shelf.folder.$first')));
      await tester.pumpAndSettle();
      expect(_collection(tester).items.single.id, 'key-a-1');
      await openFilter(tester);
      expect(
        find.byKey(const ValueKey('shelf-scope-descendants')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('shelf-scope-all')));
      await tester.pumpAndSettle();
      await pickYear(tester, '2025');
      await applyFilter(tester);
      expect(_collection(tester).items.single.id, 'key-a-2');
      expect(_collection(tester).badges['key-a-2'], startsWith('另一片单'));
      final caption = tester.widget<BookshelfCardCaption>(
        find.descendant(
          of: find.byKey(const ValueKey('api-video.key-a-2')),
          matching: find.byType(BookshelfCardCaption),
        ),
      );
      expect(caption.subtitle, startsWith('另一片单'));
      expect(caption.subtitle, contains('来源甲'));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              (widget.properties.label?.contains('另一片单') ?? false) &&
              (widget.properties.label?.contains('来源甲') ?? false),
        ),
        findsOneWidget,
      );
      expect((await data.store.read()).toJson(), before);
      await resetFilter(tester);
      expect(_collection(tester).items.single.id, 'key-a-1');
      final more = tester.widget<NativeVideoMenu>(
        find.byKey(const ValueKey('video-shelf.more')),
      );
      expect(more.options.keys, isNot(contains('__all')));
      expect(more.options.keys, isNot(contains('__unfiled')));
      await tester.tap(find.byKey(const ValueKey('video-shelf.back')));
      await tester.pumpAndSettle();
      final rootMore = tester.widget<NativeVideoMenu>(
        find.byKey(const ValueKey('video-shelf.more')),
      );
      expect(rootMore.options.keys, isNot(contains('__unfiled')));
      await openFilter(tester);
      await pickYear(tester, '2026');
      await applyFilter(tester);
      expect(_collection(tester).items.single.id, 'key-a-3');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'stale facet zero results can clear and source changes reset the conditions',
    (tester) async {
      final data = _Data([_row('a', year: '2024')]);
      addTearDown(data.dispose);
      await _mount(
        tester,
        data,
        search: const SearchStatusState(sources: ['a']),
      );
      await tester.pumpAndSettle();
      await openFilter(tester);
      await pickYear(tester, '2024');
      await applyFilter(tester);
      data.rows = [_row('a', year: '2025'), _row('b')];
      data.changes.value++;
      await tester.pumpAndSettle();
      expect(_collection(tester).items, isEmpty);
      expect(find.text(t.bookshelf.facets.noResults), findsOneWidget);
      expect(find.text(t.videoLibrary.favoritesEmpty), findsNothing);
      await tester.tap(_action('clear-empty-filter'));
      await tester.pumpAndSettle();
      expect(_collection(tester).items.single.id, 'key-a-1');
      await openFilter(tester);
      await pickYear(tester, '2025');
      await applyFilter(tester);
      await _mount(
        tester,
        data,
        search: const SearchStatusState(sources: ['b']),
      );
      await tester.pumpAndSettle();
      expect(_collection(tester).items.single.id, 'key-b-1');
      expect(_filterActive(tester), false);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'same resource IDs from different sources open the actual matching row',
    (tester) async {
      final data = _Data([_row('a'), _row('b')]);
      addTearDown(data.dispose);
      await _mount(tester, data);
      await tester.pumpAndSettle();
      final collection = _collection(tester);
      expect(collection.items.map((i) => i.id), ['key-a-1', 'key-b-1']);
      collection.onOpen(collection.items.last);
      await tester.pumpAndSettle();
      expect(data.opened.single.source, 'b');
      expect(data.opened.single.item.id, '1');
      expect(data.opened.single.watchUrl?.queryParameters, {
        'line': '3',
        'episode': '7',
      });
      expect(collection.badges.values, ['来源甲', '来源乙']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'filtered select-all moves and deletes only visible real video records',
    (tester) async {
      final data = _Data([]);
      addTearDown(data.dispose);
      final original = await data.store.createFolder(
        VideoLibraryStore.sharedFolderSource,
        '原片单',
      );
      final target = await data.store.createFolder(
        VideoLibraryStore.sharedFolderSource,
        '目标片单',
      );
      data.rows = [
        _row('a', id: '1', year: '2024', folderIds: {original}),
        _row('a', id: '2', year: '2024', folderIds: {original}),
        _row('a', id: '3', year: '2025', folderIds: {original}),
        _row('b', id: '1', year: '2024', folderIds: {original}),
      ];
      for (final row in data.rows) {
        await data.store.setFavorite(row.source, row.item, true);
        await data.store.assignFolders({row.recordKey!}, {original});
      }
      await _mount(
        tester,
        data,
        search: const SearchStatusState(sources: ['a']),
      );
      await tester.pumpAndSettle();
      await openFilter(tester);
      await pickYear(tester, '2024');
      await applyFilter(tester);
      _collection(tester).onLongPress!(_collection(tester).items.first);
      await tester.pumpAndSettle();
      await tester.tap(_action('select-all'));
      await tester.pumpAndSettle();
      expect(_collection(tester).selected, {'key-a-1', 'key-a-2'});
      await tester.tap(_action('move'));
      await tester.pumpAndSettle();
      final island = find.byKey(const ValueKey('bookshelf.island.surface'));
      await tester.tap(
        find.descendant(of: island, matching: find.text('目标片单')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: island, matching: find.text(t.common.save)),
      );
      await tester.pumpAndSettle();
      final moved = await data.store.read();
      for (final row in data.rows) {
        expect(
          moved.foldersOf(row.recordKey!),
          row.source == 'a' && row.item.id != '3' ? {target} : {original},
        );
      }
      _collection(tester).onLongPress!(_collection(tester).items.first);
      await tester.pumpAndSettle();
      await tester.tap(_action('select-all'));
      await tester.pumpAndSettle();
      await tester.tap(_action('remove'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(t.common.delete),
        ),
      );
      await tester.pumpAndSettle();
      expect(data.removed.single.$2.map((row) => row.key).toSet(), {
        'key-a-1',
        'key-a-2',
      });
      expect(data.rows.map((row) => row.key).toSet(), {'key-a-3', 'key-b-1'});
      expect(find.text(t.bookshelf.facets.noResults), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'clearing a zero-result facet restores the previous unfiltered scroll',
    (tester) async {
      final data = _Data([
        for (var id = 1; id <= 60; id++) _row('a', id: '$id', year: '2024'),
      ]);
      addTearDown(data.dispose);
      await _mount(tester, data);
      await tester.pumpAndSettle();
      ScrollPosition position() => tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(ApiVideoCollection),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      position().jumpTo(650);
      await tester.pumpAndSettle();
      final previous = position().pixels;
      await openFilter(tester);
      await pickYear(tester, '2024');
      await applyFilter(tester);
      data.rows = [
        for (var id = 1; id <= 60; id++) _row('a', id: '$id', year: '2025'),
      ];
      data.changes.value++;
      await tester.pumpAndSettle();
      expect(find.text(t.bookshelf.facets.noResults), findsOneWidget);
      await tester.tap(_action('clear-empty-filter'));
      await tester.pumpAndSettle();
      expect(position().pixels, closeTo(previous, 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a local detailed row preserves identities without requesting hidden descriptions',
    (tester) async {
      final data = _Data([_row('a'), _row('b')]);
      addTearDown(data.dispose);
      await _mount(tester, data);
      await tester.pumpAndSettle();
      final view = find.byKey(const ValueKey('video-shelf.view'));
      expect(tester.getSize(view), const Size(44, 44));
      await tester.tap(view);
      await tester.pumpAndSettle();
      expect(data.enriched, isEmpty);
      expect(find.text('详情a'), findsNothing);
      final collection = _collection(tester);
      expect(collection.items.map((item) => item.id), ['key-a-1', 'key-b-1']);
      expect(collection.loadDetail, isNull);
      collection.onOpen(collection.items.last);
      await tester.pumpAndSettle();
      expect(data.opened.single.source, 'b');
      expect(data.opened.single.item.id, '1');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mixed-source selection can move or copy and cancelled deletion writes nothing',
    (tester) async {
      final data = _Data([_row('a'), _row('b')]);
      addTearDown(data.dispose);
      final selections = <bool>[];
      await _mount(tester, data, selection: selections.add);
      await tester.pumpAndSettle();
      _collection(tester).onLongPress!(_collection(tester).items.first);
      await tester.pumpAndSettle();
      _collection(tester).onOpen(_collection(tester).items.last);
      await tester.pumpAndSettle();
      expect(_actionCallback(tester, 'move'), isNotNull);
      expect(selections, [true]);
      await tester.tap(_action('remove'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(t.common.cancel),
        ),
      );
      await tester.pumpAndSettle();
      expect(data.removed, isEmpty);
      await tester.tap(_action('cancel'));
      await tester.pumpAndSettle();
      expect(selections, [true, false]);
      expect(_collection(tester).selecting, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'history removal only affects selected records in the current source scope',
    (tester) async {
      final data = _Data([_row('a', progress: '03:20'), _row('b')]);
      addTearDown(data.dispose);
      await _mount(
        tester,
        data,
        mode: ShelfPageMode.history,
        search: const SearchStatusState(sources: ['a']),
      );
      await tester.pumpAndSettle();
      expect(_collection(tester).items, hasLength(1));
      expect(_collection(tester).badges.values.single, '来源甲 · 03:20');
      _collection(tester).onLongPress!(_collection(tester).items.single);
      await tester.pumpAndSettle();
      await tester.tap(_action('remove'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(t.common.delete),
        ),
      );
      await tester.pumpAndSettle();
      expect(data.removed.single.$1, ShelfPageMode.history);
      expect(data.removed.single.$2.single.source, 'a');
      expect(data.rows.single.source, 'b');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'exports describe system files and remove records only through the index',
    (tester) async {
      final data = _Data([_row('a')]);
      addTearDown(data.dispose);
      await _mount(tester, data, mode: ShelfPageMode.download);
      await tester.pumpAndSettle();
      await selectMore(tester, '__help');
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining(t.bookshelf.videoExportsHint),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(t.common.gotIt),
        ),
      );
      await tester.pumpAndSettle();
      _collection(tester).onLongPress!(_collection(tester).items.single);
      await tester.pumpAndSettle();
      await tester.tap(_action('remove'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(t.download.videoExternalFiles),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(t.common.delete),
        ),
      );
      await tester.pumpAndSettle();
      expect(data.removed.single.$1, ShelfPageMode.download);
      expect(data.removed.single.$2.single.key, 'key-a-1');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an unvisited video pane has no empty result before its read', (
    tester,
  ) async {
    final data = _Data([]);
    addTearDown(data.dispose);
    final read = Completer<List<VideoBookshelfRow>>();
    var calls = 0;
    data.loader = (_, _) {
      calls++;
      return read.future;
    };
    await _mount(tester, data, active: false);
    final toolbar = find.byType(BookshelfContentToolbar);
    expect(calls, 0);
    expect(_collection(tester).loading, isTrue);
    expect(find.text(t.videoLibrary.favoritesEmpty), findsNothing);
    expect(tester.widget<BookshelfContentToolbar>(toolbar).subtitle, isEmpty);
    expect(
      tester.widget<BookshelfContentToolbar>(toolbar).onCreateFolder,
      isNull,
    );
    await _mount(tester, data);
    expect(calls, 1);
    expect(find.text(t.videoLibrary.favoritesEmpty), findsNothing);
    read.complete([]);
    await tester.pumpAndSettle();
    expect(_collection(tester).loading, isFalse);
    expect(find.text(t.videoLibrary.favoritesEmpty), findsOneWidget);
    expect(
      tester.widget<BookshelfContentToolbar>(toolbar).subtitle,
      t.videoLibrary.results(count: 0),
    );
  });

  testWidgets(
    'late results from a prior source scope or inactive pane cannot reappear',
    (tester) async {
      final first = Completer<List<VideoBookshelfRow>>(),
          second = Completer<List<VideoBookshelfRow>>();
      final data = _Data([]);
      addTearDown(data.dispose);
      data.loader = (_, search) =>
          search.sources.contains('a') ? first.future : second.future;
      await _mount(
        tester,
        data,
        search: const SearchStatusState(sources: ['a']),
      );
      await _mount(
        tester,
        data,
        search: const SearchStatusState(sources: ['b']),
      );
      second.complete([_row('b')]);
      await tester.pumpAndSettle();
      expect(_collection(tester).items.single.id, 'key-b-1');
      first.complete([_row('a')]);
      await tester.pumpAndSettle();
      expect(_collection(tester).items.single.id, 'key-b-1');
      final inactive = Completer<List<VideoBookshelfRow>>();
      data.loader = (_, _) => inactive.future;
      await _mount(
        tester,
        data,
        search: const SearchStatusState(sources: ['b']),
        refresh: 1,
      );
      await _mount(
        tester,
        data,
        search: const SearchStatusState(sources: ['b']),
        refresh: 1,
        active: false,
      );
      inactive.complete([_row('b', id: '2')]);
      await tester.pumpAndSettle();
      expect(_collection(tester).items.single.id, 'key-b-1');
      expect(_collection(tester).detailsActive, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all/none follows the visible source and remains reachable after scrolling',
    (tester) async {
      final data = _Data([
        for (var i = 1; i <= 12; i++) _row('a', id: '$i'),
        _row('b'),
      ]);
      addTearDown(data.dispose);
      await _mount(
        tester,
        data,
        search: const SearchStatusState(sources: ['a']),
      );
      await tester.pumpAndSettle();
      _collection(tester).onLongPress!(_collection(tester).items.first);
      await tester.pumpAndSettle();
      await tester.tap(_action('select-all'));
      await tester.pumpAndSettle();
      expect(_collection(tester).selected, hasLength(12));
      expect(find.byTooltip(t.bookshelf.deselectAll), findsOneWidget);
      _collection(tester).onOpen(_collection(tester).items.first);
      await tester.pumpAndSettle();
      expect(find.byTooltip(t.common.selectAll), findsOneWidget);
      await tester.tap(_action('select-all'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pumpAndSettle();
      expect(_action('cancel').hitTestable(), findsOneWidget);
      await tester.tap(_action('select-all'));
      await tester.pumpAndSettle();
      expect(_collection(tester).selected, isEmpty);
      expect(_collection(tester).selecting, isTrue);
      await tester.tap(_action('cancel'));
      await tester.pumpAndSettle();
      expect(_collection(tester).selecting, isFalse);
      expect(data.removed, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'manual pull awaits the visible read and distinguishes unchanged and failed',
    (tester) async {
      final data = _Data([_row('a')]);
      addTearDown(data.dispose);
      await _mount(tester, data, mode: ShelfPageMode.history);
      await tester.pumpAndSettle();

      final gate = Completer<List<VideoBookshelfRow>>();
      var reads = 0;
      data.loader = (_, _) {
        reads++;
        return gate.future;
      };
      Future<void> pull() async {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, 350));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
      }

      await pull();
      expect(reads, 1);
      expect(_collection(tester).items.single.id, 'key-a-1');
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text(t.common.refreshUnchanged), findsNothing);

      gate.complete([_row('a')]);
      await tester.pumpAndSettle();
      expect(find.text(t.common.refreshUnchanged), findsOneWidget);
      expect(_collection(tester).retryMissingCoverDetailsOnRefresh, isFalse);
      await tester.pump(const Duration(seconds: 3));

      data.loader = (_, _) async => throw StateError('local read failed');
      await pull();
      await tester.pumpAndSettle();
      expect(_collection(tester).items.single.id, 'key-a-1');
      expect(find.text(t.common.refreshRetained), findsOneWidget);
      expect(_action('retry'), findsOneWidget);

      data.loader = (_, _) async => [_row('a', progress: '2:30')];
      await tester.tap(_action('retry'));
      await tester.pumpAndSettle();
      expect(_collection(tester).items.single.id, 'key-a-1');
      expect(find.text(t.common.refreshRetained), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'load failure offers a retry and successful retry restores content',
    (tester) async {
      var reads = 0;
      final data = _Data([]);
      addTearDown(data.dispose);
      data.loader = (_, _) async {
        if (++reads == 1) throw StateError('local read failed');
        return [_row('a')];
      };
      await _mount(tester, data);
      await tester.pumpAndSettle();
      expect(find.text(t.common.loadingFailed), findsOneWidget);
      await tester.tap(_action('retry'));
      await tester.pumpAndSettle();
      expect(_collection(tester).items.single.id, 'key-a-1');
      expect(reads, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('single-source folder classification writes the real item key', (
    tester,
  ) async {
    final data = _Data([_row('a')]);
    addTearDown(data.dispose);
    await data.store.setFavorite('a', data.rows.single.item, true);
    final folder = await data.store.createFolder('a', '今晚看');
    await _mount(tester, data, search: const SearchStatusState(sources: ['a']));
    await tester.pumpAndSettle();
    _collection(tester).onLongPress!(_collection(tester).items.single);
    await tester.pumpAndSettle();
    await tester.tap(_action('move'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('bookshelf.island.surface')),
        matching: find.text('今晚看'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.common.save));
    await tester.pumpAndSettle();
    final snapshot = await data.store.read();
    expect(snapshot.foldersOf(VideoLibraryStore.itemKey('a', '1')), {folder});
    expect(
      snapshot.favorites.containsKey(VideoLibraryStore.itemKey('a', 'key-a-1')),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'single-source folders can be created and renamed with the existing dialogs',
    (tester) async {
      final data = _Data([_row('a')]);
      addTearDown(data.dispose);
      await _mount(
        tester,
        data,
        search: const SearchStatusState(sources: ['a']),
      );
      await tester.pumpAndSettle();
      await selectMore(tester, '__new');
      await tester.enterText(
        find.byKey(const ValueKey('video-folder.name')),
        '今晚看',
      );
      await tester.pump();
      await tester.tap(find.text(t.common.save));
      await tester.pumpAndSettle();
      var folders = (await data.store.read()).foldersFor('a');
      expect(folders.values.single.data['name'], '今晚看');
      expect((await data.store.read()).foldersFor('b').keys, folders.keys);
      await tester.tap(find.byKey(const ValueKey('video-shelf.more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.videoLibrary.renameFolder));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('video-folder.name')),
        '周末看',
      );
      await tester.pump();
      await tester.tap(find.text(t.common.save));
      await tester.pumpAndSettle();
      folders = (await data.store.read()).foldersFor('a');
      expect(folders.values.single.data['name'], '周末看');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('inactive panes do not read data until activated', (
    tester,
  ) async {
    var reads = 0;
    final data = _Data([_row('a')]);
    addTearDown(data.dispose);
    data.loader = (_, _) async {
      reads++;
      return data.rows;
    };
    await _mount(tester, data, active: false);
    await tester.pumpAndSettle();
    data.changes.value++;
    await tester.pumpAndSettle();
    expect(reads, 0);
    await _mount(tester, data);
    await tester.pumpAndSettle();
    expect(reads, 1);
    expect(_collection(tester).items.single.id, 'key-a-1');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'clean video pane revisits reuse rows and dirty bursts coalesce',
    (tester) async {
      var reads = 0;
      final next = Completer<List<VideoBookshelfRow>>();
      final data = _Data([_row('a')]);
      addTearDown(data.dispose);
      data.loader = (_, _) async {
        reads++;
        return reads == 2 ? next.future : data.rows;
      };
      await _mount(tester, data);
      await tester.pumpAndSettle();
      expect(reads, 1);
      await _mount(tester, data, active: false);
      await _mount(tester, data);
      await tester.pumpAndSettle();
      expect(reads, 1);

      await _mount(tester, data, active: false);
      data.changes.value++;
      data.changes.value++;
      expect(reads, 1);
      await _mount(tester, data);
      expect(reads, 2);
      data.changes.value++;
      data.changes.value++;
      expect(reads, 2);
      data.rows = [_row('a', id: 'fresh')];
      next.complete([_row('a', id: 'older')]);
      await tester.pumpAndSettle();
      expect(reads, 3);
      expect(_collection(tester).items.single.id, 'key-a-fresh');
    },
  );

  testWidgets('last detailed row scrolls completely above the floating bar', (
    tester,
  ) async {
    const bottomInset = 72.0;
    final data = _Data([for (var id = 0; id < 18; id++) _row('a', id: '$id')]);
    addTearDown(data.dispose);
    await _mount(tester, data, bottomInset: bottomInset);
    await tester.pumpAndSettle();
    await pressControl(tester, _action('view'));
    await tester.pumpAndSettle();
    expect(_collection(tester).mode, ApiVideoView.list);
    final collection = find.byType(ApiVideoCollection);
    final scrollable = find.descendant(
      of: collection,
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    final title = find.text(_collection(tester).items.last.title);
    final row = find.ancestor(
      of: title,
      matching: find.byType(BookshelfDetailedContent),
    );
    expect(title.hitTestable(), findsOneWidget);
    expect(
      tester.getBottomLeft(row).dy,
      lessThan(tester.getBottomLeft(collection).dy - bottomInset),
    );
    await tester.tap(title);
    expect(data.opened.single.key, _collection(tester).items.last.id);
  });

  testWidgets('video source revisits restore deep positions after loading', (
    tester,
  ) async {
    final data = _Data([
      for (var id = 0; id < 84; id++) _row('a', id: '$id'),
      _row('b'),
    ]);
    addTearDown(data.dispose);
    const first = SearchStatusState(sources: ['a']);
    const second = SearchStatusState(sources: ['b']);
    final top = find.byKey(const ValueKey('bookshelf.return-to-top'));
    ScrollPosition position() => tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(ApiVideoCollection),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;

    await _mount(tester, data, search: first, showReturnToTop: true);
    await tester.pumpAndSettle();
    expect(top, findsNothing);
    position().jumpTo(position().viewportDimension * 2.5);
    await tester.pumpAndSettle();
    final offset = position().pixels;
    expect(top, findsOneWidget);

    await _mount(tester, data, search: first, showReturnToTop: false);
    await tester.pumpAndSettle();
    expect(top, findsNothing);
    expect(position().pixels, closeTo(offset, 1));

    await _mount(tester, data, search: second, showReturnToTop: true);
    await tester.pumpAndSettle();
    expect(position().pixels, 0);
    expect(top, findsNothing);
    final delayed = Completer<List<VideoBookshelfRow>>();
    data.loader = (_, _) => delayed.future;
    await _mount(tester, data, search: first, showReturnToTop: true);
    expect(position().pixels, 0);
    expect(top, findsNothing);
    delayed.complete(data.rows);
    await tester.pumpAndSettle();
    expect(position().pixels, closeTo(offset, 1));
    expect(top, findsOneWidget);
    await tester.tap(top);
    await tester.pumpAndSettle();
    expect(position().pixels, 0);
    expect(top, findsNothing);
  });

  testWidgets('320pt large text keeps management targets usable', (
    tester,
  ) async {
    final data = _Data([_row('a')]);
    addTearDown(data.dispose);
    await _mount(
      tester,
      data,
      search: const SearchStatusState(sources: ['a']),
      scale: 1.8,
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(_action('more')).height, greaterThanOrEqualTo(44));
    await selectMore(tester, '__manage');
    expect(tester.getSize(_action('cancel')).height, greaterThanOrEqualTo(44));
    await tester.tap(_action('cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'every video mode keeps destructive actions in the floating layer and reserves its last row',
    (tester) async {
      for (final mode in ShelfPageMode.values) {
        final data = _Data([_row('a')]);
        addTearDown(data.dispose);
        await _mount(tester, data, mode: mode);
        await tester.pumpAndSettle();
        _collection(tester).onLongPress!(_collection(tester).items.single);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(BookshelfSelectionToolbar),
            matching: _action('remove'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(BookshelfFloatingSelectionActions),
            matching: _action('remove'),
          ),
          findsOneWidget,
        );
        expect(
          tester.getTopLeft(_action('remove')).dy,
          greaterThan(tester.getBottomLeft(_action('cancel')).dy),
        );
        expect(_collection(tester).contentBottomPadding, 88);
        await tester.tap(_action('cancel'));
        await tester.pumpAndSettle();
        expect(_collection(tester).contentBottomPadding, 24);
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'visible new folder works with an empty single source and cancelling never creates',
    (tester) async {
      final data = _Data([]);
      addTearDown(data.dispose);
      await _mount(
        tester,
        data,
        search: const SearchStatusState(sources: ['a']),
        scale: 2,
      );
      await tester.pumpAndSettle();
      final create = _action('more');
      expect(tester.getSize(create).height, greaterThanOrEqualTo(44));
      expect(tester.widget<NativeVideoMenu>(create).options, contains('__new'));
      await selectMore(tester, '__new');
      await tester.enterText(
        find.byKey(const ValueKey('video-folder.name')),
        '临时',
      );
      await tester.tap(find.text(t.common.cancel));
      await tester.pumpAndSettle();
      expect((await data.store.read()).foldersFor('a'), isEmpty);
      await _mount(
        tester,
        data,
        search: const SearchStatusState(sources: ['a', 'b']),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<NativeVideoMenu>(create).options, contains('__new'));
      await selectMore(tester, '__new');
      await tester.enterText(
        find.byKey(const ValueKey('video-folder.name')),
        '跨插件文件夹',
      );
      await tester.pump();
      await tester.tap(find.text(t.common.save));
      await tester.pumpAndSettle();
      final snapshot = await data.store.read();
      expect(snapshot.foldersFor('a').values.single.data['name'], '跨插件文件夹');
      expect(snapshot.foldersFor('b').values.single.data['name'], '跨插件文件夹');
      expect(find.text(t.videoLibrary.folderScopeHint), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'folder grid opens, returns, and deleting a folder keeps favorites',
    (tester) async {
      final data = _Data([_row('a')]);
      addTearDown(data.dispose);
      await data.store.setFavorite('a', data.rows.single.item, true);
      final folder = await data.store.createFolder(
        VideoLibraryStore.sharedFolderSource,
        '片单',
      );
      await data.store.assignFolders({data.rows.single.recordKey!}, {folder});
      data.rows = [
        _row('a', folderIds: {folder}),
      ];
      await _mount(tester, data);
      await tester.pumpAndSettle();
      final card = find.byKey(ValueKey('video-shelf.folder.$folder'));
      expect(find.byType(BookshelfFolderCard), findsOneWidget);
      expect(_collection(tester).gridColumns, 3);
      final folderRect = tester.getRect(card);
      final itemRect = tester.getRect(
        find.byKey(const ValueKey('api-video.key-a-1')),
      );
      expect(folderRect.top, itemRect.top);
      expect(folderRect.width, closeTo(itemRect.width, .01));
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(BookshelfFolderCard), findsNothing);
      expect(_collection(tester).items, hasLength(1));
      await tester.tap(find.byKey(const ValueKey('video-shelf.back')));
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
      await tester.longPress(card);
      await tester.pumpAndSettle();
      expect(_action('move'), findsOneWidget);
      expect(_actionCallback(tester, 'move'), isNull);
      expect(_actionCallback(tester, 'copy'), isNull);
      await tester.tap(_action('remove'));
      await tester.pumpAndSettle();
      expect(find.text(t.videoLibrary.folderDeleteHint), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(t.common.cancel),
        ),
      );
      await tester.pumpAndSettle();
      expect((await data.store.read()).folders[folder]!.deleted, isFalse);
      await tester.tap(_action('remove'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(t.common.delete),
        ),
      );
      await tester.pumpAndSettle();
      final snapshot = await data.store.read();
      expect(snapshot.folders[folder]!.deleted, isTrue);
      expect(snapshot.favorites[data.rows.single.recordKey!]!.deleted, isFalse);
      expect(data.removed, isEmpty);
      expect(_collection(tester).selecting, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pane copy preserves the prior folder and move replaces it', (
    tester,
  ) async {
    final data = _Data([_row('a')]);
    addTearDown(data.dispose);
    await data.store.setFavorite('a', data.rows.single.item, true);
    final old = await data.store.createFolder('a', '原分类');
    final target = await data.store.createFolder('a', '新分类');
    final itemKey = data.rows.single.recordKey!;
    await data.store.assignFolders({itemKey}, {old});
    await _mount(tester, data, search: const SearchStatusState(sources: ['a']));
    await tester.pumpAndSettle();
    for (final action in ['copy', 'move']) {
      _collection(tester).onLongPress!(_collection(tester).items.single);
      await tester.pumpAndSettle();
      await tester.tap(_action(action));
      await tester.pumpAndSettle();
      final island = find.byKey(const ValueKey('bookshelf.island.surface'));
      await tester.tap(find.descendant(of: island, matching: find.text('新分类')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: island, matching: find.text(t.common.save)),
      );
      await tester.pumpAndSettle();
      expect(
        (await data.store.read()).foldersOf(itemKey),
        action == 'copy' ? {old, target} : {target},
      );
      expect(_collection(tester).selecting, isFalse);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'folder and video leading rows retain the visible item on view switches',
    (tester) async {
      final data = _Data([for (var i = 1; i <= 30; i++) _row('a', id: '$i')]);
      addTearDown(data.dispose);
      for (var i = 0; i < 3; i++) {
        await data.store.createFolder('a', '片单$i');
      }
      await _mount(tester, data);
      await tester.pumpAndSettle();
      ScrollPosition position() => tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      final item = find.byKey(const ValueKey('api-video.key-a-7'));
      final viewport = tester.getRect(find.byType(CustomScrollView));
      final offset = tester.getTopLeft(item).dy - viewport.top;
      position().jumpTo(offset);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(item).dy, closeTo(viewport.top, .1));
      await tester.tap(find.byKey(const ValueKey('video-shelf.view')));
      await tester.pumpAndSettle();
      expect(_collection(tester).mode, ApiVideoView.list);
      expect(tester.getTopLeft(item).dy, closeTo(viewport.top, .1));
      await tester.tap(find.byKey(const ValueKey('video-shelf.view')));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(item).dy, closeTo(viewport.top, .1));
      expect(tester.takeException(), isNull);
    },
  );
  for (final interfaceStyle in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 1.8]) {
        testWidgets(
          'video shelf $interfaceStyle ${brightness.name} shares three-column captions and toolbar at scale $scale',
          (tester) async {
            final data = _Data([_row('a'), _row('b'), _row('a', id: '2')]);
            addTearDown(data.dispose);
            final folder = await data.store.createFolder(
              VideoLibraryStore.sharedFolderSource,
              '真实片单',
            );
            data.rows = [
              _row('a', folderIds: {folder}),
              _row('b', folderIds: {folder}),
              _row('a', id: '2'),
            ];
            await _mount(
              tester,
              data,
              interfaceStyle: interfaceStyle,
              brightness: brightness,
              scale: scale,
            );
            await tester.pumpAndSettle();
            expect(
              Theme.of(
                tester.element(find.byType(BookshelfContentToolbar)),
              ).brightness,
              brightness,
            );
            expect(
              find.byType(UiKitView),
              interfaceStyle == 'system' ? findsWidgets : findsNothing,
            );
            final delegate =
                tester.widget<SliverGrid>(find.byType(SliverGrid)).gridDelegate
                    as SliverGridDelegateWithFixedCrossAxisCount;
            expect(delegate.crossAxisCount, 3);
            final folderCard = find.byKey(
              ValueKey('video-shelf.folder.$folder'),
            );
            final first = find.byKey(const ValueKey('api-video.key-a-1'));
            final second = find.byKey(const ValueKey('api-video.key-b-1'));
            final folderRect = tester.getRect(folderCard),
                firstRect = tester.getRect(first),
                secondRect = tester.getRect(second);
            expect({
              folderRect.top,
              firstRect.top,
              secondRect.top,
            }, hasLength(1));
            expect({
              folderRect.left,
              firstRect.left,
              secondRect.left,
            }, hasLength(3));
            expect(folderRect.width, closeTo(firstRect.width, .01));
            final poster = find.descendant(
              of: first,
              matching: find.byType(ApiVideoPoster),
            );
            final posterRect = tester.getRect(poster);
            expect(posterRect.width / posterRect.height, closeTo(2 / 3, .001));
            final caption = find.descendant(
              of: first,
              matching: find.byType(BookshelfCardCaption),
            );
            expect(tester.widget<BookshelfCardCaption>(caption).title, '作品a1');
            expect(
              tester.widget<BookshelfCardCaption>(caption).subtitle,
              '来源甲',
            );
            expect(
              tester.getTopLeft(caption).dy,
              greaterThanOrEqualTo(posterRect.bottom),
            );
            final toolbar = find.byType(BookshelfContentToolbar);
            final ordered = ['cover-privacy', 'filter', 'view', 'more']
                .map(
                  (id) => find.descendant(
                    of: toolbar,
                    matching: find.byKey(ValueKey('video-shelf.$id')),
                  ),
                )
                .toList();
            final rects = ordered.map(tester.getRect).toList();
            for (var i = 0; i < rects.length; i++) {
              for (var j = i + 1; j < rects.length; j++) {
                expect(rects[i].overlaps(rects[j]), isFalse);
              }
            }
            // Only the four common reading actions stay in this row.
            final readingOrder = rects;
            for (final rect in rects) {
              expect(rect.width, greaterThanOrEqualTo(44));
              expect(rect.height, greaterThanOrEqualTo(44));
            }
            expect(_action('new-folder'), findsNothing);
            expect(_action('manage'), findsNothing);
            for (var i = 0; i < readingOrder.length - 1; i++) {
              final first = readingOrder[i], next = readingOrder[i + 1];
              expect(
                first.top == next.top
                    ? first.left < next.left
                    : first.bottom <= next.top,
                isTrue,
              );
            }
            final more = tester.widget<NativeVideoMenu>(
              find.byKey(const ValueKey('video-shelf.more')),
            );
            expect(more.hostPresentation, isTrue);
            expect(more.options.keys, containsAll(['__new', '__manage']));
            final menu = find.descendant(
              of: folderCard,
              matching: find.byType(NativeVideoMenu),
            );
            final gridTrigger = tester.widget<NativeVideoMenu>(menu);
            expect(gridTrigger.symbol, 'breeze.more.on-cover');
            expect(gridTrigger.icon, Icons.more_horiz);
            expect(gridTrigger.bare && gridTrigger.overArtwork, isTrue);
            expect(gridTrigger.width, 44);
            expect(
              tester.getTopLeft(menu).dy,
              closeTo(tester.getTopLeft(folderCard).dy + 3, .1),
            );
            await writeUiPreview(
              tester,
              const ValueKey('video-shelf.preview'),
              'shelf-folder-grid-$interfaceStyle-${brightness.name}-$scale',
            );
            await pressControl(
              tester,
              find.byKey(const ValueKey('video-shelf.view')),
            );
            await tester.pumpAndSettle();
            expect(_collection(tester).mode, ApiVideoView.list);
            expect(find.byType(SliverGrid), findsNothing);
            expect(
              tester
                  .widget<BookshelfFolderCard>(find.byType(BookshelfFolderCard))
                  .view,
              BookshelfContentView.list,
            );
            expect(data.enriched, isEmpty);
            await writeUiPreview(
              tester,
              const ValueKey('video-shelf.preview'),
              'shelf-folder-list-$interfaceStyle-${brightness.name}-$scale',
            );
            final counts = find.descendant(
              of: folderCard,
              matching: find.byKey(const ValueKey('shelf-folder.counts')),
            );
            final works = find.descendant(
              of: counts,
              matching: find.text(t.videoLibrary.results(count: 2)),
            );
            expect(works, findsOneWidget);
            expect(
              find.descendant(of: counts, matching: find.byType(Text)),
              findsOneWidget,
            );
            expect(
              tester.getCenter(works).dx,
              greaterThan(tester.getCenter(folderCard).dx),
            );
            expect(
              tester
                  .widget<BookshelfContentToolbar>(
                    find.byType(BookshelfContentToolbar),
                  )
                  .subtitle,
              t.videoLibrary.results(count: 3),
            );
            final trigger = tester.widget<NativeVideoMenu>(menu);
            expect(trigger.symbol, 'breeze.more.vertical');
            expect(trigger.options, contains('replace'));
            expect(trigger.width, 44);
            expect(
              tester.getRect(menu).bottom,
              closeTo(tester.getRect(folderCard).bottom, .1),
            );
            expect(
              tester.getRect(counts).bottom,
              lessThanOrEqualTo(tester.getRect(menu).top),
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(milliseconds: 200));
          },
          variant: TargetPlatformVariant.only(TargetPlatform.iOS),
        );
      }
    }
  }
  for (final mode in ShelfPageMode.values) {
    testWidgets(
      'detail list shows actual local last-watch timestamp only for ${mode.name}',
      (tester) async {
        final watchedAt = DateTime(2026, 11, 1, 21, 37);
        final data = _Data([
          _row(
            'a',
            progress: '03:20',
            watchedAt: watchedAt,
            sourceUpdatedAt: '2040-01-02 01:02',
          ),
        ]);
        addTearDown(data.dispose);
        await _mount(tester, data, mode: mode);
        await tester.pumpAndSettle();
        await tester.tap(_action('view'));
        await tester.pumpAndSettle();
        final collection = _collection(tester),
            item = _collection(tester).items.single;
        final note = t.videoLibrary.lastWatchedAt(time: '2026-11-01 21:37');
        expect(collection.mode, ApiVideoView.list);
        expect(item.updatedAt, '2040-01-02 01:02');
        if (mode == ShelfPageMode.history) {
          final progress = t.bookshelf.watchTo(position: '03:20');
          expect(item.remarks, progress);
          expect(collection.recordNoteBuilder!(item), '$progress\n$note');
          expect(
            find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.label == note,
            ),
            findsOneWidget,
          );
          expect(collection.loadDetail, isNull);
          expect(data.enriched, isEmpty);
          expect(data.rows.single.updatedAt, watchedAt);
          await writeUiPreview(
            tester,
            const ValueKey('video-shelf.preview'),
            'shelf-history-time',
          );
        } else {
          expect(item.remarks, isNot(contains(note)));
          expect(collection.recordNoteBuilder, isNull);
          expect(find.textContaining(note), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
