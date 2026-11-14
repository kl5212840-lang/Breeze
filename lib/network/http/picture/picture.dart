import 'package:zephyr/service/image_recovery.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as file_path;
import 'package:zephyr/main.dart';
import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart';
import 'package:zephyr/page/comic_read/method/image_header_size.dart';
import 'package:zephyr/page/setting/real_sr/service/real_sr_super_resolution.dart';
import 'package:zephyr/page/source_shell/source_experience_preferences.dart'
    show bikaPlusSourceId;
import 'package:zephyr/service/download/download_asset_store.dart';
import 'package:zephyr/service/download/download_cancel_signal.dart';
import 'package:zephyr/service/download/download_retry.dart'
    show isNonRetryableDownloadFailure;
import 'package:zephyr/src/rust/api/simple.dart';
import 'package:zephyr/src/rust/decode/decode.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/type/pipe.dart';
import 'package:zephyr/util/get_path.dart';

export 'package:zephyr/service/download/download_asset_store.dart'
    show normalizeStoredAssetPath;

const _kQjsRuntimeCancelled = '__QJS_RUNTIME_CANCELLED__';
const _kDownloadTaskCancelled = '__DOWNLOAD_TASK_CANCELLED__';
const _kJmPluginUuid = 'bf99008d-010b-4f17-ac7c-61a9b57dc3d9';

void _throwIfDownloadCancelled(String taskGroupKey) {
  if (taskGroupKey.isNotEmpty && isDownloadCancelSignaled(taskGroupKey)) {
    throw const DownloadTaskCancelledException();
  }
}

const _kJmCheckFnPath = 'isJm';

/// 插件是否需要 JM 反混淆的记忆缓存：key 为归一化后的插件 id（调试运行时会带上 runtime 名）。
///
/// 首次命中时调用插件 `isJm` 探测并记忆结果，避免每张图都走一次 QJS 调用；
/// 探测抛错与返回 false 都记为 false（插件未实现该函数时抛错是常态）。
final Map<String, bool> _jmPluginDeobfuscationCache = <String, bool>{};
final Map<String, Future<bool>> _jmPluginDeobfuscationInflight =
    <String, Future<bool>>{};

/// 是否对该插件的图片做 JM 反混淆：`(uuid 命中 || 插件 isJm 返回 true) && page`。
Future<bool> _shouldApplyJmDeobfuscation({
  required String pluginId,
  String? runtimeName,
  required PictureType pictureType,
  bool probePlugin = true,
}) async {
  if (pictureType != PictureType.page) return false;
  if (pluginId == _kJmPluginUuid) return true;
  if (!probePlugin) return false;
  final trimmedRuntime = runtimeName?.trim() ?? '';
  final cacheKey = trimmedRuntime.isEmpty || trimmedRuntime == pluginId
      ? pluginId
      : '$pluginId::$trimmedRuntime';
  final cached = _jmPluginDeobfuscationCache[cacheKey];
  if (cached != null) return cached;
  final inflight = _jmPluginDeobfuscationInflight[cacheKey];
  if (inflight != null) return inflight;
  final future = _queryPluginIsJm(
    pluginId,
    trimmedRuntime.isEmpty ? null : trimmedRuntime,
  );
  _jmPluginDeobfuscationInflight[cacheKey] = future;
  final isJm = await future;
  logger.d(isJm);
  _jmPluginDeobfuscationInflight.remove(cacheKey);
  _jmPluginDeobfuscationCache[cacheKey] = isJm;
  return isJm;
}

/// 调用插件 `isJm` 函数；任何错误都吞掉并视为 false。
Future<bool> _queryPluginIsJm(String pluginId, String? runtimeName) async {
  try {
    final raw = await executeQjsCall(
      pluginId: pluginId,
      runtimeName: runtimeName,
      fnPath: _kJmCheckFnPath,
      argsJson: '{}',
    );
    return _parseIsJmResult(jsonDecode(raw));
  } catch (_) {
    return false;
  }
}

/// 插件 `isJm` 只返回裸 `bool`；其他形状一律视为 false。
bool _parseIsJmResult(Object? decoded) {
  return decoded == true;
}

/// Bika+ can return the same media path with a different URL for another
/// quality. Its image fetch uses the returned URL, including its query.
String onlinePictureCacheVariant({
  required String from,
  required String url,
  required PictureType type,
}) {
  if (type != PictureType.page || normalizePluginId(from) != bikaPlusSourceId) {
    return '';
  }
  final uri = Uri.tryParse(url.trim());
  if (uri == null ||
      uri.host.isEmpty ||
      (uri.scheme != 'https' && uri.scheme != 'http')) {
    return '';
  }
  return sha256
      .convert(utf8.encode(uri.removeFragment().toString()))
      .toString();
}

