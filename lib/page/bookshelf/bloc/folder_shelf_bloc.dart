import 'dart:async';
import 'package:zephyr/service/known_comic_metadata.dart';
import 'package:zephyr/util/text/public_search_text.dart';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show listEquals;

import 'package:bloc/bloc.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:worker_manager/worker_manager.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/object_box/object_box.dart';
import 'package:zephyr/service/reader/reader_history_service.dart';
import 'package:zephyr/page/bookshelf/cubit/search_status.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';
import 'package:zephyr/page/bookshelf/service/shelf_facet_adapters.dart';
import 'package:zephyr/page/bookshelf/service/comic_folder_service.dart';
import 'package:zephyr/page/bookshelf/service/comic_link_service.dart';
import 'package:zephyr/util/rust_loader.dart';
import 'package:zephyr/util/worker_isolate.dart';
import 'package:zephyr/page/bookshelf/bloc/folder_shelf_event.dart';
import 'package:zephyr/page/bookshelf/bloc/folder_shelf_state.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry_info.dart';
export 'package:zephyr/page/bookshelf/bloc/folder_shelf_event.dart';
export 'package:zephyr/page/bookshelf/bloc/folder_shelf_state.dart';

/// Test-only worker database root; production keeps the normal app directory.
String? debugShelfDbRootPath;

class _ShelfLoad {
  _ShelfLoad(this.scope);
  final Object scope;
  final result = Completer<bool>();
  bool manual = false;
  void finish(bool committed) {
    if (!result.isCompleted) {
      result.complete(committed);
    }
  }
}

class FolderShelfBloc extends Bloc<FolderShelfEvent, FolderShelfState> {
  FolderShelfBloc({
    required ShelfPageMode mode,
    this.loadTask,
    bool active = true,
    KeywordSearchScope keywordScope = KeywordSearchScope.all,
  }) : _keywordScope = keywordScope,
       _active = active,
       super(FolderShelfState(mode: mode)) {
    on<FolderShelfLoadRequested>(_onLoadRequested);
    on<FolderShelfSetFacets>((event, emit) {
      _advanceEpoch();
      emit(
        state.copyWith(
          facets: shelfFacetSelectionForScope(
            event.selection,
            currentFolder: state.mode == ShelfPageMode.history
                ? null
                : state.currentPath,
          ),
          selectionMode: false,
          isLoading: true,
          selectedComicKeys: {},
          selectedFolderPaths: {},
        ),
      );
      add(const FolderShelfLoadRequested());
    });
    on<FolderShelfEnterFolder>(_onEnterFolder);
    on<FolderShelfGoBack>(_onGoBack);
    on<FolderShelfGoHome>(_onGoHome);
    on<FolderShelfToggleSort>(_onToggleSort);
    on<FolderShelfCreateFolder>(_onCreateFolder);
    on<FolderShelfDeleteFolder>(_onDeleteFolder);
    on<FolderShelfRenameFolder>(_onRenameFolder);
    on<FolderShelfEnterSelectionMode>(_onEnterSelectionMode);
    on<FolderShelfExitSelectionMode>(_onExitSelectionMode);
    on<FolderShelfToggleFolderSelection>(_onToggleFolderSelection);
    on<FolderShelfToggleComicSelection>(_onToggleComicSelection);
    on<FolderShelfSelectAll>(_onSelectAll);
    on<FolderShelfClearSelection>(
      (event, emit) => emit(
        state.copyWith(
          selectedFolderPaths: const <String>{},
          selectedComicKeys: const <String>{},
          error: null,
        ),
      ),
    );
    on<FolderShelfMoveSelected>(_onMoveSelected);
    on<FolderShelfCopySelected>(_onCopySelected);
    on<FolderShelfDeleteSelected>(_onDeleteSelected);
    final watched = switch (mode) {
      ShelfPageMode.favorite => {UnifiedComicFavorite, ComicLink, ComicFolder},
      ShelfPageMode.history => {UnifiedComicHistory},
      ShelfPageMode.download => {UnifiedComicDownload, ComicLink, ComicFolder},
    };
    _storageWatch = objectbox.store.entityChanges.listen((types) {
      if (!types.any(watched.contains)) return;
      _storageRevision++;
      _storageDirty = true;
      _scheduleStorageReload();
    });
  }

  late final StreamSubscription<List<Type>> _storageWatch;
  final _quietLoads = HashSet<FolderShelfLoadRequested>.identity();
  bool _storageScheduled = false, _storageDirty = false, _closing = false;
  bool _active;
  int _storageRevision = 0;

  void setStorageActive(bool active) {
    _active = active;
    _scheduleStorageReload();
  }

