import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'dart:async';

import 'package:zephyr/widgets/read_recovery_scope.dart';
import 'package:zephyr/page/search/method/search_history_entries.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/method/copy_search_topic.dart';
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
import 'package:zephyr/page/search_result/view/search_bar.dart';
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
  });

  final SearchEvent searchEvent;
  final SearchCubit? searchCubit;
  @override
  Widget wrappedRoute(BuildContext context) {
    final pluginStates = context.read<PluginRegistryCubit>().state;
    final visiblePlugins = _activePlugins(pluginStates);
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
            initialSelectedSources: {
              for (final plugin in visiblePlugins) plugin.uuid: true,
            },
            sourceDefinitions: _sourceDefinitions(visiblePlugins),
          )..search(),
        ),
      ],
      child: BlocListener<PluginRegistryCubit, Map<String, PluginRuntimeState>>(
        listener: (context, plugins) {
          final visiblePlugins = _activePlugins(plugins);
          unawaited(
            context.read<AggregateSearchCubit>().updateAvailableSources({
              for (final plugin in visiblePlugins) plugin.uuid,
            }, definitions: _sourceDefinitions(visiblePlugins)),
          );
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

List<PluginRuntimeState> _activePlugins(
  Map<String, PluginRuntimeState> plugins,
) => PluginRegistryService.I.sortPlugins(
  plugins.values.where((plugin) => plugin.isActive),
);

Map<String, Object> _sourceDefinitions(Iterable<PluginRuntimeState> plugins) =>
    {
      for (final plugin in plugins)
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
            keywordScope: keywordSearchScope(
              widget.searchEvent.searchStates.pluginExtern,
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ReadRecoveryHost(
      onActiveChanged: context.read<AggregateSearchCubit>().setReadActive,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: SearchResultQueryTitle.toolbarHeight(context),
          leadingWidth: CollectionToolbarMetrics.leadingExtentOf(context),
          leading: CollectionToolbarMetrics.leading(
            context,
            const SourceBackButton(bare: true),
          ),
          titleSpacing: 0,
          actionsPadding: CollectionToolbarMetrics.trailingPadding,
          title: _SearchBarTrigger(searchEvent: widget.searchEvent),
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
      ),
    );
  }
}

class _SearchBarTrigger extends StatelessWidget {
  const _SearchBarTrigger({required this.searchEvent});

  final SearchEvent searchEvent;

  @override
  Widget build(BuildContext context) {
    final keyword = searchEvent.searchStates.searchKeyword;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        end: CollectionToolbarMetrics.sourceContentInset,
      ),
      child: SearchResultQueryTitle(
        key: const ValueKey('aggregate.query-title'),
        title: keyword.trim().isEmpty ? t.search.title : keyword,
        onEdit: () => _openSearchPage(context),
      ),
    );
  }

  void _openSearchPage(BuildContext context) {
    final stack = context.router.stack;
    if (stack.length > 1 && stack[stack.length - 2].name == SearchRoute.name) {
      context.maybePop();
      return;
    }

    context.pushRoute(
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
      builder: (context, state) => Padding(
        padding: CollectionToolbarMetrics.contentPaddingOf(context, bottom: 4),
        child: SingleChildScrollView(
          key: const ValueKey('aggregate.result-tools'),
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: CollectionToolbarMetrics.searchControlGap,
            children: [
              FilterChip(
                showCheckmark: false,
                label: Text(t.search.hasResults),
                selected: state.showHasResults,
                onSelected: context
                    .read<AggregateSearchCubit>()
                    .toggleHasResults,
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
                    : context.read<AggregateSearchCubit>().toggleShowErrors,
              ),
              if (state.pendingSources.isNotEmpty)
                Text('${t.common.loading} ${state.pendingSources.length}'),
            ],
          ),
        ),
      ),
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
    for (final plugin in _activePlugins(pluginStates)) {
      final pluginId = plugin.uuid;
      if (state.selectedSources[pluginId] != true) continue;

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