/// Some catalog providers only return a public image URL. This identity is
/// restricted to online artwork: chapters still require their storage path.
String _onlinePicturePath(String path, String url, PictureType type) {
  final original = path.trim();
  if (original.isNotEmpty || type == PictureType.page) return original;
  final uri = Uri.tryParse(url.trim());
  if (uri == null ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      (uri.scheme != 'https' && uri.scheme != 'http')) {
    return '';
  }
  final identity = sha256.convert(utf8.encode(uri.removeFragment().toString()));
  return 'online-url-$identity';
}

Future<String> getCachePicture({
  required String from,
  String url = '',
  String path = '',
  String cartoonId = '1',
  String chapterId = '',
  String storageChapterId = '',
  PictureType pictureType = PictureType.page,
  Map<String, dynamic>? extern,
  int index = 0,
  bool applyRealSr = true,
  bool usePlugin = true,
  int priority = 0,
  bool prefetch = false,
  bool useDownloads = true,
  bool Function()? isCurrent,
}) async {
  final source = normalizePluginId(from);
  final generation = pluginSessionWriteFence.generation(source);
  bool current() =>
      isCurrent?.call() != false &&
      !pluginSessionWriteFence.isChanging(source) &&
      pluginSessionWriteFence.generation(source) == generation;
  final key = jsonEncode([
    source,
    generation,
    cartoonId,
    chapterId,
    storageChapterId,
    pictureType.name,
    path,
    url,
    usePlugin,
    useDownloads,
    {...?extern}..remove('priority'),
  ]);
  final result = await ImageRecoveryHub.requests.run<String>(
    key,
    () => _getCachePictureRaw(
      from: from,
      url: url,
      path: path,
      cartoonId: cartoonId,
      chapterId: chapterId,
      storageChapterId: storageChapterId,
      pictureType: pictureType,
      extern: {...?extern, 'priority': priority},
      index: index,
      applyRealSr: false,
      usePlugin: usePlugin,
      useDownloads: useDownloads,
      isCurrent: () =>
          !pluginSessionWriteFence.isChanging(source) &&
          pluginSessionWriteFence.generation(source) == generation,
    ),
    priority: priority,
    current: current,
    cover: pictureType != PictureType.page,
  );
  if (!current()) throw const ImageRecoverySuperseded();
  if (!prefetch &&
      applyRealSr &&
      pictureType == PictureType.page &&
      result != '404') {
    await ImageRecoveryHub.requests.run<void>(
      'upscale:$result',
      () => RealSrSuperResolution.upscaleAndConvertToWebp(result),
      priority: priority,
      current: current,
    );
  }
  return result;
}

/// Invalidate only the exact reloadable cache reported by a decoder. A managed
/// download is never deleted or silently replaced by an online image.
Future<bool> invalidateCachedPicture({
  required String from,
  required String path,
  required String imagePath,
  String url = '',
  String cartoonId = '1',
  String chapterId = '',
  String storageChapterId = '',
  PictureType pictureType = PictureType.page,
}) async {
  final directPath = _onlinePicturePath(path, url, pictureType);
  if (directPath.isEmpty) return false;
  final store = DownloadAssetStore(
    from: normalizePluginId(from),
    path: directPath,
    cartoonId: cartoonId,
    chapterId: chapterId,
    storageChapterId: storageChapterId,
    pictureType: pictureType,
    cacheVariant: onlinePictureCacheVariant(
      from: from,
      url: url,
      type: pictureType,
    ),
  );
  final download = await store.findExistingDownload();
  if (download?.path == imagePath) return false;
  final cache = await store.findCanonicalCache();
  if (cache?.path != imagePath) return false;
  await File(imagePath).delete();
  return true;
}

