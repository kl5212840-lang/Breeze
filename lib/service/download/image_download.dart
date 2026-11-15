import 'dart:io';
import 'dart:math';

import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/http/picture/picture.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/service/download/download_cancel_signal.dart';
import 'package:zephyr/service/download/download_progress_reporter.dart';
import 'package:zephyr/service/download/download_retry.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/get_path.dart';

class DownloadImageJob {
  const DownloadImageJob({
    required this.url,
    required this.path,
    required this.cartoonId,
    required this.chapterId,
    this.storageChapterId = '',
    this.extern = const <String, dynamic>{},
  });

  final String url;
  final String path;
  final String cartoonId;
  final String chapterId;
  final String storageChapterId;
  final Map<String, dynamic> extern;
}

class DownloadImageJobException implements Exception {
  const DownloadImageJobException({
    required this.job,
    required this.result,
    this.routed = false,
  });

  final DownloadImageJob job;
  final DownloadPictureResult result;
  final bool routed;

  int? get httpStatus => switch (result.error) {
    DownloadPictureHttpException(:final statusCode) => statusCode,
    DownloadPictureNotFoundException(
      cause: DownloadPictureHttpException(:final statusCode),
    ) =>
      statusCode,
    _ => null,
  };

  ComicDownloadRetryReason? get retryReason {
    final cause = result.error;
    if (routed && result.status == DownloadPictureResultStatus.emptyData) {
      return ComicDownloadRetryReason.network;
    }
    if (cause == null ||
        result.status == DownloadPictureResultStatus.notFound ||
        isNonRetryableDownloadFailure(cause)) {
      return null;
    }
    if (httpStatus case final status? when status >= 400) {
      return comicDownloadHttpRetryReason(status);
    }
    if (cause is DownloadPictureInvalidPayload && cause.incomplete) {
      return ComicDownloadRetryReason.network;
    }
    if (cause is DownloadPictureHttpException) {
      // The plugin can report a successful response with no image as an error
      // before the host gets a byte buffer to validate.
      if (routed &&
          RegExp(r'^(?:Error: )?图片数据为空[。.]?$').hasMatch(cause.message.trim())) {
        return ComicDownloadRetryReason.network;
      }
      return comicDownloadRetryReason(cause.message);
    }
    return comicDownloadRetryReason(cause);
  }

  @override
  String toString() {
    final processedError = result.error?.toString().trim() ?? 'null';
    final rawError = _formatRawDownloadError(result.error);
    final rawStackTrace = result.errorStackTrace?.toString().trim();
    final stackSuffix = rawStackTrace == null || rawStackTrace.isEmpty
        ? ''
        : '\nrawStackTrace:\n$rawStackTrace';
    return '图片下载失败 path=${job.path} url=${job.url} '
        'status=${result.status.name}\n'
        'processedError=$processedError\n'
        'rawError=$rawError$stackSuffix';
  }
}

String _formatRawDownloadError(Object? error) {
  if (error == null) return 'null';

  final buffer = StringBuffer('${error.runtimeType}: $error');
  if (error is DownloadPictureNotFoundException) {
    final cause = error.cause;
    if (cause != null) {
      buffer.write('\nrawCause=${cause.runtimeType}: $cause');
    }
  }
  return buffer.toString();
}

class DownloadImageJobsResult {
  const DownloadImageJobsResult({
    required this.completed,
    required this.downloaded,
    required this.reused,
    required this.skipped,
  });

  final int completed;
  final int downloaded;
  final int reused;

  /// 被标记为缺页的图片数（不计入失败，不阻塞完成）。
  final int skipped;
}

Future<String> downloadCoverAsset({
  required String from,
  required String url,
  required String path,
  required String cartoonId,
  required String qjsName,
  required String qjsTaskGroupKey,
  bool Function()? shouldRetryUntilSuccess,
  bool retry = true,
}) async {
  final result = await downloadPictureResult(
    from: from,
    url: url,
    path: path,
    cartoonId: cartoonId,
    pictureType: PictureType.cover,
    retry: retry,
    requestTimeoutMs: retry ? 30000 : 8000,
    shouldRetryUntilSuccess: shouldRetryUntilSuccess,
    qjsName: qjsName,
    qjsTaskGroupKey: qjsTaskGroupKey,
  );
  _throwLocalFileFailure(result);
  return result.isSuccess ? result.path : '404';
}

