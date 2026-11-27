import 'package:zephyr/page/bookshelf/widgets/filter_sheet_detents.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:zephyr/widgets/native_material_surface.dart';
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

typedef ShelfFilterSnapshot = ({
  List<ShelfFacetEntry> entries,
  String scopeLabel,
  bool loadingMetadata,
  bool canLoadMetadata,
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

/// When [autoLoadMetadata] is enabled, [liveSnapshot] reports each page's
/// loading cycle and [onLoadMetadata] starts one page at a time.
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
  bool keywordAsFacet = false,
  bool keywordScopeEditable = false,
  bool showScopeLabel = false,
  bool autoLoadMetadata = false,
  String? loadMetadataLabel,
  ValueListenable<ShelfFilterSnapshot>? liveSnapshot,
  VoidCallback? onLoadMetadata,
}) async {
  final favorites = await _loadFacetFavorites(preferenceKey);
  if (!context.mounted) return null;
  Widget sheet(BuildContext sheetContext) {
    final route = ModalRoute.of(sheetContext);
    if (route != null) onRouteOpened?.call(route);
    Widget panel(ShelfFilterSnapshot? snapshot, Widget? detentHandle) =>
        _ShelfFilterSheet(
          detentHandle: detentHandle,
          entries: snapshot?.entries ?? entries,
          initial: initial,
          preferenceKey: preferenceKey,
          scopeLabel: snapshot?.scopeLabel ?? scopeLabel,
          currentFolder: currentFolder,
          hierarchical: hierarchical,
          focusedLayout: focusedLayout,
          showAllRecordsLabel: showAllRecordsLabel,
          nativeMaterial: nativeMaterial,
          favorites: favorites,
          keyword: keyword,
          keywordAsFacet: keywordAsFacet,
          keywordScopeEditable: keywordScopeEditable,
          showScopeLabel: showScopeLabel,
          autoLoadMetadata: autoLoadMetadata,
          autoLoadSnapshot: autoLoadMetadata ? liveSnapshot : null,
          loadMetadataLabel: loadMetadataLabel,
          loadingMetadata: snapshot?.loadingMetadata ?? false,
          onLoadMetadata: snapshot?.canLoadMetadata == true
              ? onLoadMetadata
              : null,
        );
    Widget livePanel(Widget? handle) => liveSnapshot == null
        ? panel(null, handle)
        : ValueListenableBuilder(
            valueListenable: liveSnapshot,
            builder: (_, snapshot, _) => panel(snapshot, handle),
          );
    return nativeMaterial
        ? livePanel(null)
        : FilterSheetDetents(builder: (_, handle) => livePanel(handle));
  }

  if (nativeMaterial) {
    return showVideoTaskSheet<ShelfFacetSelection>(
      context: context,
      useRootNavigator: true,
      systemStyle: AppInterfaceStyleScope.usesSystem(context),
      filterDetents: true,
      builder: sheet,
    );
  }
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<ShelfFacetSelection>(
    context: context,
    // Main tabs own nested Navigators below the persistent navigation bar.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    backgroundColor: Colors.transparent,
    clipBehavior: Clip.none,
    elevation: 0,
    builder: sheet,
  );
}

