import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/widget/keyword_scope_menu.dart';
import 'package:collection/collection.dart';
import 'package:zephyr/widgets/pull_refresh_feedback.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/page/search/widget/search_field_decoration.dart';
import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';
import 'package:zephyr/page/bookshelf/service/shelf_facet_adapters.dart';
import 'package:zephyr/page/bookshelf/service/video_bookshelf_index.dart';
import 'package:zephyr/page/bookshelf/widgets/shelf_filter_sheet.dart';
import 'package:zephyr/network/sync/sync_service.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/page/video/video_library_folder_picker.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/source_video_list_header.dart';
import 'package:zephyr/page/search/widget/search_keyboard.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_selection_toolbar.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_floating_selection_actions.dart';

class ApiVideoFavorites extends StatefulWidget {
  const ApiVideoFavorites({
    super.key,
    required this.source,
    required this.mode,
    required this.onOpen,
    this.store,
    this.repository,
    this.active = true,
    this.compact = false,
    this.onExplore,
    this.exploreLabel,
    this.onImportSite,
    this.loadDetail,
    this.onDetailLoaded,
    this.showFolders = false,
    this.compactHeader = false,
    this.onToggleView,
    this.headerLeading,
  });
  final Widget? headerLeading;
  final bool compactHeader;
  final VoidCallback? onToggleView;
  final String source;
  final bool showFolders;
  final ApiVideoView mode;
  final Future<void> Function(ApiVideoItem) onOpen;
  final VideoLibraryStore? store;
  final ApiVideoRepository? repository;
  final bool active;
  final bool compact;
  final VoidCallback? onExplore, onImportSite;
  final String? exploreLabel;
  final Future<ApiVideoItem> Function(ApiVideoItem)? loadDetail;
  final ValueChanged<ApiVideoItem>? onDetailLoaded;
  @override
  State<ApiVideoFavorites> createState() => _ApiVideoFavoritesState();
}

class _ApiVideoFavoritesState extends State<ApiVideoFavorites> {
  VideoLibraryStore get _store => widget.store ?? VideoLibraryStore.shared;
  String get _scopeKey =>
      '${widget.source}|${widget.repository?.home.origin ?? ''}|${widget.repository?.capabilities.itemNamespace ?? ''}';
  List<({String key, ApiVideoItem item, int clock})> _items(
    VideoLibrarySnapshot snapshot,
  ) => snapshot.itemsFor(widget.source, home: widget.repository?.home);

  VideoLibrarySnapshot? _snapshot;
  final _input = TextEditingController();
  final _searchFocus = FocusNode();
  final _selected = <String>{};
  String? _folder;
  String _query = '', _sort = 'recent';
  KeywordSearchScope _keywordScope = KeywordSearchScope.all;
  ShelfFacetSelection _facets = const ShelfFacetSelection();
  bool _openingFilters = false;
  bool _failed = false, _selecting = false, _working = false, _syncing = false;
  int _readEpoch = 0;
  bool _searching = false;
  String? _notice;
  Timer? _noticeTimer;
  int _noticeEpoch = 0;
  @override
  void initState() {
    super.initState();
    _store.addListener(_read);
    _searchFocus.addListener(_focusChanged);
    _read();
  }

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  void _cancelSelection() {
    _searchFocus.unfocus();
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  void _backWithinCollection() {
    if (_working) return;
    if (_searchFocus.hasFocus) {
      _searchFocus.unfocus();
    } else if (_selecting) {
      _cancelSelection();
    } else if (_folder != null) {
      setState(() => _folder = null);
    }
  }

  @override
  void didUpdateWidget(covariant ApiVideoFavorites oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.repository?.home.origin != widget.repository?.home.origin ||
        oldWidget.store != widget.store ||
        oldWidget.repository?.capabilities.itemNamespace !=
            widget.repository?.capabilities.itemNamespace) {
      (oldWidget.store ?? VideoLibraryStore.shared).removeListener(_read);
      _store.addListener(_read);
      _snapshot = null;
      _pullScope = null;
      _failedPullScope = null;
      _folder = null;
      _facets = const ShelfFacetSelection();
      _query = '';
      _keywordScope = KeywordSearchScope.all;
      _input.clear();
      _selected.clear();
      _selecting = false;
      _read();
    }
    if (!widget.showFolders) _folder = null;
    if (!widget.active && oldWidget.active) {
      _pullScope = null;
      _closeNotice(afterFrame: true);
    }
  }

  @override
  void dispose() {
    _closeNotice(afterFrame: true);
    _readEpoch++;
    _store.removeListener(_read);
    _input.dispose();
    _searchFocus.removeListener(_focusChanged);
    _searchFocus.dispose();
    super.dispose();
  }

