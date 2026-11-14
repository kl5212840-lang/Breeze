import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/chapter_progress_sync.dart';
import 'package:zephyr/network/sync/appearance_image_sync.dart';
import 'package:zephyr/network/sync/plugin_config_merge.dart';
import 'package:zephyr/network/sync/plugin_portable_scope.dart';
import 'package:zephyr/network/sync/plugin_record_scope.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/network/sync/sync_archive_adapter.dart';
import 'package:zephyr/network/sync/sync_service.dart';
import 'package:zephyr/network/sync/video_library_sync.dart';
import 'package:zephyr/page/video/video_library_store.dart';

/// No local state changed. Earlier remote writes may already have committed.
class CloudPluginPurgeFailure implements Exception {
  const CloudPluginPurgeFailure(
    this.cause, {
    required this.mayHaveChanged,
    this.currentArchiveCompleted = false,
    this.legacyArchiveCompleted = false,
  });
  final Object cause;
  final bool mayHaveChanged;
  final bool currentArchiveCompleted, legacyArchiveCompleted;
}

/// Rewrites only certified source-owned fields; shared folders/global settings
/// and every other source keep their original values. Inputs must be validated.
Map<String, dynamic> removePluginFromCloudPayload(
  String kind,
  Map<String, dynamic> input,
  String source,
) {
  final out = Map<String, dynamic>.from(jsonDecode(jsonEncode(input)) as Map);
  if (kind == 'comic') {
    final owned = comicPluginRecords(out, source);
    final keys = {
      for (final field in [
        'favorites',
        'histories',
        'follows',
        'readPreferences',
      ])
        for (final row in owned[field] as List) (row as Map)['uniqueKey'],
    };
    for (final field in [
      'favorites',
      'histories',
      'follows',
      'readPreferences',
    ]) {
      if (out[field] is List) {
        out[field] = (out[field] as List)
            .where((row) => (row as Map)['source'] != source)
            .toList();
      }
    }
    if (out['links'] is List) {
      out['links'] = (out['links'] as List)
          .where((row) => !keys.contains((row as Map)['comicUniqueKey']))
          .toList();
    }
  } else if (kind == 'settings') {
    final names = pluginConfigNamesForSource(source);
    void remove(Map block) {
      if (block['pluginInfos'] is List) {
        block['pluginInfos'] = (block['pluginInfos'] as List)
            .where((row) => (row as Map)['uuid']?.toString().trim() != source)
            .toList();
      }
      if (block['pluginConfigs'] is List) {
        block['pluginConfigs'] = (block['pluginConfigs'] as List)
            .where(
              (row) => !names.contains((row as Map)['name']?.toString().trim()),
            )
            .toList();
      }
    }

    remove(out);
    final blocks = out['blocks'];
    if (blocks is Map && blocks['plugins'] is Map) {
      final data = (blocks['plugins'] as Map)['data'];
      if (data is Map) remove(data);
    }
  } else if (kind == 'appearance') {
    final manifest = AppearanceSyncManifest.fromBytes(
      utf8.encode(jsonEncode(out)),
    );
    return AppearanceSyncManifest({
      for (final e in manifest.records.entries)
        if (appearanceImageSource(e.key) != source) e.key: e.value,
    }, selection: manifest.selection).toJson();
  } else if (kind == 'video') {
    final original = VideoLibrarySnapshot.fromJson(out['snapshot']);
    final owned = videoPluginRecords(original, source);
    final snapshot = out['snapshot'] as Map;
    final removals = {
      'favorites': owned.favorites.keys,
      'folders': owned.folders.keys,
      'memberships': owned.memberships.keys,
      'tracking': owned.tracking.keys,
    };
    for (final entry in removals.entries) {
      if (snapshot[entry.key] is Map) {
        for (final key in entry.value) {
          (snapshot[entry.key] as Map).remove(key);
        }
      }
    }
    out['sha256'] = sha256
        .convert(utf8.encode(jsonEncode(snapshot)))
        .toString();
    if (out.containsKey('portable')) {
      final portable = PortablePreferencesSnapshot.fromJson(out['portable']);
      final ownership = pluginPortableScopes(portable.entries);
      out['portable'] = PortablePreferencesSnapshot({
        for (final entry in portable.entries.entries)
          if (ownership[entry.key]?.source != source) entry.key: entry.value,
      }).toJson();
      out['portableSha256'] = sha256
          .convert(utf8.encode(jsonEncode(out['portable'])))
          .toString();
    }
  } else if (kind == 'chapter') {
    out['rows'] = (out['rows'] as List)
        .where((row) => (row as List).first != source)
        .toList();
  } else {
    throw ArgumentError.value(kind, 'kind');
  }
  return out;
}

