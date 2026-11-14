import 'package:zephyr/page/video/source_profile_video_preview.dart';
import 'package:zephyr/page/account/plugin_account_avatar_button.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
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
    this.avatar,
    this.avatarKey,
  });
  final Map<String, dynamic> account;
  final Uri page;
  final VoidCallback? onAccountSettings;
  final Widget? avatar;
  final Key? avatarKey;
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
            PluginAccountAvatarButton(
              key: avatarKey ?? const ValueKey('video-personal.account-avatar'),
              size: 52,
              label: t.videoSiteAccount.title,
              onPressed: onAccountSettings,
              child:
                  this.avatar ??
                  (avatar.isEmpty
                      ? Icon(
                          Icons.account_circle_outlined,
                          size: 48,
                          color: theme.colorScheme.onSurfaceVariant,
                        )
                      : CollectionCoverPrivacyScope(
                          enabled: false,
                          child: VideoThumbnail(url: avatar, referrer: page),
                        )),
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

/// Each declared site library owns one bounded preview and View All target.
/// Full libraries retain their actual URLs and independent scroll state.
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
    this.readCached,
    this.onAccountSettings,
    this.localRecords,
    this.showPrivacyAction = true,
  });
  final Widget? localRecords;
  final bool showPrivacyAction;
  final Map<String, dynamic> account;
  final Uri page;
  final List<({String title, Uri url})> tabs;
  final ValueChanged<Uri> onTab, onVideo;
  final Future<List<Map<String, dynamic>>> Function(Uri) readRecent;
  final bool readReady;
  final Future<List<Map<String, dynamic>>?> Function(Uri)? readCached;
  final VoidCallback? onAccountSettings;
  @override
  State<VideoPersonalOverview> createState() => _VideoPersonalOverviewState();
}

class _VideoPersonalOverviewState extends State<VideoPersonalOverview> {
  static const _sections = ['histories', 'saves', 'likes', 'playlists'];
  final _rows = <Uri, List<Map<String, dynamic>>>{};
  final _loading = <Uri>{}, _failed = <Uri>{};
  final _requests = <Uri, int>{};
  int _generation = 0;
  List<({String title, Uri url})> get _tabs => widget.tabs
      .where(
        (tab) =>
            tab.url.origin == widget.page.origin &&
            _sections.any(
              (kind) =>
                  tab.url.path ==
                  '${widget.page.path.replaceFirst(RegExp(r'/$'), '')}/$kind',
            ) &&
            !tab.url.hasQuery &&
            !tab.url.hasFragment,
      )
      .toList();
  @override
  void initState() {
    super.initState();
    if (widget.readReady || widget.readCached != null) _read();
  }

  @override
  void didUpdateWidget(VideoPersonalOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed =
        oldWidget.page != widget.page ||
        oldWidget.tabs.map((tab) => tab.url).join() !=
            widget.tabs.map((tab) => tab.url).join();
    if (changed || oldWidget.readReady && !widget.readReady) _generation++;
    if (!widget.readReady) _failed.clear();
    if (changed) {
      _rows.clear();
      _failed.clear();
      _loading.clear();
    }
    if ((widget.readReady && (changed || !oldWidget.readReady)) ||
        (changed && widget.readCached != null))
      _read();
  }

  void _read() {
    for (final tab in _tabs) {
      _readSection(tab.url);
    }
  }

  Future<void> _readSection(Uri page) async {
    if (!widget.readReady && widget.readCached == null) return;
    final generation = _generation, request = (_requests[page] ?? 0) + 1;
    _requests[page] = request;
    setState(() {
      _loading.add(page);
      _failed.remove(page);
    });
    try {
      final cached = await widget.readCached?.call(page);
      if (!mounted || generation != _generation || _requests[page] != request)
        return;
      if (cached != null) setState(() => _rows[page] = cached.take(4).toList());
      if (!widget.readReady) return;
      final rows = await widget.readRecent(page);
      if (mounted && generation == _generation && _requests[page] == request) {
        setState(() => _rows[page] = rows.take(4).toList());
      }
    } catch (_) {
      if (mounted && generation == _generation && _requests[page] == request) {
        setState(() => _failed.add(page));
      }
    } finally {
      if (mounted && generation == _generation && _requests[page] == request) {
        setState(() => _loading.remove(page));
      }
    }
  }

