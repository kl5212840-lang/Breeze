import 'package:zephyr/page/source_shell/source_loading_indicator.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';
import 'package:zephyr/page/search/method/search_history_entries.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/method/copy_search_topic.dart';
import 'package:zephyr/page/search/widget/jm_search_date_chip.dart';
import 'package:zephyr/page/source_shell/source_list_presentation.dart';
import 'package:zephyr/page/source_shell/source_list_scroll_positions.dart';
import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart' hide Thumb;
import 'package:flutter/rendering.dart' show ScrollDirection;
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
import 'package:zephyr/page/search_result/view/source_search_capabilities.dart';
import 'package:zephyr/page/search_result/widgets/filtered_result_pages.dart';
import 'package:zephyr/page/search_result/widgets/source_page_jump.dart';
import 'package:zephyr/page/source_shell/source_category_settings_scope.dart';
import 'package:zephyr/page/source_shell/bika_content_block_rules.dart';
import 'package:zephyr/page/source_shell/bika_content_block_settings_scope.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/widgets/bika_connection_notice.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/service/jm_list_like_counts.dart';
import 'package:zephyr/widgets/comic_simplify_entry/jm_cover_like_badge.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry_mapper.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';
import 'package:zephyr/widgets/section_header.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'package:zephyr/widgets/image_recovery_region.dart';
import 'package:zephyr/widgets/source_page_divider.dart';
import 'package:zephyr/widgets/toast.dart';

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
    final source = context.select<SearchCubit, String>(
      (cubit) => cubit.state.from,
    );
    return SourceExperienceBoundary(
      source: source,
      builder: (_) => SourceCategorySettingsScope(
        source: source,
        builder: (_, blocked) => BikaContentBlockSettingsScope(
          source: source,
          builder: (_, rules) => _SearchResultPage(
            searchEvent: searchEvent,
            sourceBlockedCategories: blocked,
            bikaContentRules: rules,
          ),
        ),
      ),
    );
  }
}

class _SearchResultPage extends StatefulWidget {
  final SearchEvent searchEvent;
  final Set<String> sourceBlockedCategories;
  final BikaContentBlockRules bikaContentRules;

  const _SearchResultPage({
    required this.searchEvent,
    required this.sourceBlockedCategories,
    required this.bikaContentRules,
  });

