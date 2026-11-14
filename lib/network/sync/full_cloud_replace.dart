import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/network/sync/appearance_image_sync.dart';
import 'package:zephyr/network/sync/appearance_resource_paths.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/backup_protection_adapter.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/network/sync/sync_archive_adapter.dart';
import 'package:zephyr/network/sync/sync_archive_context.dart';
import 'package:zephyr/network/sync/sync_payload_compatibility.dart';
import 'package:zephyr/network/sync/sync_service.dart';
import 'package:zephyr/network/sync/video_library_sync.dart';
import 'package:zephyr/network/sync/chapter_progress_sync.dart';
import 'package:zephyr/service/reader/comic_chapter_reading_progress.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/service/local_appearance_images.dart';

String _hash(List<int> bytes) => sha256.convert(bytes).toString();
Object? _canonical(Object? value) => value is Map
    ? {
        for (final key in (value.keys.cast<String>().toList()..sort()))
          key: _canonical(value[key]),
      }
    : value is List
    ? value.map(_canonical).toList()
    : value;
String _structured(Object? value) =>
    _hash(utf8.encode(jsonEncode(_canonical(value))));
String get _root => SyncArchiveContext.currentRoot;

class FullCloudReplaceStale implements Exception {
  const FullCloudReplaceStale();
}

/// A failed write may have reached the server even when its response was lost.
/// Local data is never changed, so a fresh preview can safely begin a retry.
class FullCloudReplaceFailure implements Exception {
  const FullCloudReplaceFailure(this.cause, {required this.mayHaveChanged});
  final Object cause;
  final bool mayHaveChanged;
}

class FullCloudReplaceCount {
  const FullCloudReplaceCount(this.local, this.removed, this.overwritten);
  final int local, removed, overwritten;
}

/// Immutable preview input; file paths/download bytes/local protection switches
/// never enter this object. Test fixtures use the same validators as production.
class FullCloudLocalSnapshot {
  FullCloudLocalSnapshot({
    required Map<String, dynamic> comic,
    required Map<String, dynamic> settings,
    required Map<String, dynamic> video,
    required AppearanceSyncManifest appearance,
    ChapterProgressArchive? chapters,
    Map<String, List<int>> resources = const {},
  }) : chapters = chapters ?? ChapterProgressArchive(),
       comic = Map.unmodifiable(
         jsonDecode(jsonEncode(comic)) as Map<String, dynamic>,
       ),
       settings = Map.unmodifiable(
         jsonDecode(jsonEncode(settings)) as Map<String, dynamic>,
       ),
       video = Map.unmodifiable(
         jsonDecode(jsonEncode(video)) as Map<String, dynamic>,
       ),
       appearance = AppearanceSyncManifest.fromBytes(
         utf8.encode(jsonEncode(appearance.toJson())),
       ),
       resources = Map.unmodifiable({
         for (final e in resources.entries)
           e.key: List<int>.unmodifiable(e.value),
       });
  final Map<String, dynamic> comic, settings, video;
  final ChapterProgressArchive chapters;
  final AppearanceSyncManifest appearance;
  final Map<String, List<int>> resources;

  String get fingerprint {
    final settingValues = jsonDecode(jsonEncode(settings)) as Map;
    settingValues.remove('syncTime');
    for (final block in (settingValues['blocks'] as Map).values) {
      (block as Map).remove('updatedAt');
    }
    final videoValues = jsonDecode(jsonEncode(video)) as Map;
    // A read-only observation of an unjournalled preference can assign a fresh
    // observation clock. Compare its intent rather than that synthetic clock.
    final portable = videoValues['portable'];
    if (portable is Map && portable['entries'] is Map) {
      for (final row in (portable['entries'] as Map).values) {
        (row as Map).remove('updatedAt');
      }
    }
    videoValues.remove('portableSha256');
    return _structured([
      comic,
      settingValues,
      videoValues,
      utf8.decode(chapters.encode()),
      appearance.toJson(),
      {for (final e in resources.entries) e.key: _hash(e.value)},
    ]);
  }

