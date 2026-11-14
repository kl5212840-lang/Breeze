import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/native_view_occlusion.dart';

/// A content-sized UIKit material behind task content. UIKit clips its own
/// background; nested native controls never inherit a Flutter rounded clip.
class NativeMaterialSurface extends StatelessWidget {
  const NativeMaterialSurface({
    super.key,
    required this.child,
    this.radius = 24,
    this.topOnly = false,
    this.systemStyle,
    this.floating = false,
    this.readableContent = false,
  });
  final Widget child;
  final double radius;
  final bool topOnly, floating;
  final bool? systemStyle;
  final bool readableContent;

  @override
  Widget build(BuildContext context) {
    final native =
        (systemStyle ?? AppInterfaceStyleScope.usesSystem(context)) &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        !context.select<GlobalSettingCubit?, bool>(
          (cubit) => cubit?.state.eInkSetting.enabled ?? false,
        );
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
                          Theme.of(context).brightness,
                          MediaQuery.highContrastOf(context),
                          radius,
                          topOnly,
                          readableContent,
                        )),
                        viewType: 'breeze.search.surface',
                        creationParams: {
                          'dark':
                              Theme.of(context).brightness == Brightness.dark,
                          'highContrast': MediaQuery.highContrastOf(context),
                          'panelRadius': radius,
                          'topOnly': topOnly,
                          'readableContent': readableContent,
                        },
                        creationParamsCodec: const StandardMessageCodec(),
                      ),
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: corners,
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        boxShadow:
                            floating && !MediaQuery.highContrastOf(context)
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
