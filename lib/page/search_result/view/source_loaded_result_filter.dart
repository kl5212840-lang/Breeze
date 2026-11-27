import 'package:zephyr/page/search/widget/search_toolbar_scope.dart';
import 'package:zephyr/page/search/widget/search_input_dialog.dart';
import 'package:zephyr/widgets/applied_filter_bar.dart';
import 'package:zephyr/widgets/collection_command_icons.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'dart:async';
import 'package:zephyr/page/search_result/source_result_filter_preferences.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/search_result/view/source_comic_search.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/widget/keyword_scope_menu.dart';
import 'package:flutter/foundation.dart';
import 'package:zephyr/util/text/public_search_text.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';
import 'package:zephyr/page/bookshelf/widgets/shelf_filter_sheet.dart';
import 'package:zephyr/page/search/widget/search_field_decoration.dart';
import 'package:zephyr/page/search/widget/search_keyboard.dart';
import 'package:zephyr/page/search_result/view/source_list_categories.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/util/text/chinese_convert.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';

ShelfFacetEntry sourceLoadedComicFacet(
  UnifiedComicListItem entry, {
  bool publicBrowseOnly = false,
}) {
  Set<String> values(List<String> types) => {
    for (final metadata in entry.metadata)
      if (types.contains(metadata.type))
        for (final value in metadata.value)
          if ((value is String || value is num) &&
              value.toString().trim().isNotEmpty)
            value.toString().trim(),
  };
  return ShelfFacetEntry(
    key: '${entry.source}:${entry.id}',
    source: entry.source,
    searchText: publicBrowseOnly
        ? ''
        : '${entry.title} ${entry.subtitle} ${entry.metadata.map((m) => m.value.join(' ')).join(' ')}',
    fields: {
      'category': values(['categories', 'category']),
      'author': values(['author']),
      if (!publicBrowseOnly) ...{
        'tags': values(['tags', 'tag']),
        'year': values(['year']),
        'area': values(['area']),
        'language': values(['language']),
      },
    }..removeWhere((_, values) => values.isEmpty),
  );
}

bool sourceLoadedComicMatches(
  UnifiedComicListItem entry,
  String query,
  ShelfFacetSelection selection, {
  SourceComicSearchScope? scope,
}) {
  final facet = sourceLoadedComicFacet(entry);
  final needle = normalizePublicSearchText(query);
  return (needle.isEmpty ||
          (scope == null
                  ? normalizePublicSearchText(facet.searchText)
                  : sourceComicSearchText(entry, scope))
              .contains(needle)) &&
      shelfFacetMatches(facet, selection, currentFolder: null);
}

class SourceLoadedResultChrome {
  const SourceLoadedResultChrome({
    required this.searchField,
    required this.filterButton,
    required this.appliedFilters,
    required this.shown,
    required this.total,
    required this.countLabel,
    required this.complete,
    required this.loadingMore,
    this.knownTotal,
    this.pageNavigation,
    required this.filtersActive,
    this.hasFilterOptions = true,
  });
  final Widget searchField, filterButton;
  final Widget? appliedFilters;
  final Widget? pageNavigation;
  final int shown, total;
  final int? knownTotal;
  final String countLabel;
  final bool complete, loadingMore, filtersActive, hasFilterOptions;
}

/// The applied conditions and count describe the loaded snapshot, not a
/// remote total. Keep them below the stable action row in either host.
class SourceLoadedFacetSummary extends StatelessWidget {
  const SourceLoadedFacetSummary({
    super.key,
    required this.chrome,
    this.showCount = true,
  });

  final SourceLoadedResultChrome chrome;
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    if (!chrome.filtersActive) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: CollectionToolbarMetrics.contentPaddingOf(context, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showCount)
            Text(
              chrome.countLabel,
              key: const ValueKey('source-loaded.scope'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ?chrome.appliedFilters,
        ],
      ),
    );
  }
}

