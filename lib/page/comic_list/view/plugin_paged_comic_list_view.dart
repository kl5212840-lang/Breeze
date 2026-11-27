import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/comic_list/view/jm_cloud_folder_controls.dart';
import 'package:zephyr/widgets/applied_filter_bar.dart';
import 'package:zephyr/widgets/collection_results_row.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'package:zephyr/widgets/read_recovery_scope.dart';
import 'package:zephyr/widgets/pull_refresh_feedback.dart';
import 'package:auto_route/auto_route.dart';
import 'package:zephyr/page/comic_list/cubit/jm_collection_snapshots.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:zephyr/page/source_shell/source_list_scroll_positions.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/widgets/tab_reselect_scope.dart';
import 'package:zephyr/page/comic_list/cubit/plugin_paged_comic_list_cubit.dart';
import 'package:zephyr/page/comic_list/cubit/plugin_paged_comic_list_state.dart';
import 'package:zephyr/page/comic_list/view/plugin_comic_grid_sliver.dart';
import 'package:zephyr/page/comic_list/view/bika_ranking_list.dart';
import 'package:zephyr/page/search_result/view/source_search_detail_list.dart';
import 'package:zephyr/page/search_result/view/source_list_categories.dart';
import 'package:zephyr/page/search_result/view/source_list_filter_bar.dart';
import 'package:zephyr/page/search_result/view/source_loaded_result_filter.dart';
import 'package:zephyr/page/search_result/widgets/filtered_result_pages.dart';
import 'package:zephyr/page/search_result/widgets/source_page_jump.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/widgets/source_page_divider.dart';
import 'package:zephyr/page/source_shell/source_list_block_preferences.dart';
import 'package:zephyr/page/source_shell/source_experience_preferences.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry_mapper.dart';
import 'package:zephyr/widgets/comic_simplify_entry/jm_cover_like_badge.dart';
import 'package:zephyr/service/jm_list_like_counts.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/error_view.dart';
import 'package:zephyr/page/source_shell/widgets/bika_connection_notice.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';

export 'package:zephyr/page/comic_list/cubit/plugin_paged_comic_list_cubit.dart';
export 'package:zephyr/page/comic_list/cubit/plugin_paged_comic_list_state.dart';

class PluginPagedComicListView extends StatelessWidget {
  const PluginPagedComicListView({
    super.key,
    required this.pluginId,
    required this.fnPath,
    required this.coreBuilder,
    required this.externBuilder,
    this.shrinkWrap = false,
    this.physics,
    this.collectionTargetId,
    this.collectionTargetName,
    this.rankingLayout = false,
    this.cloudFavorite = false,
    this.flatCollectionControls = false,
    this.detailedView = false,
    this.blockedCategories = const {},
    this.requestPage,
    this.localResultTools = true,
    this.publicLoadedFacets = false,
    this.loadedSearchController,
    this.loadedSearchFocusNode,
    this.loadedSearchScope,
    this.loadedSearchExpanded = true,
    this.loadedChromeBuilder,
    this.pageViewAction,
    this.focusedFacets = false,
    this.tabReselectEnabled = false,
  });

  final String pluginId;
  final String fnPath;
  final PluginPageCoreBuilder coreBuilder;
  final PluginPageExternBuilder externBuilder;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final String? collectionTargetId;
  final String? collectionTargetName;
  final bool rankingLayout;
  final bool cloudFavorite, flatCollectionControls;
  final bool detailedView;
  final Set<String> blockedCategories;
  final PluginPageRequest? requestPage;
  final bool localResultTools, focusedFacets, publicLoadedFacets;
  final bool tabReselectEnabled;
  final Widget? pageViewAction;
  final TextEditingController? loadedSearchController;
  final FocusNode? loadedSearchFocusNode;
  final KeywordSearchScope? loadedSearchScope;
  final bool loadedSearchExpanded;
  final Widget Function(BuildContext, SourceLoadedResultChrome)?
  loadedChromeBuilder;