Future<String> _getCachePictureRaw({
  required String from,
  String url = '',
  String path = '',
  String cartoonId = '1',
  String chapterId = '',
  String storageChapterId = '',
  PictureType pictureType = PictureType.page,
  Map<String, dynamic>? extern,
  int index = 0,
  bool applyRealSr = true,
  bool usePlugin = true,
  bool useDownloads = true,
  bool Function()? isCurrent,
}) async {
  final resolvedFrom = normalizePluginId(from);
  if (resolvedFrom.isEmpty) {
    throw StateError('getCachePicture missing pluginId');
  }
  if (url.contains("nopic-Male.gif")) return "nopic-Male.gif";

  final directPath = _onlinePicturePath(path, url, pictureType);
  if (directPath.isEmpty) {
    return '404';
  }

  final assetStore = DownloadAssetStore(
    from: resolvedFrom,
    path: directPath,
    cartoonId: cartoonId,
    chapterId: chapterId,
    storageChapterId: storageChapterId,
    pictureType: pictureType,
    cacheVariant: onlinePictureCacheVariant(
      from: resolvedFrom,
      url: url,
      type: pictureType,
    ),
  );
  final existingDownload = !useDownloads || path.trim().isEmpty
      ? null
      : await assetStore.findExistingDownload();

  if (existingDownload != null) {
    try {
      // 超分 + WebP 转换统一封装，内部会判断分辨率并保留原文件名。
      if (pictureType == PictureType.page && applyRealSr) {
        await RealSrSuperResolution.upscaleAndConvertToWebp(
          existingDownload.path,
        );
      }
      return existingDownload.path;
    } catch (e) {
      logger.w(
        'getCachePicture: 已存在下载文件不可访问，准备继续查找新缓存/网络: ${existingDownload.path}',
        error: e,
      );
    }
  }

  // Downloaded reader pages have no remote URL. The saved file must
  // exist in the download store; a transient online cache is not a copy.
  if (pictureType == PictureType.page && url.isEmpty) {
    throw const DownloadPictureNotFoundException('');
  }

  final existingCache = await assetStore.findCanonicalCache();
  if (existingCache != null) {
    try {
      if (pictureType == PictureType.page && applyRealSr) {
        await RealSrSuperResolution.upscaleAndConvertToWebp(existingCache.path);
      }
      return existingCache.path;
    } catch (e) {
      logger.w(
        'getCachePicture: 缓存文件存在但无法访问，删除并重新下载: ${existingCache.path}',
        error: e,
      );
      try {
        await File(existingCache.path).delete();
      } catch (deleteError) {
        logger.e(
          'getCachePicture: 删除损坏缓存文件失败: ${existingCache.path}',
          error: deleteError,
        );
      }
    }
  }

  if (url.isEmpty) {
    throw const DownloadPictureNotFoundException('');
  }

  final newCacheFilePath = await assetStore.canonicalCachePath();

  extern = {...?extern};
  extern['priority'] ??= 0;

  final Uint8List imageData;
  if (usePlugin) {
    imageData = await downloadImageWithRetry(
      url,
      source: resolvedFrom,
      extern: extern,
    );
  } else {
    // 插件图标在未安装或禁用插件时也需要加载，不依赖插件运行时。
    final response = await fetch(
      url,
      headers: const {'User-Agent': 'Breeze/1.0'},
    );
    if (!response.ok) {
      throw DownloadPictureHttpException(
        url,
        response.statusText,
        statusCode: response.status,
        responseBodyLength: response.body.length,
      );
    }
    imageData = response.body;
    _checkImagePayload(imageData, url);
  }

  if (isCurrent?.call() == false) throw const ImageRecoverySuperseded();
  void confirmTransport() {
    if (isCurrent?.call() == false) throw const ImageRecoverySuperseded();
    ImageRecoveryHub.instance.noteSuccessfulRequest(
      imageHost: Uri.tryParse(url)?.host ?? '',
    );
  }

  final shouldDeobfuscateCache = await _shouldApplyJmDeobfuscation(
    pluginId: resolvedFrom,
    pictureType: pictureType,
    probePlugin: usePlugin,
  );
  if (isCurrent?.call() == false) throw const ImageRecoverySuperseded();
  if (shouldDeobfuscateCache) {
    await decodeAndSaveImage(
      imageData,
      chapterId.let(toInt),
      newCacheFilePath,
      url,
    );
    // 验证文件已成功保存
    if (await File(newCacheFilePath).exists()) {
      if (pictureType == PictureType.page && applyRealSr) {
        await RealSrSuperResolution.upscaleAndConvertToWebp(newCacheFilePath);
      }
      confirmTransport();
      return newCacheFilePath;
    } else {
      throw Exception('图片保存失败');
    }
  }

  // 保存图片
  await saveImage(imageData, newCacheFilePath);

  // 验证文件已成功保存
  if (await File(newCacheFilePath).exists() &&
      await File(newCacheFilePath).length() > 0) {
    // 超分 + WebP 转换统一封装，内部会判断分辨率并保留原文件名
    if (pictureType == PictureType.page && applyRealSr) {
      await RealSrSuperResolution.upscaleAndConvertToWebp(newCacheFilePath);
    }
    confirmTransport();
    return newCacheFilePath;
  } else {
    throw Exception('图片保存失败');
  }
}

/// 在不触发下载的前提下，解析图片已存在的本地路径。
///
/// 查找顺序与 [getCachePicture] 的缓存命中分支一致：
/// 新下载路径 → 高概率旧下载路径 → 新缓存路径。
/// 找不到时返回空字符串。用于阅读器预解析图片尺寸等只需要本地文件的场景。
Future<String> findCachedPicturePath({
  required String from,
  String path = '',
  String url = '',
  String cartoonId = '1',
  String chapterId = '',
  String storageChapterId = '',
  PictureType pictureType = PictureType.page,
  bool? offlineReader,
}) async {
  final resolvedFrom = normalizePluginId(from);
  if (resolvedFrom.isEmpty) {
    return '';
  }

  final directPath = _onlinePicturePath(path, url, pictureType);
  if (directPath.isEmpty) {
    return '';
  }
  final assetStore = DownloadAssetStore(
    from: resolvedFrom,
    path: directPath,
    cartoonId: cartoonId,
    chapterId: chapterId,
    storageChapterId: storageChapterId,
    pictureType: pictureType,
    cacheVariant: onlinePictureCacheVariant(
      from: resolvedFrom,
      url: url,
      type: pictureType,
    ),
  );
  final existing = switch (offlineReader) {
    true => await assetStore.findExistingDownload(),
    false => await assetStore.findCanonicalCache(),
    null => await assetStore.findExisting(),
  };
  if (existing == null) return '';
  return existing.path;
}

