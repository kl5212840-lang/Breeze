import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/global/navigation_appearance.dart';
import 'package:zephyr/widgets/android_glass_plate.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_overlay_theme.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'package:zephyr/widgets/native_view_occlusion.dart';

/// Content-sized material behind task content. Keep native controls outside
/// the clip that bounds the background.
class NativeMaterialSurface extends StatelessWidget {
  const NativeMaterialSurface({
    super.key,
    required this.child,
    this.radius = 24,
    this.topOnly = false,
    this.systemStyle,
    this.floating = false,
    this.readableContent = false,
    this.androidGlass = false,
    this.androidBackdrop = true,
    this.androidNavigationTransparency = defaultNavigationTransparency,
  }) : _androidToolbar = false,
       _toolbarSelected = false;

  /// A small plate on a solid toolbar needs no backdrop capture.
  const NativeMaterialSurface.androidToolbar({
    super.key,
    required this.child,
    bool selected = false,
  }) : radius = 24,
       topOnly = false,
       systemStyle = null,
       floating = false,
       readableContent = false,
       androidGlass = true,
       androidBackdrop = false,
       androidNavigationTransparency = defaultNavigationTransparency,
       _androidToolbar = true,
       _toolbarSelected = selected;

  final Widget child;
  final double radius;
  final bool topOnly, floating;
  final bool? systemStyle;
  final bool readableContent;
  final bool androidGlass;

  /// Persistent chrome can stay translucent without resampling the page.
  final bool androidBackdrop;

  /// Percent transparency of the Android navigation plate.
  final int androidNavigationTransparency;
  final bool _androidToolbar;
  final bool _toolbarSelected;

  @override
  Widget build(BuildContext context) {
    final system = systemStyle ?? AppInterfaceStyleScope.usesSystem(context);
    final theme = Theme.of(context);
    final highContrast = MediaQuery.highContrastOf(context);
    final eInk =
        ((androidGlass && defaultTargetPlatform == TargetPlatform.android) ||
            defaultTargetPlatform == TargetPlatform.iOS) &&
        context.select<GlobalSettingCubit?, bool>(
          (cubit) => cubit?.state.eInkSetting.enabled ?? false,
        );
    final native =
        system &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        !(readableContent && highContrast) &&
        !eInk;
    final glass =
        androidGlass &&
        system &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        !highContrast &&
        !eInk;
    if (_androidToolbar && !glass) return child;
    final corners = topOnly
        ? BorderRadius.vertical(top: Radius.circular(radius))
        : BorderRadius.circular(radius);
    final inset = _androidToolbar
        ? CollectionToolbarMetrics.actionPlateInset
        : 0.0;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          left: inset,
          top: inset,
          right: inset,
          bottom: inset,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: native
                  ? NativeViewOcclusion(
                      child: UiKitView(
                        key: ValueKey((
                          theme.brightness,
                          highContrast,
                          radius,
                          topOnly,
                          readableContent,
                        )),
                        viewType: 'breeze.search.surface',
                        creationParams: {
                          'dark': theme.brightness == Brightness.dark,
                          'highContrast': highContrast,
                          'panelRadius': radius,
                          'topOnly': topOnly,
                          'readableContent': readableContent,
                        },
                        creationParamsCodec: const StandardMessageCodec(),
                      ),
                    )
                  : glass
                  ? _androidBackground(theme, corners)
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: corners,
                        color: readableContent && highContrast
                            ? theme.colorScheme.surface
                            : BreezeOverlayTheme.taskSurface(theme.colorScheme),
                        boxShadow: floating && !highContrast
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: .22),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                    ),
            ),
          ),
        ),
        Material(type: MaterialType.transparency, child: child),
      ],
    );
  }

  Widget _androidBackground(ThemeData theme, BorderRadius corners) {
    final colors = theme.colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final plate = AndroidGlassPlate(
      corners: corners,
      androidNavigationTransparency: androidNavigationTransparency,
      role: _androidToolbar
          ? (_toolbarSelected
                ? AndroidGlassRole.toolbarSelected
                : AndroidGlassRole.toolbar)
          : (androidBackdrop
                ? AndroidGlassRole.panel
                : AndroidGlassRole.navigation),
    );
    if (_androidToolbar) return plate;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: corners,
        boxShadow: floating
            ? [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: dark ? .24 : .085),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: androidBackdrop
          ? ClipRRect(
              borderRadius: corners,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                blendMode: BlendMode.src,
                child: plate,
              ),
            )
          : plate,
    );
  }
}
