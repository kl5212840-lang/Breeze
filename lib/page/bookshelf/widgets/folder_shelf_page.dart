import 'package:zephyr/widgets/pull_refresh_feedback.dart';
import 'package:zephyr/widgets/collection_cover_fit.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_detailed_content.dart';
import 'package:zephyr/widgets/work_list_divider.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_content_layout.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_content_toolbar.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_actions_scope.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_help.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_return_to_top.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/page/bookshelf/models/shelf_delete_prompt.dart';
import 'package:zephyr/widgets/action_feedback.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:zephyr/main.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/service/reader/reader_history_service.dart';
import 'package:zephyr/page/bookshelf/bloc/folder_shelf_bloc.dart';
import 'package:zephyr/page/bookshelf/cubit/bookshelf_search_cubit.dart';
import 'package:zephyr/page/bookshelf/cubit/search_status.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/bookshelf/method/method.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';
import 'package:zephyr/page/bookshelf/service/shelf_facet_adapters.dart';
import 'package:zephyr/page/bookshelf/widgets/shelf_filter_sheet.dart';
import 'package:zephyr/service/collection_view_preferences.dart';
import 'package:zephyr/page/bookshelf/models/shelf_back_action.dart';
import 'package:zephyr/page/bookshelf/service/comic_folder_service.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_empty_view.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_grid_shimmer.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_loading_view.dart';
import 'package:zephyr/page/bookshelf/widgets/folder_shelf_item.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_folder_picker.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/text/chinese_convert.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry_info.dart';
import 'package:zephyr/widgets/comic_entry/comic_record_time.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';
import 'package:zephyr/widgets/fluent_dropdown.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/widgets/folder_cover_menu.dart';
import 'package:zephyr/service/folder_cover_service.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_selection_toolbar.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_floating_selection_actions.dart';

class FolderShelfBackController extends ChangeNotifier {
  bool _isRoot = true;
  bool _disposed = false;
  VoidCallback? _onBack;

  bool get canGoBack => !_isRoot && _onBack != null;

  void attach(VoidCallback onBack) => _onBack = onBack;

  void updateIsRoot(bool isRoot) {
    if (_isRoot == isRoot) return;
    _isRoot = isRoot;
    scheduleMicrotask(() {
      if (!_disposed) notifyListeners();
    });
  }

  void goBack() => _onBack?.call();

  void detach() {
    _onBack = null;
    _isRoot = true;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class FolderShelfPage extends StatelessWidget {
  const FolderShelfPage({
    super.key,
    required this.mode,
    this.keywordScope = KeywordSearchScope.all,
    this.refreshSignal = 0,
    this.isActive = true,
    this.showReturnToTop = false,
    this.backController,
    this.handleRouteBack = true,
    this.onSelectionChanged,
    this.sourceNames = const {},
  });

  final ShelfPageMode mode;
  final KeywordSearchScope keywordScope;
  final Map<String, String> sourceNames;
  final int refreshSignal;
  final bool isActive;
  final bool showReturnToTop;
  final FolderShelfBackController? backController;
  final bool handleRouteBack;
  final ValueChanged<bool>? onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final search = context.read<BookshelfSearchCubit>().state.stateOf(mode);
    return BlocProvider(
      create: (_) => FolderShelfBloc(
        mode: mode,
        active: isActive,
        keywordScope: keywordScope,
      )..add(FolderShelfLoadRequested(search: search)),
      child: _FolderShelfPageContent(
        refreshSignal: refreshSignal,
        search: search,
        keywordScope: keywordScope,
        isActive: isActive,
        showReturnToTop: showReturnToTop,
        backController: backController,
        handleRouteBack: handleRouteBack,
        onSelectionChanged: onSelectionChanged,
        sourceNames: sourceNames,
      ),
    );
  }
}

class _FolderShelfPageContent extends StatefulWidget {
  const _FolderShelfPageContent({
    required this.refreshSignal,
    required this.search,
    required this.keywordScope,
    required this.isActive,
    required this.showReturnToTop,
    required this.backController,
    required this.handleRouteBack,
    required this.onSelectionChanged,
    required this.sourceNames,
  });

  final Map<String, String> sourceNames;
  final int refreshSignal;
  final SearchStatusState search;
  final KeywordSearchScope keywordScope;
  final bool isActive;
  final bool showReturnToTop;
  final FolderShelfBackController? backController;
  final bool handleRouteBack;
  final ValueChanged<bool>? onSelectionChanged;

  @override
  State<_FolderShelfPageContent> createState() =>
      _FolderShelfPageContentState();
}

class _FolderShelfPageContentState extends State<_FolderShelfPageContent>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  LocalHistoryEntry? _backEntry;
  bool _removingBackEntry = false;
  bool _batchWorking = false;
  BookshelfContentView _view = BookshelfContentView.grid;
  int _lastActionRevision = 0;
  bool _openingFilter = false;
  int _filterScopeEpoch = 0;
  Object? _pullScope, _failedPullScope;
  final _refreshIndicator = GlobalKey<RefreshIndicatorState>();
  int _viewEpoch = 0;
  String _loadedViewScope = '';

  Object _refreshScope(FolderShelfState state) => (
    state.mode,
    state.currentPath,
    widget.search,
    state.facets,
    widget.keywordScope,
  );

  bool get _pullRefreshing =>
      _pullScope == _refreshScope(context.read<FolderShelfBloc>().state);

  Future<PullRefreshResult> _refreshFromPull() async {
    if (!widget.isActive || _batchWorking || _pullRefreshing) {
      return PullRefreshResult.ignored;
    }
    final bloc = context.read<FolderShelfBloc>();
    final before = bloc.state;
    final scope = _refreshScope(before);
    final hadSnapshot = bloc.hasCurrentSnapshot;
    setState(() => _pullScope = scope);
    try {
      final committed = await bloc.refresh();
      if (!mounted || !widget.isActive || scope != _refreshScope(bloc.state)) {
        return PullRefreshResult.ignored;
      }
      final after = bloc.state;
      setState(
        () =>
            _failedPullScope = !committed && after.error != null ? scope : null,
      );
      if (!committed) return PullRefreshResult.ignored;
      if (!hadSnapshot || !_sameShelfRows(before, after)) {
        return PullRefreshResult.updated;
      }
      return PullRefreshResult.unchanged;
    } finally {
      if (mounted && _pullScope == scope) setState(() => _pullScope = null);
    }
  }

  String get _viewScope {
    final mode = context.read<FolderShelfBloc>().state.mode.name;
    if (context.getInheritedWidgetOfExactType<BookshelfActionsScope>() !=
        null) {
      return 'public|comic|$mode';
    }
    final sources = [...widget.search.sources]..sort();
    return 'plugin|${sources.join(',')}|comic|$mode';
  }

