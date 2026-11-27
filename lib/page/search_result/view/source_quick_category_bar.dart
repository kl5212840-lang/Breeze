import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search/widget/search_toolbar_scope.dart';
import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart'
    show normalizePluginId;
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/page/search_result/bloc/search_bloc.dart';
import 'package:zephyr/page/search_result/view/search_bar.dart';
import 'package:zephyr/page/search_result/view/source_list_categories.dart';
import 'package:zephyr/page/search_result/view/source_list_filter_bar.dart';
import 'package:zephyr/page/search_result/view/source_search_capabilities.dart';
import 'package:zephyr/page/search_result/widgets/source_page_jump.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/service/plugin_account_authentication.dart';
import 'package:zephyr/page/source_shell/source_list_block_preferences.dart';
import 'package:zephyr/widgets/read_recovery_scope.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'package:zephyr/widgets/multi_choice_list_dialog.dart';
import 'package:zephyr/page/source_shell/source_list_view_toggle.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/source_shell/source_experience_preferences.dart';

/// Search controls use each source's actual browse and filter capabilities.
class SourceQuickCategoryBar extends StatefulWidget {
  const SourceQuickCategoryBar({
    super.key,
    required this.categories,
    required this.detailedView,
    required this.onViewChanged,
    this.pageLabel,
    this.pageWidthSample,
    this.appliedSort,
    this.onPageTap,
    this.trailingAction,
    this.sourceBlockedCategories = const {},
    this.onShuffle,
    this.shuffling = false,
  });

  final List<String> categories;
  final bool detailedView;
  final ValueChanged<bool> onViewChanged;
  final String? pageLabel;
  final String? pageWidthSample;
  final int? appliedSort;
  final VoidCallback? onPageTap;
  final Widget? trailingAction;
  final Set<String> sourceBlockedCategories;
  final VoidCallback? onShuffle;
  final bool shuffling;

  @override
  State<SourceQuickCategoryBar> createState() => _SourceQuickCategoryBarState();
}

