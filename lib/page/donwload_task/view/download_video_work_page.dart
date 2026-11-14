import 'dart:async';

import 'package:collection/collection.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/donwload_task/service/download_center_projection.dart';
import 'package:zephyr/page/donwload_task/service/download_video_snapshot_merge.dart';
import 'package:zephyr/page/donwload_task/view/download_card_details.dart';
import 'package:zephyr/page/donwload_task/view/download_episode_management.dart';
import 'package:zephyr/page/donwload_task/view/download_queue_pause_notice.dart';
import 'package:zephyr/page/donwload_task/view/download_swipe_actions.dart';
import 'package:zephyr/page/donwload_task/view/download_task_cover.dart';
import 'package:zephyr/page/donwload_task/view/download_work_sections.dart';
import 'package:zephyr/widgets/work_list_divider.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/service/download/download_byte_amount.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_download_progress.dart';
import 'package:zephyr/page/video/video_download_progress_text.dart';
import 'package:zephyr/page/video/video_download_retry.dart';
import 'package:zephyr/page/video/video_download_source_navigation.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_episode_ranges.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/page/video/video_cover_overlay.dart';
import 'package:zephyr/page/video/video_playback_preferences.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/plugin/plugin_display_name.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/widgets/collection_selection_mark.dart';
import 'package:zephyr/widgets/pull_refresh_feedback.dart';
import 'package:zephyr/page/donwload_task/service/download_read_queue.dart';
import 'package:zephyr/service/download/download_admission.dart';

DownloadCenterItem _liveItem(
  DownloadCenterItem item,
  Map<String, dynamic>? progress,
) => DownloadCenterItem(
  key: item.key,
  source: item.source,
  title: item.title,
  priority: item.priority,
  at: item.at,
  video: mergeVideoDownloadSnapshot(item.video!, progress),
  videoFields: item.videoFields,
);

/// The live status can advance before the next inventory projection updates
/// its priority. An unverified saved file is distinct from a failed attempt.
bool canManageDownloadedVideoEpisode(Map<String, dynamic> row) =>
    !const {
      'queued',
      'pending',
      'preparing',
      'downloading',
      'saving',
    }.contains(row['status']) &&
    (row['status'] != 'saved' || row['resourceReadPending'] != true);

/// Each task keeps its own monotonic counter; mixed network/package rates are
/// never added and presented as a single network speed.
class _WorkTransferDetails extends StatefulWidget {
  const _WorkTransferDetails({required this.work});
  final DownloadVideoWork work;
  @override
  State<_WorkTransferDetails> createState() => _WorkTransferDetailsState();
}

class _WorkTransferDetailsState extends State<_WorkTransferDetails> {
  final _clock = Stopwatch()..start();
  final _samplers = <String, VideoDownloadRateSampler>{};
  final _rates = <String, VideoDownloadRate>{};

  void _sample() {
    final keys = <String>{};
    for (final item in widget.work.episodes) {
      keys.add(item.key);
      final rate = (_samplers[item.key] ??= VideoDownloadRateSampler()).update(
        item.video!,
        elapsed: _clock.elapsed,
      );
      if (rate == null) {
        _rates.remove(item.key);
      } else {
        _rates[item.key] = rate;
      }
    }
    _samplers.removeWhere((key, _) => !keys.contains(key));
    _rates.removeWhere((key, _) => !keys.contains(key));
  }

  @override
  void initState() {
    super.initState();
    _sample();
  }

  @override
  void didUpdateWidget(covariant _WorkTransferDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sample();
  }

  @override
  void dispose() {
    _clock.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final work = widget.work;
    final known = work.knownBytes;
    final totals = work.episodes.map((item) => item.totalBytes).toList();
    final total = totals.every((value) => value != null)
        ? totals.fold<int>(0, (sum, value) => sum + value!)
        : null;
    final package = work.episodes.any(
      (item) => VideoDownloadByteProgress.fromRow(item.video!).isPackage,
    );
    final networkRates = _rates.values
        .where((rate) => !rate.isPackage)
        .toList();
    final labels = videoDownloadProgressText(
      row: {
        if (known != null) 'received': known,
        if (!package && total != null && total > 0) 'total': total,
      },
      includePercent: false,
      rate: work.transferring && networkRates.isNotEmpty
          ? VideoDownloadRate(
              networkRates.fold<double>(
                0,
                (sum, rate) => sum + rate.bytesPerSecond,
              ),
              isPackage: false,
            )
          : null,
      formatBytes: downloadByteAmount,
    );
    if (known != null && !work.completeBytes && labels.isNotEmpty) {
      labels[0] = '≥ ${labels[0]}';
    }
    final completedAt = work.active
        ? null
        : work.episodes
              .map((episode) => episode.completedAt)
              .nonNulls
              .fold<DateTime?>(
                null,
                (latest, at) =>
                    latest == null || at.isAfter(latest) ? at : latest,
              );
    return DownloadCardFooter(
      itemKey: work.key,
      metrics: labels,
      completedAt: completedAt,
    );
  }
}

List<String> downloadVideoWorkStateLabels(DownloadVideoWork work) {
  final blocked = <DownloadNetworkWait, int>{};
  var blockedQueued = 0, blockedFailed = 0;
  for (final item in work.episodes) {
    final row = item.video!;
    final wait = DownloadNetworkWait.fromCode(row['failureReason']);
    if (wait == null) continue;
    if (row['status'] == 'preparing') {
      blockedQueued++;
    } else if (row['status'] == 'failed') {
      blockedFailed++;
    } else {
      continue;
    }
    blocked.update(wait, (count) => count + 1, ifAbsent: () => 1);
  }
  final waiting = work.waiting - blockedQueued;
  final failed = work.failed - blockedFailed;
  return [
    if (work.transferring)
      work.episodes.any((item) => item.video?['status'] == 'downloading')
          ? t.download.downloading
          : t.download.videoSaving,
    for (final entry in blocked.entries) '${entry.key.label} ${entry.value}',
    if (failed > 0) '${t.download.failed} $failed',
    if (waiting > 0) t.download.pending(count: waiting),
    if (work.paused > 0) '${t.download.paused} ${work.paused}',
    if (work.cancelled > 0) '${t.download.cancelled} ${work.cancelled}',
  ];
}

