import 'package:zephyr/network/sync/sync_direction.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/backup_protection_adapter.dart';
import 'package:zephyr/network/sync/sync_archive_adapter.dart';
import 'package:zephyr/network/sync/appearance_resource_paths.dart';
export 'package:zephyr/network/sync/appearance_resource_paths.dart';
import 'package:zephyr/network/sync/sync_device_id.dart';
import 'package:zephyr/network/sync/sync_plugin_participation.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/service/folder_cover_identity.dart';
import 'package:zephyr/service/backup_security/backup_security.dart';

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);
String? appearanceImageSource(String key) {
  if (!key.startsWith('profile:') && !key.startsWith('plugin-icon:'))
    return null;
  final source = key.substring(key.indexOf(':') + 1);
  return _uuid.hasMatch(source) ? source : null;
}

bool validAppearanceSyncKey(String key) =>
    FolderCoverIdentity.valid(key) ||
    appearanceImageSource(key) != null ||
    RegExp(r'^collection-cover:[0-9a-f]{64}$').hasMatch(key);

class AppearanceGalleryCapacityExceeded implements Exception {
  AppearanceGalleryCapacityExceeded(
    Iterable<LocalAppearanceSyncRecord> candidates,
  ) : candidates = List.unmodifiable(candidates);
  final List<LocalAppearanceSyncRecord> candidates;
}

class AppearanceGalleryResolutionCancelled implements Exception {}

class AppearanceGalleryResolutionStale implements Exception {}

class AppearanceGalleryPreviewUnavailable implements Exception {
  const AppearanceGalleryPreviewUnavailable(this.cause);
  final Object cause;
}

class AppearanceGalleryConflict {
  AppearanceGalleryConflict({
    required Iterable<LocalAppearanceSyncRecord> candidates,
    required Map<String, Uint8List> bytesByDigest,
    required Set<String> localKeys,
    required Set<String> cloudKeys,
  }) : candidates = List.unmodifiable(candidates),
       bytesByDigest = Map.unmodifiable(bytesByDigest),
       localKeys = Set.unmodifiable(localKeys),
       cloudKeys = Set.unmodifiable(cloudKeys);
  final List<LocalAppearanceSyncRecord> candidates;
  final Map<String, Uint8List> bytesByDigest;
  final Set<String> localKeys, cloudKeys;
}

typedef AppearanceGalleryResolver =
    Future<Set<String>?> Function(AppearanceGalleryConflict conflict);

/// The cloud and local filesystem cannot commit atomically. Preserve the
/// confirmed boundary so callers can offer retry without claiming rollback.
class AppearanceSyncIncomplete implements Exception {
  const AppearanceSyncIncomplete({
    required this.cloudManifestVerified,
    required this.localApplied,
    required this.cause,
    this.recoveryError,
  });
  final bool cloudManifestVerified;
  final bool localApplied;
  final Object cause;
  final Object? recoveryError;
}

