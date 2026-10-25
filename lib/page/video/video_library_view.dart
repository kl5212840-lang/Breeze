import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_thumbnail.dart';
import 'package:zephyr/page/video/video_watch_history.dart';

/// Host-owned personal area. Website account actions stay explicit; no account
/// identity or cloud subscription state is invented from local watch history.
class VideoLibraryView extends StatefulWidget {
  const VideoLibraryView({
    super.key,
    required this.source,
    required this.siteHost,
    required this.onOpenVideo,
    required this.onOpenAccount,
    required this.onPlaybackSettings,
    required this.onSourceSettings,
    this.onAccountSync,
    this.revision = 0,
    this.showActions = true,
  });

  final String source, siteHost;
  final int revision;
  final bool showActions;
  final ValueChanged<Uri> onOpenVideo;
  final VoidCallback onOpenAccount, onPlaybackSettings, onSourceSettings;
  final VoidCallback? onAccountSync;

  @override
  State<VideoLibraryView> createState() => _VideoLibraryViewState();
}

class _VideoLibraryViewState extends State<VideoLibraryView> {
  List<VideoWatchRecord>? _records;
  bool _failed = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void didUpdateWidget(covariant VideoLibraryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) _read();
  }

  Future<void> _read() async {
    try {
      final records = await VideoWatchHistory.read(
        widget.source,
      ).timeout(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _records = records
              .where((record) => record.watchUrl.host == widget.siteHost)
              .toList();
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _remove(VideoWatchRecord? record) async {
    if (_deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(
          record == null ? t.videoPlayback.clearWatchHistory : t.common.delete,
        ),
        content: Text(
          record == null
              ? t.videoPlayback.clearWatchHistoryPrompt
              : t.videoPlayback.removeWatchHistoryPrompt(title: record.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              t.common.delete,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _deleting = true);
    try {
      await VideoWatchHistory.remove(widget.source, record?.watchUrl);
      await _read();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.videoPlayback.historyChangeFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  String _time(Duration duration) {
    final seconds = duration.inSeconds;
    final rest = (seconds % 60).toString().padLeft(2, '0');
    if (seconds >= 3600) {
      return '${seconds ~/ 3600}:${((seconds ~/ 60) % 60).toString().padLeft(2, '0')}:$rest';
    }
    return '${seconds ~/ 60}:$rest';
  }

  Widget _record(VideoWatchRecord record) {
    final progress =
        (record.position.inMilliseconds / record.duration.inMilliseconds).clamp(
          0.0,
          1.0,
        );
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      leading: SizedBox(
        width: 104,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: VideoThumbnail(
              url: record.coverUrl?.toString() ?? '',
              referrer: record.watchUrl,
            ),
          ),
        ),
      ),
      title: Text(record.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              record.completed
                  ? t.videoPlayback.watchedComplete
                  : t.videoPlayback.watchPosition(
                      position: _time(record.position),
                      duration: _time(record.duration),
                    ),
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: record.completed ? 1 : progress,
              minHeight: 2,
            ),
          ],
        ),
      ),
      trailing: IconButton(
        tooltip: t.common.delete,
        onPressed: _deleting ? null : () => _remove(record),
        icon: const Icon(Icons.delete_outline_rounded),
      ),
      onTap: () => widget.onOpenVideo(record.watchUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final records = _records;
    return CustomScrollView(
      key: PageStorageKey('video-library.${widget.source}'),
      slivers: [
        SliverList.list(
          children: [
            if (widget.showActions) ...[
              ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: Text(t.videoPlayback.siteAccount),
                subtitle: Text(t.videoPlayback.siteAccountNote),
                trailing: const Icon(Icons.open_in_new_rounded),
                onTap: widget.onOpenAccount,
              ),
              ListTile(
                leading: const Icon(Icons.play_circle_outline_rounded),
                title: Text(t.videoPlayback.playbackSettings),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: widget.onPlaybackSettings,
              ),
              if (widget.onAccountSync != null)
                ListTile(
                  leading: const Icon(Icons.cloud_sync_outlined),
                  title: Text(t.videoAccount.title),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: widget.onAccountSync,
                ),
              ListTile(
                leading: const Icon(Icons.tune_rounded),
                title: Text(t.videoPlayback.sourceSettings),
                subtitle: Text(t.videoPlayback.sourceSettingsNote),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: widget.onSourceSettings,
              ),
              const Divider(),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      t.videoPlayback.watchHistory,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: t.videoPlayback.clearWatchHistory,
                    onPressed: _deleting || records?.isNotEmpty != true
                        ? null
                        : () => _remove(null),
                    icon: const Icon(Icons.delete_sweep_outlined),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_failed)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(t.videoPlayback.historyLoadFailed),
                  TextButton(onPressed: _read, child: Text(t.common.retry)),
                ],
              ),
            ),
          )
        else if (records == null)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (records.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.history_rounded, size: 32),
                  const SizedBox(height: 12),
                  Text(
                    t.videoPlayback.historyEmpty,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.videoPlayback.historyEmptyNote,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          SliverList.builder(
            itemCount: records.length,
            itemBuilder: (_, index) => _record(records[index]),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }
}
