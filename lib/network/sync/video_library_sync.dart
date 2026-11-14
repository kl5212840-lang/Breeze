import 'dart:convert';
import 'package:zephyr/network/sync/sync_direction.dart';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/network/sync/sync_device_id.dart';
import 'package:zephyr/network/sync/sync_plugin_participation.dart';
import 'package:zephyr/network/sync/sync_payload_compatibility.dart';
import 'package:zephyr/network/sync/sync_archive_adapter.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';

class VideoArchiveData {
  const VideoArchiveData(
    this.snapshot,
    this.preferences,
    this.hasPreferences,
    this.digests,
  );
  final VideoLibrarySnapshot snapshot;
  final PortablePreferencesSnapshot preferences;
  final bool hasPreferences;
  final Map<String, String> digests;
}

class VideoLibrarySyncCodec {
  const VideoLibrarySyncCodec({
    this.encode = ComicSyncCore.encodeEncryptedPayload,
    this.decode = ComicSyncCore.decodeEncryptedPayload,
  });
  final Future<List<int>> Function(List<int>) encode, decode;
}

/// One replaceable snapshot per device avoids a shared manifest/MD5 race.
/// Clients merge every device's entities and keep tombstones. No other device's
/// snapshot, comic data or settings are deleted by video-library synchronization.
class VideoLibrarySync {
  VideoLibrarySync._();
  static final _files = RegExp(r'^video_library_[a-f0-9]{32}\.bin$');
  static final Map<String, Future<void>> _running = {};

  static Future<void> preflight(
    ComicSyncRemoteAdapter adapter, {
    VideoLibrarySyncCodec codec = const VideoLibrarySyncCodec(),
  }) async {
    await readArchive(adapter, codec: codec);
  }

  static String syncedDigestKey(VideoLibraryStore store) =>
      '${store.storageKey}.syncedDigest';

  static Future<void> run(
    ComicSyncRemoteAdapter adapter, {
    VideoLibraryStore? store,
    VideoLibrarySyncCodec codec = const VideoLibrarySyncCodec(),
    bool upload = true,
    bool includeSettings = true,
    bool? includePluginSettings,
    SyncDirection direction = SyncDirection.merge,
    SyncPluginParticipation? participation,
  }) {
    final library = store ?? VideoLibraryStore.shared;
    final key = library.storageKey;
    // Chain a requested upload after a download, rather than coalescing two
    // different intents and silently dropping one of them.
    final operation = (_running[key] ?? Future<void>.value())
        .catchError((Object _) {})
        .then(
          (_) => _sync(
            adapter,
            library,
            codec,
            upload: upload,
            includeSettings: includeSettings,
            includePluginSettings: includePluginSettings ?? includeSettings,
            direction: direction,
            participation: participation,
          ),
        );
    _running[key] = operation;
    void release() {
      if (identical(_running[key], operation)) _running.remove(key);
    }

    operation.then(
      (_) => release(),
      onError: (Object _, StackTrace _) => release(),
    );
    return operation;
  }

  static Future<VideoArchiveData> readArchive(
    ComicSyncRemoteAdapter adapter, {
    VideoLibrarySyncCodec codec = const VideoLibrarySyncCodec(),
    bool includeSettings = true,
    Map<String, String> skipDigests = const {},
  }) async {
    final root = ComicSyncCore.syncRemoteRootName;
    await LocalPluginInstallationState.instance.load();
    final paths =
        (await adapter.listRemoteDataFiles())
            .where((path) {
              final normalized =
                  ComicSyncCore.normalizeRemotePathNoLeadingSlash(path);
              return normalized.startsWith('$root/') &&
                  normalized.split('/').length == 2 &&
                  _files.hasMatch(normalized.split('/').last);
            })
            .toSet()
            .toList()
          ..sort();
    if (paths.length > 200) {
      throw const FormatException('Too many video library device snapshots');
    }
    final digests = <String, String>{};
    var remote = VideoLibrarySnapshot();
    var remotePreferences = PortablePreferencesSnapshot();
    var hasPreferences = false;
    for (final path in paths) {
      final bytes = await adapter.downloadRemoteFile(path);
      digests[path] = sha256.convert(bytes).toString();
      if (skipDigests[path] == digests[path]) continue;
      if (bytes.length > VideoLibrarySnapshot.maxBytes) {
        throw const FormatException('Video library is too large');
      }
      final decoded = await codec.decode(bytes);
      if (decoded.length > VideoLibrarySnapshot.maxBytes) {
        throw const FormatException('Video library is too large');
      }
      final envelope = asJsonMap(jsonDecode(utf8.decode(decoded)));
      SyncPayloadCompatibility.keys(envelope, {
        'format',
        'version',
        'sha256',
        'snapshot',
        'portable',
        'portableSha256',
      });
      SyncPayloadCompatibility.version(envelope, 'version', {1});
      if (envelope['format'] != 'BreezeVideoLibrary' ||
          envelope['version'] != 1) {
        throw const FormatException('Unsupported video library backup');
      }
      final raw = asJsonMap(envelope['snapshot']);
      if (envelope['sha256'] !=
          sha256.convert(utf8.encode(jsonEncode(raw))).toString()) {
        throw const FormatException('Video library checksum mismatch');
      }
      remote = remote.merged(VideoLibrarySnapshot.fromJson(raw));
      if (envelope.containsKey('portable')) {
        final data = envelope['portable'];
        if (envelope['portableSha256'] !=
            sha256.convert(utf8.encode(jsonEncode(data))).toString()) {
          throw const FormatException('Application data checksum mismatch');
        }
        final snapshot = PortablePreferences.forSync(
          PortablePreferencesSnapshot.fromJson(data),
          includeSettings: includeSettings,
        );
        remotePreferences = remotePreferences.merged(snapshot);
        hasPreferences = true;
      }
    }
    return VideoArchiveData(remote, remotePreferences, hasPreferences, digests);
  }

