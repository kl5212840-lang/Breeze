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
import 'package:zephyr/page/comic_list/cubit/plugin_paged_comic_list_cubit.dart';
import 'package:zephyr/page/comic_list/cubit/plugin_paged_comic_list_state.dart';
import 'package:zephyr/page/comic_list/view/plugin_comic_grid_sliver.dart';
import 'package:zephyr/page/comic_list/view/bika_ranking_list.dart';
import 'package:zephyr/page/search_result/view/source_search_detail_list.dart';
import 'package:zephyr/page/search_result/view/source_list_categories.dart';
import 'package:zephyr/page/search_result/view/source_list_filter_bar.dart';
import 'package:zephyr/page/search_result/view/source_loaded_result_filter.dart';
import 'package:zephyr/page/source_shell/source_list_block_preferences.dart';
import 'package:zephyr/page/source_shell/source_experience_preferences.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/util/text/chinese_convert.dart';
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
    this.detailedView = false,
    this.blockedCategories = const {},
    this.requestPage,
    this.localResultTools = true,
    this.publicLoadedFacets = false,
    this.loadedSearchController,
    this.loadedSearchFocusNode,
    this.loadedSearchExpanded = true,
    this.loadedChromeBuilder,
    this.focusedFacets = false,
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
  final bool cloudFavorite;
  final bool detailedView;
  final Set<String> blockedCategories;
  final PluginPageRequest? requestPage;
  final bool localResultTools, focusedFacets, publicLoadedFacets;
  final TextEditingController? loadedSearchController;
  final FocusNode? loadedSearchFocusNode;
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
        privateCollection: cloudFavorite,
        jmSnapshotCache: cloudFavorite,
      )..loadInitial(),
      child: Builder(
        builder: (context) => ReadRecoveryHost(
          onActiveChanged: context
              .read<PluginPagedComicListCubit>()
              .setReadActive,
          child: _PluginPagedComicListBody(
            pluginId: pluginId,
            fnPath: fnPath,
            localResultTools: localResultTools,
            publicLoadedFacets: publicLoadedFacets,
            loadedSearchController: loadedSearchController,
            loadedSearchFocusNode: loadedSearchFocusNode,
            loadedSearchExpanded: loadedSearchExpanded,
            loadedChromeBuilder: loadedChromeBuilder,
            focusedFacets: focusedFacets,
            shrinkWrap: shrinkWrap,
            physics: physics,
            collectionTargetId: collectionTargetId,
            collectionTargetName: collectionTargetName,
            rankingLayout: rankingLayout,
            cloudFavorite: cloudFavorite,
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
    required this.localResultTools,
    required this.publicLoadedFacets,
    this.loadedSearchController,
    this.loadedSearchFocusNode,
    this.loadedSearchExpanded = true,
    this.loadedChromeBuilder,
    this.focusedFacets = false,
    required this.shrinkWrap,
    required this.physics,
    this.collectionTargetId,
    this.collectionTargetName,
    required this.rankingLayout,
    required this.cloudFavorite,
    required this.detailedView,
    required this.blockedCategories,
  });

  final bool shrinkWrap;
  final String pluginId, fnPath;
  final bool localResultTools, focusedFacets, publicLoadedFacets;
  final TextEditingController? loadedSearchController;
  final FocusNode? loadedSearchFocusNode;
  final bool loadedSearchExpanded;
  final Widget Function(BuildContext, SourceLoadedResultChrome)?
  loadedChromeBuilder;
  final ScrollPhysics? physics;
  final String? collectionTargetId;
  final String? collectionTargetName;
  final bool rankingLayout;
  final bool cloudFavorite;
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

  bool _collectionFillQueued = false;
  bool _collectionIndexRequested = false;
  bool _wasVisible = false;
  bool _visibilityCheckQueued = false;
  (String, int)? _collectionScope;

  bool get _isBikaFavorite =>
      widget.cloudFavorite && isBikaExperienceSource(widget.pluginId);

  void _toggleBikaCategory(
    String category,
    Set<String> blocked,
    ValueChanged<Set<String>> change,
  ) {
    final next = {...blocked};
    final isBlocking = next.add(category);
    if (!isBlocking) next.remove(category);
    change(next);
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          isBlocking
              ? '已屏蔽「${convertChineseForDisplay(category)}」· 再点恢复'
              : '已恢复「${convertChineseForDisplay(category)}」',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
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
    _collectionIndexRequested = needed;
    if (needed)
      _fillCollection(context.read<PluginPagedComicListCubit>().state);
  }

  void _checkVisibleCollection() {
    if (!mounted) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final visible =
        ReadRecoveryScope.activeOf(context) &&
        TickerMode.of(context) &&
        ModalRoute.of(context)?.isCurrent != false &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
    final becameVisible = visible && !_wasVisible;
    _wasVisible = visible;
    if (!becameVisible || _visibilityCheckQueued) return;
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
        state.hasReachedMax ||
        state.status != PluginPagedComicListStatus.success)
      return;
    if (!ReadRecoveryScope.activeOf(context) || !TickerMode.of(context)) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    _collectionFillQueued = true;
    final scope = _collectionScope;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _collectionFillQueued = false;
      if (!mounted) return;
      if (scope != _collectionScope) {
        _fillCollection(context.read<PluginPagedComicListCubit>().state);
        return;
      }
      if (!_collectionIndexRequested ||
          !ReadRecoveryScope.activeOf(context) ||
          !TickerMode.of(context) ||
          ModalRoute.of(context)?.isCurrent == false)
        return;
      // Full local search/facets need an index. Only explicit filtering (or
      // restored active filters) opts in; normal browsing remains paginated.
      unawaited(context.read<PluginPagedComicListCubit>().loadMore());
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
  }

  @override
  void dispose() {
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
    return PullRefreshFeedback.indicator(
      indicatorKey: _refreshIndicator,
      active: ReadRecoveryScope.activeOf(context),
      scope: (cubit, revision),
      onRefresh: () => _refreshFromPull(cubit),
      child: BlocConsumer<PluginPagedComicListCubit, PluginPagedComicListState>(
        listenWhen: (_, state) =>
            state.status == PluginPagedComicListStatus.initial,
        listener: (_, _) => _scrollPositions.reset(),
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
          Widget content([List<UnifiedComicListItem>? visible]) {
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
                return _buildContent(context, state, filteredEntries: visible);
            }
          }

          Widget loaded(
            Set<String> blocked, [
            ValueChanged<Set<String>>? change,
          ]) => SourceLoadedResultFilter(
            compactControls: true,
            searchController: widget.loadedSearchController,
            searchFocusNode: widget.loadedSearchFocusNode,
            searchExpanded: widget.loadedSearchExpanded,
            chromeBuilder: widget.loadedChromeBuilder,
            focusedFacets: widget.focusedFacets,
            publicBrowseFacets: widget.publicLoadedFacets,
            filterScopeLabel: widget.publicLoadedFacets
                ? t.sourceShell.collectionLoadedCount(count: state.list.length)
                : null,
            requireCompleteFacets: false,
            key: ValueKey(scope),
            entries: state.list,
            blockedCategories: {...widget.blockedCategories, ...blocked},
            scope: preferenceScope,
            complete: state.hasReachedMax,
            knownTotal: widget.focusedFacets ? state.knownTotal : null,
            loadingMore: state.status == PluginPagedComicListStatus.loadingMore,
            onChanged: () => _scrollPositions.reset(afterLayout: true),
            onCompleteIndexDemandChanged: widget.cloudFavorite
                ? _setCompleteIndexDemand
                : null,
            onLoadMore:
                state.status == PluginPagedComicListStatus.initial ||
                    state.status == PluginPagedComicListStatus.failure
                ? null
                : state.status == PluginPagedComicListStatus.loadingMoreFailure
                ? cubit.retryLoadMore
                : cubit.loadMore,
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
                  content(visible)
                else
                  Expanded(child: content(visible)),
              ],
            ),
          );

          final body =
              !widget.publicLoadedFacets &&
                  (!widget.cloudFavorite || !widget.localResultTools)
              ? content()
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
                            : () => _refreshIndicator.currentState?.show(),
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
  }) {
    if (state.list.isEmpty &&
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
        onRetryLoadMore: () =>
            context.read<PluginPagedComicListCubit>().retryLoadMore(),
        onLoadMore: () => context.read<PluginPagedComicListCubit>().loadMore(),
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
                  Text(
                    widget.publicLoadedFacets
                        ? t.videoLibrary.noLoadedMatches
                        : t.videoLibrary.localCatalogNoMatches,
                  ),
                  if (!widget.focusedFacets &&
                      state.status == PluginPagedComicListStatus.loadingMore)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    )
                  else if (!state.hasReachedMax &&
                      (!widget.focusedFacets ||
                          state.status ==
                              PluginPagedComicListStatus.loadingMoreFailure))
                    TextButton(
                      onPressed: () {
                        final cubit = context.read<PluginPagedComicListCubit>();
                        if (state.status ==
                            PluginPagedComicListStatus.loadingMoreFailure) {
                          cubit.retryLoadMore();
                        } else {
                          cubit.loadMore();
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

    if (widget.detailedView) {
      return SourceSearchDetailList(
        collectionLayout: widget.cloudFavorite,
        quietPaging: widget.focusedFacets,
        entries: visibleEntries,
        controller: scrollController,
        physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
        shrinkWrap: widget.shrinkWrap,
        hasReachedMax: state.hasReachedMax,
        isLoadingMore: state.status == PluginPagedComicListStatus.loadingMore,
        loadMoreFailed:
            state.status == PluginPagedComicListStatus.loadingMoreFailure,
        onRetryLoadMore: () =>
            context.read<PluginPagedComicListCubit>().retryLoadMore(),
        onLoadMore: () => context.read<PluginPagedComicListCubit>().loadMore(),
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
      quietPaging: widget.focusedFacets,
      controller: scrollController,
      entries: list,
      hasReachedMax: state.hasReachedMax,
      isLoadingMore: state.status == PluginPagedComicListStatus.loadingMore,
      loadMoreFailed:
          state.status == PluginPagedComicListStatus.loadingMoreFailure,
      onRetryLoadMore: () =>
          context.read<PluginPagedComicListCubit>().retryLoadMore(),
      onLoadMore: () => context.read<PluginPagedComicListCubit>().loadMore(),
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
      collectionTargetId: widget.collectionTargetId,
      collectionTargetName: widget.collectionTargetName,
      onEntryTap: widget.cloudFavorite
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
    if (_scrollPositions.isChanging || !mounted) return;
    if (_isBottom) {
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
