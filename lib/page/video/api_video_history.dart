import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/widget/keyword_scope_menu.dart';
import 'package:collection/collection.dart';
import 'package:zephyr/widgets/pull_refresh_feedback.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'dart:async';
import 'package:intl/intl.dart';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/bookshelf/models/shelf_delete_prompt.dart';
import 'package:zephyr/page/bookshelf/service/shelf_facet_adapters.dart';
import 'package:zephyr/page/bookshelf/service/video_bookshelf_index.dart';
import 'package:zephyr/page/bookshelf/widgets/shelf_filter_sheet.dart';
import 'package:zephyr/page/search/widget/search_input_dialog.dart';
import 'package:zephyr/page/search/widget/search_keyboard.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/widgets/source_choice_menu.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/page/video/video_cover_overlay.dart';
import 'package:zephyr/page/video/source_video_list_header.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_selection_toolbar.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_floating_selection_actions.dart';

ApiVideoItem apiVideoHistoryItem(
  VideoWatchRecord row, {
  String remarks = '',
  String year = '',
  String itemNamespace = '',
  bool containCover = false,
}) {
  final detail = videoPublicPage(row.watchUrl);
  String? id;
  if (detail != null) {
    for (final route in [
      r'^/anime/([a-f0-9]{16,64})\.html$',
      r'^/voddetail/([1-9][0-9]{0,14})\.html$',
      r'^/index\.php/vod/detail/id/([1-9][0-9]{0,14})\.html$',
      r'^/vod/([1-9][0-9]{0,14})/$',
    ]) {
      id = RegExp(route).firstMatch(detail.path)?.group(1);
      if (id != null) break;
    }
  }
  if (detail != null && id == null) {
    final hid = RegExp(
      r'^/videos/([A-Za-z0-9_-]{1,64})$',
    ).firstMatch(detail.path)?.group(1);
    if (hid != null) {
      id = itemNamespace.isEmpty ? hid : '$itemNamespace:$hid';
    }
  }
  if (detail != null && detail.path == '/watch') {
    final watchId = detail.queryParameters['v'];
    if (watchId != null)
      id = itemNamespace.isEmpty ? watchId : '$itemNamespace:$watchId';
  }
  if (detail == null || id == null) {
    throw const FormatException('Unsupported video history identity');
  }
  return ApiVideoItem(
    id: id,
    title: row.title,
    detailUrl: detail,
    coverUrl: row.coverUrl,
    containCover: containCover,
    remarks: remarks,
    sourceDuration: formatKnownVideoDuration(row.duration),
    typeName: row.metadata['typeName'] ?? '',
    genres: row.metadata['genres'] ?? '',
    year: year.isNotEmpty ? year : row.metadata['year'] ?? '',
    area: row.metadata['area'] ?? '',
    language: row.metadata['language'] ?? '',
    writers: row.metadata['writers'] ?? '',
  );
}

String _historyWorkKey(Uri url) =>
    videoPublicPage(url)?.toString() ?? url.toString();

bool _supportedHistoryRecord(
  VideoWatchRecord row, {
  String itemNamespace = '',
  bool allowStandaloneWatch = false,
}) {
  // Standalone watch IDs can only open through the browser route.
  if (!allowStandaloneWatch && row.watchUrl.path == '/watch') return false;
  try {
    apiVideoHistoryItem(row, itemNamespace: itemNamespace);
    return true;
  } on FormatException {
    return false;
  }
}

class ApiVideoContinueEntry extends StatefulWidget {
  const ApiVideoContinueEntry({
    super.key,
    required this.source,
    required this.home,
    required this.onOpen,
    this.itemNamespace = '',
    this.posterAspectRatio = 2 / 3,
  });
  final String source;
  final String itemNamespace;
  final double posterAspectRatio;
  final Uri home;
  final Future<void> Function(ApiVideoItem, Uri) onOpen;
  @override
  State<ApiVideoContinueEntry> createState() => _ApiVideoContinueEntryState();
}

class _ApiVideoContinueEntryState extends State<ApiVideoContinueEntry> {
  VideoWatchRecord? _record;
  int _epoch = 0;
  @override
  void initState() {
    super.initState();
    VideoWatchHistory.changes.addListener(_read);
    _read();
  }

