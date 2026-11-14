import 'package:zephyr/page/search/widget/search_toolbar_scope.dart';
import 'package:zephyr/page/source_shell/source_loading_indicator.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';
import 'package:zephyr/page/search/method/search_history_entries.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/method/copy_search_topic.dart';
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
import 'package:zephyr/page/search_result/view/source_loaded_result_filter.dart';
import 'package:zephyr/page/search_result/view/source_search_detail_list.dart';
import 'package:zephyr/page/search_result/view/source_list_categories.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/widgets/bika_connection_notice.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/service/jm_list_like_counts.dart';
import 'package:zephyr/widgets/comic_simplify_entry/jm_cover_like_badge.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry_mapper.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';
import 'package:zephyr/widgets/section_header.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';

SearchEvent searchRetryEvent(
  SearchEvent lastSuccessful,
  SearchState current,
  SearchStatus targetStatus,
) {
  final source =
      current.status == SearchStatus.failure ||
          (targetStatus == SearchStatus.loadingMore &&
              current.status == SearchStatus.getMoreFailure)
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
    return SourceExperienceBoundary(
      source: context.select<SearchCubit, String>((cubit) => cubit.state.from),
      builder: (_) => _SearchResultPage(searchEvent: searchEvent),
    );
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
  bool _quickActionsHidden = false;
  bool _reduceMotion = false;
  (String, String, int)? _topicLookupKey;
  Future<CopySearchTopic?>? _topicLookup;

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
      if (keyword.isEmpty || !mounted) return;
      final settingCubit = context.read<GlobalSettingCubit>();
      settingCubit.updateState(
        (current) => current.copyWith(
          searchHistory: SearchHistoryEntries.add(
            current.searchHistory,
            keyword,
            scope: widget.searchEvent.searchStates.from,
          ),
        ),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion && !_reduceMotion) {
      _animationController.value = _quickActionsHidden ? 1 : 0;
    }
    _reduceMotion = reduceMotion;
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
    final resultState = context.watch<SearchBloc>().state;
    return BlocListener<SearchCubit, SearchStates>(
      listener: (_, _) => _scrollPositions.reset(),
      child: SourceListPresentation(
        source: source,
        detailedByDefault: true,
        builder: (context, detailedView, onViewChanged) {
          _scrollPositions.select(detailedView);
          return Scaffold(
            appBar: SearchToolbarScope.appBar(
              context,
              (height) => SearchResultBar(
                searchEvent: searchEvent,
                toolbarHeight: height,
              ),
              searching: context
                  .read<SearchCubit>()
                  .state
                  .searchKeyword
                  .trim()
                  .isNotEmpty,
            ),
            body: _resultBody(
              context,
              resultState,
              detailedView,
              onViewChanged,
            ),
            floatingActionButtonLocation:
                context.watch<GlobalSettingCubit>().state.leftHandModeEnabled
                ? FloatingActionButtonLocation.startFloat
                : FloatingActionButtonLocation.endFloat,
            floatingActionButton: SlideTransition(
              position: _slideAnimation,
              child: SpeedDial(
                // SpeedDial reads its controller duration at creation.
                key: ValueKey(_reduceMotion),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                buttonSize: const Size(56, 56),
                childrenButtonSize: const Size(56, 56),
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                icon: Icons.menu,
                activeIcon: Icons.close,
                useRotationAnimation: !_reduceMotion,
                animationDuration: _reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
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
                      if (!_scrollController.hasClients) return;
                      if (_reduceMotion) {
                        _scrollController.jumpTo(0);
                      } else {
                        _scrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                        );
                      }
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

  Widget _resultBody(
    BuildContext context,
    SearchState state,
    bool detailedView,
    ValueChanged<bool> onViewChanged,
  ) {
    final search = context.watch<SearchCubit>().state;
    final categories = sourceQuickCategories(search.from);
    final pageLabel = _pageLabel(state);
    Widget toolbar([Widget? filter]) => SourceQuickCategoryBar(
      categories: categories,
      detailedView: detailedView,
      pageLabel: pageLabel,
      onPageTap: _jumpToPage,
      onViewChanged: onViewChanged,
      trailingAction: filter,
    );
    Widget content(Widget controls, [List<UnifiedComicListItem>? entries]) =>
        Column(
          children: [
            controls,
            if (supportsCopyTopicSearch(search.from) &&
                search.searchKeyword.trim().isNotEmpty &&
                sourceKeywordSearchScope(search.from, search.pluginExtern) ==
                    KeywordSearchScope.all)
              _copyTopicEntry(search),
            Expanded(child: _bloc(detailedView, loadedEntries: entries)),
          ],
        );
    if (search.from != copyComicSourceId ||
        search.searchKeyword.trim().isEmpty ||
        explicitKeywordSearchScope(search.pluginExtern) == null) {
      return content(toolbar());
    }
    return SourceLoadedResultFilter(
      key: ValueKey((
        search.from,
        search.searchKeyword,
        sourceKeywordSearchScope(search.from, search.pluginExtern),
      )),
      scope: '${search.from}|publicSearch',
      entries: state.comics.map((item) => item.comic).toList(),
      blockedCategories: _blockedCategories(search),
      complete: state.hasReachedMax,
      publicBrowseFacets: true,
      filterScopeLabel: t.videoLibrary.loadedResultScope,
      loadingMore: state.status == SearchStatus.loadingMore,
      onChanged: () => _scrollPositions.reset(afterLayout: true),
      chromeBuilder: (_, chrome) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          toolbar(chrome.hasFilterOptions ? chrome.filterButton : null),
          SourceLoadedFacetSummary(chrome: chrome),
        ],
      ),
      builder: (_, entries, controls) => content(controls, entries),
    );
  }

  Widget _copyTopicEntry(SearchStates search) {
    final generation = pluginSessionWriteFence.generation(search.from);
    final key = (search.from, search.searchKeyword, generation);
    if (_topicLookupKey != key) {
      _topicLookupKey = key;
      _topicLookup = resolveCopySearchTopic(
        search.searchKeyword,
      ).catchError((Object _) => null);
    }
    return FutureBuilder<CopySearchTopic?>(
      key: ValueKey(key),
      future: _topicLookup,
      builder: (context, snapshot) {
        final topic = snapshot.data;
        if (topic == null) return const SizedBox.shrink();
        return SectionHeader(
          title: '${t.videoLibrary.genres} · ${topic.label}',
          onTap: () {
            final cubit = context.read<SearchCubit>();
            if (cubit.state != search ||
                pluginSessionWriteFence.isChanging(search.from) ||
                pluginSessionWriteFence.generation(search.from) != generation)
              return;
            final next = copyTopicSearchState(search, topic);
            cubit.update(next);
            context.read<SearchBloc>().add(SearchEvent(searchStates: next));
          },
        );
      },
    );
  }

  Set<String> _blockedCategories(SearchStates search) => {
    ...blockedCategoryNames(search.pluginExtern['blockedCategories']),
    ...blockedCategoryNames(search.pluginExtern['settingsBlockedCategories']),
  };

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

  Widget _bloc(
    bool detailedView, {
    List<UnifiedComicListItem>? loadedEntries,
  }) => BlocConsumer<SearchBloc, SearchState>(
    listenWhen: (_, state) => state.status == SearchStatus.initial,
    listener: (_, _) => _scrollPositions.reset(),
    builder: (context, state) {
      Widget content() {
        switch (state.status) {
          case SearchStatus.initial:
            return Center(
              child: SourceLoadingIndicator(
                source: context.read<SearchCubit>().state.from,
              ),
            );
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
            final results = _comicList(
              context,
              state,
              detailedView,
              loadedEntries,
            );
            return state.searchEvent.searchStates.from ==
                    JmListLikeCounts.source
                ? JmCoverLikeScope(
                    counts: JmListLikeCounts.instance,
                    child: results,
                  )
                : results;
        }
      }

      final search = context.read<SearchCubit>().state;
      return BikaConnectionNotice.wrap(
        source: search.from,
        scope: search,
        failure: state.status == SearchStatus.failure ? state.result : null,
        ready: state.status == SearchStatus.success,
        retry: () => _refresh(SearchStatus.initial),
        child: content(),
      );
    },
  );

  Widget _comicList(
    BuildContext context,
    SearchState state,
    bool detailedView,
    List<UnifiedComicListItem>? loadedEntries,
  ) {
    final search = context.watch<SearchCubit>().state;
    final returned = filterEntriesByBlockedCategories(
      state.comics.map((item) => item.comic),
      _blockedCategories(search),
    );
    final applied = state.searchEvent.searchStates;
    final titleOnly = needsLoadedTitleMatch(applied.from, applied.pluginExtern);
    final matchesTitle = titleOnly
        ? keywordTitleMatcher(applied.searchKeyword)
        : null;
    final entries =
        loadedEntries ??
        (matchesTitle == null
            ? returned
            : returned.where((entry) => matchesTitle([entry.title])).toList());
    if ((titleOnly || loadedEntries != null) &&
        entries.isEmpty &&
        (!state.hasReachedMax || returned.isNotEmpty)) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              loadedEntries != null
                  ? t.videoLibrary.noLoadedMatches
                  : t.videoLibrary.filteredLoaded(
                      loaded: returned.length,
                      shown: 0,
                    ),
            ),
            if (state.status == SearchStatus.loadingMore)
              const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              )
            else if (state.status == SearchStatus.getMoreFailure)
              TextButton(
                onPressed: () => _refresh(SearchStatus.loadingMore),
                child: Text(t.oldHome.loadMoreFailed),
              )
            else if (!state.hasReachedMax)
              TextButton(
                onPressed: _fetchSearchResult,
                child: Text(t.videoLibrary.continueCatalogSearch),
              ),
          ],
        ),
      );
    }
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
      state.searchEvent.copyWith(
        page: state.currentPage + 1,
        status: SearchStatus.loadingMore,
      ),
    );
  }

  void _onScroll() {
    if (_scrollPositions.isChanging ||
        !mounted ||
        !_scrollController.hasClients)
      return;
    final hideActions =
        switch (_scrollController.position.userScrollDirection) {
          ScrollDirection.reverse => true,
          ScrollDirection.forward => false,
          ScrollDirection.idle => _quickActionsHidden,
        };
    if (hideActions != _quickActionsHidden) {
      _quickActionsHidden = hideActions;
      if (_reduceMotion) {
        _animationController.value = hideActions ? 1 : 0;
      } else if (hideActions) {
        _animationController.forward();
      } else {
        _animationController.reverse();
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