  Future<void> _restoreView() async {
    final epoch = ++_viewEpoch, scope = _viewScope;
    _loadedViewScope = scope;
    try {
      final value = await CollectionViewPreferences.read(scope);
      if (!mounted || epoch != _viewEpoch || scope != _viewScope) return;
      setState(
        () => _view = value == 'list'
            ? BookshelfContentView.list
            : BookshelfContentView.grid,
      );
    } catch (_) {
      // Keep the visible layout if this optional preference cannot be read.
    }
  }

  Future<void> _toggleView() async {
    final scope = _viewScope, previous = _view;
    final epoch = ++_viewEpoch;
    final next = previous == BookshelfContentView.grid
        ? BookshelfContentView.list
        : BookshelfContentView.grid;
    setState(() => _view = next);
    try {
      await CollectionViewPreferences.write(scope, next.name);
    } catch (_) {
      if (!mounted || epoch != _viewEpoch || scope != _viewScope) return;
      setState(() => _view = previous);
      await _restoreView();
      if (mounted && scope == _viewScope) showErrorToast(t.error.saveFailed);
    }
  }

  Future<void> _openFacetFilter(FolderShelfState state) async {
    if (!widget.isActive ||
        _openingFilter ||
        state.isLoading ||
        state.selectionMode) {
      return;
    }
    _openingFilter = true;
    final epoch = _filterScopeEpoch;
    bool isCurrent() =>
        mounted && widget.isActive && epoch == _filterScopeEpoch;
    try {
      final index = loadComicShelfFacetIndex(type: _folderTypeOf(state.mode));
      final search = context.read<BookshelfSearchCubit>().state.stateOf(
        state.mode,
      );
      final query = _normalizeSearchText(search.keyword);
      final entries = index.entries
          .where(
            (entry) =>
                (search.sources.isEmpty ||
                    search.sources.contains(entry.source)) &&
                (query.isEmpty ||
                    (widget.keywordScope == KeywordSearchScope.title
                            ? _normalizeSearchText(
                                index.comics[entry.key]?.title ?? '',
                              )
                            : entry.searchText)
                        .contains(query)),
          )
          .toList();
      final result = await showShelfFilterSheet(
        context,
        entries: entries,
        initial: query.isNotEmpty && !state.facets.isActive
            ? state.facets.copyWith(scope: ShelfFacetScope.all)
            : state.facets,
        preferenceKey: state.mode == ShelfPageMode.favorite
            ? 'comic'
            : 'comic.${state.mode.name}',
        scopeLabel: [
          state.mode == ShelfPageMode.history
              ? t.bookshelf.history
              : state.isRoot
              ? t.common.root
              : state.breadcrumbTitle,
          if (query.isNotEmpty)
            t.bookshelf.facets.search(name: search.keyword.trim()),
        ].join(' · '),
        currentFolder: state.mode == ShelfPageMode.history
            ? null
            : state.currentPath,
        hierarchical: state.mode != ShelfPageMode.history,
      );
      if (!isCurrent() || result == null) return;
      final current = context.read<FolderShelfBloc>().state;
      if (current.mode != state.mode ||
          current.currentPath != state.currentPath ||
          current.search != state.search) {
        return;
      }
      context.read<FolderShelfBloc>().add(FolderShelfSetFacets(result));
    } catch (_) {
      if (isCurrent()) showErrorToast(t.bookshelf.facets.loadFailed);
    } finally {
      _openingFilter = false;
    }
  }

  @override
  void initState() {
    super.initState();
    CollectionViewPreferences.changes.addListener(_restoreView);
    unawaited(_restoreView());
    widget.backController?.attach(
      () => _handleShelfBack(context.read<FolderShelfBloc>().state),
    );
    if (_isDesktop) {
      HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    }
  }

  @override
  void dispose() {
    _viewEpoch++;
    CollectionViewPreferences.changes.removeListener(_restoreView);
    _removeBackEntry();
    widget.backController?.detach();
    if (_isDesktop) {
      HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    }
    super.dispose();
  }