  @override
  void dispose() {
    _epoch++;
    VideoWatchHistory.changes.removeListener(_read);
    super.dispose();
  }

  Future<void> _read() async {
    final epoch = ++_epoch;
    try {
      final rows = await VideoWatchHistory.read(widget.source);
      final row = rows
          .where(
            (e) =>
                e.watchUrl.origin == widget.home.origin &&
                _supportedHistoryRecord(
                  e,
                  itemNamespace: widget.itemNamespace,
                ) &&
                !e.completed &&
                e.position > Duration.zero,
          )
          .firstOrNull;
      if (mounted && epoch == _epoch) setState(() => _record = row);
    } catch (_) {
      /* Optional resume never blocks the library. */
    }
  }

  String _time(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) {
    final row = _record;
    if (row == null) return const SizedBox.shrink();
    return ListTile(
      key: const ValueKey('api-continue'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: SizedBox(
        width: 28,
        height: 42,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: ApiVideoPoster(
            item: apiVideoHistoryItem(
              row,
              itemNamespace: widget.itemNamespace,
              containCover: widget.posterAspectRatio > 1,
            ),
          ),
        ),
      ),
      title: Text(
        row.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      subtitle: Text(
        '${t.bookshelf.watchTo(position: _time(row.position))} · ${t.videoMetadata.duration(value: formatKnownVideoDuration(row.duration))}',
        maxLines: 2,
      ),
      trailing: const Icon(Icons.play_circle_outline_rounded),
      onTap: () => widget.onOpen(
        apiVideoHistoryItem(
          row,
          itemNamespace: widget.itemNamespace,
          containCover: widget.posterAspectRatio > 1,
        ),
        row.watchUrl,
      ),
    );
  }
}

class ApiVideoHistory extends StatefulWidget {
  const ApiVideoHistory({
    super.key,
    required this.source,
    required this.home,
    required this.mode,
    required this.onOpen,
    this.itemNamespace = '',
    this.allowStandaloneWatch = false,
    this.posterAspectRatio = 2 / 3,
    this.loadDetail,
    this.onDetailLoaded,
    this.active = true,
    this.compactHeader = false,
    this.onToggleView,
    this.headerLeading = const SourceBackButton(),
  });
  final Widget? headerLeading;
  final bool compactHeader;
  final VoidCallback? onToggleView;
  final String source;
  final String itemNamespace;
  final bool allowStandaloneWatch;
  final double posterAspectRatio;
  final Uri home;
  final ApiVideoView mode;
  final Future<void> Function(ApiVideoItem, Uri) onOpen;
  final Future<ApiVideoItem> Function(ApiVideoItem)? loadDetail;
  final ValueChanged<ApiVideoItem>? onDetailLoaded;
  final bool active;
  @override
  State<ApiVideoHistory> createState() => _ApiVideoHistoryState();
}

class _ApiVideoHistoryState extends State<ApiVideoHistory> {
  List<VideoWatchRecord>? _records;
  bool _failed = false, _selecting = false, _working = false;
  final _selectedPaths = <String>{};
  final _searchFocus = FocusNode();
  String _query = '', _sort = 'recent';
  KeywordSearchScope _keywordScope = KeywordSearchScope.all;
  bool _searching = false;
  int _epoch = 0;
  PageStorageBucket? _storage;
  bool _restoredConditions = false, _openingFilters = false;
  ShelfFacetSelection _facets = const ShelfFacetSelection();

  String get _conditionsKey =>
      'api-video-history.conditions.${widget.source}.${widget.home.origin}.${widget.itemNamespace}';

  void _restoreConditions() {
    final saved = _storage?.readState(context, identifier: _conditionsKey);
    _query = saved is Map && saved['query'] is String ? saved['query'] : '';
    _keywordScope = saved is Map
        ? parseKeywordSearchScope(saved['keywordScope']) ??
              KeywordSearchScope.all
        : KeywordSearchScope.all;
    _sort = saved is Map && saved['sort'] == 'title' ? 'title' : 'recent';
    _facets = saved is Map && saved['facets'] is ShelfFacetSelection
        ? saved['facets']
        : const ShelfFacetSelection();
  }

