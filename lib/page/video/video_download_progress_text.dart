import 'package:zephyr/page/video/video_download_progress.dart';

/// Presentation shared by the task sheet, download rows and work summaries.
/// Package measurements may supply actual downloaded bytes, but never a
/// network rate. Missing byte totals have no invented denominator or label.
List<String> videoDownloadProgressText({
  Map<String, dynamic>? row,
  VideoDownloadByteProgress? progress,
  VideoDownloadRate? rate,
  required String Function(int) formatBytes,
  bool includePercent = true,
}) {
  final value = progress ?? VideoDownloadByteProgress.fromRow(row ?? const {});
  final received = value.received, total = value.total;
  return [
    if (received != null)
      total == null
          ? formatBytes(received)
          : '${formatBytes(received)} / ${formatBytes(total)}',
    if (includePercent && value.fraction != null)
      '${(value.fraction! * 100).floor()}%',
    if (rate != null &&
        !rate.isPackage &&
        rate.bytesPerSecond.isFinite &&
        rate.bytesPerSecond >= 0)
      '${formatBytes(rate.bytesPerSecond.round())}/s',
  ];
}
