import 'package:material_ui/material_ui.dart';

/// Keep the badge's subtree mounted through selection changes. Covers and rows
/// retain their identity; only the selection affordance fades/scales.
class ComicSelectionBadge extends StatelessWidget {
  const ComicSelectionBadge({
    super.key,
    required this.visible,
    required this.child,
  });
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160);
    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeSemantics(
        excluding: !visible,
        child: AnimatedScale(
          scale: visible ? 1 : 0,
          duration: duration,
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: duration,
            child: child,
          ),
        ),
      ),
    );
  }
}
