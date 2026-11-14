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
}) {
  final colors = Theme.of(context).colorScheme;
  final system = usesSystemSearchSurface(context);
  final inBreezeToolbar = SearchToolbarScope.of(context) != null;
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
      vertical: inBreezeToolbar ? 9 : 12,
    ),
    prefixIcon:
        prefixIcon ??
        const Center(
          widthFactor: 1,
          heightFactor: 1,
          child: SearchToolGlyph(SearchTool.search, size: 22),
        ),
    prefixIconConstraints: BoxConstraints(
      minWidth: 44,
      minHeight: inBreezeToolbar ? 44 : 48,
    ),
    suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    suffixIcon: SizedBox(width: 44, child: suffixIcon),
  );
}
