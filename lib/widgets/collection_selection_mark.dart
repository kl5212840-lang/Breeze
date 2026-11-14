import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/comic_simplify_entry/selection_badge.dart';

/// Decorative mark. The containing row/card owns the tap target and semantics.
class CollectionSelectionMark extends StatelessWidget {
  const CollectionSelectionMark({
    super.key,
    required this.visible,
    required this.selected,
  });

  static const inset = 10.0;
  static const size = 20.0;

  final bool visible, selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final highContrast = MediaQuery.highContrastOf(context);
    return ExcludeSemantics(
      child: IgnorePointer(
        child: ComicSelectionBadge(
          visible: visible,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: selected ? colors.primary : colors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: highContrast
                    ? colors.onSurface
                    : selected
                    ? colors.primary
                    : colors.outline,
              ),
            ),
            child: selected
                ? Icon(Icons.check_rounded, size: 15, color: colors.onPrimary)
                : null,
          ),
        ),
      ),
    );
  }
}

/// A light selection tint within the cover's existing clip and dimensions.
class CollectionSelectionTint extends StatelessWidget {
  const CollectionSelectionTint({
    super.key,
    required this.selected,
    required this.child,
  });

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 140),
    foregroundDecoration: BoxDecoration(
      color: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: selected ? .12 : 0),
    ),
    child: child,
  );
}
