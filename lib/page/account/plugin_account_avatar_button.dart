import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/account/plugin_account_avatar_frame.dart';
import 'package:zephyr/widgets/collection_press_feedback.dart';

/// A portrait opens the account task. A caller can supply a separate camera
/// action without overlapping or nesting the two hit targets.
class PluginAccountAvatarButton extends StatelessWidget {
  const PluginAccountAvatarButton({
    super.key,
    required this.size,
    required this.label,
    required this.onPressed,
    required this.child,
    this.hasAccount = true,
    this.flatRingColor,
  }) : assert(size >= 44);

  final double size;
  final String label;
  final VoidCallback? onPressed;
  final Widget child;
  final bool hasAccount;
  final Color? flatRingColor;

  @override
  Widget build(BuildContext context) {
    final portrait = PluginAccountAvatarFrame(
      size: size,
      hasAccount: hasAccount,
      flatRingColor: flatRingColor,
      child: child,
    );
    return onPressed == null
        ? portrait
        : Tooltip(
            message: label,
            child: CollectionPressFeedback(
              child: Stack(
                children: [
                  portrait,
                  Positioned.fill(
                    child: ClipOval(
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onPressed,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
  }
}