  static Future<FullCloudLocalSnapshot> capture(
    GlobalSettingState state, {
    VideoLibraryStore? library,
    LocalAppearanceImages? images,
  }) async {
    final comic = ComicSyncCore.captureData();
    final settings = await captureFullCloudSettings(state);
    final raw = (await (library ?? VideoLibraryStore.shared).read()).toJson();
    final portable = (await PortablePreferences.capture(
      persist: false,
    )).toJson();
    final video = <String, dynamic>{
      'format': 'BreezeVideoLibrary',
      'version': 1,
      'snapshot': raw,
      'sha256': _hash(utf8.encode(jsonEncode(raw))),
      'portable': portable,
      'portableSha256': _hash(utf8.encode(jsonEncode(portable))),
    };
    final snapshot = await (images ?? LocalAppearanceImages.instance)
        .snapshotForSync();
    try {
      final records = {
        for (final e in snapshot.records.entries)
          if (validAppearanceSyncKey(e.key)) e.key: e.value,
      };
      final alias = snapshot.records[LocalAppearanceImages.collectionCoverKey];
      final selection = AppearanceGallerySelection(
        key: alias == null || alias.deleted
            ? null
            : LocalAppearanceImages.collectionImageKey(alias.digest),
        modifiedAt: alias?.modifiedAt ?? 1,
      );
      final resources = <String, List<int>>{};
      var total = 0;
      for (final row in records.values) {
        if (row.deleted || resources.containsKey(row.digest)) continue;
        final bytes = await snapshot.readBytes(row.key);
        total += bytes.length;
        if (total > _Budget.limit)
          throw const FormatException('Artwork snapshot too large');
        resources[row.digest] = bytes;
      }
      return FullCloudLocalSnapshot(
        comic: comic,
        settings: settings,
        video: video,
        chapters: await ComicChapterReadingProgress.instance.capture(),
        appearance: AppearanceSyncManifest(records, selection: selection),
        resources: resources,
      );
    } finally {
      await snapshot.dispose();
    }
  }
}

class FullCloudReplacePlan {
  FullCloudReplacePlan._(
    this._owner,
    this._local,
    this._current,
    this._legacy,
    this.counts,
  );
  final FullCloudReplaceService _owner;
  final FullCloudLocalSnapshot _local;
  final _ArchiveView _current, _legacy;
  final Map<String, FullCloudReplaceCount> counts;
  bool _used = false;
  int get currentFiles => _current.digests.length;
  int get legacyFiles => _legacy.digests.length;
}

/// An explicit destructive path, never a mode of daily synchronization. Preview
/// and commit each hold the existing non-reentrant local queue once, without
/// holding it while the user reads or cancels either UI confirmation.
class FullCloudReplaceService {
  FullCloudReplaceService({
    required this.adapter,
    required this.captureLocal,
    this.guard,
    this.comicCodec = const ComicSyncCodec(),
    this.settingsCodec = const SettingsSyncCodec(),
    this.videoCodec = const VideoLibrarySyncCodec(),
  });
  factory FullCloudReplaceService.fromState(
    GlobalSettingState Function() state,
  ) {
    final initial = state();
    final initialConfig = jsonEncode(initial.syncSetting.toJson());
    final adapter = createSyncArchiveAdapter(initial);
    if (adapter == null) throw StateError('Sync is not configured');
    return FullCloudReplaceService(
      adapter: adapter,
      captureLocal: () => FullCloudLocalSnapshot.capture(state()),
      guard: () {
        if (jsonEncode(state().syncSetting.toJson()) != initialConfig) {
          throw const FullCloudReplaceStale();
        }
      },
    );
  }
  final ScopedSyncArchiveAdapter adapter;
  final Future<FullCloudLocalSnapshot> Function() captureLocal;
  final void Function()? guard;
  final ComicSyncCodec comicCodec;
  final SettingsSyncCodec settingsCodec;
  final VideoLibrarySyncCodec videoCodec;
  Map<String, String> _pending = {};
  String get _pendingKey => 'sync.full-replace.pending.v1.${adapter.identity}';

