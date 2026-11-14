import 'package:flutter/widgets.dart'
    show Size, WidgetsBinding, AppLifecycleState;
import 'package:zephyr/network/http/picture/picture.dart';
import 'package:zephyr/page/comic_read/cubit/image_size_cubit.dart';
import 'package:zephyr/page/comic_read/json/common_ep_info_json/common_ep_info_json.dart';
import 'package:zephyr/page/comic_read/method/image_header_size.dart';
import 'package:zephyr/page/comic_read/widgets/layout/read_layout.dart';
import 'package:zephyr/type/enum.dart';

/// 后台预解析章节图片尺寸并写入 [ImageSizeCubit]。
///
/// 列表项在图片加载前使用默认占位高度（宽 × 1.2），图片解析出真实尺寸后
/// 高度突变会造成可见的布局跳动（自动平滑滚动时尤其明显）。
/// 本函数在章节就绪后主动解析**已存在于本地**（缓存/下载目录）的图片
/// 文件头尺寸，让列表项高度尽量提前就位；未下载的图片直接跳过
/// （不触发任何网络请求），其尺寸仍走图片显示时的原有上报路径。
/// 返回尚未完成的首个页索引，全部处理后返回 [docs] 的长度。
Future<int> prefetchChapterImageSizes({
  required ImageSizeCubit imageSizeCubit,
  required List<Doc> docs,
  required String comicId,
  required String from,
  required String chapterId,
  required int chapterOrder,
  required double contentWidth,
  int startPage = 0,
  bool? offlineReader,
  bool Function()? ownsReaderSession,
  Future<Size?> Function(Doc doc)? readCachedSize,
}) async {
  bool isActive() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return !imageSizeCubit.isClosed &&
        ownsReaderSession?.call() != false &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
  }

  final load =
      readCachedSize ??
      (Doc doc) async {
        final filePath = await findCachedPicturePath(
          from: from,
          path: doc.path,
          url: doc.fileServer,
          cartoonId: comicId,
          chapterId: chapterId,
          storageChapterId: doc.storageChapterId.trim(),
          pictureType: PictureType.page,
          offlineReader: offlineReader,
        );
        if (filePath.isEmpty || !isActive()) return null;
        return readImageHeaderSize(filePath);
      };

  for (var i = startPage; i < docs.length; i++) {
    if (!isActive()) return i;

    final cacheIndex = resolveStableSizeCacheIndex(
      chapterOrder: chapterOrder,
      localPageIndex: i,
    );
    if (imageSizeCubit.getSize(cacheIndex).isCached) continue;

    try {
      final rawSize = await load(docs[i]);
      if (!isActive()) return i;
      // 文件读取期间，显示层可能已用当前布局上报了更准确的尺寸。
      if (imageSizeCubit.getSize(cacheIndex).isCached) continue;
      if (rawSize == null || rawSize.width <= 0 || rawSize.height <= 0) {
        continue;
      }

      // 与 ImageDisplay 上报保持一致：存渲染宽度 + 等比高度。
      final displayHeight = contentWidth * (rawSize.height / rawSize.width);
      imageSizeCubit.updateSize(cacheIndex, Size(contentWidth, displayHeight));
    } catch (_) {
      // 单张失败不影响其余图片。
    }
  }
  return docs.length;
}
