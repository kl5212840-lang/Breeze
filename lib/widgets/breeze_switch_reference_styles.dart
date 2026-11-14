part of 'breeze_switch.dart';

extension _ReferenceSwitchStyles on _SwitchPainter {
  // zjssun: 144 × 74 pill, 58-unit thumb, 72-unit travel. The floating
  // mark fades out as its counterpart rotates onto the selected thumb.
  void _paintThumb(Canvas canvas, Size size) {
    final unit = size.width / 144;
    final track = _SwitchPainter._pill(size, 74 * unit);
    _focus(canvas, track);
    final dark = colors.scheme.brightness == Brightness.dark;
    final idle = dark ? colors.scheme.surfaceContainerHigh : colors.lightThumb;
    final ink = BreezeThemeColors.readableOn(colors.scheme.primary, idle);
    canvas.drawRRect(track, Paint()..color = _mix(idle, colors.onTrack));
    canvas.drawRRect(
      track.deflate(unit),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * unit
        ..color = _mix(ink, colors.onTrack),
    );

    final idleMark = (1 - progress * 3).clamp(0.0, 1.0);
    _drawSwitchMark(
      canvas,
      _thumbMark,
      Offset(_mirror(108 * unit, size.width), track.top + 36 * unit),
      40 * unit,
      ink.withValues(alpha: idleMark),
    );
    final thumb = Offset(
      _mirror((37 + 72 * position) * unit, size.width),
      track.top + 37 * unit,
    );
    canvas.drawCircle(
      thumb,
      29 * unit,
      Paint()..color = Color.lerp(ink, colors.lightThumb, position)!,
    );
    _drawSwitchMark(
      canvas,
      _thumbMark,
      thumb,
      40 * unit,
      ink.withValues(alpha: position),
      rotation: (rtl ? 1 : -1) * (pi / 2) * (1 - position),
    );
  }