  Future<void> _loadPending() async {
    final raw = (await SharedPreferences.getInstance()).getString(_pendingKey);
    if (raw == null) {
      _pending = {};
    } else {
      final map = jsonDecode(raw);
      if (map is! Map ||
          map.length > 1000 ||
          map.entries.any(
            (e) =>
                e.key is! String ||
                !isManagedSyncArchivePath(e.key as String) ||
                e.value is! String ||
                !RegExp(r'^[a-f0-9]{64}$').hasMatch(e.value as String),
          )) {
        throw const FormatException(
          'Invalid full replacement recovery metadata',
        );
      }
      _pending = Map<String, String>.from(map);
    }
    final transport = adapter.transport;
    if (transport is BackupProtectionSyncAdapter)
      transport.useFullReplaceStaging(_pending.keys.toSet());
  }

  Future<void> _savePending(Map<String, String> next) async {
    if (next.length > 1000)
      throw const FormatException('Too many pending cloud files');
    if (!await (await SharedPreferences.getInstance()).setString(
      _pendingKey,
      jsonEncode(next),
    )) {
      throw StateError('Replacement recovery metadata was not saved');
    }
    _pending = next;
    final transport = adapter.transport;
    if (transport is BackupProtectionSyncAdapter)
      transport.useFullReplaceStaging(next.keys.toSet(), reset: false);
  }

  Future<FullCloudReplacePlan> preview() => runExclusiveStorageOperation(
    () async {
      guard?.call();
      await _loadPending();
      final local = await captureLocal();
      final budget = _Budget();
      final current = await _read(adapter, budget);
      final legacyReader = adapter.legacyReader;
      final legacy = legacyReader == null
          ? _ArchiveView()
          : await _read(legacyReader, budget);
      if (legacy.digests.isNotEmpty &&
          legacyReader?.supportsFullLegacyReplace != true) {
        throw StateError('Transport cannot replace legacy managed files');
      }
      // Validate the complete local payload before offering confirmation too.
      final localInventory = _Inventory();
      final localBudget = _Budget();
      final chapterBytes = local.chapters.encode();
      localBudget.add(chapterBytes.length);
      localInventory.addChapters(ChapterProgressArchive.decode(chapterBytes));
      for (final bytes in local.resources.values) {
        localBudget.add(bytes.length);
      }
      for (final entry in {
        'comic': local.comic,
        'settings': local.settings,
        'video': local.video,
      }.entries) {
        final bytes = await _encode(
          entry.key,
          utf8.encode(jsonEncode(entry.value)),
        );
        localBudget.add(bytes.length);
        await _validate(entry.key, '${entry.key}_1.bin', bytes, localInventory);
      }
      localInventory.add('appearance', local.appearance.toJson());
      _verifyResources(local.appearance, local.resources);
      final remoteInventory = current.inventory.union(legacy.inventory);
      guard?.call();
      return FullCloudReplacePlan._(
        this,
        local,
        current,
        legacy,
        Map.unmodifiable(localInventory.compare(remoteInventory)),
      );
    },
  );