void _throwLocalFileFailure(DownloadPictureResult result) {
  final error = result.error;
  if (error is FileSystemException) {
    Error.throwWithStackTrace(
      error,
      result.errorStackTrace ?? StackTrace.current,
    );
  }
}

/// Older plugins can omit this capability. The user preference is still a cap.
Future<int> resolveComicDownloadConcurrency({
  required int requested,
  required String pluginId,
  required String runtimeName,
  required String taskGroupKey,
}) async {
  if (requested == 1) return 1;
  try {
    final result = await callUnifiedComicPlugin(
      pluginId: pluginId,
      runtimeName: runtimeName,
      fnPath: 'getDownloadConcurrency',
      core: const {},
      taskGroupKey: taskGroupKey,
      notifyUnauthorized: false,
    );
    final nested = result['data'];
    // Legacy concurrency/value fields were defaults. Only an explicit maximum
    // restricts a user's chosen limit.
    final raw =
        result['maxConcurrency'] ??
        (nested is Map ? nested['maxConcurrency'] : null);
    final limit = int.tryParse(raw?.toString().trim() ?? '');
    if (limit != null && limit >= 1) return min(limit, requested);
  } catch (_) {
    // The optional capability must not prevent image downloads.
  }
  return requested;
}

Future<DownloadImageJobsResult> downloadImageJobs({
  required String from,
  required List<DownloadImageJob> jobs,
  int? concurrency,
  required String qjsRuntimeName,
  required String qjsTaskGroupKey,
  required Future<void> Function() ensureTaskRunning,
  bool Function()? shouldRetryUntilSuccess,
  Future<void> Function()? waitForForeground,
  bool isolatedPages = false,
  bool stopOnMissingPage = false,
  required DownloadProgressReporter reporter,
  Future<void> Function(Object error, DownloadImageJob job)? onError,
  void Function(DownloadImageJob job)? onJobStarted,
  Future<void> Function(
    int completed,
    int downloaded,
    int reused,
    DownloadImageJob completedJob,
    bool jobSkipped,
  )?
  onProgress,
}) async {
  void updateProgress(String message) {
    reporter.updateMessage(message);
  }

  if (jobs.isEmpty) {
    if (onProgress == null) {
      updateProgress(t.download.statusDownloadProgressComplete);
    }
    return const DownloadImageJobsResult(
      completed: 0,
      downloaded: 0,
      reused: 0,
      skipped: 0,
    );
  }

  await ensureTaskRunning();
  final downloadRoot = await getDownloadPath();
  final workerCount = min(concurrency ?? 5, jobs.length);
  var progress = 0;
  var downloaded = 0;
  var reused = 0;
  var skipped = 0;
  var lastReportedPercent = 0;
  var nextIndex = 0;
  Object? firstError;
  StackTrace? firstErrorStackTrace;

  Future<void> ensureWorkerRunning() async {
    // A sibling may already be inside continuous retry when the first job
    // fails. Stop starting new attempts before waiting for all workers.
    if (firstError case final error?) {
      Error.throwWithStackTrace(error, firstErrorStackTrace!);
    }
    await ensureTaskRunning();
  }

  Future<void> runWorker() async {
    try {
      while (firstError == null) {
        await ensureTaskRunning();
        // Each worker holds at most one page. This claim runs synchronously
        // on the same isolate, so no separate pool is needed.
        if (firstError != null || nextIndex >= jobs.length) return;
        final currentJob = jobs[nextIndex++];
        onJobStarted?.call(currentJob);
        var jobSkipped = false;
        try {
          final result = await _downloadSingleJob(
            from: from,
            job: currentJob,
            qjsRuntimeName: qjsRuntimeName,
            qjsTaskGroupKey: qjsTaskGroupKey,
            ensureTaskRunning: ensureWorkerRunning,
            waitForForeground: waitForForeground,
            shouldRetryUntilSuccess: shouldRetryUntilSuccess,
            isolatedPage: isolatedPages,
            onError: onError,
            pictureType: PictureType.page,
            downloadRoot: downloadRoot,
          );
          progress++;
          if (result.status == DownloadPictureResultStatus.existing) {
            reused++;
          } else {
            downloaded++;
          }
        } on DownloadImageJobException catch (e) {
          if (isolatedPages ||
              stopOnMissingPage ||
              e.result.status != DownloadPictureResultStatus.notFound) {
            rethrow;
          }
          progress++;
          skipped++;
          jobSkipped = true;
        }
        if (onProgress != null) {
          await onProgress(
            progress,
            downloaded,
            reused,
            currentJob,
            jobSkipped,
          );
        }
        final currentPercent = (progress / jobs.length * 100).floor();
        if (onProgress == null && currentPercent > lastReportedPercent) {
          lastReportedPercent = currentPercent;
          updateProgress(
            t.download.statusDownloadProgress(percent: currentPercent),
          );
        }
        await ensureTaskRunning();
      }
    } catch (error, stackTrace) {
      final previous = firstError;
      // A sibling already in flight can prove a terminal failure after the
      // first transient failure. Stop the chapter instead of changing route.
      if (previous == null ||
          (previous is DownloadImageJobException &&
              previous.retryReason != null &&
              !(error is DownloadImageJobException &&
                  error.retryReason != null))) {
        firstError = error;
        firstErrorStackTrace = stackTrace;
      }
    }
  }

  final tasks = List.generate(workerCount, (_) => runWorker());

  await Future.wait(tasks);
  if (firstError != null) {
    Error.throwWithStackTrace(firstError!, firstErrorStackTrace!);
  }
  return DownloadImageJobsResult(
    completed: progress,
    downloaded: downloaded,
    reused: reused,
    skipped: skipped,
  );
}

