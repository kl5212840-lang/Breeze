import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
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
  });
  final Widget child;
  final double radius;
  final bool topOnly, floating;
  final bool? systemStyle;
  final bool readableContent;
  final bool androidGlass;

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
        !eInk;
    final glass =
        androidGlass &&
        system &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        !highContrast &&
        !eInk;
    final corners = topOnly
        ? BorderRadius.vertical(top: Radius.circular(radius))
        : BorderRadius.circular(radius);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
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
                  ? ClipRRect(
                      borderRadius: corners,
                      child: BackdropFilter.grouped(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: ColoredBox(
                          color: theme.colorScheme.surfaceContainer.withValues(
                            alpha: theme.brightness == Brightness.dark
                                ? .78
                                : .86,
                          ),
                        ),
                      ),
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: corners,
                        color: theme.colorScheme.surfaceContainer,
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
}
