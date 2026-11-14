import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:zephyr/page/bookshelf/service/shelf_facet_adapters.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worker_manager/worker_manager.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/bookshelf/bloc/folder_shelf_bloc.dart';
import 'package:zephyr/page/bookshelf/cubit/bookshelf_search_cubit.dart';
import 'package:zephyr/page/bookshelf/cubit/search_status.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/bookshelf/service/comic_folder_service.dart';
import 'package:zephyr/page/bookshelf/service/comic_link_service.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_content_toolbar.dart';
import 'package:zephyr/page/bookshelf/widgets/folder_shelf_page.dart';
import 'package:zephyr/page/bookshelf/widgets/folder_shelf_item.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

import '../test_helper.dart';
import '../download_fixture.dart';

const _source = 'third-party.alpha';
const _other = 'another-vendor';
const _type = ComicFolderType.favorite;
String _key(String id, [String source = _source]) => '$source:$id';

const _red = ShelfFacetSelection(
  values: {
    'tags': {'red'},
  },
);
const _redDescendants = ShelfFacetSelection(
  scope: ShelfFacetScope.descendants,
  values: {
    'tags': {'red'},
  },
);
const _redAll = ShelfFacetSelection(
  scope: ShelfFacetScope.all,
  values: {
    'tags': {'red'},
  },
);

void _seed() {
  ComicFolderService.createFolder('', 'A', _type);
  ComicFolderService.createFolder('/A', 'child', _type);
  ComicFolderService.createFolder('', 'B', _type);
  ComicFolderService.createFolder('', 'C', _type);
  void comic(
    String id,
    String title,
    Set<String> paths, {
    String source = _source,
    String? tag,
    String? year,
  }) {
    final row = createTestFavorite(_key(id, source))
      ..source = source
      ..comicId = id
      ..title = title
      ..metadata = jsonEncode([
        if (tag != null)
          {
            'type': 'tag',
            'value': [
              {'name': tag},
            ],
          },
        if (year != null) {'type': 'year', 'value': year},
      ]);
    objectbox.unifiedFavoriteBox.put(row);
    for (final path in paths) {
      ComicLinkService.addComic(
        row.uniqueKey,
        path.isEmpty ? null : path,
        _type,
      );
    }
  }

  comic('root', 'Root red', {''}, tag: 'red', year: '2024');
  comic(
    'shared',
    'Needle shared',
    {'/A', '/A/child', '/B'},
    tag: 'red',
    year: '2024',
  );
  comic('child', 'Needle child', {'/A/child'}, tag: 'red', year: '2023');
  comic('blue', 'Needle blue', {'/B'}, tag: 'blue', year: '2024');
  comic('unknown', 'Needle no metadata', {'/A'});
  comic(
    'vendor',
    'Needle other vendor',
    {'/A'},
    source: _other,
    tag: 'red',
    year: '2024',
  );
}

Set<String> _visible(FolderShelfBloc bloc) => {
  for (final comic in bloc.state.comics) '${comic.from.trim()}:${comic.id}',
};

Set<String> _paths(String key) {
  final folders = {
    for (final folder in ComicFolderService.listAllFolders(_type))
      folder.syncId: folder,
  };
  return {
    for (final link in ComicLinkService.linksOfComic(key, _type))
      if (link.folderSyncId == null)
        ''
      else
        ComicFolderService.folderPath(
          folders[link.folderSyncId]!,
          syncIdMap: folders,
        ),
  };
}

bool _deleted(String key) => objectbox.unifiedFavoriteBox
    .getAll()
    .singleWhere((row) => row.uniqueKey == key)
    .deleted;

Future<void> _loadAfter(FolderShelfBloc bloc, FolderShelfEvent event) async {
  var sawLoading = false;
  final complete = bloc.stream
      .firstWhere((state) {
        sawLoading = sawLoading || state.isLoading;
        return sawLoading && !state.isLoading;
      })
      .timeout(const Duration(seconds: 20));
  bloc.add(event);
  await complete;
  expect(bloc.state.error, isNull);
}

Future<void> _select(FolderShelfBloc bloc, String key) async {
  final complete = bloc.stream
      .firstWhere((state) => state.selectedComicKeys.contains(key))
      .timeout(const Duration(seconds: 5));
  bloc.add(FolderShelfToggleComicSelection(key));
  await complete;
}

Future<void> _resetComicFilter(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('comic-shelf.filter')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('shelf-filter-reset')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('shelf-filter-apply')));
}

