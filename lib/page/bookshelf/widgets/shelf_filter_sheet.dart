import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'dart:async';
import 'package:zephyr/page/bookshelf/widgets/shelf_tag_pin.dart';
import 'package:zephyr/page/bookshelf/widgets/facet_option_list.dart';
import 'package:zephyr/page/bookshelf/widgets/facet_filter_body.dart';
import 'package:zephyr/page/bookshelf/widgets/facet_reorder_motion.dart';
import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/widget/search_field_decoration.dart';
import 'package:zephyr/page/search/widget/search_input_dialog.dart';
import 'package:zephyr/page/search/widget/keyword_scope_menu.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';
import 'package:zephyr/page/bookshelf/service/shelf_facet_preferences.dart';

/// Optional keyword draft for a host that filters already loaded works.
/// Computing entries is synchronous and never expands that loaded scope.
typedef ShelfFilterKeyword = ({
  String query,
  KeywordSearchScope scope,
  List<ShelfFacetEntry> Function(String, KeywordSearchScope) entriesFor,
  void Function(String, KeywordSearchScope) onApply,
});

String _facetPreferenceKey(String scope, String dimension) =>
    dimension == 'tags' ? scope : '$scope|facet:$dimension';

bool _supportsFacetFavorites(String? dimension) =>
    dimension == 'tags' || dimension == 'author';

typedef _FacetFavorites = Map<String, Set<String>?>;

Future<_FacetFavorites> _loadFacetFavorites(String scope) async {
  final favorites = await Future.wait([
    for (final dimension in shelfFacetDimensions)
      ShelfFacetPreferences.load(
        _facetPreferenceKey(scope, dimension),
      ).then<Set<String>?>((values) => values, onError: (Object _) => null),
  ]);
  return {
    for (var i = 0; i < shelfFacetDimensions.length; i++)
      shelfFacetDimensions[i]: favorites[i],
  };
}

Future<ShelfFacetSelection?> showShelfFilterSheet(
  BuildContext context, {
  required List<ShelfFacetEntry> entries,
  required ShelfFacetSelection initial,
  required String preferenceKey,
  required String scopeLabel,
  required String? currentFolder,
  bool hierarchical = true,
  bool focusedLayout = false,
  bool nativeMaterial = false,
  bool showAllRecordsLabel = true,
  ValueChanged<ModalRoute<dynamic>>? onRouteOpened,
  ShelfFilterKeyword? keyword,
}) async {
  final favorites = await _loadFacetFavorites(preferenceKey);
  if (!context.mounted) return null;
  if (nativeMaterial) {
    return showVideoTaskSheet<ShelfFacetSelection>(
      context: context,
      useRootNavigator: true,
      systemStyle: AppInterfaceStyleScope.usesSystem(context),
      builder: (sheetContext) {
        final route = ModalRoute.of(sheetContext);
        if (route != null) onRouteOpened?.call(route);
        return _ShelfFilterSheet(
          entries: entries,
          initial: initial,
          preferenceKey: preferenceKey,
          scopeLabel: scopeLabel,
          currentFolder: currentFolder,
          hierarchical: hierarchical,
          focusedLayout: focusedLayout,
          showAllRecordsLabel: showAllRecordsLabel,
          nativeMaterial: true,
          favorites: favorites,
          keyword: keyword,
        );
      },
    );
  }
  return showModalBottomSheet<ShelfFacetSelection>(
    context: context,
    // Main tabs own nested Navigators below the persistent navigation bar.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (sheetContext) {
      final route = ModalRoute.of(sheetContext);
      if (route != null) onRouteOpened?.call(route);
      return _ShelfFilterSheet(
        entries: entries,
        initial: initial,
        preferenceKey: preferenceKey,
        scopeLabel: scopeLabel,
        currentFolder: currentFolder,
        hierarchical: hierarchical,
        focusedLayout: focusedLayout,
        showAllRecordsLabel: showAllRecordsLabel,
        favorites: favorites,
        keyword: keyword,
      );
    },
  );
}