  static Future<void> _sync(
    ComicSyncRemoteAdapter adapter,
    VideoLibraryStore store,
    VideoLibrarySyncCodec codec, {
    required bool upload,
    required bool includeSettings,
    required bool includePluginSettings,
    required SyncDirection direction,
    SyncPluginParticipation? participation,
  }) async {
    participation ??= await SyncPluginParticipation.capture();
    participation.check();
    await prepareScopedSyncArchive(adapter);
    await adapter.ensureRemoteReady();
    final root = ComicSyncCore.syncRemoteRootName;
    final archive = await readArchive(
      adapter,
      codec: codec,
      includeSettings: true,
    );
    final remote = archive.snapshot, remotePreferences = archive.preferences;
    final hasPreferences = archive.hasPreferences;
    final paths = archive.digests.keys.toList();
    // Reading/merging here includes local edits made while network reads were
    // pending. A failed upload never rolls back a successful local favorite.
    if (paths.isNotEmpty) {
      await store.updateSnapshot((before) {
        participation!.check();
        return projectPluginVideoData(
          before.merged(remote),
          before,
          participation.sources,
        );
      });
    }
    if (hasPreferences) {
      await PortablePreferences.restore(
        PortablePreferences.forSync(
          remotePreferences,
          includeSettings: includeSettings,
          includePluginSettings: includePluginSettings,
        ),
        direction: direction != SyncDirection.upload
            ? direction
            : SyncDirection.recordsOnly,
        preferIncomingOnTie: !upload,
        shouldWriteKey: (key) => PortablePreferences.settingsKeySelected(
          key,
          includeSettings: includeSettings && direction != SyncDirection.upload,
          includePluginSettings:
              includePluginSettings && direction != SyncDirection.upload,
        ),
        participatingSources: participation.sources,
        beforeWrite: (_) async {
          participation!.check();
        },
      );
    }
    if (!upload) return;
    final preferences = projectPluginPortableData(
      PortablePreferences.directed(
        await PortablePreferences.capture(),
        remotePreferences,
        direction: direction,
        forCloud: true,
        includeSettings: includeSettings,
        includePluginSettings: includePluginSettings,
      ),
      remotePreferences,
      participation.sources,
    );
    final snapshot = projectPluginVideoData(
      remote.merged(await store.read()),
      remote,
      participation.sources,
    );
    final lifecycle = LocalPluginInstallationState.instance;
    final epochs = {
      for (final source in {
        ...lifecycle.excludedSources(PluginDataScope.records),
        ...lifecycle.excludedSources(PluginDataScope.accountSettings),
      })
        source: lifecycle.installationEpoch(source),
    };
    if (snapshot.favorites.isEmpty &&
        snapshot.folders.isEmpty &&
        preferences.entries.isEmpty &&
        paths.isEmpty) {
      return;
    }
    final raw = snapshot.toJson(),
        digest = sha256.convert(utf8.encode(jsonEncode(raw))).toString();
    final device = store.deviceId ?? await ensureSyncDeviceId();
    final deviceKey = sha256
        .convert(utf8.encode(device))
        .toString()
        .substring(0, 32);
    final path = '$root/video_library_$deviceKey.bin';
    final encoded = await codec.encode(
      utf8.encode(
        jsonEncode({
          'format': 'BreezeVideoLibrary',
          'version': 1,
          'sha256': digest,
          'snapshot': raw,
          'portable': preferences.toJson(),
          'portableSha256': sha256
              .convert(utf8.encode(jsonEncode(preferences.toJson())))
              .toString(),
        }),
      ),
    );
    final currentExcluded = {
      ...lifecycle.excludedSources(PluginDataScope.records),
      ...lifecycle.excludedSources(PluginDataScope.accountSettings),
    };
    if (currentExcluded.length != epochs.length ||
        currentExcluded.any((source) => !epochs.containsKey(source))) {
      throw const PluginLifecycleChanged();
    }
    for (final entry in epochs.entries) {
      if (lifecycle.installationEpoch(entry.key) != entry.value ||
          lifecycle.isInstalling(entry.key)) {
        throw const PluginLifecycleChanged();
      }
    }
    participation.check();
    await adapter.uploadRemoteFile(path, encoded);
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(syncedDigestKey(store), digest)) {
      throw StateError('Video library sync status was not saved');
    }
  }
}