  static bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.escape) return false;
    if (!mounted || !widget.isActive) return false;
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return false;

    return _handleShelfBack(context.read<FolderShelfBloc>().state);
  }

  bool _handleShelfBack(FolderShelfState state) {
    if (_batchWorking && state.selectionMode) return true;
    switch (shelfBackActionFor(
      selectionMode: state.selectionMode,
      isRoot: state.isRoot,
    )) {
      case ShelfBackAction.exitSelection:
        context.read<FolderShelfBloc>().add(
          const FolderShelfExitSelectionMode(),
        );
        return true;
      case ShelfBackAction.goBack:
        context.read<FolderShelfBloc>().add(const FolderShelfGoBack());
        return true;
      case ShelfBackAction.none:
        return false;
    }
  }

  /// 与 bloc 状态同步 entry 的持有/释放。entry 的 onRemove 即一次返回事件，
  /// 直接消费状态机；entry 被消费后 onRemove 内按新状态重新同步（无残留时放行）。
  void _syncBackEntry(FolderShelfState state) {
    final want =
        widget.handleRouteBack &&
        wantShelfBackEntry(
          isActive: widget.isActive,
          selectionMode: state.selectionMode,
          isRoot: state.isRoot,
        );
    final has = _backEntry != null;
    if (want == has) return;
    if (!want) {
      _removeBackEntry();
      return;
    }
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return;
    final entry = LocalHistoryEntry(
      // 书架 AppBar 自绘返回/关闭按钮，不需要框架按 entry 补 leading。
      impliesAppBarDismissal: false,
      onRemove: () {
        _backEntry = null;
        if (!mounted) return;
        // 程序化释放（切 tab/回根/dispose）：只清标记，不消费返回。
        if (_removingBackEntry) return;
        _handleShelfBack(context.read<FolderShelfBloc>().state);
        // 状态更新后按新状态重新同步：仍有可退层级则补回 entry，
        // 到根则保持放行。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _syncBackEntry(context.read<FolderShelfBloc>().state);
        });
      },
    );
    _backEntry = entry;
    route.addLocalHistoryEntry(entry);
  }

  void _removeBackEntry() {
    final entry = _backEntry;
    _backEntry = null;
    if (entry == null) return;
    // 同步触发 onRemove：置旗跳过其中的 _handleShelfBack。
    _removingBackEntry = true;
    try {
      entry.remove();
    } finally {
      _removingBackEntry = false;
    }
  }

  @override
  void didUpdateWidget(covariant _FolderShelfPageContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive ||
        oldWidget.keywordScope != widget.keywordScope ||
        oldWidget.search != widget.search) {
      _filterScopeEpoch++;
    }
    if (_loadedViewScope != _viewScope) {
      _view = BookshelfContentView.grid;
      unawaited(_restoreView());
    }
    if (oldWidget.isActive != widget.isActive ||
        oldWidget.handleRouteBack != widget.handleRouteBack) {
      context.read<FolderShelfBloc>().setStorageActive(widget.isActive);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncBackEntry(context.read<FolderShelfBloc>().state);
      });
    }
    final bloc = context.read<FolderShelfBloc>();
    final scopeChanged = oldWidget.keywordScope != widget.keywordScope;
    if (scopeChanged) bloc.setKeywordScope(widget.keywordScope);
    if (oldWidget.refreshSignal != widget.refreshSignal ||
        scopeChanged && widget.search.keyword.trim().isNotEmpty) {
      bloc.add(FolderShelfLoadRequested(search: widget.search));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocConsumer<FolderShelfBloc, FolderShelfState>(
      listenWhen: (previous, current) =>
          (current.error != null && current.error != previous.error) ||
          current.currentPath != previous.currentPath ||
          current.selectionMode != previous.selectionMode ||
          current.actionRevision != previous.actionRevision,
      buildWhen: _shelfStructureChanged,
      listener: (context, state) {
        widget.backController?.updateIsRoot(
          state.isRoot && !state.selectionMode,
        );
        widget.onSelectionChanged?.call(state.selectionMode);
        _syncBackEntry(state);
        if (state.actionMessage != null && widget.isActive) {
          // listenWhen also handles navigation; only consume each result once.
          if (_lastActionRevision != state.actionRevision) {
            _lastActionRevision = state.actionRevision;
            showActionFeedback(context, state.actionMessage!);
          }
        }
        final error = state.error;
        if (error != null && error.isNotEmpty && !_pullRefreshing) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error)));
        }
      },
      builder: (context, state) {
        widget.backController?.updateIsRoot(
          state.isRoot && !state.selectionMode,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _syncBackEntry(context.read<FolderShelfBloc>().state);
        });
        final content = Column(
          children: [
            _buildShelfToolbar(context, state),
            if (state.error?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _failedPullScope != _refreshScope(state)
                            ? t.common.loadingFailed
                            : context
                                      .read<FolderShelfBloc>()
                                      .hasCurrentSnapshot &&
                                  (state.comics.isNotEmpty ||
                                      state.folders.isNotEmpty)
                            ? t.common.refreshRetained
                            : t.common.refreshFailed,
                      ),
                    ),
                    TextButton.icon(
                      key: const ValueKey('comic-shelf.refresh-retry'),
                      onPressed: state.isLoading || _pullRefreshing
                          ? null
                          : () => _refreshIndicator.currentState?.show(),
                      icon: const Icon(Icons.refresh),
                      label: Text(t.common.retry),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: BlocBuilder<FolderShelfBloc, FolderShelfState>(
                builder: (context, selection) => _buildFloatingSelection(
                  context,
                  selection,
                  child: PullRefreshFeedback.indicator(
                    onRefresh: _refreshFromPull,
                    active: widget.isActive && !_batchWorking,
                    scope: _refreshScope(selection),
                    indicatorKey: _refreshIndicator,
                    notificationPredicate: (notice) =>
                        widget.isActive && !_batchWorking && notice.depth == 0,
                    child: _buildBody(context),
                  ),
                ),
              ),
            ),
          ],
        );
        return CollectionCoverFitScope(
          child: CollectionCoverPrivacyScope(child: content),
        );
      },
    );
  }

  Widget _buildShelfToolbar(BuildContext context, FolderShelfState state) {
    final bloc = context.read<FolderShelfBloc>();
    final hasSnapshot = bloc.hasCurrentSnapshot;
    final header = BookshelfActionsScope.of(context)?.header;
    final lifted = header != null;
    final filterEpoch = _filterScopeEpoch;
    final scope = _refreshScope(state);
    return BookshelfContentToolbar(
      keyPrefix: 'comic-shelf',
      headerIdentity: (scope, filterEpoch),
      canRun: () {
        if (!mounted ||
            !widget.isActive ||
            _batchWorking ||
            (lifted && filterEpoch != _filterScopeEpoch)) {
          return false;
        }
        final current = bloc.state;
        return current.mode == state.mode &&
            current.currentPath == state.currentPath &&
            (!lifted || _refreshScope(current) == scope) &&
            bloc.hasCurrentSnapshot &&
            !current.isLoading &&
            !current.selectionMode;
      },
      title: !state.isRoot
          ? convertChineseForDisplay(state.currentPath.split('/').last)
          : state.mode == ShelfPageMode.history &&
                context
                        .dependOnInheritedWidgetOfExactType<
                          BookshelfActionsScope
                        >() ==
                    null
          ? t.bookshelf.history
          : '',
      subtitle: state.isRoot && hasSnapshot
          ? t.videoLibrary.results(count: state.comics.length)
          : '',
      view: _view,
      privacyAction: const CollectionCoverPrivacyButton(
        emphasizeProtected: true,
      ),
      filterActive: state.facets.isActive,
      showFilter: true,
      onFilter: hasSnapshot && !state.isLoading && !_batchWorking
          ? () => unawaited(_openFacetFilter(state))
          : null,
      onToggleView: _toggleView,
      onBack: state.isRoot
          ? null
          : () =>
                context.read<FolderShelfBloc>().add(const FolderShelfGoBack()),
      folderRootLabel: state.mode == ShelfPageMode.download
          ? t.bookshelf.download
          : t.common.root,
      onRoot: state.currentPath.lastIndexOf('/') > 0
          ? () => context.read<FolderShelfBloc>().add(const FolderShelfGoHome())
          : null,
      showCreateFolder: state.mode != ShelfPageMode.history,
      onCreateFolder: !hasSnapshot || state.isLoading
          ? null
          : () => _showCreateFolderDialog(context),
      onManage: !hasSnapshot || state.comics.isEmpty && state.folders.isEmpty
          ? null
          : () => context.read<FolderShelfBloc>().add(
              const FolderShelfEnterSelectionMode(),
            ),
      arrangement: BookshelfActionsScope.forPane(
        context,
        video: false,
        mode: state.mode,
      ),
      selection: state.selectionMode
          ? BlocBuilder<FolderShelfBloc, FolderShelfState>(
              bloc: bloc,
              builder: (context, selection) =>
                  _buildSelectionBar(bloc, selection, lifted: lifted),
            )
          : null,
      moreOptions: {
        if (state.mode == ShelfPageMode.download)
          'import': t.bookshelf.importComic,
        'help': t.common.help,
      },
      moreGroups: [
        ['import'],
        ['help'],
      ],
      onMore: (value) {
        if (!widget.isActive || _batchWorking || state.isLoading) return;
        if (value == 'import') _importComic(context);
        if (value == 'help') _showShelfHelpDialog(context);
      },
    );
  }

  Future<void> _showShelfHelpDialog(BuildContext context) async {
    return showBookshelfHelpDialog(
      context,
      title: bookshelfHelpTitle(
        video: false,
        mode: context.read<FolderShelfBloc>().state.mode,
      ),
      content: bookshelfHelpContent(
        video: false,
        mode: context.read<FolderShelfBloc>().state.mode,
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return BlocBuilder<FolderShelfBloc, FolderShelfState>(
      buildWhen: _shelfStructureChanged,
      builder: (context, state) {
        final bloc = context.read<FolderShelfBloc>();
        final rowScope = bloc.loadedScope;
        final filteredFolders = state.folders;
        final filteredComics = state.comics;
        final totalCount = filteredFolders.length + filteredComics.length;
        if (totalCount == 0 &&
            (state.isLoading && !_pullRefreshing ||
                !bloc.hasCurrentSnapshot && state.error == null)) {
          return Stack(
            children: [
              BookshelfGridShimmer(view: _view),
              if (!_pullRefreshing) const Center(child: BookshelfLoadingView()),
            ],
          );
        }

        if (totalCount == 0) {
          if (!bloc.hasCurrentSnapshot) {
            // The retry row describes the failed read. Only a committed
            // snapshot for this scope can establish that there are no rows.
            return const CustomScrollView(
              physics: AlwaysScrollableScrollPhysics(),
            );
          }
          if (state.facets.isActive) {
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t.bookshelf.facets.noResults),
                        const SizedBox(height: 8),
                        TextButton(
                          key: const ValueKey('comic-shelf.clear-empty-filter'),
                          onPressed: () => context.read<FolderShelfBloc>().add(
                            const FolderShelfSetFacets(ShelfFacetSelection()),
                          ),
                          child: Text(t.bookshelf.facets.clear),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          return const BookshelfEmptyView();
        }

        final comicType = _comicEntryTypeOf(state.mode);
        final folderSyncIdMap = _buildSyncIdMap(state.mode);
        String folderPathOf(ComicFolder f) =>
            ComicFolderService.folderPath(f, syncIdMap: folderSyncIdMap);

        final storageKey = PageStorageKey((rowScope, _view));
        return BookshelfReturnToTop(
          key: ValueKey(storageKey.value),
          enabled:
              widget.showReturnToTop &&
              widget.isActive &&
              !state.selectionMode &&
              !state.isLoading &&
              filteredComics.isNotEmpty,
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  Widget buildItem(BuildContext context, int index) {
                    if (index < filteredFolders.length) {
                      final folder = filteredFolders[index];
                      final folderPath = folderPathOf(folder);
                      return Builder(
                        key: ValueKey('folder-${folder.uniqueKey}'),
                        builder: (rowContext) {
                          final selection = rowContext.select(
                            (FolderShelfBloc bloc) => (
                              bloc.state.selectionMode,
                              bloc.state.selectedFolderPaths.contains(
                                folderPath,
                              ),
                            ),
                          );
                          return FolderShelfItem(
                            key: ValueKey('folder-${folder.uniqueKey}'),
                            folder: folder,
                            count: state.folderCounts[folder.syncId],
                            canEditCover: () =>
                                mounted &&
                                widget.isActive &&
                                !_batchWorking &&
                                !context
                                    .read<FolderShelfBloc>()
                                    .state
                                    .selectionMode,
                            menu: FolderCoverMenu(
                              onCover: _view == BookshelfContentView.grid,
                              target: FolderCoverService.comic(
                                folder,
                                canRun: () =>
                                    mounted &&
                                    widget.isActive &&
                                    !_batchWorking,
                              ),
                              canRun: () =>
                                  mounted && widget.isActive && !_batchWorking,
                              extraOptions: {
                                'rename': t.common.rename,
                                'move': t.bookshelf.moveTo,
                                'delete': t.common.delete,
                              },
                              onCommand: (value) => _runFolderCommand(
                                context,
                                folder,
                                folderPath,
                                value,
                              ),
                            ),
                            view: _view,
                            selectionMode: selection.$1,
                            isSelected: selection.$2,
                            onTap: () {
                              final bloc = context.read<FolderShelfBloc>();
                              if (!widget.isActive ||
                                  _batchWorking ||
                                  !bloc.hasCurrentSnapshot ||
                                  bloc.state.isLoading ||
                                  !bloc.state.folders.any(
                                    (current) =>
                                        current.syncId == folder.syncId,
                                  )) {
                                return;
                              }
                              bloc.add(
                                bloc.state.selectionMode
                                    ? FolderShelfToggleFolderSelection(
                                        folderPath,
                                      )
                                    : FolderShelfEnterFolder(folderPath),
                              );
                            },
                            onLongPress: (_) {
                              if (!mounted ||
                                  !widget.isActive ||
                                  _batchWorking ||
                                  context
                                      .read<FolderShelfBloc>()
                                      .state
                                      .isLoading)
                                return;
                              context.read<FolderShelfBloc>().add(
                                FolderShelfToggleFolderSelection(folderPath),
                              );
                            },
                            onSecondaryTapDown: selection.$1
                                ? null
                                : (details) => _showFolderActions(
                                    context,
                                    folder,
                                    folderPath,
                                    details.globalPosition,
                                  ),
                          );
                        },
                      );
                    }
                    final comicIndex = index - filteredFolders.length;
                    final comic = filteredComics[comicIndex];
                    final comicUniqueKey = '${comic.from.trim()}:${comic.id}';
                    return Builder(
                      key: ValueKey('comic-${comic.from}:${comic.id}'),
                      builder: (rowContext) {
                        final selection = rowContext.select(
                          (FolderShelfBloc bloc) => (
                            bloc.state.selectionMode,
                            bloc.state.selectedComicKeys.contains(
                              comicUniqueKey,
                            ),
                          ),
                        );
                        return ComicSimplifyEntry(
                          key: ValueKey('comic-${comic.from}:${comic.id}'),
                          info: comic,
                          horizontal: _view == BookshelfContentView.list,
                          coverAspectRatio:
                              BookshelfContentLayout.coverAspectRatio,
                          caption: _withHistoryTime(
                            comic,
                            state.mode == ShelfPageMode.history &&
                                _view == BookshelfContentView.list,
                            BookshelfCardCaption(
                              fixedHeight: _view != BookshelfContentView.list,
                              title: convertChineseForDisplay(comic.title),
                              subtitle: [
                                if (state.facets.isActive &&
                                    state.facets.scope !=
                                        ShelfFacetScope.current)
                                  state.comicFolderLabels[comicUniqueKey] ?? '',
                                widget.sourceNames[comic.source
                                            .trim()
                                            .isNotEmpty
                                        ? comic.source.trim()
                                        : comic.from.trim()] ??
                                    t.bookshelf.unknownSource,
                              ].where((value) => value.isNotEmpty).join(' · '),
                            ),
                          ),
                          type: comicType,
                          selectionMode: selection.$1,
                          isSelected: selection.$2,
                          refresh: () => context.read<FolderShelfBloc>().add(
                            const FolderShelfLoadRequested(),
                          ),
                          onTapOverride: selection.$1
                              ? (info) => context.read<FolderShelfBloc>().add(
                                  FolderShelfToggleComicSelection(
                                    '${info.from.trim()}:${info.id}',
                                  ),
                                )
                              : null,
                          onLongPressOverride: (info, details) {
                            if (!widget.isActive ||
                                _batchWorking ||
                                context
                                    .read<FolderShelfBloc>()
                                    .state
                                    .isLoading) {
                              return;
                            }
                            if (!selection.$1) {
                              unawaited(HapticFeedback.selectionClick());
                            }
                            context.read<FolderShelfBloc>().add(
                              FolderShelfToggleComicSelection(
                                '${info.from.trim()}:${info.id}',
                              ),
                            );
                          },
                          onSecondaryTapDown: selection.$1
                              ? null
                              : (info, details) => _showComicActions(
                                  context,
                                  info,
                                  details.globalPosition,
                                ),
                        );
                      },
                    );
                  }

                  final padding = EdgeInsets.fromLTRB(
                    12,
                    10,
                    12,
                    NativeNavigationInset.of(context) +
                        (state.selectionMode
                            ? BookshelfFloatingSelectionActions
                                  .contentBottomPadding
                            : 20),
                  );
                  return _view == BookshelfContentView.grid
                      ? GridView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          key: storageKey,
                          primary: false,
                          padding: padding,
                          gridDelegate: BookshelfContentLayout.gridDelegate(
                            context,
                            constraints.maxWidth,
                          ),
                          itemCount: totalCount,
                          itemBuilder: buildItem,
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          key: storageKey,
                          primary: false,
                          padding: padding,
                          itemCount: totalCount,
                          itemBuilder: buildItem,
                          separatorBuilder: (_, _) => const WorkListDivider(
                            height: BookshelfContentLayout.spacing,
                          ),
                        );
                },
              ),
              if (state.isLoading && !_pullRefreshing)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectionBar(
    FolderShelfBloc bloc,
    FolderShelfState state, {
    required bool lifted,
  }) {
    final syncIds = _buildSyncIdMap(state.mode);
    final allSelected =
        (state.comics.isNotEmpty || state.folders.isNotEmpty) &&
        state.comics.every(
          (c) => state.selectedComicKeys.contains('${c.from.trim()}:${c.id}'),
        ) &&
        state.folders.every(
          (f) => state.selectedFolderPaths.contains(
            ComicFolderService.folderPath(f, syncIdMap: syncIds),
          ),
        );
    return BookshelfSelectionToolbar(
      key: const ValueKey('comic-shelf.selection-toolbar'),
      keyPrefix: 'comic-shelf',
      selectedCount: state.selectedCount,
      privacyAction: lifted ? null : const CollectionCoverPrivacyButton(),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: lifted ? 0 : 4),
      allSelected: allSelected,
      onCancel: _batchWorking || state.isLoading
          ? null
          : () => bloc.add(const FolderShelfExitSelectionMode()),
      onToggleAll:
          _batchWorking ||
              state.isLoading ||
              (state.comics.isEmpty && state.folders.isEmpty)
          ? null
          : () => bloc.add(
              allSelected
                  ? const FolderShelfClearSelection()
                  : const FolderShelfSelectAll(),
            ),
    );
  }

  Widget _buildFloatingSelection(
    BuildContext context,
    FolderShelfState state, {
    required Widget child,
  }) {
    final bloc = context.read<FolderShelfBloc>();
    final move = BookshelfBatchAction(
      id: 'move',
      label: t.bookshelf.moveTo,
      icon: Icons.drive_file_move_outline,
      symbol: 'folder',
      onPressed: state.hasSelection
          ? () => _runBatch(
              () => _showTargetFolderDialog(
                context,
                onConfirmed: (targets) =>
                    bloc.add(FolderShelfMoveSelected(targets)),
              ),
            )
          : null,
    );
    final copy = BookshelfBatchAction(
      id: 'copy',
      label: t.bookshelf.copyTo,
      icon: Icons.folder_copy_outlined,
      symbol: 'doc.on.doc',
      onPressed: state.hasSelection
          ? () => _runBatch(
              () => _showTargetFolderDialog(
                context,
                multiple: true,
                onConfirmed: (targets) =>
                    bloc.add(FolderShelfCopySelected(targets)),
              ),
            )
          : null,
    );
    return BookshelfFloatingSelectionActions(
      keyPrefix: 'comic-shelf',
      selecting: state.selectionMode,
      selectedCount: state.selectedCount,
      busy: state.isLoading || _batchWorking,
      actions: [
        if (state.mode == ShelfPageMode.favorite) ...[move, copy],
        if (state.mode == ShelfPageMode.download)
          BookshelfBatchAction(
            id: 'export',
            label: t.common.export,
            icon: Icons.ios_share,
            symbol: 'square.and.arrow.up',
            onPressed: state.hasSelection
                ? () => _runBatch(() => _batchExportSelected(context, state))
                : null,
          ),
        BookshelfBatchAction(
          id: 'remove',
          label: t.common.delete,
          icon: Icons.delete_outline,
          symbol: 'trash',
          onPressed: state.hasSelection
              ? () => _runBatch(() => _confirmDeleteSelected(context))
              : null,
        ),
      ],
      overflowActions: state.mode == ShelfPageMode.download
          ? [move, copy]
          : const [],
      child: child,
    );
  }

  Future<void> _runBatch(Future<void> Function() operation) async {
    if (_batchWorking) return;
    setState(() => _batchWorking = true);
    try {
      await operation();
    } finally {
      if (mounted) setState(() => _batchWorking = false);
    }
  }

  Future<void> _showCreateFolderDialog(BuildContext context) async {
    final state = context.read<FolderShelfBloc>().state;
    final name = await _showShelfFolderNameDialog(
      context,
      title: t.bookshelf.newFolder,
      siblings: ComicFolderService.listChildFolders(
        state.currentPath,
        _folderTypeOf(state.mode),
      ).map((f) => f.name).toSet(),
    );
    if (name != null && context.mounted) {
      context.read<FolderShelfBloc>().add(FolderShelfCreateFolder(name));
    }
  }

  void _showFolderActions(
    BuildContext context,
    ComicFolder folder,
    String folderPath,
    Offset position,
  ) {
    final anchor = Rect.fromCenter(center: position, width: 1, height: 1);

    final target = FolderCoverService.comic(
      folder,
      canRun: () => mounted && widget.isActive && !_batchWorking,
    );
    final imageRevision = LocalAppearanceImages.instance.revisionOf(target.key);
    FluentPopupMenu.show<String>(
      context: context,
      anchor: anchor,
      items: [
        FluentPopupMenuItem(
          value: 'rename',
          leading: const Icon(Icons.drive_file_rename_outline),
          title: Text(t.common.rename),
        ),
        FluentPopupMenuItem(
          value: 'move',
          leading: const Icon(Icons.drive_file_move_outline),
          title: Text(t.bookshelf.moveTo),
        ),
        for (final e in folderCoverOptions(target).entries)
          FluentPopupMenuItem(
            value: 'folder-cover.${e.key}',
            leading: const Icon(Icons.image_outlined),
            title: Text(e.value),
          ),
        FluentPopupMenuItem(
          value: 'delete',
          leading: const Icon(Icons.delete_outline),
          title: Text(t.common.delete),
        ),
      ],
      onSelected: (value) {
        if (value.startsWith('folder-cover.')) {
          unawaited(
            runFolderCoverAction(
              context,
              target,
              value.substring('folder-cover.'.length),
              expectedRevision: imageRevision,
            ),
          );
        } else {
          _runFolderCommand(context, folder, folderPath, value);
        }
      },
    );
  }

  void _runFolderCommand(
    BuildContext context,
    ComicFolder folder,
    String folderPath,
    String value,
  ) {
    if (!mounted || !widget.isActive || _batchWorking) return;
    switch (value) {
      case 'rename':
        _showRenameFolderDialog(context, folder, folderPath);
      case 'move':
        unawaited(
          _showTargetFolderDialog(
            context,
            selectedFolderPaths: {folderPath},
            onConfirmed: (targets) {
              context.read<FolderShelfBloc>().add(
                FolderShelfMoveSelected(
                  targets,
                  sourceFolderPaths: {folderPath},
                ),
              );
            },
          ),
        );
      case 'delete':
        _confirmDeleteSingleFolder(context, folderPath);
    }
  }

  Future<void> _confirmDeleteSingleFolder(
    BuildContext context,
    String path,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(t.bookshelf.confirmDeleteFolderTitle),
          content: Text(
            shelfDeletePrompt(
              mode: context.read<FolderShelfBloc>().state.mode,
              folders: 1,
              comics: 0,
            ),
          ),
          scrollable: true,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(t.common.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(t.common.delete),
            ),
          ],
        );
      },
    );
    if (confirmed == true && context.mounted) {
      context.read<FolderShelfBloc>().add(FolderShelfDeleteFolder(path));
    }
  }

  Future<void> _showRenameFolderDialog(
    BuildContext context,
    ComicFolder folder,
    String folderPath,
  ) async {
    final slash = folderPath.lastIndexOf('/');
    final parent = slash <= 0 ? '' : folderPath.substring(0, slash);
    final state = context.read<FolderShelfBloc>().state;
    final name = await _showShelfFolderNameDialog(
      context,
      title: t.common.rename,
      initialName: folder.name,
      siblings: ComicFolderService.listChildFolders(
        parent,
        _folderTypeOf(state.mode),
      ).where((f) => f.syncId != folder.syncId).map((f) => f.name).toSet(),
    );
    if (name != null && context.mounted) {
      context.read<FolderShelfBloc>().add(
        FolderShelfRenameFolder(folderPath, name),
      );
    }
  }

  Widget _withHistoryTime(
    ComicSimplifyEntryInfo info,
    bool enabled,
    Widget caption,
  ) {
    final statistics = info.detailViewCount > 0
        ? t.comicEntry.views(count: info.detailViewCount)
        : info.detailPopularity > 0
        ? t.comicList.popularity(count: info.detailPopularity)
        : '';
    if (!enabled) {
      if (_view == BookshelfContentView.list &&
          caption is BookshelfCardCaption) {
        return BookshelfDetailedCaption(
          title: caption.title,
          source: caption.subtitle,
          metadata: info.detailMetadata,
          description: info.description,
          statistics: statistics,
        );
      }
      return caption;
    }
    // The shelf's lightweight cover record intentionally has no private/history
    // fields. Read only this visible row's local history; never fetch metadata.
    final source = info.source.trim().isNotEmpty
        ? info.source.trim()
        : info.from.trim();
    final query = objectbox.unifiedHistoryBox
        .query(
          UnifiedComicHistory_.source
              .equals(source)
              .and(UnifiedComicHistory_.comicId.equals(info.id))
              .and(UnifiedComicHistory_.deleted.equals(false)),
        )
        .build();
    try {
      final history = query.findFirst();
      if (history == null && caption is BookshelfCardCaption) {
        return BookshelfDetailedCaption(
          title: caption.title,
          source: caption.subtitle,
          metadata: info.detailMetadata,
          description: info.description,
          statistics: statistics,
        );
      }
      if (history == null) return caption;
      final item = unifiedComicFromUnifiedHistory(history);
      final original = caption as BookshelfCardCaption;
      return BookshelfDetailedCaption(
        title: original.title,
        source: original.subtitle,
        metadata: info.detailMetadata,
        description: info.description,
        statistics: statistics,
        progress: shelfReadingPosition(
          history.title,
          history.chapterTitle,
          history.pageIndex,
        ),
        time: comicLastReadTimestamp(item).isEmpty
            ? ''
            : t.comicEntry.lastReadAt(time: comicLastReadTimestamp(item)),
      );
    } finally {
      query.close();
    }
  }

  static ComicEntryType _comicEntryTypeOf(ShelfPageMode mode) {
    return switch (mode) {
      ShelfPageMode.favorite => ComicEntryType.favorite,
      ShelfPageMode.history => ComicEntryType.history,
      ShelfPageMode.download => ComicEntryType.download,
    };
  }

  static String _normalizeSearchText(String text) {
    final lower = text.trim().toLowerCase();
    if (lower.isEmpty) return '';
    try {
      return t2s(lower);
    } catch (_) {
      return lower;
    }
  }

  void _showComicActions(
    BuildContext context,
    ComicSimplifyEntryInfo info,
    Offset position,
  ) {
    final anchor = Rect.fromCenter(center: position, width: 1, height: 1);

    FluentPopupMenu.show<String>(
      context: context,
      anchor: anchor,
      items: [
        FluentPopupMenuItem(
          value: 'multi_select',
          leading: const Icon(Icons.checklist),
          title: Text(t.bookshelf.manage),
        ),
        FluentPopupMenuItem(
          value: 'delete',
          leading: const Icon(Icons.delete_outline),
          title: Text(t.common.delete),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'multi_select':
            context.read<FolderShelfBloc>().add(
              FolderShelfToggleComicSelection('${info.from.trim()}:${info.id}'),
            );
          case 'delete':
            _confirmRemoveComic(context, info);
        }
      },
    );
  }

  Future<void> _confirmRemoveComic(
    BuildContext context,
    ComicSimplifyEntryInfo info,
  ) async {
    final scope = context.read<FolderShelfBloc>().state;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(t.bookshelf.confirmRemoveComicTitle),
          content: Text(
            scope.facets.isActive ||
                    (scope.search?.keyword.trim().isNotEmpty ?? false)
                ? t.bookshelf.facets.removeFiltered(title: info.title)
                : t.bookshelf.confirmRemoveComicContent(title: info.title),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(t.common.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(t.common.remove),
            ),
          ],
        );
      },
    );
    if (confirmed == true && context.mounted) {
      final uniqueKey = '${info.from.trim()}:${info.id}';
      final state = context.read<FolderShelfBloc>().state;
      if (state.mode != scope.mode ||
          state.currentPath != scope.currentPath ||
          state.facets != scope.facets ||
          state.search != scope.search ||
          !state.comics.any(
            (row) => '${row.from.trim()}:${row.id}' == uniqueKey,
          )) {
        return;
      }
      // 历史无 ComicLink：直接软删除历史本体（与旧 LocalShelfPage 一致）。
      if (state.mode == ShelfPageMode.history) {
        final index = loadComicShelfFacetIndex(type: ComicFolderType.history);
        for (final storedKey in comicFacetRecordKeys(index, uniqueKey)) {
          final query = objectbox.unifiedHistoryBox
              .query(UnifiedComicHistory_.uniqueKey.equals(storedKey))
              .build();
          try {
            for (final history in query.find()) {
              await ReaderHistoryService.instance.deleteHistoryRecord(history);
            }
          } finally {
            query.close();
          }
        }
        if (context.mounted) {
          context.read<FolderShelfBloc>().add(const FolderShelfLoadRequested());
        }
        return;
      }
      final folderType = switch (state.mode) {
        ShelfPageMode.favorite => ComicFolderType.favorite,
        ShelfPageMode.download => ComicFolderType.download,
        ShelfPageMode.history => ComicFolderType.history,
      };
      removeComicFromFacetScope(
        uniqueKey,
        _effectiveShelfSelection(state),
        currentFolder: state.currentPath,
        type: folderType,
      );
      context.read<FolderShelfBloc>().add(const FolderShelfLoadRequested());
    }
  }
}

