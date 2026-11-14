import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';

/// 单章节任务的图片下载进度（0.0 ~ 1.0）。
///
/// 总数未知时返回 null，调用方回退显示任务 status 文字。
double? downloadTaskProgressFraction({
  required int completedImages,
  required int totalImages,
}) {
  if (totalImages <= 0) return null;
  return (completedImages.clamp(0, totalImages).toDouble() / totalImages)
      .clamp(0.0, 1.0)
      .toDouble();
}

double? downloadTaskPayloadProgressFraction(DownloadTaskJson payload) {
  return downloadTaskProgressFraction(
    completedImages: payload.completedImages,
    totalImages: payload.totalImages,
  );
}

/// 单章节任务的进度文案：只有拿到章节图片总数后才有，否则返回空字符串
/// 让调用方显示任务 status。
String downloadTaskProgressMessage({
  required int completedImages,
  required int totalImages,
}) {
  if (totalImages <= 0) return '';
  final percent = (completedImages.clamp(0, totalImages) / totalImages * 100)
      .floor();
  return t.download.statusDownloadProgress(percent: percent);
}

String downloadTaskPayloadProgressMessage(DownloadTaskJson payload) {
  return downloadTaskProgressMessage(
    completedImages: payload.completedImages,
    totalImages: payload.totalImages,
  );
}

/// Equal chapter weight keeps a long chapter from hiding queued chapters. A
/// queued chapter is known zero; an active chapter without a page count keeps
/// the work total indeterminate. Chapter identity is logical/request based.
double? downloadWorkProgressFraction(
  Iterable<DownloadTaskJson> tasks, {
  Iterable<String> storedChapterKeys = const [],
}) {
  final values = <String, DownloadTaskJson>{
    for (final task in tasks) task.chapterKey: task,
  };
  final stored = storedChapterKeys.where((key) => key.isNotEmpty).toSet();
  for (final task in values.values) {
    stored.removeAll([
      task.chapterKey,
      task.chapterRef.chapterId,
      task.chapterRef.logicalKey,
      task.chapterRef.requestId,
    ]);
  }
  final count = stored.length + values.length;
  if (count == 0) return null;
  var completed = stored.length.toDouble();
  for (final task in values.values) {
    if (task.stateCode == 'completed') {
      completed += 1;
      continue;
    }
    final progress = downloadTaskPayloadProgressFraction(task);
    if (progress == null &&
        !const {'queued', 'cancelled'}.contains(task.stateCode))
      return null;
    completed += progress ?? 0;
  }
  return (completed / count).clamp(0.0, 1.0).toDouble();
}
