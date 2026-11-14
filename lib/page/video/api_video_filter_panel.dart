import 'package:zephyr/page/search/widget/search_field_decoration.dart';
import 'package:zephyr/widgets/year_filter_picker.dart';
import 'package:zephyr/widgets/selection_choice_grid.dart';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/page/video/video_search_filters.dart';

/// Keyword forms expose only conditions the source can send with the search.
/// Loaded-result filtering belongs to the catalog after submission.
Widget Function(BuildContext, VideoSearchFilters)? apiVideoKeywordFilterBuilder(
  ApiVideoCapabilities capabilities, {
  String? source,
  String namespace = '',
  List<ApiVideoCategory> categories = const [],
  String initialCategory = '',
}) {
  if (!capabilities.canSearch ||
      capabilities.search == 'website' ||
      !capabilities.filtersOnSearch) {
    return null;
  }
  final hasYear =
      capabilities.yearOnSearch &&
      capabilities.supportsYearType(initialCategory);
  if (!hasYear && !categories.any((category) => category.selectable)) {
    return null;
  }
  return (_, initial) => ApiVideoFilterPanel(
    source: source,
    namespace: namespace,
    initial: initial,
    capabilities: capabilities,
    categories: categories,
    searching: true,
    applyLabel: t.videoFilters.apply,
  );
}

/// One readable choice surface. No field opens another menu or sheet, and
/// only the explicit results action commits a modal draft.
class ApiVideoFilterPanel extends StatefulWidget {
  const ApiVideoFilterPanel({
    super.key,
    required this.initial,
    required this.capabilities,
    this.categories = const [],
    this.searching = false,
    this.includeCategory = true,
    this.categoriesLoading = false,
    this.categoriesFailed = false,
    this.onRetryCategories,
    this.applyLabel,
    this.source,
    this.namespace = '',
  });
  final VideoSearchFilters initial;
  final ApiVideoCapabilities capabilities;
  final List<ApiVideoCategory> categories;
  final bool searching, includeCategory, categoriesLoading, categoriesFailed;
  final VoidCallback? onRetryCategories;
  final String? applyLabel;
  final String? source;
  final String namespace;
  @override
  State<ApiVideoFilterPanel> createState() => _ApiVideoFilterPanelState();
}

class _ApiVideoFilterPanelState extends State<ApiVideoFilterPanel> {
  late VideoSearchFilters _draft = widget.initial;
  final _categorySearch = TextEditingController();
  bool _allCategories = false, _applying = false;
  bool get _local => widget.searching && !widget.capabilities.filtersOnSearch;

  @override
  void dispose() {
    _categorySearch.dispose();
    super.dispose();
  }

  void _change(VideoSearchFilters value) => setState(() => _draft = value);

  void _category(String value) {
    if (value == _draft.genre) return;
    _change(
      _draft.copyWith(
        genre: value,
        sort: value.startsWith('type:') || value.startsWith('genre:')
            ? _draft.sort
            : '',
        date: widget.capabilities.supportsYearType(value) ? _draft.date : '',
      ),
    );
  }

  Widget _choices({
    required String id,
    required Map<String, String> options,
    required String selected,
    required ValueChanged<String> onSelected,
    int maxColumns = 4,
  }) => SelectionChoiceGrid<String>(
    options: options,
    value: selected,
    onChanged: onSelected,
    enabled: !_applying,
    maxColumns: maxColumns,
    optionKey: (value) => ValueKey(
      'api-filters.$id.${value.isEmpty ? (id == 'sort' ? 'default' : 'all') : value}',
    ),
  );

  Widget _section(String label, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );

