import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:zephyr/service/download/download_commit_guard.dart';
import 'package:zephyr/service/download/comic_download_preview.dart';
import 'package:zephyr/service/download/comic_download_route.dart';
import 'dart:async';
import 'dart:convert';

import 'package:worker_manager/worker_manager.dart';
import 'package:path/path.dart' as p;
import 'package:zephyr/config/global/global.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart'
    as normal;
import 'package:zephyr/page/comic_info/method/get_plugin_detail.dart';
import 'package:zephyr/page/comic_read/model/unified_plugin_chapter.dart';
import 'package:zephyr/page/download/adapters/download_chapter_adapter.dart';
import 'package:zephyr/page/download/models/download_chapter.dart';
import 'package:zephyr/page/download/models/unified_comic_download.dart';
import 'package:zephyr/service/download/download_cancel_signal.dart';
import 'package:zephyr/service/download/download_asset_store.dart';
import 'package:zephyr/service/download/download_chapter_cancellation.dart';
import 'package:zephyr/service/download/download_progress_reporter.dart';
import 'package:zephyr/service/download/download_retry.dart';
import 'package:zephyr/service/download/download_task_repository.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/service/download/image_download.dart';
import 'package:zephyr/network/sync/sync_device_id.dart';
import 'package:zephyr/src/rust/api/simple.dart';
import 'package:zephyr/util/get_path.dart';

/// 单章节下载任务。
///
/// 每个任务只下载一个章节：先确认本地有无本漫画记录（没有则取详情 + 下封面，
/// 成功后连章节一起入库），再取章节、逐图下载、提交。自动线路按同一页计划
/// 恢复，候选变化时用独立路径提交完整章节。
Future<void> unifiedDownloadTask(
  DownloadProgressReporter reporter,
  DownloadTaskJson task, {
  int? taskId,
}) => runWithQjsTaskGroupNetwork(
  pluginId: task.from,
  taskGroupKey: task.taskKey,
  action: () => _unifiedDownloadTask(reporter, task, taskId: taskId),
);

