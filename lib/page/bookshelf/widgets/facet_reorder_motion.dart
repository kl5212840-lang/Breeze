import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

/// One short motion for the mounted rows of a lazy facet list. The list keeps
/// owning its layout, scroll position and selection; no offscreen rows are built.
class FacetReorderController {
  FacetReorderController({required TickerProvider vsync}) {
    _animation = AnimationController(vsync: vsync, duration: duration, value: 1)
      ..addListener(_paint);
  }
  static const duration = Duration(milliseconds: 160);
  late final AnimationController _animation;
  final _rows = <_RenderFacetReorderItem>{};
  var _generation = 0;
  bool _disposed = false;
  double get _progress => Curves.easeOutCubic.transform(_animation.value);

  /// Capture immediately before applying a new pin order, not on query changes.
  void capture({required bool animate}) {
    if (_disposed) return;
    final generation = ++_generation;
    _animation.stop();
    for (final row in _rows) {
      row.capture(animate: animate);
    }
    _animation.value = animate ? 0 : 1;
    if (!animate || _rows.isEmpty) return;
    // The first paint computes actual offsets after variable-height row layout,
    // and still draws at the captured positions. Start only after that frame.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_disposed && generation == _generation) _animation.forward();
    });
  }

  void _paint() {
    for (final row in _rows) {
      row.markNeedsPaint();
      row.markNeedsSemanticsUpdate();
    }
  }

  void dispose() {
    _disposed = true;
    _generation++;
    _animation.dispose();
    _rows.clear();
  }
}

class FacetReorderItem extends StatelessWidget {
  const FacetReorderItem({
    super.key,
    required this.controller,
    required this.child,
    this.enabled = true,
  });
  final FacetReorderController controller;
  final Widget child;
  final bool enabled;
  @override
  Widget build(BuildContext context) => _FacetReorderBox(
    controller: controller,
    enabled: enabled && !MediaQuery.disableAnimationsOf(context),
    child: child,
  );
}

class _FacetReorderBox extends SingleChildRenderObjectWidget {
  const _FacetReorderBox({
    required this.controller,
    required this.enabled,
    required super.child,
  });
  final FacetReorderController controller;
  final bool enabled;
  @override
  _RenderFacetReorderItem createRenderObject(BuildContext context) =>
      _RenderFacetReorderItem(controller, enabled);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderFacetReorderItem renderObject,
  ) {
    renderObject.update(controller, enabled);
  }
}

class _RenderFacetReorderItem extends RenderProxyBox {
  _RenderFacetReorderItem(this._controller, this._enabled);
  FacetReorderController _controller;
  bool _enabled;
  Offset? _origin;
  Offset _delta = Offset.zero;
  Offset get _translation =>
      _enabled ? _delta * (1 - _controller._progress) : Offset.zero;

  void update(FacetReorderController controller, bool enabled) {
    if (_controller != controller) {
      if (attached) _controller._rows.remove(this);
      _controller = controller;
      if (attached) _controller._rows.add(this);
      _origin = null;
      _delta = Offset.zero;
    }
    _enabled = enabled;
    if (!enabled) {
      _origin = null;
      _delta = Offset.zero;
    }
    markNeedsPaint();
  }

  void capture({required bool animate}) {
    _origin = animate && _enabled && attached && hasSize
        ? localToGlobal(Offset.zero) + _translation
        : null;
    if (_origin == null) _delta = Offset.zero;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller._rows.add(this);
  }

  @override
  void detach() {
    _controller._rows.remove(this);
    _origin = null;
    _delta = Offset.zero;
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final origin = _origin;
    if (origin != null) {
      _delta = origin - localToGlobal(Offset.zero);
      if (!_delta.dx.isFinite || !_delta.dy.isFinite) _delta = Offset.zero;
      _origin = null;
    }
    if (child != null) context.paintChild(child!, offset + _translation);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      hitTestChildren(result, position: position);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      result.addWithPaintOffset(
        offset: _translation,
        position: position,
        hitTest: (result, position) =>
            super.hitTestChildren(result, position: position),
      );
  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translateByDouble(_translation.dx, _translation.dy, 0, 1);
  }
}
