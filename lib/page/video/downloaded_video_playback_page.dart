import 'dart:async';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/downloaded_video_playback_queue.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/native_video_page.dart';
import 'package:zephyr/page/video/video_cover_overlay.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/widgets/collection_cover_fit.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/widgets/comic_simplify_entry/cover.dart';
import 'package:zephyr/widgets/soft_cover_background.dart';

/// A device-owned playback route. It never creates a source repository,
/// browser, account, comments client or a remote media resolver.
class DownloadedVideoPlaybackPage extends StatefulWidget {
  const DownloadedVideoPlaybackPage({
    super.key,
    required this.resourceId,
    this.resource,
  });
  final String resourceId;
  final Map<String, dynamic>? resource;

  @override
  State<DownloadedVideoPlaybackPage> createState() =>
      _DownloadedVideoPlaybackPageState();
}

class _DownloadedVideoPlaybackPageState
    extends State<DownloadedVideoPlaybackPage> {
  final _queue = DownloadedVideoPlaybackQueue();
  late Future<DownloadedVideoPlaybackPlan> _loading;
  Future<List<VideoWatchRecord>>? _initialHistory;
  DownloadedVideoPlaybackPlan? _enriched;
  bool _mediaPrepared = false;
  var _historyReadEpoch = 0;
  Map<Uri, VideoWatchRecord> _history = const {};
  Uri? _historyWatch;

  Map<String, dynamic>? get _initialResource =>
      widget.resource?['resourceId'] == widget.resourceId
      ? widget.resource
      : null;

  Future<DownloadedVideoPlaybackPlan> _load() async {
    final epoch = ++_historyReadEpoch;
    final plan = await _queue.open(
      widget.resourceId,
      resource: _initialResource,
    );
    if (!mounted || epoch != _historyReadEpoch) {
      throw StateError('Downloaded playback closed');
    }
    _historyWatch = plan.session.watchUrl;
    _initialHistory = _readHistory(plan.source, epoch);
    return plan;
  }

  Future<List<VideoWatchRecord>> _readHistory(String source, int epoch) async {
    List<VideoWatchRecord> records = const [];
    try {
      // Share the source-scoped read with the player's initial resume lookup.
      // Cover URLs are history metadata and never enter an image widget here.
      records = await VideoWatchHistory.read(source);
    } catch (_) {}
    if (mounted && epoch == _historyReadEpoch) {
      setState(
        () =>
            _history = {for (final record in records) record.watchUrl: record},
      );
    }
    return records;
  }

  Future<void> _mediaReady(DownloadedVideoPlaybackPlan first) async {
    if (!mounted || _mediaPrepared) return;
    final epoch = _historyReadEpoch;
    setState(() => _mediaPrepared = true);
    try {
      final plan = await _queue.enrich(first);
      if (mounted && epoch == _historyReadEpoch)
        setState(() => _enriched = plan);
    } catch (_) {
      // An optional episode list cannot prevent playing this local file.
    }
  }

  Uri? _historyCover(DownloadedVideoPlaybackPlan plan, Uri watch) {
    final row = plan.entries
        .where((entry) => entry.watchUrl == watch)
        .firstOrNull
        ?.row;
    final raw = row?['cover'];
    final cover = raw is String ? Uri.tryParse(raw) : null;
    return cover?.scheme == 'https' &&
            cover?.host.isNotEmpty == true &&
            cover?.userInfo.isEmpty == true
        ? cover
        : _history[watch]?.coverUrl;
  }

  Map<String, String> _historyMetadata(
    DownloadedVideoPlaybackPlan plan,
    NativePlaybackSession session,
  ) {
    final value = plan.entries
        .where((entry) => entry.watchUrl == session.watchUrl)
        .firstOrNull
        ?.metadata;
    return {
      ...?_history[session.watchUrl]?.metadata,
      if (value?.tags.isNotEmpty == true) 'genres': value!.tags.join('、'),
      if (value?.year.isNotEmpty == true) 'year': value!.year,
      if (value?.region.isNotEmpty == true) 'area': value!.region,
    };
  }

  @override
  void initState() {
    super.initState();
    _loading = _load();
  }

  @override
  void dispose() {
    _historyReadEpoch++;
    _queue.dispose();
    super.dispose();
  }

  void _retry() {
    _queue.cancelPending();
    setState(() {
      _enriched = null;
      _mediaPrepared = false;
      _loading = _load();
    });
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<DownloadedVideoPlaybackPlan>(
    future: _loading,
    builder: (context, snapshot) {
      final plan = _enriched ?? snapshot.data;
      if (plan != null) {
        return NativeVideoPage(
          key: ValueKey('downloaded-player.${widget.resourceId}'),
          session: plan.session,
          source: plan.source,
          historyCoverUrl: _historyCover(
            plan,
            _historyWatch ?? plan.session.watchUrl,
          ),
          historyMetadata: (session) => _historyMetadata(plan, session),
          initialHistory: _initialHistory,
          onMediaPrepared: () => unawaited(_mediaReady(plan)),
          onEpisodeChanged: (loaded) {
            if (mounted)
              setState(() => _historyWatch = loaded.session.watchUrl);
          },
          offlineOnly: true,
          autoResourceFallback: false,
          initialEpisodeSequence: plan.sequence,
          onResolutionCancelled: (_) => _queue.cancelPending(),
          loadEpisode: _enriched == null
              ? null
              : (target) async =>
                    (session: await plan.loadEpisode(target), operations: null),
          detailBuilder: (context, session, _, _, tools) {
            final entry = plan.entries
                .where((entry) => entry.card.watchUrl == session.watchUrl)
                .firstOrNull;
            return _DownloadedVideoDetails(
              key: ValueKey(
                'downloaded-details.${entry?.resourceId ?? plan.currentResourceId}',
              ),
              row: entry?.row ?? plan.currentRow,
              session: session,
              tools: tools,
              ensurePoster: _mediaPrepared,
            );
          },
        );
      }
      return _DownloadedVideoPreparation(
        resource: _initialResource,
        onRetry: snapshot.hasError ? _retry : null,
      );
    },
  );
}

String _localPlaybackLabel(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'zh'
    ? '本地播放'
    : 'Offline playback';

class _DownloadedVideoPreparation extends StatelessWidget {
  const _DownloadedVideoPreparation({required this.resource, this.onRetry});

  final Map<String, dynamic>? resource;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final player = ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: onRetry == null
                ? Semantics(
                    label: t.videoPlayback.preparingMedia,
                    child: const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 44, 20, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          zh
                              ? '本地视频不可用，请检查下载文件是否仍然存在。'
                              : 'This local video is unavailable. Check that the downloaded file still exists.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                        TextButton(
                          onPressed: onRetry,
                          child: Text(t.common.retry),
                        ),
                      ],
                    ),
                  ),
          ),
          const Align(
            alignment: AlignmentDirectional.topStart,
            child: BackButton(color: Colors.white),
          ),
        ],
      ),
    );
    final row = resource;
    final details = row != null
        ? _DownloadedVideoDetails(row: row, tools: const SizedBox.shrink())
        : Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: Text(_localPlaybackLabel(context)),
            ),
          );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: VideoPageSafeArea(
          child: LayoutBuilder(
            builder: (_, constraints) =>
                constraints.maxWidth > constraints.maxHeight
                ? Row(
                    children: [
                      Expanded(flex: 3, child: player),
                      Expanded(flex: 2, child: details),
                    ],
                  )
                : Column(
                    children: [
                      AspectRatio(aspectRatio: 16 / 9, child: player),
                      Expanded(child: details),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _DownloadedVideoDetails extends StatefulWidget {
  const _DownloadedVideoDetails({
    super.key,
    required this.row,
    this.session,
    required this.tools,
    this.ensurePoster = false,
  });
  final Map<String, dynamic> row;
  final NativePlaybackSession? session;
  final Widget tools;
  final bool ensurePoster;
  @override
  State<_DownloadedVideoDetails> createState() =>
      _DownloadedVideoDetailsState();
}

class _DownloadedVideoDetailsState extends State<_DownloadedVideoDetails> {
  late Future<DownloadedVideoMetadata?> _metadata;
  @override
  void initState() {
    super.initState();
    _metadata = VideoDownloadedDetails.readForResource(widget.row);
    VideoDownloadedDetails.posterChanges.addListener(_reloadPoster);
    if (widget.ensurePoster) unawaited(_ensurePoster());
  }

  @override
  void didUpdateWidget(covariant _DownloadedVideoDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ensurePoster && !oldWidget.ensurePoster)
      unawaited(_ensurePoster());
  }

  Future<void> _ensurePoster() async {
    final known = await _metadata.catchError((Object _) => null);
    if (!mounted || known?.localCoverPath != null) return;
    await VideoDownloadedDetails.ensureLocalPoster(widget.row);
  }

  void _reloadPoster() {
    if (mounted)
      setState(
        () => _metadata = VideoDownloadedDetails.readForResource(widget.row),
      );
  }

  @override
  void dispose() {
    VideoDownloadedDetails.posterChanges.removeListener(_reloadPoster);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<DownloadedVideoMetadata?>(
    future: _metadata,
    builder: (context, snapshot) {
      final data = snapshot.data;
      final zh = Localizations.localeOf(context).languageCode == 'zh';
      final theme = Theme.of(context);
      final title = data?.title.isNotEmpty == true
          ? data!.title
          : widget.row['publicWorkTitle'] as String? ??
                widget.session?.title ??
                widget.row['title'] as String? ??
                '';
      final episode =
          data?.episodeLabel ??
          widget.row['publicEpisodeLabel'] as String? ??
          '';
      final quality = data?.quality ?? (widget.row['quality'] as String? ?? '');
      final durationMs = data?.durationMs ?? widget.row['durationMs'];
      final duration = durationMs is int && durationMs > 0
          ? formatKnownVideoDuration(Duration(milliseconds: durationMs))
          : knownVideoDurationText(
              data?.sourceDuration ??
                  widget.row['sourceDuration'] as String? ??
                  '',
            );
      final storedAt = widget.row['at'];
      final at =
          data?.downloadedAt?.toLocal() ??
          (storedAt is int
              ? DateTime.fromMillisecondsSinceEpoch(storedAt).toLocal()
              : null);
      final description =
          data?.description ?? widget.session?.description ?? '';
      final tags = data?.tags ?? widget.session?.tags ?? const <String>[];
      final creator = data?.creatorName ?? '';
      final downloadedDate = at == null
          ? ''
          : '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';
      final releaseDate = data?.releaseDate ?? '';
      final showRelease =
          releaseDate.isNotEmpty && releaseDate != downloadedDate;
      final hanime =
          data != null &&
          VideoDownloadedDetails.isHanimeWatch(data.source, data.watchUrl);
      final secondary = [
        if (data?.sourceDisplayName.isNotEmpty == true) data!.sourceDisplayName,
        if (quality.isNotEmpty) quality,
        if (duration.isNotEmpty) duration,
      ];
      final publication = [
        if (data?.year.isNotEmpty == true &&
            (releaseDate.isEmpty || !releaseDate.startsWith(data!.year)))
          data!.year,
        if (data?.region.isNotEmpty == true) data!.region,
        if (showRelease)
          hanime
              ? t.changelog.publishedAt(date: releaseDate)
              : '${t.videoLibrary.released} $releaseDate',
      ];
      return ListView(
        key: const PageStorageKey('downloaded-video.basic-details'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DownloadedLocalCover(
                path: data?.localCoverPath,
                duration: duration,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      key: const ValueKey('downloaded-video.title'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _localPlaybackLabel(context),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (creator.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${t.bookshelf.facets.author} · $creator',
                        key: const ValueKey('downloaded-video.creator'),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                    if (episode.isNotEmpty && episode != title) ...[
                      const SizedBox(height: 4),
                      Text(episode, style: theme.textTheme.bodyMedium),
                    ],
                    if (secondary.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          for (final value in secondary)
                            Text(
                              value,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (downloadedDate.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${zh ? '下载于' : 'Downloaded'} $downloadedDate',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (publication.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              publication.join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          widget.tools,
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(tags.join(' · '), style: theme.textTheme.bodyMedium),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              description,
              key: const ValueKey('downloaded-video.description'),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      );
    },
  );
}

/// Same protection/fit contract as other collection posters, using one local
/// provider for both foreground and contain background. Never a network image.
class _DownloadedLocalCover extends StatelessWidget {
  const _DownloadedLocalCover({required this.path, required this.duration});
  final String? path;
  final String duration;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final image = path == null
        ? null
        : createCoverImageProvider(
            path!,
            width: (80 * pixelRatio).ceil().clamp(1, 512),
            height: (120 * pixelRatio).ceil().clamp(1, 512),
          );
    final placeholder = ColoredBox(
      color: colors.surfaceContainerLow,
      child: Icon(
        Icons.play_arrow_rounded,
        size: 22,
        color: colors.onSurfaceVariant,
      ),
    );
    return RepaintBoundary(
      key: const ValueKey('downloaded-video.cover'),
      child: SizedBox(
        width: image == null ? 40 : 80,
        height: image == null ? 60 : 120,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CollectionCoverFitBuilder(
            builder: (context, fit) => CollectionCoverPrivacyScope(
              child: VideoCoverOverlay(
                durationText: duration,
                child: CollectionCoverPrivacy(
                  fit: fit,
                  image: image,
                  mosaicPlaceholder: placeholder,
                  child: image == null
                      ? placeholder
                      : SoftCoverBackground(
                          image: image,
                          enabled: fit == BoxFit.contain,
                          child: Image(
                            image: image,
                            fit: fit,
                            errorBuilder: (_, _, _) => placeholder,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
