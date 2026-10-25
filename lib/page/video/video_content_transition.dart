import 'package:material_ui/material_ui.dart';

/// Incoming native content only, on an opaque parent surface. Never duplicates
/// the outgoing page or fades the underlying WebView into view. Content is
/// readable and tappable from the first frame, with no delayed loading work.
class VideoContentTransition extends StatefulWidget {
  const VideoContentTransition({
    super.key,
    required this.revision,
    required this.ready,
    required this.child,
    this.enabled = true,
  });
  final int revision;
  final bool ready, enabled;
  final Widget child;

  @override
  State<VideoContentTransition> createState() => _VideoContentTransitionState();
}

class _VideoContentTransitionState extends State<VideoContentTransition>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    value: 1,
    duration: const Duration(milliseconds: 160),
  );
  late final _opacity = Tween<double>(
    begin: 0.8,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  bool get _canAnimate =>
      widget.enabled && !MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_canAnimate) _controller.value = 1;
  }

  @override
  void didUpdateWidget(covariant VideoContentTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.ready || !_canAnimate) {
      _controller.value = 1;
    } else if (!oldWidget.ready || oldWidget.revision != widget.revision) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _opacity, child: widget.child);
}
