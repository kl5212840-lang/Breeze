import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/view/source_profile_records_view.dart';
import 'package:zephyr/page/bookshelf/service/video_bookshelf_index.dart';
import 'package:zephyr/page/donwload_task/view/download_task_cover.dart';
import 'package:zephyr/page/video/source_downloaded_videos_page.dart';
import 'package:zephyr/page/video/source_downloaded_video_groups.dart';
import 'package:zephyr/page/donwload_task/service/download_center_resources.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_cover_overlay.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_local_playback.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/widgets/collection_cover_fit.dart';

class SourceProfileVideoPreviewItem {
  const SourceProfileVideoPreviewItem({
    required this.id,
    required this.title,
    required this.cover,
    required this.onOpen,
    this.note = '',
  });
  final String id, title, note;
  final Widget cover;
  final VoidCallback onOpen;
}

/// Same heading/disclosure as comic previews; artwork alone opts into privacy.
class SourceProfileVideoPreview extends StatefulWidget {
  const SourceProfileVideoPreview({
    super.key,
    required this.identity,
    required this.title,
    required this.icon,
    required this.items,
    required this.onViewAll,
    this.loading = false,
    this.failed = false,
    this.onRetry,
    this.countLabel,
    this.responsivePreview = false,
    this.posterAspectRatio = 2 / 3,
  });
  final double posterAspectRatio;
  final bool responsivePreview;
  final String identity, title;
  final IconData icon;
  final List<SourceProfileVideoPreviewItem> items;
  final VoidCallback onViewAll;
  final bool loading, failed;
  final VoidCallback? onRetry;
  final String? countLabel;
  @override
  State<SourceProfileVideoPreview> createState() =>
      _SourceProfileVideoPreviewState();
}

