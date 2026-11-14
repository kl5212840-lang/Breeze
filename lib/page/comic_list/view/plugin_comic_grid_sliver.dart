import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_content_layout.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry.dart';
import 'package:zephyr/util/text/chinese_convert.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/search_result/widgets/bottom_loader.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry_grid.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry_info.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/type/enum.dart';

class PluginComicGridSliver extends StatelessWidget {
  const PluginComicGridSliver({
    super.key,
    required this.entries,
    this.type = ComicEntryType.normal,
    this.refresh,
    this.onDeleteSuccess,
    required this.hasReachedMax,
    required this.isLoadingMore,
    required this.loadMoreFailed,
    required this.onRetryLoadMore,
    required this.onLoadMore,
    this.controller,
    this.physics,
    this.shrinkWrap = false,
    this.collectionLayout = false,
    this.quietPaging = false,
    this.onEntryTap,
    this.onEntryLongPress,
    this.onEntrySecondaryTapDown,
    this.isEntrySelected,
    this.selectionMode = false,
    this.collectionTargetId,
    this.collectionTargetName,
  });

  final List<ComicSimplifyEntryInfo> entries;
  final ComicEntryType type;
  final VoidCallback? refresh;
  final ValueChanged<String>? onDeleteSuccess;
  final bool hasReachedMax;
  final bool isLoadingMore;
  final bool loadMoreFailed;
  final VoidCallback onRetryLoadMore;
  final VoidCallback onLoadMore;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final bool shrinkWrap, collectionLayout, quietPaging;
  final ValueChanged<ComicSimplifyEntryInfo>? onEntryTap;
  final void Function(
    ComicSimplifyEntryInfo info,
    LongPressStartDetails details,
  )?
  onEntryLongPress;
  final void Function(ComicSimplifyEntryInfo info, TapDownDetails details)?
  onEntrySecondaryTapDown;
  final bool Function(ComicSimplifyEntryInfo entry)? isEntrySelected;
  final bool selectionMode;
  final String? collectionTargetId;
  final String? collectionTargetName;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: controller,
      physics: physics,
      shrinkWrap: shrinkWrap,
      slivers: [
        if (collectionLayout)
          SliverLayoutBuilder(
            builder: (context, constraints) => SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              sliver: SliverGrid(
                gridDelegate: BookshelfContentLayout.gridDelegate(
                  context,
                  constraints.crossAxisExtent,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final info = entries[index];
                  return ComicSimplifyEntry(
                    info: info,
                    type: type,
                    coverAspectRatio: BookshelfContentLayout.coverAspectRatio,
                    caption: BookshelfCardCaption(
                      title: convertChineseForDisplay(info.title),
                      subtitle: convertChineseForDisplay(info.detailMetadata),
                    ),
                    onTapOverride: onEntryTap,
                    refresh: refresh,
                    collectionTargetId: collectionTargetId,
                    collectionTargetName: collectionTargetName,
                  );
                }, childCount: entries.length),
              ),
            ),
          )
        else
          BaseComicGridSliver(
            entries: entries,
            type: type,
            refresh: refresh,
            onDeleteSuccess: onDeleteSuccess,
            onEntryTap: onEntryTap,
            onEntryLongPress: onEntryLongPress,
            onEntrySecondaryTapDown: onEntrySecondaryTapDown,
            isEntrySelected: isEntrySelected,
            selectionMode: selectionMode,
            collectionTargetId: collectionTargetId,
            collectionTargetName: collectionTargetName,
          ),
        if (hasReachedMax)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Text(
                  t.oldHome.noMore,
                  style: const TextStyle(fontSize: 20.0),
                ),
              ),
            ),
          ),
        if (isLoadingMore && !quietPaging)
          const SliverToBoxAdapter(child: Center(child: BottomLoader())),
        if (loadMoreFailed)
          SliverToBoxAdapter(
            child: Center(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: onRetryLoadMore,
                    child: Text(t.oldHome.loadMoreFailed),
                  ),
                ],
              ),
            ),
          ),
        if (!collectionLayout &&
            !hasReachedMax &&
            !isLoadingMore &&
            !loadMoreFailed)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14, top: 6),
                child: TextButton.icon(
                  onPressed: onLoadMore,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  label: Text(t.oldHome.loadMore),
                ),
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
