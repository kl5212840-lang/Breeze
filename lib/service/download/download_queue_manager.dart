import 'package:zephyr/service/download/resource_download_notifications.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/service/download/comic_download_task.dart';
import 'package:zephyr/service/download/comic_background_download.dart';
import 'package:zephyr/service/download/download_admission.dart';
import 'package:zephyr/service/download/download_asset_store.dart';
import 'package:zephyr/service/download/download_cancel_signal.dart';
import 'package:zephyr/service/download/download_chapter_cancellation.dart';
import 'package:zephyr/service/download/download_notification_reporter.dart';
import 'package:zephyr/service/download/download_resource_lifecycle.dart';
import 'package:zephyr/service/download/download_task_deletion.dart';
import 'package:zephyr/service/download/download_task_repository.dart';
import 'package:zephyr/service/download/download_retry.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';
import 'package:zephyr/service/lifecycle/foreground_task/foreground_task_service.dart';

import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/util/macos_activity.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/service/local_import_recovery.dart';

export 'package:zephyr/service/download/download_task_deletion.dart'
    show ComicTaskDeletionReceipt;

const _kQjsRuntimeCancelledMessage = '__QJS_RUNTIME_CANCELLED__';

typedef _ComicRetry = ({DownloadTask task, DownloadTaskJson payload});

final class DownloadSourceDisabled extends StateError {
  DownloadSourceDisabled() : super('Plugin is disabled');
}

final class ComicDownloadTreeBusy implements Exception {
  const ComicDownloadTreeBusy();
}

/// 下载进度信息
class DownloadProgress {
  final String comicName;
  final String message;
  final bool isCompleted;
  final bool isFailed;

  DownloadProgress({
    required this.comicName,
    required this.message,
    this.isCompleted = false,
    this.isFailed = false,
  });
}

/// 跨平台下载队列管理器（单例）
///
/// 任务粒度为单章节：点 1 章建 1 个任务，多选 N 章建 N 个任务，队列串行执行。
/// 在所有平台的主 Isolate 中运行，负责统一下载调度。
/// Android 端配合前台服务使用；前台服务与「后台保活」共用，仅用于提权与通知展示。
class DownloadQueueManager {
  static final DownloadQueueManager instance = DownloadQueueManager._();

  DownloadQueueManager._();

  static const _taskRepository = DownloadTaskRepository();
  final _admission = DownloadAdmission.instance;

  ({int id, String key, int attempt, String workKey})? _activeTask;
  String get _downloadingTaskKey => _activeTask?.key ?? '';
  String get _downloadingWorkKey => _activeTask?.workKey ?? '';
  final _taskStops = <String, Completer<void>>{};
  final _inactiveCancellationStops = <String, Completer<void>>{};
  final _removalWaits = <DownloadResourceRemovalLease>{};
  int _taskDeletionOperations = 0;
  Completer<void>? _backupTreeHold;
  bool _backupTreeRecoveryRequired = false;

  bool _isProcessing = false;
  bool _checkingAdmission = false;
  Future<void>? _workerCancellation;
  StreamSubscription? _watchSubscription;
  StreamSubscription<PluginSessionBoundary>? _sessionSubscription;
  Timer? _startupResumeTimer;
  Timer? _retryTimer;
  StreamSubscription? _retryPreferenceSubscription;
  bool _startupResumeWaiting = false;
  bool _failureDialogShowing = false;
  final Set<int> _startupResumeTaskIds = <int>{};
  final _priorityChanges = ValueNotifier<int>(0);
  Listenable get priorityChanges => _priorityChanges;
  ({int id, String key, int attempt})? _nextTask;

  bool _isPrioritized(DownloadTask task, DownloadTaskJson? payload) {
    final next = _nextTask;
    return next != null &&
        next.id == task.id &&
        next.key == payload?.taskKey &&
        next.attempt == payload?.attempt;
  }

  int compareQueuedTasks(
    DownloadTask left,
    DownloadTaskJson? leftPayload,
    DownloadTask right,
    DownloadTaskJson? rightPayload,
  ) {
    final leftFirst = _isPrioritized(left, leftPayload);
    final rightFirst = _isPrioritized(right, rightPayload);
    if (leftFirst != rightFirst) return leftFirst ? -1 : 1;
    final leftRetry = leftPayload?.phaseCode == 'waitingRetry';
    final rightRetry = rightPayload?.phaseCode == 'waitingRetry';
    if (leftRetry != rightRetry) return leftRetry ? 1 : -1;
    return left.id.compareTo(right.id);
  }

  AppLifecycleListener? _queueLifecycle;
  bool _retiredComicTransfers = false;

  bool get _waitForForeground => !_admission.foregroundAllowed;

  bool get _persistentRetryEnabled =>
      objectbox.userSettingBox
          .get(1)
          ?.globalSetting
          .retryDownloadUntilSuccess ??
      false;

  String get _retryWaitingLabel =>
      LocaleSettings.currentLocale == AppLocale.zhCn
      ? '等待重试'
      : 'Waiting to retry';

  void _retryPreferenceChanged() {
    if (_persistentRetryEnabled) return;
    final waiting = <int, String>{};
    for (final row in _taskRepository.getAll(incompleteOnly: true)) {
      final payload = _taskRepository.readPayload(row);
      if (payload?.phaseCode == 'waitingRetry')
        waiting[row.id] = payload!.taskKey;
    }
    _pauseTasksRetainingFiles(waiting, phase: 'retryDisabled');
    _retryTimer?.cancel();
    _retryTimer = null;
    if (waiting.isNotEmpty && _watchSubscription != null) {
      unawaited(_processQueue());
    }
  }

  Future<void> _deferComicRetry(
    int id,
    String key,
    int attempt,
    ComicDownloadRetryDeferred failure,
  ) async {
    await _taskRepository.flushTaskWrites(key);
    final row = objectbox.downloadTaskBox.get(id);
    final payload = row == null ? null : _taskRepository.readPayload(row);
    if (row == null ||
        payload == null ||
        !row.isDownloading ||
        row.isCompleted ||
        payload.taskKey != key ||
        payload.attempt != attempt ||
        payload.stateCode != 'running' ||
        _taskRepository.findByTaskKey(key)?.id != id)
      return;
    if (!_persistentRetryEnabled ||
        _sourceDisabled(payload.from) ||
        LocalPluginInstallationState.instance.isRemoved(payload.from) ||
        pluginSessionWriteFence.isChanging(payload.from)) {
      _pauseTasksRetainingFiles(
        {id: key},
        phase: 'retryDisabled',
        expectedAttempts: {id: attempt},
      );
      return;
    }
    final rounds = (payload.retryRounds + 1).clamp(1, 32);
    final at = DateTime.now()
        .add(failure.delayFor(rounds))
        .millisecondsSinceEpoch;
    _taskRepository.putPayload(
      row,
      payload.copyWith(
        stateCode: 'queued',
        phaseCode: 'waitingRetry',
        retryRounds: rounds,
        nextRetryAt: at,
        lastErrorCode: failure.reason.name,
        lastErrorMessage: '',
      ),
      status: _retryWaitingLabel,
      isDownloading: false,
    );
  }

  void _deferActiveChapterUntilForeground() {
    final active = _activeTask;
    if (active == null) {
      _isProcessing = false;
      return;
    }
    final retained = objectbox.store.runInTransaction(TxMode.write, () {
      final row = objectbox.downloadTaskBox.get(active.id);
      final payload = row == null ? null : _taskRepository.readPayload(row);
      if (row == null ||
          row.isCompleted ||
          !row.isDownloading ||
          payload == null ||
          payload.stateCode != 'running' ||
          !_ownsRunningAttempt(row.id, payload) ||
          !_canPauseTask(row, payload)) {
        return null;
      }
      _taskRepository.putPayload(
        row,
        payload.copyWith(
          stateCode: 'queued',
          phaseCode: 'waitingForeground',
          imagePaths: {
            ...payload.imagePaths,
            ...startedDownloadChapterPages(payload),
          }.toList(),
        ),
        status: t.download.statusWaiting,
        isDownloading: false,
      );
      return payload.from;
    });
    if (retained != null) _cancelWorkerRetainingFiles(active.key, retained);
  }

  /// 进度 Stream，供 UI 和前台服务通知监听
  final _progressController = StreamController<DownloadProgress>.broadcast();

  Stream<DownloadProgress> get progressStream => _progressController.stream;

  /// 当前是否有任务在执行
  bool get isProcessing => _isProcessing;

  /// Called under the work's removal lease so no new writer can take over.
  Future<void>? pendingComicWorkerStop({
    required String from,
    required String comicId,
  }) => _downloadingWorkKey == buildDownloadTaskKey(from, comicId)
      ? _taskStops[_downloadingTaskKey]?.future
      : null;

