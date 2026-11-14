import 'package:crypto/crypto.dart';
import 'package:zephyr/page/download/models/download_chapter.dart';
import 'package:zephyr/page/download/adapters/download_chapter_adapter.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show listEquals, visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:zephyr/page/donwload_task/service/download_center_resources.dart';
import 'package:zephyr/service/download/download_asset_store.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/get_path.dart';

enum DownloadResourceSizeStatus { complete, partial, unavailable, error }

/// File lengths, not network traffic or allocated filesystem blocks.
/// A partial measurement exposes a confirmed lower bound through [knownBytes];
/// only a complete measurement exposes [sizeBytes]. Missing files are not zero.
class DownloadResourceSize {
  const DownloadResourceSize({
    required this.resourceKey,
    required this.version,
    required this.status,
    required this.knownBytes,
    required this.knownFiles,
    this.missingFiles = 0,
    this.failedFiles = 0,
    this.chapters = const {},
  });

  final String resourceKey, version;
  final DownloadResourceSizeStatus status;
  final int knownBytes, knownFiles, missingFiles, failedFiles;

  /// Chapter measurements share the same indexed file pass; covers are excluded.
  final Map<String, DownloadResourceSize> chapters;
  int? get sizeBytes =>
      status == DownloadResourceSizeStatus.complete ? knownBytes : null;
}

class _ComicMetricInput {
  const _ComicMetricInput(
    this.key,
    this.source,
    this.comicId,
    this.cover,
    this.metricsVersion,
    this.downloadChapters, [
    this.aliases = const {},
    this.incomplete = const {},
  ]);
  final String key, source, comicId, cover, metricsVersion;
  final List<DownloadChapter> downloadChapters;
  final Map<String, String> aliases;
  final Set<String> incomplete;
}

typedef _ProgressMembership = ({
  DownloadChapterTaskRef chapter,
  int attempt,
  String state,
  String phase,
});

class _Measurement {
  const _Measurement(this.version, this.result, {this.base, this.membership});
  final String version;
  final Future<DownloadResourceSize> result;
  final String? base;
  final List<_ProgressMembership>? membership;
}

/// On-demand, read-only measurements. No directory walks, decoding, migrations,
/// timers or database writes. Changed resource versions invalidate themselves;
/// callers invalidate after file-only mutations or recovery without a row change.
class DownloadResourceMetrics {
  DownloadResourceMetrics({
    this.maximumConcurrent = 2,
    this.maximumCacheEntries = 128,
    DateTime Function()? clock,
    @visibleForTesting this.onProgressFingerprint,
  }) : _clock = clock ?? DateTime.now {
    if (maximumConcurrent < 1 || maximumCacheEntries < 1) {
      throw ArgumentError('Measurement limits must be positive');
    }
  }

  static final instance = DownloadResourceMetrics();
  final int maximumConcurrent, maximumCacheEntries;
  final DateTime Function() _clock;
  final void Function()? onProgressFingerprint;
  final _cache = LinkedHashMap<String, _Measurement>();
  final _waiting = Queue<Completer<void>>();
  int _running = 0;

  @visibleForTesting
  bool get measuring => _running > 0;
  final _progressReadAt = <String, DateTime>{};

  Map<String, String> _aliases(DownloadComicResource? resource) {
    final candidates = <String, Set<String>>{};
    const adapter = DownloadChapterAdapter();
    for (final stored in resource?.chapters ?? []) {
      final id = adapter.fromStoredMap(stored.toMap()).id;
      for (final alias in [
        stored.logicalKey,
        stored.taskChapterId,
        stored.id,
      ].where((value) => value.isNotEmpty)) {
        (candidates[alias] ??= {}).add(id);
      }
    }
    return {
      for (final entry in candidates.entries)
        if (entry.value.length == 1) entry.key: entry.value.single,
    };
  }

  Future<DownloadResourceSize> readComic(DownloadComicResource resource) {
    final prior = _cache.remove(resource.key);
    if (prior != null && prior.version == resource.metricsVersion) {
      _cache[resource.key] = prior;
      return prior.result;
    }
    final future = _limited(
      () => _measure(
        _ComicMetricInput(
          resource.key,
          resource.source,
          resource.comicId,
          resource.cover,
          resource.metricsVersion,
          resource.downloadChapters,
          _aliases(resource),
        ),
      ),
    );
    _cache[resource.key] = _Measurement(resource.metricsVersion, future);
    while (_cache.length > maximumCacheEntries) {
      final oldest = _cache.keys.first;
      _cache.remove(oldest);
      _progressReadAt.remove(oldest);
    }
    return future;
  }

