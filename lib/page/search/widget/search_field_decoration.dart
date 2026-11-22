import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/search/widget/search_field_surface.dart';
import 'package:zephyr/page/search/widget/search_tool_glyph.dart';
import 'package:zephyr/page/search/widget/search_toolbar_scope.dart';

export 'package:zephyr/page/search/widget/search_field_surface.dart';

/// An explicit outline on every state prevents inherited underline themes
/// from drawing a second dark bar beneath the rounded search surface.
InputDecoration searchFieldDecoration(
  BuildContext context, {
  required String hintText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  bool variableSuffixWidth = false,
}) {
  final colors = Theme.of(context).colorScheme;
  final system = usesSystemSearchSurface(context);
  final touch = CollectionToolbarMetrics.actionExtentOf(context);
  final inSearchToolbar = SearchToolbarScope.of(context) != null;
  final shape = OutlineInputBorder(
    borderRadius: searchFieldRadius(context),
    borderSide: BorderSide.none,
  );
  return InputDecoration(
    hintText: hintText,
    hintMaxLines: 1,
    filled: false,
    border: shape,
    enabledBorder: shape,
    disabledBorder: shape,
    focusedBorder: shape.copyWith(
      borderSide: system && !MediaQuery.highContrastOf(context)
          ? BorderSide.none
          : BorderSide(color: colors.primary),
    ),
    errorBorder: shape.copyWith(borderSide: BorderSide(color: colors.error)),
    focusedErrorBorder: shape.copyWith(
      borderSide: BorderSide(color: colors.error),
    ),
    isDense: true,
    hintStyle: TextStyle(color: colors.onSurfaceVariant),
    contentPadding: EdgeInsets.symmetric(
      horizontal: 12,
      vertical: inSearchToolbar ? 9 : 12,
    ),
    prefixIcon:
        prefixIcon ??
        const Center(
          widthFactor: 1,
          heightFactor: 1,
          child: SearchToolGlyph(SearchTool.search, size: 22),
        ),
    prefixIconConstraints: BoxConstraints(
      minWidth: touch,
      minHeight: inSearchToolbar ? touch : 48,
    ),
    suffixIconConstraints: BoxConstraints(minWidth: touch, minHeight: touch),
    suffixIcon: variableSuffixWidth
        ? suffixIcon
        : SizedBox(width: touch, child: suffixIcon),
  );
}