  /// The caller already owns the storage FIFO. Reject a live worker rather
  /// than await it (it may be on a slow source), and defer new disk mutations
  /// for the duration without changing the user's queue preference.
  Future<T> withStableDownloadTree<T>(Future<T> Function() action) async {
    if (_backupTreeHold != null ||
        _downloadingTaskKey.isNotEmpty ||
        _inactiveCancellationStops.isNotEmpty ||
        _taskDeletionOperations != 0) {
      throw const ComicDownloadTreeBusy();
    }
    final hold = _backupTreeHold = Completer<void>();
    try {
      return await action();
    } finally {
      try {
        LocalImportRecovery.requireRecovered();
      } on LocalImportRecoveryFailed {
        _backupTreeRecoveryRequired = true;
      }
      _backupTreeHold = null;
      hold.complete();
      if (_watchSubscription != null) unawaited(_processQueue());
    }
  }

  void _requireRecoveredTree() {
    if (!_backupTreeRecoveryRequired) return;
    LocalImportRecovery.requireRecovered();
    _backupTreeRecoveryRequired = false;
  }

  bool _blocksTreeWrites() {
    if (_backupTreeHold != null) return true;
    try {
      _requireRecoveredTree();
      return false;
    } on LocalImportRecoveryFailed {
      _isProcessing = false;
      return true;
    }
  }

  bool canPrioritize(DownloadTask task) {
    final payload = _taskRepository.readPayload(task);
    return payload != null &&
        !task.isDownloading &&
        !task.isCompleted &&
        const {'', 'queued', 'pending'}.contains(payload.stateCode) &&
        payload.phaseCode != 'cancelling' &&
        payload.phaseCode != downloadTaskDeletionPhase &&
        !_taskStops.containsKey(payload.taskKey) &&
        !LocalPluginInstallationState.instance.isRemoved(payload.from) &&
        !_sourceDisabled(payload.from);
  }

  bool prioritize(DownloadTask snapshot) {
    final expected = _taskRepository.readPayload(snapshot);
    final task = objectbox.downloadTaskBox.get(snapshot.id);
    if (expected == null || task == null || !canPrioritize(task)) return false;
    final current = _taskRepository.readPayload(task)!;
    if (current.taskKey != expected.taskKey ||
        current.attempt != expected.attempt) {
      return false;
    }
    _nextTask = (id: task.id, key: current.taskKey, attempt: current.attempt);
    _priorityChanges.value++;
    _startupResumeTaskIds.remove(task.id);
    unawaited(_processQueue());
    return true;
  }

  bool canPauseTask(DownloadTask task) {
    final payload = _taskRepository.readPayload(task);
    return payload != null && _canPauseTask(task, payload);
  }

  bool _canPauseTask(DownloadTask task, DownloadTaskJson payload) =>
      !task.isCompleted &&
      payload.phaseCode != 'cancelling' &&
      payload.phaseCode != downloadTaskDeletionPhase &&
      const {'', 'pending', 'queued', 'running'}.contains(payload.stateCode);

  /// Settle all requested rows before asking the running worker to stop.
  /// Snapshots identify the exact attempt the caller selected.
  int pauseTasks(Iterable<DownloadTask> snapshots) {
    _requireRecoveredTree();
    final tasks = <int, String>{};
    final attempts = <int, int>{};
    final sources = <String, String>{};
    for (final task in snapshots) {
      final payload = _taskRepository.readPayload(task);
      if (payload == null || !_canPauseTask(task, payload)) continue;
      tasks[task.id] = payload.taskKey;
      attempts[task.id] = payload.attempt;
      sources[payload.taskKey] = payload.from;
    }
    final paused = _pauseTasksRetainingFiles(
      tasks,
      phase: 'userPaused',
      expectedAttempts: attempts,
    );
    final activeKey = _downloadingTaskKey;
    if (paused.contains(activeKey)) {
      _cancelWorkerRetainingFiles(activeKey, sources[activeKey]!);
    } else if (paused.isNotEmpty && _watchSubscription != null) {
      // A recovered native transfer can exist before a Dart worker attaches.
      unawaited(_processQueue());
    }
    return paused.length;
  }

  bool canResumeTask(DownloadTask task) {
    final payload = _taskRepository.readPayload(task);
    return payload != null && _canResumeTask(task, payload);
  }

  bool _canResumeTask(DownloadTask task, DownloadTaskJson payload) {
    if (task.isDownloading ||
        payload.phaseCode == 'cancelling' ||
        payload.phaseCode == downloadTaskDeletionPhase) {
      return false;
    }
    if (!task.isCompleted) {
      return const {'paused', 'failed'}.contains(payload.stateCode) ||
          payload.phaseCode == 'waitingRetry' && payload.stateCode == 'queued';
    }
    final chapter = payload.chapterRef;
    return payload.stateCode == 'cancelled' &&
        payload.phaseCode == 'cancelled' &&
        payload.from.trim().isNotEmpty &&
        payload.comicId.trim().isNotEmpty &&
        (chapter.order > 0 ||
            chapter.logicalKey.trim().isNotEmpty ||
            chapter.chapterId.trim().isNotEmpty ||
            chapter.requestId.trim().isNotEmpty);
  }

  /// An explicit resume applies to the device queue, including tasks delayed
  /// for automatic startup recovery. Admission still owns every new worker.
  Future<void> resumeQueueFromUser() async {
    await _admission.setQueuePaused(false);
    if (_admission.queuePaused) return;
    _clearStartupResumeDelay();
    if (_watchSubscription != null) {
      unawaited(_processQueue());
      if (Platform.isAndroid &&
          _admission.networkWait == null &&
          _runnableTasks().isNotEmpty) {
        await _startForegroundForResume();
      }
    }
  }

  /// Requeue the existing rows. A newer attempt or a deleted row does not
  /// inherit the request, even if the old worker is still releasing its files.
  Future<void> resumeTasks(Iterable<DownloadTask> snapshots) async {
    final ids = <int>{};
    final resumes = <Future<_ComicRetry?>>[];
    for (final task in snapshots) {
      final payload = _taskRepository.readPayload(task);
      if (payload == null ||
          !_canResumeTask(task, payload) ||
          !ids.add(task.id)) {
        continue;
      }
      resumes.add(
        _prepareRetry(
          task.id,
          isCurrent: () {
            final current = objectbox.downloadTaskBox.get(task.id);
            if (current == null) return false;
            final live = _taskRepository.readPayload(current);
            return live?.taskKey == payload.taskKey &&
                live?.attempt == payload.attempt;
          },
        ),
      );
    }
    final ready = await Future.wait(resumes);
    final queued = _requeuePreparedRetries(ready.nonNulls);
    if (queued.isNotEmpty && Platform.isAndroid) {
      await _startForegroundForResume();
    }
  }

  Future<void> _startForegroundForResume() async {
    try {
      await ForegroundTaskService.instance.start();
    } catch (error, stackTrace) {
      logger.w('续下时无法启动 Android 前台服务', error: error, stackTrace: stackTrace);
      showWarningToast(t.settings.syncKeepForeground);
    }
  }

  bool canStopAndDeleteTask(DownloadTask snapshot) {
    final payload = _taskRepository.readPayload(snapshot);
    return payload != null && _canStopAndDeleteTask(snapshot, payload);
  }

  bool _canStopAndDeleteTask(DownloadTask task, DownloadTaskJson payload) =>
      !task.isCompleted &&
      payload.phaseCode != 'cancelling' &&
      payload.phaseCode != downloadTaskDeletionPhase &&
      payload.from.trim().isNotEmpty &&
      payload.comicId.trim().isNotEmpty &&
      payload.chapterKey.isNotEmpty &&
      const {
        '',
        'pending',
        'queued',
        'running',
        'paused',
        'failed',
      }.contains(payload.stateCode);

  bool _ownsRunningAttempt(int taskId, DownloadTaskJson payload) {
    final active = _activeTask;
    return active != null &&
        active.id == taskId &&
        active.key == payload.taskKey &&
        active.attempt == payload.attempt;
  }