  /// Include only indexed, already-written task paths. The expected image
  /// count never becomes a byte estimate. Progress snapshots share a two-second
  /// measurement window; terminal/membership changes are measured immediately.
  Future<DownloadResourceSize> readComicProgress({
    required String source,
    required String comicId,
    DownloadComicResource? resource,
    Iterable<DownloadTaskJson> tasks = const [],
  }) {
    final rows = tasks
        .where(
          (task) =>
              task.from == source &&
              task.comicId == comicId &&
              task.phaseCode != 'fileRemoved' &&
              task.stateCode != 'cancelled',
        )
        .toList();
    final key = resource?.key ?? buildDownloadTaskKey(source, comicId);
    if (resource != null &&
        (rows.isEmpty || rows.every((task) => task.stateCode == 'completed'))) {
      final aliases = _aliases(resource);
      if (rows.every((task) => aliases.containsKey(task.chapterKey))) {
        return readComic(resource);
      }
    }
    final base = resource?.metricsVersion ?? 'pending';
    final old = _cache[key];
    final now = _clock();
    final active = rows.any(
      (task) => !const {
        'completed',
        'failed',
        'paused',
        'cancelled',
      }.contains(task.stateCode),
    );
    final membership = [
      for (final task in rows)
        (
          chapter: task.chapterRef,
          attempt: task.attempt,
          state: task.stateCode,
          phase: task.phaseCode,
        ),
    ];
    if (active &&
        old != null &&
        old.base == base &&
        listEquals(old.membership, membership) &&
        now.difference(_progressReadAt[key] ?? DateTime(0)) <
            const Duration(seconds: 2)) {
      return old.result;
    }
    if (resource == null &&
        rows.every(
          (task) => task.imagePaths.every((path) => path.trim().isEmpty),
        )) {
      return Future.value(
        DownloadResourceSize(
          resourceKey: key,
          version: 'pending',
          status: DownloadResourceSizeStatus.unavailable,
          knownBytes: 0,
          knownFiles: 0,
        ),
      );
    }
    onProgressFingerprint?.call();
    final version =
        '$base|${sha256.convert(utf8.encode(jsonEncode([
          for (final task in rows) [task.chapterRef.toJson(), task.attempt, task.stateCode, task.phaseCode, task.completedImages, task.imagePaths],
        ])))}';
    if (old?.version == version) return old!.result;
    final chapters = <String, DownloadChapter>{
      for (final chapter
          in resource?.downloadChapters ?? const <DownloadChapter>[])
        chapter.id: chapter,
    };
    const adapter = DownloadChapterAdapter();
    for (final task in rows) {
      final chapter = adapter.fromTaskRef(task.chapterRef);
      final prior = chapters[chapter.id];
      final images = <String, DownloadImage>{
        for (final image in prior?.images ?? const <DownloadImage>[])
          image.path: image,
      };
      for (final path in task.imagePaths) {
        if (path.trim().isNotEmpty)
          images.putIfAbsent(
            path,
            () => DownloadImage(id: path, name: '', path: path),
          );
      }
      if (images.isNotEmpty)
        chapters[chapter.id] = (prior ?? chapter).copyWith(
          images: images.values.toList(),
        );
    }
    final aliasCandidates = <String, Set<String>>{
      for (final entry in _aliases(resource).entries) entry.key: {entry.value},
    };
    for (final task in rows) {
      for (final alias in [
        task.chapterKey,
        task.chapterRef.logicalKey,
        task.chapterRef.chapterId,
        task.chapterRef.requestId,
      ].where((value) => value.isNotEmpty))
        (aliasCandidates[alias] ??= {}).add(task.chapterKey);
    }
    final aliases = {
      for (final entry in aliasCandidates.entries)
        if (entry.value.length == 1) entry.key: entry.value.single,
    };
    final incomplete = {
      for (final task in rows)
        if (task.stateCode != 'completed') task.chapterKey,
    };
    final future = _limited(
      () => _measure(
        _ComicMetricInput(
          key,
          source,
          comicId,
          resource?.cover ?? '',
          version,
          chapters.values.toList(),
          aliases,
          incomplete,
        ),
      ),
    );
    _cache[key] = _Measurement(
      version,
      future,
      base: base,
      membership: membership,
    );
    _progressReadAt[key] = now;
    while (_cache.length > maximumCacheEntries) {
      final oldest = _cache.keys.first;
      _cache.remove(oldest);
      _progressReadAt.remove(oldest);
    }
    return future;
  }

  void invalidate(String resourceKey) {
    _progressReadAt.remove(resourceKey);
    _cache.remove(resourceKey);
  }

  void invalidateAll() {
    _cache.clear();
    _progressReadAt.clear();
  }

  /// Call when resource membership changes to release removed-row cache entries.
  void retainResources(Iterable<DownloadComicResource> resources) {
    final versions = {for (final row in resources) row.key: row.metricsVersion};
    _cache.removeWhere(
      (key, value) => versions[key] != (value.base ?? value.version),
    );
    _progressReadAt.removeWhere((key, _) => !_cache.containsKey(key));
  }

  Future<T> _limited<T>(Future<T> Function() action) async {
    if (_running >= maximumConcurrent) {
      final ready = Completer<void>();
      _waiting.add(ready);
      await ready.future;
    } else {
      _running++;
    }
    try {
      return await action();
    } finally {
      if (_waiting.isNotEmpty) {
        _waiting.removeFirst().complete();
      } else {
        _running--;
      }
    }
  }

  Future<DownloadResourceSize> _measure(_ComicMetricInput resource) async {
    var bytes = 0, missing = 0, failed = 0;
    final files = <String>{};
    final chapters = <String, DownloadResourceSize>{};
    final references = <(PictureType, String, String)>{};
    try {
      final root = p.normalize(p.absolute(await getDownloadPath()));
      if (await FileSystemEntity.type(root, followLinks: false) !=
          FileSystemEntityType.directory) {
        throw const FileSystemException('Unsafe download root');
      }
      final canonicalRoot = await Directory(root).resolveSymbolicLinks();
      final checkedDirectories = <String>{root};
      final checkedFiles = <String, Future<(String, int)?>>{};
      Future<void> measureImage({
        required String path,
        required String chapterId,
        required String storageId,
        required PictureType type,
        void Function(String path, int bytes)? onFile,
      }) async {
        if (!references.add((type, storageId, path))) return;
        if (path.trim().isEmpty) {
          missing++;
          return;
        }
        final store = DownloadAssetStore(
          from: resource.source,
          cartoonId: resource.comicId,
          chapterId: chapterId,
          storageChapterId: storageId,
          path: path,
          pictureType: type,
        );
        var found = false, unsafe = false;
        try {
          for (final candidate in await store.downloadCandidates()) {
            try {
              final measurement = await checkedFiles.putIfAbsent(
                candidate.path,
                () => _fileLength(
                  candidate.path,
                  root,
                  canonicalRoot,
                  checkedDirectories,
                ),
              );
              if (measurement == null) continue;
              if (files.add(measurement.$1)) bytes += measurement.$2;
              onFile?.call(measurement.$1, measurement.$2);
              found = true;
              break;
            } on FileSystemException {
              unsafe = true;
            }
          }
        } catch (_) {
          unsafe = true;
        }
        if (!found) {
          if (unsafe) {
            failed++;
          } else {
            missing++;
          }
        }
      }

      if (resource.cover.trim().isNotEmpty) {
        try {
          final cover = jsonDecode(resource.cover);
          if (cover is! Map)
            throw const FormatException('Invalid stored cover');
          final extern = cover['extern'] is Map
              ? cover['extern'] as Map
              : const {};
          final raw = cover['path'] as String? ?? '';
          final path = raw.trim().isEmpty
              ? extern['path'] as String? ?? ''
              : raw;
          if (path.trim().isNotEmpty && extern['downloadSkipped'] != true) {
            await measureImage(
              path: path,
              chapterId: '',
              storageId: '',
              type: PictureType.cover,
            );
          }
        } catch (_) {
          failed++;
        }
      }
      for (final chapter in resource.downloadChapters) {
        // Deduplicate within each chapter, while the total still deduplicates
        // physical files across chapters. No additional filesystem pass.
        references.clear();
        final chapterFiles = <String>{};
        var chapterBytes = 0;
        final missingBefore = missing, failedBefore = failed;
        for (final image in chapter.images) {
          if (image.extern['downloadSkipped'] == true) continue;
          await measureImage(
            path: image.path,
            chapterId: chapter.id,
            storageId: chapter.effectiveStorageId,
            type: PictureType.page,
            onFile: (path, length) {
              if (chapterFiles.add(path)) chapterBytes += length;
            },
          );
        }
        final chapterMissing = missing - missingBefore;
        final chapterFailed = failed - failedBefore;
        chapters[chapter.id] = DownloadResourceSize(
          resourceKey: resource.key,
          version: resource.metricsVersion,
          status: chapterFiles.isEmpty
              ? chapterFailed > 0
                    ? DownloadResourceSizeStatus.error
                    : DownloadResourceSizeStatus.unavailable
              : chapterMissing > 0 ||
                    chapterFailed > 0 ||
                    resource.incomplete.contains(chapter.id)
              ? DownloadResourceSizeStatus.partial
              : DownloadResourceSizeStatus.complete,
          knownBytes: chapterBytes,
          knownFiles: chapterFiles.length,
          missingFiles: chapterMissing,
          failedFiles: chapterFailed,
        );
      }
    } catch (_) {
      failed++;
    }
    for (final alias in resource.aliases.entries) {
      final value = chapters[alias.value];
      if (value != null) chapters[alias.key] = value;
    }
    final status = files.isEmpty
        ? failed > 0
              ? DownloadResourceSizeStatus.error
              : DownloadResourceSizeStatus.unavailable
        : missing > 0 ||
              failed > 0 ||
              resource.incomplete.isNotEmpty ||
              chapters.values.any((chapter) => chapter.sizeBytes == null)
        ? DownloadResourceSizeStatus.partial
        : DownloadResourceSizeStatus.complete;
    return DownloadResourceSize(
      resourceKey: resource.key,
      version: resource.metricsVersion,
      status: status,
      knownBytes: bytes,
      knownFiles: files.length,
      missingFiles: missing,
      failedFiles: failed,
      chapters: Map.unmodifiable(chapters),
    );
  }

  Future<(String, int)?> _fileLength(
    String path,
    String root,
    String canonicalRoot,
    Set<String> checkedDirectories,
  ) async {
    path = p.normalize(p.absolute(path));
    if (!p.isWithin(root, path)) {
      throw const FileSystemException('Download file is outside its root');
    }
    var directory = root;
    final segments = p.split(p.relative(p.dirname(path), from: root));
    for (final segment in segments) {
      if (segment == '.') continue;
      directory = p.join(directory, segment);
      if (checkedDirectories.contains(directory)) continue;
      final type = await FileSystemEntity.type(directory, followLinks: false);
      if (type == FileSystemEntityType.notFound) return null;
      if (type != FileSystemEntityType.directory) {
        throw const FileSystemException('Unsafe download directory');
      }
      checkedDirectories.add(directory);
    }
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return null;
    if (type != FileSystemEntityType.file) {
      throw const FileSystemException('Unsafe download file');
    }
    final canonical = await File(path).resolveSymbolicLinks();
    if (!p.isWithin(canonicalRoot, canonical)) {
      throw const FileSystemException('Linked download file escapes its root');
    }
    final stat = await File(canonical).stat();
    if (stat.type != FileSystemEntityType.file || stat.size <= 0) return null;
    return (canonical, stat.size);
  }
}

/// Process-only byte rate using the caller's monotonic clock, with no polling.
/// The first sample, counter rollback and terminal states have an unknown rate.
class VideoTransferRate {
  String? _taskKey;
  int? _received;
  Duration? _elapsed;

  double? update({
    required String taskKey,
    required int received,
    required Duration elapsed,
    required bool active,
  }) {
    if (!active || received < 0 || elapsed.isNegative) {
      reset();
      return null;
    }
    final previous = _received, at = _elapsed;
    if (_taskKey != taskKey ||
        previous == null ||
        at == null ||
        received < previous ||
        elapsed < at) {
      _taskKey = taskKey;
      _received = received;
      _elapsed = elapsed;
      return null;
    }
    final microseconds = (elapsed - at).inMicroseconds;
    if (microseconds <= 0) return null;
    _received = received;
    _elapsed = elapsed;
    return (received - previous) *
        Duration.microsecondsPerSecond /
        microseconds;
  }

  void reset() {
    _taskKey = null;
    _received = null;
    _elapsed = null;
  }
}
