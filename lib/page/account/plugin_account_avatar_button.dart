import 'package:material_ui/material_ui.dart';
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
  }) : assert(size >= 44);

  final double size;
  final String label;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final portrait = SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (onPressed != null)
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onPressed,
                ),
              ),
          ],
        ),
      ),
    );
    return onPressed == null
        ? portrait
        : Tooltip(
            message: label,
            child: CollectionPressFeedback(child: portrait),
          );
  }
}