Future<void> _unifiedDownloadTask(
  DownloadProgressReporter reporter,
  DownloadTaskJson task, {
  int? taskId,
}) async {
  await ensureSyncDeviceId();
  logger.d('unifiedDownloadTask received taskKey=${task.taskKey}');
  final pluginId = (task.from).trim();
  final from = pluginId;
  var comicId = task.comicId;
  final runtimeName = runtimeNameForPluginId(pluginId);
  final taskKey = task.taskKey;
  const taskRepository = DownloadTaskRepository();
  bool shouldRetryUntilSuccess() {
    return objectbox.userSettingBox
            .get(1)
            ?.globalSetting
            .retryDownloadUntilSuccess ??
        false;
  }

  DownloadTask? boundTask() {
    final current = taskId == null
        ? taskRepository.findByTaskKey(taskKey)
        : objectbox.downloadTaskBox.get(taskId);
    return current != null &&
            taskRepository.readPayload(current)?.taskKey == taskKey &&
            taskRepository.readPayload(current)?.attempt == task.attempt
        ? current
        : null;
  }

  final initialTask = boundTask();
  var checkpoint = initialTask == null
      ? task
      : taskRepository.readPayload(initialTask) ?? task;

  DownloadTask? findCurrentTask() {
    final current = boundTask();
    if (current == null || !current.isDownloading) return null;
    return current;
  }

  void queueTaskWrite(int id, {String? status, String? payloadJson}) {
    unawaited(
      taskRepository
          .putTaskWriteBackground(
            taskKey: taskKey,
            taskId: id,
            expectedAttempt: task.attempt,
            requireRunning: true,
            status: status,
            payloadJson: payloadJson,
          )
          .catchError((Object error, StackTrace stackTrace) {
            logger.w(
              '后台写入下载任务失败: $taskKey',
              error: error,
              stackTrace: stackTrace,
            );
          }),
    );
  }

  void updateCheckpoint(
    DownloadTaskJson Function(DownloadTaskJson payload) update, {
    String? status,
  }) {
    final dbTask = boundTask();
    if (dbTask == null) return;
    // Compose from the latest scheduled checkpoint, which may still be in flight.
    checkpoint = update(checkpoint);
    queueTaskWrite(
      dbTask.id,
      status: status,
      payloadJson: downloadTaskJsonToJson(checkpoint),
    );
  }

  Future<void> ensureTaskRunning() async {
    final currentTask = findCurrentTask();
    final signaled = isDownloadCancelSignaled(taskKey);
    if (signaled || currentTask == null || !currentTask.isDownloading) {
      logger.w(
        'ensureTaskRunning 取消任务: taskKey=$taskKey, signaled=$signaled, currentTask=${currentTask != null}, isDownloading=${currentTask?.isDownloading}',
      );
      await cancelTrackedQjsTasks(pluginId: pluginId, taskGroupKey: taskKey);
      throw const DownloadTaskCancelledException();
    }
  }

  const adapter = DownloadChapterAdapter();
  final chapter = adapter.fromTaskRef(task.chapterRef);
  // Paths owned by this chapter's transfer, including a reserved page plan.
  final completedPaths = <String>{...checkpoint.imagePaths};
  // A file may finish its atomic rename while a pause is being committed.
  // Keep ownership of every started page even before the next progress write.
  final startedPaths = <String>{};
  void Function()? releaseChapterPages;

  try {
    await ensureQjsRuntimeReady(pluginId: pluginId);
    await ensureTaskRunning();
    updateCheckpoint(
      (payload) =>
          payload.copyWith(stateCode: 'running', phaseCode: 'preparingRuntime'),
    );
    await preparePluginDownloadRuntime(
      from: from,
      pluginId: pluginId,
      runtimeName: runtimeName,
      taskGroupKey: taskKey,
    );

    // 本地已有本漫画记录时跳过详情和封面，直下本章。
    final existing = taskRepository.findDownloadRecord(from, comicId);
    late normal.NormalComicAllInfo normalInfo;
    List<Map<String, dynamic>> onlineCatalog;
    if (existing == null) {
      updateCheckpoint(
        (payload) => payload.copyWith(
          phaseCode: 'fetchingComicInfo',
          lastErrorCode: '',
          lastErrorMessage: '',
        ),
        status: t.download.statusFetchingComicInfo,
      );
      reporter.updateMessage(t.download.statusFetchingComicInfo);
      final PluginComicDetail detail;
      try {
        detail = await getComicDetailByPlugin(
          comicId,
          from,
          pluginId: pluginId,
          extern: {
            'comicDownload': true,
            'chapterId': chapter.effectiveRequestId,
          },
          taskGroupKey: taskKey,
        );
      } catch (error) {
        final failure = ComicDownloadRouteUnavailable.fromPluginError(error);
        if (failure != null) throw failure;
        rethrow;
      }
      comicId = detail.comicId;
      await ensureTaskRunning();
      ComicDownloadPreview.publish(from, comicId, {
        ...detail.normalInfo.comicInfo.cover.toJson(),
        'path': detail.normalInfo.comicInfo.cover.path.trim().isNotEmpty
            ? detail.normalInfo.comicInfo.cover.path
            : detail.normalInfo.comicInfo.cover.extern['path']?.toString() ??
                  '',
      });

      updateCheckpoint(
        (payload) => payload.copyWith(phaseCode: 'downloadingCover'),
        status: t.download.statusDownloadingCover,
      );
      reporter.updateMessage(t.download.statusDownloadingCover);
      final cover = detail.normalInfo.comicInfo.cover;
      final coverExtension = Map<String, dynamic>.from(cover.extern);
      final rawCoverFileName = cover.path.trim().isNotEmpty
          ? cover.path
          : coverExtension['path']?.toString() ?? '';
      String coverPath = '404';
      if (rawCoverFileName.trim().isNotEmpty && cover.url.trim().isNotEmpty) {
        final coverFileName = normalizeStoredAssetPath(rawCoverFileName);
        coverPath = await downloadCoverAsset(
          from: from,
          url: cover.url,
          path: coverFileName,
          cartoonId: comicId,
          qjsName: runtimeName,
          qjsTaskGroupKey: taskKey,
          retry: false,
        );
      }

      // 首存：把全量在线目录快照一起带上（显示排序与下载校验用）。
      onlineCatalog = buildChapterCatalog(detail.normalInfo.eps);
      normalInfo = detail.normalInfo.copyWith(recommend: const []);
      if (coverPath.startsWith('404')) {
        final clearedCoverExtension = {
          ...normalInfo.comicInfo.cover.extern,
          'path': '',
        };
        normalInfo = normalInfo.copyWith(
          comicInfo: normalInfo.comicInfo.copyWith(
            cover: normalInfo.comicInfo.cover.copyWith(
              url: '',
              path: '',
              extern: clearedCoverExtension,
            ),
          ),
        );
      }
    } else {
      normalInfo = normal.NormalComicAllInfo.fromJson(
        jsonDecode(existing.detailJson) as Map<String, dynamic>,
      );
      // 追加：本章不在目录快照里说明快照过期，重拉一次刷新。失败不阻塞下载。
      onlineCatalog = readChapterCatalogMaps(existing);
      final catalogChapters = readChapterCatalog(existing);
      final inCatalog = catalogChapters.any(
        (entry) => downloadChapterIdentityMatches(entry, chapter),
      );
      if (!inCatalog) {
        try {
          final fresh = await getComicDetailByPlugin(
            comicId,
            from,
            pluginId: pluginId,
            taskGroupKey: taskKey,
          );
          onlineCatalog = buildChapterCatalog(fresh.normalInfo.eps);
          // The commit publishes the refreshed catalog with the downloaded
          // chapter. A late response must not write a detached record.
          logger.i('下载目录快照已刷新: $from:$comicId');
        } on DownloadTaskCancelledException {
          rethrow;
        } catch (e) {
          logger.w('下载目录快照刷新失败，继续下载: $from:$comicId', error: e);
        }
      }
    }

    final requestChapterId = chapter.effectiveRequestId;
    final chapterExtern = Map<String, dynamic>.from(chapter.extern);
    final excluded = <String>[];
    ComicDownloadRetryReason? previousRouteFailure;
    Future<UnifiedPluginChapterResponse> readChapter() async {
      try {
        return await getComicChapterByPlugin(
          comicId,
          requestChapterId,
          from,
          pluginId: pluginId,
          runtimeName: runtimeName,
          extern: {...chapterExtern, 'chapterId': requestChapterId},
          taskGroupKey: taskKey,
          excludedDownloadRoutes: List.of(excluded),
        );
      } catch (error) {
        final failure = ComicDownloadRouteUnavailable.fromPluginError(error);
        if (failure != null) throw failure;
        rethrow;
      }
    }

    late UnifiedPluginChapterResponse response;
    late List<UnifiedPluginChapterDoc> docs;
    late DownloadImageJobsResult progress;
    ComicDownloadRoute? route;
    int? concurrency;
    while (true) {
      await ensureTaskRunning();
      final switching = excluded.isNotEmpty;
      final status = !switching
          ? t.download.statusFetchingChapterInfo
          : LocaleSettings.currentLocale == AppLocale.zhCn
          ? '正在尝试备用线路…'
          : 'Trying another download route…';
      reporter.updateMessage(status);
      updateCheckpoint(
        (payload) => payload.copyWith(
          phaseCode: switching ? 'switchingRoute' : 'fetchingChapterInfo',
          completedImages: 0,
          reusedImages: 0,
          totalImages: 0,
          imagePaths: {...completedPaths, ...startedPaths}.toList(),
        ),
        status: status,
      );
      try {
        response = switching
            ? await readChapter()
            : await retryDownloadOperation(
                operation: '获取章节 ${chapter.displayName}',
                ensureTaskRunning: ensureTaskRunning,
                shouldRetry: (error) => error is! ComicDownloadRouteUnavailable,
                action: readChapter,
              );
      } on ComicDownloadRouteUnavailable catch (error) {
        final reason = error.noCandidate ? previousRouteFailure : null;
        if (reason != null) throw ComicDownloadRouteUnavailable(null, reason);
        rethrow;
      }
      await ensureTaskRunning();
      route = ComicDownloadRoute.fromChapter(response);
      if (switching && (route == null || excluded.contains(route.key))) {
        throw const ComicDownloadRouteUnavailable();
      }
      _validateDownloadChapterIdentity(
        response,
        task.chapterRef,
        requestChapterId,
        onlineCatalog,
        expectedComicId: route == null ? null : comicId,
      );
      if (response.chapter.docs.isEmpty) {
        throw const FormatException('当前章节没有可用图片');
      }
      docs = route == null
          ? response.chapter.docs
          : isolateComicDownloadPages(
              taskKey: taskKey,
              response: response,
              route: route,
              retainedPaths: {...completedPaths, ...startedPaths},
            );
      if (docs.any(
        (doc) => doc.path.trim().isEmpty || doc.url.trim().isEmpty,
      )) {
        throw const FormatException('章节缺少有效的图片地址或文件名');
      }
      final jobs = [
        for (final doc in docs)
          DownloadImageJob(
            url: doc.url,
            path: doc.path,
            cartoonId: comicId,
            chapterId: response.chapter.epId,
            storageChapterId: chapter.effectiveStorageId,
            extern: doc.extern,
          ),
      ];
      final startingMessage = t.download.statusDownloadProgress(percent: 0);
      reporter.updateMessage(startingMessage);
      final downloading = checkpoint.copyWith(
        phaseCode: 'downloadingChapter',
        totalImages: jobs.length,
      );
      if (route == null) {
        updateCheckpoint((_) => downloading, status: startingMessage);
      } else {
        // Persist the whole generation before any file can be written. A
        // process exit before the next progress tick still leaves ownership.
        completedPaths.addAll(jobs.map((job) => job.path));
        checkpoint = downloading.copyWith(imagePaths: completedPaths.toList());
        final current = boundTask();
        if (current == null) throw const DownloadTaskCancelledException();
        await taskRepository.putTaskWriteBackground(
          taskKey: taskKey,
          taskId: current.id,
          expectedAttempt: task.attempt,
          requireRunning: true,
          status: startingMessage,
          payloadJson: downloadTaskJsonToJson(checkpoint),
        );
        await ensureTaskRunning();
      }
      releaseChapterPages?.call();
      releaseChapterPages = await claimDownloadChapterPages(
        task: task,
        comicId: comicId,
        docPaths: jobs.map((job) => job.path),
        startedPaths: startedPaths,
      );
      concurrency ??= await resolveDownloadConcurrency(
        from: from,
        pluginId: pluginId,
        taskGroupKey: taskKey,
      );
      var lastPersistedImages = 0;
      var lastPersistedAt = DateTime.now();
      var lastReportedPercent = 0;
      var progressMessage = startingMessage;
      try {
        progress = await downloadImageJobs(
          from: from,
          jobs: jobs,
          qjsRuntimeName: runtimeName,
          qjsTaskGroupKey: taskKey,
          ensureTaskRunning: ensureTaskRunning,
          stopOnMissingPage: true,
          isolatedPages: route != null,
          reporter: reporter,
          concurrency: concurrency,
          onJobStarted: (job) {
            if (job.path.trim().isEmpty) return;
            startedPaths.add(job.path);
          },
          onProgress: (completed, _, reused, job, _) async {
            if (job.path.trim().isNotEmpty) {
              completedPaths.add(job.path);
            }
            final percent = (completed / jobs.length * 100).floor();
            if (percent > lastReportedPercent) {
              lastReportedPercent = percent;
              progressMessage = t.download.statusDownloadProgress(
                percent: percent,
              );
              reporter.updateMessage(progressMessage);
            }
            final now = DateTime.now();
            if (completed == jobs.length ||
                completed - lastPersistedImages >= 5 ||
                now.difference(lastPersistedAt) >= const Duration(seconds: 1)) {
              lastPersistedImages = completed;
              lastPersistedAt = now;
              updateCheckpoint(
                (payload) => payload.copyWith(
                  completedImages: completed,
                  reusedImages: reused,
                  imagePaths: completedPaths.toList(),
                ),
                status: progressMessage,
              );
            }
          },
        );
        break;
      } on DownloadImageJobException catch (error) {
        final failedRoute = route;
        if (failedRoute == null) rethrow;
        await ensureTaskRunning();
        final reason = error.retryReason;
        if (reason == null) {
          if (error.httpStatus == 401 || error.httpStatus == 403) {
            final chinese = LocaleSettings.currentLocale == AppLocale.zhCn;
            throw ComicDownloadRouteUnavailable(
              chinese
                  ? '来源拒绝了图片下载，请检查访问权限'
                  : 'The source rejected the page download. Check access permissions.',
            );
          }
          throw const ComicDownloadRouteUnavailable();
        }
        if (!failedRoute.canSwitch ||
            reason == ComicDownloadRetryReason.rateLimited ||
            excluded.length >= 2) {
          throw ComicDownloadRouteUnavailable(null, reason);
        }
        previousRouteFailure = reason;
        excluded.add(failedRoute.key);
      }
    }

    await ensureTaskRunning();
    if (progress.downloaded == 0 && progress.reused == 0) {
      throw const FormatException('当前章节没有可用图片');
    }
    if (route != null && progress.downloaded + progress.reused != docs.length) {
      throw const ComicDownloadRouteUnavailable();
    }
    updateCheckpoint(
      (payload) => payload.copyWith(phaseCode: 'committingChapter'),
    );
    final commitTask = boundTask();
    if (commitTask == null) throw const DownloadTaskCancelledException();
    // Existing readers can still have the previous committed page paths.
    final published = route != null && existing != null
        ? resolveDownloadChapters(existing)
              .where(
                (saved) =>
                    saved.effectiveStorageId == chapter.effectiveStorageId,
              )
              .toList()
        : const <DownloadChapter>[];
    final currentPaths = {for (final doc in docs) doc.path};
    final retainedPaths = {
      ...completedPaths,
      ...startedPaths,
      for (final saved in published)
        if (saved.id == chapter.id)
          for (final page in saved.images) page.path,
    };
    await _saveUnifiedDownloadChapter(
      taskId: commitTask.id,
      taskKey: taskKey,
      attempt: task.attempt,
      from: from,
      comicId: comicId,
      normalInfo: normalInfo,
      selectedChapter: chapter,
      chapterResponse: response,
      docs: docs,
      route: route,
      progress: progress,
      imagePaths: (route == null ? completedPaths : retainedPaths).toList(),
      onlineCatalog: onlineCatalog,
    );
    if (route != null && retainedPaths.length > currentPaths.length) {
      releaseChapterPages();
      releaseChapterPages = null;
      await deleteCancelledChapterPages(
        task: task,
        taskId: commitTask.id,
        comicId: comicId,
        docPaths: retainedPaths.difference(currentPaths).difference({
          for (final saved in published)
            for (final page in saved.images) page.path,
        }),
      );
    }

    reporter.updateMessage(t.download.statusDownloadProgressComplete);
  } on DownloadTaskCancelledException {
    releaseChapterPages?.call();
    releaseChapterPages = null;
    if (!preserveCancelledDownloadFiles(taskKey)) {
      await deleteCancelledChapterPages(
        task: task,
        taskId: taskId,
        comicId: comicId,
        docPaths: {...completedPaths, ...startedPaths},
      );
    }
    rethrow;
  } catch (error) {
    if (startedPaths.isNotEmpty) {
      updateCheckpoint(
        (payload) => payload.copyWith(
          imagePaths: {...payload.imagePaths, ...startedPaths}.toList(),
        ),
      );
    }
    if (shouldRetryUntilSuccess()) {
      final reason = switch (error) {
        ComicDownloadRouteUnavailable(:final retryReason) => retryReason,
        DownloadImageJobException(:final retryReason) => retryReason,
        _ => comicDownloadRetryReason(error),
      };
      if (reason != null) {
        await ensureTaskRunning();
        throw ComicDownloadRetryDeferred(reason);
      }
    }
    rethrow;
  } finally {
    releaseChapterPages?.call();
  }
}

