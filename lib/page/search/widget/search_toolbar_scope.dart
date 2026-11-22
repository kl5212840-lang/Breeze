import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';

/// Carries the search field geometry without changing adjacent command sizes.
class SearchToolbarScope extends InheritedWidget {
  const SearchToolbarScope({
    required this.extent,
    this.onClose,
    this.closeKey,
    this.leadingControl,
    this.leadingWidth = 64,
    required super.child,
    super.key,
  });

  final double? extent;
  final VoidCallback? onClose;
  final Key? closeKey;
  final Widget? leadingControl;
  final double leadingWidth;

  static SearchToolbarScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SearchToolbarScope>();

  static double stableHeight(BuildContext context, double titleHeight) =>
      (fieldExtent(context) + CollectionToolbarMetrics.searchControlGap).clamp(
        titleHeight,
        double.infinity,
      );

  static double? of(BuildContext context) => maybeOf(context)?.extent;

  static const actionExtent = CollectionToolbarMetrics.actionExtent;
  static const _minimumFieldHeight = 48.0;

  static double fieldExtent(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: 'Ag', style: Theme.of(context).textTheme.bodyLarge),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final extent = (painter.height.ceilToDouble() + 18).clamp(
      _minimumFieldHeight,
      double.infinity,
    );
    painter.dispose();
    return extent;
  }

  static PreferredSizeWidget appBar(
    BuildContext context,
    PreferredSizeWidget Function(double? toolbarHeight) build, {
    bool searching = true,
  }) {
    final extent = searching ? fieldExtent(context) : null;
    return build(
      extent == null
          ? null
          : extent + CollectionToolbarMetrics.searchControlGap,
    ).withSearchToolbar(extent);
  }

  @override
  bool updateShouldNotify(SearchToolbarScope oldWidget) =>
      extent != oldWidget.extent ||
      onClose != oldWidget.onClose ||
      closeKey != oldWidget.closeKey ||
      leadingControl != oldWidget.leadingControl ||
      leadingWidth != oldWidget.leadingWidth;
}

extension SearchToolbarBar on PreferredSizeWidget {
  PreferredSizeWidget withSearchToolbar(double? extent) => PreferredSize(
    preferredSize: preferredSize,
    child: SearchToolbarScope(extent: extent, child: this),
  );
}
