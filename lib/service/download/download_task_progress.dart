import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';

/// 将“已完成数量”转换为用户看到的“当前第几个”。
///
/// 下载逻辑内部保存的是已完成数量，因此从 0 开始；展示当前正在处理的
/// 章节或图片时，需要从 1 开始。全部完成后固定显示总数，避免出现 total + 1。
int downloadTaskDisplayPosition({
  required int completed,
  required int total,
}) {
  if (total <= 0) return 0;

  final safeCompleted = completed.clamp(0, total).toInt();
  return safeCompleted >= total ? total : safeCompleted + 1;
}

double? downloadTaskProgressFraction({
  required int completedChapters,
  required int totalChapters,
  required int currentChapterCompletedImages,
  required int currentChapterTotalImages,
}) {
  if (totalChapters <= 0) return null;

  final completed = completedChapters.clamp(0, totalChapters).toInt();
  final currentProgress = currentChapterTotalImages <= 0
      ? 0.0
      : currentChapterCompletedImages
                .clamp(0, currentChapterTotalImages)
                .toDouble() /
            currentChapterTotalImages;

  return ((completed + currentProgress) / totalChapters)
      .clamp(0.0, 1.0)
      .toDouble();
}

double? downloadTaskPayloadProgressFraction(DownloadTaskJson payload) {
  return downloadTaskProgressFraction(
    completedChapters: payload.completedChapterCount,
    totalChapters: payload.totalChapterCount,
    currentChapterCompletedImages: payload.currentChapterCompletedImages,
    currentChapterTotalImages: payload.currentChapterTotalImages,
  );
}

String downloadTaskProgressMessage({
  required int completedChapters,
  required int totalChapters,
  required int currentChapterCompletedImages,
  required int currentChapterTotalImages,
}) {
  if (totalChapters <= 0) return '';

  final chapterPosition = downloadTaskDisplayPosition(
    completed: completedChapters,
    total: totalChapters,
  );

  if (currentChapterTotalImages > 0) {
    final imagePosition = downloadTaskDisplayPosition(
      completed: currentChapterCompletedImages,
      total: currentChapterTotalImages,
    );
    return t.download.statusComicProgress(
      completedChapters: chapterPosition,
      totalChapters: totalChapters,
      currentChapterCompletedImages: imagePosition,
      currentChapterTotalImages: currentChapterTotalImages,
    );
  }

  return t.download.statusComicProgressChaptersOnly(
    completedChapters: chapterPosition,
    totalChapters: totalChapters,
  );
}

String downloadTaskPayloadProgressMessage(DownloadTaskJson payload) {
  return downloadTaskProgressMessage(
    completedChapters: payload.completedChapterCount,
    totalChapters: payload.totalChapterCount,
    currentChapterCompletedImages: payload.currentChapterCompletedImages,
    currentChapterTotalImages: payload.currentChapterTotalImages,
  );
}