class AppearanceSyncManifest {
  AppearanceSyncManifest(this.records, {this.selection});
  final Map<String, LocalAppearanceSyncRecord> records;
  final AppearanceGallerySelection? selection;
  Map<String, dynamic> toJson() => {
    'format': 'BreezeAppearanceImages',
    'version': records.keys.any(FolderCoverIdentity.valid) ? 3 : 2,
    if (selection != null) 'selection': selection!.toJson(),
    'entries': {
      for (final key in (records.keys.toList()..sort()))
        key: records[key]!.changeJson,
    },
  };
  factory AppearanceSyncManifest.fromBytes(List<int> bytes) {
    if (bytes.length > 256 * 1024)
      throw const FormatException('Artwork manifest too large');
    final raw = jsonDecode(utf8.decode(bytes));
    if (raw is! Map ||
        raw['format'] != 'BreezeAppearanceImages' ||
        raw['version'] is! int ||
        !const {1, 2, 3}.contains(raw['version']) ||
        raw.keys.any(
          (k) => !{'format', 'version', 'entries', 'selection'}.contains(k),
        ) ||
        raw['entries'] is! Map ||
        (raw['entries'] as Map).length > 256)
      throw const FormatException('Unsupported artwork manifest');
    final records = <String, LocalAppearanceSyncRecord>{};
    for (final e in (raw['entries'] as Map).entries) {
      final v = e.value;
      if (e.key is! String ||
          !validAppearanceSyncKey(e.key as String) ||
          (FolderCoverIdentity.valid(e.key as String) && raw['version'] != 3) ||
          v is! Map ||
          v.keys.toSet().difference({
            'modifiedAt',
            'deleted',
            'digest',
            'size',
          }).isNotEmpty ||
          v['modifiedAt'] is! int ||
          (v['modifiedAt'] as int) < 1 ||
          v['deleted'] is! bool ||
          v['digest'] is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(v['digest'] as String) ||
          (e.key.toString().startsWith('collection-cover:') &&
              e.key.toString().substring('collection-cover:'.length) !=
                  v['digest']) ||
          v['size'] is! int ||
          (v['size'] as int) < 1 ||
          (v['size'] as int) > LocalAppearanceImages.maximumInputBytes) {
        throw const FormatException('Invalid artwork reference');
      }
      records[e.key as String] = LocalAppearanceSyncRecord(
        key: e.key as String,
        digest: v['digest'] as String,
        size: v['size'] as int,
        modifiedAt: v['modifiedAt'] as int,
        deleted: v['deleted'] as bool,
      );
    }
    final selection = raw.containsKey('selection')
        ? AppearanceGallerySelection.fromJson(raw['selection'])
        : null;
    return AppearanceSyncManifest(records, selection: selection);
  }
}

/// Small manifests participate in the round's existing forward-version gate.
/// Immutable blob bytes remain lazy and are authenticated before use/reference.
Future<bool> preflightAppearanceImages(ComicSyncRemoteAdapter adapter) async {
  final paths = (await adapter.listRemoteDataFiles())
      .where((p) => appearanceManifestName.hasMatch(p.split('/').last))
      .toList();
  if (paths.length > 200)
    throw const FormatException('Too many artwork manifests');
  var hasManifest = false;
  for (final path in paths) {
    final bytes = await adapter.downloadRemoteFile(path);
    final expected = appearanceManifestDigest(path);
    if (expected != null && sha256.convert(bytes).toString() != expected)
      continue;
    AppearanceSyncManifest.fromBytes(bytes);
    hasManifest = true;
  }
  return hasManifest;
}

LocalAppearanceSyncRecord _newer(
  LocalAppearanceSyncRecord a,
  LocalAppearanceSyncRecord b,
) {
  if (a.modifiedAt != b.modifiedAt) return a.modifiedAt > b.modifiedAt ? a : b;
  if (a.deleted != b.deleted) return a.deleted ? a : b;
  if (a.digest != b.digest)
    throw const FormatException('Conflicting artwork revisions');
  if (a.size != b.size)
    throw const FormatException('Conflicting artwork sizes');
  return a;
}