void _validateDownloadChapterIdentity(
  UnifiedPluginChapterResponse response,
  DownloadChapterTaskRef selected,
  String requestChapterId,
  List<Map<String, dynamic>> catalog, {
  String? expectedComicId,
}) {
  if (expectedComicId != null && response.comicId.trim() != expectedComicId) {
    throw const FormatException('插件返回的图片与当前作品不匹配');
  }
  final expectedIds = {
    selected.logicalKey.trim(),
    selected.chapterId.trim(),
    requestChapterId,
  }..remove('');
  final returnedIds = {
    response.chapter.epId.trim(),
    response.chapter.logicalKey.trim(),
  }..remove('');
  if (expectedComicId != null && returnedIds.isEmpty) {
    throw const FormatException('插件未确认下载章节的标识');
  }
  // The request fields can echo what was sent even when the chapter itself
  // names different content. Use them only for responses without a content ID.
  if (returnedIds.isEmpty) {
    final chapterRequest = response.chapter.requestId.trim();
    final request = chapterRequest.isNotEmpty
        ? chapterRequest
        : response.chapterId.trim();
    if (request.isNotEmpty) returnedIds.add(request);
  }
  final matchesRequested = expectedComicId == null
      ? returnedIds.any(expectedIds.contains)
      : returnedIds.every(expectedIds.contains);
  if (returnedIds.isEmpty || matchesRequested) return;

  // Older numeric-only tasks lack the content ID. A unique catalog entry can
  // prove the alias through its explicit requestId, as used by Bika's API.
  if (expectedIds.length == 1 &&
      selected.order > 0 &&
      requestChapterId == selected.order.toString()) {
    final matches = catalog
        .where(
          (entry) => entry['requestId']?.toString().trim() == requestChapterId,
        )
        .take(2)
        .toList();
    if (matches.length == 1) {
      final entry = matches.single;
      if (returnedIds.contains(entry['id']?.toString().trim()) ||
          returnedIds.contains(entry['logicalKey']?.toString().trim())) {
        return;
      }
    }
  }
  throw const FormatException('插件返回的图片与当前章节不匹配');
}

