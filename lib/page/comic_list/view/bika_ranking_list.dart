import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'dart:math' as math;
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';
import 'package:zephyr/page/bookshelf/widgets/shelf_filter_sheet.dart';
import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/search_result/widgets/bottom_loader.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search_result/bloc/search_bloc.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/text/chinese_convert.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';
import 'package:zephyr/widgets/comic_simplify_entry/cover.dart';
import 'package:zephyr/widgets/work_list_divider.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';

/// The ranked feed uses the source's leaderboard count, not lifetime views.
class BikaRankingList extends StatefulWidget {
  const BikaRankingList({
    super.key,
    required this.entries,
    required this.hasReachedMax,
    required this.isLoadingMore,
    required this.loadMoreFailed,
    required this.onRetryLoadMore,
    required this.onLoadMore,
    this.controller,
  });

  final List<UnifiedComicListItem> entries;
  final bool hasReachedMax;
  final bool isLoadingMore;
  final bool loadMoreFailed;
  final VoidCallback onRetryLoadMore;
  final VoidCallback onLoadMore;
  final ScrollController? controller;

  @override
  State<BikaRankingList> createState() => _BikaRankingListState();
}

class _BikaRankingListState extends State<BikaRankingList> {
  ShelfFacetSelection _filters = const ShelfFacetSelection();
  bool _openingFilters = false;
  int _revision = 0;

  ShelfFacetEntry _facet(UnifiedComicListItem entry) {
    Set<String> values(List<String> types) => {
      for (final type in types)
        for (final value in entry.metadataValues(type))
          if (value.toString().trim().isNotEmpty) value.toString().trim(),
    };
    return ShelfFacetEntry(
      key: entry.id,
      source: entry.source,
      searchText: entry.title.toLowerCase(),
      fields: {
        'category': values(['categories', 'category']),
        'author': values(['author']),
        'tags': values(['tags', 'tag']),
      }..removeWhere((_, values) => values.isEmpty),
    );
  }

  @override
  void didUpdateWidget(covariant BikaRankingList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.entries, widget.entries)) _revision++;
  }

  Future<void> _editFilters() async {
    if (_openingFilters || widget.isLoadingMore) return;
    _openingFilters = true;
    final revision = _revision;
    try {
      final result = await showShelfFilterSheet(
        context,
        entries: widget.entries.map(_facet).toList(),
        initial: _filters,
        preferenceKey:
            'bika.ranking|${widget.entries.firstOrNull?.source ?? ''}',
        scopeLabel: t.bikaRanking.filterLoaded,
        currentFolder: null,
        hierarchical: false,
      );
      if (mounted && revision == _revision && result != null) {
        setState(() => _filters = result);
      }
    } finally {
      _openingFilters = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep the source's order and original positions after local filtering.
    final visible = widget.entries.indexed
        .where(
          (row) =>
              shelfFacetMatches(_facet(row.$2), _filters, currentFolder: null),
        )
        .toList();
    final rankStyle = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    final rankMeasure = TextPainter(
      text: TextSpan(
        text: '8' * math.max(2, widget.entries.length.toString().length),
        style: rankStyle,
      ),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
    )..layout();
    final rankWidth = math.max(24.0, rankMeasure.width.ceilToDouble());
    rankMeasure.dispose();
    return CustomScrollView(
      controller: widget.controller,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              CollectionToolbarMetrics.sourceContentInset,
              0,
              CollectionToolbarMetrics.sourceContentInset,
              4,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t.bikaRanking.loadedScope(
                      loaded: widget.entries.length,
                      shown: visible.length,
                    ),
                    key: const ValueKey('bika-ranking.loaded-scope'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                SourceFilterIconButton(
                  key: const ValueKey('bika-ranking.filters'),
                  bare: false,
                  tooltip: _filters.isActive
                      ? t.comicList.activeFilters
                      : t.bikaRanking.filterLoaded,
                  active: _filters.isActive,
                  onPressed: widget.isLoadingMore ? null : _editFilters,
                ),
              ],
            ),
          ),
        ),
        if (visible.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(t.bikaRanking.noLoadedMatches)),
            ),
          ),
        SliverList.builder(
          itemCount: visible.length,
          itemBuilder: (context, index) => WorkListRow(
            divided: index + 1 < visible.length,
            inset: 12,
            child: _RankingTile(
              entry: visible[index].$2,
              rank: visible[index].$1 + 1,
              rankWidth: rankWidth,
            ),
          ),
        ),
        if (widget.hasReachedMax && visible.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(t.oldHome.noMore)),
            ),
          ),
        if (widget.isLoadingMore)
          const SliverToBoxAdapter(child: Center(child: BottomLoader())),
        if (widget.loadMoreFailed)
          SliverToBoxAdapter(
            child: Center(
              child: TextButton(
                onPressed: widget.onRetryLoadMore,
                child: Text(t.oldHome.loadMoreFailed),
              ),
            ),
          ),
        if (!widget.hasReachedMax &&
            !widget.isLoadingMore &&
            !widget.loadMoreFailed)
          SliverToBoxAdapter(
            child: Center(
              child: TextButton.icon(
                onPressed: widget.onLoadMore,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                label: Text(t.oldHome.loadMore),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: SizedBox(height: NativeNavigationInset.scrollBottom(context)),
        ),
      ],
    );
  }
}

class _RankingTile extends StatelessWidget {
  const _RankingTile({
    required this.entry,
    required this.rank,
    required this.rankWidth,
  });

  final UnifiedComicListItem entry;
  final int rank;
  final double rankWidth;

  @override
  Widget build(BuildContext context) {
    final categories = entry.metadataValues('categories').join(' · ');
    final count =
        entry.raw['leaderboardCount'] ?? entry.raw['leaderboard_count'];
    final creator = entry.extern['rankingCreator'] == true;
    final colors = Theme.of(context).colorScheme;
    final rankColor = rank <= 3 ? colors.primary : colors.onSurfaceVariant;
    return InkWell(
      onTap: () => creator
          ? context.pushRoute(
              SearchResultRoute(
                searchEvent: SearchEvent().copyWith(
                  searchStates: SearchStates.initial().copyWith(
                    from: entry.from,
                    searchKeyword: entry.title,
                    pluginExtern: {'mode': 'creator', 'creatorId': entry.id},
                  ),
                ),
              ),
            )
          : context.pushRoute(
              ComicInfoRoute(
                comicId: entry.id,
                type: ComicEntryType.normal,
                from: entry.from,
              ),
            ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: rankWidth,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '$rank',
                  textAlign: TextAlign.center,
                  key: ValueKey('bika-ranking.rank.$rank'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: rank <= 3 ? colors.primary : colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CoverWidget(
                fileServer: entry.cover.url,
                path: entry.cover.cachePath,
                id: entry.id,
                pictureType: PictureType.cover,
                from: entry.from,
                width: 80,
                height: 110,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 110),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      convertChineseForDisplay(entry.title),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (entry.primaryText.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        convertChineseForDisplay(entry.primaryText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.primary, fontSize: 12),
                      ),
                    ],
                    if (categories.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        convertChineseForDisplay(categories),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    if (creator
                        ? entry.raw['comicsUploaded'] != null
                        : count != null)
                      Text(
                        creator
                            ? t.bikaRanking.uploadedCount(
                                count: entry.raw['comicsUploaded'].toString(),
                              )
                            : t.bikaRanking.nominationCount(
                                count: count.toString(),
                              ),
                        style: TextStyle(
                          color: rankColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
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
  }
}
