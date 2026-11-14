import 'dart:async';
import 'package:zephyr/page/bookshelf/cubit/search_status.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/bookshelf/widgets/video_bookshelf_pane.dart';
import 'package:zephyr/page/bookshelf/service/video_bookshelf_index.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/models/source_video_module.dart';
import 'package:zephyr/page/video/api_video_library_page.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/source_profile_video_preview.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_local_playback.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/page/donwload_task/view/download_task_cover.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/page/video/video_page_route.dart';
import 'package:zephyr/widgets/source_choice_menu.dart';

/// Local record tasks share the declared module identity with the browse tab.
class SourceProfileVideoRecords extends StatefulWidget {
  const SourceProfileVideoRecords({super.key, required this.modules});
  final List<SourceVideoModule> modules;
  @override
  State<SourceProfileVideoRecords> createState() =>
      _SourceProfileVideoRecordsState();
}

class _SourceProfileVideoRecordsState extends State<SourceProfileVideoRecords> {
  String? _selected;
  int _epoch = 0;
  final _rows = <ShelfPageMode, List<VideoBookshelfRow>>{};
  final _loading = <ShelfPageMode>{};
  final _failed = <ShelfPageMode>{};
  Map<String, Map<String, dynamic>> _resources = {};
  SourceVideoModule? get _module =>
      widget.modules.where((value) => value.id == _selected).firstOrNull ??
      widget.modules.firstOrNull;
  @override
  void initState() {
    super.initState();
    VideoLibraryStore.shared.addListener(_read);
    VideoWatchHistory.changes.addListener(_read);
    VideoLocalResources.changes.addListener(_read);
    _read();
  }

  @override
  void didUpdateWidget(SourceProfileVideoRecords oldWidget) {
    super.didUpdateWidget(oldWidget);
    String identity(List<SourceVideoModule> modules) => modules
        .map(
          (module) =>
              '${module.source}|${module.id}|${module.capabilities.itemNamespace}|${module.catalogFn}|${module.detailFn}|${module.playbackFn}',
        )
        .join('\n');
    if (identity(oldWidget.modules) != identity(widget.modules)) {
      _rows.clear();
      _resources = {};
      _read();
    }
  }

  @override
  void dispose() {
    _epoch++;
    VideoLibraryStore.shared.removeListener(_read);
    VideoWatchHistory.changes.removeListener(_read);
    VideoLocalResources.changes.removeListener(_read);
    super.dispose();
  }

  Future<VideoBookshelfRow?> _scoped(
    SourceVideoModule module,
    List<SourceVideoModule> declared,
    VideoBookshelfRow row,
    ShelfPageMode mode,
  ) async {
    if (row.source != module.source ||
        row.item.detailUrl.origin != module.home.origin)
      return null;
    final namespace = module.capabilities.itemNamespace;
    final sameOrigin = declared
        .where(
          (value) =>
              value.source == module.source &&
              value.home.origin == module.home.origin,
        )
        .toList();
    final names = sameOrigin
        .map((value) => value.capabilities.itemNamespace)
        .where((value) => value.isNotEmpty)
        .toSet();
    var item = row.item;
    if (namespace.isNotEmpty && !item.id.startsWith('$namespace:')) {
      if (mode != ShelfPageMode.download && item.id.contains(':')) return null;
      // Opaque downloaded IDs do not encode a module. Read only previously
      // saved public identity; never ask a source API to classify a record.
      ApiVideoItem? cached;
      try {
        cached = await VideoDownloadedDetails.readItem(
          row.source,
          row.watchUrl ?? item.detailUrl,
        );
      } catch (_) {}
      if (cached != null &&
          cached.id.contains(':') &&
          !cached.id.startsWith('$namespace:'))
        return null;
      if (cached != null &&
          cached.id.startsWith('$namespace:') &&
          videoPublicPage(cached.detailUrl) ==
              videoPublicPage(item.detailUrl)) {
        if (mode != ShelfPageMode.download) item = cached;
      } else if (mode == ShelfPageMode.download && sameOrigin.length == 1) {
        // A unique declared origin is sufficient for a legacy file whose
        // resource ID has no namespace. Shared-origin ambiguity stays out.
      } else if (mode == ShelfPageMode.history &&
          sameOrigin.length == 1 &&
          !item.id.contains(':') &&
          RegExp(
            r'^/videos/[A-Za-z0-9_-]{1,64}$',
          ).hasMatch(item.detailUrl.path)) {
        // Same explicit /videos identity mapping used by apiVideoHistoryItem.
        item = ApiVideoItem.fromJson({
          ...item.toLibraryJson(),
          'id': '$namespace:${item.id}',
        }, home: item.detailUrl);
      } else {
        return null;
      }
    } else if (namespace.isEmpty &&
        names.any((value) => item.id.startsWith('$value:'))) {
      return null;
    }
    return VideoBookshelfRow(
      key: row.key,
      source: row.source,
      item: item,
      updatedAt: row.updatedAt,
      watchUrl: row.watchUrl,
      folderIds: row.folderIds,
      recordKey: row.recordKey,
      localResourceId: row.localResourceId,
      progress: row.progress,
      facetFields: row.facetFields,
    );
  }

