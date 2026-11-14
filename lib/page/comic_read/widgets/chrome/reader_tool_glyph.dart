import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/widgets/collection_command_icons.dart';

/// Reader tools are painted inside the sliding Flutter controls. Keep the
/// glyph separate from the existing press, blur and transition layers.
class ReaderToolGlyph extends StatelessWidget {
  const ReaderToolGlyph(this.icon, {super.key, this.size = 24});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hasSystemGlyph = switch (icon) {
      Icons.skip_previous_rounded ||
      Icons.skip_next_rounded ||
      Icons.home_outlined ||
      Icons.view_list_outlined ||
      Icons.tune_rounded ||
      Icons.play_arrow_rounded ||
      Icons.pause_rounded => true,
      _ => false,
    };
    if (!hasSystemGlyph || !usesNativeSourceChrome(context)) {
      return CollectionCommandGlyph(icon, size: size);
    }
    final iconTheme = IconTheme.of(context);
    final color = iconTheme.color ?? Theme.of(context).colorScheme.onSurface;
    return CustomPaint(
      size: Size.square(size),
      painter: _ReaderToolPainter(
        icon,
        color.withValues(alpha: color.a * (iconTheme.opacity ?? 1)),
      ),
    );
  }
}

class _ReaderToolPainter extends CustomPainter {
  const _ReaderToolPainter(this.icon, this.color);

  final IconData icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final fill = Paint()..color = color;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (icon) {
      case Icons.skip_previous_rounded:
        canvas.translate(24, 0);
        canvas.scale(-1, 1);
        _drawChapterEnd(canvas, fill);
      case Icons.skip_next_rounded:
        _drawChapterEnd(canvas, fill);
      case Icons.home_outlined:
        canvas.drawPath(
          Path()
            ..moveTo(3, 11)
            ..lineTo(12, 3.5)
            ..lineTo(21, 11)
            ..moveTo(5.5, 9)
            ..lineTo(5.5, 19.5)
            ..quadraticBezierTo(5.5, 20.5, 6.5, 20.5)
            ..lineTo(10, 20.5)
            ..lineTo(10, 15)
            ..lineTo(14, 15)
            ..lineTo(14, 20.5)
            ..lineTo(17.5, 20.5)
            ..quadraticBezierTo(18.5, 20.5, 18.5, 19.5)
            ..lineTo(18.5, 9),
          line,
        );
      case Icons.view_list_outlined:
        for (final y in [6.0, 12.0, 18.0]) {
          canvas.drawCircle(Offset(4.5, y), 1.1, fill);
          canvas.drawLine(Offset(8.5, y), Offset(20, y), line);
        }
      case Icons.tune_rounded:
        for (final (x, y) in [(8.0, 6.0), (15.5, 12.0), (10.5, 18.0)]) {
          canvas.drawLine(Offset(3.5, y), Offset(x - 2, y), line);
          canvas.drawCircle(Offset(x, y), 2, line);
          canvas.drawLine(Offset(x + 2, y), Offset(20.5, y), line);
        }
      case Icons.play_arrow_rounded:
        _drawPlay(canvas, fill, left: 7.5, tip: 19);
      case Icons.pause_rounded:
        for (final x in [7.0, 13.25]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, 5, 3.75, 14),
              const Radius.circular(1.2),
            ),
            fill,
          );
        }
    }
    canvas.restore();
  }

  void _drawChapterEnd(Canvas canvas, Paint fill) {
    _drawPlay(canvas, fill, left: 4.5, tip: 16.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(17, 5, 2.75, 14),
        const Radius.circular(1),
      ),
      fill,
    );
  }

  void _drawPlay(
    Canvas canvas,
    Paint fill, {
    required double left,
    required double tip,
  }) {
    canvas.drawPath(
      Path()
        ..moveTo(left, 6.5)
        ..quadraticBezierTo(left, 4.7, left + 1.6, 5.6)
        ..lineTo(tip - 1, 10.9)
        ..quadraticBezierTo(tip + 1, 12, tip - 1, 13.1)
        ..lineTo(left + 1.6, 18.4)
        ..quadraticBezierTo(left, 19.3, left, 17.5)
        ..close(),
      fill,
    );
  }

  @override
  bool shouldRepaint(_ReaderToolPainter oldDelegate) =>
      oldDelegate.icon != icon || oldDelegate.color != color;
}
