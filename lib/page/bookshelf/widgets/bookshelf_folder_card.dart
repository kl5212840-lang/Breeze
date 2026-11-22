import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_content_layout.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_folder_visual.dart';
import 'package:zephyr/widgets/collection_selection_mark.dart';
import 'package:zephyr/widgets/collection_press_feedback.dart';
import 'package:zephyr/service/local_appearance_images.dart';

class BookshelfFolderCard extends StatelessWidget {
  const BookshelfFolderCard({
    super.key,
    required this.title,
    this.subtitle = '',
    this.imageKey,
    this.workCount,
    this.subfolderCount,
    this.menu,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTapDown,
    this.selectionMode = false,
    this.isSelected = false,
    this.view = BookshelfContentView.grid,
  });
  final String title, subtitle;
  final String? imageKey;
  final int? workCount, subfolderCount;
  final Widget? menu;
  final VoidCallback? onTap;
  final GestureLongPressStartCallback? onLongPress;
  final GestureTapDownCallback? onSecondaryTapDown;
  final bool selectionMode, isSelected;
  final BookshelfContentView view;

  static const _listTopPadding = 12.0;
  static const _countGap = 4.0;

  /// The video list uses fixed extents for its leading folder rows. Allow
  /// two title lines and a work count at large sizes.
  static double videoListHeight(BuildContext context) =>
      (_listTopPadding * 2 +
              BookshelfContentLayout.titleHeight(context) +
              _countGap +
              BookshelfContentLayout.subtitleHeight(context))
          .clamp(120.0, double.infinity);

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(height: 1.3);
    final actionExtent = CollectionToolbarMetrics.actionExtentOf(context);
    final titleLineHeight =
        MediaQuery.textScalerOf(context).scale(titleStyle?.fontSize ?? 14) *
        1.3;
    final listMenuTop = (_listTopPadding + (titleLineHeight - actionExtent) / 2)
        .clamp(0.0, double.infinity);
    final poster = AspectRatio(
      aspectRatio: BookshelfContentLayout.coverAspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ValueListenableBuilder<Map<String, String>>(
            valueListenable: LocalAppearanceImages.instance.paths,
            builder: (context, paths, _) => BookshelfFolderVisual(
              imagePath: paths[imageKey],
              selected: selectionMode && isSelected,
            ),
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
    final caption = view == BookshelfContentView.list && subtitle.isEmpty
        ? Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          )
        : BookshelfCardCaption(
            title: title,
            subtitle: subtitle,
            fixedHeight: view == BookshelfContentView.grid,
          );
    return Semantics(
      button: true,
      selected: selectionMode ? isSelected : null,
      child: Stack(
        children: [
          CollectionPressFeedback.surface(
            enabled: onLongPress != null || onTap != null,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              onLongPressStart: onLongPress,
              onSecondaryTapDown: onSecondaryTapDown,
              child: view == BookshelfContentView.grid
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [poster, const SizedBox(height: 8), caption],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 80, child: poster),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                              0,
                              _listTopPadding,
                              menu == null ? 8 : actionExtent + 8,
                              _listTopPadding,
                            ),
                            child: workCount == null
                                ? caption
                                : _listDetails(context, caption),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          if (!selectionMode && menu != null)
            PositionedDirectional(
              top: view == BookshelfContentView.grid ? 3 : listMenuTop,
              end: view == BookshelfContentView.grid
                  ? 0
                  : CollectionToolbarMetrics.sourceContentInset -
                        BookshelfContentLayout.horizontalPadding,
              child: menu!,
            ),
        ],
      ),
    );
  }

  Widget _listDetails(BuildContext context, Widget caption) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.3,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: _countGap,
      children: [
        caption,
        Wrap(
          key: const ValueKey('shelf-folder.counts'),
          spacing: 8,
          runSpacing: 2,
          children: [
            Text(
              t.videoLibrary.results(count: workCount!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
            if (subfolderCount case final count?)
              Text(
                t.bookshelf.subfolderCount(count: count),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
          ],
        ),
      ],
    );
  }
}