class _SourceQuickCategoryBarState extends State<SourceQuickCategoryBar> {
  Timer? _searchTimer;
  int _reconcileEpoch = 0;
  bool _editingBlockedCategories = false;
  bool _active = false, _pendingRefresh = false;
  void _setActive(bool active) {
    _active = active;
    if (!active) {
      if (_searchTimer != null) _pendingRefresh = true;
      _searchTimer?.cancel();
      _searchTimer = null;
    } else if (_pendingRefresh) {
      _scheduleSearch();
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(SourceQuickCategoryBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceBlockedCategories
        .difference(widget.sourceBlockedCategories)
        .isNotEmpty) {
      // A plugin can omit screened items upstream. Reread once on return
      // when a rule is removed so those items can become visible again.
      _scheduleSearch();
    }
  }

  void _scheduleSearch() {
    _searchTimer?.cancel();
    if (!_active) {
      _pendingRefresh = true;
      return;
    }
    _pendingRefresh = false;
    _searchTimer = Timer(const Duration(milliseconds: 280), _runSearch);
  }

  void _runSearch() {
    if (!mounted) return;
    _searchTimer = null;
    if (!_active) {
      _pendingRefresh = true;
      return;
    }
    final bloc = context.read<SearchBloc>();
    bloc.add(SearchEvent(searchStates: context.read<SearchCubit>().state));
  }

  void _setBlockedCategories(Set<String> blocked) {
    final cubit = context.read<SearchCubit>();
    final current = cubit.state;
    if (setEquals(
      blockedCategoryNames(current.pluginExtern['blockedCategories']),
      blocked,
    )) {
      return;
    }
    final extern = <String, dynamic>{...current.pluginExtern};
    extern['blockedCategories'] = blocked.toList();
    cubit.update(current.copyWith(pluginExtern: extern));
    final jm =
        normalizePluginId(current.from) ==
        PluginAccountAuthenticationService.jm;
    // JM and Bika apply the quick exclusions to loaded results.
    if (!jm && !isBikaExperienceSource(current.from)) _scheduleSearch();
  }

  void _toggleBlockedCategory(
    String category,
    Set<String> saved,
    ValueChanged<Set<String>> persist,
  ) {
    final next = {...saved};
    if (!next.add(category)) next.remove(category);
    persist(next);
    _setBlockedCategories(next);
  }

  Future<void> _editBlockedCategories(
    BuildContext context,
    Set<String> savedBlocked,
    ValueChanged<Set<String>> persist,
  ) async {
    if (_editingBlockedCategories) return;
    _editingBlockedCategories = true;
    final cubit = context.read<SearchCubit>();
    final query = cubit.state;
    final source = normalizePluginId(query.from);
    final owner = pluginSessionWriteFence.generation(source);
    try {
      final picked = await showMultiChoiceListDialog(
        context,
        title: t.searchResult.blockCategories,
        options: [
          for (final category in {...widget.categories, ...savedBlocked})
            MultiChoiceDialogOption(label: category, value: category),
        ],
        initialSelected: savedBlocked,
        confirmText: t.common.save,
      );
      if (picked == null ||
          !context.mounted ||
          cubit.state.from != query.from ||
          pluginSessionWriteFence.isChanging(source) ||
          pluginSessionWriteFence.generation(source) != owner) {
        return;
      }
      final current = cubit.state.pluginExtern;
      final currentLocal = blockedCategoryNames(current['blockedCategories']);
      final changed = {
        ...currentLocal.difference(savedBlocked.difference(picked)),
        ...picked.difference(savedBlocked),
      };
      persist(changed);
      _setBlockedCategories(changed);
    } finally {
      _editingBlockedCategories = false;
    }
  }

  Widget _controls(
    BuildContext context,
    SearchStates state,
    Map<String, String> sorts,
    VoidCallback? openBlockedCategories,
  ) {
    final extent = CollectionToolbarMetrics.actionExtentOf(context);
    final page = widget.pageLabel;
    final pageStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: CollectionToolbarMetrics.contentPaddingOf(
        context,
        startInset: CollectionToolbarMetrics.searchResultContentInset,
        bottom: 4,
      ),
      child: Row(
        key: const ValueKey('search-result.toolbar'),
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: page == null
                  ? null
                  : TextButton(
                      key: const ValueKey('search-result.page-progress'),
                      style: TextButton.styleFrom(
                        foregroundColor: pageStyle?.color,
                        textStyle: pageStyle,
                        minimumSize: Size(extent, extent),
                        padding: const EdgeInsetsDirectional.only(end: 8),
                      ).copyWith(alignment: AlignmentDirectional.centerStart),
                      onPressed: widget.onPageTap,
                      child: Text(
                        page,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
            ),
          ),
          if (sorts.isNotEmpty)
            NativeVideoMenu(
              hostPresentation: true,
              noPageDimming: true,
              bare: true,
              label: '',
              tooltip: t.search.sortBy,
              icon: Icons.swap_vert_rounded,
              symbol: 'arrow.up.arrow.down',
              width: VideoControlMetrics.touchExtent,
              selected: state.sortBy.toString(),
              options: sorts,
              onSelected: (value) {
                final sort = int.tryParse(value);
                if (sort != null && sort != state.sortBy) {
                  _changeSort(context, sort);
                }
              },
            ),
          SearchResultOptions(onOpenBlockedCategories: openBlockedCategories),
          ?widget.trailingAction,
          SourceListViewToggle(
            detailed: widget.detailedView,
            onChanged: widget.onViewChanged,
            bare: true,
          ),
        ],
      ),
    );
  }

  void _changeSort(BuildContext context, int sortBy) {
    final cubit = context.read<SearchCubit>();
    final current = cubit.state;
    final extern = <String, dynamic>{...current.pluginExtern, 'sortBy': sortBy};
    extern.remove('sort');
    cubit.update(current.copyWith(sortBy: sortBy, pluginExtern: extern));
    _scheduleSearch();
  }

  Widget _sourceControls(
    BuildContext context,
    SearchStates state,
    Map<String, String> sorts,
    Set<String> excluded,
    VoidCallback? openBlockedCategories, {
    required bool sortPending,
    bool showFilter = true,
  }) {
    final extent = CollectionToolbarMetrics.actionExtentOf(context);
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium;
    final pageStyle = style?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final foreground = theme.colorScheme.onSurfaceVariant;
    final page = widget.pageLabel;
    final sortBy =
        int.tryParse(state.pluginExtern['sortBy']?.toString() ?? '') ??
        widget.appliedSort ??
        state.sortBy;
    final sortValue = sortBy.toString();
    final sortLabel = sorts[sortValue] ?? t.search.sortBy;
    final viewLabel = widget.detailedView
        ? t.discover.gridLayout
        : t.discover.listLayout;
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    );
    double width(String text, double padding, {TextStyle? textStyle}) {
      painter.text = TextSpan(text: text, style: textStyle ?? style);
      painter.layout();
      return (painter.width.ceilToDouble() + padding).clamp(
        extent,
        double.infinity,
      );
    }

    final pageSample = widget.pageWidthSample ?? page;
    final pageWidth = pageSample == null
        ? 0.0
        : width(pageSample, 20, textStyle: pageStyle);
    final sortWidth = sorts.isNotEmpty
        ? width(sortLabel, 34)
        : sortPending
        ? extent
        : 0.0;
    final filterWidth = showFilter ? width(t.comicList.filter, 34) : 0.0;
    final viewWidth = width(viewLabel, 36);
    final enlargedHeight = painter.height + 16;
    painter.dispose();
    final buttonStyle = TextButton.styleFrom(
      minimumSize: Size.square(extent),
      foregroundColor: foreground,
      textStyle: style,
      padding: EdgeInsets.zero,
    );
    return VideoControlAppearance(
      systemControls: usesNativeSourceChrome(context),
      child: Padding(
        padding: CollectionToolbarMetrics.contentPaddingOf(
          context,
          inset: CollectionToolbarMetrics.searchResultContentInset,
          bottom: 4,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final trailingWidth = widget.trailingAction == null ? 0.0 : extent;
            final commonWidth = pageWidth + trailingWidth;
            final showLabels =
                maxWidth >= commonWidth + sortWidth + filterWidth + viewWidth;
            final compactWidth =
                commonWidth +
                (1 + (sortWidth == 0 ? 0 : 1) + (showFilter ? 1 : 0)) * extent;
            final pageButton = page == null
                ? (pageWidth == 0
                      ? null
                      : SizedBox(width: pageWidth.clamp(0, maxWidth)))
                : SizedBox(
                    width: pageWidth.clamp(0, maxWidth),
                    child: SourcePageJumpButton(
                      key: const ValueKey('search-result.page-progress'),
                      label: page,
                      onPressed: widget.onPageTap,
                    ),
                  );
            final commands = [
              if (sorts.isNotEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: extent),
                  child: NativeVideoMenu(
                    key: const ValueKey('search-result.sort'),
                    hostPresentation: true,
                    noPageDimming: true,
                    bare: true,
                    label: showLabels ? sortLabel : '',
                    tooltip: '${t.search.sortBy} · $sortLabel',
                    icon: showLabels ? null : Icons.swap_vert_rounded,
                    symbol: showLabels ? '' : 'arrow.up.arrow.down',
                    width: showLabels
                        ? sortWidth
                        : VideoControlMetrics.touchExtent,
                    compactTextChoice: showLabels,
                    selected: sortValue,
                    options: sorts,
                    onSelected: (value) {
                      final sort = int.tryParse(value);
                      if (sort != null && sort != sortBy) {
                        _changeSort(context, sort);
                      }
                    },
                  ),
                )
              else if (sortPending)
                SizedBox.square(dimension: extent),
              if (showFilter)
                SearchResultOptions(
                  key: const ValueKey('search-result.filter-options'),
                  activeFilters:
                      excluded.isNotEmpty ||
                      (int.tryParse('${state.pluginExtern['y']}') ?? 0) > 0,
                  labelWidth: showLabels ? filterWidth : null,
                  onOpenBlockedCategories: openBlockedCategories,
                ),
              ?widget.trailingAction,
              if (showLabels)
                SizedBox(
                  width: viewWidth,
                  child: Tooltip(
                    message: widget.detailedView
                        ? t.comicList.switchToGrid
                        : t.comicList.switchToList,
                    child: TextButton.icon(
                      icon: Icon(
                        widget.detailedView
                            ? Icons.grid_view_rounded
                            : Icons.view_list_outlined,
                        size: 16,
                      ),
                      label: Text(viewLabel, maxLines: 1),
                      style: buttonStyle,
                      onPressed: () =>
                          widget.onViewChanged(!widget.detailedView),
                    ),
                  ),
                )
              else
                SourceListViewToggle(
                  detailed: widget.detailedView,
                  onChanged: widget.onViewChanged,
                  bare: true,
                ),
            ];
            return SearchToolbarScope(
              extent: enlargedHeight > extent ? enlargedHeight : null,
              child: !showLabels && maxWidth < compactWidth
                  ? Wrap(
                      key: const ValueKey('search-result.toolbar'),
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [?pageButton, ...commands],
                    )
                  : Row(
                      key: const ValueKey('search-result.toolbar'),
                      children: [?pageButton, const Spacer(), ...commands],
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _bikaControls(
    BuildContext context,
    SearchStates state,
    Widget quickCategories,
  ) {
    final extent = CollectionToolbarMetrics.actionExtentOf(context);
    final url = state.pluginExtern['url']?.toString();
    final random = isBikaRandomResult(state);
    final colors = Theme.of(context).colorScheme;
    final noteStyle = TextButton.styleFrom(
      minimumSize: Size.square(extent),
      foregroundColor: colors.onSurfaceVariant,
      textStyle: Theme.of(context).textTheme.labelMedium,
      padding: const EdgeInsetsDirectional.only(end: 8),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        quickCategories,
        if (random)
          Padding(
            key: const ValueKey('search-result.toolbar'),
            padding: CollectionToolbarMetrics.contentPaddingOf(
              context,
              inset: CollectionToolbarMetrics.searchResultContentInset,
              bottom: 4,
            ),
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: CollectionToolbarMetrics.searchControlGap,
              children: [
                TextButton.icon(
                  key: const ValueKey('search-result.shuffle'),
                  style: noteStyle,
                  icon: widget.shuffling
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.shuffle_rounded, size: 18),
                  label: Text(t.searchResult.shuffle),
                  onPressed: widget.onShuffle,
                ),
                SourceListViewToggle(
                  detailed: widget.detailedView,
                  onChanged: widget.onViewChanged,
                  bare: true,
                ),
              ],
            ),
          )
        else
          FutureBuilder<List<Map<String, dynamic>>>(
            future: sourceAdvancedFields(state.from, browseUrl: url),
            builder: (context, snapshot) {
              final fields = snapshot.connectionState == ConnectionState.done
                  ? snapshot.data ?? const []
                  : const <Map<String, dynamic>>[];
              return _sourceControls(
                context,
                state,
                sourceSortOptions(fields),
                const {},
                null,
                sortPending:
                    snapshot.connectionState == ConnectionState.waiting,
                showFilter: false,
              );
            },
          ),
      ],
    );
  }

  Widget _quickCategories(
    Set<String> savedBlocked,
    ValueChanged<Set<String>> persist, {
    Set<String> locked = const {},
    String? label,
  }) {
    final categories = {...widget.categories, ...locked, ...savedBlocked};
    if (categories.isEmpty) return const SizedBox.shrink();
    return SourceListFilterBar(
      key: const ValueKey('search-result.quick-categories'),
      categories: categories.toList(),
      categoryLabel: label,
      fullCategoryTouchTargets: true,
      contentInset: CollectionToolbarMetrics.searchResultContentInset,
      categoriesOnly: true,
      blockedCategories: {...locked, ...savedBlocked},
      lockedCategories: locked,
      onCategoryTap: (category) =>
          _toggleBlockedCategory(category, savedBlocked, persist),
      onClearBlockedCategories: savedBlocked.isEmpty
          ? null
          : () {
              persist({});
              _setBlockedCategories({});
            },
      sortValue: '',
      sortOptions: const {},
      onSortChanged: (_) {},
      detailedView: widget.detailedView,
      onViewChanged: widget.onViewChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ReadRecoveryHost(
      onActiveChanged: _setActive,
      child: BlocBuilder<SearchCubit, SearchStates>(
        builder: (context, state) {
          final bika = isBikaExperienceSource(state.from);
          final jm =
              normalizePluginId(state.from) ==
              PluginAccountAuthenticationService.jm;
          final blocked = blockedCategoryNames(
            state.pluginExtern['blockedCategories'],
          );
          return SourceCategoryBlockScope(
            // The legacy Bika search scope has already been imported into
            // settings. Quick changes belong to the result list.
            scope: bika
                ? '${state.from}|search|categoryBlock'
                : '${state.from}|search',
            initial: blocked,
            onRestored: _setBlockedCategories,
            builder: (context, savedBlocked, persist) {
              final reconcileEpoch = ++_reconcileEpoch;
              if (!setEquals(blocked, savedBlocked)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted &&
                      reconcileEpoch == _reconcileEpoch &&
                      context.read<SearchCubit>().state == state) {
                    _setBlockedCategories(savedBlocked);
                  }
                });
              }
              if (bika) {
                return _bikaControls(
                  context,
                  state,
                  _quickCategories(
                    savedBlocked,
                    persist,
                    locked: widget.sourceBlockedCategories,
                  ),
                );
              }
              return FutureBuilder<List<Map<String, dynamic>>>(
                future: sourceAdvancedFields(state.from),
                builder: (context, snapshot) {
                  final sorts = snapshot.connectionState == ConnectionState.done
                      ? sourceSortOptions(snapshot.data ?? const [])
                      : const <String, String>{};
                  final categories = {...widget.categories, ...savedBlocked};
                  final editBlocked = categories.isEmpty
                      ? null
                      : () => _editBlockedCategories(
                          context,
                          savedBlocked,
                          persist,
                        );
                  if (!jm) return _controls(context, state, sorts, editBlocked);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _quickCategories(
                        savedBlocked,
                        persist,
                        label: t.searchResult.blockCategories,
                      ),
                      _sourceControls(
                        context,
                        state,
                        sorts,
                        savedBlocked,
                        editBlocked,
                        sortPending:
                            snapshot.connectionState == ConnectionState.waiting,
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
