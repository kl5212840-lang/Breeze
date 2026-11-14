import 'dart:math' as math;
import 'package:zephyr/page/video/omo_network.dart';
import 'package:zephyr/page/video/video_network_scope.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_browse_theme.dart';
import 'package:zephyr/widgets/native_material_surface.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/video_modal_exit.dart';
import 'package:zephyr/page/video/video_panel_transition.dart';
import 'package:zephyr/page/video/video_side_panel.dart';

/// Keep the movie/status area black while the home-indicator inset belongs to
/// the detail surface. Fullscreen keeps the entire canvas black.
class VideoPageSafeArea extends StatelessWidget {
  const VideoPageSafeArea({
    super.key,
    required this.child,
    this.fullscreen = false,
  });
  final Widget child;
  final bool fullscreen;

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const ValueKey('video-page.inset-background'),
    color: fullscreen ? Colors.black : Theme.of(context).colorScheme.surface,
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (!fullscreen)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.paddingOf(context).top,
            child: const ColoredBox(
              key: ValueKey('video-page.status-background'),
              color: Colors.black,
            ),
          ),
        SafeArea(top: !fullscreen, bottom: !fullscreen, child: child),
      ],
    ),
  );
}

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

/// A size change becomes immediate when motion is reduced. Avoid a zero-length
/// AnimatedSize scheduling a second layout while a child's size is changing.
class VideoSizeTransition extends StatelessWidget {
  const VideoSizeTransition({
    super.key,
    required this.child,
    this.alignment = Alignment.topCenter,
  });
  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => MediaQuery.disableAnimationsOf(context)
      ? child
      : AnimatedSize(
          duration: VideoMotion.feedback(context),
          alignment: alignment,
          child: child,
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

/// A nearby, dismissible action error. Success stays in the action itself.
class VideoActionNotice extends StatelessWidget {
  const VideoActionNotice({
    super.key,
    required this.message,
    required this.onClose,
  });
  final String message;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 2),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            IconButton(
              onPressed: onClose,
              tooltip: t.common.close,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
      ),
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
  bool useRootNavigator = false,
  bool? systemStyle,
  String? networkSource,
  Future<OmoNetworkContext?>? network,
  VideoPanelPurpose purpose = VideoPanelPurpose.download,
}) {
  // Capture player appearance before crossing the modal route boundary.
  final appearance = systemStyle ?? VideoControlAppearance.usesSystem(context);
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  ModalRoute<T>? closingRoute;
  Widget buildTask(BuildContext sheetContext) {
    closingRoute = ModalRoute.of<T>(sheetContext);
    return VideoControlAppearance(
      systemControls: appearance,
      child: Theme(
        data:
            MediaQuery.sizeOf(sheetContext).width >
                MediaQuery.sizeOf(sheetContext).height
            ? videoSidePanelTheme(videoBrowseTheme(Theme.of(sheetContext)))
            : videoReadableTaskTheme(videoBrowseTheme(Theme.of(sheetContext))),
        child: Builder(
          builder: (context) {
            final rawMedia = videoOverlayMedia(MediaQuery.of(context));
            // A bottom-sheet route removes top padding when useSafeArea=false.
            // Restore it for content only; the material stays edge-to-edge.
            final media = rawMedia.copyWith(
              padding: rawMedia.padding.copyWith(
                top: math.max(rawMedia.padding.top, rawMedia.viewPadding.top),
              ),
            );
            final landscape = media.size.width > media.size.height;
            return MediaQuery(
              data: media,
              child: LayoutBuilder(
                builder: (context, bounds) {
                  final available = (bounds.maxHeight - media.viewInsets.bottom)
                      .clamp(0.0, bounds.maxHeight);
                  final width = landscape
                      ? videoSidePanelWidth(context, bounds, purpose: purpose)
                      : math.min(bounds.maxWidth, 720.0);
                  final positioned = Padding(
                    padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
                    child: Align(
                      alignment: landscape
                          ? Alignment.centerRight
                          : Alignment.bottomCenter,
                      heightFactor: landscape ? null : 1,
                      child: ConstrainedBox(
                        key: const ValueKey('video-task.surface'),
                        constraints: BoxConstraints(
                          minWidth: width,
                          maxWidth: width,
                          minHeight: 0,
                          maxHeight: landscape
                              ? available
                              : math.min(
                                  600,
                                  (media.size.height -
                                              media.padding.vertical -
                                              media.viewInsets.bottom)
                                          .clamp(0.0, double.infinity) *
                                      .82,
                                ),
                        ),
                        child: Padding(
                          padding: landscape
                              ? EdgeInsets.fromLTRB(
                                  12,
                                  math.max(12, media.padding.top),
                                  math.max(12, media.padding.right),
                                  math.max(12, media.padding.bottom),
                                )
                              : EdgeInsets.zero,
                          child: MediaQuery.removePadding(
                            context: context,
                            removeTop: landscape,
                            removeBottom: landscape,
                            removeLeft: landscape,
                            removeRight: landscape,
                            child: NativeMaterialSurface(
                              radius: landscape ? 14 : 24,
                              topOnly: !landscape,
                              systemStyle: appearance,
                              readableContent: true,
                              child: SafeArea(
                                top: false,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!landscape)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        child: Container(
                                          width: 32,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    Flexible(
                                      key: const ValueKey('video-task.body'),
                                      child: ColoredBox(
                                        key: const ValueKey(
                                          'video-task.content',
                                        ),
                                        color:
                                            MediaQuery.highContrastOf(context)
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.surface
                                            : Colors.transparent,
                                        child: Material(
                                          type: MaterialType.transparency,
                                          child: networkSource == null
                                              ? builder(context)
                                              : VideoNetworkScope(
                                                  source: networkSource,
                                                  network: network,
                                                  child: builder(context),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                  return Stack(
                    fit: landscape ? StackFit.expand : StackFit.loose,
                    children: [
                      if (landscape) VideoSidePanelDepth(width: width),
                      positioned,
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  final media = MediaQuery.of(context);
  final landscape = media.size.width > media.size.height;
  final shown = landscape
      ? showGeneralDialog<T>(
          context: context,
          useRootNavigator: useRootNavigator,
          barrierDismissible: true,
          barrierLabel: t.common.close,
          barrierColor: Colors.transparent,
          transitionDuration:
              VideoMotion.sheet(context).duration ?? Duration.zero,
          transitionBuilder: (context, animation, _, child) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: animation.drive(
                Tween(
                  begin: const Offset(.06, 0),
                  end: Offset.zero,
                ).chain(CurveTween(curve: Curves.easeOutCubic)),
              ),
              child: child,
            ),
          ),
          pageBuilder: (_, _, _) => themes.wrap(
            Builder(
              builder: (context) => Stack(
                fit: StackFit.expand,
                children: [
                  const Positioned.fill(child: VideoPanelScrim()),
                  buildTask(context),
                ],
              ),
            ),
          ),
        )
      : navigator.push<T>(
          _VideoTaskBottomSheetRoute<T>(
            builder: buildTask,
            capturedThemes: themes,
            barrierLabel: MaterialLocalizations.of(context).scrimLabel,
            barrierOnTapHint: MaterialLocalizations.of(context).scrimOnTapHint(
              MaterialLocalizations.of(context).bottomSheetLabel,
            ),
            sheetAnimationStyle: VideoMotion.sheet(context),
          ),
        );
  return retainVideoModalExitBarrier(shown, () => closingRoute);
}

/// Keep native bottom-sheet drag/close behavior, with a responsive scrim and
/// no route-wide safe area that would inset the landscape material itself.
class _VideoTaskBottomSheetRoute<T> extends ModalBottomSheetRoute<T> {
  _VideoTaskBottomSheetRoute({
    required super.builder,
    required super.capturedThemes,
    required super.barrierLabel,
    required super.barrierOnTapHint,
    required super.sheetAnimationStyle,
  }) : super(
         isScrollControlled: true,
         useSafeArea: false,
         showDragHandle: false,
         backgroundColor: Colors.transparent,
         modalBarrierColor: Colors.transparent,
         elevation: 0,
         clipBehavior: Clip.none,
         constraints: const BoxConstraints(maxWidth: double.infinity),
       );
  @override
  Widget buildModalBarrier() => Stack(
    fit: StackFit.expand,
    children: [
      Positioned.fill(
        child: AnimatedBuilder(
          animation: animation!,
          builder: (context, _) => VideoPanelScrim(progress: animation!.value),
        ),
      ),
      super.buildModalBarrier(),
    ],
  );
}

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
