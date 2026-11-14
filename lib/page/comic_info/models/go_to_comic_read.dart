import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/cubit/string_select.dart';
import 'package:zephyr/page/comic_info/method/get_plugin_detail.dart';
import 'package:zephyr/page/download/adapters/download_chapter_adapter.dart';
import 'package:zephyr/page/download/adapters/download_chapter_matcher.dart';
import 'package:zephyr/page/download/models/download_chapter.dart';
import 'package:zephyr/page/comic_read/method/get_local_info.dart';
import 'package:zephyr/service/reader/reader_history_service.dart';
import 'package:zephyr/page/comic_read/type/chapter_extern.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/config/router/router.gr.dart' show ComicReadRoute;

import 'package:zephyr/page/comic_info/models/read_launch_adapter.dart';

void goToComicRead(
  BuildContext context,
  String comicId,
  ComicEntryType type,
  dynamic allInfo,
  String from, {
  ReaderHistoryService? historyService,
}) {
  final isDownload =
      type == ComicEntryType.download ||
      type == ComicEntryType.historyAndDownload;
  final historyForChapter = (historyService ?? ReaderHistoryService.instance)
      .currentResumePosition(source: from, comicId: comicId);
  final chapters = resolveReaderChapters(allInfo, from, offline: isDownload);
  final readChapter = _resolveChapter(chapters, historyForChapter);
  final readComicId = resolveReadComicId(allInfo, from, isDownload: isDownload);
  final readEpsCount = chapters.length;
  final hasHistory = historyForChapter != null;

  final typeVal = hasHistory
      ? (isDownload
            ? ComicEntryType.historyAndDownload
            : ComicEntryType.history)
      : (isDownload ? ComicEntryType.download : ComicEntryType.normal);
  final orderVal = readChapter?.order ?? 1;

  context.pushRoute(
    ComicReadRoute(
      comicId: readComicId,
      order: orderVal,
      chapterId: readChapter?.id ?? '',
      requestId: readChapter?.effectiveRequestId ?? '',
      storageChapterId: readChapter?.storageId ?? '',
      logicalKey: readChapter?.id ?? '',
      chapterExtern: ChapterExtern.from(
        readChapter?.extern ?? const <String, dynamic>{},
      ),
      epsNumber: readEpsCount,
      from: from,
      type: typeVal,
      comicInfo: allInfo,
      stringSelectCubit: context.read<StringSelectCubit>(),
    ),
  );
}

DownloadChapter? _resolveChapter(
  List<UnifiedComicChapterRef> chapterRefs,
  ReaderResumePosition? history,
) {
  if (chapterRefs.isEmpty) {
    return null;
  }

  const adapter = DownloadChapterAdapter();
  const matcher = DownloadChapterMatcher();
  final chapters = chapterRefs.map(adapter.fromChapterRef).toList();

  if (history != null) {
    // 优先按 history.chapterId 匹配（可能是 logicalKey / id / requestId）。
    final chapterId = (history.chapterId).trim();
    if (chapterId.isNotEmpty) {
      final matched = matcher.find(chapters, chapterId);
      if (matched != null) {
        return matched;
      }
    }

    // 再按 history.chapterOrder 匹配。
    if (history.chapterOrder > 0) {
      final matched = matcher.findByOrder(chapters, history.chapterOrder);
      if (matched != null) {
        return matched;
      }
    }

    // 兼容老数据：chapterOrder 曾经被当 chapterId 用。
    final matched = matcher.find(chapters, history.chapterOrder.toString());
    if (matched != null) {
      return matched;
    }
  }

  return chapters.first;
}
