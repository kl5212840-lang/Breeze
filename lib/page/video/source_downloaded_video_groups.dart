import 'dart:async';
import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/donwload_task/service/download_center_projection.dart';
import 'package:zephyr/page/donwload_task/service/download_center_resources.dart';
import 'package:zephyr/page/donwload_task/service/download_center_removal.dart';
import 'package:zephyr/page/donwload_task/view/download_card_details.dart';
import 'package:zephyr/page/donwload_task/view/download_swipe_actions.dart';
import 'package:zephyr/page/donwload_task/view/download_task_cover.dart';
import 'package:zephyr/page/donwload_task/view/download_video_work_page.dart';
import 'package:zephyr/page/video/video_download.dart';
import 'package:zephyr/page/video/video_download_cancel_action.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/video_download_panel.dart';
import 'package:zephyr/page/video/video_download_retry.dart';
import 'package:zephyr/page/video/video_download_retry_action.dart';
import 'package:zephyr/page/video/video_download_source_navigation.dart';
import 'package:zephyr/page/video/video_local_playback.dart';
import 'package:zephyr/page/video/video_page_route.dart';
import 'package:zephyr/service/download/download_byte_amount.dart';
import 'package:zephyr/widgets/toast.dart';

List<DownloadCenterItem> sourceVideoDownloadItems(
  Iterable<Map<String, dynamic>> rows,
  String source,
) => projectDownloadCenter(
  tasks: [],
  comics: [],
  videos: [
    for (final row in rows)
      if (row['source'] == source)
        {
          ...row,
          'status': row['status'] ?? 'saved',
          'local': row['local'] ?? row['available'] == true,
        },
  ],
);

/// Same canonical source/module/work rule as Downloads, never title/author.
List<DownloadCenterDisplayItem> sourceVideoDownloadGroups(
  Iterable<Map<String, dynamic>> rows,
  String source,
) {
  final all = sourceVideoDownloadItems(rows, source);
  final playable = all
      .where(
        (item) =>
            item.video?['available'] == true &&
            item.video?['filePresent'] == true &&
            item.video?['resourceId'] is String,
      )
      .toList();
  return groupVideoDownloadItems(playable, universe: all);
}

Future<void> openSourceDownloadedWork(
  BuildContext context,
  DownloadVideoWork work,
) {
  DownloadVideoWorkHistory? readyHistory;
  final initialHistory = readDownloadVideoWorkHistory(
    work.identity.source,
  ).then((history) => readyHistory = history);
  return Navigator.of(context).push<void>(
    videoPageRoute<void>(
      settings: const RouteSettings(name: 'breeze.video.source-download-work'),
      builder: (workContext) => DownloadVideoWorkPage(
        initial: work,
        initialHistory: initialHistory,
        readyHistory: readyHistory,
        readItems: () async => sourceVideoDownloadItems(
          await DownloadCenterResources.readVideos(),
          work.identity.source,
        ),
        refreshItems: () async => sourceVideoDownloadItems(
          await DownloadCenterResources.readVideos(fresh: true),
          work.identity.source,
        ),
        matches: (_) => true,
        onContinueWatching: (origin, item) async {
          final row = item.video!;
          try {
            await openLocalVideo(
              origin,
              row['resourceId'] as String,
              resource: row,
            );
          } catch (_) {
            if (origin.mounted) showErrorToast(t.download.fileUnavailable);
          }
        },
        onRemoveEpisodes: (origin, items) =>
            deleteSourceDownloadedItems(origin, items, episodes: true),
        rowBuilder: (_, item, showFileFormat, resumeAt) =>
            SourceDownloadedEpisodeRow(
              item: item,
              episodeContext: true,
              showFileFormat: showFileFormat,
              resumeAt: resumeAt,
            ),
        onRetryFailed: (items) async {
          for (final item in items) {
            if (!workContext.mounted) return;
            final row = item.video!;
            if (VideoDownloadRetry.canRetry(row) &&
                !VideoDownloadRetry.needsSource(row)) {
              await retryVideoDownload(workContext, row);
            }
          }
        },
      ),
    ),
  );
}

