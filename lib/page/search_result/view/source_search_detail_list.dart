import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/search_result/widgets/bottom_loader.dart';
import 'package:zephyr/page/discover/service/discover_router.dart';
import 'package:zephyr/util/json/json_value.dart';
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
    this.physics,
    this.shrinkWrap = false,
  });

  final List<UnifiedComicListItem> entries;
  final bool hasReachedMax;
  final bool isLoadingMore;
  final bool loadMoreFailed;
  final VoidCallback onRetryLoadMore;
  final VoidCallback onLoadMore;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final VoidCallback? onReturned;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: controller,
      physics: physics ?? const AlwaysScrollableScrollPhysics(),
      shrinkWrap: shrinkWrap,
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

  List<String> _values(String type) => entry
      .metadataValues(type)
      .map((value) => value.toString().trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList();

  String get _updatedAt {
    final raw = entry.updatedAt.trim();
    if (raw.isEmpty || raw == '0') return '';
    final date = DateTime.tryParse(raw);
    // Some older adapters fill absent dates with the Unix epoch.
    if (date != null && date.year == 1970 && date.month == 1 && date.day == 1) {
      return '';
    }
    return raw;
  }

  void _returned(BuildContext context) {
    if (context.mounted && ModalRoute.of(context)?.isActive == true) {
      onReturned?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final authors = _values('author');
    final author = authors.join(' / ');
    final authorActions = [
      for (final raw in asJsonList(entry.extern['authorActions']))
        if (asJsonMap(raw) case final action)
          if (action['label']?.toString().trim().isNotEmpty == true &&
              asJsonMap(action['action']).isNotEmpty)
            action,
    ];
    final linkedAuthors = authorActions
        .map((item) => item['label'].toString().trim())
        .toSet();
    final staticAuthor = authors
        .where((name) => !linkedAuthors.contains(name))
        .join(' / ');
    final statuses = _values('status');
    final latest = _values('latest');
    final detail = {...statuses, ...latest}.join(' · ');
    final known = {
      author,
      ...authors,
      ...statuses,
      ...latest,
      ...authorActions.map((item) => item['label'].toString().trim()),
    };
    final secondary = type == ComicEntryType.history
        ? entry.subtitle.trim()
        : entry.subtitle
              .split(RegExp(r'\s*·\s*'))
              .map((part) => part.trim())
              .where((part) => part.isNotEmpty && !known.contains(part))
              .join(' · ');
    final categories = _values('categories').join(' · ');
    final tags = _values(
      'tags',
    ).where((tag) => !_values('categories').contains(tag)).join(' · ');
    final aliases = _values(
      'aliases',
    ).where((alias) => alias != entry.title.trim()).join(' / ');
    final popularity = _values('popularity').firstOrNull;
    final updatedAt = _updatedAt;
    final description = (entry.raw['description'] ?? '').toString().trim();
    final pageCount = int.tryParse('${entry.raw['pagesCount'] ?? ''}') ?? 0;
    final hasStats =
        entry.likesCount > 0 ||
        popularity != null ||
        (entry.finished && statuses.isEmpty) ||
        pageCount > 0;

    Widget line(String value, {Color? color, int maxLines = 1}) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        convertChineseForDisplay(value),
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color ?? colors.onSurfaceVariant,
          height: 1.3,
        ),
      ),
    );

    return InkWell(
      key: ValueKey('detail-${entry.id}'),
      onTap: () async {
        await context.pushRoute(
          ComicInfoRoute(comicId: entry.id, type: type, from: entry.from),
        );
        if (context.mounted) _returned(context);
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
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  if (authorActions.isNotEmpty)
                    LayoutBuilder(
                      builder: (context, constraints) => Wrap(
                        spacing: 8,
                        children: [
                          for (final item in authorActions)
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth,
                              ),
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  minimumSize: const Size(44, 44),
                                  alignment: Alignment.centerLeft,
                                ),
                                onPressed: () async {
                                  await DiscoverRouter.route(
                                    context,
                                    action: asJsonMap(item['action']),
                                    currentFrom: entry.from,
                                  );
                                  if (context.mounted) _returned(context);
                                },
                                child: Text(
                                  convertChineseForDisplay(
                                    item['label'].toString(),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (staticAuthor.isNotEmpty)
                    line(staticAuthor, color: colors.primary, maxLines: 2),
                  if (detail.isNotEmpty) line(detail),
                  if (secondary.isNotEmpty)
                    line(
                      type == ComicEntryType.history
                          ? '看到：$secondary'
                          : secondary,
                    ),
                  if (aliases.isNotEmpty)
                    line(t.comicList.aliases(names: aliases)),
                  if (categories.isNotEmpty) line(categories),
                  if (tags.isNotEmpty) line(tags, color: colors.secondary),
                  if (updatedAt.isNotEmpty)
                    line(t.comicEntry.updatedAt(time: updatedAt)),
                  if (description.isNotEmpty) line(description, maxLines: 2),
                  if (hasStats) ...[
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
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
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        if (popularity != null)
                          Text(
                            t.comicList.popularity(count: popularity),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        if (entry.finished && statuses.isEmpty)
                          Text(
                            '完结',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.primary,
                            ),
                          ),
                        if (pageCount > 0)
                          Text(
                            t.searchResult.itemPageCount(count: pageCount),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
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
