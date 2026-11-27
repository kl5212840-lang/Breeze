import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart'
    show normalizePluginId;
import 'package:zephyr/widgets/collection_cover_fit.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'package:zephyr/page/search_result/widgets/bottom_loader.dart';
import 'package:zephyr/page/discover/service/discover_router.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/text/chinese_convert.dart';
import 'package:zephyr/service/comic_like_updates.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';
import 'package:zephyr/widgets/comic_entry/comic_record_time.dart';
import 'package:zephyr/widgets/comic_simplify_entry/cover.dart';
import 'package:zephyr/widgets/comic_simplify_entry/jm_cover_like_badge.dart';
import 'package:zephyr/widgets/work_list_divider.dart';
import 'package:zephyr/widgets/source_page_divider.dart';
import 'package:zephyr/widgets/detailed_metadata.dart';
import 'package:zephyr/service/plugin_account_authentication.dart';

String formatSourceComicTimestamp(String value) =>
    formatComicRecordTimestamp(value);

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
    this.collectionLayout = false,
    this.quietPaging = false,
    this.entryBuilder,
    this.pageBreaks = const {},
    this.itemsSliverKey,
  });

  final Widget Function(UnifiedComicListItem, Widget)? entryBuilder;
  final List<UnifiedComicListItem> entries;

  /// Divider positions before the first visible item from a later source page.
  final Set<int> pageBreaks;
  final Key? itemsSliverKey;
  final bool hasReachedMax;
  final bool isLoadingMore;
  final bool loadMoreFailed;
  final VoidCallback onRetryLoadMore;
  final VoidCallback onLoadMore;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final bool collectionLayout, quietPaging;
  final VoidCallback? onReturned;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: controller,
      physics: physics ?? const AlwaysScrollableScrollPhysics(),
      shrinkWrap: shrinkWrap,
      slivers: [
        SliverList.builder(
          key: itemsSliverKey,
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            final tile = SourceSearchDetailTile(
              entry: entry,
              collectionLayout: collectionLayout,
              onReturned: onReturned,
              showMetadata: entryBuilder == null,
            );
            final inset = collectionLayout
                ? 12.0
                : CollectionToolbarMetrics.searchResultContentInset;
            final row = WorkListRow(
              divided:
                  index + 1 < entries.length && !pageBreaks.contains(index + 1),
              inset: inset,
              child: entryBuilder?.call(entry, tile) ?? tile,
            );
            if (index == 0 || !pageBreaks.contains(index)) return row;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SourcePageDivider(
                  key: ValueKey(('result-page-divider', index)),
                ),
                row,
              ],
            );
          },
        ),
        if (hasReachedMax)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(t.oldHome.noMore)),
            ),
          ),
        if (isLoadingMore && !quietPaging)
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
        if (!quietPaging && !hasReachedMax && !isLoadingMore && !loadMoreFailed)
          SliverToBoxAdapter(
            child: Center(
              child: TextButton.icon(
                onPressed: onLoadMore,
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

class SourceSearchDetailTile extends StatelessWidget {
  const SourceSearchDetailTile({
    super.key,
    required this.entry,
    this.type = ComicEntryType.normal,
    this.localRecord = false,
    this.collectionLayout = false,
    this.showMetadata = true,
    this.horizontalInset,
    this.onReturned,
  });

  final UnifiedComicListItem entry;
  final ComicEntryType type;

  /// Local saved-record revision is distinct from a source's comic update.
  final bool localRecord;
  final bool collectionLayout;
  final bool showMetadata;
  final double? horizontalInset;
  final VoidCallback? onReturned;

  void _returned(BuildContext context) {
    if (context.mounted && ModalRoute.of(context)?.isActive == true) {
      onReturned?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget coverImage({BoxFit fit = BoxFit.cover}) {
      final likeCounts = JmCoverLikeScope.maybeOf(context, entry.from);
      final image = CoverWidget(
        fileServer: entry.cover.url,
        path: entry.cover.cachePath,
        id: entry.id,
        pictureType: PictureType.cover,
        from: entry.from,
        width: collectionLayout ? 80 : 84,
        height: collectionLayout ? 120 : 116,
        fit: fit,
        containBackground: collectionLayout,
      );
      if (likeCounts == null) return image;
      return JmCoverLikeVisibility(
        comicId: entry.id,
        child: Stack(
          children: [
            image,
            PositionedDirectional(
              start: JmCoverLikeBadge.inset,
              end: JmCoverLikeBadge.inset,
              bottom: JmCoverLikeBadge.inset,
              child: JmCoverLikeBadge(counts: likeCounts, comicId: entry.id),
            ),
          ],
        ),
      );
    }

    return InkWell(
      key: ValueKey('detail-${entry.id}'),
      onTap: () async {
        await context.pushRoute(
          ComicInfoRoute(comicId: entry.id, type: type, from: entry.from),
        );
        if (context.mounted) _returned(context);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal:
              horizontalInset ??
              (collectionLayout
                  ? 12
                  : CollectionToolbarMetrics.searchResultContentInset),
          vertical: collectionLayout ? 6 : 11,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: collectionLayout
                  ? CollectionCoverFitBuilder(
                      builder: (_, fit) => coverImage(fit: fit),
                    )
                  : coverImage(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ComicDetailedCaption(
                entry: entry,
                type: type,
                localRecord: localRecord,
                showMetadata: showMetadata,
                onReturned: onReturned,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ComicDetailedCaption extends StatelessWidget {
  const ComicDetailedCaption({
    super.key,
    required this.entry,
    this.type = ComicEntryType.normal,
    this.localRecord = false,
    this.sourceName = '',
    this.showViews = true,
    this.showMetadata = true,
    this.rankCount,
    this.progress,
    this.onReturned,
  });

  final UnifiedComicListItem entry;
  final ComicEntryType type;
  final bool localRecord;
  final String sourceName;
  final bool showViews;
  final bool showMetadata;
  final String? progress, rankCount;
  final VoidCallback? onReturned;

  static const _gap = 2.0;
  static TextStyle _titleStyle(BuildContext context) =>
      (Theme.of(context).textTheme.titleSmall ?? const TextStyle(fontSize: 14))
          .copyWith(fontWeight: FontWeight.w700, height: 1.25);
  static TextStyle _detailStyle(BuildContext context) =>
      (Theme.of(context).textTheme.bodySmall ?? const TextStyle(fontSize: 12))
          .copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.35,
          );

  List<String> _values(String type) => entry
      .metadataValues(type)
      .map((value) => value.toString().trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList();

  bool get _jm => entry.source == PluginAccountAuthenticationService.jm;

  String get _updatedAt =>
      formatComicRecordTimestamp(entry.updatedAt, epochSeconds: _jm);

  void _returned(BuildContext context) {
    if (context.mounted && ModalRoute.of(context)?.isActive == true) {
      onReturned?.call();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: ComicLikeUpdates.instance,
    builder: (context, _) => _buildCaption(
      context,
      ComicLikeUpdates.instance.valueFor(comicLikeWork(entry.from, entry.id)),
    ),
  );

  Widget _buildCaption(BuildContext context, ComicLikeResult? vote) {
    final colors = Theme.of(context).colorScheme;
    final display = watchChineseDisplayConverter(context);
    final authors = _values('author');
    final history = type == ComicEntryType.history;
    final copy =
        normalizePluginId(entry.from) ==
        PluginAccountAuthenticationService.copy;
    final detailStyle = _detailStyle(context);
    final authorTarget = DetailedMetadata.actionExtentOf(context);
    final reportedAuthorActions = [
      if (!history)
        for (final raw in asJsonList(entry.extern['authorActions']))
          if (asJsonMap(raw) case final action)
            if (action['label']?.toString().trim().isNotEmpty == true &&
                asJsonMap(action['action']).isNotEmpty)
              action,
    ];
    final reportedAuthors = reportedAuthorActions
        .map((item) => item['label'].toString().trim())
        .toSet();
    final authorActions = copy ? const [] : reportedAuthorActions;
    final unlistedAuthors = reportedAuthors.difference(authors.toSet());
    final staticAuthor = copy
        ? {...authors, ...reportedAuthors}.join(' / ')
        : authors.where((name) => !reportedAuthors.contains(name)).join(' / ');
    final statuses = _values('status');
    final latest = _values('latest');
    final known = {
      authors.join(' / '),
      ...authors,
      ...statuses,
      ...latest,
      ...reportedAuthors,
    };
    final secondary = entry.subtitle
        .split(RegExp(r'\s*·\s*'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty && !known.contains(part));
    final keywords = {
      ...statuses,
      ...latest,
      ..._values('categories'),
      ..._values('category'),
      ..._values('tag'),
      ..._values('tags'),
      ...secondary,
    };
    final previewKeywordLimit = _jm ? 4 : 3;
    final summary = keywords.take(previewKeywordLimit).join(' · ');
    final reading = (progress ?? entry.subtitle).trim();
    final popularity = _values('popularity').firstOrNull;
    final updatedAt = history ? '' : _updatedAt;
    final updateLabel = updatedAt.isEmpty
        ? ''
        : localRecord
        ? t.comicEntry.recordUpdatedAt(time: updatedAt)
        : t.comicEntry.updatedAt(time: updatedAt);
    final pageCount = entry.publicPageCount;
    final likeCounts = JmCoverLikeScope.maybeOf(context, entry.from);
    final suppliedLikes = entry.publicLikesCount;
    final totalLikes = vote?.totalLikes ?? suppliedLikes;
    final totalViews = entry.publicViewsCount;
    final visibleLikes = likeCounts == null ? totalLikes : null;
    final metrics = [
      if (pageCount != null) t.searchResult.itemPageCount(count: pageCount),
      if (rankCount == null)
        if (showViews && totalViews != null)
          t.comicEntry.views(count: totalViews)
        else if (popularity != null)
          t.comicList.popularity(count: popularity)
        else if (entry.finished && !statuses.contains(t.comicEntry.finished))
          t.comicEntry.finished,
    ];
    final hasMetrics =
        visibleLikes != null || rankCount != null || metrics.isNotEmpty;

    final description = entry.raw['description'] is String
        ? (entry.raw['description'] as String).trim()
        : '';
    final storedUpdates = <String>{
      for (final (label, value) in entry.publicStoredTitleFacts)
        if (label == '更新' || label == '更新时间') formatSourceComicTimestamp(value),
    }..remove('');
    final metadata = [
      if (sourceName.isNotEmpty) (label: '', value: display(sourceName)),
      for (final group in entry.publicDetailMetadata(
        localRecord: localRecord || history,
      ))
        (label: display(group.label), value: display(group.values.join(' · '))),
      if (unlistedAuthors.isNotEmpty)
        (label: '', value: display(unlistedAuthors.join(' · '))),
      if (secondary.isNotEmpty)
        (label: '', value: display(secondary.join(' · '))),
      if (description.isNotEmpty)
        (label: t.comicInfo.description, value: display(description)),
      if (history && reading.isNotEmpty)
        (
          label: '',
          value: display(
            progress == null ? t.bookshelf.readTo(chapter: reading) : reading,
          ),
        ),
      if (history && comicLastReadTimestamp(entry).isNotEmpty)
        (
          label: '',
          value: t.comicEntry.lastReadAt(time: comicLastReadTimestamp(entry)),
        ),
      if (updateLabel.isNotEmpty) (label: '', value: updateLabel),
      for (final (label, value) in entry.publicStoredTitleFacts)
        if (label == '章节数') (label: display(label), value: display(value)),
      if (!history)
        for (final update in storedUpdates)
          if (localRecord || update != updatedAt)
            (label: '', value: t.comicEntry.updatedAt(time: update)),
      if (visibleLikes != null)
        (label: '', value: t.comicInfo.likes(count: visibleLikes)),
      if (pageCount != null)
        (label: '', value: t.searchResult.itemPageCount(count: pageCount)),
      if (rankCount case final count?) (label: '', value: display(count)),
      if (totalViews != null)
        (label: '', value: t.comicEntry.views(count: totalViews)),
      if (entry.finished && !statuses.contains(t.comicEntry.finished))
        (label: '', value: t.comicEntry.finished),
    ];

    Widget line(String value, {Color? color, String? semanticsLabel}) => Text(
      display(value),
      semanticsLabel: semanticsLabel,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: color == null ? detailStyle : detailStyle.copyWith(color: color),
    );

    return DetailedMetadata(
      title: display(entry.title),
      fields: showMetadata ? metadata : const [],
      additional: !showMetadata || likeCounts == null
          ? null
          : (context) => ListenableBuilder(
              listenable: Listenable.merge([
                likeCounts,
                ComicLikeUpdates.instance,
              ]),
              builder: (context, _) {
                final exact =
                    ComicLikeUpdates.instance
                        .valueFor(comicLikeWork(entry.from, entry.id))
                        ?.totalLikes ??
                    likeCounts.countFor(entry.id) ??
                    suppliedLikes;
                if (exact == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    t.comicInfo.likes(count: exact),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              },
            ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: _gap,
        children: [
          Text(
            display(entry.title),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _titleStyle(context),
          ),
          if (sourceName.isNotEmpty ||
              staticAuthor.isNotEmpty ||
              authorActions.isNotEmpty)
            Row(
              spacing: 6,
              children: [
                if (sourceName.isNotEmpty) Flexible(child: line(sourceName)),
                for (final item in authorActions)
                  Flexible(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.square(authorTarget),
                        alignment: AlignmentDirectional.centerStart,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () async {
                        await DiscoverRouter.route(
                          context,
                          action: asJsonMap(item['action']),
                          currentFrom: entry.from,
                        );
                        if (context.mounted) _returned(context);
                      },
                      child: line(
                        item['label'].toString(),
                        color: colors.primary,
                      ),
                    ),
                  ),
                if (staticAuthor.isNotEmpty)
                  Flexible(
                    child: line(
                      staticAuthor,
                      color: copy ? colors.onSurfaceVariant : colors.primary,
                    ),
                  ),
              ],
            ),
          if (!history && summary.isNotEmpty)
            line(
              keywords.length > previewKeywordLimit ? '$summary …' : summary,
            ),
          if (history && reading.isNotEmpty)
            line(
              progress == null ? t.bookshelf.readTo(chapter: reading) : reading,
            ),
          if (history && comicLastReadTimestamp(entry).isNotEmpty)
            ComicLastReadLine(item: entry),
          if (updateLabel.isNotEmpty &&
              (_jm || localRecord || summary.isEmpty || !hasMetrics))
            line(updateLabel),
          if (hasMetrics)
            Wrap(
              spacing: 8,
              runSpacing: _gap,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (rankCount != null) line(rankCount!),
                if (visibleLikes != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: [
                      Icon(
                        vote?.liked == true
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 15,
                        color: colors.primary,
                      ),
                      Flexible(
                        child: line(
                          '$visibleLikes',
                          semanticsLabel: t.comicInfo.likes(
                            count: visibleLikes,
                          ),
                        ),
                      ),
                    ],
                  ),
                for (final metric in metrics) line(metric),
              ],
            ),
        ],
      ),
    );
  }
}