String? _kind(String path) {
  final name = path.split('/').last;
  if (appearanceManifestName.hasMatch(name)) return 'appearance';
  if (RegExp(r'^comic_\d+\.bin$').hasMatch(name)) return 'comic';
  if (RegExp(r'^settings_\d+\.bin$').hasMatch(name)) return 'settings';
  if (RegExp(r'^video_library_[a-f0-9]{32}\.bin$').hasMatch(name))
    return 'video';
  if (ChapterProgressSync.name.hasMatch(name)) return 'chapter';
  return null;
}

/// Caller owns the existing storage queue/source stop. Both archives and every
/// historical/device snapshot are fully planned before either archive is written.
Future<void> purgeCloudPluginAccountData(
  ComicSyncRemoteAdapter adapter,
  String source, {
  ComicSyncCodec comicCodec = const ComicSyncCodec(),
  SettingsSyncCodec settingsCodec = const SettingsSyncCodec(),
  VideoLibrarySyncCodec videoCodec = const VideoLibrarySyncCodec(),
  void Function()? guard,
}) async {
  var changed = false;
  var currentComplete = false, legacyComplete = false;
  try {
    if (source.trim() != source ||
        source.isEmpty ||
        source.length > 200 ||
        RegExp(r'[/\\\x00-\x1f]').hasMatch(source)) {
      throw const FormatException('Invalid plugin identity');
    }
    final budget = _PurgeBudget();
    Future<_PurgePlan> prepare(
      ComicSyncRemoteAdapter reader,
      Future<void> Function(String, List<int>) write,
    ) => _PurgePlan.prepare(
      reader: reader,
      write: write,
      source: source,
      guard: guard,
      comicCodec: comicCodec,
      settingsCodec: settingsCodec,
      videoCodec: videoCodec,
      budget: budget,
    );
    guard?.call();
    final current = await prepare(
      adapter,
      (path, data) => adapter.uploadRemoteFile(path, data),
    );
    final legacyReader = adapter is ScopedSyncArchiveAdapter
        ? adapter.legacyReader
        : null;
    final legacy = legacyReader == null
        ? null
        : await prepare(
            legacyReader,
            legacyReader.rewriteLegacySnapshotForPluginPurge,
          );
    // Reject a missing capability before current data can change.
    if (legacy != null &&
        legacy.outputs.isNotEmpty &&
        legacyReader!.transport is! LegacyPluginPurgeTransport) {
      throw StateError(
        'Transport does not support explicit legacy plugin purge',
      );
    }
    await current.checkOriginals();
    await legacy?.checkOriginals();
    void changing() {
      guard?.call();
      changed = true;
    }

    await current.commit(changing);
    await current.verify();
    currentComplete = true;
    if (legacy != null) {
      await legacy.commit(changing);
      await legacy.verify();
    }
    legacyComplete = true;
    // Only candidate blobs proven owned by removed refs are collected; shared
    // content stays if ANY retained manifest still references it.
    await current.verify();
    await legacy?.verify();
    final referenced = {
      ...current.retainedDigests,
      ...?legacy?.retainedDigests,
    };
    // Re-list immediately before collection: a newly published OTHER-source
    // reference must protect a formerly source-owned shared blob too.
    for (final path in await adapter.listRemoteDataFiles()) {
      if (!appearanceManifestName.hasMatch(path.split('/').last)) continue;
      final bytes = await adapter.downloadRemoteFile(path);
      final expected = appearanceManifestDigest(path);
      if (expected != null && sha256.convert(bytes).toString() != expected)
        continue;
      final manifest = AppearanceSyncManifest.fromBytes(bytes);
      if (manifest.records.keys.any(
        (key) => appearanceImageSource(key) == source,
      ))
        throw StateError('Cloud changed; retry');
      referenced.addAll(
        manifest.records.values.where((r) => !r.deleted).map((r) => r.digest),
      );
    }
    for (final digest in {
      ...current.removedDigests,
      ...?legacy?.removedDigests,
    }.difference(referenced)) {
      final path =
          '${ComicSyncCore.syncRemoteRootName}/appearance_resource_$digest.bin';
      if (!current.resourcePaths.contains(path)) continue;
      changing();
      await adapter.deleteRemoteFiles([path]);
      if ((await adapter.listRemoteDataFiles()).contains(path))
        throw StateError('Artwork deletion not confirmed');
    }
    // Recheck both after the second commit; no source can hide in a late file.
    currentComplete = false;
    await current.verify();
    currentComplete = true;
    legacyComplete = false;
    await legacy?.verify();
    legacyComplete = true;
    guard?.call();
  } catch (error) {
    throw CloudPluginPurgeFailure(
      error,
      mayHaveChanged: changed,
      currentArchiveCompleted: currentComplete,
      legacyArchiveCompleted: legacyComplete,
    );
  }
}