class _ShelfFilterSheet extends StatefulWidget {
  const _ShelfFilterSheet({
    required this.entries,
    this.detentHandle,
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
    this.keywordAsFacet = false,
    this.keywordScopeEditable = false,
    this.showScopeLabel = false,
    this.autoLoadMetadata = false,
    this.autoLoadSnapshot,
    this.loadMetadataLabel,
    this.loadingMetadata = false,
    this.onLoadMetadata,
  });
  final List<ShelfFacetEntry> entries;
  final Widget? detentHandle;
  final ShelfFacetSelection initial;
  final String preferenceKey, scopeLabel;
  final String? currentFolder;
  final bool hierarchical, focusedLayout, nativeMaterial, showAllRecordsLabel;
  final _FacetFavorites favorites;
  final ShelfFilterKeyword? keyword;
  final bool keywordAsFacet, keywordScopeEditable;
  final bool showScopeLabel, autoLoadMetadata;
  final String? loadMetadataLabel;
  final ValueListenable<ShelfFilterSnapshot>? autoLoadSnapshot;
  final bool loadingMetadata;
  final VoidCallback? onLoadMetadata;
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
  static const _autoLoadLimit = 3;
  int _autoLoads = 0;
  bool _autoLoadScheduled = false, _awaitingAutoLoad = false;
  bool _autoLoadWasLoading = false;
  String? _expanded, _visibleDimension, _preferenceError;
  final _query = TextEditingController();
  final _optionScroll = ScrollController();
  bool get _usesTitleFacet => widget.keywordAsFacet && widget.keyword != null;
  static const _titleFacet = 'title';
  late String _workQuery = widget.keyword?.query ?? '';
  late KeywordSearchScope _workScope =
      _usesTitleFacet && !widget.keywordScopeEditable
      ? KeywordSearchScope.title
      : widget.keyword?.scope ?? KeywordSearchScope.all;
  Map<String, String> get _labels => {
    'tags': t.bookshelf.facets.tags,
    'category': t.bookshelf.facets.category,
    'year': t.bookshelf.facets.year,
    'area': t.bookshelf.facets.area,
    'language': t.bookshelf.facets.language,
    'author': t.bookshelf.facets.author,
    'team': t.searchResult.bikaFilterTranslationTeam,
    _titleFacet: widget.keywordScopeEditable
        ? t.videoLibrary.localCatalogSearchHint
        : keywordSearchScopeLabel(KeywordSearchScope.title),
    'quality': t.bookshelf.facets.quality,
    'duration': t.videoFilters.duration,
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
    if (_usesTitleFacet && _workQuery.trim().isNotEmpty) {
      _expanded = _titleFacet;
    }
    _favorites = widget.favorites;
    widget.autoLoadSnapshot?.addListener(_autoLoadSnapshotChanged);
    ShelfFacetPreferences.changes.addListener(_favoritesChanged);
    PortablePreferences.changes.addListener(_favoritesChanged);
    _favoritesChanged();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleAutoLoad();
  }