Future<void> _saveUnifiedDownloadChapter({
  required int taskId,
  required String taskKey,
  required int attempt,
  required String from,
  required String comicId,
  required normal.NormalComicAllInfo normalInfo,
  required DownloadChapter selectedChapter,
  required UnifiedPluginChapterResponse chapterResponse,
  required List<UnifiedPluginChapterDoc> docs,
  ComicDownloadRoute? route,
  required DownloadImageJobsResult progress,
  required List<String> imagePaths,
  List<Map<String, dynamic>>? onlineCatalog,
  Set<String> skippedPaths = const {},
}) async {
  final now = DateTime.now().toUtc();
  final key = buildDownloadTaskKey(from, comicId);
  final existing = objectbox.unifiedDownloadBox
      .query(UnifiedComicDownload_.uniqueKey.equals(key))
      .build()
      .findFirst();
  final downloadPath = await getDownloadPath();
  // JSON 拼装是纯计算，走全局 worker 池；主线程只做 put。
  final buildArgs = <String, dynamic>{
    'normalInfo': normalInfo.toJson(),
    'existing': existing == null
        ? null
        : {
            'cover': existing.cover,
            'chapters': existing.chapters,
            'detailJson': existing.detailJson,
          },
    'selected': {
      'id': selectedChapter.id,
      'displayName': selectedChapter.displayName,
      'order': selectedChapter.order,
      'requestId': selectedChapter.requestId,
      'storageId': selectedChapter.storageId,
      'groupTitle': selectedChapter.groupTitle,
      'extern': Map<String, dynamic>.from(selectedChapter.extern),
    },
    'docs': [
      for (final doc in docs)
        if (route == null)
          doc.toMap()
        else
          {'id': doc.id, 'name': doc.name, 'path': doc.path},
    ],
    'downloadApiHost': route?.apiHost ?? '',
    'downloadImageHost': route?.imageHost ?? '',
    'epId': chapterResponse.chapter.epId,
    'epName': chapterResponse.chapter.epName,
    'from': from,
    'comicId': comicId,
    'mainVersion': mainVersion,
    'onlineCatalog': onlineCatalog,
    'completedAtMs': now.millisecondsSinceEpoch,
    'skippedPaths': skippedPaths.toList(),
  };
  final built = await workerManager.execute<Map<String, dynamic>>(
    () => _buildDownloadRecordJson(buildArgs),
  );

  // 记录落库 + 根目录下载链接，同一个后台事务里提交，主线程零写库。
  // 失败时回退主线程直写，保证记录不丢。
  final saveArgs = <String, dynamic>{
    'taskId': taskId,
    'taskKey': taskKey,
    'attempt': attempt,
    'completedStatus': t.download.notificationCompleteTitle,
    'completedImages': progress.completed,
    'reusedImages': progress.reused,
    'imagePaths': imagePaths,
    'entity': {
      'id': existing?.id ?? 0,
      'uniqueKey': key,
      'source': from,
      'comicId': comicId,
      'title': built['title'] as String,
      'description': built['description'] as String,
      'cover': built['cover'] as String,
      'creator': built['creator'] as String,
      'titleMeta': built['titleMeta'] as String,
      'metadata': built['metadata'] as String,
      'totalViews': built['totalViews'] as int,
      'totalLikes': built['totalLikes'] as int,
      'totalComments': built['totalComments'] as int,
      'isFavourite': built['isFavourite'] as bool,
      'isLiked': built['isLiked'] as bool,
      'allowComment': built['allowComment'] as bool,
      'allowLike': built['allowLike'] as bool,
      'allowFavorite': built['allowFavorite'] as bool,
      'allowDownload': built['allowDownload'] as bool,
      'chapters': built['chapters'] as String,
      'detailJson': built['detail'] as String,
      'storageRoot': p.join(
        downloadPath,
        encodePath(path: normalizePluginId(from)),
        encodePath(path: comicId),
      ),
      'createdAtMs': (existing?.createdAt ?? now).millisecondsSinceEpoch,
      'nowMs': now.millisecondsSinceEpoch,
    },
    'linkUniqueKey': '$key||${ComicFolderType.download.name}',
    'linkComicKey': key,
    'deviceId': syncDeviceId,
  };
  try {
    final committed = await objectbox.store
        .runInTransactionAsync<int, Map<String, dynamic>>(
          TxMode.write,
          commitDownloadChapterOnWorker,
          saveArgs,
        );
    if (committed < 0) throw const DownloadTaskCancelledException();
  } on DownloadTaskCancelledException {
    rethrow;
  } catch (e) {
    // 后台提交失败时回退主线程直写（同一函数，主 store）。
    logger.w('后台落库失败，回退主线程: $key', error: e);
    final committed = objectbox.store.runInTransaction(
      TxMode.write,
      () => commitDownloadChapterOnWorker(objectbox.store, saveArgs),
    );
    if (committed < 0) throw const DownloadTaskCancelledException();
  }
}

