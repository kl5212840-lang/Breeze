import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_community_page.dart';
import 'package:zephyr/page/video/video_download.dart';
import 'package:zephyr/page/video/video_download_failure.dart';
import 'package:zephyr/page/video/video_download_choice.dart';
import 'package:zephyr/page/video/video_site_action_models.dart';
import 'package:zephyr/page/video/video_download_panel.dart';
import 'package:zephyr/page/video/video_download_availability.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_playback_download_adapter.dart';

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
    this.source = '',
    this.networkContext,
    this.cover,
    this.durationMs,
    this.sourceDuration,
    this.headersForChoice,
    this.emptyMessage,
    this.refreshAdapter,
    this.choicesAreSnapshot = false,
  });
  final Future<VideoSiteResult<List<VideoDownloadChoice>>> Function()
  readChoices;
  final Uri video;
  final String title;
  final VoidCallback onClose;
  final VoidCallback? onWebsite;
  final String source;
  final String? networkContext;
  final String? cover;
  final int? durationMs;
  final String? sourceDuration;
  final Map<String, String> Function(VideoDownloadChoice)? headersForChoice;
  final String? emptyMessage;
  final Future<VideoPlaybackDownloadAdapter> Function()? refreshAdapter;
  final bool choicesAreSnapshot;

  @override
  State<VideoDownloadSheet> createState() => _VideoDownloadSheetState();
}

class _VideoDownloadSheetState extends State<VideoDownloadSheet> {
  var _transfer = VideoSystemDownload();
  List<VideoDownloadChoice> _choices = const [];
  bool _loading = true, _running = false, _cancelling = false;
  bool _lastWasReplacement = false;
  VideoSiteStatus? _readStatus;
  VideoDownloadStatus? _status;
  VideoDownloadProgress? _progress;
  String _quality = '';
  VideoDownloadChoice? _selectedChoice;
  VideoPlaybackDownloadAdapter? _freshAdapter;
  VideoDownloadAvailability _availability = const VideoDownloadAvailability();
  int _loadEpoch = 0;
  int _availabilityEpoch = 0;
  String _taskStructure = '';
  bool _availabilityFailed = false;

  @override
  void initState() {
    super.initState();
    VideoExportRecords.changes.addListener(_taskChanged);
    VideoLocalResources.changes.addListener(_resourcesChanged);
    if (VideoSystemDownload.available) {
      unawaited(_load());
    } else {
      _loading = false;
      _status = VideoDownloadStatus.unavailable;
    }
  }

  void _taskChanged() {
    if (_running || _loading || widget.source.isEmpty) return;
    final structure = VideoExportRecords.sessionTaskSnapshot()
        .where(
          (row) =>
              row['source'] == widget.source &&
              row['url'] == widget.video.toString(),
        )
        .map(
          (row) =>
              '${row['key']}|${row['status']}|${row['attempt']}|${row['resourceId']}',
        )
        .join('\n');
    if (structure == _taskStructure) return;
    _taskStructure = structure;
    unawaited(_readAvailability());
  }

  void _resourcesChanged() {
    if (!_running && !_loading) unawaited(_readAvailability());
  }

  Future<void> _readAvailability() async {
    final epoch = _loadEpoch;
    final availabilityEpoch = ++_availabilityEpoch;
    try {
      final value = await VideoDownloadAvailability.read(
        source: widget.source,
        watch: widget.video,
      ).timeout(const Duration(seconds: 8));
      if (mounted &&
          epoch == _loadEpoch &&
          availabilityEpoch == _availabilityEpoch)
        setState(() {
          _availability = value;
          _availabilityFailed = false;
        });
    } catch (error) {
      if (mounted &&
          epoch == _loadEpoch &&
          availabilityEpoch == _availabilityEpoch)
        setState(() => _availabilityFailed = true);
    }
  }

  @override
  void didUpdateWidget(covariant VideoDownloadSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.video != widget.video ||
        oldWidget.networkContext != widget.networkContext) {
      // The old transfer remains process-owned. A late result cannot become
      // this different episode's status, nor can its instance block a new job.
      _transfer = VideoSystemDownload();
      _running = false;
      _cancelling = false;
      _progress = null;
      _quality = '';
      _lastWasReplacement = false;
      _freshAdapter = null;
      _availability = const VideoDownloadAvailability();
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _loadEpoch++;
    _availabilityEpoch++;
    VideoExportRecords.changes.removeListener(_taskChanged);
    VideoLocalResources.changes.removeListener(_resourcesChanged);
    super.dispose();
  }