  Future<void> commit(
    FullCloudReplacePlan plan,
  ) => runExclusiveStorageOperation(() async {
    if (!identical(plan._owner, this) || plan._used)
      throw const FullCloudReplaceStale();
    plan._used = true;
    var changed = false;
    try {
      guard?.call();
      if ((await captureLocal()).fingerprint != plan._local.fingerprint)
        throw const FullCloudReplaceStale();
      final current = Map<String, String>.of(plan._current.digests);
      final legacy = Map<String, String>.of(plan._legacy.digests);
      await _check(adapter, current);
      if (adapter.legacyReader != null)
        await _check(adapter.legacyReader!, legacy);
      // Unique publication names leave the old committed snapshots readable
      // until the replacement set and both MD5 commit markers are verified.
      final random = Random.secure();
      final nonce = _hash(
        List<int>.generate(32, (_) => random.nextInt(256)),
      ).substring(0, 32);
      var stamp = DateTime.now().millisecondsSinceEpoch;
      for (final path in current.keys) {
        final match = RegExp(
          r'^(?:comic|settings)_(\d+)\.bin$',
        ).firstMatch(path.split('/').last);
        if (match != null) stamp = max(stamp, int.parse(match[1]!) + 1);
      }
      final local = plan._local;
      final outgoing = <String, List<int>>{
        for (final entry in local.resources.entries)
          '$_root/appearance_resource_${entry.key}.bin': entry.value,
        '$_root/comic_$stamp.bin': await _encode(
          'comic',
          utf8.encode(jsonEncode(local.comic)),
        ),
        '$_root/settings_$stamp.bin': await _encode(
          'settings',
          utf8.encode(jsonEncode(local.settings)),
        ),
        '$_root/video_library_$nonce.bin': await _encode(
          'video',
          utf8.encode(jsonEncode(local.video)),
        ),
        if (local.chapters.rows.isNotEmpty)
          '$_root/chapter_progress_v1_$nonce.bin': await videoCodec.encode(
            local.chapters.encode(),
          ),
      };
      final artwork = utf8.encode(jsonEncode(local.appearance.toJson()));
      outgoing['$_root/appearance_${nonce}_${_hash(artwork)}.bin'] = artwork;
      guard?.call();
      await _check(adapter, current);
      if (adapter.legacyReader != null)
        await _check(adapter.legacyReader!, legacy);
      // First possible remote write. ensureRemoteReady also rechecks the existing
      // protection profile; preview never calls it or writes control information.
      // Persist only publication names/digests before a write can be interrupted.
      // An incomplete PUT remains identifiable after restart; preview never
      // repairs it or writes this journal.
      await _savePending({
        for (final e in _pending.entries)
          if (current.containsKey(e.key)) e.key: e.value,
        for (final e in outgoing.entries)
          if (!current.containsKey(e.key)) e.key: _hash(e.value),
        for (final kind in ['comic', 'settings'])
          '$_root/$kind.md5': _hash(
            utf8.encode(
              ComicSyncCore.calculateMd5(
                outgoing['$_root/${kind}_$stamp.bin']!,
              ),
            ),
          ),
      });
      changed = true;
      await adapter.ensureRemoteReady();
      for (final entry in outgoing.entries) {
        guard?.call();
        final existing = current[entry.key];
        final outgoingDigest = _hash(entry.value);
        if (existing == outgoingDigest) continue;
        if (existing != null) {
          // Content-addressed image names are stable across retries. Only our
          // certified interrupted publication may be repaired at that name;
          // all other same-name content changes remain stale.
          if (_pending[entry.key] != outgoingDigest)
            throw const FullCloudReplaceStale();
          await _checkFile(adapter, entry.key, existing);
        }
        await adapter.uploadRemoteFile(entry.key, entry.value);
        current[entry.key] = outgoingDigest;
        await _checkFile(adapter, entry.key, current[entry.key]!);
      }
      // A concurrent mutation detected here stops before any old data is removed.
      await _check(adapter, current);
      if (adapter.legacyReader != null)
        await _check(adapter.legacyReader!, legacy);
      for (final kind in ['comic', 'settings']) {
        final path = '$_root/$kind.md5';
        final old = current[path];
        if (old != null) await _checkFile(adapter, path, old);
        final bytes = utf8.encode(
          ComicSyncCore.calculateMd5(outgoing['$_root/${kind}_$stamp.bin']!),
        );
        await adapter.uploadRemoteFile(path, bytes);
        current[path] = _hash(bytes);
        await _checkFile(adapter, path, current[path]!);
      }
      final keep = {
        ...outgoing.keys,
        '$_root/comic.md5',
        '$_root/settings.md5',
      };
      await _check(adapter, current);
      if (adapter.legacyReader != null)
        await _check(adapter.legacyReader!, legacy);
      // A known file is checked immediately before deletion. Listings are checked
      // again for late files. This is optimistic protection, not cross-device CAS.
      for (final path
          in current.keys.where((p) => !keep.contains(p)).toList()) {
        await _checkListing(adapter, current);
        await _checkFile(adapter, path, current[path]!);
        guard?.call();
        await adapter.deleteRemoteFiles([path]);
        current.remove(path);
      }
      final oldReader = adapter.legacyReader;
      if (oldReader != null) {
        for (final path in legacy.keys.toList()) {
          await _checkListing(oldReader, legacy);
          await _checkFile(oldReader, path, legacy[path]!);
          guard?.call();
          // Legacy cleanup obeys the same current cloud protection guard.
          await adapter.ensureRemoteReady();
          await oldReader.deleteLegacyFilesForFullReplace([path]);
          legacy.remove(path);
        }
      }
      await _check(adapter, current);
      if (oldReader != null) await _check(oldReader, legacy);
      // Read the final archive through the same production format validators.
      await _read(adapter, _Budget());
      guard?.call();
      if (!await (await SharedPreferences.getInstance()).remove(_pendingKey)) {
        throw StateError('Replacement recovery metadata cleanup failed');
      }
      _pending = {};
      final transport = adapter.transport;
      if (transport is BackupProtectionSyncAdapter)
        transport.useFullReplaceStaging({});
    } catch (error) {
      if (!changed && error is FullCloudReplaceStale) rethrow;
      throw FullCloudReplaceFailure(error, mayHaveChanged: changed);
    } finally {
      adapter.invalidate();
    }
  });