Future<String> downloadPicture({
  required String from,
  String url = '',
  String path = '',
  String cartoonId = '1',
  String chapterId = '',
  String storageChapterId = '',
  PictureType pictureType = PictureType.page,
  String? qjsName,
  String qjsTaskGroupKey = '',
  bool retry = false,
  bool Function()? shouldRetryUntilSuccess,
  Map<String, dynamic> extern = const <String, dynamic>{},
  bool applyRealSr = true,
}) async {
  final result = await downloadPictureResult(
    from: from,
    url: url,
    path: path,
    cartoonId: cartoonId,
    chapterId: chapterId,
    storageChapterId: storageChapterId,
    pictureType: pictureType,
    qjsName: qjsName,
    qjsTaskGroupKey: qjsTaskGroupKey,
    retry: retry,
    shouldRetryUntilSuccess: shouldRetryUntilSuccess,
    applyRealSr: applyRealSr,
    extern: extern,
  );
  if (result.status == DownloadPictureResultStatus.notFound ||
      result.status == DownloadPictureResultStatus.emptyData ||
      result.status == DownloadPictureResultStatus.failed) {
    return '404';
  }
  return result.path;
}

/// Uses the same isolated-page check as the final writer. Native pre-submission
/// can omit already committed pages without treating arbitrary cached bytes as
/// a completed download.
Future<bool> hasCommittedDownloadPage({
  required String from,
  required String path,
  required String cartoonId,
  required String chapterId,
  required String storageChapterId,
}) async {
  final existing = await DownloadAssetStore(
    from: from,
    path: path,
    cartoonId: cartoonId,
    chapterId: chapterId,
    storageChapterId: storageChapterId,
    pictureType: PictureType.page,
  ).findCanonicalDownload();
  if (existing == null) return false;
  try {
    return await _hasIsolatedDownloadPage(existing.path);
  } on FileSystemException {
    return false;
  }
}

