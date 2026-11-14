import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/donwload_task/service/download_work_pin_removal.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_hls_assets.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/util/get_path.dart';
import 'package:zephyr/service/local_import_recovery.dart';
import 'package:zephyr/network/sync/sync_service.dart'
    show runExclusiveStorageOperation;

/// Owned by exactly one native player, released after its native dispose future.
class ManagedVideoReadLease {
  ManagedVideoReadLease._(this.resourceId);
  final String resourceId;
  bool _released = false;
  void release() {
    if (_released) return;
    _released = true;
    final readers = VideoLocalResources._readers[resourceId];
    readers?.remove(this);
    if (readers?.isEmpty == true) {
      VideoLocalResources._readers.remove(resourceId);
    }
  }
}

class ManagedVideoTreeLease {
  ManagedVideoTreeLease._();
  bool _released = false;
  void release() {
    if (_released) return;
    _released = true;
    VideoLocalResources._treeWriters.remove(this);
  }
}

class ManagedVideoResourceBusy implements Exception {
  const ManagedVideoResourceBusy();
  @override
  String toString() => 'managed_video_resource_busy';
}

/// Scoped to one download-center execution inside the storage mutation queue.
/// Reuses the native download/export hold; it never reacquires its own hold.
class ManagedVideoRemovalLease {
  ManagedVideoRemovalLease._(this.resourceId, this._snapshot);
  final String resourceId;
  final Map<String, dynamic>? _snapshot;
  bool _active = true, _removed = false;
  bool get hasResource => _snapshot != null;
  void requireExpectedVersion(ManagedVideoRemovalVersion expected) {
    if (expected.resourceId != resourceId) {
      throw ArgumentError(
        'Video removal token belongs to a different resource',
      );
    }
    if (_snapshot != null &&
        VideoLocalResources.resourceVersion(_snapshot) !=
            expected._fingerprint) {
      throw StateError('Video resource changed after confirmation');
    }
  }

  Future<void> remove({bool allowUnindexedOwnedFile = false}) =>
      VideoLocalResources._removeBoundResource(
        this,
        allowUnindexedOwnedFile: allowUnindexedOwnedFile,
      );
}

class ManagedVideoRemovalVersion {
  ManagedVideoRemovalVersion._(this.resourceId, this._fingerprint);
  final String resourceId;
  final String? _fingerprint;

  bool get hasResource => _fingerprint != null;
}

/// Device-owned resources. Neither this index nor its relative file IDs belong
/// in PortablePreferences or the synchronized video library. Keeping the index
/// beside media also makes an include-downloads backup self-contained.
abstract final class VideoLocalResources {
  static const directoryName = 'video-v1';
  static final changes = ValueNotifier<int>(0);
  static Future<void>? _writes;
  static int _sequence = 0;
  static final _inUse = <String>{};
  static final _readers = <String, Set<ManagedVideoReadLease>>{};
  static final _treeWriters = <ManagedVideoTreeLease>{};
  static void requireNoReadLeases() {
    if (_readers.isNotEmpty) throw const ManagedVideoResourceBusy();
  }

  static ManagedVideoTreeLease acquireTreeMutationLease() {
    LocalImportRecovery.requireRecovered();
    requireNoReadLeases();
    if (_treeWriters.isNotEmpty) throw const ManagedVideoResourceBusy();
    final lease = ManagedVideoTreeLease._();
    _treeWriters.add(lease);
    return lease;
  }

  static ManagedVideoReadLease acquireReadLease(Uri uri, String id) {
    LocalImportRecovery.requireRecovered();
    if (!authorizesFile(uri, id)) {
      throw const FormatException('Invalid managed video source');
    }
    if (_treeWriters.isNotEmpty || _inUse.contains(id)) {
      throw const ManagedVideoResourceBusy();
    }
    final lease = ManagedVideoReadLease._(id);
    (_readers[id] ??= {}).add(lease);
    return lease;
  }

  static bool tryHold(String id) =>
      validId(id) &&
      _readers[id]?.isNotEmpty != true &&
      _treeWriters.isEmpty &&
      _inUse.add(id);
  static ManagedVideoReadLease acquireHlsReadLease(String id) {
    LocalImportRecovery.requireRecovered();
    if (!validId(id) || _treeWriters.isNotEmpty || _inUse.contains(id)) {
      throw const ManagedVideoResourceBusy();
    }
    final lease = ManagedVideoReadLease._(id);
    (_readers[id] ??= {}).add(lease);
    return lease;
  }

  static void release(String id) => _inUse.remove(id);
  static String? _cachedRoot;
  static List<Map<String, dynamic>>? _cache;

  /// Preserve verified line/episode selectors for new API downloads. Old
  /// selector-free API indexes remain readable under their original identity;
  /// they are never guessed to belong to any particular episode.
  static Uri? resourcePage(Uri video) {
    final identity = videoPlaybackIdentity(video);
    if (identity != null) return identity;
    return video.hasQuery || video.hasFragment ? null : videoPublicPage(video);
  }

