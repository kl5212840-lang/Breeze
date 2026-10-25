import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// The outer plugin route must not win iOS edge-back over an internal location.
/// Only a narrow leading-edge horizontal gesture is handled; normal scrolling,
/// video gestures, and root-route dismissal keep their existing behavior.
class VideoBackGesture extends StatefulWidget {
  const VideoBackGesture({
    super.key,
    required this.enabled,
    required this.onBack,
    required this.child,
    this.previousPage,
  });
  final bool enabled;
  final AsyncCallback onBack;
  final Widget child;
  final Widget? previousPage;

  @override
  State<VideoBackGesture> createState() => _VideoBackGestureState();
}

class _VideoBackGestureState extends State<VideoBackGesture>
    with SingleTickerProviderStateMixin {
  late final _position = AnimationController(vsync: this);
  double _distance = 0;
  int _gesture = 0;
  bool _settling = false;

  @override
  void didUpdateWidget(covariant VideoBackGesture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled && _position.value > 0) {
      _gesture++;
      _position.stop();
      _distance = 0;
      _settling = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.enabled) _position.value = 0;
      });
    }
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  Future<void> _finish(bool commit, int gesture) async {
    if (!mounted || gesture != _gesture) return;
    if (!commit && _position.value == 0) return;
    _settling = true;
    try {
      await _position
          .animateTo(
            commit ? 1 : 0,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
          )
          .orCancel;
      if (!mounted || gesture != _gesture) return;
      if (commit && widget.enabled) await widget.onBack();
    } on TickerCanceled {
      // A system cancellation or a disposed route never commits navigation.
    } finally {
      if (mounted && gesture == _gesture) {
        _position.value = 0;
        _settling = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final reducedMotion = MediaQuery.disableAnimationsOf(context);
      final direction = Directionality.of(context) == TextDirection.rtl
          ? -1
          : 1;
      return Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _position,
            child: widget.child,
            builder: (context, child) => Stack(
              fit: StackFit.expand,
              children: [
                if (_position.value > 0)
                  ExcludeSemantics(
                    child: IgnorePointer(
                      child: Transform.translate(
                        key: const ValueKey('video-back-preview-transition'),
                        offset: Offset(
                          reducedMotion
                              ? 0
                              : -direction *
                                    size.maxWidth *
                                    0.25 *
                                    (1 - _position.value),
                          0,
                        ),
                        child:
                            widget.previousPage ??
                            ColoredBox(
                              color: Theme.of(context).colorScheme.surface,
                            ),
                      ),
                    ),
                  ),
                Transform.translate(
                  key: const ValueKey('video-back-transition'),
                  offset: Offset(
                    direction * size.maxWidth * _position.value,
                    0,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: _position.value == 0
                          ? []
                          : const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 16,
                                offset: Offset(-4, 0),
                              ),
                            ],
                    ),
                    child: AbsorbPointer(absorbing: _settling, child: child),
                  ),
                ),
              ],
            ),
          ),
          if (widget.enabled && defaultTargetPlatform == TargetPlatform.iOS)
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              width: 22,
              child: Listener(
                behavior: HitTestBehavior.translucent,
                // Accepted drags can end when a pointer is cancelled by the system.
                onPointerDown: (_) {
                  if (!_settling) _gesture++;
                },
                onPointerCancel: (_) {
                  _gesture++;
                  _distance = 0;
                  _position.stop();
                  unawaited(_finish(false, _gesture));
                },
                child: GestureDetector(
                  key: const ValueKey('video-internal-back-edge'),
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragStart: (_) {
                    if (!_settling) _distance = 0;
                  },
                  onHorizontalDragUpdate: (details) {
                    if (_settling) return;
                    _distance =
                        (_distance + (details.primaryDelta ?? 0) * direction)
                            .clamp(0, size.maxWidth);
                    _position.value = _distance / size.maxWidth;
                  },
                  onHorizontalDragCancel: () {
                    _distance = 0;
                    unawaited(_finish(false, _gesture));
                  },
                  onHorizontalDragEnd: (details) {
                    if (_settling) return;
                    final shouldBack =
                        _position.value >= 0.35 ||
                        (_distance >= 24 &&
                            (details.primaryVelocity ?? 0) * direction >= 500);
                    _distance = 0;
                    final gesture = _gesture;
                    // The recognizer may receive cancellation before Listener does.
                    // Commit only after that same pointer event has fully dispatched.
                    scheduleMicrotask(() {
                      if (!mounted || gesture != _gesture || !widget.enabled) {
                        return;
                      }
                      unawaited(_finish(shouldBack, gesture));
                    });
                  },
                ),
              ),
            ),
        ],
      );
    },
  );
}
