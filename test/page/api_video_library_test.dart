import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_favorites.dart';
import 'package:zephyr/page/video/api_video_library_page.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/video_library_folder_picker.dart';
import 'package:zephyr/page/video/video_library_store.dart';

final home = Uri.parse('https://www.ikunzy.com/');
ApiVideoItem item(int id) => ApiVideoItem(
  id: '$id',
  title: '作品$id 长标题用于检查换行',
  detailUrl: home.resolve('voddetail/$id.html'),
  description: '这是一段用于判断内容的真实资料结构示例，测试排版与状态而不证明站点播放。',
  typeName: '科幻片',
  year: '2014',
  area: '美国',
  remarks: '正片',
  sourceViews: 1234,
);
Map<String, dynamic> page(String title, {int count = 1}) => {
  'data': {
    'page': 1,
    'pageCount': 1,
    'total': count,
    'items': [
      for (var i = 1; i <= count; i++)
        {...item(i).toLibraryJson(), 'title': '$title$i'},
    ],
    'categories': [
      {'id': '1', 'parentId': '0', 'name': '电影'},
      {'id': '4', 'parentId': '0', 'name': '动漫'},
      {'id': '37', 'parentId': '4', 'name': '日本动漫'},
    ],
  },
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('late category response cannot replace a newer selection', (
    tester,
  ) async {
    final slow = Completer<Map<String, dynamic>>();
    final calls = <Map<String, dynamic>>[];
    final repo = ApiVideoRepository(
      source: 'test',
      home: home,
      catalogFn: 'list',
      detailFn: 'item',
      playbackFn: 'play',
      pluginCall: (path, args) async {
        calls.add(args);
        if (args['typeId'] == '1') return slow.future;
        return page(args['typeId'] == '4' ? '动漫结果' : '初始结果');
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ApiVideoLibraryPage(repository: repo, title: 'iKun'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '电影'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, '动漫'));
    await tester.pumpAndSettle();
    expect(find.text('动漫结果1'), findsOneWidget);
    slow.complete(page('迟到结果'));
    await tester.pumpAndSettle();
    expect(find.text('动漫结果1'), findsOneWidget);
    expect(find.text('迟到结果1'), findsNothing);
    expect(calls.map((e) => e['typeId']), ['', '1', '4']);
  });
  testWidgets('grid and list preserve the visible title when switching', (
    tester,
  ) async {
    tester.view.resetPhysicalSize();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Widget tree(ApiVideoView mode) => MaterialApp(
      home: Scaffold(
        body: ApiVideoCollection(
          key: const ValueKey('collection'),
          items: [for (var i = 1; i <= 60; i++) item(i)],
          mode: mode,
          onOpen: (_) {},
          storageKey: 'anchor',
        ),
      ),
    );
    await tester.pumpWidget(tree(ApiVideoView.grid));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('api-video.23')),
      350,
      scrollable: find.byType(Scrollable),
    );
    final scroll = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    final before = scroll.offset;
    await tester.pumpWidget(tree(ApiVideoView.list));
    await tester.pumpAndSettle();
    expect(scroll.offset, isNot(before));
    final rect = tester.getRect(find.byKey(const ValueKey('api-video.23')));
    expect(rect.bottom, greaterThan(0));
    expect(rect.top, lessThan(844));
    expect(tester.takeException(), isNull);
  });
  testWidgets('small phone large text fits both views and favorites controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = VideoLibraryStore(deviceId: 'test', storageKey: 'widgets');
    addTearDown(store.dispose);
    await store.setFavorite('test', item(1), true);
    Widget tree(Widget child) => MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
        child: child!,
      ),
      home: Scaffold(body: child),
    );
    for (final mode in ApiVideoView.values) {
      await tester.pumpWidget(
        tree(
          ApiVideoFavorites(
            source: 'test',
            mode: mode,
            onOpen: (_) async {},
            store: store,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byTooltip(t.videoLibrary.newFolder));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('video-folder.name')),
      '科幻',
    );
    await tester.pump();
    await tester.tap(find.text(t.common.save));
    await tester.pumpAndSettle();
    expect(
      (await store.read()).foldersFor('test').values.single.data['name'],
      '科幻',
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(TextField).first);
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('folder picker dismissal consumes tap and can be reopened', (
    tester,
  ) async {
    final store = VideoLibraryStore(deviceId: 'test', storageKey: 'picker');
    addTearDown(store.dispose);
    await store.createFolder('test', '精选');
    var background = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () => showVideoFolderPicker(
                    context,
                    source: 'test',
                    item: item(1),
                    store: store,
                  ),
                  child: const Text('Open'),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => background++,
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text(t.videoLibrary.chooseFolders), findsOneWidget);
      await tester.tapAt(const Offset(5, 100));
      await tester.pumpAndSettle();
      expect(find.text(t.videoLibrary.chooseFolders), findsNothing);
      expect(background, 0);
    }
  });
  testWidgets('folder creation tolerates a transient negative keyboard inset', (
    tester,
  ) async {
    final store = VideoLibraryStore(deviceId: 'test', storageKey: 'keyboard');
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showVideoFolderPicker(
                context,
                source: 'test',
                item: item(1),
                store: store,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.videoLibrary.newFolder));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('video-folder.name')),
      'Keyboard QA',
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: -60);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, t.common.save));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, t.common.save));
    await tester.pumpAndSettle();
    final snapshot = await store.read();
    expect(snapshot.contains('test', '1'), isTrue);
    expect(
      snapshot.foldersOf(VideoLibraryStore.itemKey('test', '1')),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });
}