  Future<List<int>> _encode(String kind, List<int> bytes) => switch (kind) {
    'comic' => comicCodec.encode(bytes),
    'settings' => settingsCodec.encode(bytes),
    'video' => videoCodec.encode(bytes),
    _ => Future.value(bytes),
  };

  Future<void> _validate(
    String kind,
    String name,
    List<int> bytes,
    _Inventory inventory,
  ) async {
    final path = '$_root/$name';
    final single = _ReadOnlySnapshot(path, bytes);
    List<int> decoded;
    switch (kind) {
      case 'comic':
        await readComicArchiveData(single, codec: comicCodec);
        decoded = await comicCodec.decode(bytes);
      case 'settings':
        await readSettingsArchiveData(single, codec: settingsCodec);
        decoded = await settingsCodec.decode(bytes);
      case 'video':
        // Video reader only accepts a per-device canonical filename.
        await VideoLibrarySync.readArchive(
          _ReadOnlySnapshot(
            '$_root/video_library_00000000000000000000000000000000.bin',
            bytes,
          ),
          codec: videoCodec,
        );
        decoded = await videoCodec.decode(bytes);
      case 'chapter':
        inventory.addChapters(
          await ChapterProgressSync.decode(bytes, videoCodec),
        );
        return;
      default:
        final manifest = AppearanceSyncManifest.fromBytes(bytes);
        inventory.add('appearance', manifest.toJson());
        return;
    }
    if (decoded.length > _Budget.fileLimit)
      throw const FormatException('Cloud snapshot too large');
    inventory.add(
      kind,
      Map<String, dynamic>.from(jsonDecode(utf8.decode(decoded)) as Map),
    );
  }

