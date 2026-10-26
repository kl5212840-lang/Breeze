import 'package:material_ui/material_ui.dart';

/// Shared timing for host-owned task sheets; native controls keep their own
/// feedback. No delayed content, stacked entrances or automatic haptics.
abstract final class VideoMotion {
  static Duration feedback(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 160);

  static ChipAnimationStyle chip(BuildContext context) {
    final style = AnimationStyle(duration: feedback(context));
    return ChipAnimationStyle(
      selectAnimation: style,
      enableAnimation: style,
      avatarDrawerAnimation: style,
      deleteDrawerAnimation: style,
    );
  }

  static AnimationStyle sheet(BuildContext context) => AnimationStyle(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 240),
    reverseDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180),
  );
}

/// Short, interruptible acknowledgment in a stable parent button/summary.
class VideoFeedbackLabel extends StatelessWidget {
  const VideoFeedbackLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: AnimatedSwitcher(
      duration: VideoMotion.feedback(context),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [
          if (previous.isNotEmpty) ExcludeSemantics(child: previous.last),
          ?current,
        ],
      ),
      child: Text(text, key: ValueKey(text)),
    ),
  );
}

/// iOS keyboard dismissal can briefly report an inset below zero. Never pass
/// that transient value to Padding or Dialog's inset animation.
MediaQueryData videoOverlayMedia(MediaQueryData media) => media.copyWith(
  viewInsets: EdgeInsets.fromLTRB(
    media.viewInsets.left.clamp(0.0, double.infinity),
    media.viewInsets.top.clamp(0.0, double.infinity),
    media.viewInsets.right.clamp(0.0, double.infinity),
    media.viewInsets.bottom.clamp(0.0, double.infinity),
  ),
);

Future<T?> showVideoTaskSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: 720),
  sheetAnimationStyle: VideoMotion.sheet(context),
  builder: (context) {
    final media = videoOverlayMedia(MediaQuery.of(context));
    return MediaQuery(
      data: media,
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
                  (media.size.height -
                          media.padding.vertical -
                          media.viewInsets.bottom)
                      .clamp(0.0, double.infinity) *
                  .92,
            ),
            child: builder(context),
          ),
        ),
      ),
    );
  },
);

/// Inline disclosure uses right → down; navigation and popup-menu arrows keep
/// their separate meanings. Only the glyph rotates, never its 44pt hit target.
class VideoDisclosureIndicator extends StatelessWidget {
  const VideoDisclosureIndicator({
    super.key,
    required this.expanded,
    this.size = 22,
  });
  final bool expanded;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Transform.flip(
      flipX: Directionality.of(context) == TextDirection.rtl,
      child: AnimatedRotation(
        turns: expanded ? .25 : 0,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : Duration(milliseconds: expanded ? 200 : 160),
        curve: Curves.easeOutCubic,
        child: Icon(Icons.chevron_right_rounded, size: size),
      ),
    ),
  );
}

/// Keep the same horizontal list attached during a reversal. Once fully
/// collapsed, release its children; closed subscriptions don't keep loading.
class VideoDisclosureRegion extends StatefulWidget {
  const VideoDisclosureRegion({
    super.key,
    required this.expanded,
    required this.child,
  });
  final bool expanded;
  final Widget child;
  @override
  State<VideoDisclosureRegion> createState() => _VideoDisclosureRegionState();
}

class _VideoDisclosureRegionState extends State<VideoDisclosureRegion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _extent;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 160),
      value: widget.expanded ? 1 : 0,
    )..addStatusListener(_statusChanged);
    _extent = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOutCubic,
    );
  }

  bool _reduced = false;

  void _statusChanged(AnimationStatus status) {
    if (mounted && status == AnimationStatus.dismissed) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) _controller.value = widget.expanded ? 1 : 0;
  }

  @override
  void didUpdateWidget(covariant VideoDisclosureRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded == widget.expanded) return;
    if (_reduced) {
      _controller.value = widget.expanded ? 1 : 0;
    } else if (widget.expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_statusChanged);
    _extent.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.expanded && _controller.isDismissed) {
      return const SizedBox.shrink();
    }
    return ClipRect(
      child: SizeTransition(
        sizeFactor: _extent,
        alignment: Alignment.topCenter,
        child: IgnorePointer(
          ignoring: !widget.expanded,
          child: ExcludeSemantics(
            excluding: !widget.expanded,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
