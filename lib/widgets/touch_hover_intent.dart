import 'package:flutter/foundation.dart'
    show TargetPlatform, ValueNotifier, defaultTargetPlatform;
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

bool _directInput(PointerDeviceKind kind) =>
    kind == PointerDeviceKind.touch ||
    kind == PointerDeviceKind.stylus ||
    kind == PointerDeviceKind.invertedStylus;

bool get _touchPlatform =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.android;

/// Observes Flutter touches without consuming events or changing native views.
/// A touch elsewhere also ends a control's previous mouse-hover intent.
class TouchHoverIntentScope extends StatefulWidget {
  const TouchHoverIntentScope({super.key, required this.child});
  final Widget child;

  @override
  State<TouchHoverIntentScope> createState() => _TouchHoverIntentScopeState();
}

class _TouchHoverIntentScopeState extends State<TouchHoverIntentScope> {
  final _epoch = ValueNotifier<int>(0);

  @override
  void dispose() {
    _epoch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) {
      if (_touchPlatform && _directInput(event.kind)) {
        _epoch.value++;
      }
    },
    child: _TouchHoverEpoch(notifier: _epoch, child: widget.child),
  );
}

class _TouchHoverEpoch extends InheritedNotifier<ValueNotifier<int>> {
  const _TouchHoverEpoch({required super.notifier, required super.child});

  static ValueNotifier<int>? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TouchHoverEpoch>()?.notifier;
}

/// Paint policy only: selected, pressed, focus, cursor and callbacks stay owned
/// by the original control. A null result retains its normal theme fallback.
class TouchHoverStyle {
  const TouchHoverStyle._(this.allowed);
  final bool allowed;

  Color? hoverColor([Color? original]) =>
      allowed ? original : Colors.transparent;

  WidgetStateProperty<Color?>? overlayColor(
    WidgetStateProperty<Color?>? original,
  ) => allowed
      ? original
      : WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) &&
              !states.contains(WidgetState.pressed) &&
              !states.contains(WidgetState.focused)) {
            return Colors.transparent;
          }
          return original?.resolve(states);
        });
}

/// On touch platforms a new row/page can appear below a stationary pointer.
/// MouseRegion.onEnter alone is not movement (nor does its synthesized flag
/// distinguish a frame-generated enter). Qualify each control independently
/// from actual local movement or mouse-down; desktop behavior stays unchanged.
class TouchHoverIntent extends StatefulWidget {
  const TouchHoverIntent({super.key, this.identity, required this.builder});
  final Object? identity;
  final Widget Function(BuildContext context, TouchHoverStyle style) builder;

  @override
  State<TouchHoverIntent> createState() => _TouchHoverIntentState();
}

class _TouchHoverIntentState extends State<TouchHoverIntent> {
  final _devices = <int>{};
  ValueNotifier<int>? _epochSignal;
  int? _epoch;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _epochSignal = _TouchHoverEpoch.of(context);
    _syncEpoch();
  }

  void _syncEpoch() {
    final epoch = _epochSignal?.value;
    if (epoch != _epoch) {
      _devices.clear();
      _epoch = epoch;
    }
  }

  @override
  void didUpdateWidget(TouchHoverIntent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity) {
      _devices.clear();
    }
  }

  void _qualify(PointerEvent event) {
    // If touch and mouse events arrive before the next build, the latest real
    // mouse movement must not be discarded by a delayed inherited rebuild.
    _syncEpoch();
    if (!event.synthesized &&
        (event.kind == PointerDeviceKind.mouse ||
            event.kind == PointerDeviceKind.stylus ||
            event.kind == PointerDeviceKind.invertedStylus) &&
        event.delta != Offset.zero &&
        _devices.add(event.device)) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      opaque: false,
      onExit: (event) {
        if (_devices.remove(event.device)) {
          setState(() {});
        }
      },
      child: Listener(
        onPointerHover: _qualify,
        onPointerMove: _qualify,
        onPointerDown: (event) {
          _syncEpoch();
          if (_directInput(event.kind)) {
            if (_devices.isNotEmpty) {
              setState(_devices.clear);
            }
          } else if (!event.synthesized &&
              event.kind == PointerDeviceKind.mouse &&
              _devices.add(event.device)) {
            setState(() {});
          }
        },
        child: widget.builder(
          context,
          TouchHoverStyle._(!_touchPlatform || _devices.isNotEmpty),
        ),
      ),
    );
  }
}