  static String identity(String source, Uri video, String quality) {
    final page = resourcePage(video);
    if (source.isEmpty || source.length > 200 || page == null) {
      throw ArgumentError('Invalid local video identity');
    }
    return sha256.convert(utf8.encode('$source|$page|$quality')).toString();
  }

  static bool validId(String id) => RegExp(r'^[a-f0-9]{64}$').hasMatch(id);
  static Future<Directory> root({bool create = true}) async {
    final files = Directory(await getFilePath(create: create));
    final downloads = Directory(p.join(files.path, 'downloads'));
    if (create && !await downloads.exists()) {
      await downloads.create(recursive: true);
    }
    final directory = Directory(p.join(downloads.path, directoryName));
    if (!create && !await downloads.exists()) return directory;
    final canonicalFiles = await files.resolveSymbolicLinks();
    if (await downloads.resolveSymbolicLinks() !=
        p.join(canonicalFiles, 'downloads')) {
      throw const FormatException('Linked download root is not supported');
    }
    if (await directory.exists() &&
        await directory.resolveSymbolicLinks() !=
            p.join(canonicalFiles, 'downloads', directoryName)) {
      throw const FormatException('Linked managed root is not supported');
    }
    return directory;
  }

  /// No plugin URL or restored absolute path is accepted as a local file.
  static Future<File> file(String id) async {
    if (!validId(id)) throw const FormatException('Invalid local video ID');
    final directory = await root();
    final path = p.join(directory.path, '$id.mp4');
    if (await FileSystemEntity.type(path, followLinks: false) ==
        FileSystemEntityType.link) {
      throw const FormatException('Linked local video is not supported');
    }
    return File(path);
  }

  static bool authorizesFile(Uri uri, String id) =>
      validId(id) &&
      _cachedRoot != null &&
      uri == Uri.file(p.join(_cachedRoot!, '$id.mp4'));

  static Future<NativePlaybackSession> playback(String id) async =>
      (await readPlaybackResource(id)).session;

  static Future<({Map<String, dynamic> row, NativePlaybackSession session})>
  readPlaybackResource(String id, {Map<String, dynamic>? resource}) async {
    if (!validId(id)) throw const FormatException('Invalid local video ID');
    LocalImportRecovery.requireRecovered();
    Map<String, dynamic>? hls;
    if (VideoHlsAssets.supported &&
        resource?['resourceId'] == id &&
        resource?['format'] == 'hls' &&
        resource?['available'] == true) {
      try {
        hls = VideoHlsAssets.validateRow(resource);
      } on FormatException {
        // Some older list projections have no native generation binding.
      }
    }
    if (hls != null) {
      // The native read lease checks the exact generation and package before
      // creating a controller. A snapshot alone cannot authorize a file URL.
      return _playbackResource(hls, VideoHlsAssets.playbackUri(hls));
    }
    final mp4 = await _readCheckedMp4(id);
    if (mp4 != null) return _playbackResource(mp4.row, mp4.uri);
    final rows = await VideoHlsAssets.read();
    final row = rows.where((row) => row['resourceId'] == id).firstOrNull;
    if (row == null || row['available'] != true) {
      throw const FileSystemException('Local video is unavailable');
    }
    return _playbackResource(row, VideoHlsAssets.playbackUri(row));
  }

  static Future<Map<String, dynamic>?> readMp4PosterResource(String id) async {
    if (!validId(id)) return null;
    LocalImportRecovery.requireRecovered();
    return (await _readCheckedMp4(id))?.row;
  }

  static Future<({Map<String, dynamic> row, Uri uri})?> _readCheckedMp4(
    String id,
  ) => runExclusiveStorageOperation(() async {
    await flush();
    final directory = await root();
    final rows = await _readDirectory(directory, onlyId: id);
    if (rows.isEmpty) return null;
    if (rows.length != 1 || rows.single['available'] != true) {
      throw const FileSystemException('Local video is unavailable');
    }
    if (_cachedRoot != directory.path) _cache = null;
    _cachedRoot = directory.path;
    return (row: rows.single, uri: File(p.join(directory.path, '$id.mp4')).uri);
  });

  static ({Map<String, dynamic> row, NativePlaybackSession session})
  _playbackResource(Map<String, dynamic> row, Uri media) => (
    row: row,
    session: NativePlaybackSession(
      title: row['title'] as String,
      watchUrl: Uri.parse(row['url'] as String),
      description: '',
      tags: const [],
      sources: [
        NativePlaybackSource(
          url: media,
          label: row['quality'] as String,
          headers: const {},
          localResourceId: row['resourceId'] as String,
        ),
      ],
    ),
  );

  static void invalidate() {
    _cache = null;
    changes.value++;
  }

  static Future<void> flush() async {
    await _writes?.catchError((Object _) {});
  }

  static Future<List<Map<String, dynamic>>> read({bool fresh = false}) =>
      runExclusiveStorageOperation(() => _readAllNow(fresh: fresh));