  @override
  void didUpdateWidget(covariant _ShelfFilterSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoLoadSnapshot != widget.autoLoadSnapshot) {
      oldWidget.autoLoadSnapshot?.removeListener(_autoLoadSnapshotChanged);
      widget.autoLoadSnapshot?.addListener(_autoLoadSnapshotChanged);
      _autoLoadWasLoading = widget.loadingMetadata;
    }
    _scheduleAutoLoad();
  }

  void _autoLoadSnapshotChanged() {
    final loading = widget.autoLoadSnapshot?.value.loadingMetadata == true;
    if (_autoLoadWasLoading && !loading) _awaitingAutoLoad = false;
    _autoLoadWasLoading = loading;
  }

  void _scheduleAutoLoad() {
    if (!_canAutoLoad || _autoLoadScheduled) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return;
    _autoLoadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoLoadScheduled = false;
      if (!mounted ||
          !_canAutoLoad ||
          !route.isCurrent ||
          route.animation?.status == AnimationStatus.reverse) {
        return;
      }
      // A no-op callback must not be retried every rebuild. Only a host
      // loading → idle transition can unlock the next page.
      _awaitingAutoLoad = true;
      _autoLoads++;
      widget.onLoadMetadata?.call();
    });
  }

  bool get _canAutoLoad =>
      widget.autoLoadMetadata &&
      _autoLoads < _autoLoadLimit &&
      !_awaitingAutoLoad &&
      !widget.loadingMetadata &&
      widget.onLoadMetadata != null;

  @override
  void dispose() {
    _favoritesEpoch++;
    widget.autoLoadSnapshot?.removeListener(_autoLoadSnapshotChanged);
    ShelfFacetPreferences.changes.removeListener(_favoritesChanged);
    PortablePreferences.changes.removeListener(_favoritesChanged);
    _query.dispose();
    _optionScroll.dispose();
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

  Widget _keywordField({required bool editableScope, bool inFacet = false}) {
    final field = SearchQueryField(
      key: const ValueKey('shelf-filter-work-query'),
      query: _workQuery,
      inline: true,
      closeOnSubmit: false,
      textInputAction: inFacet ? TextInputAction.done : TextInputAction.search,
      hintText: t.videoLibrary.localCatalogSearchHint,
      onChanged: (value) => setState(() => _workQuery = value),
    );
    if (!editableScope) return field;
    return Row(
      spacing: 8,
      children: [
        Expanded(child: field),
        KeywordScopeMenu(
          compact: true,
          scope: _workScope,
          onChanged: (value) => setState(() => _workScope = value),
        ),
      ],
    );
  }

  Widget _focused(
    BuildContext context,
    Map<String, Map<String, int>> options,
    int count,
    double inset,
  ) {
    final available = facetOptionsAppliedFirst(options.keys.toList(), {
      for (final entry in widget.initial.values.entries)
        if (entry.value.isNotEmpty) entry.key,
    });
    final dimensions = _usesTitleFacet
        ? <String>{
            _titleFacet,
            ...available,
            for (final dimension in shelfFacetDimensions)
              if (widget.entries.any(
                (entry) => entry.fields[dimension]?.isNotEmpty == true,
              ))
                dimension,
          }.toList()
        : available;
    final dimension = dimensions.contains(_expanded)
        ? _expanded
        : _usesTitleFacet &&
              !widget.keywordScopeEditable &&
              dimensions.contains('tags')
        ? 'tags'
        : available.firstOrNull ?? dimensions.firstOrNull;
    final titleSelected = _usesTitleFacet && dimension == _titleFacet;
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
    final ordered = {...counts.keys, ...selected}.toList()
      ..sort((a, b) {
        final rank =
            (pinned.contains(b) ? 1 : 0) - (pinned.contains(a) ? 1 : 0);
        return rank != 0 ? rank : a.compareTo(b);
      });
    final values = facetOptionsAppliedFirst(
      ordered,
      widget.initial.values[dimension] ?? const {},
    );
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
          if (widget.scopeLabel.isNotEmpty &&
              (widget.showScopeLabel ||
                  widget.autoLoadMetadata ||
                  !widget.focusedLayout ||
                  !widget.autoLoadMetadata &&
                      (widget.onLoadMetadata != null ||
                          widget.loadingMetadata)))
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.scopeLabel,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (!widget.autoLoadMetadata && widget.loadingMetadata)
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (!widget.autoLoadMetadata &&
                    widget.onLoadMetadata != null)
                  TextButton(
                    key: const ValueKey('shelf-filter-more-metadata'),
                    onPressed: widget.onLoadMetadata,
                    child: Text(
                      widget.loadMetadataLabel ??
                          (LocaleSettings.currentLocale.languageCode == 'zh'
                              ? '补齐标签'
                              : 'Load tags'),
                    ),
                  ),
              ],
            ),
          if (!widget.focusedLayout) ...[
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
          if (widget.keyword != null && !_usesTitleFacet)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: _keywordField(editableScope: true),
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
                        onSelected: (_) {
                          if (_usesTitleFacet && value == dimension) return;
                          if (_usesTitleFacet && _optionScroll.hasClients) {
                            _optionScroll.jumpTo(0);
                          }
                          setState(() {
                            _expanded = value;
                            _query.clear();
                          });
                        },
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
          if (titleSelected)
            _keywordField(
              editableScope: widget.keywordScopeEditable,
              inFacet: true,
            )
          else if (dimension != null)
            SearchFieldSurface(
              child: TextField(
                key: const ValueKey('shelf-facet-search'),
                controller: _query,
                textInputAction: TextInputAction.done,
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
      header: Column(children: [?widget.detentHandle, header]),
      controls: controls,
      footer: footer,
      scrollKey: const ValueKey('shelf-focused-options'),
      hasScope:
          !widget.focusedLayout ||
          widget.showScopeLabel ||
          widget.autoLoadMetadata,
      scrollController: _usesTitleFacet ? _optionScroll : null,
      options: titleSelected
          ? const SliverToBoxAdapter(child: SizedBox.shrink())
          : SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: FacetOptionSliver(
                values: values,
                query: _query,
                counts: counts,
                selected: selected,
                onToggle: (value) => _toggle(dimension!, value),
                optionKey: (value) =>
                    ValueKey('shelf-option-$dimension-$value'),
                label: (value) => _label(dimension, value),
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
                                label: _label(dimension, value),
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
          child: NativeMaterialSurface(
            radius: 20,
            androidGlass: true,
            topOnly: true,
            readableContent: true,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: FilterSheetDetents.heightOf(
                  context,
                  compact: math.min(600, available * .82),
                  expanded: FilterSheetDetents.expandedHeight(
                    context,
                    available,
                    reservedBottom: media.padding.bottom,
                  ),
                ),
                child: content,
              ),
            ),
          ),
        );
      },
    );
  }

  String _label(String? dimension, String value) =>
      switch ((dimension, value)) {
        ('duration', 'less-than-10') => t.download.durationShort,
        ('duration', '10-to-30') => t.download.durationMedium,
        ('duration', '30-to-60') => t.download.durationLong,
        ('duration', '60-or-more') => t.download.durationHour,
        _ => shelfFacetDisplayValue(value),
      };
}
