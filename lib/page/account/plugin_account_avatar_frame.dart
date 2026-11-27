import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/native_material_surface.dart';

/// An account portrait keeps its outer footprint while the native material
/// shows through a narrow rim. Only the Flutter portrait is clipped.
class PluginAccountAvatarFrame extends StatelessWidget {
  const PluginAccountAvatarFrame({
    super.key,
    required this.size,
    required this.child,
    this.hasAccount = true,
    this.flatRingColor,
  });

  final double size;
  final Widget child;
  final bool hasAccount;
  final Color? flatRingColor;

  @override
  Widget build(BuildContext context) {
    final native =
        hasAccount &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        AppInterfaceStyleScope.usesSystem(context) &&
        !context.select<GlobalSettingCubit?, bool>(
          (cubit) => cubit?.state.eInkSetting.enabled ?? false,
        );
    final inset = native ? 3.0 : (flatRingColor == null ? 0.0 : 4.0);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (native)
            Positioned.fill(
              child: NativeMaterialSurface(
                radius: size / 2,
                child: const SizedBox.expand(),
              ),
            )
          else if (flatRingColor case final color?)
            Positioned.fill(
              child: ClipOval(child: ColoredBox(color: color)),
            ),
          Padding(
            padding: EdgeInsets.all(inset),
            child: ClipOval(child: child),
          ),
        ],
      ),
    );
  }
}