Future<DownloadPictureResult> downloadPictureResult({
  required String from,
  String url = '',
  String path = '',
  String cartoonId = '1',
  String chapterId = '',
  String storageChapterId = '',
  PictureType pictureType = PictureType.page,
  String? qjsName,
  String qjsTaskGroupKey = '',
  bool retry = false,
  bool Function()? shouldRetryUntilSuccess,
  Map<String, dynamic> extern = const <String, dynamic>{},
  bool applyRealSr = true,
  bool isolatedPage = false,
  int requestTimeoutMs = 30000,
  Future<Uint8List> Function()? preparedImage,
}) async {
  final resolvedFrom = normalizePluginId(from);
  if (resolvedFrom.isEmpty) {
    throw StateError('downloadPicture missing pluginId');
  }
  if (url.isEmpty) {
    return DownloadPictureResult(
      status: DownloadPictureResultStatus.notFound,
      error: StateError('图片 URL 为空'),
      errorStackTrace: StackTrace.current,
    );
  }

  // 不能通过 URL 文本判断资源是否不存在，合法文件名也可能包含 404，
  // 例如 00404.webp。真正的 HTTP 404/422 在请求结果中按状态码处理。
  if (path.trim().isEmpty) {
    return DownloadPictureResult(
      status: DownloadPictureResultStatus.notFound,
      error: StateError('图片保存路径为空'),
      errorStackTrace: StackTrace.current,
    );
  }

  final assetStore = DownloadAssetStore(
    from: resolvedFrom,
    path: path,
    cartoonId: cartoonId,
    chapterId: chapterId,
    storageChapterId: storageChapterId,
    pictureType: pictureType,
    cacheVariant: onlinePictureCacheVariant(
      from: resolvedFrom,
      url: url,
      type: pictureType,
    ),
  );
  final existingDownload = await assetStore.findCanonicalDownload();
  if (existingDownload != null &&
      (!isolatedPage ||
          await _hasIsolatedDownloadPage(existingDownload.path))) {
    return DownloadPictureResult(
      status: DownloadPictureResultStatus.existing,
      path: existingDownload.path,
      location: DownloadAssetLocation.canonicalDownload,
    );
  }

  // 下载时缓存只检查新的 canonical 路径，不兼容旧缓存。
  final existingCache = isolatedPage
      ? null
      : await assetStore.findCanonicalCache();
  if (existingCache != null) {
    try {
      // A previous version may have cached a gateway response. Never promote
      // those bytes to the user's durable offline copy.
      final cached = await File(existingCache.path).open();
      try {
        _checkImagePayload(
          await cached.read(96),
          url,
          length: await cached.length(),
        );
      } finally {
        await cached.close();
      }
      final canonicalDownloadPath = await assetStore.canonicalDownloadPath();
      await assetStore.copyFileAtomically(
        sourcePath: existingCache.path,
        finalPath: canonicalDownloadPath,
        taskId: qjsTaskGroupKey,
      );
      return DownloadPictureResult(
        status: DownloadPictureResultStatus.downloaded,
        path: canonicalDownloadPath,
        location: DownloadAssetLocation.canonicalDownload,
      );
    } catch (e, stackTrace) {
      // A target write can fail while the cached source remains usable.
      if (e is FileSystemException && await File(existingCache.path).exists()) {
        return DownloadPictureResult(
          status: DownloadPictureResultStatus.failed,
          error: e,
          errorStackTrace: stackTrace,
        );
      }
      logger.w(
        'downloadPicture: 新缓存不可复制，准备重新下载: ${existingCache.path}',
        error: e,
      );
    }
  }

  // 新下载路径和新缓存路径都没有命中后，才兼容查找旧下载布局。
  final legacyDownload = isolatedPage
      ? null
      : await assetStore.findLegacyDownload();
  if (legacyDownload != null) {
    try {
      final canonicalDownloadPath = await assetStore.migrateDownload(
        legacyDownload,
      );
      return DownloadPictureResult(
        status: DownloadPictureResultStatus.existing,
        path: canonicalDownloadPath,
        location: DownloadAssetLocation.canonicalDownload,
      );
    } catch (e) {
      logger.w(
        'downloadPicture: 旧下载文件不可迁移，准备重新下载: ${legacyDownload.path}',
        error: e,
      );
    }
  }

  Uint8List imageData;
  try {
    imageData =
        await (preparedImage?.call() ??
            downloadImageWithRetry(
              url,
              source: resolvedFrom,
              retry: retry,
              shouldRetryUntilSuccess: shouldRetryUntilSuccess,
              qjsName: qjsName,
              qjsTaskGroupKey: qjsTaskGroupKey,
              extern: extern,
              maxRetries: 10,
              requestTimeoutMs: requestTimeoutMs,
            ));
    _checkImagePayload(imageData, url);
    if (isolatedPage && !_hasDownloadImageHeader(imageData)) {
      throw const DownloadPictureInvalidPayload(incomplete: false);
    }
  } catch (e, stackTrace) {
    if (_isDownloadTaskCancelledError(e) || _isQjsRuntimeCancelledError(e)) {
      rethrow;
    }
    if (e is DownloadPictureNotFoundException) {
      logger.w('下载图片资源不存在: source=$resolvedFrom url=$url');
      return DownloadPictureResult(
        status: DownloadPictureResultStatus.notFound,
        error: e,
        errorStackTrace: stackTrace,
      );
    }
    if (e is DownloadPictureEmptyDataException) {
      logger.w('下载图片返回空数据: source=$resolvedFrom url=$url');
      return DownloadPictureResult(
        status: DownloadPictureResultStatus.emptyData,
        error: e,
        errorStackTrace: stackTrace,
      );
    }
    logger.w('downloadPicture failed source=$resolvedFrom url=$url', error: e);
    return DownloadPictureResult(
      status: DownloadPictureResultStatus.failed,
      error: e,
      errorStackTrace: stackTrace,
    );
  }

  _throwIfDownloadCancelled(qjsTaskGroupKey);

  final downloadFilePath = await assetStore.canonicalDownloadPath();

  try {
    final shouldDeobfuscateDownload = await _shouldApplyJmDeobfuscation(
      pluginId: resolvedFrom,
      runtimeName: qjsName,
      pictureType: pictureType,
    );
    if (shouldDeobfuscateDownload) {
      await decodeAndSaveImage(
        imageData,
        chapterId.let(toInt),
        downloadFilePath,
        url,
        taskId: qjsTaskGroupKey,
      );
    } else {
      await saveImage(imageData, downloadFilePath, taskId: qjsTaskGroupKey);
    }
  } catch (e, stackTrace) {
    if (_isDownloadTaskCancelledError(e) || _isQjsRuntimeCancelledError(e)) {
      rethrow;
    }
    logger.w(
      'downloadPicture save failed source=$resolvedFrom url=$url',
      error: e,
    );
    return DownloadPictureResult(
      status: DownloadPictureResultStatus.failed,
      error: e,
      errorStackTrace: stackTrace,
    );
  }

  _throwIfDownloadCancelled(qjsTaskGroupKey);
  final finalFile = File(downloadFilePath);
  if (!await finalFile.exists()) {
    return DownloadPictureResult(
      status: DownloadPictureResultStatus.failed,
      error: StateError('图片保存后文件不存在: $downloadFilePath'),
      errorStackTrace: StackTrace.current,
    );
  }
  if (await finalFile.length() <= 0) {
    return DownloadPictureResult(
      status: DownloadPictureResultStatus.failed,
      error: StateError('图片保存后文件为空: $downloadFilePath'),
      errorStackTrace: StackTrace.current,
    );
  }
  // 导出等只读场景传 applyRealSr=false，避免改动已落盘文件。
  if (pictureType == PictureType.page && applyRealSr) {
    await RealSrSuperResolution.upscaleAndConvertToWebp(downloadFilePath);
  }
  return DownloadPictureResult(
    status: DownloadPictureResultStatus.downloaded,
    path: downloadFilePath,
    location: DownloadAssetLocation.canonicalDownload,
  );
}