Future<void> deleteSourceDownloadedItems(
  BuildContext context,
  Iterable<DownloadCenterItem> items, {
  bool episodes = false,
}) async {
  final snapshot = List<DownloadCenterItem>.unmodifiable(items);
  if (snapshot.isEmpty) return;
  if (snapshot.any((item) => !canManageDownloadedVideoEpisode(item.video!))) {
    showInfoToast(
      snapshot.any((item) => item.video?['resourceReadPending'] == true)
          ? t.download.fileUnavailable
          : t.download.cancelBeforeDelete,
    );
    return;
  }
  try {
    final tokens = <String, VideoDownloadRemovalToken>{};
    for (final item in snapshot) {
      final row = item.video!;
      tokens[item.key] = await bindVideoDownloadRemoval(
        source: item.source,
        page: Uri.parse(row['url'] as String),
        quality: '${row['quality'] ?? ''}',
        format: '${row['format'] ?? 'mp4'}',
        displayedTask: row,
      );
    }
    if (!context.mounted || ModalRoute.isCurrentOf(context) != true) return;
    final names = snapshot
        .take(3)
        .map((item) {
          final episode = item.video?['publicEpisodeLabel'];
          return episodes && episode is String && episode.trim().isNotEmpty
              ? episode.trim()
              : item.title;
        })
        .join(' · ');
    final count = snapshot.length;
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    final shown = count > 3 ? '$names…' : names;
    final description = chinese
        ? '删除这 $count 项下载记录及对应的应用内文件？已导出的副本、收藏和历史会保留。'
        : 'Delete ${count == 1 ? 'this download' : 'these $count downloads'} and any associated in-app files? Exported copies, favorites, and history are kept.';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: Text(t.common.delete),
        content: Text('$shown\n$description'),
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
    if (confirmed != true || !context.mounted) return;
    var failed = false;
    for (final item in snapshot) {
      try {
        final row = item.video!;
        await removeVideoDownload(
          source: item.source,
          page: Uri.parse(row['url'] as String),
          quality: '${row['quality'] ?? ''}',
          format: '${row['format'] ?? 'mp4'}',
          expected: tokens[item.key],
        );
      } catch (_) {
        failed = true;
      }
    }
    if (failed && context.mounted) showErrorToast(t.download.removeFileFailed);
  } catch (_) {
    if (context.mounted) showErrorToast(t.download.removeFileFailed);
  }
}

/// Both source work entries and episodes share the same poster and card
/// geometry; grouping changes navigation, not the information hierarchy.
class SourceDownloadedCardFrame extends StatelessWidget {
  const SourceDownloadedCardFrame({
    super.key,
    required this.row,
    required this.title,
    required this.metadata,
    required this.trailing,
    required this.onOpen,
    this.onManage,
    this.selecting = false,
    this.selected = false,
  });
  final Map<String, dynamic> row;
  final String title;
  final Widget metadata, trailing;
  final VoidCallback? onOpen, onManage;
  final bool selecting, selected;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colors.primary.withValues(alpha: .06)
          : Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onOpen,
              onLongPress: onManage,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        DownloadVideoTaskCover(
                          width: 88,
                          height: 132,
                          row: row,
                          localOnly: true,
                          fallback: const Icon(Icons.play_arrow_rounded),
                        ),
                        if (selecting)
                          DownloadCardSelection(
                            label: title,
                            selected: selected,
                            onTap: onOpen,
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 132),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              key: const ValueKey('source-download-card.title'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            DefaultTextStyle.merge(
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    height: 1.25,
                                  ),
                              child: metadata,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: 44, child: trailing),
        ],
      ),
    );
  }
}

