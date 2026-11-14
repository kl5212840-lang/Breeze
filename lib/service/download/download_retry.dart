import 'dart:async';
import 'dart:io';

import 'package:zephyr/main.dart';
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/download/download_cancel_signal.dart';
import 'package:zephyr/service/image_recovery.dart'
    show ImageFailureEvidence, imageFailureHttpStatus;
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';

enum ComicDownloadRetryReason {
  network,
  timeout,
  rateLimited,
  sourceUnavailable,
}

class ComicDownloadRetryDeferred implements Exception {
  const ComicDownloadRetryDeferred(this.reason);
  final ComicDownloadRetryReason reason;

  Duration delayFor(int consecutiveRounds) {
    final step = (consecutiveRounds - 1).clamp(0, 5).toInt();
    final seconds =
        (reason == ComicDownloadRetryReason.rateLimited ? 30 : 5) * (1 << step);
    return Duration(seconds: seconds.clamp(0, 300).toInt());
  }
}

ComicDownloadRetryReason? comicDownloadHttpRetryReason(int? status) =>
    switch (status) {
      408 => ComicDownloadRetryReason.timeout,
      425 => ComicDownloadRetryReason.sourceUnavailable,
      429 => ComicDownloadRetryReason.rateLimited,
      final int code when code >= 500 && code <= 599 =>
        ComicDownloadRetryReason.sourceUnavailable,
      _ => null,
    };

/// Unknown legacy errors keep their bounded silent retry budget. A new queue
/// round requires transport evidence, without inspecting URL or stack frames.
ComicDownloadRetryReason? comicDownloadRetryReason(Object error) {
  if (isNonRetryableDownloadFailure(error) || _isDownloadCancellation(error)) {
    return null;
  }
  if (error is TimeoutException) return ComicDownloadRetryReason.timeout;
  if (error is SocketException) return ComicDownloadRetryReason.network;
  final detail = error is String ? error : quickJsErrorMessage(error);
  if (detail == null) return null;
  final status = imageFailureHttpStatus(detail);
  if (status != null) return comicDownloadHttpRetryReason(status);
  final message = detail.trim().toLowerCase().replaceFirst(
    RegExp(r'^(?:ky request failed: |timeout(?:error|exception): )+'),
    '',
  );
  if (RegExp(
    r'^(?:request |connection |operation )?(?:timeout|timed out)\b',
  ).hasMatch(message)) {
    return ComicDownloadRetryReason.timeout;
  }
  if (RegExp(
    r'^(?:network error|connection reset|connection refused|failed to connect|dns lookup failed)\b',
  ).hasMatch(message)) {
    return ComicDownloadRetryReason.network;
  }
  return null;
}

/// 下载操作在首次尝试失败后，默认最多静默重试的次数。
const downloadSilentRetryCount = 3;

bool isNonRetryableDownloadFailure(Object error) => switch (error) {
  FileSystemException() ||
  FormatException() ||
  ArgumentError() ||
  PluginLoginRequiredException() ||
  PluginSessionChanged() ||
  PluginLifecycleChanged() => true,
  ImageFailureEvidence(:final retryable) => !retryable,
  _ => false,
};

Future<T> retryDownloadOperation<T>({
  required String operation,
  required Future<T> Function() action,
  required Future<void> Function() ensureTaskRunning,
  bool Function(Object error)? shouldRetry,
  bool Function()? shouldRetryUntilSuccess,
  Duration retryDelay = const Duration(seconds: 1),
}) async {
  var attempt = 0;
  // 开启“失败后持续重试”时不设尝试上限：退出只靠取消、
  // 不可重试错误（如 404、本机文件失败），或关闭开关且打满静默次数。
  while (true) {
    // 取消检查放在 try 外，取消不会被当成普通网络错误再次重试。
    await ensureTaskRunning();
    try {
      return await action();
    } catch (error, stackTrace) {
      if (isNonRetryableDownloadFailure(error) ||
          _isDownloadCancellation(error) ||
          shouldRetry?.call(error) == false) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      final retryForever = shouldRetryUntilSuccess?.call() ?? false;
      if (!retryForever && attempt >= downloadSilentRetryCount) {
        Error.throwWithStackTrace(error, stackTrace);
      }

      final retryNumber = attempt + 1;
      attempt += 1;
      logger.w(
        retryForever
            ? '$operation 失败，准备持续重试 (第 $retryNumber 次)'
            : '$operation 失败，准备静默重试 ($retryNumber/$downloadSilentRetryCount)',
        error: error,
        stackTrace: stackTrace,
      );
      await Future<void>.delayed(retryDelay);
    }
  }
}

bool _isDownloadCancellation(Object error) {
  final message = error.toString();
  return message.contains(downloadTaskCancelledMessage) ||
      message.contains('__QJS_RUNTIME_CANCELLED__');
}