/// The keyword editor can live in a route title without moving result controls.
class SourceLoadedSearchField extends StatelessWidget {
  const SourceLoadedSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.scopeMenu,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Widget scopeMenu;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final toolbar = SearchToolbarScope.maybeOf(context);
    final embedded = toolbar?.onClose != null;
    final menuWidth = KeywordScopeMenu.leadingWidth(context);
    final textField = ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) => SearchFieldSurface(
        child: TextField(
          key: const ValueKey('source-loaded.search'),
          controller: controller,
          autofocus: autofocus,
          focusNode: focusNode,
          textAlignVertical: TextAlignVertical.center,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          decoration: searchFieldDecoration(
            context,
            hintText: t.videoLibrary.localCatalogSearchHint,
            prefixIcon: embedded ? SizedBox(width: menuWidth + 6) : null,
            variableSuffixWidth: embedded,
            suffixIcon: embedded
                ? SearchFieldCloseActions(
                    hasText: value.text.isNotEmpty,
                    onClear: controller.clear,
                    onClose: toolbar?.onClose,
                    closeKey: toolbar?.closeKey,
                  )
                : value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: t.common.clear,
                    onPressed: controller.clear,
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
      ),
    );
    return embedded
        ? AndroidSearchExpansion(
            child: Stack(
              children: [
                textField,
                PositionedDirectional(
                  start: 0,
                  top: 0,
                  bottom: 0,
                  width: menuWidth,
                  child: Center(child: scopeMenu),
                ),
              ],
            ),
          )
        : Row(
            children: [
              Expanded(child: textField),
              const SizedBox(width: 6),
              scopeMenu,
            ],
          );
  }
}

/// Search and facets inspect the public snapshot; focused source collections
/// may fill absent metadata from existing local records of that exact work.
/// Exclusions stay owned by the containing source/scene blocklist.
class SourceLoadedResultFilter extends StatefulWidget {
  const SourceLoadedResultFilter({
    super.key,
    required this.entries,
    required this.scope,
    required this.builder,
    this.complete = true,
    this.knownTotal,
    this.compactControls = false,
    this.flatCollectionControls = false,
    this.searchController,
    this.searchFocusNode,
    this.searchScope,
    this.searchExpanded = true,
    this.focusedFacets = false,
    this.publicBrowseFacets = false,
    this.filterScopeLabel,
    this.chromeBuilder,
    this.pageNavigation,
    this.requireCompleteFacets = false,
    this.loadingMore = false,
    this.onLoadMore,
    this.onChanged,
    this.onCompleteIndexDemandChanged,
    this.blockedCategories = const {},
  });

  final List<UnifiedComicListItem> entries;
  final String scope;
  final bool complete, loadingMore;
  final int? knownTotal;
  final bool compactControls, requireCompleteFacets, focusedFacets;
  final bool flatCollectionControls;
  final bool publicBrowseFacets;
  final String? filterScopeLabel;
  final bool searchExpanded;
  final TextEditingController? searchController;
  final FocusNode? searchFocusNode;
  final KeywordSearchScope? searchScope;
  final Widget Function(BuildContext, SourceLoadedResultChrome)? chromeBuilder;
  final Widget? pageNavigation;
  final VoidCallback? onLoadMore, onChanged;

  /// Active search or applied facets may need the remaining pages.
  final ValueChanged<bool>? onCompleteIndexDemandChanged;
  final Set<String> blockedCategories;
  final Widget Function(BuildContext, List<UnifiedComicListItem>, Widget)
  builder;

  static ({Object criteria, bool filtering, bool editing})? demandOf(
    BuildContext context,
  ) => context.dependOnInheritedWidgetOfExactType<_LoadedResultDemand>()?.data;

  @override
  State<SourceLoadedResultFilter> createState() =>
      _SourceLoadedResultFilterState();
}

class _LoadedResultDemand extends InheritedWidget {
  const _LoadedResultDemand({required this.data, required super.child});

  final ({Object criteria, bool filtering, bool editing}) data;

  @override
  bool updateShouldNotify(_LoadedResultDemand oldWidget) =>
      data != oldWidget.data;
}

class _SourceLoadedResultFilterState extends State<SourceLoadedResultFilter> {
  final _ownedSearch = TextEditingController();
  final _ownedSearchFocus = FocusNode();
  FocusNode get _searchFocus => widget.searchFocusNode ?? _ownedSearchFocus;
  int _focusEpoch = 0;
  KeywordSearchScope _ownedSearchScope = KeywordSearchScope.all;
  KeywordSearchScope get _searchScope =>
      widget.searchScope ?? _ownedSearchScope;
  late List<UnifiedComicListItem> _entries;

