import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/sync_device_id.dart';
import 'package:zephyr/network/sync/sync_plugin_participation.dart';
import 'package:zephyr/network/sync/sync_payload_compatibility.dart';
import 'package:zephyr/network/sync/video_library_sync.dart';
import 'package:zephyr/service/reader/comic_chapter_reading_progress.dart';

abstract final class ChapterProgressSync {
  static final name = RegExp(r'^chapter_progress_v1_[a-f0-9]{32}\.bin$');

  static Future<Map<String, ChapterProgressArchive>> read(
    ComicSyncRemoteAdapter adapter, {
    required VideoLibrarySyncCodec codec,
  }) async {
    final archives = <String, ChapterProgressArchive>{};
    final paths =
        (await adapter.listRemoteDataFiles())
            .map(ComicSyncCore.normalizeRemotePathNoLeadingSlash)
            .where((path) {
              final parts = path.split('/');
              return parts.length == 2 &&
                  parts.first == ComicSyncCore.syncRemoteRootName &&
                  parts.last.startsWith('chapter_progress_');
            })
            .toSet()
            .toList()
          ..sort();
    if (paths.length > 200) throw const SyncCompatibilityException();
    var size = 0;
    for (final path in paths) {
      if (!name.hasMatch(path.split('/').last)) {
        throw const SyncCompatibilityException();
      }
      final bytes = await adapter.downloadRemoteFile(path);
      size += bytes.length;
      if (size > 64 * 1024 * 1024) throw const SyncCompatibilityException();
      archives[path] = await decode(bytes, codec);
    }
    return archives;
  }

  static Future<ChapterProgressArchive> decode(
    List<int> bytes,
    VideoLibrarySyncCodec codec,
  ) async {
    if (bytes.length > ChapterProgressArchive.byteLimit) {
      throw const SyncCompatibilityException();
    }
    try {
      return ChapterProgressArchive.decode(await codec.decode(bytes));
    } on FormatException {
      throw const SyncCompatibilityException();
    }
  }

  static Future<void> run(
    ComicSyncRemoteAdapter adapter, {
    required VideoLibrarySyncCodec codec,
    required SyncPluginParticipation participation,
    required Map<String, ChapterProgressArchive> archives,
    ComicChapterReadingProgress? store,
  }) async {
    final progress = store ?? ComicChapterReadingProgress.instance;
    var remote = ChapterProgressArchive();
    for (final snapshot in archives.values) {
      remote = remote.merged(snapshot);
    }
    bool participates(ChapterProgressIdentity id) =>
        participation.sources.contains(id.$1);
    participation.check();
    final local = await progress.restore(
      ChapterProgressArchive({
        for (final row in remote.rows.entries)
          if (participates(row.key)) row.key: row.value,
      }),
      deletedWorks: {
        for (final history in objectbox.unifiedHistoryBox.getAll())
          if (history.deleted && participation.sources.contains(history.source))
            (history.source, history.comicId):
                history.updatedAt.millisecondsSinceEpoch,
      },
      beforeWrite: (_, {beforeValues}) async => participation.check(),
    );
    if (!local.rows.keys.any(participates)) return;
    final id = await ensureSyncDeviceId();
    final deviceKey = sha256
        .convert(utf8.encode(id))
        .toString()
        .substring(0, 32);
    final path =
        '${ComicSyncCore.syncRemoteRootName}/chapter_progress_v1_$deviceKey.bin';
    final current = archives[path];
    final outgoing = ChapterProgressArchive({
      if (current != null)
        for (final row in current.rows.entries)
          if (!participates(row.key)) row.key: row.value,
      for (final row in local.rows.entries)
        if (participates(row.key)) row.key: row.value,
    });
    final encoded = outgoing.encode();
    if (current != null && listEquals(current.encode(), encoded)) {
      return;
    }
    final bytes = await codec.encode(encoded);
    participation.check();
    await adapter.uploadRemoteFile(path, bytes);
    final uploaded = await decode(
      await adapter.downloadRemoteFile(path),
      codec,
    );
    if (!listEquals(uploaded.encode(), encoded)) {
      throw StateError('Chapter history upload was not confirmed');
    }
  }
}
