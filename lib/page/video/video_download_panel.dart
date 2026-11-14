import 'dart:async';
import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/service/download/download_byte_amount.dart';
import 'package:zephyr/page/donwload_task/view/download_task_entry.dart';
import 'package:zephyr/page/video/video_download.dart';
import 'package:zephyr/page/video/video_download_retry.dart';
import 'package:zephyr/page/video/video_download_source_navigation.dart';
import 'package:zephyr/page/video/video_download_retry_action.dart';
import 'package:zephyr/page/video/video_download_failure.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_download_progress.dart';
import 'package:zephyr/page/video/video_download_progress_text.dart';
import 'package:zephyr/page/video/video_download_availability.dart';

/// Shared task hierarchy; closing a presentation never cancels its transfer.
class VideoDownloadPanel extends StatelessWidget {
  const VideoDownloadPanel({
    super.key,
    required this.title,
    required this.onClose,
    required this.child,
    this.actions,
    this.continuing = false,
  });
  final String title;
  final VoidCallback onClose;
  final Widget child;
  final Widget? actions;
  final bool continuing;
  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: t.common.close,
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
      Flexible(child: child),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (continuing)
              Text(
                t.download.videoForegroundNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  key: const ValueKey('video-download-tasks'),
                  onPressed: () => openDownloadTasks(context),
                  icon: const Icon(Icons.downloading_outlined),
                  label: Text(t.download.title),
                ),
                ?actions,
              ],
            ),
          ],
        ),
      ),
    ];
    return LayoutBuilder(
      builder: (context, bounds) {
        if (bounds.hasBoundedHeight &&
            bounds.maxHeight <
                MediaQuery.textScalerOf(context).scale(16) * 18) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in children)
                  if (entry is Flexible)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: math.max(280, bounds.maxHeight * .65),
                      ),
                      child: entry.child,
                    )
                  else
                    entry,
              ],
            ),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }
}

/// Unknown size remains unknown. Media progress is separate from byte totals.
class VideoDownloadProgressReadout extends StatefulWidget {
  const VideoDownloadProgressReadout({
    super.key,
    this.received,
    this.total,
    this.mediaProgress,
    this.receivedSource,
    this.row,
  });
  final Map<String, dynamic>? row;
  final int? received, total;
  final double? mediaProgress;
  final String? receivedSource;
  @override
  State<VideoDownloadProgressReadout> createState() =>
      _VideoDownloadProgressReadoutState();
}