Future<String?> _showShelfFolderNameDialog(
  BuildContext context, {
  required String title,
  required Set<String> siblings,
  String initialName = '',
}) => showDialog<String>(
  context: context,
  builder: (_) => _ShelfFolderNameDialog(
    title: title,
    siblings: siblings,
    initialName: initialName,
  ),
);

class _ShelfFolderNameDialog extends StatefulWidget {
  const _ShelfFolderNameDialog({
    required this.title,
    required this.siblings,
    required this.initialName,
  });
  final String title, initialName;
  final Set<String> siblings;
  @override
  State<_ShelfFolderNameDialog> createState() => _ShelfFolderNameDialogState();
}

class _ShelfFolderNameDialogState extends State<_ShelfFolderNameDialog> {
  late final _controller = TextEditingController(text: widget.initialName);
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    scrollable: true,
    content: Form(
      key: _form,
      child: TextFormField(
        key: const ValueKey('shelf-folder-name.input'),
        controller: _controller,
        autofocus: true,
        maxLength: 60,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(labelText: t.bookshelf.folderName),
        validator: (raw) {
          final name = raw?.trim() ?? '';
          if (name.isEmpty) return t.bookshelf.folderNameEmpty;
          if (name.contains('/')) return t.bookshelf.folderNameSlash;
          if (widget.siblings.contains(name)) {
            return t.bookshelf.folderNameExists;
          }
          return null;
        },
        onFieldSubmitted: (_) => _submit(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(t.common.cancel),
      ),
      FilledButton(
        key: const ValueKey('shelf-folder-name.confirm'),
        onPressed: _submit,
        child: Text(t.common.ok),
      ),
    ],
  );
}