class _ShelfFilterSheet extends StatefulWidget {
  const _ShelfFilterSheet({
    required this.entries,
    required this.initial,
    required this.preferenceKey,
    required this.scopeLabel,
    required this.currentFolder,
    required this.hierarchical,
    required this.focusedLayout,
    required this.showAllRecordsLabel,
    this.nativeMaterial = false,
    required this.favorites,
    this.keyword,
  });
  final List<ShelfFacetEntry> entries;
  final ShelfFacetSelection initial;
  final String preferenceKey, scopeLabel;
  final String? currentFolder;
  final bool hierarchical, focusedLayout, nativeMaterial, showAllRecordsLabel;
  final _FacetFavorites favorites;
  final ShelfFilterKeyword? keyword;
  @override
  State<_ShelfFilterSheet> createState() => _ShelfFilterSheetState();
}

class _ShelfFilterSheetState extends State<_ShelfFilterSheet>
    with SingleTickerProviderStateMixin {
  late final _reorder = FacetReorderController(vsync: this);
  late ShelfFacetSelection _draft;
  late _FacetFavorites _favorites;
  bool _saving = false, _resetDraft = false;
  int _favoritesEpoch = 0;
  String? _expanded, _visibleDimension, _preferenceError;
  final _query = TextEditingController();
  late String _workQuery = widget.keyword?.query ?? '';
  late KeywordSearchScope _workScope =
      widget.keyword?.scope ?? KeywordSearchScope.all;
  Map<String, String> get _labels => {
    'tags': t.bookshelf.facets.tags,
    'category': t.bookshelf.facets.category,
    'year': t.bookshelf.facets.year,
    'area': t.bookshelf.facets.area,
    'language': t.bookshelf.facets.language,
    'author': t.bookshelf.facets.author,
    'quality': t.bookshelf.facets.quality,
  };

  @override
  void initState() {
    super.initState();
    _draft = shelfFacetSelectionForScope(
      widget.initial,
      currentFolder: widget.currentFolder,
      hierarchical: widget.hierarchical,
    );
    // A hidden legacy missing-metadata choice must not keep filtering results.
    _draft = _draft.copyWith(
      values: {
        for (final entry in _draft.values.entries)
          entry.key: {...entry.value}..remove(shelfFacetUnknown),
      },
    );
    _favorites = widget.favorites;
    ShelfFacetPreferences.changes.addListener(_favoritesChanged);
    PortablePreferences.changes.addListener(_favoritesChanged);
    _favoritesChanged();
  }

  @override
  void dispose() {
    _favoritesEpoch++;
    ShelfFacetPreferences.changes.removeListener(_favoritesChanged);
    PortablePreferences.changes.removeListener(_favoritesChanged);
    _query.dispose();
    _reorder.dispose();
    super.dispose();
  }

  void _favoritesChanged() => unawaited(_refreshFavorites());

  Future<void> _refreshFavorites() async {
    final epoch = ++_favoritesEpoch;
    final favorites = await _loadFacetFavorites(widget.preferenceKey);
    if (!mounted || epoch != _favoritesEpoch) return;
    final before = _favorites[_visibleDimension];
    final after = favorites[_visibleDimension];
    if (before != null &&
        after != null &&
        (after.length != before.length || !after.containsAll(before))) {
      _reorder.capture(animate: !MediaQuery.disableAnimationsOf(context));
    }
    setState(() {
      _favorites = favorites;
      _preferenceError = null;
    });
  }

  Future<void> _star(String dimension, String value) async {
    if (_saving || !_supportsFacetFavorites(dimension)) return;
    _favoritesEpoch++;
    setState(() {
      _saving = true;
      _preferenceError = null;
    });
    try {
      await ShelfFacetPreferences.toggle(
        _facetPreferenceKey(widget.preferenceKey, dimension),
        value,
      );
      if (mounted) await _refreshFavorites();
    } catch (_) {
      if (mounted) {
        _favoritesEpoch++;
        setState(
          () => _preferenceError = dimension == 'tags'
              ? t.bookshelf.facets.saveFavoritesFailed
              : t.error.saveFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggle(String dimension, String value) {
    final values = {
      for (final e in _draft.values.entries) e.key: {...e.value},
    };
    final selected = values.putIfAbsent(dimension, () => <String>{});
    selected.contains(value) ? selected.remove(value) : selected.add(value);
    setState(() => _draft = _draft.copyWith(values: values));
  }

  @override
  Widget build(BuildContext context) {
    final entries =
        widget.keyword?.entriesFor(_workQuery.trim(), _workScope) ??
        widget.entries;
    final options = shelfFacetOptions(
      entries,
      _draft,
      currentFolder: widget.currentFolder,
    );
    // Retain unavailable pins in dimensions backed by the collection.
    for (final dimension in shelfFacetDimensions) {
      final favorites = _supportsFacetFavorites(dimension)
          ? _favorites[dimension]
          : const <String>{};
      if (favorites != null &&
          favorites.isNotEmpty &&
          (options.containsKey(dimension) ||
              entries.any(
                (entry) =>
                    entry.fields[dimension]?.any(
                      (value) => value.trim().isNotEmpty,
                    ) ??
                    false,
              ))) {
        final counts = options.putIfAbsent(dimension, () => <String, int>{});
        for (final value in favorites) {
          counts.putIfAbsent(value, () => 0);
        }
      }
      if (_draft.values[dimension]?.isNotEmpty ?? false) {
        options.putIfAbsent(dimension, () => <String, int>{});
      }
    }
    final count = entries
        .where(
          (e) =>
              shelfFacetMatches(e, _draft, currentFolder: widget.currentFolder),
        )
        .length;
    for (final counts in options.values) {
      counts.remove(shelfFacetUnknown);
    }
    options.removeWhere(
      (dimension, counts) =>
          counts.isEmpty && (_draft.values[dimension]?.isNotEmpty != true),
    );
    final inset = widget.nativeMaterial
        ? 0.0
        : MediaQuery.viewInsetsOf(context).bottom;
    return _focused(context, options, count, inset);
  }

  Widget _focused(
    BuildContext context,
    Map<String, Map<String, int>> options,
    int count,
    double inset,
  ) {
    final dimensions = options.keys.toList();
    final dimension = dimensions.contains(_expanded)
        ? _expanded
        : dimensions.firstOrNull;
    _visibleDimension = dimension;
    final selected = _draft.values[dimension] ?? const <String>{};
    final counts = options[dimension] ?? const <String, int>{};
    final favorites = _supportsFacetFavorites(dimension)
        ? _favorites[dimension]
        : const <String>{};
    final preferenceError =
        _preferenceError ??
        (dimension != null && favorites == null
            ? dimension == 'tags'
                  ? t.bookshelf.facets.loadFavoritesFailed
                  : t.bookshelf.facets.loadFailed
            : null);
    final pinned = favorites ?? const <String>{};
    final values = {...counts.keys, ...selected}.toList()
      ..sort((a, b) {
        final rank =
            (pinned.contains(b) ? 1 : 0) - (pinned.contains(a) ? 1 : 0);
        return rank != 0 ? rank : a.compareTo(b);
      });
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              t.bookshelf.filter,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          TextButton(
            key: const ValueKey('shelf-filter-reset'),
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            onPressed: () => setState(() {
              _resetDraft = true;
              _draft = shelfFacetSelectionForScope(
                const ShelfFacetSelection(),
                currentFolder: widget.currentFolder,
                hierarchical: widget.hierarchical,
              );
              _query.clear();
              _workQuery = '';
            }),
            child: Text(t.common.reset),
          ),
          IconButton(
            key: const ValueKey('shelf-focused-cancel'),
            tooltip: t.common.cancel,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
    final controls = Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.focusedLayout) ...[
            if (widget.scopeLabel.isNotEmpty)
              Text(
                widget.scopeLabel,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (widget.showAllRecordsLabel &&
                widget.currentFolder == null &&
                widget.keyword == null)
              Padding(
                key: const ValueKey('shelf-scope-all-label'),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(t.bookshelf.facets.allRecords),
              )
            else if (widget.currentFolder != null)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final scope in ShelfFacetScope.values)
                      if (scope != ShelfFacetScope.descendants ||
                          (widget.hierarchical &&
                              widget.currentFolder!.isNotEmpty))
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: ChoiceChip(
                            key: ValueKey('shelf-scope-${scope.name}'),
                            label: Text(switch (scope) {
                              ShelfFacetScope.current =>
                                t.bookshelf.facets.current,
                              ShelfFacetScope.descendants =>
                                t.bookshelf.facets.descendants,
                              ShelfFacetScope.all => t.bookshelf.facets.all,
                            }),
                            materialTapTargetSize: MaterialTapTargetSize.padded,
                            selected: _draft.scope == scope,
                            onSelected: (_) => setState(
                              () => _draft = _draft.copyWith(scope: scope),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
          ],
          if (widget.keyword != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: SearchQueryField(
                      key: const ValueKey('shelf-filter-work-query'),
                      query: _workQuery,
                      inline: true,
                      closeOnSubmit: false,
                      hintText: t.videoLibrary.localCatalogSearchHint,
                      onChanged: (value) => setState(() => _workQuery = value),
                    ),
                  ),
                  KeywordScopeMenu(
                    compact: true,
                    scope: _workScope,
                    onChanged: (value) => setState(() => _workScope = value),
                  ),
                ],
              ),
            ),
          if (dimensions.length > 1)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final value in dimensions)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(
                        key: ValueKey('shelf-facet-$value'),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        label: Text(
                          (_draft.values[value]?.isNotEmpty ?? false)
                              ? '${_labels[value]} · ${_draft.values[value]!.length}'
                              : _labels[value]!,
                        ),
                        selected: dimension == value,
                        onSelected: (_) => setState(() {
                          _expanded = value;
                          _query.clear();
                        }),
                      ),
                    ),
                ],
              ),
            ),
          if (preferenceError != null)
            ShelfTagPinError(
              message: preferenceError,
              onRetry: _saving ? null : _favoritesChanged,
            ),
          if (dimension != null)
            SearchFieldSurface(
              child: TextField(
                key: const ValueKey('shelf-facet-search'),
                controller: _query,
                decoration: searchFieldDecoration(
                  context,
                  hintText: t.bookshelf.facets.search(
                    name: _labels[dimension]!,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    final footer = Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          key: const ValueKey('shelf-filter-apply'),
          style: FilledButton.styleFrom(minimumSize: const Size(44, 44)),
          onPressed: () {
            widget.keyword?.onApply(_workQuery.trim(), _workScope);
            Navigator.pop(
              context,
              _draft.copyWith(applied: !_resetDraft || _draft.isActive),
            );
          },
          child: Text(
            t.bookshelf.facets.resultTitle(count: count),
            key: const ValueKey('shelf-filter-count'),
          ),
        ),
      ),
    );
    final content = FacetFilterBody(
      key: const ValueKey('shelf-filter-fields'),
      header: header,
      controls: controls,
      footer: footer,
      scrollKey: const ValueKey('shelf-focused-options'),
      hasScope: !widget.focusedLayout,
      options: SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: FacetOptionSliver(
          values: values,
          query: _query,
          counts: counts,
          selected: selected,
          onToggle: (value) => _toggle(dimension!, value),
          optionKey: (value) => ValueKey('shelf-option-$dimension-$value'),
          label: _label,
          reorderController: _reorder,
          trailing: !_supportsFacetFavorites(dimension)
              ? null
              : (value) => ShelfTagPinButton(
                  key: ValueKey(
                    dimension == 'tags'
                        ? 'shelf-star-$value'
                        : 'shelf-star-$dimension-$value',
                  ),
                  pinned: pinned.contains(value),
                  tooltip: dimension == 'tags'
                      ? null
                      : ShelfTagPinButton.optionTooltip(
                          context,
                          label: _label(value),
                          pinned: pinned.contains(value),
                        ),
                  onPressed: !_saving && preferenceError == null
                      ? () => _star(dimension!, value)
                      : null,
                ),
          empty: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              dimension == null
                  ? t.bookshelf.facets.emptyMetadata
                  : t.bookshelf.facets.emptyOptions,
            ),
          ),
        ),
      ),
    );
    if (widget.nativeMaterial) return content;
    return LayoutBuilder(
      builder: (context, bounds) {
        final media = MediaQuery.of(context);
        final available = math.max(
          0.0,
          math.min(
                bounds.maxHeight,
                media.size.height - media.padding.vertical,
              ) -
              inset,
        );
        return Padding(
          padding: EdgeInsets.only(bottom: inset),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: math.min(600, available * .82),
                child: content,
              ),
            ),
          ),
        );
      },
    );
  }

  String _label(String value) => shelfFacetDisplayValue(value);
}
