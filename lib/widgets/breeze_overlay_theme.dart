import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/breeze_theme_colors.dart';

abstract final class BreezeOverlayTheme {
  static const menuRadius = BorderRadius.all(Radius.circular(20));
  static const dialogRadius = BorderRadius.all(Radius.circular(24));
  static const sheetRadius = BorderRadius.vertical(top: Radius.circular(24));
  static const menuPadding = EdgeInsets.symmetric(vertical: 6);

  static Color menuSurface(ColorScheme colors) =>
      colors.surfaceContainerLowest.withValues(alpha: 1);
  static Color alertSurface(ColorScheme colors) =>
      colors.surfaceContainerHigh.withValues(alpha: 1);
  static Color taskSurface(ColorScheme colors) =>
      colors.surfaceContainer.withValues(alpha: 1);

  /// Flutter fallbacks inherit these roles. Platform menus and custom task
  /// surfaces still choose their own materials and keep their route behavior.
  static ThemeData apply(ThemeData base) {
    final colors = base.colorScheme;
    final alert = alertSurface(colors);
    final menu = menuSurface(colors);
    final dialog = base.dialogTheme;
    final popup = base.popupMenuTheme;
    final text = base.textTheme;
    final menuText = (popup.textStyle ?? text.bodyLarge ?? const TextStyle())
        .copyWith(
          fontSize: 17,
          color: BreezeThemeColors.readableOn(colors.onSurface, menu),
        );
    return base.copyWith(
      dialogTheme: dialog.copyWith(
        backgroundColor: alert,
        surfaceTintColor: Colors.transparent,
        shape:
            dialog.shape ??
            const RoundedRectangleBorder(borderRadius: dialogRadius),
      ),
      popupMenuTheme: popup.copyWith(
        color: menu,
        surfaceTintColor: Colors.transparent,
        shape:
            popup.shape ??
            const RoundedRectangleBorder(borderRadius: menuRadius),
        menuPadding: popup.menuPadding ?? menuPadding,
        elevation: popup.elevation ?? 8,
        position: popup.position ?? PopupMenuPosition.under,
        textStyle: menuText,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? menuText.copyWith(
                  color: colors.onSurface.withValues(alpha: .38),
                )
              : menuText,
        ),
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        modalBackgroundColor: taskSurface(colors),
        surfaceTintColor: Colors.transparent,
        shape:
            base.bottomSheetTheme.shape ??
            const RoundedRectangleBorder(borderRadius: sheetRadius),
      ),
    );
  }
}
