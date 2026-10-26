import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_watch_history.dart';

ApiVideoItem apiVideoHistoryItem(VideoWatchRecord row) => ApiVideoItem(
  id:
      RegExp(r'/([0-9]+)\.html$').firstMatch(row.watchUrl.path)?.group(1) ??
      row.watchUrl.path,
  title: row.title,
  detailUrl: row.watchUrl.replace(query: ''),
  coverUrl: row.coverUrl,
);

class ApiVideoContinueEntry extends StatefulWidget {
  const ApiVideoContinueEntry({
    super.key,
    required this.source,
    required this.home,
    required this.onOpen,
  });
  final String source;
  final Uri home;
  final Future<void> Function(ApiVideoItem, Uri) onOpen;
  @override
  State<ApiVideoContinueEntry> createState() => _ApiVideoContinueEntryState();
}

class _ApiVideoContinueEntryState extends State<ApiVideoContinueEntry> {
  VideoWatchRecord? _record;
  int _epoch = 0;
  @override
  void initState() {
    super.initState();
    VideoWatchHistory.changes.addListener(_read);
    _read();
  }

  @override
  void dispose() {
    _epoch++;
    VideoWatchHistory.changes.removeListener(_read);
    super.dispose();
  }

  Future<void> _read() async {
    final epoch = ++_epoch;
    try {
      final rows = await VideoWatchHistory.read(widget.source);
      final row = rows
          .where(
            (e) =>
                e.watchUrl.origin == widget.home.origin &&
                !e.completed &&
                e.position > Duration.zero,
          )
          .firstOrNull;
      if (mounted && epoch == _epoch) setState(() => _record = row);
    } catch (_) {
      /* Optional resume never blocks the library. */
    }
  }

  String _time(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) {
    final row = _record;
    if (row == null) return const SizedBox.shrink();
    return ListTile(
      key: const ValueKey('api-continue'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: SizedBox(
        width: 40,
        height: 60,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: ApiVideoPoster(item: apiVideoHistoryItem(row)),
        ),
      ),
      title: Text(
        row.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      subtitle: Text(
        '${t.videoLibrary.continueWatching} · ${_time(row.position)} / ${_time(row.duration)}',
        maxLines: 2,
      ),
      trailing: const Icon(Icons.play_circle_outline_rounded),
      onTap: () => widget.onOpen(apiVideoHistoryItem(row), row.watchUrl),
    );
  }
}

class ApiVideoHistory extends StatefulWidget {
  const ApiVideoHistory({
    super.key,
    required this.source,
    required this.home,
    required this.mode,
    required this.onOpen,
  });
  final String source;
  final Uri home;
  final ApiVideoView mode;
  final Future<void> Function(ApiVideoItem, Uri) onOpen;
  @override
  State<ApiVideoHistory> createState() => _ApiVideoHistoryState();
}

class _ApiVideoHistoryState extends State<ApiVideoHistory> {
  List<VideoWatchRecord>? _records;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    VideoWatchHistory.changes.addListener(_read);
    _read();
  }

  @override
  void dispose() {
    VideoWatchHistory.changes.removeListener(_read);
    super.dispose();
  }

  Future<void> _read() async {
    try {
      final records = await VideoWatchHistory.read(widget.source);
      if (mounted) {
        setState(() {
          _records = records
              .where((e) => e.watchUrl.origin == widget.home.origin)
              .toList();
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _remove([String? path]) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(
          path == null ? t.videoLibrary.clearHistory : t.common.delete,
        ),
        content: Text(
          path == null
              ? t.videoLibrary.clearHistoryConfirm
              : t.videoPlayback.removeWatchHistoryPrompt(
                  title: _records!
                      .firstWhere((e) => e.watchUrl.path == path)
                      .title,
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(t.common.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      if (path == null) {
        await VideoWatchHistory.remove(widget.source, null);
      } else {
        for (final row
            in _records!.where((e) => e.watchUrl.path == path).toList()) {
          await VideoWatchHistory.remove(widget.source, row.watchUrl);
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.videoLibrary.saveFailed)));
      }
    }
  }

  String _time(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) {
    final byPath = <String, VideoWatchRecord>{};
    for (final row in _records ?? <VideoWatchRecord>[]) {
      byPath.putIfAbsent(row.watchUrl.path, () => row);
    }
    final rows = byPath.values.toList();
    final items = [
      for (final row in rows)
        ApiVideoItem(
          id:
              RegExp(
                r'/([0-9]+)\.html$',
              ).firstMatch(row.watchUrl.path)?.group(1) ??
              row.watchUrl.path,
          title: row.title,
          detailUrl: row.watchUrl.replace(query: ''),
          coverUrl: row.coverUrl,
          remarks: '${_time(row.position)} / ${_time(row.duration)}',
          year:
              '${row.updatedAt.toLocal().year}-${row.updatedAt.toLocal().month.toString().padLeft(2, '0')}-${row.updatedAt.toLocal().day.toString().padLeft(2, '0')}',
        ),
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t.videoLibrary.history,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: t.videoLibrary.clearHistory,
                onPressed: rows.isEmpty ? null : () => _remove(),
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              t.videoLibrary.historyHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        Expanded(
          child: _records == null
              ? ApiVideoEmpty(
                  title: _failed ? t.common.loadingFailed : t.common.loading,
                  action: _failed
                      ? TextButton(
                          onPressed: _read,
                          child: Text(t.common.retry),
                        )
                      : null,
                )
              : rows.isEmpty
              ? ApiVideoEmpty(
                  title: t.videoLibrary.historyEmpty,
                  icon: Icons.history,
                )
              : ApiVideoCollection(
                  items: items,
                  mode: widget.mode,
                  storageKey: '${widget.source}.history',
                  onOpen: (item) => unawaited(
                    widget.onOpen(item, rows[items.indexOf(item)].watchUrl),
                  ),
                  onLongPress: (item) => _remove(item.detailUrl.path),
                ),
        ),
      ],
    );
  }
}
