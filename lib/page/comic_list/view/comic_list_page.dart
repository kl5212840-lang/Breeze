import 'package:zephyr/widgets/read_recovery_scope.dart';
import 'package:zephyr/page/source_shell/view/jm_collection_toolbar.dart';
import 'dart:async';
import 'package:zephyr/page/search/widget/search_field_surface.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/widget/search_keyboard.dart';
import 'package:zephyr/page/search_result/view/source_loaded_result_filter.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/widgets/source_choice_menu.dart';
import 'package:zephyr/page/source_shell/source_list_presentation.dart';
import 'package:zephyr/page/source_shell/source_list_view_toggle.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:auto_route/annotations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/page/comic_list/cubit/comic_list_cubit.dart';
import 'package:zephyr/page/comic_list/models/comic_list_scene.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comic_list/scene_filter/plugin_list_filter_dialog.dart';
import 'package:zephyr/page/comic_list/scene_filter/cloud_favorite_filter.dart';
import 'package:zephyr/page/comic_list/view/plugin_paged_comic_list_view.dart';
import 'package:zephyr/page/search_result/view/source_list_filter_bar.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/util/text/chinese_convert.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/widgets/collection_cover_settings.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'package:zephyr/page/source_shell/source_list_block_preferences.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';

@RoutePage()
class ComicListPage extends StatelessWidget {
  const ComicListPage({
    super.key,
    this.title,
    this.scene,
    this.sceneSource,
    this.sceneBundleFnPath,
    this.sceneBundleFnPathFallback,
    this.embedded = false,
    this.jmCollection = false,
  });

  final String? title;
  final ComicListScene? scene;
  final String? sceneSource;
  final String? sceneBundleFnPath;
  final String? sceneBundleFnPathFallback;

  /// Render inside a source shell without a second navigation scaffold.
  final bool embedded;
  final bool jmCollection;

  @override
  Widget build(BuildContext context) => SourceExperienceBoundary(
    source: scene?.from ?? sceneSource ?? '',
    builder: _buildSourcePage,
  );

  Widget _buildSourcePage(BuildContext context) {
    return BlocProvider(
      create: (_) => ComicListCubit(
        initialScene: scene,
        sceneSource: sceneSource,
        sceneBundleFnPath: sceneBundleFnPath,
        sceneBundleFnPathFallback: sceneBundleFnPathFallback,
        observeSessionChanges:
            sceneBundleFnPath == 'getCloudFavoriteSceneBundle' ||
            sceneBundleFnPath == 'get_cloud_favorite_scene_bundle' ||
            scene?.body.request?.fnPath == 'getCloudFavoriteData' ||
            scene?.body.request?.extern['source'] == 'cloudFavorite',
      ),
      child: Builder(
        builder: (context) => ReadRecoveryHost(
          onActiveChanged: context.read<ComicListCubit>().setReadActive,
          child: _ComicListView(
            title: title,
            embedded: embedded,
            jmCollection: jmCollection,
            cloudFavoriteEntryPoint:
                sceneBundleFnPath == 'getCloudFavoriteSceneBundle' ||
                sceneBundleFnPath == 'get_cloud_favorite_scene_bundle',
          ),
        ),
      ),
    );
  }
}

class _ComicListView extends StatefulWidget {
  const _ComicListView({
    this.title,
    required this.embedded,
    this.jmCollection = false,
    required this.cloudFavoriteEntryPoint,
  });

  final String? title;
  final bool embedded, jmCollection;
  final bool cloudFavoriteEntryPoint;

  @override
  State<_ComicListView> createState() => _ComicListViewState();
}

