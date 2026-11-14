import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';

/// A partial read keeps the usable detail visible. Retry awaits the existing
/// detail load, with no automatic loop or second cache/database write path.
class ComicDetailPartialNotice extends StatefulWidget {
  const ComicDetailPartialNotice({super.key, required this.onRetry});
  final Future<void> Function() onRetry;

  @override
  State<ComicDetailPartialNotice> createState() =>
      _ComicDetailPartialNoticeState();
}

class _ComicDetailPartialNoticeState extends State<ComicDetailPartialNotice> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        Expanded(child: Text(t.comicInfo.partialDetails)),
        const SizedBox(width: 8),
        TextButton.icon(
          key: const ValueKey('comic-detail-partial-retry'),
          onPressed: _retrying ? null : _retry,
          icon: _retrying
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: Text(t.common.retry),
        ),
      ],
    ),
  );
}
