import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_community_page.dart';
import 'package:zephyr/page/video/video_download.dart';
import 'package:zephyr/page/video/video_download_choice.dart';
import 'package:zephyr/page/video/video_site_action_models.dart';

/// Quality selection, actual file transfer and Files export inside playback.
/// An unsupported platform has a single explicit website action; no fake queue.
class VideoDownloadSheet extends StatefulWidget {
  const VideoDownloadSheet({
    super.key,
    required this.readChoices,
    required this.video,
    required this.title,
    required this.onClose,
    this.onWebsite,
  });
  final Future<VideoSiteResult<List<VideoDownloadChoice>>> Function()
  readChoices;
  final Uri video;
  final String title;
  final VoidCallback onClose;
  final VoidCallback? onWebsite;

  @override
  State<VideoDownloadSheet> createState() => _VideoDownloadSheetState();
}

class _VideoDownloadSheetState extends State<VideoDownloadSheet> {
  final _transfer = VideoSystemDownload();
  List<VideoDownloadChoice> _choices = const [];
  bool _loading = true, _running = false;
  VideoSiteStatus? _readStatus;
  VideoDownloadStatus? _status;
  VideoDownloadProgress? _progress;
  String _quality = '';

  @override
  void initState() {
    super.initState();
    if (VideoSystemDownload.available) {
      unawaited(_load());
    } else {
      _loading = false;
      _status = VideoDownloadStatus.unavailable;
    }
  }

  @override
  void dispose() {
    unawaited(_transfer.cancel());
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _status = null;
      _readStatus = null;
      _choices = const [];
    });
    VideoSiteResult<List<VideoDownloadChoice>> result;
    try {
      result = await widget.readChoices();
    } catch (_) {
      result = (
        status: VideoSiteStatus.network,
        value: null,
        writeUnconfirmed: false,
      );
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _readStatus = result.status;
      if (result.status == VideoSiteStatus.ok) {
        _choices = result.value ?? const [];
      }
    });
  }

  Future<void> _save(VideoDownloadChoice choice) async {
    if (_running || _loading) return;
    setState(() {
      _running = true;
      _status = null;
      _quality = choice.label;
      _progress = null;
    });
    final status = await _transfer.save(
      choice: choice,
      video: widget.video,
      title: widget.title,
      onProgress: (progress) {
        if (mounted) setState(() => _progress = progress);
      },
    );
    if (!mounted) return;
    setState(() {
      _running = false;
      _status = status;
      // A failed link may have expired. Require an explicit fresh page read.
      if (status == VideoDownloadStatus.failed) _choices = const [];
    });
  }

  String? get _message => switch (_status) {
    VideoDownloadStatus.saved => t.videoDownload.saved,
    VideoDownloadStatus.cancelled => t.videoDownload.cancelled,
    VideoDownloadStatus.failed => t.videoDownload.failed,
    VideoDownloadStatus.unavailable => t.videoDownload.unavailable,
    VideoDownloadStatus.busy => t.videoCommunity.busy,
    null =>
      _readStatus != null && _readStatus != VideoSiteStatus.ok
          ? videoOperationMessage(_readStatus!.name)
          : !_loading && _choices.isEmpty
          ? t.videoDownload.empty
          : null,
  };

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    final total = progress?.total;
    final ratio = total == null
        ? null
        : (progress!.received / total).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t.videoDownload.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: widget.onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_loading) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(t.videoDownload.loading),
                ] else if (_running) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      progress?.saving == true
                          ? t.videoDownload.saving
                          : t.videoDownload.downloading(quality: _quality),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (progress?.saving != true)
                    LinearProgressIndicator(value: ratio),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => unawaited(_transfer.cancel()),
                    child: Text(t.videoDownload.cancel),
                  ),
                ] else ...[
                  if (_message case final message?)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Semantics(liveRegion: true, child: Text(message)),
                    ),
                  if (_choices.isNotEmpty) ...[
                    Text(
                      t.videoDownload.chooseQuality,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    for (var index = 0; index < _choices.length; index++)
                      ListTile(
                        key: ValueKey('video-download-choice-$index'),
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.download_outlined),
                        title: Text(_choices[index].label),
                        subtitle: _choices[index].format?.isNotEmpty == true
                            ? Text(_choices[index].format!)
                            : null,
                        onTap: () => unawaited(_save(_choices[index])),
                      ),
                  ],
                  if (VideoSystemDownload.available)
                    TextButton.icon(
                      onPressed: () => unawaited(_load()),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(t.videoDownload.reload),
                    ),
                  if (widget.onWebsite != null)
                    TextButton.icon(
                      onPressed: widget.onWebsite,
                      icon: const Icon(Icons.open_in_browser_rounded),
                      label: Text(t.videoDownload.website),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