  /// A URL-only position belongs to a local file only when the checked
  /// inventory can identify a single playable version without delaying startup.
  static Future<bool> isUniquePlaybackVersion(
    String source,
    Uri watchUrl,
    String resourceId,
  ) async {
    try {
      final (mp4, hls) = await (
        runExclusiveStorageOperation(_readNow),
        VideoHlsAssets.read(),
      ).wait.timeout(const Duration(milliseconds: 500));
      final matches = {
        for (final row in [...mp4, ...hls])
          if (row['available'] == true &&
              row['source'] == source &&
              row['url'] == watchUrl.toString() &&
              row['resourceId'] is String)
            row['resourceId'] as String,
      };
      return matches.length == 1 && matches.contains(resourceId);
    } catch (_) {
      return false;
    }
  }

  /// Only the download center can present the checked MP4 files alongside a
  /// native inventory error. Other consumers continue to require both indexes.
  static Future<({List<Map<String, dynamic>> rows, bool complete})>
  readDownloadInventory({
    bool fresh = false,
    void Function(List<Map<String, dynamic>>)? onCheckedMp4,
  }) => runExclusiveStorageOperation(() async {
    final mp4 = await _readNow(fresh: fresh);
    onCheckedMp4?.call(mp4);
    try {
      return (rows: [...mp4, ...await VideoHlsAssets.read()], complete: true);
    } catch (_) {
      return (rows: mp4, complete: false);
    }
  });

  static Future<List<Map<String, dynamic>>> readPlaybackQueue() async {
    LocalImportRecovery.requireRecovered();
    // A queue is advisory. Its snapshot doesn't own the storage operation
    // lock or update the managed index cache. Opening an episode verifies the
    // exact MP4 on disk or obtains a generation-bound native HLS lease.
    final rows = await _readDirectory(await root(create: false));
    return [...rows, ...await VideoHlsAssets.read()];
  }

  /// A storage summary is advisory and has no authority to open or modify
  /// files. Keep the two inventories independent without waiting for sync.
  static Future<({List<Map<String, dynamic>> rows, bool complete})>
  readStorageInventory() async {
    LocalImportRecovery.requireRecovered();
    Future<List<Map<String, dynamic>>?> readMp4() async {
      if (_treeWriters.isNotEmpty) return null;
      try {
        final rows = await _readDirectory(await root(create: false));
        return _treeWriters.isEmpty ? rows : null;
      } catch (_) {
        return null;
      }
    }

    final (mp4, hls) = await (
      readMp4(),
      VideoHlsAssets.read()
          .then<List<Map<String, dynamic>>?>((rows) => rows)
          .catchError((Object _) => null),
    ).wait;
    return (rows: [...?mp4, ...?hls], complete: mp4 != null && hls != null);
  }

  static Future<List<Map<String, dynamic>>> _readAllNow({
    bool fresh = false,
  }) async {
    final rows = await _readNow(fresh: fresh);
    final hls = await VideoHlsAssets.read();
    return [...rows, ...hls];
  }

  static Future<void> requirePortableBackup() async {
    if ((await VideoHlsAssets.read()).any(
      (row) => row['filePresent'] == true,
    )) {
      throw const HlsPortableBackupUnsupported();
    }
  }