  @override
  State<_SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends State<_SearchResultPage>
    with SingleTickerProviderStateMixin {
  late SearchEvent searchEvent;
  final _scrollPositions = SourceListScrollPositions(detailed: true);
  ScrollController get _scrollController => _scrollPositions.controller;
  final _resultItems = GlobalKey();
  final _visiblePage = ValueNotifier<int?>(null);
  List<int?> _presentedPages = const [];
  bool _pageUpdatePending = false;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  bool _quickActionsHidden = false;
  bool _reduceMotion = false;
  bool _shuffling = false;
  int _shuffleAttempt = 0;
  SearchState? _viewportFillRequestedFor;
  SearchState? _pageRequestFor;
  bool _filteredPaging = false;
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
            keywordScope: sourceKeywordSearchScope(
              widget.searchEvent.searchStates.from,
              widget.searchEvent.searchStates.pluginExtern,
            ),
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
    _visiblePage.dispose();
    _scrollPositions.removeListener(_onScroll);
    _scrollPositions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final search = context.watch<SearchCubit>().state;
    final source = search.from;
    final resultState = context.watch<SearchBloc>().state;
    return BlocListener<SearchCubit, SearchStates>(
      listener: (_, _) => _scrollPositions.reset(),
      child: SourceListPresentation(
        source: source,
        detailedByDefault: true,
        builder: (context, detailedView, onViewChanged) {
          _scrollPositions.select(detailedView);
          return Scaffold(
            appBar: SearchResultBar(
              searchEvent: searchEvent,
              toolbarHeight: SearchResultQueryTitle.toolbarHeight(context),
            ),
            body: SafeArea(
              top: false,
              bottom: false,
              child: _resultBody(
                context,
                resultState,
                detailedView,
                onViewChanged,
              ),
            ),
            floatingActionButtonLocation:
                context.watch<GlobalSettingCubit>().state.leftHandModeEnabled
                ? FloatingActionButtonLocation.startFloat
                : FloatingActionButtonLocation.endFloat,
            floatingActionButton: isBikaRandomResult(search)
                ? null
                : SlideTransition(
                    position: _slideAnimation,
                    child: SpeedDial(
                      // SpeedDial reads its controller duration at creation.
                      key: ValueKey(_reduceMotion),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      buttonSize: Size.square(
                        CollectionToolbarMetrics.actionExtentOf(context),
                      ),
                      childrenButtonSize: const Size(56, 56),
                      backgroundColor: colorScheme.surfaceContainerHigh,
                      foregroundColor: colorScheme.onSurface,
                      elevation: 1,
                      icon: Icons.unfold_more_rounded,
                      tooltip: t.searchResult.resultNavigation,
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
    final random = isBikaRandomResult(search);
    final appliedQuery = state.searchEvent.searchStates;
    final appliedSort =
        appliedQuery.from == search.from &&
            appliedQuery.searchKeyword == search.searchKeyword
        ? int.tryParse(appliedQuery.pluginExtern['sortBy']?.toString() ?? '')
        : null;
    Widget toolbar([Widget? filter]) => ValueListenableBuilder<int?>(
      valueListenable: _visiblePage,
      builder: (_, page, _) => SourceQuickCategoryBar(
        categories: categories,
        detailedView: detailedView,
        pageLabel: _pageLabel(state, page),
        pageWidthSample: state.totalPages > 0
            ? t.searchResult.pageProgress(
                page: state.totalPages,
                pages: state.totalPages,
              )
            : state.currentPage > 0
            ? t.searchResult.pageOnly(page: 9999)
            : null,
        appliedSort: appliedSort,
        onPageTap: _jumpToPage,
        onViewChanged: onViewChanged,
        trailingAction: filter,
        sourceBlockedCategories: widget.sourceBlockedCategories,
        shuffling:
            random &&
            state.status == SearchStatus.initial &&
            state.comics.isNotEmpty,
        onShuffle:
            random &&
                (state.status == SearchStatus.success ||
                    state.comics.isNotEmpty) &&
                state.status != SearchStatus.initial
            ? _shuffle
            : null,
      ),
    );
    Widget content(Widget controls, [List<UnifiedComicListItem>? entries]) =>
        Column(
          children: [
            controls,
            if (jmSearchDiscoveryFunction(search.from) != null)
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: CollectionToolbarMetrics.searchResultContentInset,
                ),
                child: JmSearchDateChip(
                  inline: true,
                  onCleared: (next) => context.read<SearchBloc>().add(
                    SearchEvent(searchStates: next),
                  ),
                ),
              ),
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
      entries: _matchesSearchOwner(state.searchEvent.searchStates, search)
          ? state.comics.map((item) => item.comic).toList()
          : const [],
      blockedCategories: _blockedCategories(search),
      complete: state.hasReachedMax,
      publicBrowseFacets: true,
      filterScopeLabel: '',
      loadingMore: state.status == SearchStatus.loadingMore,
      onLoadMore:
          _matchesSearchOwner(state.searchEvent.searchStates, search) &&
              (state.status == SearchStatus.success ||
                  state.status == SearchStatus.loadingMore)
          ? _fetchSearchResult
          : null,
      onChanged: _restartFilteredRange,
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
    ...widget.sourceBlockedCategories,
    ...blockedCategoryNames(search.pluginExtern['blockedCategories']),
    if (!isBikaExperienceSource(search.from))
      ...blockedCategoryNames(search.pluginExtern['settingsBlockedCategories']),
  };

  bool _matchesSearchOwner(SearchStates applied, SearchStates search) =>
      applied.from == search.from &&
      applied.searchKeyword == search.searchKeyword &&
      sourceKeywordSearchScope(applied.from, applied.pluginExtern) ==
          sourceKeywordSearchScope(search.from, search.pluginExtern) &&
      applied.pluginExtern['url'] == search.pluginExtern['url'];

  void _restartFilteredRange() {
    _scrollPositions.reset(afterLayout: true);
    final bloc = context.read<SearchBloc>();
    if (bloc.firstLoadedPage == 1) return;
    final search = context.read<SearchCubit>().state;
    if (_matchesSearchOwner(bloc.state.searchEvent.searchStates, search)) {
      bloc.add(SearchEvent(searchStates: search));
    }
  }

  void _shuffle() {
    if (_shuffling) return;
    final query = context.read<SearchCubit>().state;
    if (!isBikaRandomResult(query)) return;
    _shuffling = true;
    _shuffleAttempt++;
    context.read<SearchBloc>().add(SearchEvent(searchStates: query));
  }

  int _browsingPage(int? visible) =>
      visible ?? context.read<SearchBloc>().firstLoadedPage;

  String? _pageLabel(SearchState state, int? visible) {
    if (state.currentPage < 1 || state.status == SearchStatus.initial) {
      return null;
    }
    final page = _browsingPage(visible);
    return state.totalPages > 0
        ? t.searchResult.pageProgress(page: page, pages: state.totalPages)
        : t.searchResult.pageOnly(page: page);
  }

  Future<void> _jumpToPage() async {
    final bloc = context.read<SearchBloc>();
    final before = bloc.state;
    final query = context.read<SearchCubit>().state;
    final session = pluginSessionWriteFence.generation(query.from);
    final visible = _browsingPage(_visiblePage.value);
    final targetPage = await showSourcePageJumpDialog(
      context,
      page: visible,
      totalPages: before.totalPages > 0 ? before.totalPages : null,
    );
    if (!mounted || targetPage == null) return;
    final current = context.read<SearchCubit>().state;
    final state = bloc.state;
    if (!_matchesSearchOwner(query, current) ||
        query.sortBy != current.sortBy ||
        !_matchesSearchOwner(state.searchEvent.searchStates, current) ||
        session != pluginSessionWriteFence.generation(query.from) ||
        pluginSessionWriteFence.isChanging(query.from)) {
      return;
    }
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
    if (targetPage == visible &&
        targetPage == bloc.firstLoadedPage &&
        _scrollController.hasClients &&
        _scrollController.offset <= 0) {
      return;
    }
    bloc.add(
      state.searchEvent.copyWith(
        page: targetPage,
        status: SearchStatus.initial,
      ),
    );
    _scrollPositions.reset();
  }

  Widget _bloc(
    bool detailedView, {
    List<UnifiedComicListItem>? loadedEntries,
  }) => BlocConsumer<SearchBloc, SearchState>(
    listenWhen: (_, state) =>
        state.status == SearchStatus.initial || _shuffling,
    listener: (context, state) {
      final random = isBikaRandomResult(context.read<SearchCubit>().state);
      if (state.status == SearchStatus.initial) {
        if (!random) {
          _visiblePage.value = null;
          _scrollPositions.reset();
        }
      } else if (_shuffling) {
        _shuffling = false;
        if (state.status == SearchStatus.success) {
          _scrollPositions.reset();
        } else if (state.status == SearchStatus.failure &&
            state.comics.isNotEmpty &&
            !BikaConnectionNotice.handlesFailure(state.result) &&
            ModalRoute.isCurrentOf(context) != false) {
          showErrorToast(t.comicList.loadFailedRetry);
        }
      }
    },
    builder: (context, state) {
      final search = context.read<SearchCubit>().state;
      final random = isBikaRandomResult(search);
      Widget content() {
        switch (state.status) {
          case SearchStatus.initial:
            if (random && state.comics.isNotEmpty) {
              return _comicList(context, state, detailedView, loadedEntries);
            }
            return Center(
              child: SourceLoadingIndicator(
                source: context.read<SearchCubit>().state.from,
              ),
            );
          case SearchStatus.failure:
            if (random && state.comics.isNotEmpty) {
              return _comicList(context, state, detailedView, loadedEntries);
            }
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
                    subtleBadge: true,
                    child: results,
                  )
                : results;
        }
      }

      final results = content();
      return BikaConnectionNotice.wrap(
        source: search.from,
        scope: search,
        failure: state.status == SearchStatus.failure ? state.result : null,
        ready: state.status == SearchStatus.success,
        retry: random ? _shuffle : () => _refresh(SearchStatus.initial),
        manualAttempt: _shuffleAttempt,
        child: random
            ? PageImageRefreshScope(revision: searchEvent, child: results)
            : results,
      );
    },
  );

  Widget _comicList(
    BuildContext context,
    SearchState state,
    bool detailedView,
    List<UnifiedComicListItem>? loadedEntries,
  ) {
    _scheduleVisiblePageUpdate();
    final search = context.watch<SearchCubit>().state;
    final random = isBikaRandomResult(search);
    final blockedCategories = _blockedCategories(search);
    final contentBlocks = widget.bikaContentRules;
    final returned = filterEntriesByBlockedCategories(
      state.comics.map((item) => item.comic),
      blockedCategories,
    );
    final visible = contentBlocks.isEmpty
        ? returned
        : returned.where((entry) => !contentBlocks.blocks(entry)).toList();
    final applied = state.searchEvent.searchStates;
    final titleOnly =
        !random && needsLoadedTitleMatch(applied.from, applied.pluginExtern);
    final matchesTitle = titleOnly
        ? keywordTitleMatcher(applied.searchKeyword)
        : null;
    final entries =
        loadedEntries ??
        (matchesTitle == null
            ? visible
            : visible.where((entry) => matchesTitle([entry.title])).toList());
    if (random && entries.isEmpty && state.status == SearchStatus.success) {
      return Center(child: Text(t.searchResult.noVisibleRandomWorks));
    }
    final bikaBlocking =
        isBikaExperienceSource(search.from) &&
        (blockedCategories.isNotEmpty || !contentBlocks.isEmpty);
    final demand = SourceLoadedResultFilter.demandOf(context);
    _filteredPaging =
        !random && (bikaBlocking || titleOnly || demand?.filtering == true);
    if (_filteredPaging) {
      return FilteredResultPages(
        key: ValueKey((
          search.from,
          search.searchKeyword,
          sourceKeywordSearchScope(search.from, search.pluginExtern),
          search.pluginExtern['url'],
          search.pluginExtern['mode'],
          pluginSessionWriteFence.generation(search.from),
          search.sortBy,
          Object.hashAllUnordered(blockedCategories),
          contentBlocks,
          demand?.criteria,
        )),
        matches: entries,
        controller: _scrollController,
        page: state.currentPage,
        firstPage: context.read<SearchBloc>().firstLoadedPage,
        ready:
            state.status == SearchStatus.success &&
            _matchesSearchOwner(applied, search),
        complete: state.hasReachedMax,
        failed: state.status == SearchStatus.getMoreFailure,
        paused: demand?.editing == true,
        batchSize: detailedView ? 5 : 9,
        loadMore: _fetchSearchResult,
        builder: (shown, progress) {
          if (shown.isEmpty) {
            final message = switch (progress) {
              FilteredPageProgress.failed => userFacingErrorMessage(
                state.result,
              ),
              FilteredPageProgress.checking when bikaBlocking && !titleOnly =>
                t.common.loading,
              _ when bikaBlocking && !titleOnly =>
                t.searchResult.noVisibleRandomWorks,
              _ => progress.emptyMessage!,
            };
            return CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(message, textAlign: TextAlign.center),
                          if (state.status == SearchStatus.getMoreFailure)
                            TextButton(
                              onPressed: () =>
                                  _refresh(SearchStatus.loadingMore),
                              child: Text(t.common.retry),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return _resultList(
            state,
            shown,
            detailed: detailedView,
            random: false,
            quiet: true,
          );
        },
      );
    }
    if (loadedEntries != null &&
        entries.isEmpty &&
        (!state.hasReachedMax || returned.isNotEmpty)) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.videoLibrary.noLoadedMatches),
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
    if (!random && entries.isNotEmpty) _fillShortViewport(state);
    return _resultList(state, entries, detailed: detailedView, random: random);
  }

  Widget _resultList(
    SearchState state,
    List<UnifiedComicListItem> entries, {
    required bool detailed,
    required bool random,
    bool quiet = false,
  }) {
    if (state.status == SearchStatus.success &&
        entries.isEmpty &&
        state.hasReachedMax) {
      return Center(child: Text(t.comicList.nothingHere));
    }
    final terminal =
        random || state.hasReachedMax && state.status == SearchStatus.success;
    final confirmedPages = {
      for (final row in state.comics)
        if (row.sourcePage case final page?)
          (row.comic.source, row.comic.id): page,
    };
    _presentedPages = random
        ? const []
        : [for (final row in entries) confirmedPages[(row.source, row.id)]];
    final pageBreaks = random || !detailed
        ? const <int>{}
        : sourcePageBreaks(
            entries,
            (row) => confirmedPages[(row.source, row.id)],
          );
    if (detailed) {
      return SourceSearchDetailList(
        controller: _scrollController,
        entries: entries,
        pageBreaks: pageBreaks,
        itemsSliverKey: _resultItems,
        quietPaging: quiet,
        hasReachedMax: terminal,
        isLoadingMore: state.status == SearchStatus.loadingMore,
        loadMoreFailed: state.status == SearchStatus.getMoreFailure,
        onRetryLoadMore: () => _refresh(SearchStatus.loadingMore),
        onLoadMore: _fetchSearchResult,
      );
    }
    return PluginComicGridSliver(
      gridHorizontalInset: CollectionToolbarMetrics.searchResultContentInset,
      controller: _scrollController,
      physics: quiet ? const AlwaysScrollableScrollPhysics() : null,
      entries: mapToUnifiedComicSimplifyEntryInfoList(entries),
      itemsSliverKey: _resultItems,
      quietPaging: quiet,
      hasReachedMax: terminal,
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

  void _fillShortViewport(SearchState state) {
    if (state.status != SearchStatus.success ||
        state.currentPage != context.read<SearchBloc>().firstLoadedPage ||
        state.hasReachedMax ||
        identical(_viewportFillRequestedFor, state)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          identical(_viewportFillRequestedFor, state) ||
          ModalRoute.isCurrentOf(context) == false ||
          !identical(context.read<SearchBloc>().state, state) ||
          context.read<SearchCubit>().state != state.searchEvent.searchStates ||
          !_scrollController.hasClients) {
        return;
      }
      final position = _scrollController.position;
      if (!position.hasContentDimensions ||
          position.maxScrollExtent > position.minScrollExtent) {
        return;
      }
      // One automatic continuation keeps a sparse first page useful without
      // draining a source that repeatedly returns sparse or duplicate pages.
      _viewportFillRequestedFor = state;
      _fetchSearchResult();
    });
  }

  bool _fetchSearchResult() {
    final state = context.read<SearchBloc>().state;
    if (state.status != SearchStatus.success ||
        state.hasReachedMax ||
        identical(_pageRequestFor, state)) {
      return false;
    }
    _pageRequestFor = state;
    context.read<SearchBloc>().add(
      state.searchEvent.copyWith(
        page: state.currentPage + 1,
        status: SearchStatus.loadingMore,
      ),
    );
    return true;
  }

  void _onScroll() {
    if (_scrollPositions.isChanging ||
        !mounted ||
        !_scrollController.hasClients)
      return;
    _scheduleVisiblePageUpdate();
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

    if (!_filteredPaging &&
        _isBottom &&
        ModalRoute.isCurrentOf(context) != false) {
      _fetchSearchResult();
    }
  }

  void _scheduleVisiblePageUpdate() {
    if (_pageUpdatePending) return;
    _pageUpdatePending = true;
    WidgetsBinding.instance.ensureVisualUpdate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageUpdatePending = false;
      if (!mounted) return;
      _visiblePage.value = topVisibleSourcePage(_resultItems, _presentedPages);
    });
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return false;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll * 0.9);
  }
}