Future<void> _showTargetFolderDialog(
  BuildContext context, {
  Set<String>? selectedFolderPaths,
  bool multiple = false,
  required ValueChanged<Set<String>> onConfirmed,
}) async {
  final bloc = context.read<FolderShelfBloc>(),
      state = context.read<FolderShelfBloc>().state;
  final allFolders = ComicFolderService.listAllFolders(
    _folderTypeOf(state.mode),
  );
  final syncIdMap = {for (final folder in allFolders) folder.syncId: folder};
  final pathMap = {
    for (final folder in allFolders)
      folder.syncId: ComicFolderService.folderPath(
        folder,
        syncIdMap: syncIdMap,
      ),
  };
  final forbidden = <String>{};
  // A filtered result can include works archived outside the visible directory.
  // In that case the visible directory is a valid destination, including root.
  final pathsInScope =
      state.mode != ShelfPageMode.history &&
          (state.facets.isActive ||
              (state.search?.keyword.trim().isNotEmpty ?? false))
      ? comicFacetPathsInScope(
          loadComicShelfFacetIndex(type: _folderTypeOf(state.mode)),
          _effectiveShelfSelection(state),
          currentFolder: state.currentPath,
        )
      : const <String, Set<String>>{};
  final canTargetCurrent = state.selectedComicKeys.any(
    (key) => (pathsInScope[key] ?? const <String>{}).any(
      (path) => path != state.currentPath,
    ),
  );
  for (final path in selectedFolderPaths ?? state.selectedFolderPaths) {
    final folder = allFolders.firstWhereOrNull(
      (f) => pathMap[f.syncId] == path,
    );
    if (folder != null) {
      _collectForbiddenSyncIds(folder.syncId, allFolders, forbidden);
    }
  }
  var createdFolder = false;
  try {
    await showDialog<void>(
      context: context,
      builder: (_) => BookshelfFolderPicker(
        title: multiple ? t.bookshelf.copyTo : t.bookshelf.moveTo,
        multiple: multiple,
        initialCreateParent: state.currentPath,
        choices: [
          BookshelfFolderChoice(
            path: '',
            name: t.common.root,
            parentPath: '',
            selectable: state.currentPath.isNotEmpty || canTargetCurrent,
          ),
          for (final folder in allFolders)
            BookshelfFolderChoice(
              path: pathMap[folder.syncId]!,
              name: folder.name,
              parentPath: pathMap[folder.parentSyncId] ?? '',
              selectable:
                  (pathMap[folder.syncId] != state.currentPath ||
                      canTargetCurrent) &&
                  !forbidden.contains(folder.syncId),
              browsable: !forbidden.contains(folder.syncId),
            ),
        ],
        onCreate: (parent, name) async {
          final folder = ComicFolderService.createFolder(
            parent,
            name,
            _folderTypeOf(state.mode),
          );
          createdFolder = true;
          return BookshelfFolderChoice(
            path: ComicFolderService.folderPath(folder),
            name: folder.name,
            parentPath: parent,
          );
        },
        onConfirmed: onConfirmed,
      ),
    );
  } finally {
    if (createdFolder && context.mounted && !bloc.isClosed) {
      bloc.add(const FolderShelfLoadRequested());
    }
  }
}

