import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/page/video/video_detail_action.dart';

/// Native-site favorites and this local action are independent. Construct the
/// persisted item from an allowlist of public metadata, never media sources.
class VideoLocalFavoriteAction extends StatefulWidget {
  const VideoLocalFavoriteAction({
    super.key,
    required this.source,
    required this.session,
    this.store,
    this.detailAction = false,
    this.compact = false,
    this.siteFavorited,
    this.onSiteFavorite,
    this.destinationRow = false,
    this.onOpenDestinations,
  });
  final String source;
  final NativePlaybackSession session;
  final VideoLibraryStore? store;
  final bool detailAction, compact, destinationRow;
  final bool? siteFavorited;
  final VoidCallback? onSiteFavorite;
  final ValueChanged<bool>? onOpenDestinations;
  @override
  State<VideoLocalFavoriteAction> createState() =>
      _VideoLocalFavoriteActionState();
}

class _VideoLocalFavoriteActionState extends State<VideoLocalFavoriteAction> {
  VideoLibraryStore get _store => widget.store ?? VideoLibraryStore.shared;
  bool? _saved;
  bool _busy = false, _readFailed = false, _destinationOpen = false;
  String? _notice;
  Timer? _noticeTimer;
  int _readEpoch = 0, _writeEpoch = 0;

  ApiVideoItem? get _item {
    final page = videoPublicPage(widget.session.watchUrl);
    final id = page?.queryParameters['v'] ?? '';
    if (widget.source.trim().isEmpty ||
        widget.source.length > 200 ||
        page?.path != '/watch' ||
        id.isEmpty ||
        widget.session.title.trim().isEmpty) {
      return null;
    }
    return ApiVideoItem(
      id: id,
      title: widget.session.title,
      detailUrl: page!,
      coverUrl: apiVideoHttps(widget.session.coverUrl?.toString()),
      description: widget.session.description,
      genres: widget.session.tags.join(','),
      sourceViews: widget.session.metadata.viewCount,
      sourceDuration: widget.session.metadata.duration ?? '',
      releaseDate: widget.session.metadata.publishedDate ?? '',
    );
  }

  String get _identity =>
      '${widget.source}\n${videoPublicPage(widget.session.watchUrl)}';

  @override
  void initState() {
    super.initState();
    _store.addListener(_read);
    unawaited(_read());
  }

