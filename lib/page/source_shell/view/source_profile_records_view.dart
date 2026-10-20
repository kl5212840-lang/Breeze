import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/search_result/view/source_search_detail_list.dart';
import 'package:zephyr/page/search_result/view/source_list_categories.dart';
import 'package:zephyr/page/search_result/view/source_list_filter_bar.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/text/chinese_convert.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry_grid.dart';
import 'package:zephyr/widgets/comic_simplify_entry/cover.dart';

String sourceProfileRecordLabel(ShelfPageMode mode) => switch (mode) {
  ShelfPageMode.favorite => '已收藏',
  ShelfPageMode.history => '最近观看',
  ShelfPageMode.download => '下载管理',
};

IconData sourceProfileRecordIcon(ShelfPageMode mode) => switch (mode) {
  ShelfPageMode.favorite => Icons.bookmark_outline,
  ShelfPageMode.history => Icons.history,
  ShelfPageMode.download => Icons.download_outlined,
};

ComicEntryType _entryType(ShelfPageMode mode) => switch (mode) {
  ShelfPageMode.favorite => ComicEntryType.favorite,
  ShelfPageMode.history => ComicEntryType.history,
  ShelfPageMode.download => ComicEntryType.download,
};

class SourceProfilePreviewSection extends StatelessWidget {
  const SourceProfilePreviewSection({
    super.key,
    required this.mode,
    required this.entries,
    required this.onViewAll,
    required this.onReturned,
  });

  final ShelfPageMode mode;
  final List<UnifiedComicListItem> entries;
  final VoidCallback onViewAll;
  final VoidCallback onReturned;

  @override
  Widget build(BuildContext context) => SourceProfileComicPreviewCard(
    previewKey: ValueKey('profile-preview-${mode.name}'),
    title: sourceProfileRecordLabel(mode),
    icon: sourceProfileRecordIcon(mode),
    countLabel: '${entries.length}',
    emptyMessage: switch (mode) {
      ShelfPageMode.favorite => '还没有收藏的漫画',
      ShelfPageMode.history => '还没有观看记录',
      ShelfPageMode.download => '还没有下载的漫画',
    },
    entries: entries,
    type: _entryType(mode),
    onViewAll: onViewAll,
    onReturned: onReturned,
  );
}

class SourceProfileComicPreviewCard extends StatelessWidget {
  const SourceProfileComicPreviewCard({
    super.key,
    required this.previewKey,
    required this.title,
    required this.icon,
    required this.entries,
    required this.type,
    required this.emptyMessage,
    required this.onViewAll,
    required this.onReturned,
    this.countLabel,
    this.loading = false,
    this.error,
    this.onRetry,
  });

