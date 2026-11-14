import 'dart:convert';

import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/plugin_portable_scope.dart';
import 'package:zephyr/network/sync/plugin_record_scope.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/network/sync/sync_service.dart';
import 'package:zephyr/network/sync/video_library_sync.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/video/video_library_store.dart';

/// One in-memory preview for an explicitly requested cloud purge. This is not
/// persisted, replayed or synchronized; its fields become ordinary tombstones
/// only if the caller's existing journaled clear operation actually commits.
class CloudPluginAccountData {
  CloudPluginAccountData._(
    this.configs,
    this.portable,
    this.comicRecords,
    this.videoRecords,
  );
  final List<PluginConfig> configs;
  final PortablePreferencesSnapshot portable;
  final Map<String, dynamic>? comicRecords;
  final VideoLibrarySnapshot videoRecords;
  @override
  String toString() => 'CloudPluginAccountData(private preview)';
}

/// Uses the current protected/scoped adapter and the existing validated domain
/// readers. There is no Sync, directory creation, upload, restore or cleanup.
/// Locked/unsupported/network failures propagate before any purge mutation.
Future<CloudPluginAccountData> readCloudPluginAccountData(
  ComicSyncRemoteAdapter adapter,
  String source, {
  SettingsSyncCodec settingsCodec = const SettingsSyncCodec(),
  VideoLibrarySyncCodec videoCodec = const VideoLibrarySyncCodec(),
  ComicSyncCodec comicCodec = const ComicSyncCodec(),
}) async {
  source = source.trim();
  if (source.isEmpty ||
      source.length > 200 ||
      RegExp(r'[/\\\x00-\x1f]').hasMatch(source)) {
    throw const FormatException('Invalid plugin identity');
  }
  await adapter.testConnection();
  final comics = await readComicArchiveData(adapter, codec: comicCodec);
  final settings = await readSettingsArchiveData(adapter, codec: settingsCodec);
  final video = await VideoLibrarySync.readArchive(adapter, codec: videoCodec);
  final configs =
      settings?.pluginConfigsForSource(source) ?? const <PluginConfig>[];
  for (final config in configs) {
    try {
      if (jsonDecode(config.config) is! Map<String, dynamic>) {
        throw const FormatException();
      }
    } catch (_) {
      throw const FormatException(
        'Cloud plugin settings cannot create field deletions',
      );
    }
  }
  final ownership = pluginPortableScopes(video.preferences.entries);
  final portable = PortablePreferencesSnapshot({
    for (final entry in ownership.entries)
      if (entry.value.source == source)
        entry.key: video.preferences.entries[entry.key]!,
  });
  PortablePreferencesSnapshot.fromJson(portable.toJson());
  return CloudPluginAccountData._(
    configs,
    portable,
    comics == null ? null : comicPluginRecords(comics, source),
    videoPluginRecords(video.snapshot, source),
  );
}
