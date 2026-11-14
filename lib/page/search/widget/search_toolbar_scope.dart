import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

/// Centers Breeze search fields and neighbouring controls on one line.
/// Ordinary toolbars and UIKit controls keep their own dimensions.
class SearchToolbarScope extends InheritedWidget {
  const SearchToolbarScope({
    required this.extent,
    required super.child,
    super.key,
  });

  final double? extent;

  static double? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SearchToolbarScope>()?.extent;

  static const actionExtent = 44.0;

  static double? breezeExtent(BuildContext context) {
    if (AppInterfaceStyleScope.usesSystem(context)) return null;
    final painter = TextPainter(
      text: TextSpan(text: 'Ag', style: Theme.of(context).textTheme.bodyLarge),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final extent = (painter.height.ceilToDouble() + 18).clamp(
      actionExtent,
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
    final extent = searching ? breezeExtent(context) : null;
    final bar = build(extent == null ? null : extent + 8);
    if (extent == null) return bar;
    return PreferredSize(
      preferredSize: bar.preferredSize,
      child: SearchToolbarScope(extent: extent, child: bar),
    );
  }

  @override
  bool updateShouldNotify(SearchToolbarScope oldWidget) =>
      extent != oldWidget.extent;
}
