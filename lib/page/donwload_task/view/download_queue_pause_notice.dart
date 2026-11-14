import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/service/download/download_admission.dart';
import 'package:zephyr/service/download/download_queue_manager.dart';
import 'package:zephyr/widgets/toast.dart';

/// Offers recovery when an existing device-level pause holds waiting tasks.
class DownloadQueuePauseNotice extends StatefulWidget {
  const DownloadQueuePauseNotice({super.key, this.onResumeStarted});

  final VoidCallback? onResumeStarted;

  @override
  State<DownloadQueuePauseNotice> createState() =>
      _DownloadQueuePauseNoticeState();
}

class _DownloadQueuePauseNoticeState extends State<DownloadQueuePauseNotice> {
  final _admission = DownloadAdmission.instance;
  bool _resuming = false;

  @override
  void initState() {
    super.initState();
    unawaited(_admission.initializeQueueState());
  }

  Future<void> _resume() async {
    if (_resuming || !_admission.queuePaused) return;
    widget.onResumeStarted?.call();
    setState(() => _resuming = true);
    try {
      await DownloadQueueManager.instance.resumeQueueFromUser();
    } catch (_) {
      if (mounted) showErrorToast(t.error.saveFailed);
    } finally {
      if (mounted) setState(() => _resuming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _admission,
      builder: (context, _) {
        if (!_admission.queuePaused) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                t.download.queuePaused,
                key: const ValueKey('download-queue-paused'),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              TextButton(
                key: const ValueKey('download-queue-resume'),
                onPressed: _resuming ? null : _resume,
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                child: Text(t.download.resumeQueue),
              ),
            ],
          ),
        );
      },
    );
  }
}
