import 'package:material_ui/material_ui.dart';
import 'package:zephyr/util/text/chinese_convert.dart';

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
  });

  final List<String> categories;
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (categories.isNotEmpty)
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = categories[index];
                final blocked = blockedCategories.contains(category);
                final tint = _categoryColors[index % _categoryColors.length];
                final fill = blocked
                    ? scheme.surfaceContainerHighest
                    : Color.lerp(tint, scheme.surface, isDark ? 0.55 : 0.16)!;
                return Center(
                  child: Tooltip(
                    message: blocked ? '点击恢复' : '点击屏蔽',
                    child: ActionChip(
                      key: ValueKey('category-$category'),
                      label: Text(convertChineseForDisplay(category)),
                      avatar: blocked
                          ? const Icon(Icons.block, size: 15)
                          : null,
                      backgroundColor: fill,
                      labelStyle: TextStyle(
                        color: blocked
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                      ),
                      side: BorderSide(
                        color: blocked ? scheme.outlineVariant : tint,
                      ),
                      onPressed: () => onCategoryTap(category),
                    ),
                  ),
                );
              },
            ),
          ),
        SizedBox(
          height: 44,
          child: Row(
            children: [
              const SizedBox(width: 12),
              if (blockedCategories.isNotEmpty &&
                  onClearBlockedCategories != null)
                if (pageLabel != null)
                  IconButton(
                    tooltip: '清除屏蔽 (${blockedCategories.length})',
                    onPressed: onClearBlockedCategories,
                    icon: const Icon(Icons.filter_alt_off_outlined),
                  )
                else
                  TextButton(
                    onPressed: onClearBlockedCategories,
                    child: Text('清除屏蔽 (${blockedCategories.length})'),
                  )
              else if (categories.isNotEmpty)
                Text(
                  '点标签可屏蔽',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              if (pageLabel != null && onPageTap != null)
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    minimumSize: const Size(0, 40),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onPageTap,
                  child: Text(pageLabel!),
                ),
              const Spacer(),
              if (sortOptions.isNotEmpty)
                PopupMenuButton<String>(
                  tooltip: '排序',
                  initialValue: sortValue,
                  onSelected: onSortChanged,
                  itemBuilder: (context) => [
                    for (final option in sortOptions.entries)
                      PopupMenuItem(
                        value: option.key,
                        child: Text(option.value),
                      ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          sortOptions[sortValue] ?? sortOptions.values.first,
                        ),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
              IconButton(
                key: viewToggleKey,
                tooltip: detailedView ? '切换网格' : '切换列表',
                icon: Icon(detailedView ? Icons.grid_view : Icons.view_list),
                onPressed: () => onViewChanged(!detailedView),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ],
    );
  }
}
