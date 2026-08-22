import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as file_path;
import 'package:zephyr/src/rust/api/simple.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/get_path.dart';

/// 资产在本地磁盘上的候选位置。
///
/// 新文件只写入 [canonicalDownload]；其余位置仅用于兼容已经存在的文件。
enum DownloadAssetLocation {
  direct,
  canonicalDownload,
  legacyDownload,
  canonicalCache,
  legacyCache,
}

class DownloadAssetCandidate {
  const DownloadAssetCandidate({required this.path, required this.location});

  final String path;
  final DownloadAssetLocation location;
}

/// 下载/缓存图片的统一路径解析器和文件落盘工具。
class DownloadAssetStore {
  DownloadAssetStore({
    required String from,
    required String path,
    required String cartoonId,
    required String chapterId,
    required this.pictureType,
  }) : from = from.trim(),
       path = path.trim(),
       cartoonId = cartoonId.trim(),
       chapterId = chapterId.trim();

  final String from;
  final String path;
  final String cartoonId;
  final String chapterId;
  final PictureType pictureType;

  bool get isCover => pictureType == PictureType.cover;

  /// 按“直接绝对路径 -> 编码下载 -> 原始下载 -> 编码缓存 -> 原始缓存”排序。
  Future<List<DownloadAssetCandidate>> candidates() async {
    if (path.isEmpty) return const [];

    if (file_path.isAbsolute(path)) {
      return [
        DownloadAssetCandidate(
          path: path,
          location: DownloadAssetLocation.direct,
        ),
      ];
    }

    final cacheRoot = await getCachePath();
    final downloadRoot = await getDownloadPath();
    final encodedPath = encodePath(path: normalizeStoredAssetPath(path));
    final encodedCartoonId = encodePath(path: cartoonId);
    final encodedChapterId = encodePath(path: chapterId);

    final result = <DownloadAssetCandidate>[];
    void addCandidate(
      String basePath,
      String cartoonSegment,
      String chapterSegment,
      String fileSegment,
      DownloadAssetLocation location, {
      String? rootFolder,
    }) {
      final candidate = _buildStoredFilePath(
        basePath,
        from,
        fileSegment,
        cartoonSegment,
        isCover ? '' : chapterSegment,
        rootFolder: rootFolder,
      );
      if (isWithinRoot(basePath, candidate)) {
        result.add(DownloadAssetCandidate(path: candidate, location: location));
      }
    }

    addCandidate(
      downloadRoot,
      encodedCartoonId,
      encodedChapterId,
      encodedPath,
      DownloadAssetLocation.canonicalDownload,
      rootFolder: 'original',
    );
    addCandidate(
      downloadRoot,
      cartoonId,
      chapterId,
      normalizeStoredAssetPath(path),
      DownloadAssetLocation.legacyDownload,
      rootFolder: 'original',
    );
    addCandidate(
      cacheRoot,
      encodedCartoonId,
      encodedChapterId,
      encodedPath,
      DownloadAssetLocation.canonicalCache,
    );
    addCandidate(
      cacheRoot,
      cartoonId,
      chapterId,
      normalizeStoredAssetPath(path),
      DownloadAssetLocation.legacyCache,
    );
    return result;
  }

  Future<DownloadAssetCandidate?> findExisting() async {
    for (final candidate in await candidates()) {
      final file = File(candidate.path);
      try {
        if (await file.exists() && await file.length() > 0) {
          return candidate;
        }
      } catch (_) {
        // 读取失败时继续尝试下一个兼容路径。
      }
    }
    return null;
  }

  Future<String> canonicalDownloadPath() async {
    final candidate = (await candidates()).firstWhere(
      (item) => item.location == DownloadAssetLocation.canonicalDownload,
      orElse: () => throw StateError('无法生成编码下载路径'),
    );
    return candidate.path;
  }

  Future<String> canonicalCachePath() async {
    final candidate = (await candidates()).firstWhere(
      (item) => item.location == DownloadAssetLocation.canonicalCache,
      orElse: () => throw StateError('无法生成编码缓存路径'),
    );
    return candidate.path;
  }

  /// 将字节先写入临时文件，再提交到最终路径。
  static Future<void> writeBytesAtomically(
    Uint8List data, {
    required String finalPath,
    String taskId = '',
  }) async {
    if (data.isEmpty) {
      throw StateError('不能写入空图片数据');
    }

    final temporaryPath = temporaryPathFor(finalPath, taskId: taskId);
    final temporaryFile = File(temporaryPath);
    try {
      await ensureParentDirectory(finalPath);
      await temporaryFile.writeAsBytes(data, flush: true);
      if (await temporaryFile.length() <= 0) {
        throw StateError('临时图片文件为空');
      }
      await commitTemporaryFile(temporaryPath, finalPath);
    } catch (_) {
      await _deleteIfExists(temporaryFile);
      rethrow;
    }
  }

