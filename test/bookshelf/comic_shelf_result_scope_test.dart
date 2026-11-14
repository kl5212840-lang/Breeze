import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:worker_manager/worker_manager.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/bookshelf/bloc/folder_shelf_bloc.dart';
import 'package:zephyr/page/bookshelf/cubit/search_status.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/bookshelf/service/comic_folder_service.dart';
import 'package:zephyr/page/bookshelf/service/comic_link_service.dart';
import 'package:zephyr/page/bookshelf/service/shelf_facet_adapters.dart';

import '../test_helper.dart';

const _source = 'result-scope.source';
const _type = ComicFolderType.favorite;
String _key(String id) => '$_source:$id';

Future<void> _load(FolderShelfBloc bloc, FolderShelfEvent event) async {
  var loading = false;
  final ready = bloc.stream
      .firstWhere((state) {
        loading = loading || state.isLoading;
        return loading && !state.isLoading;
      })
      .timeout(const Duration(seconds: 20));
  bloc.add(event);
  await ready;
  expect(bloc.state.error, isNull);
}

Future<void> _select(FolderShelfBloc bloc, String id) async {
  final selected = bloc.stream
      .firstWhere((state) => state.selectedComicKeys.contains(_key(id)))
      .timeout(const Duration(seconds: 5));
  bloc.add(FolderShelfToggleComicSelection(_key(id)));
  await selected;
}

