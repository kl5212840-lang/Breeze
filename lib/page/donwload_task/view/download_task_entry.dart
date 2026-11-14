import 'package:zephyr/page/video/video_download_navigation.dart';
import 'package:zephyr/widgets/toast.dart';
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/download/download_center_navigation.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/service/download/download_task_progress.dart';
import 'package:zephyr/service/download/download_task_repository.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';

/// Every task shortcut opens the one Downloads center. An unavailable main
/// owner leaves the current page intact; it never creates another task screen.
Future<void> openDownloadTasks(BuildContext context) async {
  if (!DownloadCenterNavigation.available) {
    showErrorToast(t.videoPlayback.actionFailed);
    return;
  }
  if (!await VideoDownloadNavigation.pauseBeforeOpeningTasks()) {
    showErrorToast(t.videoPlayback.actionFailed);
    return;
  }
  if (!context.mounted) return;
  if (!await DownloadCenterNavigation.open(
    from: VideoDownloadNavigationOrigin.of(context),
  )) {
    showErrorToast(t.videoPlayback.actionFailed);
  }
}

/// A nearby entrance into the existing persistent comic download queue.
/// Progress is read from the same checkpoints as the task page, never inferred
/// from the launch toast or from a downloaded-cover record.
class DownloadTaskEntry extends StatefulWidget {
  const DownloadTaskEntry({
    super.key,
    required this.onOpen,
    this.source,
    this.comicId,
    this.compact = false,
    this.label,
  });
  final VoidCallback onOpen;
  final String? label;
  final String? source, comicId;
  final bool compact;

  @override
  State<DownloadTaskEntry> createState() => _DownloadTaskEntryState();
}

class _DownloadTaskEntryState extends State<DownloadTaskEntry> {
  StreamSubscription? _watch;
  List<DownloadTask> _tasks = [];
  static const _repository = DownloadTaskRepository();

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant DownloadTaskEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.comicId != widget.comicId) {
      _subscribe();
    }
  }

  void _subscribe() {
    unawaited(_watch?.cancel());
    _tasks = _matching(objectbox.downloadTaskBox.getAll());
    _watch = objectbox.downloadTaskBox.query().watch().listen((query) {
      if (mounted) {
        setState(() => _tasks = _matching(query.find()));
      }
    });
  }

  List<DownloadTask> _matching(List<DownloadTask> rows) => rows.where((row) {
    final payload = _repository.readPayload(row);
    return (widget.source == null || payload?.from == widget.source) &&
        (widget.comicId == null || row.comicId == widget.comicId);
  }).toList();

  @override
  void dispose() {
    unawaited(_watch?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _tasks
        .where(
          (task) =>
              (!task.isCompleted &&
                  _repository.readPayload(task)?.stateCode != 'paused') ||
              _repository.readPayload(task)?.phaseCode == 'cancelling',
        )
        .toList();
    if (widget.compact) {
      return IconButton(
        key: const ValueKey('download-task-entry'),
        tooltip: widget.label ?? t.download.title,
        onPressed: widget.onOpen,
        icon: Badge(
          isLabelVisible: active.isNotEmpty,
          label: Text('${active.length}'),
          child: const Icon(Icons.downloading_outlined),
        ),
      );
    }
    DownloadTask? running;
    for (final task in active) {
      if (task.isDownloading) {
        running = task;
        break;
      }
    }
    final failed = active
        .where((task) => _repository.readPayload(task)?.stateCode == 'failed')
        .length;
    final payload = running == null ? null : _repository.readPayload(running);
    final progress = payload == null
        ? null
        : downloadTaskPayloadProgressFraction(payload);
    final detail = payload == null
        ? ''
        : downloadTaskPayloadProgressMessage(payload);
    final latest = _tasks.isEmpty
        ? null
        : (_tasks.toList()..sort((a, b) => b.id.compareTo(a.id))).first;
    final latestPayload = latest == null
        ? null
        : _repository.readPayload(latest);
    final status = latestPayload?.phaseCode == 'cancelling'
        ? t.download.statusCancelling
        : running != null
        ? detail.isNotEmpty
              ? detail
              : t.download.downloading
        : failed > 0
        ? t.download.notificationFailedTitle
        : active.isNotEmpty
        ? t.download.pending(count: active.length)
        : latestPayload?.phaseCode == 'fileRemoved'
        ? t.download.fileRemoved
        : latestPayload?.stateCode == 'cancelled'
        ? t.download.cancelled
        : latestPayload?.stateCode == 'completed'
        ? t.download.notificationCompleteTitle
        : _tasks.isEmpty
        ? ''
        : t.common.unknown;
    return TouchHoverIntent(
      identity: 'download:${widget.source}:${widget.comicId}',
      builder: (context, hover) => ListTile(
        key: const ValueKey('download-task-entry'),
        hoverColor: hover.hoverColor(),
        leading: const Icon(Icons.downloading_outlined),
        title: Text(widget.label ?? t.download.title),
        subtitle: status.isEmpty
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(status),
                  if (running != null && progress != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: LinearProgressIndicator(value: progress),
                    ),
                ],
              ),
        trailing: const Icon(Icons.chevron_right),
        onTap: widget.onOpen,
      ),
    );
  }
}