  static Future<List<Map<String, dynamic>>> _readNow({
    bool fresh = false,
  }) async {
    await flush();
    final directory = await root();
    if (fresh || _cachedRoot != directory.path) _cache = null;
    _cachedRoot = directory.path;
    if (_cache != null) {
      return _cache!.map((row) => Map<String, dynamic>.from(row)).toList();
    }
    final rows = await _readDirectory(directory);
    _cache = rows;
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  static Future<List<Map<String, dynamic>>> _readDirectory(
    Directory directory, {
    bool strict = false,
    String? onlyId,
    bool verifyMedia = true,
  }) async {
    final index = File(p.join(directory.path, 'index.json'));
    if (!await index.exists()) {
      if (strict) throw const FormatException('Missing local video index');
      return [];
    }
    if (await FileSystemEntity.type(index.path, followLinks: false) !=
            FileSystemEntityType.file ||
        await index.length() > 24 * 1024 * 1024) {
      throw const FormatException('Invalid local video index');
    }
    final raw = jsonDecode(await index.readAsString());
    if (raw is! Map ||
        raw['format'] != 'breeze-local-video' ||
        raw['version'] != 1 ||
        raw['resources'] is! List ||
        raw.keys.any(
          (key) => !const {'format', 'version', 'resources'}.contains(key),
        )) {
      throw const FormatException('Unsupported local video index');
    }
    final rows = <Map<String, dynamic>>[];
    for (final value in raw['resources'] as List) {
      if (value is! Map) throw const FormatException('Invalid local video row');
      if (onlyId != null && value['resourceId'] != onlyId) continue;
      final row = Map<String, dynamic>.from(value);
      if (row.keys.any(
        (key) => !const {
          'resourceId',
          'source',
          'url',
          'title',
          'quality',
          'bytes',
          'taskKey',
          'showTask',
          'at',
          'cover',
          'durationMs',
          'sourceDuration',
        }.contains(key),
      )) {
        throw const FormatException('Unknown local video metadata');
      }
      final cover = row['cover'];
      final durationMs = row['durationMs'],
          sourceDuration = row['sourceDuration'];
      if ((durationMs != null && (durationMs is! int || durationMs <= 0)) ||
          (sourceDuration != null &&
              (sourceDuration is! String ||
                  sourceDuration.trim().isEmpty ||
                  sourceDuration.length > 300))) {
        throw const FormatException('Invalid local video duration');
      }
      final image = cover is String ? Uri.tryParse(cover) : null;
      if (cover != null &&
          (image?.scheme != 'https' ||
              image?.host.isEmpty != false ||
              image?.userInfo.isNotEmpty == true ||
              image?.hasQuery == true ||
              image?.hasFragment == true)) {
        throw const FormatException('Invalid public poster URL');
      }
      final id = row['resourceId'], source = row['source'], url = row['url'];
      final quality = row['quality'],
          title = row['title'],
          bytes = row['bytes'];
      final page = url is String ? Uri.tryParse(url) : null;
      if (id is! String ||
          !validId(id) ||
          source is! String ||
          page == null ||
          quality is! String ||
          quality.length > 80 ||
          title is! String ||
          title.length > 300 ||
          bytes is! int ||
          bytes <= 12 ||
          row['at'] is! int ||
          row['taskKey'] is! String ||
          row['showTask'] is! bool ||
          identity(source, page, quality) != id ||
          resourcePage(page)?.toString() != url) {
        throw const FormatException('Invalid local video metadata');
      }
      // Confirmation binds persisted metadata, not physical availability.
      // The removal lease still performs full validation before any mutation.
      if (!verifyMedia) {
        rows.add(row);
        continue;
      }
      final media = File(p.join(directory.path, '$id.mp4'));
      final type = await FileSystemEntity.type(media.path, followLinks: false);
      if (type != FileSystemEntityType.file &&
          type != FileSystemEntityType.notFound) {
        throw const FormatException('Invalid local video file');
      }
      row['filePresent'] = type == FileSystemEntityType.file;
      row['available'] =
          row['filePresent'] == true && await _validMp4(media, bytes);
      if (strict && row['filePresent'] == true && row['available'] != true) {
        throw const FormatException('Local video bytes did not match index');
      }
      rows.add(row);
    }
    return rows;
  }

  /// Pure backup validation. Caller owns the storage queue; this method must
  /// not await queued writes or touch runtime caches/notifiers.
  static Future<void> validateBackupDirectory(Directory downloads) async {
    await readBackupRows(downloads);
  }

  static Future<List<Map<String, dynamic>>> readBackupRows(
    Directory downloads,
  ) async {
    final parentType = await FileSystemEntity.type(
      downloads.path,
      followLinks: false,
    );
    if (parentType == FileSystemEntityType.notFound) return [];
    if (parentType != FileSystemEntityType.directory) {
      throw const FormatException('Invalid download directory');
    }
    final directory = Directory(p.join(downloads.path, directoryName));
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) return [];
    if (type != FileSystemEntityType.directory) {
      throw const FormatException('Invalid local video directory');
    }
    final rows = await _readDirectory(directory, strict: true);
    final allowed = {
      'index.json',
      for (final row in rows) '${row['resourceId']}.mp4',
    };
    if (allowed.length != rows.length + 1) {
      throw const FormatException('Duplicate local video identity');
    }
    await for (final entity in directory.list(followLinks: false)) {
      if (!allowed.contains(p.basename(entity.path)) ||
          await FileSystemEntity.type(entity.path, followLinks: false) !=
              FileSystemEntityType.file) {
        throw const FormatException('Uncommitted local video files');
      }
    }
    return rows;
  }

  static Future<bool> _validMp4(File file, int bytes) async {
    if (bytes <= 12 || !await file.exists() || await file.length() != bytes) {
      return false;
    }
    final input = await file.open();
    try {
      final header = await input.read(12);
      return header.length == 12 &&
          ascii.decode(header.sublist(4, 8), allowInvalid: true) == 'ftyp';
    } finally {
      await input.close();
    }
  }