  Future<List<VideoBookshelfRow>> _load(
    SourceVideoModule module,
    ShelfPageMode mode,
    SearchStatusState search, {
    required List<SourceVideoModule> declared,
  }) async {
    final rows = await VideoBookshelfIndex.load(mode, search);
    final scoped = await Future.wait(
      rows.map((row) => _scoped(module, declared, row, mode)),
    );
    return scoped.whereType<VideoBookshelfRow>().toList();
  }

  void _read() {
    final module = _module;
    if (module == null || !mounted) return;
    final epoch = ++_epoch;
    final declared = List<SourceVideoModule>.of(widget.modules);
    setState(() {
      _loading.addAll(ShelfPageMode.values);
      _failed.clear();
    });
    for (final mode in ShelfPageMode.values) {
      unawaited(() async {
        try {
          final rows = await _load(
            module,
            mode,
            SearchStatusState(sources: [module.source]),
            declared: declared,
          );
          final resources = mode == ShelfPageMode.download
              ? {
                  for (final row in await VideoLocalResources.read())
                    '${row['resourceId']}': row,
                }
              : null;
          if (!mounted || epoch != _epoch) return;
          setState(() {
            _rows[mode] = rows;
            if (resources != null) _resources = resources;
            _loading.remove(mode);
          });
        } catch (_) {
          if (!mounted || epoch != _epoch) return;
          setState(() {
            _failed.add(mode);
            _loading.remove(mode);
          });
        }
      }());
    }
  }

  Future<void> _open(
    SourceVideoModule module,
    String section, {
    VideoBookshelfRow? row,
    BuildContext? origin,
  }) => Navigator.of(origin ?? context).push<void>(
    videoPageRoute(
      settings: RouteSettings(name: 'breeze.video.local-$section'),
      networkSource: module.source,
      builder: (_) => ApiVideoLibraryPage(
        repository: module.repository(),
        title:
            '${module.title} · ${section == 'favorite' ? t.videoSource.localFavorites : t.sourceShell.videoHistory}',
        initialSection: section,
        bookshelfItem: row?.item,
        bookshelfResume: row?.resumeAt(module.home),
      ),
    ),
  );

