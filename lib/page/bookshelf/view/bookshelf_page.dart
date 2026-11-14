import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_navigation_bar.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/page/search/widget/search_keyboard.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/widget/keyword_scope_menu.dart';
import 'dart:async';
import 'dart:ui' show SemanticsRole;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart' show listEquals, mapEquals;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/cubit/plugin_registry_cubit.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/page/bookshelf/bookshelf.dart';
import 'package:zephyr/page/bookshelf/service/video_bookshelf_index.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_scope_controls.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_actions_scope.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_header_slots.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_selection_toolbar.dart';
import 'package:zephyr/page/bookshelf/service/bookshelf_source_preferences.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_source_manager.dart';
import 'package:zephyr/page/bookshelf/widgets/video_bookshelf_pane.dart';
import 'package:zephyr/page/search/widget/search_input_dialog.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/util/debouncer.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';

@RoutePage()
class BookshelfPage extends StatelessWidget {
  const BookshelfPage({super.key});

  @override
  Widget build(BuildContext context) {
    final setting = context.read<GlobalSettingCubit>().state.bookshelfSetting;
    return BlocProvider(
      create: (_) => BookshelfSearchCubit(
        favorite: SearchStatusState(
          sort: setting.rememberFavoriteSort ? setting.favoriteSort : 'dd',
        ),
        history: SearchStatusState(
          sort: setting.rememberHistorySort ? setting.historySort : 'dd',
        ),
      ),
      child: _BookshelfPageContent(initialIndex: setting.homePageIndex),
    );
  }
}

class _BookshelfPageContent extends StatefulWidget {
  const _BookshelfPageContent({required this.initialIndex});
  final int initialIndex;
  @override
  State<_BookshelfPageContent> createState() => _BookshelfPageContentState();
}

class _BookshelfPageContentState extends State<_BookshelfPageContent> {
  static const _mediaKey = 'breeze.bookshelf.media.v1';
  static const _videoSortKey = 'breeze.bookshelf.video.sorts.v2';
  static const _legacyVideoSortKey = 'breeze.bookshelf.video.sorts.v1';
  static const _recordModes = [ShelfPageMode.favorite, ShelfPageMode.history];
  late int _currentIndex;
  int? _pendingHomeSection;
  late final _comicPages = PageController(
    initialPage: _currentIndex,
    keepPage: false,
  );
  late final _videoPages = PageController(
    initialPage: _currentIndex,
    keepPage: false,
  );
  bool _syncingRecordPanes = false;
  final _videoSearch = BookshelfSearchCubit();
  final _videoSortTouched = <ShelfPageMode>{};
  final _keywordScopes = <(bool, ShelfPageMode), KeywordSearchScope>{};
  KeywordSearchScope _keywordScope(bool video, ShelfPageMode mode) =>
      _keywordScopes[(video, mode)] ?? KeywordSearchScope.all;
  final _comicRefresh = [0, 0, 0];
  final _comicSelecting = [false, false, false],
      _videoSelecting = [false, false, false];
  final _searchFocusNode = FocusNode();
  final _header = BookshelfHeaderController();
  final _keywordDebouncer = Debouncer(milliseconds: 500);
  (BookshelfSearchCubit, ShelfPageMode, String)? _pendingKeyword;
  Map<String, String> _comicSources = {}, _videoSources = {};
  Set<String>? _comicRecordSources;
  late final StreamSubscription<List<Type>> _comicRecordsWatch;
  bool _comicSourcesUpdateScheduled = false;
  final _sourcePreferenceStore = BookshelfSourcePreferenceStore();
  final _sourcePreferences = {
    for (final medium in const [
      BookshelfSourceMedium.comic,
      BookshelfSourceMedium.video,
    ])
      medium: BookshelfSourcePreferences(),
  };
  bool _sourcePreferencesReady = false, _sourceManagerOpen = false;
  bool _sourcePreferencesFailed = false, _sourceInventoryFailed = false;
  bool get _sourceControlsReady => _sourcePreferencesReady && !_sourcesLoading;
  bool _showVideos = false,
      _mediaReady = false,
      _mediaTouched = false,
      _sourcesLoading = true,
      _isSearchExpanded = false;
  int _sourceEpoch = 0, _preferencesEpoch = 0;
  BookshelfSearchCubit get _comicSearch => context.read<BookshelfSearchCubit>();
  BookshelfSearchCubit get _activeSearch =>
      _showVideos ? _videoSearch : _comicSearch;
  bool get _scopeLocked =>
      _sourceManagerOpen ||
      (_showVideos ? _videoSelecting : _comicSelecting)[_currentIndex];
  bool get _showReturnToTop =>
      !_isSearchExpanded && !_searchFocusNode.hasFocus && !_scopeLocked;
  BookshelfSourceMedium get _sourceMedium =>
      _showVideos ? BookshelfSourceMedium.video : BookshelfSourceMedium.comic;
  ShelfPageMode get _mode => ShelfPageMode.values[_currentIndex];

