import 'package:material_ui/material_ui.dart';

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
        ignoring: !widget.open,
        child: ExcludeSemantics(
          excluding: !widget.open,
          child: BlockSemantics(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ModalBarrier(
                  dismissible: true,
                  color: Colors.black.withValues(alpha: .42 * value),
                  onDismiss: widget.onDismiss,
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
                    child: FocusScope(child: widget.child),
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
