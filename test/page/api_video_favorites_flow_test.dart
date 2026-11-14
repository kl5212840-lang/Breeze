import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_favorites.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/source_video_list_header.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/page/video/video_library_folder_picker.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

ApiVideoItem _item(String id, String title) => ApiVideoItem(
  id: id,
  title: title,
  detailUrl: Uri.parse('https://example.test/anime/$id.html'),
);

class _FailingFolderStore extends VideoLibraryStore {
  _FailingFolderStore() : super(deviceId: 'test', storageKey: 'failed-folders');

  @override
  Future<void> addToFolders(Set<String> itemKeys, Set<String> folderIds) async {
    throw StateError('test_save_failed');
  }
}

class _DelayedFavoritesStore extends VideoLibraryStore {
  _DelayedFavoritesStore()
    : super(deviceId: 'test', storageKey: 'delayed-favorites');
  final ready = Completer<void>();

  @override
  Future<VideoLibrarySnapshot> read() async {
    await ready.future;
    return super.read();
  }
}

void main() {
  late VideoLibraryStore store;
  final first = _item('1', '星空物语'), second = _item('2', '海边故事');
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = VideoLibraryStore(deviceId: 'test', storageKey: 'favorites-flow');
  });
  tearDown(() => store.dispose());

  Widget favorites({bool active = true}) => ApiVideoFavorites(
    showFolders: true,
    source: 'test',
    mode: ApiVideoView.grid,
    store: store,
    active: active,
    onOpen: (_) async {},
  );
  Finder folderRow(String name) => find.widgetWithText(ListTile, name);
  bool folderChecked(WidgetTester tester, String name) => tester
      .widget<Checkbox>(
        find.descendant(of: folderRow(name), matching: find.byType(Checkbox)),
      )
      .value!;

  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: favorites())));
    await tester.pumpAndSettle();
  }

  for (final (style, direction) in [
    ('system', TextDirection.ltr),
    ('breeze', TextDirection.rtl),
  ]) {
    testWidgets(
      'local favorites keep tools aligned from loading to ready: $style $direction',
      (tester) async {
        final delayed = _DelayedFavoritesStore();
        await delayed.setFavorite('test', first, true);
        final preference = ValueNotifier(style);
        addTearDown(preference.dispose);
        addTearDown(delayed.dispose);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 700);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: preference,
            child: MaterialApp(
              builder: (context, child) => Directionality(
                textDirection: direction,
                child: MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
              ),
              home: Scaffold(
                body: ApiVideoFavorites(
                  source: 'test',
                  mode: ApiVideoView.grid,
                  store: delayed,
                  compactHeader: true,
                  headerLeading: const SourceBackButton(),
                  onOpen: (_) async {},
                ),
              ),
            ),
          ),
        );
        final search = find.byKey(
          const ValueKey('local-favorites.search-toggle'),
        );
        final privacy = find.byKey(
          const ValueKey('local-favorites.cover-privacy'),
        );
        final more = find.byKey(const ValueKey('local-favorites.manage'));
        final startSearch = tester.getCenter(search);
        final startPrivacy = tester.getCenter(privacy);
        expect(more, findsNothing);
        delayed.ready.complete();
        await tester.pumpAndSettle();
        expect(more, findsOneWidget);
        expect(tester.getCenter(search), startSearch);
        expect(tester.getCenter(privacy), startPrivacy);
        expect(tester.getSize(more), const Size(44, 44));
        final back = tester.getCenter(find.byType(SourceBackButton));
        expect(back.dx, direction == TextDirection.ltr ? 28 : 292);
        expect(back.dy, startSearch.dy);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('legacy tracking stays invisible while its favorite remains', (
    tester,
  ) async {
    final home = Uri.parse('https://example.test/');
    final detail = home.resolve('anime/3.html');
    ApiVideoItem series(int count) => ApiVideoItem(
      id: '3',
      title: '已收藏的旧追更作品',
      detailUrl: detail,
      plannedEpisodes: 3,
      lines: [
        ApiVideoLine(
          id: 'main',
          label: 'Main',
          episodes: [
            for (var i = 1; i <= count; i++)
              ApiVideoEpisode(
                id: '$i',
                title: '$i',
                url: home.resolve('media/$i.m3u8'),
                watchUrl: detail.replace(
                  queryParameters: {'line': 'main', 'episode': '$i'},
                ),
              ),
          ],
        ),
      ],
    );
    await store.setFollow('test', series(1), true);
    await store.observeItems('test', [series(2)]);
    final key = VideoLibraryStore.itemKey('test', '3');
    expect((await store.read()).newEpisodes(key), 1);

    final requests = <String>[];
    final repository = ApiVideoRepository(
      source: 'test',
      home: home,
      catalogFn: 'list',
      detailFn: 'detail',
      playbackFn: 'play',
      pluginCall: (operation, _) async {
        requests.add(operation);
        throw StateError('Unexpected update check');
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ApiVideoFavorites(
            source: 'test',
            mode: ApiVideoView.grid,
            store: store,
            repository: repository,
            compactHeader: true,
            onOpen: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(series(1).title), findsOneWidget);
    expect(find.text(t.videoLibrary.newEpisodes(count: 1)), findsNothing);
    expect(
      tester
          .widget<SourceVideoListHeader>(find.byType(SourceVideoListHeader))
          .options
          .containsKey('updates'),
      isFalse,
    );
    expect(requests, isEmpty);
    expect((await store.read()).newEpisodes(key), 1);
  });

  testWidgets('batch adds a folder without replacing distinct memberships', (
    tester,
  ) async {
    final a = await store.createFolder('test', '原分类甲');
    final b = await store.createFolder('test', '原分类乙');
    await store.createFolder('test', '共同分类');
    await store.setFavorite('test', first, true, folderIds: {a});
    await store.setFavorite('test', second, true, folderIds: {b});
    await show(tester);
    await tester.longPress(find.text(first.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text(second.title));
    await tester.pump();
    await tester.tap(find.text(t.bookshelf.addToFolder));
    await tester.pumpAndSettle();
    await tester.tap(folderRow('共同分类'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, t.common.save));
    await tester.pumpAndSettle();
    final snapshot = await store.read();
    final common = snapshot
        .foldersFor('test')
        .entries
        .singleWhere((e) => e.value.data['name'] == '共同分类')
        .key;
    expect(snapshot.foldersOf(VideoLibraryStore.itemKey('test', '1')), {
      a,
      common,
    });
    expect(snapshot.foldersOf(VideoLibraryStore.itemKey('test', '2')), {
      b,
      common,
    });
    expect(tester.takeException(), isNull);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets(
    'search preserves selection and select all uses current results',
    (tester) async {
      await store.importFavorites('test', [first, second]);
      await show(tester);
      await tester.longPress(find.text(first.title));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();
      expect(find.text(t.videoLibrary.selectedCount(count: 1)), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '海边');
      await tester.pumpAndSettle();
      expect(find.text(t.videoLibrary.selectedCount(count: 1)), findsOneWidget);
      await tester.tap(find.text(t.videoLibrary.selectAll));
      await tester.pump();
      expect(find.text(t.videoLibrary.selectedCount(count: 2)), findsOneWidget);
      await tester.tap(find.byTooltip(t.common.clear));
      await tester.pumpAndSettle();
      expect(find.text(t.videoLibrary.selectedCount(count: 2)), findsOneWidget);
      await tester.tap(find.text(t.common.cancel));
      await tester.pumpAndSettle();
      expect(find.text(t.videoLibrary.selectedCount(count: 2)), findsNothing);
      expect((await store.read()).itemsFor('test'), hasLength(2));
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets('back leaves selection then folder before leaving favorites', (
    tester,
  ) async {
    final folder = await store.createFolder('test', '想看');
    await store.setFavorite('test', first, true, folderIds: {folder});
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(body: favorites()),
                ),
              ),
              child: const Text('打开收藏'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开收藏'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, t.videoLibrary.all));
    await tester.pumpAndSettle();
    await tester.tap(find.text('想看'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text(first.title));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(t.common.cancel), findsNothing);
    expect(find.widgetWithText(TextButton, '想看'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, t.videoLibrary.all), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('打开收藏'), findsOneWidget);
  });

  testWidgets('small phone keeps selection controls usable above keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await store.setFavorite('test', first, true);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(body: favorites()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.text(first.title));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField).first);
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    expect(find.text(t.videoLibrary.selectedCount(count: 1)), findsOneWidget);
    expect(find.text(t.common.cancel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small phone large text gives a long folder name its own row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const name = '我的特别喜爱经典动画收藏';
    final folder = await store.createFolder('test', name);
    await store.setFavorite('test', first, true, folderIds: {folder});
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(body: favorites()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, t.videoLibrary.all));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
    final identity = tester.getRect(find.widgetWithText(TextButton, name));
    final sort = tester.getRect(find.byTooltip(t.videoLibrary.sort));
    final manage = tester.getRect(
      find.byKey(const ValueKey('local-favorites.manage')),
    );
    expect(identity.width, greaterThanOrEqualTo(240));
    expect(
      tester.renderObject<RenderParagraph>(find.text(name)).didExceedMaxLines,
      isFalse,
    );
    expect(sort.top, greaterThanOrEqualTo(identity.bottom));
    expect(manage.top, greaterThanOrEqualTo(identity.bottom));
    for (final target in [
      identity,
      sort,
      manage,
      tester.getRect(find.byTooltip(t.common.back)),
    ]) {
      expect(target.width, greaterThanOrEqualTo(44));
      expect(target.height, greaterThanOrEqualTo(44));
    }
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip(t.common.back));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, t.videoLibrary.all), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('regular phone keeps folder sorting and management on one row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final folder = await store.createFolder('test', '想看');
    await store.setFavorite('test', first, true, folderIds: {folder});
    await show(tester);
    await tester.tap(find.widgetWithText(TextButton, t.videoLibrary.all));
    await tester.pumpAndSettle();
    await tester.tap(find.text('想看'));
    await tester.pumpAndSettle();
    final identity = tester.getRect(find.widgetWithText(TextButton, '想看'));
    final sort = tester.getRect(find.byTooltip(t.videoLibrary.sort));
    final manage = tester.getRect(
      find.byKey(const ValueKey('local-favorites.manage')),
    );
    expect(sort.center.dy, closeTo(identity.center.dy, 1));
    expect(manage.center.dy, closeTo(identity.center.dy, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty library still exposes existing folders and management', (
    tester,
  ) async {
    await store.createFolder('test', '空文件夹');
    await show(tester);
    expect(find.text(t.videoLibrary.favoritesEmpty), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, t.videoLibrary.all));
    await tester.pumpAndSettle();
    await tester.tap(find.text('空文件夹'));
    await tester.pumpAndSettle();
    expect(find.text(t.videoLibrary.folderEmpty), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '空文件夹'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.videoSource.manageFolders));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, '空文件夹'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('single item editing can still replace folder memberships', (
    tester,
  ) async {
    final a = await store.createFolder('test', '原分类');
    final b = await store.createFolder('test', '新分类');
    await store.setFavorite('test', first, true, folderIds: {a});
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showVideoFolderPicker(
                context,
                source: 'test',
                item: first,
                store: store,
              ),
              child: const Text('编辑归类'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('编辑归类'));
    await tester.pumpAndSettle();
    expect(folderChecked(tester, '原分类'), isTrue);
    await tester.tap(folderRow('原分类'));
    await tester.tap(folderRow('新分类'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, t.common.save));
    await tester.pumpAndSettle();
    expect(
      (await store.read()).foldersOf(VideoLibraryStore.itemKey('test', '1')),
      {b},
    );
  });

  testWidgets(
    'batch picker cancellation keeps selection and new-folder save adds',
    (tester) async {
      final original = await store.createFolder('test', '原分类');
      await store.setFavorite('test', first, true, folderIds: {original});
      await show(tester);
      await tester.longPress(find.text(first.title));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.bookshelf.addToFolder));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, t.common.save),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip(t.common.close));
      await tester.pumpAndSettle();
      expect(find.text(t.videoLibrary.selectedCount(count: 1)), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        (await store.read()).foldersOf(VideoLibraryStore.itemKey('test', '1')),
        {original},
      );
      await tester.tap(find.text(t.bookshelf.addToFolder));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.videoLibrary.newFolder));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('video-folder.new-name')),
        '新建分类',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('video-folder.create')));
      await tester.pumpAndSettle();
      expect(folderChecked(tester, '新建分类'), isTrue);
      await tester.tap(find.widgetWithText(FilledButton, t.common.save));
      await tester.pumpAndSettle();
      final snapshot = await store.read();
      expect(snapshot.foldersOf(VideoLibraryStore.itemKey('test', '1')), {
        original,
        snapshot
            .foldersFor('test')
            .entries
            .singleWhere((e) => e.value.data['name'] == '新建分类')
            .key,
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed folder save keeps the panel and selection without a toast',
    (tester) async {
      store.dispose();
      store = _FailingFolderStore();
      final original = await store.createFolder('test', '原分类');
      await store.createFolder('test', '目标分类');
      await store.setFavorite('test', first, true, folderIds: {original});
      await show(tester);
      await tester.longPress(find.text(first.title));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.bookshelf.addToFolder));
      await tester.pumpAndSettle();
      await tester.tap(folderRow('目标分类'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, t.common.save));
      await tester.pumpAndSettle();
      expect(find.text(t.videoLibrary.saveFailed), findsOneWidget);
      expect(folderChecked(tester, '目标分类'), isTrue);
      expect(find.byType(SnackBar), findsNothing);
      await tester.tap(find.byTooltip(t.common.close));
      await tester.pumpAndSettle();
      expect(find.text(t.videoLibrary.selectedCount(count: 1)), findsOneWidget);
      expect(
        (await store.read()).foldersOf(VideoLibraryStore.itemKey('test', '1')),
        {original},
      );
    },
  );

  testWidgets(
    'local error leaves unrelated notices alone and closes on leaving',
    (tester) async {
      await store.createFolder('test', '重复分类');
      var active = true;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, set) {
                update = set;
                return favorites(active: active);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final messenger = ScaffoldMessenger.of(
        tester.element(find.byType(ApiVideoFavorites)),
      );
      for (final message in ['旧反馈一', '旧反馈二']) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(message),
            action: SnackBarAction(label: '操作', onPressed: () {}),
          ),
        );
      }
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, t.videoLibrary.all));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.videoLibrary.newFolder));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('video-folder.name')),
        '重复分类',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, t.common.save));
      await tester.pumpAndSettle();
      expect(find.text('旧反馈一'), findsOneWidget);
      expect(find.byType(VideoActionNotice), findsOneWidget);
      update(() => active = false);
      await tester.pumpAndSettle();
      expect(find.byType(VideoActionNotice), findsNothing);
      expect(find.text('旧反馈一'), findsOneWidget);
      messenger.removeCurrentSnackBar();
      await tester.pumpAndSettle();
      expect(find.text('旧反馈二'), findsOneWidget);
      messenger.clearSnackBars();
      messenger.removeCurrentSnackBar();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