  @override
  Widget build(BuildContext context) {
    final list = BlocProvider(
      create: (_) => PluginPagedComicListCubit(
        pluginId: pluginId,
        fnPath: fnPath,
        coreBuilder: coreBuilder,
        externBuilder: externBuilder,
        requestPage: requestPage,
        privateCollection:
            cloudFavorite ||
            pluginId == JmListLikeCounts.source &&
                fnPath == 'getSiteWatchHistory',
        jmSnapshotCache: cloudFavorite,
      )..loadInitial(),
      child: Builder(
        builder: (context) => ReadRecoveryHost(
          onActiveChanged: context
              .read<PluginPagedComicListCubit>()
              .setReadActive,
          keepActiveWhileCovered: () =>
              AppliedFilterBar.confirmationIsCovering(context),
          child: _PluginPagedComicListBody(
            pluginId: pluginId,
            fnPath: fnPath,
            tabReselectEnabled: tabReselectEnabled,
            localResultTools: localResultTools,
            publicLoadedFacets: publicLoadedFacets,
            loadedSearchController: loadedSearchController,
            loadedSearchFocusNode: loadedSearchFocusNode,
            loadedSearchScope: loadedSearchScope,
            loadedSearchExpanded: loadedSearchExpanded,
            loadedChromeBuilder: loadedChromeBuilder,
            pageViewAction: pageViewAction,
            focusedFacets: focusedFacets,
            shrinkWrap: shrinkWrap,
            physics: physics,
            collectionTargetId: collectionTargetId,
            collectionTargetName: collectionTargetName,
            rankingLayout: rankingLayout,
            cloudFavorite: cloudFavorite,
            flatCollectionControls: flatCollectionControls,
            detailedView: detailedView,
            blockedCategories: blockedCategories,
          ),
        ),
      ),
    );
    return pluginId == JmListLikeCounts.source
        ? JmCoverLikeScope(counts: JmListLikeCounts.instance, child: list)
        : list;
  }
}

class _PluginPagedComicListBody extends StatefulWidget {
  const _PluginPagedComicListBody({
    required this.pluginId,
    required this.fnPath,
    required this.tabReselectEnabled,
    required this.localResultTools,
    required this.publicLoadedFacets,
    this.loadedSearchController,
    this.loadedSearchFocusNode,
    this.loadedSearchScope,
    this.loadedSearchExpanded = true,
    this.loadedChromeBuilder,
    this.pageViewAction,
    this.focusedFacets = false,
    required this.shrinkWrap,
    required this.physics,
    this.collectionTargetId,
    this.collectionTargetName,
    required this.rankingLayout,
    required this.cloudFavorite,
    required this.flatCollectionControls,
    required this.detailedView,
    required this.blockedCategories,
  });

  final bool shrinkWrap, tabReselectEnabled;
  final Widget? pageViewAction;
  final String pluginId, fnPath;
  final bool localResultTools, focusedFacets, publicLoadedFacets;
  final TextEditingController? loadedSearchController;
  final FocusNode? loadedSearchFocusNode;
  final KeywordSearchScope? loadedSearchScope;
  final bool loadedSearchExpanded;
  final Widget Function(BuildContext, SourceLoadedResultChrome)?
  loadedChromeBuilder;
  final ScrollPhysics? physics;
  final String? collectionTargetId;
  final String? collectionTargetName;
  final bool rankingLayout;
  final bool cloudFavorite, flatCollectionControls;
  final bool detailedView;
  final Set<String> blockedCategories;

  @override
  State<_PluginPagedComicListBody> createState() =>
      _PluginPagedComicListBodyState();
}