  /// Stop and remove precisely the unfinished attempts the user confirmed.
  /// A published chapter retains its own files and offline record.
  Future<ComicTaskDeletionReceipt> stopAndDeleteTasks(
    Iterable<DownloadTask> snapshots,
  ) async {
    final seen = <int>{};
    final requested = <_ComicRetry>[];
    final removed = <int>{}, skipped = <int>{};
    final failures = <int, Object>{};
    final leases = <String, DownloadResourceRemovalLease>{};
    final deleting = <String, List<DownloadTask>>{};
    var holdsBackupGate = false;
    for (final task in snapshots) {
      if (!seen.add(task.id)) continue;
      final payload = _taskRepository.readPayload(task);
      if (payload == null || !_canStopAndDeleteTask(task, payload)) {
        skipped.add(task.id);
      } else {
        requested.add((task: task, payload: payload));
      }
    }

    void recordFailure(List<DownloadTask> group, Object error) {
      objectbox.store.runInTransaction(TxMode.write, () {
        final versions = {
          for (final task in group) task.id: _taskRepository.readPayload(task)!,
        };
        final newest = newestComicTaskIds(
          versions.values.map((payload) => payload.taskKey),
        );
        for (final task in group) {
          if (!matchesComicTaskDeletion(task)) {
            skipped.add(task.id);
            continue;
          }
          final payload = versions[task.id]!;
          _restoreInterruptedTaskDeletion(task, payload);
          if (newest[payload.taskKey] != task.id) {
            skipped.add(task.id);
          } else {
            failures[task.id] = error;
          }
        }
      });
    }

    try {
      if (requested.isNotEmpty) {
        while (_backupTreeHold != null) {
          await _backupTreeHold!.future;
        }
        _requireRecoveredTree();
        _taskDeletionOperations++;
        holdsBackupGate = true;
        for (final (:task, :payload) in requested) {
          final work = buildDownloadTaskKey(payload.from, payload.comicId);
          try {
            leases.putIfAbsent(
              work,
              () => DownloadResourceLifecycle.acquireRemoval(
                DownloadResourceLifecycle.comic(work),
              ),
            );
          } catch (error) {
            failures[task.id] = error;
          }
        }

        // Fence the whole selection before any await can admit a queued item.
        deleting.addAll(
          objectbox.store.runInTransaction(TxMode.write, () {
            final fenced = <String, List<DownloadTask>>{};
            final newest = newestComicTaskIds(
              requested.map((entry) => entry.payload.taskKey),
            );
            for (final (:task, :payload) in requested) {
              if (failures.containsKey(task.id)) continue;
              final current = objectbox.downloadTaskBox.get(task.id);
              final live = current == null
                  ? null
                  : _taskRepository.readPayload(current);
              if (current == null ||
                  live == null ||
                  newest[payload.taskKey] != current.id ||
                  live.taskKey != payload.taskKey ||
                  live.attempt != payload.attempt ||
                  live.from.trim() != payload.from.trim() ||
                  live.comicId.trim() != payload.comicId.trim() ||
                  live.chapterKey != payload.chapterKey ||
                  !_canStopAndDeleteTask(current, live)) {
                skipped.add(task.id);
                continue;
              }
              final paths = {
                ...live.imagePaths,
                if (_ownsRunningAttempt(current.id, live))
                  ...startedDownloadChapterPages(live),
              };
              current
                ..status = t.download.statusCancelling
                ..isDownloading = false
                ..taskInfo = live.copyWith(
                  stateCode: 'paused',
                  phaseCode: downloadTaskDeletionPhase,
                  imagePaths: paths.toList(),
                );
              objectbox.downloadTaskBox.put(current);
              final work = buildDownloadTaskKey(live.from, live.comicId);
              fenced.putIfAbsent(work, () => []).add(current);
            }
            return fenced;
          }),
        );
        for (final work in leases.keys.toList()) {
          if (!deleting.containsKey(work)) leases.remove(work)?.release();
        }

        final workers = <String, Future<void>>{};
        for (final task in deleting.values.expand((group) => group)) {
          final payload = _taskRepository.readPayload(task)!;
          if (!_ownsRunningAttempt(task.id, payload)) continue;
          final stop = _taskStops[payload.taskKey];
          if (stop != null) {
            workers[payload.taskKey] = stop.future;
            _cancelWorkerRetainingFiles(payload.taskKey, payload.from);
          }
        }

        for (final entry in deleting.entries) {
          final group = entry.value;
          try {
            for (final task in group) {
              final key = _taskRepository.readPayload(task)!.taskKey;
              await workers[key];
              await _taskRepository.flushTaskWrites(key);
              await ComicBackgroundDownload.cancelMatching(taskKey: key);
            }
            await removeStoppedComicTasks(group);
            removed.addAll(group.map((task) => task.id));
          } catch (error, stackTrace) {
            logger.w('删除所选下载任务失败', error: error, stackTrace: stackTrace);
            recordFailure(group, error);
          } finally {
            leases.remove(entry.key)?.release();
          }
        }
      }
    } catch (error, stackTrace) {
      logger.w('停止并删除下载任务失败', error: error, stackTrace: stackTrace);
      for (final group in deleting.values) {
        final unresolved = group
            .where(
              (task) =>
                  !removed.contains(task.id) &&
                  !skipped.contains(task.id) &&
                  !failures.containsKey(task.id),
            )
            .toList();
        if (unresolved.isNotEmpty) recordFailure(unresolved, error);
      }
      for (final (:task, payload: _) in requested) {
        if (!removed.contains(task.id) && !skipped.contains(task.id)) {
          failures.putIfAbsent(task.id, () => error);
        }
      }
    } finally {
      for (final lease in leases.values) {
        lease.release();
      }
      if (holdsBackupGate) {
        _taskDeletionOperations--;
        if (_watchSubscription != null) unawaited(_processQueue());
      }
    }
    return ComicTaskDeletionReceipt(
      removed: removed,
      skipped: skipped,
      failures: failures,
    );
  }

  void _restoreInterruptedTaskDeletion(
    DownloadTask task,
    DownloadTaskJson payload,
  ) {
    task
      ..status = t.download.paused
      ..taskInfo = payload.copyWith(phaseCode: 'userPaused');
    objectbox.downloadTaskBox.put(task);
  }

  /// 取消当前正在执行的下载任务
  ///
  /// 如果当前没有运行中的任务，此方法无任何副作用。
  void cancelCurrentTask() {
    final downloadingTasks = _taskRepository
        .getAll(incompleteOnly: true)
        .where((task) => task.isDownloading)
        .toList();
    final downloadingTask = downloadingTasks.isEmpty
        ? null
        : downloadingTasks.first;

    if (downloadingTask != null) {
      logger.i('收到取消请求，正在取消当前任务: ${downloadingTask.comicName}');
      unawaited(_cancelTask(downloadingTask));
      return;
    }

    if (_downloadingTaskKey.isEmpty) {
      return;
    }

    final fallbackTask = _taskRepository.findByTaskKey(
      _downloadingTaskKey,
      incompleteOnly: true,
    );

    if (fallbackTask != null) {
      logger.i('收到取消请求(回退匹配)，正在取消任务: ${fallbackTask.comicName}');
      unawaited(_cancelTask(fallbackTask));
    }
  }

  /// 取消指定章节的下载任务。
  ///
  /// 排队中的任务直接摘除；正在下载的章节走取消信号，worker 清理该章
  /// 独占的散图后结束任务，队列继续下载其他章节。
  Future<void> cancelChapterTask({
    required String from,
    required String comicId,
    required String chapterKey,
  }) async {
    _requireRecoveredTree();
    final taskKey = buildDownloadChapterTaskKey(from, comicId, chapterKey);
    final cancelling = _inactiveCancellationStops[taskKey];
    if (cancelling != null) {
      await cancelling.future;
      return;
    }
    final dbTask = _taskRepository.findByTaskKey(taskKey, incompleteOnly: true);
    if (dbTask == null) return;
    if (_taskRepository.readPayload(dbTask)?.phaseCode ==
        downloadTaskDeletionPhase) {
      return;
    }

    final hold = _backupTreeHold;
    if (hold != null) {
      await hold.future;
      if (objectbox.downloadTaskBox.get(dbTask.id)?.dbTaskInfoStr !=
          dbTask.dbTaskInfoStr) {
        return;
      }
      return cancelChapterTask(
        from: from,
        comicId: comicId,
        chapterKey: chapterKey,
      );
    }

    final stopped = _taskStops[taskKey]?.future;
    if (dbTask.isDownloading) {
      logger.i('收到章节取消请求(下载中)，正在取消任务: ${dbTask.comicName}');
      await _cancelTask(dbTask);
      await stopped;
      return;
    }
    if (stopped != null) {
      // A source pause can have settled the row while its worker still owns
      // the files. Only cancel the same paused row after the worker releases it.
      await stopped;
      if (objectbox.downloadTaskBox.get(dbTask.id)?.dbTaskInfoStr !=
          dbTask.dbTaskInfoStr) {
        return;
      }
      return cancelChapterTask(
        from: from,
        comicId: comicId,
        chapterKey: chapterKey,
      );
    }

    logger.i('收到章节取消请求(排队中): ${dbTask.comicName}');
    dbTask
      ..isCompleted = true
      ..isDownloading = false
      ..status = t.download.statusCancelling
      ..taskInfo = dbTask.taskInfo?.copyWith(
        stateCode: 'cancelled',
        phaseCode: 'cancelling',
      );
    objectbox.downloadTaskBox.put(dbTask);

    await _finishInactiveCancellation(dbTask, taskKey);
  }

