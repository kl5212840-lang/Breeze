import 'package:material_ui/material_ui.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/bookshelf/bloc/folder_shelf_state.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_content_layout.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_folder_card.dart';
import 'package:zephyr/type/pipe.dart';
import 'package:zephyr/util/text/chinese_convert.dart';
import 'package:zephyr/service/folder_cover_identity.dart';
import 'package:zephyr/widgets/folder_cover_menu.dart';
import 'package:zephyr/service/folder_cover_service.dart';

class FolderShelfItem extends StatelessWidget {
  const FolderShelfItem({
    super.key,
    required this.folder,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTapDown,
    this.selectionMode = false,
    this.isSelected = false,
    this.count,
    this.subtitle = '',
    this.view = BookshelfContentView.grid,
    this.canEditCover,
    this.menu,
  });
  final ComicFolder folder;
  final ComicShelfFolderCount? count;
  final VoidCallback? onTap;
  final GestureLongPressStartCallback? onLongPress;
  final GestureTapDownCallback? onSecondaryTapDown;
  final bool selectionMode, isSelected;
  final String subtitle;
  final BookshelfContentView view;
  final bool Function()? canEditCover;
  final Widget? menu;

  @override
  Widget build(BuildContext context) => BookshelfFolderCard(
    title: folder.name.let(convertChineseForDisplay),
    imageKey: FolderCoverIdentity.comic(folder.syncId),
    menu:
        menu ??
        FolderCoverMenu(
          onCover: view == BookshelfContentView.grid,
          target: FolderCoverService.comic(folder, canRun: canEditCover),
          canRun: canEditCover,
        ),
    subtitle: subtitle,
    workCount: count?.works,
    subfolderCount: count?.subfolders,
    view: view,
    onTap: onTap,
    onLongPress: onLongPress,
    onSecondaryTapDown: onSecondaryTapDown,
    selectionMode: selectionMode,
    isSelected: isSelected,
  );
}