  Future<_ArchiveView> _read(
    ScopedSyncArchiveAdapter reader,
    _Budget budget,
  ) async {
    final view = _ArchiveView();
    final paths = await _listing(reader);
    final resources = <String, List<int>>{};
    final manifests = <AppearanceSyncManifest>[];
    for (final path in paths) {
      guard?.call();
      final transport = reader.transport;
      final bytes = transport is BackupProtectionSyncAdapter
          ? await transport.readFreshForFullReplace(path)
          : await reader.downloadRemoteFile(path);
      budget.add(bytes.length);
      view.digests[path] = _hash(bytes);
      final name = path.split('/').last;
      if (!reader.context.legacy &&
          _pending.containsKey(path) &&
          _pending[path] != view.digests[path]) {
        // A partial PUT may not decode at all. A decodable structured payload
        // still passes the full forward-format gate; a valid future format is
        // never excused merely because its path was locally journalled.
        if (name.endsWith('.md5') || appearanceResourceName.hasMatch(name))
          continue;
        try {
          final decoded = name.startsWith('comic_')
              ? await comicCodec.decode(bytes)
              : name.startsWith('settings_')
              ? await settingsCodec.decode(bytes)
              : name.startsWith('video_library_') ||
                    ChapterProgressSync.name.hasMatch(name)
              ? await videoCodec.decode(bytes)
              : bytes;
          jsonDecode(utf8.decode(decoded));
        } catch (_) {
          continue;
        }
      }
      if (name.endsWith('.md5')) {
        if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(utf8.decode(bytes).trim())) {
          throw const FormatException('Invalid cloud commit marker');
        }
      } else if (appearanceResourceName.hasMatch(name)) {
        final digest = name.substring(
          'appearance_resource_'.length,
          name.length - 4,
        );
        if (_hash(bytes) != digest)
          throw const FormatException('Cloud image integrity failed');
        resources[digest] = bytes;
      } else {
        final kind = name.startsWith('video_library_')
            ? 'video'
            : ChapterProgressSync.name.hasMatch(name)
            ? 'chapter'
            : name.split('_').first;
        if (kind == 'appearance') {
          final expected = appearanceManifestDigest(path);
          if (expected != null && _hash(bytes) != expected)
            throw const FormatException('Incomplete cloud image manifest');
          manifests.add(AppearanceSyncManifest.fromBytes(bytes));
        }
        await _validate(kind, name, bytes, view.inventory);
      }
    }
    // This explicit path validates every actual snapshot independently. A prior
    // partial replacement may leave a known-format orphan head/snapshot; unlike
    // normal sync it can still preview and replace that exact remaining range.
    final incomplete = reader.context.legacy
        ? <String>{}
        : {
            for (final e in _pending.entries)
              if (appearanceResourceName.hasMatch(e.key.split('/').last) &&
                  view.digests[e.key] != e.value)
                e.key
                    .split('/')
                    .last
                    .substring(
                      'appearance_resource_'.length,
                      e.key.split('/').last.length - 4,
                    ),
          };
    for (final manifest in manifests) {
      _verifyResources(manifest, resources, incomplete: incomplete);
    }
    return view;
  }

  Future<void> _check(
    ScopedSyncArchiveAdapter reader,
    Map<String, String> expected,
  ) async {
    guard?.call();
    await _checkListing(reader, expected);
    for (final entry in expected.entries) {
      await _checkFile(reader, entry.key, entry.value);
    }
    await _checkListing(reader, expected);
  }

  Future<void> _checkListing(
    ScopedSyncArchiveAdapter reader,
    Map<String, String> expected,
  ) async {
    final transport = reader.transport;
    if (transport is BackupProtectionSyncAdapter)
      await transport.guardFullReplace();
    final actual = await _listing(reader);
    final wanted = expected.keys.toList()..sort();
    if (jsonEncode(actual) != jsonEncode(wanted))
      throw const FullCloudReplaceStale();
  }

  Future<void> _checkFile(
    ScopedSyncArchiveAdapter reader,
    String path,
    String digest,
  ) async {
    final transport = reader.transport;
    final bytes = transport is BackupProtectionSyncAdapter
        ? await transport.readFreshForFullReplace(path)
        : await reader.downloadRemoteFile(path);
    if (_hash(bytes) != digest) throw const FullCloudReplaceStale();
  }
}

Future<List<String>> _listing(ScopedSyncArchiveAdapter reader) async {
  final paths = await reader.listRemoteDataFiles();
  if (paths.any(
    (p) =>
        !isManagedSyncArchivePath(p) &&
        RegExp(
          r'^(?:comic|settings|video_library|appearance|chapter_progress)_',
        ).hasMatch(p.split('/').last),
  )) {
    throw const SyncCompatibilityException();
  }
  final managed = paths.where(isManagedSyncArchivePath).toSet().toList()
    ..sort();
  if (managed.length > 1000)
    throw const FormatException('Too many cloud files');
  return managed;
}

void _verifyResources(
  AppearanceSyncManifest manifest,
  Map<String, List<int>> resources, {
  Set<String> incomplete = const {},
}) {
  for (final row in manifest.records.values) {
    if (row.deleted || incomplete.contains(row.digest)) continue;
    final bytes = resources[row.digest];
    if (bytes == null ||
        bytes.length != row.size ||
        _hash(bytes) != row.digest) {
      throw const FormatException('Cloud artwork is unavailable');
    }
  }
  final selected = manifest.selection?.key;
  if (selected != null &&
      (manifest.records[selected] == null ||
          manifest.records[selected]!.deleted)) {
    throw const FormatException('Selected artwork is unavailable');
  }
}

class _Budget {
  static const limit = 128 * 1024 * 1024, fileLimit = 32 * 1024 * 1024;
  int total = 0;
  void add(int size) {
    total += size;
    if (size > fileLimit || total > limit)
      throw const FormatException('Cloud snapshot too large');
  }
}

class _ArchiveView {
  final digests = <String, String>{};
  final inventory = _Inventory();
}