/// 后台 isolate 里拼下载记录 JSON（纯计算，无 DB/IO/logger）。
Map<String, dynamic> _buildDownloadRecordJson(Map<String, dynamic> args) {
  final normalInfo = normal.NormalComicAllInfo.fromJson(
    Map<String, dynamic>.from(args['normalInfo'] as Map),
  );
  final existingRaw = args['existing'] as Map?;
  final selectedRaw = Map<String, dynamic>.from(args['selected'] as Map);
  final selected = DownloadChapter(
    id: selectedRaw['id'] as String,
    displayName: selectedRaw['displayName'] as String,
    order: selectedRaw['order'] as int,
    requestId: selectedRaw['requestId'] as String?,
    storageId: selectedRaw['storageId'] as String?,
    groupTitle: selectedRaw['groupTitle'] as String? ?? '',
    extern: Map<String, dynamic>.from(selectedRaw['extern'] as Map),
    images: const [],
  );
  final docs = (args['docs'] as List)
      .map(
        (m) => UnifiedPluginChapterDoc.fromMap(
          Map<String, dynamic>.from(m as Map),
        ),
      )
      .toList();
  final response = UnifiedPluginChapterResponse(
    source: '',
    comicId: '',
    chapterId: '',
    extern: const {},
    scheme: const {},
    chapter: UnifiedPluginChapter(
      epId: args['epId'] as String,
      epName: args['epName'] as String,
      order: 0,
      length: docs.length,
      epPages: docs.length.toString(),
      docs: docs,
      extern: const {},
    ),
  );

  final storedChapters = existingRaw == null
      ? <UnifiedComicDownloadStoredChapter>[]
      : resolveStoredDownloadChaptersFromJson(
          chaptersJson: existingRaw['chapters'] as String,
          detailJson: existingRaw['detailJson'] as String,
        ).toList();
  final skippedPaths = ((args['skippedPaths'] as List?) ?? const [])
      .map((e) => normalizeStoredAssetPath(e.toString()))
      .toSet();
  final storedChapter = _buildStoredChapter(
    selected,
    response,
    completedAt: DateTime.fromMillisecondsSinceEpoch(
      args['completedAtMs'] as int,
      isUtc: true,
    ),
    skippedPaths: skippedPaths,
    downloadApiHost: args['downloadApiHost'] as String,
    downloadImageHost: args['downloadImageHost'] as String,
  );
  final existingIndex = storedChapter.downloadApiHost.isEmpty
      ? storedChapters.indexWhere(
          (item) => _storedChapterMatches(item, selected),
        )
      : _automaticReplacementIndex(storedChapters, selected);
  if (existingIndex >= 0) {
    storedChapters[existingIndex] = storedChapter;
  } else {
    storedChapters.add(storedChapter);
  }
  storedChapters.sort((a, b) => a.order.compareTo(b.order));

  final eps = buildDownloadEps(storedChapters);
  final onlineCatalog = args['onlineCatalog'] as List?;
  final detail = normalInfo.copyWith(
    eps: eps,
    recommend: const [],
    extern: {
      ...normalInfo.extern,
      if (onlineCatalog != null)
        'chapterCatalog': onlineCatalog
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      'downloadChapters': storedChapters.map((e) => e.toMap()).toList(),
    },
  );
  var coverMap = _normalizeStoredImageMap(
    _deepCopyMap(detail.comicInfo.cover.toJson()),
  );
  if (_isEmptyStoredImage(coverMap) && existingRaw != null) {
    try {
      coverMap = _normalizeStoredImageMap(
        Map<String, dynamic>.from(
          jsonDecode(existingRaw['cover'] as String) as Map,
        ),
      );
    } catch (_) {
      // 旧记录封面 JSON 损坏时继续使用当前详情的空封面。
    }
  }
  final creatorMap = _normalizeStoredCreatorMap(
    _deepCopyMap(detail.comicInfo.creator.toJson()),
  );
  final titleMeta = _deepCopyMapList(
    detail.comicInfo.titleMeta.map((e) => e.toJson()).toList(),
  );
  final metadata = _normalizeMetadataForStorage(detail.comicInfo.metadata);
  final chapters = storedChapters.map((chapter) => chapter.toMap()).toList();

  return <String, dynamic>{
    'title': detail.comicInfo.title,
    'description': detail.comicInfo.description,
    'cover': jsonEncode(coverMap),
    'creator': jsonEncode(creatorMap),
    'titleMeta': jsonEncode(titleMeta),
    'metadata': metadata,
    'totalViews': detail.totalViews,
    'totalLikes': detail.totalLikes,
    'totalComments': detail.totalComments,
    'isFavourite': detail.isFavourite,
    'isLiked': detail.isLiked,
    'allowComment': detail.allowComments,
    'allowLike': detail.allowLike,
    'allowFavorite': detail.allowCollected,
    'allowDownload': detail.allowDownload,
    'chapters': jsonEncode(chapters),
    'detail': jsonEncode(
      detail
          .copyWith(extern: {...detail.extern, 'version': args['mainVersion']})
          .toJson(),
    ),
    'imageCount': storedChapter.images.length,
    'storedCount': storedChapters.length,
  };
}

