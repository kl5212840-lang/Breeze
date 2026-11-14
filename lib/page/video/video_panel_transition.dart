import 'package:material_ui/material_ui.dart';

/// Depth belongs near the sidebar; the main video stays clear at the left.
class VideoPanelScrim extends StatelessWidget {
  const VideoPanelScrim({super.key, this.side, this.progress = 1});
  final bool? side;
  final double progress;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, bounds) {
          final landscape = side ?? bounds.maxWidth > bounds.maxHeight;
          return DecoratedBox(
            key: const ValueKey('video-panel.scrim'),
            decoration: BoxDecoration(
              color: landscape
                  ? null
                  : Colors.black.withValues(alpha: .32 * progress),
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    ),
  );
}

/// One reversible controller owns the panel and scrim. Closing then reopening
/// reverses from the current frame; no delayed removal can dismiss a new panel.
class VideoPanelTransition extends StatefulWidget {
  const VideoPanelTransition({
    super.key,
    required this.open,
    required this.side,
    required this.onDismiss,
    required this.child,
  });
  final bool open, side;
  final VoidCallback onDismiss;
  final Widget child;
  @override
  State<VideoPanelTransition> createState() => _VideoPanelTransitionState();
}

class _VideoPanelTransitionState extends State<VideoPanelTransition>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this);
  bool _reduced = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _controller.duration = Duration(milliseconds: _reduced ? 100 : 240);
    _controller.reverseDuration = Duration(milliseconds: _reduced ? 80 : 180);
    if (widget.open) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant VideoPanelTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open != oldWidget.open) {
      widget.open ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      if (_controller.isDismissed && !widget.open) {
        return const SizedBox.shrink();
      }
      final value = Curves.easeOutCubic.transform(_controller.value);
      return IgnorePointer(
        ignoring: _controller.isDismissed,
        child: ExcludeSemantics(
          excluding: !widget.open,
          child: BlockSemantics(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: VideoPanelScrim(side: widget.side, progress: value),
                ),
                ModalBarrier(
                  dismissible: widget.open,
                  color: Colors.transparent,
                  onDismiss: widget.open ? widget.onDismiss : null,
                  semanticsLabel: MaterialLocalizations.of(
                    context,
                  ).modalBarrierDismissLabel,
                ),
                Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: _reduced
                        ? Offset.zero
                        : widget.side
                        ? Offset(32 * (1 - value), 0)
                        : Offset(0, 32 * (1 - value)),
                    child: IgnorePointer(
                      ignoring: !widget.open,
                      child: FocusScope(child: widget.child),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
