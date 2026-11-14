part of 'breeze_switch.dart';

class _SparkThumbPainter extends CustomPainter {
  const _SparkThumbPainter(this.switchPainter);

  final _SwitchPainter switchPainter;

  @override
  void paint(Canvas canvas, Size size) =>
      switchPainter._paintSparkThumb(canvas, size);

  @override
  bool shouldRepaint(_SparkThumbPainter oldDelegate) =>
      switchPainter.shouldRepaint(oldDelegate.switchPainter);
}

class _SparkParticleLayer extends StatefulWidget {
  const _SparkParticleLayer({
    required this.checked,
    required this.rtl,
    required this.animate,
    required this.offColor,
    required this.onColor,
  });

  final bool checked, rtl, animate;
  final Color offColor, onColor;

  @override
  State<_SparkParticleLayer> createState() => _SparkParticleLayerState();
}

class _SparkParticleLayerState extends State<_SparkParticleLayer>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _visibilityKey = UniqueKey();
  final _frame = ValueNotifier(0);
  late final Ticker _ticker;
  int _frameAtResume = 0;
  bool _visible = false;
  bool _routeActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker((elapsed) {
      // The source runs at the browser's frame rate. Cap the particle
      // layer at 60 updates per second on high-refresh displays.
      _frame.value =
          _frameAtResume +
          elapsed.inMicroseconds * 60 ~/ Duration.microsecondsPerSecond;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeActive =
        TickerMode.valuesOf(context).enabled &&
        ModalRoute.isCurrentOf(context) != false;
    _syncTicker();
  }

  @override
  void didUpdateWidget(_SparkParticleLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) {
      _visible = false;
      VisibilityDetectorController.instance.forget(_visibilityKey);
    }
    if (oldWidget.checked != widget.checked) {
      // CSS restarts the individual timelines when drift changes to warp.
      _ticker.stop();
      _frame.value = 0;
    }
    _syncTicker();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _syncTicker();

  void _syncTicker() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final active =
        widget.animate &&
        _visible &&
        _routeActive &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
    if (active == _ticker.isActive) return;
    if (active) {
      _frameAtResume = _frame.value;
      _ticker.start();
    } else {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    VisibilityDetectorController.instance.forget(_visibilityKey);
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final particles = RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: widget.checked ? 1.0 : 0.0),
        duration: widget.animate
            ? const Duration(milliseconds: 300)
            : Duration.zero,
        curve: Curves.ease,
        builder: (context, shape, _) => CustomPaint(
          key: const ValueKey('breeze.switch.spark.particles'),
          painter: _SparkParticlesPainter(
            frame: widget.animate ? _frame : null,
            checked: widget.checked,
            rtl: widget.rtl,
            shape: shape,
            color: Color.lerp(widget.offColor, widget.onColor, shape)!,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
    if (!widget.animate) return particles;
    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: (info) {
        if (!mounted) return;
        _visible = info.visibleFraction > 0;
        _syncTicker();
      },
      child: particles,
    );
  }
}

class _SparkParticlesPainter extends CustomPainter {
  _SparkParticlesPainter({
    required this.frame,
    required this.checked,
    required this.rtl,
    required this.shape,
    required this.color,
  }) : super(repaint: frame);

  final ValueListenable<int>? frame;
  final bool checked, rtl;
  final double shape;
  final Color color;

  // Top, idle diameter, then period and delay in seconds for each mode.
  static const _stars = [
    (.4, .15, 3.0, 0.0, .4, 0.0),
    (1.2, .20, 4.0, 1.0, .6, .1),
    (2.0, .10, 2.5, .5, .3, .2),
    (.8, .15, 5.0, 2.0, .5, .15),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 5;
    final track = _SwitchPainter._pill(size, 2.5 * unit);
    final seconds = (frame?.value ?? 0) / 60;
    final paint = Paint();
    canvas.save();
    canvas.clipRRect(track);
    for (final (index, star) in _stars.indexed) {
      final (top, diameter, driftPeriod, driftDelay, warpPeriod, warpDelay) =
          star;
      final delay = checked ? warpDelay : driftDelay;
      final period = checked ? warpPeriod : driftPeriod;
      if (frame != null && seconds < delay) continue;

      final t = frame == null
          ? .19 + index * .16
          : ((seconds - delay) % period) / period;
      final opacity = t < .1
          ? t * 10
          : checked
          ? (1 - t) / .9
          : t > .9
          ? (1 - t) * 10
          : 1.0;
      final width = (diameter + (1.5 - diameter) * shape) * unit;
      final height = (diameter + (.1 - diameter) * shape) * unit;
      final center = (5 - 6 * t) * unit + width / 2;
      final bounds = Rect.fromCenter(
        center: Offset(
          rtl ? size.width - center : center,
          track.top + top * unit + height / 2,
        ),
        width: width * (checked ? 1 + t : 1),
        height: height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bounds, Radius.circular(height / 2)),
        paint..color = color.withValues(alpha: opacity * (.82 + .08 * shape)),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SparkParticlesPainter oldDelegate) =>
      checked != oldDelegate.checked ||
      rtl != oldDelegate.rtl ||
      shape != oldDelegate.shape ||
      color != oldDelegate.color ||
      frame != oldDelegate.frame;
}
