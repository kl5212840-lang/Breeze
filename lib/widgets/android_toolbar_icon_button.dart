import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/android_glass_plate.dart';
import 'package:zephyr/widgets/breeze_control_motion.dart';
import 'package:zephyr/widgets/breeze_theme_colors.dart';
import 'package:zephyr/widgets/collection_press_feedback.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'package:zephyr/widgets/native_material_surface.dart';

/// Android page chrome draws one shared plate and keeps the entire command
/// slot interactive. The glyph alone responds to a pointer press.
class AndroidToolbarIconButton extends StatelessWidget {
  const AndroidToolbarIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selected,
  });

  final String tooltip;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final extent = CollectionToolbarMetrics.actionExtentOf(context);
    final highContrast = MediaQuery.highContrastOf(context);
    final role = selected == true
        ? AndroidGlassRole.toolbarSelected
        : AndroidGlassRole.toolbar;
    final fill = AndroidGlassPlate.tint(colors, role);
    final ink = BreezeThemeColors.readableOn(
      selected == true ? colors.primary : colors.onSurface,
      fill,
    );
    return SizedBox.square(
      dimension: extent,
      child: NativeMaterialSurface.androidToolbar(
        selected: selected == true,
        child: CollectionPressFeedback.builder(
          enabled: onPressed != null,
          pressedBuilder: (context, pressed) => IconButton(
            tooltip: tooltip,
            icon: BreezePressedContent(pressed: pressed, child: icon),
            isSelected: selected,
            onPressed: onPressed,
            style:
                IconButton.styleFrom(
                  minimumSize: Size.square(extent),
                  fixedSize: Size.square(extent),
                  visualDensity: VisualDensity.standard,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                  foregroundColor: ink,
                  disabledForegroundColor: colors.onSurface.withValues(
                    alpha: .38,
                  ),
                  backgroundColor: Colors.transparent,
                  splashFactory: NoSplash.splashFactory,
                  shape: const CircleBorder(),
                ).copyWith(
                  overlayColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.focused)
                        ? colors.primary.withValues(
                            alpha: highContrast ? .24 : .13,
                          )
                        : Colors.transparent,
                  ),
                ),
          ),
        ),
      ),
    );
  }
}
