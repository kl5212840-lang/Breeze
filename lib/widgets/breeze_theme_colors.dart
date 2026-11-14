import 'dart:math' as math;

import 'package:material_color_utilities/material_color_utilities.dart'
    show Hct, TonalPalette;
import 'package:material_ui/material_ui.dart';

/// Resolves the app's content colors from a user or system seed. The seed is
/// still the original swatch and is never replaced by a derived UI color.
abstract final class BreezeThemeColors {
  static final _recent = <(int, Brightness), ColorScheme>{};
  static final _corrected = <(int, int, double), Color>{};

  static ColorScheme fromSeed(Color seed, Brightness brightness) {
    final opaque = seed.withAlpha(255);
    final key = (opaque.toARGB32(), brightness);
    final colors = _recent.putIfAbsent(
      key,
      () => _resolve(
        opaque,
        ColorScheme.fromSeed(seedColor: opaque, brightness: brightness),
      ),
    );
    // A color-wheel drag can produce a new seed on every pointer update.
    if (_recent.length > 16) _recent.remove(_recent.keys.first);
    return colors;
  }

  static ColorScheme fromSystem(ColorScheme system) =>
      _resolve(system.primary, system);

  static ColorScheme _resolve(Color seed, ColorScheme base) {
    final hct = Hct.fromInt(seed.toARGB32());
    // HCT reports a small chroma even for RGB grays. Keep those seeds gray.
    final chroma = hct.chroma < 5 ? 0.0 : hct.chroma;
    final dark = base.brightness == Brightness.dark;
    final surface = TonalPalette.of(hct.hue, math.min(chroma * .14, 7));
    final accent = TonalPalette.of(hct.hue, math.min(chroma, 52));
    final selection = TonalPalette.of(hct.hue, math.min(chroma * .55, 27));
    final softSelection = TonalPalette.of(hct.hue, math.min(chroma * .30, 15));
    Color at(TonalPalette palette, int tone) => Color(palette.get(tone));

    final page = at(surface, dark ? 9 : 96);
    final group = at(surface, dark ? 15 : 98);
    final navigation = at(selection, dark ? 27 : 90);
    final selected = at(softSelection, dark ? 22 : 93);
    final primary = readableOn(at(accent, dark ? 84 : 35), page);
    final inverse = at(surface, dark ? 91 : 20);
    return base.copyWith(
      surface: page,
      surfaceDim: at(surface, dark ? 6 : 90),
      surfaceBright: at(surface, dark ? 28 : 99),
      surfaceContainerLowest: at(surface, dark ? 12 : 99),
      surfaceContainerLow: group,
      surfaceContainer: at(surface, dark ? 17 : 96),
      surfaceContainerHigh: at(surface, dark ? 22 : 93),
      surfaceContainerHighest: at(surface, dark ? 26 : 90),
      onSurface: at(surface, dark ? 92 : 14),
      onSurfaceVariant: at(surface, dark ? 72 : 34),
      outline: at(surface, dark ? 56 : 49),
      outlineVariant: at(surface, dark ? 36 : 80),
      surfaceTint: primary,
      inverseSurface: inverse,
      onInverseSurface: at(surface, dark ? 12 : 95),
      inversePrimary: readableOn(at(accent, dark ? 35 : 84), inverse),
      primary: primary,
      onPrimary: readableOn(at(surface, dark ? 12 : 99), primary),
      primaryContainer: navigation,
      onPrimaryContainer: readableOn(at(accent, dark ? 86 : 33), navigation),
      secondaryContainer: selected,
      onSecondaryContainer: readableOn(at(accent, dark ? 82 : 35), selected),
    );
  }

  static double contrast(Color foreground, Color background) {
    final a = foreground.computeLuminance() + .05;
    final b = background.computeLuminance() + .05;
    return math.max(a, b) / math.min(a, b);
  }

  /// Adjusts tone while keeping the intended hue as far as the gamut permits.
  /// The inputs are opaque colors on the surface that actually gets painted.
  static Color readableOn(
    Color foreground,
    Color background, {
    double minimumContrast = 4.5,
  }) {
    assert(minimumContrast >= 1 && minimumContrast <= 4.5);
    if (contrast(foreground, background) >= minimumContrast) return foreground;
    final key = (foreground.toARGB32(), background.toARGB32(), minimumContrast);
    final cached = _corrected[key];
    if (cached != null) return cached;
    final hct = Hct.fromInt(foreground.toARGB32());
    final palette = TonalPalette.of(hct.hue, hct.chroma);
    final darker =
        contrast(Colors.black, background) >=
        contrast(Colors.white, background);
    var fail = hct.tone.round();
    var pass = darker ? 0 : 100;
    while ((pass - fail).abs() > 1) {
      final tone = (fail + pass) ~/ 2;
      if (contrast(Color(palette.get(tone)), background) >= minimumContrast) {
        pass = tone;
      } else {
        fail = tone;
      }
    }
    final result = Color(palette.get(pass));
    _corrected[key] = result;
    if (_corrected.length > 32) _corrected.remove(_corrected.keys.first);
    return result;
  }
}