class _ComicListViewState extends State<_ComicListView>
    with AutomaticKeepAliveClientMixin {
  final _jmSearch = TextEditingController();
  final _jmSearchFocus = FocusNode();
  bool _jmSearching = false;
  late (String, int) _searchSession;
  bool _filterOpening = false;
  bool _systemSearchSurface = false;
  ModalRoute<dynamic>? _remoteFilterRoute;

  void _dismissRemoteFilter() {
    final route = _remoteFilterRoute;
    final navigator = route?.navigator;
    if (route == null || navigator == null) return;
    scheduleMicrotask(() {
      if (route.isActive && route.navigator == navigator)
        navigator.removeRoute(route);
    });
  }

  (String, int) _sessionOf(ComicListState state) => (
    state.currentFrom,
    pluginSessionWriteFence.generation(state.currentFrom),
  );

  @override
  void initState() {
    super.initState();
    _searchSession = _sessionOf(context.read<ComicListCubit>().state);
  }

  @override
  void dispose() {
    _dismissRemoteFilter();
    _jmSearch.dispose();
    _jmSearchFocus.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  bool _isCloudFavoriteScene(ComicListScene scene) {
    final request = scene.body.request;
    return request != null &&
        (request.fnPath == 'getCloudFavoriteData' ||
            request.extern['source']?.toString() == 'cloudFavorite');
  }

  bool _compactCloud(ComicListState state) =>
      widget.jmCollection ||
      widget.cloudFavoriteEntryPoint ||
      (state.scene != null && _isCloudFavoriteScene(state.scene!));

  void _toggleCategory(
    String category,
    Set<String> blocked,
    ValueChanged<Set<String>> change,
  ) {
    final wasBlocked = blocked.contains(category);
    final next = {...blocked};
    wasBlocked ? next.remove(category) : next.add(category);
    change(next);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          wasBlocked
              ? '已恢复「${convertChineseForDisplay(category)}」'
              : '已屏蔽「${convertChineseForDisplay(category)}」· 再点恢复',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildJmCollection(
    BuildContext context,
    ComicListState state,
    bool detailed,
    ValueChanged<bool> onViewChanged,
    Set<String> blocked,
  ) {
    final sort = cloudFavoriteSortField(state.filterBundle);
    final remoteFilters = cloudFavoriteHasRemoteResultFilters(
      state.filterBundle,
    );
    final body = Column(
      children: [
        if (remoteFilters)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: CollectionToolbarMetrics.horizontalInset,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _cloudFolderChoice(state),
                  ),
                ),
                SourceListViewToggle(
                  key: const ValueKey('jm-cloud-view'),
                  detailed: detailed,
                  onChanged: onViewChanged,
                ),
                SourceChromeIconButton(
                  key: const ValueKey('jm-cloud-remote-filter'),
                  tooltip: t.comicList.filter,
                  icon: Icons.filter_list_rounded,
                  symbol: 'line.3.horizontal.decrease',
                  onPressed: _filterOpening
                      ? null
                      : () => _openFilterDialog(context),
                ),
              ],
            ),
          ),
        if (remoteFilters)
          _filterSummary(
            state,
            inset: CollectionToolbarMetrics.horizontalInset,
          ),
        Expanded(
          child: CollectionCoverPrivacyScope(
            child: _buildBody(
              context,
              state,
              detailed,
              blocked,
              jmViewChanged: onViewChanged,
            ),
          ),
        ),
      ],
    );
    final actions = <Widget>[
      JmCollectionNavigationActions(
        searching: _jmSearching,
        selected: sort == null
            ? ''
            : 'sort.${state.filterSelections[sort.key] ?? state.filterBundle?.defaultSelections[sort.key] ?? sort.options.first.value}',
        onSearch: remoteFilters
            ? null
            : () {
                final accountGeneration = pluginSessionWriteFence.generation(
                  state.currentFrom,
                );
                setState(() {
                  _jmSearching = !_jmSearching;
                  if (!_jmSearching) {
                    _jmSearch.clear();
                    _jmSearchFocus.unfocus();
                  }
                });
                if (_jmSearching)
                  requestSearchKeyboard(
                    _jmSearchFocus,
                    isCurrent: () =>
                        mounted &&
                        _jmSearching &&
                        context.read<ComicListCubit>().state.currentFrom ==
                            state.currentFrom &&
                        !pluginSessionWriteFence.isChanging(
                          state.currentFrom,
                        ) &&
                        pluginSessionWriteFence.generation(state.currentFrom) ==
                            accountGeneration &&
                        ModalRoute.of(context)?.isCurrent != false,
                  );
              },
        options: {
          if (sort != null)
            for (final option in sort.options)
              'sort.${option.value}': option.label,
          if (!remoteFilters &&
              cloudFavoriteNeedsFilterDialog(state.filterBundle))
            'remote-filter': t.comicList.filter,
          collectionCoverSettingsAction: collectionCoverSettingsLabel(context),
        },
        groups: [
          if (sort != null) [for (final o in sort.options) 'sort.${o.value}'],
          [
            if (!remoteFilters &&
                cloudFavoriteNeedsFilterDialog(state.filterBundle))
              'remote-filter',
            collectionCoverSettingsAction,
          ],
        ],
        onSelected: (value) {
          if (value.startsWith('sort.') && sort != null) {
            context.read<ComicListCubit>().applyFilterSelections({
              ...state.filterSelections,
              sort.key: value.substring(5),
            });
          } else if (value == 'remote-filter') {
            unawaited(_openFilterDialog(context));
          } else if (value == collectionCoverSettingsAction) {
            unawaited(openCollectionCoverSettings(context));
          }
        },
      ),
    ];
    if (widget.embedded)
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(widget.title ?? '站点收藏')),
              ...actions,
            ],
          ),
          Expanded(child: body),
        ],
      );
    return Scaffold(
      appBar: AppBar(
        leading: const SourceBackButton(),
        title: Text(widget.title ?? state.scene?.title ?? '站点收藏'),
        actions: actions,
      ),
      body: body,
    );
  }

  Widget _jmControls(
    BuildContext context,
    ComicListState state,
    SourceLoadedResultChrome chrome,
    bool detailed,
    ValueChanged<bool> onViewChanged,
  ) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AnimatedSize(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.topCenter,
        child: _jmSearching
            ? Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                child: chrome.searchField,
              )
            : const SizedBox.shrink(),
      ),
      JmCollectionResultsRow(
        scope: _cloudFolderChoice(state),
        countLabel: chrome.countLabel,
        filterButton: chrome.filterButton,
        viewAction: SourceListViewToggle(
          key: const ValueKey('jm-cloud-view'),
          detailed: detailed,
          onChanged: onViewChanged,
        ),
      ),
      if (chrome.appliedFilters case final applied?) applied,
    ],
  );

  Widget _cloudToolbar(
    ComicListState state,
    bool detailed,
    ValueChanged<bool> onChanged,
    Set<String> blocked,
    ValueChanged<Set<String>> onBlockedChanged,
  ) {
    final sort = cloudFavoriteSortField(state.filterBundle);
    return SourceListFilterBar(
      contentInset: CollectionToolbarMetrics.sourceContentInset,
      categories: const [],
      blockedCategories: blocked,
      onCategoryTap: (category) =>
          _toggleCategory(category, blocked, onBlockedChanged),
      onClearBlockedCategories: () => onBlockedChanged({}),
      sortValue: sort == null ? '' : state.filterSelections[sort.key] ?? '',
      sortOptions: {
        if (sort != null)
          for (final option in sort.options) option.value: option.label,
      },
      onSortChanged: (value) {
        if (sort == null) return;
        context.read<ComicListCubit>().applyFilterSelections({
          ...state.filterSelections,
          sort.key: value,
        });
      },
      detailedView: detailed,
      onViewChanged: onChanged,
      viewToggleKey: const ValueKey('cloud-favorite-view-toggle'),
      leading: _cloudFolderChoice(state),
    );
  }

  Widget? _cloudFolderChoice(ComicListState state) {
    final folders = state.filterBundle?.scheme.fields
        .where(
          (field) =>
              field.key == 'folderId' &&
              field.options.isNotEmpty &&
              field.options.every((option) => option.children.isEmpty),
        )
        .firstOrNull;
    if (folders == null) {
      if (_compactCloud(state) && state.filterLoading)
        return Row(
          key: const ValueKey('cloud-favorite.folder-loading'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_outlined, size: 18),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                t.common.loading,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        );
      return null;
    }
    if (!_compactCloud(state) && folders.options.length < 2) return null;
    final value = state.filterSelections[folders.key] ?? '';
    final options = {
      for (final option in folders.options) option.value: option.label,
    };
    void select(String value) => context
        .read<ComicListCubit>()
        .applyFilterSelections({...state.filterSelections, folders.key: value});
    final Widget choice = _compactCloud(state) && folders.options.length > 8
        ? JmCollectionFolderChoice(
            key: const ValueKey('cloud-favorite.folder'),
            label: folders.label,
            value: value,
            options: options,
            onChanged: folders.options.length == 1 ? null : select,
          )
        : SourceChoiceMenu<String>(
            key: const ValueKey('cloud-favorite.folder'),
            tooltip: folders.label,
            label:
                folders.findOptionByValue(value)?.label ??
                folders.options.first.label,
            value: value,
            options: options,
            selectionIndicator: !_compactCloud(state),
            maximumWidth: _compactCloud(state) ? 160 : 180,
            onChanged: _compactCloud(state) && folders.options.length == 1
                ? null
                : select,
          );
    if (!_compactCloud(state)) return choice;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.folder_outlined, size: 18),
        const SizedBox(width: 4),
        Flexible(child: choice),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _systemSearchSurface = usesSystemSearchSurface(context);
    return BlocConsumer<ComicListCubit, ComicListState>(
      listenWhen: (_, state) => _searchSession != _sessionOf(state),
      listener: (_, state) {
        _searchSession = _sessionOf(state);
        _jmSearching = false;
        _jmSearch.clear();
        _jmSearchFocus.unfocus();
      },
      builder: (context, state) {
        final isBikaRanking = _usesBikaRankingLayout(state);
        final isCloudFavorite =
            widget.cloudFavoriteEntryPoint ||
            (state.scene != null && _isCloudFavoriteScene(state.scene!));
        final title =
            widget.title ?? (state.scene?.title ?? t.comicList.defaultTitle);
        final publicLoadedFacets = _copyPublicLoadedFacets(state);

        return SourceCategoryBlockScope(
          scope:
              '${state.currentFrom}|${isCloudFavorite ? 'cloudFavorite' : state.scene?.body.request?.fnPath ?? 'list'}',
          builder: (context, blocked, onBlockedChanged) =>
              SourceListPresentation(
                source: state.currentFrom,
                detailedByDefault: isCloudFavorite,
                builder: (context, detailed, onViewChanged) {
                  Widget loadedTools(
                    BuildContext context,
                    SourceLoadedResultChrome chrome,
                  ) => _publicLoadedToolbar(
                    context,
                    chrome,
                    title: widget.embedded ? title : null,
                    detailed: detailed,
                    onViewChanged: onViewChanged,
                  );
                  if (isCloudFavorite && _compactCloud(state)) {
                    return _buildJmCollection(
                      context,
                      state,
                      detailed,
                      onViewChanged,
                      blocked,
                    );
                  }
                  final remoteFilter =
                      state.requiresFilter &&
                          !isBikaRanking &&
                          (!isCloudFavorite ||
                              cloudFavoriteNeedsFilterDialog(
                                state.filterBundle,
                              ))
                      ? SourceChromeIconButton(
                          tooltip: t.comicList.filter,
                          icon: Icons.filter_list_rounded,
                          symbol: 'line.3.horizontal.decrease',
                          onPressed: _filterOpening
                              ? null
                              : () => _openFilterDialog(context),
                        )
                      : null;
                  if (widget.embedded) {
                    return Column(
                      children: [
                        if (!publicLoadedFacets)
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              CollectionToolbarMetrics.sourceContentInset,
                              4,
                              CollectionToolbarMetrics.sourceContentInset,
                              4,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                                if (isBikaRanking)
                                  _rankingTypeChoice(context, state),
                                if (isCloudFavorite) ...[
                                  const CollectionCoverPrivacyButton(),
                                  const CollectionCoverSettingsMoreButton(),
                                ],
                                ?remoteFilter,
                                if (!isBikaRanking && !isCloudFavorite)
                                  SourceListViewToggle(
                                    detailed: detailed,
                                    onChanged: onViewChanged,
                                  ),
                              ],
                            ),
                          ),
                        if (isCloudFavorite)
                          _cloudToolbar(
                            state,
                            detailed,
                            onViewChanged,
                            blocked,
                            onBlockedChanged,
                          ),
                        if (isBikaRanking) _rankingPeriodBar(context, state),
                        _filterSummary(state),
                        Expanded(
                          child: CollectionCoverPrivacyScope(
                            enabled: isCloudFavorite,
                            child: _buildBody(
                              context,
                              state,
                              detailed,
                              blocked,
                              publicLoadedTools: publicLoadedFacets
                                  ? loadedTools
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return Scaffold(
                    appBar: AppBar(
                      leading: const SourceBackButton(),
                      title: Text(title),
                      actionsPadding: const EdgeInsetsDirectional.only(
                        end: CollectionToolbarMetrics.sourceContentInset,
                      ),
                      actions: [
                        if (isBikaRanking) _rankingTypeChoice(context, state),
                        if (isCloudFavorite)
                          const CollectionCoverPrivacyButton(),
                        ?remoteFilter,
                        if (!isBikaRanking &&
                            !isCloudFavorite &&
                            !publicLoadedFacets)
                          SourceListViewToggle(
                            detailed: detailed,
                            onChanged: onViewChanged,
                          ),
                        SourceMoreButton(
                          source: state.currentFrom,
                          showCoverSettings: isCloudFavorite,
                        ),
                      ],
                    ),
                    body: Column(
                      children: [
                        if (isCloudFavorite)
                          _cloudToolbar(
                            state,
                            detailed,
                            onViewChanged,
                            blocked,
                            onBlockedChanged,
                          ),
                        if (isBikaRanking) _rankingPeriodBar(context, state),
                        _filterSummary(state),
                        Expanded(
                          child: CollectionCoverPrivacyScope(
                            enabled: isCloudFavorite,
                            child: _buildBody(
                              context,
                              state,
                              detailed,
                              blocked,
                              publicLoadedTools: publicLoadedFacets
                                  ? loadedTools
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
        );
      },
    );
  }

  bool _copyPublicLoadedFacets(ComicListState state) =>
      state.currentFrom == copyComicSourceId &&
      !state.requiresFilter &&
      const {
        'getHomeRecommend',
        'getHomeNewest',
      }.contains(state.scene?.body.request?.fnPath);

  Widget _publicLoadedToolbar(
    BuildContext context,
    SourceLoadedResultChrome chrome, {
    required String? title,
    required bool detailed,
    required ValueChanged<bool> onViewChanged,
  }) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          CollectionToolbarMetrics.sourceContentInset,
          4,
          CollectionToolbarMetrics.sourceContentInset,
          4,
        ),
        child: Row(
          key: const ValueKey('comic-list.public-loaded-tools'),
          children: [
            Expanded(
              child: Text(
                title ??
                    (chrome.filtersActive
                        ? chrome.countLabel
                        : chrome.total == 0
                        ? ''
                        : t.sourceShell.collectionLoadedCount(
                            count: chrome.total,
                          )),
                style: title == null
                    ? Theme.of(context).textTheme.bodyMedium
                    : Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (chrome.hasFilterOptions) chrome.filterButton,
            SourceListViewToggle(detailed: detailed, onChanged: onViewChanged),
          ],
        ),
      ),
      SourceLoadedFacetSummary(chrome: chrome, showCount: title != null),
    ],
  );

  Widget _filterSummary(
    ComicListState state, {
    double inset = CollectionToolbarMetrics.sourceContentInset,
  }) {
    final bundle = state.filterBundle;
    if (bundle == null) return const SizedBox.shrink();
    final selected = <String>[];
    for (final field in bundle.scheme.fields) {
      // The period segmented control already expresses this exact condition.
      // Keep any additional user-selected conditions in the summary.
      if (_usesBikaRankingLayout(state) && field.key == 'ranking') continue;
      if ((widget.cloudFavoriteEntryPoint ||
              state.scene != null && _isCloudFavoriteScene(state.scene!)) &&
          (field == cloudFavoriteSortField(bundle) || field.key == 'folderId'))
        continue;
      final value = state.filterSelections[field.key];
      if (value == null || value == bundle.defaultSelections[field.key]) {
        continue;
      }
      final option = field.findOptionByValue(value);
      if (option != null && option.value.isNotEmpty) {
        selected.add('${field.label} · ${option.label}');
      }
    }
    if (selected.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsetsDirectional.only(start: inset, end: 4),
              itemCount: selected.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => Center(
                child: ActionChip(
                  label: Text(convertChineseForDisplay(selected[index])),
                  onPressed: _filterOpening
                      ? null
                      : () => _openFilterDialog(context),
                ),
              ),
            ),
          ),
          SourceChromeIconButton(
            tooltip: t.comicList.clearFilters,
            icon: Icons.filter_alt_off_outlined,
            symbol: 'xmark',
            onPressed: () => context
                .read<ComicListCubit>()
                .applyFilterSelections(bundle.defaultSelections),
          ),
          SizedBox(width: inset),
        ],
      ),
    );
  }

  Widget _rankingPeriodBar(BuildContext context, ComicListState state) {
    final selected = state.filterSelections['ranking'] ?? 'day';
    final selectedType = state.filterSelections['rankingType'] ?? 'comic';
    if (selectedType != 'comic') return const SizedBox.shrink();
    final periods = <String, String>{
      'day': t.bikaRanking.day,
      'week': t.bikaRanking.week,
      'month': t.bikaRanking.month,
    };
    void select(String key, String value) {
      context.read<ComicListCubit>().applyFilterSelections({
        ...state.filterSelections,
        key: value,
      });
    }

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        CollectionToolbarMetrics.sourceContentInset,
        0,
        CollectionToolbarMetrics.sourceContentInset,
        4,
      ),
      child: Tooltip(
        message: '${t.bikaRanking.period}: ${periods.values.join(' / ')}',
        child: NativeVideoSegmentedControl(
          key: const ValueKey('bika-ranking.period'),
          options: periods,
          selected: selected,
          enabled: state.hasResolvedFilter,
          onSelected: state.hasResolvedFilter
              ? (value) => select('ranking', value)
              : null,
        ),
      ),
    );
  }

  bool _usesBikaRankingLayout(ComicListState state) =>
      state.scene?.body.request?.fnPath == 'getRankingData' &&
      (state.currentFrom == 'e9f18928-3ba8-4d86-a12e-b53a62f47933' ||
          state.scene?.body.params['layout'] == 'bikaRanking');

  Widget _rankingTypeChoice(BuildContext context, ComicListState state) {
    final selected = state.filterSelections['rankingType'] ?? 'comic';
    final types = {
      'comic': t.bikaRanking.popular,
      'creator': t.bikaRanking.creators,
    };
    return SourceChoiceMenu<String>(
      key: const ValueKey('bika-ranking.type'),
      label: types[selected] ?? types.values.first,
      tooltip: t.bikaRanking.type,
      value: selected,
      options: types,
      selectionIndicator: true,
      onChanged: state.hasResolvedFilter
          ? (value) => context.read<ComicListCubit>().applyFilterSelections({
              ...state.filterSelections,
              'rankingType': value,
            })
          : null,
    );
  }

  Widget _buildBody(
    BuildContext context,
    ComicListState state,
    bool detailed,
    Set<String> blocked, {
    Widget Function(BuildContext, SourceLoadedResultChrome)? publicLoadedTools,
    ValueChanged<bool>? jmViewChanged,
  }) {
    final currentFrom = state.currentFrom;

    if (currentFrom.isEmpty) {
      return Center(child: Text(t.comicList.missingSource));
    }

    if (state.sceneLoading && state.scene == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.sceneError != null &&
        (state.scene == null ||
            state.scene!.body.request?.fnPath.trim().isNotEmpty != true)) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                userFacingErrorMessage(state.sceneError!),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => context.read<ComicListCubit>().reload(),
              child: Text(t.comicList.reload),
            ),
          ],
        ),
      );
    }

    if (state.requiresFilter &&
        state.filterLoading &&
        !state.hasResolvedFilter) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.requiresFilter &&
        state.filterError != null &&
        !state.hasResolvedFilter) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                userFacingErrorMessage(state.filterError!),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => context.read<ComicListCubit>().loadFilter(),
              child: Text(t.comicList.reload),
            ),
          ],
        ),
      );
    }

    final scene = state.scene;
    if (scene != null) {
      return _buildSceneBody(
        state,
        scene,
        detailed,
        blocked,
        publicLoadedTools,
        jmViewChanged,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildSceneBody(
    ComicListState state,
    ComicListScene scene,
    bool detailed,
    Set<String> blocked,
    Widget Function(BuildContext, SourceLoadedResultChrome)? publicLoadedTools,
    ValueChanged<bool>? jmViewChanged,
  ) {
    final request = scene.body.request!;
    final filterCore = state.resolvedFilterCore;
    final filterExtern = state.resolvedFilterExtern;
    final listCore = <String, dynamic>{...request.core, ...filterCore};
    final listExtern = <String, dynamic>{...request.extern, ...filterExtern};
    final collectionTargetId = _resolveCollectionTargetId(
      request: request,
      core: listCore,
      extern: listExtern,
    );

    return PluginPagedComicListView(
      key: ValueKey(
        '${request.fnPath}_${listCore}_${listExtern}_${pluginSessionWriteFence.generation(state.currentFrom)}',
      ),
      pluginId: state.currentFrom,
      fnPath: request.fnPath,
      coreBuilder: (page) => {'page': page, ...listCore},
      externBuilder: (_) => listExtern,
      collectionTargetId: collectionTargetId,
      rankingLayout: _usesBikaRankingLayout(state),
      cloudFavorite:
          widget.cloudFavoriteEntryPoint || _isCloudFavoriteScene(scene),
      detailedView: detailed,
      blockedCategories: blocked,
      localResultTools: !cloudFavoriteHasRemoteResultFilters(
        state.filterBundle,
      ),
      publicLoadedFacets: publicLoadedTools != null,
      loadedSearchController: _compactCloud(state) ? _jmSearch : null,
      loadedSearchFocusNode: _compactCloud(state) ? _jmSearchFocus : null,
      loadedSearchExpanded: !_compactCloud(state) || _jmSearching,
      focusedFacets: _compactCloud(state),
      loadedChromeBuilder: _compactCloud(state) && jmViewChanged != null
          ? (context, chrome) =>
                _jmControls(context, state, chrome, detailed, jmViewChanged)
          : publicLoadedTools,
    );
  }

  String? _resolveCollectionTargetId({
    required ComicListRequestConfig request,
    required Map<String, dynamic> core,
    required Map<String, dynamic> extern,
  }) {
    final isCloudFavoriteScene =
        request.fnPath == 'getCloudFavoriteData' ||
        extern['source']?.toString() == 'cloudFavorite';
    if (!isCloudFavoriteScene) {
      return null;
    }
    final targetId = core['folderId'] ?? extern['folderId'];
    final normalized = targetId?.toString().trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  Future<void> _openFilterDialog(BuildContext context) async {
    if (_filterOpening) return;
    setState(() => _filterOpening = true);
    final cubit = context.read<ComicListCubit>();
    final source = cubit.state.currentFrom;
    final generation = pluginSessionWriteFence.generation(source);
    final sessionChanges = pluginSessionWriteFence.changes.listen((boundary) {
      if (boundary.source == source) _dismissRemoteFilter();
    });
    try {
      if (!cubit.state.hasResolvedFilter) await cubit.loadFilter();
      if (!context.mounted) return;
      if (generation != pluginSessionWriteFence.generation(source) ||
          pluginSessionWriteFence.isChanging(source)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.comicList.loadedFiltersChanged)),
        );
        return;
      }
      final bundle = cubit.state.filterBundle;
      if (bundle == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFacingErrorMessage(
                cubit.state.filterError ?? t.common.loadingFailed,
              ),
            ),
          ),
        );
        return;
      }
      final scene = cubit.state.scene;
      final role =
          widget.cloudFavoriteEntryPoint ||
              (scene != null && _isCloudFavoriteScene(scene))
          ? 'cloudFavorite'
          : scene?.body.request?.fnPath ?? 'list';
      final favoriteScope =
          'source-filter|$source|comic-list|${Uri.encodeComponent(role)}';
      final result = await showModalBottomSheet<Map<String, String>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        constraints: const BoxConstraints(maxWidth: 640),
        clipBehavior: _systemSearchSurface ? Clip.none : Clip.antiAlias,
        builder: (sheetContext) {
          _remoteFilterRoute = ModalRoute.of(sheetContext);
          return PluginListFilterDialog(
            favoriteScope: favoriteScope,
            scheme: bundle.scheme,
            defaultSelections: bundle.defaultSelections,
            initialSelections: cubit.state.filterSelections.isNotEmpty
                ? cubit.state.filterSelections
                : bundle.defaultSelections,
          );
        },
      );
      if (result != null && context.mounted) {
        if (generation != pluginSessionWriteFence.generation(source)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.comicList.loadedFiltersChanged)),
          );
          return;
        }
        cubit.applyFilterSelections(result);
      }
    } finally {
      // The broadcast subscription detaches synchronously. Its completion is
      // cleanup, not part of the sheet's interactive lifetime (and can belong
      // to a different async zone in an embedded host).
      final cancellation = sessionChanges.cancel();
      await _remoteFilterRoute?.completed;
      _remoteFilterRoute = null;
      if (mounted) {
        setState(() => _filterOpening = false);
      } else {
        _filterOpening = false;
      }
      await cancellation;
    }
  }
}
