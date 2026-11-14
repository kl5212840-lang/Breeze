import 'package:collection/collection.dart';
import 'package:zephyr/widgets/collection_selection_mark.dart';
import 'package:zephyr/widgets/pull_refresh_feedback.dart';
import 'package:zephyr/widgets/collection_cover_fit.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_detailed_content.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_content_layout.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_content_toolbar.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_actions_scope.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_help.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_return_to_top.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_folder_card.dart';
import 'package:zephyr/widgets/folder_cover_menu.dart';
import 'package:zephyr/service/folder_cover_service.dart';
import 'package:zephyr/service/folder_cover_identity.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/widgets/action_feedback.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry.dart'
    show kComicCardBorderRadius;
import 'dart:async';
import 'package:intl/intl.dart';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/cubit/search_status.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';
import 'package:zephyr/page/bookshelf/service/shelf_facet_adapters.dart';
import 'package:zephyr/page/bookshelf/widgets/shelf_filter_sheet.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_selection_toolbar.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_floating_selection_actions.dart';
import 'package:zephyr/page/bookshelf/service/video_bookshelf_index.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/video_cover_overlay.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/service/collection_view_preferences.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/util/text/public_search_text.dart';
import 'package:zephyr/page/video/video_library_folder_picker.dart';
import 'package:zephyr/page/video/video_library_store.dart';

/// Injectable boundary for tests; production reads the original video stores.
class VideoBookshelfPaneDataSource {
  const VideoBookshelfPaneDataSource({
    required this.load,
    required this.sourceNames,
    required this.open,
    required this.remove,
    required this.enrich,
    required this.store,
    required this.changes,
    this.readPane,
  });
  final Future<List<VideoBookshelfRow>> Function(
    ShelfPageMode,
    SearchStatusState,
  )
  load;
  final Future<Map<String, String>> Function() sourceNames;
  final Future<void> Function(BuildContext, VideoBookshelfRow) open;
  final Future<void> Function(ShelfPageMode, List<VideoBookshelfRow>) remove;
  final Future<ApiVideoItem> Function(VideoBookshelfRow) enrich;
  final VideoLibraryStore store;
  final Listenable changes;
  final Future<VideoBookshelfSnapshot> Function(
    ShelfPageMode,
    SearchStatusState,
  )?
  readPane;
  static final live = VideoBookshelfPaneDataSource(
    load: VideoBookshelfIndex.load,
    sourceNames: VideoBookshelfIndex.sourceNames,
    open: VideoBookshelfIndex.open,
    remove: VideoBookshelfIndex.remove,
    enrich: VideoBookshelfIndex.enrich,
    store: VideoBookshelfIndex.store,
    changes: VideoBookshelfIndex.changes,
    readPane: VideoBookshelfIndex.readPane,
  );
}

class VideoBookshelfPane extends StatefulWidget {
  const VideoBookshelfPane({
    super.key,
    required this.mode,
    required this.search,
    this.keywordScope = KeywordSearchScope.all,
    this.refreshSignal = 0,
    this.isActive = true,
    this.showReturnToTop = false,
    this.onSelectionChanged,
    this.dataSource,
  });
  final ShelfPageMode mode;
  final SearchStatusState search;
  final KeywordSearchScope keywordScope;
  final int refreshSignal;
  final bool isActive;
  final bool showReturnToTop;
  final ValueChanged<bool>? onSelectionChanged;
  final VideoBookshelfPaneDataSource? dataSource;
  @override
  State<VideoBookshelfPane> createState() => _VideoBookshelfPaneState();
}