  bool get _canRefresh =>
      widget.refreshAdapter != null || !widget.choicesAreSnapshot;

  Future<void> _load({bool fresh = false}) async {
    final epoch = ++_loadEpoch;
    setState(() {
      _loading = true;
      _status = null;
      _readStatus = null;
      _choices = const [];
      _selectedChoice = null;
      _availabilityFailed = false;
    });
    VideoSiteResult<List<VideoDownloadChoice>> result;
    try {
      if (!await VideoSystemDownload.supportsRoute(
        widget.source,
        widget.networkContext,
      )) {
        if (mounted && epoch == _loadEpoch)
          setState(() {
            _loading = false;
            _status = VideoDownloadStatus.routeUnavailable;
          });
        return;
      }
      if (fresh && widget.refreshAdapter != null) {
        final adapter = await widget.refreshAdapter!().timeout(
          const Duration(seconds: 45),
        );
        if (!mounted || epoch != _loadEpoch) return;
        _freshAdapter = adapter;
        result = await adapter.readChoices();
      } else if (fresh && !_canRefresh) {
        result = (
          status: VideoSiteStatus.unsupported,
          value: null,
          writeUnconfirmed: false,
        );
      } else {
        result = await widget.readChoices().timeout(
          const Duration(seconds: 45),
        );
      }
      if (mounted && epoch == _loadEpoch) await _readAvailability();
    } catch (_) {
      result = (
        status: VideoSiteStatus.network,
        value: null,
        writeUnconfirmed: false,
      );
    }
    if (!mounted || epoch != _loadEpoch) return;
    setState(() {
      _loading = false;
      _readStatus = result.status;
      if (result.status == VideoSiteStatus.ok) {
        _choices = result.value ?? const [];
      }
    });
  }

  VideoEpisodeDownloadAvailability _choiceState(VideoDownloadChoice choice) =>
      _availability.episode(
        widget.video,
        quality: choice.label,
        format: choice.url.path.toLowerCase().endsWith('.m3u8') ? 'hls' : 'mp4',
      );

  Future<void> _retry() async {
    if (_running || _loading) return;
    final quality = _quality;
    final replaceExisting = _lastWasReplacement;
    final format =
        _selectedChoice?.url.path.toLowerCase().endsWith('.m3u8') == true
        ? 'hls'
        : 'mp4';
    await _load(fresh: true);
    if (!mounted || _loading || _readStatus != VideoSiteStatus.ok) return;
    final choice = _choices
        .where(
          (choice) =>
              choice.label == quality &&
              (choice.url.path.toLowerCase().endsWith('.m3u8')
                      ? 'hls'
                      : 'mp4') ==
                  format,
        )
        .firstOrNull;
    if (choice == null)
      return; // Fresh options remain visible for an explicit selection.
    setState(() => _selectedChoice = choice);
    await _save(choice, replaceExisting: replaceExisting);
  }

  Future<void> _redownload() async {
    final choice = _selectedChoice;
    if (choice == null || _running || _loading || _availabilityFailed) return;
    if (!_canRefresh) return _save(choice, replaceExisting: true);
    _quality = choice.label;
    _lastWasReplacement = true;
    await _retry();
  }

  Future<void> _save(
    VideoDownloadChoice choice, {
    bool replaceExisting = false,
  }) async {
    if (_running || _loading) return;
    if (_availabilityFailed ||
        _choiceState(choice).downloading ||
        !replaceExisting && _choiceState(choice).downloaded)
      return;
    final epoch = _loadEpoch;
    setState(() {
      _running = true;
      _cancelling = false;
      _status = null;
      _quality = choice.label;
      _lastWasReplacement = replaceExisting;
      _progress = null;
    });
    final status = await _transfer.save(
      userInitiated: true,
      choice: choice,
      networkContext: widget.networkContext,
      headers:
          _freshAdapter?.headersForChoice(choice) ??
          widget.headersForChoice?.call(choice) ??
          const {},
      source: widget.source,
      cover: widget.cover,
      durationMs: widget.durationMs,
      sourceDuration: widget.sourceDuration,
      replaceExisting: replaceExisting,
      onMediaProgress: (_) {},
      video: widget.video,
      title: widget.title,
      onProgress: (progress) {
        if (mounted && epoch == _loadEpoch)
          setState(() => _progress = progress);
      },
    );
    if (!mounted || epoch != _loadEpoch) return;
    setState(() {
      _running = false;
      _status = status;
      // A failed link may have expired. Require an explicit fresh page read.
      if (status == VideoDownloadStatus.failed) _choices = const [];
    });
    unawaited(_readAvailability());
  }

