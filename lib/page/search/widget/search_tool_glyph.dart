import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/search/widget/search_field_surface.dart';

enum SearchTool {
  search(Icons.search_rounded),
  clear(Icons.cancel_rounded),
  close(Icons.close_rounded),
  selectAll(Icons.select_all_rounded),
  deselectAll(Icons.deselect_rounded),
  trash(Icons.delete_outline_rounded);

  const SearchTool(this.breezeIcon);

  final IconData breezeIcon;
}

/// Search editing and history controls retain their Flutter hit testing and
/// share the same glyph style without inserting UIKit views into their clips.
class SearchToolGlyph extends StatelessWidget {
  const SearchToolGlyph(this.action, {super.key, required this.size});

  final SearchTool action;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (!usesSystemSearchSurface(context)) {
      return Icon(action.breezeIcon, size: size);
    }
    final theme = IconTheme.of(context);
    final color = theme.color ?? Theme.of(context).colorScheme.onSurface;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _SearchToolGlyphPainter(
          action,
          color.withValues(alpha: color.a * (theme.opacity ?? 1)),
        ),
      ),
    );
  }
}

class _SearchToolGlyphPainter extends CustomPainter {
  const _SearchToolGlyphPainter(this.action, this.color);

  final SearchTool action;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (action) {
      case SearchTool.search:
        canvas.drawCircle(const Offset(10.3, 10.3), 6, line);
        canvas.drawLine(const Offset(14.6, 14.6), const Offset(20, 20), line);
      case SearchTool.clear:
        final glyph = Path()
          ..fillType = PathFillType.evenOdd
          ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 9))
          ..moveTo(12, 10.85)
          ..lineTo(15.05, 7.8)
          ..lineTo(16.2, 8.95)
          ..lineTo(13.15, 12)
          ..lineTo(16.2, 15.05)
          ..lineTo(15.05, 16.2)
          ..lineTo(12, 13.15)
          ..lineTo(8.95, 16.2)
          ..lineTo(7.8, 15.05)
          ..lineTo(10.85, 12)
          ..lineTo(7.8, 8.95)
          ..lineTo(8.95, 7.8)
          ..close();
        canvas.drawPath(glyph, Paint()..color = color);
      case SearchTool.close:
        canvas.drawLine(const Offset(6.5, 6.5), const Offset(17.5, 17.5), line);
        canvas.drawLine(const Offset(6.5, 17.5), const Offset(17.5, 6.5), line);
      case SearchTool.selectAll:
      case SearchTool.deselectAll:
        canvas.drawCircle(const Offset(12, 12), 8.5, line);
        if (action == SearchTool.selectAll) {
          canvas.drawPath(
            Path()
              ..moveTo(8, 12)
              ..lineTo(10.7, 14.7)
              ..lineTo(16, 9.4),
            line,
          );
        }
      case SearchTool.trash:
        canvas.drawPath(
          Path()
            ..moveTo(6.4, 7)
            ..lineTo(7.3, 19.6)
            ..quadraticBezierTo(7.4, 20.7, 8.5, 20.7)
            ..lineTo(15.5, 20.7)
            ..quadraticBezierTo(16.6, 20.7, 16.7, 19.6)
            ..lineTo(17.6, 7)
            ..moveTo(4.7, 7)
            ..lineTo(19.3, 7)
            ..moveTo(9.7, 7)
            ..lineTo(9.7, 4)
            ..lineTo(14.3, 4)
            ..lineTo(14.3, 7)
            ..moveTo(10.5, 10.5)
            ..lineTo(10.5, 17)
            ..moveTo(13.5, 10.5)
            ..lineTo(13.5, 17),
          line,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SearchToolGlyphPainter oldDelegate) =>
      oldDelegate.action != action || oldDelegate.color != color;
}
