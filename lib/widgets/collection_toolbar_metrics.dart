import 'package:material_ui/material_ui.dart';

/// Align the trailing control slots of stacked collection toolbars.
abstract final class CollectionToolbarMetrics {
  static const horizontalInset = 12.0;
  static const actionExtent = 44.0;
  static const actionPlateInset = 4.0;
  static const actionPlateExtent = actionExtent - actionPlateInset * 2;
  static const searchControlGap = 8.0;
  static const sourceContentInset = 16.0;
  static const searchResultContentInset = 14.0;
  static const contentPadding = EdgeInsetsDirectional.symmetric(
    horizontal: sourceContentInset,
  );
  static const trailingPadding = EdgeInsetsDirectional.only(
    start: searchControlGap,
    end: sourceContentInset,
  );

  static double actionExtentOf(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.android ? 48 : actionExtent;

  static double leadingExtentOf(BuildContext context) =>
      sourceContentInset + actionExtentOf(context) + searchControlGap;

  static EdgeInsetsDirectional contentPaddingOf(
    BuildContext context, {
    double inset = sourceContentInset,
    double? startInset,
    double top = 0,
    double bottom = 0,
  }) {
    final safe = MediaQuery.paddingOf(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return EdgeInsetsDirectional.fromSTEB(
      (startInset ?? inset) + (rtl ? safe.right : safe.left),
      top,
      inset + (rtl ? safe.left : safe.right),
      bottom,
    );
  }

  static Widget leading(BuildContext context, Widget child) => Padding(
    padding: const EdgeInsetsDirectional.only(
      start: sourceContentInset,
      end: searchControlGap,
    ),
    child: Align(
      alignment: Alignment.center,
      child: SizedBox.square(dimension: actionExtentOf(context), child: child),
    ),
  );
}
