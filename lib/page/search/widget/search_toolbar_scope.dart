import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';

/// Gives the search surface and its neighbouring controls one row height.
class SearchToolbarScope extends InheritedWidget {
  const SearchToolbarScope({
    required this.extent,
    required super.child,
    super.key,
  });

  final double? extent;

  static double? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SearchToolbarScope>()?.extent;

  static const actionExtent = CollectionToolbarMetrics.actionExtent;
  static const fieldActionWidth = 48.0;

  static double fieldExtent(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: 'Ag', style: Theme.of(context).textTheme.bodyLarge),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final extent = (painter.height.ceilToDouble() + 18).clamp(
      fieldActionWidth,
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
    return build(extent == null ? null : extent + 8).withSearchToolbar(extent);
  }

  @override
  bool updateShouldNotify(SearchToolbarScope oldWidget) =>
      extent != oldWidget.extent;
}

extension SearchToolbarBar on PreferredSizeWidget {
  PreferredSizeWidget withSearchToolbar(double? extent) => PreferredSize(
    preferredSize: preferredSize,
    child: SearchToolbarScope(extent: extent, child: this),
  );
}
