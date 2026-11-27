import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/breeze_theme_colors.dart';
import 'package:zephyr/widgets/swipe_row_tap_region.dart';

/// Reveal discrete row commands while leaving the remaining row actionable.
class ComicFollowRowActions extends StatefulWidget {
  const ComicFollowRowActions({
    super.key,
    required this.rowKey,
    required this.openRow,
    this.onMarkRead,
    required this.onUnfollow,
    required this.child,
  });

  final String rowKey;
  final ValueNotifier<String?> openRow;
  final VoidCallback? onMarkRead;
  final VoidCallback onUnfollow;
  final Widget child;

  @override
  State<ComicFollowRowActions> createState() => _ComicFollowRowActionsState();
}

class _ComicFollowRowActionsState extends State<ComicFollowRowActions>
    with SingleTickerProviderStateMixin {
  static const _backGestureEdge = 28.0;
  static const _radius = BorderRadius.all(Radius.circular(16));

  late final _slide = AnimationController(vsync: this);
  bool _dragging = false;
  bool _startedOpen = false;

  bool get _open => widget.openRow.value == widget.rowKey;

  @override
  void initState() {
    super.initState();
    _slide.value = _open ? 1 : 0;
    widget.openRow.addListener(_sync);
  }

  @override
  void dispose() {
    widget.openRow.removeListener(_sync);
    _slide.dispose();
    super.dispose();
  }

  void _sync() {
    if (_open && _dragging) return;
    if (!_open && !_dragging && _slide.isDismissed) return;
    _dragging = false;
    _settle(_open);
  }

  void _settle(bool open) {
    _slide.animateTo(
      open ? 1 : 0,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
    );
  }

  void _start(DragStartDetails _) {
    _startedOpen = _open;
    _dragging = true;
    _slide.stop();
    widget.openRow.value = widget.rowKey;
  }

  void _update(double delta) {
    if (_dragging) _slide.value = (_slide.value + delta).clamp(0.0, 1.0);
  }

  void _finish(bool reveal) {
    if (!_dragging) return;
    setState(() => _dragging = false);
    if (reveal) {
      _settle(true);
    } else {
      widget.openRow.value = null;
    }
  }

  void _close() {
    if (_open) widget.openRow.value = null;
  }

  void _run(VoidCallback action) {
    if (ModalRoute.isCurrentOf(context) == false) return;
    _close();
    action();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final markRead = widget.onMarkRead;
      final slotWidth = (constraints.maxWidth * .24).clamp(48.0, 76.0);
      final width = slotWidth * (markRead == null ? 1 : 2);
      final direction = Directionality.of(context) == TextDirection.ltr
          ? 1
          : -1;
      final screenWidth = MediaQuery.sizeOf(context).width;
      final theme = Theme.of(context);
      final surface = Color.alphaBlend(
        Scaffold.maybeOf(context)?.widget.backgroundColor ??
            theme.scaffoldBackgroundColor,
        theme.colorScheme.surface,
      );

      return RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        gestures: {
          _FollowRowDrag: GestureRecognizerFactoryWithHandlers<_FollowRowDrag>(
            _FollowRowDrag.new,
            (gesture) {
              gesture.canStart = (point) => direction > 0
                  ? point.dx >= _backGestureEdge
                  : point.dx <= screenWidth - _backGestureEdge;
              gesture.dragStartBehavior = DragStartBehavior.down;
              gesture.onStart = _start;
              gesture.onUpdate = (details) =>
                  _update(-details.delta.dx * direction / width);
              gesture.onEnd = (_) => _finish(
                gesture.isCancelling
                    ? _startedOpen
                    : _slide.value >= (_startedOpen ? .4 : .5),
              );
              gesture.onCancel = () => _finish(_startedOpen);
            },
          ),
        },
        child: AnimatedBuilder(
          animation: _slide,
          child: widget.child,
          builder: (context, child) {
            final reveal = _slide.value * width;
            final ready = _open && !_dragging && _slide.value == 1;
            return SwipeRowTapRegion(
              group: widget.openRow,
              enabled: _open,
              onDismiss: _close,
              child: ClipRect(
                child: Stack(
                  children: [
                    if (reveal > 0)
                      PositionedDirectional(
                        end: 0,
                        top: 0,
                        bottom: 0,
                        width: width,
                        child: IgnorePointer(
                          ignoring: !ready,
                          child: ExcludeSemantics(
                            excluding: !ready,
                            child: ExcludeFocus(
                              excluding: !ready,
                              child: _buildTray(context, markRead, surface),
                            ),
                          ),
                        ),
                      ),
                    Transform.translate(
                      offset: Offset(-reveal * direction, 0),
                      child: Semantics(
                        customSemanticsActions: ready
                            ? null
                            : {
                                if (markRead != null)
                                  CustomSemanticsAction(
                                    label: t.sourceNotices.markRead,
                                  ): () =>
                                      _run(markRead),
                                CustomSemanticsAction(
                                  label: t.comicFollow.unfollow,
                                ): () =>
                                    _run(widget.onUnfollow),
                              },
                        child: AbsorbPointer(
                          absorbing: _open || reveal > 0,
                          child: ColoredBox(
                            color: reveal > 0 ? surface : Colors.transparent,
                            child: child!,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );

  Widget _buildTray(
    BuildContext context,
    VoidCallback? markRead,
    Color surface,
  ) {
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: _radius,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (markRead != null)
            Expanded(
              child: _button(
                context,
                label: t.sourceNotices.read,
                semanticLabel: t.sourceNotices.markRead,
                icon: Icons.check_rounded,
                tone: colors.primary,
                surface: surface,
                action: markRead,
              ),
            ),
          Expanded(
            child: _button(
              context,
              label: t.comicFollow.unfollow,
              semanticLabel: t.comicFollow.unfollow,
              icon: Icons.notifications_off_outlined,
              tone: colors.error,
              surface: surface,
              action: widget.onUnfollow,
            ),
          ),
        ],
      ),
    );
  }

  Widget _button(
    BuildContext context, {
    required String label,
    required String semanticLabel,
    required IconData icon,
    required Color tone,
    required Color surface,
    required VoidCallback action,
  }) {
    final theme = Theme.of(context);
    final background = Color.alphaBlend(tone.withValues(alpha: .10), surface);
    final ink = BreezeThemeColors.readableOn(tone, background);
    return Material(
      color: background,
      child: InkWell(
        onTap: () {
          if (_open && !_dragging && _slide.value == 1) _run(action);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: ink),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  label,
                  semanticsLabel: semanticLabel,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(color: ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FollowRowDrag extends HorizontalDragGestureRecognizer {
  bool Function(Offset)? canStart;
  bool isCancelling = false;
  int? _pointer;

  bool _canStart(PointerEvent event) =>
      _pointer == null && (canStart?.call(event.position) ?? true);

  @override
  bool isPointerAllowed(PointerEvent event) =>
      _canStart(event) && super.isPointerAllowed(event);

  @override
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) =>
      _canStart(event) && super.isPointerPanZoomAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _pointer = event.pointer;
    super.addAllowedPointer(event);
  }

  @override
  void addAllowedPointerPanZoom(PointerPanZoomStartEvent event) {
    _pointer = event.pointer;
    super.addAllowedPointerPanZoom(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    // Flutter ends an accepted drag even when the contact was cancelled.
    isCancelling = event is PointerCancelEvent;
    super.handleEvent(event);
    isCancelling = false;
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _pointer = null;
    super.didStopTrackingLastPointer(pointer);
  }
}
