import 'package:zephyr/page/comic_info/method/get_plugin_detail.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/page/comic_read/json/common_ep_info_json/common_ep_info_json.dart'
    show Doc;
import 'package:zephyr/page/comic_read/model/normal_comic_ep_info.dart';
import 'package:zephyr/page/download/adapters/download_chapter_matcher.dart';
import 'package:zephyr/page/download/models/download_chapter.dart';
import 'package:zephyr/page/download/models/unified_comic_download.dart';

List<UnifiedComicChapterRef> resolveReaderChapters(
  dynamic comicInfo,
  String source, {
  required bool offline,
}) {
  if (!offline || comicInfo is! UnifiedComicDownload) {
    return resolveUnifiedComicChapters(comicInfo, source);
  }
  return [
    for (final chapter in resolveDownloadChapters(comicInfo))
      if (chapter.images.isNotEmpty)
        UnifiedComicChapterRef(
          id: chapter.id,
          name: chapter.displayName,
          order: chapter.order,
          requestId: chapter.effectiveRequestId,
          storageChapterId: chapter.effectiveStorageId,
          logicalKey: chapter.id,
          groupTitle: chapter.groupTitle,
          extern: chapter.extern,
        ),
  ];
}

/// Exact stored identities only. Numeric chapter orders and shared storage
/// directories cannot silently select another chapter after a stale click.
DownloadChapter? findLocalDownloadChapterByKey(
  UnifiedComicDownload download,
  String chapterKey,
) {
  final key = chapterKey.trim();
  if (key.isEmpty || download.deleted) return null;
  final chapters = resolveDownloadChapters(download);
  DownloadChapter? unique(Iterable<DownloadChapter> values) {
    final matches = values.toList();
    return matches.length == 1 ? matches.single : null;
  }

  final ids = chapters.where((chapter) => chapter.id.trim() == key).toList();
  if (ids.isNotEmpty) return unique(ids);
  final requests = chapters
      .where((chapter) => chapter.effectiveRequestId.trim() == key)
      .toList();
  if (requests.isNotEmpty) return unique(requests);
  final stored = resolveStoredDownloadChapters(download);
  if (stored.length != chapters.length) return null;
  return unique([
    for (var i = 0; i < stored.length; i++)
      if (stored[i].id.trim() == key || stored[i].taskChapterId.trim() == key)
        chapters[i],
  ]);
}

/// Historical identities for one exact local chapter. Ignore aliases that
/// identify several rows or collide with another chapter's canonical ID.
Iterable<String> localDownloadChapterHistoryKeys(
  UnifiedComicDownload download,
  String chapterId,
) sync* {
  yield chapterId;
  final chapters = resolveDownloadChapters(download);
  final stored = resolveStoredDownloadChapters(download);
  if (chapters.length != stored.length) return;
  final index = chapters.indexWhere((chapter) => chapter.id == chapterId);
  if (index < 0) return;
  Set<String> keys(int i) => {
    chapters[i].id.trim(),
    stored[i].logicalKey.trim(),
    stored[i].taskChapterId.trim(),
    stored[i].id.trim(),
  }..remove('');
  final aliases = keys(index)..remove(chapterId);
  for (var i = 0; i < chapters.length; i++) {
    if (i != index) aliases.removeAll(keys(i));
  }
  yield* aliases;
}

void _logLocalInfo(
  int epsId,
  DownloadChapter chapter,
  List<DownloadImage> images,
) {
  logger.d(
    'getPluginInfoFromLocal: epsId=$epsId, '
    'chapter.id=${chapter.id}, order=${chapter.order}, '
    'requestId=${chapter.effectiveRequestId}, '
    'storageId=${chapter.effectiveStorageId}, '
    'imageCount=${images.length}, '
    'firstPath=${images.isNotEmpty ? images.first.path : ''}',
  );
}

Future<NormalComicEpInfo> getPluginInfoFromLocal(
  String pluginId,
  String comicId,
  int epsId, {
  String? chapterKey,
}) async {
  final resolvedPluginId = pluginId.trim();
  if (resolvedPluginId.isEmpty) {
    throw StateError('pluginId 不能为空');
  }

  final download = _readDownload(resolvedPluginId, comicId);
  if (download == null) {
    throw StateError('本地下载信息不存在: $resolvedPluginId:$comicId');
  }
  final chapters = resolveDownloadChapters(download);
  if (chapters.isEmpty) throw StateError('本地下载没有章节数据');
  const matcher = DownloadChapterMatcher();
  final key = chapterKey?.trim() ?? '';
  final chapter = key.isEmpty
      ? matcher.findByOrder(chapters, epsId) ??
            matcher.find(chapters, epsId.toString()) ??
            chapters.first
      : findLocalDownloadChapterByKey(download, key);
  if (chapter == null || chapter.images.isEmpty) {
    throw StateError('本地下载章节不存在');
  }
  return _localReaderChapter(epsId, chapter);
}

UnifiedComicDownload? _readDownload(String source, String comicId) {
  final query = objectbox.unifiedDownloadBox
      .query(UnifiedComicDownload_.uniqueKey.equals('$source:$comicId'))
      .build();
  final UnifiedComicDownload? download;
  try {
    download = query.findFirst();
  } finally {
    query.close();
  }
  return download == null || download.deleted ? null : download;
}

NormalComicEpInfo _localReaderChapter(int epsId, DownloadChapter chapter) {
  final orderedDocs = chapter.images
      .map(
        (image) => Doc(
          originalName: image.name,
          path: image.path,
          // The offline reader and its prefetcher share these docs. An empty
          // URL makes missing local files fail without a network fallback.
          fileServer: '',
          id: image.id.isNotEmpty ? image.id : chapter.id,
          storageChapterId: chapter.effectiveStorageId,
          extern: Map<String, dynamic>.from(image.extern),
        ),
      )
      .toList();

  _logLocalInfo(epsId, chapter, chapter.images);

  return NormalComicEpInfo(
    length: orderedDocs.length,
    epPages: orderedDocs.length.toString(),
    docs: orderedDocs,
    epId: chapter.id,
    epName: chapter.displayName,
  );
}