  static Future<File> stagedFile(String id) async {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(id)) {
      throw const FormatException('Invalid stage ID');
    }
    final cache = Directory(await getCachePath());
    final directory = Directory(p.join(cache.path, 'breeze-video-staging'));
    if (await directory.exists() &&
        await directory.resolveSymbolicLinks() !=
            p.join(
              await cache.resolveSymbolicLinks(),
              'breeze-video-staging',
            )) {
      throw const FormatException('Linked staging directory');
    }
    final stage = File(p.join(directory.path, '$id.mp4'));
    if (await FileSystemEntity.type(stage.path, followLinks: false) ==
        FileSystemEntityType.link) {
      throw const FormatException('Linked stage file');
    }
    return stage;
  }

  static Future<void> discardStage(String id) async {
    final stage = await stagedFile(id);
    if (await stage.exists()) await stage.delete();
  }

  static Future<void> _change(
    void Function(List<Map<String, dynamic>>) change,
  ) {
    final job = (_writes ?? Future<void>.value())
        .catchError((Object _) {})
        .then((_) async {
          // Read before replacing _writes, avoiding a read waiting on itself.
          final rows = (_cache ?? const <Map<String, dynamic>>[])
              .map((row) => Map<String, dynamic>.from(row))
              .toList();
          change(rows);
          final directory = await root();
          await directory.create(recursive: true);
          final index = File(p.join(directory.path, 'index.json'));
          final stage = File(
            p.join(directory.path, '.index-${++_sequence}.tmp'),
          );
          try {
            await stage.writeAsString(
              jsonEncode({
                'format': 'breeze-local-video',
                'version': 1,
                'resources': [
                  for (final row in rows)
                    {...row}
                      ..remove('available')
                      ..remove('filePresent'),
                ],
              }),
              flush: true,
            );
            await stage.rename(index.path);
          } finally {
            if (await stage.exists()) await stage.delete();
          }
          _cachedRoot = directory.path;
          _cache = rows;
          changes.value++;
        });
    _writes = job;
    void releaseWrite() {
      if (identical(_writes, job)) _writes = null;
    }

    job.then(
      (_) => releaseWrite(),
      onError: (Object _, StackTrace _) => releaseWrite(),
    );
    return job;
  }

  static Future<void> saved({
    required String resourceId,
    required int bytes,
    required String source,
    required Uri video,
    required String title,
    required String quality,
    required String taskKey,
    String? cover,
    int? durationMs,
    String? sourceDuration,
  }) => runExclusiveStorageOperation(
    () => _saved(
      resourceId: resourceId,
      bytes: bytes,
      source: source,
      video: video,
      title: title,
      quality: quality,
      taskKey: taskKey,
      cover: cover,
      durationMs: durationMs,
      sourceDuration: sourceDuration,
    ),
  );

  static Future<bool> commitStaged({
    required String stageId,
    required String resourceId,
    required int bytes,
    required String source,
    required Uri video,
    required String title,
    required String quality,
    required String taskKey,
    String? cover,
    int? durationMs,
    String? sourceDuration,
    bool Function()? cancelled,
    String? expectedVersion,
  }) => runExclusiveStorageOperation(() async {
    if (cancelled?.call() == true) return false;
    if (identity(source, video, quality) != resourceId) {
      throw const FormatException('Wrong resource identity');
    }
    final stage = await stagedFile(stageId);
    if (!await _validMp4(stage, bytes)) {
      throw const FormatException('Incomplete local video stage');
    }
    // Reject unknown/future index data before touching the stable resource.
    final resources = await _readNow(fresh: true);
    if (expectedVersion != null) {
      final current = resources
          .where((row) => row['resourceId'] == resourceId)
          .firstOrNull;
      final version = current == null ? '' : resourceVersion(current);
      if (expectedVersion != version) return false;
    }
    if (cancelled?.call() == true) return false;
    final target = await file(resourceId);
    final directoryExisted = await target.parent.exists();
    await target.parent.create(recursive: true);
    if (cancelled?.call() == true) {
      if (!directoryExisted && await target.parent.list().isEmpty) {
        await target.parent.delete();
      }
      return false;
    }
    // Keep only the file being replaced until its new index entry is durable.
    // A failed index commit must not destroy an existing playable download.
    final previous = File(
      p.join(target.parent.path, '.replace-$stageId-${++_sequence}.mp4'),
    );
    if (await FileSystemEntity.type(previous.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw const FileSystemException('Video replacement path already exists');
    }
    var retained = false, installed = false, committed = false;
    try {
      if (await target.exists()) {
        await target.rename(previous.path);
        retained = true;
      }
      if (cancelled?.call() == true) return false;
      await stage.rename(target.path);
      installed = true;
      if (cancelled?.call() == true) return false;
      await _saved(
        resourceId: resourceId,
        bytes: bytes,
        source: source,
        video: video,
        title: title,
        quality: quality,
        taskKey: taskKey,
        cover: cover,
        durationMs: durationMs,
        sourceDuration: sourceDuration,
      );
      committed = true;
      return true;
    } finally {
      if (!committed) {
        try {
          if (installed) await target.rename(stage.path);
        } finally {
          if (retained) await previous.rename(target.path);
          invalidate();
        }
      } else if (retained) {
        try {
          await previous.delete();
        } on FileSystemException {
          // Index and stable file are already committed. Cleanup failure must
          // not turn that successful download into a reported failed transfer.
        }
      }
    }
  });

  static Future<void> _saved({
    required String resourceId,
    required int bytes,
    required String source,
    required Uri video,
    required String title,
    required String quality,
    required String taskKey,
    String? cover,
    int? durationMs,
    String? sourceDuration,
  }) async {
    if (identity(source, video, quality) != resourceId || bytes <= 12) {
      throw const FormatException('Local video identity did not match');
    }
    final media = await file(resourceId);
    if (!await _validMp4(media, bytes)) {
      throw const FormatException('Local video was not committed');
    }
    await _readNow(fresh: true);
    final image = cover == null ? null : Uri.tryParse(cover);
    await _change((rows) {
      rows.removeWhere((row) => row['resourceId'] == resourceId);
      rows.insert(0, {
        'resourceId': resourceId,
        'source': source,
        'url': resourcePage(video).toString(),
        'title': title,
        'quality': quality,
        'bytes': bytes,
        'taskKey': taskKey,
        'showTask': true,
        'at': DateTime.now().toUtc().millisecondsSinceEpoch,
        'available': true,
        'filePresent': true,
        if (durationMs != null && durationMs > 0) 'durationMs': durationMs,
        if (sourceDuration != null &&
            sourceDuration.trim().isNotEmpty &&
            sourceDuration.length <= 300)
          'sourceDuration': sourceDuration,
        if (image?.scheme == 'https' &&
            image?.host.isNotEmpty == true &&
            image?.userInfo.isEmpty == true &&
            image?.hasQuery == false)
          'cover': cover,
      });
    });
    await VideoDownloadedDetails.retainForResource({
      'resourceId': resourceId,
      'source': source,
      'url': resourcePage(video).toString(),
      'title': title,
      'quality': quality,
      'durationMs': durationMs,
      'sourceDuration': sourceDuration,
      'cover': cover,
    }).catchError((Object _) {});
  }

  static Future<void> hideTasks(Set<String> keys) =>
      runExclusiveStorageOperation(() async {
        if (keys.isEmpty) return;
        final current = await _readNow();
        if (current.any((row) => keys.contains(row['taskKey'])))
          await _change((rows) {
            for (final row in rows) {
              if (keys.contains(row['taskKey'])) row['showTask'] = false;
            }
          });
        await VideoHlsAssets.hideTasks(keys);
      });

  static Future<void> remove(String id) =>
      runExclusiveStorageOperation(() async {
        if (!validId(id)) throw const FormatException('Invalid local video ID');
        if (_readers[id]?.isNotEmpty == true || _treeWriters.isNotEmpty) {
          throw const ManagedVideoResourceBusy();
        }
        if (!tryHold(id)) throw StateError('Local video is in use');
        try {
          final rows = await _readAllNow(fresh: true);
          final row = rows.where((row) => row['resourceId'] == id).firstOrNull;
          if (row?['format'] == 'hls') {
            await VideoHlsAssets.delete(row!);
            await VideoDownloadedDetails.removeResource(
              id,
            ).catchError((Object _) {});
            return;
          }
          final media = await file(id);
          if (await media.exists()) await media.delete();
          await _change((rows) {
            for (final row in rows) {
              if (row['resourceId'] == id) {
                row['available'] = false;
                row['filePresent'] = false;
              }
            }
          });
          await VideoDownloadedDetails.removeResource(
            id,
          ).catchError((Object _) {});
        } finally {
          release(id);
          invalidate();
        }
      }).then((_) => afterVideoRemoval(id));

  static Future<T> withRemovalLease<T>(
    String id,
    Future<T> Function(ManagedVideoRemovalLease lease) action,
  ) async {
    LocalImportRecovery.requireRecovered();
    if (!validId(id)) throw const FormatException('Invalid local video ID');
    if (!tryHold(id)) throw const ManagedVideoResourceBusy();
    ManagedVideoRemovalLease? lease;
    try {
      return await runExclusiveStorageOperation(() async {
        final rows = await _readAllNow(fresh: true);
        final row = rows.where((row) => row['resourceId'] == id).firstOrNull;
        lease = ManagedVideoRemovalLease._(
          id,
          row == null ? null : Map<String, dynamic>.from(row),
        );
        return action(lease!);
      });
    } finally {
      lease?._active = false;
      release(id);
      invalidate();
    }
  }

  /// Binding of a validated index row, before adding display-only fields.
  static String resourceVersion(Map<String, dynamic> row) => sha256
      .convert(
        utf8.encode(
          jsonEncode({
            for (final key in (row.keys.toList()..sort()))
              if (key != 'available' && key != 'filePresent') key: row[key],
          }),
        ),
      )
      .toString();

  /// Read-only version for a confirmation. Physical absence is not a new
  /// generation; persisted public metadata/taskKey/time are the version.
  static Future<ManagedVideoRemovalVersion> bindRemovalVersion(
    String id, {
    String? expectedResourceVersion,
  }) async {
    if (!validId(id)) throw const FormatException('Invalid local video ID');
    final row = await runExclusiveStorageOperation(() async {
      await flush();
      final rows = await _readDirectory(
        await root(),
        onlyId: id,
        verifyMedia: false,
      );
      if (rows.isNotEmpty) return rows.single;
      // HLS has a separate native metadata index. Do not enumerate it for a
      // known MP4 identity; HLS/MP4 IDs include their distinct format scope.
      return (await VideoHlsAssets.read())
          .where((row) => row['resourceId'] == id)
          .firstOrNull;
    });
    final version = row == null ? null : resourceVersion(row);
    if (expectedResourceVersion != null && version != expectedResourceVersion) {
      throw StateError('Video resource changed before confirmation');
    }
    return ManagedVideoRemovalVersion._(id, version);
  }

  static Future<void> _removeBoundResource(
    ManagedVideoRemovalLease lease, {
    required bool allowUnindexedOwnedFile,
  }) async {
    if (!lease._active || !_inUse.contains(lease.resourceId)) {
      throw StateError('Video removal lease has ended');
    }
    if (lease._removed) return;
    final rows = await _readAllNow(fresh: true);
    final row = rows
        .where((row) => row['resourceId'] == lease.resourceId)
        .firstOrNull;
    if (row != null &&
        (lease._snapshot == null ||
            resourceVersion(row) != resourceVersion(lease._snapshot))) {
      throw StateError('Video resource changed during removal');
    }
    // An external-only acknowledgment is never authority to delete a file.
    if (row == null && !allowUnindexedOwnedFile) return;
    if (row?['format'] == 'hls') {
      await VideoHlsAssets.delete(row!);
      await VideoDownloadedDetails.removeResource(
        lease.resourceId,
      ).catchError((Object _) {});
      lease._removed = true;
      return;
    }
    final media = await file(lease.resourceId);
    if (await media.exists()) await media.delete();
    await _change(
      (rows) =>
          rows.removeWhere((row) => row['resourceId'] == lease.resourceId),
    );
    await VideoDownloadedDetails.removeResource(
      lease.resourceId,
    ).catchError((Object _) {});
    lease._removed = true;
  }
}