  void _saveConditions() => _storage?.writeState(context, {
    'query': _query,
    'keywordScope': _keywordScope.name,
    'sort': _sort,
    'facets': _facets,
  }, identifier: _conditionsKey);

  void _setQuery(String value) {
    setState(() => _query = value);
    _saveConditions();
  }

  Widget _keywordMenu() => KeywordScopeMenu(
    scope: _keywordScope,
    compact: true,
    onChanged: (scope) {
      setState(() => _keywordScope = scope);
      _saveConditions();
    },
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _storage = PageStorage.maybeOf(context);
    if (!_restoredConditions) {
      _restoreConditions();
      _restoredConditions = true;
    }
  }

  @override
  void didUpdateWidget(covariant ApiVideoHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed =
        oldWidget.source != widget.source ||
        oldWidget.home.origin != widget.home.origin ||
        oldWidget.itemNamespace != widget.itemNamespace ||
        oldWidget.allowStandaloneWatch != widget.allowStandaloneWatch;
    if (!widget.active || changed) {
      _pullScope = null;
      _searchFocus.unfocus();
    }
    if (changed) {
      _selectedPaths.clear();
      _selecting = false;
      _records = null;
      _failed = false;
      _failedPullScope = null;
      _restoreConditions();
      _read();
    }
  }

  @override
  void initState() {
    super.initState();
    VideoWatchHistory.changes.addListener(_read);
    _read();
  }

  @override
  void dispose() {
    _epoch++;
    _searchFocus.dispose();
    VideoWatchHistory.changes.removeListener(_read);
    super.dispose();
  }

  final _refreshIndicator = GlobalKey<RefreshIndicatorState>();
  int _imageRefreshToken = 0;
  Object? _pullScope, _failedPullScope;
  Future<void>? _readTask;

  Object get _refreshScope => (
    _conditionsKey,
    widget.allowStandaloneWatch,
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
    final before = _visibleSnapshot();
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
      return before != null &&
              const DeepCollectionEquality().equals(before, _visibleSnapshot())
          ? PullRefreshResult.unchanged
          : PullRefreshResult.updated;
    } finally {
      if (mounted && _pullScope == scope) setState(() => _pullScope = null);
    }
  }

  Future<void> _readNow() async {
    final epoch = ++_epoch;
    final source = widget.source;
    final origin = widget.home.origin;
    final namespace = widget.itemNamespace;
    final allowStandaloneWatch = widget.allowStandaloneWatch;
    try {
      final records = await VideoWatchHistory.read(source);
      if (mounted && epoch == _epoch) {
        setState(() {
          _records = records
              .where(
                (e) =>
                    e.watchUrl.origin == origin &&
                    _supportedHistoryRecord(
                      e,
                      itemNamespace: namespace,
                      allowStandaloneWatch: allowStandaloneWatch,
                    ),
              )
              .toList();
          _failed = false;
          _failedPullScope = null;
          _selectedPaths.retainAll(
            _records!.map((row) => _historyWorkKey(row.watchUrl)),
          );
        });
      }
    } catch (_) {
      if (mounted && epoch == _epoch) setState(() => _failed = true);
    }
  }

  Future<void> _remove(Set<String> paths, {bool clear = false}) async {
    if (_working || paths.isEmpty) return;
    _searchFocus.unfocus();
    final source = widget.source;
    final scope = _conditionsKey;
    final selected = (_records ?? <VideoWatchRecord>[])
        .where((row) => paths.contains(_historyWorkKey(row.watchUrl)))
        .toList();
    if (selected.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: Text(clear ? t.videoLibrary.clearHistory : t.common.delete),
        content: Text(
          '${shelfDeletePrompt(mode: ShelfPageMode.history, folders: 0, comics: paths.length)}\n\n${t.videoLibrary.localHistoryRemovalHint}',
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
        !widget.active ||
        widget.source != source ||
        scope != _conditionsKey) {
      return;
    }
    setState(() => _working = true);
    try {
      for (final row in selected) {
        await VideoWatchHistory.remove(source, row.watchUrl);
      }
      if (mounted && scope == _conditionsKey) {
        setState(() {
          _selecting = false;
          _selectedPaths.clear();
        });
      }
    } catch (_) {
      if (mounted && widget.active && scope == _conditionsKey) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.videoLibrary.saveFailed)));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  ShelfFacetEntry _facetEntry(VideoWatchRecord row) => shelfFacetEntryFromVideo(
    VideoBookshelfRow(
      key: _historyWorkKey(row.watchUrl),
      source: widget.source,
      item: apiVideoHistoryItem(row, itemNamespace: widget.itemNamespace),
      updatedAt: row.updatedAt,
    ),
  );

