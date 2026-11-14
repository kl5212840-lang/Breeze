import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

/// A stack action that appears only after meaningful vertical scrolling.
class ScrollReturnToTop extends StatelessWidget {
  const ScrollReturnToTop({
    super.key,
    required this.actionKey,
    required this.visible,
    required this.bottom,
    required this.onPressed,
  });

  final Key actionKey;
  final bool visible;
  final double bottom;
  final VoidCallback onPressed;

  static bool canReturn(ScrollMetrics metrics) {
    final threshold = metrics.viewportDimension * 1.5;
    return threshold > 0 &&
        metrics.maxScrollExtent - metrics.minScrollExtent > threshold &&
        metrics.extentBefore > threshold;
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final show = visible && MediaQuery.viewInsetsOf(context).bottom == 0;
    final label = t.download.jumpToTop;
    final native = usesNativeSourceChrome(context);
    final breeze = !AppInterfaceStyleScope.usesSystem(context);
    return Positioned(
      right: 0,
      bottom: bottom,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: show ? 1 : 0),
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        builder: (context, progress, child) {
          if (progress == 0) return const SizedBox.shrink();
          final control = breeze
              ? Material(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  child: child,
                )
              : child;
          final inset = 18 * progress;
          // Move the native control with layout, keeping its glass and shape.
          return Padding(
            padding: EdgeInsets.only(right: inset),
            child: IgnorePointer(
              ignoring: !show,
              child: ExcludeFocus(
                excluding: !show,
                child: ExcludeSemantics(
                  excluding: !show,
                  child: Opacity(opacity: progress, child: control),
                ),
              ),
            ),
          );
        },
        child: native || breeze
            ? VideoControlAppearance(
                systemControls: native,
                child: NativeVideoIconButton(
                  key: actionKey,
                  light: false,
                  size: 50,
                  iconSize: 24,
                  icon: Icons.vertical_align_top_rounded,
                  symbol: 'arrow.up.to.line',
                  tooltip: label,
                  onPressed: onPressed,
                ),
              )
            : Material(
                shape: const CircleBorder(),
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                child: IconButton(
                  key: actionKey,
                  tooltip: label,
                  constraints: const BoxConstraints.tightFor(
                    width: 50,
                    height: 50,
                  ),
                  onPressed: onPressed,
                  icon: const Icon(Icons.vertical_align_top_rounded, size: 24),
                ),
              ),
      ),
    );
  }
}
