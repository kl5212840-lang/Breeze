import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_card_metadata.dart';
import 'package:zephyr/page/video/video_public_metadata.dart';
import 'package:zephyr/page/video/video_thumbnail.dart';

/// The owner's compact identity is separate from a public creator profile.
class VideoPersonalAccountHeader extends StatelessWidget {
  const VideoPersonalAccountHeader({
    super.key,
    required this.account,
    required this.page,
    this.onAccountSettings,
  });
  final Map<String, dynamic> account;
  final Uri page;
  final VoidCallback? onAccountSettings;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatar = account['avatarUrl']?.toString() ?? '';
    final summary = account['summary']?.toString().trim() ?? '';
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          account['name']?.toString() ?? t.videoPlayback.siteAccount,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium,
        ),
        if (account['status'] != 'signedIn')
          Text(
            t.videoPlayback.accountUnconfirmed,
            style: theme.textTheme.bodySmall,
          )
        else if (summary.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            summary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
    final action = onAccountSettings == null
        ? null
        : TextButton.icon(
            onPressed: onAccountSettings,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            icon: const Icon(Icons.manage_accounts_outlined, size: 18),
            label: Text(t.videoSiteAccount.title),
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        final inline =
            constraints.maxWidth >=
            320 *
                (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
                  1.0,
                  1.8,
                );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipOval(
              child: SizedBox.square(
                dimension: 52,
                child: avatar.isEmpty
                    ? Icon(
                        Icons.account_circle_outlined,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      )
                    : VideoThumbnail(url: avatar, referrer: page),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [identity, if (!inline && action != null) action],
              ),
            ),
            if (inline && action != null) ...[const SizedBox(width: 8), action],
          ],
        );
      },
    );
  }
}

/// Overview is a task hub; its small preview comes only from the observed
/// account history URL. Full libraries retain their original pages and keys.
class VideoPersonalOverview extends StatefulWidget {
  const VideoPersonalOverview({
    super.key,
    required this.account,
    required this.page,
    required this.tabs,
    required this.onTab,
    required this.onVideo,
    required this.readRecent,
    this.readReady = true,
    this.onAccountSettings,
  });
  final Map<String, dynamic> account;
  final Uri page;
  final List<({String title, Uri url})> tabs;
  final ValueChanged<Uri> onTab, onVideo;
  final Future<List<Map<String, dynamic>>> Function(Uri) readRecent;
  final bool readReady;
  final VoidCallback? onAccountSettings;
  @override
  State<VideoPersonalOverview> createState() => _VideoPersonalOverviewState();
}

class _VideoPersonalOverviewState extends State<VideoPersonalOverview> {
  List<Map<String, dynamic>> _recent = const [];
  bool _loading = false, _failed = false;
  int _generation = 0;
  Uri? get _history => widget.tabs
      .where((tab) => tab.url.path.endsWith('/histories'))
      .firstOrNull
      ?.url;
  @override
  void initState() {
    super.initState();
    if (widget.readReady) {
      _read();
    } else {
      _loading = true;
    }
  }

  @override
  void didUpdateWidget(VideoPersonalOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed =
        oldWidget.page != widget.page ||
        oldWidget.tabs.map((tab) => tab.url).join() !=
            widget.tabs.map((tab) => tab.url).join();
    if (changed) _recent = const [];
    if (!widget.readReady) {
      _generation++;
      _loading = _recent.isEmpty;
      _failed = false;
    } else if (changed || !oldWidget.readReady) {
      _read();
    }
  }

  Future<void> _read() async {
    if (!widget.readReady) return;
    final history = _history;
    final generation = ++_generation;
    if (history == null) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final recent = await widget.readRecent(history);
      if (mounted && generation == _generation) {
        setState(() => _recent = recent.take(3).toList());
      }
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _shortcut(String suffix, IconData icon, String title) {
    final target = widget.tabs
        .where((tab) => tab.url.path.endsWith('/$suffix'))
        .firstOrNull
        ?.url;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: ValueKey('video-personal.$suffix'),
        borderRadius: BorderRadius.circular(12),
        onTap: target == null ? null : () => widget.onTab(target),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: target == null
                    ? Theme.of(context).disabledColor
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: target == null
                        ? Theme.of(context).disabledColor
                        : null,
                  ),
                ),
              ),
              if (target == null) const Icon(Icons.remove_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recentRow(Map<String, dynamic> card) {
    final target = Uri.tryParse(card['watchUrl']?.toString() ?? '');
    final enabled =
        target != null &&
        target.host == widget.page.host &&
        target.scheme == 'https' &&
        target.path == '/watch';
    final metadata = VideoPublicMetadata.fromWire(card);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: !enabled ? null : () => widget.onVideo(target),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final coverWidth = (constraints.maxWidth * .32).clamp(
                88.0,
                128.0,
              );
              final title = Text(
                card['title']?.toString() ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              );
              final creator =
                  card['creatorName']?.toString() ??
                  card['subtitle']?.toString() ??
                  '';
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: coverWidth,
                      height: coverWidth * 9 / 16,
                      child: VideoCardCover(
                        url: card['coverUrl']?.toString() ?? '',
                        referrer: widget.page,
                        metadata: metadata,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        title,
                        if (creator.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            creator,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final extras = widget.tabs
        .where(
          (tab) => const [
            'uploaded',
            'uploading',
          ].contains(tab.url.path.split('/').last),
        )
        .toList();
    return ListView(
      key: PageStorageKey('video-personal.overview.${widget.page}'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        VideoPersonalAccountHeader(
          account: widget.account,
          page: widget.page,
          onAccountSettings: widget.onAccountSettings,
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 320 * scale.clamp(1.0, 1.8)
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final item in [
                  (
                    'histories',
                    Icons.history_rounded,
                    t.videoPersonal.histories,
                  ),
                  (
                    'saves',
                    Icons.watch_later_outlined,
                    t.videoPersonal.watchLater,
                  ),
                  ('likes', Icons.thumb_up_outlined, t.videoPersonal.likes),
                  (
                    'playlists',
                    Icons.playlist_play_rounded,
                    t.videoPersonal.playlists,
                  ),
                ])
                  SizedBox(
                    width: width,
                    child: _shortcut(item.$1, item.$2, item.$3),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                t.videoPersonal.recent,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            if (_history case final history?)
              TextButton(
                onPressed: () => widget.onTab(history),
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  padding: EdgeInsets.zero,
                  alignment: AlignmentDirectional.centerEnd,
                ),
                child: Text(t.videoPersonal.viewAll),
              ),
          ],
        ),
        if (_loading)
          Semantics(
            label: t.videoPlayback.analysisLoading,
            child: Column(
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: SizedBox(
                      height: 64,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          )
        else if (_failed || _history == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t.videoPersonal.recentUnavailable,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                if (_history != null)
                  TextButton(onPressed: _read, child: Text(t.common.retry)),
              ],
            ),
          )
        else if (_recent.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              t.videoPersonal.emptyHistory,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          for (final card in _recent) _recentRow(card),
        if (extras.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(height: 1),
          for (final tab in extras)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tab.title),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () => widget.onTab(tab.url),
            ),
        ],
      ],
    );
  }
}
