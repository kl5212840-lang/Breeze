import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/widget/keyword_scope_menu.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';
import 'package:zephyr/page/donwload_task/view/download_filter_sheet.dart';
import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/source_downloaded_video_groups.dart';
import 'package:zephyr/page/donwload_task/service/download_center_resources.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/donwload_task/view/download_task_cover.dart';
import 'package:zephyr/page/video/video_local_playback.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_page_route.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/widgets/work_list_divider.dart';
import 'package:zephyr/page/search/widget/search_input_dialog.dart';
import 'package:zephyr/page/search/widget/search_keyboard.dart';
import 'package:zephyr/page/video/source_video_list_header.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_selection_toolbar.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_floating_selection_actions.dart';
import 'package:zephyr/page/donwload_task/service/download_center_projection.dart';
import 'package:zephyr/page/video/video_download.dart';
import 'package:zephyr/widgets/toast.dart';

List<Map<String, dynamic>> sourcePlayableVideoRows(
  Iterable<Map<String, dynamic>> rows,
  String source,
) {
  final selected = rows
      .where(
        (row) =>
            row['source'] == source &&
            row['available'] == true &&
            row['filePresent'] == true &&
            row['resourceId'] is String &&
            (row['resourceId'] as String).isNotEmpty,
      )
      .toList();
  selected.sort(
    (a, b) => ((b['at'] as num?) ?? 0).compareTo((a['at'] as num?) ?? 0),
  );
  return selected;
}

Future<void> openSourceDownloadedVideos(
  BuildContext context,
  String source, {
  bool groupDownloads = true,
}) => Navigator.of(context).push<void>(
  videoPageRoute<void>(
    settings: const RouteSettings(name: 'breeze.video.source-downloads'),
    builder: (_) => SourceDownloadedVideosPage(
      source: source,
      groupDownloads: groupDownloads,
    ),
  ),
);

/// Browses source-owned playable content; canonical works retain their task siblings.
class SourceDownloadedVideosPage extends StatefulWidget {
  const SourceDownloadedVideosPage({
    super.key,
    required this.source,
    this.groupDownloads = true,
  });
  final bool groupDownloads;
  final String source;
  @override
  State<SourceDownloadedVideosPage> createState() =>
      _SourceDownloadedVideosPageState();
}