  // teymr / vinodjangid07: a recessed circular power button with a lit
  // rim and halo when selected. Keep the halo inside the switch row.
  void _paintPower(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.height / 2;
    final disk = RRect.fromRectAndRadius(
      Rect.fromCircle(center: center, radius: radius),
      Radius.circular(radius),
    );
    _focus(canvas, disk);
    final scheme = colors.scheme;
    final dark = scheme.brightness == Brightness.dark;
    final idle = Color.lerp(
      scheme.surfaceContainerHigh,
      scheme.onSurface,
      .28,
    )!;
    final selected = BreezeThemeColors.readableOn(
      Color.lerp(colors.onTrack, scheme.primary, dark ? .45 : .25)!,
      colors.lightThumb,
    );
    final rim = BreezeThemeColors.readableOn(
      scheme.primary,
      scheme.surfaceContainerLow,
    );
    final accent = Color.lerp(
      scheme.primary,
      colors.lightThumb,
      dark ? .18 : .06,
    )!;
    if (progress > 0) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = accent.withValues(alpha: progress * (dark ? .62 : .43))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
    canvas.drawRRect(disk, Paint()..color = _mix(idle, selected));
    canvas.drawRRect(
      disk.deflate(.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = _mix(
          Color.lerp(idle, scheme.onSurface, .30)!,
          dark ? colors.lightThumb : rim,
        ),
    );
    final idleMark = BreezeThemeColors.readableOn(scheme.onSurface, idle);

    _drawSwitchMark(
      canvas,
      _powerMark,
      center,
      radius * .78,
      _mix(idleMark, colors.lightThumb),
    );
  }

  Color get _sparkIdle => Color.lerp(
    colors.scheme.inverseSurface,
    colors.onTrack,
    colors.scheme.brightness == Brightness.dark ? .88 : .55,
  )!;

  Color get _sparkAccent => BreezeThemeColors.readableOn(
    colors.scheme.tertiary,
    colors.lightThumb,
    minimumContrast: 3.05,
  );

  Color get _sparkTrackInk =>
      BreezeThemeColors.readableOn(colors.lightThumb, _sparkIdle);

  // swift_9148: paint the gradient and halo on the main switch layer.
  // The clipped star field repaints independently beneath the thumb.
  void _paintSparkTrack(Canvas canvas, Size size) {
    final track = _SwitchPainter._pill(size, size.width / 2);
    _focus(canvas, track);
    final dark = colors.scheme.brightness == Brightness.dark;
    final idle = _sparkIdle;
    final accent = _sparkAccent;
    final dimRim = Color.lerp(idle, _sparkTrackInk, .22)!;
    final edge = _mix(dimRim, accent);
    canvas.drawRRect(
      track,
      Paint()
        ..color = edge.withValues(alpha: progress * (dark ? .40 : .26))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawRRect(
      track,
      Paint()
        ..shader = LinearGradient(
          begin: rtl ? Alignment.centerRight : Alignment.centerLeft,
          end: rtl ? Alignment.centerLeft : Alignment.centerRight,
          colors: [_mix(idle, colors.onTrack), _mix(idle, accent)],
        ).createShader(track.outerRect),
    );
    canvas.drawRRect(
      track.deflate(.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = edge,
    );
  }

  void _paintSparkThumb(Canvas canvas, Size size) {
    final unit = size.width / 5;
    // Clamp the overshoot against the pill's visible edge at this scale.
    final travel = position.clamp(-.10, 1.10);
    final center = Offset(
      _mirror((1.25 + 2.5 * travel) * unit, size.width),
      size.height / 2,
    );
    canvas.drawCircle(
      center.translate(0, .10 * unit),
      unit,
      Paint()
        ..color = Colors.black.withValues(alpha: .28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    canvas.drawCircle(center, unit, Paint()..color = colors.lightThumb);
    final idleMark = BreezeThemeColors.readableOn(
      colors.scheme.onSurface,
      colors.lightThumb,
    );
    _drawSwitchMark(
      canvas,
      _sparkMark,
      center,
      (1.2 + .12 * progress) * unit,
      _mix(idleMark, _sparkAccent),
    );
  }
}

void _drawSwitchMark(
  Canvas canvas,
  Path mark,
  Offset center,
  double size,
  Color color, {
  double rotation = 0,
}) {
  if (color.a == 0) return;
  canvas.save();
  canvas.translate(center.dx, center.dy);
  if (rotation != 0) canvas.rotate(rotation);
  canvas.scale(size / 100);
  canvas.translate(-50, -50);
  canvas.drawPath(mark, Paint()..color = color);
  canvas.restore();
}

// swift_9148's 24-unit lightning path normalized to the common view box.
final _sparkMark = Path()
  ..moveTo(54.17, 8.33)
  ..lineTo(12.5, 58.33)
  ..lineTo(50, 58.33)
  ..lineTo(45.83, 91.67)
  ..lineTo(87.5, 41.67)
  ..lineTo(50, 41.67)
  ..close();
final _thumbMark = Path()
  ..moveTo(61.4, 18)
  ..cubicTo(55.9, 16.4, 50.1, 19.6, 48.5, 25.1)
  ..lineTo(47.7, 28)
  ..cubicTo(47.2, 29.9, 46.2, 31.6, 44.9, 33.1)
  ..lineTo(37.5, 41.3)
  ..cubicTo(36.2, 42.7, 36.3, 44.9, 37.7, 46.2)
  ..cubicTo(39.1, 47.5, 41.3, 47.4, 42.6, 46)
  ..lineTo(50, 37.8)
  ..cubicTo(52, 35.6, 53.5, 32.9, 54.4, 30)
  ..lineTo(55.2, 27.1)
  ..cubicTo(55.7, 25.3, 57.6, 24.2, 59.5, 24.7)
  ..cubicTo(61.4, 25.2, 62.4, 27.1, 61.9, 29)
  ..lineTo(61.1, 31.9)
  ..cubicTo(60.3, 34.8, 59, 37.5, 57.3, 39.9)
  ..cubicTo(56.5, 41, 56.5, 42.3, 57.1, 43.5)
  ..cubicTo(57.7, 44.7, 58.9, 45.4, 60.2, 45.4)
  ..lineTo(79.5, 45.4)
  ..cubicTo(80.8, 45.4, 81.8, 46.4, 81.8, 47.7)
  ..cubicTo(81.8, 49, 81.2, 49.5, 80.3, 49.9)
  ..cubicTo(79.2, 50.3, 78.4, 51.2, 78.1, 52.3)
  ..cubicTo(77.8, 53.4, 78.1, 54.6, 78.9, 55.4)
  ..cubicTo(79.3, 55.8, 79.5, 56.3, 79.5, 56.9)
  ..cubicTo(79.5, 58, 78.7, 59, 77.6, 59.2)
  ..cubicTo(76.4, 59.4, 75.4, 60.3, 75, 61.4)
  ..cubicTo(74.6, 62.5, 74.8, 63.8, 75.5, 64.8)
  ..cubicTo(75.8, 65.2, 76, 65.7, 76, 66.2)
  ..cubicTo(76, 67.2, 75.4, 68, 74.5, 68.4)
  ..cubicTo(72.8, 69.1, 71.9, 70.8, 72.4, 72.6)
  ..cubicTo(72.4, 72.8, 72.4, 73, 72.4, 73.2)
  ..cubicTo(72.4, 74.5, 71.4, 75.5, 70.1, 75.5)
  ..lineTo(56, 75.5)
  ..cubicTo(54.2, 75.5, 52.4, 75, 50.9, 74)
  ..lineTo(42, 68.1)
  ..cubicTo(40.4, 67, 38.3, 67.5, 37.2, 69.1)
  ..cubicTo(36.1, 70.7, 36.6, 72.8, 38.2, 73.9)
  ..lineTo(47.1, 79.8)
  ..cubicTo(49.8, 81.6, 52.9, 82.5, 56.1, 82.5)
  ..lineTo(70.2, 82.5)
  ..cubicTo(75.2, 82.5, 79.3, 78.5, 79.5, 73.5)
  ..cubicTo(81.6, 71.8, 83, 69.2, 83, 66.3)
  ..cubicTo(83, 63.4, 83, 65, 82.8, 64.4)
  ..cubicTo(85, 62.7, 86.5, 60, 86.5, 57)
  ..cubicTo(86.5, 54, 86.4, 55.1, 86.1, 54.3)
  ..cubicTo(87.8, 52.6, 88.8, 50.3, 88.8, 47.7)
  ..cubicTo(88.8, 42.6, 84.7, 38.4, 79.5, 38.4)
  ..lineTo(66.1, 38.4)
  ..cubicTo(66.8, 36.9, 67.4, 35.3, 67.8, 33.7)
  ..lineTo(68.6, 30.8)
  ..cubicTo(70.2, 25.3, 67, 19.5, 61.5, 17.9)
  ..lineTo(61.5, 17.9)
  ..close()
  ..moveTo(19.2, 40.7)
  ..cubicTo(16.6, 40.7, 14.6, 42.8, 14.6, 45.3)
  ..lineTo(14.6, 77.7)
  ..cubicTo(14.6, 80.3, 16.7, 82.3, 19.2, 82.3)
  ..lineTo(28.5, 82.3)
  ..cubicTo(31.1, 82.3, 33.1, 80.2, 33.1, 77.7)
  ..lineTo(33.1, 45.3)
  ..cubicTo(33.1, 42.7, 31, 40.7, 28.5, 40.7)
  ..lineTo(19.2, 40.7)
  ..close();
final _powerMark = Path()
  ..moveTo(56.25, 6.25)
  ..cubicTo(56.25, 2.793, 53.457, 0, 50, 0)
  ..cubicTo(46.543, 0, 43.75, 2.793, 43.75, 6.25)
  ..lineTo(43.75, 50)
  ..cubicTo(43.75, 53.457, 46.543, 56.25, 50, 56.25)
  ..cubicTo(53.457, 56.25, 56.25, 53.457, 56.25, 50)
  ..lineTo(56.25, 6.25)
  ..close()
  ..moveTo(28.0273, 23.5547)
  ..cubicTo(30.6836, 21.3477, 31.0352, 17.4023, 28.8281, 14.7461)
  ..cubicTo(26.6211, 12.0898, 22.6758, 11.7383, 20.0195, 13.9453)
  ..cubicTo(9.707, 22.5391, 3.125, 35.5078, 3.125, 50)
  ..cubicTo(3.125, 75.8789, 24.1211, 96.875, 50, 96.875)
  ..cubicTo(75.8789, 96.875, 96.875, 75.8789, 96.875, 50)
  ..cubicTo(96.875, 35.5078, 90.2734, 22.5391, 79.9609, 13.9453)
  ..cubicTo(77.3047, 11.7383, 73.3594, 12.1094, 71.1523, 14.7461)
  ..cubicTo(68.9453, 17.3828, 69.3164, 21.3477, 71.9531, 23.5547)
  ..cubicTo(79.5508, 29.8633, 84.3555, 39.375, 84.3555, 50)
  ..cubicTo(84.3555, 68.9844, 68.9648, 84.375, 49.9805, 84.375)
  ..cubicTo(30.9961, 84.375, 15.6055, 68.9844, 15.6055, 50)
  ..cubicTo(15.6055, 39.375, 20.4297, 29.8633, 28.0078, 23.5547)
  ..close();