Map<String, ComicFolder> _buildSyncIdMap(ShelfPageMode mode) {
  final allFolders = ComicFolderService.listAllFolders(_folderTypeOf(mode));
  return {for (final folder in allFolders) folder.syncId: folder};
}

void _collectForbiddenSyncIds(
  String syncId,
  List<ComicFolder> allFolders,
  Set<String> result,
) {
  if (!result.add(syncId)) return;
  for (final child in allFolders) {
    if (child.parentSyncId == syncId) {
      _collectForbiddenSyncIds(child.syncId, allFolders, result);
    }
  }
}

ShelfFacetSelection _effectiveShelfSelection(FolderShelfState state) =>
    !state.facets.isActive && (state.search?.keyword.trim().isNotEmpty ?? false)
    ? const ShelfFacetSelection(scope: ShelfFacetScope.all)
    : state.facets;

ComicFolderType _folderTypeOf(ShelfPageMode mode) {
  return switch (mode) {
    ShelfPageMode.favorite => ComicFolderType.favorite,
    ShelfPageMode.download => ComicFolderType.download,
    ShelfPageMode.history => ComicFolderType.history,
  };
}

Future<void> _importComic(BuildContext context) async {
  String? importRoot;
  String? cleanupDir;
  try {
    if (Platform.isAndroid) {
      importRoot = await pickComicZipAndroid();
      if (importRoot != null) {
        cleanupDir = p.dirname(p.dirname(importRoot));
      }
    } else {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'zip',
            extensions: ['zip'],
            uniformTypeIdentifiers: ['public.zip-archive'],
          ),
        ],
      );
      importRoot = file?.path;
    }
    if (importRoot == null || importRoot.trim().isEmpty) return;

    if (!context.mounted) return;
    showSuccessToast(t.bookshelf.importStarted);

    final result = await importComicFromZip(
      importRoot,
      cleanupDir: cleanupDir,
      onConfirmOverwrite: (title) =>
          _confirmComicImportOverwrite(context, title),
    );

    if (!context.mounted) return;
    showSuccessToast(t.bookshelf.importCompleted(title: result.title));
    context.read<FolderShelfBloc>().add(const FolderShelfLoadRequested());
  } on ComicImportCancelledException catch (_) {
    if (!context.mounted) return;
    showErrorToast(t.common.cancelled);
  } catch (e) {
    if (!context.mounted) return;
    showErrorToast(t.error.importFailed(error: e.toString()));
  }
}

