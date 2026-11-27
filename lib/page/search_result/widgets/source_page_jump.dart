import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/search_result/widgets/page_skip.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';

class SourcePageJumpButton extends StatelessWidget {
  const SourcePageJumpButton({
    super.key,
    required this.label,
    this.onPressed,
    this.maxLines = 1,
  });

  final String label;
  final VoidCallback? onPressed;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extent = CollectionToolbarMetrics.actionExtentOf(context);
    return Tooltip(
      message: t.searchResult.jumpToPage,
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: Size.square(extent),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          textStyle: theme.textTheme.labelMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          padding: EdgeInsets.zero,
          alignment: AlignmentDirectional.centerStart,
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 14),
          ],
        ),
      ),
    );
  }
}

Future<int?> showSourcePageJumpDialog(
  BuildContext context, {
  required int page,
  int? totalPages,
}) => showNumberInputDialog(
  context: context,
  title: t.searchResult.jump,
  initialValue: page,
  hintText: totalPages == null ? null : '1–$totalPages',
);

int? topVisibleSourcePage(GlobalKey items, List<int?> pages) {
  final sliver = items.currentContext?.findRenderObject();
  if (sliver is! RenderSliverMultiBoxAdaptor ||
      sliver.geometry == null ||
      pages.isEmpty) {
    return null;
  }
  final top = sliver.constraints.scrollOffset;
  for (
    var child = sliver.firstChild;
    child != null;
    child = sliver.childAfter(child)
  ) {
    final start = sliver.childScrollOffset(child);
    if (start == null || !child.hasSize || start + child.size.height <= top) {
      continue;
    }
    final index = sliver.indexOf(child);
    return index < pages.length ? pages[index] : null;
  }
  return null;
}