class _SourceDownloadedVideosPageState
    extends State<SourceDownloadedVideosPage> {
  late Future<List<Map<String, dynamic>>> _rows;
  String _query = '', _sort = 'recent';
  KeywordSearchScope _keywordScope = KeywordSearchScope.all;
  bool get _titleOnly => _keywordScope == KeywordSearchScope.title;
  ShelfFacetSelection _facets = const ShelfFacetSelection();
  bool _openingFilters = false;
  bool _searching = false, _managing = false, _busy = false;
  List<Map<String, dynamic>> _snapshot = [];
  final _selected = <String>{};
  int _readEpoch = 0;
  final _searchFocus = FocusNode();
  @override
  void initState() {
    super.initState();
    _rows = _read();
    VideoLocalResources.changes.addListener(_changed);
  }

  Future<List<Map<String, dynamic>>> _read() async {
    final epoch = ++_readEpoch;
    final rows = widget.groupDownloads
        ? (await DownloadCenterResources.readVideos())
              .where((row) => row['source'] == widget.source)
              .toList()
        : sourcePlayableVideoRows(
            await VideoLocalResources.read(),
            widget.source,
          );
    if (mounted && widget.groupDownloads && epoch == _readEpoch)
      setState(() {
        _snapshot = rows;
      });
    return rows;
  }

  List<DownloadCenterDisplayItem> _entries(List<Map<String, dynamic>> rows) {
    final entries = sourceVideoDownloadGroups(rows, widget.source)
        .where(
          (entry) =>
              !_facets.isActive ||
              (entry.work?.episodes ?? [entry.item]).any(
                (item) => downloadFacetMatches(_facetEntry(item), _facets),
              ),
        )
        .where((entry) {
          final work = entry.work;
          return work != null
              ? keywordTitleMatcher(_query)([work.title]) ||
                    work.episodes.any(
                      (item) =>
                          item.matches(query: _query, titleOnly: _titleOnly),
                    )
              : entry.item.matches(query: _query, titleOnly: _titleOnly);
        })
        .toList();
    if (_sort == 'title')
      entries.sort(
        (a, b) => (a.work?.title ?? a.item.title).compareTo(
          b.work?.title ?? b.item.title,
        ),
      );
    return entries;
  }

  Widget _keywordMenu() => KeywordScopeMenu(
    scope: _keywordScope,
    compact: true,
    onChanged: (scope) => setState(() => _keywordScope = scope),
  );

  ShelfFacetEntry _facetEntry(DownloadCenterItem item) => ShelfFacetEntry(
    key: item.key,
    source: item.source,
    searchText: item.title,
    fields: item.facetFields,
  );
  Future<void> _editFilters() async {
    if (_openingFilters || _busy) return;
    _openingFilters = true;
    _searchFocus.unfocus();
    final source = widget.source;
    try {
      final rows = await _rows;
      if (!mounted || source != widget.source) return;
      final selection = await showDownloadFilterSheet(
        context,
        entries: sourceVideoDownloadItems(
          rows,
          source,
        ).map(_facetEntry).toList(),
        initial: _facets,
        preferenceKey: 'source-downloads.$source',
      );
      if (!mounted || source != widget.source || selection == null) return;
      setState(() {
        _facets = selection;
        _selected.clear();
        _managing = false;
      });
    } catch (_) {
      if (mounted) showErrorToast(t.common.loadingFailed);
    } finally {
      _openingFilters = false;
    }
  }

  List<DownloadCenterItem> get _visibleItems => _entries(
    _snapshot,
  ).expand((entry) => entry.work?.episodes ?? [entry.item]).toList();
  void _toggleItems(List<DownloadCenterItem> items) => setState(() {
    final keys = items.map((item) => item.key).toSet();
    _selected.containsAll(keys)
        ? _selected.removeAll(keys)
        : _selected.addAll(keys);
  });
  void _manageItems(List<DownloadCenterItem> items) => setState(() {
    _managing = true;
    _searching = false;
    _searchFocus.unfocus();
    _selected.addAll(items.map((item) => item.key));
  });
  Future<void> _deleteSelected() => _deleteItems(
    _visibleItems.where((item) => _selected.contains(item.key)).toList(),
  );
  Future<void> _deleteItems(List<DownloadCenterItem> items) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await deleteSourceDownloadedItems(context, items);
      if (mounted)
        setState(() {
          _selected.clear();
          _managing = false;
          _rows = _read();
        });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportSelected(DownloadCenterItem item) async {
    if (_busy) return;
    final resourceVersion = item.video!['resourceVersion'];
    if (resourceVersion is! String) return;
    setState(() => _busy = true);
    try {
      final result = await VideoSystemDownload.exportLocal(
        item.video!['resourceId'] as String,
        item.title,
        expectedResourceVersion: resourceVersion,
      );
      if (!mounted) return;
      if (result == VideoDownloadStatus.saved) {
        showSuccessToast(t.download.exportCopySaved);
      } else if (result != VideoDownloadStatus.cancelled) {
        showErrorToast(
          result == VideoDownloadStatus.busy
              ? t.download.exportBusy
              : t.download.exportFailed,
        );
      }
    } catch (_) {
      if (mounted) showErrorToast(t.download.exportFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _selectionBody(Widget child) {
    if (!widget.groupDownloads) return child;
    final selected = _visibleItems
        .where((item) => _selected.contains(item.key))
        .toList();
    final video = selected.length == 1 ? selected.single.video : null;
    return BookshelfFloatingSelectionActions(
      selecting: _managing,
      busy: _busy,
      keyPrefix: 'source-downloads.selection',
      selectedCount: selected.length,
      actions: [
        BookshelfBatchAction(
          id: 'delete',
          label: t.common.delete,
          icon: Icons.delete_outline_rounded,
          symbol: 'trash',
          onPressed: _busy || selected.isEmpty ? null : _deleteSelected,
        ),
        if (video != null &&
            video['local'] == true &&
            video['status'] == 'saved' &&
            video['resourceId'] is String &&
            video['resourceVersion'] is String &&
            video['fileRemoved'] != true &&
            video['fileInvalid'] != true &&
            video['format'] != 'hls')
          BookshelfBatchAction(
            id: 'export',
            label: t.download.exportVideo,
            icon: Icons.ios_share_rounded,
            symbol: 'square.and.arrow.up',
            onPressed: _busy ? null : () => _exportSelected(selected.single),
          ),
      ],
      child: child,
    );
  }

  void _changed() {
    if (mounted) setState(() => _rows = _read());
  }

  @override
  void dispose() {
    VideoLocalResources.changes.removeListener(_changed);
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !widget.groupDownloads || (!_managing && !_busy),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !_busy)
        setState(() {
          _managing = false;
          _selected.clear();
        });
    },
    child: Scaffold(
      appBar: AppBar(
        toolbarHeight:
            widget.groupDownloads &&
                _managing &&
                MediaQuery.textScalerOf(context).scale(16) > 22
            ? 80
            : 56,
        automaticallyImplyLeading: !widget.groupDownloads,
        leading: widget.groupDownloads ? null : const SourceBackButton(),
        titleSpacing: widget.groupDownloads ? 0 : null,
        title: !widget.groupDownloads
            ? Text(t.bookshelf.download)
            : _managing
            ? BookshelfSelectionToolbar(
                keyPrefix: 'source-downloads.selection',
                selectedCount: _visibleItems
                    .where((item) => _selected.contains(item.key))
                    .length,
                allSelected:
                    _visibleItems.isNotEmpty &&
                    _selected.containsAll(
                      _visibleItems.map((item) => item.key),
                    ),
                onCancel: _busy
                    ? null
                    : () => setState(() {
                        _managing = false;
                        _selected.clear();
                      }),
                onToggleAll: _busy || _visibleItems.isEmpty
                    ? null
                    : () => _toggleItems(_visibleItems),
              )
            : SourceVideoListHeader(
                keyPrefix: 'source-downloads',
                leading: const SourceBackButton(),
                title: _query.isEmpty ? t.bookshelf.download : _query,
                searching: _searching,
                searchScope: _keywordMenu(),
                searchField: SearchQueryField(
                  key: const ValueKey('source-downloads.search'),
                  query: _query,
                  inline: true,
                  focusNode: _searchFocus,
                  closeOnSubmit: false,
                  hintText: t.common.search,
                  onChanged: (value) => setState(() => _query = value),
                ),
                onSearch: _busy
                    ? null
                    : () {
                        setState(() => _searching = !_searching);
                        if (_searching)
                          requestSearchKeyboard(
                            _searchFocus,
                            isCurrent: () => mounted && _searching,
                          );
                        else
                          _searchFocus.unfocus();
                      },
                options: {
                  'recent': t.videoPersonal.recent,
                  'title': t.videoLibrary.titleOrder,
                  if (_visibleItems.isNotEmpty) 'manage': t.videoSource.manage,
                },
                onMore: (value) {
                  if (_busy) return;
                  if (value == 'manage')
                    _manageItems([]);
                  else
                    setState(() => _sort = value);
                },
              ),
        actions: widget.groupDownloads
            ? null
            : const [CollectionCoverPrivacyButton()],
      ),
      body: _selectionBody(
        Column(
          children: [
            if (widget.groupDownloads)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _rows,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return Text(
                          snapshot.hasError
                              ? t.common.unknown
                              : t.common.loading,
                        );
                      final entries = _entries(snapshot.data!);
                      return Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.videoLibrary.results(count: entries.length),
                              key: const ValueKey('source-downloads.count'),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          SourceChromeIconButton(
                            key: const ValueKey('source-downloads.filters'),
                            tooltip: t.videoFilters.title,
                            symbol: _facets.isActive
                                ? 'line.3.horizontal.decrease.circle.fill'
                                : 'line.3.horizontal.decrease.circle',
                            onPressed: _openingFilters || _busy
                                ? null
                                : _editFilters,
                            icon: Icons.filter_list_rounded,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            if (!widget.groupDownloads)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: SearchQueryField(
                        query: _query,
                        inline: true,
                        focusNode: _searchFocus,
                        closeOnSubmit: false,
                        hintText: t.common.search,
                        onChanged: (value) => setState(() => _query = value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _keywordMenu(),
                  ],
                ),
              ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _rows,
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return Center(
                      child: TextButton(
                        onPressed: _changed,
                        child: Text(t.common.retry),
                      ),
                    );
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  if (widget.groupDownloads) {
                    final entries = _entries(snapshot.data!);
                    if (entries.isEmpty)
                      return Center(child: Text(t.common.empty));
                    return CollectionCoverPrivacyScope(
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          4,
                          16,
                          _managing
                              ? BookshelfFloatingSelectionActions
                                    .contentBottomPadding
                              : 24,
                        ),
                        itemCount: entries.length,
                        separatorBuilder: (_, _) =>
                            const WorkListDivider(height: 8),
                        itemBuilder: (context, index) {
                          final entry = entries[index],
                              work = entries[index].work;
                          if (work == null)
                            return SourceDownloadedEpisodeRow(
                              item: entry.item,
                              selecting: _managing,
                              selected: _selected.contains(entry.item.key),
                              onSelect: () => _toggleItems([entry.item]),
                              onManage: () => _manageItems([entry.item]),
                            );
                          return SourceDownloadedWorkCard(
                            key: ValueKey('source-download-work.${work.key}'),
                            work: work,
                            selecting: _managing,
                            selected: _selected.containsAll(
                              work.episodes.map((item) => item.key),
                            ),
                            enabled: !_busy,
                            onOpen: () => _managing
                                ? _toggleItems(work.episodes)
                                : unawaited(
                                    openSourceDownloadedWork(context, work),
                                  ),
                            onManage: () => _manageItems(work.episodes),
                            onRemove: () =>
                                unawaited(_deleteItems(work.episodes)),
                          );
                        },
                      ),
                    );
                  }
                  final matches = keywordTitleMatcher(_query);
                  final rows = snapshot.data!.where((row) {
                    final title = '${row['title'] ?? ''}';
                    final public = row['publicSearchText'];
                    return matches([
                      title,
                      if (!_titleOnly && public is String) public,
                    ]);
                  }).toList();
                  if (rows.isEmpty) return Center(child: Text(t.common.empty));
                  return CollectionCoverPrivacyScope(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: rows.length,
                      separatorBuilder: (_, _) =>
                          const WorkListDivider(height: 12),
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        return InkWell(
                          key: ValueKey('source-download.${row['resourceId']}'),
                          onTap: () => unawaited(
                            openLocalVideo(
                              context,
                              row['resourceId'] as String,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              DownloadVideoTaskCover(
                                row: row,
                                localOnly: true,
                                fallback: const Icon(Icons.play_arrow_rounded),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${row['title'] ?? ''}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    if ('${row['quality'] ?? ''}'
                                        .isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        '${row['quality']}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