void main() {
  test(
    'copy rejects a vanished destination without copying to other paths',
    () {
      final snapshot = loadComicShelfFacetIndex(type: _type);
      ComicFolderService.deleteFolder('/C', _type);
      var rejected = false;
      try {
        copyComicFromFacetIndex(
          _key('child'),
          {'/B', '/C'},
          snapshot: snapshot,
          type: _type,
        );
      } on StateError {
        rejected = true;
      }
      expect(_paths(_key('child')), {'/A/child'});
      expect(rejected, isTrue);
    },
  );

  test(
    'a failed multi-destination folder copy rolls back the valid target',
    () async {
      final bloc = FolderShelfBloc(mode: ShelfPageMode.favorite);
      addTearDown(bloc.close);
      await _loadAfter(bloc, const FolderShelfLoadRequested());
      final selected = bloc.stream.firstWhere(
        (state) => state.selectedFolderPaths.contains('/A'),
      );
      bloc.add(const FolderShelfToggleFolderSelection('/A'));
      await selected.timeout(const Duration(seconds: 5));
      ComicFolderService.deleteFolder('/C', _type);
      final failed = bloc.stream.firstWhere((state) => state.error != null);
      bloc.add(const FolderShelfCopySelected({'/B', '/C'}));
      final state = await failed.timeout(const Duration(seconds: 5));
      expect(state.error, t.bookshelf.moveTargetUnavailable);
      expect(ComicFolderService.folderSyncIdByPath('/B/A', _type), isNull);
      expect(ComicFolderService.folderSyncIdByPath('/A', _type), isNotNull);
    },
  );

  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const connectivity = MethodChannel('dev.fluttercommunity.plus/connectivity');
  const changes = MethodChannel(
    'dev.fluttercommunity.plus/connectivity_status',
  );
  setUpAll(() async {
    messenger.setMockMethodCallHandler(connectivity, (_) async => ['wifi']);
    messenger.setMockMethodCallHandler(changes, (_) async => null);
    await TestObjectBoxHelper.setUpTestObjectBox();
    debugShelfDbRootPath = TestObjectBoxHelper.tempPath;
    await workerManager.init(isolatesCount: 1);
  });
  tearDownAll(() async {
    await workerManager.dispose();
    debugShelfDbRootPath = null;
    await TestObjectBoxHelper.tearDownTestObjectBox();
    messenger.setMockMethodCallHandler(connectivity, null);
    messenger.setMockMethodCallHandler(changes, null);
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _seed();
  });
  tearDown(TestObjectBoxHelper.cleanComicFolderBoxes);

  for (final (path, selection, action) in [
    ('', _redAll, 'copy'),
    ('/A', _redDescendants, 'move'),
  ]) {
    testWidgets('filtered $action can target the current directory $path', (
      tester,
    ) async {
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      final search = BookshelfSearchCubit(
        favorite: const SearchStatusState(sources: [_source]),
      );
      addTearDown(search.close);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<GlobalSettingCubit>(
              create: (_) => GlobalSettingCubit(),
            ),
            BlocProvider<BookshelfSearchCubit>.value(value: search),
          ],
          child: AppInterfaceStyleScope(
            style: style,
            child: MaterialApp(
              home: const Scaffold(
                body: FolderShelfPage(
                  mode: ShelfPageMode.favorite,
                  sourceNames: {_source: 'Third party'},
                ),
              ),
            ),
          ),
        ),
      );
      Future<void> wait(bool Function() ready) async {
        for (var i = 0; i < 150; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          await tester.pump();
          if (ready()) return;
        }
        fail('filtered folder host did not reach expected state');
      }

      late FolderShelfBloc bloc;
      await wait(() {
        final toolbar = find.byType(BookshelfContentToolbar);
        if (toolbar.evaluate().isEmpty) return false;
        bloc = tester.element(toolbar).read<FolderShelfBloc>();
        return !bloc.state.isLoading;
      });
      if (path.isNotEmpty) {
        bloc.add(FolderShelfEnterFolder(path));
        await wait(
          () => !bloc.state.isLoading && bloc.state.currentPath == path,
        );
      }
      bloc.add(FolderShelfSetFacets(selection));
      await wait(
        () =>
            !bloc.state.isLoading &&
            bloc.state.facets == selection &&
            _visible(bloc).contains(_key('child')),
      );
      bloc.add(FolderShelfToggleComicSelection(_key('child')));
      await wait(() => bloc.state.selectedComicKeys.contains(_key('child')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(ValueKey('comic-shelf.$action')));
      await tester.pumpAndSettle();
      final destination = find.byKey(ValueKey('shelf-folder.$path'));
      expect(tester.widget<ListTile>(destination).onTap, isNotNull);
      await tester.tap(destination);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('shelf-folder.confirm')));
      await wait(
        () =>
            !bloc.state.isLoading &&
            !bloc.state.selectionMode &&
            _paths(_key('child')).contains(path),
      );
      expect(
        _paths(_key('child')),
        action == 'copy' ? {'/A/child', ''} : {'/A'},
      );
      expect(bloc.state.currentPath, path);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });
  }

  test(
    'worker applies root/current/descendant/all scopes once per comic and select-all uses actual results',
    () async {
      final bloc = FolderShelfBloc(mode: ShelfPageMode.favorite);
      addTearDown(bloc.close);
      await _loadAfter(bloc, const FolderShelfSetFacets(_red));
      expect(_visible(bloc), {_key('root')});
      await _loadAfter(bloc, const FolderShelfEnterFolder('/A'));
      await _loadAfter(bloc, const FolderShelfSetFacets(_red));
      expect(_visible(bloc), {_key('shared'), _key('vendor', _other)});
      expect(bloc.state.folders, isEmpty);
      expect(
        bloc.state.comicFolderLabels[_key('shared')],
        contains('/A/child'),
      );
      expect(bloc.state.comicFolderLabels[_key('shared')], contains('/B'));
      await _loadAfter(bloc, const FolderShelfSetFacets(_redDescendants));
      expect(_visible(bloc), {
        _key('shared'),
        _key('child'),
        _key('vendor', _other),
      });
      await _loadAfter(bloc, const FolderShelfSetFacets(_redAll));
      expect(_visible(bloc), {
        _key('root'),
        _key('shared'),
        _key('child'),
        _key('vendor', _other),
      });
      expect(
        bloc.state.comics.where((row) => row.id == 'shared'),
        hasLength(1),
      );
      final selected = bloc.stream.firstWhere(
        (state) => state.selectedComicKeys.length == 4,
      );
      bloc.add(const FolderShelfSelectAll());
      await selected;
      expect(bloc.state.selectedComicKeys, _visible(bloc));
      expect(bloc.state.selectedFolderPaths, isEmpty);
    },
  );

  test(
    'arbitrary vendors, unknown metadata, keyword and source combine with facets by AND',
    () async {
      final bloc = FolderShelfBloc(mode: ShelfPageMode.favorite);
      addTearDown(bloc.close);
      await _loadAfter(
        bloc,
        const FolderShelfLoadRequested(
          search: SearchStatusState(keyword: 'needle', sources: [_source]),
        ),
      );
      await _loadAfter(
        bloc,
        const FolderShelfSetFacets(
          ShelfFacetSelection(
            scope: ShelfFacetScope.all,
            values: {
              'tags': {'red'},
              'year': {'2024'},
            },
          ),
        ),
      );
      expect(_visible(bloc), {_key('shared')});
      await _loadAfter(
        bloc,
        const FolderShelfSetFacets(
          ShelfFacetSelection(
            scope: ShelfFacetScope.all,
            values: {
              'tags': {shelfFacetUnknown},
            },
          ),
        ),
      );
      expect(_visible(bloc), {_key('unknown')});
      await _loadAfter(
        bloc,
        const FolderShelfSetFacets(
          ShelfFacetSelection(
            scope: ShelfFacetScope.all,
            values: {
              'tags': {'red', shelfFacetUnknown},
            },
          ),
        ),
      );
      expect(_visible(bloc), {_key('shared'), _key('child'), _key('unknown')});
      expect(_paths(_key('unknown')), {'/A'});
      expect(_deleted(_key('unknown')), isFalse);
    },
  );

  test(
    'filtered copy and move preserve outside-scope memberships and a target already inside the scope',
    () async {
      final bloc = FolderShelfBloc(mode: ShelfPageMode.favorite);
      addTearDown(bloc.close);
      await _loadAfter(bloc, const FolderShelfEnterFolder('/A'));
      await _loadAfter(bloc, const FolderShelfSetFacets(_redDescendants));
      await _select(bloc, _key('shared'));
      await _loadAfter(bloc, const FolderShelfCopySelected({'/C'}));
      expect(_paths(_key('shared')), {'/A', '/A/child', '/B', '/C'});
      expect(_paths(_key('child')), {'/A/child'});
      await _select(bloc, _key('shared'));
      await _loadAfter(bloc, const FolderShelfMoveSelected({'/A/child'}));
      expect(_paths(_key('shared')), {'/A/child', '/B', '/C'});
      expect(_deleted(_key('shared')), isFalse);
      expect(_paths(_key('vendor', _other)), {'/A'});
      expect(_paths(_key('blue')), {'/B'});
      await _select(bloc, _key('child'));
      await _loadAfter(bloc, const FolderShelfMoveSelected({'/C'}));
      expect(_paths(_key('child')), {'/C'});
      expect(
        _deleted(_key('child')),
        isFalse,
        reason: 'moving the last archive must preserve the favorite itself',
      );
    },
  );

  test(
    'filtered delete removes only scoped memberships until the selected work has no remaining archive',
    () async {
      final bloc = FolderShelfBloc(mode: ShelfPageMode.favorite);
      addTearDown(bloc.close);
      await _loadAfter(bloc, const FolderShelfEnterFolder('/A'));
      await _loadAfter(bloc, const FolderShelfSetFacets(_red));
      await _select(bloc, _key('shared'));
      await _loadAfter(bloc, const FolderShelfDeleteSelected());
      expect(_paths(_key('shared')), {'/A/child', '/B'});
      expect(_deleted(_key('shared')), isFalse);
      await _loadAfter(bloc, const FolderShelfSetFacets(_redDescendants));
      await _select(bloc, _key('shared'));
      await _loadAfter(bloc, const FolderShelfDeleteSelected());
      expect(_paths(_key('shared')), {'/B'});
      expect(_deleted(_key('shared')), isFalse);
      await _loadAfter(bloc, const FolderShelfSetFacets(_redAll));
      await _select(bloc, _key('shared'));
      await _loadAfter(bloc, const FolderShelfDeleteSelected());
      expect(_paths(_key('shared')), isEmpty);
      expect(_deleted(_key('shared')), isTrue);
      expect(_paths(_key('child')), {'/A/child'});
      expect(_paths(_key('vendor', _other)), {'/A'});
      expect(_deleted(_key('root')), isFalse);
    },
  );

  test(
    'history facets use actual history metadata and visible-only deletion',
    () async {
      for (final (id, tag, source) in [
        ('root', 'history-red', _source),
        ('blue', 'history-blue', _source),
        ('vendor', 'history-red', _other),
        ('unknown', '', _source),
      ]) {
        final row = createTestHistory(_key(id, source))
          ..source = source
          ..comicId = id
          ..title = 'History $id'
          ..metadata = tag.isEmpty
              ? '{bad'
              : jsonEncode([
                  {
                    'type': 'tags',
                    'value': [tag],
                  },
                ]);
        objectbox.unifiedHistoryBox.put(row);
      }
      final bloc = FolderShelfBloc(mode: ShelfPageMode.history);
      addTearDown(bloc.close);
      await _loadAfter(
        bloc,
        const FolderShelfLoadRequested(
          search: SearchStatusState(sources: [_source]),
        ),
      );
      await _loadAfter(
        bloc,
        const FolderShelfSetFacets(
          ShelfFacetSelection(
            scope: ShelfFacetScope.descendants,
            values: {
              'tags': {'history-red'},
            },
          ),
        ),
      );
      expect(bloc.state.facets.scope, ShelfFacetScope.current);
      expect(_visible(bloc), {_key('root')});
      expect(bloc.state.folders, isEmpty);
      expect(
        bloc.state.comicFolderLabels.values.every((value) => value.isEmpty),
        isTrue,
      );
      final index = loadComicShelfFacetIndex(type: ComicFolderType.history);
      expect(index.folderLabels, isEmpty);
      expect(
        index.entries
            .singleWhere((entry) => entry.key == _key('root'))
            .fields['tags'],
        {'history-red'},
      );
      expect(
        index.entries.expand(
          (entry) => entry.fields.values.expand((values) => values),
        ),
        isNot(contains('red')),
      );
      await _loadAfter(
        bloc,
        const FolderShelfSetFacets(
          ShelfFacetSelection(
            values: {
              'tags': {'absent'},
            },
          ),
        ),
      );
      expect(_visible(bloc), isEmpty);
      await _loadAfter(
        bloc,
        const FolderShelfSetFacets(
          ShelfFacetSelection(
            values: {
              'tags': {'history-red'},
            },
          ),
        ),
      );
      final selected = bloc.stream.firstWhere(
        (state) => state.selectedComicKeys.isNotEmpty,
      );
      bloc.add(const FolderShelfSelectAll());
      await selected;
      expect(bloc.state.selectedComicKeys, {_key('root')});
      await _loadAfter(bloc, const FolderShelfDeleteSelected());
      expect(
        objectbox.unifiedHistoryBox
            .getAll()
            .where((row) => row.deleted)
            .map((row) => row.uniqueKey),
        [_key('root')],
      );
      expect(
        _deleted(_key('root')),
        isFalse,
        reason: 'history deletion cannot change favorites',
      );
      await _loadAfter(bloc, const FolderShelfSetFacets(ShelfFacetSelection()));
      expect(_visible(bloc), {_key('blue'), _key('unknown')});
    },
  );

  test(
    'download facets preserve outside-scope archives and files until the final link',
    () async {
      await useIsolatedDownloadFixture();
      const type = ComicFolderType.download;
      final directories = <String, Directory>{};
      addTearDown(() async {
        for (final directory in directories.values) {
          if (await directory.exists()) await directory.delete(recursive: true);
        }
      });
      for (final (parent, name) in [('', 'A'), ('/A', 'child'), ('', 'B')]) {
        ComicFolderService.createFolder(parent, name, type);
      }
      for (final (id, tag, paths) in [
        ('shared', 'download-red', {'/A', '/A/child', '/B'}),
        ('blue', 'download-blue', {'/A'}),
        ('orphan', 'download-red', <String>{}),
      ]) {
        final directory = await createDownloadFixture(_source, id);
        directories[id] = directory;
        await File(
          '${directory.path}/page.jpg',
        ).writeAsString('synthetic local file');
        final row = createTestDownload(_key(id), storageRoot: directory.path)
          ..source = _source
          ..comicId = id
          ..title = 'Download $id'
          ..metadata = jsonEncode([
            {
              'type': 'tag',
              'value': [tag],
            },
          ]);
        objectbox.unifiedDownloadBox.put(row);
        for (final path in paths) {
          ComicLinkService.addComic(row.uniqueKey, path, type);
        }
      }
      Set<String> downloadPaths() => loadComicShelfFacetIndex(type: type)
          .entries
          .where((entry) => entry.key == _key('shared'))
          .expand((entry) => entry.folders)
          .toSet();
      final bloc = FolderShelfBloc(mode: ShelfPageMode.download);
      addTearDown(bloc.close);
      await _loadAfter(bloc, const FolderShelfEnterFolder('/A'));
      await _loadAfter(
        bloc,
        const FolderShelfSetFacets(
          ShelfFacetSelection(
            values: {
              'tags': {'download-red'},
            },
          ),
        ),
      );
      expect(_visible(bloc), {_key('shared')});
      expect(
        loadComicShelfFacetIndex(type: type).entries.map((entry) => entry.key),
        isNot(contains(_key('orphan'))),
      );
      await _select(bloc, _key('shared'));
      await _loadAfter(bloc, const FolderShelfDeleteSelected());
      expect(downloadPaths(), {'/A/child', '/B'});
      expect(
        await File('${directories['shared']!.path}/page.jpg').exists(),
        isTrue,
      );
      await _loadAfter(
        bloc,
        const FolderShelfSetFacets(
          ShelfFacetSelection(
            scope: ShelfFacetScope.descendants,
            values: {
              'tags': {'download-red'},
            },
          ),
        ),
      );
      await _select(bloc, _key('shared'));
      await _loadAfter(bloc, const FolderShelfDeleteSelected());
      expect(downloadPaths(), {'/B'});
      expect(await directories['shared']!.exists(), isTrue);
      await _loadAfter(
        bloc,
        const FolderShelfSetFacets(
          ShelfFacetSelection(
            scope: ShelfFacetScope.all,
            values: {
              'tags': {'download-red'},
            },
          ),
        ),
      );
      final selected = bloc.stream.firstWhere(
        (state) => state.selectedComicKeys.isNotEmpty,
      );
      bloc.add(const FolderShelfSelectAll());
      await selected;
      expect(bloc.state.selectedComicKeys, {_key('shared')});
      await _loadAfter(bloc, const FolderShelfDeleteSelected());
      expect(downloadPaths(), isEmpty);
      // The final link schedules file/record deletion independently of the
      // shelf reload. Wait for that real IO before checking its durable result
      // or allowing fixture teardown to remove the download root.
      final deletionDeadline = DateTime.now().add(const Duration(seconds: 3));
      while (objectbox.unifiedDownloadBox.getAll().any(
            (row) => row.uniqueKey == _key('shared'),
          ) &&
          DateTime.now().isBefore(deletionDeadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(
        objectbox.unifiedDownloadBox
            .getAll()
            .map((row) => row.uniqueKey)
            .toSet(),
        {_key('blue'), _key('orphan')},
      );
      await expectDownloadRemoved(directories['shared']!);
      expect(await directories['blue']!.exists(), isTrue);
      expect(_paths(_key('shared')), {'/A', '/A/child', '/B'});
      expect(_deleted(_key('shared')), isFalse);
      await _loadAfter(bloc, const FolderShelfSetFacets(ShelfFacetSelection()));
      expect(_visible(bloc), {_key('blue')});
    },
  );

  testWidgets(
    'real favorite page counts direct membership, keeps filter scope, and returns from deep folders',
    (tester) async {
      final deep = ComicFolderService.createFolder('/A/child', '深层目录', _type);
      final deleted = createTestFavorite(_key('deleted'))
        ..source = _source
        ..comicId = 'deleted';
      objectbox.unifiedFavoriteBox.put(deleted);
      ComicLinkService.addComic(deleted.uniqueKey, '/A', _type);
      objectbox.unifiedFavoriteBox.put(deleted..deleted = true);
      final alias = createTestFavorite('old-key', updatedAt: DateTime.utc(2020))
        ..source = _source
        ..comicId = 'shared';
      objectbox.unifiedFavoriteBox.put(alias);
      ComicLinkService.addComic(alias.uniqueKey, '/A', _type);
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      final search = BookshelfSearchCubit(
        favorite: const SearchStatusState(sources: [_source]),
      );
      addTearDown(search.close);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<GlobalSettingCubit>(
              create: (_) => GlobalSettingCubit(),
            ),
            BlocProvider<BookshelfSearchCubit>.value(value: search),
          ],
          child: AppInterfaceStyleScope(
            style: style,
            child: MaterialApp(
              home: const Scaffold(
                body: FolderShelfPage(
                  sourceNames: {_source: 'Third party'},
                  mode: ShelfPageMode.favorite,
                ),
              ),
            ),
          ),
        ),
      );
      Future<void> wait(bool Function() ready) async {
        for (var i = 0; i < 150; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
          if (ready()) return;
        }
        fail('favorite worker did not reach the expected state');
      }

      late FolderShelfBloc bloc;
      await wait(() {
        final toolbar = find.byType(BookshelfContentToolbar);
        if (toolbar.evaluate().isEmpty) return false;
        bloc = tester.element(toolbar).read<FolderShelfBloc>();
        return !bloc.state.isLoading && _visible(bloc).contains(_key('root'));
      });
      final toolbar = find.byType(BookshelfContentToolbar);
      expect(tester.widget<BookshelfContentToolbar>(toolbar).title, isEmpty);
      expect(
        tester.widget<BookshelfContentToolbar>(toolbar).subtitle,
        t.videoLibrary.results(count: 1),
      );
      final a = bloc.state.folders.singleWhere((folder) => folder.name == 'A');
      expect(bloc.state.folderCounts[a.syncId], (works: 2, subfolders: 1));
      final empty = bloc.state.folders.singleWhere(
        (folder) => folder.name == 'C',
      );
      expect(bloc.state.folderCounts[empty.syncId], (works: 0, subfolders: 0));
      final counts = find.byKey(const ValueKey('shelf-folder.counts'));
      expect(counts, findsNothing);
      await tester.tap(find.byKey(const ValueKey('comic-shelf.view')));
      await tester.pumpAndSettle();
      Finder folder(String id) => find.byWidgetPredicate(
        (widget) => widget is FolderShelfItem && widget.folder.syncId == id,
      );
      final aCounts = find.descendant(of: folder(a.syncId), matching: counts);
      expect(aCounts, findsOneWidget);
      expect(
        find.descendant(
          of: aCounts,
          matching: find.text(t.videoLibrary.results(count: 2)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: aCounts,
          matching: find.text(t.bookshelf.subfolderCount(count: 1)),
        ),
        findsOneWidget,
      );
      await tester.tap(folder(a.syncId));
      await wait(
        () =>
            bloc.state.currentPath == '/A' &&
            !bloc.state.isLoading &&
            _visible(bloc).contains(_key('shared')) &&
            _visible(bloc).contains(_key('unknown')),
      );
      expect(bloc.state.error, isNull);
      await tester.pump();
      final before = _visible(bloc);
      Future<void> draft() async {
        await tester.tap(find.byKey(const ValueKey('comic-shelf.filter')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('shelf-scope-descendants')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('shelf-facet-tags')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('shelf-option-tags-red')));
        await tester.pumpAndSettle();
      }

      await draft();
      await tester.tap(find.byTooltip(t.common.cancel));
      await tester.pumpAndSettle();
      expect(bloc.state.facets.isActive, isFalse);
      expect(_visible(bloc), before);
      expect(bloc.state.currentPath, '/A');
      await draft();
      await tester.tap(find.byKey(const ValueKey('shelf-filter-apply')));
      await wait(
        () =>
            !bloc.state.isLoading &&
            bloc.state.facets.isActive &&
            _visible(bloc).length == 2 &&
            _visible(bloc).contains(_key('shared')) &&
            _visible(bloc).contains(_key('child')),
      );
      expect(_visible(bloc), {_key('shared'), _key('child')});
      expect(bloc.state.folders, isEmpty);
      expect(bloc.state.comicFolderLabels[_key('shared')], contains('/B'));
      await _resetComicFilter(tester);
      await wait(
        () =>
            !bloc.state.isLoading &&
            !bloc.state.facets.isActive &&
            _visible(bloc).length == before.length &&
            _visible(bloc).containsAll(before),
      );
      expect(bloc.state.currentPath, '/A');
      expect(_visible(bloc), before);
      expect(search.state.favorite.sources, [_source]);
      expect(_paths(_key('shared')), {'/A', '/A/child', '/B'});
      final child = bloc.state.folders.single;
      await tester.tap(folder(child.syncId));
      await wait(
        () => !bloc.state.isLoading && bloc.state.currentPath == '/A/child',
      );
      expect(bloc.state.folderCounts[deep.syncId], (works: 0, subfolders: 0));
      await tester.tap(folder(deep.syncId));
      await wait(
        () =>
            !bloc.state.isLoading && bloc.state.currentPath == '/A/child/深层目录',
      );
      final back = find.byKey(const ValueKey('comic-shelf.back'));
      final root = find.byKey(const ValueKey('comic-shelf.root'));
      expect(tester.widget<BookshelfContentToolbar>(toolbar).title, deep.name);
      expect(tester.widget<BookshelfContentToolbar>(toolbar).subtitle, isEmpty);
      expect(
        tester.widget<BookshelfContentToolbar>(toolbar).moreOptions.keys,
        everyElement(isNot(startsWith('folder-cover.'))),
      );
      expect(find.byTooltip(t.bookshelf.returnToParent), findsOneWidget);
      await tester.tap(back);
      await wait(
        () => !bloc.state.isLoading && bloc.state.currentPath == '/A/child',
      );
      await tester.tap(root);
      await wait(() => !bloc.state.isLoading && bloc.state.isRoot);
      expect(root, findsNothing);
      expect(back, findsNothing);
      expect(bloc.state.folderCounts[a.syncId], (works: 2, subfolders: 1));
      expect(bloc.state.search?.sources, [_source]);
      ComicLinkService.removeComic(_key('unknown'), '/A', _type);
      await wait(() => bloc.state.folderCounts[a.syncId]?.works == 1);
      expect(
        find.descendant(
          of: aCounts,
          matching: find.text(t.videoLibrary.results(count: 1)),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    },
  );
  testWidgets(
    'history and download pages cancel, apply, clear and keep independent mode conditions',
    (tester) async {
      for (final id in ['red', 'blue']) {
        final metadata = jsonEncode([
          {
            'type': 'tags',
            'value': [id],
          },
        ]);
        final history = createTestHistory(_key(id))
          ..source = _source
          ..comicId = id
          ..title = 'History $id'
          ..metadata = metadata;
        final download = createTestDownload(_key(id))
          ..source = _source
          ..comicId = id
          ..title = 'Download $id'
          ..metadata = metadata;
        objectbox.unifiedHistoryBox.put(history);
        objectbox.unifiedDownloadBox.put(download);
        ComicLinkService.addComic(_key(id), null, ComicFolderType.download);
      }
      final style = ValueNotifier('breeze');
      final active = ValueNotifier(0);
      final search = BookshelfSearchCubit(
        history: const SearchStatusState(sources: [_source]),
        download: const SearchStatusState(sources: [_source]),
      );
      addTearDown(style.dispose);
      addTearDown(active.dispose);
      addTearDown(search.close);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<GlobalSettingCubit>(
              create: (_) => GlobalSettingCubit(),
            ),
            BlocProvider<BookshelfSearchCubit>.value(value: search),
          ],
          child: AppInterfaceStyleScope(
            style: style,
            child: MaterialApp(
              home: Scaffold(
                body: ValueListenableBuilder<int>(
                  valueListenable: active,
                  builder: (_, index, _) => IndexedStack(
                    index: index,
                    children: [
                      for (final mode in [
                        ShelfPageMode.history,
                        ShelfPageMode.download,
                      ])
                        FolderShelfPage(
                          key: ValueKey('mode.${mode.name}'),
                          mode: mode,
                          isActive:
                              mode ==
                              [
                                ShelfPageMode.history,
                                ShelfPageMode.download,
                              ][index],
                          sourceNames: const {_source: 'Third party'},
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      Future<void> wait(bool Function() ready) async {
        for (var i = 0; i < 150; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          await tester.pump();
          if (ready()) return;
        }
        fail('history/download page did not reach expected state');
      }

      FolderShelfBloc currentBloc() => tester
          .element(find.byType(BookshelfContentToolbar))
          .read<FolderShelfBloc>();
      await wait(
        () =>
            find.byType(BookshelfContentToolbar).evaluate().isNotEmpty &&
            !currentBloc().state.isLoading,
      );
      // Both real pages create their workers immediately. Hidden IndexedStack
      // children can still own an animating loading indicator; pumpAndSettle
      // cannot complete their real isolate IO by advancing fake time alone.
      await wait(() {
        final toolbars = find.byType(
          BookshelfContentToolbar,
          skipOffstage: false,
        );
        return toolbars.evaluate().length == 2 &&
            toolbars.evaluate().every(
              (element) => !element.read<FolderShelfBloc>().state.isLoading,
            );
      });
      final history = currentBloc();
      Future<void> draft() async {
        await tester.tap(find.byKey(const ValueKey('comic-shelf.filter')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('shelf-scope-descendants')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('shelf-scope-all')),
          active.value == 0 ? findsNothing : findsOneWidget,
        );
        // Tags are the only seeded facet, so the sheet opens their options
        // directly and omits the dimension picker.
        await tester.tap(find.byKey(const ValueKey('shelf-option-tags-red')));
        await tester.pumpAndSettle();
      }

      await draft();
      active.value = 1;
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('shelf-filter-apply')));
      await tester.pumpAndSettle();
      expect(history.state.facets.isActive, isFalse);
      active.value = 0;
      await tester.pumpAndSettle();

      await draft();
      expect(find.byKey(const ValueKey('shelf-scope-current')), findsNothing);
      await tester.tap(find.byTooltip(t.common.cancel));
      await tester.pumpAndSettle();
      expect(history.state.facets.isActive, isFalse);
      expect(_visible(history), {_key('red'), _key('blue')});
      await draft();
      await tester.tap(find.byKey(const ValueKey('shelf-filter-apply')));
      await wait(
        () => !history.state.isLoading && history.state.facets.isActive,
      );
      expect(_visible(history), {_key('red')});
      active.value = 1;
      await tester.pump();
      await wait(
        () =>
            currentBloc().state.mode == ShelfPageMode.download &&
            !currentBloc().state.isLoading,
      );
      final download = currentBloc();
      expect(download.state.facets.isActive, isFalse);
      expect(_visible(download), {_key('red'), _key('blue')});
      await draft();
      await tester.tap(find.byTooltip(t.common.cancel));
      await tester.pumpAndSettle();
      expect(download.state.facets.isActive, isFalse);
      await draft();
      await tester.tap(find.byKey(const ValueKey('shelf-filter-apply')));
      await wait(
        () => !download.state.isLoading && download.state.facets.isActive,
      );
      expect(_visible(download), {_key('red')});
      await _resetComicFilter(tester);
      await wait(
        () => !download.state.isLoading && !download.state.facets.isActive,
      );
      expect(_visible(download), {_key('red'), _key('blue')});
      active.value = 0;
      await tester.pump();
      expect(currentBloc(), same(history));
      expect(_visible(history), {_key('red')});
      await _resetComicFilter(tester);
      await wait(
        () => !history.state.isLoading && !history.state.facets.isActive,
      );
      expect(_visible(history), {_key('red'), _key('blue')});
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    },
  );
}
