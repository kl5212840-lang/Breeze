import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';

/// Called inside the same DB transaction as resource commit. Cancellation,
/// replacement and commit therefore have a single ordering, without a timer.
bool downloadTaskMayCommit(
  DownloadTask? task, {
  required String taskKey,
  required int attempt,
}) {
  if (task == null || task.isCompleted || !task.isDownloading) return false;
  DownloadTaskJson? payload;
  try {
    payload = task.taskInfo;
  } catch (_) {
    return false;
  }
  return payload != null &&
      payload.taskKey == taskKey &&
      payload.attempt == attempt &&
      payload.stateCode == 'running' &&
      payload.phaseCode != 'cancelling';
}
