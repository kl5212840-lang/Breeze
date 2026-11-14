import 'package:material_ui/material_ui.dart';

/// Shared density for video browsing surfaces only; never changes the player
/// control bar or the rest of the application's plugins.
ThemeData videoBrowseTheme(ThemeData base) {
  final colors = base.colorScheme;
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  final button = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(64, 44)),
    shape: WidgetStatePropertyAll(shape),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    ),
  );
  return base.copyWith(
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      labelStyle: base.textTheme.labelLarge,
      selectedColor: colors.secondaryContainer,
      backgroundColor: colors.surfaceContainerLow,
      side: BorderSide(color: colors.outlineVariant),
    ),
    textButtonTheme: TextButtonThemeData(
      style: base.textButtonTheme.style?.merge(button) ?? button,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: base.outlinedButtonTheme.style?.merge(button) ?? button,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: base.filledButtonTheme.style?.merge(button) ?? button,
    ),
  );
}

/// Readable text on the system's thick task material, scoped to video tasks.
/// Semantic colors follow brightness; only the heading is semibold.
ThemeData videoReadableTaskTheme(ThemeData base) {
  final colors = base.colorScheme;
  final title = base.textTheme.titleMedium?.copyWith(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: colors.onSurface,
  );
  final body = base.textTheme.bodyLarge?.copyWith(
    fontSize: 17,
    fontWeight: FontWeight.w500,
    color: colors.onSurface,
  );
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      titleMedium: title,
      bodyLarge: body,
      titleSmall: base.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: colors.onSurface,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(color: colors.onSurface),
    ),
    iconTheme: base.iconTheme.copyWith(color: colors.onSurface),
    listTileTheme: base.listTileTheme.copyWith(
      minTileHeight: 44,
      titleTextStyle: body,
      textColor: colors.onSurface,
      iconColor: colors.onSurface,
      selectedColor: colors.onSurface,
      selectedTileColor: Colors.transparent,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      horizontalTitleGap: 10,
      minVerticalPadding: 4,
    ),
  );
}