class SourceDownloadedWorkCard extends StatelessWidget {
  const SourceDownloadedWorkCard({
    super.key,
    required this.work,
    required this.onOpen,
    required this.onManage,
    required this.onRemove,
    this.selecting = false,
    this.selected = false,
    this.enabled = true,
  });
  final DownloadVideoWork work;
  final VoidCallback onOpen, onManage, onRemove;
  final bool selecting, selected, enabled;
  @override
  Widget build(BuildContext context) => SourceDownloadedCardFrame(
    row: {...work.poster.video!, 'durationMs': null, 'sourceDuration': ''},
    title: work.title,
    selecting: selecting,
    selected: selecting && selected,
    onOpen: enabled ? onOpen : null,
    onManage: enabled && !selecting ? onManage : null,
    metadata: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.download.workEpisodeCount(count: work.episodes.length)),
        if (work.knownBytes != null) Text(downloadByteAmount(work.knownBytes!)),
      ],
    ),
    trailing: selecting
        ? const SizedBox.shrink()
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NativeVideoMenu(
                key: ValueKey(
                  jsonEncode([
                    for (final item in work.episodes)
                      [
                        item.video!['key'],
                        item.video!['attempt'],
                        item.video!['resourceVersion'],
                        item.video!['at'],
                      ],
                  ]),
                ),
                label: '',
                tooltip: t.common.more,
                selected: '',
                hostPresentation: true,
                width: 44,
                icon: Icons.more_horiz_rounded,
                symbol: 'ellipsis',
                options: {
                  'open': t.videoPlayback.episodes,
                  'manage': t.videoSource.manage,
                  'delete': t.common.delete,
                },
                optionIcons: const {
                  'open': (
                    icon: Icons.video_library_outlined,
                    symbol: 'list.bullet',
                  ),
                  'manage': (
                    icon: Icons.checklist_rounded,
                    symbol: 'checklist',
                  ),
                  'delete': (
                    icon: Icons.delete_outline_rounded,
                    symbol: 'trash',
                  ),
                },
                onSelected: (action) {
                  if (!enabled) return;
                  if (action == 'open')
                    onOpen();
                  else if (action == 'manage')
                    onManage();
                  else
                    onRemove();
                },
              ),
              const Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ),
  );
}

/// Source content uses the same exact resource/attempt recovery and removal
/// services as Downloads, without introducing another task-management root.
class SourceDownloadedEpisodeRow extends StatefulWidget {
  const SourceDownloadedEpisodeRow({
    super.key,
    required this.item,
    this.selecting = false,
    this.selected = false,
    this.episodeContext = false,
    this.showFileFormat = false,
    this.resumeAt,
    this.onSelect,
    this.onManage,
  });
  final DownloadCenterItem item;
  final bool selecting, selected, episodeContext, showFileFormat;
  final Duration? resumeAt;
  final VoidCallback? onSelect, onManage;
  @override
  State<SourceDownloadedEpisodeRow> createState() =>
      _SourceDownloadedEpisodeRowState();
}

