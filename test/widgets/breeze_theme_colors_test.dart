import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/breeze_control_colors.dart';
import 'package:zephyr/widgets/breeze_theme_colors.dart';

void main() {
  test('color wheel gamut produces layered surfaces with readable content', () {
    final seeds = [
      Colors.black,
      Colors.white,
      const Color(0xff888888),
      const Color(0xffcddc39),
      for (var hue = 0; hue < 360; hue += 15)
        for (final (saturation, value) in [
          (.1, .96),
          (.4, .45),
          (1.0, .13),
          (1.0, 1.0),
        ])
          HSVColor.fromAHSV(1, hue.toDouble(), saturation, value).toColor(),
    ];
    for (final seed in seeds) {
      for (final brightness in Brightness.values) {
        final colors = BreezeThemeColors.fromSeed(seed, brightness);
        final reason = '$seed $brightness';
        final native = BreezeControlColors.systemSegmentSelection(colors);
        final nativeContrast = BreezeThemeColors.contrast(
          native.fill,
          native.track,
        );
        expect(native.fill, isNot(Colors.white), reason: reason);
        expect(nativeContrast, greaterThanOrEqualTo(1.06), reason: reason);
        expect(
          nativeContrast,
          lessThan(
            BreezeThemeColors.contrast(
              colors.primaryContainer,
              colors.surfaceContainerLowest,
            ),
          ),
          reason: '$reason system segment stays below navigation',
        );
        expect(
          BreezeThemeColors.contrast(native.foreground, native.fill),
          greaterThanOrEqualTo(4.5),
          reason: reason,
        );
        final high = BreezeControlColors.systemSegmentSelection(
          colors,
          highContrast: true,
        );
        expect(
          BreezeThemeColors.contrast(high.fill, high.track),
          greaterThanOrEqualTo(3),
          reason: reason,
        );
        expect(
          BreezeThemeColors.contrast(high.foreground, high.fill),
          greaterThanOrEqualTo(4.5),
          reason: reason,
        );
        final bottomBarSurface = colors.surfaceContainerLowest;
        final selectedTabForeground = BreezeThemeColors.readableOn(
          colors.primary,
          bottomBarSurface,
        );
        for (final foreground in [
          selectedTabForeground,
          colors.onSurfaceVariant,
        ]) {
          expect(
            BreezeThemeColors.contrast(foreground, bottomBarSurface),
            greaterThanOrEqualTo(4.5),
            reason: '$reason bottom bar foreground',
          );
        }
        final surfaces = [
          colors.surface,
          colors.surfaceContainerLowest,
          colors.surfaceContainerLow,
          colors.surfaceBright,
          colors.surfaceContainerHighest,
        ];
        for (final background in surfaces) {
          for (final text in [colors.onSurface, colors.onSurfaceVariant]) {
            expect(
              BreezeThemeColors.contrast(text, background),
              greaterThanOrEqualTo(4.5),
              reason: reason,
            );
          }
        }
        expect(colors.surfaceContainerLow, isNot(Colors.white), reason: reason);
        expect(
          colors.surfaceContainerLow.computeLuminance(),
          greaterThan(colors.surface.computeLuminance()),
          reason: reason,
        );
        expect(
          colors.surfaceBright.computeLuminance(),
          greaterThan(colors.surfaceContainerLow.computeLuminance()),
          reason: reason,
        );
        for (final (text, fill) in [
          (colors.primary, colors.surface),
          (colors.onPrimary, colors.primary),
          (colors.onPrimaryContainer, colors.primaryContainer),
          (colors.onSecondaryContainer, colors.secondaryContainer),
          (colors.onInverseSurface, colors.inverseSurface),
          (colors.inversePrimary, colors.inverseSurface),
        ]) {
          expect(
            BreezeThemeColors.contrast(text, fill),
            greaterThanOrEqualTo(4.5),
            reason: reason,
          );
        }
        for (final surface in [
          colors.surface,
          colors.surfaceContainerLow,
          if (brightness == Brightness.dark) Colors.black,
        ]) {
          final theme = ThemeData(
            colorScheme: colors,
            scaffoldBackgroundColor: surface,
          );
          final bar = BreezeControlColors.navigationSurface(theme);
          for (final label in [colors.primary, colors.onSurfaceVariant]) {
            expect(
              BreezeThemeColors.contrast(
                BreezeThemeColors.readableOn(label, bar),
                bar,
              ),
              greaterThanOrEqualTo(4.5),
              reason: '$reason page-derived navigation foreground',
            );
          }
          final track = BreezeControlColors.track(theme);
          expect(
            track.computeLuminance(),
            greaterThan(surface.computeLuminance()),
          );
          for (final highContrast in [false, true]) {
            final navigation = BreezeControlColors.navigation(
              colors,
              highContrast: highContrast,
            );
            final navContrast = BreezeThemeColors.contrast(
              navigation.indicator,
              colors.surfaceContainerLowest,
            );
            expect(
              BreezeThemeColors.contrast(
                navigation.foreground,
                navigation.indicator,
              ),
              greaterThanOrEqualTo(4.5),
              reason: '$reason navigation label on the fill',
            );
            for (final localTrack in [null, track]) {
              final selection = BreezeControlColors.sectionSelection(
                theme,
                track: localTrack,
                highContrast: highContrast,
              );
              final backdrop = localTrack ?? surface;
              final separation = BreezeThemeColors.contrast(
                selection.fill,
                backdrop,
              );
              expect(
                separation,
                highContrast
                    ? greaterThanOrEqualTo(3)
                    : greaterThanOrEqualTo(1.06),
                reason: '$reason selection fill against the backdrop',
              );
              expect(
                separation,
                lessThan(navContrast),
                reason: '$reason local selection stays below navigation',
              );
              expect(
                BreezeThemeColors.contrast(
                  selection.foreground,
                  selection.fill,
                ),
                greaterThanOrEqualTo(4.5),
                reason: '$reason selected label on the fill',
              );
              if (localTrack == null && !highContrast) {
                expect(
                  BreezeThemeColors.contrast(
                    selection.foreground,
                    colors.onSurfaceVariant,
                  ),
                  greaterThanOrEqualTo(1.18),
                  reason: '$reason source label differs in luminance',
                );
              }
            }
          }
        }
      }
    }
  });

  test('tone correction handles both bright and dark backgrounds', () {
    for (final background in const [
      Color(0xfff8faef),
      Color(0xff23261d),
      Color(0xff777777),
    ]) {
      final ink = BreezeThemeColors.readableOn(background, background);
      expect(
        BreezeThemeColors.contrast(ink, background),
        greaterThanOrEqualTo(4.5),
      );
    }
  });
}
