import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/sync_device_id.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/util/json/json_value.dart';

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

  static Future<void> run(
    ComicSyncRemoteAdapter adapter, {
    VideoLibraryStore? store,
    VideoLibrarySyncCodec codec = const VideoLibrarySyncCodec(),
    bool upload = true,
  }) {
    final library = store ?? VideoLibraryStore.shared;
    final key = library.storageKey;
    // Chain a requested upload after a download, rather than coalescing two
    // different intents and silently dropping one of them.
    final operation = (_running[key] ?? Future<void>.value())
        .catchError((Object _) {})
        .then((_) => _sync(adapter, library, codec, upload: upload));
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

  static Future<void> _sync(
    ComicSyncRemoteAdapter adapter,
    VideoLibraryStore store,
    VideoLibrarySyncCodec codec, {
    required bool upload,
  }) async {
    await adapter.ensureRemoteReady();
    final root = ComicSyncCore.syncRemoteRootName;
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
    var remote = VideoLibrarySnapshot();
    for (final path in paths) {
      final bytes = await adapter.downloadRemoteFile(path);
      if (bytes.length > VideoLibrarySnapshot.maxBytes) {
        throw const FormatException('Video library is too large');
      }
      final decoded = await codec.decode(bytes);
      if (decoded.length > VideoLibrarySnapshot.maxBytes) {
        throw const FormatException('Video library is too large');
      }
      final envelope = asJsonMap(jsonDecode(utf8.decode(decoded)));
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
    }
    // Reading/merging here includes local edits made while network reads were
    // pending. A failed upload never rolls back a successful local favorite.
    if (paths.isNotEmpty) await store.merge(remote);
    if (!upload) return;
    final snapshot = await store.read();
    if (snapshot.favorites.isEmpty &&
        snapshot.folders.isEmpty &&
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
        }),
      ),
    );
    await adapter.uploadRemoteFile(path, encoded);
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString('${store.storageKey}.syncedDigest', digest)) {
      throw StateError('Video library sync status was not saved');
    }
  }
}