  /// A queued or interrupted cancellation owns its paths until cleanup ends.
  Future<void> _finishInactiveCancellation(
    DownloadTask task,
    String taskKey,
  ) async {
    try {
      _requireRecoveredTree();
    } on LocalImportRecoveryFailed {
      return; // The startup recovery will replay this cleanup safely.
    }
    // Also covers recovery's interrupted cancellation cleanup.
    final hold = _backupTreeHold;
    if (hold != null) {
      await hold.future;
      if (objectbox.downloadTaskBox.get(task.id)?.dbTaskInfoStr !=
          task.dbTaskInfoStr) {
        return;
      }
      return _finishInactiveCancellation(task, taskKey);
    }
    final stopped = _inactiveCancellationStops[taskKey];
    if (stopped != null) {
      await stopped.future;
      return;
    }
    final stop = _inactiveCancellationStops[taskKey] = Completer<void>();
    try {
      await _deleteTaskChapterFiles(task);
      await _removeCancelledTaskRecord(
        taskKey,
        taskId: task.id,
        expectedAttempt: task.taskInfo!.attempt,
      );
    } finally {
      _inactiveCancellationStops.remove(taskKey);
      stop.complete();
    }
  }

  /// 删除任务 payload 里已记录的章节散图（取消排队任务时用）。
  Future<void> _deleteTaskChapterFiles(DownloadTask dbTask) async {
    final payload = _taskRepository.readPayload(dbTask);
    if (payload == null) return;
    await ComicBackgroundDownload.cancelMatching(taskKey: payload.taskKey);
    await deleteCancelledChapterPages(
      task: payload,
      taskId: dbTask.id,
      comicId: payload.comicId,
      docPaths: payload.imagePaths,
    );
  }

  Future<void> _cancelTask(DownloadTask dbTask) async {
    final taskKey = downloadTaskKeyOf(dbTask);
    final attempt = _taskRepository.readPayload(dbTask)?.attempt;
    // Settle the cancellation before a network event can requeue this task.
    // A checkpoint transaction can only write to the same running attempt.
    final cancelled = objectbox.store.runInTransaction(TxMode.write, () {
      final current = objectbox.downloadTaskBox.get(dbTask.id);
      final payload = current == null
          ? null
          : _taskRepository.readPayload(current);
      if (current == null ||
          current.isCompleted ||
          !current.isDownloading ||
          payload == null ||
          payload.taskKey != taskKey ||
          payload.attempt != attempt) {
        return null;
      }
      current
        ..status = t.download.statusCancelling
        ..isDownloading = false
        ..isCompleted = true
        ..taskInfo = payload.copyWith(phaseCode: 'cancelling');
      objectbox.downloadTaskBox.put(current);
      return current;
    });
    if (cancelled == null) return;
    triggerDownloadCancelSignal(taskKey);

    final source = cancelled.taskInfo?.from;
    if (source != null && source.isNotEmpty) {
      unawaited(
        cancelTrackedQjsTasks(
          pluginId: source,
          taskGroupKey: taskKey,
        ).catchError((Object error, StackTrace stackTrace) {
          logger.w('取消下载插件任务失败', error: error, stackTrace: stackTrace);
        }),
      );
    }

    _progressController.add(
      DownloadProgress(
        comicName: cancelled.comicName,
        message: t.download.statusCancelling,
      ),
    );
  }

  /// Preserve files and checkpoints until the user explicitly retries.
  /// Disabling the plugin also drops its runtime, which cancels its QJS calls.
  Future<void> stopSourceRetainingFiles(
    String source, {
    bool disabling = false,
  }) async {
    source = normalizePluginId(source);
    final tasks = <int, String>{};
    for (final task in _taskRepository.getAll(incompleteOnly: true)) {
      final payload = _taskRepository.readPayload(task);
      if (payload != null && normalizePluginId(payload.from) == source) {
        tasks[task.id] = payload.taskKey;
      }
    }
    if (!disabling) {
      await Future.wait(tasks.values.map(_taskRepository.flushTaskWrites));
    }

    final waits = <Future<void>>[];
    final paused = _pauseTasksRetainingFiles(
      tasks,
      phase: disabling ? 'pluginDisabled' : 'pluginRemoved',
    );
    for (final key in paused) {
      final stopped = _taskStops[key]?.future;
      if (stopped == null) continue;
      waits.add(stopped);
      triggerDownloadCancelSignal(key, preserveFiles: true);
      if (!disabling) {
        waits.add(cancelTrackedQjsTasks(pluginId: source, taskGroupKey: key));
      }
    }
    await Future.wait(waits).timeout(const Duration(seconds: 20));
    await ComicBackgroundDownload.cancelMatching(source: source);
  }

  List<String> _pauseTasksRetainingFiles(
    Map<int, String> tasks, {
    required String phase,
    Map<int, int>? expectedAttempts,
  }) {
    if (tasks.isEmpty) return const [];
    // The commit worker writes the resource and completed row in one write
    // transaction. Decide which operation wins before changing the task row.
    final paused = objectbox.store.runInTransaction(TxMode.write, () {
      final paused = <String>[];
      final box = objectbox.downloadTaskBox;
      for (final entry in tasks.entries) {
        final task = box.get(entry.key);
        if (task == null || task.isCompleted) continue;
        final payload = _taskRepository.readPayload(task);
        if (payload == null ||
            payload.taskKey != entry.value ||
            payload.phaseCode == downloadTaskDeletionPhase) {
          continue;
        }
        if (expectedAttempts != null &&
            (payload.attempt != expectedAttempts[task.id] ||
                !_canPauseTask(task, payload))) {
          continue;
        }
        final startedPaths = startedDownloadChapterPages(payload);
        task
          ..isDownloading = false
          ..status = t.download.paused
          ..taskInfo = payload.copyWith(
            stateCode: 'paused',
            phaseCode: phase,
            nextRetryAt: null,
            retryRounds: 0,
            imagePaths: startedPaths.isEmpty
                ? payload.imagePaths
                : {...payload.imagePaths, ...startedPaths}.toList(),
            lastErrorCode: '',
            lastErrorMessage: '',
          );
        box.put(task);
        paused.add(payload.taskKey);
      }
      return paused;
    });
    return paused;
  }

  bool _sourceDisabled(String source) =>
      PluginRegistryService.I.getByUuid(source)?.isActive == false;

  /// 队列中剩余任务数
  int get queueLength {
    final query = objectbox.downloadTaskBox
        .query(DownloadTask_.isCompleted.equals(false))
        .build();
    try {
      return query.count();
    } finally {
      query.close();
    }
  }

  List<DownloadTask> _runnableTasks() {
    final disabled = <int, String>{};
    final retryDisabled = <int, String>{};
    final persistentRetry = _persistentRetryEnabled;
    final now = DateTime.now().millisecondsSinceEpoch;
    int? nextRetryAt;
    final runnable =
        _taskRepository.getAll(incompleteOnly: true).where((task) {
          final payload = _taskRepository.readPayload(task);
          final removal = payload == null
              ? null
              : DownloadResourceLifecycle.removing(
                  DownloadResourceLifecycle.comic(
                    buildDownloadTaskKey(payload.from, payload.comicId),
                  ),
                );
          if (removal != null) {
            if (_removalWaits.add(removal)) {
              unawaited(
                removal.released.then((_) {
                  _removalWaits.remove(removal);
                  if (_watchSubscription != null && !_isProcessing) {
                    unawaited(_processQueue());
                  }
                }),
              );
            }
            return false;
          }
          if (payload == null) return true;
          if (pluginSessionWriteFence.isChanging(payload.from)) return false;
          if (payload.stateCode == 'failed' ||
              payload.stateCode == 'paused' ||
              LocalPluginInstallationState.instance.isRemoved(payload.from)) {
            return false;
          }
          if (_sourceDisabled(payload.from)) {
            disabled[task.id] = payload.taskKey;
            return false;
          }
          if (payload.phaseCode == 'waitingRetry') {
            if (!persistentRetry) {
              retryDisabled[task.id] = payload.taskKey;
              return false;
            }
            final at = payload.nextRetryAt;
            if (at != null && at > now) {
              // A clock correction must not strand a saved backoff indefinitely.
              final cap = now + const Duration(minutes: 5).inMilliseconds;
              if (at <= cap) {
                if (nextRetryAt == null || at < nextRetryAt!) nextRetryAt = at;
                return false;
              }
            }
          }
          return true;
        }).toList()..sort(
          (a, b) => compareQueuedTasks(
            a,
            _taskRepository.readPayload(a),
            b,
            _taskRepository.readPayload(b),
          ),
        );
    _pauseTasksRetainingFiles(disabled, phase: 'pluginDisabled');
    _pauseTasksRetainingFiles(retryDisabled, phase: 'retryDisabled');
    _retryTimer?.cancel();
    final retryAt = nextRetryAt;
    _retryTimer =
        retryAt == null || _watchSubscription == null || _admission.queuePaused
        ? null
        : Timer(Duration(milliseconds: retryAt - now), () {
            _retryTimer = null;
            unawaited(_processQueue());
          });
    return runnable;
  }