Set<String> _paths(String id) {
  final folders = {
    for (final row in ComicFolderService.listAllFolders(_type)) row.syncId: row,
  };
  return {
    for (final row in ComicLinkService.linksOfComic(_key(id), _type))
      row.folderSyncId == null
          ? ''
          : ComicFolderService.folderPath(
              folders[row.folderSyncId]!,
              syncIdMap: folders,
            ),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    debugShelfDbRootPath = TestObjectBoxHelper.tempPath;
    await workerManager.init(isolatesCount: 1);
  });
  tearDownAll(() async {
    await workerManager.dispose();
    debugShelfDbRootPath = null;
    await TestObjectBoxHelper.tearDownTestObjectBox();
  });
  setUp(() {
    for (final folder in ['A', 'B', 'C']) {
      ComicFolderService.createFolder('', folder, _type);
    }
    for (final (id, title, paths) in [
      ('shared', 'Needle shared', {'/A', '/B'}),
      ('other', 'Unrelated work', {'/B'}),
    ]) {
      final row = createTestFavorite(_key(id))
        ..source = _source
        ..comicId = id
        ..title = title
        ..metadata = jsonEncode([
          {'type': 'tag', 'value': 'public-tag'},
          {'type': 'internal', 'value': 'private-fixture-marker'},
        ]);
      objectbox.unifiedFavoriteBox.put(row);
      for (final path in paths) {
        ComicLinkService.addComic(row.uniqueKey, path, _type);
      }
    }
  });
  tearDown(TestObjectBoxHelper.cleanComicFolderBoxes);

  for (final move in [false, true]) {
    test(
      'global keyword ${move ? 'move' : 'delete'} acts on only visible works',
      () async {
        final bloc = FolderShelfBloc(mode: ShelfPageMode.favorite);
        addTearDown(bloc.close);
        await _load(bloc, const FolderShelfEnterFolder('/C'));
        await _load(
          bloc,
          const FolderShelfLoadRequested(
            search: SearchStatusState(keyword: 'needle', sources: [_source]),
          ),
        );
        expect(bloc.state.folders, isEmpty);
        expect(bloc.state.comics.map((row) => row.id), ['shared']);
        await _select(bloc, 'shared');
        await _load(
          bloc,
          move
              ? const FolderShelfMoveSelected({'/C'})
              : const FolderShelfDeleteSelected(),
        );
        expect(_paths('shared'), move ? {'/C'} : isEmpty);
        expect(_paths('other'), {'/B'});
      },
    );
  }

  test(
    'search refresh discards hidden folder selection before deleting results',
    () async {
      final bloc = FolderShelfBloc(mode: ShelfPageMode.favorite);
      addTearDown(bloc.close);
      await _load(bloc, const FolderShelfLoadRequested());
      final selected = bloc.stream
          .firstWhere((state) => state.selectedFolderPaths.contains('/B'))
          .timeout(const Duration(seconds: 5));
      bloc.add(const FolderShelfToggleFolderSelection('/B'));
      await selected;
      await _load(
        bloc,
        const FolderShelfLoadRequested(
          search: SearchStatusState(keyword: 'needle', sources: [_source]),
        ),
      );
      expect(bloc.state.selectedFolderPaths, isEmpty);
      await _select(bloc, 'shared');
      await _load(bloc, const FolderShelfDeleteSelected());
      expect(_paths('other'), {'/B'});
      expect(
        ComicFolderService.listAllFolders(_type).any((row) => row.name == 'B'),
        isTrue,
      );
    },
  );

  test(
    'keyword uses the same public metadata projection with and without facets',
    () async {
      final bloc = FolderShelfBloc(mode: ShelfPageMode.favorite);
      addTearDown(bloc.close);
      await _load(
        bloc,
        const FolderShelfLoadRequested(
          search: SearchStatusState(
            keyword: 'private-fixture-marker',
            sources: [_source],
          ),
        ),
      );
      expect(bloc.state.comics, isEmpty);
      await _load(
        bloc,
        const FolderShelfSetFacets(
          ShelfFacetSelection(
            scope: ShelfFacetScope.all,
            values: {
              'tags': {'public-tag'},
            },
          ),
        ),
      );
      expect(bloc.state.comics, isEmpty);
    },
  );

  test(
    'explicit empty current scope constrains keyword and stays a works-only result',
    () async {
      final bloc = FolderShelfBloc(mode: ShelfPageMode.favorite);
      addTearDown(bloc.close);
      await _load(bloc, const FolderShelfEnterFolder('/C'));
      await _load(
        bloc,
        const FolderShelfLoadRequested(
          search: SearchStatusState(keyword: 'needle', sources: [_source]),
        ),
      );
      expect(bloc.state.comics.map((row) => row.id), ['shared']);
      await _load(
        bloc,
        const FolderShelfSetFacets(ShelfFacetSelection(applied: true)),
      );
      expect(bloc.state.comics, isEmpty);
      expect(bloc.state.folders, isEmpty);
      await _load(
        bloc,
        const FolderShelfLoadRequested(
          search: SearchStatusState(sources: [_source]),
        ),
      );
      expect(bloc.state.facets.isActive, isTrue);
      expect(bloc.state.folders, isEmpty);
      await _load(bloc, const FolderShelfGoHome());
      expect(bloc.state.facets.isActive, isFalse);
      expect(bloc.state.folders, hasLength(3));
    },
  );

  test(
    'canonical aliases move/copy/delete using original identities and scoped memberships',
    () async {
      const alias = ' result-scope.source :alias';
      final row = createTestFavorite(alias)
        ..source = ' $_source '
        ..comicId = 'alias'
        ..title = 'Needle alias';
      objectbox.unifiedFavoriteBox.put(row);
      ComicLinkService.addComic(alias, '/A', _type);
      ComicLinkService.addComic(alias, '/B', _type);
      final bloc = FolderShelfBloc(mode: ShelfPageMode.favorite);
      addTearDown(bloc.close);
      await _load(bloc, const FolderShelfEnterFolder('/A'));
      await _load(
        bloc,
        const FolderShelfSetFacets(ShelfFacetSelection(applied: true)),
      );
      await _select(bloc, 'alias');
      await _load(bloc, const FolderShelfMoveSelected({'/C'}));
      Set<String> paths() => loadComicShelfFacetIndex(
        type: _type,
      ).entries.singleWhere((entry) => entry.key == _key('alias')).folders;
      expect(paths(), {'/B', '/C'});
      expect(objectbox.unifiedFavoriteBox.get(row.id)?.uniqueKey, alias);
      expect(ComicLinkService.linksOfComic(_key('alias'), _type), isEmpty);
      await _load(bloc, const FolderShelfEnterFolder('/C'));
      await _select(bloc, 'alias');
      await _load(bloc, const FolderShelfCopySelected({'/A'}));
      expect(paths(), {'/A', '/B', '/C'});
      await _select(bloc, 'alias');
      await _load(bloc, const FolderShelfDeleteSelected());
      expect(paths(), {'/A', '/B'});
      expect(objectbox.unifiedFavoriteBox.get(row.id)?.deleted, isFalse);
      await _load(
        bloc,
        const FolderShelfSetFacets(
          ShelfFacetSelection(scope: ShelfFacetScope.all, applied: true),
        ),
      );
      await _select(bloc, 'alias');
      await _load(bloc, const FolderShelfDeleteSelected());
      expect(ComicLinkService.linksOfComic(alias, _type), isEmpty);
      expect(objectbox.unifiedFavoriteBox.get(row.id)?.deleted, isTrue);
      expect(_paths('other'), {'/B'});
    },
  );

  test(
    'history alias deletion removes only the visible original record',
    () async {
      const alias = ' result-scope.source :history-alias';
      final row = createTestHistory(alias)
        ..source = ' $_source '
        ..comicId = 'history-alias'
        ..title = 'Needle history';
      final other = createTestHistory(_key('other-history'))
        ..source = _source
        ..comicId = 'other-history'
        ..title = 'Unrelated history';
      objectbox.unifiedHistoryBox.putMany([row, other]);
      final bloc = FolderShelfBloc(mode: ShelfPageMode.history);
      addTearDown(bloc.close);
      await _load(
        bloc,
        const FolderShelfLoadRequested(
          search: SearchStatusState(keyword: 'needle', sources: [_source]),
        ),
      );
      expect(bloc.state.comics.map((comic) => comic.id), ['history-alias']);
      await _select(bloc, 'history-alias');
      await _load(bloc, const FolderShelfDeleteSelected());
      expect(objectbox.unifiedHistoryBox.get(row.id)?.uniqueKey, alias);
      expect(objectbox.unifiedHistoryBox.get(row.id)?.deleted, isTrue);
      expect(objectbox.unifiedHistoryBox.get(other.id)?.deleted, isFalse);
      expect(_paths('shared'), {'/A', '/B'});
    },
  );
}