/// 后台 isolate 里落下载记录 + 根目录下载链接（同一事务，顶层函数）。
///
/// 失败时调用方会用主 store 直接调本函数重试，因此函数体不能依赖 worker 特有状态。
@visibleForTesting
int commitDownloadChapterOnWorker(Store store, Map<String, dynamic> args) {
  final task = store.box<DownloadTask>().get(args['taskId'] as int);
  if (!downloadTaskMayCommit(
    task,
    taskKey: args['taskKey'] as String,
    attempt: args['attempt'] as int,
  ))
    return -1;
  final e = Map<String, dynamic>.from(args['entity'] as Map);
  final entity = UnifiedComicDownload(
    uniqueKey: e['uniqueKey'] as String,
    source: e['source'] as String,
    comicId: e['comicId'] as String,
    title: e['title'] as String,
    description: e['description'] as String,
    cover: e['cover'] as String,
    creator: e['creator'] as String,
    titleMeta: e['titleMeta'] as String,
    metadata: e['metadata'] as String,
    totalViews: e['totalViews'] as int,
    totalLikes: e['totalLikes'] as int,
    totalComments: e['totalComments'] as int,
    isFavourite: e['isFavourite'] as bool,
    isLiked: e['isLiked'] as bool,
    allowComment: e['allowComment'] as bool,
    allowLike: e['allowLike'] as bool,
    allowFavorite: e['allowFavorite'] as bool,
    allowDownload: e['allowDownload'] as bool,
    chapters: e['chapters'] as String,
    detailJson: e['detailJson'] as String,
    storageRoot: e['storageRoot'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      e['createdAtMs'] as int,
      isUtc: true,
    ),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      e['nowMs'] as int,
      isUtc: true,
    ),
    downloadedAt: DateTime.fromMillisecondsSinceEpoch(
      e['nowMs'] as int,
      isUtc: true,
    ),
    deleted: false,
    schemaVersion: 2,
  );
  entity.id = e['id'] as int;
  store.box<UnifiedComicDownload>().put(entity);

  // 与 ComicLinkService.addComic(key, null, download) 等价：复活 tombstone 或新建。
  final linkUniqueKey = args['linkUniqueKey'] as String;
  final nowMs = e['nowMs'] as int;
  final linkBox = store.box<ComicLink>();
  final found = linkBox
      .query(ComicLink_.uniqueKey.equals(linkUniqueKey))
      .build()
      .findFirst();
  if (found != null) {
    if (found.deletedAt != null) {
      found
        ..deletedAt = null
        ..createdAt = nowMs
        ..updatedAt = nowMs
        ..versionVectorJson = _bumpLinkVersionVector(
          found.versionVectorJson,
          args['deviceId'] as String,
        );
      linkBox.put(found);
    }
  } else {
    linkBox.put(
      ComicLink(
        uniqueKey: linkUniqueKey,
        comicUniqueKey: args['linkComicKey'] as String,
        typeData: ComicFolderType.download.name,
        versionVectorJson: jsonEncode({args['deviceId'] as String: 1}),
        createdAt: nowMs,
        updatedAt: nowMs,
      ),
    );
  }
  // Publish the committed resource and its terminal task atomically. A later
  // cancel sees completed and cannot delete files belonging to this resource.
  // The periodic checkpoint may still be in flight at this point.
  final completedImages = args['completedImages'] as int;
  final committedTask = task!;
  committedTask
    ..status = args['completedStatus'] as String? ?? committedTask.status
    ..isCompleted = true
    ..isDownloading = false
    ..taskInfo = committedTask.taskInfo!.copyWith(
      stateCode: 'completed',
      phaseCode: 'completed',
      completedImages: completedImages,
      reusedImages: args['reusedImages'] as int,
      totalImages: completedImages,
      imagePaths: List<String>.from(args['imagePaths'] as List),
    );
  store.box<DownloadTask>().put(committedTask);
  return 0;
}

