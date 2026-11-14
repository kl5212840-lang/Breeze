import 'package:zephyr/page/search/widget/search_field_decoration.dart';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/comic_list/scene_filter/plugin_list_filter_schema.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/widgets/year_filter_picker.dart';
import 'package:zephyr/widgets/filter_option_favorites.dart';
import 'package:zephyr/widgets/selection_choice_grid.dart';

/// A draft-only task sheet. Only Apply returns a new filter selection.
class PluginListFilterDialog extends StatefulWidget {
  const PluginListFilterDialog({
    super.key,
    required this.scheme,
    required this.initialSelections,
    this.defaultSelections = const {},
    this.favoriteScope,
  });

  final PluginListFilterSchema scheme;
  final Map<String, String> initialSelections;
  final Map<String, String> defaultSelections;
  final String? favoriteScope;

  @override
  State<PluginListFilterDialog> createState() => _PluginListFilterDialogState();
}

class _PluginListFilterDialogState extends State<PluginListFilterDialog> {
  late final Map<String, String> _selections;
  late final FilterOptionFavorites? _favorites;
  final _expanded = <String>{};
  final _queries = <String, TextEditingController>{};
  final _scrolls = <String, ScrollController>{};
  int _resetVersion = 0;

  @override
  void initState() {
    super.initState();
    _selections = Map<String, String>.from(widget.initialSelections);
    final scope = widget.favoriteScope;
    _favorites = scope == null ? null : FilterOptionFavorites(scope);
    _favorites?.addListener(_favoritesChanged);
  }

  void _favoritesChanged() => setState(() {});

  @override
  void dispose() {
    _favorites?.removeListener(_favoritesChanged);
    _favorites?.dispose();
    for (final controller in _queries.values) {
      controller.dispose();
    }
    for (final controller in _scrolls.values) {
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
      _resetVersion++;
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
            // Keep the rounded surface paint outside native search ancestry.
            clipBehavior: usesSystemSearchSurface(context)
                ? Clip.none
                : Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: height),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                    Flexible(
                      child: ListView(
                        key: const ValueKey('plugin-filter-fields'),
                        shrinkWrap: true,
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
      padding: EdgeInsets.only(bottom: widget.scheme.wrapOptions ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (field.label.isNotEmpty && !_isYear(field)) ...[
            Text(field.label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
          ],
          for (final level in levels)
            _buildLevel(context, field, level, selectedPath),
        ],
      ),
    );
  }

  Widget _buildLevel(
    BuildContext context,
    PluginChoiceField field,
    PluginChoiceLevel level,
    List<PluginChoiceOption> selectedPath,
  ) {
    final id = '${field.key}-${level.pathIndex}';
    final selectedValue = selectedPath.length > level.pathIndex
        ? selectedPath[level.pathIndex].value
        : null;
    final dimension = [
      field.key,
      for (final parent in selectedPath.take(level.pathIndex)) parent.value,
    ].map(Uri.encodeComponent).join(':');
    final favorites = field.supportsFavorites ? _favorites : null;
    final isYear = _isYear(field);
    final options = isYear
        ? level.options
        : favorites?.order(
                dimension,
                level.options,
                (option) => option.value,
              ) ??
              level.options;
    final labels = {
      for (final option in options) option.value: _optionLabel(option),
    };
    Widget favorite(String value) {
      final label = labels[value] ?? value;
      if (!_canPin(value, label)) return const SizedBox.shrink();
      return favorites!.star(context, dimension, value, label);
    }

    // Respect declared year fields; never reinterpret numeric categories.
    if (isYear) {
      return YearFilterPicker(
        key: ValueKey('filter-year-$id-$_resetVersion'),
        keyPrefix: 'filter-year-$id',
        label: field.label,
        options: labels,
        favorite: favorites == null ? null : favorite,
        favoriteValues: [
          if (favorites != null)
            for (final entry in labels.entries)
              if (_canPin(entry.key, entry.value) &&
                  favorites.isPinned(dimension, entry.key))
                entry.key,
        ],
        selected: selectedValue ?? level.options.first.value,
        onSelected: (value) => setState(() => _selections[field.key] = value),
      );
    }
    final many = level.options.length > 12;
    final controller = many
        ? _queries.putIfAbsent(id, TextEditingController.new)
        : null;
    final query = controller?.text.trim().toLowerCase() ?? '';
    final expanded = _expanded.contains(id);
    final matching = options.where(
      (option) =>
          query.isEmpty ||
          option.label.toLowerCase().contains(query) ||
          option.value.toLowerCase().contains(query),
    );
    final visible = query.isNotEmpty || !many || expanded
        ? matching.toList()
        : [
            ...options.take(8),
            ...options.skip(8).where((option) => option.value == selectedValue),
          ];
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
            SearchFieldSurface(
              child: TextField(
                key: ValueKey('filter-search-$id'),
                controller: controller,
                onChanged: (_) => setState(() {}),
                decoration: searchFieldDecoration(
                  context,
                  hintText: t.comicList.searchOptions,
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: t.common.clear,
                          onPressed: () => setState(controller!.clear),
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(t.comicList.noMatchingOptions),
            ),
          if (!many && !widget.scheme.wrapOptions)
            SelectionChoiceGrid<String>(
              options: labels,
              favorite: favorites == null ? null : favorite,
              value: selectedValue ?? level.options.first.value,
              optionKey: (value) => ValueKey('filter-option-$id-$value'),
              onChanged: (value) =>
                  setState(() => _selections[field.key] = value),
            )
          else
            _optionRegion(
              context,
              id,
              many && (expanded || query.isNotEmpty),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final option in visible)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: ChoiceChip(
                            key: ValueKey('filter-option-$id-${option.value}'),
                            label: Text(_optionLabel(option)),
                            selected: selectedValue == option.value,
                            showCheckmark: false,
                            materialTapTargetSize: MaterialTapTargetSize.padded,
                            onSelected: (_) => setState(
                              () => _selections[field.key] = option.value,
                            ),
                          ),
                        ),
                        if (favorites != null) favorite(option.value),
                      ],
                    ),
                ],
              ),
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
              icon: VideoDisclosureIndicator(expanded: expanded, size: 20),
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

  String _optionLabel(PluginChoiceOption option) =>
      option.label.isNotEmpty ? option.label : option.value;

  bool _canPin(String value, String label) {
    final normalized = value.trim().toLowerCase();
    if (const {'', 'all', 'any', '全部', '不限'}.contains(normalized)) {
      return false;
    }
    final display = label.trim().toLowerCase();
    if (display == 'all' ||
        display == 'any' ||
        display == '不限' ||
        display.startsWith('全部'))
      return false;
    return true;
  }

  bool _isYear(PluginChoiceField field) => RegExp(
    r'year|年份|年代',
    caseSensitive: false,
  ).hasMatch('${field.key} ${field.label}');

  Widget _optionRegion(
    BuildContext context,
    String id,
    bool bounded,
    Widget child,
  ) {
    if (!bounded) return child;
    final controller = _scrolls.putIfAbsent(id, ScrollController.new);
    return ConstrainedBox(
      key: ValueKey('filter-options-$id'),
      constraints: BoxConstraints(
        maxHeight: (MediaQuery.sizeOf(context).height * .3).clamp(144.0, 280.0),
      ),
      child: Scrollbar(
        controller: controller,
        child: SingleChildScrollView(
          controller: controller,
          primary: false,
          child: child,
        ),
      ),
    );
  }
}
