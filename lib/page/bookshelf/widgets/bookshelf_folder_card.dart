import 'package:material_ui/material_ui.dart';
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
  static const _menuSize = 44.0;
  static const _countGap = 4.0;

  /// The video list uses fixed extents for its leading folder rows. Allow
  /// two title lines and a work count stacked above the menu at large sizes.
  static double videoListHeight(BuildContext context) =>
      (_listTopPadding +
              BookshelfContentLayout.titleHeight(context) +
              _countGap +
              BookshelfContentLayout.subtitleHeight(context) +
              _menuSize)
          .clamp(120.0, double.infinity);

  @override
  Widget build(BuildContext context) {
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
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(height: 1.3),
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
          CollectionPressFeedback(
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
                              8,
                              menu == null ? _listTopPadding : _menuSize,
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
              top: view == BookshelfContentView.grid ? 3 : null,
              bottom: view == BookshelfContentView.list ? 0 : null,
              end: 0,
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
    final counts = Column(
      key: const ValueKey('shelf-folder.counts'),
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          t.videoLibrary.results(count: workCount!),
          textAlign: TextAlign.end,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
        if (subfolderCount != null)
          Text(
            t.bookshelf.subfolderCount(count: subfolderCount!),
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <
            MediaQuery.textScalerOf(context).scale(154)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              caption,
              const SizedBox(height: _countGap),
              counts,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: caption),
            const SizedBox(width: 8),
            Flexible(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: counts,
              ),
            ),
          ],
        );
      },
    );
  }
}
