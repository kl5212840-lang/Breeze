import 'package:material_ui/material_ui.dart';

/// Only the artwork changes tone. Its bounds and the surrounding controls
/// stay intact while the source is enabled or disabled.
class PluginIconVeil extends StatelessWidget {
  const PluginIconVeil({
    super.key,
    required this.enabled,
    required this.radius,
    required this.child,
  });

  final bool enabled;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return AnimatedScale(
      scale: enabled ? 1 : .90,
      duration: duration,
      curve: Curves.easeOutCubic,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: TweenAnimationBuilder<double>(
          duration: duration,
          curve: Curves.easeOutCubic,
          tween: Tween(end: enabled ? 0 : 1),
          builder: (context, amount, artwork) {
            // A neutral veil alone leaves bright colors visible. Mix each
            // channel toward its luminance while retaining the icon details.
            final color = 1 - amount;
            final red = .2126 * amount;
            final green = .7152 * amount;
            final blue = .0722 * amount;
            return DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                color: const Color(0xFFBDBDBD).withValues(alpha: .32 * amount),
              ),
              child: ImageFiltered(
                enabled: amount > 0,
                imageFilter: ColorFilter.matrix([
                  red + color,
                  green,
                  blue,
                  0,
                  0,
                  red,
                  green + color,
                  blue,
                  0,
                  0,
                  red,
                  green,
                  blue + color,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                ]),
                child: artwork!,
              ),
            );
          },
          child: child,
        ),
      ),
    );
  }
}