  @override
  void didUpdateWidget(covariant VideoLocalFavoriteAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      (oldWidget.store ?? VideoLibraryStore.shared).removeListener(_read);
      _store.addListener(_read);
    }
    if (oldWidget.source != widget.source ||
        videoPublicPage(oldWidget.session.watchUrl) !=
            videoPublicPage(widget.session.watchUrl) ||
        oldWidget.store != widget.store) {
      _readEpoch++;
      _writeEpoch++;
      _noticeTimer?.cancel();
      _saved = null;
      _busy = false;
      _readFailed = false;
      _notice = null;
      unawaited(_read());
    }
  }

  Future<void> _read() async {
    final epoch = ++_readEpoch, identity = _identity, item = _item;
    if (item == null) return;
    final recovering = _readFailed;
    if (recovering) setState(() => _readFailed = false);
    try {
      final snapshot = await _store.read();
      if (mounted && epoch == _readEpoch && identity == _identity) {
        setState(() {
          _saved = snapshot.contains(widget.source, item.id);
          _readFailed = false;
          if (recovering) _notice = null;
        });
        if (recovering) _noticeTimer?.cancel();
      }
    } catch (_) {
      if (mounted && epoch == _readEpoch && identity == _identity) {
        setState(() => _readFailed = true);
        _showError(t.common.loadingFailed);
      }
    }
  }

  void _showError(String message) {
    _noticeTimer?.cancel();
    setState(() => _notice = message);
    _noticeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  Future<void> _toggle() async {
    final item = _item;
    if (_busy || _saved == null || item == null) return;
    final source = widget.source, identity = _identity, epoch = ++_writeEpoch;
    final desired = !_saved!;
    setState(() => _busy = true);
    try {
      await _store.setFavorite(source, item, desired);
      if (mounted && epoch == _writeEpoch && identity == _identity) {
        setState(() => _saved = desired);
      }
    } catch (_) {
      if (mounted && epoch == _writeEpoch && identity == _identity) {
        _showError(t.videoLibrary.saveFailed);
      }
    } finally {
      if (mounted && epoch == _writeEpoch && identity == _identity) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  void dispose() {
    _readEpoch++;
    _writeEpoch++;
    _noticeTimer?.cancel();
    _store.removeListener(_read);
    super.dispose();
  }

  Future<void> _chooseDestination() async {
    if (_destinationOpen) return;
    _destinationOpen = true;
    final hold = widget.onOpenDestinations;
    hold?.call(true);
    final source = widget.source, identity = _identity;
    bool? openSite;
    ModalRoute<bool>? route;
    try {
      openSite = await showVideoTaskSheet<bool>(
        context: context,
        useRootNavigator: true,
        builder: (sheetContext) {
          route = ModalRoute.of<bool>(sheetContext);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  key: const ValueKey('video.site-favorite'),
                  minTileHeight: 48,
                  leading: const Icon(Icons.playlist_add_rounded),
                  title: Text(t.videoCommunity.siteFavorite),
                  trailing: widget.siteFavorited == true
                      ? Icon(
                          Icons.check_rounded,
                          semanticLabel: t.videoCommunity.siteFavorited,
                        )
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(sheetContext).pop(true),
                ),
                VideoLocalFavoriteAction(
                  source: source,
                  session: widget.session,
                  store: widget.store,
                  destinationRow: true,
                ),
              ],
            ),
          );
        },
      );
      await route?.completed;
    } finally {
      _destinationOpen = false;
      hold?.call(false);
    }
    if (openSite == true && mounted && _identity == identity) {
      widget.onSiteFavorite?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onSiteFavorite != null) {
      final selected = widget.siteFavorited == true || _saved == true;
      return VideoDetailAction(
        buttonKey: const ValueKey('video-favorite'),
        compact: widget.compact,
        label: t.videoCommunity.favorite,
        selected: selected,
        icon: selected ? Icons.star_rounded : Icons.star_outline_rounded,
        onPressed: widget.onOpenDestinations == null
            ? null
            : _item == null
            ? widget.onSiteFavorite
            : _chooseDestination,
      );
    }
    if (_item == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.destinationRow)
          ListTile(
            key: const ValueKey('video.local-favorite'),
            minTileHeight: 48,
            selected: _saved == true,
            leading: Icon(
              _readFailed
                  ? Icons.refresh_rounded
                  : Icons.bookmark_outline_rounded,
            ),
            title: Text(t.videoSource.localFavorites),
            trailing: _busy || _saved == null && !_readFailed
                ? SizedBox.square(
                    dimension: 18,
                    child: MediaQuery.disableAnimationsOf(context)
                        ? const Icon(Icons.hourglass_empty_rounded, size: 18)
                        : const CircularProgressIndicator(strokeWidth: 2),
                  )
                : _saved == true
                ? Icon(
                    Icons.check_rounded,
                    semanticLabel: t.videoSource.localSaved,
                  )
                : null,
            onTap: _busy || _saved == null && !_readFailed
                ? null
                : _readFailed || _saved == null
                ? _read
                : _toggle,
          )
        else if (widget.detailAction)
          VideoDetailAction(
            buttonKey: const ValueKey('video.local-favorite'),
            compact: widget.compact,
            label: _saved == true
                ? t.videoSource.localSaved
                : t.videoSource.localFavorites,
            selected: _saved == true,
            busy: _busy || _saved == null && !_readFailed,
            icon: _readFailed
                ? Icons.refresh_rounded
                : _saved == true
                ? Icons.star_rounded
                : Icons.star_outline_rounded,
            onPressed: _busy || _saved == null && !_readFailed
                ? null
                : _readFailed || _saved == null
                ? _read
                : _toggle,
          )
        else
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Semantics(
              selected: _saved,
              child: TextButton.icon(
                key: const ValueKey('video.local-favorite'),
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                onPressed: _busy || _saved == null && !_readFailed
                    ? null
                    : _readFailed || _saved == null
                    ? _read
                    : _toggle,
                icon: _busy || _saved == null && !_readFailed
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: MediaQuery.disableAnimationsOf(context)
                            ? const Icon(
                                Icons.hourglass_empty_rounded,
                                size: 18,
                              )
                            : const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _readFailed
                            ? Icons.refresh_rounded
                            : _saved == true
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 22,
                      ),
                label: VideoFeedbackLabel(
                  _saved == true
                      ? t.videoSource.localSaved
                      : t.videoSource.localFavorites,
                ),
              ),
            ),
          ),
        if (_notice != null)
          VideoActionNotice(
            message: _notice!,
            onClose: () {
              _noticeTimer?.cancel();
              setState(() => _notice = null);
            },
          ),
      ],
    );
  }
}
