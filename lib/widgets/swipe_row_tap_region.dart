import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

/// A revealed row consumes a tap to close, while a drag still scrolls.
/// Navigation in the same tap group can leave the page immediately.
class SwipeRowTapRegion extends StatefulWidget {
  const SwipeRowTapRegion({
    super.key,
    required this.group,
    required this.enabled,
    required this.onDismiss,
    required this.child,
  });

  final Object group;
  final bool enabled;
  final VoidCallback onDismiss;
  final Widget child;

  @override
  State<SwipeRowTapRegion> createState() => _SwipeRowTapRegionState();
}

class _SwipeRowTapRegionState extends State<SwipeRowTapRegion> {
  late final _outsideTap = _DismissTap()
    ..onTap = _dismiss
    ..onSecondaryTap = _dismiss;

  void _dismiss() {
    if (widget.enabled) widget.onDismiss();
  }

  @override
  void dispose() {
    _outsideTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TapRegion(
    groupId: widget.group,
    enabled: widget.enabled,
    onTapOutside: (event) {
      if (!widget.enabled) return;
      if (event.pointer != 0) {
        _outsideTap.addPointer(event);
      } else {
        _dismiss();
      }
    },
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? _dismiss : null,
      child: widget.child,
    ),
  );
}

class _DismissTap extends TapGestureRecognizer {
  @override
  void handlePrimaryPointer(PointerEvent event) {
    if (event is PointerUpEvent) resolve(GestureDisposition.accepted);
    super.handlePrimaryPointer(event);
  }
}