/// A normal-sync channel, sharing the caller's queue and installation snapshot.
/// Immutable resources are uploaded/read only when a reference changes or a file
/// needs repair. No image decoding, resizing, external fetching, or absolute
/// file identity is performed by the transport.
Future<void> syncAppearanceImages(
  ComicSyncRemoteAdapter adapter, {
  required SyncPluginParticipation participation,
  required bool includeGlobal,
  required bool includePlugins,
  bool includeFolders = false,
  Future<Set<String>> Function(Iterable<String> candidateKeys)?
  retiredFolderKeys,
  LocalAppearanceImages? images,
  String? deviceId,
  AppearanceGalleryResolver? resolveGalleryConflict,
  Future<void> Function()? beforePublish,
  void Function(int completed, int total)? onUploadProgress,
  void Function(int completed, int total)? onPrepareProgress,
  SyncDirection direction = SyncDirection.merge,
}) async {
  if (direction == SyncDirection.recordsOnly ||
      (!includeGlobal && !includePlugins && !includeFolders)) {
    await beforePublish?.call();
    return;
  }
  final store = images ?? LocalAppearanceImages.instance;
  final snapshot = await store.snapshotForSync();
  LocalAppearanceRestorePlan? plan;
  var cloudManifestVerified = false;
  var localApplied = false;
  try {
    bool participates(String key) {
      if (!validAppearanceSyncKey(key)) return false;
      if (FolderCoverIdentity.valid(key)) return includeFolders;
      final source = appearanceImageSource(key);
      // Installation alone controls artwork participation. Local-only cleanup
      // forgets its change records, so reinstall can import retained cloud
      // artwork without treating device data masks as remote deletions.
      return source == null
          ? includeGlobal
          : includePlugins && participation.sources.contains(source);
    }

    final root = ComicSyncCore.syncRemoteRootName;
    final device = deviceId ?? await ensureSyncDeviceId();
    final ownPrefix =
        '$root/appearance_${sha256.convert(utf8.encode(device)).toString().substring(0, 32)}';
    final listing = await adapter.listRemoteDataFiles();
    final paths =
        listing
            .where((p) => appearanceManifestName.hasMatch(p.split('/').last))
            .toList()
          ..sort();
    if (paths.length > 200)
      throw const FormatException('Too many artwork manifests');
    final remote = <String, LocalAppearanceSyncRecord>{};
    final ownRecords = <String, LocalAppearanceSyncRecord>{};
    AppearanceGallerySelection? remoteSelection, ownSelection;
    final ownComplete = <String, AppearanceSyncManifest>{};
    final ownIncomplete = <String>{};
    final manifestDigests = <String, String>{};
    for (final path in paths) {
      final manifestBytes = await adapter.downloadRemoteFile(path);
      manifestDigests[path] = sha256.convert(manifestBytes).toString();
      final expected = appearanceManifestDigest(path);
      if (expected != null &&
          sha256.convert(manifestBytes).toString() != expected) {
        if (path.startsWith(ownPrefix)) ownIncomplete.add(path);
        continue; // incomplete immutable PUT never replaces earlier refs
      }
      final manifest = AppearanceSyncManifest.fromBytes(manifestBytes);
      remoteSelection = AppearanceGallerySelection.newer(
        remoteSelection,
        manifest.selection,
      );
      if (path.startsWith(ownPrefix)) {
        ownSelection = AppearanceGallerySelection.newer(
          ownSelection,
          manifest.selection,
        );
        ownComplete[path] = manifest;
        for (final e in manifest.records.entries) {
          ownRecords[e.key] = ownRecords.containsKey(e.key)
              ? _newer(ownRecords[e.key]!, e.value)
              : e.value;
        }
      }
      for (final e in manifest.records.entries) {
        remote[e.key] = remote.containsKey(e.key)
            ? _newer(remote[e.key]!, e.value)
            : e.value;
      }
    }
    final merged = {...remote};
    for (final e in snapshot.records.entries) {
      final row = e.value;
      if (!participates(e.key) ||
          row.size < 1 ||
          (!row.deleted && row.file == null))
        continue;
      final cloud = merged[e.key];
      if (direction == SyncDirection.restore && cloud != null) continue;
      merged[e.key] = direction == SyncDirection.upload && cloud != null
          ? LocalAppearanceSyncRecord(
              key: row.key,
              digest: row.digest,
              size: row.size,
              modifiedAt: row.modifiedAt > cloud.modifiedAt
                  ? row.modifiedAt
                  : cloud.modifiedAt + 1,
              deleted: row.deleted,
              file: row.file,
            )
          : cloud == null
          ? row
          : _newer(cloud, row);
    }
    final selected = {
      for (final e in merged.entries)
        if (participates(e.key)) e.key: e.value,
    };
    final localAlias =
        snapshot.records[LocalAppearanceImages.collectionCoverKey];
    final localSelection = localAlias == null
        ? null
        : AppearanceGallerySelection(
            key: localAlias.deleted
                ? null
                : LocalAppearanceImages.collectionImageKey(localAlias.digest),
            modifiedAt: localAlias.modifiedAt,
          );
    var selection = includeGlobal
        ? direction == SyncDirection.restore
              ? remoteSelection ?? localSelection
              : direction == SyncDirection.upload
              ? localSelection ?? remoteSelection
              : AppearanceGallerySelection.newer(
                  remoteSelection,
                  localSelection,
                )
        : ownSelection;
    if (includeGlobal &&
        direction == SyncDirection.upload &&
        localSelection != null &&
        remoteSelection != null &&
        selection!.modifiedAt <= remoteSelection.modifiedAt) {
      selection = AppearanceGallerySelection(
        key: selection.key,
        modifiedAt: remoteSelection.modifiedAt + 1,
      );
    }
    // Missing local files still occupy a library identity. Do not hide them
    // from the capacity check or reinterpret their omission as user deletion.
    final gallery = <String, LocalAppearanceSyncRecord>{
      for (final r in selected.values)
        if (r.key.startsWith('collection-cover:') && !r.deleted) r.key: r,
      for (final r in snapshot.records.values)
        if (includeGlobal &&
            validAppearanceSyncKey(r.key) &&
            r.key.startsWith('collection-cover:') &&
            !r.deleted &&
            !selected.containsKey(r.key))
          r.key: r,
    }.values.toList();
    final bytesByDigest = <String, Uint8List>{};
    var total = 0;
    Future<Uint8List> bytesFor(LocalAppearanceSyncRecord record) async {
      if (bytesByDigest[record.digest] case final Uint8List cached)
        return cached;
      final local = snapshot.records.values
          .where(
            (r) =>
                !r.deleted &&
                r.file != null &&
                r.digest == record.digest &&
                r.size == record.size,
          )
          .firstOrNull;
      final blob = '$root/appearance_resource_${record.digest}.bin';
      Uint8List bytes;
      if (listing.contains(blob)) {
        final raw = await adapter.downloadRemoteFile(
          blob,
        ); // authenticates protected envelope on demand
        bytes = raw is Uint8List ? raw : Uint8List.fromList(raw);
      } else if (local != null) {
        bytes = await snapshot.readBytes(local.key);
      } else {
        throw const FormatException('Referenced artwork is missing');
      }
      if (bytes.length != record.size ||
          sha256.convert(bytes).toString() != record.digest)
        throw const FormatException('Artwork integrity failure');
      total += bytes.length;
      if (total > LocalAppearanceImages.maximumBackupBytes)
        throw const FormatException('Artwork sync exceeds limit');
      bytesByDigest[record.digest] = bytes;
      return bytes;
    }

    if (gallery.length > LocalAppearanceImages.maximumCollectionCovers) {
      final resolver = resolveGalleryConflict;
      if (resolver == null) throw AppearanceGalleryCapacityExceeded(gallery);
      // Read/authenticate every preview before asking the user to make a
      // destructive decision. No local references or remote bytes are written.
      try {
        for (final record in gallery) {
          await bytesFor(record);
        }
      } catch (error, stack) {
        if (error is BackupProtectionException) rethrow;
        Error.throwWithStackTrace(
          AppearanceGalleryPreviewUnavailable(error),
          stack,
        );
      }
      final keep = await resolver(
        AppearanceGalleryConflict(
          candidates: gallery,
          bytesByDigest: bytesByDigest,
          localKeys: {
            for (final r in gallery)
              if (snapshot.records[r.key] != null &&
                  !snapshot.records[r.key]!.deleted)
                r.key,
          },
          cloudKeys: {
            for (final r in gallery)
              if (remote[r.key] != null && !remote[r.key]!.deleted) r.key,
          },
        ),
      );
      if (keep == null) throw AppearanceGalleryResolutionCancelled();
      if (keep.length > LocalAppearanceImages.maximumCollectionCovers ||
          !keep.every((key) => gallery.any((r) => r.key == key))) {
        throw const FormatException('Invalid gallery decision');
      }
      participation.check();
      // Invalidate the protected adapter's authenticated read cache so this
      // second read really binds the decision to the cloud snapshot shown.
      ComicSyncRemoteAdapter transport = adapter;
      while (transport is ScopedSyncArchiveAdapter) {
        transport = transport.transport;
      }
      if (transport is BackupProtectionSyncAdapter)
        transport.invalidateProtection();
      final nowPaths = (await adapter.listRemoteDataFiles())
          .where((p) => appearanceManifestName.hasMatch(p.split('/').last))
          .toSet();
      if (nowPaths.length != manifestDigests.length ||
          !nowPaths.containsAll(manifestDigests.keys))
        throw AppearanceGalleryResolutionStale();
      for (final e in manifestDigests.entries) {
        if (sha256
                .convert(await adapter.downloadRemoteFile(e.key))
                .toString() !=
            e.value)
          throw AppearanceGalleryResolutionStale();
      }
      // Also guard local candidates that were omitted from the resulting apply
      // set. A user edit while the chooser is open invalidates the decision.
      final current = await store.snapshotForSync();
      try {
        final beforeGallery = {
          for (final e in snapshot.records.entries)
            if (e.key.startsWith('collection-cover:'))
              e.key: e.value.changeJson,
        };
        final nowGallery = {
          for (final e in current.records.entries)
            if (e.key.startsWith('collection-cover:'))
              e.key: e.value.changeJson,
        };
        if (jsonEncode(beforeGallery) != jsonEncode(nowGallery))
          throw AppearanceGalleryResolutionStale();
      } finally {
        await current.dispose();
      }
      final latest = gallery.fold<int>(
        0,
        (n, r) => n > r.modifiedAt ? n : r.modifiedAt,
      );
      final time = DateTime.now().toUtc().microsecondsSinceEpoch;
      final revision = time > latest ? time : latest + 1;
      for (final record in gallery) {
        selected[record.key] = keep.contains(record.key)
            ? record
            : LocalAppearanceSyncRecord(
                key: record.key,
                digest: record.digest,
                size: record.size,
                modifiedAt: revision,
                deleted: true,
              );
      }
      bytesByDigest.clear();
      total = 0;
      // A preview was read before user interaction. Revalidate retained bytes
      // after the fresh cloud guard instead of publishing stale cached trust.
      try {
        for (final record in gallery.where((r) => keep.contains(r.key))) {
          await bytesFor(record);
        }
      } catch (error, stack) {
        if (error is BackupProtectionException) rethrow;
        Error.throwWithStackTrace(
          AppearanceGalleryPreviewUnavailable(error),
          stack,
        );
      }
    }
    if (includeGlobal && selection != null) {
      final live =
          selected.values
              .where((r) => r.key.startsWith('collection-cover:') && !r.deleted)
              .toList()
            ..sort((a, b) => a.key.compareTo(b.key));
      if (!live.any((r) => r.key == selection!.key)) {
        final fallback =
            live.where((r) => r.key == localSelection?.key).firstOrNull ??
            live.firstOrNull;
        if (selection.key != fallback?.key) {
          final latest = selected.values
              .where((r) => r.key.startsWith('collection-cover:'))
              .fold<int>(
                selection.modifiedAt,
                (time, r) => time > r.modifiedAt ? time : r.modifiedAt,
              );
          selection = AppearanceGallerySelection(
            key: fallback?.key,
            modifiedAt: latest + 1,
          );
        }
      }
    }
    var outbound = {...ownRecords, ...selected};
    var combinedPayload = utf8.encode(
      jsonEncode(
        AppearanceSyncManifest(outbound, selection: selection).toJson(),
      ),
    );
    // Apply the same limits to our candidate before any PUT; an oversized
    // local/tombstone history must never poison the next round's preflight.
    AppearanceSyncManifest.fromBytes(combinedPayload);
    var combinedPath = '${ownPrefix}_${sha256.convert(combinedPayload)}.bin';
    var changed =
        jsonEncode(
              AppearanceSyncManifest(outbound, selection: selection).toJson(),
            ) !=
            jsonEncode(
              AppearanceSyncManifest(
                ownRecords,
                selection: ownSelection,
              ).toJson(),
            ) ||
        (ownComplete.isNotEmpty && !ownComplete.containsKey(combinedPath));

    final apply = <LocalAppearanceSyncRecord>[];
    bool unchanged(LocalAppearanceSyncRecord record) {
      final before = snapshot.records[record.key];
      return before != null &&
          jsonEncode(before.changeJson) == jsonEncode(record.changeJson) &&
          (record.deleted || before.file != null);
    }

    final preparing = selected.values
        .where((r) => !r.deleted && !unchanged(r))
        .length;
    var prepared = 0;
    onPrepareProgress?.call(prepared, preparing);
    for (final record in selected.values) {
      if (!unchanged(record)) {
        if (!record.deleted) {
          await bytesFor(record);
          onPrepareProgress?.call(++prepared, preparing);
        }
        apply.add(record);
      }
      final previous = ownRecords[record.key];
      if (!record.deleted &&
          (previous == null ||
              previous.digest != record.digest ||
              previous.deleted ||
              !listing.contains(
                '$root/appearance_resource_${record.digest}.bin',
              ))) {
        await bytesFor(record);
      }
    }
    participation.check();
    final applySelection =
        includeGlobal &&
        selection != null &&
        jsonEncode(selection.toJson()) != jsonEncode(localSelection?.toJson());
    if (direction != SyncDirection.upload &&
        (apply.isNotEmpty || applySelection))
      plan = await store.prepareSyncRestore(
        apply,
        bytesByDigest,
        expectedRecords: snapshot.records,
        gallerySelection: applySelection ? selection : null,
      );
    // The archive round may only start mutating its other domains after all
    // artwork validation and user decisions have completed. Cancelling the
    // gallery chooser therefore cancels the entire round before its first PUT
    // or visible local change. Staged files are rolled back if that round fails.
    await beforePublish?.call();
    participation.check();
    final retired = includeFolders && retiredFolderKeys != null
        ? await retiredFolderKeys(
            selected.keys.where(FolderCoverIdentity.valid),
          )
        : <String>{};
    if (retired.any((key) => selected[key]?.deleted == false)) {
      // Records have now committed. Retire only explicit tombstones/identities
      // reported by that merge, never an ID absent from a page or this device.
      await plan?.finish(committed: false);
      plan = null;
      final now = DateTime.now().toUtc().microsecondsSinceEpoch;
      for (final key in retired) {
        final row = selected[key];
        if (row == null || row.deleted) continue;
        selected[key] = LocalAppearanceSyncRecord(
          key: key,
          digest: row.digest,
          size: row.size,
          modifiedAt: now > row.modifiedAt ? now : row.modifiedAt + 1,
          deleted: true,
        );
      }
      outbound = {...ownRecords, ...selected};
      combinedPayload = utf8.encode(
        jsonEncode(
          AppearanceSyncManifest(outbound, selection: selection).toJson(),
        ),
      );
      AppearanceSyncManifest.fromBytes(combinedPayload);
      combinedPath = '${ownPrefix}_${sha256.convert(combinedPayload)}.bin';
      changed = !ownComplete.containsKey(combinedPath);
      if (direction != SyncDirection.upload) {
        apply.clear();
        for (final record in selected.values) {
          final before = snapshot.records[record.key];
          if (before == null ||
              jsonEncode(before.changeJson) != jsonEncode(record.changeJson) ||
              (!record.deleted && before.file == null))
            apply.add(record);
        }
        plan = await store.prepareSyncRestore(
          apply,
          bytesByDigest,
          expectedRecords: snapshot.records,
          gallerySelection: applySelection ? selection : null,
        );
      }
    }
    if (direction == SyncDirection.restore) {
      await plan?.activate();
      localApplied = true;
      // The preflight snapshot pins old files until activation is durable.
      // Release it before the restore plan verifies retired-file cleanup.
      await snapshot.dispose();
      await plan?.finish(committed: true);
      return;
    }
    // The batch is known only after manifests and record decisions settle.
    // Count unique missing blobs, and finish an item only after readback.
    final missing = <String, LocalAppearanceSyncRecord>{
      for (final record in selected.values.where((r) => !r.deleted))
        if (!listing.contains('$root/appearance_resource_${record.digest}.bin'))
          record.digest: record,
    }.values.toList();
    var uploaded = 0;
    onUploadProgress?.call(uploaded, missing.length);
    for (final record in missing) {
      final path = '$root/appearance_resource_${record.digest}.bin';
      final bytes = await bytesFor(record);
      participation.check();
      await adapter.uploadRemoteFile(path, bytes);
      final readBack = await adapter.downloadRemoteFile(path);
      if (readBack.length != record.size ||
          sha256.convert(readBack).toString() != record.digest)
        throw const FormatException('Artwork upload verification failed');
      listing.add(path);
      onUploadProgress?.call(++uploaded, missing.length);
    }
    cloudManifestVerified = ownComplete.containsKey(combinedPath);
    if (changed) {
      // Verify every newly published selected live reference, including reused blobs.
      for (final record in selected.values.where((r) => !r.deleted)) {
        await bytesFor(record);
      }
      participation.check();
      final payload = utf8.encode(
        jsonEncode(
          AppearanceSyncManifest(outbound, selection: selection).toJson(),
        ),
      );
      final ownPath = '${ownPrefix}_${sha256.convert(payload)}.bin';
      try {
        await adapter.uploadRemoteFile(ownPath, payload);
        final readBack = await adapter.downloadRemoteFile(ownPath);
        if (sha256.convert(readBack).toString() !=
            sha256.convert(payload).toString())
          throw const FormatException('Artwork manifest verification failed');
        cloudManifestVerified = true;
      } catch (_) {
        // Only this attempt's new immutable candidate may be removed. Existing
        // complete candidates/bytes remain intact even if cleanup also fails.
        if (!ownComplete.containsKey(ownPath)) {
          try {
            await adapter.deleteRemoteFiles([ownPath]);
          } catch (_) {}
        }
        rethrow;
      }
      ownComplete[ownPath] = AppearanceSyncManifest(
        outbound,
        selection: selection,
      );
      ownIncomplete.remove(ownPath);
    }
    // A historical-candidate cleanup failure must not prevent an already
    // verified cloud publication from being applied on this device.
    participation.check();
    await plan?.activate();
    localApplied = direction != SyncDirection.upload;
    await snapshot.dispose();
    await plan?.finish(committed: true);
    // Bounded metadata history: retain current plus one complete own candidate.
    // No other device candidate or arbitrary orphan blob is garbage-collected.
    if (ownComplete.isNotEmpty) {
      final currentPayload = utf8.encode(
        jsonEncode(
          AppearanceSyncManifest(outbound, selection: selection).toJson(),
        ),
      );
      final currentPath = '${ownPrefix}_${sha256.convert(currentPayload)}.bin';
      int stamp(AppearanceSyncManifest m) => m.records.values.fold(
        m.selection?.modifiedAt ?? 0,
        (value, r) => value > r.modifiedAt ? value : r.modifiedAt,
      );
      final previous = ownComplete.keys.where((p) => p != currentPath).toList()
        ..sort((a, b) {
          final c = stamp(ownComplete[b]!).compareTo(stamp(ownComplete[a]!));
          return c != 0 ? c : a.compareTo(b);
        });
      final keep = {
        if (ownComplete.containsKey(currentPath)) currentPath,
        ...previous.take(ownComplete.containsKey(currentPath) ? 1 : 2),
      };
      final obsolete = {
        ...ownComplete.keys.where((p) => !keep.contains(p)),
        ...ownIncomplete,
      }.toList();
      if (obsolete.isNotEmpty) {
        participation.check();
        await adapter.deleteRemoteFiles(obsolete);
      }
    }
  } catch (error, stack) {
    Object? recoveryError;
    if (!localApplied) {
      try {
        await plan?.finish(committed: false);
      } catch (failure) {
        recoveryError = failure;
      }
    }
    // Once activate persisted references, finish may already have removed old
    // files. Rolling back after that point could restore dangling references.
    if (cloudManifestVerified || localApplied || recoveryError != null) {
      Error.throwWithStackTrace(
        AppearanceSyncIncomplete(
          cloudManifestVerified: cloudManifestVerified,
          localApplied: localApplied,
          cause: error,
          recoveryError: recoveryError,
        ),
        stack,
      );
    }
    Error.throwWithStackTrace(error, stack);
  } finally {
    await snapshot.dispose();
  }
}
