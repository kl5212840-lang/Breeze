import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/collection_selection_mark.dart';

/// A folder remains a folder at every cover size, including without artwork.
/// Artwork belongs to this folder; global work-cover privacy never replaces it.
/// The tab and identity mark remain visible above the artwork.
class BookshelfFolderVisual extends StatelessWidget {
  const BookshelfFolderVisual({
    super.key,
    this.imagePath,
    this.selected = false,
  });
  final String? imagePath;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final line = colors.outlineVariant;
    return CustomPaint(
      foregroundPainter: _FolderOutline(line),
      child: ClipPath(
        clipper: const _FolderClipper(),
        child: ColoredBox(
          color: colors.surfaceContainerLow,
          child: CollectionSelectionTint(
            selected: selected,
            child: LayoutBuilder(
              builder: (context, bounds) {
                final mark = (bounds.maxWidth * .19).clamp(18.0, 28.0);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imagePath case final String path)
                      Image.file(
                        File(path),
                        fit: BoxFit.cover,
                        // Bound decoding to the actual card, not the full edit.
                        cacheWidth:
                            (bounds.maxWidth *
                                    MediaQuery.devicePixelRatioOf(context))
                                .ceil(),
                        errorBuilder: (_, _, _) => const _FolderPaper(),
                      )
                    else
                      const _FolderPaper(),
                    Positioned(
                      right: 9,
                      bottom: 10,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: line),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.folder_outlined,
                            size: mark,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _FolderPaper extends StatelessWidget {
  const _FolderPaper();
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _FolderPaperPainter(
        colors.surfaceContainer,
        colors.outlineVariant,
      ),
    );
  }
}

// Broad, quiet paper planes fill the card rather than an enlarged app icon.
class _FolderPaperPainter extends CustomPainter {
  const _FolderPaperPainter(this.paper, this.line);
  final Color paper, line;
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final offset in [0.0, .045]) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * (.13 + offset),
          size.height * (.19 + offset),
          size.width * .70,
          size.height * .58,
        ),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, Paint()..color = paper);
      canvas.drawRRect(rect, stroke);
    }
    final front = Path()
      ..moveTo(0, size.height * .42)
      ..lineTo(size.width * .40, size.height * .42)
      ..quadraticBezierTo(
        size.width * .46,
        size.height * .42,
        size.width * .50,
        size.height * .47,
      )
      ..lineTo(size.width, size.height * .47)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(front, Paint()..color = paper);
    canvas.drawPath(front, stroke);
  }

  @override
  bool shouldRepaint(_FolderPaperPainter old) =>
      old.paper != paper || old.line != line;
}

Path _folderPath(Size size) {
  const radius = 8.0;
  final tab = (size.height * .065).clamp(5.0, 10.0);
  return Path()
    ..moveTo(radius, 0)
    ..lineTo(size.width * .34, 0)
    ..quadraticBezierTo(size.width * .39, 0, size.width * .42, tab)
    ..lineTo(size.width - radius, tab)
    ..quadraticBezierTo(size.width, tab, size.width, tab + radius)
    ..lineTo(size.width, size.height - radius)
    ..quadraticBezierTo(
      size.width,
      size.height,
      size.width - radius,
      size.height,
    )
    ..lineTo(radius, size.height)
    ..quadraticBezierTo(0, size.height, 0, size.height - radius)
    ..lineTo(0, radius)
    ..quadraticBezierTo(0, 0, radius, 0)
    ..close();
}

class _FolderClipper extends CustomClipper<Path> {
  const _FolderClipper();
  @override
  Path getClip(Size size) => _folderPath(size);
  @override
  bool shouldReclip(_FolderClipper old) => false;
}

class _FolderOutline extends CustomPainter {
  const _FolderOutline(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    _folderPath(size),
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );
  @override
  bool shouldRepaint(_FolderOutline old) => old.color != color;
}

/// Small folder identity for destination-picker rows; no icon backplate.
class BookshelfFolderIcon extends StatelessWidget {
  const BookshelfFolderIcon({super.key, this.selected = false, this.size = 44});
  final bool selected;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Icon(
      Icons.folder_outlined,
      size: size * .65,
      color: selected
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}