class _VideoDownloadProgressReadoutState
    extends State<VideoDownloadProgressReadout> {
  final _clock = Stopwatch()..start();
  final _sampler = VideoDownloadRateSampler();

  @override
  void dispose() {
    _clock.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final value = VideoDownloadByteProgress.fromRow(
      row ??
          {
            'received': widget.received,
            'total': widget.total,
            'receivedSource': widget.receivedSource,
            'mediaProgress': widget.mediaProgress,
          },
    );
    final ratio = value.fraction;
    final rate = row == null
        ? null
        : _sampler.update(row, elapsed: _clock.elapsed);
    final fields = videoDownloadProgressText(
      progress: value,
      rate: rate,
      formatBytes: downloadByteAmount,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(value: ratio),
        if (fields.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              fields.join(' · '),
              key: const ValueKey('video-download.progress-details'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

/// Event-driven projection of the real queue. No media resolution or polling.
class VideoDownloadCurrentTasks extends StatelessWidget {
  const VideoDownloadCurrentTasks({
    super.key,
    required this.taskKeys,
    this.onRetry,
    this.onReselect,
    this.allowSourceNavigation = true,
    this.retryEnabled = true,
    this.availability,
    this.checkingResources = false,
    this.resourceReadFailed = false,
  });
  final Set<String> taskKeys;
  final Future<void> Function(Map<String, dynamic>)? onRetry;
  final void Function(Map<String, dynamic>)? onReselect;
  final bool allowSourceNavigation, retryEnabled;
  final VideoDownloadAvailability? availability;
  final bool checkingResources, resourceReadFailed;

  bool _missingFile(Map<String, dynamic> row) {
    final watch = Uri.tryParse('${row['url']}');
    return row['status'] == 'saved' &&
        availability != null &&
        watch != null &&
        (row['quality'] is! String ||
            !availability!
                .episode(
                  watch,
                  quality: row['quality'] as String,
                  format: videoDownloadFormat(row),
                )
                .downloaded);
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: VideoExportRecords.changes,
    builder: (_, revision, _) => FutureBuilder<List<Map<String, dynamic>>>(
      future: VideoExportRecords.readTaskSnapshot(),
      builder: (context, snapshot) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final row in snapshot.data ?? const <Map<String, dynamic>>[])
            if (taskKeys.contains(row['key']))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${row['title'] ?? ''}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(switch (row['status']) {
                      'preparing' => t.download.videoQueued,
                      'downloading' => t.download.downloading,
                      'saving' => t.download.videoSaving,
                      'saved' =>
                        checkingResources
                            ? t.common.loading
                            : resourceReadFailed
                            ? t.common.loadingFailed
                            : _missingFile(row)
                            ? t.download.fileUnavailable
                            : row['fileRemoved'] == true
                            ? t.download.fileRemoved
                            : row['fileInvalid'] == true
                            ? t.download.fileUnavailable
                            : t.download.videoSaved,
                      'cancelled' => t.download.videoCancelled,
                      'interrupted' => t.download.videoInterrupted,
                      _ => videoDownloadFailureText(
                        row['failureReason'],
                        inWork: !allowSourceNavigation,
                        chinese:
                            Localizations.localeOf(context).languageCode ==
                            'zh',
                      ),
                    }),
                    if (allowSourceNavigation &&
                        VideoDownloadRetry.needsSource(row) &&
                        videoDownloadSourceTarget(row) == null)
                      Text(
                        t.download.sourceUnavailableHint,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (onReselect != null &&
                        row['failureReason'] == 'qualityUnavailable')
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          key: ValueKey(
                            'video-download-inline-reselect.${row['key']}',
                          ),
                          onPressed: retryEnabled
                              ? () => onReselect!(row)
                              : null,
                          child: Text(t.download.reselect),
                        ),
                      )
                    else if (onRetry != null &&
                        (const {
                              'failed',
                              'cancelled',
                              'interrupted',
                              'routeUnavailable',
                              'unavailable',
                              'unsupported',
                              'busy',
                            }.contains(row['status']) ||
                            _missingFile(row) ||
                            resourceReadFailed))
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          key: ValueKey(
                            'video-download-inline-retry.${row['key']}',
                          ),
                          onPressed: retryEnabled
                              ? () => unawaited(onRetry!(row))
                              : null,
                          child: Text(t.common.retry),
                        ),
                      )
                    else if (allowSourceNavigation &&
                        (VideoDownloadRetry.needsSource(row)
                            ? videoDownloadSourceTarget(row) != null
                            : VideoDownloadRetry.canRetry(row)))
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: VideoDownloadRetryAction(row: row),
                      ),
                    if (row['status'] == 'downloading')
                      VideoDownloadProgressReadout(
                        key: ValueKey((
                          'task-progress',
                          row['key'],
                          row['attempt'],
                        )),
                        row: row,
                      ),
                    if (const {
                      'preparing',
                      'downloading',
                      'saving',
                    }.contains(row['status']))
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          key: ValueKey(
                            'video-download-inline-cancel.${row['key']}.${row['attempt']}',
                          ),
                          onPressed: row['attempt'] is int
                              ? () => unawaited(
                                  VideoSystemDownload.cancelTask(
                                    row['key'] as String,
                                    expectedAttempt: row['attempt'] as int,
                                  ).catchError((Object _) {}),
                                )
                              : null,
                          child: Text(t.videoDownload.cancel),
                        ),
                      ),
                  ],
                ),
              ),
        ],
      ),
    ),
  );
}

/// Reads only the small task log; metadata/poster/network resolution is excluded.
class VideoDownloadTaskProgress extends StatefulWidget {
  const VideoDownloadTaskProgress({super.key, required this.taskKey});
  final String taskKey;
  @override
  State<VideoDownloadTaskProgress> createState() =>
      _VideoDownloadTaskProgressState();
}

class _VideoDownloadTaskProgressState extends State<VideoDownloadTaskProgress> {
  Map<String, dynamic>? _row;
  int _epoch = 0;
  @override
  void initState() {
    super.initState();
    VideoExportRecords.changes.addListener(_reload);
    _reload();
  }

  @override
  void didUpdateWidget(covariant VideoDownloadTaskProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taskKey != widget.taskKey) {
      _row = null;
      _reload();
    }
  }

  Future<void> _reload() async {
    final epoch = ++_epoch;
    try {
      final rows = await VideoExportRecords.readTaskSnapshot();
      if (!mounted || epoch != _epoch) return;
      final matches = rows.where((row) => row['key'] == widget.taskKey);
      setState(() => _row = matches.isEmpty ? null : matches.first);
    } catch (_) {
      // A read failure cannot turn a package counter into network progress.
    }
  }

  @override
  void dispose() {
    VideoExportRecords.changes.removeListener(_reload);
    _epoch++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _row == null
      ? const LinearProgressIndicator()
      : VideoDownloadProgressReadout(row: _row);
}