Future<bool> _confirmComicImportOverwrite(
  BuildContext context,
  String title,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(t.bookshelf.comicExists),
      content: Text(t.bookshelf.confirmOverwriteImport(title: title)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(t.common.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(t.common.overwrite),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<void> _batchExportSelected(
  BuildContext context,
  FolderShelfState state,
) async {
  final selectedComics = state.comics
      .where(
        (c) => state.selectedComicKeys.contains('${c.from.trim()}:${c.id}'),
      )
      .toList();

  if (selectedComics.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t.bookshelf.noExportableComics)));
    return;
  }

  try {
    final success = await batchExportComics(
      context: context,
      comics: selectedComics,
    );
    if (!context.mounted) return;
    showSuccessToast(
      t.bookshelf.batchExportCompleted(
        success: success,
        total: selectedComics.length,
      ),
    );
    context.read<FolderShelfBloc>().add(const FolderShelfExitSelectionMode());
  } catch (e) {
    if (!context.mounted) return;
    showErrorToast(t.bookshelf.batchExportFailed(error: e.toString()));
  }
}

Future<void> _confirmDeleteSelected(BuildContext context) async {
  final bloc = context.read<FolderShelfBloc>();
  final selection = bloc.state;
  if (!selection.hasSelection) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(t.bookshelf.confirmDeleteSelectedTitle),
        content: Text(
          selection.facets.isActive
              ? t.bookshelf.facets.removeFilteredBatch
              : shelfDeletePrompt(
                  mode: selection.mode,
                  folders: selection.selectedFolderPaths.length,
                  comics: selection.selectedComicKeys.length,
                ),
        ),
        scrollable: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.common.delete),
          ),
        ],
      );
    },
  );
  if (confirmed == true && context.mounted) {
    final current = bloc.state;
    if (current.mode != selection.mode ||
        current.facets != selection.facets ||
        current.search != selection.search ||
        current.currentPath != selection.currentPath ||
        !const SetEquality<String>().equals(
          current.selectedFolderPaths,
          selection.selectedFolderPaths,
        ) ||
        !const SetEquality<String>().equals(
          current.selectedComicKeys,
          selection.selectedComicKeys,
        )) {
      showActionFeedback(context, t.bookshelf.selectionChanged);
      return;
    }
    bloc.add(const FolderShelfDeleteSelected());
  }
}