class _VideoBookshelfPaneState extends State<VideoBookshelfPane>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  VideoBookshelfPaneDataSource get _data =>
      widget.dataSource ?? VideoBookshelfPaneDataSource.live;
  List<VideoBookshelfRow>? _rows;
  Map<String, int> _folderWorkCounts = const {};
  Map<String, ShelfFacetEntry>? _entriesByKey;
  Map<String, String> _names = {};
  VideoLibrarySnapshot? _snapshot;
  final _selected = <String>{};
  final _selectedFolders = <String>{};
  int get _selectionCount => _selected.length + _selectedFolders.length;
  ApiVideoView _view = ApiVideoView.grid;
  int _viewEpoch = 0;
  String get _viewScope => 'public|video|${widget.mode.name}';

  Future<void> _restoreView() async {
    final epoch = ++_viewEpoch, scope = _viewScope;
    try {
      final value = await CollectionViewPreferences.read(scope);
      if (!mounted || epoch != _viewEpoch || scope != _viewScope) return;
      setState(
        () => _view = value == 'list' ? ApiVideoView.list : ApiVideoView.grid,
      );
    } catch (_) {}
  }

  Future<void> _toggleView() async {
    final scope = _viewScope, previous = _view;
    final epoch = ++_viewEpoch;
    final next = previous == ApiVideoView.grid
        ? ApiVideoView.list
        : ApiVideoView.grid;
    setState(() => _view = next);
    try {
      await CollectionViewPreferences.write(scope, next.name);
    } catch (_) {
      if (!mounted || epoch != _viewEpoch || scope != _viewScope) return;
      setState(() => _view = previous);
      await _restoreView();
      if (mounted && scope == _viewScope) {
        showErrorToast(t.error.saveFailed);
      }
    }
  }

  ShelfFacetSelection _filter = const ShelfFacetSelection();
  bool _openingFilter = false;
  bool _pendingDataChange = false;
  int _filterScopeEpoch = 0;
  String? _folder, _notice;
  bool _loading = false, _failed = false, _selecting = false, _working = false;
  int _epoch = 0;
  bool get _favorites => widget.mode == ShelfPageMode.favorite;
  String? get _source =>
      widget.search.sources.length == 1 ? widget.search.sources.single : null;

  @override
  void initState() {
    super.initState();
    CollectionViewPreferences.changes.addListener(_restoreView);
    unawaited(_restoreView());
    _data.changes.addListener(_changed);
    if (widget.isActive) unawaited(_load());
  }

  @override
  void didUpdateWidget(VideoBookshelfPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _view = ApiVideoView.grid;
      unawaited(_restoreView());
    }
    final dataSourceChanged = oldWidget.dataSource != widget.dataSource;
    if (dataSourceChanged) {
      (oldWidget.dataSource ?? VideoBookshelfPaneDataSource.live).changes
          .removeListener(_changed);
      _data.changes.addListener(_changed);
    }
    final scopeChanged =
        oldWidget.mode != widget.mode ||
        oldWidget.search != widget.search ||
        widget.search.keyword.trim().isNotEmpty &&
            oldWidget.keywordScope != widget.keywordScope;
    if (scopeChanged ||
        dataSourceChanged ||
        oldWidget.isActive != widget.isActive) {
      _filterScopeEpoch++;
    }
    if (scopeChanged) {
      _rows = null;
      _entriesByKey = null;
      _notice = null;
      _failed = false;
    }
    if (scopeChanged || dataSourceChanged) {
      _invalidateRead();
    }
    if (!listEquals(oldWidget.search.sources, widget.search.sources) ||
        oldWidget.mode != widget.mode) {
      _folder = null;
      _filter = const ShelfFacetSelection();
    }
    if (scopeChanged || !widget.isActive) _setSelecting(false);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      _pendingDataChange = true;
    }
    if (!widget.isActive) {
      if (_readTask != null) _invalidateRead();
    } else if (_readTask == null &&
        (_pendingDataChange || (_rows == null && !_failed))) {
      unawaited(_load());
    }
  }

  void _invalidateRead() {
    _epoch++;
    _pullScope = null;
    _failedPullScope = null;
    _readTask = null;
    _loading = false;
    _pendingDataChange = true;
  }

  @override
  void dispose() {
    _viewEpoch++;
    CollectionViewPreferences.changes.removeListener(_restoreView);
    _epoch++;
    _data.changes.removeListener(_changed);
    if (_selecting) {
      final callback = widget.onSelectionChanged;
      scheduleMicrotask(() => callback?.call(false));
    }
    super.dispose();
  }

  void _changed() {
    _pendingDataChange = true;
    if (widget.isActive && !_working && _readTask == null) {
      unawaited(_load());
    }
  }

  void _finishWork() {
    if (!mounted) return;
    setState(() => _working = false);
    if (_pendingDataChange && widget.isActive) unawaited(_load());
  }

  void _setSelecting(bool value) {
    if (_selecting == value) return;
    _selecting = value;
    if (!value) {
      _selected.clear();
      _selectedFolders.clear();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _selecting == value) {
        widget.onSelectionChanged?.call(value);
      }
    });
  }

  Future<void>? _readTask;
  Object? _pullScope, _failedPullScope;
  Object get _refreshScope => (
    _data,
    widget.mode,
    widget.search,
    _folder,
    _filter,
    widget.keywordScope,
  );
  bool get _pullRefreshing => _pullScope == _refreshScope;

  Future<void> _load() {
    if (!mounted || !widget.isActive) return Future.value();
    final pending = _readTask;
    if (pending != null) {
      if (!_pendingDataChange) return pending;
      return pending.then((_) {
        if (_pendingDataChange) return _load();
      });
    }
    _pendingDataChange = false;
    late final Future<void> task;
    task = _loadNow().whenComplete(() {
      if (identical(_readTask, task)) {
        _readTask = null;
        if (mounted && widget.isActive && !_working && _pendingDataChange) {
          unawaited(_load());
        }
      }
    });
    return _readTask = task;
  }

  int _imageRefreshToken = 0;
  Future<PullRefreshResult> _refreshFromPull() async {
    if (!widget.isActive || _working || _pullRefreshing) {
      return PullRefreshResult.ignored;
    }
    final scope = _refreshScope;
    final before = _rows == null ? null : _visibleSnapshot();
    setState(() => _pullScope = scope);
    try {
      var task = _load();
      while (true) {
        await task;
        if (!mounted ||
            !widget.isActive ||
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
      return before != null &&
              const DeepCollectionEquality().equals(before, _visibleSnapshot())
          ? PullRefreshResult.unchanged
          : PullRefreshResult.updated;
    } finally {
      if (mounted && _pullScope == scope) setState(() => _pullScope = null);
    }
  }

  List<Object?> _visibleSnapshot() => [
    _folderTitle,
    for (final folder in _visibleFolders.entries)
      [folder.key, folder.value.data['name'], _folderWorkCounts[folder.key]],
    for (final row in _visible)
      [
        row.key,
        _names[row.source] ?? row.source,
        row.item.toLibraryJson(),
        row.watchUrl,
        row.recordKey,
        row.localResourceId,
        row.updatedAt,
        row.progress,
        _originalFolders(row),
      ],
  ];

  Future<void> _loadNow() async {
    if (!widget.isActive) return;
    final epoch = ++_epoch;
    final mode = widget.mode, search = widget.search;
    final titleQuery = widget.keywordScope == KeywordSearchScope.title
        ? normalizePublicSearchText(search.keyword)
        : '';
    setState(() {
      _loading = true;
      _failed = false;
      _failedPullScope = null;
    });
    try {
      final snapshot =
          await (_data.readPane?.call(mode, search) ??
              _readDataSource(mode, search));
      if (!mounted || !widget.isActive || epoch != _epoch) return;
      setState(() {
        _rows = snapshot.rows
            .where(
              (row) =>
                  (search.sources.isEmpty ||
                      search.sources.contains(row.source)) &&
                  (titleQuery.isEmpty ||
                      [row.item.title, row.item.alternateTitle].any(
                        (title) => normalizePublicSearchText(
                          title,
                        ).contains(titleQuery),
                      )),
            )
            .toList();
        _entriesByKey = null;
        final worksByFolder = <String, Set<String>>{};
        if (mode == ShelfPageMode.favorite && search.keyword.isEmpty) {
          for (final row in _rows!) {
            for (final id in row.folderIds) {
              worksByFolder.putIfAbsent(id, () => {}).add(row.key);
            }
          }
        }
        _folderWorkCounts = {
          for (final entry in worksByFolder.entries)
            entry.key: entry.value.length,
        };
        _names = snapshot.names;
        _snapshot = snapshot.library;
        if (_folder != null &&
            _folder != '__unfiled' &&
            (_snapshot?.folders[_folder]?.deleted != false ||
                (_source != null &&
                    !(_snapshot?.foldersFor(_source!).containsKey(_folder) ??
                        false)))) {
          _folder = null;
          _filter = const ShelfFacetSelection();
        }
        _selected.retainAll(_visible.map((r) => r.key));
        _selectedFolders.retainAll(_visibleFolders.keys);
        _loading = false;
        _notice = null;
      });
    } catch (_) {
      if (mounted && widget.isActive && epoch == _epoch) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<VideoBookshelfSnapshot> _readDataSource(
    ShelfPageMode mode,
    SearchStatusState search,
  ) async {
    final values = await (
      _data.load(mode, search),
      _data.sourceNames(),
      mode == ShelfPageMode.favorite
          ? _data.store.read()
          : Future<VideoLibrarySnapshot?>.value(),
    ).wait;
    return (rows: values.$1, names: values.$2, library: values.$3);
  }

  Map<String, ShelfFacetEntry> get _facetEntriesByKey => _entriesByKey ??= {
    for (final row in _rows ?? const []) row.key: shelfFacetEntryFromVideo(row),
  };

  List<VideoBookshelfRow> get _visible => [
    for (final row in _rows ?? <VideoBookshelfRow>[])
      if (_filter.isActive
          ? shelfFacetMatches(
              _facetEntriesByKey[row.key]!,
              _filter,
              currentFolder: _favorites ? _folder : null,
            )
          : _folder == null ||
                (_folder == '__unfiled'
                    ? row.folderIds.isEmpty
                    : row.folderIds.contains(_folder)))
        row,
  ];

  String get _folderTitle => _folder == '__unfiled'
      ? t.videoLibrary.unfiled
      : _folders[_folder]?.data['name']?.toString() ?? t.common.root;

  void _clearFilter() => setState(() {
    _filter = const ShelfFacetSelection();
    _setSelecting(false);
  });

  Future<void> _editFilter() async {
    if (!widget.isActive ||
        _working ||
        _loading ||
        _rows == null ||
        _openingFilter) {
      return;
    }
    _openingFilter = true;
    try {
      final folder = _folder, search = widget.search, mode = widget.mode;
      final scopeEpoch = _filterScopeEpoch;
      final result = await showShelfFilterSheet(
        context,
        entries: _facetEntriesByKey.values.toList(),
        initial: _filter,
        preferenceKey: _favorites ? 'video' : 'video.${mode.name}',
        scopeLabel: [
          _folder == null ? t.bookshelf.facets.all : _folderTitle,
          if (search.keyword.trim().isNotEmpty)
            t.bookshelf.facets.search(name: search.keyword.trim()),
        ].join(' · '),
        currentFolder: _favorites ? _folder : null,
        hierarchical: false,
      );
      if (result == null ||
          !mounted ||
          !widget.isActive ||
          mode != widget.mode ||
          scopeEpoch != _filterScopeEpoch ||
          folder != _folder ||
          search != widget.search) {
        return;
      }
      setState(() {
        _filter = _favorites
            ? result
            : result.copyWith(scope: ShelfFacetScope.current);
        _setSelecting(false);
      });
    } finally {
      _openingFilter = false;
    }
  }

  String _originalFolders(VideoBookshelfRow row) {
    if (!_favorites ||
        !_filter.isActive ||
        (_filter.scope != ShelfFacetScope.all && _folder != null)) {
      return '';
    }
    final names = [
      for (final id in row.folderIds)
        if (_snapshot?.folders[id]?.deleted == false)
          _snapshot!.folders[id]!.data['name']?.toString() ?? '',
    ].where((name) => name.isNotEmpty).toSet().toList()..sort();
    return names.isEmpty ? t.videoLibrary.unfiled : names.join('、');
  }

  Widget _caption(ApiVideoItem item, VideoBookshelfRow? row) {
    final folders = row == null ? '' : _originalFolders(row);
    final subtitle = [
      if (folders.isNotEmpty) folders,
      _names[row?.source] ?? row?.source ?? '',
      if ((row?.progress ?? '').isNotEmpty)
        t.bookshelf.watchTo(position: row!.progress),
      if ((row?.progress ?? '').isEmpty &&
          item.remarks.isNotEmpty &&
          clockVideoDurationText(item.remarks).isEmpty)
        item.remarks,
    ].where((part) => part.isNotEmpty).join(' · ');
    final caption = BookshelfCardCaption(title: item.title, subtitle: subtitle);
    return folders.isEmpty
        ? caption
        : Semantics(
            label: '${item.title} · $subtitle',
            excludeSemantics: true,
            child: caption,
          );
  }

  String get _collectionKey {
    final conditions = <String>[];
    if (_filter.isActive) {
      conditions.add(_filter.scope.name);
      final fields = _filter.values.keys.toList()..sort();
      for (final field in fields) {
        final values = _filter.values[field]!.toList()..sort();
        if (values.isEmpty) continue;
        conditions.add('$field=${values.map(Uri.encodeComponent).join(',')}');
      }
    }
    return 'bookshelf.video.${widget.mode.name}.${widget.search.sources.join('|')}.$_folder.${widget.search.keyword}.${widget.search.sort}.${conditions.join(';')}';
  }

  ApiVideoItem _display(VideoBookshelfRow row, [ApiVideoItem? item]) {
    final current = item ?? row.item;
    final duration = videoCoverDurationText(
      current.sourceDuration,
      clockFallback: current.remarks,
    );
    return ApiVideoItem.fromJson({
      ...current.toLibraryJson(),
      'id': row.key,
      // Preserve a source's bare duration remark before history replaces
      // remarks with local watch progress. Progress is never a total.
      'sourceDuration': duration.isNotEmpty
          ? duration
          : videoCoverDurationText(
              row.item.sourceDuration,
              clockFallback: row.item.remarks,
            ),
      if (widget.mode == ShelfPageMode.history)
        'remarks': t.bookshelf.watchTo(position: row.progress),
    }, home: row.item.detailUrl);
  }

  Future<void> _open(VideoBookshelfRow row) async {
    if (_working || _loading || !widget.isActive) return;
    setState(() {
      _working = true;
      _notice = null;
    });
    try {
      await _data.open(context, row);
    } catch (_) {
      if (mounted) setState(() => _notice = t.error.loadFailed);
    } finally {
      _finishWork();
    }
  }

  void _pick(VideoBookshelfRow row) {
    if (_working || _loading || !widget.isActive) return;
    setState(() {
      _setSelecting(true);
      if (!_selected.add(row.key)) _selected.remove(row.key);
    });
  }

  Future<void> _remove() async {
    final rows = _visible.where((r) => _selected.contains(r.key)).toList();
    final folders = _selectedFolders.intersection(_visibleFolders.keys.toSet());
    if (_working || (rows.isEmpty && folders.isEmpty)) return;
    final mode = widget.mode, search = widget.search, epoch = _epoch;
    final filter = _filter, folder = _folder;
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: Text(t.bookshelf.deleteSelected),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (rows.isNotEmpty)
              Text(t.bookshelf.confirmDeleteSelected(count: rows.length)),
            if (rows.isNotEmpty && mode == ShelfPageMode.favorite) ...[
              const SizedBox(height: 8),
              Text(t.videoLibrary.localFavoriteRemovalHint),
            ],
            if (rows.isNotEmpty && mode == ShelfPageMode.history) ...[
              const SizedBox(height: 8),
              Text(t.videoLibrary.localHistoryRemovalHint),
            ],
            if (folders.isNotEmpty) ...[
              Text(t.bookshelf.deleteFoldersQuestion(count: folders.length)),
              const SizedBox(height: 8),
              Text(t.videoLibrary.folderDeleteHint),
            ],
            if (widget.mode == ShelfPageMode.download) ...[
              const SizedBox(height: 8),
              if (rows.any((row) => row.localResourceId != null))
                Text(t.download.deleteFilesConfirm),
              if (rows.any((row) => row.localResourceId == null))
                Text(t.download.videoExternalFiles),
            ],
          ],
        ),
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
    if (confirmed != true ||
        !mounted ||
        !widget.isActive ||
        widget.mode != mode ||
        widget.search != search ||
        epoch != _epoch ||
        filter != _filter ||
        folder != _folder) {
      return;
    }
    setState(() {
      _working = true;
      _notice = null;
    });
    try {
      if (rows.isNotEmpty) await _data.remove(mode, rows);
      for (final folder in folders) {
        await _data.store.deleteFolder(folder);
      }
      if (mounted) showActionFeedback(context, t.bookshelf.actionRemoved);
      if (mounted) setState(() => _setSelecting(false));
      await _load();
    } catch (_) {
      await _load();
      if (mounted) setState(() => _notice = t.bookshelf.batchDeleteFailed);
    } finally {
      _finishWork();
    }
  }

  Future<void> _transfer(VideoFolderAssignment assignment) async {
    final rows = _visible.where((r) => _selected.contains(r.key)).toList();
    if (!_favorites ||
        _working ||
        rows.isEmpty ||
        _selectedFolders.isNotEmpty) {
      return;
    }
    final sources = rows.map((r) => r.source).toSet();
    setState(() {
      _working = true;
      _notice = null;
    });
    try {
      final saved = await showVideoFolderPicker(
        context,
        source: sources.length == 1
            ? sources.single
            : VideoLibraryStore.sharedFolderSource,
        itemKeys: rows
            .map(
              (r) =>
                  r.recordKey ?? VideoLibraryStore.itemKey(r.source, r.item.id),
            )
            .toSet(),
        assignment: assignment,
        store: _data.store,
      );
      if (saved == true) {
        if (mounted) {
          showActionFeedback(
            context,
            assignment == VideoFolderAssignment.move
                ? t.bookshelf.actionMoved
                : t.bookshelf.actionCopied,
          );
          setState(() => _setSelecting(false));
        }
        await _load();
      }
    } catch (_) {
      if (mounted) setState(() => _notice = t.videoLibrary.saveFailed);
    } finally {
      _finishWork();
    }
  }

  Future<void> _folderAction(String action) async {
    final source = _source;
    if (_working || !widget.isActive) return;
    if (action == '__delete') {
      await _deleteFolder();
      return;
    }
    if (action == '__help') {
      await showBookshelfHelpDialog(
        context,
        title: bookshelfHelpTitle(video: true, mode: widget.mode),
        content: bookshelfHelpContent(video: true, mode: widget.mode),
      );
      return;
    }
    if (!_favorites) return;
    if (!const {'__new', '__rename'}.contains(action)) {
      setState(() {
        _folder = action == '__all' ? null : action;
        _filter = const ShelfFacetSelection();
        _selected.clear();
      });
      return;
    }
    final folder = _folder;
    final epoch = _epoch;
    final initial = action == '__rename'
        ? _snapshot?.folders[folder]?.data['name']?.toString() ?? ''
        : '';
    setState(() {
      _working = true;
      _notice = null;
    });
    try {
      final name = await videoFolderName(context, initial: initial);
      if (name == null ||
          !mounted ||
          epoch != _epoch ||
          source != _source ||
          !_favorites ||
          !widget.isActive) {
        return;
      }
      if (action == '__new') {
        final created = await _data.store.createFolder(
          VideoLibraryStore.sharedFolderSource,
          name,
        );
        if (!mounted || epoch != _epoch || source != _source) return;
        _folder = created;
        _filter = const ShelfFacetSelection();
      } else if (folder != null) {
        await _data.store.renameFolder(folder, name);
      }
      await _load();
      if (mounted) {
        showActionFeedback(
          context,
          action == '__new'
              ? t.bookshelf.folderCreated
              : t.bookshelf.actionRenamed,
        );
      }
    } catch (error) {
      if (mounted) setState(() => _notice = videoLibraryError(error));
    } finally {
      _finishWork();
    }
  }

  Widget _action(String id, String label, VoidCallback? action) => KeyedSubtree(
    key: ValueKey('video-shelf.$id'),
    child: NativeVideoTextButton(
      label: label,
      tooltip: label,
      light: false,
      maxWidth: 190,
      onPressed: action,
    ),
  );

  Map<String, VideoLibraryEntry> get _folders => _source == null
      ? {
          for (final entry
              in _snapshot?.folders.entries ??
                  <MapEntry<String, VideoLibraryEntry>>[])
            if (!entry.value.deleted) entry.key: entry.value,
        }
      : _snapshot?.foldersFor(_source!) ?? <String, VideoLibraryEntry>{};

  Map<String, VideoLibraryEntry> get _visibleFolders =>
      _favorites &&
          !_filter.isActive &&
          _folder == null &&
          widget.search.keyword.isEmpty
      ? _folders
      : const {};

  void _pickFolder(String id) {
    if (_working || _loading || !widget.isActive) return;
    setState(() {
      _setSelecting(true);
      if (!_selectedFolders.add(id)) _selectedFolders.remove(id);
    });
  }

  Future<void> _deleteFolder() async {
    final folder = _folder, epoch = _epoch;
    if (folder == null || !_folders.containsKey(folder) || _working) return;
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
    if (confirmed != true ||
        !mounted ||
        !widget.isActive ||
        epoch != _epoch ||
        folder != _folder) {
      return;
    }
    setState(() {
      _working = true;
      _notice = null;
    });
    try {
      await _data.store.deleteFolder(folder);
      if (!mounted) return;
      setState(() {
        _folder = null;
        _filter = const ShelfFacetSelection();
      });
      await _load();
      if (mounted) showActionFeedback(context, t.bookshelf.actionRemoved);
    } catch (_) {
      if (mounted) setState(() => _notice = t.videoLibrary.saveFailed);
    } finally {
      _finishWork();
    }
  }

  Widget _header(List<VideoBookshelfRow> rows) {
    final actionEpoch = _filterScopeEpoch, actionMode = widget.mode;
    final actionScope = _refreshScope;
    final folders = _visibleFolders;
    final allSelected =
        (rows.isNotEmpty || folders.isNotEmpty) &&
        _selected.containsAll(rows.map((r) => r.key)) &&
        _selectedFolders.containsAll(folders.keys);
    final actionsScope = BookshelfActionsScope.of(context);
    final inMainShelf = actionsScope != null;
    final lifted = actionsScope?.header != null;
    final currentTitle = !_favorites
        ? (widget.mode == ShelfPageMode.history
              ? (inMainShelf ? '' : t.bookshelf.history)
              : t.bookshelf.download)
        : _folder == '__unfiled'
        ? t.videoLibrary.unfiled
        : _folders[_folder]?.data['name']?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BookshelfContentToolbar(
          selection: _selecting
              ? BookshelfSelectionToolbar(
                  keyPrefix: 'video-shelf',
                  privacyAction: lifted
                      ? null
                      : const CollectionCoverPrivacyButton(
                          key: ValueKey('video-shelf.cover-privacy'),
                        ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: lifted ? 0 : 4,
                  ),
                  selectedCount: _selectionCount,
                  allSelected: allSelected,
                  onCancel: _working
                      ? null
                      : () => setState(() => _setSelecting(false)),
                  onToggleAll: _working || (rows.isEmpty && folders.isEmpty)
                      ? null
                      : () => setState(() {
                          final keys = rows.map((r) => r.key).toSet();
                          if (allSelected) {
                            _selected.removeAll(keys);
                            _selectedFolders.removeAll(folders.keys);
                          } else {
                            _selected.addAll(keys);
                            _selectedFolders.addAll(folders.keys);
                          }
                        }),
                )
              : null,
          keyPrefix: 'video-shelf',
          headerIdentity: (actionScope, actionEpoch),
          canRun: () =>
              mounted &&
              widget.isActive &&
              !_working &&
              !_loading &&
              !_selecting &&
              actionEpoch == _filterScopeEpoch &&
              (!lifted || actionScope == _refreshScope) &&
              actionMode == widget.mode,
          privacyAction: const CollectionCoverPrivacyButton(
            key: ValueKey('video-shelf.cover-privacy'),
            emphasizeProtected: true,
          ),
          title: currentTitle,
          subtitle: _folder == null && _rows != null
              ? t.videoLibrary.results(count: rows.length)
              : '',
          filterActive: _filter.isActive,
          showFilter: true,
          onFilter: !_working && !_loading && !_failed && _rows != null
              ? _editFilter
              : null,
          view: _view == ApiVideoView.grid
              ? BookshelfContentView.grid
              : BookshelfContentView.list,
          showCreateFolder: _favorites,
          onCreateFolder: _working || _loading || _failed || _rows == null
              ? null
              : () => _folderAction('__new'),
          folderRootLabel: t.common.root,
          onBack: _favorites && _folder != null
              ? () => unawaited(_folderAction('__all'))
              : null,
          onToggleView: _working ? null : _toggleView,
          onManage:
              !_working && !_loading && (rows.isNotEmpty || folders.isNotEmpty)
              ? () => setState(() => _setSelecting(true))
              : null,
          arrangement: BookshelfActionsScope.forPane(
            context,
            video: true,
            mode: widget.mode,
          ),
          moreOptions: {
            if (_favorites) ...{
              if (_folders.containsKey(_folder))
                '__rename': t.videoLibrary.renameFolder,
              if (_folders.containsKey(_folder))
                '__delete': t.videoLibrary.deleteFolder,
            },
            '__help': t.common.help,
          },
          moreGroups: [
            ['__rename'],
            ['__delete'],
            ['__help'],
          ],
          onMore: (value) => unawaited(_folderAction(value)),
        ),
        if (_notice != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              _notice!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_failed && _rows != null && (rows.isNotEmpty || folders.isNotEmpty))
          Padding(
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
                _action('retry', t.common.retry, _load),
              ],
            ),
          ),
        if ((_loading && _rows != null && !_pullRefreshing) ||
            (_working && (ModalRoute.isCurrentOf(context) ?? true)))
          const LinearProgressIndicator(minHeight: 2),
      ],
    );
  }

  Widget _floatingSelection(List<VideoBookshelfRow> rows, Widget child) {
    final selectedRows = rows.where((r) => _selected.contains(r.key)).toList();
    return BookshelfFloatingSelectionActions(
      keyPrefix: 'video-shelf',
      selecting: _selecting,
      selectedCount: _selectionCount,
      busy: _working,
      actions: [
        if (_favorites) ...[
          BookshelfBatchAction(
            id: 'move',
            label: t.bookshelf.moveTo,
            icon: Icons.drive_file_move_outlined,
            symbol: 'folder',
            onPressed:
                !_working && _selectedFolders.isEmpty && selectedRows.isNotEmpty
                ? () => _transfer(VideoFolderAssignment.move)
                : null,
          ),
          BookshelfBatchAction(
            id: 'copy',
            label: t.bookshelf.copyTo,
            icon: Icons.copy_outlined,
            symbol: 'doc.on.doc',
            onPressed:
                !_working && _selectedFolders.isEmpty && selectedRows.isNotEmpty
                ? () => _transfer(VideoFolderAssignment.copy)
                : null,
          ),
        ],
        BookshelfBatchAction(
          id: 'remove',
          label: t.common.delete,
          icon: Icons.delete_outline,
          symbol: 'trash',
          onPressed: !_working && _selectionCount > 0 ? _remove : null,
        ),
      ],
      child: child,
    );
  }

  Widget _empty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _failed ? Icons.cloud_off_outlined : Icons.video_library_outlined,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            _failed
                ? (_failedPullScope == _refreshScope
                      ? t.common.refreshFailed
                      : t.common.loadingFailed)
                : _filter.isActive
                ? t.bookshelf.facets.noResults
                : widget.search.keyword.isNotEmpty
                ? t.videoLibrary.noResults
                : _folder != null
                ? t.videoLibrary.folderEmpty
                : _favorites
                ? t.videoLibrary.favoritesEmpty
                : widget.mode == ShelfPageMode.history
                ? t.videoLibrary.historyEmpty
                : t.bookshelf.noDownload,
            textAlign: TextAlign.center,
          ),
          if (_filter.isActive && !_failed) ...[
            const SizedBox(height: 12),
            _action(
              'clear-empty-filter',
              t.bookshelf.facets.clear,
              _clearFilter,
            ),
          ],
          if (_failed) ...[
            const SizedBox(height: 12),
            _action('retry', t.common.retry, _load),
          ],
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final rows = _visible, byKey = {for (final row in rows) row.key: row};
    // A short placeholder must not claim or clamp the loaded list's offset.
    final storageKey = _rows == null
        ? '$_collectionKey.pending'
        : _collectionKey;
    return CollectionCoverFitScope(
      child: CollectionCoverPrivacyScope(
        child: PopScope(
          canPop: !_selecting && (_folder == null || !widget.isActive),
          onPopInvokedWithResult: (popped, _) {
            if (popped || !widget.isActive || _working) return;
            if (_selecting) {
              setState(() => _setSelecting(false));
            } else if (_folder != null) {
              setState(() {
                _folder = null;
                _filter = const ShelfFacetSelection();
              });
            }
          },
          child: Column(
            children: [
              _header(rows),
              Expanded(
                child: _floatingSelection(
                  rows,
                  BookshelfReturnToTop(
                    key: ValueKey(storageKey),
                    enabled:
                        widget.showReturnToTop &&
                        widget.isActive &&
                        !_selecting &&
                        !_working &&
                        !_loading &&
                        rows.isNotEmpty,
                    child: PullRefreshFeedback.indicator(
                      notificationPredicate: (notice) =>
                          !_working && widget.isActive && notice.depth == 0,
                      onRefresh: _refreshFromPull,
                      active: widget.isActive && !_working,
                      scope: _refreshScope,
                      child: LayoutBuilder(
                        builder: (context, constraints) => ApiVideoCollection(
                          imageRefreshToken: _imageRefreshToken,
                          retryMissingCoverDetailsOnRefresh: false,
                          key: ValueKey(storageKey),
                          gridColumns: BookshelfContentLayout.columns(
                            constraints.maxWidth,
                          ),
                          gridItemExtent: BookshelfContentLayout.itemExtent(
                            context,
                            constraints.maxWidth,
                          ),
                          gridMainAxisSpacing: BookshelfContentLayout.spacing,
                          listItemExtent:
                              BookshelfDetailedContent.contentHeight(context) +
                              BookshelfContentLayout.spacing,
                          listSeparatorHeight: BookshelfContentLayout.spacing,
                          listTileBuilder: (context, item) {
                            final row = byKey[item.id];
                            final views = item.sourceViews;
                            final rating = item.sourceRating;
                            final votes = item.sourceRatingDisplayCount;
                            final time =
                                row == null ||
                                    row.updatedAt.millisecondsSinceEpoch <= 0
                                ? ''
                                : DateFormat(
                                    'yyyy-MM-dd HH:mm',
                                  ).format(row.updatedAt.toLocal());
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: BookshelfContentLayout.spacing,
                              ),
                              child: BookshelfDetailedContent(
                                cover: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    kComicCardBorderRadius,
                                  ),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      CollectionSelectionTint(
                                        selected:
                                            _selecting &&
                                            _selected.contains(item.id),
                                        child: ApiVideoPoster(
                                          item: item,
                                          source: row?.source,
                                          refreshToken: _imageRefreshToken,
                                        ),
                                      ),
                                      PositionedDirectional(
                                        top: CollectionSelectionMark.inset,
                                        end: CollectionSelectionMark.inset,
                                        child: CollectionSelectionMark(
                                          visible: _selecting,
                                          selected: _selected.contains(item.id),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                title: item.title,
                                source:
                                    _names[row?.source] ?? row?.source ?? '',
                                metadata: item.summary.join(' · '),
                                description: item.description,
                                statistics: [
                                  if (views != null)
                                    item.sourceViewsAreClicks
                                        ? t.videoLibrary.sourceClicks(
                                            count: views,
                                          )
                                        : t.videoLibrary.sourceViews(
                                            count: views,
                                          ),
                                  if (rating != null)
                                    votes == null
                                        ? t.videoLibrary.sourceRatingOnly(
                                            score: rating,
                                          )
                                        : t.videoLibrary.sourceRating(
                                            score: rating,
                                            count: votes,
                                          ),
                                ].join(' · '),
                                progress: row == null || row.progress.isEmpty
                                    ? ''
                                    : t.bookshelf.watchTo(
                                        position: row.progress,
                                      ),
                                time: time.isEmpty
                                    ? ''
                                    : widget.mode == ShelfPageMode.history
                                    ? t.videoLibrary.lastWatchedAt(time: time)
                                    : t.bookshelf.collectedAt(time: time),
                              ),
                            );
                          },
                          posterRadius: kComicCardBorderRadius,
                          contentPadding: const EdgeInsets.fromLTRB(
                            12,
                            8,
                            12,
                            8,
                          ),
                          gridCaptionBuilder: (context, item) =>
                              _caption(item, byKey[item.id]),
                          leadingListExtent:
                              BookshelfFolderCard.videoListHeight(context) +
                              BookshelfContentLayout.spacing,
                          leadingItems: [
                            for (final folder in _visibleFolders.entries)
                              Padding(
                                padding: _view == ApiVideoView.list
                                    ? const EdgeInsets.only(bottom: 12)
                                    : EdgeInsets.zero,
                                child: BookshelfFolderCard(
                                  key: ValueKey(
                                    'video-shelf.folder.${folder.key}',
                                  ),
                                  title:
                                      folder.value.data['name']?.toString() ??
                                      '',
                                  workCount: _rows == null
                                      ? null
                                      : _folderWorkCounts[folder.key] ?? 0,
                                  view: _view == ApiVideoView.grid
                                      ? BookshelfContentView.grid
                                      : BookshelfContentView.list,
                                  imageKey: FolderCoverIdentity.video(
                                    folder.key,
                                  ),
                                  menu: FolderCoverMenu(
                                    onCover: _view == ApiVideoView.grid,
                                    target: FolderCoverService.video(
                                      folder.key,
                                      folder.value,
                                      _data.store,
                                      canRun: () =>
                                          mounted &&
                                          widget.isActive &&
                                          !_working &&
                                          !_selecting,
                                    ),
                                    canRun: () =>
                                        mounted &&
                                        widget.isActive &&
                                        !_working &&
                                        !_selecting,
                                  ),
                                  selectionMode: _selecting,
                                  isSelected: _selectedFolders.contains(
                                    folder.key,
                                  ),
                                  onTap: () => _selecting
                                      ? _pickFolder(folder.key)
                                      : unawaited(_folderAction(folder.key)),
                                  onLongPress: (_) => _pickFolder(folder.key),
                                ),
                              ),
                          ],
                          sourceByItem: {
                            for (final row in rows) row.key: row.source,
                          },
                          items: [for (final row in rows) _display(row)],
                          mode: _view,
                          storageKey: storageKey,
                          emptyState: _empty(),
                          contentBottomPadding:
                              NativeNavigationInset.of(context) +
                              (_selecting
                                  ? BookshelfFloatingSelectionActions
                                        .contentBottomPadding
                                  : 24),
                          loading: _rows == null && !_failed,
                          selecting: _selecting,
                          selected: _selected,
                          detailsActive:
                              widget.isActive && !_selecting && !_working,
                          onDetailLoaded: (display) {
                            final row = byKey[display.id];
                            if (row == null || !widget.isActive) return;
                            final original = ApiVideoItem.fromJson({
                              ...display.toLibraryJson(),
                              'id': row.item.id,
                            }, home: row.item.detailUrl);
                            unawaited(
                              _data.store
                                  .observeDetails(row.source, [original])
                                  .catchError((Object _) {}),
                            );
                          },
                          badges: {
                            for (final row in rows)
                              row.key: [
                                if (_originalFolders(row).isNotEmpty)
                                  _originalFolders(row),
                                _names[row.source] ?? row.source,
                                if (row.progress.isNotEmpty) row.progress,
                              ].join(' · '),
                          },
                          onOpen: (item) {
                            final row = byKey[item.id];
                            if (row != null) {
                              _selecting ? _pick(row) : unawaited(_open(row));
                            }
                          },
                          onLongPress: (item) {
                            final row = byKey[item.id];
                            if (row != null &&
                                widget.isActive &&
                                !_working &&
                                !_loading) {
                              if (!_selecting) {
                                unawaited(HapticFeedback.selectionClick());
                              }
                              _pick(row);
                            }
                          },
                          recordNoteBuilder:
                              widget.mode == ShelfPageMode.history
                              ? (item) {
                                  final row = byKey[item.id];
                                  return row == null
                                      ? ''
                                      : [
                                          if (row.progress.isNotEmpty)
                                            t.bookshelf.watchTo(
                                              position: row.progress,
                                            ),
                                          if (row
                                                  .updatedAt
                                                  .millisecondsSinceEpoch >
                                              0)
                                            t.videoLibrary.lastWatchedAt(
                                              time: DateFormat(
                                                'yyyy-MM-dd HH:mm',
                                              ).format(row.updatedAt.toLocal()),
                                            ),
                                        ].join('\n');
                                }
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
