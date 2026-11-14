import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_download.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/widgets/toast.dart';

Future<bool> confirmVideoDownloadCancellation(
  BuildContext context,
  Map<String, dynamic> row, {
  required VoidCallback onConfirmed,
}) async {
  final key = row['key'] as String;
  final attempt = row['attempt'];
  final accepted = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(t.download.cancelTask),
      content: Text(
        t.download.cancelTaskConfirm(comicName: row['title'] as String),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: Text(t.common.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialog, true),
          child: Text(t.common.ok),
        ),
      ],
    ),
  );
  // A confirmation belongs to its original transfer. It cannot cancel a
  // replacement started while this dialog was open.
  if (accepted != true ||
      !context.mounted ||
      attempt is! int ||
      !VideoExportRecords.isAttemptCurrent(key, attempt)) {
    return false;
  }
  onConfirmed();
  try {
    await VideoSystemDownload.cancelTask(key, expectedAttempt: attempt);
    return true;
  } catch (_) {
    showErrorToast(t.common.loadingFailed);
    return false;
  }
}