  void _clearFacets() {
    setState(() => _facets = const ShelfFacetSelection());
    _saveConditions();
  }

  Map<String, String> _sortOptions() => {
    'recent': t.videoPersonal.recent,
    'title': t.videoLibrary.titleOrder,
  };

  void _changeSort(String value) {
    _searchFocus.unfocus();
    setState(() => _sort = value);
    _saveConditions();
  }

  Widget _filterButton(bool empty, List<VideoWatchRecord> candidates) =>
      SourceFilterIconButton(
        key: const ValueKey('api-history.filter'),
        bare: false,
        tooltip: _facets.isActive
            ? t.videoFilters.active
            : t.bookshelf.facets.title,
        onPressed: empty || _working || _selecting
            ? null
            : () => _editFilters(candidates),
        active: _facets.isActive,
      );

  Future<void> _editFilters(List<VideoWatchRecord> candidates) async {
    if (_openingFilters || _working || !widget.active) return;
    _openingFilters = true;
    final scope = _conditionsKey, query = _query, keywordScope = _keywordScope;
    _searchFocus.unfocus();
    try {
      final result = await showShelfFilterSheet(
        context,
        entries: candidates.map(_facetEntry).toList(),
        initial: _facets,
        preferenceKey:
            'api-video.history|${widget.source}|${widget.home.origin}|${widget.itemNamespace}',
        scopeLabel: t.videoSource.localHistory,
        currentFolder: null,
        hierarchical: false,
      );
      if (!mounted ||
          !widget.active ||
          result == null ||
          scope != _conditionsKey ||
          query != _query ||
          keywordScope != _keywordScope) {
        return;
      }
      setState(() {
        _facets = result;
        _selecting = false;
        _selectedPaths.clear();
      });
      _saveConditions();
    } finally {
      _openingFilters = false;
    }
  }

  String _recordNote(VideoWatchRecord row) => [
    t.bookshelf.watchTo(position: _time(row.position)),
    if (widget.mode == ApiVideoView.list)
      t.videoLibrary.lastWatchedAt(
        time: DateFormat('yyyy-MM-dd HH:mm').format(row.updatedAt.toLocal()),
      ),
  ].join('\n');