/// Source-scoped download removal. The shared index is replaced atomically and
/// its old bytes remain staged until the enclosing recovery journal commits.
class PluginVideoRemovalPlan {
  PluginVideoRemovalPlan._(
    this.source,
    this._directory,
    this._indexBefore,
    this._indexAfter,
    this.moves,
    this.resourceCount,
    this.fileCount,
    this._lease,
    this._hlsRows,
    this._recovery,
  );
  final String source;
  final Directory _directory;
  final String? _indexBefore;
  final List<int> _indexAfter;
  final List<({String original, String staged, String? replacementSha256})>
  moves;
  final int resourceCount, fileCount;
  ManagedVideoTreeLease? _lease;
  final List<Map<String, dynamic>> _hlsRows;
  final LocalImportRecovery? _recovery;
  String? _hlsRemoval;
  bool _staged = false, _finished = false;

  static Future<PluginVideoRemovalPlan> prepare(
    String source, {
    LocalImportRecovery? recovery,
  }) async {
    if (source.trim().isEmpty || source.length > 200) {
      throw const FormatException('Invalid plugin identity');
    }
    if (VideoLocalResources._inUse.isNotEmpty) {
      throw const ManagedVideoResourceBusy();
    }
    final ManagedVideoTreeLease lease;
    if (recovery == null) {
      lease = VideoLocalResources.acquireTreeMutationLease();
    } else {
      if (recovery.journal['phase'] != 'prepared') {
        throw const LocalImportRecoveryFailed();
      }
      VideoLocalResources.requireNoReadLeases();
      if (VideoLocalResources._treeWriters.isNotEmpty) {
        throw const ManagedVideoResourceBusy();
      }
      lease = ManagedVideoTreeLease._();
      VideoLocalResources._treeWriters.add(lease);
    }
    try {
      final rows = await VideoLocalResources._readNow(fresh: true);
      final directory = await VideoLocalResources.root();
      final selected = rows.where((row) => row['source'] == source).toList();
      final hlsRows = (await VideoHlsAssets.read())
          .where((row) => row['source'] == source)
          .toList();
      final index = File(p.join(directory.path, 'index.json'));
      final before = await index.exists() ? await index.readAsString() : null;
      final next = utf8.encode(
        jsonEncode({
          'format': 'breeze-local-video',
          'version': 1,
          'resources': [
            for (final row in rows.where((row) => row['source'] != source))
              {...row}
                ..remove('available')
                ..remove('filePresent'),
          ],
        }),
      );
      final token =
          '${DateTime.now().microsecondsSinceEpoch}-${VideoLocalResources._sequence++}';
      final moves =
          <({String original, String staged, String? replacementSha256})>[];
      for (final id
          in selected.map((row) => row['resourceId'] as String).toSet()) {
        final media = await VideoLocalResources.file(id);
        if (await media.exists()) {
          moves.add((
            original: media.path,
            staged: '${media.path}.breeze-removal-$token',
            replacementSha256: null,
          ));
        }
      }
      final files = moves.length;
      if (selected.isNotEmpty && before != null) {
        moves.add((
          original: index.path,
          staged: '${index.path}.breeze-removal-$token',
          replacementSha256: sha256.convert(next).toString(),
        ));
      }
      return PluginVideoRemovalPlan._(
        source,
        directory,
        before,
        next,
        List.unmodifiable(moves),
        selected.length + hlsRows.length,
        files + hlsRows.where((row) => row['filePresent'] == true).length,
        lease,
        hlsRows,
        recovery,
      );
    } catch (_) {
      lease.release();
      rethrow;
    }
  }