class _SourceProfileVideoPreviewState extends State<SourceProfileVideoPreview> {
  bool _expanded = true;
  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    final scale = MediaQuery.textScalerOf(context);
    // A fixed two-line title and two-line record slot keep each rail steady;
    // another section's longest note never sets this section's height.
    final lineHeight = scale.scale(style?.fontSize ?? 12) * 1.4;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SourceProfilePreviewHeader(
            previewKey: ValueKey(widget.identity),
            title: widget.title,
            icon: widget.icon,
            hasEntries: widget.items.isNotEmpty,
            expanded: _expanded,
            onToggle: () => setState(() => _expanded = !_expanded),
            onViewAll: widget.onViewAll,
            countLabel: widget.countLabel,
          ),
          if (widget.loading) const LinearProgressIndicator(),
          if (widget.failed)
            Row(
              children: [
                Expanded(child: Text(t.videoSource.readFailed, style: style)),
                TextButton(
                  onPressed: widget.onRetry,
                  child: Text(t.common.retry),
                ),
              ],
            ),
          if (_expanded &&
              !widget.loading &&
              !widget.failed &&
              widget.items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(t.common.empty, style: style),
            ),
          if (_expanded && widget.items.isNotEmpty)
            CollectionCoverPrivacyScope(
              child: CollectionCoverFitScope(
                child: LayoutBuilder(
                  builder: (context, bounds) {
                    final columns = (bounds.maxWidth / 112).floor().clamp(3, 4);
                    final width = widget.responsivePreview
                        ? (bounds.maxWidth - 12 * (columns - 1)) / columns
                        : 80.0;
                    final posterHeight = width / widget.posterAspectRatio;
                    final count =
                        widget.responsivePreview && widget.items.length > 4
                        ? 4
                        : widget.items.length;
                    Widget textSlot(String text, String id, bool note) {
                      final child = Text(
                        text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: style?.copyWith(
                          height: 1.4,
                          color: note
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : null,
                        ),
                      );
                      return widget.responsivePreview
                          ? SizedBox(
                              key: ValueKey(
                                'video-preview.${note ? 'note' : 'title'}.${widget.identity}.$id',
                              ),
                              height: lineHeight * 2,
                              child: child,
                            )
                          : child;
                    }

                    return SizedBox(
                      height: posterHeight + 6 + lineHeight * 4 + 4,
                      child: ListView.separated(
                        key: PageStorageKey('video-preview.${widget.identity}'),
                        scrollDirection: Axis.horizontal,
                        primary: false,
                        itemCount: count,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final item = widget.items[index];
                          return SizedBox(
                            width: width,
                            child: InkWell(
                              key: ValueKey(
                                'video-preview.${widget.identity}.${item.id}',
                              ),
                              onTap: item.onOpen,
                              borderRadius: BorderRadius.circular(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    key: ValueKey(
                                      'video-preview.cover.${widget.identity}.${item.id}',
                                    ),
                                    width: width,
                                    height: posterHeight,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: item.cover,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  textSlot(item.title, item.id, false),
                                  if (widget.responsivePreview ||
                                      item.note.isNotEmpty)
                                    textSlot(item.note, item.id, true),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A bounded, live preview of the same local collection as View All.
class SourceProfileLocalVideoFavorites extends StatefulWidget {
  const SourceProfileLocalVideoFavorites({
    super.key,
    required this.source,
    required this.home,
    required this.onViewAll,
    required this.onOpen,
    this.active = true,
    this.posterAspectRatio = 2 / 3,
  });

  final String source;
  final Uri home;
  final VoidCallback onViewAll;
  final ValueChanged<ApiVideoItem> onOpen;
  final bool active;
  final double posterAspectRatio;

  @override
  State<SourceProfileLocalVideoFavorites> createState() =>
      _SourceProfileLocalVideoFavoritesState();
}

class _SourceProfileLocalVideoFavoritesState
    extends State<SourceProfileLocalVideoFavorites> {
  final _store = VideoLibraryStore.shared;
  var _epoch = 0;
  var _items = <({String key, ApiVideoItem item, int clock})>[];
  int? _count;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _store.addListener(_read);
    _read();
  }

  @override
  void didUpdateWidget(covariant SourceProfileLocalVideoFavorites oldWidget) {
    super.didUpdateWidget(oldWidget);
    final scopeChanged =
        oldWidget.source != widget.source ||
        oldWidget.home.origin != widget.home.origin;
    if (scopeChanged) {
      _items = [];
      _count = null;
      _failed = false;
    }
    if (scopeChanged || oldWidget.active != widget.active) _read();
  }

  Future<void> _read() async {
    final epoch = ++_epoch;
    if (!widget.active) return;
    if (_failed) setState(() => _failed = false);
    try {
      final snapshot = await _store.read();
      if (!mounted || epoch != _epoch) return;
      final rows = snapshot.itemsFor(widget.source, home: widget.home)
        ..sort((a, b) => b.clock.compareTo(a.clock));
      setState(() {
        _items = rows.take(4).toList();
        _count = rows.length;
      });
    } catch (_) {
      if (mounted && epoch == _epoch) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _store.removeListener(_read);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SourceProfileVideoPreview(
    key: ValueKey((widget.source, widget.home.origin)),
    identity: 'local-favorites.${widget.source}',
    title: t.videoSource.localFavorites,
    icon: Icons.bookmark_outline_rounded,
    responsivePreview: true,
    posterAspectRatio: widget.posterAspectRatio,
    countLabel: _count?.toString(),
    loading: _count == null && !_failed,
    failed: _failed,
    onRetry: _read,
    onViewAll: widget.onViewAll,
    items: [
      for (final row in _items)
        SourceProfileVideoPreviewItem(
          id: row.key,
          title: row.item.title,
          note: row.item.remarks,
          cover: ApiVideoPoster(item: row.item, source: widget.source),
          onOpen: () => widget.onOpen(row.item),
        ),
    ],
  );
}

/// Device records are source-scoped and independent of the site's signed-in user.
class SourceProfileLocalVideoPreviews extends StatefulWidget {
  const SourceProfileLocalVideoPreviews({
    super.key,
    required this.source,
    required this.onHistory,
    this.active = true,
    this.afterHistory,
    this.groupDownloads = false,
    this.responsivePreview = false,
    this.showPrivacyAction = true,
    this.readDownloads,
  });
  final Future<List<Map<String, dynamic>>> Function()? readDownloads;
  final bool showPrivacyAction;
  final bool groupDownloads, responsivePreview;
  final String source;
  final VoidCallback onHistory;
  final bool active;
  final Widget? afterHistory;
  @override
  State<SourceProfileLocalVideoPreviews> createState() =>
      _SourceProfileLocalVideoPreviewsState();
}

class _SourceProfileLocalVideoPreviewsState
    extends State<SourceProfileLocalVideoPreviews> {
  List<VideoWatchRecord> _history = [];
  List<Map<String, dynamic>> _downloads = [];
  bool _historyLoading = true, _downloadsLoading = true;
  bool _historyFailed = false, _downloadsFailed = false;
  int _epoch = 0;
  @override
  void initState() {
    super.initState();
    VideoWatchHistory.changes.addListener(_read);
    VideoLocalResources.changes.addListener(_read);
    _read();
  }

  @override
  void didUpdateWidget(covariant SourceProfileLocalVideoPreviews oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.active != widget.active ||
        oldWidget.groupDownloads != widget.groupDownloads ||
        oldWidget.readDownloads != widget.readDownloads) {
      _epoch++;
      if (oldWidget.source != widget.source) {
        _history = [];
        _downloads = [];
        _historyLoading = true;
        _downloadsLoading = true;
        _historyFailed = false;
        _downloadsFailed = false;
      }
      _read();
    }
  }

  void _read() {
    if (!widget.active) return;
    final epoch = ++_epoch, source = widget.source;
    unawaited(() async {
      try {
        final rows = await VideoWatchHistory.read(source);
        if (!mounted || epoch != _epoch) return;
        setState(() {
          _history = rows;
          _historyLoading = false;
          _historyFailed = false;
        });
      } catch (_) {
        if (mounted && epoch == _epoch) {
          setState(() {
            _historyLoading = false;
            _historyFailed = true;
          });
        }
      }
    }());
    unawaited(() async {
      try {
        final rows = widget.readDownloads != null
            ? await widget.readDownloads!()
            : widget.groupDownloads
            ? await DownloadCenterResources.readVideos()
            : await VideoLocalResources.read();
        if (!mounted || epoch != _epoch) return;
        setState(() {
          _downloads = widget.groupDownloads
              ? rows.where((row) => row['source'] == source).toList()
              : sourcePlayableVideoRows(rows, source);
          _downloadsLoading = false;
          _downloadsFailed = false;
        });
      } catch (_) {
        if (mounted && epoch == _epoch) {
          setState(() {
            _downloadsLoading = false;
            _downloadsFailed = true;
          });
        }
      }
    }());
  }

  @override
  void dispose() {
    _epoch++;
    VideoWatchHistory.changes.removeListener(_read);
    VideoLocalResources.changes.removeListener(_read);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (widget.showPrivacyAction)
        const Align(
          alignment: AlignmentDirectional.centerEnd,
          child: CollectionCoverPrivacyButton(),
        ),
      SourceProfileVideoPreview(
        identity: 'local-history.${widget.source}',
        responsivePreview: widget.responsivePreview,
        title: t.omoAccount.localHistory,
        icon: Icons.history_rounded,
        onViewAll: widget.onHistory,
        loading: _historyLoading,
        failed: _historyFailed,
        onRetry: _read,
        countLabel: _historyLoading || _historyFailed
            ? null
            : '${_history.length}',
        items: _history.take(widget.responsivePreview ? 4 : 8).map((row) {
          final item = ApiVideoItem(
            id: row.watchUrl.toString(),
            title: row.title,
            detailUrl: row.watchUrl.replace(query: '', fragment: ''),
            coverUrl: row.coverUrl,
            sourceDuration: formatKnownVideoDuration(row.duration),
          );
          return SourceProfileVideoPreviewItem(
            id: item.id,
            title: row.title,
            note:
                '${formatKnownVideoDuration(row.position)} · ${row.updatedAt.toLocal().toString().split(' ').first}',
            cover: ApiVideoPoster(item: item, source: widget.source),
            onOpen: () => unawaited(
              VideoBookshelfIndex.open(
                context,
                VideoBookshelfRow(
                  key: item.id,
                  source: widget.source,
                  item: item,
                  updatedAt: row.updatedAt,
                  watchUrl: row.watchUrl,
                ),
              ),
            ),
          );
        }).toList(),
      ),
      ?widget.afterHistory,
      SourceProfileVideoPreview(
        identity: 'local-downloads.${widget.source}',
        responsivePreview: widget.responsivePreview,
        title: t.bookshelf.download,
        icon: Icons.download_outlined,
        onViewAll: () => unawaited(
          openSourceDownloadedVideos(
            context,
            widget.source,
            groupDownloads: widget.groupDownloads,
          ),
        ),
        loading: _downloadsLoading,
        failed: _downloadsFailed,
        onRetry: _read,
        countLabel: _downloadsLoading || _downloadsFailed
            ? null
            : '${widget.groupDownloads ? sourceVideoDownloadGroups(_downloads, widget.source).length : _downloads.length}',
        items: widget.groupDownloads
            ? sourceVideoDownloadGroups(
                _downloads,
                widget.source,
              ).take(widget.responsivePreview ? 4 : 8).map((entry) {
                final work = entry.work,
                    row = entry.work?.poster.video ?? entry.item.video!;
                return SourceProfileVideoPreviewItem(
                  id: entry.key,
                  title: work?.title ?? entry.item.title,
                  note: work == null
                      ? '${row['quality'] ?? ''}'
                      : t.download.workEpisodeCount(
                          count: work.episodes.length,
                        ),
                  cover: DownloadVideoTaskCover(
                    localOnly: true,
                    row: work == null
                        ? row
                        : {...row, 'durationMs': null, 'sourceDuration': ''},
                    fallback: const Icon(Icons.play_arrow_rounded),
                  ),
                  onOpen: () => unawaited(
                    work == null
                        ? openLocalVideo(context, row['resourceId'] as String)
                        : openSourceDownloadedWork(context, work),
                  ),
                );
              }).toList()
            : _downloads
                  .take(widget.responsivePreview ? 4 : 8)
                  .map(
                    (row) => SourceProfileVideoPreviewItem(
                      id: row['resourceId'] as String,
                      title: '${row['title'] ?? ''}',
                      note: '${row['quality'] ?? ''}',
                      cover: DownloadVideoTaskCover(
                        row: row,
                        localOnly: true,
                        fallback: const Icon(Icons.play_arrow_rounded),
                      ),
                      onOpen: () => unawaited(
                        openLocalVideo(context, row['resourceId'] as String),
                      ),
                    ),
                  )
                  .toList(),
      ),
    ],
  );
}
