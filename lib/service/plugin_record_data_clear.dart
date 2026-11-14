import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/plugin_record_scope.dart';
import 'package:zephyr/network/sync/sync_device_id.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';

Map<String, dynamic> _capture(String source, bool downloads) {
  final favorites = objectbox.unifiedFavoriteBox
      .getAll()
      .where((row) => row.source == source)
      .map((row) => row.toJson())
      .toList();
  final histories = objectbox.unifiedHistoryBox
      .getAll()
      .where((row) => row.source == source)
      .map((row) => row.toJson())
      .toList();
  final follows = objectbox.comicFollowBox
      .getAll()
      .where((row) => row.source == source)
      .map((row) => row.toJson())
      .toList();
  final preferences = objectbox.comicReadPreferenceBox
      .getAll()
      .where((row) => row.source == source)
      .map((row) => row.toJson())
      .toList();
  final media = downloads
      ? objectbox.unifiedDownloadBox
            .getAll()
            .where((row) => row.source == source)
            .map((row) => row.toJson())
            .toList()
      : <Map<String, dynamic>>[];
  final keys = {
    ...favorites,
    ...histories,
    ...follows,
    ...preferences,
    ...media,
  }.map((row) => row['uniqueKey']).toSet();
  final links = objectbox.comicLinkBox
      .getAll()
      .where(
        (row) =>
            keys.contains(row.comicUniqueKey) &&
            (downloads || row.typeData != 'download'),
      )
      .map((row) => row.toJson())
      .toList();
  final tasks = <Map<String, dynamic>>[];
  if (downloads) {
    for (final row in objectbox.downloadTaskBox.getAll()) {
      try {
        if (row.taskInfo?.from == source) tasks.add(row.toJson());
      } catch (_) {
        /* Unknown task identities are never guessed/deleted. */
      }
    }
  }
  return {
    'favorites': favorites,
    'histories': histories,
    'follows': follows,
    'readPreferences': preferences,
    'links': links,
    'downloads': media,
    'tasks': tasks,
  };
}

class PluginRecordDataClearPlan {
  PluginRecordDataClearPlan._(
    this.source,
    this.epoch,
    this.cloudDelete,
    this.includeDownloads,
    this._before,
    this._next,
    this._videoBefore,
    this._videoNext,
    this._videoSelected,
    this._counts,
    this._store,
  );
  final String source;
  final int epoch;
  final bool cloudDelete, includeDownloads;
  final Map<String, dynamic> _before, _next;
  final VideoLibrarySnapshot _videoBefore, _videoNext;
  final VideoLibrarySnapshot _videoSelected;
  final Map<String, int> _counts;
  final VideoLibraryStore _store;
  int get favoriteCount => (_counts['favorites'] ?? 0) + videoFavoriteCount;
  int get historyCount => _counts['histories'] ?? 0;
  int get followCount =>
      (_counts['follows'] ?? 0) +
      _videoSelected.tracking.values.where((entry) => !entry.deleted).length;
  int get downloadCount => (_before['downloads'] as List).length;
  int get readPreferenceCount => _counts['readPreferences'] ?? 0;
  int get videoFavoriteCount =>
      _videoSelected.favorites.values.where((entry) => !entry.deleted).length;

  void _guard() {
    final state = LocalPluginInstallationState.instance;
    if (state.installationEpoch(source) != epoch ||
        state.isInstalling(source)) {
      throw const PluginLifecycleChanged();
    }
  }

  void persistDatabase() {
    _guard();
    if (jsonEncode(_capture(source, includeDownloads)) != jsonEncode(_before)) {
      throw const PluginLifecycleChanged();
    }
    List<int> ids(String name) =>
        (_before[name] as List).map((row) => row['id'] as int).toList();
    objectbox.unifiedFavoriteBox.removeMany(ids('favorites'));
    objectbox.unifiedHistoryBox.removeMany(ids('histories'));
    objectbox.comicFollowBox.removeMany(ids('follows'));
    objectbox.comicReadPreferenceBox.removeMany(ids('readPreferences'));
    objectbox.comicLinkBox.removeMany(ids('links'));
    if (includeDownloads) {
      objectbox.unifiedDownloadBox.removeMany(ids('downloads'));
      objectbox.downloadTaskBox.removeMany(ids('tasks'));
    }
    if (cloudDelete) {
      objectbox.unifiedFavoriteBox.putMany(
        (_next['favorites'] as List)
            .map(
              (row) =>
                  UnifiedComicFavorite.fromJson(Map<String, dynamic>.from(row)),
            )
            .toList(),
      );
      objectbox.unifiedHistoryBox.putMany(
        (_next['histories'] as List)
            .map(
              (row) =>
                  UnifiedComicHistory.fromJson(Map<String, dynamic>.from(row)),
            )
            .toList(),
      );
      objectbox.comicFollowBox.putMany(
        (_next['follows'] as List)
            .map((row) => ComicFollow.fromJson(Map<String, dynamic>.from(row)))
            .toList(),
      );
      objectbox.comicReadPreferenceBox.putMany(
        (_next['readPreferences'] as List)
            .map(
              (row) =>
                  ComicReadPreference.fromJson(Map<String, dynamic>.from(row)),
            )
            .toList(),
      );
      objectbox.comicLinkBox.putMany(
        (_next['links'] as List)
            .map((row) => ComicLink.fromJson(Map<String, dynamic>.from(row)))
            .toList(),
      );
    }
  }

