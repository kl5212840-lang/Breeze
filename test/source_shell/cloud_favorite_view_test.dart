import 'dart:async';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comic_list/cubit/comic_list_cubit.dart';
import 'package:zephyr/page/comic_list/view/comic_list_page.dart';
import 'package:zephyr/page/comic_list/view/plugin_paged_comic_list_view.dart';
import 'package:zephyr/page/source_shell/source_list_view_toggle.dart';
import 'package:zephyr/page/source_shell/source_experience_preferences.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/src/rust/frb_generated.dart';

import 'package:zephyr/page/source_shell/view/jm_collection_toolbar.dart';
import 'package:zephyr/service/plugin_account_authentication.dart';

import 'package:zephyr/page/comic_list/view/jm_cloud_folder_controls.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry.dart';
import 'package:zephyr/widgets/comic_simplify_entry/cover.dart';

import '../test_helper.dart';

const _source = 'cloud-view-fixture';

class _CloudViewApi extends RustLibApi {
  bool management = false;
  bool bikaPaging = false;
  bool rejectMove = false;
  bool rejectName = false;
  bool loseReceipt = false;
  int filterReads = 0;
  Completer<void>? filterGate;
  final filterRefreshes = <bool>[];
  bool incompleteFolders = false;
  Completer<void>? nameGate;
  Map<String, dynamic>? nameFailure;
  final writes = <(String, Map<String, dynamic>)>[];
  final folders = <String, String>{};

  @override
  String crateApiQjsOpenccConvert({
    required String text,
    required String config,
  }) => text;

  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({
    required String name,
  }) async => true;

  @override
  Future<String> crateApiQjsQjsCurrentBundle({
    required String runtimeName,
  }) async => jsonEncode('fixture');

  @override
  Future<Uint8List> crateApiQjsQjsTaskCall({
    required String runtimeName,
    required String taskGroupKey,
    required bool isOnce,
    String? bundleJs,
    String? bundleUrl,
    required String fnPath,
    required String argsJson,
  }) async {
    Uint8List encode(Map<String, dynamic> value) =>
        Uint8List.fromList(utf8.encode(jsonEncode(value)));
    if (management && fnPath == 'getCloudFavoriteFilterBundle') {
      filterReads++;
      final explicit = (jsonDecode(argsJson) as Map)['refresh'] == true;
      filterRefreshes.add(explicit);
      final result = encode({
        'scheme': {
          'fields': [
            {
              'kind': 'choice',
              'key': 'folderId',
              'label': 'Folder',
              'options': [
                {'value': '', 'label': 'All'},
                for (final e in folders.entries.where(
                  (_) => !incompleteFolders,
                ))
                  {
                    'value': e.key,
                    'label': e.value,
                    'result': {
                      'extern': {'folderId': e.key},
                    },
                  },
              ],
            },
          ],
        },
        'data': {
          if (incompleteFolders) 'folderListVerified': false,
          'values': {'folderId': ''},
        },
      });
      if (!explicit) await filterGate?.future;
      return result;
    }
    if (management &&
        [
          'createFavoriteFolder',
          'moveFavoriteToFolder',
          'renameFavoriteFolder',
          'deleteFavoriteFolder',
        ].contains(fnPath)) {
      final args = jsonDecode(argsJson) as Map<String, dynamic>;
      writes.add((fnPath, args));
      final isName =
          fnPath == 'createFavoriteFolder' || fnPath == 'renameFavoriteFolder';
      if (isName && nameGate != null) await nameGate!.future;
      if (isName && nameFailure != null) {
        throw AnyhowException(
          'Error: ${jsonEncode(nameFailure)}\n    at fixture',
        );
      }
      if (isName && rejectName ||
          fnPath == 'moveFavoriteToFolder' && rejectMove)
        return encode({'ok': false});
      final id = args['folderId']?.toString() ?? '12';
      if (isName) {
        folders[id] = args['folderName'] as String;
      } else if (fnPath == 'deleteFavoriteFolder') {
        folders.remove(id);
      }
      if (isName && loseReceipt) return encode({'ok': false});
      return encode({
        'ok': true,
        if (isName) 'folder': {'id': id, 'name': folders[id]},
        if (fnPath != 'moveFavoriteToFolder')
          'folders': [
            for (final e in folders.entries) {'id': e.key, 'name': e.value},
          ],
      });
    }
    final source = management
        ? PluginAccountAuthenticationService.jm
        : bikaPaging
        ? bikaPlusSourceId
        : _source;
    final data = switch (fnPath) {
      'init' => {'ok': true},
      'getCloudFavoriteSceneBundle' => {
        'source': source,
        if (management) 'cloudFavoriteFolderManagement': true,
        if (management) 'filter': {'fnPath': 'getCloudFavoriteFilterBundle'},
        'title': '云端收藏',
        'list': {
          'fnPath': bikaPaging ? 'getFavoriteData' : 'getCloudFavoriteData',
          'extern': {'source': 'cloudFavorite', if (bikaPaging) 'sort': 'dd'},
        },
      },
      'getCloudFavoriteData' || 'getFavoriteData' => {
        if (bikaPaging) 'paging': {'page': 1, 'pages': 29, 'total': 579},
        'items': [
          {
            'source': source,
            'id': 'first',
            'title': 'Cloud work',
            'cover': {'id': 'first', 'url': '', 'path': '', 'extern': {}},
            'metadata': [],
          },
        ],
        if (!bikaPaging) 'hasReachedMax': true,
      },
      _ => throw StateError('Unexpected fixture call $fnPath'),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode({'data': data})));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected API ${invocation.memberName}');
}