  Future<void> _check() async {
    final index = File(p.join(_directory.path, 'index.json'));
    final current = await index.exists() ? await index.readAsString() : null;
    if (current != _indexBefore) {
      throw StateError('Local video index changed before removal');
    }
    for (final move in moves) {
      if (await FileSystemEntity.type(move.original, followLinks: false) !=
              FileSystemEntityType.file ||
          await FileSystemEntity.type(move.staged, followLinks: false) !=
              FileSystemEntityType.notFound) {
        throw const FormatException('Local video files changed before removal');
      }
    }
  }

  Future<void> stage({
    required Future<void> Function(
      List<({String original, String staged, String? replacementSha256})>,
    )
    beforeFileMoves,
  }) async {
    if (_staged || _finished) {
      throw StateError('Video removal plan already used');
    }
    if (moves.isEmpty) {
      _hlsRemoval = await VideoHlsAssets.stageRemoval(source, _hlsRows);
      _staged = true;
      if (_hlsRemoval != null)
        await _recovery?.beforeNativeHlsRemoval(_hlsRemoval!);
      return;
    }
    await _check();
    await beforeFileMoves(moves);
    await _check();
    _hlsRemoval = await VideoHlsAssets.stageRemoval(source, _hlsRows);
    _staged = true;
    if (_hlsRemoval != null)
      await _recovery?.beforeNativeHlsRemoval(_hlsRemoval!);
    final replacement = moves
        .where((move) => move.replacementSha256 != null)
        .single;
    final candidate = File('${replacement.staged}-replacement');
    if (await FileSystemEntity.type(candidate.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw const FormatException('Unexpected video replacement stage');
    }
    await candidate.writeAsBytes(_indexAfter, flush: true);
    for (final move in moves) {
      await File(move.original).rename(move.staged);
    }
    await candidate.rename(replacement.original);
    VideoLocalResources.invalidate();
  }

  Future<void> applyPreferences({
    required Future<void> Function(Map<String, dynamic>) beforeWrite,
  }) async {
    await VideoDownloadedDetails.removeSource(source, beforeWrite: beforeWrite);
    // Device transfer logs are separate from external Files acknowledgments.
    final prefs = await SharedPreferences.getInstance();
    final original = prefs.getString('breeze.local.video.download-tasks.v1');
    if (original == null) return;
    final rows = jsonDecode(original);
    if (rows is! List) throw const FormatException('Invalid local video tasks');
    final kept = rows
        .where((row) => row is! Map || row['source'] != source)
        .toList();
    if (kept.length == rows.length) return;
    final next = jsonEncode(kept);
    await beforeWrite({'breeze.local.video.download-tasks.v1': next});
    if (prefs.getString('breeze.local.video.download-tasks.v1') != original) {
      throw StateError('Local video tasks changed before removal');
    }
    if (!await prefs.setString('breeze.local.video.download-tasks.v1', next)) {
      throw StateError('Local video tasks were not saved');
    }
  }

  Future<void> rollback() async {
    if (!_staged || _finished) return;
    for (final move in moves.reversed) {
      if (move.replacementSha256 != null) {
        final candidate = File('${move.staged}-replacement');
        final kind = await FileSystemEntity.type(
          candidate.path,
          followLinks: false,
        );
        if (kind != FileSystemEntityType.notFound &&
            kind != FileSystemEntityType.file) {
          throw const FormatException('Unsafe video rollback stage');
        }
        if (kind == FileSystemEntityType.file) await candidate.delete();
      }
      final stagedKind = await FileSystemEntity.type(
        move.staged,
        followLinks: false,
      );
      if (stagedKind == FileSystemEntityType.notFound) continue;
      if (stagedKind != FileSystemEntityType.file) {
        throw const FormatException('Unsafe video rollback stage');
      }
      final originalKind = await FileSystemEntity.type(
        move.original,
        followLinks: false,
      );
      if (originalKind != FileSystemEntityType.notFound) {
        if (originalKind != FileSystemEntityType.file ||
            move.replacementSha256 == null ||
            (await sha256.bind(File(move.original).openRead()).first)
                    .toString() !=
                move.replacementSha256) {
          throw StateError('Local video rollback needs recovery');
        }
        await File(move.original).delete();
      }
      await File(move.staged).rename(move.original);
    }
    if (_hlsRemoval != null) {
      await VideoHlsAssets.finishRemoval(_hlsRemoval!, committed: false);
      _hlsRemoval = null;
    }
    _staged = false;
    VideoLocalResources.invalidate();
  }

  Future<bool> finish({required bool committed}) async {
    if (_finished) return true;
    try {
      if (!committed) {
        await rollback();
      } else {
        if (_hlsRemoval != null) {
          await VideoHlsAssets.finishRemoval(_hlsRemoval!, committed: true);
          _hlsRemoval = null;
        }
        for (final move in moves) {
          if (move.replacementSha256 != null &&
              (await FileSystemEntity.type(move.original, followLinks: false) !=
                      FileSystemEntityType.file ||
                  (await sha256.bind(File(move.original).openRead()).first)
                          .toString() !=
                      move.replacementSha256)) {
            return false;
          }
        }
        for (final move in moves) {
          final file = File(move.staged);
          final kind = await FileSystemEntity.type(
            file.path,
            followLinks: false,
          );
          if (kind != FileSystemEntityType.notFound &&
              kind != FileSystemEntityType.file) {
            return false;
          }
          if (kind == FileSystemEntityType.file) await file.delete();
        }
      }
      if (committed) {
        await VideoDownloadedDetails.removeSourceResources(
          source,
        ).catchError((Object _) {});
      }
      _finished = true;
      return true;
    } catch (_) {
      return false;
    } finally {
      _lease?.release();
      _lease = null;
      VideoLocalResources.invalidate();
    }
  }
}