  Future<void> applyPreferences({
    required Future<void> Function(Map<String, dynamic>) beforeWrite,
  }) async {
    _guard();
    if (jsonEncode((await _store.read()).toJson()) !=
        jsonEncode(_videoBefore.toJson())) {
      throw const PluginLifecycleChanged();
    }
    final prefs = await SharedPreferences.getInstance();
    final original = prefs.getString(_store.storageKey);
    await beforeWrite({
      _store.storageKey: videoLibrarySnapshotEncoding(_videoNext),
    });
    _guard();
    if (prefs.getString(_store.storageKey) != original) {
      throw const PluginLifecycleChanged();
    }
    await _store.replaceSnapshot(_videoNext);
  }
}

Future<PluginRecordDataClearPlan> preparePluginRecordDataClear(
  String source, {
  required bool cloudDelete,
  required int expectedEpoch,
  bool includeDownloads = false,
  Map<String, dynamic>? knownCloudComics,
  VideoLibrarySnapshot? knownCloudVideo,
  VideoLibraryStore? store,
  int? nowMs,
}) async {
  source = source.trim();
  final state = LocalPluginInstallationState.instance;
  await state.load();
  if (state.installationEpoch(source) != expectedEpoch ||
      state.isInstalling(source)) {
    throw const PluginLifecycleChanged();
  }
  if (knownCloudComics != null) ComicSyncCore.validatePayload(knownCloudComics);
  final before = _capture(source, includeDownloads), next = <String, dynamic>{};
  final clock = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  final actor = store?.deviceId ?? syncDeviceId;
  final ownedKeys = <String>{};
  final counts = <String, int>{};
  for (final field in [
    'favorites',
    'histories',
    'follows',
    'readPreferences',
  ]) {
    final rows = <String, Map<String, dynamic>>{};
    final List remoteRows = cloudDelete
        ? ((knownCloudComics?[field] as List?) ?? const [])
        : const [];
    for (final raw in [...remoteRows, ...(before[field] as List)]) {
      final row = Map<String, dynamic>.from(raw as Map);
      if (row['source'] != source) continue;
      final key = row['uniqueKey'] as String;
      final old = rows[key];
      int time(Map<String, dynamic> value) =>
          DateTime.tryParse('${value['updatedAt']}')?.millisecondsSinceEpoch ??
          0;
      if (old == null || time(row) >= time(old)) rows[key] = row;
    }
    ownedKeys.addAll(rows.keys);
    counts[field] = rows.values.where((row) => row['deleted'] != true).length;
    next[field] = rows.values.map((row) {
      final result = Map<String, dynamic>.from(row)..['id'] = 0;
      if (cloudDelete && result['deleted'] != true) {
        final previous =
            DateTime.tryParse(
              '${result['updatedAt']}',
            )?.millisecondsSinceEpoch ??
            0;
        result['updatedAt'] = DateTime.fromMillisecondsSinceEpoch(
          clock > previous ? clock : previous + 1,
          isUtc: true,
        ).toIso8601String();
        result['deleted'] = true;
        if (field == 'readPreferences') result['overridesJson'] = '{}';
      }
      return result;
    }).toList();
  }
  final links = <String, Map<String, dynamic>>{};
  final List remoteLinks = cloudDelete
      ? ((knownCloudComics?['links'] as List?) ?? const [])
      : const [];
  for (final raw in [...remoteLinks, ...(before['links'] as List)]) {
    final row = Map<String, dynamic>.from(raw as Map);
    if (!ownedKeys.contains(row['comicUniqueKey']) ||
        row['typeData'] == 'download') {
      continue;
    }
    links[row['uniqueKey'] as String] = row;
  }
  next['links'] = links.values.map((row) {
    final result = Map<String, dynamic>.from(row)..['id'] = 0;
    if (cloudDelete && result['deletedAt'] == null) {
      final revision = clock > (result['updatedAt'] as int)
          ? clock
          : (result['updatedAt'] as int) + 1;
      final vector = Map<String, dynamic>.from(
        jsonDecode(result['versionVectorJson'] as String) as Map,
      );
      vector[actor] = ((vector[actor] as num?)?.toInt() ?? 0) + 1;
      result['versionVectorJson'] = jsonEncode(vector);
      result['updatedAt'] = revision;
      result['deletedAt'] = revision;
    }
    return result;
  }).toList();
  final library = store ?? VideoLibraryStore.shared,
      videoBefore = await (store ?? VideoLibraryStore.shared).read();
  final combined = videoBefore.merged(
    cloudDelete && knownCloudVideo != null
        ? videoPluginRecords(knownCloudVideo, source)
        : VideoLibrarySnapshot(),
  );
  final videoClock = combined.maxClock >= clock ? combined.maxClock + 1 : clock;
  Map<String, VideoLibraryEntry> clear(
    Map<String, VideoLibraryEntry> all,
    Set<String> selected,
  ) => {
    for (final entry in all.entries)
      if (!selected.contains(entry.key))
        entry.key: entry.value
      else if (cloudDelete)
        entry.key: entry.value.deleted
            ? entry.value
            : VideoLibraryEntry(
                clock: videoClock,
                device: actor,
                deleted: true,
                data: entry.value.data,
              ),
  };
  final selected = videoPluginRecords(combined, source);
  final videoNext = VideoLibrarySnapshot(
    favorites: clear(combined.favorites, selected.favorites.keys.toSet()),
    folders: clear(combined.folders, selected.folders.keys.toSet()),
    memberships: clear(combined.memberships, selected.memberships.keys.toSet()),
    tracking: clear(combined.tracking, selected.tracking.keys.toSet()),
  );
  return PluginRecordDataClearPlan._(
    source,
    expectedEpoch,
    cloudDelete,
    includeDownloads,
    before,
    next,
    videoBefore,
    videoNext,
    selected,
    counts,
    library,
  );
}