/// 删除漫画下载根目录。
///
/// 新布局按 hash(from)/hash(cartoonId) 组织；同时清理已知的旧布局根目录。
Future<void> deleteComicDownloadDirectory(
  String from,
  String comicId, {
  String? legacyStorageRoot,
  bool strict = false,
}) async {
  final downloadRoot = await getDownloadPath();
  final source = normalizePluginId(from);
  final id = comicId.trim();
  final encodedId = encodePath(path: id);
  final candidates = {
    file_path.join(downloadRoot, encodePath(path: source), encodedId),
    if (DownloadAssetStore.isLegacyPathSegment(source)) ...{
      file_path.join(downloadRoot, source, 'original', encodedId),
      if (DownloadAssetStore.isLegacyPathSegment(id))
        file_path.join(downloadRoot, source, 'original', id),
    },
  };

  // Preflight every layout before deleting any files. Older unencoded IDs and
  // linked directories must never authorize deletion outside this work.
  final owned = <String>[];
  for (final path in candidates) {
    try {
      if (await _downloadDirectoryExists(downloadRoot, path)) owned.add(path);
    } on FileSystemException catch (error) {
      if (strict) rethrow;
      logger.w('跳过不安全的下载目录', error: error);
    }
  }
  for (final path in owned) {
    try {
      if (await _downloadDirectoryExists(downloadRoot, path)) {
        await Directory(path).delete(recursive: true);
      }
    } on FileSystemException catch (error) {
      if (strict) rethrow;
      logger.w('删除下载目录失败', error: error);
    }
  }

  // storageRoot can come from another device or an old backup. It is not
  // authority to recursively delete a directory. The three supported layouts
  // above are resolved from this app's download root and comic identity.
}

Future<bool> _downloadDirectoryExists(String root, String path) async {
  final base = file_path.normalize(file_path.absolute(root));
  final target = file_path.normalize(file_path.absolute(path));
  if (!file_path.isWithin(base, target)) {
    throw FileSystemException('Download directory is outside its root', path);
  }
  var current = base;
  final segments = file_path.split(file_path.relative(target, from: base));
  for (final segment in ['', ...segments]) {
    current = file_path.join(current, segment);
    final type = await FileSystemEntity.type(current, followLinks: false);
    if (type == FileSystemEntityType.notFound) return false;
    if (type != FileSystemEntityType.directory) {
      throw FileSystemException('Unsafe download directory', current);
    }
  }
  return true;
}

