import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/breeze_control_motion.dart';

/// Paint-only feedback: the existing child retains the gesture arena and its
/// full hit target. In particular a long press must not compete with scrolling.
class CollectionPressFeedback extends StatefulWidget {
  const CollectionPressFeedback({
    super.key,
    required Widget this.child,
    this.enabled = true,
  }) : pressedBuilder = null,
       _surface = false;

  /// A large list item needs less motion than a compact toolbar button.
  const CollectionPressFeedback.surface({
    super.key,
    required Widget this.child,
    this.enabled = true,
  }) : pressedBuilder = null,
       _surface = true;

  /// Reuses the passive pointer observer for a control that paints its own
  /// hover, focus and pressed states. The original button handles activation.
  const CollectionPressFeedback.builder({
    super.key,
    required Widget Function(BuildContext, bool) this.pressedBuilder,
    this.enabled = true,
  }) : child = null,
       _surface = false;

  final Widget? child;
  final Widget Function(BuildContext, bool)? pressedBuilder;
  final bool enabled;
  final bool _surface;

  static Color surfaceHighlight(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: .035);

  @override
  State<CollectionPressFeedback> createState() =>
      _CollectionPressFeedbackState();
}

class _CollectionPressFeedbackState extends State<CollectionPressFeedback>
    with WidgetsBindingObserver {
  int? _pointer;
  Offset? _origin;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant CollectionPressFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _pointer = null;
      _origin = null;
      _pressed = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _release();
  }

  void _release() {
    _pointer = null;
    _origin = null;
    if (_pressed && mounted) setState(() => _pressed = false);
  }

  void _down(PointerDownEvent event) {
    if (!widget.enabled ||
        _pointer != null ||
        event.buttons != kPrimaryButton) {
      return;
    }
    _pointer = event.pointer;
    _origin = event.localPosition;
    setState(() => _pressed = true);
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer || _origin == null) return;
    final slop = MediaQuery.gestureSettingsOf(context).touchSlop ?? kTouchSlop;
    final bounds = Offset.zero & context.size!;
    if (!bounds.contains(event.localPosition) ||
        (event.localPosition - _origin!).distance > slop) {
      _release();
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerDown: _down,
    onPointerMove: _move,
    onPointerUp: (event) {
      if (event.pointer == _pointer) _release();
    },
    onPointerCancel: (event) {
      if (event.pointer == _pointer) _release();
    },
    child:
        widget.pressedBuilder?.call(context, _pressed) ??
        (MediaQuery.disableAnimationsOf(context)
            ? Opacity(
                opacity: _pressed ? (widget._surface ? .97 : .84) : 1,
                child: widget.child!,
              )
            : BreezePressedContent(
                pressed: _pressed,
                scaleDelta: widget._surface ? .01 : .04,
                verticalOffset: widget._surface ? 0 : .6,
                child: widget.child!,
              )),
  );
}
