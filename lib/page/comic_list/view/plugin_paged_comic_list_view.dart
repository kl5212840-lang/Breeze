import 'package:auto_route/auto_route.dart';
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
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry_mapper.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/error_view.dart';

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

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PluginPagedComicListCubit(
        pluginId: pluginId,
        fnPath: fnPath,
        coreBuilder: coreBuilder,
        externBuilder: externBuilder,
        requestPage: requestPage,
      )..loadInitial(),
      child: _PluginPagedComicListBody(
        shrinkWrap: shrinkWrap,
        physics: physics,
        collectionTargetId: collectionTargetId,
        collectionTargetName: collectionTargetName,
        rankingLayout: rankingLayout,
        cloudFavorite: cloudFavorite,
        detailedView: detailedView,
        blockedCategories: blockedCategories,
      ),
    );
  }
}

class _PluginPagedComicListBody extends StatefulWidget {
  const _PluginPagedComicListBody({
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
    with AutomaticKeepAliveClientMixin {
  late final SourceListScrollPositions _scrollPositions;
  ScrollController get scrollController => _scrollPositions.controller;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
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
    _scrollPositions.removeListener(_onScroll);
    _scrollPositions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: () => context.read<PluginPagedComicListCubit>().loadInitial(),
      child: BlocConsumer<PluginPagedComicListCubit, PluginPagedComicListState>(
        listenWhen: (_, state) =>
            state.status == PluginPagedComicListStatus.initial,
        listener: (_, _) => _scrollPositions.reset(),
        builder: (context, state) {
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
              return _buildContent(context, state);
          }
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

  Widget _buildContent(BuildContext context, PluginPagedComicListState state) {
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

    final visibleEntries = widget.blockedCategories.isEmpty
        ? state.list
        : state.list
              .where(
                (entry) =>
                    !isEntryBlockedByCategory(entry, widget.blockedCategories),
              )
              .toList();

    if (widget.cloudFavorite && visibleEntries.isEmpty) {
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
                  const Text('当前筛选没有匹配的漫画'),
                  if (state.status == PluginPagedComicListStatus.loadingMore)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    )
                  else if (!state.hasReachedMax)
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
                  context.read<PluginPagedComicListCubit>().loadInitial();
                }
              }
            : null,
      );
    }

    final list = mapToUnifiedComicSimplifyEntryInfoList(visibleEntries);

    return PluginComicGridSliver(
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
                context.read<PluginPagedComicListCubit>().loadInitial();
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
