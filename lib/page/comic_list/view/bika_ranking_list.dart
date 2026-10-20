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

/// The ranked feed uses the source's leaderboard count, not lifetime views.
class BikaRankingList extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverList.builder(
          itemCount: entries.length,
          itemBuilder: (context, index) =>
              _RankingTile(entry: entries[index], rank: index + 1),
        ),
        if (hasReachedMax)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(t.oldHome.noMore)),
            ),
          ),
        if (isLoadingMore)
          const SliverToBoxAdapter(child: Center(child: BottomLoader())),
        if (loadMoreFailed)
          SliverToBoxAdapter(
            child: Center(
              child: TextButton(
                onPressed: onRetryLoadMore,
                child: Text(t.oldHome.loadMoreFailed),
              ),
            ),
          ),
        if (!hasReachedMax && !isLoadingMore && !loadMoreFailed)
          SliverToBoxAdapter(
            child: Center(
              child: TextButton.icon(
                onPressed: onLoadMore,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                label: Text(t.oldHome.loadMore),
              ),
            ),
          ),
      ],
    );
  }
}

class _RankingTile extends StatelessWidget {
  const _RankingTile({required this.entry, required this.rank});

  final UnifiedComicListItem entry;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final categories = entry.metadataValues('categories').join(' · ');
    final count =
        entry.raw['leaderboardCount'] ?? entry.raw['leaderboard_count'];
    final creator = entry.extern['rankingCreator'] == true;
    final rankColor = switch (rank) {
      1 => const Color(0xFFE9A800),
      2 => const Color(0xFFD486A8),
      3 => const Color(0xFFC75D7B),
      _ => colors.onSurfaceVariant,
    };
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
            Container(
              width: 32,
              height: 110,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: rank <= 3 ? rankColor : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$rank',
                style: TextStyle(
                  color: rank <= 3 ? Colors.white : colors.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
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
                    if (count != null || creator)
                      Text(
                        creator
                            ? '上传作品  ${entry.raw['comicsUploaded'] ?? 0}'
                            : '指名次数  $count',
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