  String _title(String kind) => switch (kind) {
    'histories' => t.videoPersonal.histories,
    'saves' => t.videoPersonal.watchLater,
    'likes' => t.videoPersonal.likes,
    _ => t.videoPersonal.playlists,
  };
  IconData _icon(String kind) => switch (kind) {
    'histories' => Icons.history_rounded,
    'saves' => Icons.watch_later_outlined,
    'likes' => Icons.thumb_up_outlined,
    _ => Icons.playlist_play_rounded,
  };
  Uri? _target(Map<String, dynamic> row, String kind) {
    final uri = Uri.tryParse(
      '${row[kind == 'playlists' ? 'pageUrl' : 'watchUrl'] ?? ''}',
    );
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.origin != widget.page.origin ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      return null;
    }
    if (kind == 'playlists') {
      return uri.path == '/playlist' &&
              RegExp(
                r'^[A-Za-z0-9_-]{1,80}$',
              ).hasMatch(uri.queryParameters['list'] ?? '')
          ? uri
          : null;
    }
    return uri.path == '/watch' &&
            RegExp(r'^\d+$').hasMatch(uri.queryParameters['v'] ?? '')
        ? uri
        : null;
  }

  Widget _section(({String title, Uri url}) tab) {
    final kind = tab.url.path.split('/').last;
    return KeyedSubtree(
      key: ValueKey('video-personal.$kind'),
      child: SourceProfileVideoPreview(
        identity: 'site-personal.$kind',
        title: _title(kind),
        icon: _icon(kind),
        responsivePreview: true,
        posterAspectRatio: 2 / 3,
        loading:
            (!_rows.containsKey(tab.url)) &&
            (!widget.readReady || _loading.contains(tab.url)),
        failed: _failed.contains(tab.url),
        onRetry: () => _readSection(tab.url),
        onViewAll: () => widget.onTab(tab.url),
        items: [
          for (final row in _rows[tab.url] ?? const <Map<String, dynamic>>[])
            if (_target(row, kind) case final target?)
              SourceProfileVideoPreviewItem(
                id: target.toString(),
                title: '${row['title'] ?? ''}',
                note: '${row['creatorName'] ?? row['subtitle'] ?? ''}',
                cover: VideoCardCover(
                  url: '${row['coverUrl'] ?? ''}',
                  referrer: widget.page,
                  metadata: VideoPublicMetadata.fromWire(row),
                ),
                onOpen: () => kind == 'playlists'
                    ? widget.onTab(target)
                    : widget.onVideo(target),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => CollectionCoverPrivacyScope(
    child: Column(
      children: [
        if (widget.showPrivacyAction)
          const Align(
            alignment: AlignmentDirectional.centerEnd,
            child: CollectionCoverPrivacyButton(
              key: ValueKey('personal-overview.cover-privacy'),
            ),
          ),
        Expanded(
          child: ListView(
            key: PageStorageKey('video-personal.overview.${widget.page}'),
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              VideoPersonalAccountHeader(
                account: widget.account,
                page: widget.page,
                onAccountSettings: widget.onAccountSettings,
              ),
              const SizedBox(height: 16),
              for (final tab in _tabs) _section(tab),
              if (widget.localRecords != null) widget.localRecords!,
              for (final tab in widget.tabs.where(
                (tab) => const [
                  'uploaded',
                  'uploading',
                ].contains(tab.url.path.split('/').last),
              ))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tab.title),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => widget.onTab(tab.url),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
