import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_theme_colors.dart';

/// Breeze control surfaces: neutral at rest, tinted when they convey state.
abstract final class BreezeControlColors {
  static Color _pageSurface(ThemeData theme) => Color.alphaBlend(
    theme.scaffoldBackgroundColor,
    theme.colorScheme.surface,
  );

  static Color track(ThemeData theme) {
    final colors = theme.colorScheme;
    final page = _pageSurface(theme);
    if (colors.brightness == Brightness.dark) {
      return Color.alphaBlend(colors.onSurface.withValues(alpha: .06), page);
    }
    return Color.lerp(page, colors.surfaceBright, .72)!;
  }

  static Color tool(ColorScheme colors) =>
      colors.onSurface.withValues(alpha: .055);

  static Color selected(ColorScheme colors) => colors.secondaryContainer;

  static ({Color fill, Color foreground}) sectionSelection(
    ThemeData theme, {
    Color? track,
    bool highContrast = false,
  }) {
    final colors = theme.colorScheme;
    final backdrop = track ?? _pageSurface(theme);
    // Both local selections sit between their backdrop and the navigation
    // accent. A source chip needs less tint than a full segment.
    final fill = highContrast
        ? BreezeThemeColors.readableOn(
            selected(colors),
            backdrop,
            minimumContrast: 3.05,
          )
        : Color.lerp(
            backdrop,
            colors.primaryContainer,
            track == null ? .52 : .68,
          )!;
    final label = track == null
        ? Color.lerp(colors.onSecondaryContainer, colors.onSurface, .5)!
        : colors.onSecondaryContainer;
    return (fill: fill, foreground: BreezeThemeColors.readableOn(label, fill));
  }

  static ({Color track, Color fill, Color foreground}) systemSegmentSelection(
    ColorScheme colors, {
    bool highContrast = false,
  }) {
    final dark = colors.brightness == Brightness.dark;
    final track = dark
        ? colors.surfaceContainerLow
        : Color.lerp(colors.surfaceDim, colors.surfaceContainerHigh, .5)!;
    final raised = dark ? colors.surfaceBright : colors.surfaceContainerLow;
    final tint = Color.lerp(raised, colors.secondaryContainer, .55)!;
    final fill = highContrast
        ? BreezeThemeColors.readableOn(
            tint,
            dark ? colors.surfaceContainerHigh : track,
            minimumContrast: 3.05,
          )
        : tint;
    final label = Color.lerp(
      colors.onSecondaryContainer,
      colors.onSurface,
      .46,
    )!;
    return (
      track: track,
      fill: fill,
      foreground: BreezeThemeColors.readableOn(label, fill),
    );
  }

  /// Follow the effective page (including a plugin palette or pure black),
  /// with a quiet tonal separation from content.
  static Color navigationSurface(ThemeData theme) => Color.alphaBlend(
    theme.colorScheme.onSurface.withValues(alpha: .045),
    _pageSurface(theme),
  );

  // Navigation is a persistent location cue. Give it its own tone so source
  // filters and ordinary actions keep their lighter selection surfaces.
  static ({Color indicator, Color foreground}) navigation(
    ColorScheme colors, {
    Color? backdrop,
    bool highContrast = false,
  }) {
    if (!highContrast) {
      return (
        indicator: colors.primaryContainer,
        foreground: colors.onPrimaryContainer,
      );
    }
    final indicator = BreezeThemeColors.readableOn(
      colors.primaryContainer,
      backdrop ?? colors.surfaceContainerLowest,
      minimumContrast: 3.4,
    );
    return (
      indicator: indicator,
      foreground: BreezeThemeColors.readableOn(
        colors.onPrimaryContainer,
        indicator,
      ),
    );
  }
}

/// Applies the Breeze paint roles inside the effective application or plugin
/// style scope. Routes and sheets capture this theme with their color scheme.
class BreezeControlTheme extends StatelessWidget {
  const BreezeControlTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final existing = theme.getAdaptation<SwitchThemeData>();
    final breeze = !AppInterfaceStyleScope.usesSystem(context);
    final active = existing is _BreezeSwitchAdaptation;
    return Theme(
      data: breeze == active
          ? theme
          : theme.copyWith(
              adaptations: [
                for (final adaptation in theme.adaptationMap.values)
                  if (adaptation is! _BreezeSwitchAdaptation) adaptation,
                if (breeze) const _BreezeSwitchAdaptation(),
              ],
            ),
      child: child,
    );
  }
}

class _BreezeSwitchAdaptation extends Adaptation<SwitchThemeData> {
  const _BreezeSwitchAdaptation();

  @override
  SwitchThemeData adapt(ThemeData theme, SwitchThemeData defaultValue) {
    if (theme.platform != TargetPlatform.iOS &&
        theme.platform != TargetPlatform.macOS) {
      return defaultValue;
    }
    final colors = theme.colorScheme;
    final fill = BreezeThemeColors.readableOn(
      Color.lerp(
        colors.primary,
        colors.surface,
        colors.brightness == Brightness.dark ? .59 : .17,
      )!,
      Colors.white,
    );
    return defaultValue.copyWith(
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected) &&
            !states.contains(WidgetState.disabled)) {
          return fill;
        }
        return defaultValue.trackColor?.resolve(states);
      }),
    );
  }
}