  @override
  void initState() {
    super.initState();
    PortablePreferences.changes.addListener(_portableRestored);
    // Downloads have one home in the bottom navigation. Old saved index 2
    // must not silently select a different bookshelf category.
    _currentIndex = widget.initialIndex == 1 ? 1 : 0;
    VideoBookshelfIndex.changes.addListener(_loadSources);
    _comicRecordsWatch = objectbox.store.entityChanges.listen(
      _comicRecordsChanged,
    );
    _searchFocusNode.addListener(_searchFocusChanged);
    unawaited(_restorePreferences());
    unawaited(_loadSources());
  }

  @override
  void dispose() {
    _sourceEpoch++;
    PortablePreferences.changes.removeListener(_portableRestored);
    VideoBookshelfIndex.changes.removeListener(_loadSources);
    unawaited(_comicRecordsWatch.cancel());
    _comicPages.dispose();
    _videoPages.dispose();
    _header.dispose();
    _searchFocusNode
      ..removeListener(_searchFocusChanged)
      ..dispose();
    _keywordDebouncer.cancel();
    unawaited(_videoSearch.close());
    super.dispose();
  }

  void _portableRestored() {
    if (mounted) unawaited(_restorePreferences());
  }

  Future<void> _restorePreferences() async {
    final epoch = ++_preferencesEpoch;
    if (_sourcePreferencesFailed) {
      setState(() => _sourcePreferencesFailed = false);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || epoch != _preferencesEpoch) return;
      var sorts = prefs.getStringList(_videoSortKey);
      final old = prefs.getStringList(_legacyVideoSortKey);
      if (sorts == null && old != null && old.length == 3) {
        final setting = context
            .read<GlobalSettingCubit>()
            .state
            .bookshelfSetting;
        sorts = [
          if (setting.rememberFavoriteSort && old[0] == 'da') 'da' else 'dd',
          if (setting.rememberHistorySort && old[1] == 'da') 'da' else 'dd',
        ];
        // Read the shared legacy flags once. New video choices are independent
        // of the comic flags, including the first comic sort after upgrade.
        await prefs.setStringList(_videoSortKey, sorts);
        if (!mounted || epoch != _preferencesEpoch) return;
      }
      if (sorts != null && sorts.length == _recordModes.length) {
        for (final mode in _recordModes) {
          if (!_videoSortTouched.contains(mode)) {
            _videoSearch.setSort(mode, sorts[mode.index] == 'da' ? 'da' : 'dd');
          }
        }
      }
      if (!_mediaTouched || !_mediaReady) {
        setState(() {
          if (!_mediaTouched) {
            final showVideos = prefs.getString(_mediaKey) == 'video';
            if (showVideos != _showVideos) {
              _header.changePane();
              _showVideos = showVideos;
            }
          }
          _mediaReady = true;
        });
      }
      const media = [BookshelfSourceMedium.comic, BookshelfSourceMedium.video];
      final sourcePreferences = await Future.wait([
        for (final medium in media) _sourcePreferenceStore.read(medium),
      ]);
      if (!mounted || epoch != _preferencesEpoch) return;
      setState(() {
        for (final medium in media) {
          _sourcePreferences[medium] = sourcePreferences[medium.index];
          _clearHiddenSourceScopes(medium, sourcePreferences[medium.index]);
        }
        _sourcePreferencesReady = true;
      });
    } catch (_) {
      if (mounted && epoch == _preferencesEpoch) {
        setState(() {
          _mediaReady = true;
          _sourcePreferencesFailed = !_sourcePreferencesReady;
        });
      }
    }
  }

  Future<void> _loadSources() async {
    final epoch = ++_sourceEpoch;
    if (_sourceInventoryFailed) {
      setState(() => _sourceInventoryFailed = false);
    }
    try {
      final videos = await VideoBookshelfIndex.recordSourceNames();
      if (!mounted || epoch != _sourceEpoch) return;
      _updateSourceNames(videos, finishedLoading: true);
    } catch (_) {
      if (mounted && epoch == _sourceEpoch && _sourcesLoading) {
        setState(() => _sourceInventoryFailed = true);
      }
    }
  }

  void _comicRecordsChanged(List<Type> types) {
    if (!types.contains(UnifiedComicFavorite) &&
        !types.contains(UnifiedComicHistory) &&
        !types.contains(UnifiedComicDownload)) {
      return;
    }
    _comicRecordSources = null;
    if (_comicSourcesUpdateScheduled) return;
    _comicSourcesUpdateScheduled = true;
    scheduleMicrotask(() {
      _comicSourcesUpdateScheduled = false;
      if (mounted && !_sourcesLoading) _updateSourceNames(_videoSources);
    });
  }

  void _updateSourceNames(
    Map<String, String> videos, {
    bool finishedLoading = false,
  }) {
    final comics = <String, String>{};
    for (final plugin in PluginRegistryService.I.sortPlugins(
      context.read<PluginRegistryCubit>().state.values.where(
        (p) => !p.isDeleted,
      ),
    )) {
      if (!videos.containsKey(plugin.uuid)) {
        comics[plugin.uuid] = _sourceTitle(plugin.uuid);
      }
    }
    // Local records remain reachable when their plugin is disabled or removed.
    for (final source in _comicRecordSources ??= _readComicRecordSources()) {
      if (source.isNotEmpty) {
        comics.putIfAbsent(source, () => _sourceTitle(source));
      }
    }
    final loading = _sourcesLoading && !finishedLoading;
    if (loading == _sourcesLoading &&
        _sameSourceOrder(comics, _comicSources) &&
        _sameSourceOrder(videos, _videoSources)) {
      return;
    }
    setState(() {
      _comicSources = comics;
      _videoSources = videos;
      _sourcesLoading = loading;
    });
  }

  bool _sameSourceOrder(Map<String, String> left, Map<String, String> right) =>
      mapEquals(left, right) &&
      listEquals(left.keys.toList(), right.keys.toList());

  Set<String> _readComicRecordSources() => {
    ..._readDistinctSources(
      objectbox.unifiedFavoriteBox
          .query(UnifiedComicFavorite_.deleted.equals(false))
          .build(),
      UnifiedComicFavorite_.source,
    ),
    ..._readDistinctSources(
      objectbox.unifiedHistoryBox
          .query(UnifiedComicHistory_.deleted.equals(false))
          .build(),
      UnifiedComicHistory_.source,
    ),
    ..._readDistinctSources(
      objectbox.unifiedDownloadBox
          .query(UnifiedComicDownload_.deleted.equals(false))
          .build(),
      UnifiedComicDownload_.source,
    ),
  };

  List<String> _readDistinctSources<T>(
    Query<T> query,
    QueryStringProperty<T> source,
  ) {
    try {
      final property = query.property(source);
      try {
        property
          ..caseSensitive = true
          ..distinct = true;
        return property.find();
      } finally {
        property.close();
      }
    } finally {
      query.close();
    }
  }

  void _searchFocusChanged() {
    if (mounted) setState(() {});
  }

  String _sourceTitle(String id) {
    final name =
        PluginRegistryService.I
            .getCachedPluginInfo(id)?['name']
            ?.toString()
            .trim() ??
        '';
    final title = name.isEmpty ? id : name;
    return PluginRegistryService.I.getByUuid(id)?.isDeleted == false
        ? title
        : '$title · ${t.pluginLifecycle.notInstalled}';
  }

  Map<String, String> _allLabelSources(BookshelfSourceMedium medium) {
    final values = {
      ...(medium == BookshelfSourceMedium.video
          ? _videoSources
          : _comicSources),
    };
    final cubit = medium == BookshelfSourceMedium.video
        ? _videoSearch
        : _comicSearch;
    for (final mode in ShelfPageMode.values) {
      for (final id in cubit.state.stateOf(mode).sources) {
        values.putIfAbsent(id, () => _sourceTitle(id));
      }
    }
    return values;
  }

  void _clearHiddenSourceScopes(
    BookshelfSourceMedium medium,
    BookshelfSourcePreferences preferences,
  ) {
    final cubit = medium == BookshelfSourceMedium.video
        ? _videoSearch
        : _comicSearch;
    for (final mode in ShelfPageMode.values) {
      if (cubit.state.stateOf(mode).sources.any(preferences.hidden.contains)) {
        cubit.setSources(mode, []);
        if (medium == BookshelfSourceMedium.comic) _comicRefresh[mode.index]++;
      }
    }
  }

  Future<void> _manageSources() async {
    if (!mounted || _scopeLocked || !_sourceControlsReady) return;
    _flushPendingKeyword();
    _searchFocusNode.unfocus();
    final medium = _sourceMedium;
    setState(() => _sourceManagerOpen = true);
    try {
      await showBookshelfSourceManager(
        context: context,
        sources: _allLabelSources(medium),
        useDisplayNames: true,
        initial: _sourcePreferences[medium]!,
        onSave: (next) async {
          await _sourcePreferenceStore.save(medium, next);
          if (!mounted) return;
          setState(() {
            _sourcePreferences[medium] = next;
            _clearHiddenSourceScopes(medium, next);
          });
        },
      );
    } finally {
      if (mounted) {
        setState(() => _sourceManagerOpen = false);
        _applyPendingHomeSection();
      }
    }
  }

  void _selectMedia(String media) {
    if (_scopeLocked || _showVideos == (media == 'video')) return;
    _flushPendingKeyword();
    _searchFocusNode.unfocus();
    setState(() {
      _header.changePane();
      _showVideos = media == 'video';
      _mediaTouched = true;
      _isSearchExpanded = false;
    });
    _syncRecordPanes();
    unawaited(
      SharedPreferences.getInstance().then(
        (p) => p.setString(_mediaKey, media),
      ),
    );
  }

  void _selectRecords(int index) {
    if (_currentIndex == index) return;
    _flushPendingKeyword();
    _searchFocusNode.unfocus();
    setState(() {
      _header.changePane();
      _currentIndex = index;
    });
    _syncRecordPanes();
  }

  PageController _recordsController(bool video) =>
      video ? _videoPages : _comicPages;

  void _syncRecordPanes() {
    // Taps change the data scope in place. Only a horizontal gesture moves
    // the visible PageView, and both retained media panes share its scope.
    _syncingRecordPanes = true;
    try {
      for (final pages in [_comicPages, _videoPages]) {
        if (pages.hasClients &&
            (pages.page != _currentIndex ||
                pages.position.isScrollingNotifier.value)) {
          pages.jumpToPage(_currentIndex);
        }
      }
    } finally {
      _syncingRecordPanes = false;
    }
  }

  void _selectionChanged(bool video, int index, bool selecting) {
    if (!mounted) return;
    final values = video ? _videoSelecting : _comicSelecting;
    if (values[index] == selecting) return;
    if (selecting) {
      _flushPendingKeyword();
      _searchFocusNode.unfocus();
    }
    setState(() => values[index] = selecting);
    if (!selecting) _applyPendingHomeSection();
  }

  void _applyPendingHomeSection() {
    final index = _pendingHomeSection;
    if (index == null || _scopeLocked || _isSearchExpanded) return;
    _pendingHomeSection = null;
    _selectRecords(index);
  }

  Widget _recordViewport({
    required bool video,
    required List<Widget> children,
  }) => NotificationListener<ScrollEndNotification>(
    onNotification: (notification) {
      final metrics = notification.metrics;
      if (notification.depth == 0 &&
          _showVideos == video &&
          !_syncingRecordPanes &&
          metrics is PageMetrics) {
        final page = metrics.page;
        if (page != null) _selectRecords(page.round());
      }
      return false;
    },
    child: PageView(
      controller: _recordsController(video),
      physics: _scopeLocked
          ? const NeverScrollableScrollPhysics()
          : const ClampingScrollPhysics(),
      children: [
        for (final child in children)
          Semantics(role: SemanticsRole.tabPanel, child: child),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) =>
      BlocListener<GlobalSettingCubit, GlobalSettingState>(
        listenWhen: (before, after) =>
            before.bookshelfSetting.homePageIndex !=
            after.bookshelfSetting.homePageIndex,
        listener: (_, state) {
          _pendingHomeSection = state.bookshelfSetting.homePageIndex == 1
              ? 1
              : 0;
          _applyPendingHomeSection();
        },
        child: _mediaReady
            ? _buildContent(context)
            : const Scaffold(body: Center(child: BookshelfLoadingView())),
      );

  Widget _buildContent(
    BuildContext context,
  ) => BlocListener<PluginRegistryCubit, Map<String, PluginRuntimeState>>(
    listener: (_, _) {
      unawaited(_loadSources());
      _refreshAll();
    },
    child: Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: CollectionToolbarMetrics.sourceContentInset,
        scrolledUnderElevation: 0,
        toolbarHeight: _headerHeight(context),
        title: _buildHeader(),
      ),
      body: Column(
        children: [
          _buildMediaRow(),
          _buildScopeRow(),
          Expanded(
            child: _withActions(
              IndexedStack(
                index: _showVideos ? 1 : 0,
                children: [
                  BlocProvider.value(
                    value: _comicSearch,
                    child: _recordViewport(
                      video: false,
                      children: [
                        for (final mode in _recordModes)
                          FolderShelfPage(
                            key: ValueKey('comic-shelf.${mode.name}'),
                            mode: mode,
                            keywordScope: _keywordScope(false, mode),
                            sourceNames: _comicSources,
                            refreshSignal: _comicRefresh[mode.index],
                            isActive:
                                !_showVideos && _currentIndex == mode.index,
                            showReturnToTop: _showReturnToTop,
                            onSelectionChanged: (value) =>
                                _selectionChanged(false, mode.index, value),
                          ),
                      ],
                    ),
                  ),
                  BlocProvider.value(
                    value: _videoSearch,
                    child:
                        BlocBuilder<BookshelfSearchCubit, BookshelfSearchState>(
                          builder: (context, searches) => _recordViewport(
                            video: true,
                            children: [
                              for (final mode in _recordModes)
                                VideoBookshelfPane(
                                  key: ValueKey('video-shelf.${mode.name}'),
                                  mode: mode,
                                  keywordScope: _keywordScope(true, mode),
                                  search: searches.stateOf(mode),
                                  isActive:
                                      _showVideos &&
                                      _currentIndex == mode.index,
                                  showReturnToTop: _showReturnToTop,
                                  onSelectionChanged: (value) =>
                                      _selectionChanged(
                                        true,
                                        mode.index,
                                        value,
                                      ),
                                ),
                            ],
                          ),
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _shelfSelector({
    Key? key,
    required Map<String, String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) => !AppInterfaceStyleScope.usesSystem(context)
      ? BreezeSectionSelector(
          key: key,
          options: options,
          selected: selected,
          enabled: !_scopeLocked,
          onSelected: onSelected,
        )
      : VideoControlAppearance(
          systemControls: usesNativeSourceChrome(context),
          child: NativeVideoSegmentedControl(
            key: key,
            options: options,
            selected: selected,
            enabled: !_scopeLocked,
            onSelected: _scopeLocked ? null : onSelected,
          ),
        );

  Widget _buildScopeRow() {
    final sourceFailed = _sourceInventoryFailed || _sourcePreferencesFailed;
    final options = {
      ShelfPageMode.favorite.name: t.bookshelf.favorite,
      ShelfPageMode.history.name: t.bookshelf.history,
    };
    final records = _shelfSelector(
      key: const ValueKey('bookshelf.records'),
      options: options,
      selected: _mode.name,
      onSelected: (value) {
        if (!mounted || _scopeLocked) return;
        _pendingHomeSection = null;
        _selectRecords(ShelfPageMode.values.byName(value).index);
      },
    );
    final sources = BlocBuilder<BookshelfSearchCubit, BookshelfSearchState>(
      bloc: _activeSearch,
      builder: (context, state) {
        final medium = _sourceMedium, mode = _mode, cubit = _activeSearch;
        return VideoControlAppearance(
          systemControls: usesNativeSourceChrome(context),
          child: BookshelfSourceNavigation(
            horizontalInset: CollectionToolbarMetrics.sourceContentInset,
            showManage: true,
            classicChips: true,
            sources: _sourceControlsReady
                ? _sourcePreferences[medium]!.arrange(_allLabelSources(medium))
                : const {},
            hidden: _sourcePreferences[medium]!.hidden,
            selected: state.stateOf(mode).sources,
            loading:
                (_sourcesLoading && !_sourceInventoryFailed) ||
                (!_sourcePreferencesReady && !_sourcePreferencesFailed),
            onManage: _scopeLocked || !_sourceControlsReady
                ? null
                : () {
                    if (!mounted || _scopeLocked || _sourceMedium != medium) {
                      return;
                    }
                    _manageSources();
                  },
            onChanged: _scopeLocked || !_sourceControlsReady
                ? null
                : (sources) {
                    if (!mounted ||
                        _scopeLocked ||
                        !_sourceControlsReady ||
                        _sourceMedium != medium ||
                        _mode != mode ||
                        cubit.isClosed) {
                      return;
                    }
                    cubit.setSources(mode, sources);
                    _refreshFor(medium == BookshelfSourceMedium.video, mode);
                  },
            statusAction: sourceFailed
                ? SourceChromeIconButton(
                    key: const ValueKey('bookshelf.sources.retry'),
                    icon: Icons.refresh,
                    symbol: 'arrow.clockwise',
                    tooltip: t.common.retry,
                    onPressed: () {
                      if (_sourceInventoryFailed) unawaited(_loadSources());
                      if (_sourcePreferencesFailed) {
                        unawaited(_restorePreferences());
                      }
                    },
                  )
                : null,
          ),
        );
      },
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final recordWidth = NativeVideoSegmentedControl.minimumHorizontalWidth(
          context,
          options.values,
        ).ceilToDouble();
        // Keep room for a complete source label, the scroll gutter and the
        // management button. At larger type sizes the switch gets its own row.
        final minimumSources =
            MediaQuery.textScalerOf(context).scale(60) +
            2 * CollectionToolbarMetrics.actionExtent +
            (sourceFailed ? CollectionToolbarMetrics.actionExtent : 0);
        const leadingPadding = CollectionToolbarMetrics.sourceContentInset;
        final fits =
            recordWidth + minimumSources + leadingPadding <=
            constraints.maxWidth;
        return Column(
          children: [
            if (fits)
              Row(
                children: [
                  const SizedBox(width: leadingPadding),
                  SizedBox(width: recordWidth, child: records),
                  Expanded(child: sources),
                ],
              )
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: leadingPadding),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SizedBox(
                    width: recordWidth.clamp(
                      0,
                      (constraints.maxWidth - 2 * leadingPadding).clamp(
                        0.0,
                        double.infinity,
                      ),
                    ),
                    child: records,
                  ),
                ),
              ),
              sources,
            ],
            const Padding(
              padding: EdgeInsets.fromLTRB(
                leadingPadding,
                2,
                leadingPadding,
                0,
              ),
              child: Divider(height: 1),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    const extent = CollectionToolbarMetrics.actionExtent;
    return ListenableBuilder(
      key: const ValueKey('bookshelf.main-header'),
      listenable: _header,
      child: _isSearchExpanded ? _searchField() : null,
      builder: (context, field) {
        final slots = _header.slots;
        final theme = Theme.of(context);
        final subtitle = slots?.subtitle ?? '';
        return Row(
          children: [
            Expanded(child: field ?? _buildHeading(context, theme, subtitle)),
            BlocSelector<BookshelfSearchCubit, BookshelfSearchState, String>(
              bloc: _activeSearch,
              selector: (state) => state.stateOf(_mode).keyword,
              builder: (context, query) => Badge(
                isLabelVisible: !_isSearchExpanded && query.isNotEmpty,
                child: SourceChromeIconButton(
                  key: const ValueKey('bookshelf.search'),
                  icon: _isSearchExpanded ? Icons.close_rounded : Icons.search,
                  symbol: _isSearchExpanded ? 'xmark' : 'magnifyingglass',
                  tooltip: _isSearchExpanded
                      ? t.common.close
                      : query.isEmpty
                      ? t.bookshelf.searchList
                      : '${t.bookshelf.searchList} · $query',
                  onPressed: _scopeLocked
                      ? null
                      : _isSearchExpanded
                      ? _exitSearch
                      : _openSearch,
                ),
              ),
            ),
            const CollectionCoverPrivacyButton(
              key: ValueKey('bookshelf.cover-privacy'),
              emphasizeProtected: true,
            ),
            SizedBox.square(
              dimension: extent,
              child: _scopeLocked || slots?.more == null
                  ? null
                  : KeyedSubtree(
                      // A menu must retire when its scope changes. Otherwise
                      // a late choice could act on the new pane or directory.
                      key: ValueKey((_header.generation, slots?.identity)),
                      child: slots!.more!,
                    ),
            ),
          ],
        );
      },
    );
  }

  double _headerHeight(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final title = scaler.scale(24) * 1.34;
    return (title + (scaler.scale(14) > 20 ? scaler.scale(12) * 1.4 : 0)).clamp(
      60.0,
      double.infinity,
    );
  }

  Widget _buildHeading(BuildContext context, ThemeData theme, String subtitle) {
    final title = Text(
      t.bookshelf.title,
      style: theme.textTheme.headlineSmall,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (subtitle.isEmpty) return title;
    final count = Text(
      subtitle,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (MediaQuery.textScalerOf(context).scale(14) > 20) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [title, count],
      );
    }
    return Row(
      children: [
        Flexible(child: title),
        const SizedBox(width: 8),
        Flexible(child: count),
      ],
    );
  }

  Widget _buildMediaRow() {
    final media = _shelfSelector(
      key: const ValueKey('bookshelf.media'),
      options: {
        'comic': t.bookshelf.mediaComics,
        'video': t.bookshelf.mediaVideos,
      },
      selected: _showVideos ? 'video' : 'comic',
      onSelected: _selectMedia,
    );
    return ListenableBuilder(
      key: const ValueKey('bookshelf.media-row'),
      listenable: _header,
      child: media,
      builder: (context, selector) {
        const extent = CollectionToolbarMetrics.actionExtent;
        final slots = _header.slots;
        return BookshelfSelectionHeader(
          regular: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: CollectionToolbarMetrics.sourceContentInset,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  Expanded(child: selector!),
                  const SizedBox(width: 4),
                  if (slots == null)
                    const SizedBox(width: 2 * extent)
                  else
                    for (final control in slots.controls)
                      SizedBox(width: extent, child: control),
                ],
              ),
            ),
          ),
          selection: slots?.selection,
        );
      },
    );
  }

  void _openSearch() {
    setState(() => _isSearchExpanded = true);
    requestSearchKeyboard(
      _searchFocusNode,
      isCurrent: () =>
          mounted &&
          _isSearchExpanded &&
          !_scopeLocked &&
          ModalRoute.of(context)?.isCurrent != false,
    );
  }

  Widget _searchScopeMenu() {
    final video = _showVideos, mode = _mode;
    return IgnorePointer(
      ignoring: _scopeLocked,
      child: KeywordScopeMenu(
        compact: true,
        scope: _keywordScope(video, mode),
        onChanged: (scope) {
          if (_scopeLocked || _showVideos != video || _mode != mode) return;
          _flushPendingKeyword();
          setState(() => _keywordScopes[(video, mode)] = scope);
        },
      ),
    );
  }

  Widget _withActions(Widget child) =>
      BlocBuilder<BookshelfSearchCubit, BookshelfSearchState>(
        bloc: _activeSearch,
        builder: (context, state) {
          final mode = _mode, cubit = _activeSearch, video = _showVideos;
          final medium = _sourceMedium;
          final generation = _header.generation;
          bool stillCurrent() =>
              mounted &&
              !_scopeLocked &&
              _header.isCurrent(generation) &&
              _mode == mode &&
              _showVideos == video &&
              identical(_activeSearch, cubit) &&
              !cubit.isClosed;
          return BookshelfActionsScope(
            mode: mode,
            video: video,
            header: _header,
            headerGeneration: generation,
            canUseHeader: stillCurrent,
            sort: state.stateOf(mode).sort,
            onSort: _scopeLocked
                ? null
                : (value) {
                    if (!stillCurrent()) return;
                    cubit.setSort(mode, value);
                    _persistSort(video, mode, value);
                    _refreshFor(video, mode);
                  },
            onManageSources: _scopeLocked || !_sourceControlsReady
                ? null
                : () {
                    if (!stillCurrent() || _sourceMedium != medium) return;
                    _manageSources();
                  },
            child: child,
          );
        },
      );

  Widget _searchField() =>
      BlocBuilder<BookshelfSearchCubit, BookshelfSearchState>(
        bloc: _activeSearch,
        builder: (context, state) {
          final mode = _mode, cubit = _activeSearch, video = _showVideos;
          return IgnorePointer(
            ignoring: _scopeLocked,
            child: SearchQueryField(
              key: ValueKey('shelf-search.$_showVideos.${mode.name}'),
              query: state.stateOf(mode).keyword,
              inline: true,
              focusNode: _searchFocusNode,
              leadingControlWidth: KeywordScopeMenu.leadingWidth(context),
              leadingControl: _searchScopeMenu(),
              closeOnSubmit: false,
              hintText: t.bookshelf.searchList,
              semanticLabel: t.bookshelf.searchList,
              onChanged: (value) {
                _keywordDebouncer.cancel();
                _pendingKeyword = null;
                if (value.isEmpty) {
                  cubit.setKeyword(mode, '');
                  _refreshFor(video, mode);
                } else {
                  _pendingKeyword = (cubit, mode, value);
                  _keywordDebouncer.run(() {
                    if (mounted) _flushPendingKeyword();
                  });
                }
              },
              onSubmitted: (value) {
                _keywordDebouncer.cancel();
                _pendingKeyword = null;
                cubit.setKeyword(mode, value.trim());
                _refreshFor(video, mode);
              },
            ),
          );
        },
      );

  void _exitSearch() {
    _flushPendingKeyword();
    _searchFocusNode.unfocus();
    setState(() => _isSearchExpanded = false);
    _applyPendingHomeSection();
  }

  void _flushPendingKeyword() {
    _keywordDebouncer.cancel();
    final pending = _pendingKeyword;
    _pendingKeyword = null;
    if (pending != null && !pending.$1.isClosed) {
      pending.$1.setKeyword(pending.$2, pending.$3);
      // The comic host reads its query on explicit refresh. Keep the captured
      // medium/mode: a tab or media switch may flush the previous editor.
      _refreshFor(identical(pending.$1, _videoSearch), pending.$2);
    }
  }

  void _refreshFor(bool video, ShelfPageMode mode) {
    // Video panes observe their scoped search value directly.
    if (!video) setState(() => _comicRefresh[mode.index]++);
  }

  void _refreshAll() {
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < 3; i++) {
        _comicRefresh[i]++;
      }
    });
  }

  void _persistSort(bool video, ShelfPageMode mode, String sort) {
    if (video) {
      _videoSortTouched.add(mode);
      final savedSorts = [
        for (final m in _recordModes) _videoSearch.state.stateOf(m).sort,
      ];
      unawaited(
        SharedPreferences.getInstance().then(
          (p) => p.setStringList(_videoSortKey, savedSorts),
        ),
      );
      return;
    }
    final cubit = context.read<GlobalSettingCubit>();
    cubit.updateBookshelfSetting(
      (s) => switch (mode) {
        ShelfPageMode.favorite => s.copyWith(
          favoriteSort: sort,
          rememberFavoriteSort: true,
        ),
        ShelfPageMode.history => s.copyWith(
          historySort: sort,
          rememberHistorySort: true,
        ),
        ShelfPageMode.download => s,
      },
    );
  }
}
