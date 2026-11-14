import 'package:zephyr/page/search/widget/search_toolbar_scope.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/widgets/read_recovery_scope.dart';
import 'package:zephyr/page/search/method/search_history_entries.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/method/copy_search_topic.dart';
import 'package:zephyr/page/search_result/view/source_search_scope_control.dart';
import 'package:zephyr/page/search_aggregate/aggregate_video_search.dart';
import 'package:zephyr/page/search_aggregate/aggregate_search_matching.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/video_source_action.dart';
import 'package:zephyr/page/discover/service/discover_router.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/cubit/plugin_registry_cubit.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search/widget/search_input_dialog.dart';
import 'package:zephyr/page/search/widget/source_select_dialog.dart';
import 'package:zephyr/page/search_result/bloc/search_bloc.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/service/jm_list_like_counts.dart';
import 'package:zephyr/widgets/comic_simplify_entry/jm_cover_like_badge.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry_info.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry_mapper.dart';
import 'package:zephyr/widgets/section_header.dart';

import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/search_aggregate/cubit/search_aggregate_cubit.dart';

@RoutePage()
class SearchAggregateResultPage extends StatelessWidget
    implements AutoRouteWrapper {
  const SearchAggregateResultPage({
    super.key,
    required this.searchEvent,
    this.searchCubit,
    this.selectedSources = const <String, bool>{},
  });

  final SearchEvent searchEvent;
  final SearchCubit? searchCubit;
  final Map<String, bool> selectedSources;

  @override
  Widget wrappedRoute(BuildContext context) {
    final pluginStates = context.read<PluginRegistryCubit>().state;
    final visiblePlugins = PluginRegistryService.I.sortPlugins(
      pluginStates.values.where((state) => !state.isDeleted && state.isEnabled),
    );
    final initial = {
      for (final plugin in visiblePlugins)
        plugin.uuid: selectedSources[plugin.uuid] ?? true,
    };
    return MultiBlocProvider(
      providers: [
        searchCubit != null
            ? BlocProvider.value(value: searchCubit!)
            : BlocProvider(
                create: (_) => SearchCubit(searchEvent.searchStates),
              ),
        BlocProvider(
          create: (_) => AggregateSearchCubit(
            searchEvent,
            initialSelectedSources: initial,
            availableSources: visiblePlugins.map((p) => p.uuid).toSet(),
            sourceDefinitions: _sourceDefinitions(pluginStates),
          )..search(),
        ),
      ],
      child: BlocListener<PluginRegistryCubit, Map<String, PluginRuntimeState>>(
        listener: (context, plugins) {
          final cubit = context.read<AggregateSearchCubit>();
          cubit.updateAvailableSources(
            plugins.values
                .where((p) => p.isEnabled && !p.isDeleted)
                .map((p) => p.uuid)
                .toSet(),
          );
          cubit.updateSourceDefinitions(_sourceDefinitions(plugins));
        },
        child: this,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SearchAggregateResultPage(searchEvent: searchEvent);
  }
}

Map<String, Object> _sourceDefinitions(
  Map<String, PluginRuntimeState> plugins,
) => {
  for (final plugin in plugins.values)
    plugin.uuid: (
      plugin.version,
      plugin.originScript,
      plugin.debug,
      plugin.debugUrl,
    ),
};

class _SearchAggregateResultPage extends StatefulWidget {
  const _SearchAggregateResultPage({required this.searchEvent});

  final SearchEvent searchEvent;

  @override
  State<_SearchAggregateResultPage> createState() =>
      _SearchAggregateResultPageState();
}

class _SearchAggregateResultPageState
    extends State<_SearchAggregateResultPage> {
  bool _selectingSources = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final keyword = widget.searchEvent.searchStates.searchKeyword.trim();
      if (keyword.isEmpty || !mounted) {
        return;
      }
      final settingCubit = context.read<GlobalSettingCubit>();
      settingCubit.updateState(
        (current) => current.copyWith(
          searchHistory: SearchHistoryEntries.add(
            current.searchHistory,
            keyword,
            scope: '',
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ReadRecoveryHost(
      onActiveChanged: context.read<AggregateSearchCubit>().setReadActive,
      keepActiveWhileCovered: () => _selectingSources,
      child: Scaffold(
        appBar: SearchToolbarScope.appBar(
          context,
          (height) => AppBar(
            toolbarHeight: height,
            leadingWidth: height,
            leading: height == null ? null : const SourceBackButton(),
            titleSpacing: 0,
            title: _SearchBarTrigger(
              searchEvent: widget.searchEvent,
              onSelectSources: _showSourceDialog,
            ),
          ),
        ),
        body: Column(
          children: [
            const _FilterChipsRow(),
            Expanded(
              child: BlocBuilder<AggregateSearchCubit, AggregateSearchState>(
                builder: (context, state) {
                  final hasAnyResponse =
                      state.results.isNotEmpty ||
                      state.errors.isNotEmpty ||
                      state.notices.isNotEmpty;
                  if (state.status == AggregateSearchStatus.loading &&
                      !hasAnyResponse) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return Stack(
                    children: [
                      _ResultList(
                        searchEvent: context
                            .read<AggregateSearchCubit>()
                            .baseEvent,
                        state: state,
                      ),
                      if (state.status == AggregateSearchStatus.loading)
                        const Align(
                          alignment: Alignment.topCenter,
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSourceDialog() async {
    if (_selectingSources) return;
    final cubit = context.read<AggregateSearchCubit>();
    final options = _sourceOptions(context, cubit.state.selectedSources.keys);
    final session = context.read<SearchCubit>();
    _selectingSources = true;
    final Map<String, bool>? selected;
    try {
      selected = await showSourceSelectDialog(
        context,
        initial: cubit.state.selectedSources,
        sourceOptions: options,
      );
    } finally {
      _selectingSources = false;
    }
    if (selected == null ||
        !mounted ||
        ModalRoute.of(context)?.isCurrent == false)
      return;
    session.update(
      session.state.copyWith(
        aggregateSources: {...session.state.aggregateSources, ...selected},
      ),
    );
    await cubit.applySelectedSources(selected);
  }

  List<({String pluginId, String title})> _sourceOptions(
    BuildContext context,
    Iterable<String> selectedKeys,
  ) {
    final pluginStates = context.read<PluginRegistryCubit>().state;
    final ordered = PluginRegistryService.I.sortPlugins(
      pluginStates.values.where((state) => !state.isDeleted && state.isEnabled),
    );
    final selectedSet = selectedKeys.toSet();
    final result = <({String pluginId, String title})>[];
    for (final plugin in ordered) {
      if (!selectedSet.contains(plugin.uuid)) {
        continue;
      }
      final info = PluginRegistryService.I.getCachedPluginInfo(plugin.uuid);
      final title = info?['name']?.toString().trim().isNotEmpty == true
          ? info!['name'].toString().trim()
          : plugin.uuid;
      result.add((pluginId: plugin.uuid, title: title));
    }
    return result;
  }
}

class _SearchBarTrigger extends StatelessWidget {
  const _SearchBarTrigger({
    required this.searchEvent,
    required this.onSelectSources,
  });

  final SearchEvent searchEvent;
  final VoidCallback onSelectSources;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 12),
      child: Row(
        children: [
          Expanded(
            child: SearchQueryField(
              query: searchEvent.searchStates.searchKeyword,
              hintText: t.search.searchHint,
              semanticLabel: t.search.title,
              onTap: () => _openSearchPage(context),
            ),
          ),
          if (SearchToolbarScope.of(context) != null) const SizedBox(width: 4),
          SourceSearchScopeControl(
            aggregate: true,
            compact: MediaQuery.sizeOf(context).width < 352,
            onChanged: context.read<AggregateSearchCubit>().applyKeywordScope,
          ),
          if (SearchToolbarScope.of(context) != null) const SizedBox(width: 4),
          SourceChromeIconButton(
            tooltip: t.search.selectSourceTooltip,
            onPressed: onSelectSources,
            icon: Icons.layers_outlined,
            symbol: 'square.stack.3d.up',
          ),
        ],
      ),
    );
  }

  void _openSearchPage(BuildContext context) {
    final stack = context.router.stack;
    if (stack.length > 1 && stack[stack.length - 2].name == SearchRoute.name) {
      context.maybePop();
      return;
    }

    context.replaceRoute(
      SearchRoute(
        key: ValueKey(const Uuid().v4()),
        searchState: context.read<SearchCubit>().state,
        aggregateMode: true,
      ),
    );
  }
}

class _FilterChipsRow extends StatelessWidget {
  const _FilterChipsRow();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AggregateSearchCubit, AggregateSearchState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              alignment: WrapAlignment.start,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (state.pendingSources.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      '${t.common.loading} ${state.pendingSources.length}',
                    ),
                  ),
                FilterChip(
                  showCheckmark: false,
                  label: Text(t.search.hasResults),
                  selected: state.showHasResults,
                  onSelected: (value) => context
                      .read<AggregateSearchCubit>()
                      .toggleHasResults(value),
                ),
                FilterChip(
                  showCheckmark: false,
                  label: Text(
                    state.errors.isEmpty
                        ? t.search.showErrors
                        : t.search.aggregateUnavailable(
                            count: state.errors.length,
                          ),
                  ),
                  selected: state.showErrors,
                  onSelected: state.errors.isEmpty
                      ? null
                      : (value) => context
                            .read<AggregateSearchCubit>()
                            .toggleShowErrors(value),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ResultList extends StatelessWidget {
  const _ResultList({required this.searchEvent, required this.state});

  final SearchEvent searchEvent;
  final AggregateSearchState state;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    final pluginStates = context.watch<PluginRegistryCubit>().state;
    final selectedIds = state.selectedSources.keys.toSet();
    final pluginIds = PluginRegistryService.I
        .sortPlugins(
          pluginStates.values.where(
            (plugin) =>
                selectedIds.contains(plugin.uuid) &&
                plugin.isEnabled &&
                !plugin.isDeleted,
          ),
        )
        .map((plugin) => plugin.uuid)
        .toList();
    for (final pluginId in pluginIds) {
      final selected = state.selectedSources[pluginId] ?? false;
      if (!selected) {
        continue;
      }

      final items = state.results[pluginId] ?? const <dynamic>[];
      final category = state.categoryPreviews[pluginId];
      final error = state.errors[pluginId] ?? '';
      final notice = state.notices[pluginId];
      final refreshing = state.refreshingSources.contains(pluginId);

      final shouldShowResultSection =
          items.isNotEmpty ||
          (explicitKeywordSearchScope(searchEvent.searchStates.pluginExtern) ==
                  KeywordSearchScope.title &&
              (state.filteredCounts[pluginId] ?? 0) > 0) ||
          (!state.showHasResults &&
              notice == null &&
              error.isEmpty &&
              !state.pendingSources.contains(pluginId));
      if (shouldShowResultSection) {
        final videos = items.whereType<ApiVideoItem>().toList();
        final List<ComicSimplifyEntryInfo> entries =
            items.isNotEmpty && videos.isEmpty
            ? mapToUnifiedComicSimplifyEntryInfoList(items)
            : const <ComicSimplifyEntryInfo>[];
        children.add(
          Padding(
            key: ValueKey('aggregate-source-$pluginId'),
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: _sourceTitle(pluginId),
                  subtitle: t.search.aggregatePreviewCount(count: items.length),
                  onTap: () => _openSourceSearch(context, pluginId),
                ),
                if (videos.isNotEmpty)
                  _AggregateVideoStrip(
                    items: videos,
                    onOpen: (item) => _openVideoItem(context, pluginId, item),
                  ),
                if (entries.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: ComicFixedSizeHorizontalList(
                      key: ValueKey('aggregate-list-$pluginId'),
                      entries: entries,
                      spacing: 10,
                      itemWidth: 112,
                    ),
                  ),
                if (entries.isEmpty && videos.isEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(14, 2, 14, 8),
                    child: Text(
                      (state.filteredCounts[pluginId] ?? 0) > 0
                          ? t.videoLibrary.filteredLoaded(
                              loaded: state.filteredCounts[pluginId]!,
                              shown: 0,
                            )
                          : t.search.noResults,
                    ),
                  ),
              ],
            ),
          ),
        );
      }

      if (category != null) {
        final label = category.topic == null
            ? t.search.aggregateCategoryPreview(category: category.category)
            : '${t.videoLibrary.genres} · ${category.category}';
        children.add(
          Padding(
            key: ValueKey('aggregate-category-$pluginId'),
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: '${_sourceTitle(pluginId)} · $label',
                  subtitle: category.items.isEmpty
                      ? ''
                      : t.search.aggregatePreviewCount(
                          count: category.items.length,
                        ),
                  onTap: () => _openSourceSearch(
                    context,
                    pluginId,
                    category: category.topic == null ? category.category : null,
                    topic: category.topic,
                  ),
                ),
                if (category.items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: ComicFixedSizeHorizontalList(
                      entries: mapToUnifiedComicSimplifyEntryInfoList(
                        category.items,
                      ),
                      spacing: 10,
                      itemWidth: 112,
                    ),
                  ),
              ],
            ),
          ),
        );
      }

      if (notice != null) {
        children.add(
          Padding(
            key: ValueKey('aggregate-entry-$pluginId'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: const Icon(Icons.ondemand_video_outlined),
              title: Text(_sourceTitle(pluginId)),
              subtitle: Text(
                notice == AggregateSourceNotice.inSource
                    ? t.search.inSourceSearchHint
                    : t.search.sourceSearchUnsupported,
              ),
              trailing: notice == AggregateSourceNotice.inSource
                  ? IconButton(
                      tooltip: t.search.continueInSource,
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _openSourceSearch(context, pluginId),
                    )
                  : null,
              onTap: notice == AggregateSourceNotice.inSource
                  ? () => _openSourceSearch(context, pluginId)
                  : null,
            ),
          ),
        );
      }
      if (state.showErrors && error.isNotEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline),
                title: Text(
                  t.search.loadFailedForSource(source: _sourceTitle(pluginId)),
                ),
                subtitle: Text(
                  error == 'login'
                      ? t.navigation.needLoginTitle
                      : error == 'timeout'
                      ? t.search.searchRequestTimedOut
                      : error == 'verification'
                      ? t.search.inSourceSearchHint
                      : t.search.searchRequestFailed,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: SizedBox.square(
                  dimension: 48,
                  child: refreshing
                      ? const Center(
                          child: SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: error == 'login'
                              ? t.navigation.goLogin
                              : error == 'verification'
                              ? t.search.continueInSource
                              : t.common.refresh,
                          icon: Icon(
                            error == 'login'
                                ? Icons.login
                                : error == 'verification'
                                ? Icons.chevron_right
                                : Icons.refresh,
                          ),
                          onPressed: () {
                            if (error == 'login') {
                              context.pushRoute(LoginRoute(from: pluginId));
                            } else if (error == 'verification') {
                              _openSourceSearch(context, pluginId);
                            } else {
                              context
                                  .read<AggregateSearchCubit>()
                                  .refreshSource(pluginId);
                            }
                          },
                        ),
                ),
              ),
            ),
          ),
        );
      }
    }

    if (children.isEmpty) {
      if (state.pendingSources.isNotEmpty)
        return const Center(child: CircularProgressIndicator());
      if (state.errors.isNotEmpty)
        return Center(
          child: Text(
            t.search.aggregateUnavailable(count: state.errors.length),
          ),
        );
      final filtered = state.filteredCounts.values.fold<int>(
        0,
        (a, b) => a + b,
      );
      if (filtered > 0)
        return Center(
          child: Text(
            t.videoLibrary.filteredLoaded(loaded: filtered, shown: 0),
          ),
        );
      return Center(child: Text(t.search.noResults));
    }

    return JmCoverLikeScope(
      counts: JmListLikeCounts.instance,
      child: ListView(children: children),
    );
  }

  String _sourceTitle(String pluginId) {
    final info = PluginRegistryService.I.getCachedPluginInfo(pluginId);
    final name = info?['name']?.toString().trim() ?? '';
    if (name.isNotEmpty) {
      return name;
    }
    return t.bookshelf.unknownSource;
  }

  void _openVideoItem(
    BuildContext context,
    String pluginId,
    ApiVideoItem item,
  ) {
    final video = videoSourceAction(
      PluginRegistryService.I.getCachedPluginInfo(pluginId),
      home: item.detailUrl,
    );
    if (video == null) return;
    DiscoverRouter.route(
      context,
      currentFrom: pluginId,
      action: {
        ...video,
        'payload': {
          ...asJsonMap(video['payload']),
          'source': pluginId,
          'bookshelfItem': item.toLibraryJson(),
        },
      },
    );
  }

  void _openSourceSearch(
    BuildContext context,
    String pluginId, {
    String? category,
    CopySearchTopic? topic,
  }) {
    final video = aggregateVideoSourceAction(
      PluginRegistryService.I.getCachedPluginInfo(pluginId),
    );
    if (video != null) {
      DiscoverRouter.route(
        context,
        currentFrom: pluginId,
        action: {
          ...video,
          'payload': {
            ...asJsonMap(video['payload']),
            'source': pluginId,
            'initialQuery': searchEvent.searchStates.searchKeyword,
            'initialKeywordScope': keywordSearchScope(
              searchEvent.searchStates.pluginExtern,
            ).name,
          },
        },
      );
      return;
    }
    final search = searchEvent.searchStates;
    final sourceStates = topic != null
        ? copyTopicSearchState(search, topic)
        : category == null
        ? search.copyWith(
            from: pluginId,
            pluginExtern: aggregateComicSearchExtern(search, pluginId),
          )
        : aggregateCategorySearch(search, pluginId, category);
    context.pushRoute(
      SearchResultRoute(
        key: ValueKey(const Uuid().v4()),
        searchEvent: searchEvent.copyWith(searchStates: sourceStates, page: 1),
      ),
    );
  }
}

class _AggregateVideoStrip extends StatelessWidget {
  const _AggregateVideoStrip({required this.items, required this.onOpen});
  final List<ApiVideoItem> items;
  final ValueChanged<ApiVideoItem> onOpen;
  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context);
    return SizedBox(
      height: 168 + scale.scale(14) * 2.8 + scale.scale(12) * 1.5 + 12,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          return SizedBox(
            width: 112,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onOpen(item),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 112,
                    height: 168,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ApiVideoPoster(item: item),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    [
                      item.year,
                      item.remarks,
                    ].where((s) => s.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
