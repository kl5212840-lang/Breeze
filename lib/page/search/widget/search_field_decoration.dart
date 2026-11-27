import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:zephyr/i18n/strings.g.dart';
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
  final native = usesSystemSearchSurface(context);
  final android = usesAndroidSearchSurface(context);
  final highContrast = MediaQuery.highContrastOf(context);
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
      borderSide: highContrast || (!native && !android)
          ? BorderSide(color: colors.primary)
          : android
          ? BorderSide(color: colors.primary.withValues(alpha: .74))
          : BorderSide.none,
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

/// The leading action in a dedicated query field.
class SearchFieldSubmitButton extends StatelessWidget {
  const SearchFieldSubmitButton({
    super.key,
    required this.query,
    required this.onSubmitted,
  });

  final ValueListenable<TextEditingValue> query;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: query,
    builder: (context, value, _) => IconButton(
      tooltip: t.common.search,
      icon: const SearchToolGlyph(SearchTool.search, size: 22),
      onPressed: value.text.trim().isEmpty || onSubmitted == null
          ? null
          : () => onSubmitted!(value.text),
    ),
  );
}
