import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_diagnostic_preferences.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_favorites.dart';
import 'package:zephyr/page/video/api_video_library_page.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/omo_network.dart';
import 'package:zephyr/page/video/video_library_folder_picker.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_search_page.dart';
import 'package:zephyr/page/video/video_page_analysis.dart';

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
  testWidgets(
    'source capabilities remove unavailable controls and allow other root IDs',
    (tester) async {
      Map<String, dynamic>? request;
      final data = page('真实结构');
      (data['data'] as Map)['categories'] = [
        {'id': '7', 'parentId': '0', 'name': '独立根分类'},
      ];
      final repo = ApiVideoRepository(
        source: 'capability-test',
        home: home,
        catalogFn: 'list',
        detailFn: 'item',
        playbackFn: 'play',
        capabilities: const ApiVideoCapabilities(
          search: 'none',
          year: false,
          recent: false,
        ),
        pluginCall: (_, args) async {
          request = args;
          return data;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ApiVideoLibraryPage(repository: repo, title: '来源标题'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(VideoSearchEntry), findsNothing);
      expect(find.text('来源标题'), findsOneWidget);
      expect(find.text(t.videoLibrary.year), findsNothing);
      expect(find.text(t.videoLibrary.recent24Hours), findsNothing);
      expect(find.widgetWithText(ChoiceChip, '独立根分类'), findsOneWidget);
      expect(request?['clientProtocol'], 2);
      expect(tester.takeException(), isNull);
    },
  );

  test('protocol 1 sources retain their existing capabilities by default', () {
    final capabilities = ApiVideoCapabilities.fromJson({});
    expect(capabilities.canSearch, isTrue);
    expect(capabilities.year, isTrue);
    expect(capabilities.recent, isTrue);
  });

  testWidgets('iKun catalog remains readable when native network setup fails', (
    tester,
  ) async {
    const source = 'f5387e66-9c58-4b8f-beb7-22a939f79e5d';
    const channel = MethodChannel('breeze.video.network');
    final messenger = tester.binding.defaultBinaryMessenger;
    var opens = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'supported') return true;
      if (call.method == 'open') {
        opens++;
        throw PlatformException(code: 'configuration');
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final calls = <String>[];
    final repo = ApiVideoRepository(
      source: source,
      home: home,
      catalogFn: 'getLibrary',
      detailFn: 'getItem',
      playbackFn: 'getSession',
      pluginCall: (path, args) async {
        calls.add(path);
        expect(args, isNot(contains('networkContext')));
        return page('iKun 片库');
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ApiVideoLibraryPage(repository: repo, title: 'iKun'),
      ),
    );
    await tester.pumpAndSettle();
    expect(opens, 1);
    expect(calls, ['getLibrary']);
    expect(find.text('iKun 片库1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  test(
    'iKun catalog reads while its playback network is still opening',
    () async {
      const source = 'f5387e66-9c58-4b8f-beb7-22a939f79e5d';
      final network = Completer<OmoNetworkContext?>();
      final calls = <String>[];
      final repo = ApiVideoRepository(
        source: source,
        home: home,
        catalogFn: 'getLibrary',
        detailFn: 'getItem',
        playbackFn: 'getSession',
        network: network.future,
        pluginCall: (path, _) async {
          calls.add(path);
          return page('iKun 片库');
        },
      );
      final result = await repo.page().timeout(const Duration(seconds: 2));
      expect(result.items, hasLength(1));
      expect(network.isCompleted, isFalse);
      expect(calls, ['getLibrary']);
      network.completeError(PlatformException(code: 'configuration'));
      // Let the late opening error settle before a player starts listening.
      await Future<void>.delayed(Duration.zero);
      await expectLater(
        repo.session('1'),
        throwsA(
          isA<ApiVideoStageFailure>().having(
            (failure) => failure.stage,
            'stage',
            'network_session',
          ),
        ),
      );
      expect(calls, ['getLibrary']);
    },
  );

  test(
    'browser catalog still requires a usable native network session',
    () async {
      var calls = 0;
      final repo = ApiVideoRepository(
        source: omoNetworkSource,
        home: Uri.parse('https://www.omofuna.com/'),
        catalogFn: 'catalog',
        detailFn: 'item',
        playbackFn: 'play',
        capabilities: const ApiVideoCapabilities(browserCatalog: true),
        network: Future.error(PlatformException(code: 'configuration')),
        pluginCall: (_, _) async {
          calls++;
          return page('Omo 片库');
        },
      );
      await expectLater(
        repo.page(),
        throwsA(
          isA<ApiVideoStageFailure>().having(
            (failure) => failure.stage,
            'stage',
            'network_session',
          ),
        ),
      );
      expect(calls, 0);
    },
  );

  testWidgets(
    'empty favorites offer discovery and explicit import without dead tools',
    (tester) async {
      final store = VideoLibraryStore(
        deviceId: 'test',
        storageKey: 'empty-actions',
      );
      addTearDown(store.dispose);
      var discover = 0, imports = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ApiVideoFavorites(
              source: 'test',
              mode: ApiVideoView.grid,
              onOpen: (_) async {},
              store: store,
              onExplore: () => discover++,
              onImportSite: () => imports++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(find.text(t.videoLibrary.sort), findsNothing);
      expect(find.text(t.videoLibrary.syncLocalOnly), findsNothing);
      await tester.tap(find.text(t.videoSource.goDiscover));
      await tester.tap(find.text(t.videoSource.importFollows));
      expect(discover, 1);
      expect(imports, 1);
    },
  );
  testWidgets('diagnostic switch actually changes the API library menu', (
    tester,
  ) async {
    final repo = ApiVideoRepository(
      source: 'diagnostic-test',
      home: home,
      catalogFn: 'list',
      detailFn: 'item',
      playbackFn: 'play',
      pluginCall: (_, _) async => page('Title'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ApiVideoLibraryPage(repository: repo, title: 'iKun'),
      ),
    );
    await tester.pumpAndSettle();
    List<String> actions() => tester
        .widget<SourceMoreButton>(find.byType(SourceMoreButton))
        .actions
        .map((a) => a.id)
        .toList();
    expect(actions(), isNot(contains('analysis')));
    await SourceDiagnosticPreferences.setEnabled('diagnostic-test', true);
    await tester.pumpAndSettle();
    expect(actions(), contains('analysis'));
    await SourceDiagnosticPreferences.setEnabled('diagnostic-test', false);
    await tester.pumpAndSettle();
    expect(actions(), isNot(contains('analysis')));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'catalog identifies transport failure and retries the same catalog',
    (tester) async {
      var calls = 0;
      final repo = ApiVideoRepository(
        source: 'f5387e66-9c58-4b8f-beb7-22a939f79e5d',
        home: home,
        catalogFn: 'list',
        detailFn: 'item',
        playbackFn: 'play',
        pluginCall: (path, _) async {
          if (path != 'list') return {'data': item(1).toLibraryJson()};
          if (++calls == 1) {
            throw const SocketException('Connection reset by peer');
          }
          return page('Recovered item');
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ApiVideoLibraryPage(repository: repo, title: 'Source'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(t.login.networkUnavailable), findsOneWidget);
      await tester.tap(find.text(t.common.retry));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text(t.login.networkUnavailable), findsNothing);
      expect(find.text('Recovered item1'), findsOneWidget);
    },
  );

  testWidgets(
    'failed catalog diagnostics remain readable without another request',
    (tester) async {
      var calls = 0;
      final repo = ApiVideoRepository(
        source: 'offline-diagnostic-test',
        home: home,
        catalogFn: 'list',
        detailFn: 'item',
        playbackFn: 'play',
        pluginCall: (_, _) async {
          calls++;
          throw const FormatException(
            'offline token=secret-fixture password=private-fixture '
            'https://fixture.test/private?q=search-fixture',
          );
        },
      );
      await SourceDiagnosticPreferences.setEnabled(
        'offline-diagnostic-test',
        true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ApiVideoLibraryPage(repository: repo, title: 'Source'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(t.login.networkUnavailable), findsNothing);
      final previous = calls;
      tester
          .widget<SourceMoreButton>(find.byType(SourceMoreButton))
          .actions
          .firstWhere((action) => action.id == 'analysis')
          .onSelected();
      await tester.pumpAndSettle();
      final result = await tester
          .widget<VideoPageAnalysis>(find.byType(VideoPageAnalysis))
          .analyze();
      expect(calls, previous);
      expect(result.status, t.common.loadingFailed);
      expect(result.report, contains('items: 0'));
      expect(result.report, contains('Local state only'));
      expect(result.report, contains('stage=plugin_data'));
      expect(result.report, contains('type=FormatException'));
      expect(result.report, contains('reason=invalid_data'));
      for (final secret in [
        'secret-fixture',
        'private-fixture',
        'search-fixture',
        'fixture.test',
      ]) {
        expect(result.report, isNot(contains(secret)));
      }
      expect(tester.takeException(), isNull);
    },
  );

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
        if (path == 'list') calls.add(args);
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
    await tester.pumpWidget(tree(ApiVideoView.grid));
    await tester.pumpAndSettle();
    final returned = tester.getRect(find.byKey(const ValueKey('api-video.23')));
    expect(returned.bottom, greaterThan(0));
    expect(returned.top, lessThan(844));
    expect(tester.takeException(), isNull);
  });
  for (final headerHeight in [0.0, 640.0]) {
    testWidgets(
      'layout switching keeps the top and works below header $headerHeight',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const gridExtent = 300.0;
        const first = ValueKey('api-video.1');
        const anchor = ValueKey('api-video.7');
        const header = ValueKey('catalog-header');
        Widget tree(ApiVideoView mode) => MaterialApp(
          home: Scaffold(
            body: ApiVideoCollection(
              items: [for (var i = 1; i <= 60; i++) item(i)],
              mode: mode,
              onOpen: (_) {},
              storageKey: 'header-anchor',
              header: headerHeight == 0
                  ? null
                  : SizedBox(key: header, height: headerHeight),
              gridItemExtent: gridExtent,
            ),
          ),
        );
        await tester.pumpWidget(tree(ApiVideoView.grid));
        final scroll = tester
            .widget<CustomScrollView>(find.byType(CustomScrollView))
            .controller!;
        final topOffset = headerHeight == 0 ? 0.0 : 50.0;
        scroll.jumpTo(topOffset);
        await tester.pump();
        final top = find.byKey(headerHeight == 0 ? first : header);
        final before = tester.getTopLeft(top).dy;
        await tester.pumpWidget(tree(ApiVideoView.list));
        await tester.pumpAndSettle();
        expect(scroll.offset, closeTo(topOffset, 0.1));
        expect(tester.getTopLeft(top).dy, closeTo(before, 0.1));
        await tester.pumpWidget(tree(ApiVideoView.grid));
        await tester.pumpAndSettle();
        expect(scroll.offset, closeTo(topOffset, 0.1));

        scroll.jumpTo(headerHeight + 8 + 2 * gridExtent + 10);
        await tester.pump();
        final works = find.byKey(anchor);
        expect(tester.getTopLeft(works).dy, closeTo(-10, 0.1));
        await tester.pumpWidget(tree(ApiVideoView.list));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(works).dy, closeTo(0, 0.1));
        await tester.pumpWidget(tree(ApiVideoView.grid));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(works).dy, closeTo(0, 0.1));

        await tester.pumpWidget(tree(ApiVideoView.list));
        await tester.pumpWidget(tree(ApiVideoView.grid));
        final settledOffset = scroll.offset;
        await tester.pumpAndSettle();
        expect(scroll.offset, closeTo(settledOffset, 0.1));
        expect(tester.getTopLeft(works).dy, closeTo(0, 0.1));
        expect(tester.takeException(), isNull);
      },
    );
  }
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
            showFolders: true,
            onOpen: (_) async {},
            store: store,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.widgetWithText(TextButton, t.videoLibrary.all));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.videoLibrary.newFolder));
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
    await tester.tap(find.text(t.common.add));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, item(1).title));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, t.common.confirm));
    await tester.pumpAndSettle();
    final snapshot = await store.read();
    expect(snapshot.foldersOf(VideoLibraryStore.itemKey('test', '1')), {
      snapshot.foldersFor('test').keys.single,
    });
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
      find.byKey(const ValueKey('video-folder.new-name')),
      'Keyboard QA',
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: -60);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('video-folder.create')));
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