Future<Uint8List> downloadImageWithRetry(
  String url, {
  required String source,
  bool retry = false,
  int maxRetries = 10,
  bool Function()? shouldRetryUntilSuccess,
  String? qjsName,
  String qjsTaskGroupKey = '',
  Map<String, dynamic> extern = const <String, dynamic>{},
  int requestTimeoutMs = 30000,
}) async {
  var attempts = 0;
  while (true) {
    try {
      attempts += 1;
      _throwIfDownloadCancelled(qjsTaskGroupKey);
      final pluginId = source.trim();
      if (pluginId.isEmpty) {
        throw StateError('downloadImageWithRetry missing plugin id');
      }
      final runtimeName = qjsName?.trim().isNotEmpty == true
          ? qjsName!.trim()
          : pluginId;
      final args = <String, dynamic>{'url': url, 'timeoutMs': requestTimeoutMs};
      if (qjsTaskGroupKey.isNotEmpty) {
        args["taskGroupKey"] = qjsTaskGroupKey;
      }
      final externPayload = <String, dynamic>{...extern};
      if (qjsTaskGroupKey.isNotEmpty) {
        externPayload["taskGroupKey"] = qjsTaskGroupKey;
      }
      if (externPayload.isNotEmpty) {
        args["extern"] = externPayload;
      }
      final result = await executeQjsFetchImageResult(
        pluginId: pluginId,
        runtimeName: runtimeName,
        fnPath: 'fetchImageBytes',
        argsJson: jsonEncode(args),
        taskGroupKey: qjsTaskGroupKey.isEmpty ? null : qjsTaskGroupKey,
      );

      if (result.error != null) {
        final code = result.statusCode ?? imageFailureHttpStatus(result.error!);
        throw DownloadPictureHttpException(
          url,
          result.error!,
          statusCode: code,
          responseBodyLength: result.responseBodyLength,
        );
      }

      final statusCode = result.statusCode;
      if (statusCode == 404 || statusCode == 422) {
        throw DownloadPictureNotFoundException(
          url,
          DownloadPictureHttpException(
            url,
            'HTTP $statusCode',
            statusCode: statusCode,
            responseBodyLength: result.responseBodyLength,
          ),
        );
      }
      if (statusCode != null && (statusCode < 200 || statusCode >= 300)) {
        throw DownloadPictureHttpException(
          url,
          'HTTP $statusCode',
          statusCode: statusCode,
          responseBodyLength: result.responseBodyLength,
        );
      }

      final bytes = result.bytes;
      _checkImagePayload(bytes, url);

      return bytes;
    } catch (e) {
      if (_isDownloadTaskCancelledError(e)) {
        throw const DownloadTaskCancelledException();
      }
      if (_isQjsRuntimeCancelledError(e)) {
        throw const DownloadTaskCancelledException();
      }
      if (e is DownloadPictureNotFoundException) {
        logger.w('下载图片资源不存在，跳过: $url');
        rethrow;
      }
      if (e is DownloadPictureEmptyDataException) {
        logger.w('下载图片返回空数据，停止重试: $url');
        rethrow;
      }
      if (e is DownloadPictureHttpException) {
        if (e.statusCode == 404 || e.statusCode == 422) {
          logger.w('下载图片资源不存在，跳过: $url');
          throw DownloadPictureNotFoundException(url, e);
        }
        logger.w(
          '图片请求失败，将按重试策略处理: $url '
          '(status=${e.statusCode}, bodyLength=${e.responseBodyLength})',
          error: e,
        );
      }
      if (isNonRetryableDownloadFailure(e)) rethrow;
      logger.w('fetchImageBytes failed source=$source url=$url error=$e');

      if (e is TimeoutException) {
        logger.e('下载图片超时: $url, 准备重试...($attempts/$maxRetries)');
      } else {
        logger.e('下载图片失败: $e, URL: $url, 准备重试...($attempts/$maxRetries)');
      }

      final retryForever = shouldRetryUntilSuccess?.call() ?? false;
      if ((!retry && !retryForever) ||
          (!retryForever && attempts >= maxRetries)) {
        rethrow;
      }

      await _delayWithCancel(
        taskGroupKey: qjsTaskGroupKey,
        duration: const Duration(seconds: 1),
      );
    }
  }
}

bool _isQjsRuntimeCancelledError(Object error) {
  return error.toString().contains(_kQjsRuntimeCancelled);
}

bool _isDownloadTaskCancelledError(Object error) {
  return error.toString().contains(_kDownloadTaskCancelled) ||
      error.toString().contains(downloadTaskCancelledMessage);
}

enum DownloadPictureResultStatus {
  existing,
  downloaded,
  notFound,
  emptyData,
  failed,
}

class DownloadPictureResult {
  const DownloadPictureResult({
    required this.status,
    this.path = '',
    this.location,
    this.error,
    this.errorStackTrace,
  });

  final DownloadPictureResultStatus status;
  final String path;
  final DownloadAssetLocation? location;
  final Object? error;
  final StackTrace? errorStackTrace;

  bool get isSuccess =>
      status == DownloadPictureResultStatus.existing ||
      status == DownloadPictureResultStatus.downloaded;
}

class DownloadPictureNotFoundException
    implements Exception, ImageFailureEvidence {
  @override
  bool get retryable => false;
  const DownloadPictureNotFoundException(this.url, [this.cause]);

  final String url;
  final Object? cause;

  @override
  String toString() {
    final detail = cause?.toString().trim();
    if (detail == null || detail.isEmpty) {
      return '图片资源不存在: $url';
    }
    return '图片资源不存在: $url（$detail）';
  }
}

class DownloadPictureHttpException implements Exception, ImageFailureEvidence {
  @override
  bool get retryable =>
      (statusCode == null && imageFailureIsTransient(message)) ||
      statusCode == 408 ||
      statusCode == 425 ||
      statusCode == 429 ||
      (statusCode ?? 0) >= 500;
  const DownloadPictureHttpException(
    this.url,
    this.message, {
    this.statusCode,
    this.responseBodyLength,
  });

