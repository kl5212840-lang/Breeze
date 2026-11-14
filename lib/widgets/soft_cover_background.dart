import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

/// Reuses the foreground provider/cache key, keeping the original image whole
/// while filling its letterbox space with a quiet, local image background.
class SoftCoverBackground extends StatelessWidget {
  const SoftCoverBackground({
    super.key,
    required this.image,
    required this.child,
    this.enabled = true,
  });
  final ImageProvider image;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final surface = Theme.of(context).colorScheme.surface;
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: surface),
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: 12,
              sigmaY: 12,
              tileMode: TileMode.clamp,
            ),
            child: Image(
              image: image,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          ColoredBox(color: surface.withValues(alpha: .55)),
          child,
        ],
      ),
    );
  }
}