// Selection sets are consumed by the row selectors and action bar, not by the
// enclosing grid. Keep all data/path/loading changes visible.
bool _shelfStructureChanged(
  FolderShelfState previous,
  FolderShelfState current,
) =>
    previous.currentPath != current.currentPath ||
    previous.folders != current.folders ||
    previous.folderCounts != current.folderCounts ||
    previous.comics != current.comics ||
    previous.comicSearchTexts != current.comicSearchTexts ||
    previous.facets != current.facets ||
    previous.comicFolderLabels != current.comicFolderLabels ||
    previous.search != current.search ||
    previous.isLoading != current.isLoading ||
    previous.error != current.error ||
    previous.sortAscending != current.sortAscending ||
    previous.selectionMode != current.selectionMode;

bool _sameShelfRows(FolderShelfState before, FolderShelfState after) {
  const equality = DeepCollectionEquality();
  return equality.equals(before.comics, after.comics) &&
      equality.equals(before.folderCounts, after.folderCounts) &&
      equality.equals(before.comicSearchTexts, after.comicSearchTexts) &&
      equality.equals(before.comicFolderLabels, after.comicFolderLabels) &&
      equality.equals(
        before.folders.map((folder) => folder.toJson()).toList(),
        after.folders.map((folder) => folder.toJson()).toList(),
      );
}
