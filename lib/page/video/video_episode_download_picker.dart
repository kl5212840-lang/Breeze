import 'dart:async';
import 'package:zephyr/page/video/video_download_line_history.dart';
import 'package:zephyr/page/video/video_download_navigation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/video/video_download_panel.dart';
import 'package:zephyr/page/video/video_download_availability.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_download_failure.dart';
import 'package:zephyr/page/video/video_episode_ranges.dart';

/// Returns public episode cards in source order. No media is resolved here.
Future<List<NativeVideoCard>?> showVideoEpisodeDownloadPicker(
  BuildContext context, {
  required List<NativeVideoCard> episodes,
  required Uri currentWatch,
  Map<String, String> lineLabels = const {},
  String source = '',
  String workId = '',
  String namespace = '',
  bool? systemStyle,
  Future<List<String>> Function(List<NativeVideoCard>)? onEnqueue,
  Future<List<String>> Function(NativeVideoCard, Map<String, dynamic>)? onRetry,
}) => showVideoTaskSheet<List<NativeVideoCard>>(
  context: context,
  useRootNavigator: true,
  systemStyle: systemStyle,
  builder: (_) => VideoDownloadNavigationOrigin(
    origin: context,
    child: VideoEpisodeDownloadPicker(
      episodes: episodes,
      currentWatch: currentWatch,
      lineLabels: lineLabels,
      source: source,
      workId: workId,
      namespace: namespace,
      onEnqueue: onEnqueue,
      onRetry: onRetry,
    ),
  ),
);

class VideoEpisodeDownloadPicker extends StatefulWidget {
  const VideoEpisodeDownloadPicker({
    super.key,
    required this.episodes,
    required this.currentWatch,
    this.lineLabels = const {},
    this.source = '',
    this.workId = '',
    this.namespace = '',
    this.onEnqueue,
    this.onRetry,
  });
  final List<NativeVideoCard> episodes;
  final Uri currentWatch;
  final Map<String, String> lineLabels;
  final String source, workId, namespace;
  final Future<List<String>> Function(List<NativeVideoCard>)? onEnqueue;
  final Future<List<String>> Function(NativeVideoCard, Map<String, dynamic>)?
  onRetry;

  @override
  State<VideoEpisodeDownloadPicker> createState() =>
      _VideoEpisodeDownloadPickerState();
}

