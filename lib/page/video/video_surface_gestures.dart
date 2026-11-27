import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';

enum _Adjustment { brightness, volume }

class _AdjustmentDrag {
  _AdjustmentDrag(this.kind, this.travel);

  final _Adjustment kind;
  final double travel;
  double? target;
  int? lastRequest;
  int? confirmed;
  bool ended = false;
  bool unsupported = false;
  int movementRevision = 0;
  int readRevision = -1;
  double _offset = 0, _minimum = 0, _maximum = 1;

  int? get requested => target == null ? null : _percent(target!);

  void move(double dy) {
    movementRevision++;
    final step = -dy / travel;
    if (target case final level?) {
      target = (level + step).clamp(0.0, 1.0);
      return;
    }
    // Compose the clamped steps while device readback is pending. Reversing
    // after pushing past either end remains responsive without buffering moves.
    _offset += step;
    _minimum = (_minimum + step).clamp(0.0, 1.0);
    _maximum = (_maximum + step).clamp(0.0, 1.0);
  }

  void readOrigin(double level) {
    target = (level + _offset).clamp(_minimum, _maximum);
    lastRequest = confirmed = _percent(level);
  }

  static int _percent(double level) => (level * 100).round();
}

/// Resolves a drag on the video once. Controls above the surface keep their
/// own hit targets, and the initial touch chooses the adjustment side.
class VideoSurfaceGestures extends StatefulWidget {
  const VideoSurfaceGestures({
    super.key,
    required this.sessionActive,
    required this.enabled,
    required this.reversed,
    required this.seekEnabled,
    required this.fullscreen,
    required this.controlsVisible,
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeekEnd,
    required this.onSeekCancel,
    required this.child,
  });

  final bool sessionActive, enabled, reversed;
  final bool seekEnabled, fullscreen, controlsVisible;
  final VoidCallback onSeekStart, onSeekEnd, onSeekCancel;
  final ValueChanged<double> onSeekUpdate;
  final Widget child;

  @override
  State<VideoSurfaceGestures> createState() => _VideoSurfaceGesturesState();
}

class _VideoSurfaceGesturesState extends State<VideoSurfaceGestures> {
  static const _device = MethodChannel('zephyr/video_screen_brightness');
  _AdjustmentDrag? _drag;
  bool _androidBrightnessChanged = false;
  Future<void>? _operation;
  Timer? _dismiss;

