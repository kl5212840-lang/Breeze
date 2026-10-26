import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/comic_list/scene_filter/plugin_list_filter_schema.dart';
import 'package:zephyr/i18n/strings.g.dart';

/// A draft-only task sheet. Only Apply returns a new filter selection.
class PluginListFilterDialog extends StatefulWidget {
  const PluginListFilterDialog({
    super.key,
    required this.scheme,
    required this.initialSelections,
    this.defaultSelections = const {},
  });

  final PluginListFilterSchema scheme;
  final Map<String, String> initialSelections;
  final Map<String, String> defaultSelections;

  @override
  State<PluginListFilterDialog> createState() => _PluginListFilterDialogState();
}

class _PluginListFilterDialogState extends State<PluginListFilterDialog> {
  late final Map<String, String> _selections;
  final _expanded = <String>{};
  final _queries = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _selections = Map<String, String>.from(widget.initialSelections);
  }

  @override
  void dispose() {
    for (final controller in _queries.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _reset() {
    setState(() {
      _selections
        ..clear()
        ..addAll(
          widget.scheme
              .resolve(
                requestedSelections: widget.defaultSelections,
                defaultSelections: widget.defaultSelections,
              )
              .selections,
        );
      _expanded.clear();
      for (final query in _queries.values) {
        query.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fields = [
      ...widget.scheme.fields.where((field) => field.options.length <= 12),
      ...widget.scheme.fields.where((field) => field.options.length > 12),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = MediaQuery.viewInsetsOf(context).bottom;
        final screenHeight = MediaQuery.sizeOf(context).height;
        final available = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : screenHeight;
        final height = math.max(
          0.0,
          math.min(available, screenHeight * .88) - inset,
        );
        return Padding(
          padding: EdgeInsets.only(bottom: inset),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: height,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.scheme.title.isNotEmpty
                                  ? widget.scheme.title
                                  : t.comicList.filter,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            tooltip: t.common.close,
                            onPressed: () => Navigator.pop(context),
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        key: const ValueKey('plugin-filter-fields'),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        children: fields
                            .map((field) => _buildField(context, field))
                            .toList(),
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _reset,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(44, 44),
                              ),
                              child: Text(t.common.reset),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => Navigator.pop(
                                context,
                                Map<String, String>.from(_selections),
                              ),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(44, 44),
                              ),
                              child: Text(t.common.apply),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildField(BuildContext context, PluginChoiceField field) {
    final selectedPath =
        field.findPathByValue(_selections[field.key]) ?? const [];
    final levels = field.buildVisibleLevels(_selections[field.key]);
    if (levels.length == 1 && levels.first.options.length <= 1) {
      return const SizedBox.shrink();
    }
    return Padding(
      key: ValueKey('filter-field-${field.key}'),
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (field.label.isNotEmpty) ...[
            Text(field.label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
          ],
          for (final level in levels)
            _buildLevel(
              context,
              field,
              level,
              selectedPath.length > level.pathIndex
                  ? selectedPath[level.pathIndex].value
                  : null,
            ),
        ],
      ),
    );
  }

  Widget _buildLevel(
    BuildContext context,
    PluginChoiceField field,
    PluginChoiceLevel level,
    String? selectedValue,
  ) {
    final id = '${field.key}-${level.pathIndex}';
    final many = level.options.length > 12;
    final controller = many
        ? _queries.putIfAbsent(id, TextEditingController.new)
        : null;
    final query = controller?.text.trim().toLowerCase() ?? '';
    final expanded = _expanded.contains(id);
    final matching = level.options.where(
      (option) =>
          query.isEmpty ||
          option.label.toLowerCase().contains(query) ||
          option.value.toLowerCase().contains(query),
    );
    final visible = query.isNotEmpty || !many || expanded
        ? matching.toList()
        : level.options
              .where(
                (option) =>
                    level.options.indexOf(option) < 8 ||
                    option.value == selectedValue,
              )
              .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (level.pathIndex > 0) ...[
            Text(
              level.pathIndex == 1
                  ? t.comicList.subCategory
                  : t.comicList.levelCategory(level: level.pathIndex + 1),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
          ],
          if (many) ...[
            TextField(
              key: ValueKey('filter-search-$id'),
              controller: controller,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: t.comicList.searchOptions,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: t.common.clear,
                        onPressed: () => setState(controller!.clear),
                        icon: const Icon(Icons.close_rounded),
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(t.comicList.noMatchingOptions),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final option in visible)
                ChoiceChip(
                  key: ValueKey('filter-option-$id-${option.value}'),
                  label: Text(
                    option.label.isNotEmpty ? option.label : option.value,
                  ),
                  selected: selectedValue == option.value,
                  showCheckmark: false,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onSelected: (_) =>
                      setState(() => _selections[field.key] = option.value),
                ),
            ],
          ),
          if (many && query.isEmpty)
            TextButton.icon(
              onPressed: () => setState(() {
                if (expanded) {
                  _expanded.remove(id);
                } else {
                  _expanded.add(id);
                }
              }),
              icon: Icon(
                expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
              ),
              label: Text(
                expanded
                    ? t.comicList.showFewerOptions
                    : t.comicList.showAllOptions(count: level.options.length),
              ),
            ),
        ],
      ),
    );
  }
}