  String _time(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
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

  List<Object?>? _visibleSnapshot() {
    if (_records == null) return null;
    final (allRows, _, rows) = _historyRows();
    return [allRows.isEmpty, for (final row in rows) row.toJson()];
  }

  (List<VideoWatchRecord>, List<VideoWatchRecord>, List<VideoWatchRecord>)
  _historyRows() {
    final byPath = <String, VideoWatchRecord>{};
    for (final row in _records ?? <VideoWatchRecord>[]) {
      byPath.putIfAbsent(_historyWorkKey(row.watchUrl), () => row);
    }
    final allRows = byPath.values.toList();
    final matches = keywordTitleMatcher(_query);
    final candidates = allRows
        .where(
          (row) =>
              _query.trim().isEmpty ||
              (_keywordScope == KeywordSearchScope.title
                  ? matches([row.title])
                  : matches([_facetEntry(row).searchText])),
        )
        .toList();
    final rows = candidates
        .where(
          (row) =>
              !_facets.isActive ||
              shelfFacetMatches(_facetEntry(row), _facets, currentFolder: null),
        )
        .toList();
    rows.sort((a, b) {
      final order = _sort == 'title'
          ? a.title.compareTo(b.title)
          : b.updatedAt.compareTo(a.updatedAt);
      return order == 0
          ? a.watchUrl.toString().compareTo(b.watchUrl.toString())
          : order;
    });
    return (allRows, candidates, rows);
  }

  @override
  Widget build(BuildContext context) {
    final (allRows, candidates, rows) = _historyRows();
    final visiblePaths = rows
        .map((row) => _historyWorkKey(row.watchUrl))
        .toSet();
    final visibleSelected = _selectedPaths.intersection(visiblePaths);
    final items = [
      for (final row in rows)
        apiVideoHistoryItem(
          row,
          itemNamespace: widget.itemNamespace,
          containCover: widget.posterAspectRatio > 1,
          remarks: _recordNote(row),
        ),
    ];
    return CollectionCoverPrivacyScope(
      child: BookshelfFloatingSelectionActions(
        selecting: widget.compactHeader && _selecting,
        selectedCount: visibleSelected.length,
        busy: _working,
        keyPrefix: 'api-history.selection',
        actions: [
          BookshelfBatchAction(
            id: 'delete',
            label: t.common.delete,
            icon: Icons.delete_outline,
            symbol: 'trash',
            onPressed: visibleSelected.isEmpty || _working
                ? null
                : () => _remove(visibleSelected),
          ),
        ],
        child: PopScope(
          canPop: !widget.active || (!_selecting && !_working),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && _selecting && !_working) {
              setState(() {
                _selecting = false;
                _selectedPaths.clear();
              });
            }
          },
          child: Column(
            children: [
              if (!widget.compactHeader)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: SearchQueryField(
                          key: ValueKey('$_conditionsKey.search'),
                          query: _query,
                          inline: true,
                          autoExpand: false,
                          closeOnSubmit: false,
                          focusNode: _searchFocus,
                          hintText: t.videoLibrary.searchHint,
                          semanticLabel: t.videoLibrary.searchHint,
                          onChanged: _setQuery,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _keywordMenu(),
                      const CollectionCoverPrivacyButton(
                        key: ValueKey('api-history.cover-privacy'),
                      ),
                    ],
                  ),
                ),
              if (widget.compactHeader)
                SafeArea(
                  bottom: false,
                  child: _selecting
                      ? BookshelfSelectionToolbar(
                          keyPrefix: 'api-history.selection',
                          selectedCount: visibleSelected.length,
                          allSelected:
                              visiblePaths.isNotEmpty &&
                              _selectedPaths.containsAll(visiblePaths),
                          onCancel: _working
                              ? null
                              : () => setState(() {
                                  _selecting = false;
                                  _selectedPaths.clear();
                                }),
                          onToggleAll: _working || visiblePaths.isEmpty
                              ? null
                              : () => setState(() {
                                  _selectedPaths.containsAll(visiblePaths)
                                      ? _selectedPaths.removeAll(visiblePaths)
                                      : _selectedPaths.addAll(visiblePaths);
                                }),
                        )
                      : Column(
                          children: [
                            SourceVideoListHeader(
                              key: const ValueKey('api-history.compact-header'),
                              keyPrefix: 'api-history',
                              menuKey: const ValueKey('api-history.manage'),
                              leading: widget.headerLeading,
                              searching: _searching,
                              searchScope: _keywordMenu(),
                              title: _query.isEmpty
                                  ? t.videoSource.localHistory
                                  : _query,
                              searchField: SearchQueryField(
                                key: ValueKey('$_conditionsKey.search'),
                                query: _query,
                                inline: true,
                                closeOnSubmit: false,
                                focusNode: _searchFocus,
                                hintText: t.videoLibrary.searchHint,
                                onChanged: _setQuery,
                              ),
                              onSearch: _working
                                  ? null
                                  : () {
                                      setState(() => _searching = !_searching);
                                      if (_searching) {
                                        requestSearchKeyboard(
                                          _searchFocus,
                                          isCurrent: () =>
                                              mounted &&
                                              widget.active &&
                                              _searching,
                                        );
                                      } else {
                                        _searchFocus.unfocus();
                                      }
                                    },
                              options: {
                                if (allRows.isNotEmpty)
                                  'manage': t.videoSource.manage,
                                if (rows.isNotEmpty)
                                  'clear': t.videoLibrary.clearHistory,
                              },
                              onMore: (action) {
                                if (_working) return;
                                _searchFocus.unfocus();
                                if (action == 'clear') {
                                  _remove(visiblePaths, clear: true);
                                } else if (action == 'manage') {
                                  setState(() {
                                    _selecting = true;
                                    _searching = false;
                                    _selectedPaths.clear();
                                  });
                                }
                              },
                            ),
                            SourceVideoResultsToolbar(
                              key: const ValueKey(
                                'api-history.compact-results',
                              ),
                              keyPrefix: 'api-history',
                              count: _records == null
                                  ? (_failed
                                        ? t.common.unknown
                                        : t.common.loading)
                                  : t.videoLibrary.results(count: rows.length),
                              sort: _sort,
                              sortOptions: _sortOptions(),
                              onSort: _working || allRows.isEmpty
                                  ? null
                                  : _changeSort,
                              gridView: widget.onToggleView == null
                                  ? null
                                  : widget.mode == ApiVideoView.grid,
                              onToggleView: _working
                                  ? null
                                  : widget.onToggleView,
                              filter: _filterButton(
                                allRows.isEmpty,
                                candidates,
                              ),
                            ),
                          ],
                        ),
                )
              else
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    sourceVideoCollectionInset,
                    0,
                    sourceVideoCollectionInset,
                    4,
                  ),
                  child: LayoutBuilder(
                    builder: (context, bounds) {
                      final sort = SourceChoiceMenu<String>(
                        key: const ValueKey('api-video-history.sort'),
                        tooltip: t.videoLibrary.sort,
                        label: _sortOptions()[_sort] ?? t.videoLibrary.sort,
                        value: _sort,
                        maximumWidth: 140,
                        options: _sortOptions(),
                        onChanged: _working ? null : _changeSort,
                      );
                      final count = Expanded(
                        child: Text(
                          _selecting
                              ? t.videoLibrary.selectedCount(
                                  count: visibleSelected.length,
                                )
                              : t.videoLibrary.results(count: rows.length),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      );
                      final controls = <Widget>[
                        _filterButton(allRows.isEmpty, candidates),
                        if (_selecting)
                          SourceChromeIconButton(
                            key: const ValueKey('api-history.manage'),
                            tooltip: t.common.cancel,
                            onPressed: _working
                                ? null
                                : () => setState(() {
                                    _selecting = false;
                                    _selectedPaths.clear();
                                  }),
                            icon: Icons.close_rounded,
                            symbol: 'xmark',
                          )
                        else
                          SourceChoiceMenu<String>(
                            key: const ValueKey('api-history.manage'),
                            label: t.common.more,
                            tooltip: t.common.more,
                            value: '',
                            maximumWidth: 90,
                            options: {
                              'manage': t.videoSource.manage,
                              if (rows.isNotEmpty)
                                'clear': t.videoLibrary.clearHistory,
                            },
                            onChanged: _working || allRows.isEmpty
                                ? null
                                : (action) {
                                    _searchFocus.unfocus();
                                    if (action == 'clear') {
                                      _remove(visiblePaths, clear: true);
                                    } else if (action == 'manage') {
                                      setState(() {
                                        _selecting = true;
                                        _selectedPaths.clear();
                                      });
                                    }
                                  },
                          ),
                      ];
                      final narrow =
                          bounds.maxWidth < 420 ||
                          MediaQuery.textScalerOf(context).scale(14) > 20;
                      return Column(
                        children: [
                          Row(
                            children: [count, if (!narrow) sort, ...controls],
                          ),
                          if (narrow && !_selecting)
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: sort,
                            ),
                        ],
                      );
                    },
                  ),
                ),
              if (_selecting && !widget.compactHeader)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: rows.isEmpty || _working
                              ? null
                              : () => setState(() {
                                  if (_selectedPaths.containsAll(
                                    visiblePaths,
                                  )) {
                                    _selectedPaths.removeAll(visiblePaths);
                                  } else {
                                    _selectedPaths.addAll(visiblePaths);
                                  }
                                }),
                          child: Text(
                            visiblePaths.isNotEmpty &&
                                    _selectedPaths.containsAll(visiblePaths)
                                ? t.bookshelf.deselectAll
                                : t.videoLibrary.selectAll,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton.icon(
                        key: const ValueKey('api-history.delete-selected'),
                        onPressed: visibleSelected.isEmpty || _working
                            ? null
                            : () => _remove(visibleSelected),
                        icon: const Icon(Icons.delete_outline),
                        label: Text(t.common.delete),
                      ),
                    ],
                  ),
                ),
              if (_facets.isActive)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      key: const ValueKey('api-history.clear-filter'),
                      onPressed: _clearFacets,
                      child: Text(t.bookshelf.facets.clear),
                    ),
                  ),
                ),
              if (_failed && _records != null) _refreshErrorRow(),
              Expanded(
                child: PullRefreshFeedback.indicator(
                  onRefresh: _refresh,
                  active: widget.active && !_working,
                  scope: _refreshScope,
                  indicatorKey: _refreshIndicator,
                  notificationPredicate: (notice) =>
                      widget.active && !_working && notice.depth == 0,
                  child: _records == null
                      ? ApiVideoEmpty(
                          scrollable: true,
                          title: _failed
                              ? (_failedPullScope == _refreshScope
                                    ? t.common.refreshFailed
                                    : t.common.loadingFailed)
                              : t.common.loading,
                          action: _failed
                              ? TextButton(
                                  onPressed: _read,
                                  child: Text(t.common.retry),
                                )
                              : null,
                        )
                      : allRows.isEmpty
                      ? ApiVideoEmpty(
                          scrollable: true,
                          title: t.videoLibrary.historyEmpty,
                          icon: Icons.history,
                        )
                      : rows.isEmpty
                      ? ApiVideoEmpty(
                          scrollable: true,
                          title: t.videoLibrary.noResults,
                          action: TextButton(
                            onPressed: () {
                              _searchFocus.unfocus();
                              if (_facets.isActive) {
                                _clearFacets();
                              } else {
                                _setQuery('');
                              }
                            },
                            child: Text(t.common.clear),
                          ),
                        )
                      : ApiVideoCollection(
                          contentBottomPadding:
                              widget.compactHeader && _selecting
                              ? BookshelfFloatingSelectionActions
                                    .contentBottomPadding
                              : 0,
                          imageRefreshToken: _imageRefreshToken,
                          retryMissingCoverDetailsOnRefresh: false,
                          posterAspectRatio: widget.posterAspectRatio,
                          loadDetail: widget.loadDetail,
                          recordNoteBuilder: (initial) => initial.remarks,
                          onDetailLoaded: widget.onDetailLoaded,
                          detailsActive: widget.active && !_selecting,
                          selecting: _selecting,
                          selected: {
                            for (final item in items)
                              if (_selectedPaths.contains(
                                _historyWorkKey(item.detailUrl),
                              ))
                                item.id,
                          },
                          items: items,
                          mode: widget.mode,
                          key: ValueKey(
                            '$_conditionsKey.$_query.$_facets.$_sort',
                          ),
                          storageKey: '$_conditionsKey.$_query.$_facets.$_sort',
                          onOpen: (item) {
                            _searchFocus.unfocus();
                            if (_working) return;
                            if (_selecting) {
                              setState(() {
                                if (!_selectedPaths.add(
                                  _historyWorkKey(item.detailUrl),
                                )) {
                                  _selectedPaths.remove(
                                    _historyWorkKey(item.detailUrl),
                                  );
                                }
                              });
                              return;
                            }
                            final index = items.indexWhere(
                              (value) => value.id == item.id,
                            );
                            if (index >= 0) {
                              unawaited(
                                widget.onOpen(item, rows[index].watchUrl),
                              );
                            }
                          },
                          onLongPress: (item) {
                            if (_working) return;
                            _searchFocus.unfocus();
                            setState(() {
                              _selecting = true;
                              _selectedPaths.add(
                                _historyWorkKey(item.detailUrl),
                              );
                            });
                          },
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
