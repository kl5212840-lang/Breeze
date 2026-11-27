import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';

/// Scope and counts form the left reading group; the filter has a fixed trailing
/// slot, regardless of a missing folder selector or a short/long folder name.
class CollectionResultsRow extends StatelessWidget {
  const CollectionResultsRow({
    super.key,
    required this.countLabel,
    this.filterButton,
    this.scope,
    this.sortAction,
    this.viewAction,
    this.countKey,
    this.countSemanticsLabel,
    this.startInset,
    this.horizontalInset = CollectionToolbarMetrics.sourceContentInset,
    this.sortWidth,
    this.extraAction,
    this.inlineScope = false,
  });
  final String countLabel;
  final String? countSemanticsLabel;
  final Widget? scope, sortAction, filterButton, viewAction, extraAction;
  final Key? countKey;
  final double horizontalInset;
  final double? startInset, sortWidth;
  final bool inlineScope;
  @override
  Widget build(BuildContext context) {
    final actionExtent = CollectionToolbarMetrics.actionExtentOf(context);
    const gap = CollectionToolbarMetrics.searchControlGap;
    final actions = [
      if (sortAction != null)
        SizedBox(
          width: sortWidth ?? actionExtent,
          height: actionExtent,
          child: sortAction,
        ),
      for (final action in [?filterButton, ?viewAction])
        SizedBox.square(dimension: actionExtent, child: action),
    ];
    final theme = Theme.of(context);
    final count = countLabel.isEmpty
        ? null
        : Text(
            countLabel,
            key: countKey,
            semanticsLabel: countSemanticsLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );
    return Padding(
      padding: CollectionToolbarMetrics.contentPaddingOf(
        context,
        inset: horizontalInset,
        startInset: startInset,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (scope != null && inlineScope) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: gap,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: gap,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [scope!, ?count],
                  ),
                ),
                ...actions,
                ?extraAction,
              ],
            );
          }
          final minimumLabels = MediaQuery.textScalerOf(context).scale(144);
          final scopeOnOwnRow =
              scope != null &&
              count != null &&
              constraints.maxWidth <
                  actions.length * (actionExtent + gap) +
                      (sortWidth == null ? 0 : sortWidth! - actionExtent) +
                      minimumLabels;
          final tools = Row(
            spacing: gap,
            children: [
              if (scope != null && !scopeOnOwnRow)
                Expanded(flex: 2, child: scope!),
              if (count != null || scope == null || scopeOnOwnRow)
                Expanded(child: count ?? const SizedBox.shrink()),
              ...actions,
              ?extraAction,
            ],
          );
          return scopeOnOwnRow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [scope!, tools],
                )
              : tools;
        },
      ),
    );
  }
}