class _SourceDownloadedEpisodeRowState
    extends State<SourceDownloadedEpisodeRow> {
  bool _busy = false;
  String? _cancellingKey;
  int? _cancellingAttempt;
  Future<void> _action(String action) async {
    if (_busy) return;
    final item = widget.item, row = widget.item.video!;
    if (action == 'play') {
      final key = row['key'];
      final currentAttempt = key is String
          ? VideoExportRecords.currentAttempt(key)
          : null;
      if (currentAttempt != null && currentAttempt != row['attempt']) return;
      setState(() => _busy = true);
      try {
        if (VideoDownloadRetry.needsSource(row)) {
          if (videoDownloadSourceTarget(row) != null)
            await openVideoDownloadWork(context, row);
          else
            showInfoToast(t.download.sourceUnavailableHint);
          return;
        }
        if (VideoDownloadRetry.canRetry(row)) {
          await retryVideoDownload(context, row);
          return;
        }
        if (row['local'] == true &&
            row['status'] == 'saved' &&
            row['fileRemoved'] != true &&
            row['fileInvalid'] != true &&
            row['resourceId'] is String) {
          await openLocalVideo(context, row['resourceId'] as String);
        } else {
          showInfoToast(t.download.playWhenComplete);
        }
        return;
      } catch (_) {
        if (mounted) showErrorToast(t.download.fileUnavailable);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
    setState(() => _busy = true);
    try {
      if (action == 'cancel') {
        final submitted = await confirmVideoDownloadCancellation(
          context,
          row,
          onConfirmed: () {
            if (mounted)
              setState(() {
                _cancellingKey = row['key'] as String;
                _cancellingAttempt = row['attempt'] as int?;
              });
          },
        );
        if (!submitted && mounted)
          setState(() {
            _cancellingKey = null;
            _cancellingAttempt = null;
          });
      } else if (action == 'export') {
        final resourceVersion = row['resourceVersion'];
        if (resourceVersion is! String) {
          showErrorToast(t.download.fileUnavailable);
          return;
        }
        final result = await VideoSystemDownload.exportLocal(
          row['resourceId'] as String,
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
      } else if (action == 'delete') {
        await deleteSourceDownloadedItems(context, [
          item,
        ], episodes: widget.episodeContext);
      }
    } catch (_) {
      if (mounted)
        showErrorToast(
          action == 'export'
              ? t.download.exportFailed
              : t.download.removeFileFailed,
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item, row = item.video!;
    final episode = DownloadEpisodeRowScope.of(context);
    final selecting = episode?.selecting ?? widget.selecting;
    final selected = episode?.selected ?? widget.selected;
    final busy = _busy || episode?.busy == true;
    final onSelect = episode == null ? widget.onSelect : episode.onSelect;
    final onManage = episode == null ? widget.onManage : episode.onManage;
    final playable =
        row['local'] == true &&
        row['status'] == 'saved' &&
        row['fileRemoved'] != true &&
        row['fileInvalid'] != true &&
        row['resourceReadPending'] != true &&
        row['resourceId'] is String &&
        (row['resourceId'] as String).isNotEmpty;
    final label = '${row['publicEpisodeLabel'] ?? ''}'.trim();
    final active = const {
      'queued',
      'pending',
      'preparing',
      'downloading',
      'saving',
    }.contains(row['status']);
    final cancelling =
        _cancellingKey == row['key'] && _cancellingAttempt == row['attempt'];
    final workTitle = '${row['publicWorkTitle'] ?? ''}'.trim();
    final title = widget.episodeContext && label.isNotEmpty
        ? label
        : workTitle.isNotEmpty
        ? workTitle
        : item.title;
    final menu = NativeVideoMenu(
      key: ValueKey((
        row['key'],
        row['attempt'],
        row['resourceVersion'],
        row['at'],
      )),
      label: '',
      tooltip: t.common.more,
      selected: '',
      hostPresentation: true,
      selectAfterDismissal: const {'export'},
      width: 44,
      icon: Icons.more_horiz_rounded,
      symbol: 'ellipsis',
      options: {
        if (playable &&
            row['format'] != 'hls' &&
            row['resourceVersion'] is String)
          'export': t.download.exportVideo,
        if (active) 'cancel': t.download.cancelTask,
        'delete': t.common.delete,
      },
      optionIcons: const {
        'export': (
          icon: Icons.ios_share_rounded,
          symbol: 'square.and.arrow.up',
        ),
        'delete': (icon: Icons.delete_outline_rounded, symbol: 'trash'),
        'cancel': (icon: Icons.close_rounded, symbol: 'xmark'),
      },
      onSelected: (action) {
        if (!_busy && !(action == 'cancel' && cancelling))
          unawaited(_action(action));
      },
    );
    Widget withTray(Widget child) {
      if (episode == null) return child;
      return DownloadSwipeActions(
        rowKey: item.key,
        openRow: episode.openSwipe,
        exposeActions: true,
        completedAt: playable ? item.completedAt : null,
        actionVersion: (
          row['key'],
          row['attempt'],
          row['status'],
          row['resourceId'],
          row['resourceVersion'],
          row['fileRemoved'],
          row['fileInvalid'],
          row['url'],
          row['at'],
        ),
        actions: [
          if (!selecting && !busy) ...[
            if (playable &&
                row['format'] != 'hls' &&
                row['resourceVersion'] is String)
              (
                id: 'export',
                label: t.download.exportVideo,
                icon: Icons.ios_share_rounded,
                run: () => unawaited(_action('export')),
              ),
            if (canManageDownloadedVideoEpisode(row))
              (
                id: 'delete',
                label: t.common.delete,
                icon: Icons.delete_outline_rounded,
                run: () => unawaited(_action('delete')),
              ),
          ],
        ],
        child: child,
      );
    }

    if (widget.episodeContext && playable && (!selecting || episode != null)) {
      final quality = '${row['quality'] ?? ''}'.trim();
      final variant = [
        if (quality.isNotEmpty) quality,
        if (widget.showFileFormat) '${row['format']}'.toUpperCase(),
      ].join(' · ');
      final play = DownloadEpisodePlayRow(
        title: title,
        variant: variant,
        bytes: item.sizeBytes,
        resumeAt: widget.resumeAt,
        onPlay: busy
            ? null
            : selecting
            ? onSelect
            : () => unawaited(_action('play')),
        onManage: busy || selecting ? null : onManage,
        selecting: selecting,
        selected: selected,
      );
      final key = ValueKey('source-download.${row['resourceId']}');
      if (episode != null) {
        return withTray(KeyedSubtree(key: key, child: play));
      }
      return Row(
        key: key,
        children: [
          Expanded(child: play),
          menu,
        ],
      );
    }
    return withTray(
      SourceDownloadedCardFrame(
        key: ValueKey('source-download.${row['resourceId'] ?? row['key']}'),
        row: row,
        title: title,
        selecting: selecting,
        selected: selecting && selected,
        onOpen: busy
            ? null
            : selecting
            ? onSelect
            : () => unawaited(_action('play')),
        onManage: busy || selecting ? null : onManage,
        metadata: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.episodeContext && label.isNotEmpty && label != title)
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            if ('${row['quality'] ?? ''}'.isNotEmpty)
              Text(
                '${row['quality']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (playable && item.sizeBytes != null)
              Text(downloadByteAmount(item.sizeBytes!)),
            if (!playable)
              Text(switch (row['status']) {
                'failed' => t.download.failed,
                'cancelled' => t.download.cancelled,
                'paused' => t.download.paused,
                'preparing' || 'queued' || 'pending' => t.download.videoQueued,
                'saving' => t.download.videoSaving,
                'interrupted' => t.download.videoInterrupted,
                'saved' => t.download.fileUnavailable,
                _ => t.download.downloading,
              }),
            if (row['status'] == 'downloading' && row['key'] is String)
              VideoDownloadTaskProgress(taskKey: row['key'] as String),
          ],
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!selecting && episode == null) menu,
            if (active && !selecting)
              IconButton(
                key: ValueKey('source-download-cancel.${row['key']}'),
                tooltip: t.download.cancelTask,
                onPressed: busy || cancelling
                    ? null
                    : () => unawaited(_action('cancel')),
                icon: const Icon(Icons.close_rounded),
              ),
            if (!selecting &&
                (VideoDownloadRetry.canRetry(row) ||
                    VideoDownloadRetry.needsSource(row) &&
                        videoDownloadSourceTarget(row) != null))
              VideoDownloadRetryAction(
                row: row,
                iconOnly: true,
                enabled: !busy,
              ),
          ],
        ),
      ),
    );
  }
}