String _completedDownloads(BuildContext context, int completed, int total) =>
    Localizations.localeOf(context).languageCode == 'zh'
    ? '已完成 $completed / $total 项下载'
    : '$completed of $total downloads complete';

String _matchingDownloads(BuildContext context, int matched, int total) =>
    Localizations.localeOf(context).languageCode == 'zh'
    ? '匹配 $matched / $total 项下载'
    : '$matched of $total downloads match';

int _retryFailedCount(DownloadVideoWork work) => work.failedEpisodes
    .where(
      (item) =>
          VideoDownloadRetry.canRetry(item.video!) &&
          !VideoDownloadRetry.isWaitingForNetwork(item.video!) &&
          !VideoDownloadRetry.needsSource(item.video!),
    )
    .length;
bool _canRetryFailed(DownloadVideoWork work) => _retryFailedCount(work) > 0;

/// Work is a navigation summary; actions still receive original episode rows.
class DownloadVideoWorkCard extends StatelessWidget {
  const DownloadVideoWorkCard({
    super.key,
    required this.work,
    required this.sourceTitle,
    required this.onOpen,
    required this.onManage,
    required this.onRemove,
    this.openSwipe,
    this.onOpenDetails,
    this.onRetryFailed,
    this.onTogglePin,
    this.progress = const {},
    this.managing = false,
    this.selected = false,
    this.enabled = true,
    this.unread = false,
    this.pinned = false,
  });
  final DownloadVideoWork work;
  final String sourceTitle;
  final VoidCallback onOpen, onManage;
  final ValueChanged<DownloadVideoWork> onRemove;
  final ValueNotifier<String?>? openSwipe;
  final ValueChanged<Map<String, dynamic>>? onOpenDetails;
  final ValueChanged<DownloadVideoWork>? onRetryFailed;
  final VoidCallback? onTogglePin;
  final Map<String, ValueListenable<Map<String, dynamic>>> progress;
  final bool managing, selected, enabled, unread, pinned;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge(
      work.episodes
          .map((item) => progress[item.video?['key']])
          .whereType<Listenable>(),
    ),
    builder: (context, _) {
      final live = DownloadVideoWork(
        identity: work.identity,
        totalEpisodes: work.totalEpisodes,
        episodes: work.episodes
            .map((item) => _liveItem(item, progress[item.video?['key']]?.value))
            .toList(),
      );
      final colors = Theme.of(context).colorScheme;
      final muted = Theme.of(context).textTheme.bodySmall?.copyWith(
        color: colors.onSurfaceVariant,
        height: 1.25,
      );
      final fraction = live.progress;
      final wholeWork = live.episodes.length == live.totalEpisodes;
      final count = live.episodes.length;
      final chinese = Localizations.localeOf(context).languageCode == 'zh';
      final deleteLabel = wholeWork
          ? (chinese ? '删除整部' : 'Delete work')
          : (chinese
                ? '删除这 $count 项'
                : count == 1
                ? 'Delete this download'
                : 'Delete $count downloads');
      final stateLabels = downloadVideoWorkStateLabels(live);
      final retry = onRetryFailed != null && _canRetryFailed(live)
          ? Visibility(
              visible: !managing,
              maintainAnimation: true,
              maintainState: true,
              maintainSize: true,
              child: IconButton(
                key: ValueKey('download-work-retry.${work.key}'),
                tooltip: '${t.common.retry} (${_retryFailedCount(live)})',
                onPressed: enabled ? () => onRetryFailed!(live) : null,
                icon: const Icon(Icons.refresh_rounded),
              ),
            )
          : null;
      final summary = _completedDownloads(context, live.completed, count);
      final pageColor = Theme.of(context).scaffoldBackgroundColor;
      final checked = managing && !live.active && selected;
      final title = Text(
        work.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      );
      final card = Material(
        key: ValueKey('download-work.${work.key}'),
        color: checked
            ? Color.alphaBlend(colors.primary.withValues(alpha: .06), pageColor)
            : pageColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        child: Stack(
          children: [
            InkWell(
              key: ValueKey('download-work-open.${work.key}'),
              onTap: enabled && (!managing || !live.active) ? onOpen : null,
              onLongPress: enabled && !managing && !live.active
                  ? onManage
                  : null,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: DownloadCardMetrics.padding,
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        DownloadVideoTaskCover(
                          width: DownloadCardMetrics.coverWidth,
                          height: DownloadCardMetrics.coverHeight,
                          // An episode's duration does not describe the work.
                          row: {
                            ...live.poster.video!,
                            'durationMs': null,
                            'sourceDuration': '',
                          },
                          fallback: const Icon(Icons.video_library_outlined),
                        ),
                        if (pinned) const DownloadCardPin(),
                        if (managing)
                          DownloadCardSelection(
                            key: ValueKey('download-work-select.${work.key}'),
                            label: live.title,
                            selected: checked,
                            onTap: enabled && !live.active ? onOpen : null,
                          ),
                        if (unread)
                          PositionedDirectional(
                            top: -3,
                            end: -3,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: colors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colors.surface,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DownloadCardDetails(
                        heading: [
                          title,
                          Text(
                            sourceTitle,
                            maxLines:
                                MediaQuery.textScalerOf(context).scale(12) > 16
                                ? 2
                                : 1,
                            overflow: TextOverflow.ellipsis,
                            style: muted,
                          ),
                          Row(
                            key: ValueKey('download-work-summary.${work.key}'),
                            children: [
                              ExcludeSemantics(
                                child: Icon(
                                  Icons.video_library_outlined,
                                  size: 17,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  summary,
                                  style: muted?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (!managing)
                                ExcludeSemantics(
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: colors.onSurfaceVariant,
                                  ),
                                )
                              else
                                const SizedBox(width: 20),
                            ],
                          ),
                          if (!wholeWork)
                            Text(
                              _matchingDownloads(
                                context,
                                count,
                                work.totalEpisodes,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: muted,
                            ),
                        ],
                        footer: [
                          if (stateLabels.isNotEmpty || retry != null)
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    stateLabels.join(' · '),
                                    key: ValueKey(
                                      'download-work-state.${work.key}',
                                    ),
                                    style: muted?.copyWith(
                                      color: live.failed > 0
                                          ? colors.error
                                          : null,
                                    ),
                                  ),
                                ),
                                if (retry != null) retry,
                              ],
                            ),
                          if (live.transferring)
                            Row(
                              children: [
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: fraction,
                                    minHeight: 3,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                if (fraction != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '${(fraction * 100).floor()}%',
                                    key: ValueKey(
                                      'download-work-progress-text.${work.key}',
                                    ),
                                    style: muted,
                                  ),
                                ],
                              ],
                            ),
                          _WorkTransferDetails(work: live),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
      final openRow = openSwipe;
      if (openRow == null) return card;
      final openDetails = onOpenDetails;
      final togglePin = onTogglePin;
      final sourceRow = managing || !enabled || openDetails == null
          ? null
          : live.episodes
                .where(work.identity.contains)
                .map((episode) => episode.video!)
                .where((row) => videoDownloadSourceTarget(row) != null)
                .firstOrNull;
      return DownloadSwipeActions(
        rowKey: work.key,
        openRow: openRow,
        exposeActions: true,
        actionVersion: jsonEncode([
          for (final episode in live.episodes)
            [
              episode.key,
              episode.video!['attempt'],
              episode.video!['status'],
              episode.video!['resourceId'],
              episode.video!['resourceVersion'],
              episode.video!['fileRemoved'],
              episode.video!['fileInvalid'],
              episode.video!['url'],
              episode.video!['retryItemId'],
            ],
        ]),
        actions: [
          if (!managing && enabled && togglePin != null)
            (
              id: pinned ? 'unpin' : 'pin',
              label: pinned
                  ? (chinese ? '取消置顶' : 'Unpin')
                  : (chinese ? '置顶' : 'Pin'),
              icon: pinned ? Icons.push_pin : Icons.push_pin_outlined,
              run: togglePin,
            ),
          if (sourceRow != null && openDetails != null)
            (
              id: 'details',
              label: t.download.workDetails,
              icon: Icons.info_outline_rounded,
              run: () => openDetails(sourceRow),
            ),
          if (!managing && enabled && !live.active)
            (
              id: 'delete',
              label: deleteLabel,
              icon: Icons.delete_outline_rounded,
              run: () => onRemove(live),
            ),
        ],
        child: card,
      );
    },
  );
}

/// The play affordance and the episode title share one tap target.
class DownloadEpisodePlayRow extends StatelessWidget {
  const DownloadEpisodePlayRow({
    super.key,
    required this.title,
    required this.variant,
    required this.onPlay,
    this.bytes,
    this.resumeAt,
    this.onManage,
    this.selecting = false,
    this.selected = false,
  });

  final String title, variant;
  final int? bytes;
  final Duration? resumeAt;
  final VoidCallback? onPlay;
  final VoidCallback? onManage;
  final bool selecting, selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final position = resumeAt;
    final watched = DownloadEpisodeRowScope.of(context)?.watchCompleted == true;
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    final fileBytes = bytes;
    final metadataStyle = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    return Semantics(
      button: true,
      enabled: onPlay != null,
      checked: selecting ? selected : null,
      label: selecting ? null : t.download.openEpisodePlayback,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPlay,
        onLongPress: onManage,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 70),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: !selecting && position != null && onPlay != null
                        ? colors.primary.withValues(alpha: .12)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: 38,
                    child: selecting
                        ? Center(
                            child: Opacity(
                              opacity: onPlay == null ? .48 : 1,
                              child: CollectionSelectionMark(
                                visible: true,
                                selected: selected,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.play_arrow_rounded,
                            size: 25,
                            color: onPlay == null
                                ? colors.onSurface.withValues(alpha: .38)
                                : position != null
                                ? colors.primary
                                : colors.onSurfaceVariant,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 3,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (variant.isNotEmpty || fileBytes != null)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Expanded(
                              flex: 3,
                              child: variant.isEmpty
                                  ? const SizedBox.shrink()
                                  : Text(variant, style: metadataStyle),
                            ),
                            if (fileBytes != null) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                flex: 2,
                                child: Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: Text(
                                    downloadByteAmount(fileBytes),
                                    textAlign: TextAlign.end,
                                    style: metadataStyle?.copyWith(
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      if (watched || position != null)
                        Text(
                          watched
                              ? (chinese ? '已看完' : 'Watched')
                              : (chinese
                                    ? '看到 ${formatKnownVideoDuration(position!)}'
                                    : 'Watched to ${formatKnownVideoDuration(position!)}'),
                          key: const ValueKey(
                            'download-episode-watch-progress',
                          ),
                          style: metadataStyle,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One tray owner per work page, with the same selection contract in the
/// main download center and source downloads.
class DownloadEpisodeRowScope extends InheritedWidget {
  const DownloadEpisodeRowScope({
    super.key,
    required super.child,
    required this.openSwipe,
    required this.selecting,
    required this.selected,
    required this.busy,
    required this.onManage,
    required this.onSelect,
    this.watchCompleted = false,
  });
  final ValueNotifier<String?> openSwipe;
  final bool selecting, selected, busy, watchCompleted;
  final VoidCallback? onManage, onSelect;

  static DownloadEpisodeRowScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DownloadEpisodeRowScope>();

  @override
  bool updateShouldNotify(DownloadEpisodeRowScope oldWidget) => true;
}

class DownloadVideoWorkPage extends StatefulWidget {
  const DownloadVideoWorkPage({
    super.key,
    required this.initial,
    required this.readItems,
    required this.matches,
    required this.rowBuilder,
    this.sourceTitle,
    this.refreshItems,
    this.onRetryFailed,
    this.onContinueWatching,
    this.initialHistory,
    this.readyHistory,
    this.onScroll,
    this.canRemoveEpisode,
    this.onRemoveEpisodes,
  });
  final DownloadVideoWork initial;
  final Future<List<DownloadCenterItem>> Function() readItems;
  final Future<List<DownloadCenterItem>> Function()? refreshItems;
  final bool Function(DownloadCenterItem) matches;
  final Widget Function(
    BuildContext,
    DownloadCenterItem,
    bool showFileFormat,
    Duration? resumeAt,
  )
  rowBuilder;
  final String? sourceTitle;
  final Future<void> Function(Iterable<DownloadCenterItem>)? onRetryFailed;
  final Future<void> Function(BuildContext, DownloadCenterItem)?
  onContinueWatching;
  final Future<DownloadVideoWorkHistory>? initialHistory;
  final DownloadVideoWorkHistory? readyHistory;
  final VoidCallback? onScroll;
  final bool Function(DownloadCenterItem)? canRemoveEpisode;
  final Future<void> Function(BuildContext, List<DownloadCenterItem>)?
  onRemoveEpisodes;
  @override
  State<DownloadVideoWorkPage> createState() => _DownloadVideoWorkPageState();
}

typedef _WatchSnapshot = ({
  Uri watchUrl,
  Duration position,
  Duration duration,
  DateTime updatedAt,
  bool completed,
  String? resourceId,
});

typedef DownloadVideoWorkHistory = ({
  bool resumeEnabled,
  List<VideoWatchRecord> records,
  int historyRevision,
  int settingsRevision,
});

bool _isCurrentWorkHistory(DownloadVideoWorkHistory history) =>
    history.historyRevision == VideoWatchHistory.changes.value &&
    history.settingsRevision == VideoPlaybackPreferences.changes.value;

List<_WatchSnapshot> _workWatchPositions(DownloadVideoWorkHistory snapshot) => [
  for (final record in snapshot.records)
    (
      watchUrl: record.watchUrl,
      position: record.position,
      duration: record.duration,
      updatedAt: record.updatedAt,
      completed: record.completed,
      resourceId: record.localResourceId,
    ),
];

/// Can start before the route opens. History and preferences are device-local.
Future<DownloadVideoWorkHistory> readDownloadVideoWorkHistory(
  String source,
) async {
  final historyRevision = VideoWatchHistory.changes.value;
  final settingsRevision = VideoPlaybackPreferences.changes.value;
  try {
    final (settings, records) = await (
      VideoPlaybackPreferences.read(),
      VideoWatchHistory.read(source),
    ).wait;
    if (settings.recordHistory) {
      return (
        resumeEnabled: settings.resumeProgress,
        records: records,
        historyRevision: historyRevision,
        settingsRevision: settingsRevision,
      );
    }
  } catch (_) {
    // Playback history is optional to the work's inventory.
  }
  return (
    resumeEnabled: false,
    records: const <VideoWatchRecord>[],
    historyRevision: historyRevision,
    settingsRevision: settingsRevision,
  );
}

typedef _WorkResumeTarget = ({DownloadCenterItem item, Duration position});

class _DownloadVideoWorkPageState extends State<DownloadVideoWorkPage> {
  late List<DownloadCenterItem> _episodes = _ordered(
    widget.initial.episodes.where(widget.matches),
  );
  List<DownloadCenterItem>? _workInventory;
  late int _total = widget.initial.totalEpisodes;
  bool _failed = false;
  bool _retrying = false;
  final _openSwipe = ValueNotifier<String?>(null);
  final _selections = {
    for (final pane in DownloadWorkPane.values)
      pane: DownloadEpisodeSelection(),
  };
  DownloadEpisodeSelection get _selection => _selections[_pane]!;
  late DownloadWorkPane _pane;
  bool _finishedActive = false;
  final _ranges = DownloadEpisodeRangeSelection();
  bool _removing = false;
  bool _openingResume = false;

  bool _isSaved(DownloadCenterItem item) {
    final row = item.video!;
    return row['status'] == 'saved' &&
        row['local'] == true &&
        row['fileInvalid'] != true &&
        row['fileRemoved'] != true;
  }

  Iterable<DownloadCenterItem> _paneEpisodes(DownloadWorkPane pane) => _episodes
      .where((item) => _isSaved(item) == (pane == DownloadWorkPane.saved));

  void _selectPane(DownloadWorkPane pane) {
    if (_pane == pane || _removing) return;
    _openSwipe.value = null;
    setState(() => _pane = pane);
  }

  void _setEpisodes(List<DownloadCenterItem> next) {
    final previousActive = _paneEpisodes(
      DownloadWorkPane.active,
    ).map((item) => item.key).toSet();
    final previouslySelected = {
      for (final entry in _selections.entries)
        if (entry.value.active)
          entry.key: entry.value.matching(
            _candidates(_paneEpisodes(entry.key)),
          ),
    };
    _episodes = next;
    if (_paneEpisodes(DownloadWorkPane.active).isNotEmpty) {
      _finishedActive = false;
    } else if (next.any(
      (item) => _isSaved(item) && previousActive.contains(item.key),
    )) {
      _finishedActive = true;
    }
    for (final entry in previouslySelected.entries) {
      final selection = _selections[entry.key]!;
      final candidates = _candidates(_paneEpisodes(entry.key));
      selection.clearKeys(
        entry.value.difference(selection.matching(candidates)),
      );
    }
  }

  bool _canSelect(DownloadCenterItem item) =>
      canManageDownloadedVideoEpisode(item.video!) &&
      (widget.canRemoveEpisode?.call(item) ?? true);

  Map<String, Object> _candidates(Iterable<DownloadCenterItem> items) => {
    for (final item in items)
      if (_canSelect(item)) item.key: _version(item),
  };

  Object _version(DownloadCenterItem item) {
    final row = item.video!;
    return (
      row['key'],
      row['attempt'],
      row['status'],
      row['resourceId'],
      row['resourceVersion'],
      row['fileRemoved'],
      row['fileInvalid'],
      row['url'],
      row['at'],
    );
  }

  void _startManaging([DownloadCenterItem? item]) {
    if (_selection.active || _removing || widget.onRemoveEpisodes == null) {
      return;
    }
    _openSwipe.value = null;
    setState(() {
      if (item != null && _canSelect(item)) {
        _selection.start(item.key, _version(item));
      } else {
        _selection.start();
      }
    });
  }

  Future<void> _removeSelected(List<DownloadCenterItem> items) async {
    final remove = widget.onRemoveEpisodes;
    if (_removing || items.isEmpty || remove == null) return;
    setState(() => _removing = true);
    try {
      await remove(context, List.unmodifiable(items));
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  DownloadVideoWork get _work => DownloadVideoWork(
    identity: widget.initial.identity,
    episodes: _episodes,
    totalEpisodes: _total,
  );
  Future<void> _retryFailed() async {
    if (_retrying || widget.onRetryFailed == null) return;
    setState(() => _retrying = true);
    try {
      await widget.onRetryFailed!(_work.failedEpisodes.toList());
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  late final _reads = DownloadReadQueue(_readNow, isActive: () => mounted);
  int _revision = 0;
  int? _settledRevision;
  bool _verifyFiles = false;
  String _structure = '';
  List<_WatchSnapshot> _resumeHistory = const [];
  bool _resumeEnabled = false;
  int _resumeRevision = 0;
  bool _resumeVisible = false, _resumeNeedsRead = true;
  Future<DownloadVideoWorkHistory>? _initialHistory;
  @override
  void initState() {
    super.initState();
    _workInventory = widget.initial.inventory;
    _initialHistory = widget.initialHistory;
    if (widget.readyHistory case final history?
        when _isCurrentWorkHistory(history)) {
      _resumeHistory = _workWatchPositions(history);
      _resumeEnabled = history.resumeEnabled;
      _initialHistory = null;
    }
    _pane = _episodes.any(_isSaved)
        ? DownloadWorkPane.saved
        : DownloadWorkPane.active;
    VideoExportRecords.changes.addListener(_tasksChanged);
    VideoExportRecords.recoveredHlsChanges.addListener(_changed);
    VideoLocalResources.changes.addListener(_changed);
    VideoWatchHistory.changes.addListener(_resumeChanged);
    VideoPlaybackPreferences.changes.addListener(_resumeChanged);
    unawaited(_read());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible =
        ModalRoute.isCurrentOf(context) != false &&
        TickerMode.valuesOf(context).enabled;
    if (_resumeVisible && !visible) {
      _openSwipe.value = null;
      _resumeRevision++;
      _resumeNeedsRead = true;
    }
    _resumeVisible = visible;
    if (visible && _resumeNeedsRead) {
      _resumeNeedsRead = false;
      unawaited(_readResumePositions());
    }
  }

  void _resumeChanged() {
    _initialHistory = null;
    _resumeNeedsRead = !_resumeVisible;
    if (_resumeVisible) unawaited(_readResumePositions());
  }

  Future<void> _readResumePositions() async {
    final revision = ++_resumeRevision;
    final source = widget.initial.identity.source;
    final initial = _initialHistory;
    _initialHistory = null;
    DownloadVideoWorkHistory snapshot;
    try {
      snapshot = await (initial ?? readDownloadVideoWorkHistory(source));
    } catch (_) {
      // A preloaded history is optional to the local file inventory.
      if (!mounted || revision != _resumeRevision) return;
      snapshot = await readDownloadVideoWorkHistory(source);
    }
    if (!mounted || revision != _resumeRevision) return;
    if (!_isCurrentWorkHistory(snapshot)) {
      return _readResumePositions();
    }
    final history = _workWatchPositions(snapshot);
    if (snapshot.resumeEnabled != _resumeEnabled ||
        !listEquals(history, _resumeHistory)) {
      setState(() {
        _resumeEnabled = snapshot.resumeEnabled;
        _resumeHistory = history;
      });
    }
  }

  ({_WorkResumeTarget? resume, Map<String, _WatchSnapshot> episodes})
  _viewingProgress() {
    final inventory = _workInventory;
    if (inventory == null || _resumeHistory.isEmpty) {
      return (resume: null, episodes: const {});
    }
    final workPages = <Uri>{};
    final variants = <Uri, Map<String, DownloadCenterItem>>{};
    for (final item in inventory) {
      final row = item.video!;
      final uri = Uri.tryParse('${row['url']}');
      if (item.source != widget.initial.identity.source ||
          uri == null ||
          videoPlaybackIdentity(uri) != uri) {
        continue;
      }
      if (videoPublicPage(uri) case final page?) workPages.add(page);
      final resource = row['resourceId'];
      if (row['status'] != 'saved' ||
          row['local'] != true ||
          row['available'] != true ||
          row['filePresent'] != true ||
          row['resourceReadPending'] == true ||
          row['fileRemoved'] == true ||
          row['fileInvalid'] == true ||
          resource is! String ||
          !VideoLocalResources.validId(resource)) {
        continue;
      }
      (variants[uri] ??= {})[resource] = item;
    }
    final episodes = <String, _WatchSnapshot>{};
    _WorkResumeTarget? resume;
    var foundLatest = false;
    for (final record in _resumeHistory) {
      if (!workPages.contains(videoPublicPage(record.watchUrl))) continue;
      final candidates = variants[record.watchUrl];
      // A newer watch on another episode or line must never fall back to an
      // older entry. Legacy history can prove a variant only when unique.
      final item = candidates == null
          ? null
          : record.resourceId != null
          ? candidates[record.resourceId]
          : candidates.length == 1
          ? candidates.values.single
          : null;
      final resumable =
          !record.completed &&
          record.position.inSeconds > 0 &&
          record.position < record.duration;
      if (item != null && (record.completed || resumable)) {
        episodes.putIfAbsent(item.key, () => record);
      }
      if (!foundLatest) {
        foundLatest = true;
        if (_resumeEnabled &&
            widget.onContinueWatching != null &&
            item != null &&
            resumable) {
          resume = (item: item, position: record.position);
        }
      }
    }
    return (resume: resume, episodes: episodes);
  }

  Future<void> _continueWatching(DownloadCenterItem item) async {
    if (_selection.active || _openingResume) return;
    final current = _viewingProgress().resume?.item;
    if (current == null ||
        current.key != item.key ||
        _version(current) != _version(item)) {
      return;
    }
    _openSwipe.value = null;
    setState(() => _openingResume = true);
    try {
      await widget.onContinueWatching!(context, current);
    } finally {
      if (mounted) {
        setState(() => _openingResume = false);
        _resumeChanged();
      }
    }
  }

  void _tasksChanged() {
    final tasks = VideoExportRecords.sessionTaskSnapshot();
    final structure = tasks
        .map(
          (row) =>
              '${row['key']}|${row['status']}|${row['attempt']}|${row['resourceId']}|${row['quality']}|${row['failureReason']}',
        )
        .join('\n');
    if (structure == _structure) return;
    _structure = structure;
    // Update the work's interaction state immediately for task transitions.
    // A separately verified inventory still decides whether a file is playable.
    final live = {
      for (final task in tasks)
        if (task['status'] != 'saved') task['key']: task,
    };
    if (mounted &&
        (_workInventory ?? _episodes).any(
          (item) => live.containsKey(item.video!['key']),
        )) {
      setState(() {
        _setEpisodes(
          _ordered([
            for (final item in _episodes)
              _liveItem(item, live[item.video!['key']]),
          ]),
        );
        if (_workInventory case final inventory?) {
          _workInventory = [
            for (final item in inventory)
              _liveItem(item, live[item.video!['key']]),
          ];
        }
      });
    }
    _changed();
  }

  void _changed() {
    _revision++;
    unawaited(_read());
  }

  int _episodeRank(DownloadCenterItem item) => switch (item.video?['status']) {
    'downloading' || 'saving' => 0,
    'queued' ||
    'pending' ||
    'preparing' when item.video?['phaseCode'] == 'waitingRetry' => 3,
    'queued' || 'pending' || 'preparing' => 2,
    'paused' => 4,
    'cancelled' || 'canceled' => 5,
    'saved' when _isSaved(item) => 6,
    _ => 1,
  };

  List<DownloadCenterItem> _ordered(Iterable<DownloadCenterItem> items) =>
      items.toList()..sort((a, b) {
        final rank = _episodeRank(a);
        final state = rank.compareTo(_episodeRank(b));
        if (state != 0) return state;
        if (rank == 2) {
          final queued = b.at.compareTo(a.at);
          if (queued != 0) return queued;
        }
        final left = a.video?['publicEpisodeOrder'];
        final right = b.video?['publicEpisodeOrder'];
        if (left is int) {
          if (right is! int) return -1;
          if (left != right) return left.compareTo(right);
        } else if (right is int) {
          return 1;
        }
        return a.key.compareTo(b.key);
      });
  Future<void> _read({bool verifyFiles = false}) {
    _verifyFiles |= verifyFiles;
    return _reads.request();
  }

  Future<PullRefreshResult> _refreshFromPull() async {
    final episodes = _episodes, total = _total;
    await _read(verifyFiles: true);
    // A task change can supersede the in-flight projection. Its existing
    // follow-up covers the pull without starting another asset enumeration.
    while (mounted && _settledRevision != _revision) {
      final pending = _reads.pending;
      if (pending == null) return PullRefreshResult.ignored;
      await pending;
    }
    if (!mounted || _failed) return PullRefreshResult.ignored;
    final same =
        total == _total &&
        const DeepCollectionEquality().equals(
          episodes.map((item) => item.video).toList(),
          _episodes.map((item) => item.video).toList(),
        );
    return same ? PullRefreshResult.unchanged : PullRefreshResult.updated;
  }

  Future<void> _readNow() async {
    final revision = _revision;
    final read = _verifyFiles
        ? widget.refreshItems ?? widget.readItems
        : widget.readItems;
    _verifyFiles = false;
    try {
      final snapshot = await read();
      if (!mounted || revision != _revision) return;
      final live = {
        for (final row in VideoExportRecords.sessionTaskSnapshot())
          if (row['status'] != 'saved') row['key']: row,
      };
      final all = snapshot
          .where(widget.initial.identity.contains)
          .map((item) => _liveItem(item, live[item.video!['key']]))
          .toList();
      final matching = _ordered(all.where(widget.matches));
      setState(() {
        _workInventory = all;
        _setEpisodes(matching);
        _total = all.length;
        _failed = false;
      });
    } catch (_) {
      if (mounted && revision == _revision) setState(() => _failed = true);
    } finally {
      if (mounted && revision == _revision) _settledRevision = revision;
    }
  }

  Set<String> _formatVariants() {
    final groups = <(Uri, String), List<(String, String)>>{};
    for (final item in _episodes) {
      final row = item.video!;
      final url = row['url'], quality = row['quality'], format = row['format'];
      if (url is! String ||
          quality is! String ||
          (format != 'hls' && format != 'mp4'))
        continue;
      final uri = Uri.tryParse(url);
      final identity = uri == null ? null : videoPlaybackIdentity(uri);
      if (identity == null) continue;
      (groups[(identity, quality.trim())] ??= []).add((
        item.key,
        format as String,
      ));
    }
    return {
      for (final variants in groups.values)
        if (variants.any((variant) => variant.$2 != variants.first.$2))
          for (final variant in variants) variant.$1,
    };
  }

  @override
  void dispose() {
    _openSwipe.dispose();
    VideoExportRecords.changes.removeListener(_tasksChanged);
    VideoExportRecords.recoveredHlsChanges.removeListener(_changed);
    VideoLocalResources.changes.removeListener(_changed);
    VideoWatchHistory.changes.removeListener(_resumeChanged);
    VideoPlaybackPreferences.changes.removeListener(_resumeChanged);
    super.dispose();
  }

  Widget _overview(BuildContext context) {
    final work = _work;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final count = _episodes.length;
    final completed = work.completed;
    final filtered = count != _total;
    final sizes = _episodes
        .map((item) => item.sizeBytes)
        .whereType<int>()
        .toList();
    final bytes = sizes.fold(0, (sum, value) => sum + value);
    final size = sizes.isEmpty
        ? null
        : sizes.length < completed
        ? t.download.spaceAtLeast(
            size: downloadByteAmount(bytes, lowerBound: true),
          )
        : downloadByteAmount(bytes);
    final poster =
        (_episodes.isEmpty ? widget.initial.poster : work.poster).video!;
    final source = work.identity.source;
    final sourceName =
        widget.sourceTitle ??
        PluginRegistryService.I
            .getCachedPluginInfo(source)?['name']
            ?.toString()
            .trim() ??
        '';
    return Row(
      key: const ValueKey('video-work-overview'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DownloadVideoTaskCover(
          key: const ValueKey('video-work-cover'),
          width: 60,
          height: 90,
          row: {...poster, 'durationMs': null, 'sourceDuration': ''},
          fallback: const Icon(Icons.play_arrow_rounded),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              PluginDisplayNameBuilder(
                source: source,
                fallback: sourceName,
                builder: (context, name) => name.isEmpty
                    ? const SizedBox.shrink()
                    : Text(name, style: theme.textTheme.titleSmall),
              ),
              Text(
                _completedDownloads(context, completed, count),
                style: theme.textTheme.bodySmall,
              ),
              if (filtered)
                Text(_matchingDownloads(context, count, _total), style: muted),
              if (size != null)
                Text(
                  t.download.compactStorageUsed(size: size),
                  key: const ValueKey('video-work-local-size'),
                  style: muted,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _paneTools(bool saved) {
    final work = _work;
    final retryCount = saved ? 0 : _retryFailedCount(work);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!saved && work.waiting > 0)
          DownloadQueuePauseNotice(
            onResumeStarted: () => _openSwipe.value = null,
          ),
        if (!saved &&
            !_selection.active &&
            widget.onRetryFailed != null &&
            retryCount > 0)
          TextButton.icon(
            key: const ValueKey('video-work-retry-failed'),
            onPressed: _retrying ? null : _retryFailed,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text('${t.download.retryEpisodeDownload} ($retryCount)'),
          ),
        if (_failed)
          TextButton(
            onPressed: () => _read(verifyFiles: true),
            child: Text(
              '${_episodes.isEmpty ? t.common.loadingFailed : t.common.refreshRetained} · ${t.common.retry}',
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _emptyPane(BuildContext context, {required bool saved}) {
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            saved
                ? (chinese ? '暂无已下载剧集' : 'No downloaded episodes')
                : (chinese ? '暂无下载任务' : 'No download tasks'),
            textAlign: TextAlign.center,
          ),
          if (!saved &&
              _finishedActive &&
              _paneEpisodes(DownloadWorkPane.saved).isNotEmpty)
            TextButton(
              key: const ValueKey('video-work-view-saved'),
              onPressed: () => _selectPane(DownloadWorkPane.saved),
              child: Text(chinese ? '查看已下载' : 'View downloads'),
            ),
        ],
      ),
    );
  }

  Widget _continueCard(
    BuildContext context,
    DownloadCenterItem item,
    Duration position,
  ) {
    final theme = Theme.of(context);
    final row = item.video!;
    final episode = '${row['publicEpisodeLabel'] ?? ''}'.trim();
    final title = episode.isEmpty ? item.title : episode;
    final quality = '${row['quality'] ?? ''}'.trim();
    final variant = [
      if (quality.isNotEmpty) quality,
      if (row['format'] == 'hls') 'HLS' else 'MP4',
    ].join(' · ');
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    const corners = BorderRadius.all(Radius.circular(12));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: corners,
        child: InkWell(
          key: const ValueKey('video-work-continue-watching'),
          borderRadius: corners,
          onTap: _selection.active || _openingResume
              ? null
              : () => _continueWatching(item),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                spacing: 10,
                children: [
                  Icon(
                    Icons.play_arrow_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 3,
                      children: [
                        Text(
                          t.videoLibrary.continueWatching,
                          style: theme.textTheme.titleSmall,
                        ),
                        Wrap(
                          spacing: 10,
                          runSpacing: 3,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '$title · ${formatKnownVideoDuration(position)}',
                              style: theme.textTheme.bodyMedium,
                            ),
                            Text(variant, style: muted),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatVariants = _formatVariants();
    final viewing = _viewingProgress();
    final paneEpisodes = _paneEpisodes(_pane).toList();
    final saved = _pane == DownloadWorkPane.saved;
    final resume = saved ? viewing.resume : null;
    final episodeKeys = [for (final item in paneEpisodes) item.key];
    final range = saved
        ? _ranges.resolve(episodeKeys)
        : (index: 0, start: 0, end: episodeKeys.length);
    final indices = {
      for (var index = range.start; index < range.end; index++)
        episodeKeys[index]: index - range.start + 1,
    };
    final candidates = _candidates(paneEpisodes);
    final selected = _selection.matching(candidates);
    final list = NotificationListener<ScrollStartNotification>(
      onNotification: (notification) {
        if (notification.dragDetails != null &&
            notification.metrics.axis == Axis.vertical) {
          _openSwipe.value = null;
          widget.onScroll?.call();
        }
        return false;
      },
      child: PullRefreshFeedback.indicator(
        scope: widget.initial.identity,
        onRefresh: _refreshFromPull,
        child: ListView.separated(
          key: PageStorageKey(
            'video-download-work.${widget.initial.key}.${_pane.name}',
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          itemCount: paneEpisodes.isEmpty ? 2 : range.end - range.start + 1,
          findItemIndexCallback: (key) =>
              key is ValueKey<String> ? indices[key.value] : null,
          separatorBuilder: (_, index) => index == 0
              ? const SizedBox(height: 8)
              : const WorkListDivider(height: 8),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (resume != null)
                    _continueCard(context, resume.item, resume.position),
                  _paneTools(saved),
                  if (saved &&
                      episodeKeys.length > downloadWorkEpisodeRangeSize)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: VideoEpisodeRanges(
                        key: const ValueKey('download-video-ranges'),
                        count: episodeKeys.length,
                        index: range.index,
                        pageSize: downloadWorkEpisodeRangeSize,
                        padding: EdgeInsets.zero,
                        onChanged: (index) {
                          if (index == range.index) return;
                          _openSwipe.value = null;
                          setState(() => _ranges.select(episodeKeys, index));
                        },
                      ),
                    ),
                ],
              );
            }
            if (paneEpisodes.isEmpty) return _emptyPane(context, saved: saved);
            final item = paneEpisodes[range.start + index - 1];
            final watch = viewing.episodes[item.key];
            final watched = watch?.completed == true;
            return DownloadEpisodeRowScope(
              key: ValueKey(item.key),
              openSwipe: _openSwipe,
              selecting: _selection.active,
              selected: selected.contains(item.key),
              busy: _removing,
              watchCompleted: watched,
              onManage:
                  !_selection.active &&
                      widget.onRemoveEpisodes != null &&
                      candidates.containsKey(item.key)
                  ? () => _startManaging(item)
                  : null,
              onSelect:
                  _selection.active &&
                      !_removing &&
                      candidates.containsKey(item.key)
                  ? () => setState(
                      () => _selection.toggle(item.key, candidates[item.key]!),
                    )
                  : null,
              child: Builder(
                builder: (context) => widget.rowBuilder(
                  context,
                  item,
                  formatVariants.contains(item.key),
                  watched ? null : watch?.position,
                ),
              ),
            );
          },
        ),
      ),
    );
    return PopScope(
      canPop: !_selection.active,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_removing && _selection.active) {
          setState(_selection.close);
        }
      },
      child: SettingPageShell(
        title: widget.initial.title,
        actions: [
          if (widget.onRemoveEpisodes != null)
            TextButton(
              key: const ValueKey('download-episodes-manage'),
              onPressed: _removing
                  ? null
                  : _selection.active
                  ? () => setState(_selection.close)
                  : candidates.isNotEmpty
                  ? _startManaging
                  : null,
              child: Text(
                _selection.active ? t.common.done : t.bookshelf.manage,
              ),
            ),
        ],
        child: CollectionCoverPrivacyScope(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _overview(context),
                    const SizedBox(height: 8),
                    DownloadWorkSectionControl(
                      selected: _pane,
                      onSelected: _selectPane,
                      enabled: !_removing,
                    ),
                  ],
                ),
              ),
              Expanded(child: list),
              if (_selection.active)
                DownloadEpisodeManagementBar(
                  count: selected.length,
                  allSelected: selected.length == candidates.length,
                  onToggleAll: _removing || candidates.isEmpty
                      ? null
                      : () => setState(() => _selection.toggleAll(candidates)),
                  onDelete: _removing || selected.isEmpty
                      ? null
                      : () => _removeSelected(
                          paneEpisodes
                              .where((item) => selected.contains(item.key))
                              .toList(),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
