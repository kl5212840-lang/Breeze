import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/navigation_appearance.dart';

enum AndroidGlassRole {
  toolbar,
  toolbarSelected,
  search,
  navigation,
  selection,
  panel,
}

/// Shared optical treatment for Android chrome. The plate paints directly
/// over its background. Its host can supply one clipped blur for a popup.
class AndroidGlassPlate extends StatelessWidget {
  const AndroidGlassPlate({
    super.key,
    required this.role,
    required this.corners,
    this.androidNavigationTransparency = defaultNavigationTransparency,
  });

  static const _highlightEnd = .76;

  final AndroidGlassRole role;
  final BorderRadius corners;
  final int androidNavigationTransparency;

  static Color track(ColorScheme colors) => Color.alphaBlend(
    colors.onSurface.withValues(
      alpha: colors.brightness == Brightness.dark ? .07 : .065,
    ),
    colors.surface,
  );

  static Color selected(ColorScheme colors, Color track) =>
      colors.brightness == Brightness.dark
      ? Color.alphaBlend(colors.onSurface.withValues(alpha: .15), track)
      : Color.lerp(track, Colors.white, .84)!;

  static double navigationOpacity(int transparency) =>
      (100 - normalizeNavigationTransparency(transparency)) / 100;

  static Color _plateHighlight(bool dark) =>
      Colors.white.withValues(alpha: dark ? .07 : .18);

  static Color tint(ColorScheme colors, AndroidGlassRole role) {
    return switch (role) {
      AndroidGlassRole.toolbar => Color.alphaBlend(
        colors.onSurface.withValues(alpha: .04),
        colors.surface,
      ),
      AndroidGlassRole.toolbarSelected => Color.alphaBlend(
        colors.primary.withValues(alpha: .12),
        colors.surface,
      ),
      AndroidGlassRole.search => Color.alphaBlend(
        colors.onSurface.withValues(alpha: .05),
        colors.surface,
      ),
      AndroidGlassRole.navigation => track(colors),
      AndroidGlassRole.selection => selected(colors, track(colors)),
      AndroidGlassRole.panel => colors.surfaceContainerLow,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final opacity = switch (role) {
      AndroidGlassRole.toolbar ||
      AndroidGlassRole.toolbarSelected ||
      AndroidGlassRole.search => .89,
      AndroidGlassRole.navigation => navigationOpacity(
        androidNavigationTransparency,
      ),
      AndroidGlassRole.selection => .96,
      AndroidGlassRole.panel => dark ? .86 : .89,
    };
    final body = tint(colors, role).withValues(alpha: opacity);
    final isToolbarOrSearch =
        role == AndroidGlassRole.toolbar ||
        role == AndroidGlassRole.toolbarSelected ||
        role == AndroidGlassRole.search;
    return CustomPaint(
      foregroundPainter: role == AndroidGlassRole.navigation
          ? AndroidGlassNavigationRim(corners: corners, colors: colors)
          : null,
      painter: isToolbarOrSearch
          ? _ChromePlatePainter(
              corners: corners,
              body: body,
              light: dark ? colors.onSurface : colors.surfaceContainerLowest,
              shade: colors.onSurface,
              dark: dark,
            )
          : _GlassPlatePainter(
              corners: corners,
              body: body,
              role: role,
              dark: dark,
            ),
      child: const SizedBox.expand(),
    );
  }
}

/// A top edge catch and a soft lower edge on persistent, non-blurred chrome.
class _ChromePlatePainter extends CustomPainter {
  const _ChromePlatePainter({
    required this.corners,
    required this.body,
    required this.light,
    required this.shade,
    required this.dark,
  });

  final BorderRadius corners;
  final Color body, light, shade;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final shape = corners.toRRect(rect);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.alphaBlend(light.withValues(alpha: dark ? .028 : .17), body),
          body,
          Color.alphaBlend(shade.withValues(alpha: .013), body),
        ],
        stops: const [0, .56, 1],
      ).createShader(rect);
    canvas.drawRRect(shape, paint);

    if (size.shortestSide <= 1.5) return;
    paint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        light.withValues(alpha: dark ? .15 : .82),
        Colors.transparent,
        shade.withValues(alpha: dark ? .025 : .085),
      ],
      stops: const [0, .53, 1],
    ).createShader(rect);
    canvas.drawDRRect(shape, shape.deflate(.75), paint);
  }

  @override
  bool shouldRepaint(_ChromePlatePainter oldDelegate) =>
      corners != oldDelegate.corners ||
      body != oldDelegate.body ||
      light != oldDelegate.light ||
      shade != oldDelegate.shade ||
      dark != oldDelegate.dark;
}

class _GlassPlatePainter extends CustomPainter {
  const _GlassPlatePainter({
    required this.corners,
    required this.body,
    required this.role,
    required this.dark,
  });

  final BorderRadius corners;
  final Color body;
  final AndroidGlassRole role;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = corners.toRRect(rect);
    final floating = role == AndroidGlassRole.panel;
    final highlight = AndroidGlassPlate._plateHighlight(dark);
    final paint = Paint();
    if (role == AndroidGlassRole.selection) {
      paint.color = body;
    } else {
      paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color.alphaBlend(highlight, body), body],
        stops: const [0, AndroidGlassPlate._highlightEnd],
      ).createShader(rect);
    }
    canvas.drawRRect(shape, paint);

    if (!floating) return;
    paint.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: dark ? .23 : .68),
        Colors.white.withValues(alpha: dark ? .07 : .20),
        Colors.transparent,
      ],
      stops: const [0, .50, 1],
    ).createShader(rect);
    canvas.drawDRRect(shape, shape.deflate(.65), paint);
  }

  @override
  bool shouldRepaint(_GlassPlatePainter oldDelegate) =>
      corners != oldDelegate.corners ||
      body != oldDelegate.body ||
      role != oldDelegate.role ||
      dark != oldDelegate.dark;
}

/// A directional inner rim gives the bar and its current tab the same light.
/// The rim is drawn into the existing plate, without sampling the backdrop.
class AndroidGlassNavigationRim extends CustomPainter {
  const AndroidGlassNavigationRim({
    required this.corners,
    required this.colors,
    this.width = 1.35,
  });

  final BorderRadius corners;
  final ColorScheme colors;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.shortestSide <= width * 2) return;
    final rect = Offset.zero & size;
    final shape = corners.toRRect(rect);
    final dark = colors.brightness == Brightness.dark;
    final top = (dark ? colors.onSurface : colors.surfaceBright).withValues(
      alpha: dark ? .24 : .76,
    );
    final bottom = colors.shadow.withValues(alpha: dark ? .28 : .13);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          top,
          top.withValues(alpha: top.a * .28),
          bottom,
        ],
        stops: const [0, .42, 1],
      ).createShader(rect);
    canvas.drawDRRect(shape, shape.deflate(width), paint);
  }

  @override
  bool shouldRepaint(AndroidGlassNavigationRim oldDelegate) =>
      corners != oldDelegate.corners ||
      colors != oldDelegate.colors ||
      width != oldDelegate.width;
}