  void _networkChanged() {
    final wait = _admission.networkWait;
    final key = _downloadingTaskKey;
    if (wait != null && key.isNotEmpty) {
      final current = _taskRepository.findByTaskKey(key, incompleteOnly: true);
      final payload = current == null
          ? null
          : _taskRepository.readPayload(current);
      if (current != null &&
          payload != null &&
          _taskRepository.markNetworkWaiting(
            current,
            wait,
            retainedPagePaths: startedDownloadChapterPages(payload),
          )) {
        _cancelWorkerRetainingFiles(key, payload.from);
      }
    } else if (!_isProcessing) {
      unawaited(_processQueue());
    }
  }

  void _cancelWorkerRetainingFiles(String key, String source) {
    triggerDownloadCancelSignal(key, preserveFiles: true);
    _workerCancellation ??=
        cancelTrackedQjsTasks(pluginId: source, taskGroupKey: key).catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          logger.w('停止下载插件任务失败', error: error, stackTrace: stackTrace);
        });
  }

  /// 检查指定章节的任务是否已存在（未完成的任务）
  bool chapterTaskExists(String from, String comicId, String chapterKey) {
    return _taskRepository.findByChapterKey(
          from: from,
          comicId: comicId,
          chapterKey: chapterKey,
          incompleteOnly: true,
        ) !=
        null;
  }

  /// 统一的队列处理入口
  Future<void> _processQueue() async {
    if (_waitForForeground ||
        _blocksTreeWrites() ||
        _checkingAdmission ||
        _downloadingTaskKey.isNotEmpty) {
      return;
    }
    _checkingAdmission = true;
    try {
      await _admission.start();
      if (!_retiredComicTransfers &&
          defaultTargetPlatform == TargetPlatform.iOS) {
        // Update from older builds with a pending comic URLSession batch.
        // Reclaim raw staging only; committed chapter pages stay on disk.
        await ComicBackgroundDownload.cancelMatching();
        _retiredComicTransfers = true;
      }
    } catch (error, stackTrace) {
      // Do not admit another writer after an unconfirmed native stop.
      logger.w('后台图片任务恢复失败', error: error, stackTrace: stackTrace);
      return;
    } finally {
      _checkingAdmission = false;
    }
    if (_watchSubscription == null) {
      _isProcessing = false;
      return;
    }
    if (_waitForForeground ||
        _blocksTreeWrites() ||
        _downloadingTaskKey.isNotEmpty) {
      return;
    }
    final allPendingTasks = _runnableTasks();
    final pendingTasks = !_startupResumeWaiting
        ? allPendingTasks
        : allPendingTasks
              .where((task) => !_startupResumeTaskIds.contains(task.id))
              .toList();
    logger.d('_processQueue: 发现 ${pendingTasks.length} 个待处理任务');

    if (_admission.networkWait case final wait?) {
      for (final task in pendingTasks) {
        if (_taskRepository.readPayload(task)?.phaseCode == 'waitingRetry')
          continue;
        _taskRepository.markNetworkWaiting(task, wait);
      }
      _isProcessing = false;
      return;
    }

    if (pendingTasks.isEmpty || _admission.queuePaused) {
      if (_startupResumeWaiting && allPendingTasks.isNotEmpty) {
        _isProcessing = false;
        return;
      }
      if (Platform.isMacOS) {
        MacOSActivity.stop();
      }
      _isProcessing = false;
      if (Platform.isAndroid && _retryTimer == null) {
        await ForegroundTaskService.instance.stop();
      }
      return;
    }

    if (Platform.isMacOS) {
      MacOSActivity.start();
    }
    _isProcessing = true;

    final reporter = DownloadNotificationReporter();
    reporter.setOnUpdate((comicName, message) {
      _progressController.add(
        DownloadProgress(comicName: comicName, message: message),
      );
    });
    final next = _nextTask;
    final dbTask = pendingTasks.first;
    final task = _taskRepository.readPayload(dbTask);
    logger.d(
      '_processQueue: 处理任务 id=${dbTask.id}, comicId=${dbTask.comicId}, taskInfo=${task != null}',
    );

    if (task == null) {
      logger.w("任务 ${dbTask.comicName} 无任务信息，跳过");
      dbTask.isCompleted = true;
      objectbox.downloadTaskBox.put(dbTask);
      Future.microtask(() => _processQueue());
      return;
    }

    final taskKey = task.taskKey;
    final workKey = buildDownloadTaskKey(task.from, task.comicId);
    if (_downloadingTaskKey == taskKey) {
      logger.w("重复添加任务 ${task.comicName}");
      _isProcessing = false;
      Future.microtask(() => _processQueue());
      return;
    }

    _checkingAdmission = true;
    final hasSpace = await _admission.hasSpace();
    _checkingAdmission = false;
    final fresh = objectbox.downloadTaskBox.get(dbTask.id);
    if (_watchSubscription == null) {
      _isProcessing = false;
      return;
    }
    if (_waitForForeground || _blocksTreeWrites()) return;
    if (fresh == null ||
        fresh.dbTaskInfoStr != dbTask.dbTaskInfoStr ||
        fresh.isCompleted ||
        DownloadResourceLifecycle.removing(
              DownloadResourceLifecycle.comic(workKey),
            ) !=
            null ||
        _admission.networkWait != null ||
        _admission.queuePaused ||
        next != _nextTask) {
      Future.microtask(_processQueue);
      return;
    }
    if (!hasSpace) {
      _taskRepository.putPayload(
        fresh,
        task.copyWith(
          stateCode: 'failed',
          phaseCode: 'retryWaiting',
          lastErrorCode: 'outOfSpace',
          lastErrorMessage: t.download.notEnoughSpace,
        ),
        status: t.download.notEnoughSpace,
        isDownloading: false,
      );
      Future.microtask(_processQueue);
      return;
    }

    if (_isPrioritized(dbTask, task)) {
      _nextTask = null;
      _priorityChanges.value++;
    }
    final executionAttempt = task.attempt + 1;
    _activeTask = (
      id: dbTask.id,
      key: taskKey,
      attempt: executionAttempt,
      workKey: workKey,
    );
    _taskStops[taskKey] = Completer<void>();
    prepareDownloadCancelSignal(taskKey);

    dbTask.isDownloading = true;
    dbTask.status = t.download.statusStartDownload;
    dbTask.taskInfo = task.copyWith(
      stateCode: 'running',
      phaseCode: 'preparingRuntime',
      nextRetryAt: null,
      attempt: executionAttempt,
      lastErrorCode: '',
      lastErrorMessage: '',
    );
    logger.d("dbTask.status: ${dbTask.status}");
    objectbox.downloadTaskBox.put(dbTask);
    final source = normalizePluginId(task.from);
    await ResourceDownloadNotifications.instance.observeBeforeWork();
    final sessionGeneration = pluginSessionWriteFence.generation(source);
    final displayName = _taskDisplayName(task);
    _progressController.add(
      DownloadProgress(
        comicName: displayName,
        message: t.download.statusStartDownload,
      ),
    );

    try {
      if (isDownloadCancelSignaled(taskKey)) {
        throw const DownloadTaskCancelledException();
      }
      reporter.updateComicName(displayName);
      await unifiedDownloadTask(reporter, dbTask.taskInfo!, taskId: dbTask.id);

      logger.d("任务 $displayName 完成");

      // unifiedDownloadTask 会持续更新 taskInfo。这里必须重新读取实体，
      // 不能把进入队列时保存的旧 dbTask 再写回去，否则可能覆盖掉最新的
      // 进度 / stateCode。先排空后台写，保证读到的是最新提交。
      await _taskRepository.flushTaskWrites(taskKey);
      final completedDbTask = objectbox.downloadTaskBox.get(dbTask.id);
      final completedPayload = completedDbTask == null
          ? null
          : _taskRepository.readPayload(completedDbTask);
      if (completedPayload?.taskKey != taskKey ||
          completedPayload?.attempt != executionAttempt ||
          completedPayload?.stateCode != 'completed') {
        return;
      }
      if (completedDbTask != null) {
        completedDbTask
          ..isCompleted = true
          ..isDownloading = false
          ..taskInfo = completedPayload!.copyWith(
            stateCode: 'completed',
            phaseCode: 'completed',
          );
        objectbox.downloadTaskBox.put(completedDbTask);
      }
      ResourceDownloadNotifications.instance.changed();

      _progressController.add(
        DownloadProgress(
          comicName: displayName,
          message: t.download.notificationCompleteTitle,
          isCompleted: true,
        ),
      );

      // Completion history is retained until the user explicitly clears it.
      logger.d('_processQueue: 任务完成');
    } catch (e, s) {
      final retainingFiles = preserveCancelledDownloadFiles(taskKey);
      if (!retainingFiles &&
          e is ComicDownloadRetryDeferred &&
          !_isTaskCancelledOrMarked(taskKey, e)) {
        await _deferComicRetry(dbTask.id, taskKey, executionAttempt, e);
        return;
      }
      if (retainingFiles) {
        final phase = _taskRepository
            .findByTaskKey(taskKey)
            ?.taskInfo
            ?.phaseCode;
        final wait = DownloadNetworkWait.fromCode(phase);
        _progressController.add(
          DownloadProgress(
            comicName: displayName,
            message:
                wait?.label ??
                (phase == 'waitingForeground'
                    ? t.download.statusWaiting
                    : t.download.paused),
          ),
        );
      } else if (_isTaskCancelledOrMarked(taskKey, e)) {
        logger.i('任务已取消: $displayName');
        await _removeCancelledTaskRecord(
          taskKey,
          taskId: dbTask.id,
          expectedAttempt: executionAttempt,
        );

        _progressController.add(
          DownloadProgress(
            comicName: displayName,
            message: t.download.statusCancelling,
          ),
        );
      } else {
        if (_isTaskGoneOrCompleted(taskKey)) {
          logger.i('任务状态已变更，跳过失败回写: $displayName');
          await _removeCancelledTaskRecord(
            taskKey,
            taskId: dbTask.id,
            expectedAttempt: executionAttempt,
          );
          _progressController.add(
            DownloadProgress(
              comicName: displayName,
              message: t.download.statusCancelling,
            ),
          );
          return;
        }

        logger.e("任务 $displayName 失败", error: e, stackTrace: s);

        await _taskRepository.flushTaskWrites(taskKey);
        final currentDbTask = objectbox.downloadTaskBox.get(dbTask.id);
        if (currentDbTask == null) return;
        final currentPayload = _taskRepository.readPayload(currentDbTask);
        if (currentPayload == null ||
            currentPayload.taskKey != taskKey ||
            currentPayload.attempt != executionAttempt ||
            currentPayload.stateCode != 'running' ||
            currentDbTask.isCompleted ||
            !currentDbTask.isDownloading) {
          return;
        }
        final fileFailure = e is FileSystemException;
        currentDbTask.isDownloading = false;
        currentDbTask.status = t.download.notificationFailedTitle;
        currentDbTask.taskInfo = currentPayload.copyWith(
          stateCode: 'failed',
          phaseCode: 'retryWaiting',
          lastErrorCode: e.runtimeType.toString(),
          lastErrorMessage: fileFailure
              ? t.settings.syncStorageFailed
              : e.toString(),
        );
        objectbox.downloadTaskBox.put(currentDbTask);

        _progressController.add(
          DownloadProgress(
            comicName: displayName,
            message: t.download.notificationFailedTitle,
            isFailed: true,
          ),
        );

        unawaited(
          _reportFailure(
            task: currentDbTask,
            source: source,
            sessionGeneration: sessionGeneration,
            message: t.download.toastDownloadFailed(
              comicName: displayName,
              error: fileFailure
                  ? t.settings.syncStorageFailed
                  : userFacingErrorMessage(e),
            ),
            reporter: reporter,
          ),
        );
      }
    } finally {
      await _workerCancellation;
      _workerCancellation = null;
      clearDownloadCancelSignal(taskKey);
      _activeTask = null;
      _taskStops.remove(taskKey)?.complete();
      if (_waitForForeground) _isProcessing = false;
      Future.microtask(() => _processQueue());
    }
  }

  String _taskDisplayName(DownloadTaskJson task) {
    final chapterTitle = task.chapterRef.title.trim();
    if (chapterTitle.isEmpty) return task.comicName;
    return '${task.comicName} $chapterTitle';
  }

  Future<void> _reportFailure({
    required DownloadTask task,
    required String source,
    required int sessionGeneration,
    required String message,
    required DownloadNotificationReporter reporter,
  }) async {
    bool currentSession() =>
        pluginSessionWriteFence.generation(source) == sessionGeneration &&
        !pluginSessionWriteFence.isChanging(source) &&
        !LocalPluginInstallationState.instance.isRemoved(source);

    bool currentFailure() {
      final latest = objectbox.downloadTaskBox.get(task.id);
      return currentSession() &&
          latest != null &&
          !latest.isCompleted &&
          !latest.isDownloading &&
          latest.dbTaskInfoStr == task.dbTaskInfoStr;
    }

    if (!currentFailure()) return;
    final overlay = navigatorKey.currentState?.overlay;
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
        overlay != null &&
        overlay.mounted) {
      showToastEvent(
        overlay.context,
        ToastEvent(
          type: ToastType.error,
          message: message,
          duration: const Duration(seconds: 5),
          actionLabel: t.common.retry,
          // A batch can fail across many chapters. One visible notice per work
          // is enough while the download center retains every failed chapter.
          deduplicationKey: (
            'comic-download-failure',
            source,
            task.comicId,
            sessionGeneration,
          ),
          onTap: () async {
            if (!currentFailure()) return;
            await _showFailureRetryDialog(
              taskId: task.id,
              source: source,
              message: message,
              currentFailure: currentFailure,
            );
          },
        ),
        overlayState: overlay,
      );
      return;
    }
    try {
      await reporter.sendNotification(
        t.download.notificationFailedTitle,
        message,
      );
    } catch (error, stackTrace) {
      logger.w('发送下载失败通知失败', error: error, stackTrace: stackTrace);
    }
  }

  Future<bool> _showFailureRetryDialog({
    required int taskId,
    required String source,
    required String message,
    required bool Function() currentFailure,
  }) async {
    if (_failureDialogShowing ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return false;
    }

    final navigator = navigatorKey.currentState;
    final context = navigator?.overlay?.context;
    if (navigator == null || context == null) return false;

    _failureDialogShowing = true;
    StreamSubscription<PluginSessionBoundary>? accountChanges;
    try {
      final route = DialogRoute<bool>(
        context: context,
        barrierColor:
            DialogTheme.of(context).barrierColor ??
            Theme.of(context).dialogTheme.barrierColor ??
            Colors.black54,
        traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
        builder: (dialogContext) => AlertDialog(
          title: Text(t.download.notificationFailedTitle),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(t.common.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(t.common.retry),
            ),
          ],
        ),
      );
      accountChanges = pluginSessionWriteFence.changes.listen((change) {
        if (change.source != source) return;
        scheduleMicrotask(() {
          if (route.isActive && !currentFailure()) {
            navigator.removeRoute(route, false);
          }
        });
      });
      final shouldRetry = await navigator.push(route);
      await route.completed;
      if (shouldRetry == true && currentFailure()) {
        await _retryTask(taskId, isCurrent: currentFailure);
      }
      return true;
    } catch (dialogError, stackTrace) {
      logger.w(
        '处理下载失败重试对话框失败: taskId=$taskId',
        error: dialogError,
        stackTrace: stackTrace,
      );
      return false;
    } finally {
      _failureDialogShowing = false;
      await accountChanges?.cancel();
    }
  }

  /// 添加一个单章节下载任务到队列。
  ///
  /// 同一章节已有未完成任务时直接返回；已有失败任务时自动重置为排队。
  /// 任务会被持久化到 ObjectBox，随后 [watchTasks] 的 query watcher 会触发
  /// [_processQueue] 开始执行。
  void addTask(DownloadTaskJson task) {
    final cancelling = _inactiveCancellationStops[task.taskKey];
    if (cancelling != null) {
      unawaited(cancelling.future.then((_) => addTask(task)));
      return;
    }
    final removal = DownloadResourceLifecycle.removing(
      DownloadResourceLifecycle.comic(
        buildDownloadTaskKey(task.from, task.comicId),
      ),
    );
    if (removal != null) {
      // Keep the later user request as a new generation, after old files and
      // bound rows are committed. Do not let its worker enter that directory.
      unawaited(removal.released.then((_) => addTask(task)));
      return;
    }
    final existing = _taskRepository.findByChapterKey(
      from: task.from,
      comicId: task.comicId,
      chapterKey: task.chapterKey,
      incompleteOnly: true,
    );
    if (existing != null) {
      final payload = _taskRepository.readPayload(existing);
      if (payload?.stateCode == 'failed') {
        logger.i('章节任务失败残留，自动重新排队: ${task.taskKey}');
        retryTask(existing.id);
        return;
      }
      logger.w("任务 ${task.comicName} ${task.chapterRef.title} 已存在，跳过添加");
      showInfoToast(
        t.download.toastTaskAlreadyExists(comicName: task.comicName),
      );
      return;
    }

    final previous = _taskRepository.findByTaskKey(task.taskKey);
    final previousPayload = previous == null
        ? null
        : _taskRepository.readPayload(previous);
    final stopping = _taskStops[task.taskKey];
    if (previousPayload?.phaseCode == 'cancelling' && stopping != null) {
      unawaited(stopping.future.then((_) => addTask(task)));
      return;
    }
    if (previous != null &&
        previousPayload?.stateCode == 'cancelled' &&
        _canResumeTask(previous, previousPayload!)) {
      unawaited(retryTask(previous.id));
      return;
    }

    final box = objectbox.downloadTaskBox;
    final downloadTask = DownloadTask()
      ..comicId = task.comicId
      ..comicName = task.comicName
      ..isCompleted = false
      ..isDownloading = false
      ..status = t.download.statusWaiting
      ..taskInfo = task.copyWith(
        queuedAt: DateTime.now().microsecondsSinceEpoch,
      );

    final id = box.put(downloadTask);
    logger.d('addTask: 已添加任务 id=$id, taskKey=${task.taskKey}');
  }

  /// 批量添加单章节任务（多选下载）。逐个走 [addTask] 的判重逻辑。
  void addTasks(List<DownloadTaskJson> tasks) {
    for (final task in tasks) {
      addTask(task);
    }
  }

  /// 手动继续或重试一个章节任务。
  Future<void> retryTask(int taskId) => _retryTask(taskId);

  Future<void> _retryTask(int taskId, {bool Function()? isCurrent}) async {
    final ready = await _prepareRetry(taskId, isCurrent: isCurrent);
    if (ready == null || isCurrent?.call() == false) return;
    _requeuePreparedRetries([ready]);
  }

  Future<_ComicRetry?> _prepareRetry(
    int taskId, {
    bool Function()? isCurrent,
  }) async {
    if (isCurrent?.call() == false) return null;
    final task = objectbox.downloadTaskBox.get(taskId);
    if (task == null) return null;
    final payload = _taskRepository.readPayload(task);
    if (payload == null || !_canResumeTask(task, payload)) return null;
    final identity = DownloadResourceLifecycle.comic(
      buildDownloadTaskKey(payload.from, payload.comicId),
    );
    final removal = DownloadResourceLifecycle.removing(identity);
    if (removal != null) {
      await removal.released;
      return _prepareRetry(taskId, isCurrent: isCurrent);
    }
    if (LocalPluginInstallationState.instance.isRemoved(payload.from)) {
      throw StateError('Plugin is not installed on this device');
    }
    if (_sourceDisabled(payload.from)) {
      throw DownloadSourceDisabled();
    }
    final stopped = _taskStops[payload.taskKey]?.future;
    if (stopped != null) {
      await stopped;
      return _prepareRetry(taskId, isCurrent: isCurrent);
    }
    // 先排空在途写，防止旧 checkpoint 覆盖重置后的排队态。
    await _taskRepository.flushTaskWrites(payload.taskKey);
    if (isCurrent?.call() == false) return null;
    // A removal may have acquired its lease while the checkpoint write drained.
    final afterFlushRemoval = DownloadResourceLifecycle.removing(identity);
    if (afterFlushRemoval != null) {
      await afterFlushRemoval.released;
      return _prepareRetry(taskId, isCurrent: isCurrent);
    }
    final latest = objectbox.downloadTaskBox.get(taskId);
    if (latest == null) return null;
    if (latest.dbTaskInfoStr != task.dbTaskInfoStr ||
        latest.isDownloading != task.isDownloading ||
        latest.isCompleted != task.isCompleted) {
      return _prepareRetry(taskId, isCurrent: isCurrent);
    }
    return (task: latest, payload: payload);
  }

  List<DownloadTaskJson> _requeuePreparedRetries(Iterable<_ComicRetry> ready) {
    if (ready.isEmpty) return const [];
    // Revalidate every row at submission. Register completion notices for
    // the whole accepted selection before the query watcher can start it.
    final queued = objectbox.store.runInTransaction(TxMode.write, () {
      final queued = <_ComicRetry>[];
      for (final (:task, :payload) in ready) {
        final current = objectbox.downloadTaskBox.get(task.id);
        final resource = DownloadResourceLifecycle.comic(
          buildDownloadTaskKey(payload.from, payload.comicId),
        );
        if (current == null ||
            current.dbTaskInfoStr != task.dbTaskInfoStr ||
            current.isDownloading != task.isDownloading ||
            current.isCompleted != task.isCompleted ||
            _taskStops.containsKey(payload.taskKey) ||
            DownloadResourceLifecycle.removing(resource) != null) {
          continue;
        }
        if (LocalPluginInstallationState.instance.isRemoved(payload.from)) {
          throw StateError('Plugin is not installed on this device');
        }
        if (_sourceDisabled(payload.from)) throw DownloadSourceDisabled();

        final cancelled = payload.stateCode == 'cancelled';
        if (_taskRepository.findByTaskKey(payload.taskKey)?.id != task.id ||
            cancelled &&
                _taskRepository.findDownloadedChapter(
                      from: payload.from,
                      comicId: payload.comicId,
                      chapterKey: payload.chapterKey,
                    ) !=
                    null) {
          continue;
        }
        final preserveCheckpoint =
            payload.stateCode == 'paused' ||
            payload.phaseCode == 'waitingRetry';
        _taskRepository.putPayload(
          current,
          payload.copyWith(
            stateCode: 'queued',
            phaseCode: 'retry',
            queuedAt: DateTime.now().microsecondsSinceEpoch,
            nextRetryAt: null,
            retryRounds: 0,
            completedImages: preserveCheckpoint ? payload.completedImages : 0,
            reusedImages: preserveCheckpoint ? payload.reusedImages : 0,
            totalImages: preserveCheckpoint ? payload.totalImages : 0,
            imagePaths: cancelled ? const [] : payload.imagePaths,
            lastErrorCode: '',
            lastErrorMessage: '',
          ),
          status: t.download.statusWaiting,
          isDownloading: false,
          isCompleted: false,
        );
        queued.add((task: current, payload: payload));
      }
      return queued;
    });
    for (final (:task, :payload) in queued) {
      // A deliberate retry should run now even though it reuses a startup row.
      _startupResumeTaskIds.remove(task.id);
      logger.i('已重新排队下载任务: taskId=${task.id}, taskKey=${payload.taskKey}');
    }
    return queued.map((retry) => retry.payload).toList();
  }

  /// 重置异常退出时遗留的“下载中”状态。
  ///
  /// 应用启动后、开始监听任务队列前调用一次，避免上次崩溃/杀进程后留下的
  /// `isDownloading == true` 任务永远无法被调度。
  void resetStuckTasks() {
    // Navigation can be recreated while the process still owns a live worker.
    if (_watchSubscription != null ||
        _isProcessing ||
        _taskDeletionOperations != 0) {
      return;
    }
    _taskRepository.removeLegacyDeletedTasks();
    _taskRepository.removeSupersededCancelledRecords();
    _taskRepository.resetInterruptedTasks();
    objectbox.store.runInTransaction(TxMode.write, () {
      for (final task in _taskRepository.getAll(incompleteOnly: true)) {
        final payload = _taskRepository.readPayload(task);
        if (payload?.phaseCode == downloadTaskDeletionPhase) {
          _restoreInterruptedTaskDeletion(task, payload!);
        }
      }
    });
    for (final task in _taskRepository.getAll()) {
      if (!task.isCompleted ||
          task.dbTaskInfoStr?.contains('cancelling') != true) {
        continue;
      }
      final payload = _taskRepository.readPayload(task);
      if (payload == null ||
          payload.phaseCode != 'cancelling' ||
          _taskStops.containsKey(payload.taskKey)) {
        continue;
      }
      final newest = _taskRepository.findByTaskKey(payload.taskKey);
      if (newest != null && newest.id > task.id) {
        // A pre-existing newer request owns the same paths.
        _markCancellationFinished(task);
      } else {
        unawaited(_finishInactiveCancellation(task, payload.taskKey));
      }
    }
  }

  void watchTasks({Duration startupResumeDelay = Duration.zero}) {
    if (_watchSubscription != null) return;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _queueLifecycle = AppLifecycleListener(
        onHide: _deferActiveChapterUntilForeground,
        onPause: _deferActiveChapterUntilForeground,
        onResume: () => unawaited(_processQueue()),
      );
    }
    final noticeBaseline = ResourceDownloadNotifications.instance
        .startObserving();

    final startupQuery = objectbox.downloadTaskBox
        .query(
          DownloadTask_.isCompleted
              .equals(false)
              .and(DownloadTask_.isDownloading.equals(false)),
        )
        .build();
    late final List<DownloadTask> startupTasks;
    try {
      startupTasks = startupQuery.find();
    } finally {
      startupQuery.close();
    }

    final watchedQuery = objectbox.downloadTaskBox
        .query(
          DownloadTask_.isCompleted
              .equals(false)
              .and(DownloadTask_.isDownloading.equals(false)),
        )
        .watch(triggerImmediately: startupResumeDelay == Duration.zero);

    _startupResumeTaskIds
      ..clear()
      ..addAll(startupTasks.map((task) => task.id));
    _startupResumeWaiting = startupResumeDelay > Duration.zero;
    if (_startupResumeWaiting) {
      logger.i(
        '应用启动后延迟 ${startupResumeDelay.inSeconds} 秒恢复下载，'
        '待恢复任务数=${_startupResumeTaskIds.length}',
      );
      _startupResumeTimer = Timer(startupResumeDelay, () {
        _startupResumeWaiting = false;
        _startupResumeTaskIds.clear();
        _startupResumeTimer = null;
        logger.i('应用启动下载恢复延迟结束，开始处理下载队列');
        if (!_isProcessing) {
          _processQueue();
        }
      });
    }

    _watchSubscription = watchedQuery.listen((query) {
      final pendingTasks = query.find();
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          !_retiredComicTransfers) {
        unawaited(noticeBaseline.then((_) => _processQueue()));
        return;
      }
      if (pendingTasks.isNotEmpty && !_isProcessing) {
        final hasNewTaskDuringStartupDelay =
            _startupResumeWaiting &&
            pendingTasks.any(
              (task) => !_startupResumeTaskIds.contains(task.id),
            );
        if (!_startupResumeWaiting || hasNewTaskDuringStartupDelay) {
          unawaited(noticeBaseline.then((_) => _processQueue()));
        }
      }
    });
    _admission.addListener(_networkChanged);
    _retryPreferenceSubscription = objectbox.userSettingBox
        .query()
        .watch()
        .listen((_) => _retryPreferenceChanged());
    _sessionSubscription = pluginSessionWriteFence.changes.listen((change) {
      if (change.changing) {
        final waiting = <int, String>{};
        for (final row in _taskRepository.getAll(incompleteOnly: true)) {
          final payload = _taskRepository.readPayload(row);
          if (payload?.from == change.source &&
              payload?.phaseCode == 'waitingRetry') {
            waiting[row.id] = payload!.taskKey;
          }
        }
        _pauseTasksRetainingFiles(waiting, phase: 'sessionChanged');
      }
      final active = _activeTask;
      final row = active == null
          ? null
          : objectbox.downloadTaskBox.get(active.id);
      final payload = row == null ? null : _taskRepository.readPayload(row);
      if (active != null &&
          payload?.from == change.source &&
          _pauseTasksRetainingFiles(
            {active.id: active.key},
            phase: 'sessionChanged',
            expectedAttempts: {active.id: active.attempt},
          ).contains(active.key)) {
        // Use the same transaction and file-retention boundary as a manual
        // pause. A late decoded page cannot publish under a different account.
        _cancelWorkerRetainingFiles(active.key, change.source);
      } else if (!change.changing && _watchSubscription != null) {
        unawaited(_processQueue());
      }
    });
  }

  void stopWatchingTasks() {
    ResourceDownloadNotifications.instance.stopObserving();
    _queueLifecycle?.dispose();
    _queueLifecycle = null;
    _sessionSubscription?.cancel();
    _sessionSubscription = null;
    _retryPreferenceSubscription?.cancel();
    _retryPreferenceSubscription = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _admission.removeListener(_networkChanged);
    _watchSubscription?.cancel();
    _watchSubscription = null;
    _clearStartupResumeDelay();
  }

  void _clearStartupResumeDelay() {
    _startupResumeTimer?.cancel();
    _startupResumeTimer = null;
    _startupResumeWaiting = false;
    _startupResumeTaskIds.clear();
  }

  void dispose() {
    _progressController.close();
    stopWatchingTasks();
  }

  Future<void> _removeCancelledTaskRecord(
    String taskKey, {
    required int taskId,
    required int expectedAttempt,
  }) async {
    // 先排空在途写，再结算取消态，防止旧写恢复已取消的任务。
    await _taskRepository.flushTaskWrites(taskKey);
    bool canFinish(DownloadTask task) {
      final payload = _taskRepository.readPayload(task);
      return payload != null &&
          payload.taskKey == taskKey &&
          payload.attempt == expectedAttempt &&
          (payload.phaseCode == 'cancelling' ||
              !task.isCompleted &&
                  task.isDownloading &&
                  payload.stateCode == 'running');
    }

    final task = objectbox.downloadTaskBox.get(taskId);
    if (preserveCancelledDownloadFiles(taskKey) ||
        task == null ||
        !canFinish(task)) {
      return;
    }
    final newest = _taskRepository.findByTaskKey(taskKey);
    if (newest != null && newest.id > taskId) {
      _markCancellationFinished(task);
      return;
    }
    try {
      await cleanupDownloadTaskTemporaryFiles(taskKey);
      logger.i('已清理取消任务的临时文件: $taskKey');
    } catch (e, s) {
      logger.w('清理取消任务临时文件失败: taskKey=$taskKey', error: e, stackTrace: s);
    }
    final latest = objectbox.downloadTaskBox.get(taskId);
    if (latest == null || !canFinish(latest)) return;
    _markCancellationFinished(latest);
  }

  void _markCancellationFinished(DownloadTask task) {
    task
      ..isCompleted = true
      ..isDownloading = false
      ..status = t.download.cancelled
      ..taskInfo = task.taskInfo?.copyWith(
        stateCode: 'cancelled',
        phaseCode: 'cancelled',
      );
    objectbox.downloadTaskBox.put(task);
    ResourceDownloadNotifications.instance.changed();
    final key = task.taskInfo?.taskKey;
    if (key != null) {
      final newest = _taskRepository.findByTaskKey(key);
      if (newest != null && newest.id > task.id) {
        _taskRepository.removeSupersededCancelledRecords(
          beforeIds: {key: newest.id},
        );
      }
    }
  }
}

