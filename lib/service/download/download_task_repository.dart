import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';

/// DownloadTask 的唯一读写入口。
///
/// ObjectBox 实体暂时保持兼容，任务 payload 和检查点都存放在
/// [DownloadTask.dbTaskInfoStr] 对应的版本化 JSON 中。这样旧任务仍可读取，
/// 新任务可以在进程退出后恢复章节级进度。
class DownloadTaskRepository {
  const DownloadTaskRepository();

  List<DownloadTask> getAll({bool incompleteOnly = false}) {
    final tasks = objectbox.downloadTaskBox.getAll();
    if (!incompleteOnly) return tasks;
    return tasks.where((task) => !task.isCompleted).toList();
  }

  DownloadTask? findByTaskKey(String taskKey, {bool incompleteOnly = false}) {
    final normalizedKey = taskKey.trim();
    if (normalizedKey.isEmpty) return null;
    for (final task in getAll(incompleteOnly: incompleteOnly)) {
      if (_taskKeyOf(task) == normalizedKey) return task;
    }
    return null;
  }

  DownloadTask? findByPayload({
    required String from,
    required String comicId,
    bool incompleteOnly = false,
  }) {
    return findByTaskKey(
      buildDownloadTaskKey(from, comicId),
      incompleteOnly: incompleteOnly,
    );
  }

  DownloadTaskJson? readPayload(DownloadTask task) {
    try {
      return task.taskInfo;
    } catch (error, stackTrace) {
      logger.e(
        '读取下载任务 payload 失败: taskId=${task.id}',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  int putPayload(
    DownloadTask task,
    DownloadTaskJson payload, {
    String? status,
    bool? isDownloading,
    bool? isCompleted,
  }) {
    task
      ..taskInfo = payload
      ..comicId = payload.comicId
      ..comicName = payload.comicName;
    if (status != null) task.status = status;
    if (isDownloading != null) task.isDownloading = isDownloading;
    if (isCompleted != null) task.isCompleted = isCompleted;
    return objectbox.downloadTaskBox.put(task);
  }

  int putState(
    DownloadTask task, {
    DownloadTaskJson? payload,
    String? status,
    bool? isDownloading,
    bool? isCompleted,
  }) {
    if (payload != null) {
      task
        ..taskInfo = payload
        ..comicId = payload.comicId
        ..comicName = payload.comicName;
    }
    if (status != null) task.status = status;
    if (isDownloading != null) task.isDownloading = isDownloading;
    if (isCompleted != null) task.isCompleted = isCompleted;
    return objectbox.downloadTaskBox.put(task);
  }

  void resetInterruptedTasks() {
    final interrupted = getAll(
      incompleteOnly: true,
    ).where((task) => task.isDownloading).toList();
    if (interrupted.isEmpty) return;

    for (final task in interrupted) {
      final payload = readPayload(task);
      task.isDownloading = false;
      if (payload != null) {
        task.taskInfo = payload.copyWith(
          stateCode: 'queued',
          phaseCode: 'resume',
          lastErrorCode: '',
          lastErrorMessage: '',
        );
      }
    }
    objectbox.downloadTaskBox.putMany(interrupted);
    logger.i('重置了 ${interrupted.length} 个中断的下载任务');
  }

  String _taskKeyOf(DownloadTask task) {
    final payload = readPayload(task);
    if (payload != null) return payload.taskKey;
    return task.comicId.trim();
  }
}

String downloadTaskKeyOf(DownloadTask task) {
  try {
    final payload = task.taskInfo;
    if (payload != null) return payload.taskKey;
  } catch (_) {
    // 旧任务 payload 损坏时仍使用实体中的 comicId 作为最后回退。
  }
  return task.comicId.trim();
}
