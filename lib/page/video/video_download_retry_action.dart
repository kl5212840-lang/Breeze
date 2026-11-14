import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_download_failure.dart';
import 'package:zephyr/page/video/video_download_source_navigation.dart';
import 'package:zephyr/page/video/video_download_retry.dart';
import 'package:zephyr/page/video/video_download_retry_host.dart';
import 'package:zephyr/widgets/toast.dart';

bool videoDownloadRequiresSourceDetails(Map<String, dynamic> row) =>
    VideoDownloadRetry.needsSource(row) ||
    (row['status'] == 'saved' &&
        (row['fileInvalid'] == true || row['fileRemoved'] == true));

Future<void> retryVideoDownload(
  BuildContext context,
  Map<String, dynamic> row,
) async {
  if (VideoDownloadRetry.needsSource(row)) {
    await openVideoDownloadWork(context, row);
    return;
  }
  final overlay = Overlay.of(context, rootOverlay: true);
  final owner = Object();
  try {
    final queued = await VideoDownloadRetry.retry(
      row,
      userInitiated: true,
      fallback: (task) =>
          VideoDownloadRetryHosts.resolve(overlay, task, owner: owner),
      cancelResolution: () =>
          VideoDownloadRetryHosts.cancel('${row['source']}', owner),
    );
    if (!queued &&
        context.mounted &&
        !VideoDownloadRetry.isPending('${row['key']}')) {
      showErrorToast(
        videoDownloadFailureText(
          'missingIdentity',
          chinese: Localizations.localeOf(context).languageCode == 'zh',
        ),
      );
    }
  } on VideoDownloadRetryFailure catch (error) {
    if (context.mounted)
      showErrorToast(
        videoDownloadFailureText(
          error.reason,
          chinese: Localizations.localeOf(context).languageCode == 'zh',
        ),
      );
  } catch (_) {
    if (context.mounted) showErrorToast(t.common.loadingFailed);
  }
}

class VideoDownloadRetryAction extends StatelessWidget {
  const VideoDownloadRetryAction({
    super.key,
    required this.row,
    this.iconOnly = false,
    this.enabled = true,
    this.includeSourceDetails = true,
    this.onOpenSource,
    this.onRetry,
    this.sourceLabel,
    this.retryLabel,
  });
  final Map<String, dynamic> row;
  final bool iconOnly, enabled, includeSourceDetails;
  final VoidCallback? onOpenSource, onRetry;
  final String? sourceLabel, retryLabel;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: VideoDownloadRetryHosts.changes,
    builder: (context, _, __) {
      if (VideoDownloadRetry.isWaitingForNetwork(row)) {
        return const SizedBox.shrink();
      }
      final source = '${row['source']}';
      final verify = VideoDownloadRetryHosts.canContinue(
        source,
        taskKey: '${row['key']}',
      );
      final needsSource = videoDownloadRequiresSourceDetails(row);
      if (needsSource &&
          (!includeSourceDetails || videoDownloadSourceTarget(row) == null)) {
        return const SizedBox.shrink();
      }
      if (!verify && !needsSource && !VideoDownloadRetry.canRetry(row))
        return const SizedBox.shrink();
      final label = needsSource
          ? sourceLabel ?? t.download.openSourceVideo
          : verify
          ? Localizations.localeOf(context).languageCode == 'zh'
                ? '继续验证'
                : 'Continue verification'
          : retryLabel ?? t.common.retry;
      void press() {
        if (needsSource) {
          if (onOpenSource case final open?) {
            open();
          } else {
            openVideoDownloadWork(context, row);
          }
        } else if (verify) {
          VideoDownloadRetryHosts.continueVerification(
            source,
            taskKey: '${row['key']}',
          );
        } else if (onRetry case final retry?) {
          retry();
        } else {
          retryVideoDownload(context, row);
        }
      }

      return iconOnly
          ? IconButton(
              key: ValueKey(
                '${needsSource ? 'download-source' : 'download-retry'}.${row['key']}',
              ),
              tooltip: label,
              onPressed: enabled ? press : null,
              icon: Icon(
                needsSource
                    ? Icons.arrow_forward_rounded
                    : verify
                    ? Icons.verified_user_outlined
                    : Icons.refresh_rounded,
              ),
            )
          : TextButton(
              key: ValueKey(
                '${needsSource ? 'download-source' : 'download-retry'}.${row['key']}',
              ),
              onPressed: enabled ? press : null,
              child: Text(label),
            );
    },
  );
}