  final Key previewKey;
  final String title;
  final IconData icon;
  final List<UnifiedComicListItem> entries;
  final ComicEntryType type;
  final String emptyMessage;
  final VoidCallback onViewAll;
  final VoidCallback onReturned;
  final String? countLabel;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: previewKey,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (countLabel != null) ...[
                Text(
                  countLabel!,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(width: 5),
              ],
              TextButton(onPressed: onViewAll, child: const Text('查看全部')),
            ],
          ),
          if (loading && entries.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 10, 4, 14),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else if (error != null && entries.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (onRetry != null)
                    TextButton(onPressed: onRetry, child: const Text('重试')),
                ],
              ),
            )
          else if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 14),
              child: Text(
                emptyMessage,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = math.min(132.0, (constraints.maxWidth - 20) / 3);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (
                      var index = 0;
                      index < math.min(3, entries.length);
                      index++
                    ) ...[
                      if (index > 0) const SizedBox(width: 10),
                      SizedBox(
                        width: width,
                        child: _PreviewCover(
                          entry: entries[index],
                          type: type,
                          onReturned: onReturned,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _PreviewCover extends StatelessWidget {
  const _PreviewCover({
    required this.entry,
    required this.type,
    required this.onReturned,
  });

  final UnifiedComicListItem entry;
  final ComicEntryType type;
  final VoidCallback onReturned;

  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey('profile-cover-${entry.source}:${entry.id}'),
    borderRadius: BorderRadius.circular(9),
    onTap: () async {
      await context.pushRoute(
        ComicInfoRoute(comicId: entry.id, type: type, from: entry.from),
      );
      onReturned();
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 0.77,
          child: LayoutBuilder(
            builder: (context, constraints) => ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: CoverWidget(
                fileServer: entry.cover.url,
                path: entry.cover.cachePath,
                id: entry.id,
                pictureType: PictureType.cover,
                from: entry.from,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          convertChineseForDisplay(entry.title),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class SourceProfileRecordsView extends StatefulWidget {
  const SourceProfileRecordsView({
    super.key,
    required this.mode,
    required this.entries,
    required this.onBack,
    required this.onRefresh,
    this.onManageFolders,
    this.source,
  });

  final ShelfPageMode mode;
  final List<UnifiedComicListItem> entries;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback? onManageFolders;
  final String? source;

  @override
  State<SourceProfileRecordsView> createState() =>
      _SourceProfileRecordsViewState();
}

class _SourceProfileRecordsViewState extends State<SourceProfileRecordsView> {
  bool _detailed = true;
  String _sort = 'new';
  final Set<String> _blockedCategories = {};

  void _toggleCategory(String category) {
    final wasBlocked = _blockedCategories.contains(category);
    setState(() {
      if (wasBlocked) {
        _blockedCategories.remove(category);
      } else {
        _blockedCategories.add(category);
      }
    });
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

  List<UnifiedComicListItem> _visibleEntries() {
    final visible = widget.entries
        .where((entry) => !isEntryBlockedByCategory(entry, _blockedCategories))
        .toList();
    switch (_sort) {
      case 'old':
        return visible.reversed.toList();
      case 'likes':
        visible.sort((a, b) => b.likesCount.compareTo(a.likesCount));
      case 'views':
        visible.sort((a, b) => b.viewsCount.compareTo(a.viewsCount));
    }
    return visible;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final visibleEntries = _visibleEntries();
    final sources = {
      if (widget.source != null) widget.source!,
      ...widget.entries.map((entry) => entry.source),
    };
    final categories = sources.expand(sourceQuickCategories).toSet().toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
          child: Row(
            children: [
              IconButton(
                tooltip: '返回我的',
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sourceProfileRecordLabel(widget.mode),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _blockedCategories.isEmpty
                          ? '${widget.entries.length} 本漫画'
                          : '${visibleEntries.length} / ${widget.entries.length} 本漫画',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onManageFolders != null)
                IconButton(
                  tooltip: '管理文件夹',
                  onPressed: widget.onManageFolders,
                  icon: const Icon(Icons.folder_outlined),
                ),
            ],
          ),
        ),
        SourceListFilterBar(
          categories: categories,
          blockedCategories: _blockedCategories,
          onCategoryTap: _toggleCategory,
          onClearBlockedCategories: () => setState(_blockedCategories.clear),
          sortValue: _sort,
          sortOptions: const {
            'new': '最新',
            'old': '最早',
            'likes': '最多喜欢',
            'views': '最多观看',
          },
          onSortChanged: (value) => setState(() => _sort = value),
          detailedView: _detailed,
          onViewChanged: (value) => setState(() => _detailed = value),
          viewToggleKey: const ValueKey('profile-grid-mode'),
        ),
        const Divider(height: 1),
        Expanded(
          child: visibleEntries.isEmpty
              ? Center(
                  child: Text(
                    widget.entries.isEmpty
                        ? '暂无${sourceProfileRecordLabel(widget.mode)}的漫画'
                        : '当前筛选没有匹配的漫画',
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => widget.onRefresh(),
                  child: _detailed
                      ? ListView.builder(
                          key: const ValueKey('profile-detailed-list'),
                          itemCount: visibleEntries.length,
                          itemBuilder: (context, index) =>
                              SourceSearchDetailTile(
                                entry: visibleEntries[index],
                                type: _entryType(widget.mode),
                                onReturned: widget.onRefresh,
                              ),
                        )
                      : GridView.builder(
                          key: const ValueKey('profile-cover-grid'),
                          padding: const EdgeInsets.all(10),
                          gridDelegate: buildComicSimplifyEntryGridDelegate(),
                          itemCount: visibleEntries.length,
                          itemBuilder: (context, index) => ComicSimplifyEntry(
                            info: visibleEntries[index].toSimplifyEntryInfo(),
                            type: _entryType(widget.mode),
                            refresh: widget.onRefresh,
                            onTapOverride: (info) async {
                              await context.pushRoute(
                                ComicInfoRoute(
                                  comicId: info.id,
                                  type: _entryType(widget.mode),
                                  from: info.source.trim().isEmpty
                                      ? info.from
                                      : info.source,
                                ),
                              );
                              widget.onRefresh();
                            },
                          ),
                        ),
                ),
        ),
      ],
    );
  }
}
