import 'package:material_ui/material_ui.dart';

/// Platform pairs for the common commands that change a visible result set.
abstract final class CollectionCommandIcons {
  static const sort = (
    icon: Icons.swap_vert_rounded,
    symbol: 'arrow.up.arrow.down',
  );
  static const grid = (
    icon: Icons.grid_view_outlined,
    symbol: 'square.grid.2x2',
  );
  static const list = (icon: Icons.view_list_outlined, symbol: 'list.bullet');
  static const filter = (
    icon: Icons.filter_list_rounded,
    symbol: 'line.3.horizontal.decrease',
  );
}

/// Breeze's line icons are drawn on the same optical canvas. Native controls
/// draw their corresponding system symbol; their hit boxes are independent.
class CollectionCommandGlyph extends StatelessWidget {
  const CollectionCommandGlyph(this.icon, {super.key, this.size = 22});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final command = switch (icon) {
      Icons.swap_vert_rounded || Icons.sort_rounded || Icons.sort => 0,
      Icons.grid_view_outlined || Icons.grid_view_rounded => 1,
      Icons.view_list_outlined || Icons.view_list_rounded => 2,
      Icons.filter_list_rounded || Icons.filter_list => 3,
      _ => null,
    };
    if (command == null) return Icon(icon, size: size);
    return CustomPaint(
      size: Size.square(size),
      painter: _CommandPainter(
        command,
        IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class _CommandPainter extends CustomPainter {
  const _CommandPainter(this.command, this.color);
  final int command;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.55
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void line(double x1, double y1, double x2, double y2) =>
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), stroke);
    switch (command) {
      case 0:
        canvas.drawPath(
          Path()
            ..moveTo(3.5, 8.5)
            ..lineTo(7.5, 4.5)
            ..lineTo(11.5, 8.5)
            ..moveTo(7.5, 4.5)
            ..lineTo(7.5, 19.5)
            ..moveTo(12.5, 15.5)
            ..lineTo(16.5, 19.5)
            ..lineTo(20.5, 15.5)
            ..moveTo(16.5, 19.5)
            ..lineTo(16.5, 4.5),
          stroke,
        );
      case 1:
        for (final x in [4.0, 13.5]) {
          for (final y in [4.0, 13.5]) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(x, y, 6.5, 6.5),
                const Radius.circular(1.4),
              ),
              stroke,
            );
          }
        }
      case 2:
        final dot = Paint()..color = color;
        for (final y in [6.0, 12.0, 18.0]) {
          canvas.drawCircle(Offset(5, y), 1, dot);
          line(9, y, 20, y);
        }
      case 3:
        line(4, 6, 20, 6);
        line(7, 12, 17, 12);
        line(10, 18, 14, 18);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CommandPainter oldDelegate) =>
      oldDelegate.command != command || oldDelegate.color != color;
}
