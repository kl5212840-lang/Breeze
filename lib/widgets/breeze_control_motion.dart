import 'package:material_ui/material_ui.dart';

/// Short, interruptible feedback for Breeze controls. Business actions and
/// layout are independent of these paint-only transitions.
abstract final class BreezeControlMotion {
  static const curve = Curves.easeOutCubic;
  static const selectionCurve = Cubic(.26, .12, .24, 1);

  static Duration press(BuildContext context, {required bool pressed}) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : Duration(milliseconds: pressed ? 70 : 140);

  static Duration segmentSelection(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 185);

  static Duration sourceSelection(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 200);
}

/// Keeps one progress value for a moving selection surface and its labels.
class BreezeSelectionProgress<T> {
  BreezeSelectionProgress(TickerProvider vsync, Set<T> selected)
    : _controller = AnimationController(vsync: vsync, value: 1),
      _selected = selected;

  final AnimationController _controller;
  Set<T> _selected;
  Map<T, double> _start = const {};

  Listenable get changes => _controller;

  bool animates(T id) =>
      _controller.isAnimating &&
      (_start.containsKey(id) || _selected.contains(id));

  double weight(T id) {
    final end = _selected.contains(id) ? 1.0 : 0.0;
    if (_controller.isCompleted) return end;
    final start = _start[id] ?? 0;
    return start + (end - start) * _controller.value;
  }

  void snap(Set<T> selected) {
    _selected = selected;
    _start = const {};
    if (!_controller.isCompleted) _controller.value = 1;
  }

  void scrub(Map<T, double> weights) {
    _start = weights;
    _controller.value = 0;
  }

  void select(Set<T> selected, {required Duration duration}) {
    if (duration == Duration.zero ||
        _selected.length != 1 ||
        selected.length != 1) {
      snap(selected);
      return;
    }

    // Retarget from the current frame. Only identities that were actually
    // selected gain emphasis, including during a jump across several options.
    final start = {
      for (final id in {..._start.keys, ..._selected}) id: weight(id),
    }..removeWhere((_, weight) => weight == 0);
    final remaining = 1 - (start[selected.single] ?? 0);
    _start = start;
    _selected = selected;
    if (remaining == 0) {
      snap(selected);
      return;
    }
    _controller.value = 0;
    _controller.animateTo(
      1,
      duration: duration * (.62 + .38 * remaining),
      curve: BreezeControlMotion.selectionCurve,
    );
  }

  void dispose() => _controller.dispose();
}

class BreezePressedContent extends StatelessWidget {
  const BreezePressedContent({
    super.key,
    required this.pressed,
    required this.child,
  });

  final bool pressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = BreezeControlMotion.press(context, pressed: pressed);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: pressed && duration != Duration.zero ? 1 : 0),
      duration: duration,
      curve: BreezeControlMotion.curve,
      child: child,
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, .6 * value),
        transformHitTests: false,
        child: Transform.scale(
          scale: 1 - .04 * value,
          transformHitTests: false,
          child: child,
        ),
      ),
    );
  }
}