  final String url;
  final String message;
  final int? statusCode;
  final int? responseBodyLength;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' HTTP $statusCode';
    final bodyLength = responseBodyLength?.toString() ?? '未知';
    return '图片请求失败$status (响应体 $bodyLength 字节): $url: $message';
  }
}

class DownloadPictureEmptyDataException
    implements Exception, ImageFailureEvidence {
  @override
  bool get retryable => false;
  const DownloadPictureEmptyDataException(this.url);

  final String url;

  @override
  String toString() => '图片下载返回空数据: $url';
}

class DownloadPictureInvalidPayload implements Exception, ImageFailureEvidence {
  const DownloadPictureInvalidPayload({required this.incomplete});
  final bool incomplete;

  @override
  bool get retryable => incomplete;

  @override
  String toString() => incomplete ? '图片数据未传完整' : '站点返回了非图片内容';
}

final _imageTextResponse = RegExp(
  r'^(?:<!doctype\s+html|<html\b|<head\b|<body\b|<script\b|\{|\[)',
  caseSensitive: false,
);

const _downloadImageHeaderBytes = 256 * 1024;

bool _hasDownloadImageHeader(Uint8List bytes) {
  if (bytes.length > _downloadImageHeaderBytes) {
    bytes = Uint8List.sublistView(bytes, 0, _downloadImageHeaderBytes);
  }
  if (parseImageHeaderSize(bytes) != null) return true;
  if (bytes.length < 16) return false;
  final format = String.fromCharCodes(bytes, 4, 12);
  return format == 'ftypavif' || format == 'ftypavis';
}

Future<bool> _hasIsolatedDownloadPage(String path) async {
  final file = await File(path).open();
  try {
    final bytes = await file.read(_downloadImageHeaderBytes);
    try {
      _checkImagePayload(bytes, '', length: await file.length());
    } on DownloadPictureInvalidPayload {
      return false;
    } on DownloadPictureEmptyDataException {
      return false;
    }
    return _hasDownloadImageHeader(bytes);
  } finally {
    await file.close();
  }
}

/// Cheap checks for unambiguous false successes. Leave other formats to the
/// platform decoder; scanning or decoding every image twice hurts scrolling.
void _checkImagePayload(Uint8List bytes, String url, {int? length}) {
  if (bytes.isEmpty) throw DownloadPictureEmptyDataException(url);
  final total = length ?? bytes.length;
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    final declared = ByteData.sublistView(bytes).getUint32(4, Endian.little);
    if (declared + 8 > total) {
      throw const DownloadPictureInvalidPayload(incomplete: true);
    }
    return;
  }
  final first = bytes.first;
  if (first == 0x3c ||
      first == 0x7b ||
      first == 0x5b ||
      first == 0xef ||
      first == 0x20 ||
      (first >= 9 && first <= 13)) {
    final offset =
        bytes.length >= 3 &&
            first == 0xef &&
            bytes[1] == 0xbb &&
            bytes[2] == 0xbf
        ? 3
        : 0;
    final prefix = String.fromCharCodes(bytes.take(96).skip(offset)).trimLeft();
    if (_imageTextResponse.hasMatch(prefix)) {
      throw const DownloadPictureInvalidPayload(incomplete: false);
    }
  }
}

Future<void> _delayWithCancel({
  required String taskGroupKey,
  required Duration duration,
}) async {
  if (taskGroupKey.isEmpty) {
    await Future.delayed(duration);
    return;
  }
  await raceWithDownloadCancel(taskGroupKey, Future<void>.delayed(duration));
}

Future<void> saveImage(
  Uint8List imageData,
  String filePath, {
  String taskId = '',
}) async {
  try {
    await DownloadAssetStore.writeBytesAtomically(
      imageData,
      finalPath: filePath,
      taskId: taskId,
    );
  } catch (e) {
    logger.e('保存图片失败: $filePath', error: e);
    rethrow;
  }
}

Future<void> ensureDirectoryExists(String filePath) async {
  await DownloadAssetStore.ensureParentDirectory(filePath);
}

Future<void> decodeAndSaveImage(
  Uint8List imgData,
  int chapterId,
  String fileName,
  String url, {
  String taskId = '',
}) async {
  if (imgData.isEmpty) {
    throw StateError('图片数据为空');
  }

  final temporaryPath = DownloadAssetStore.temporaryPathFor(
    fileName,
    taskId: taskId,
  );
  final imageInfo = ImageInfo(
    imgData: imgData,
    chapterId: chapterId,
    fileName: temporaryPath,
    url: url,
  );

  try {
    await antiObfuscationPicture(imageInfo: imageInfo);
    await DownloadAssetStore.commitTemporaryFile(temporaryPath, fileName);
  } catch (e, s) {
    try {
      final temporaryFile = File(temporaryPath);
      if (await temporaryFile.exists()) await temporaryFile.delete();
    } catch (_) {}
    logger.e(e, stackTrace: s);
    rethrow;
  }
}
