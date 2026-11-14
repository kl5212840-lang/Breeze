import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/page/bookshelf/bloc/folder_shelf_bloc.dart';
import 'package:zephyr/page/bookshelf/cubit/search_status.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry_info.dart';

import '../test_helper.dart';

Map<String, dynamic> _empty() => {
  'comics': <ComicSimplifyEntryInfo>[],
  'folders': <ComicFolder>[],
  'comicSearchTexts': <String, String>{},
  'comicFolderLabels': <String, String>{},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  for (final mode in [ShelfPageMode.favorite, ShelfPageMode.history]) {
    test(
      'cold ${mode.name} read never publishes a concurrently deleted row',
      () async {
        final key = 'cold-${mode.name}';
        final favorite = createTestFavorite(key);
        final history = createTestHistory(key);
        final isFavorite = mode == ShelfPageMode.favorite;
        if (isFavorite) {
          objectbox.unifiedFavoriteBox.put(favorite);
        } else {
          objectbox.unifiedHistoryBox.put(history);
        }
        final stale = Completer<Map<String, dynamic>>();
        final entered = Completer<void>();
        final refreshed = Completer<void>();
        final bloc = FolderShelfBloc(
          mode: mode,
          loadTask: (_) async {
            if (!entered.isCompleted) {
              entered.complete();
              return stale.future;
            }
            refreshed.complete();
            return _empty();
          },
        );
        var showedDeleted = false;
        final states = bloc.stream.listen((state) {
          showedDeleted |= state.comics.isNotEmpty;
        });
        addTearDown(() async {
          if (!stale.isCompleted) stale.complete(_empty());
          await states.cancel();
          await bloc.close();
          if (isFavorite) {
            objectbox.unifiedFavoriteBox.remove(favorite.id);
          } else {
            objectbox.unifiedHistoryBox.remove(history.id);
          }
        });
        final first = bloc.refresh();
        await entered.future;
        final changed = objectbox.store.entityChanges.firstWhere(
          (types) => types.contains(
            isFavorite ? UnifiedComicFavorite : UnifiedComicHistory,
          ),
        );
        if (isFavorite) {
          objectbox.unifiedFavoriteBox.put(favorite..deleted = true);
        } else {
          objectbox.unifiedHistoryBox.put(history..deleted = true);
        }
        await changed.timeout(const Duration(seconds: 2));
        stale.complete({
          ..._empty(),
          'comics': [
            ComicSimplifyEntryInfo(
              title: 'Previously saved',
              id: key,
              fileServer: '',
              path: '',
              pictureType: PictureType.cover,
              from: 'test',
            ),
          ],
        });
        expect(await first, isFalse);
        await refreshed.future.timeout(const Duration(seconds: 2));
        await Future<void>.delayed(Duration.zero);
        expect(showedDeleted, isFalse);
        expect(bloc.state.comics, isEmpty);
        expect(bloc.state.isLoading, isFalse);
      },
    );
  }

  test(
    'awaited refresh completes only after this DB result is committed',
    () async {
      final gate = Completer<Map<String, dynamic>>();
      var reads = 0;
      final bloc = FolderShelfBloc(
        mode: ShelfPageMode.favorite,
        loadTask: (_) {
          reads++;
          return gate.future;
        },
      );
      addTearDown(bloc.close);
      var completed = false;
      final first = bloc.refresh().then((result) {
        completed = true;
        return result;
      });
      final duplicate = bloc.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(reads, 1);
      expect(completed, isFalse);
      expect(bloc.state.isLoading, isTrue);
      gate.complete(_empty());
      expect(await first, isTrue);
      expect(await duplicate, isTrue);
      expect(bloc.state.isLoading, isFalse);
      expect(bloc.state.error, isNull);
    },
  );

  test(
    'a failed local read is not success and is explicitly retryable',
    () async {
      var fail = true;
      final bloc = FolderShelfBloc(
        mode: ShelfPageMode.history,
        loadTask: (_) async {
          if (fail) throw StateError('offline DB fixture');
          return _empty();
        },
      );
      addTearDown(bloc.close);
      expect(await bloc.refresh(), isFalse);
      expect(bloc.state.isLoading, isFalse);
      expect(bloc.state.error, contains('offline DB fixture'));
      fail = false;
      expect(await bloc.refresh(), isTrue);
      expect(bloc.state.error, isNull);
    },
  );

  test(
    'scope change cancels only its waiter and rejects an old late result',
    () async {
      final old = Completer<Map<String, dynamic>>();
      final next = Completer<Map<String, dynamic>>();
      final paths = <String>[];
      final bloc = FolderShelfBloc(
        mode: ShelfPageMode.favorite,
        loadTask: (payload) {
          final path = payload['currentPath'] as String;
          paths.add(path);
          return path.isEmpty ? old.future : next.future;
        },
      );
      addTearDown(bloc.close);
      final first = bloc.refresh();
      await Future<void>.delayed(Duration.zero);
      bloc.add(const FolderShelfEnterFolder('new-scope'));
      await Future<void>.delayed(Duration.zero);
      expect(await first, isFalse);
      final current = bloc.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(paths, ['', 'new-scope']);
      next.complete(_empty());
      expect(await current, isTrue);
      old.complete({'error': 'stale read must not replace new success'});
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.currentPath, 'new-scope');
      expect(bloc.state.error, isNull);
      expect(bloc.state.isLoading, isFalse);
    },
  );

  test(
    'folder navigation and pull refresh retain a pending search and source',
    () async {
      const previous = SearchStatusState(keyword: 'before', sources: ['old']);
      const desired = SearchStatusState(keyword: 'needle', sources: ['new']);
      final requests = <Map<String, dynamic>>[];
      final reads = <Completer<Map<String, dynamic>>>[];
      final bloc = FolderShelfBloc(
        mode: ShelfPageMode.favorite,
        loadTask: (payload) {
          requests.add(payload);
          final read = Completer<Map<String, dynamic>>();
          reads.add(read);
          return read.future;
        },
      );
      addTearDown(() async {
        for (final read in reads) {
          if (!read.isCompleted) read.complete(_empty());
        }
        await bloc.close();
      });
      bloc.add(const FolderShelfLoadRequested(search: previous));
      await Future<void>.delayed(Duration.zero);
      reads[0].complete(_empty());
      await Future<void>.delayed(Duration.zero);

      bloc.add(const FolderShelfLoadRequested(search: desired));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const FolderShelfEnterFolder('/next'));
      await Future<void>.delayed(Duration.zero);
      final pull = bloc.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(requests, hasLength(3));
      expect(requests.last['currentPath'], '/next');
      expect(requests.last['keyword'], 'needle');
      expect(requests.last['sources'], ['new']);

      reads[2].complete(_empty());
      expect(await pull, isTrue);
      reads[1].complete({'error': 'stale root result'});
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.search, desired);
      expect(bloc.state.error, isNull);
    },
  );
}