String _bumpLinkVersionVector(String raw, String deviceId) {
  try {
    final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    map[deviceId] = ((map[deviceId] as num?) ?? 0).toInt() + 1;
    return jsonEncode(map);
  } catch (_) {
    return jsonEncode({deviceId: 1});
  }
}

UnifiedComicDownloadStoredChapter _buildStoredChapter(
  DownloadChapter selectedChapter,
  UnifiedPluginChapterResponse response, {
  required DateTime completedAt,
  Set<String> skippedPaths = const {},
  String downloadApiHost = '',
  String downloadImageHost = '',
}) {
  // 注意：此函数会在后台 isolate 里运行，不要在这里打 logger/碰 IO。
  return UnifiedComicDownloadStoredChapter(
    // `id` 字段保持为本地存储 key，旧版本读取时仍按 storage key 理解。
    id: selectedChapter.effectiveStorageId,
    name: selectedChapter.displayName.trim().isNotEmpty
        ? selectedChapter.displayName
        : response.chapter.epName,
    order: selectedChapter.order,
    // `logicalKey` 写入宿主匹配 key，保证新版本通过适配器能还原出正确的 id。
    logicalKey: selectedChapter.id,
    taskChapterId: selectedChapter.effectiveRequestId,
    // 显式保存 storageChapterId，确保显式指定了 storage key 的插件能正确还原。
    storageChapterId: selectedChapter.effectiveStorageId,
    groupTitle: selectedChapter.groupTitle,
    downloadApiHost: downloadApiHost,
    downloadImageHost: downloadImageHost,
    completedAt: completedAt,
    images: response.chapter.docs.map((doc) {
      final imageName = _resolveImageDisplayName(doc);
      final imagePath = normalizeStoredAssetPath(doc.path, allowEmpty: true);
      // 真 404 而跳过的图打标记：阅读器显示缺图占位，导出不再补下。
      final skipped = imagePath.isEmpty || skippedPaths.contains(imagePath);
      return UnifiedComicDownloadImage(
        id: doc.id.isNotEmpty
            ? doc.id
            : _fallbackImageId(doc, response.chapter.epId),
        name: imageName,
        path: imagePath,
        url: doc.url,
        extern: skipped ? {...doc.extern, 'downloadSkipped': true} : doc.extern,
      );
    }).toList(),
  );
}

