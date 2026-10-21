import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/search_result/widgets/bottom_loader.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/text/chinese_convert.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';
import 'package:zephyr/widgets/comic_simplify_entry/cover.dart';

class SourceSearchDetailList extends StatelessWidget {
  const SourceSearchDetailList({
    super.key,
    required this.entries,
    required this.hasReachedMax,
    required this.isLoadingMore,
    required this.loadMoreFailed,
    required this.onRetryLoadMore,
    required this.onLoadMore,
    this.controller,
    this.onReturned,
  });

  final List<UnifiedComicListItem> entries;
  final bool hasReachedMax;
  final bool isLoadingMore;
  final bool loadMoreFailed;
  final VoidCallback onRetryLoadMore;
  final VoidCallback onLoadMore;
  final ScrollController? controller;
  final VoidCallback? onReturned;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverList.builder(
          itemCount: entries.length,
          itemBuilder: (context, index) => SourceSearchDetailTile(
            entry: entries[index],
            onReturned: onReturned,
          ),
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

class SourceSearchDetailTile extends StatelessWidget {
  const SourceSearchDetailTile({
    super.key,
    required this.entry,
    this.type = ComicEntryType.normal,
    this.onReturned,
  });

  final UnifiedComicListItem entry;
  final ComicEntryType type;
  final VoidCallback? onReturned;

  String _metadata(String type) =>
      entry.metadataValues(type).join(' · ').trim();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final author = entry.metadataValues('author').join(' / ').trim();
    final secondary = entry.subtitle.trim();
    final categories = _metadata('categories');
    final tags = _metadata('tags');
    final description = (entry.raw['description'] ?? '').toString().trim();
    final pageCount = int.tryParse('${entry.raw['pagesCount'] ?? ''}') ?? 0;

    return InkWell(
      key: ValueKey('detail-${entry.id}'),
      onTap: () async {
        await context.pushRoute(
          ComicInfoRoute(comicId: entry.id, type: type, from: entry.from),
        );
        onReturned?.call();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: CoverWidget(
                fileServer: entry.cover.url,
                path: entry.cover.cachePath,
                id: entry.id,
                pictureType: PictureType.cover,
                from: entry.from,
                width: 84,
                height: 116,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    convertChineseForDisplay(entry.title),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  if (author.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      convertChineseForDisplay(author),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.primary),
                    ),
                  ],
                  if (secondary.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      convertChineseForDisplay(
                        type == ComicEntryType.history
                            ? '看到：$secondary'
                            : secondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (categories.isNotEmpty) ...[
                    const SizedBox(height: 4),
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
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      convertChineseForDisplay(tags),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.secondary, fontSize: 12),
                    ),
                  ],
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      convertChineseForDisplay(description),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.2,
                      ),
                    ),
                  ],
                  if (entry.likesCount > 0 ||
                      entry.finished ||
                      pageCount > 0) ...[
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 10,
                      runSpacing: 2,
                      children: [
                        if (entry.likesCount > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.favorite_border,
                                size: 15,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${entry.likesCount}',
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        if (entry.finished)
                          Text(
                            '完结',
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 12,
                            ),
                          ),
                        if (pageCount > 0)
                          Text(
                            t.searchResult.itemPageCount(count: pageCount),
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
