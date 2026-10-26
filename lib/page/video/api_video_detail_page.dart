import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/native_video_page.dart';
import 'package:zephyr/page/video/video_episode_sequence.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/page/video/video_library_folder_picker.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_system_share.dart';
import 'package:zephyr/page/video/video_watch_history.dart';

class ApiVideoDetailPage extends StatefulWidget {
  const ApiVideoDetailPage({
    super.key,
    required this.repository,
    required this.initialItem,
    this.resume,
    this.store,
  });
  final ApiVideoRepository repository;
  final ApiVideoItem initialItem;
  final Uri? resume;
  final VideoLibraryStore? store;
  @override
  State<ApiVideoDetailPage> createState() => _ApiVideoDetailPageState();
}

class _ApiVideoDetailPageState extends State<ApiVideoDetailPage> {
  late ApiVideoItem _item = widget.initialItem;
  VideoLibraryStore get _store => widget.store ?? VideoLibraryStore.shared;
  VideoLibrarySnapshot? _library;
  NativePlaybackSession? _initialSession;
  Uri? _currentWatch;
  final _candidateItems = <Uri, ApiVideoItem>{};
  bool _failed = false, _expanded = false, _saving = false;
  int _epoch = 0, _libraryEpoch = 0;
  @override
  void initState() {
    super.initState();
    _store.addListener(_readLibrary);
    _readLibrary();
    _load();
  }

  @override
  void dispose() {
    _epoch++;
    _libraryEpoch++;
    _store.removeListener(_readLibrary);
    super.dispose();
  }

  Future<void> _readLibrary() async {
    final epoch = ++_libraryEpoch;
    try {
      final library = await _store.read();
      if (mounted && epoch == _libraryEpoch) setState(() => _library = library);
    } catch (_) {
      if (mounted && epoch == _libraryEpoch) setState(() => _library = null);
    }
  }

  Future<void> _load() async {
    final epoch = ++_epoch;
    setState(() => _failed = false);
    try {
      final item = await widget.repository.item(_item.id);
      if (!mounted || epoch != _epoch) return;
      if (item.lines.isEmpty) throw StateError('No episodes');
      final line = item.lines.first;
      final candidate = item.session(line.id, line.episodes.first.id);
      Uri target = VideoEpisodeSequence(
        candidate.episodes,
      ).items.first.watchUrl;
      try {
        final records = await VideoWatchHistory.read(widget.repository.source);
        final recent =
            widget.resume ??
            records
                .where(
                  (r) =>
                      r.watchUrl.path == item.detailUrl.path &&
                      r.watchUrl.origin == item.detailUrl.origin,
                )
                .map((r) => r.watchUrl)
                .firstOrNull;
        if (recent != null &&
            item.lines.any(
              (l) =>
                  l.id == recent.queryParameters['line'] &&
                  l.episodes.any(
                    (e) => e.id == recent.queryParameters['episode'],
                  ),
            )) {
          target = recent;
        }
      } catch (_) {
        /* Optional local history never blocks a real source. */
      }
      if (!mounted || epoch != _epoch) return;
      final session = item.session(
        target.queryParameters['line']!,
        target.queryParameters['episode']!,
      );
      setState(() {
        _item = item;
        _initialSession = session;
        _currentWatch = session.watchUrl;
      });
      unawaited(
        _store
            .observeItems(widget.repository.source, [item], acknowledge: true)
            .catchError((Object _) {}),
      );
    } catch (_) {
      if (mounted && epoch == _epoch) setState(() => _failed = true);
    }
  }

  Future<NativeEpisodeLoad> _loadEpisode(
    Uri target, {
    bool refresh = false,
  }) async {
    if (target.origin != widget.repository.home.origin ||
        target.path != _item.detailUrl.path) {
      throw const FormatException('Episode outside this item');
    }
    final epoch = _epoch;
    final result = await widget.repository.session(
      _item.id,
      lineId: target.queryParameters['line'],
      episodeId: target.queryParameters['episode'],
      refresh: refresh,
    );
    if (!mounted || epoch != _epoch) throw StateError('Video page closed');
    _candidateItems[result.session.watchUrl] = result.item;
    return (session: result.session, operations: null);
  }

