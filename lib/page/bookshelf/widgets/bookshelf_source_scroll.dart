import 'package:flutter/widgets.dart';

/// Keeps source offsets separate from the widget key that preserves the viewport
/// and the covers shared by adjacent source selections.
class BookshelfSourceScroll extends ScrollController {
  BookshelfSourceScroll() : super(keepScrollOffset: false);

  Object? _scope;
  set scope(Object value) {
    if (_scope == value) return;
    _scope = value;
    for (final position in positions.cast<_BookshelfSourcePosition>()) {
      position._requestLayout();
    }
  }

  final _offsets = <Object, double>{};

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _BookshelfSourcePosition(
    this,
    physics: physics,
    context: context,
    oldPosition: oldPosition,
  );

  @override
  void detach(ScrollPosition position) {
    (position as _BookshelfSourcePosition)._remember();
    super.detach(position);
  }
}

class _BookshelfSourcePosition extends ScrollPositionWithSingleContext {
  _BookshelfSourcePosition(
    this._controller, {
    required super.physics,
    required super.context,
    super.oldPosition,
  }) : super(keepScrollOffset: false);

  final BookshelfSourceScroll _controller;
  Object? _displayedScope;
  bool _restoring = false;

  // Lazy slivers can keep exactly the same visible geometry on a source
  // change. Invalidate the viewport even if its existing children did not.
  void _requestLayout() {
    if (hasContentDimensions) notifyListeners();
  }

  void _remember() {
    if (_displayedScope case final scope? when hasContentDimensions) {
      _controller._offsets[scope] = pixels.clamp(
        minScrollExtent,
        maxScrollExtent,
      );
    }
  }

  @override
  bool applyViewportDimension(double viewportDimension) {
    final scope = _controller._scope;
    if (_displayedScope != scope) {
      _remember();
      _displayedScope = scope;
      _restoring = true;
      // Restore during layout so the next paint already shows the right rows.
      // The previous source's extent is not valid for the new content.
      correctBy((_controller._offsets[scope] ?? 0) - pixels);
      if (activity?.isScrolling == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Applying the new dimensions can replace the outgoing activity.
          if (_controller.positions.contains(this) &&
              _displayedScope == scope &&
              _controller._scope == scope) {
            goIdle();
          }
        });
      }
    }
    return super.applyViewportDimension(viewportDimension);
  }

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    if (_restoring) {
      final inRange = pixels.clamp(minScrollExtent, maxScrollExtent);
      if (inRange != pixels) {
        correctBy(inRange - pixels);
        return false;
      }
      _restoring = false;
    }
    return super.applyContentDimensions(minScrollExtent, maxScrollExtent);
  }
}
