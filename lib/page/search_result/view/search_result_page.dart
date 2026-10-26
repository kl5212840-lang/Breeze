import 'package:zephyr/page/source_shell/source_list_presentation.dart';
import 'package:zephyr/page/source_shell/source_list_scroll_positions.dart';
import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart' hide Thumb;
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/cubit/string_select.dart';
import 'package:zephyr/page/comic_list/view/plugin_comic_grid_sliver.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search_result/search_result.dart';
import 'package:zephyr/page/search_result/view/source_quick_category_bar.dart';
import 'package:zephyr/page/search_result/view/source_search_detail_list.dart';
import 'package:zephyr/page/search_result/view/source_list_categories.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry_mapper.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';

SearchEvent searchRetryEvent(
  SearchEvent lastSuccessful,
  SearchState current,
  SearchStatus targetStatus,
) {
  final source =
      targetStatus == SearchStatus.loadingMore &&
          current.status == SearchStatus.getMoreFailure
      ? current.searchEvent
      : lastSuccessful;
  return source.copyWith(status: targetStatus);
}

@RoutePage()
class SearchResultPage extends StatelessWidget implements AutoRouteWrapper {
  final SearchEvent searchEvent;
  final SearchCubit? searchCubit;

  const SearchResultPage({
    super.key,
    required this.searchEvent,
    this.searchCubit,
  });

  @override
  Widget wrappedRoute(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        searchCubit != null
            ? BlocProvider.value(value: searchCubit!)
            : BlocProvider(
                create: (_) => SearchCubit(searchEvent.searchStates),
              ),
        BlocProvider(create: (_) => SearchBloc()..add(searchEvent)),
        BlocProvider(create: (_) => StringSelectCubit()),
      ],
      child: this,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SearchResultPage(searchEvent: searchEvent);
  }
}

class _SearchResultPage extends StatefulWidget {
  final SearchEvent searchEvent;

  const _SearchResultPage({required this.searchEvent});