/// Keys/values are digested before comparison; the preview exposes only counts.
/// Historical snapshots contribute a union so old-only records are not hidden.
class _Inventory {
  final values = <String, Map<String, Set<String>>>{
    for (final kind in ['comic', 'video', 'plugins', 'preferences', 'images'])
      kind: {},
  };
  void put(String kind, String key, Object? value) =>
      (values[kind]![key] ??= {}).add(_structured(value));
  void addChapters(ChapterProgressArchive archive) {
    for (final row in archive.rows.entries) {
      final (source, work, chapter) = row.key;
      final progress = row.value.progress;
      if (progress == null) continue;
      put('comic', 'chapter-progress:${jsonEncode([source, work, chapter])}', [
        progress.pageIndex,
        progress.pageCount,
        progress.completed,
        row.value.at,
      ]);
    }
  }

  void add(String kind, Map<String, dynamic> raw) {
    if (kind == 'comic') {
      for (final field in [
        'favorites',
        'histories',
        'follows',
        'folders',
        'links',
        'readPreferences',
      ]) {
        for (final row in (raw[field] as List? ?? [])) {
          final map = row as Map;
          put(
            'comic',
            '$field:${map['uniqueKey'] ?? map['comicUniqueKey'] ?? _structured(map)}',
            map,
          );
        }
      }
    } else if (kind == 'video') {
      final snapshot = raw['snapshot'] as Map;
      for (final field in ['favorites', 'folders', 'memberships', 'tracking']) {
        for (final e in (snapshot[field] as Map? ?? {}).entries) {
          put('video', '$field:${e.key}', e.value);
        }
      }
      final entries = (raw['portable'] as Map?)?['entries'] as Map? ?? {};
      for (final e in entries.entries) {
        put('preferences', 'portable:${e.key}', e.value);
      }
    } else if (kind == 'settings') {
      for (final field in ['pluginInfos', 'pluginConfigs']) {
        for (final row in raw[field] as List? ?? []) {
          final map = row as Map;
          put('plugins', '$field:${map['uuid'] ?? map['name']}', map);
        }
      }
      for (final e in (raw['blocks'] as Map? ?? {}).entries) {
        if (e.key != 'plugins')
          put('preferences', 'settings:${e.key}', (e.value as Map)['data']);
      }
    } else if (kind == 'appearance') {
      for (final e in (raw['entries'] as Map).entries) {
        put('images', '${e.key}', e.value);
      }
      if (raw.containsKey('selection'))
        put('preferences', 'image-selection', raw['selection']);
    }
  }

  _Inventory union(_Inventory other) {
    final result = _Inventory();
    for (final kind in values.keys) {
      for (final source in [values[kind]!, other.values[kind]!]) {
        for (final e in source.entries) {
          (result.values[kind]![e.key] ??= {}).addAll(e.value);
        }
      }
    }
    return result;
  }

  Map<String, FullCloudReplaceCount> compare(_Inventory remote) => {
    for (final kind in values.keys)
      kind: FullCloudReplaceCount(
        values[kind]!.length,
        remote.values[kind]!.keys
            .where((key) => !values[kind]!.containsKey(key))
            .length,
        remote.values[kind]!.entries
            .where(
              (e) =>
                  values[kind]!.containsKey(e.key) &&
                  !e.value.every(values[kind]![e.key]!.contains),
            )
            .length,
      ),
  };
}

class _ReadOnlySnapshot implements ComicSyncRemoteAdapter {
  _ReadOnlySnapshot(this.path, this.bytes);
  final String path;
  final List<int> bytes;
  @override
  Future<void> testConnection() async {}
  @override
  Future<void> ensureRemoteReady() async =>
      throw StateError('Read-only preview');
  @override
  Future<List<String>> listRemoteDataFiles() async => [path];
  @override
  Future<List<int>> downloadRemoteFile(String request) async =>
      request.endsWith('.md5')
      ? utf8.encode(ComicSyncCore.calculateMd5(bytes))
      : bytes;
  @override
  Future<String> downloadRemoteMd5() async => ComicSyncCore.calculateMd5(bytes);
  @override
  Future<void> uploadRemoteMd5(String value) async =>
      throw StateError('Read-only preview');
  @override
  Future<void> uploadRemoteFile(
    String path,
    List<int> bytes, {
    String contentType = 'application/octet-stream',
  }) async => throw StateError('Read-only preview');
  @override
  Future<void> deleteRemoteFiles(List<String> paths) async =>
      throw StateError('Read-only preview');
}
