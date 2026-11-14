import 'package:zephyr/widgets/plugin_installation_guard.dart';
import 'package:zephyr/widgets/collection_selection_mark.dart';
import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:uuid/uuid.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/type/pipe.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/widgets/collection_press_feedback.dart';

import 'package:zephyr/main.dart';
import 'package:zephyr/network/http/picture/picture.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/service/reader/reader_history_service.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/util/text/chinese_convert.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry_info.dart';
import 'package:zephyr/widgets/comic_simplify_entry/cover.dart';
import 'package:zephyr/widgets/comic_simplify_entry/jm_cover_like_badge.dart';

const double kComicCardBorderRadius = 5.0;

class ComicFixedSizeHorizontalList extends StatelessWidget {
  final List<ComicSimplifyEntryInfo> entries;
  final double spacing; // 卡片之间的横向间距
  final double itemWidth; // 卡片固定宽度
  final bool roundedCorner; // 是否有圆角
  final bool useRandomImageKey;
  final bool titleBelow;

  const ComicFixedSizeHorizontalList({
    super.key,
    required this.entries,
    this.spacing = 10.0, // 默认间距设为 10
    this.itemWidth = 200, // 固定宽度，不随窗口宽高比变化
    this.roundedCorner = true,
    this.useRandomImageKey = false,
    this.titleBelow = false,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    // 使用固定的宽高，避免在 Windows 桌面端拖动窗口时因
    // MediaQuery.orientation 随宽高比切换而导致高度跳变
    final double itemHeight = itemWidth / 0.75;

    // 最外层需要限制高度，否则横向 ListView 会报错
    return SizedBox(
      height: itemHeight + (titleBelow ? 42 : 0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final info = entries[index];

          // 过滤无数据的情况
          if (info.title == "无数据") {
            return const SizedBox.shrink();
          }
          final cover = _buildCover(
            context,
            info,
            itemWidth,
            itemHeight,
            useRandomImageKey
                ? ValueKey('cover-${const Uuid().v4()}')
                : ValueKey('cover-${info.from}:${info.id}:${info.path}'),
          );

          return Padding(
            padding: EdgeInsets.only(right: spacing),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _navigateToComicInfo(context, info),
              child: SizedBox(
                width: itemWidth,
                height: itemHeight + (titleBelow ? 42 : 0),
                child: titleBelow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          cover,
                          const SizedBox(height: 5),
                          Text(
                            info.title.let(convertChineseForDisplay),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      )
                    : cover,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCover(
    BuildContext context,
    ComicSimplifyEntryInfo info,
    double width,
    double height,
    Key coverKey,
  ) {
    final circular = roundedCorner ? kComicCardBorderRadius : 0.0;
    final likeCounts = JmCoverLikeScope.maybeOf(context, info.from);
    final image = CoverWidget(
      key: coverKey,
      fileServer: info.fileServer,
      path: info.path,
      id: info.id,
      pictureType: info.pictureType,
      from: info.from,
      roundedCorner: roundedCorner,
      width: width,
      height: height,
    );
    if (titleBelow && likeCounts == null) return image;
    final cover = Stack(
      children: [
        image,
        if (!titleBelow)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.7],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(circular),
                  bottomRight: Radius.circular(circular),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(5.0, 20.0, 5.0, 5.0),
              child: Text(
                info.title.let(convertChineseForDisplay),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.0,
                  fontWeight: FontWeight.w500,
                  shadows: [
                    Shadow(
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                  ],
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.start,
              ),
            ),
          ),
        if (likeCounts != null)
          PositionedDirectional(
            top: JmCoverLikeBadge.inset,
            start: JmCoverLikeBadge.inset,
            end: JmCoverLikeBadge.inset,
            child: JmCoverLikeBadge(counts: likeCounts, comicId: info.id),
          ),
      ],
    );
    return likeCounts == null
        ? cover
        : JmCoverLikeVisibility(comicId: info.id, child: cover);
  }

  // 点击跳转逻辑 (需要把当前的 info 传进来)
  Future<void> _navigateToComicInfo(
    BuildContext context,
    ComicSimplifyEntryInfo info,
  ) async {
    final pluginId = (info.source.trim().isNotEmpty ? info.source : info.from)
        .trim();
    if (pluginId.isEmpty ||
        !await ensurePluginInstalled(context, pluginId) ||
        !context.mounted) {
      return;
    }
    context.pushRoute(
      ComicInfoRoute(
        comicId: info.id,
        type: ComicEntryType.normal,
        from: pluginId,
      ),
    );
  }
}

class ComicSimplifyEntry extends StatelessWidget {
  final ComicSimplifyEntryInfo info;
  final ComicEntryType type;
  final VoidCallback? refresh;
  final ValueChanged<String>? onDeleteSuccess;
  final ValueChanged<ComicSimplifyEntryInfo>? onTapOverride;
  final void Function(
    ComicSimplifyEntryInfo info,
    LongPressStartDetails details,
  )?
  onLongPressOverride;
  final void Function(ComicSimplifyEntryInfo info, TapDownDetails details)?
  onSecondaryTapDown;
  final bool isSelected;
  final bool selectionMode;
  final bool topPadding;
  final bool roundedCorner;
  final String? collectionTargetId;
  final String? collectionTargetName;
  final Widget? caption;
  final double coverAspectRatio;
  final bool horizontal;

  const ComicSimplifyEntry({
    super.key,
    required this.info,
    required this.type,
    this.refresh,
    this.onDeleteSuccess,
    this.onTapOverride,
    this.onLongPressOverride,
    this.onSecondaryTapDown,
    this.isSelected = false,
    this.selectionMode = false,
    this.topPadding = true,
    this.roundedCorner = true,
    this.collectionTargetId,
    this.collectionTargetName,
    this.caption,
    this.coverAspectRatio = 0.75,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    if (info.title == "无数据") {
      return const SizedBox.shrink();
    }
    final title = caption == null
        ? watchChineseDisplayConverter(context)(info.title)
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = horizontal ? 80.0 : constraints.maxWidth;
        final height = width / coverAspectRatio;

        return Semantics(
          selected: selectionMode ? isSelected : null,
          child: CollectionPressFeedback(
            enabled:
                onLongPressOverride != null || type != ComicEntryType.normal,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                final onTapHandler = onTapOverride;
                if (onTapHandler != null) {
                  onTapHandler(info);
                  return;
                }
                _navigateToComicInfo(context);
              },
              onLongPressStart: (details) {
                final onLongPressHandler = onLongPressOverride;
                if (onLongPressHandler != null) {
                  onLongPressHandler(info, details);
                  return;
                }
                if (type != ComicEntryType.normal) {
                  _showDeleteDialog(context);
                }
              },
              onSecondaryTapDown: (details) {
                onSecondaryTapDown?.call(info, details);
              },
              child: caption == null
                  ? SizedBox(
                      width: width,
                      height: height,
                      child: _buildCoverWithTitle(
                        context,
                        width,
                        height,
                        title,
                      ),
                    )
                  : horizontal
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: width,
                          height: height,
                          child: _buildCoverWithTitle(
                            context,
                            width,
                            height,
                            title,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: caption!),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: width,
                          height: height,
                          child: _buildCoverWithTitle(
                            context,
                            width,
                            height,
                            title,
                          ),
                        ),
                        const SizedBox(height: 8),
                        caption!,
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCoverWithTitle(
    BuildContext context,
    double width,
    double height,
    String? title,
  ) {
    final circular = roundedCorner ? kComicCardBorderRadius : 0.0;
    final likeCounts = JmCoverLikeScope.maybeOf(context, info.from);
    final cover = ClipRRect(
      borderRadius: BorderRadius.circular(circular),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CollectionSelectionTint(
            selected: selectionMode && isSelected,
            child: CoverWidget(
              fileServer: info.fileServer,
              path: info.path,
              id: info.id,
              pictureType: info.pictureType,
              from: info.from,
              roundedCorner: roundedCorner,
              width: width,
              height: height,
            ),
          ),
          if (title != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.7],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(circular),
                    bottomRight: Radius.circular(circular),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(5.0, 20.0, 5.0, 5.0),
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.0,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        offset: const Offset(0, 1),
                        blurRadius: 2,
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                  maxLines: 3, // 最多显示3行
                  overflow: TextOverflow.ellipsis, // 超出部分显示省略号
                  textAlign:
                      TextAlign.start, // 文字对齐方式，也可以用 TextAlign.center 居中显示
                ),
              ),
            ),
          if (likeCounts != null)
            PositionedDirectional(
              top: JmCoverLikeBadge.inset,
              start: JmCoverLikeBadge.inset,
              end: selectionMode
                  ? CollectionSelectionMark.inset +
                        CollectionSelectionMark.size +
                        JmCoverLikeBadge.inset
                  : JmCoverLikeBadge.inset,
              child: JmCoverLikeBadge(counts: likeCounts, comicId: info.id),
            ),
          PositionedDirectional(
            top: CollectionSelectionMark.inset,
            end: CollectionSelectionMark.inset,
            child: CollectionSelectionMark(
              visible: selectionMode,
              selected: isSelected,
            ),
          ),
        ],
      ),
    );
    return likeCounts == null
        ? cover
        : JmCoverLikeVisibility(comicId: info.id, child: cover);
  }

  Future<void> _navigateToComicInfo(BuildContext context) async {
    final pluginId = (info.source.trim().isNotEmpty ? info.source : info.from)
        .trim();
    if (pluginId.isEmpty) return;
    if (type != ComicEntryType.download &&
        !await ensurePluginInstalled(context, pluginId)) {
      return;
    }
    if (!context.mounted) return;
    context.pushRoute(
      ComicInfoRoute(
        comicId: info.id,
        type: type,
        from: pluginId,
        collectionTargetId: collectionTargetId,
        collectionTargetName: collectionTargetName,
      ),
    );
  }

  Future<void> _showDeleteDialog(BuildContext context) async {
    final (title, content) = _getDialogContent();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () {
              context.router.pop();
              _handleDeleteAction(context);
            },
            child: Text(t.common.confirm),
          ),
        ],
      ),
    );
  }

  (String, String) _getDialogContent() {
    logger.d(type);
    switch (type) {
      case ComicEntryType.favorite:
        return (
          t.comicEntry.deleteFavorite,
          t.comicEntry.deleteFavoriteConfirm(
            title: info.title.let(convertChineseForDisplay),
          ),
        );
      case ComicEntryType.history:
        return (
          t.comicEntry.deleteHistory,
          t.comicEntry.deleteHistoryConfirm(
            title: info.title.let(convertChineseForDisplay),
          ),
        );
      case ComicEntryType.download:
        return (
          t.comicEntry.deleteDownload,
          t.comicEntry.deleteDownloadConfirm(
            title: info.title.let(convertChineseForDisplay),
          ),
        );
      default:
        return ("", "");
    }
  }

  Future<void> _handleDeleteAction(BuildContext context) async {
    try {
      if (type == ComicEntryType.history) {
        await _deleteHistory();
      } else if (type == ComicEntryType.download) {
        await _deleteDownload();
      } else if (type == ComicEntryType.favorite) {
        await _deleteFavorite();
      }
      final deletedKey = '${info.from.trim()}:${info.id}';
      if (onDeleteSuccess != null) {
        onDeleteSuccess!(deletedKey);
      } else {
        refresh?.call();
      }
    } catch (e, s) {
      logger.e('删除失败', error: e, stackTrace: s);
      showErrorToast(t.comicEntry.deleteFailed);
    }
  }

  Future<void> _deleteHistory() async {
    final uniqueKey = '${info.from.trim()}:${info.id}';
    final temp = objectbox.unifiedHistoryBox
        .query(UnifiedComicHistory_.uniqueKey.equals(uniqueKey))
        .build()
        .findFirst();

    if (temp != null) {
      await ReaderHistoryService.instance.deleteHistoryRecord(temp);
    }
  }

  Future<void> _deleteDownload() async {
    final uniqueKey = '${info.from.trim()}:${info.id}';
    final temp = objectbox.unifiedDownloadBox
        .query(UnifiedComicDownload_.uniqueKey.equals(uniqueKey))
        .build()
        .findFirst();

    if (temp != null) {
      objectbox.unifiedDownloadBox.remove(temp.id);
      await _deleteDownloadDirectory(info.id);
    }
  }

  Future<void> _deleteFavorite() async {
    final uniqueKey = '${info.from.trim()}:${info.id}';
    final temp = objectbox.unifiedFavoriteBox
        .query(UnifiedComicFavorite_.uniqueKey.equals(uniqueKey))
        .build()
        .findFirst();

    if (temp != null) {
      temp.deleted = true;
      temp.updatedAt = DateTime.now().toUtc();
      objectbox.unifiedFavoriteBox.put(temp);
    }
  }

  Future<void> _deleteDownloadDirectory(String id) async {
    try {
      await deleteComicDownloadDirectory(info.from, id);
      logger.d('目录已成功删除: $id');
    } catch (e) {
      logger.e('删除目录时发生错误: $e');
      throw Exception('删除目录失败');
    }
  }
}