  final _refreshIndicator = GlobalKey<RefreshIndicatorState>();
  int _imageRefreshToken = 0;
  Object? _pullScope, _failedPullScope;
  Future<void>? _readTask;

  Object get _refreshScope => (
    _scopeKey,
    _store,
    widget.showFolders,
    _folder,
    _query,
    _keywordScope,
    _sort,
    _facets,
  );

  Future<void> _read() {
    final task = _readNow();
    _readTask = task;
    return task.whenComplete(() {
      if (identical(_readTask, task)) {
        _readTask = null;
      }
    });
  }

  Future<PullRefreshResult> _refresh() async {
    final scope = _refreshScope;
    if (!widget.active || _working || _pullScope == scope) {
      return PullRefreshResult.ignored;
    }
    final before = _snapshot;
    setState(() => _pullScope = scope);
    try {
      var task = _readTask ?? _read();
      while (true) {
        await task;
        if (!mounted ||
            !widget.active ||
            scope != _pullScope ||
            scope != _refreshScope) {
          return PullRefreshResult.ignored;
        }
        final pending = _readTask;
        if (pending == null || identical(pending, task)) break;
        task = pending;
      }
      setState(() {
        _failedPullScope = _failed ? scope : null;
        if (!_failed) _imageRefreshToken++;
      });
      if (_failed) return PullRefreshResult.ignored;
      final after = _snapshot;
      return before != null &&
              after != null &&
              const DeepCollectionEquality().equals(
                _visibleSnapshot(before),
                _visibleSnapshot(after),
              )
          ? PullRefreshResult.checked
          : PullRefreshResult.updated;
    } finally {
      if (mounted && _pullScope == scope) setState(() => _pullScope = null);
    }
  }

  Future<void> _readNow() async {
    final epoch = ++_readEpoch;
    try {
      final snapshot = await _store.read();
      if (!mounted || epoch != _readEpoch) return;
      setState(() {
        _snapshot = snapshot;
        _failed = false;
        _failedPullScope = null;
        if (_folder != null &&
            _folder != '__unfiled' &&
            snapshot.folders[_folder]?.deleted != false) {
          _folder = null;
        }
        final live = snapshot
            .itemsFor(widget.source)
            .map((e) => e.item.id)
            .toSet();
        _selected.removeWhere((id) => !live.contains(id));
      });
    } catch (_) {
      if (mounted && epoch == _readEpoch) setState(() => _failed = true);
    }
  }

