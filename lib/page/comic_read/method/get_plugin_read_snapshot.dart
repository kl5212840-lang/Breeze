import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/network/http/plugin/qjs_network_route.dart';
import 'package:zephyr/page/comic_info/method/get_plugin_detail.dart';
import 'package:zephyr/page/comic_read/model/comic_read_snapshot.dart';
import 'package:zephyr/page/comic_read/model/normal_comic_ep_info.dart';
import 'package:zephyr/page/comic_read/type/chapter_extern.dart';
import 'package:zephyr/page/download/adapters/download_chapter_adapter.dart';
import 'package:zephyr/page/download/adapters/download_chapter_matcher.dart';
import 'package:zephyr/page/download/models/download_chapter.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';

Future<NormalComicEpInfo> getPluginReadSnapshot(
  String comicId,
  int order,
  String from,
  dynamic comicInfo,
  String? selectedChapterId,
  String requestId,
  String logicalKey,
  String storageChapterId,
  ChapterExtern chapterExtern, {
  String? taskGroupKey,
  bool notifyUnauthorized = true,
}) async {
  final source = canonicalQjsSource(from);
  final generation = pluginSessionWriteFence.generation(source);
  if (pluginSessionWriteFence.isChanging(source)) {
    throw const PluginSessionChanged();
  }
  const adapter = DownloadChapterAdapter();
  const matcher = DownloadChapterMatcher();
  DownloadChapter? chapter;
  if (requestId.trim().isEmpty && logicalKey.trim().isEmpty) {
    final chapterRefs = resolveUnifiedComicChapters(comicInfo, from);
    final chapters = chapterRefs.map(adapter.fromChapterRef).toList();
    final normalizedChapterId = (selectedChapterId ?? '').trim();
    chapter = normalizedChapterId.isNotEmpty
        ? matcher.find(chapters, normalizedChapterId)
        : matcher.findByOrder(chapters, order);
  }

  final resolvedChapterId = _resolveReadSnapshotChapterId(
    chapter,
    requestId,
    order,
    selectedChapterId: selectedChapterId,
  );

  final extern = <String, dynamic>{
    ...chapterExtern,
    ...?chapter?.extern,
    'order': order,
  };

  final expectedIds = {
    requestId,
    logicalKey,
    selectedChapterId ?? '',
    chapter?.id ?? '',
    chapter?.effectiveRequestId ?? '',
  }.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
  final candidates = {resolvedChapterId, comicId, ''};

  ComicReadSnapshot? snapshot;
  for (final candidate in candidates) {
    final current = await _fetchSnapshot(
      from: from,
      comicId: comicId,
      chapterId: candidate,
      extern: extern,
      taskGroupKey: taskGroupKey,
      notifyUnauthorized: notifyUnauthorized,
    );
    // An empty old response cannot start a fallback request in a new session.
    if (generation != pluginSessionWriteFence.generation(source)) {
      throw const PluginSessionChanged();
    }
    if (current.chapter.pages.isEmpty) continue;
    final returnedIds = {
      current.chapter.id,
      current.chapter.requestId,
      current.chapter.logicalKey,
    }.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    if (expectedIds.isNotEmpty &&
        (returnedIds.isNotEmpty
            ? !returnedIds.any(expectedIds.contains)
            : candidate != resolvedChapterId)) {
      throw const FormatException('插件返回的图片与当前章节不匹配');
    }
    snapshot = current;
    break;
  }
  if (snapshot == null) {
    throw const FormatException('当前章节没有可用图片');
  }

  final fallbackChapterId = snapshot.chapter.id.isNotEmpty
      ? snapshot.chapter.id
      : resolvedChapterId;
  final logicalChapterId = _resolveLogicalChapterId(
    chapter,
    selectedChapterId,
    logicalKey,
    order,
    fallbackChapterId,
  );
  final resolvedStorageChapterId = storageChapterId.trim().isNotEmpty
      ? storageChapterId.trim()
      : chapter?.effectiveStorageId ?? '';
  return snapshot.toNormalEpInfo(
    logicalChapterId: logicalChapterId,
    storageChapterId: resolvedStorageChapterId,
  );
}

String _resolveReadSnapshotChapterId(
  DownloadChapter? chapter,
  String requestId,
  int order, {
  String? selectedChapterId,
}) {
  final explicitRequestId = requestId.trim();
  if (explicitRequestId.isNotEmpty) {
    return explicitRequestId;
  }

  final requestIdFromChapter = chapter?.effectiveRequestId ?? '';
  if (requestIdFromChapter.isNotEmpty) {
    return requestIdFromChapter;
  }

  final selected = selectedChapterId?.trim() ?? '';
  return selected.isNotEmpty ? selected : order.toString();
}

String _resolveLogicalChapterId(
  DownloadChapter? chapter,
  String? selectedChapterId,
  String logicalKey,
  int order,
  String fallbackChapterId,
) {
  final explicitLogicalKey = logicalKey.trim();
  if (explicitLogicalKey.isNotEmpty) {
    return explicitLogicalKey;
  }

  final logicalKeyFromChapter = chapter?.id ?? '';
  if (logicalKeyFromChapter.isNotEmpty) {
    return logicalKeyFromChapter;
  }

  final explicitSelectedChapterId = (selectedChapterId ?? '').trim();
  if (explicitSelectedChapterId.isNotEmpty) {
    return explicitSelectedChapterId;
  }

  if (fallbackChapterId.trim().isNotEmpty) {
    return fallbackChapterId.trim();
  }

  return order.toString();
}

Future<ComicReadSnapshot> _fetchSnapshot({
  required String from,
  required String comicId,
  required String chapterId,
  required Map<String, dynamic> extern,
  required String? taskGroupKey,
  required bool notifyUnauthorized,
}) async {
  final core = <String, dynamic>{'comicId': comicId};
  if (chapterId.trim().isNotEmpty) {
    core['chapterId'] = chapterId;
  }

  final response = await callUnifiedComicPlugin(
    from: from,
    fnPath: 'getReadSnapshot',
    core: core,
    extern: extern,
    taskGroupKey: taskGroupKey,
    notifyUnauthorized: notifyUnauthorized,
  );
  return ComicReadSnapshot.fromMap(response);
}