  @override
  State<_SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends State<_SearchResultPage>
    with SingleTickerProviderStateMixin {
  late SearchEvent searchEvent;
  final _scrollPositions = SourceListScrollPositions(detailed: true);
  ScrollController get _scrollController => _scrollPositions.controller;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300), // 动画持续时间
    );
    _slideAnimation =
        Tween<Offset>(
          begin: const Offset(0, 0), // 初始位置
          end: const Offset(0, 2),
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut, // 动画曲线
          ),
        );

    searchEvent = widget.searchEvent;
    _scrollPositions.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final keyword = widget.searchEvent.searchStates.searchKeyword.trim();
      if (keyword.isEmpty) return;
      final historyItem = _buildHistoryItem(widget.searchEvent);
      final settingCubit = context.read<GlobalSettingCubit>();
      final history = settingCubit.state.searchHistory.toList();
      history
        ..remove(historyItem)
        ..insert(0, historyItem);
      await Future.delayed(const Duration(milliseconds: 200));
      settingCubit.updateState(
        (current) =>
            current.copyWith(searchHistory: history.take(300).toList()),
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollPositions.removeListener(_onScroll);
    _scrollPositions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final source = context.read<SearchCubit>().state.from;
    final quickCategories = sourceQuickCategories(source);
    final resultState = context.watch<SearchBloc>().state;
    final pageLabel = _pageLabel(resultState);
    return BlocListener<SearchCubit, SearchStates>(
      listener: (_, _) => _scrollPositions.reset(),
      child: SourceListPresentation(
        source: source,
        detailedByDefault: true,
        builder: (context, detailedView, onViewChanged) {
          _scrollPositions.select(detailedView);
          return Scaffold(
            appBar: SearchResultBar(searchEvent: searchEvent),
            body: Column(
              children: [
                SourceQuickCategoryBar(
                  categories: quickCategories,
                  detailedView: detailedView,
                  pageLabel: pageLabel,
                  onPageTap: _jumpToPage,
                  onViewChanged: onViewChanged,
                ),
                Expanded(child: _bloc(detailedView)),
              ],
            ),
            floatingActionButtonLocation:
                context.watch<GlobalSettingCubit>().state.leftHandModeEnabled
                ? FloatingActionButtonLocation.startFloat
                : FloatingActionButtonLocation.endFloat,
            floatingActionButton: SlideTransition(
              position: _slideAnimation,
              child: SpeedDial(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                buttonSize: const Size(56, 56),
                childrenButtonSize: const Size(56, 56),
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                icon: Icons.menu,
                activeIcon: Icons.close,
                useRotationAnimation: true,
                animationDuration: const Duration(milliseconds: 300),
                spacing: 12,
                spaceBetweenChildren: 8,
                children: [
                  SpeedDialChild(
                    child: const Icon(Icons.vertical_align_top),
                    label: t.searchResult.returnToTop,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: colorScheme.secondaryContainer,
                    foregroundColor: colorScheme.onSecondaryContainer,
                    onTap: () {
                      _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                  SpeedDialChild(
                    child: const Icon(Icons.shortcut),
                    label: t.searchResult.jumpToPage,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: colorScheme.secondaryContainer,
                    foregroundColor: colorScheme.onSecondaryContainer,
                    onTap: _jumpToPage,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String? _pageLabel(SearchState state) {
    if (state.currentPage < 1 || state.status == SearchStatus.initial) {
      return null;
    }
    return state.totalPages > 0
        ? t.searchResult.pageProgress(
            page: state.currentPage,
            pages: state.totalPages,
          )
        : t.searchResult.pageOnly(page: state.currentPage);
  }

  Future<void> _jumpToPage() async {
    final state = context.read<SearchBloc>().state;
    final targetPage = await showNumberInputDialog(
      context: context,
      title: t.searchResult.jump,
      initialValue: state.currentPage > 0 ? state.currentPage : 1,
      hintText: state.totalPages > 0 ? '1–${state.totalPages}' : null,
    );
    if (!mounted || targetPage == null) return;
    if (targetPage < 1 ||
        (state.totalPages > 0 && targetPage > state.totalPages)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.totalPages > 0
                ? t.searchResult.pageOutOfRange(pages: state.totalPages)
                : t.searchResult.pageMustBePositive,
          ),
        ),
      );
      return;
    }
    if (targetPage == state.currentPage) return;
    context.read<SearchBloc>().add(
      searchEvent.copyWith(page: targetPage, status: SearchStatus.initial),
    );
    _scrollPositions.reset();
  }

  Widget _bloc(bool detailedView) => BlocConsumer<SearchBloc, SearchState>(
    listenWhen: (_, state) => state.status == SearchStatus.initial,
    listener: (_, _) => _scrollPositions.reset(),
    builder: (context, state) {
      switch (state.status) {
        case SearchStatus.initial:
          return Center(child: CircularProgressIndicator());
        case SearchStatus.failure:
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    userFacingErrorMessage(state.result),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                SizedBox(height: 10), // 添加间距
                ElevatedButton(
                  onPressed: () {
                    _refresh(SearchStatus.initial);
                  },
                  child: Text(t.searchResult.retry),
                ),
              ],
            ),
          );
        case SearchStatus.success:
        case SearchStatus.loadingMore:
        case SearchStatus.getMoreFailure:
          if (state.status == SearchStatus.success) {
            final searchCubit = context.read<SearchCubit>();
            // A category tap can happen while an older request is still
            // running. Do not let that older response undo the user's choice.
            if (searchCubit.state == searchEvent.searchStates &&
                searchCubit.state != state.searchEvent.searchStates) {
              searchCubit.update(state.searchEvent.searchStates);
            }
            searchEvent = state.searchEvent;
          }
          return _comicList(context, state, detailedView);
      }
    },
  );

  String _buildHistoryItem(SearchEvent event) {
    return event.searchStates.searchKeyword.trim();
  }

  Widget _comicList(
    BuildContext context,
    SearchState state,
    bool detailedView,
  ) {
    final search = context.watch<SearchCubit>().state;
    final blocked = blockedCategoryNames(
      search.pluginExtern['blockedCategories'],
    );
    final entries = filterEntriesByBlockedCategories(
      state.comics.map((item) => item.comic),
      blocked,
    );
    if (detailedView) {
      if (state.status == SearchStatus.success &&
          entries.isEmpty &&
          state.hasReachedMax) {
        return Center(child: Text(t.comicList.nothingHere));
      }
      return SourceSearchDetailList(
        controller: _scrollController,
        entries: entries,
        hasReachedMax:
            state.hasReachedMax && state.status == SearchStatus.success,
        isLoadingMore: state.status == SearchStatus.loadingMore,
        loadMoreFailed: state.status == SearchStatus.getMoreFailure,
        onRetryLoadMore: () => _refresh(SearchStatus.loadingMore),
        onLoadMore: _fetchSearchResult,
      );
    }
    return _genericList(state, entries);
  }

  Widget _genericList(SearchState state, List<UnifiedComicListItem> entries) {
    if (state.status == SearchStatus.success) {
      if (entries.isEmpty && state.hasReachedMax) {
        return Center(
          child: Text(
            t.comicList.nothingHere,
            style: TextStyle(fontSize: 20.0),
          ),
        );
      }
    }

    final list = mapToUnifiedComicSimplifyEntryInfoList(entries);

    return PluginComicGridSliver(
      controller: _scrollController,
      entries: list,
      hasReachedMax:
          state.hasReachedMax && state.status == SearchStatus.success,
      isLoadingMore: state.status == SearchStatus.loadingMore,
      loadMoreFailed: state.status == SearchStatus.getMoreFailure,
      onRetryLoadMore: () => _refresh(SearchStatus.loadingMore),
      onLoadMore: _fetchSearchResult,
    );
  }

  void _refresh(SearchStatus status) {
    final bloc = context.read<SearchBloc>();
    bloc.add(searchRetryEvent(searchEvent, bloc.state, status));
  }

  void _fetchSearchResult() {
    final state = context.read<SearchBloc>().state;
    if (state.status != SearchStatus.success || state.hasReachedMax) return;
    context.read<SearchBloc>().add(
      searchEvent.copyWith(
        page: searchEvent.page + 1,
        status: SearchStatus.loadingMore,
      ),
    );
  }

  void _onScroll() {
    if (_scrollPositions.isChanging || !mounted) return;
    // 控制 FAB 的上下移动
    if (_scrollController.position.userScrollDirection ==
        ScrollDirection.reverse) {
      if (_animationController.isDismissed) {
        _animationController.forward(); // 向上滚动时隐藏 FAB
      }
    } else if (_scrollController.position.userScrollDirection ==
        ScrollDirection.forward) {
      if (_animationController.isCompleted) {
        _animationController.reverse(); // 向下滚动时显示 FAB
      }
    }

    if (_isBottom) {
      _fetchSearchResult();
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return false;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll * 0.9);
  }
}