class _PurgeBudget {
  int bytes = 0, files = 0;
}

class _PurgePlan {
  _PurgePlan({
    required this.reader,
    required this.write,
    required this.source,
    required this.comicCodec,
    required this.settingsCodec,
    required this.videoCodec,
    required this.guard,
  });
  final ComicSyncRemoteAdapter reader;
  final Future<void> Function(String, List<int>) write;
  final String source;
  final ComicSyncCodec comicCodec;
  final SettingsSyncCodec settingsCodec;
  final VideoLibrarySyncCodec videoCodec;
  final void Function()? guard;
  final originals = <String, String>{}, commitDigests = <String, String>{};
  final outputs = <String, List<int>>{};
  final heads = <String, List<int>>{};
  final paths = <String>[];
  final removedDigests = <String>{},
      retainedDigests = <String>{},
      resourcePaths = <String>{};

  Future<List<int>> _decode(String kind, List<int> bytes) =>
      kind == 'appearance'
      ? Future.value(bytes)
      : kind == 'comic'
      ? comicCodec.decode(bytes)
      : kind == 'settings'
      ? settingsCodec.decode(bytes)
      : videoCodec.decode(bytes);
  Future<List<int>> _encode(String kind, List<int> bytes) =>
      kind == 'appearance'
      ? Future.value(bytes)
      : kind == 'comic'
      ? comicCodec.encode(bytes)
      : kind == 'settings'
      ? settingsCodec.encode(bytes)
      : videoCodec.encode(bytes);
  Future<void> _validate(String path, List<int> bytes) async {
    final kind = _kind(path)!;
    if (kind == 'appearance') {
      final digest = appearanceManifestDigest(path);
      if (digest != null && sha256.convert(bytes).toString() != digest) return;
      AppearanceSyncManifest.fromBytes(bytes);
      return;
    }
    final single = _SingleSnapshot(path, bytes);
    if (kind == 'comic') {
      await readComicArchiveData(single, codec: comicCodec);
    } else if (kind == 'settings') {
      await readSettingsArchiveData(single, codec: settingsCodec);
    } else if (kind == 'chapter') {
      await ChapterProgressSync.decode(bytes, videoCodec);
    } else {
      await VideoLibrarySync.readArchive(single, codec: videoCodec);
    }
  }

  static List<String> _managedPaths(List<String> listing) {
    if (listing.any(
      (path) =>
          path.endsWith('.bin') &&
          _kind(path) == null &&
          !appearanceResourceName.hasMatch(path.split('/').last),
    )) {
      throw const FormatException('Unknown cloud snapshot family');
    }
    final paths = listing.where((p) => _kind(p) != null).toList()..sort();
    if (paths.length > 200)
      throw const FormatException('Too many cloud snapshots');
    return paths;
  }

