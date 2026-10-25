import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_thumbnail.dart';
import 'package:zephyr/page/video/video_interaction.dart';

/// Keep part of the next cover visible, including at accessibility text sizes.
double videoShelfCardWidth(BuildContext context, double available) {
  final scale = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
    1.0,
    1.4,
  );
  return (available * .54 * scale).clamp(160.0 * scale, 224.0 * scale);
}

/// One author anchors one lazy horizontal shelf. Collapse and scroll are
/// independent per author and live in the account-scoped PageStorage bucket.
class VideoCreatorShelf extends StatefulWidget {
  const VideoCreatorShelf({
    super.key,
    required this.creator,
    required this.videos,
    required this.page,
    required this.onOpenCreator,
    this.onOpenWorks,
    this.opening = false,
    required this.cardBuilder,
    required this.cardExtent,
  });
  final Map<String, dynamic> creator;
  final List<Map<String, dynamic>> videos;
  final Uri page;
  final VoidCallback onOpenCreator;
  final VoidCallback? onOpenWorks;
  final bool opening;
  final Widget Function(Map<String, dynamic>) cardBuilder;
  final double Function(double) cardExtent;
  @override
  State<VideoCreatorShelf> createState() => _VideoCreatorShelfState();
}

class _VideoCreatorShelfState extends State<VideoCreatorShelf> {
  bool _collapsed = false, _restored = false;
  PageStorageBucket? _storage;
  late ScrollController _scroll;
  double _offset = 0;
  String get _identity => widget.creator['entityKey']?.toString() ?? '';
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_restored) {
      _restored = true;
      _storage = PageStorage.maybeOf(context);
      _collapsed =
          _identity.isNotEmpty &&
          _storage?.readState(
                context,
                identifier: 'creator.collapsed.$_identity',
              ) ==
              true;
      _offset = _identity.isEmpty
          ? 0
          : (_storage?.readState(
                          context,
                          identifier: 'creator.offset.$_identity',
                        )
                        as num?)
                    ?.toDouble() ??
                0;
      if (!_offset.isFinite || _offset < 0) _offset = 0;
      _createScroll();
    }
  }

  @override
  void didUpdateWidget(covariant VideoCreatorShelf oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.creator['entityKey']?.toString() ?? '';
    if (previous != _identity) {
      _scroll.dispose();
      _collapsed =
          _identity.isNotEmpty &&
          _storage?.readState(
                context,
                identifier: 'creator.collapsed.$_identity',
              ) ==
              true;
      _offset = _identity.isEmpty
          ? 0
          : (_storage?.readState(
                          context,
                          identifier: 'creator.offset.$_identity',
                        )
                        as num?)
                    ?.toDouble() ??
                0;
      if (!_offset.isFinite || _offset < 0) _offset = 0;
      _createScroll();
    } else if (oldWidget.videos.isEmpty &&
        widget.videos.isNotEmpty &&
        !_collapsed) {
      // Reattach at the remembered location after a temporary empty refresh.
      _scroll.dispose();
      _createScroll();
    }
    if (oldWidget.videos.length != widget.videos.length) _clampAfterLayout();
  }

  void _createScroll() {
    _scroll = ScrollController(
      initialScrollOffset: _offset,
      keepScrollOffset: false,
    )..addListener(_rememberOffset);
    _clampAfterLayout();
  }

  void _clampAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final position = _scroll.position;
      if (!position.hasContentDimensions) return;
      final target = position.pixels
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if (target != position.pixels) _scroll.jumpTo(target);
      _rememberOffset();
    });
  }

  void _rememberOffset() {
    if (!_scroll.hasClients) return;
    _offset = _scroll.offset;
    if (_identity.isEmpty) return;
    _storage?.writeState(
      context,
      _offset,
      identifier: 'creator.offset.$_identity',
    );
  }

  void _toggle() {
    if (_collapsed && !_scroll.hasClients) {
      _scroll.dispose();
      _createScroll();
    }
    setState(() => _collapsed = !_collapsed);
    if (_identity.isEmpty) return;
    _storage?.writeState(
      context,
      _collapsed,
      identifier: 'creator.collapsed.$_identity',
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name =
        (widget.creator['title'] ?? widget.creator['name'])?.toString() ?? '';
    final avatar =
        (widget.creator['avatarUrl'] ?? widget.creator['coverUrl'])
            ?.toString()
            .trim() ??
        '';
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final scaler = MediaQuery.textScalerOf(context);
              final label = TextPainter(
                text: TextSpan(
                  text: t.videoCommunity.viewCreatorWorks,
                  style: theme.textTheme.labelLarge,
                ),
                textDirection: Directionality.of(context),
                textScaler: scaler,
              )..layout();
              final labelWidth = label.width;
              label.dispose();
              final identityWidth = 60 + scaler.scale(72);
              final inline =
                  constraints.maxWidth >= identityWidth + labelWidth + 44 + 40;
              final identity = Semantics(
                button: true,
                enabled: !widget.opening,
                value: widget.opening ? t.common.loading : null,
                child: InkWell(
                  key: const ValueKey('creator.open'),
                  onTap: widget.opening ? null : widget.onOpenCreator,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        ExcludeSemantics(
                          child: ClipOval(
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  avatar.isEmpty
                                      ? ColoredBox(
                                          color: theme
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          child: Icon(
                                            Icons.person_outline_rounded,
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        )
                                      : VideoThumbnail(
                                          url: avatar,
                                          referrer: widget.page,
                                        ),
                                  if (widget.opening)
                                    ColoredBox(
                                      color: theme.colorScheme.surface
                                          .withValues(alpha: .72),
                                      child: const Center(
                                        child: SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium,
                              ),
                              if (widget.creator['followed'] == true)
                                Text(
                                  t.videoCommunity.following,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
              final works = TextButton(
                key: const ValueKey('creator.works'),
                onPressed: widget.opening
                    ? null
                    : widget.onOpenWorks ?? widget.onOpenCreator,
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Semantics(
                        label: '$name ${t.videoCommunity.viewCreatorWorks}',
                        excludeSemantics: true,
                        child: Text(t.videoCommunity.viewCreatorWorks),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 18),
                  ],
                ),
              );
              final toggle = Semantics(
                key: const ValueKey('creator.toggle'),
                button: true,
                expanded: !_collapsed,
                excludeSemantics: true,
                label: _collapsed
                    ? t.videoCommunity.expandCreator(name: name)
                    : t.videoCommunity.collapseCreator(name: name),
                onTap: _toggle,
                child: IconButton(
                  tooltip: _collapsed
                      ? t.videoCommunity.expandCreator(name: name)
                      : t.videoCommunity.collapseCreator(name: name),
                  onPressed: _toggle,
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  icon: VideoDisclosureIndicator(expanded: !_collapsed),
                ),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: identity),
                      if (inline) ...[const SizedBox(width: 8), works],
                      const SizedBox(width: 4),
                      toggle,
                    ],
                  ),
                  if (!inline)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: works,
                    ),
                ],
              );
            },
          ),
          VideoDisclosureRegion(
            key: ValueKey('creator.disclosure.$_identity'),
            expanded: !_collapsed,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                if (widget.videos.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      t.videoCommunity.emptyLibrary,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = videoShelfCardWidth(
                        context,
                        constraints.maxWidth,
                      );
                      return SizedBox(
                        height: widget.cardExtent(width),
                        child: ListView.separated(
                          controller: _scroll,
                          key: _identity.isEmpty
                              ? ObjectKey(this)
                              : PageStorageKey('creator.videos.$_identity'),
                          primary: false,
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.videos.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, index) => SizedBox(
                            width: width,
                            child: widget.cardBuilder(widget.videos[index]),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
