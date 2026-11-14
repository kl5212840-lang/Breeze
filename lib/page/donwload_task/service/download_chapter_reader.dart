import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/cubit/string_select.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/page/comic_read/method/get_local_info.dart';
import 'package:zephyr/page/comic_read/type/chapter_extern.dart';
import 'package:zephyr/page/download/models/unified_comic_download.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';
import 'package:zephyr/type/enum.dart';

import 'package:zephyr/page/donwload_task/service/download_center_resources.dart';
import 'package:zephyr/service/reader/comic_chapter_reading_progress.dart';
import 'package:zephyr/service/reader/reader_history_service.dart';

typedef DownloadedReaderPosition = ({String key, String title, int page});

/// The download center derives its resume row from the same saved
/// chapters and the same progress the reader uses when it opens a chapter.
DownloadedReaderPosition? resolveDownloadedReaderPosition(
  DownloadComicResource resource,
  ReaderResumePosition? latest,
  ComicChapterReadingProgress progress,
) {
  final chapters = resource.downloadChapters;
  final identities = <String, int>{};
  final aliases = <String, int>{};
  final chapterAliases = <Set<String>>[];
  for (final (index, chapter) in chapters.indexed) {
    final stored = resource.chapters[index];
    final keys = {
      chapter.effectiveRequestId,
      stored.id.trim(),
      stored.taskChapterId.trim(),
    }..removeAll({'', chapter.id});
    chapterAliases.add(keys);
    identities.update(chapter.id, (count) => count + 1, ifAbsent: () => 1);
    for (final key in keys) {
      aliases.update(key, (count) => count + 1, ifAbsent: () => 1);
    }
  }
  final latestKey = latest?.chapterId;
  // A shared legacy ID does not identify the current chapter. Only use older
  // progress when the current ID is unambiguous or the chapter is absent.
  if (latestKey != null &&
      (identities[latestKey] ?? aliases[latestKey] ?? 0) > 1) {
    return null;
  }
  DownloadedReaderPosition? fallback;
  int? fallbackTime;
  for (final (index, chapter) in chapters.indexed) {
    if (chapter.images.isEmpty || identities[chapter.id] != 1) continue;
    final keys = [
      chapter.id,
      ...chapterAliases[index].where(
        (key) => !identities.containsKey(key) && aliases[key] == 1,
      ),
    ];
    final revision = progress.lookupRevision(
      resource.source,
      resource.comicId,
      keys,
    );
    final matchesLatest = latest != null && keys.contains(latestKey);
    final page =
        revision?.progress?.pageIndex ??
        (matchesLatest ? latest.pageIndex - 1 : 1);
    final position = (
      key: chapter.id,
      title: chapter.displayName,
      page: page.clamp(1, chapter.images.length),
    );
    if (matchesLatest) return position;
    if (revision != null &&
        (fallbackTime == null || revision.at > fallbackTime)) {
      fallback = position;
      fallbackTime = revision.at;
    }
  }
  return fallback;
}

/// Builds an offline reader launch for the exact chapter the user tapped.
/// The download-page owner retains the cubit across reader route replacements;
/// normal reader history writes and the caller's navigation stack are reused.
abstract final class DownloadChapterReader {
  static ComicReadRoute? findRoute({
    required String source,
    required String comicId,
    required String chapterKey,
    required StringSelectCubit stringSelectCubit,
  }) {
    final query = objectbox.unifiedDownloadBox
        .query(
          UnifiedComicDownload_.uniqueKey.equals(
            buildDownloadTaskKey(source, comicId),
          ),
        )
        .build();
    try {
      final record = query.findFirst();
      if (record == null) return null;
      return route(
        record: record,
        chapterKey: chapterKey,
        stringSelectCubit: stringSelectCubit,
      );
    } finally {
      query.close();
    }
  }

  static ComicReadRoute? route({
    required UnifiedComicDownload record,
    required String chapterKey,
    required StringSelectCubit stringSelectCubit,
  }) {
    if (record.deleted ||
        record.source.trim().isEmpty ||
        record.comicId.trim().isEmpty ||
        stringSelectCubit.isClosed)
      return null;
    try {
      final chapter = findLocalDownloadChapterByKey(record, chapterKey);
      if (chapter == null || chapter.images.isEmpty) return null;
      return ComicReadRoute(
        comicInfo: record,
        comicId: record.comicId,
        from: record.source,
        type: ComicEntryType.download,
        order: chapter.order,
        chapterId: chapter.id,
        requestId: chapter.effectiveRequestId,
        storageChapterId: chapter.effectiveStorageId,
        logicalKey: chapter.id,
        chapterExtern: ChapterExtern.from(chapter.extern),
        epsNumber: resolveDownloadChapters(
          record,
        ).where((chapter) => chapter.images.isNotEmpty).length,
        stringSelectCubit: stringSelectCubit,
      );
    } catch (_) {
      // Damaged or stale local metadata never turns into an online launch.
      return null;
    }
  }
}