  static Future<_PurgePlan> prepare({
    required ComicSyncRemoteAdapter reader,
    required Future<void> Function(String, List<int>) write,
    required String source,
    required ComicSyncCodec comicCodec,
    required SettingsSyncCodec settingsCodec,
    required VideoLibrarySyncCodec videoCodec,
    required _PurgeBudget budget,
    required void Function()? guard,
  }) async {
    final plan = _PurgePlan(
      reader: reader,
      write: write,
      source: source,
      comicCodec: comicCodec,
      settingsCodec: settingsCodec,
      videoCodec: videoCodec,
      guard: guard,
    );
    await preflightSyncRound(
      reader,
      comicCodec: comicCodec,
      settingsCodec: settingsCodec,
      videoCodec: videoCodec,
    );
    final listing = await reader.listRemoteDataFiles();
    plan.paths.addAll(_managedPaths(listing));
    if (reader is ScopedSyncArchiveAdapter &&
        reader.context.legacy &&
        plan.paths.any((path) => _kind(path) == 'appearance')) {
      throw const FormatException('Artwork is not a legacy archive feature');
    }
    plan.resourcePaths.addAll(
      listing.where((p) => appearanceResourceName.hasMatch(p.split('/').last)),
    );
    budget.files += plan.paths.length;
    if (budget.files > 200)
      throw const FormatException('Too many cloud snapshots');
    for (final path in plan.paths) {
      guard?.call();
      final bytes = await reader.downloadRemoteFile(path);
      budget.bytes += bytes.length;
      if (bytes.length > 32 * 1024 * 1024 || budget.bytes > 64 * 1024 * 1024) {
        throw const FormatException('Cloud purge exceeds snapshot limit');
      }
      plan.originals[path] = sha256.convert(bytes).toString();
      plan.commitDigests[path] = ComicSyncCore.calculateMd5(bytes);
      await plan._validate(path, bytes);
      final kind = _kind(path)!;
      if (kind == 'appearance' &&
          appearanceManifestDigest(path) != null &&
          sha256.convert(bytes).toString() != appearanceManifestDigest(path))
        continue;
      final raw = await plan._readPayload(kind, bytes);
      final output = removePluginFromCloudPayload(kind, raw, source);
      if (kind == 'appearance') {
        final before = AppearanceSyncManifest.fromBytes(bytes);
        final after = AppearanceSyncManifest.fromBytes(
          utf8.encode(jsonEncode(output)),
        );
        plan.removedDigests.addAll(
          before.records.values
              .where(
                (r) => appearanceImageSource(r.key) == source && !r.deleted,
              )
              .map((r) => r.digest),
        );
        plan.retainedDigests.addAll(
          after.records.values.where((r) => !r.deleted).map((r) => r.digest),
        );
        for (final record in before.records.values.where((r) => !r.deleted)) {
          final blobPath =
              '${ComicSyncCore.syncRemoteRootName}/appearance_resource_${record.digest}.bin';
          final blob = await reader.downloadRemoteFile(blobPath);
          if (blob.length != record.size ||
              sha256.convert(blob).toString() != record.digest)
            throw const FormatException('Artwork integrity failure');
        }
      }
      if (jsonEncode(raw) != jsonEncode(output)) {
        plan.outputs[path] = await plan._encode(
          kind,
          utf8.encode(jsonEncode(output)),
        );
      }
    }
    // Commit-marker validity is also checked in preparation, before any writes.
    for (final kind in ['comic', 'settings']) {
      final candidates = plan.paths.where((p) => _kind(p) == kind).toList();
      if (candidates.isEmpty) continue;
      final head = '${ComicSyncCore.syncRemoteRootName}/$kind.md5';
      final bytes = await reader.downloadRemoteFile(head);
      final digest = utf8.decode(bytes).trim();
      if (!candidates.any((p) => plan.commitDigests[p] == digest)) {
        throw const FormatException('Cloud commit marker has no snapshot');
      }
      plan.heads[kind] = bytes;
    }
    return plan;
  }

