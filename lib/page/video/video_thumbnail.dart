import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';

/// Poster requests are independent of video playback. Missing URLs, loading
/// and failed requests each get a visible state instead of a silent black box.
class VideoThumbnail extends StatefulWidget {
  const VideoThumbnail({
    super.key,
    required this.url,
    required this.referrer,
    this.placeholderIcon = Icons.image_outlined,
  });
  final String url;
  final IconData placeholderIcon;
  final Uri referrer;
  @override
  State<VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<VideoThumbnail> {
  int _attempt = 0;
  Timer? _retryTimer;
  Map<String, String> get _headers => {'Referer': widget.referrer.toString()};

  @override
  void didUpdateWidget(covariant VideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url) {
      _retryTimer?.cancel();
      _retryTimer = null;
      _attempt = 0;
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> _retry() async {
    await NetworkImage(widget.url, headers: _headers).evict();
    if (mounted) setState(() => _attempt++);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final uri = Uri.tryParse(widget.url);
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: uri?.scheme != 'https' || uri?.host.isEmpty != false
          ? Center(
              child: Icon(
                widget.placeholderIcon,
                color: colors.onSurfaceVariant,
              ),
            )
          : Image.network(
              widget.url,
              key: ValueKey('${widget.url}.$_attempt'),
              headers: _headers,
              fit: BoxFit.cover,
              loadingBuilder: (_, image, progress) => progress == null
                  ? image
                  : Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: progress.expectedTotalBytes == null
                              ? null
                              : progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!,
                        ),
                      ),
                    ),
              errorBuilder: (_, _, _) {
                if (_attempt == 0) {
                  _retryTimer ??= Timer(const Duration(milliseconds: 800), () {
                    if (mounted) _retry();
                  });
                }
                return Center(
                  child: IconButton(
                    tooltip: t.common.retry,
                    onPressed: _retry,
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