  void _scheduleStorageReload() {
    if (isClosed ||
        _closing ||
        !_active ||
        !_storageDirty ||
        _storageScheduled ||
        _activeLoads.isNotEmpty ||
        _preparedLoads.isNotEmpty) {
      return;
    }
    _storageScheduled = true;
    scheduleMicrotask(() {
      if (isClosed || _closing) return;
      if (!_active) {
        _storageScheduled = false;
        return;
      }
      final event = FolderShelfLoadRequested.new();
      if (!state.isLoading) _quietLoads.add(event);
      add(event);
    });
  }

  ComicFolderType get _folderType => _toFolderType(state.mode);
  int _loadEpoch = 0;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)? loadTask;
  final _preparedLoads =
      HashMap<FolderShelfLoadRequested, _ShelfLoad>.identity();
  final _activeLoads = <_ShelfLoad>{};
  // Committed rows keep state.search until the new snapshot is ready.
  SearchStatusState? _requestedSearch;
  KeywordSearchScope _keywordScope;
  Object? _loadedScope;

  /// The rows can stay visible while another scope is loading.
  Object? get loadedScope => _loadedScope;
  bool get hasCurrentSnapshot => _loadedScope == _scope;

  Object get _scope => (
    state.mode,
    state.currentPath,
    _requestedSearch,
    state.facets,
    _scopeFor(_requestedSearch),
  );

  KeywordSearchScope? _scopeFor(SearchStatusState? search) =>
      search?.keyword.trim().isNotEmpty == true ? _keywordScope : null;

  void setKeywordScope(KeywordSearchScope scope) {
    if (_keywordScope == scope) return;
    _keywordScope = scope;
    if (_scopeFor(_requestedSearch) != null) _advanceEpoch();
  }

  int _advanceEpoch({_ShelfLoad? keep}) {
    for (final load in [..._preparedLoads.values, ..._activeLoads]) {
      if (!identical(load, keep)) load.finish(false);
    }
    return ++_loadEpoch;
  }

  /// Completes after this local DB snapshot is committed, not after add().
  /// Concurrent pulls join the same scope; navigation invalidates its waiter.
  Future<bool> refresh() {
    if (isClosed) {
      return Future.value(false);
    }
    for (final load in [..._preparedLoads.values, ..._activeLoads]) {
      if (load.scope == _scope && !load.result.isCompleted) {
        load.manual = true;
        return load.result.future;
      }
    }
    final event = FolderShelfLoadRequested(search: _requestedSearch);
    final load = _ShelfLoad(_scope)..manual = true;
    _preparedLoads[event] = load;
    add(event);
    return load.result.future;
  }

  @override
  Future<void> close() async {
    _closing = true;
    _advanceEpoch();
    await _storageWatch.cancel();
    await super.close();
  }

  static ComicFolderType _toFolderType(ShelfPageMode mode) {
    return switch (mode) {
      ShelfPageMode.favorite => ComicFolderType.favorite,
      ShelfPageMode.history => ComicFolderType.history,
      ShelfPageMode.download => ComicFolderType.download,
    };
  }

  Future<void> _onLoadRequested(
    FolderShelfLoadRequested event,
    Emitter<FolderShelfState> emit,
  ) async {
    _storageScheduled = false;
    final quiet = _quietLoads.remove(event);
    final prepared = _preparedLoads.remove(event);
    if (prepared != null &&
        (prepared.result.isCompleted || prepared.scope != _scope)) {
      prepared.finish(false);
      return;
    }
    final previousSearch = _requestedSearch;
    final search = event.search ?? previousSearch;
    final facets =
        previousSearch != null &&
            search != null &&
            !listEquals(previousSearch.sources, search.sources)
        ? const ShelfFacetSelection()
        : state.facets;
    _requestedSearch = search;
    final currentMode = state.mode;
    final currentPath = state.currentPath;
    final keywordScope = _scopeFor(search);
    final load =
        prepared ??
        _ShelfLoad((currentMode, currentPath, search, facets, keywordScope));
    _activeLoads.add(load);
    final epoch = _advanceEpoch(keep: load);
    if (!quiet)
      emit(state.copyWith(isLoading: true, error: null, facets: facets));
    try {
      if (!quiet && !load.manual && loadTask == null) {
        await restoreKnownComicMetadata(kind: currentMode.name);
      }
      if (emit.isDone || epoch != _loadEpoch) return;
      final token = captureWorkerIsolateToken();
      final payload = {
        'mode': currentMode.name,
        'currentPath': currentPath,
        'dbRootPath': debugShelfDbRootPath,
        'keyword': search?.keyword ?? '',
        'keywordScope': keywordScope?.name,
        'sort': search?.sort ?? 'dd',
        'sources': search?.sources ?? const <String>[],
        'facets': facets,
      };
      final storageRevision = _storageRevision;
      _storageDirty = false;
      final result =
          await (loadTask?.call(payload) ??
              workerManager.execute<Map<String, dynamic>>(
                () => _runFolderShelfLoadTask(payload, token),
              ));
      if (emit.isDone ||
          epoch != _loadEpoch ||
          storageRevision != _storageRevision)
        return;

      final error = result['error']?.toString() ?? '';
      if (error.isNotEmpty) {
        throw Exception(error);
      }

      final comics = result['comics'] as List<ComicSimplifyEntryInfo>;
      final visibleKeys = comics
          .map((comic) => '${comic.from.trim()}:${comic.id}')
          .toSet();
      final folders = result['folders'] as List<ComicFolder>;
      final syncIdMap = _buildSyncIdMap(_folderType);
      final visibleFolderPaths = folders
          .map(
            (folder) =>
                ComicFolderService.folderPath(folder, syncIdMap: syncIdMap),
          )
          .toSet();

      _loadedScope = (currentMode, currentPath, search, facets, keywordScope);
      emit(
        state.copyWith(
          folders: folders,
          folderCounts:
              (result['folderCounts'] as Map?)
                  ?.cast<String, ComicShelfFolderCount>() ??
              const {},
          comics: comics,
          selectedComicKeys: state.selectedComicKeys.intersection(visibleKeys),
          selectedFolderPaths: state.selectedFolderPaths.intersection(
            visibleFolderPaths,
          ),
          comicSearchTexts:
              (result['comicSearchTexts'] as Map?)?.cast<String, String>() ??
              const <String, String>{},
          comicFolderLabels:
              (result['comicFolderLabels'] as Map?)?.cast<String, String>() ??
              const {},
          search: search,
          sortAscending: search?.sort == 'da',
          isLoading: false,
          error: null,
        ),
      );
      load.finish(true);
    } catch (e) {
      if (emit.isDone || epoch != _loadEpoch) return;
      if (!quiet || load.manual) {
        emit(state.copyWith(isLoading: false, error: e.toString()));
      }
    } finally {
      load.finish(false);
      _activeLoads.remove(load);
      _scheduleStorageReload();
    }
  }

  /// 历史无文件夹：导航/文件夹变更事件直接忽略（历史恒为根目录）。
  bool get _isHistoryMode => state.mode == ShelfPageMode.history;

  bool get _showsWorkResults =>
      state.facets.isActive ||
      (state.search?.keyword.trim().isNotEmpty ?? false);

  ShelfFacetSelection get _resultScope => state.facets.isActive
      ? state.facets
      : const ShelfFacetSelection(scope: ShelfFacetScope.all);

  Set<String> get _selectedVisibleComics =>
      state.selectedComicKeys.intersection({
        for (final comic in state.comics) '${comic.from.trim()}:${comic.id}',
      });

  Set<String> get _visibleFolderPaths {
    final syncIdMap = _buildSyncIdMap(_folderType);
    return {
      for (final folder in state.folders)
        ComicFolderService.folderPath(folder, syncIdMap: syncIdMap),
    };
  }

  Set<String> get _selectedVisibleFolders =>
      state.selectedFolderPaths.intersection(_visibleFolderPaths);

  Future<void> _onEnterFolder(
    FolderShelfEnterFolder event,
    Emitter<FolderShelfState> emit,
  ) async {
    if (_isHistoryMode) return;
    _advanceEpoch();
    emit(
      state.copyWith(
        currentPath: event.path,
        isLoading: true,
        error: null,
        facets: const ShelfFacetSelection(),
      ),
    );
    add(const FolderShelfLoadRequested());
  }

  Future<void> _onGoBack(
    FolderShelfGoBack event,
    Emitter<FolderShelfState> emit,
  ) async {
    if (state.isRoot) return;
    final lastIndex = state.currentPath.lastIndexOf('/');
    final parentPath = lastIndex <= 0
        ? kFolderShelfRootPath
        : state.currentPath.substring(0, lastIndex);
    _advanceEpoch();
    emit(
      state.copyWith(
        currentPath: parentPath,
        isLoading: true,
        error: null,
        facets: const ShelfFacetSelection(),
      ),
    );
    add(const FolderShelfLoadRequested());
  }

  Future<void> _onGoHome(
    FolderShelfGoHome event,
    Emitter<FolderShelfState> emit,
  ) async {
    if (state.isRoot) return;
    _advanceEpoch();
    emit(
      state.copyWith(
        currentPath: kFolderShelfRootPath,
        isLoading: true,
        error: null,
        facets: const ShelfFacetSelection(),
      ),
    );
    add(const FolderShelfLoadRequested());
  }

  Future<void> _onToggleSort(
    FolderShelfToggleSort event,
    Emitter<FolderShelfState> emit,
  ) async {
    emit(state.copyWith(sortAscending: !state.sortAscending, error: null));
    add(const FolderShelfLoadRequested());
  }

  Future<void> _onCreateFolder(
    FolderShelfCreateFolder event,
    Emitter<FolderShelfState> emit,
  ) async {
    if (_isHistoryMode) return;
    try {
      ComicFolderService.createFolder(
        state.currentPath,
        event.name,
        _folderType,
      );
      _completed(emit, t.bookshelf.folderCreated);
      add(const FolderShelfLoadRequested());
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onDeleteFolder(
    FolderShelfDeleteFolder event,
    Emitter<FolderShelfState> emit,
  ) async {
    if (_isHistoryMode) return;
    try {
      ComicFolderService.deleteFolder(event.path, _folderType);
      ComicLinkService.removeLinksInFolderTree(event.path, _folderType);
      _completed(emit, t.bookshelf.actionRemoved);
      add(const FolderShelfLoadRequested());
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onRenameFolder(
    FolderShelfRenameFolder event,
    Emitter<FolderShelfState> emit,
  ) async {
    if (_isHistoryMode) return;
    try {
      ComicFolderService.renameFolder(event.path, event.newName, _folderType);
      _completed(emit, t.bookshelf.actionRenamed);
      add(const FolderShelfLoadRequested());
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onEnterSelectionMode(
    FolderShelfEnterSelectionMode event,
    Emitter<FolderShelfState> emit,
  ) async {
    emit(state.copyWith(selectionMode: true, error: null));
  }

  Future<void> _onExitSelectionMode(
    FolderShelfExitSelectionMode event,
    Emitter<FolderShelfState> emit,
  ) async {
    emit(
      state.copyWith(
        selectionMode: false,
        selectedFolderPaths: const <String>{},
        selectedComicKeys: const <String>{},
        error: null,
      ),
    );
  }

  Future<void> _onToggleFolderSelection(
    FolderShelfToggleFolderSelection event,
    Emitter<FolderShelfState> emit,
  ) async {
    if (_isHistoryMode ||
        state.isLoading ||
        !_visibleFolderPaths.contains(event.path)) {
      return;
    }
    final selected = Set<String>.from(state.selectedFolderPaths);
    if (selected.contains(event.path)) {
      selected.remove(event.path);
    } else {
      selected.add(event.path);
    }
    emit(
      state.copyWith(
        selectionMode: true,
        selectedFolderPaths: selected,
        error: null,
      ),
    );
  }

  Future<void> _onToggleComicSelection(
    FolderShelfToggleComicSelection event,
    Emitter<FolderShelfState> emit,
  ) async {
    if (state.isLoading ||
        !state.comics.any(
          (comic) => '${comic.from.trim()}:${comic.id}' == event.comicUniqueKey,
        )) {
      return;
    }
    final selected = Set<String>.from(state.selectedComicKeys);
    if (selected.contains(event.comicUniqueKey)) {
      selected.remove(event.comicUniqueKey);
    } else {
      selected.add(event.comicUniqueKey);
    }
    emit(
      state.copyWith(
        selectionMode: true,
        selectedComicKeys: selected,
        error: null,
      ),
    );
  }

  Future<void> _onSelectAll(
    FolderShelfSelectAll event,
    Emitter<FolderShelfState> emit,
  ) async {
    if (state.isLoading) return;
    final allComics = state.comics
        .map((c) => '${c.from.trim()}:${c.id}')
        .toSet();
    // 历史无文件夹，全选只选中漫画。
    final allFolders = _isHistoryMode
        ? <String>{}
        : state.folders
              .map(
                (f) => ComicFolderService.folderPath(
                  f,
                  syncIdMap: _buildSyncIdMap(_folderType),
                ),
              )
              .toSet();
    emit(
      state.copyWith(
        selectionMode: true,
        selectedFolderPaths: allFolders,
        selectedComicKeys: allComics,
        error: null,
      ),
    );
  }

  Map<String, ComicFolder> _buildSyncIdMap(ComicFolderType type) {
    final all = ComicFolderService.listAllFolders(type);
    return {for (final folder in all) folder.syncId: folder};
  }

  Future<void> _onMoveSelected(
    FolderShelfMoveSelected event,
    Emitter<FolderShelfState> emit,
  ) async {
    if (_isHistoryMode || state.isLoading) return;
    try {
      final comicKeys = _selectedVisibleComics;
      final targetPaths = event.targetPaths;
      final sourceFolderPaths =
          (event.sourceFolderPaths ?? _selectedVisibleFolders).intersection(
            _visibleFolderPaths,
          );
      if (sourceFolderPaths.isNotEmpty && targetPaths.length > 1) {
        throw StateError(t.bookshelf.moveFoldersOnlyOneTarget);
      }
      for (final targetPath in targetPaths) {
        if (sourceFolderPaths.isNotEmpty) {
          ComicFolderService.batchMoveFolders(
            sourceFolderPaths,
            targetPath,
            _folderType,
          );
        }
      }
      if (comicKeys.isNotEmpty && targetPaths.isNotEmpty) {
        final index = loadComicShelfFacetIndex(type: _folderType);
        for (final key in comicKeys) {
          moveComicFromFacetScope(
            key,
            _showsWorkResults ? _resultScope : const ShelfFacetSelection(),
            targetPaths,
            currentFolder: state.currentPath,
            snapshot: index,
            type: _folderType,
          );
        }
      }
      _completed(emit, t.bookshelf.actionMoved);
      _exitSelectionAndRefresh();
    } catch (e) {
      emit(state.copyWith(error: e is StateError ? e.message : e.toString()));
    }
  }

  Future<void> _onCopySelected(
    FolderShelfCopySelected event,
    Emitter<FolderShelfState> emit,
  ) async {
    if (_isHistoryMode || state.isLoading) return;
    try {
      final comicKeys = _selectedVisibleComics;
      final folderPaths = _selectedVisibleFolders;
      final index = loadComicShelfFacetIndex(type: _folderType);
      objectbox.store.runInTransaction(TxMode.write, () {
        for (final targetPath in event.targetPaths) {
          ComicFolderService.batchCopyFolders(
            folderPaths,
            targetPath,
            _folderType,
          );
        }
        for (final key in comicKeys) {
          copyComicFromFacetIndex(
            key,
            event.targetPaths,
            snapshot: index,
            type: _folderType,
          );
        }
      });
      _completed(emit, t.bookshelf.actionCopied);
      _exitSelectionAndRefresh();
    } catch (e) {
      emit(state.copyWith(error: e is StateError ? e.message : e.toString()));
    }
  }

  Future<void> _onDeleteSelected(
    FolderShelfDeleteSelected event,
    Emitter<FolderShelfState> emit,
  ) async {
    if (!state.hasSelection || state.isLoading) return;
    try {
      final comicKeys = _selectedVisibleComics;
      final folderPaths = _selectedVisibleFolders;
      // 历史无 ComicLink：直接软删除历史本体（与旧 LocalShelfPage 一致）。
      if (_isHistoryMode) {
        await _deleteHistoryComics(comicKeys);
        _completed(emit, t.bookshelf.actionRemoved);
        _exitSelectionAndRefresh();
        return;
      }
      ComicFolderService.batchDeleteFolders(folderPaths, _folderType);
      for (final folderPath in folderPaths) {
        ComicLinkService.removeLinksInFolderTree(folderPath, _folderType);
      }
      final snapshot = loadComicShelfFacetIndex(type: _folderType);
      for (final key in comicKeys) {
        removeComicFromFacetScope(
          key,
          _showsWorkResults ? _resultScope : const ShelfFacetSelection(),
          currentFolder: state.currentPath,
          snapshot: snapshot,
          type: _folderType,
        );
      }
      _completed(emit, t.bookshelf.actionRemoved);
      _exitSelectionAndRefresh();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  /// 批量软删除历史记录。调用方保证只传历史 uniqueKey。
  Future<void> _deleteHistoryComics(Set<String> comicUniqueKeys) async {
    if (comicUniqueKeys.isEmpty) return;
    final snapshot = loadComicShelfFacetIndex(type: ComicFolderType.history);
    for (final uniqueKey in {
      for (final key in comicUniqueKeys) ...comicFacetRecordKeys(snapshot, key),
    }) {
      final query = objectbox.unifiedHistoryBox
          .query(UnifiedComicHistory_.uniqueKey.equals(uniqueKey))
          .build();
      try {
        final history = query.findFirst();
        if (history != null) {
          await ReaderHistoryService.instance.deleteHistoryRecord(history);
        }
      } finally {
        query.close();
      }
    }
  }

  void _completed(Emitter<FolderShelfState> emit, String message) {
    emit(
      state.copyWith(
        actionMessage: message,
        actionRevision: state.actionRevision + 1,
        error: null,
      ),
    );
  }

  void _exitSelectionAndRefresh() {
    add(const FolderShelfExitSelectionMode());
    add(const FolderShelfLoadRequested());
  }
}

Future<Map<String, dynamic>> _runFolderShelfLoadTask(
  Map<String, dynamic> payload,
  RootIsolateToken? token,
) async {
  try {
    ensureWorkerIsolateInitialized(token);
    await initRustLib(silent: true);
    objectbox = await ObjectBox.create(
      dbRootPath: payload['dbRootPath'] as String?,
    );

    final mode = ShelfPageMode.values.byName(payload['mode'] as String);
    final folderType = FolderShelfBloc._toFolderType(mode);
    final currentPath = payload['currentPath'] as String;
    final keyword = payload['keyword']?.toString() ?? '';
    final titleOnly =
        parseKeywordSearchScope(payload['keywordScope']) ==
        KeywordSearchScope.title;
    final sort = payload['sort']?.toString() ?? 'dd';
    final sources =
        (payload['sources'] as List?)?.cast<String>() ?? const <String>[];
    final search = SearchStatusState(
      keyword: keyword,
      sort: sort,
      sources: sources,
    );

    final sortAscending = sort == 'da';
    final sortByViewTime =
        (mode == ShelfPageMode.favorite || mode == ShelfPageMode.download) &&
        (sort == 'vd' || sort == 'va');
    final viewTimes = <String, DateTime>{
      if (sortByViewTime)
        for (final history in objectbox.unifiedHistoryBox.getAll().where(
          (history) => !history.deleted,
        ))
          history.uniqueKey: history.lastReadAt,
    };
    final itemTimes = <String, DateTime>{};
    if (sortByViewTime) {
      if (mode == ShelfPageMode.favorite) {
        for (final favorite in objectbox.unifiedFavoriteBox.getAll().where(
          (favorite) => !favorite.deleted,
        )) {
          itemTimes[favorite.uniqueKey] = favorite.createdAt;
        }
      } else {
        for (final download in objectbox.unifiedDownloadBox.getAll().where(
          (download) => !download.deleted,
        )) {
          itemTimes[download.uniqueKey] = download.downloadedAt;
        }
      }
    }
    final sourceFilter = _sourceFilterFromSearch(search);

    final facets =
        payload['facets'] as ShelfFacetSelection? ??
        const ShelfFacetSelection();
    if (facets.isActive || keyword.trim().isNotEmpty) {
      // Keyword-only lookup has always spanned all folders. Use the same
      // public-metadata snapshot and scope for its display and management.
      final resultScope = facets.isActive
          ? facets
          : const ShelfFacetSelection(scope: ShelfFacetScope.all);
      final index = loadComicShelfFacetIndex(type: folderType);
      final query = _normalizeSearchText(keyword);
      final matching = index.entries
          .where(
            (entry) =>
                (sourceFilter == null || sourceFilter.contains(entry.source)) &&
                (query.isEmpty ||
                    (titleOnly
                            ? _normalizeSearchText(
                                index.comics[entry.key]?.title ?? '',
                              )
                            : entry.searchText)
                        .contains(query)) &&
                shelfFacetMatches(
                  entry,
                  resultScope,
                  currentFolder: mode == ShelfPageMode.history
                      ? null
                      : currentPath,
                ),
          )
          .toList();
      final keys = matching.map((entry) => entry.key).toSet();
      final comics = index.comics.entries
          .where((entry) => keys.contains(entry.key))
          .map((entry) => entry.value)
          .toList();
      if (sortByViewTime) {
        _sortShelfItemsByViewTime(
          comics,
          viewTimes: viewTimes,
          itemTimes: itemTimes,
          ascending: sort == 'va',
        );
      } else {
        final times = index.sortTimes;
        comics.sort((a, b) {
          final first =
              times['${a.from.trim()}:${a.id}'] ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final second =
              times['${b.from.trim()}:${b.id}'] ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final compared = first.compareTo(second);
          return compared == 0
              ? '${a.from}:${a.id}'.compareTo('${b.from}:${b.id}')
              : sortAscending
              ? compared
              : -compared;
        });
      }
      return {
        'folders': <ComicFolder>[],
        'comics': comics,
        'comicSearchTexts': {
          for (final entry in matching) entry.key: entry.searchText,
        },
        'comicFolderLabels': {
          for (final entry in matching)
            entry.key:
                (entry.folders
                        .map((path) => index.folderLabels[path] ?? path)
                        .toList()
                      ..sort())
                    .join(' · '),
        },
      };
    }

    // 历史无文件夹体系：直读历史表，按更新时间排序。
    if (mode == ShelfPageMode.history) {
      return _loadHistoryShelf(
        sortAscending: sortAscending,
        keyword: keyword,
        sourceFilter: sourceFilter,
      );
    }

    return objectbox.store.runInTransaction<Map<String, dynamic>>(
      TxMode.read,
      () {
        final folders = ComicFolderService.listChildFolders(
          currentPath,
          folderType,
          sortAscending: sortAscending,
        );
        final links = ComicLinkService.listLinks(
          currentPath.isEmpty ? null : currentPath,
          folderType,
          sortAscending: sortAscending,
        );

        final comics = <ComicSimplifyEntryInfo>[];
        final comicSearchTexts = <String, String>{};
        final seenKeys = <String>{};
        for (final link in links) {
          final resolved = _resolveComic(link.comicUniqueKey, folderType);
          if (resolved == null) continue;
          if (sourceFilter != null &&
              !sourceFilter.contains(resolved.info.source.trim())) {
            continue;
          }
          final key = '${resolved.info.from.trim()}:${resolved.info.id}';
          if (!seenKeys.add(key)) continue;
          comics.add(resolved.info);
          comicSearchTexts[key] = resolved.searchText;
        }
        if (sortByViewTime) {
          _sortShelfItemsByViewTime(
            comics,
            viewTimes: viewTimes,
            itemTimes: itemTimes,
            ascending: sort == 'va',
          );
        }

        return {
          'folders': folders,
          if (mode == ShelfPageMode.favorite)
            'folderCounts': _favoriteFolderCounts(folders, sourceFilter),
          'comics': comics,
          'comicSearchTexts': comicSearchTexts,
        };
      },
    );
  } catch (e) {
    return {
      'error': e.toString(),
      'folders': <ComicFolder>[],
      'comics': <ComicSimplifyEntryInfo>[],
      'comicSearchTexts': <String, String>{},
    };
  }
}

/// Direct memberships only, from the same database snapshot as the visible
/// folders. Batch by stable folder ID so opening a large shelf adds no per-row
/// database reads or public metadata parsing.
Map<String, ComicShelfFolderCount> _favoriteFolderCounts(
  List<ComicFolder> folders,
  Set<String>? sources,
) {
  if (folders.isEmpty) return const {};
  final ids = folders.map((folder) => folder.syncId).toList();
  const type = ComicFolderType.favorite;
  final childrenQuery = objectbox.comicFolderBox
      .query(
        ComicFolder_.typeData
            .equals(type.name)
            .and(ComicFolder_.deletedAt.isNull())
            .and(ComicFolder_.parentSyncId.oneOf(ids)),
      )
      .build();
  final childCounts = <String, int>{};
  try {
    for (final child in childrenQuery.find()) {
      childCounts.update(child.parentSyncId!, (n) => n + 1, ifAbsent: () => 1);
    }
  } finally {
    childrenQuery.close();
  }

  final linksQuery = objectbox.comicLinkBox
      .query(
        ComicLink_.typeData
            .equals(type.name)
            .and(ComicLink_.deletedAt.isNull())
            .and(ComicLink_.folderSyncId.oneOf(ids)),
      )
      .build();
  final List<ComicLink> links;
  try {
    links = linksQuery.find();
  } finally {
    linksQuery.close();
  }
  final keys = links.map((link) => link.comicUniqueKey).toSet();
  final liveWorks = <String, (String, String)>{};
  if (keys.isNotEmpty) {
    final query = objectbox.unifiedFavoriteBox
        .query(
          UnifiedComicFavorite_.deleted
              .equals(false)
              .and(UnifiedComicFavorite_.uniqueKey.oneOf(keys.toList())),
        )
        .build();
    try {
      for (final row in query.find()) {
        final source = row.source.trim();
        if (sources == null || sources.contains(source)) {
          liveWorks[row.uniqueKey] = (source, row.comicId);
        }
      }
    } finally {
      query.close();
    }
  }
  final worksByFolder = <String, Set<(String, String)>>{};
  for (final link in links) {
    final work = liveWorks[link.comicUniqueKey];
    if (work != null) {
      worksByFolder.putIfAbsent(link.folderSyncId!, () => {}).add(work);
    }
  }
  return {
    for (final id in ids)
      id: (
        works: worksByFolder[id]?.length ?? 0,
        subfolders: childCounts[id] ?? 0,
      ),
  };
}

/// 历史无文件夹体系：直接查询历史表，按 updatedAt 排序（与旧 LocalShelfPage 一致）。
Map<String, dynamic> _loadHistoryShelf({
  required bool sortAscending,
  required String keyword,
  required Set<String>? sourceFilter,
}) {
  final condition = UnifiedComicHistory_.deleted.equals(false);
  final query = objectbox.unifiedHistoryBox
      .query(condition)
      .order(
        UnifiedComicHistory_.updatedAt,
        flags: sortAscending ? 0 : Order.descending,
      )
      .build();
  try {
    final isSearching = keyword.trim().isNotEmpty;
    final normalizedKeyword = isSearching ? _normalizeSearchText(keyword) : '';
    final comics = <ComicSimplifyEntryInfo>[];
    final comicSearchTexts = <String, String>{};
    for (final history in query.find()) {
      if (sourceFilter != null &&
          !sourceFilter.contains(history.source.trim())) {
        continue;
      }
      final info = unifiedComicFromUnifiedHistory(
        history,
      ).toSimplifyEntryInfo();
      final key = '${info.from.trim()}:${info.id}';
      final searchText = _buildComicSearchText(history);
      if (isSearching && !searchText.contains(normalizedKeyword)) {
        continue;
      }
      comics.add(info);
      comicSearchTexts[key] = searchText;
    }
    return {
      'folders': <ComicFolder>[],
      'comics': comics,
      'comicSearchTexts': comicSearchTexts,
    };
  } finally {
    query.close();
  }
}

void _sortShelfItemsByViewTime(
  List<ComicSimplifyEntryInfo> items, {
  required Map<String, DateTime> viewTimes,
  required Map<String, DateTime> itemTimes,
  required bool ascending,
}) {
  items.sort((left, right) {
    final leftKey = '${left.from.trim()}:${left.id}';
    final rightKey = '${right.from.trim()}:${right.id}';
    final leftViewTime = viewTimes[leftKey];
    final rightViewTime = viewTimes[rightKey];

    // 未观看的条目没有可比较的观看时间，始终放在已观看项目之后。
    if (leftViewTime == null && rightViewTime != null) return 1;
    if (leftViewTime != null && rightViewTime == null) return -1;
    if (leftViewTime != null && rightViewTime != null) {
      final result = leftViewTime.compareTo(rightViewTime);
      if (result != 0) return ascending ? result : -result;
    }

    final leftItemTime = itemTimes[leftKey];
    final rightItemTime = itemTimes[rightKey];
    if (leftItemTime != null && rightItemTime != null) {
      final result = leftItemTime.compareTo(rightItemTime);
      if (result != 0) return ascending ? result : -result;
    }
    return leftKey.compareTo(rightKey);
  });
}

Set<String>? _sourceFilterFromSearch(SearchStatusState? search) {
  if (search == null) return null;
  final cleaned = search.sources
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet();
  if (cleaned.isEmpty) return null;
  return cleaned;
}

({ComicSimplifyEntryInfo info, String searchText})? _resolveComic(
  String uniqueKey,
  ComicFolderType folderType,
) {
  switch (folderType) {
    case ComicFolderType.favorite:
      final comic = _findFirstAndClose(
        objectbox.unifiedFavoriteBox
            .query(
              UnifiedComicFavorite_.uniqueKey
                  .equals(uniqueKey)
                  .and(UnifiedComicFavorite_.deleted.equals(false)),
            )
            .build(),
      );
      if (comic == null) return null;
      return (
        info: unifiedComicFromUnifiedFavorite(comic).toSimplifyEntryInfo(),
        searchText: _buildComicSearchText(comic),
      );
    case ComicFolderType.download:
      final comic = _findFirstAndClose(
        objectbox.unifiedDownloadBox
            .query(
              UnifiedComicDownload_.uniqueKey
                  .equals(uniqueKey)
                  .and(UnifiedComicDownload_.deleted.equals(false)),
            )
            .build(),
      );
      if (comic == null) return null;
      return (
        info: unifiedComicFromUnifiedDownload(comic).toSimplifyEntryInfo(),
        searchText: _buildComicSearchText(comic),
      );
    case ComicFolderType.history:
      final comic = _findFirstAndClose(
        objectbox.unifiedHistoryBox
            .query(
              UnifiedComicHistory_.uniqueKey
                  .equals(uniqueKey)
                  .and(UnifiedComicHistory_.deleted.equals(false)),
            )
            .build(),
      );
      if (comic == null) return null;
      return (
        info: unifiedComicFromUnifiedHistory(comic).toSimplifyEntryInfo(),
        searchText: _buildComicSearchText(comic),
      );
  }
}

T? _findFirstAndClose<T>(Query<T> query) {
  try {
    return query.findFirst();
  } finally {
    query.close();
  }
}

String _buildComicSearchText(dynamic comic) {
  final text = [
    comic.comicId?.toString() ?? '',
    comic.title?.toString() ?? '',
    comic.description?.toString() ?? '',
    _creatorName(comic.creator?.toString() ?? ''),
    comic.titleMeta?.toString() ?? '',
    ...shelfFacetFieldsFromMetadata(
      comic.metadata?.toString() ?? '',
    ).values.expand((values) => values),
    comic.source?.toString() ?? '',
  ].join();
  return _normalizeSearchText(text);
}

String _creatorName(String raw) {
  if (raw.trim().isEmpty) return '';
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) return decoded['name']?.toString() ?? '';
  } catch (_) {}
  return '';
}

String _normalizeSearchText(String text) => normalizePublicSearchText(text);
