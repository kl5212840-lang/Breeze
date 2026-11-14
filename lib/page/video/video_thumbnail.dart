import 'package:zephyr/service/image_recovery.dart';
import 'package:zephyr/widgets/image_recovery_region.dart';
import 'package:zephyr/widgets/soft_cover_background.dart';
import 'package:zephyr/page/video/video_cover_overlay.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/widgets/collection_cover_fit.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/page/video/omo_network.dart';
import 'package:zephyr/page/video/omo_network_image.dart';
import 'package:zephyr/page/video/omofun_image_url.dart';
import 'package:zephyr/page/video/video_network_scope.dart';
import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';

/// Poster requests are independent of video playback. Missing URLs, loading
/// and failed requests each get a visible state instead of a silent black box.
class VideoThumbnail extends StatefulWidget {
  const VideoThumbnail({
    super.key,
    required this.url,
    required this.referrer,
    this.placeholderIcon = Icons.image_outlined,
    this.cacheWidth = 600,
    this.refreshToken = 0,
    this.refreshHealthyOnTokenChange = false,
    this.retryOnTap = true,
    this.network,
    this.source,
    this.fit = BoxFit.cover,
    this.containBackground = false,
  });
  final String url;
  final String? source;
  final Future<OmoNetworkContext?>? network;
  final IconData placeholderIcon;
  final int cacheWidth;

  /// A successful explicit parent refresh can re-request an unchanged URL.
  final int refreshToken;

  /// Mutable account portraits may change bytes without changing URL. Catalog
  /// covers retain their decoded cache unless a failed request is retried.
  final bool refreshHealthyOnTokenChange;
  final bool retryOnTap;
  final Uri referrer;
  final BoxFit fit;
  final bool containBackground;
  @override
  State<VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<VideoThumbnail> {
  Future<OmoNetworkContext?>? _network;
  Future<OmoNetworkContext?>? _ownedNetwork;

  void _releaseOwnedNetwork() {
    final owned = _ownedNetwork;
    _ownedNetwork = null;
    if (owned != null) {
      unawaited(
        owned.then<void>(
          (value) async => value?.close(),
          onError: (Object _) {},
        ),
      );
    }
  }

  void _syncNetwork() {
    final scope = VideoNetworkScope.maybeOf(context);
    final inherited = widget.source == null || widget.source == scope?.source
        ? scope?.network
        : null;
    final provided = widget.network ?? inherited;
    if (provided != null || widget.source == null) {
      _releaseOwnedNetwork();
      _network = provided;
    } else {
      if (_ownedNetwork == null) {
        final opening = OmoNetworkContext.open(
          null,
          source: widget.source!,
          siteOrigins: [widget.referrer],
        );
        _ownedNetwork = opening;
        unawaited(opening.then<void>((_) {}, onError: (Object _) {}));
      }
      _network = _ownedNetwork;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncNetwork();
  }

  int _attempt = 0;
  int _reloadEpoch = 0;
  bool _refreshing = false;
  bool _failed = false;
  late final ImageRecoveryController _recovery;
  void Function()? _cancelDecodeWait;
  @override
  void initState() {
    super.initState();
    _recovery = ImageRecoveryController(
      active: false,
      imageHost: () => Uri.tryParse(widget.url)?.host,
      retry: () => _retry(automatic: true),
      onChanged: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      },
    );
  }

  Map<String, String> get _headers => {'Referer': widget.referrer.toString()};
  String get _imageUrl =>
      (widget.source ?? VideoNetworkScope.maybeOf(context)?.source) ==
          omoNetworkSource
      ? omofunImageUrl(widget.url)
      : widget.url;
  ImageProvider get _provider {
    final network = _network;
    return ResizeImage.resizeIfNeeded(
      widget.cacheWidth,
      null,
      network != null
          ? OmoNetworkImage(_imageUrl, widget.referrer, network)
          : NetworkImage(_imageUrl, headers: _headers),
    );
  }

  @override
  void didUpdateWidget(covariant VideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.source != oldWidget.source ||
        widget.referrer != oldWidget.referrer ||
        !identical(widget.network, oldWidget.network)) {
      _releaseOwnedNetwork();
      _syncNetwork();
    }
    final identityChanged =
        widget.url != oldWidget.url ||
        widget.source != oldWidget.source ||
        !identical(widget.network, oldWidget.network) ||
        widget.referrer != oldWidget.referrer ||
        widget.cacheWidth != oldWidget.cacheWidth;
    final retryFailed =
        widget.refreshToken != oldWidget.refreshToken &&
        (_failed || widget.refreshHealthyOnTokenChange);
    if (identityChanged || retryFailed) {
      _recovery.reset();
      _cancelDecodeWait?.call();
      _attempt = 0;
      _reloadEpoch++;
      _refreshing = false;
      _failed = false;
      // Catalog refreshes retry failures only. Explicit mutable-avatar consumers
      // can invalidate a same-URL portrait after a profile update or refresh.
      if (retryFailed ||
          (widget.url == oldWidget.url &&
              widget.referrer != oldWidget.referrer)) {
        unawaited(_retry());
      }
    }
  }

  @override
  void dispose() {
    _releaseOwnedNetwork();
    _recovery.dispose();
    _cancelDecodeWait?.call();
    super.dispose();
  }