  Future<void> _records(SourceVideoModule module, ShelfPageMode mode) {
    final declared = List<SourceVideoModule>.of(widget.modules);
    return Navigator.of(context).push<void>(
      videoPageRoute(
        settings: RouteSettings(name: 'breeze.video.local-${mode.name}'),
        builder: (_) {
          final live = VideoBookshelfPaneDataSource.live;
          return Scaffold(
            appBar: AppBar(
              leading: const SourceBackButton(),
              title: Text(module.title),
            ),
            body: VideoBookshelfPane(
              mode: mode,
              search: SearchStatusState(sources: [module.source]),
              dataSource: VideoBookshelfPaneDataSource(
                load: (mode, search) =>
                    _load(module, mode, search, declared: declared),
                sourceNames: () async => {module.source: module.title},
                open: (context, row) => row.localResourceId != null
                    ? openLocalVideo(context, row.localResourceId!)
                    : _open(module, mode.name, row: row, origin: context),
                remove: live.remove,
                // Profile records project local snapshots. Fresh source reads
                // belong to an explicit video open, not preview/hover enrichment.
                enrich: (row) async => row.item,
                store: live.store,
                changes: live.changes,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _preview(SourceVideoModule module, ShelfPageMode mode) {
    final section = mode.name;
    final rows = _rows[mode] ?? const <VideoBookshelfRow>[];
    void viewAll() => unawaited(_records(module, mode));
    return KeyedSubtree(
      key: ValueKey('profile-video-$section'),
      child: SourceProfileVideoPreview(
        key: ValueKey('${module.source}|${module.id}|$section'),
        identity: 'profile.${module.source}.${module.id}.$section',
        responsivePreview: true,
        title: switch (mode) {
          ShelfPageMode.favorite => t.videoSource.localFavorites,
          ShelfPageMode.history => t.sourceShell.videoHistory,
          ShelfPageMode.download => t.bookshelf.download,
        },
        icon: switch (mode) {
          ShelfPageMode.favorite => Icons.bookmark_outline,
          ShelfPageMode.history => Icons.history,
          ShelfPageMode.download => Icons.download_outlined,
        },
        countLabel: _loading.contains(mode) || _failed.contains(mode)
            ? null
            : '${rows.length}',
        loading: _loading.contains(mode),
        failed: _failed.contains(mode),
        onRetry: _read,
        onViewAll: viewAll,
        items: rows
            .take(4)
            .map(
              (row) => SourceProfileVideoPreviewItem(
                id: row.key,
                title: row.item.title,
                note: mode == ShelfPageMode.history
                    ? row.progress
                    : row.item.remarks,
                cover: row.localResourceId == null
                    ? ApiVideoPoster(item: row.item, source: row.source)
                    : DownloadVideoTaskCover(
                        row:
                            _resources[row.localResourceId] ??
                            {
                              'resourceId': row.localResourceId,
                              'source': row.source,
                              'url': '${row.watchUrl}',
                              'title': row.item.title,
                              'cover': row.item.coverUrl?.toString(),
                              'local': true,
                            },
                        localOnly: true,
                        fallback: const Icon(Icons.play_arrow_rounded),
                      ),
                onOpen: () => unawaited(
                  row.localResourceId != null
                      ? openLocalVideo(context, row.localResourceId!)
                      : mode == ShelfPageMode.download
                      ? _records(module, mode)
                      : _open(module, section, row: row),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.modules.isEmpty) return const SizedBox.shrink();
    final module =
        widget.modules.where((value) => value.id == _selected).firstOrNull ??
        widget.modules.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.modules.length > 1)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t.sourceShell.videoModule,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SourceChoiceMenu<String>(
                      key: const ValueKey('profile-video-module'),
                      label: module.title,
                      tooltip: t.sourceShell.videoModule,
                      value: module.id,
                      options: {
                        for (final value in widget.modules)
                          value.id: value.title,
                      },
                      selectionIndicator: true,
                      onChanged: (value) {
                        if (_selected == value) return;
                        setState(() {
                          _selected = value;
                          _rows.clear();
                          _failed.clear();
                        });
                        _read();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          child: Column(
            children: [
              const Align(
                alignment: AlignmentDirectional.centerEnd,
                child: CollectionCoverPrivacyButton(),
              ),
              for (final mode in ShelfPageMode.values) _preview(module, mode),
            ],
          ),
        ),
      ],
    );
  }
}