  @override
  void didUpdateWidget(VideoSurfaceGestures oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled ||
        !widget.sessionActive ||
        oldWidget.reversed != widget.reversed ||
        oldWidget.fullscreen != widget.fullscreen) {
      _clearGesture();
    }
    if (!widget.sessionActive) unawaited(_restoreAndroidBrightness());
  }

  void _clearGesture() {
    _dismiss?.cancel();
    _dismiss = null;
    _drag = null;
  }

  void _start(bool left, double travel) {
    final brightness = left != widget.reversed;
    setState(() {
      _clearGesture();
      _drag = _AdjustmentDrag(
        brightness ? _Adjustment.brightness : _Adjustment.volume,
        travel,
      );
    });
    _syncLevel();
  }

  void _move(double dy) {
    final drag = _drag;
    if (drag == null || drag.ended || drag.unsupported || dy == 0) return;
    drag.move(dy);
    _syncLevel();
  }

  void _syncLevel() {
    final drag = _drag;
    if (drag == null || _operation != null) return;
    final requested = drag.requested;
    final hasWork = requested == null
        ? drag.readRevision != drag.movementRevision
        : requested != drag.lastRequest;
    if (drag.unsupported || !hasWork) {
      if (drag.ended) _finish();
      return;
    }
    if (requested == null) {
      drag.readRevision = drag.movementRevision;
    } else {
      drag.lastRequest = requested;
    }
    _operation = _updateLevel(drag, requested).whenComplete(() {
      _operation = null;
      if (mounted) _syncLevel();
    });
  }

  Future<void> _updateLevel(_AdjustmentDrag drag, int? requested) async {
    final brightness = drag.kind == _Adjustment.brightness;
    if (requested != null &&
        brightness &&
        defaultTargetPlatform == TargetPlatform.android) {
      _androidBrightnessChanged = true;
    }
    try {
      final actual = await _device.invokeMethod<Object?>(
        requested == null
            ? (brightness ? 'get' : 'getVolume')
            : (brightness ? 'set' : 'setVolume'),
        requested == null ? null : requested / 100,
      );
      if (!mounted || !identical(_drag, drag)) return;
      if (actual is! num || !actual.isFinite) return;
      final level = actual.toDouble().clamp(0.0, 1.0);
      if (requested == null) {
        setState(() => drag.readOrigin(level));
      } else {
        final percent = _AdjustmentDrag._percent(level);
        if (drag.confirmed != percent) setState(() => drag.confirmed = percent);
      }
    } on PlatformException catch (error) {
      // A temporary device error leaves the finger and the last readback active.
      // Another movement can retry the read or send a fresh target.
      if (error.code == 'unsupported') _disableDrag(drag);
    } on MissingPluginException {
      _disableDrag(drag);
    }
  }

  void _disableDrag(_AdjustmentDrag drag) {
    if (mounted && identical(_drag, drag)) {
      setState(() {
        drag.unsupported = true;
        drag.confirmed = null;
      });
    }
  }

  void _end() {
    final drag = _drag;
    if (drag == null || drag.ended) return;
    setState(() => drag.ended = true);
    _syncLevel();
  }

  void _finish() {
    if (_dismiss?.isActive == true) return;
    _dismiss = Timer(const Duration(milliseconds: 450), () {
      if (mounted) setState(_clearGesture);
    });
  }

  void _cancelAdjustment() {
    if (_drag != null) setState(_clearGesture);
  }

  Future<void> _restoreAndroidBrightness() async {
    if (!_androidBrightnessChanged) return;
    _androidBrightnessChanged = false;
    await _operation;
    if (mounted && widget.sessionActive) {
      _androidBrightnessChanged = true;
      return;
    }
    try {
      await _device.invokeMethod<void>('restore');
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }

  @override
  void dispose() {
    _clearGesture();
    unawaited(_restoreAndroidBrightness());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final inset = widget.fullscreen
          ? MediaQuery.viewPaddingOf(context)
          : EdgeInsets.zero;
      final system = MediaQuery.systemGestureInsetsOf(context);
      final drag = _drag;
      final confirmed = drag?.confirmed;
      final reduceMotion = MediaQuery.disableAnimationsOf(context);
      return RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        gestures: {
          if (widget.seekEnabled || widget.enabled)
            _VideoSurfaceDragRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  _VideoSurfaceDragRecognizer
                >(_VideoSurfaceDragRecognizer.new, (recognizer) {
                  final midpoint = size.width / 2;
                  final seekEdge = widget.fullscreen ? 12.0 : 24.0;
                  final left = math.max(inset.left + 12, system.left);
                  final right = math.max(inset.right + 12, system.right);
                  final adjustmentArea = Rect.fromLTRB(
                    left,
                    math.max(
                      system.top,
                      inset.top + (widget.controlsVisible ? 48 : 16),
                    ),
                    size.width - right,
                    size.height -
                        math.max(
                          system.bottom,
                          inset.bottom + (widget.controlsVisible ? 56 : 20),
                        ),
                  );
                  recognizer.gestureSettings = MediaQuery.gestureSettingsOf(
                    context,
                  );
                  recognizer.allowSeek = (position) =>
                      widget.seekEnabled &&
                      position.dx >= math.max(left, seekEdge) &&
                      position.dx <= size.width - math.max(right, seekEdge);
                  recognizer.allowAdjustment = (position) =>
                      widget.enabled &&
                      adjustmentArea.contains(position) &&
                      (position.dx - midpoint).abs() >= 12;
                  recognizer.onStart = (event) {
                    if (recognizer.axis == Axis.horizontal) {
                      widget.onSeekStart();
                    } else {
                      _start(
                        event.localPosition.dx < midpoint,
                        (size.height * .7).clamp(160.0, 320.0),
                      );
                    }
                  };
                  recognizer.onUpdate = (event) {
                    if (recognizer.axis == Axis.horizontal) {
                      widget.onSeekUpdate(event.delta.dx);
                    } else {
                      _move(event.delta.dy);
                    }
                  };
                  recognizer.onEnd = (_) {
                    if (recognizer.axis == Axis.horizontal) {
                      widget.onSeekEnd();
                    } else {
                      _end();
                    }
                  };
                  recognizer.onPointerCancelled = () {
                    if (recognizer.axis == Axis.horizontal) {
                      widget.onSeekCancel();
                    } else if (recognizer.axis == Axis.vertical) {
                      _cancelAdjustment();
                    }
                  };
                }),
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (widget.enabled)
              IgnorePointer(
                child: Center(
                  child: AnimatedSwitcher(
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 120),
                    reverseDuration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 100),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween(begin: .96, end: 1.0).animate(animation),
                        child: child,
                      ),
                    ),
                    layoutBuilder: (current, previous) =>
                        current ??
                        (previous.isEmpty
                            ? const SizedBox.shrink()
                            : previous.last),
                    child: confirmed == null
                        ? null
                        : _AdjustmentIndicator(
                            key: ValueKey(drag!.kind),
                            brightness: drag.kind == _Adjustment.brightness,
                            percent: confirmed,
                            held: !drag.ended,
                          ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _VideoSurfaceDragRecognizer extends PanGestureRecognizer {
  _VideoSurfaceDragRecognizer() {
    dragStartBehavior = DragStartBehavior.down;
    onlyAcceptDragOnThreshold = true;
  }

  late bool Function(Offset) allowSeek, allowAdjustment;
  VoidCallback? onPointerCancelled;
  int? _pointer;
  Offset _movement = Offset.zero;
  Axis? axis;
  bool _seek = false, _adjust = false;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      _pointer == null &&
      (allowSeek(event.localPosition) ||
          allowAdjustment(event.localPosition)) &&
      super.isPointerAllowed(event);

  @override
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) =>
      _pointer == null &&
      allowSeek(event.localPosition) &&
      super.isPointerPanZoomAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _pointer = event.pointer;
    _seek = allowSeek(event.localPosition);
    _adjust = allowAdjustment(event.localPosition);
    super.addAllowedPointer(event);
  }

  @override
  void addAllowedPointerPanZoom(PointerPanZoomStartEvent event) {
    _pointer = event.pointer;
    _seek = true;
    super.addAllowedPointerPanZoom(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (axis == null) {
      _movement += switch (event) {
        PointerMoveEvent() => event.localDelta,
        PointerPanZoomUpdateEvent() => event.localPanDelta,
        _ => Offset.zero,
      };
    }
    if (event is PointerCancelEvent) onPointerCancelled?.call();
    super.handleEvent(event);
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind kind,
    double? slop,
  ) {
    if (axis != null) return true;
    final threshold = computeHitSlop(kind, gestureSettings);
    final dx = _movement.dx.abs();
    final dy = _movement.dy.abs();
    // A curved thumb swipe can first cross touch slop on the other axis.
    // Wait for clear separation before committing to an available action.
    final separation = math.min(10.0, threshold);
    if (_seek && dx > threshold && dx - dy >= separation && dx > dy * 1.35) {
      axis = Axis.horizontal;
    } else if (_adjust &&
        dy > threshold &&
        dy - dx >= separation &&
        dy > dx * 1.35) {
      axis = Axis.vertical;
    }
    return axis != null;
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    super.didStopTrackingLastPointer(pointer);
    _pointer = null;
    _movement = Offset.zero;
    axis = null;
    _seek = _adjust = false;
  }
}

class _AdjustmentIndicator extends StatelessWidget {
  const _AdjustmentIndicator({
    super.key,
    required this.brightness,
    required this.percent,
    required this.held,
  });

  final bool brightness, held;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final label = brightness
        ? t.videoPlayback.adjustBrightness
        : t.videoPlayback.adjustVolume;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final trackHeight = held && !reduceMotion
        ? (percent == 0 || percent == 100 ? 7.0 : 5.5)
        : 4.0;
    return Semantics(
      label: label,
      value: '$percent%',
      excludeSemantics: true,
      child: DecoratedBox(
        key: const ValueKey('video-landscape-adjustment'),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .66),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SizedBox(
          width: 176,
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              spacing: 14,
              children: [
                Icon(
                  brightness
                      ? Icons.light_mode_outlined
                      : percent == 0
                      ? Icons.volume_off_outlined
                      : Icons.volume_up_outlined,
                  size: 24,
                  color: Colors.white,
                ),
                Expanded(
                  child: SizedBox(
                    height: 8,
                    child: Center(
                      child: AnimatedContainer(
                        key: const ValueKey('video-adjustment-track'),
                        height: trackHeight,
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 100),
                        curve: Curves.easeOutCubic,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: percent / 100),
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 60),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) =>
                              LinearProgressIndicator(
                                value: value,
                                borderRadius: BorderRadius.circular(4),
                                color: Colors.white,
                                backgroundColor: Colors.white30,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