  Future<Map<String, dynamic>> _readPayload(
    String kind,
    List<int> bytes,
  ) async {
    final decoded = await _decode(kind, bytes);
    if (decoded.length > 32 * 1024 * 1024)
      throw const FormatException('Cloud snapshot too large');
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(decoded)) as Map);
  }

  Future<void> _unchanged(String path, String digest) async {
    guard?.call();
    final now = await reader.downloadRemoteFile(path);
    if (sha256.convert(now).toString() != digest)
      throw StateError('Cloud changed; retry');
  }

  Future<void> checkOriginals() async {
    final listing = _managedPaths(await reader.listRemoteDataFiles());
    if (jsonEncode(listing) != jsonEncode(paths))
      throw StateError('Cloud changed; retry');
    for (final entry in originals.entries) {
      await _unchanged(entry.key, entry.value);
    }
    for (final entry in heads.entries) {
      await _unchanged(
        '${ComicSyncCore.syncRemoteRootName}/${entry.key}.md5',
        sha256.convert(entry.value).toString(),
      );
    }
  }

  Future<void> commit(void Function() changing) async {
    await checkOriginals();
    for (final kind in ['comic', 'settings']) {
      final oldHead = heads[kind];
      if (oldHead == null) continue;
      final candidates = paths.where((p) => _kind(p) == kind).toList();
      final active = candidates.firstWhere(
        (p) => commitDigests[p] == utf8.decode(oldHead).trim(),
      );
      final bytes = outputs[active];
      if (bytes == null) continue;
      final latest = candidates
          .map(
            (p) =>
                int.parse(p.split('/').last.split('_').last.split('.').first),
          )
          .reduce((a, b) => a > b ? a : b);
      final now = DateTime.now().millisecondsSinceEpoch;
      final path =
          '${ComicSyncCore.syncRemoteRootName}/${kind}_${now > latest ? now : latest + 1}.bin';
      changing();
      await write(path, bytes);
      await _unchanged(path, sha256.convert(bytes).toString());
      final head = '${ComicSyncCore.syncRemoteRootName}/$kind.md5';
      await _unchanged(head, sha256.convert(oldHead).toString());
      changing();
      await write(head, utf8.encode(ComicSyncCore.calculateMd5(bytes)));
    }
    for (final entry in outputs.entries) {
      await _unchanged(entry.key, originals[entry.key]!);
      changing();
      if (_kind(entry.key) == 'appearance' &&
          appearanceManifestDigest(entry.key) != null) {
        if (reader is ScopedSyncArchiveAdapter &&
            (reader as ScopedSyncArchiveAdapter).context.legacy)
          throw const FormatException(
            'Artwork is not a legacy archive feature',
          );
        final name = entry.key.split('/').last;
        final device = name.split('_')[1];
        final target =
            '${ComicSyncCore.syncRemoteRootName}/appearance_${device}_${sha256.convert(entry.value)}.bin';
        await write(target, entry.value);
        await _unchanged(target, sha256.convert(entry.value).toString());
        await reader.deleteRemoteFiles([entry.key]);
      } else {
        await write(entry.key, entry.value);
        await _unchanged(entry.key, sha256.convert(entry.value).toString());
      }
    }
  }

  Future<void> verify() async {
    await preflightSyncRound(
      reader,
      comicCodec: comicCodec,
      settingsCodec: settingsCodec,
      videoCodec: videoCodec,
    );
    for (final path in _managedPaths(await reader.listRemoteDataFiles())) {
      guard?.call();
      final bytes = await reader.downloadRemoteFile(path);
      if (bytes.length > 32 * 1024 * 1024)
        throw const FormatException('Cloud snapshot too large');
      await _validate(path, bytes);
      if (_kind(path) == 'appearance' &&
          appearanceManifestDigest(path) != null &&
          sha256.convert(bytes).toString() != appearanceManifestDigest(path))
        continue;
      final raw = await _readPayload(_kind(path)!, bytes);
      if (jsonEncode(raw) !=
          jsonEncode(removePluginFromCloudPayload(_kind(path)!, raw, source))) {
        throw StateError('Cloud purge is not complete');
      }
    }
  }
}

/// Every candidate uses production validators, never live transport writes.
class _SingleSnapshot implements ComicSyncRemoteAdapter {
  _SingleSnapshot(this.path, this.bytes);
  final String path;
  final List<int> bytes;
  @override
  Future<void> testConnection() async {}
  @override
  Future<void> ensureRemoteReady() async {}
  @override
  Future<List<String>> listRemoteDataFiles() async => [path];
  @override
  Future<String> downloadRemoteMd5() async => ComicSyncCore.calculateMd5(bytes);
  @override
  Future<List<int>> downloadRemoteFile(String request) async =>
      request.endsWith('.md5')
      ? utf8.encode(ComicSyncCore.calculateMd5(bytes))
      : bytes;
  @override
  Future<void> uploadRemoteMd5(String value) async =>
      throw StateError('Read only');
  @override
  Future<void> uploadRemoteFile(
    String path,
    List<int> bytes, {
    String contentType = 'application/octet-stream',
  }) async => throw StateError('Read only');
  @override
  Future<void> deleteRemoteFiles(List<String> paths) async =>
      throw StateError('Read only');
}