class _VideoEpisodeDownloadPickerState
    extends State<VideoEpisodeDownloadPicker> {
  final _selected = <Uri>{};
  late String _line;
  int? _range;
  bool _queueing = false;
  bool _queueFailed = false;
  Set<String> _queuedKeys = const {};
  String? _lastSuccessfulLine;
  int _historyEpoch = 0;
  int _availabilityEpoch = 0;
  int _scopeEpoch = 0;
  VideoDownloadAvailability _availability = const VideoDownloadAvailability();
  bool _readingAvailability = false, _availabilityFailed = false;
  String _taskStructure = '';

  @override
  void initState() {
    super.initState();
    _line = widget.currentWatch.queryParameters['line'] ?? '';
    unawaited(_readLineHistory());
    VideoExportRecords.changes.addListener(_tasksChanged);
    VideoLocalResources.changes.addListener(_readAvailability);
    unawaited(_readAvailability());
  }

  void _tasksChanged() {
    final structure = VideoExportRecords.sessionTaskSnapshot()
        .where((row) => row['source'] == widget.source)
        .map(
          (row) =>
              '${row['key']}|${row['status']}|${row['attempt']}|${row['quality']}|${row['format']}|${row['resourceId']}',
        )
        .join('\n');
    if (structure == _taskStructure) return;
    _taskStructure = structure;
    unawaited(_readAvailability());
  }

  Future<void> _readAvailability() async {
    final epoch = ++_availabilityEpoch;
    if (widget.source.isEmpty) return;
    setState(() => _readingAvailability = true);
    try {
      final value = await VideoDownloadAvailability.read(
        source: widget.source,
        watch: widget.currentWatch,
        workId: widget.workId,
        namespace: widget.namespace,
      ).timeout(const Duration(seconds: 8));
      if (!mounted || epoch != _availabilityEpoch) return;
      setState(() {
        _availability = value;
        _availabilityFailed = false;
      });
    } catch (_) {
      if (mounted && epoch == _availabilityEpoch)
        setState(() => _availabilityFailed = true);
    } finally {
      if (mounted && epoch == _availabilityEpoch)
        setState(() => _readingAvailability = false);
    }
  }

  Future<void> _readLineHistory() async {
    final epoch = ++_historyEpoch;
    final line = await readLastSuccessfulVideoDownloadLine(
      source: widget.source,
      workId: widget.workId,
      namespace: widget.namespace,
      currentWatch: widget.currentWatch,
      lineIds: widget.lineLabels.keys.toSet(),
    );
    if (mounted && epoch == _historyEpoch && line != _lastSuccessfulLine) {
      setState(() => _lastSuccessfulLine = line);
    }
  }

  @override
  void didUpdateWidget(covariant VideoEpisodeDownloadPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.workId != widget.workId ||
        oldWidget.namespace != widget.namespace ||
        oldWidget.currentWatch != widget.currentWatch) {
      _lastSuccessfulLine = null;
      _scopeEpoch++;
      _queueing = false;
      _availability = const VideoDownloadAvailability();
      _selected.clear();
      _range = null;
      _queuedKeys = const {};
      unawaited(_readLineHistory());
      unawaited(_readAvailability());
    }
  }

  @override
  void dispose() {
    _historyEpoch++;
    _availabilityEpoch++;
    _scopeEpoch++;
    VideoExportRecords.changes.removeListener(_tasksChanged);
    VideoLocalResources.changes.removeListener(_readAvailability);
    super.dispose();
  }

  Uri? _identity(NativeVideoCard card) {
    final identity = videoPlaybackIdentity(card.watchUrl);
    return card.title.trim().isNotEmpty && identity == card.watchUrl
        ? identity
        : null;
  }

  Future<void> _submit() async {
    if (_queueing ||
        _selected.isEmpty ||
        _readingAvailability ||
        _availabilityFailed)
      return;
    final emitted = <Uri>{};
    final selected = [
      for (final card in widget.episodes)
        if (_identity(card) case final Uri identity)
          if (_selected.contains(identity) && emitted.add(identity)) card,
    ];
    final enqueue = widget.onEnqueue;
    if (enqueue == null) {
      Navigator.pop(context, selected);
      return;
    }
    setState(() {
      _queueing = true;
      _queueFailed = false;
    });
    final epoch = _scopeEpoch;
    try {
      final keys = await enqueue(selected);
      if (mounted && epoch == _scopeEpoch)
        setState(() {
          _queuedKeys = keys.toSet();
          _queueFailed = keys.isEmpty;
        });
    } catch (_) {
      if (mounted && epoch == _scopeEpoch) setState(() => _queueFailed = true);
    } finally {
      if (mounted && epoch == _scopeEpoch) setState(() => _queueing = false);
    }
  }

  Future<void> _retry(Map<String, dynamic> row) async {
    if (_queueing) return;
    if (_availabilityFailed) {
      await _readAvailability();
      return;
    }
    final card = widget.episodes
        .where((card) => _identity(card)?.toString() == row['url'])
        .firstOrNull;
    if (card == null) return;
    final epoch = _scopeEpoch;
    setState(() {
      _queueing = true;
      _queueFailed = false;
    });
    try {
      final keys = widget.onRetry != null
          ? await widget.onRetry!(card, row)
          : await widget.onEnqueue?.call([card]) ?? const <String>[];
      if (mounted && epoch == _scopeEpoch)
        setState(() {
          _queuedKeys = {..._queuedKeys, ...keys};
          _queueFailed = keys.isEmpty;
        });
    } catch (_) {
      if (mounted && epoch == _scopeEpoch) setState(() => _queueFailed = true);
    } finally {
      if (mounted && epoch == _scopeEpoch) {
        setState(() => _queueing = false);
        unawaited(_readAvailability());
      }
    }
  }

  void _reselect(Map<String, dynamic> row) {
    final card = widget.episodes
        .where((card) => _identity(card)?.toString() == row['url'])
        .firstOrNull;
    if (card == null || _queueing) return;
    setState(() {
      _queuedKeys = const {};
      _queueFailed = false;
      _line = card.watchUrl.queryParameters['line'] ?? '';
      _range = null;
      _selected
        ..clear()
        ..add(card.watchUrl);
    });
    unawaited(_readAvailability());
  }

  String? _episodeStatus(NativeVideoCard card) {
    final state = _availability.episode(card.watchUrl);
    if (state.downloaded)
      return '${t.download.alreadyDownloaded} · ${state.files.map((row) => '${row['quality']} ${videoDownloadFormat(row).toUpperCase()}').toSet().join(' / ')}';
    final row = state.latestTask;
    if (row == null) return null;
    return switch (row['status']) {
      'preparing' => t.download.videoQueued,
      'downloading' => t.download.downloading,
      'saving' => t.download.videoSaving,
      'cancelled' => t.download.videoCancelled,
      'interrupted' => t.download.videoInterrupted,
      'saved' => t.download.fileUnavailable,
      _ => videoDownloadFailureText(
        row['failureReason'],
        inWork: true,
        chinese: Localizations.localeOf(context).languageCode == 'zh',
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final lines = <String, String>{
      for (final entry in widget.lineLabels.entries)
        if (entry.value.trim().isNotEmpty &&
            widget.episodes.any(
              (card) => card.watchUrl.queryParameters['line'] == entry.key,
            ))
          entry.key: entry.value,
    };
    final lineRows = widget.episodes
        .where((card) => (card.watchUrl.queryParameters['line'] ?? '') == _line)
        .toList();
    final rows = lineRows;
    final currentIndex = rows.indexWhere(
      (card) => card.isCurrent(widget.currentWatch),
    );
    final range =
        (_range ??
                (currentIndex < 0 ? 0 : currentIndex ~/ videoEpisodeRangeSize))
            .clamp(
              0,
              rows.isEmpty ? 0 : (rows.length - 1) ~/ videoEpisodeRangeSize,
            );
    final start = rows.length > videoEpisodeRangeSize
        ? range * videoEpisodeRangeSize
        : 0;
    final visibleRows = rows.skip(start).take(videoEpisodeRangeSize).toList();
    final selectable = visibleRows
        .where((card) => !_availability.episode(card.watchUrl).downloading)
        .map(_identity)
        .whereType<Uri>()
        .toSet();
    final allSelected =
        selectable.isNotEmpty && selectable.every(_selected.contains);
    return VideoDownloadPanel(
      title: t.videoPlayback.downloadEpisodes,
      onClose: () => Navigator.pop(context),
      continuing:
          _queueing ||
          VideoExportRecords.sessionTaskSnapshot().any(
            (row) =>
                _queuedKeys.contains(row['key']) && videoDownloadIsActive(row),
          ),
      actions: _queuedKeys.isNotEmpty
          ? TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t.common.close),
            )
          : Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                TextButton(
                  key: const ValueKey('download-episodes.cancel'),
                  onPressed: () => Navigator.pop(context),
                  child: Text(t.common.cancel),
                ),
                FilledButton(
                  key: const ValueKey('download-episodes.submit'),
                  onPressed:
                      _selected.isEmpty ||
                          _queueing ||
                          _readingAvailability ||
                          _availabilityFailed
                      ? null
                      : _submit,
                  child: Text(
                    t.videoPlayback.downloadEpisodeCount(
                      count: _selected.length,
                    ),
                  ),
                ),
              ],
            ),
      child: _queuedKeys.isNotEmpty
          ? SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(t.videoPlayback.downloadQueued),
                  VideoDownloadCurrentTasks(
                    taskKeys: _queuedKeys,
                    allowSourceNavigation: false,
                    retryEnabled: !_queueing,
                    checkingResources: _readingAvailability,
                    resourceReadFailed: _availabilityFailed,
                    availability: _readingAvailability || _availabilityFailed
                        ? null
                        : _availability,
                    onReselect: _reselect,
                    onRetry: widget.onRetry != null || widget.onEnqueue != null
                        ? _retry
                        : null,
                  ),
                ],
              ),
            )
          : _queueing
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: LinearProgressIndicator(),
            )
          : ListView.builder(
              key: const ValueKey('download-episodes.list'),
              shrinkWrap: true,
              primary: false,
              itemCount: visibleRows.length + 1,
              itemBuilder: (_, index) {
                if (index == 0) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_queueFailed)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(t.videoDownload.failed),
                        ),
                      if (_readingAvailability) const LinearProgressIndicator(),
                      if (_availabilityFailed)
                        TextButton.icon(
                          onPressed: _readAvailability,
                          icon: const Icon(Icons.refresh),
                          label: Text(t.common.loadingFailed),
                        ),
                      if (lines.length > 1 && lines.containsKey(_line))
                        SettingChoiceTile<String>(
                          key: const ValueKey('download-episodes.line'),
                          title: t.videoPlayback.source,
                          value: _line,
                          items: lines,
                          description: _line == _lastSuccessfulLine
                              ? t.download.lastSuccessfulLine
                              : null,
                          onChanged: (line) => setState(() {
                            _line = line;
                            _range = null;
                          }),
                        )
                      else if (lines[_line] case final String label)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: Text(label),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Wrap(
                          spacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              t.videoPlayback.downloadEpisodesSelected(
                                count: _selected.length,
                              ),
                            ),
                            TextButton(
                              key: const ValueKey(
                                'download-episodes.select-all',
                              ),
                              onPressed: selectable.isEmpty
                                  ? null
                                  : () => setState(() {
                                      if (allSelected) {
                                        _selected.removeAll(selectable);
                                      } else {
                                        _selected.addAll(selectable);
                                      }
                                    }),
                              child: Text(
                                rows.length > videoEpisodeRangeSize
                                    ? (allSelected
                                          ? t.videoPlayback.deselectCurrentRange
                                          : t.videoPlayback.selectCurrentRange)
                                    : (allSelected
                                          ? t.bookshelf.deselectAll
                                          : t.common.selectAll),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (rows.length > videoEpisodeRangeSize)
                        VideoEpisodeRanges(
                          count: rows.length,
                          index: range,
                          onChanged: (value) => setState(() => _range = value),
                        ),
                    ],
                  );
                }
                final card = visibleRows[index - 1];
                final identity = _identity(card);
                final state = _availability.episode(card.watchUrl);
                final status = _episodeStatus(card);
                final previous = state.latestTask;
                return CheckboxListTile(
                  key: ValueKey('download-episodes.item.${card.watchUrl}'),
                  title: Text(card.title),
                  subtitle: identity == null
                      ? Text(t.videoPlayback.downloadEpisodeUnavailable)
                      : status != null
                      ? Text(status)
                      : card.isCurrent(widget.currentWatch)
                      ? Text(t.videoPlayback.currentPlayback)
                      : card.episodeLabel.isNotEmpty &&
                            card.episodeLabel != card.title
                      ? Text(card.episodeLabel)
                      : null,
                  selected: identity != null && _selected.contains(identity),
                  value: identity != null && _selected.contains(identity),
                  secondary:
                      previous != null &&
                          !state.downloading &&
                          !state.downloaded &&
                          (widget.onRetry != null || widget.onEnqueue != null)
                      ? TextButton(
                          onPressed: _queueing
                              ? null
                              : () =>
                                    previous['failureReason'] ==
                                        'qualityUnavailable'
                                    ? _reselect(previous)
                                    : unawaited(_retry(previous)),
                          child: Text(
                            previous['failureReason'] == 'qualityUnavailable'
                                ? t.download.reselect
                                : t.common.retry,
                          ),
                        )
                      : null,
                  onChanged: identity == null || state.downloading
                      ? null
                      : (value) => setState(() {
                          if (value == true) {
                            _selected.add(identity);
                          } else {
                            _selected.remove(identity);
                          }
                        }),
                  controlAffinity: ListTileControlAffinity.leading,
                );
              },
            ),
    );
  }
}