  void _readEntries() {
    _entries = widget.entries;
    if (widget.focusedFacets) {
      try {
        _entries = enrichSourceComicMetadata(widget.entries);
      } catch (_) {
        /* Optional local enrichment cannot hide the supplied rows. */
      }
    }
  }

  void _syncSearchFocus() {
    final epoch = ++_focusEpoch;
    if (!widget.focusedFacets) return;
    // The collection owner requests its external node only on an explicit
    // search gesture. Metadata refreshes may replace this filter state.
    if (widget.searchFocusNode != null) return;
    if (!widget.searchExpanded) {
      _searchFocus.unfocus();
      return;
    }
    requestSearchKeyboard(
      _searchFocus,
      isCurrent: () =>
          mounted &&
          epoch == _focusEpoch &&
          widget.searchExpanded &&
          ModalRoute.of(context)?.isCurrent != false,
    );
  }

  TextEditingController get _search => widget.searchController ?? _ownedSearch;
  @override
  void initState() {
    super.initState();
    _search.addListener(_queryChanged);
    _readEntries();
    _loadAppliedFilters();
    PortablePreferences.changes.addListener(_loadAppliedFilters);
    _syncSearchFocus();
    _updateCompleteIndexDemand();
  }

  void _updateCompleteIndexDemand() {
    widget.onCompleteIndexDemandChanged?.call(
      _search.text.trim().isNotEmpty || _filters.isActive,
    );
  }

  void _queryChanged() {
    if (!mounted) return;
    setState(() {});
    widget.onChanged?.call();
    _updateCompleteIndexDemand();
    _scheduleFilterSnapshot?.call();
  }

  ShelfFacetSelection _filters = const ShelfFacetSelection();
  bool _opening = false;
  ModalRoute<dynamic>? _filterRoute;
  VoidCallback? _scheduleFilterSnapshot;
  int _revision = 0;
  int _preferenceEpoch = 0;
  int? _pendingFilterSave;
  bool _reloadAfterFilterSave = false;
  bool get _persistFilters =>
      widget.scope.contains('|cloudFavorite|') &&
      !widget.scope.contains('|session|');

  Future<void> _loadAppliedFilters() async {
    if (!_persistFilters) return;
    if (_pendingFilterSave != null) {
      _reloadAfterFilterSave = true;
      return;
    }
    final epoch = ++_preferenceEpoch;
    final scope = widget.scope;
    try {
      final filters = await SourceResultFilterPreferences.read(scope);
      if (!mounted || epoch != _preferenceEpoch || scope != widget.scope)
        return;
      setState(() => _filters = filters);
      widget.onChanged?.call();
      _updateCompleteIndexDemand();
    } catch (_) {
      /* An unavailable preference does not discard live results. */
    }
  }

  void _commitFilters(ShelfFacetSelection filters) {
    final epoch = ++_preferenceEpoch;
    setState(() => _filters = filters);
    widget.onChanged?.call();
    _updateCompleteIndexDemand();
    if (_persistFilters) {
      _pendingFilterSave = epoch;
      unawaited(_saveAppliedFilters(widget.scope, filters, epoch));
    }
  }

