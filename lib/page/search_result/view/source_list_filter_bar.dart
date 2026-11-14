import 'package:material_ui/material_ui.dart';
import 'package:zephyr/util/text/chinese_convert.dart';
import 'package:zephyr/page/source_shell/source_list_view_toggle.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/widgets/source_choice_menu.dart';

/// Shared controls for source search and personal record lists.
class SourceListFilterBar extends StatelessWidget {
  const SourceListFilterBar({
    super.key,
    required this.categories,
    required this.blockedCategories,
    required this.onCategoryTap,
    this.onClearBlockedCategories,
    required this.sortValue,
    required this.sortOptions,
    required this.onSortChanged,
    required this.detailedView,
    required this.onViewChanged,
    this.viewToggleKey,
    this.pageLabel,
    this.onPageTap,
    this.leading,
    this.trailingAction,
    this.categoriesOnly = false,
    this.lockedCategories = const {},
    this.onLockedCategoryTap,
    this.contentInset,
  });

  final List<String> categories;
  final Widget? leading, trailingAction;
  final Set<String> blockedCategories;
  final ValueChanged<String> onCategoryTap;
  final VoidCallback? onClearBlockedCategories;
  final String sortValue;
  final Map<String, String> sortOptions;
  final ValueChanged<String> onSortChanged;
  final bool detailedView;
  final ValueChanged<bool> onViewChanged;
  final Key? viewToggleKey;
  final String? pageLabel;
  final VoidCallback? onPageTap;
  final bool categoriesOnly;
  final Set<String> lockedCategories;
  final ValueChanged<String>? onLockedCategoryTap;
  final double? contentInset;

  static const _categoryColors = <Color>[
    Color(0xFFF4B546),
    Color(0xFFE98AB0),
    Color(0xFF829BEE),
    Color(0xFF86CBA5),
    Color(0xFFB69DDF),
    Color(0xFFEEA17D),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final display = watchChineseDisplayConverter(context);
    final clear = SourceChromeIconButton(
      key: const ValueKey('source-list.clear-blocked'),
      tooltip: '清除屏蔽 (${blockedCategories.length})',
      onPressed: onClearBlockedCategories,
      icon: Icons.filter_alt_off_outlined,
      symbol: 'xmark',
    );
    final painter = TextPainter(
      text: TextSpan(text: '标签', style: Theme.of(context).textTheme.labelLarge),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final categoryHeight = (painter.height + 20).clamp(44.0, double.infinity);
    painter.dispose();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (categories.isNotEmpty ||
            categoriesOnly &&
                blockedCategories.isNotEmpty &&
                onClearBlockedCategories != null)
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: categoryHeight,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final blocked = blockedCategories.contains(category);
                      final locked = lockedCategories.contains(category);
                      final tint =
                          _categoryColors[index % _categoryColors.length];
                      final fill = blocked
                          ? scheme.surfaceContainerHighest
                          : Color.lerp(
                              tint,
                              scheme.surface,
                              isDark ? 0.83 : 0.84,
                            )!;
                      return Center(
                        child: Tooltip(
                          message: locked
                              ? '已在插件设置中屏蔽'
                              : blocked
                              ? '点击恢复'
                              : '点击屏蔽',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: locked
                                ? () => onLockedCategoryTap?.call(category)
                                : null,
                            child: ActionChip(
                              key: ValueKey('category-$category'),
                              visualDensity: const VisualDensity(
                                horizontal: -2,
                                vertical: -1,
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              labelPadding: EdgeInsets.zero,
                              label: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text(
                                      display(category),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  if (blocked)
                                    PositionedDirectional(
                                      start: 0,
                                      top: 0,
                                      bottom: 0,
                                      child: Center(
                                        child: Icon(
                                          locked
                                              ? Icons.lock_outline
                                              : Icons.block,
                                          size: 15,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              backgroundColor: fill,
                              disabledColor: scheme.surfaceContainerHighest,
                              labelStyle: TextStyle(
                                color: locked
                                    ? scheme.onSurface.withValues(alpha: .38)
                                    : blocked
                                    ? scheme.onSurfaceVariant
                                    : scheme.onSurface,
                              ),
                              side: BorderSide(
                                color: blocked
                                    ? scheme.outlineVariant
                                    : tint.withValues(alpha: .45),
                              ),
                              onPressed: locked
                                  ? null
                                  : () => onCategoryTap(category),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (categoriesOnly &&
                  blockedCategories.isNotEmpty &&
                  onClearBlockedCategories != null)
                clear,
            ],
          ),
        if (!categoriesOnly)
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              contentInset ?? 12,
              0,
              contentInset ?? 8,
              4,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final hasClear =
                    blockedCategories.isNotEmpty &&
                    onClearBlockedCategories != null;
                final sortWidth = SourceChoiceMenu.triggerWidth(
                  context,
                  sortOptions.values,
                  selectionIndicator: true,
                  maximumWidth: (constraints.maxWidth - 60).clamp(
                    44.0,
                    double.infinity,
                  ),
                );
                final sort = SourceChoiceMenu<String>(
                  key: const ValueKey('source-list.sort'),
                  tooltip: '排序',
                  label:
                      sortOptions[sortValue] ??
                      sortOptions.values.firstOrNull ??
                      '',
                  value: sortValue,
                  options: sortOptions,
                  optionIcons: {
                    for (final key in sortOptions.keys)
                      key: (
                        icon: Icons.sort_rounded,
                        symbol: 'arrow.up.arrow.down',
                      ),
                  },
                  selectionIndicator: true,
                  fitToOptions: true,
                  fillAvailableWidth: true,
                  maximumWidth: sortWidth,
                  onChanged: onSortChanged,
                );
                return Row(
                  key: const ValueKey('source-list.management'),
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          key: const ValueKey('source-list.manage-actions'),
                          children: [
                            ?leading,
                            if (pageLabel != null && onPageTap != null)
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: scheme.onSurfaceVariant,
                                  minimumSize: const Size(44, 44),
                                ),
                                onPressed: onPageTap,
                                child: Text(pageLabel!),
                              ),
                            if (sortOptions.isNotEmpty)
                              SizedBox(width: sortWidth, child: sort),
                            if (hasClear) clear,
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    ?trailingAction,
                    SourceListViewToggle(
                      key: viewToggleKey,
                      detailed: detailedView,
                      onChanged: onViewChanged,
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}
