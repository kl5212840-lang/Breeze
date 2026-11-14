import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/comic_read/widgets/image/read_image_widget.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/page/comic_read/widgets/modes/read_mode_utils.dart';
import 'package:zephyr/widgets/picture_bloc/models/picture_info.dart';

/// 构造列/行模式共用的图片 widget。
///
/// - [slotIndex] 会作为 [ReadImageWidget] 的 `pageSlotIndex`。
/// - [cacheIndex] 会作为 [ReadImageWidget] 的 `sizeCacheIndex`。
/// - [displayNumber] 用于行模式等需要显式页号的场景；为 null 时使用 [slotIndex] + 1。
Widget buildReadModeImage({
  required BuildContext context,
  required ReadModeEntry entry,
  required String comicId,
  required String from,
  required int slotIndex,
  required int cacheIndex,
  required bool isColumn,
  int? displayNumber,
  Alignment imageAlignment = Alignment.center,
}) {
  if (entry.type != ReadModeEntryType.image ||
      entry.doc == null ||
      entry.chapterId == null) {
    return const SizedBox.shrink();
  }

  return ReadImageWidget(
    key: ValueKey((
      from,
      comicId,
      entry.chapterId,
      entry.doc!.storageChapterId,
      entry.chapterOrder,
      entry.chapterPageIndex,
      entry.doc!.fileServer,
      entry.doc!.path,
    )),
    pictureInfo: PictureInfo(
      from: from,
      url: entry.doc!.fileServer,
      path: entry.doc!.path,
      cartoonId: comicId,
      chapterId: entry.chapterId!,
      storageChapterId: entry.doc!.storageChapterId,
      pictureType: PictureType.page,
      extern: entry.doc!.extern,
    ),
    useDownloads: ReaderDecodedImageScope.of(context)?.offline == true,
    index: slotIndex,
    cacheIndex: cacheIndex,
    displayNumber: displayNumber,
    chapterPage: entry.chapterPageIndex == null
        ? null
        : entry.chapterPageIndex! + 1,
    isColumn: isColumn,
    imageAlignment: imageAlignment,
  );
}