  Future<void> _retry({bool automatic = false}) async {
    if (!automatic) _recovery.reset();
    _cancelDecodeWait?.call();
    final epoch = ++_reloadEpoch;
    setState(() {
      _refreshing = true;
      _failed = false;
    });
    // Image.network(cacheWidth: ...) resolves a ResizeImage key. Evict that
    // exact provider, including a still-live decoded image, before resolving.
    await _provider.evict();
    if (mounted && epoch == _reloadEpoch) {
      setState(() {
        _refreshing = false;
        _attempt++;
      });
      if (automatic) {
        final stream = _provider.resolve(
          createLocalImageConfiguration(context),
        );
        final done = Completer<void>();
        late final ImageStreamListener listener;
        void stop() {
          stream.removeListener(listener);
          if (!done.isCompleted) {
            done.completeError(const ImageRecoverySuperseded());
          }
        }

        listener = ImageStreamListener(
          (image, _) {
            image.dispose();
            stream.removeListener(listener);
            if (!done.isCompleted) done.complete();
          },
          onError: (Object error, StackTrace? stack) {
            stream.removeListener(listener);
            if (!done.isCompleted) done.completeError(error, stack);
          },
        );
        _cancelDecodeWait = stop;
        stream.addListener(listener);
        try {
          await done.future;
        } finally {
          if (identical(_cancelDecodeWait, stop)) _cancelDecodeWait = null;
        }
      }
    }
  }

  void _retryAfterPageRefresh() {
    if (_failed && !_refreshing) unawaited(_retry());
  }

  // The replacement file belongs to privacy, not the original image stream.
  // Keep it available while the real poster is pending, unsupported or failed;
  // Loading and fallback feedback stays outside the protected pixels.
  Widget _surface(Widget pixels, [Widget? feedback, ImageProvider? image]) =>
      Stack(
        fit: StackFit.expand,
        children: [
          CollectionCoverPrivacy(
            fit: CollectionCoverFitScope.maybeOf(context) ?? widget.fit,
            image: image,
            child: pixels,
          ),
          ?feedback,
        ],
      );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fit = CollectionCoverFitScope.maybeOf(context) ?? widget.fit;
    final softBackground =
        fit == BoxFit.contain &&
        (widget.containBackground ||
            CollectionCoverFitScope.maybeOf(context) != null);
    // This image widget is shared with portraits and folder artwork. The
    // existing poster host opts in resource placeholders without changing them.
    final poster =
        context.findAncestorWidgetOfExactType<VideoCoverOverlay>() != null ||
        widget.placeholderIcon == Icons.play_arrow_rounded;
    final placeholderIcon =
        poster && widget.placeholderIcon == Icons.image_outlined
        ? Icons.play_arrow_rounded
        : widget.placeholderIcon;
    final provider = _provider;
    final uri = Uri.tryParse(_imageUrl);
    final placeholder = Center(
      child: Icon(placeholderIcon, color: colors.onSurfaceVariant),
    );
    final loading = Semantics(
      label: t.common.loading,
      child: Center(
        child: !widget.retryOnTap
            ? Icon(placeholderIcon, color: colors.onSurfaceVariant)
            : MediaQuery.disableAnimationsOf(context)
            ? const Icon(Icons.hourglass_empty_rounded)
            : const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
      ),
    );
    return ImageRecoveryRegion(
      onActiveChanged: _recovery.setActive,
      onPageRefreshed: _retryAfterPageRefresh,
      child: ColoredBox(
        color: colors.surfaceContainerHighest,
        child: uri?.scheme != 'https' || uri?.host.isEmpty != false
            ? _surface(const SizedBox.expand(), placeholder)
            : _refreshing
            ? _surface(const SizedBox.expand(), loading)
            : Image(
                image: provider,
                key: ValueKey('${widget.url}.$_attempt'),
                fit: fit,
                frameBuilder: (_, image, frame, synchronous) {
                  final decoded = frame != null || synchronous;
                  if (decoded) {
                    _failed = false;
                    _recovery.succeeded();
                    if (poster) {
                      VideoDownloadedDetails.rememberDecodedPoster(
                        source:
                            widget.source ??
                            VideoNetworkScope.maybeOf(context)?.source ??
                            '',
                        page: widget.referrer,
                        url: widget.url,
                        provider: provider,
                      );
                    }
                  }
                  return _surface(
                    SoftCoverBackground(
                      image: provider,
                      enabled: decoded && softBackground,
                      child: image,
                    ),
                    decoded ? null : loading,
                    decoded ? provider : null,
                  );
                },
                errorBuilder: (_, error, _) {
                  _failed = true;
                  _recovery.failed(error);
                  // A poster is part of the open-video target. Recover its
                  // request in place or let the page refresh retry the failure.
                  final showRetry =
                      widget.retryOnTap && !poster && !_recovery.recovering;
                  return _surface(
                    const SizedBox.expand(),
                    showRetry
                        ? Center(
                            child: IconButton(
                              tooltip: t.common.retry,
                              onPressed: _retry,
                              icon: Icon(
                                error is UnsupportedVideoImageContent
                                    ? Icons.image_not_supported_outlined
                                    : Icons.refresh_rounded,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          )
                        : placeholder,
                  );
                },
              ),
      ),
    );
  }
}