  /// 将已有缓存文件原子复制到编码下载路径。
  Future<void> copyFileAtomically({
    required String sourcePath,
    required String finalPath,
    String taskId = '',
  }) async {
    final source = File(sourcePath);
    final temporaryPath = temporaryPathFor(finalPath, taskId: taskId);
    final temporaryFile = File(temporaryPath);
    try {
      await ensureParentDirectory(finalPath);
      await source.copy(temporaryPath);
      if (await temporaryFile.length() <= 0) {
        throw StateError('临时复制文件为空');
      }
      await commitTemporaryFile(temporaryPath, finalPath);
    } catch (_) {
      await _deleteIfExists(temporaryFile);
      rethrow;
    }
  }

  static String temporaryPathFor(String finalPath, {String taskId = ''}) {
    final rawSuffix = taskId.trim().isNotEmpty
        ? taskId.trim()
        : DateTime.now().microsecondsSinceEpoch.toString();
    final suffix = rawSuffix.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
    return '$finalPath.part.$suffix';
  }

  static Future<void> commitTemporaryFile(
    String temporaryPath,
    String finalPath,
  ) async {
    final temporaryFile = File(temporaryPath);
    final finalFile = File(finalPath);
    if (!await temporaryFile.exists() || await temporaryFile.length() <= 0) {
      throw StateError('临时图片文件不存在或为空: $temporaryPath');
    }

    // 并发下载同一资源时，已经提交的完整文件优先保留。
    if (await finalFile.exists() && await finalFile.length() > 0) {
      await _deleteIfExists(temporaryFile);
      return;
    }

    await ensureParentDirectory(finalPath);
    try {
      await temporaryFile.rename(finalPath);
    } on FileSystemException {
      // Windows 等平台在 rename 竞态下可能报告目标已存在；重新确认后
      // 将其视为另一个执行器已经完成写入。
      if (await finalFile.exists() && await finalFile.length() > 0) {
        await _deleteIfExists(temporaryFile);
        return;
      }
      rethrow;
    }
  }

  static Future<void> ensureParentDirectory(String filePath) async {
    final directory = Directory(file_path.dirname(filePath));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  static Future<void> _deleteIfExists(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  static String _buildStoredFilePath(
    String basePath,
    String from,
    String path,
    String cartoonId,
    String chapterId, {
    String? rootFolder,
  }) {
    final fileName = normalizeStoredAssetPath(path);
    final segments = <String>[basePath, from.trim()];
    if (rootFolder != null && rootFolder.isNotEmpty) {
      segments.add(rootFolder);
    }
    if (cartoonId.trim().isNotEmpty) segments.add(cartoonId.trim());
    if (chapterId.trim().isNotEmpty) segments.add(chapterId.trim());
    segments.add(fileName);
    return file_path.joinAll(segments);
  }

  static bool isWithinRoot(String rootPath, String candidatePath) {
    final root = file_path.normalize(file_path.absolute(rootPath));
    final candidate = file_path.normalize(file_path.absolute(candidatePath));
    final normalizedRoot = Platform.isWindows ? root.toLowerCase() : root;
    final normalizedCandidate = Platform.isWindows
        ? candidate.toLowerCase()
        : candidate;
    return normalizedCandidate == normalizedRoot ||
        normalizedCandidate.startsWith('$normalizedRoot${file_path.separator}');
  }
}

/// 取消任务时只清理该任务写入的临时文件，不触碰已经提交的历史图片。
Future<void> cleanupDownloadTaskTemporaryFiles(String taskKey) async {
  final suffix = taskKey.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
  if (suffix.isEmpty) return;

  final roots = <String>[await getDownloadPath(), await getCachePath()];
  for (final rootPath in roots) {
    final root = Directory(rootPath);
    if (!await root.exists()) continue;

    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File ||
          !DownloadAssetStore.isWithinRoot(rootPath, entity.path)) {
        continue;
      }
      final name = file_path.basename(entity.path);
      if (!name.endsWith('.part.$suffix')) continue;
      try {
        await entity.delete();
      } catch (_) {
        // 临时文件清理失败不应影响任务状态迁移。
      }
    }
  }
}

String normalizeStoredAssetPath(String rawPath, {bool allowEmpty = false}) {
  final raw = rawPath.trim();
  if (raw.isEmpty) {
    if (allowEmpty) return '';
    throw StateError('normalizeStoredAssetPath requires non-empty path');
  }
  final candidate = file_path.isAbsolute(raw) ? file_path.basename(raw) : raw;
  final sanitized = candidate.replaceAll(RegExp(r'[^a-zA-Z0-9_\-.]'), '_');
  if (sanitized.isNotEmpty) return sanitized;
  throw StateError('normalizeStoredAssetPath received invalid path: $rawPath');
}