class _PluginPagedComicListBodyState extends State<_PluginPagedComicListBody>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  late final SourceListScrollPositions _scrollPositions;
  ScrollController get scrollController => _scrollPositions.controller;
  final _refreshIndicator = GlobalKey<RefreshIndicatorState>();
  final _resultItems = GlobalKey();
  final _visiblePage = ValueNotifier<int?>(null);
  List<int?> _visibleResultPages = const [];
  int _visibleNumberedRange = 1;
  bool _pageUpdateQueued = false;
  bool _jumpOpen = false;

  bool _collectionFillQueued = false;
  bool _collectionIndexRequested = false;
  bool _filteredPaging = false;
  static const _maxCollectionFillPages = 16;
  static const _collectionFillBudget = Duration(seconds: 22);
  int _collectionFillPages = 0;
  Stopwatch? _collectionFillElapsed;
  Duration get _collectionFillRemaining =>
      _collectionFillBudget -
      (_collectionFillElapsed?.elapsed ?? Duration.zero);
  bool get _collectionFillPaused =>
      _collectionFillPages >= _maxCollectionFillPages ||
      _collectionFillRemaining <= Duration.zero;
  bool _wasVisible = false;
  bool _visibilityCheckQueued = false;
  (String, int)? _collectionScope;

  bool get _isBikaFavorite =>
      widget.cloudFavorite && isBikaExperienceSource(widget.pluginId);
  bool get _supportsPageChrome => !widget.shrinkWrap && !widget.rankingLayout;

  Widget _sourcePageJump(PluginPagedComicListCubit cubit) => ListenableBuilder(
    listenable: Listenable.merge([_visiblePage, cubit.sourcePageCountChanges]),
    builder: (context, _) {
      if (cubit.state.status == PluginPagedComicListStatus.initial ||
          cubit.state.status == PluginPagedComicListStatus.failure) {
        return const SizedBox.shrink();
      }
      final count = cubit.sourcePageCount;
      final visible = _visiblePage.value;
      final page = visible != null && (count == null || visible <= count)
          ? visible
          : cubit.firstVerifiedSourcePage;
      if (page == null || count != null && page > count) {
        return const SizedBox.shrink();
      }
      if (count == null) {
        final theme = Theme.of(context);
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            t.searchResult.pageOnly(page: page),
            key: const ValueKey('plugin-list.page-progress'),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );
      }
      return Align(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: 1,
        child: SourcePageJumpButton(
          key: const ValueKey('plugin-list.page-progress'),
          maxLines: 2,
          label: t.searchResult.pageProgress(page: page, pages: count),
          onPressed: _jumpOpen
              ? null
              : () => unawaited(_jumpToSourcePage(cubit, page, count)),
        ),
      );
    },
  );

  Future<void> _jumpToSourcePage(
    PluginPagedComicListCubit cubit,
    int currentPage,
    int totalPages,
  ) async {
    if (_jumpOpen) return;
    final source = widget.pluginId;
    final generation = pluginSessionWriteFence.generation(source);
    final revision = cubit.privateDataRevision;
    bool current() =>
        mounted &&
        !cubit.isClosed &&
        identical(cubit, context.read<PluginPagedComicListCubit>()) &&
        !pluginSessionWriteFence.isChanging(source) &&
        generation == pluginSessionWriteFence.generation(source) &&
        revision == cubit.privateDataRevision;
    setState(() => _jumpOpen = true);
    try {
      final target = await showSourcePageJumpDialog(
        context,
        page: currentPage,
        totalPages: totalPages,
      );
      if (!mounted || target == null || !current()) return;
      final count = cubit.sourcePageCount;
      if (count == null) return;
      if (target < 1 || target > count) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.searchResult.pageOutOfRange(pages: count))),
        );
        return;
      }
      if (await cubit.jumpToSourcePage(target) && current()) {
        _visiblePage.value = null;
        _scrollPositions.reset(afterLayout: true);
      }
    } finally {
      if (mounted) setState(() => _jumpOpen = false);
    }
  }

  void _scheduleSourcePageUpdate() {
    if (!_supportsPageChrome || _pageUpdateQueued) return;
    _pageUpdateQueued = true;
    WidgetsBinding.instance.ensureVisualUpdate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageUpdateQueued = false;
      if (mounted) {
        _visiblePage.value = topVisibleSourcePage(
          _resultItems,
          _visibleResultPages,
        );
      }
    });
  }

  void _toggleBikaCategory(
    String category,
    Set<String> blocked,
    ValueChanged<Set<String>> change,
  ) {
    final next = {...blocked};
    if (!next.add(category)) next.remove(category);
    change(next);
  }

  List<String> _bikaFavoriteCategories(List<UnifiedComicListItem> entries) {
    if (!_isBikaFavorite) return const [];
    final categories = <String>{};
    for (final entry in entries) {
      for (final field in entry.metadata) {
        if (field.type != 'categories' && field.type != 'category') continue;
        for (final value in field.value) {
          final category = value.toString().trim();
          if (category.isNotEmpty) categories.add(category);
        }
      }
    }
    return categories.toList()..sort();
  }

  void _setCompleteIndexDemand(bool needed) {
    if (!mounted || !widget.cloudFavorite) return;
    if (needed && !_collectionIndexRequested) _restartCollectionFill();
    _collectionIndexRequested = needed;
    if (needed)
      _fillCollection(context.read<PluginPagedComicListCubit>().state);
  }

  void _restartCollectionFill() {
    _collectionFillPages = 0;
    _collectionFillElapsed = Stopwatch();
  }

  Future<void> _loadMore({bool retry = false}) {
    if (_collectionIndexRequested && _collectionFillPaused) {
      _restartCollectionFill();
    }
    final cubit = context.read<PluginPagedComicListCubit>();
    return retry ? cubit.retryLoadMore() : cubit.loadMore();
  }

  void _checkVisibleCollection() {
    if (!mounted) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final visible =
        ReadRecoveryScope.activeOf(context) &&
        TickerMode.of(context) &&
        (ModalRoute.of(context)?.isCurrent != false ||
            AppliedFilterBar.confirmationIsCovering(context)) &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
    final becameVisible = visible && !_wasVisible;
    _wasVisible = visible;
    if (!becameVisible || _visibilityCheckQueued) return;
    if (_collectionIndexRequested && _collectionFillPaused) {
      _restartCollectionFill();
    }
    _visibilityCheckQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityCheckQueued = false;
      if (!mounted || !_wasVisible) return;
      unawaited(
        context.read<PluginPagedComicListCubit>().checkForUpdates(
          automatic: true,
        ),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkVisibleCollection();
  }

  void _fillCollection(PluginPagedComicListState state) {
    if (!_collectionIndexRequested ||
        !widget.cloudFavorite ||
        !widget.localResultTools ||
        _collectionFillQueued ||
        _collectionFillPaused ||
        state.hasReachedMax ||
        state.status != PluginPagedComicListStatus.success)
      return;
    if (!ReadRecoveryScope.activeOf(context) || !TickerMode.of(context)) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    _collectionFillQueued = true;
    final scope = _collectionScope;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cubit = mounted ? context.read<PluginPagedComicListCubit>() : null;
      if (cubit?.refreshing ?? false) await cubit!.waitForRefresh();
      _collectionFillQueued = false;
      if (!mounted || cubit == null || cubit.isClosed) return;
      if (scope != _collectionScope) {
        _fillCollection(cubit.state);
        return;
      }
      if (!_collectionIndexRequested ||
          _collectionFillPaused ||
          !ReadRecoveryScope.activeOf(context) ||
          !TickerMode.of(context) ||
          ModalRoute.of(context)?.isCurrent == false ||
          cubit.state.status != PluginPagedComicListStatus.success ||
          cubit.state.hasReachedMax) {
        return;
      }
      // Search and filters use the confirmed rows while this window fills.
      _collectionFillElapsed?.start();
      _collectionFillPages++;
      await cubit.loadMore(readBudget: _collectionFillRemaining);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _wasVisible = false;
    if (state == AppLifecycleState.resumed && mounted) {
      _checkVisibleCollection();
      _fillCollection(context.read<PluginPagedComicListCubit>().state);
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollPositions = SourceListScrollPositions(detailed: widget.detailedView)
      ..addListener(_onScroll);
  }

  @override
  void didUpdateWidget(_PluginPagedComicListBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scrollPositions.select(widget.detailedView);
    if (!setEquals(oldWidget.blockedCategories, widget.blockedCategories) ||
        oldWidget.rankingLayout != widget.rankingLayout) {
      _scrollPositions.reset(afterLayout: true);
    }
    if (widget.loadedSearchController != null &&
        oldWidget.loadedSearchExpanded != widget.loadedSearchExpanded) {
      if (widget.loadedSearchExpanded) {
        _scrollPositions.beginSearch();
      } else {
        _scrollPositions.endSearch();
      }
    }
  }

  @override
  void dispose() {
    _visiblePage.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _scrollPositions.removeListener(_onScroll);
    _scrollPositions.dispose();
    super.dispose();
  }

  Future<PullRefreshResult> _refreshFromPull(
    PluginPagedComicListCubit cubit,
  ) async {
    final previous = cubit.state;
    final revision = cubit.privateDataRevision;
    final applied = await cubit.refresh();
    // The cubit already exposes failures through the list's retry states.
    if (!applied ||
        !mounted ||
        cubit.isClosed ||
        revision != cubit.privateDataRevision) {
      return PullRefreshResult.ignored;
    }
    final current = cubit.state;
    if (previous.status == PluginPagedComicListStatus.initial ||
        previous.status == PluginPagedComicListStatus.failure) {
      return PullRefreshResult.updated;
    }
    if (previous.page > 1 && current.page == 1 && !current.hasReachedMax) {
      // A first-page read cannot compare the previously loaded tail.
      return PullRefreshResult.checked;
    }
    if (!listEquals(previous.list, current.list) ||
        previous.hasReachedMax != current.hasReachedMax ||
        previous.knownTotal != current.knownTotal) {
      return PullRefreshResult.updated;
    }
    // Collection snapshots can reuse other pages after checking the head and
    // one rotating page. Only a complete range can establish no change.
    return !current.hasReachedMax || widget.cloudFavorite && current.page > 2
        ? PullRefreshResult.checked
        : PullRefreshResult.unchanged;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cubit = context.read<PluginPagedComicListCubit>();
    final revision = context.select(
      (PluginPagedComicListCubit owner) => owner.privateDataRevision,
    );
    final content = PullRefreshFeedback.indicator(
      indicatorKey: _refreshIndicator,
      active: ReadRecoveryScope.activeOf(context),
      scope: (cubit, revision),
      onRefresh: () => _refreshFromPull(cubit),
      child: BlocConsumer<PluginPagedComicListCubit, PluginPagedComicListState>(
        listenWhen: (_, state) =>
            state.status == PluginPagedComicListStatus.initial ||
            _supportsPageChrome &&
                cubit.numberedRangeStart != _visibleNumberedRange,
        listener: (_, state) {
          _visibleNumberedRange = cubit.numberedRangeStart;
          _visiblePage.value = null;
          _scrollPositions.reset(
            afterLayout: state.status != PluginPagedComicListStatus.initial,
          );
        },
        builder: (context, state) {
          final cubit = context.read<PluginPagedComicListCubit>();
          final account = widget.cloudFavorite
              ? JmCollectionSnapshots.instance.accountScope(widget.pluginId)
              : null;
          final preferenceScope = widget.publicLoadedFacets
              ? '${widget.pluginId}|publicBrowse|${widget.fnPath}'
              : '${widget.pluginId}|cloudFavorite|${account ?? 'session'}|'
                    '${widget.collectionTargetId ?? ''}';
          final scope = (preferenceScope, cubit.privateDataRevision);
          if (_collectionScope != scope) {
            _collectionScope = scope;
            _collectionIndexRequested = false;
            _restartCollectionFill();
          }
          final lifecycle = WidgetsBinding.instance.lifecycleState;
          cubit.setMetadataActive(
            ReadRecoveryScope.activeOf(context) &&
                TickerMode.of(context) &&
                ModalRoute.of(context)?.isCurrent != false &&
                (lifecycle == null || lifecycle == AppLifecycleState.resumed),
          );
          _checkVisibleCollection();
          _fillCollection(state);
          Widget content(
            BuildContext scopeContext, [
            List<UnifiedComicListItem>? visible,
          ]) {
            _filteredPaging = false;
            switch (state.status) {
              case PluginPagedComicListStatus.initial:
                return _statusView(
                  const Center(child: CircularProgressIndicator()),
                );
              case PluginPagedComicListStatus.failure:
                return _statusView(
                  ErrorView(
                    errorMessage: userFacingErrorMessage(state.result),
                    onRetry: () =>
                        context.read<PluginPagedComicListCubit>().loadInitial(),
                  ),
                );
              case PluginPagedComicListStatus.loadingMore:
              case PluginPagedComicListStatus.loadingMoreFailure:
              case PluginPagedComicListStatus.success:
                final demand = SourceLoadedResultFilter.demandOf(scopeContext);
                if (widget.publicLoadedFacets &&
                    !widget.shrinkWrap &&
                    demand?.filtering == true &&
                    visible != null) {
                  _filteredPaging = true;
                  return FilteredResultPages(
                    key: ValueKey((
                      scope,
                      demand!.criteria,
                      cubit.numberedRangeStart,
                    )),
                    matches: visible,
                    controller: scrollController,
                    page: state.page,
                    firstPage: cubit.numberedRangeStart,
                    ready:
                        state.status == PluginPagedComicListStatus.success &&
                        !cubit.refreshing,
                    complete: state.hasReachedMax,
                    failed:
                        state.status ==
                        PluginPagedComicListStatus.loadingMoreFailure,
                    paused:
                        demand.editing ||
                        !ReadRecoveryScope.activeOf(scopeContext),
                    batchSize: widget.detailedView ? 5 : 9,
                    loadMore: () {
                      if (cubit.refreshing ||
                          cubit.state.status !=
                              PluginPagedComicListStatus.success) {
                        return false;
                      }
                      unawaited(_loadMore());
                      return cubit.state.status ==
                          PluginPagedComicListStatus.loadingMore;
                    },
                    builder: (shown, progress) => _buildContent(
                      scopeContext,
                      state,
                      filteredEntries: shown,
                      progress: progress,
                    ),
                  );
                }
                return _buildContent(
                  scopeContext,
                  state,
                  filteredEntries: visible,
                );
            }
          }

          final usesLoadedTools =
              widget.publicLoadedFacets ||
              (widget.cloudFavorite && widget.localResultTools);
          final usesEmbeddedPages =
              usesLoadedTools && widget.loadedChromeBuilder != null;
          Widget loaded(
            Set<String> blocked, [
            ValueChanged<Set<String>>? change,
          ]) => ListenableBuilder(
            listenable: cubit.sourcePageCountChanges,
            builder: (_, _) => SourceLoadedResultFilter(
              compactControls: true,
              flatCollectionControls:
                  widget.cloudFavorite || widget.flatCollectionControls,
              searchController: widget.loadedSearchController,
              searchFocusNode: widget.loadedSearchFocusNode,
              searchScope: widget.loadedSearchScope,
              searchExpanded: widget.loadedSearchExpanded,
              chromeBuilder: widget.loadedChromeBuilder,
              pageNavigation:
                  _supportsPageChrome && cubit.hasVerifiedSourcePages
                  ? _sourcePageJump(cubit)
                  : null,
              focusedFacets: widget.focusedFacets,
              publicBrowseFacets: widget.publicLoadedFacets,
              filterScopeLabel: widget.publicLoadedFacets ? '' : null,
              requireCompleteFacets: false,
              key: ValueKey(scope),
              entries: state.list,
              blockedCategories: {...widget.blockedCategories, ...blocked},
              scope: preferenceScope,
              complete: state.hasReachedMax && cubit.numberedRangeStart == 1,
              knownTotal: widget.focusedFacets ? state.knownTotal : null,
              loadingMore:
                  state.status == PluginPagedComicListStatus.loadingMore,
              onChanged: () => _scrollPositions.reset(afterLayout: true),
              onCompleteIndexDemandChanged: widget.cloudFavorite
                  ? _setCompleteIndexDemand
                  : null,
              onLoadMore:
                  state.hasReachedMax ||
                      state.status == PluginPagedComicListStatus.initial ||
                      state.status == PluginPagedComicListStatus.failure ||
                      (widget.publicLoadedFacets &&
                          state.status ==
                              PluginPagedComicListStatus.loadingMoreFailure)
                  ? null
                  : state.status ==
                        PluginPagedComicListStatus.loadingMoreFailure
                  ? () => _loadMore(retry: true)
                  : _loadMore,
              builder: (context, visible, controls) => Column(
                mainAxisSize: widget.shrinkWrap
                    ? MainAxisSize.min
                    : MainAxisSize.max,
                children: [
                  if (change != null)
                    SourceListFilterBar(
                      categories: _bikaFavoriteCategories(state.list),
                      blockedCategories: blocked,
                      onCategoryTap: (category) =>
                          _toggleBikaCategory(category, blocked, change),
                      onClearBlockedCategories: () => change({}),
                      sortValue: '',
                      sortOptions: const {},
                      onSortChanged: (_) {},
                      detailedView: widget.detailedView,
                      onViewChanged: (_) {},
                      categoriesOnly: true,
                    ),
                  controls,
                  if (widget.shrinkWrap)
                    content(context, visible)
                  else
                    Expanded(child: content(context, visible)),
                ],
              ),
            ),
          );

          final body = !usesLoadedTools
              ? content(context)
              : _isBikaFavorite
              ? SourceCategoryBlockScope(
                  key: ValueKey(scope),
                  scope: '$preferenceScope|categoryBlock',
                  persistent: account != null,
                  builder: (_, blocked, change) => loaded(blocked, change),
                )
              : loaded(const {});
          final list = Column(
            mainAxisSize: widget.shrinkWrap
                ? MainAxisSize.min
                : MainAxisSize.max,
            children: [
              if (widget.pageViewAction != null)
                CollectionResultsRow(
                  countLabel: '',
                  scope: _supportsPageChrome ? _sourcePageJump(cubit) : null,
                  viewAction: widget.pageViewAction,
                )
              else if (_supportsPageChrome && !usesEmbeddedPages)
                Padding(
                  padding: CollectionToolbarMetrics.contentPaddingOf(context),
                  child: _sourcePageJump(cubit),
                ),
              if (cubit.refreshError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          userFacingErrorMessage(cubit.refreshError!),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        key: const ValueKey('plugin-list.refresh-retry'),
                        onPressed: cubit.refreshing
                            ? null
                            : () {
                                final target = cubit.failedPageJump;
                                if (target == null) {
                                  _refreshIndicator.currentState?.show();
                                } else {
                                  unawaited(
                                    _retrySourcePageJump(cubit, target),
                                  );
                                }
                              },
                        icon: const Icon(Icons.refresh),
                        label: Text(t.common.retry),
                      ),
                    ],
                  ),
                ),
              if (widget.shrinkWrap)
                body
              else
                Expanded(
                  key: const ValueKey('plugin-list.content'),
                  child: body,
                ),
            ],
          );
          return BikaConnectionNotice.wrap(
            source: widget.pluginId,
            scope: scope,
            failure: state.status == PluginPagedComicListStatus.failure
                ? state.result
                : null,
            ready: state.status == PluginPagedComicListStatus.success,
            retry: () => unawaited(cubit.refresh()),
            child: list,
          );
        },
      ),
    );
    return TabReselectListener(
      enabled: widget.tabReselectEnabled && ReadRecoveryScope.activeOf(context),
      onReselect: () {
        if (!_scrollPositions.isChanging) {
          TabReselectScope.scrollToStart(context, scrollController);
        }
      },
      child: content,
    );
  }

  Future<void> _retrySourcePageJump(
    PluginPagedComicListCubit cubit,
    int target,
  ) async {
    if (await cubit.jumpToSourcePage(target) && mounted) {
      _visiblePage.value = null;
      _scrollPositions.reset(afterLayout: true);
    }
  }

  Widget _statusView(Widget child) => CustomScrollView(
    physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
    shrinkWrap: widget.shrinkWrap,
    slivers: [
      if (widget.shrinkWrap)
        SliverToBoxAdapter(
          child: Padding(padding: const EdgeInsets.all(24), child: child),
        )
      else
        SliverFillRemaining(hasScrollBody: false, child: child),
    ],
  );

  Widget _buildContent(
    BuildContext context,
    PluginPagedComicListState state, {
    List<UnifiedComicListItem>? filteredEntries,
    FilteredPageProgress? progress,
  }) {
    if (progress == null &&
        state.list.isEmpty &&
        state.hasReachedMax &&
        state.status == PluginPagedComicListStatus.success) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                t.comicList.nothingHere,
                style: const TextStyle(fontSize: 20.0),
              ),
            ),
          ),
        ],
      );
    }

    if (widget.rankingLayout) {
      return BikaRankingList(
        entries: state.list,
        controller: scrollController,
        hasReachedMax: state.hasReachedMax,
        isLoadingMore: state.status == PluginPagedComicListStatus.loadingMore,
        loadMoreFailed:
            state.status == PluginPagedComicListStatus.loadingMoreFailure,
        onRetryLoadMore: () => _loadMore(retry: true),
        onLoadMore: _loadMore,
      );
    }

    final visibleEntries =
        filteredEntries ??
        (widget.blockedCategories.isEmpty
            ? state.list
            : state.list
                  .where(
                    (entry) => !isEntryBlockedByCategory(
                      entry,
                      widget.blockedCategories,
                    ),
                  )
                  .toList());

    if (_supportsPageChrome) {
      final cubit = context.read<PluginPagedComicListCubit>();
      _visibleResultPages = visibleEntries.map(cubit.reportedPageOf).toList();
      _scheduleSourcePageUpdate();
    }

    final automatic = progress != null;

    if ((widget.cloudFavorite || widget.publicLoadedFacets) &&
        visibleEntries.isEmpty) {
      return CustomScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      progress?.emptyMessage ??
                          (automatic
                              ? userFacingErrorMessage(state.result)
                              : widget.publicLoadedFacets
                              ? t.videoLibrary.noLoadedMatches
                              : t.videoLibrary.localCatalogNoMatches),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (!automatic &&
                      !widget.focusedFacets &&
                      state.status == PluginPagedComicListStatus.loadingMore)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    )
                  else if (automatic &&
                      state.status ==
                          PluginPagedComicListStatus.loadingMoreFailure)
                    TextButton(
                      onPressed: () => _loadMore(retry: true),
                      child: Text(t.oldHome.loadMoreFailed),
                    )
                  else if (!automatic &&
                      !state.hasReachedMax &&
                      (!widget.focusedFacets ||
                          _collectionFillPaused ||
                          state.status ==
                              PluginPagedComicListStatus.loadingMoreFailure))
                    TextButton(
                      onPressed: () {
                        if (state.status ==
                            PluginPagedComicListStatus.loadingMoreFailure) {
                          _loadMore(retry: true);
                        } else {
                          _loadMore();
                        }
                      },
                      child: Text(t.oldHome.loadMore),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final selection = JmCloudSelection.maybeOf(context);
    if (widget.detailedView) {
      return SourceSearchDetailList(
        collectionLayout: widget.cloudFavorite,
        quietPaging: automatic || widget.focusedFacets,
        pageBreaks: widget.cloudFavorite && !_isBikaFavorite
            ? const {}
            : sourcePageBreaks(
                visibleEntries,
                context.read<PluginPagedComicListCubit>().reportedPageOf,
              ),
        entries: visibleEntries,
        entryBuilder: selection == null
            ? null
            : (entry, tile) => selection.row(entry.id, entry.title, tile),
        controller: scrollController,
        itemsSliverKey: _supportsPageChrome ? _resultItems : null,
        physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
        shrinkWrap: widget.shrinkWrap,
        hasReachedMax: state.hasReachedMax,
        isLoadingMore: state.status == PluginPagedComicListStatus.loadingMore,
        loadMoreFailed:
            state.status == PluginPagedComicListStatus.loadingMoreFailure,
        onRetryLoadMore: () => _loadMore(retry: true),
        onLoadMore: _loadMore,
        onReturned: widget.cloudFavorite
            ? () {
                if (context.mounted) {
                  unawaited(
                    context.read<PluginPagedComicListCubit>().checkForUpdates(
                      automatic: true,
                    ),
                  );
                  _fillCollection(
                    context.read<PluginPagedComicListCubit>().state,
                  );
                }
              }
            : null,
      );
    }

    final list = mapToUnifiedComicSimplifyEntryInfoList(visibleEntries);

    return PluginComicGridSliver(
      collectionLayout: widget.cloudFavorite,
      quietPaging: automatic || widget.focusedFacets,
      controller: scrollController,
      itemsSliverKey: _supportsPageChrome ? _resultItems : null,
      entries: list,
      hasReachedMax: state.hasReachedMax,
      isLoadingMore: state.status == PluginPagedComicListStatus.loadingMore,
      loadMoreFailed:
          state.status == PluginPagedComicListStatus.loadingMoreFailure,
      onRetryLoadMore: () => _loadMore(retry: true),
      onLoadMore: _loadMore,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
      collectionTargetId: widget.collectionTargetId,
      collectionTargetName: widget.collectionTargetName,
      selectionMode: selection != null,
      isEntrySelected: selection == null
          ? null
          : (entry) => selection.ids.contains(entry.id),
      onEntryLongPress: selection == null
          ? null
          : (entry, _) => selection.toggle(entry.id),
      onEntrySecondaryTapDown: selection == null
          ? null
          : (entry, _) => selection.toggle(entry.id),
      onEntryTap: selection != null
          ? (entry) => selection.toggle(entry.id)
          : widget.cloudFavorite
          ? (info) async {
              await context.pushRoute(
                ComicInfoRoute(
                  comicId: info.id,
                  type: ComicEntryType.normal,
                  from: info.source.trim().isEmpty ? info.from : info.source,
                ),
              );
              if (context.mounted) {
                unawaited(
                  context.read<PluginPagedComicListCubit>().checkForUpdates(
                    automatic: true,
                  ),
                );
                _fillCollection(
                  context.read<PluginPagedComicListCubit>().state,
                );
              }
            }
          : null,
    );
  }

  void _onScroll() {
    _scheduleSourcePageUpdate();
    if (_scrollPositions.isChanging ||
        !mounted ||
        _collectionIndexRequested && _collectionFillPaused) {
      return;
    }
    if (!_filteredPaging && _isBottom) {
      context.read<PluginPagedComicListCubit>().loadMore();
    }
  }

  bool get _isBottom {
    if (!scrollController.hasClients) return false;
    final maxScroll = scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return false;
    final currentScroll = scrollController.offset;
    return currentScroll >= (maxScroll * 0.9);
  }
}