  void _message(String value) {
    if (!mounted || !widget.active) return;
    _noticeTimer?.cancel();
    final epoch = ++_noticeEpoch;
    setState(() => _notice = value);
    _noticeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && epoch == _noticeEpoch) setState(() => _notice = null);
    });
  }

  void _closeNotice({bool afterFrame = false}) {
    _noticeTimer?.cancel();
    final epoch = ++_noticeEpoch;
    void close() {
      if (mounted && epoch == _noticeEpoch) setState(() => _notice = null);
    }

    if (afterFrame) {
      WidgetsBinding.instance.addPostFrameCallback((_) => close());
    } else {
      close();
    }
  }

  Future<void> _newFolder() async {
    final name = await videoFolderName(context);
    if (name == null || !mounted) return;
    try {
      final id = await _store.createFolder(widget.source, name);
      if (mounted) setState(() => _folder = id);
    } catch (error) {
      _message(videoLibraryError(error));
    }
  }

  Future<void> _manageFolders() async {
    await showVideoTaskSheet<void>(
      context: context,
      builder: (_) => _FolderManager(source: widget.source, store: _store),
    );
  }

  Future<void> _addToFolder() async {
    final folder = _folder, snapshot = _snapshot;
    if (folder == null ||
        snapshot == null ||
        snapshot.folders[folder]?.deleted != false) {
      return;
    }
    final items = snapshot
        .itemsFor(widget.source)
        .where((e) => !snapshot.foldersOf(e.key).contains(folder))
        .map((e) => e.item)
        .toList();
    final chosen = await showVideoTaskSheet<List<ApiVideoItem>>(
      context: context,
      builder: (_) => _FolderContentsPicker(items: items),
    );
    if (chosen == null || chosen.isEmpty || !mounted) return;
    try {
      await _store.importFavorites(widget.source, chosen, folderIds: {folder});
    } catch (error) {
      _message(videoLibraryError(error));
    }
  }

  Future<void> _chooseFolder() async {
    final snapshot = _snapshot!;
    final all = _items(snapshot);
    final choice = await showVideoTaskSheet<String>(
      context: context,
      builder: (sheet) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(t.videoLibrary.chooseFolders)),
            for (final entry in <String, String>{
              '__all': t.videoLibrary.all,
              '__unfiled': t.videoLibrary.unfiled,
              for (final e in snapshot.foldersFor(widget.source).entries)
                e.key: '${e.value.data['name']}',
            }.entries)
              ListTile(
                leading: Icon(
                  entry.key == '__all'
                      ? Icons.video_library_outlined
                      : Icons.folder_outlined,
                ),
                title: Text(entry.value),
                subtitle: Text(
                  t.videoLibrary.results(
                    count: all
                        .where(
                          (row) =>
                              entry.key == '__all' ||
                              (entry.key == '__unfiled'
                                  ? snapshot.foldersOf(row.key).isEmpty
                                  : snapshot
                                        .foldersOf(row.key)
                                        .contains(entry.key)),
                        )
                        .length,
                  ),
                ),
                trailing: (_folder ?? '__all') == entry.key
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(sheet, entry.key),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: Text(t.videoLibrary.newFolder),
              onTap: () => Navigator.pop(sheet, '__new'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: Text(t.videoSource.manageFolders),
              onTap: () => Navigator.pop(sheet, '__manage'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == '__new') return _newFolder();
    if (choice == '__manage') return _manageFolders();
    setState(() {
      _folder = choice == '__all' ? null : choice;
      _selected.clear();
      _selecting = false;
    });
  }

  Future<void> _manage() async {
    final scope = _scopeKey, store = _store;
    final configured = context.read<GlobalSettingCubit?>();
    final syncReady =
        configured != null && isSyncServiceConfigured(configured.state);
    final action = await showVideoTaskSheet<String>(
      context: context,
      useRootNavigator: true,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: Text(t.videoSource.manageCollection)),
          for (final entry in <String, (IconData, String)>{
            if (widget.showFolders &&
                _snapshot?.folders[_folder]?.deleted == false)
              'add': (Icons.add_rounded, t.common.add),
            'select': (Icons.checklist_rounded, t.videoLibrary.batchSelect),
            if (_snapshot != null && _visibleRows(_snapshot!).isNotEmpty)
              'clear': (Icons.delete_sweep_outlined, t.common.clear),
            if (widget.showFolders)
              'folders': (
                Icons.folder_open_outlined,
                t.videoSource.manageFolders,
              ),
            if (widget.onImportSite != null)
              'import': (Icons.download_outlined, t.videoSource.importFollows),
            'cloud': (Icons.cloud_sync_outlined, t.videoSource.cloudSync),
            if (syncReady) 'sync': (Icons.sync_rounded, t.videoLibrary.syncNow),
          }.entries)
            ListTile(
              leading: Icon(entry.value.$1),
              title: Text(entry.value.$2),
              onTap: () => Navigator.pop(sheet, entry.key),
            ),
        ],
      ),
    );
    if (!mounted || scope != _scopeKey || store != _store) return;
    await _manageAction(action);
  }

  Future<void> _manageAction(String? action) async {
    switch (action) {
      case 'add':
        await _addToFolder();
      case 'select':
        setState(() {
          _selecting = true;
          _selected.clear();
        });
      case 'clear':
        if (_snapshot != null) {
          await _remove(
            _visibleRows(_snapshot!).map((row) => row.item.id).toSet(),
          );
        }
      case 'folders':
        await _manageFolders();
      case 'import':
        widget.onImportSite?.call();
      case 'cloud':
        await context.pushRoute(SyncSettingRoute());
      case 'sync':
        await _sync();
    }
  }

  Future<void> _classify() async {
    final keys = _selected
        .map((id) => VideoLibraryStore.itemKey(widget.source, id))
        .toSet();
    if (keys.isEmpty) return;
    final saved = await showVideoFolderPicker(
      context,
      source: widget.source,
      itemKeys: keys,
      store: _store,
    );
    if (saved == true && mounted) {
      setState(() {
        _selecting = false;
        _selected.clear();
      });
    }
  }

  bool _baseMatches(
    ({String key, ApiVideoItem item, int clock}) row,
    VideoLibrarySnapshot snapshot,
  ) {
    final matches = keywordTitleMatcher(_query);
    return _query.trim().isEmpty ||
        (_keywordScope == KeywordSearchScope.title
            ? matches([row.item.title, row.item.alternateTitle])
            : matches([_facetEntry(row, snapshot).searchText]));
  }

  ShelfFacetEntry _facetEntry(
    ({String key, ApiVideoItem item, int clock}) row,
    VideoLibrarySnapshot snapshot,
  ) => shelfFacetEntryFromVideo(
    VideoBookshelfRow(
      key: row.key,
      source: widget.source,
      item: row.item,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.clock),
      folderIds: snapshot.foldersOf(row.key),
    ),
  );

  List<({String key, ApiVideoItem item, int clock})> _visibleRows(
    VideoLibrarySnapshot snapshot,
  ) => _items(snapshot)
      .where(
        (row) =>
            _baseMatches(row, snapshot) &&
            (!_facets.isActive
                ? !widget.showFolders ||
                      _folder == null ||
                      (_folder == '__unfiled'
                          ? snapshot.foldersOf(row.key).isEmpty
                          : snapshot.foldersOf(row.key).contains(_folder))
                : shelfFacetMatches(
                    _facetEntry(row, snapshot),
                    _facets,
                    currentFolder: widget.showFolders ? _folder : null,
                  )),
      )
      .toList();

  List<({String key, ApiVideoItem item, int clock})> _sortedVisibleRows(
    VideoLibrarySnapshot snapshot,
  ) => _visibleRows(snapshot)
    ..sort(
      (a, b) => switch (_sort) {
        'title' => a.item.title.compareTo(b.item.title),
        'year' => b.item.year.compareTo(a.item.year),
        _ => b.clock.compareTo(a.clock),
      },
    );

  List<Object?> _visibleSnapshot(VideoLibrarySnapshot snapshot) => [
    if (widget.showFolders)
      for (final folder in snapshot.foldersFor(widget.source).entries)
        [folder.key, folder.value.data['name']],
    for (final row in _sortedVisibleRows(snapshot))
      [row.key, row.item.toLibraryJson()],
  ];

  void _clearFacets() => setState(() => _facets = const ShelfFacetSelection());

  Widget _filterButton(bool empty) => SourceFilterIconButton(
    key: const ValueKey('local-favorites.filter'),
    bare: false,
    tooltip: _facets.isActive
        ? t.videoFilters.active
        : t.bookshelf.facets.title,
    onPressed: _working || empty ? null : _editFilters,
    active: _facets.isActive,
  );

  Future<void> _editFilters() async {
    final snapshot = _snapshot;
    if (_openingFilters || _working || snapshot == null || !widget.active) {
      return;
    }
    _openingFilters = true;
    final scope = _scopeKey, folder = _folder, query = _query;
    final keywordScope = _keywordScope;
    _searchFocus.unfocus();
    try {
      final result = await showShelfFilterSheet(
        context,
        entries: _items(snapshot)
            .where((row) => _baseMatches(row, snapshot))
            .map((row) => _facetEntry(row, snapshot))
            .toList(),
        initial: _facets,
        preferenceKey: 'api-video.favorites|$scope',
        scopeLabel: t.videoSource.localFavorites,
        currentFolder: widget.showFolders ? folder : null,
        hierarchical: false,
      );
      if (!mounted ||
          !widget.active ||
          result == null ||
          scope != _scopeKey ||
          folder != _folder ||
          query != _query ||
          keywordScope != _keywordScope) {
        return;
      }
      setState(() {
        _facets = result;
        _selecting = false;
        _selected.clear();
      });
    } finally {
      _openingFilters = false;
    }
  }

  Future<void> _remove([Set<String>? chosen]) async {
    _searchFocus.unfocus();
    final snapshot = _snapshot;
    if (snapshot == null || _working) return;
    final visible = _visibleRows(snapshot).map((row) => row.item.id).toSet();
    final selected = (chosen ?? _selected).intersection(visible);
    if (selected.isEmpty) return;
    final source = widget.source, store = _store, scope = _scopeKey;
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: Text(t.videoLibrary.removeSelected),
        content: Text(
          '${t.videoLibrary.batchRemoveHint(count: selected.length)}\n\n${t.videoLibrary.localFavoriteRemovalHint}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(t.common.remove),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !mounted ||
        !widget.active ||
        scope != _scopeKey ||
        store != _store) {
      return;
    }
    setState(() => _working = true);
    try {
      await store.removeFavorites(
        selected.map((id) => VideoLibraryStore.itemKey(source, id)).toSet(),
      );
      if (mounted) {
        setState(() {
          _selecting = false;
          _selected.clear();
        });
      }
    } catch (error) {
      if (mounted && widget.active && scope == _scopeKey && store == _store) {
        _message(videoLibraryError(error));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _sync() async {
    final settings = context.read<GlobalSettingCubit>();
    if (_syncing || !isSyncServiceConfigured(settings.state)) return;
    final scope = _scopeKey, store = _store;
    void report(String message) {
      if (mounted && widget.active && scope == _scopeKey && store == _store) {
        _message(message);
      }
    }

    setState(() => _syncing = true);
    try {
      final synced = await syncVideoLibrary(
        readState: () => settings.state,
        store: store,
      );
      report(synced ? t.videoLibrary.syncDone : t.videoLibrary.syncFailed);
    } catch (_) {
      report(t.videoLibrary.syncFailed);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Widget _selectionBody(Widget child) {
    if (!widget.compactHeader) return child;
    final ids = _snapshot == null
        ? <String>{}
        : _visibleRows(_snapshot!).map((row) => row.item.id).toSet();
    final selected = _selected.intersection(ids);
    return BookshelfFloatingSelectionActions(
      selecting: _selecting,
      keyPrefix: 'local-favorites.selection',
      selectedCount: selected.length,
      busy: _working,
      actions: [
        BookshelfBatchAction(
          id: 'delete',
          label: t.videoLibrary.removeSelected,
          icon: Icons.delete_outline,
          symbol: 'trash',
          onPressed: selected.isEmpty || _working
              ? null
              : () => _remove(selected),
        ),
      ],
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) => CollectionCoverPrivacyScope(
    child: _selectionBody(
      Column(
        children: [
          if (!widget.compactHeader) _buildSearchRow(context),
          if (widget.active && _notice != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: VideoActionNotice(
                message: _notice!,
                onClose: _closeNotice,
              ),
            ),
          if (_failed && _snapshot != null) _refreshErrorRow(),
          Expanded(
            child: PullRefreshFeedback.indicator(
              onRefresh: _refresh,
              active: widget.active && !_working,
              scope: _refreshScope,
              indicatorKey: _refreshIndicator,
              notificationPredicate: (notice) =>
                  widget.active && !_working && notice.depth == 0,
              child: _buildCollection(context),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _keywordMenu() => KeywordScopeMenu(
    scope: _keywordScope,
    compact: true,
    onChanged: (scope) => setState(() => _keywordScope = scope),
  );

  Widget _buildSearchRow(BuildContext context) => Padding(
    padding: widget.compactHeader
        ? EdgeInsets.zero
        : const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Row(
      children: [
        Expanded(
          child: SearchFieldSurface(
            child: TextField(
              controller: _input,
              enabled:
                  !_working &&
                  _snapshot != null &&
                  _items(_snapshot!).isNotEmpty,
              focusNode: _searchFocus,
              onTapOutside: (_) => _searchFocus.unfocus(),
              decoration: searchFieldDecoration(
                context,
                hintText: t.videoSource.searchLocal,
                suffixIcon: _query.isEmpty
                    ? const SizedBox(width: 44)
                    : IconButton(
                        tooltip: t.common.clear,
                        onPressed: () {
                          _input.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
              onChanged: (value) => setState(() {
                _query = value;
              }),
            ),
          ),
        ),
        if (!widget.compactHeader) ...[
          const SizedBox(width: 8),
          _keywordMenu(),
          const CollectionCoverPrivacyButton(
            key: ValueKey('local-favorites.cover-privacy'),
          ),
        ],
      ],
    ),
  );

  Widget _refreshErrorRow() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        Expanded(
          child: Text(
            _failedPullScope == _refreshScope
                ? t.common.refreshRetained
                : t.common.loadingFailed,
          ),
        ),
        TextButton.icon(
          onPressed: _pullScope == _refreshScope
              ? null
              : () => _refreshIndicator.currentState?.show(),
          icon: const Icon(Icons.refresh),
          label: Text(t.common.retry),
        ),
      ],
    ),
  );

  Widget _emptyCollection(Widget empty) => widget.compactHeader
      ? Column(
          children: [
            SourceVideoListHeader(
              keyPrefix: 'local-favorites',
              leading: widget.headerLeading,
              title: t.videoSource.localFavorites,
              onSearch: null,
              options: const {},
              reserveMoreSlot: _snapshot == null,
              onMore: (_) {},
            ),
            Expanded(child: empty),
          ],
        )
      : empty;

  Widget _buildCollection(BuildContext context) {
    final compact = widget.compact || _searchFocus.hasFocus;
    if (_snapshot == null) {
      return _emptyCollection(
        ApiVideoEmpty(
          scrollable: true,
          title: _failed
              ? (_failedPullScope == _refreshScope
                    ? t.common.refreshFailed
                    : t.common.loadingFailed)
              : t.common.loading,
          action: _failed
              ? TextButton(onPressed: _read, child: Text(t.common.retry))
              : null,
        ),
      );
    }
    final snapshot = _snapshot!, all = _items(snapshot);
    final q = _query.trim().toLowerCase();
    final rows = _sortedVisibleRows(snapshot);
    final visibleSelected = _selected.intersection(
      rows.map((row) => row.item.id).toSet(),
    );
    final emptyLibrary = ApiVideoEmpty(
      scrollable: true,
      title: t.videoLibrary.favoritesEmpty,
      message: t.videoSource.emptyLocalHint,
      icon: Icons.bookmark_border_rounded,
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.onExplore != null)
            FilledButton(
              onPressed: widget.onExplore,
              child: Text(widget.exploreLabel ?? t.videoSource.goDiscover),
            ),
          if (widget.onImportSite != null)
            TextButton.icon(
              onPressed: widget.onImportSite,
              icon: const Icon(Icons.download_outlined),
              label: Text(t.videoSource.importFollows),
            ),
        ],
      ),
    );
    if (all.isEmpty &&
        (!widget.showFolders || snapshot.foldersFor(widget.source).isEmpty)) {
      return _emptyCollection(emptyLibrary);
    }
    final emptyFolder =
        _folder != null &&
        snapshot.folders[_folder]?.deleted == false &&
        q.isEmpty &&
        !_facets.isActive;
    const toolbarInset = 16.0;
    final folderLabel = _folder == '__unfiled'
        ? t.videoLibrary.unfiled
        : snapshot.folders[_folder]?.data['name']?.toString() ??
              t.videoLibrary.all;
    final sorts = {
      'recent': t.videoLibrary.recentAdded,
      'title': t.videoLibrary.titleOrder,
      'year': t.videoLibrary.yearOrder,
    };
    return PopScope(
      canPop:
          !widget.active ||
          (!_working &&
              !_selecting &&
              _folder == null &&
              !_searchFocus.hasFocus),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _closeNotice();
        } else if (widget.active) {
          _backWithinCollection();
        }
      },
      child: Column(
        children: [
          if (widget.compactHeader)
            if (_selecting)
              BookshelfSelectionToolbar(
                keyPrefix: 'local-favorites.selection',
                selectedCount: visibleSelected.length,
                allSelected:
                    rows.isNotEmpty &&
                    _selected.containsAll(rows.map((row) => row.item.id)),
                onCancel: _working ? null : _cancelSelection,
                onToggleAll: _working || rows.isEmpty
                    ? null
                    : () => setState(() {
                        final ids = rows.map((row) => row.item.id).toSet();
                        _selected.containsAll(ids)
                            ? _selected.removeAll(ids)
                            : _selected.addAll(ids);
                      }),
              )
            else
              SourceVideoListHeader(
                keyPrefix: 'local-favorites',
                leading: widget.headerLeading,
                menuKey: const ValueKey('local-favorites.manage'),
                title: _query.isEmpty ? t.videoSource.localFavorites : _query,
                searching: _searching,
                searchField: _buildSearchRow(context),
                searchScope: _keywordMenu(),
                onSearch: _working
                    ? null
                    : () {
                        setState(() => _searching = !_searching);
                        if (_searching)
                          requestSearchKeyboard(
                            _searchFocus,
                            isCurrent: () =>
                                mounted && widget.active && _searching,
                          );
                        else
                          _searchFocus.unfocus();
                      },
                options: {
                  'select': t.videoLibrary.batchSelect,
                  if (rows.isNotEmpty) 'clear': t.common.clear,
                  if (widget.onImportSite != null)
                    'import': t.videoSource.importFollows,
                  'cloud': t.videoSource.cloudSync,
                  if (context.read<GlobalSettingCubit?>()?.state
                      case final settings?
                      when isSyncServiceConfigured(settings))
                    'sync': t.videoLibrary.syncNow,
                },
                onMore: (action) {
                  if (_working) return;
                  _searchFocus.unfocus();
                  _manageAction(action);
                },
              ),
          if (!compact && !widget.compactHeader) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: toolbarInset),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final viewportWidth = constraints.maxWidth + toolbarInset * 2;
                  final stacked =
                      viewportWidth < 360 ||
                      MediaQuery.textScalerOf(context).scale(14) > 20;
                  final identity = <Widget>[
                    if (_folder != null)
                      SourceChromeIconButton(
                        tooltip: t.common.back,
                        onPressed: _working ? null : _backWithinCollection,
                        icon: Icons.arrow_back_ios_new_rounded,
                        symbol: 'chevron.left',
                      ),
                    Expanded(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          alignment: AlignmentDirectional.centerStart,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onPressed: _working ? null : _chooseFolder,
                        icon: const Icon(Icons.folder_outlined, size: 20),
                        label: Text(
                          folderLabel,
                          maxLines: stacked ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ];
                  Widget sort(double width) => NativeVideoMenu(
                    label: sorts[_sort]!,
                    tooltip: t.videoLibrary.sort,
                    selected: _sort,
                    width: width,
                    options: sorts,
                    onSelected: (value) => setState(() => _sort = value),
                  );
                  final manage = NativeVideoTextButton(
                    backgroundInset: 0,
                    key: const ValueKey('local-favorites.manage'),
                    light: false,
                    maxWidth: 180,
                    tooltip: _selecting
                        ? t.common.cancel
                        : t.videoSource.manage,
                    label: _selecting ? t.common.cancel : t.videoSource.manage,
                    onPressed: _working
                        ? null
                        : () {
                            if (_selecting) {
                              _cancelSelection();
                            } else {
                              _manage();
                            }
                          },
                  );
                  if (!widget.showFolders) {
                    return Row(
                      children: [
                        const Spacer(),
                        sort(140),
                        const SizedBox(width: 8),
                        manage,
                      ],
                    );
                  }
                  if (!stacked) {
                    return Row(
                      children: [
                        ...identity,
                        sort(88),
                        const SizedBox(width: 8),
                        manage,
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: identity),
                      Row(
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (_, space) => sort(space.maxWidth),
                            ),
                          ),
                          const SizedBox(width: 8),
                          manage,
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
          if (widget.compactHeader && !_selecting)
            SourceVideoResultsToolbar(
              count: t.videoLibrary.results(count: rows.length),
              keyPrefix: 'local-favorites',
              sort: _sort,
              sortOptions: sorts,
              onSort: _working
                  ? null
                  : (value) {
                      _searchFocus.unfocus();
                      setState(() => _sort = value);
                    },
              gridView: widget.onToggleView == null
                  ? null
                  : widget.mode == ApiVideoView.grid,
              onToggleView: _working ? null : widget.onToggleView,
              filter: _filterButton(all.isEmpty),
            ),
          if (widget.compactHeader && !_selecting && _facets.isActive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  key: const ValueKey('local-favorites.clear-filter'),
                  onPressed: _clearFacets,
                  child: Text(t.bookshelf.facets.clear),
                ),
              ),
            ),
          if (!widget.compactHeader)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selecting
                          ? t.videoLibrary.selectedCount(
                              count: widget.showFolders
                                  ? _selected.length
                                  : visibleSelected.length,
                            )
                          : t.videoLibrary.results(count: rows.length),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (!_selecting && _facets.isActive)
                    TextButton(
                      key: const ValueKey('local-favorites.clear-filter'),
                      onPressed: _clearFacets,
                      child: Text(t.bookshelf.facets.clear),
                    ),
                  if (!_selecting) _filterButton(all.isEmpty),
                  if (compact && _selecting)
                    TextButton(
                      onPressed: _working ? null : _cancelSelection,
                      child: Text(t.common.cancel),
                    ),
                ],
              ),
            ),
          if (_selecting && !widget.compactHeader)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    TextButton(
                      onPressed: rows.isEmpty || _working
                          ? null
                          : () => setState(() {
                              final ids = rows.map((e) => e.item.id).toSet();
                              if (_selected.containsAll(ids)) {
                                _selected.removeAll(ids);
                              } else {
                                _selected.addAll(ids);
                              }
                            }),
                      child: Text(
                        rows.isNotEmpty &&
                                _selected.containsAll(
                                  rows.map((e) => e.item.id),
                                )
                            ? t.bookshelf.deselectAll
                            : t.videoLibrary.selectAll,
                      ),
                    ),
                    if (widget.showFolders)
                      TextButton.icon(
                        onPressed: _selected.isEmpty || _working
                            ? null
                            : _classify,
                        icon: const Icon(Icons.create_new_folder_outlined),
                        label: Text(t.bookshelf.addToFolder),
                      ),
                    TextButton.icon(
                      onPressed: visibleSelected.isEmpty || _working
                          ? null
                          : _remove,
                      icon: const Icon(Icons.delete_outline),
                      label: Text(t.videoLibrary.removeSelected),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: all.isEmpty && _folder == null
                ? emptyLibrary
                : rows.isEmpty
                ? ApiVideoEmpty(
                    scrollable: true,
                    title: emptyFolder
                        ? t.videoLibrary.folderEmpty
                        : t.videoLibrary.noResults,
                    message: emptyFolder ? '' : t.videoLibrary.noResultsHint,
                    icon: Icons.search_off_rounded,
                    action: TextButton(
                      onPressed: emptyFolder
                          ? _addToFolder
                          : _facets.isActive
                          ? _clearFacets
                          : () => setState(() {
                              _folder = null;
                              _facets = const ShelfFacetSelection();
                              _query = '';
                              _input.clear();
                            }),
                      child: Text(
                        emptyFolder
                            ? t.common.add
                            : _facets.isActive
                            ? t.bookshelf.facets.clear
                            : t.videoSource.showAllFavorites,
                      ),
                    ),
                  )
                : ApiVideoCollection(
                    contentBottomPadding: widget.compactHeader && _selecting
                        ? BookshelfFloatingSelectionActions.contentBottomPadding
                        : 0,
                    imageRefreshToken: _imageRefreshToken,
                    retryMissingCoverDetailsOnRefresh: false,
                    posterAspectRatio:
                        widget.repository?.capabilities.posterAspectRatio ??
                        2 / 3,
                    loadDetail: widget.loadDetail,
                    onDetailLoaded: widget.onDetailLoaded,
                    detailsActive: widget.active && !_selecting,
                    key: ValueKey(
                      'favorite.$_folder.$_query.${_keywordScope.name}.$_facets.$_sort',
                    ),
                    items: rows.map((e) => e.item).toList(),
                    mode: widget.mode,
                    storageKey:
                        '$_scopeKey.favorites.$_folder.$_query.${_keywordScope.name}.$_facets',
                    selected: _selected,
                    selecting: _selecting,
                    onOpen: (item) {
                      if (_working) return;
                      if (_selecting) {
                        setState(() {
                          _selected.contains(item.id)
                              ? _selected.remove(item.id)
                              : _selected.add(item.id);
                        });
                      } else {
                        unawaited(widget.onOpen(item));
                      }
                    },
                    onLongPress: (item) {
                      if (_working) return;
                      setState(() {
                        _selecting = true;
                        _selected.add(item.id);
                      });
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FolderContentsPicker extends StatefulWidget {
  const _FolderContentsPicker({required this.items});
  final List<ApiVideoItem> items;
  @override
  State<_FolderContentsPicker> createState() => _FolderContentsPickerState();
}

class _FolderContentsPickerState extends State<_FolderContentsPicker> {
  final _selected = <String>{}, _query = TextEditingController();
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim().toLowerCase();
    final items = widget.items
        .where((e) => e.title.toLowerCase().contains(query))
        .toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .75,
      child: Column(
        children: [
          ListTile(
            title: Text(t.bookshelf.addToFolder),
            subtitle: Text(
              t.videoLibrary.selectedCount(count: _selected.length),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SearchFieldSurface(
              child: TextField(
                controller: _query,
                onChanged: (_) => setState(() {}),
                decoration: searchFieldDecoration(
                  context,
                  hintText: t.videoSource.searchLocal,
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: t.common.clear,
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _query.clear();
                            setState(() {});
                          },
                        ),
                ),
              ),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? ApiVideoEmpty(title: t.videoLibrary.noResults)
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, index) {
                      final item = items[index];
                      return CheckboxListTile(
                        value: _selected.contains(item.id),
                        title: Text(item.title),
                        onChanged: (selected) => setState(() {
                          selected == true
                              ? _selected.add(item.id)
                              : _selected.remove(item.id);
                        }),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _selected.isEmpty
                  ? null
                  : () => Navigator.pop(
                      context,
                      widget.items
                          .where((e) => _selected.contains(e.id))
                          .toList(),
                    ),
              child: Text(t.common.confirm),
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderManager extends StatefulWidget {
  const _FolderManager({required this.source, required this.store});
  final String source;
  final VideoLibraryStore store;
  @override
  State<_FolderManager> createState() => _FolderManagerState();
}

class _FolderManagerState extends State<_FolderManager> {
  VideoLibrarySnapshot? _snapshot;
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    try {
      final value = await widget.store.read();
      if (mounted) setState(() => _snapshot = value);
    } catch (error) {
      if (mounted) setState(() => _error = videoLibraryError(error));
    }
  }

  Future<void> _rename(String id, String current) async {
    final value = await videoFolderName(context, initial: current);
    if (value == null || !mounted) return;
    await _change(() => widget.store.renameFolder(id, value));
  }

  Future<void> _delete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(t.videoLibrary.deleteFolder),
        content: Text(t.videoLibrary.folderDeleteHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(t.common.delete),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _change(() => widget.store.deleteFolder(id));
    }
  }

  Future<void> _change(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await _read();
    } catch (error) {
      if (mounted) setState(() => _error = videoLibraryError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.videoLibrary.chooseFolders,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: t.common.close,
                onPressed: _busy ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final e
                    in (_snapshot?.foldersFor(widget.source).entries ??
                        <MapEntry<String, VideoLibraryEntry>>[]))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder_outlined),
                    title: Text('${e.value.data['name']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: t.videoLibrary.renameFolder,
                          onPressed: _busy
                              ? null
                              : () => _rename(e.key, '${e.value.data['name']}'),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: t.videoLibrary.deleteFolder,
                          onPressed: _busy ? null : () => _delete(e.key),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                if (_snapshot?.foldersFor(widget.source).isEmpty == true)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(t.videoLibrary.folderEmpty),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