bool _isTaskCancelledError(Object error) {
  return error.toString().contains(downloadTaskCancelledMessage);
}

bool _isTaskCancelledOrMarked(String taskKey, Object error) {
  if (_isTaskCancelledError(error) ||
      error.toString().contains(_kQjsRuntimeCancelledMessage)) {
    return true;
  }

  final task = const DownloadTaskRepository().findByTaskKey(taskKey);

  if (task == null) {
    return true;
  }

  final status = task.status;
  final isMarkedCancelled =
      task.isCompleted && !task.isDownloading && status.contains('取消') ||
      status.toLowerCase().contains('cancel');

  return isMarkedCancelled;
}

bool _isTaskGoneOrCompleted(String taskKey) {
  final task = const DownloadTaskRepository().findByTaskKey(taskKey);

  if (task == null) {
    return true;
  }

  return task.isCompleted || !task.isDownloading;
}

/// 启动一个单章节下载任务。
///
/// 所有平台都会把任务写入数据库，由 [DownloadQueueManager] 统一调度。
/// Android 端会确保前台服务在跑（若保活已开启则复用），前台服务本身不管理下载逻辑。
Future<void> startDownloadTask(DownloadTaskJson task) async {
  logger.d(
    'startDownloadTask: comicId=${task.comicId}, chapter=${task.chapterKey}',
  );

  DownloadQueueManager.instance.addTask(task);

  if (Platform.isAndroid) {
    await ForegroundTaskService.instance.start();
  }
}

/// 批量启动单章节下载任务（多选下载）。
Future<void> startDownloadTasks(List<DownloadTaskJson> tasks) async {
  for (final task in tasks) {
    logger.d(
      'startDownloadTasks: comicId=${task.comicId}, chapter=${task.chapterKey}',
    );
  }

  DownloadQueueManager.instance.addTasks(tasks);

  if (tasks.isNotEmpty && Platform.isAndroid) {
    await ForegroundTaskService.instance.start();
  }
}