  Future<void> _favorite() async {
    if (_saving) return;
    if (_library?.contains(widget.repository.source, _item.id) == true) {
      await showVideoFolderPicker(
        context,
        source: widget.repository.source,
        item: _item,
        store: _store,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _store.setFavorite(widget.repository.source, _item, true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.videoLibrary.saved),
            action: SnackBarAction(
              label: t.videoLibrary.classify,
              onPressed: () => showVideoFolderPicker(
                context,
                source: widget.repository.source,
                item: _item,
                store: _store,
              ),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(videoLibraryError(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _share(BuildContext anchorContext) async {
    final box = anchorContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final result = await VideoSystemShare.share(
      video: _item.detailUrl,
      title: _item.title,
      anchor: box.localToGlobal(Offset.zero) & box.size,
    );
    if (!mounted) return;
    if (result == VideoShareStatus.failed ||
        result == VideoShareStatus.unavailable) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.videoCommunity.shareFailed)));
    }
  }

  Future<void> _follow() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final snapshot = await _store.read();
      final following = snapshot.follows(
        VideoLibraryStore.itemKey(widget.repository.source, _item.id),
      );
      await _store.setFollow(widget.repository.source, _item, !following);
      if (mounted && !following) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.videoLibrary.followEnabled)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(videoLibraryError(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _website() => context.pushRoute(
    WebViewRoute(info: [_item.title, _item.detailUrl.toString()]),
  );
  Widget _favoriteIcon({bool light = false}) => NativeVideoIconButton(
    light: light,
    tooltip: _library?.contains(widget.repository.source, _item.id) == true
        ? t.videoLibrary.saved
        : t.videoLibrary.addFavorite,
    symbol: _library?.contains(widget.repository.source, _item.id) == true
        ? 'star.fill'
        : 'star',
    icon: _library?.contains(widget.repository.source, _item.id) == true
        ? Icons.star_rounded
        : Icons.star_outline_rounded,
    onPressed: _saving ? null : _favorite,
  );
  @override
  Widget build(BuildContext context) {
    final session = _initialSession;
    if (session == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const SourceBackButton(),
          title: Text(
            _item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: ApiVideoEmpty(
          title: _failed ? t.videoLibrary.mediaUnavailable : t.common.loading,
          action: _failed
              ? Wrap(
                  spacing: 12,
                  children: [
                    TextButton(onPressed: _load, child: Text(t.common.retry)),
                    TextButton(
                      onPressed: _website,
                      child: Text(t.videoLibrary.openWebsite),
                    ),
                  ],
                )
              : null,
        ),
      );
    }
    return NativeVideoPage(
      key: ValueKey('api-player.${_item.id}'),
      session: session,
      source: widget.repository.source,
      loadEpisode: (target) => _loadEpisode(target),
      refreshSession: () async =>
          (await _loadEpisode(_currentWatch!, refresh: true)).session,
      onEpisodeChanged: (loaded) {
        if (mounted) {
          setState(() {
            _currentWatch = loaded.session.watchUrl;
            _item = _candidateItems.remove(_currentWatch) ?? _item;
          });
        }
      },
      extraPlayerActions: (context, _) => [
        ListenableBuilder(
          listenable: _store,
          builder: (_, _) => _favoriteIcon(light: true),
        ),
        Builder(
          builder: (anchor) => NativeVideoIconButton(
            light: true,
            tooltip: t.videoCommunity.share,
            symbol: 'arrowshape.turn.up.right',
            icon: Icons.reply_rounded,
            mirrorFallbackIcon: true,
            onPressed: () => _share(anchor),
          ),
        ),
      ],
      detailBuilder: (context, current) => _details(context, current),
    );
  }

  Widget _details(BuildContext context, NativePlaybackSession session) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    final saved =
        _library?.contains(widget.repository.source, _item.id) == true;
    final following =
        _library?.follows(
          VideoLibraryStore.itemKey(widget.repository.source, _item.id),
        ) ==
        true;
    Widget info(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: SelectableText(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
    final available =
        _item.lines
            .where(
              (line) => line.id == session.watchUrl.queryParameters['line'],
            )
            .firstOrNull
            ?.episodes
            .length ??
        0;
    return ListView(
      key: PageStorageKey('api-detail.${_item.id}'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Text(
          _item.title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
        if (_item.summary.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _item.summary.join(' · '),
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
        if (_item.remarks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_item.remarks, style: theme.textTheme.titleSmall),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.tonalIcon(
              onPressed: _saving ? null : _favorite,
              icon: Icon(
                saved ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 20,
              ),
              label: Text(
                saved ? t.videoLibrary.saved : t.videoLibrary.addFavorite,
              ),
            ),
            if (saved)
              TextButton.icon(
                onPressed: _saving ? null : _favorite,
                icon: const Icon(Icons.folder_open_outlined, size: 20),
                label: Text(t.videoLibrary.classify),
              ),
            if (_item.canFollow || following)
              OutlinedButton.icon(
                onPressed: _saving ? null : _follow,
                icon: Icon(
                  following
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_none_rounded,
                  size: 20,
                ),
                label: Text(
                  following ? t.videoLibrary.followed : t.videoLibrary.follow,
                ),
              ),
            Builder(
              builder: (anchor) => TextButton.icon(
                onPressed: () => _share(anchor),
                icon: const Icon(Icons.ios_share_rounded, size: 20),
                label: Text(t.videoCommunity.share),
              ),
            ),
          ],
        ),
        if (_item.sourceViews != null || _item.sourceRating != null) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              if (_item.sourceViews != null)
                Text(
                  t.videoLibrary.sourceViews(count: _item.sourceViews!),
                  style: theme.textTheme.bodySmall,
                ),
              if (_item.sourceRating != null)
                Text(
                  t.videoLibrary.sourceRating(
                    score: _item.sourceRating!,
                    count: _item.sourceRatingCount!,
                  ),
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ],
        if (_item.doubanScore != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Tooltip(
              message: t.videoLibrary.ratingSourceHint,
              child: TextButton.icon(
                onPressed: () => context.pushRoute(
                  WebViewRoute(
                    info: [
                      '豆瓣',
                      'https://movie.douban.com/subject/${_item.doubanId}/',
                    ],
                  ),
                ),
                icon: const Icon(Icons.star_rounded, size: 18),
                label: Text(
                  t.videoLibrary.doubanRating(score: _item.doubanScore!),
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),
        Text(t.videoLibrary.synopsis, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        AnimatedSize(
          duration: VideoMotion.feedback(context),
          alignment: AlignmentDirectional.topStart,
          child: Text(
            _item.description.isEmpty
                ? t.videoLibrary.noSynopsis
                : _item.description,
            maxLines: _expanded ? null : 5,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ),
        if (_item.description.length > 140)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: VideoDisclosureIndicator(expanded: _expanded, size: 18),
              label: Text(
                _expanded
                    ? t.videoPlayback.collapseDescription
                    : t.videoPlayback.expandDescription,
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (_item.alternateTitle.isNotEmpty &&
            _item.alternateTitle != _item.title)
          info(t.videoLibrary.alternateTitle, _item.alternateTitle),
        if (_item.genres.isNotEmpty) info(t.videoLibrary.genres, _item.genres),
        if (_item.directors.isNotEmpty)
          info(t.videoLibrary.director, _item.directors),
        if (_item.writers.isNotEmpty)
          info(t.videoLibrary.writers, _item.writers),
        if (_item.actors.isNotEmpty)
          info(t.videoLibrary.starring, _item.actors),
        if (_item.language.isNotEmpty)
          info(t.videoLibrary.language, _item.language),
        if (_item.releaseDate.isNotEmpty)
          info(t.videoLibrary.released, _item.releaseDate),
        if (_item.updatedAt.isNotEmpty)
          info(t.videoLibrary.resourceUpdated, _item.updatedAt),
        if (available > 0)
          info(
            t.videoLibrary.allEpisodes,
            [
              t.videoLibrary.availableEpisodes(count: available),
              if (_item.plannedEpisodes > available)
                t.videoLibrary.plannedEpisodes(count: _item.plannedEpisodes),
            ].join(' · '),
          ),
        const SizedBox(height: 16),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: _website,
            icon: const Icon(Icons.open_in_browser, size: 20),
            label: Text(t.videoLibrary.openWebsite),
          ),
        ),
      ],
    );
  }
}