  String? get _message => switch (_status) {
    VideoDownloadStatus.saved =>
      widget.source.isEmpty ? t.videoDownload.saved : t.download.videoSaved,
    VideoDownloadStatus.cancelled => t.videoDownload.cancelled,
    VideoDownloadStatus.failed =>
      !_canRefresh
          ? t.download.notificationFailedTitle
          : _transfer.failureReason == null ||
                _transfer.failureReason == 'downloadFailed'
          ? t.videoDownload.failed
          : videoDownloadFailureText(
              _transfer.failureReason,
              inWork: true,
              chinese: Localizations.localeOf(context).languageCode == 'zh',
            ),
    VideoDownloadStatus.unavailable => t.videoDownload.unavailable,
    VideoDownloadStatus.unsupported => t.videoDownload.unsupportedMedia,
    VideoDownloadStatus.routeUnavailable => t.videoDownload.routeUnavailable,
    VideoDownloadStatus.busy => t.videoCommunity.busy,
    null =>
      _readStatus != null && _readStatus != VideoSiteStatus.ok
          ? videoOperationMessage(_readStatus!.name)
          : !_loading && _choices.isEmpty
          ? widget.emptyMessage ?? t.videoDownload.empty
          : null,
  };

  @override
  Widget build(BuildContext context) => VideoDownloadPanel(
    title: t.videoDownload.title,
    onClose: widget.onClose,
    continuing: _running,
    actions: _running
        ? OutlinedButton(
            key: const ValueKey('video-download.cancel'),
            onPressed: _cancelling
                ? null
                : () {
                    setState(() => _cancelling = true);
                    unawaited(_transfer.cancel());
                  },
            child: Text(t.videoDownload.cancel),
          )
        : FilledButton(
            key: const ValueKey('video-download.start'),
            onPressed:
                _loading ||
                    _availabilityFailed ||
                    _selectedChoice == null ||
                    !_choices.contains(_selectedChoice) ||
                    _choiceState(_selectedChoice!).downloading ||
                    _choiceState(_selectedChoice!).downloaded
                ? null
                : () => unawaited(_save(_selectedChoice!)),
            child: Text(t.download.startDownload),
          ),
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
                _progress?.saving == true
                    ? t.videoDownload.saving
                    : t.videoDownload.downloading(quality: _quality),
              ),
            ),
            const SizedBox(height: 12),
            if (_progress?.saving != true)
              if (_transfer.lastTaskKey case final key?)
                VideoDownloadTaskProgress(key: ValueKey(key), taskKey: key)
              else
                const LinearProgressIndicator(),
          ] else ...[
            if (_message case final message?)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Semantics(liveRegion: true, child: Text(message)),
              ),
            if (_canRefresh &&
                _status != null &&
                _status != VideoDownloadStatus.saved &&
                _status != VideoDownloadStatus.unavailable &&
                _status != VideoDownloadStatus.unsupported)
              TextButton.icon(
                key: const ValueKey('video-download.retry'),
                onPressed: _loading ? null : () => unawaited(_retry()),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(t.common.retry),
              ),
            if (_availabilityFailed)
              TextButton.icon(
                onPressed: _readAvailability,
                icon: const Icon(Icons.refresh),
                label: Text(t.common.loadingFailed),
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
                  selected: _selectedChoice == _choices[index],
                  leading: Icon(
                    _selectedChoice == _choices[index]
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(_choices[index].label),
                  subtitle: Text(
                    [
                      if (_choices[index].format?.isNotEmpty == true)
                        _choices[index].format!,
                      if (_choiceState(_choices[index]).downloaded)
                        t.download.alreadyDownloaded
                      else if (_choiceState(_choices[index]).downloading)
                        t.download.downloading,
                    ].join(' · '),
                  ),
                  onTap: () =>
                      setState(() => _selectedChoice = _choices[index]),
                ),
              if (_selectedChoice != null &&
                  _choiceState(_selectedChoice!).downloaded)
                TextButton(
                  key: const ValueKey('video-download.redownload'),
                  onPressed: _availabilityFailed
                      ? null
                      : () => unawaited(_redownload()),
                  child: Text(t.download.redownload),
                ),
            ],
            if (VideoSystemDownload.available && _canRefresh)
              TextButton.icon(
                onPressed: () => unawaited(_load(fresh: true)),
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
  );
}