Future<DownloadPictureResult> _downloadSingleJob({
  required String from,
  required DownloadImageJob job,
  required String qjsRuntimeName,
  required String qjsTaskGroupKey,
  required Future<void> Function() ensureTaskRunning,
  bool Function()? shouldRetryUntilSuccess,
  Future<void> Function()? waitForForeground,
  bool isolatedPage = false,
  Future<void> Function(Object error, DownloadImageJob job)? onError,
  PictureType pictureType = PictureType.comic,
  required String downloadRoot,
}) async {
  var emptyResponses = 0;
  Future<DownloadPictureResult> fetchPage() async {
    if (waitForForeground != null) {
      await waitForForeground();
      await ensureTaskRunning();
    }
    final result = await downloadPictureResult(
      from: from,
      url: job.url,
      path: job.path,
      cartoonId: job.cartoonId,
      chapterId: job.chapterId,
      storageChapterId: job.storageChapterId,
      pictureType: pictureType,
      downloadRoot: downloadRoot,
      // 外层负责整张图片的重试，避免网络层 10 次重试后才进入
      // 保存/解码失败的重试流程。
      retry: false,
      qjsName: qjsRuntimeName,
      qjsTaskGroupKey: qjsTaskGroupKey,
      extern: job.extern,
      isolatedPage: isolatedPage,
      requestTimeoutMs: isolatedPage ? 12000 : 30000,
    );
    if (!result.isSuccess) {
      _throwLocalFileFailure(result);
      throw DownloadImageJobException(
        job: job,
        result: result,
        routed: isolatedPage,
      );
    }
    return result;
  }

  try {
    if (isolatedPage) {
      await ensureTaskRunning();
      try {
        return await fetchPage();
      } on DownloadImageJobException catch (error) {
        // A single short interruption shouldn't discard this chapter's plan.
        // Explicit host errors (including 429 and 503) keep their route policy.
        final retryPage =
            error.retryReason == ComicDownloadRetryReason.timeout ||
            error.retryReason == ComicDownloadRetryReason.network;
        if (!retryPage) rethrow;
      }
      await raceWithDownloadCancel(
        qjsTaskGroupKey,
        Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await ensureTaskRunning();
      return await fetchPage();
    }
    return await retryDownloadOperation<DownloadPictureResult>(
      operation: '下载图片 ${job.path}',
      ensureTaskRunning: ensureTaskRunning,
      shouldRetryUntilSuccess: shouldRetryUntilSuccess,
      shouldRetry: (error) {
        if (error is! DownloadImageJobException) return true;
        if (error.result.status == DownloadPictureResultStatus.emptyData) {
          emptyResponses++;
          return emptyResponses <= downloadSilentRetryCount;
        }
        final cause = error.result.error;
        return (cause == null || !isNonRetryableDownloadFailure(cause)) &&
            error.result.status != DownloadPictureResultStatus.notFound;
      },
      action: fetchPage,
    );
  } catch (error, stackTrace) {
    if (onError != null) {
      await onError(error, job);
      return DownloadPictureResult(
        status: DownloadPictureResultStatus.failed,
        error: error,
        errorStackTrace: stackTrace,
      );
    }
    rethrow;
  }
}