  Widget _expand({
    required String keyName,
    required bool expanded,
    required String label,
    required VoidCallback onPressed,
  }) => Align(
    alignment: Alignment.centerLeft,
    child: Semantics(
      expanded: expanded,
      child: TextButton.icon(
        key: ValueKey('api-filters.$keyName'),
        onPressed: onPressed,
        icon: VideoDisclosureIndicator(expanded: expanded, size: 20),
        label: Text(label),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final caps = widget.capabilities;
    final yearSupported =
        _local || caps.year && (!widget.searching || caps.yearOnSearch);
    final yearAllowed =
        _local || yearSupported && caps.supportsYearType(_draft.genre);
    final category = widget.categories
        .where((c) => c.id == _draft.genre)
        .firstOrNull;
    final availableCategories = widget.categories
        .where(
          (c) =>
              c.selectable &&
              (widget.includeCategory || caps.supportsYearType(c.id)),
        )
        .toList();
    final categoryAvailable = !_local && availableCategories.isNotEmpty;
    final chooseRange =
        categoryAvailable &&
        (widget.includeCategory || !yearAllowed && yearSupported);
    final sorting =
        !widget.searching &&
        caps.sourceSort &&
        (_draft.genre.startsWith('type:') || _draft.genre.startsWith('genre:'));
    final hasFields =
        widget.includeCategory && categoryAvailable || yearAllowed || sorting;
    final years = {
      '': t.videoLibrary.all,
      if (yearAllowed) ...{
        for (var year = DateTime.now().year; year >= 1940; year--)
          '$year': '$year',
        if (widget.initial.date.isNotEmpty)
          widget.initial.date: widget.initial.date,
        if (_draft.date.isNotEmpty) _draft.date: _draft.date,
      },
    };
    final categoryQuery = _categorySearch.text.trim().toLowerCase();
    final rankedCategories = availableCategories;
    final categoryValues = _allCategories
        ? rankedCategories.where(
            (c) =>
                categoryQuery.isEmpty ||
                c.name.toLowerCase().contains(categoryQuery),
          )
        : rankedCategories.take(6);
    final fields = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.includeCategory)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              '${t.videoFilters.active} · ${category?.name ?? t.videoLibrary.allTypes}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        if (_local)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              t.videoLibrary.loadedResultScope,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        if (chooseRange)
          _section(
            t.videoFilters.genre,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_allCategories && availableCategories.length > 12)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SearchFieldSurface(
                      child: TextField(
                        controller: _categorySearch,
                        decoration: searchFieldDecoration(
                          context,
                          hintText: t.videoLibrary.searchCategoriesHint,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                _choices(
                  id: 'category',
                  maxColumns: 3,
                  options: {
                    if (widget.includeCategory) '': t.videoLibrary.allTypes,
                    for (final value in categoryValues) value.id: value.name,
                    if (!_allCategories &&
                        category != null &&
                        !categoryValues.any((c) => c.id == category.id))
                      category.id: category.name,
                  },
                  selected: _draft.genre,
                  onSelected: _category,
                ),
                if (availableCategories.length > 6)
                  _expand(
                    keyName: 'more-categories',
                    expanded: _allCategories,
                    label: _allCategories
                        ? t.videoFilters.collapseOptions
                        : t.videoLibrary.moreCategories,
                    onPressed: () =>
                        setState(() => _allCategories = !_allCategories),
                  ),
              ],
            ),
          ),
        if (!_local &&
            widget.categories.isEmpty &&
            (widget.categoriesLoading || widget.categoriesFailed))
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: widget.categoriesLoading
                ? Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(t.common.loading)),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.videoFilters.optionsUnavailable),
                      TextButton(
                        onPressed: widget.onRetryCategories,
                        child: Text(t.common.retry),
                      ),
                    ],
                  ),
          ),
        if (sorting)
          _section(
            t.videoFilters.sort,
            _choices(
              id: 'sort',
              maxColumns: 3,
              options: {
                '': t.videoLibrary.updatedFirst,
                'hits': t.videoSource.sourcePopularity,
                'score': t.videoSource.sourceScore,
              },
              selected: _draft.sort,
              onSelected: (value) => _change(_draft.copyWith(sort: value)),
            ),
          ),
        if (yearSupported)
          if (yearAllowed)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: YearFilterPicker(
                keyPrefix: 'api-filters.year',
                label: t.videoLibrary.year,
                options: years,
                selected: _draft.date,
                enabled: !_applying,
                onSelected: (value) => _change(_draft.copyWith(date: value)),
              ),
            )
          else if (!widget.categoriesLoading && !widget.categoriesFailed)
            Padding(
              key: const ValueKey('api-filters.year-help'),
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                chooseRange
                    ? t.videoFilters.yearNeedsCategory
                    : t.videoFilters.yearUnavailableRange,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
        if (_local)
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Flexible(
                  child: FilterChip(
                    label: Text(t.videoLibrary.completedOnly),
                    selected: _draft.completed,
                    chipAnimationStyle: VideoMotion.chip(context),
                    onSelected: (value) =>
                        _change(_draft.copyWith(completed: value)),
                  ),
                ),
              ],
            ),
          ),
        if (!hasFields &&
            !chooseRange &&
            !widget.categoriesLoading &&
            !widget.categoriesFailed)
          Padding(
            key: const ValueKey('api-filters.unavailable'),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(t.videoLibrary.filterUnavailable),
          ),
      ],
    );
    void reset() => _change(
      _draft.copyWith(
        genre: widget.includeCategory ? '' : _draft.genre,
        date: '',
        sort: '',
        completed: false,
      ),
    );
    final header = Row(
      children: [
        Expanded(
          child: Text(
            t.videoFilters.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: t.common.close,
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 12),
          Flexible(
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              key: const ValueKey('api-filters.scroll'),
              child: fields,
            ),
          ),
          if (hasFields) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: _applying ? null : reset,
                  child: Text(t.videoFilters.reset),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('api-filters.apply'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onPressed: _applying
                        ? null
                        : () {
                            setState(() => _applying = true);
                            Navigator.pop(context, _draft);
                          },
                    child: Text(
                      widget.applyLabel ?? t.videoFilters.showResults,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
