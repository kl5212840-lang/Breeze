import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/bookshelf/widgets/facet_reorder_motion.dart';

/// Bounded, lazy checkbox rows shared by bookshelf and download facets.
/// Selected zero-count values remain actionable so a draft can be cleared.
class FacetOptionList extends StatelessWidget {
  const FacetOptionList({
    super.key,
    required this.values,
    required this.counts,
    required this.selected,
    required this.onToggle,
    required this.optionKey,
    this.label,
    this.trailing,
    this.empty,
    this.shrinkWrap = false,
    this.reorderController,
  });
  final List<String> values;
  final Map<String, int> counts;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final Key Function(String) optionKey;
  final String Function(String)? label;
  final Widget? Function(String)? trailing;
  final Widget? empty;
  final bool shrinkWrap;
  final FacetReorderController? reorderController;
  @override
  Widget build(BuildContext context) => CustomScrollView(
    shrinkWrap: shrinkWrap,
    primary: false,
    slivers: [
      FacetOptionSliver(
        values: values,
        counts: counts,
        selected: selected,
        onToggle: onToggle,
        optionKey: optionKey,
        label: label,
        trailing: trailing,
        empty: empty,
        reorderController: reorderController,
      ),
    ],
  );
}

class FacetOptionSliver extends StatelessWidget {
  const FacetOptionSliver({
    super.key,
    required this.values,
    required this.counts,
    required this.selected,
    required this.onToggle,
    required this.optionKey,
    this.label,
    this.trailing,
    this.empty,
    this.reorderController,
    this.query,
  });
  final List<String> values;
  final Map<String, int> counts;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final Key Function(String) optionKey;
  final String Function(String)? label;
  final Widget? Function(String)? trailing;
  final Widget? empty;
  final FacetReorderController? reorderController;
  final TextEditingController? query;
  @override
  Widget build(BuildContext context) {
    final search = query;
    if (search == null) return _options(values);
    // Searching within the option names does not change the data counts or
    // the result preview. Rebuild just this sliver while the user types.
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: search,
      builder: (_, value, _) {
        final text = value.text.trim().toLowerCase();
        return _options(
          text.isEmpty
              ? values
              : values.where((option) {
                  final name = label?.call(option) ?? option;
                  return name.toLowerCase().contains(text);
                }).toList(),
        );
      },
    );
  }

  Widget _options(List<String> values) {
    if (values.isEmpty) {
      return SliverToBoxAdapter(child: empty ?? const SizedBox.shrink());
    }
    final indices = {
      for (var i = 0; i < values.length; i++)
        ValueKey<Key>(optionKey(values[i])): i,
    };
    return SliverList.builder(
      itemCount: values.length,
      findChildIndexCallback: (key) => indices[key],
      itemBuilder: (context, index) {
        final value = values[index];
        final extra = trailing?.call(value);
        final row = Semantics(
          selected: selected.contains(value),
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  key: optionKey(value),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed:
                      (counts[value] ?? 0) > 0 || selected.contains(value)
                      ? () => onToggle(value)
                      : null,
                  child: Row(
                    children: [
                      Icon(
                        selected.contains(value)
                            ? Icons.check_box_outlined
                            : Icons.check_box_outline_blank,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(label?.call(value) ?? value)),
                      const SizedBox(width: 8),
                      Text('${counts[value] ?? 0}'),
                    ],
                  ),
                ),
              ),
              if (extra != null) extra,
            ],
          ),
        );
        final key = ValueKey<Key>(optionKey(value));
        return reorderController == null
            ? KeyedSubtree(key: key, child: row)
            : FacetReorderItem(
                key: key,
                controller: reorderController!,
                child: row,
              );
      },
    );
  }
}
