import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/color_theme_types.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';
import 'package:zephyr/widgets/breeze_overlay_theme.dart';
import 'package:zephyr/widgets/breeze_theme_colors.dart';

void main() {
  test('overlay roles are opaque and readable across application palettes', () {
    final seeds = [
      ...colorThemeList.map((item) => item.color),
      const Color(0xff000000),
      const Color(0xffffffff),
      const Color(0xff00ff00),
      const Color(0xff00ffff),
      const Color(0xffff00ff),
    ];
    for (final brightness in Brightness.values) {
      final palettes = [
        for (final seed in seeds) BreezeThemeColors.fromSeed(seed, brightness),
        for (final seed in [Colors.brown, Colors.indigo])
          BreezeThemeColors.fromSystem(
            ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
          ),
      ];
      final branded = sourceOriginalPinkTheme(
        BreezeOverlayTheme.apply(ThemeData(brightness: brightness)),
      );
      final themes = [
        for (final colors in palettes)
          BreezeOverlayTheme.apply(ThemeData(colorScheme: colors)),
        branded,
      ];
      for (final theme in themes) {
        final colors = theme.colorScheme;
        final alert = theme.dialogTheme.backgroundColor!;
        final menu = theme.popupMenuTheme.color!;
        final task = theme.bottomSheetTheme.modalBackgroundColor!;
        expect(alert, BreezeOverlayTheme.alertSurface(colors));
        expect(menu, BreezeOverlayTheme.menuSurface(colors));
        expect(task, BreezeOverlayTheme.taskSurface(colors));
        for (final surface in [alert, menu, task]) {
          expect(surface.a, 1);
          expect(
            BreezeThemeColors.contrast(colors.onSurface, surface),
            greaterThanOrEqualTo(4.5),
          );
        }
        final menuLabel = theme.popupMenuTheme.labelTextStyle!.resolve({})!;
        expect(
          menuLabel.color,
          BreezeThemeColors.readableOn(colors.onSurface, menu),
        );
        expect(
          BreezeThemeColors.contrast(menuLabel.color!, menu),
          greaterThanOrEqualTo(4.5),
        );
        expect(theme.dialogTheme.surfaceTintColor, Colors.transparent);
        expect(theme.popupMenuTheme.surfaceTintColor, Colors.transparent);
        expect(theme.bottomSheetTheme.surfaceTintColor, Colors.transparent);
      }
    }
  });
}