void main() {
  final api = _CloudViewApi();
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    RustLib.initMock(api: api);
  });
  tearDownAll(() async {
    RustLib.dispose();
    await TestObjectBoxHelper.tearDownTestObjectBox();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api.management = false;
    api.bikaPaging = false;
    api.rejectMove = false;
    api.rejectName = false;
    api.loseReceipt = false;
    api.filterReads = 0;
    api.filterGate = null;
    api.filterRefreshes.clear();
    api.incompleteFolders = false;
    api.nameGate = null;
    api.nameFailure = null;
    api.writes.clear();
    api.folders.clear();
  });

  testWidgets('cloud favorite entry point defaults to detailed view', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ComicListPage(
          title: '云端收藏',
          sceneSource: _source,
          sceneBundleFnPath: 'getCloudFavoriteSceneBundle',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final toggle = find.byKey(const ValueKey('jm-cloud-view'));
    final grid = find.descendant(
      of: toggle,
      matching: find.byTooltip(t.comicList.switchToGrid),
    );
    expect(tester.widget<SourceListViewToggle>(toggle).detailed, isTrue);
    expect(grid.hitTestable(), findsOneWidget);
    final records = find.byType(PluginPagedComicListView);
    expect(
      tester.widget<PluginPagedComicListView>(records).detailedView,
      isTrue,
    );
    expect(find.text('Cloud work'), findsOneWidget);

    await tester.tap(grid);
    await tester.pump();
    expect(tester.widget<SourceListViewToggle>(toggle).detailed, isFalse);
    expect(
      tester.widget<PluginPagedComicListView>(records).detailedView,
      isFalse,
    );
    expect(
      find.byTooltip(t.comicList.switchToList).hitTestable(),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 2));
  });

  for (final (width, scale) in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets('Bika verified page and count fit toolbar at $width / $scale', (
      tester,
    ) async {
      api.bikaPaging = true;
      tester.view.physicalSize = Size(width, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const ComicListPage(
            title: '云端收藏',
            sceneSource: bikaPlusSourceId,
            sceneBundleFnPath: 'getCloudFavoriteSceneBundle',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('plugin-list.page-progress'));
      final count = find.byKey(const ValueKey('plugin-list.numbered-count'));
      expect(
        find.text(t.searchResult.pageProgress(page: 1, pages: 29)),
        findsOneWidget,
      );
      expect(find.text('1/579'), findsOneWidget);
      expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
      if (scale == 1) {
        expect(
          tester.getCenter(count).dy,
          closeTo(tester.getCenter(button).dy, 4),
        );
      } else {
        expect(tester.getRect(count).overlaps(tester.getRect(button)), isFalse);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'cloud list search replaces its route title and retains query on close',
    (tester) async {
      api.bikaPaging = true;
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (_) async => null,
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          null,
        ),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: ComicListPage(
            title: '云端收藏',
            sceneSource: bikaPlusSourceId,
            sceneBundleFnPath: 'getCloudFavoriteSceneBundle',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final appBar = find.byType(AppBar);
      final search = find.byKey(const ValueKey('jm-collection.search'));
      final input = find.byKey(const ValueKey('source-loaded.search'));
      final view = find.byKey(const ValueKey('jm-cloud-view'));
      final toolbarY = tester.getTopLeft(view).dy;
      final titleBox = tester.getRect(appBar);
      Future<void> openSearch() async {
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          tester.widget<SourceChromeIconButton>(search).onPressed!();
        } else {
          await tester.tap(search);
        }
        await tester.pumpAndSettle();
      }

      expect(search, findsOneWidget);
      await openSearch();
      expect(tester.takeException(), isNull);
      expect(find.descendant(of: appBar, matching: input), findsOneWidget);
      expect(tester.getRect(appBar), titleBox);
      expect(tester.getTopLeft(view).dy, toolbarY);
      expect(tester.widget<TextField>(input).focusNode?.hasFocus, isTrue);
      await tester.enterText(input, 'impossible query');
      await tester.pumpAndSettle();
      final close = find.byTooltip(t.common.close);
      expect(close, findsOneWidget);
      expect(find.byTooltip(t.common.clear), findsOneWidget);
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(input, findsNothing);
      expect(tester.getTopLeft(view).dy, toolbarY);
      await openSearch();
      expect(
        tester.widget<TextField>(input).controller?.text,
        'impossible query',
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'JM selection retains checked work through create and failed move, retries once and cancels locally',
    (tester) async {
      api.management = true;
      addTearDown(() => api.management = false);
      await tester.pumpWidget(
        const MaterialApp(
          home: ComicListPage(
            title: 'JM',
            sceneSource: PluginAccountAuthenticationService.jm,
            sceneBundleFnPath: 'getCloudFavoriteSceneBundle',
          ),
        ),
      );
      await tester.pumpAndSettle();
      void select() => tester
          .widget<JmCollectionNavigationActions>(
            find.byType(JmCollectionNavigationActions),
          )
          .onSelected('cloud-folder.select');
      select();
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Cloud work')),
        containsSemantics(
          label: 'Cloud work',
          hasCheckedState: true,
          isChecked: false,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, t.bookshelf.addToFolder),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(find.text(t.videoLibrary.selectedCount(count: 1)), findsOneWidget);
      await tester.tap(find.text(t.bookshelf.createFolder));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('video-folder.name')),
        'Weekend',
      );
      await tester.pump();
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, t.common.save))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text(t.common.save));
      await tester.pumpAndSettle();
      expect(api.writes.single.$1, 'createFavoriteFolder');
      expect(api.writes.single.$2.containsKey('comicIds'), isFalse);
      expect(find.text(t.videoLibrary.selectedCount(count: 1)), findsOneWidget);
      Future<void> move() async {
        await tester.tap(find.text(t.bookshelf.addToFolder));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, 'Weekend'));
        await tester.pumpAndSettle();
      }

      api.rejectMove = true;
      await move();
      expect(find.text(t.videoLibrary.selectedCount(count: 1)), findsOneWidget);
      expect(find.text(t.sourceProfile.jmFolderUnconfirmed), findsOneWidget);
      api.rejectMove = false;
      await move();
      expect(api.writes.map((w) => w.$1), [
        'createFavoriteFolder',
        'moveFavoriteToFolder',
        'moveFavoriteToFolder',
      ]);
      expect(api.writes.last.$2['comicIds'], ['first']);
      expect(api.writes.last.$2['folderId'], '12');
      expect(find.text(t.bookshelf.cancelSelect), findsNothing);
      select();
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.bookshelf.cancelSelect));
      await tester.pumpAndSettle();
      expect(api.writes.length, 3);
      await tester.tap(find.byTooltip(t.comicList.switchToGrid));
      await tester.pumpAndSettle();
      select();
      await tester.pumpAndSettle();
      final gridEntry = find.byType(ComicSimplifyEntry);
      await tester.tap(gridEntry.first);
      await tester.pumpAndSettle();
      expect(
        tester.widget<ComicSimplifyEntry>(gridEntry.first).isSelected,
        isTrue,
      );
      await tester.tap(find.text(t.bookshelf.cancelSelect));
      await tester.pumpAndSettle();
      final folder = find.byKey(const ValueKey('cloud-favorite.folder'));
      await tester.tap(folder);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('jm-folder.open.12')));
      await tester.pumpAndSettle();
      void edit(String operation) => tester
          .widget<JmCollectionNavigationActions>(
            find.byType(JmCollectionNavigationActions),
          )
          .onSelected('cloud-folder.$operation');
      edit('rename');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('video-folder.name')),
        'Archive',
      );
      await tester.pump();
      await tester.tap(find.text(t.common.save));
      await tester.pumpAndSettle();
      expect(tester.widget<JmCloudFolderButton>(folder).label, 'Archive');
      edit('delete');
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.common.cancel));
      await tester.pumpAndSettle();
      expect(api.writes.length, 4);
      edit('delete');
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.common.delete));
      await tester.pumpAndSettle();
      expect(api.writes.last.$1, 'deleteFavoriteFolder');
      expect(tester.widget<JmCloudFolderButton>(folder).label, 'All');
      expect(
        tester
            .widget<JmCollectionNavigationActions>(
              find.byType(JmCollectionNavigationActions),
            )
            .options
            .containsKey('cloud-folder.delete'),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'creating from Join keeps the draft on failure and returns directly to destination choices',
    (tester) async {
      api.management = true;
      api.folders['9'] = 'Existing';
      await tester.pumpWidget(
        const MaterialApp(
          home: ComicListPage(
            sceneSource: PluginAccountAuthenticationService.jm,
            sceneBundleFnPath: 'getCloudFavoriteSceneBundle',
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester
          .widget<JmCollectionNavigationActions>(
            find.byType(JmCollectionNavigationActions),
          )
          .onSelected('cloud-folder.select');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.bookshelf.addToFolder));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, t.bookshelf.createFolder));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('video-folder.name'));
      await tester.enterText(field, 'Unread');
      await tester.pump();
      api.rejectName = true;
      await tester.tap(find.text(t.common.save));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, 'Unread');
      expect(find.text(t.sourceProfile.jmFolderUnconfirmed), findsOneWidget);
      final reads = api.filterReads;
      api.rejectName = false;
      await tester.tap(find.text(t.common.save));
      await tester.pumpAndSettle();
      expect(api.filterReads, reads);
      expect(find.widgetWithText(ListTile, 'Unread'), findsOneWidget);
      expect(api.writes.every((w) => w.$1 == 'createFavoriteFolder'), isTrue);
      expect(
        tester.getTopLeft(find.text('Unread')).dy,
        lessThan(tester.getTopLeft(find.text('Existing')).dy),
      );
      await tester.tap(find.widgetWithText(ListTile, 'Unread'));
      await tester.pumpAndSettle();
      expect(api.writes.last.$1, 'moveFavoriteToFolder');
      expect(api.writes.last.$2['folderId'], '12');
      await tester.tap(find.text(t.videoLibrary.viewFolder));
      await tester.pumpAndSettle();
      final scope = find.byKey(const ValueKey('cloud-favorite.folder'));
      expect(tester.widget<JmCloudFolderButton>(scope).label, 'Unread');
      api.incompleteFolders = true;
      tester
          .widget<JmCollectionNavigationActions>(
            find.byType(JmCollectionNavigationActions),
          )
          .onSelected('cloud-folder.refresh');
      await tester.pumpAndSettle();
      expect(tester.widget<JmCloudFolderButton>(scope).label, 'Unread');
      api.incompleteFolders = false;
      api.folders.remove('12');
      tester
          .widget<JmCollectionNavigationActions>(
            find.byType(JmCollectionNavigationActions),
          )
          .onSelected('cloud-folder.refresh');
      await tester.pumpAndSettle();
      expect(tester.widget<JmCloudFolderButton>(scope).label, 'All');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'folder manager refresh shows the new directory before an older read finishes',
    (tester) async {
      api.management = true;
      api.folders['9'] = 'Original';
      await tester.pumpWidget(
        const MaterialApp(
          home: ComicListPage(
            sceneSource: PluginAccountAuthenticationService.jm,
            sceneBundleFnPath: 'getCloudFavoriteSceneBundle',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scope = find.byKey(const ValueKey('cloud-favorite.folder'));
      final cubit = tester.element(scope).read<ComicListCubit>();
      await tester.tap(scope);
      await tester.pumpAndSettle();
      expect(find.text('Original'), findsOneWidget);

      final old = api.filterGate = Completer<void>();
      final pending = cubit.loadFilter();
      try {
        await tester.pump();
        expect(api.filterRefreshes, [false, false]);
        api.folders['9'] = 'Renamed on another device';
        await tester.tap(find.byTooltip(t.sourceProfile.jmRefreshFolders));
        await tester.pump();
        expect(api.filterRefreshes, [false, false, true]);
        expect(find.text('Renamed on another device'), findsOneWidget);
      } finally {
        old.complete();
        await pending;
      }
      await tester.pumpAndSettle();
      expect(find.text('Renamed on another device'), findsOneWidget);
      expect(find.text('Original'), findsNothing);
      expect(find.text(t.common.refreshChecked), findsOneWidget);
      expect(api.writes, isEmpty);
    },
  );

  testWidgets('a rejected create gives the verified cap without another read', (
    tester,
  ) async {
    api.management = true;
    await tester.pumpWidget(
      const MaterialApp(
        home: ComicListPage(
          sceneSource: PluginAccountAuthenticationService.jm,
          sceneBundleFnPath: 'getCloudFavoriteSceneBundle',
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester
        .widget<JmCollectionNavigationActions>(
          find.byType(JmCollectionNavigationActions),
        )
        .onSelected('cloud-folder.create');
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('video-folder.name'));
    await tester.enterText(field, 'Draft');
    await tester.pump();
    final reads = api.filterReads;
    api.nameFailure = {
      'type': 'jm_folder_change',
      'phase': 'rejected',
      'reason': 'limit',
      'folderCount': 10,
    };
    await tester.tap(find.text(t.common.save));
    await tester.pumpAndSettle();
    expect(find.text(t.sourceProfile.jmFolderLimitDetail(count: 10)), findsOne);
    expect(tester.widget<TextField>(field).controller!.text, 'Draft');
    expect(api.filterReads, reads);

    api.nameFailure = {
      'type': 'jm_folder_change',
      'phase': 'notSubmitted',
      'reason': 'unavailable',
    };
    await tester.tap(find.text(t.common.save));
    await tester.pumpAndSettle();
    expect(find.text(t.videoLibrary.saveFailed), findsOne);
    expect(
      find.text(t.sourceProfile.jmFolderLimitDetail(count: 10)),
      findsNothing,
    );
    expect(api.filterReads, reads);
  });

  testWidgets(
    'a pending folder rename cannot be submitted twice or leak after an account change',
    (tester) async {
      api.management = true;
      api.folders['12'] = 'Original';
      await tester.pumpWidget(
        const MaterialApp(
          home: ComicListPage(
            sceneSource: PluginAccountAuthenticationService.jm,
            sceneBundleFnPath: 'getCloudFavoriteSceneBundle',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scope = find.byKey(const ValueKey('cloud-favorite.folder'));
      await tester.tap(scope);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('jm-folder.open.12')));
      await tester.pumpAndSettle();
      tester
          .widget<JmCollectionNavigationActions>(
            find.byType(JmCollectionNavigationActions),
          )
          .onSelected('cloud-folder.rename');
      await tester.pumpAndSettle();
      final editor = find.byKey(const ValueKey('video-folder.name'));
      await tester.enterText(editor, 'Draft name');
      await tester.pump();
      api.rejectName = true;
      await tester.tap(find.text(t.common.save));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(editor).controller!.text, 'Draft name');
      expect(tester.widget<JmCloudFolderButton>(scope).label, 'Original');
      api.nameGate = Completer<void>();
      final submit = tester.widget<TextField>(editor).onSubmitted!;
      submit('Draft name');
      submit('Draft name');
      await tester.pump();
      expect(tester.widget<TextField>(editor).readOnly, isTrue);
      expect(api.writes, hasLength(2));
      final source = PluginAccountAuthenticationService.jm;
      final generation = pluginSessionWriteFence.beginSessionChange(source);
      await tester.pump();
      await tester.pump();
      expect(editor, findsNothing);
      api.nameGate!.complete();
      pluginSessionWriteFence.seal(source, generation);
      await tester.pumpAndSettle();
      expect(find.text('Draft name'), findsNothing);
      expect(find.text(t.sourceProfile.jmFolderRenamed), findsNothing);
      expect(api.writes, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'JM folder management keeps long lists scrollable without search',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JmCloudFolderManager(
              options: () => {
                '0': 'All',
                for (var index = 1; index <= 20; index++)
                  '$index': 'Fixture folder $index',
              },
              currentId: () => '0',
              onAction: (_, _, _) async {},
            ),
          ),
        ),
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.text(t.bookshelf.createFolder), findsOneWidget);
      final list = find.byType(CustomScrollView);
      await tester.scrollUntilVisible(
        find.text('Fixture folder 20'),
        200,
        scrollable: find.descendant(
          of: list,
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Fixture folder 20').hitTestable(), findsOneWidget);
    },
  );

  testWidgets(
    'an empty cloud folder picker can create, reconcile a lost receipt, and edit without switching collections',
    (tester) async {
      tester.view.physicalSize = const Size(360, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      api.management = true;
      await tester.pumpWidget(
        const MaterialApp(
          home: ComicListPage(
            sceneSource: PluginAccountAuthenticationService.jm,
            sceneBundleFnPath: 'getCloudFavoriteSceneBundle',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scope = find.byKey(const ValueKey('cloud-favorite.folder'));
      await tester.tap(scope);
      await tester.pumpAndSettle();
      expect(find.text(t.videoSource.manageFolders), findsOneWidget);
      expect(find.byKey(const ValueKey('jm-folder.edit.')), findsNothing);
      await tester.tap(
        find.widgetWithText(FilledButton, t.bookshelf.createFolder),
      );
      await tester.pumpAndSettle();
      final input = find.byKey(const ValueKey('video-folder.name'));
      await tester.enterText(input, 'Reading');
      await tester.pump();
      api.loseReceipt = true;
      await tester.tap(find.text(t.common.save));
      await tester.pumpAndSettle();
      expect(
        find.text(t.sourceProfile.jmFolderAvailable(name: 'Reading')),
        findsOneWidget,
      );
      expect(input, findsNothing);
      expect(api.writes, hasLength(1));
      expect(tester.widget<JmCloudFolderButton>(scope).label, 'All');
      final rowMenu = find.byKey(const ValueKey('jm-folder.edit.12'));
      api.loseReceipt = false;
      await tester.tap(rowMenu);
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.bookshelf.renameFolder));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(input).controller!.text, 'Reading');
      await tester.enterText(input, 'Weekend');
      await tester.pump();
      await tester.tap(find.text(t.common.save));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Weekend'), findsOneWidget);
      expect(api.writes.last.$2['folderId'], '12');
      await tester.tap(rowMenu);
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.videoLibrary.deleteFolder));
      await tester.pumpAndSettle();
      expect(
        find.text(t.sourceProfile.jmDeleteFolder(name: 'Weekend')),
        findsOneWidget,
      );
      await tester.tap(find.text(t.common.cancel));
      await tester.pumpAndSettle();
      expect(api.writes, hasLength(2));
      await tester.tap(find.byKey(const ValueKey('jm-folder.open.12')));
      await tester.pumpAndSettle();
      expect(tester.widget<JmCloudFolderButton>(scope).label, 'Weekend');
      final folderIcon = find.descendant(
        of: scope,
        matching: find.byIcon(Icons.folder_outlined),
      );
      expect(
        tester.getTopLeft(folderIcon).dx,
        tester.getTopLeft(find.byType(CoverWidget).first).dx,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