int _automaticReplacementIndex(
  List<UnifiedComicDownloadStoredChapter> stored,
  DownloadChapter selected,
) {
  final exact = [
    for (final (index, chapter) in stored.indexed)
      if (chapter.logicalKey.trim() == selected.id) index,
  ];
  if (exact.length == 1) return exact.single;
  final legacy = [
    for (final (index, chapter) in stored.indexed)
      if (chapter.logicalKey.trim().isEmpty &&
          _storedChapterMatches(chapter, selected))
        index,
  ];
  if (exact.length > 1 || legacy.length > 1) {
    throw const FormatException('本地下载章节标识重复');
  }
  return legacy.isEmpty ? -1 : legacy.single;
}

/// 章节身份只认 logical / request 系 key，storage 系 key
///（多分块可共享，如 EH 的 "Gallery"）绝不能作为判同依据。
bool _storedChapterMatches(
  UnifiedComicDownloadStoredChapter stored,
  DownloadChapter selected,
) {
  final storedIdentity = <String>{
    stored.logicalKey.trim(),
    stored.taskChapterId.trim(),
  }..remove('');
  if (storedIdentity.isEmpty && stored.storageChapterId.trim().isEmpty) {
    // 纯老数据：没有任何插件化字段时，id 才是匹配 key。
    final legacyId = stored.id.trim();
    if (legacyId.isNotEmpty) storedIdentity.add(legacyId);
  }
  final selectedIdentity = <String>{
    selected.id.trim(),
    selected.effectiveRequestId.trim(),
  }..remove('');
  if (storedIdentity.intersection(selectedIdentity).isNotEmpty) return true;
  // order 不再单独作为判同依据；双方都没有身份 key 时才用它兜底。
  return storedIdentity.isEmpty &&
      selectedIdentity.isEmpty &&
      stored.order > 0 &&
      stored.order == selected.order;
}

bool _isEmptyStoredImage(Map<String, dynamic> image) {
  final path = image['path']?.toString().trim() ?? '';
  final extern = Map<String, dynamic>.from(image['extern'] as Map? ?? const {});
  final externPath = extern['path']?.toString().trim() ?? '';
  return path.isEmpty && externPath.isEmpty;
}

Map<String, dynamic> _deepCopyMap(Object value) {
  final encoded = jsonEncode(value);
  final decoded = jsonDecode(encoded);
  return Map<String, dynamic>.from(decoded as Map);
}

List<Map<String, dynamic>> _deepCopyMapList(Object value) {
  final encoded = jsonEncode(value);
  final decoded = jsonDecode(encoded) as List;
  return decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
}

String _normalizeMetadataForStorage(List<normal.ComicInfoMetadata> metadata) {
  final normalized = <Map<String, dynamic>>[];
  for (final item in metadata) {
    final values = item.value
        .map((entry) => entry.name.trim())
        .where((entry) => entry.isNotEmpty)
        .map((entry) => {'name': entry})
        .toList();
    if (values.isEmpty) {
      continue;
    }
    normalized.add({'type': item.type, 'name': item.name, 'value': values});
  }
  return jsonEncode(normalized);
}

String _fallbackImageId(UnifiedPluginChapterDoc doc, String chapterId) {
  final candidate = doc.path.isNotEmpty ? doc.path : doc.name;
  final base = candidate.split(RegExp(r'[\\/]')).last.trim();
  final withoutExt = base.contains('.')
      ? base.substring(0, base.lastIndexOf('.'))
      : base;
  if (withoutExt.isNotEmpty) {
    return withoutExt.replaceAll(RegExp(r'[^a-zA-Z0-9_\-.]'), '_');
  }
  return '${chapterId}_${doc.id.hashCode.abs()}';
}

String _resolveImageDisplayName(UnifiedPluginChapterDoc doc) {
  if (doc.name.trim().isNotEmpty) {
    return doc.name.trim();
  }
  final pathName = p.basename(doc.path.trim());
  if (pathName.isNotEmpty) {
    return pathName;
  }
  return 'asset.bin';
}

Map<String, dynamic> _normalizeStoredImageMap(Map<String, dynamic> image) {
  final map = Map<String, dynamic>.from(image);
  final ext = Map<String, dynamic>.from(map['extern'] as Map? ?? const {});
  final topLevelRawPath = map['path']?.toString() ?? '';
  final extRawPath = ext['path']?.toString() ?? '';

  final normalizedTopLevelPath = normalizeStoredAssetPath(
    topLevelRawPath,
    allowEmpty: true,
  );
  final normalizedExtPath = normalizeStoredAssetPath(
    extRawPath,
    allowEmpty: true,
  );
  final mergedPath = normalizedTopLevelPath.isNotEmpty
      ? normalizedTopLevelPath
      : normalizedExtPath;

  map['path'] = mergedPath;
  ext['path'] = mergedPath;
  map['extern'] = ext;
  return map;
}

Map<String, dynamic> _normalizeStoredCreatorMap(Map<String, dynamic> creator) {
  final map = Map<String, dynamic>.from(creator);
  final avatar = Map<String, dynamic>.from(map['avatar'] as Map? ?? const {});
  if (avatar.isNotEmpty) {
    map['avatar'] = _normalizeStoredImageMap(avatar);
  }
  return map;
}