  Future<void> _saveAppliedFilters(
    String scope,
    ShelfFacetSelection filters,
    int epoch,
  ) async {
    var failed = false;
    try {
      await SourceResultFilterPreferences.write(scope, filters);
    } catch (_) {
      failed = true;
    }
    if (!mounted || _pendingFilterSave != epoch || scope != widget.scope) {
      return;
    }
    _pendingFilterSave = null;
    final reload = failed || _reloadAfterFilterSave;
    _reloadAfterFilterSave = false;
    if (failed) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(t.error.saveFailed)));
    }
    if (reload) await _loadAppliedFilters();
  }

  bool get _matchingScopeComplete {
    if (!widget.complete) return false;
    final dimensions = _filters.values.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => e.key)
        .toSet();
    if (_search.text.trim().isNotEmpty &&
        _searchScope == KeywordSearchScope.all) {
      dimensions.addAll(['tags', 'author']);
    }
    return _entries.every(
      (row) => dimensions.every(
        (dimension) => row.metadata.any(
          (m) =>
              m.type == dimension ||
              dimension == 'tags' && m.type == 'tag' ||
              dimension == 'category' && m.type == 'categories',
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(SourceLoadedResultFilter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.entries, widget.entries) ||
        oldWidget.focusedFacets != widget.focusedFacets ||
        oldWidget.scope != widget.scope) {
      _readEntries();
    }
    if (oldWidget.searchExpanded != widget.searchExpanded ||
        oldWidget.focusedFacets != widget.focusedFacets)
      _syncSearchFocus();
    if (oldWidget.searchController != widget.searchController) {
      (oldWidget.searchController ?? _ownedSearch).removeListener(
        _queryChanged,
      );
      _search.addListener(_queryChanged);
    }
    if ((!widget.focusedFacets &&
            !widget.publicBrowseFacets &&
            !identical(oldWidget.entries, widget.entries)) ||
        !setEquals(oldWidget.blockedCategories, widget.blockedCategories))
      _revision++;
    if (oldWidget.scope != widget.scope) {
      _pendingFilterSave = null;
      _reloadAfterFilterSave = false;
      _preferenceEpoch++;
      _search.removeListener(_queryChanged);
      _search.clear();
      _search.addListener(_queryChanged);
      _filters = const ShelfFacetSelection();
      _ownedSearchScope = KeywordSearchScope.all;
      _revision++;
      _loadAppliedFilters();
    }
    if (oldWidget.searchController != widget.searchController ||
        oldWidget.scope != widget.scope) {
      _updateCompleteIndexDemand();
    }
    if (oldWidget.searchScope != widget.searchScope &&
        _search.text.isNotEmpty) {
      widget.onChanged?.call();
    }
    _scheduleFilterSnapshot?.call();
  }

  @override
  void dispose() {
    PortablePreferences.changes.removeListener(_loadAppliedFilters);
    ++_preferenceEpoch;
    final route = _filterRoute;
    final navigator = route?.navigator;
    if (route != null && navigator != null) {
      // A session boundary can dispose this collection under a root sheet.
      // Remove only that exact obsolete route, never a newer modal.
      Future.microtask(() {
        if (route.isActive && route.navigator == navigator)
          navigator.removeRoute(route);
      });
    }
    _search.removeListener(_queryChanged);
    _ownedSearch.dispose();
    _focusEpoch++;
    _ownedSearchFocus.dispose();
    super.dispose();
  }

  Iterable<UnifiedComicListItem> _keywordCandidates(
    String query,
    KeywordSearchScope scope,
  ) {
    final needle = normalizePublicSearchText(query);
    final searchScope = scope == KeywordSearchScope.title
        ? SourceComicSearchScope.title
        : SourceComicSearchScope.all;
    return _entries.where(
      (entry) =>
          !isEntryBlockedByCategory(entry, widget.blockedCategories) &&
          (needle.isEmpty ||
              sourceComicSearchText(entry, searchScope).contains(needle)),
    );
  }

  Future<void> _editFilters() async {
    if (_opening) return;
    setState(() => _opening = true);
    final revision = _revision;
    final query = _search.text;
    final searchScope = _searchScope;
    bool ownsScope() =>
        mounted &&
        revision == _revision &&
        query == _search.text &&
        searchScope == _searchScope;
    ShelfFilterSnapshot snapshot() {
      final entries = _keywordCandidates(query, searchScope)
          .map(
            (entry) => sourceLoadedComicFacet(
              entry,
              publicBrowseOnly: widget.publicBrowseFacets,
            ),
          )
          .toList();
      return (
        entries: entries,
        scopeLabel:
            widget.filterScopeLabel ?? t.videoLibrary.localCatalogFilters,
        loadingMetadata: widget.loadingMore,
        canLoadMetadata: !widget.complete && widget.onLoadMore != null,
      );
    }

    final initial = snapshot();
    final live = widget.publicBrowseFacets && widget.onLoadMore != null
        ? ValueNotifier<ShelfFilterSnapshot>(initial)
        : null;
    var scheduled = false;
    if (live != null) {
      late final VoidCallback publish;
      publish = () {
        if (scheduled) return;
        scheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          scheduled = false;
          if (!identical(_scheduleFilterSnapshot, publish)) return;
          if (ownsScope()) {
            live.value = snapshot();
          } else {
            final current = live.value;
            live.value = (
              entries: current.entries,
              scopeLabel: current.scopeLabel,
              loadingMetadata: false,
              canLoadMetadata: false,
            );
          }
        });
      };
      _scheduleFilterSnapshot = publish;
    }
    // Pinned options share the established source/folder preference. Applied
    // result filters keep the separate owner-bound scope used by persistence.
    final scopeParts = widget.scope.split('|');
    final pinnedScope =
        scopeParts.length >= 4 && scopeParts[1] == 'cloudFavorite'
        ? [scopeParts[0], scopeParts[1], ...scopeParts.skip(3)].join('|')
        : widget.scope;
    try {
      final result = await showShelfFilterSheet(
        context,
        entries: initial.entries,
        initial: _filters,
        preferenceKey: 'source-results|$pinnedScope',
        scopeLabel: initial.scopeLabel,
        showScopeLabel: live != null,
        autoLoadMetadata: live != null,
        liveSnapshot: live,
        onLoadMetadata: live == null
            ? null
            : () {
                final lifecycle = WidgetsBinding.instance.lifecycleState;
                if (!ownsScope() ||
                    (lifecycle != null &&
                        lifecycle != AppLifecycleState.resumed) ||
                    live.value.loadingMetadata ||
                    widget.loadingMore ||
                    widget.complete ||
                    widget.onLoadMore == null) {
                  return;
                }
                widget.onLoadMore?.call();
              },
        currentFolder: null,
        hierarchical: false,
        showAllRecordsLabel: !widget.publicBrowseFacets,
        focusedLayout: widget.focusedFacets,
        nativeMaterial: widget.focusedFacets,
        onRouteOpened: (route) => _filterRoute = route,
      );
      if (!mounted || result == null) return;
      if (!ownsScope()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.comicList.loadedFiltersChanged)),
        );
        return;
      }
      _commitFilters(result);
    } finally {
      _scheduleFilterSnapshot = null;
      await _filterRoute?.completed;
      live?.dispose();
      _filterRoute = null;
      if (mounted) {
        setState(() => _opening = false);
        _updateCompleteIndexDemand();
      } else {
        _opening = false;
      }
    }
  }

  Widget _scopeMenu() => KeywordScopeMenu(
    key: const ValueKey('source-loaded.search-scope'),
    scope: _searchScope,
    onChanged: (value) {
      setState(() => _ownedSearchScope = value);
      widget.onChanged?.call();
      _updateCompleteIndexDemand();
      _scheduleFilterSnapshot?.call();
    },
  );

  Widget _compactFilterButton({required bool enabled, required bool busy}) =>
      SourceChromeIconButton(
        key: const ValueKey('source-loaded.filters'),
        tooltip: _filters.isActive
            ? t.videoFilters.active
            : t.videoLibrary.localCatalogFilters,
        icon: CollectionCommandIcons.filter.icon,
        symbol: CollectionCommandIcons.filter.symbol,
        selected: _filters.isActive,
        bare: true,
        busy: busy,
        onPressed: enabled ? _editFilters : null,
      );

  @override
  Widget build(BuildContext context) {
    final candidates = _keywordCandidates(_search.text, _searchScope).toList();
    final visible = !_filters.isActive
        ? candidates
        : candidates
              .where(
                (entry) => shelfFacetMatches(
                  sourceLoadedComicFacet(
                    entry,
                    publicBrowseOnly: widget.publicBrowseFacets,
                  ),
                  _filters,
                  currentFolder: null,
                ),
              )
              .toList();
    Widget results(Widget controls) => _LoadedResultDemand(
      data: (
        criteria: (
          _search.text,
          _searchScope,
          _filters,
          Object.hashAllUnordered(widget.blockedCategories),
        ),
        filtering:
            _filters.isActive ||
            _search.text.trim().isNotEmpty ||
            widget.blockedCategories.isNotEmpty,
        editing: _opening,
      ),
      child: Builder(
        builder: (context) => widget.builder(context, visible, controls),
      ),
    );
    final applied = !_filters.isActive
        ? null
        : AppliedFilterBar(
            key: const ValueKey('source-loaded.applied'),
            clearKey: const ValueKey('source-loaded.reset'),
            clearWhenEmpty: _filters.isActive,
            compact: widget.flatCollectionControls,
            entries: [
              for (final group in _filters.values.entries)
                for (final value in group.value)
                  (
                    id: 'source-loaded.applied.${group.key}.$value',
                    label: value == shelfFacetUnknown
                        ? t.bookshelf.facets.unknown
                        : convertChineseForDisplay(
                            shelfFacetDisplayValue(value),
                          ),
                    edit: _opening ? null : _editFilters,
                    remove: () {
                      final next = {
                        for (final e in _filters.values.entries)
                          e.key: {...e.value},
                      };
                      next[group.key]?.remove(value);
                      _commitFilters(
                        _filters.copyWith(
                          values: next,
                          applied: next.values.any(
                            (values) => values.isNotEmpty,
                          ),
                        ),
                      );
                    },
                  ),
            ],
            onClearAll: () => _commitFilters(
              _filters.copyWith(values: const {}, applied: false),
            ),
          );
    final colors = Theme.of(context).colorScheme;
    if (widget.chromeBuilder != null) {
      final countLabel = !widget.publicBrowseFacets && _matchingScopeComplete
          ? t.videoLibrary.results(count: visible.length)
          : t.videoLibrary.localCatalogUnknownTotal(
              loaded: widget.entries.length,
              shown: visible.length,
            );
      final hasOptions = widget.publicBrowseFacets
          ? _filters.isActive ||
                !widget.complete && widget.onLoadMore != null ||
                candidates.any(
                  (entry) => sourceLoadedComicFacet(
                    entry,
                    publicBrowseOnly: true,
                  ).fields.isNotEmpty,
                )
          : _entries.isNotEmpty;
      final enabled =
          !_opening &&
          hasOptions &&
          (!widget.requireCompleteFacets || widget.complete);
      final searchField = SourceLoadedSearchField(
        controller: _search,
        focusNode: _searchFocus,
        scopeMenu: _scopeMenu(),
        autofocus: !widget.focusedFacets,
      );
      final filterButton = _compactFilterButton(
        enabled: enabled,
        busy:
            !widget.publicBrowseFacets &&
            !widget.focusedFacets &&
            widget.loadingMore &&
            widget.requireCompleteFacets &&
            !widget.complete,
      );
      final chrome = SourceLoadedResultChrome(
        searchField: searchField,
        filterButton: filterButton,
        appliedFilters: applied,
        shown: visible.length,
        total: widget.entries.length,
        knownTotal: widget.knownTotal,
        pageNavigation: widget.pageNavigation,
        countLabel: countLabel,
        complete: widget.complete,
        loadingMore: widget.loadingMore,
        filtersActive: _filters.isActive,
        hasFilterOptions: hasOptions,
      );
      return results(widget.chromeBuilder!(context, chrome));
    }
    final controls = Padding(
      padding: CollectionToolbarMetrics.contentPaddingOf(
        context,
        top: 4,
        bottom: 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: SearchFieldSurface(
                  child: TextField(
                    key: const ValueKey('source-loaded.search'),
                    controller: _search,
                    focusNode: _searchFocus,
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),

                    decoration: searchFieldDecoration(
                      context,
                      hintText: t.videoLibrary.localCatalogSearchHint,
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: t.common.clear,
                              onPressed: () {
                                _search.clear();
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _scopeMenu(),
              if (widget.compactControls) ...[
                const SizedBox(width: 4),
                _compactFilterButton(
                  enabled:
                      !_opening &&
                      widget.entries.isNotEmpty &&
                      (!widget.requireCompleteFacets || widget.complete),
                  busy:
                      widget.requireCompleteFacets &&
                      !widget.complete &&
                      widget.loadingMore,
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          if (!widget.compactControls)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.tonalIcon(
                key: const ValueKey('source-loaded.filters'),
                style: FilledButton.styleFrom(minimumSize: const Size(44, 44)),
                onPressed:
                    _opening ||
                        widget.entries.isEmpty ||
                        widget.requireCompleteFacets && !widget.complete
                    ? null
                    : _editFilters,
                icon: const Icon(Icons.tune_rounded, size: 20),
                label: Text(t.videoLibrary.localCatalogFilters),
              ),
            ),
          ?applied,
          Text(
            _matchingScopeComplete
                ? t.videoLibrary.results(count: visible.length)
                : t.videoLibrary.localCatalogUnknownTotal(
                    loaded: widget.entries.length,
                    shown: visible.length,
                  ),
            key: const ValueKey('source-loaded.scope'),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
    return results(controls);
  }
}
