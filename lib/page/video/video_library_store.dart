import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:zephyr/network/sync/sync_device_id.dart';
import 'package:zephyr/network/sync/sync_payload_compatibility.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_cover_overlay.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/service/folder_cover_identity.dart';

/// An immutable per-entity revision. Folders and memberships merge separately
/// so an offline rename cannot overwrite a different device's folder choice.
class VideoLibraryEntry {
  VideoLibraryEntry({
    required this.clock,
    required this.device,
    required this.deleted,
    required Map<String, dynamic> data,
  }) : data = Map.unmodifiable(data);
  final int clock;
  final String device;
  final bool deleted;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => {
    'clock': clock,
    'device': device,
    'deleted': deleted,
    'data': data,
  };
  factory VideoLibraryEntry.fromJson(Map<String, dynamic> json) {
    SyncPayloadCompatibility.keys(json, {'clock', 'device', 'deleted', 'data'});
    final clock = json['clock'], device = json['device'];
    if (clock is! int ||
        clock < 1 ||
        clock > 8640000000000000 ||
        device is! String ||
        device.isEmpty ||
        device.length > 200 ||
        json['deleted'] is! bool ||
        json['data'] is! Map) {
      throw const FormatException('Invalid video library revision');
    }
    return VideoLibraryEntry(
      clock: clock,
      device: device,
      deleted: json['deleted'] == true,
      data: asJsonMap(json['data']),
    );
  }

  static VideoLibraryEntry newer(VideoLibraryEntry a, VideoLibraryEntry b) {
    final clock = a.clock.compareTo(b.clock);
    if (clock != 0) return clock > 0 ? a : b;
    final device = a.device.compareTo(b.device);
    if (device != 0) return device > 0 ? a : b;
    if (a.deleted != b.deleted) return a.deleted ? a : b;
    // A corrupt or duplicated revision must still converge deterministically.
    return _canonical(a.data).compareTo(_canonical(b.data)) >= 0 ? a : b;
  }
}

String _canonical(Object? value) {
  Object? sorted(Object? v) {
    if (v is Map) {
      final keys = v.keys.map((x) => x.toString()).toList()..sort();
      return {for (final key in keys) key: sorted(v[key])};
    }
    if (v is List) return v.map(sorted).toList();
    return v;
  }

  return jsonEncode(sorted(value));
}

/// Exact persisted encoding for a journal's compare-before-rollback value.
String videoLibrarySnapshotEncoding(VideoLibrarySnapshot snapshot) =>
    _canonical(snapshot.toJson());

// Missing duration is unknown, not a retraction of an observed total. Keep
// only this field across sparse writes; all other explicit empty detail fields
// retain their existing clearing semantics.
Map<String, Object?> _itemWithKnownDuration(ApiVideoItem item, Object? old) {
  final metadata = item.toLibraryJson();
  var duration = videoCoverDurationText(
    item.sourceDuration,
    clockFallback: item.remarks,
  );
  if (duration.isEmpty && old is Map && old['id'] == item.id) {
    final previous = apiVideoHttps(old['detailUrl']);
    final samePage =
        previous != null &&
        (videoPublicPage(previous) ?? previous) ==
            (videoPublicPage(item.detailUrl) ?? item.detailUrl);
    if (samePage) {
      duration = videoCoverDurationText(
        apiVideoText(old['sourceDuration']),
        clockFallback: apiVideoText(old['remarks']),
      );
    }
  }
  if (duration.isNotEmpty) metadata['sourceDuration'] = duration;
  return metadata;
}

class VideoLibrarySnapshot {
  VideoLibrarySnapshot({
    Map<String, VideoLibraryEntry> favorites = const {},
    Map<String, VideoLibraryEntry> folders = const {},
    Map<String, VideoLibraryEntry> memberships = const {},
    Map<String, VideoLibraryEntry> tracking = const {},
  }) : favorites = Map.unmodifiable(favorites),
       folders = Map.unmodifiable(folders),
       memberships = Map.unmodifiable(memberships),
       tracking = Map.unmodifiable(tracking);
  final Map<String, VideoLibraryEntry> favorites,
      folders,
      memberships,
      tracking;
  late final Map<String, Set<String>> _foldersByItem = _indexFolders();
  static const maxBytes = 24 * 1024 * 1024;

  Map<String, dynamic> toJson() => {
    'version': 1,
    'favorites': {for (final e in favorites.entries) e.key: e.value.toJson()},
    'folders': {for (final e in folders.entries) e.key: e.value.toJson()},
    'memberships': {
      for (final e in memberships.entries) e.key: e.value.toJson(),
    },
    'tracking': {for (final e in tracking.entries) e.key: e.value.toJson()},
  };

  factory VideoLibrarySnapshot.fromJson(Map<String, dynamic> json) {
    SyncPayloadCompatibility.keys(json, {
      'version',
      'favorites',
      'folders',
      'memberships',
      'tracking',
    });
    SyncPayloadCompatibility.version(json, 'version', {1});
    if (json['version'] != 1) {
      throw const FormatException('Unsupported video library version');
    }
    Map<String, VideoLibraryEntry> entries(String field, int limit) {
      if (json[field] is! Map) {
        throw const FormatException('Invalid video library data');
      }
      final data = asJsonMap(json[field]);
      if (data.length > limit) {
        throw const FormatException('Video library is too large');
      }
      return {
        for (final e in data.entries)
          e.key: VideoLibraryEntry.fromJson(asJsonMap(e.value)),
      };
    }

    final favorites = entries('favorites', 10000),
        folders = entries('folders', 2000),
        memberships = entries('memberships', 50000),
        tracking = json.containsKey('tracking')
            ? entries('tracking', 10000)
            : <String, VideoLibraryEntry>{};
    for (final e in favorites.entries) {
      final source = apiVideoText(e.value.data['source'], 200);
      final raw = asJsonMap(e.value.data['item']);
      final home = apiVideoHttps(raw['detailUrl']);
      if (source.isEmpty || home == null) {
        throw const FormatException('Invalid favorite source');
      }
      final item = ApiVideoItem.fromJson(raw, home: home);
      SyncPayloadCompatibility.keys(e.value.data, {
        'source',
        'item',
        'addedAt',
      });
      SyncPayloadCompatibility.keys(raw, {
        ...item.toLibraryJson().keys,
        'containCover',
      });
      if (e.key != VideoLibraryStore.itemKey(source, item.id)) {
        throw const FormatException('Invalid favorite identity');
      }
      // Serialize only the known public metadata contract, even for cloud data.
      favorites[e.key] = VideoLibraryEntry(
        clock: e.value.clock,
        device: e.value.device,
        deleted: e.value.deleted,
        data: {
          'source': source,
          'item': item.toLibraryJson(),
          'addedAt': apiVideoInt(e.value.data['addedAt'], e.value.clock),
        },
      );
    }
    for (final e in folders.entries) {
      final d = e.value.data;
      if (d['id'] != e.key ||
          apiVideoText(d['source'], 200).isEmpty ||
          apiVideoText(d['name'], 61).isEmpty ||
          '${d['name']}'.length > 60) {
        throw const FormatException('Invalid favorite folder');
      }
    }
    for (final e in memberships.entries) {
      final item = e.value.data['itemKey'], folder = e.value.data['folderId'];
      if (item is! String ||
          folder is! String ||
          e.key != VideoLibraryStore.membershipKey(item, folder)) {
        throw const FormatException('Invalid favorite membership');
      }
    }
    for (final e in tracking.entries) {
      final d = e.value.data;
      SyncPayloadCompatibility.keys(d, {
        'itemKey',
        'known',
        'latest',
        'checkedAt',
        'available',
      });
      if (d['itemKey'] != e.key ||
          d['known'] is! List ||
          d['latest'] is! List ||
          [d['known'], d['latest']].any(
            (x) =>
                (x as List).length > 5000 ||
                x.any((v) => v is! String || v.length > 1000),
          ) ||
          d['checkedAt'] is! int ||
          (d['checkedAt'] as int) < 0) {
        throw const FormatException('Invalid update tracking');
      }
      tracking[e.key] = VideoLibraryEntry(
        clock: e.value.clock,
        device: e.value.device,
        deleted: e.value.deleted,
        data: {
          'itemKey': e.key,
          'known': List<String>.from(d['known']),
          'latest': List<String>.from(d['latest']),
          'checkedAt': d['checkedAt'],
          'available': d['available'] != false,
        },
      );
    }
    return VideoLibrarySnapshot(
      favorites: favorites,
      folders: folders,
      memberships: memberships,
      tracking: tracking,
    );
  }

  VideoLibrarySnapshot merged(VideoLibrarySnapshot remote) {
    Map<String, VideoLibraryEntry> merge(
      Map<String, VideoLibraryEntry> a,
      Map<String, VideoLibraryEntry> b,
    ) => {
      ...a,
      for (final e in b.entries)
        e.key: a[e.key] == null
            ? e.value
            : VideoLibraryEntry.newer(a[e.key]!, e.value),
    };
    return VideoLibrarySnapshot(
      favorites: merge(favorites, remote.favorites),
      folders: merge(folders, remote.folders),
      memberships: merge(memberships, remote.memberships),
      tracking: merge(tracking, remote.tracking),
    );
  }

  int get maxClock => [
    ...favorites.values,
    ...folders.values,
    ...memberships.values,
    ...tracking.values,
  ].fold(0, (value, entry) => entry.clock > value ? entry.clock : value);

  Map<String, VideoLibraryEntry> foldersFor(String source) => {
    for (final e in folders.entries)
      if (!e.value.deleted &&
          (e.value.data['source'] == source ||
              e.value.data['source'] == VideoLibraryStore.sharedFolderSource))
        e.key: e.value,
  };

  bool contains(String source, String id) =>
      favorites[VideoLibraryStore.itemKey(source, id)]?.deleted == false;

  bool follows(String key) =>
      favorites[key]?.deleted == false && tracking[key]?.deleted == false;

  int newEpisodes(String key) {
    if (!follows(key)) return 0;
    final value = tracking[key]!.data;
    return (value['latest'] as List)
        .toSet()
        .difference((value['known'] as List).toSet())
        .length;
  }

  int get updatedFollowCount =>
      tracking.keys.where((key) => newEpisodes(key) > 0).length;

  Map<String, Set<String>> _indexFolders() {
    final result = <String, Set<String>>{};
    for (final e in memberships.values) {
      final key = e.data['itemKey'], folder = e.data['folderId'];
      if (!e.deleted &&
          folders[folder]?.deleted == false &&
          favorites[key]?.deleted == false &&
          (folders[folder]?.data['source'] == favorites[key]?.data['source'] ||
              folders[folder]?.data['source'] ==
                  VideoLibraryStore.sharedFolderSource)) {
        (result[key as String] ??= <String>{}).add(folder as String);
      }
    }
    return result;
  }

  Set<String> foldersOf(String itemKey) =>
      Set.unmodifiable(_foldersByItem[itemKey] ?? const <String>{});

  List<({String key, ApiVideoItem item, int clock})> itemsFor(
    String source, {
    Uri? home,
  }) => [
    for (final e in favorites.entries)
      if (!e.value.deleted && e.value.data['source'] == source)
        if (Uri.parse(asJsonMap(e.value.data['item'])['detailUrl'] as String)
            case final detail when home == null || detail.origin == home.origin)
          (
            key: e.key,
            item: ApiVideoItem.fromJson(
              asJsonMap(e.value.data['item']),
              home: detail,
            ),
            clock: apiVideoInt(e.value.data['addedAt'], e.value.clock),
          ),
  ];
}

class VideoLibraryStore extends ChangeNotifier {
  /// Shared bookshelf folders accept titles from every video plugin. Existing
  /// source-specific folders keep their identities and memberships unchanged.
  static const sharedFolderSource = '__breeze_all_video_sources__';
  VideoLibraryStore({this.deviceId, this.storageKey = prefsKey});
  static final shared = VideoLibraryStore();
  static const prefsKey = 'breeze.video.library.v1';
  final String? deviceId;
  final String storageKey;
  Future<void>? _pending;
  static String itemKey(String source, String id) => jsonEncode([source, id]);
  static String membershipKey(String item, String folder) =>
      jsonEncode([item, folder]);

  Future<VideoLibrarySnapshot> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null) return VideoLibrarySnapshot();
    if (utf8.encode(raw).length > VideoLibrarySnapshot.maxBytes) {
      throw const FormatException('Video library is too large');
    }
    return VideoLibrarySnapshot.fromJson(asJsonMap(jsonDecode(raw)));
  }

  Future<VideoLibrarySnapshot> read() async {
    await _pending?.catchError((Object _) {});
    return _read();
  }

  Future<void> _change(
    VideoLibrarySnapshot Function(VideoLibrarySnapshot, String, int) mutate, {
    Future<void> Function(String? before, String after)? beforeWrite,
  }) => _queueWrite(() async {
    final current = await _read(),
        device = deviceId ?? await ensureSyncDeviceId();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final clock = (current.maxClock >= now ? current.maxClock : now) + 1;
    final next = mutate(current, device, clock);
    if (identical(next, current)) return;
    // Validate before replacing the only persisted copy.
    final normalized = VideoLibrarySnapshot.fromJson(next.toJson());
    final data = videoLibrarySnapshotEncoding(normalized);
    if (utf8.encode(data).length > VideoLibrarySnapshot.maxBytes) {
      throw const FormatException('Video library is too large');
    }
    final prefs = await SharedPreferences.getInstance();
    if (beforeWrite != null) {
      await beforeWrite(prefs.getString(storageKey), data);
    }
    if (!await prefs.setString(storageKey, data)) {
      throw StateError('library_save_failed');
    }
    notifyListeners();
  });

  Future<T> _queueWrite<T>(Future<T> Function() write) {
    final operation = (_pending ?? Future<void>.value())
        .catchError((Object _) {})
        .then((_) => write());
    final pending = operation.then<void>((_) {});
    _pending = pending;
    void release() {
      if (identical(_pending, pending)) _pending = null;
    }

    unawaited(
      pending.then(
        (_) => release(),
        onError: (Object _, StackTrace _) => release(),
      ),
    );
    return operation;
  }

  /// Holds the existing write queue while artwork commits, so a delayed editor
  /// cannot attach an image after the folder has been renamed or deleted.
  Future<T> withCurrentFolder<T>(
    String id,
    VideoLibraryEntry expected,
    Future<T> Function() commit,
  ) => _queueWrite(() async {
    final latest = (await _read()).folders[id];
    if (latest == null ||
        latest.deleted ||
        _canonical(latest.toJson()) != _canonical(expected.toJson())) {
      throw StateError('folder_operation_expired');
    }
    return commit();
  });

  /// Replace the library after validation, serialized with other library writes.
  Future<void> replaceSnapshot(VideoLibrarySnapshot snapshot) =>
      updateSnapshot((_) => snapshot);

  Future<void> merge(VideoLibrarySnapshot remote) =>
      updateSnapshot((current) => current.merged(remote));

  /// Compute a sync/import update and journal its exact values in the same
  /// queue slot as the write. Local favorite edits can only land on either side.
  Future<void> updateSnapshot(
    VideoLibrarySnapshot Function(VideoLibrarySnapshot current) update, {
    Future<void> Function(String? before, String after)? beforeWrite,
  }) => _change((current, _, _) => update(current), beforeWrite: beforeWrite);

  Future<void> restoreSnapshotIfCurrent(String? expected, String? before) =>
      _queueWrite(() async {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getString(storageKey) != expected || before == expected) {
          return;
        }
        final saved = before == null
            ? await prefs.remove(storageKey)
            : await prefs.setString(storageKey, before);
        if (!saved) throw StateError('library_save_failed');
        notifyListeners();
      });

  Future<String> createFolder(String source, String name) async {
    final id = const Uuid().v4();
    await _change((current, device, clock) {
      final cleaned = _folderName(current, source, name);
      return VideoLibrarySnapshot(
        favorites: current.favorites,
        memberships: current.memberships,
        tracking: current.tracking,
        folders: {
          ...current.folders,
          id: VideoLibraryEntry(
            clock: clock,
            device: device,
            deleted: false,
            data: {'id': id, 'source': source, 'name': cleaned},
          ),
        },
      );
    });
    return id;
  }

  String _folderName(
    VideoLibrarySnapshot snapshot,
    String source,
    String name, [
    String? except,
  ]) {
    final clean = name.trim();
    if (clean.isEmpty ||
        clean.length > 60 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(clean)) {
      throw StateError('folder_name_invalid');
    }
    if (snapshot
        .foldersFor(source)
        .entries
        .any(
          (e) =>
              e.key != except &&
              '${e.value.data['name']}'.toLowerCase() == clean.toLowerCase(),
        )) {
      throw StateError('folder_exists');
    }
    return clean;
  }

  Future<void> renameFolder(String id, String name) =>
      _change((current, device, clock) {
        final folder = current.folders[id];
        if (folder == null || folder.deleted) {
          throw StateError('folder_unavailable');
        }
        final clean = _folderName(
          current,
          folder.data['source'] as String,
          name,
          id,
        );
        return VideoLibrarySnapshot(
          favorites: current.favorites,
          memberships: current.memberships,
          tracking: current.tracking,
          folders: {
            ...current.folders,
            id: VideoLibraryEntry(
              clock: clock,
              device: device,
              deleted: false,
              data: {...folder.data, 'name': clean},
            ),
          },
        );
      });

  /// Removing a folder never removes its films; they remain in All/Unfiled.
  Future<void> deleteFolder(String id) async {
    await _change((current, device, clock) {
      final folder = current.folders[id];
      if (folder == null || folder.deleted) return current;
      return VideoLibrarySnapshot(
        favorites: current.favorites,
        memberships: current.memberships,
        tracking: current.tracking,
        folders: {
          ...current.folders,
          id: VideoLibraryEntry(
            clock: clock,
            device: device,
            deleted: true,
            data: folder.data,
          ),
        },
      );
    });
    final artwork = LocalAppearanceImages.instance;
    final key = FolderCoverIdentity.video(id);
    if (artwork.paths.value.containsKey(key)) await artwork.remove(key);
  }

  Future<void> setFavorite(
    String source,
    ApiVideoItem item,
    bool favorite, {
    Set<String>? folderIds,
  }) => _change((current, device, clock) {
    final key = itemKey(source, item.id),
        memberships = {...current.memberships},
        tracking = {...current.tracking};
    if (tracking[key] case final previous? when !favorite) {
      tracking[key] = VideoLibraryEntry(
        clock: clock,
        device: device,
        deleted: true,
        data: previous.data,
      );
    }
    final validFolders = current.foldersFor(source).keys.toSet();
    if (folderIds != null && !validFolders.containsAll(folderIds)) {
      throw StateError('folder_unavailable');
    }
    if (!favorite || folderIds != null) {
      final desired = favorite ? folderIds! : <String>{};
      final existing = current.foldersOf(key);
      for (final id in {...existing, ...desired}) {
        final link = membershipKey(key, id);
        memberships[link] = VideoLibraryEntry(
          clock: clock,
          device: device,
          deleted: !desired.contains(id),
          data: {'itemKey': key, 'folderId': id},
        );
      }
    }
    return VideoLibrarySnapshot(
      folders: current.folders,
      memberships: memberships,
      tracking: tracking,
      favorites: {
        ...current.favorites,
        key: VideoLibraryEntry(
          clock: clock,
          device: device,
          deleted: !favorite,
          data: {
            'source': source,
            'item': _itemWithKnownDuration(
              item,
              current.favorites[key]?.data['item'],
            ),
            'addedAt': current.contains(source, item.id)
                ? apiVideoInt(
                    current.favorites[key]?.data['addedAt'],
                    current.favorites[key]!.clock,
                  )
                : clock,
          },
        ),
      },
    );
  });

  /// Explicit import adds public titles and folder memberships atomically.
  /// Existing favorites keep their original order, metadata and other folders.
  Future<({int added, int existing})> importFavorites(
    String source,
    List<ApiVideoItem> items, {
    Set<String> folderIds = const {},
  }) async {
    var added = 0, existing = 0;
    await _change((current, device, clock) {
      if (items.isEmpty || items.length > 10000) {
        throw ArgumentError.value(items.length, 'items');
      }
      if (!current.foldersFor(source).keys.toSet().containsAll(folderIds)) {
        throw StateError('folder_unavailable');
      }
      final favorites = {...current.favorites},
          memberships = {...current.memberships};
      for (final item in {for (final item in items) item.id: item}.values) {
        final key = itemKey(source, item.id), previous = favorites[key];
        if (previous == null || previous.deleted) {
          added++;
          favorites[key] = VideoLibraryEntry(
            clock: clock,
            device: device,
            deleted: false,
            data: {
              'source': source,
              'item': _itemWithKnownDuration(item, previous?.data['item']),
              'addedAt': clock,
            },
          );
        } else {
          existing++;
        }
        for (final folder in folderIds) {
          final link = membershipKey(key, folder);
          if (memberships[link]?.deleted == false) continue;
          memberships[link] = VideoLibraryEntry(
            clock: clock,
            device: device,
            deleted: false,
            data: {'itemKey': key, 'folderId': folder},
          );
        }
      }
      return VideoLibrarySnapshot(
        favorites: favorites,
        folders: current.folders,
        memberships: memberships,
        tracking: current.tracking,
      );
    });
    return (added: added, existing: existing);
  }

  /// Batch organization adds memberships without replacing each item's folders.
  Future<void> addToFolders(Set<String> itemKeys, Set<String> folderIds) =>
      _change((current, device, clock) {
        if (itemKeys.isEmpty || folderIds.isEmpty) return current;
        final memberships = {...current.memberships};
        for (final key in itemKeys) {
          final item = current.favorites[key];
          if (item == null || item.deleted) continue;
          if (!current
              .foldersFor(item.data['source'] as String)
              .keys
              .toSet()
              .containsAll(folderIds)) {
            throw StateError('folder_unavailable');
          }
          for (final id in folderIds) {
            final link = membershipKey(key, id);
            if (memberships[link]?.deleted == false) continue;
            memberships[link] = VideoLibraryEntry(
              clock: clock,
              device: device,
              deleted: false,
              data: {'itemKey': key, 'folderId': id},
            );
          }
        }
        return VideoLibrarySnapshot(
          favorites: current.favorites,
          folders: current.folders,
          memberships: memberships,
          tracking: current.tracking,
        );
      });

  Future<void> assignFolders(Set<String> itemKeys, Set<String> folderIds) =>
      _change((current, device, clock) {
        final memberships = {...current.memberships};
        for (final key in itemKeys) {
          final item = current.favorites[key];
          if (item == null || item.deleted) continue;
          if (!current
              .foldersFor(item.data['source'] as String)
              .keys
              .toSet()
              .containsAll(folderIds)) {
            throw StateError('folder_unavailable');
          }
          for (final id in {...current.foldersOf(key), ...folderIds}) {
            memberships[membershipKey(key, id)] = VideoLibraryEntry(
              clock: clock,
              device: device,
              deleted: !folderIds.contains(id),
              data: {'itemKey': key, 'folderId': id},
            );
          }
        }
        return VideoLibrarySnapshot(
          favorites: current.favorites,
          folders: current.folders,
          memberships: memberships,
          tracking: current.tracking,
        );
      });

  Future<void> removeFavorites(Set<String> keys) =>
      _change((current, device, clock) {
        final favorites = {...current.favorites},
            memberships = {...current.memberships},
            tracking = {...current.tracking};
        for (final key in keys) {
          final value = favorites[key];
          if (value == null || value.deleted) continue;
          favorites[key] = VideoLibraryEntry(
            clock: clock,
            device: device,
            deleted: true,
            data: value.data,
          );
          if (tracking[key] case final previous?) {
            tracking[key] = VideoLibraryEntry(
              clock: clock,
              device: device,
              deleted: true,
              data: previous.data,
            );
          }
          for (final link in memberships.entries.toList()) {
            if (link.value.data['itemKey'] == key) {
              memberships[link.key] = VideoLibraryEntry(
                clock: clock,
                device: device,
                deleted: true,
                data: link.value.data,
              );
            }
          }
        }
        return VideoLibrarySnapshot(
          favorites: favorites,
          folders: current.folders,
          memberships: memberships,
          tracking: tracking,
        );
      });

  Future<void> setFollow(String source, ApiVideoItem item, bool follow) =>
      _change((current, device, clock) {
        final key = itemKey(source, item.id), previous = current.tracking[key];
        if (!follow && previous == null) return current;
        if (follow && !item.canFollow) throw StateError('item_cannot_follow');
        final keys = item.episodeKeys.toList();
        return VideoLibrarySnapshot(
          folders: current.folders,
          memberships: current.memberships,
          favorites: {
            ...current.favorites,
            if (follow)
              key: VideoLibraryEntry(
                clock: clock,
                device: device,
                deleted: false,
                data: {
                  'source': source,
                  'item': _itemWithKnownDuration(
                    item,
                    current.favorites[key]?.data['item'],
                  ),
                  'addedAt': current.contains(source, item.id)
                      ? apiVideoInt(
                          current.favorites[key]?.data['addedAt'],
                          current.favorites[key]!.clock,
                        )
                      : clock,
                },
              ),
          },
          tracking: {
            ...current.tracking,
            key: VideoLibraryEntry(
              clock: clock,
              device: device,
              deleted: !follow,
              data: {
                'itemKey': key,
                'known': keys,
                'latest': keys,
                'checkedAt': DateTime.now().millisecondsSinceEpoch,
                'available': item.lines.isNotEmpty,
              },
            ),
          },
        );
      });

  /// The persisted keys already carry the chosen source line. Keep that
  /// identity across reorder, partial responses and sync with older clients.
  static Set<String> _followEpisodeKeys(
    ApiVideoItem item,
    VideoLibraryEntry previous,
  ) {
    for (final field in const ['latest', 'known']) {
      for (final key in previous.data[field] as List) {
        try {
          final parts = jsonDecode(key as String);
          if (parts is List && parts.length == 2 && parts.first is String) {
            return item.episodeKeysForLine(parts.first as String);
          }
        } on FormatException {
          // Ignore malformed legacy keys when finding the tracked line.
        }
      }
    }
    return item.episodeKeys;
  }

  Future<void> acknowledgeFollows(Set<String> keys) =>
      _change((current, device, clock) {
        final tracking = {...current.tracking};
        var changed = false;
        for (final key in keys) {
          if (current.newEpisodes(key) == 0) continue;
          final previous = current.tracking[key]!;
          tracking[key] = VideoLibraryEntry(
            clock: clock,
            device: device,
            deleted: false,
            data: {...previous.data, 'known': previous.data['latest']},
          );
          changed = true;
        }
        return changed
            ? VideoLibrarySnapshot(
                favorites: current.favorites,
                folders: current.folders,
                memberships: current.memberships,
                tracking: tracking,
              )
            : current;
      });

  /// A successful full-detail read may replace all public metadata, including
  /// explicit empty values. Catalog summaries must not call this entry point:
  /// ApiVideoItem no longer distinguishes an omitted field from an empty one.
  /// Never imports a missing/deleted favorite or moves its original added date.
  Future<void> observeDetails(
    String source,
    List<ApiVideoItem> items, {
    bool acknowledge = false,
  }) => _change((current, device, clock) {
    final favorites = {...current.favorites}, tracking = {...current.tracking};
    var changed = false;
    for (final item in {for (final item in items) item.id: item}.values) {
      final key = itemKey(source, item.id), previous = current.favorites[key];
      if (previous == null || previous.deleted) continue;
      // Compare the exact normalized public snapshot, not runtime playback or
      // browser fields. Repeated enrichment must not write/notify/rebuild again.
      final metadata = _itemWithKnownDuration(
        ApiVideoItem.fromJson(item.toLibraryJson(), home: item.detailUrl),
        previous.data['item'],
      );
      if (_canonical(previous.data['item']) != _canonical(metadata)) {
        favorites[key] = VideoLibraryEntry(
          clock: clock,
          device: device,
          deleted: false,
          data: {...previous.data, 'item': metadata},
        );
        changed = true;
      }
      if (!acknowledge || !current.follows(key)) continue;
      final baseline = current.tracking[key]!,
          keys = _followEpisodeKeys(item, baseline),
          available = keys.isNotEmpty,
          latest = available ? keys.toList() : baseline.data['latest'];
      final next = {
        ...baseline.data,
        'known': available ? latest : baseline.data['known'],
        'latest': latest,
        'available': available,
      };
      final before = {...baseline.data}..remove('checkedAt');
      final comparable = {...next}..remove('checkedAt');
      if (_canonical(before) == _canonical(comparable)) continue;
      tracking[key] = VideoLibraryEntry(
        clock: clock,
        device: device,
        deleted: false,
        data: {...next, 'checkedAt': DateTime.now().millisecondsSinceEpoch},
      );
      changed = true;
    }
    if (!changed) return current;
    return VideoLibrarySnapshot(
      favorites: favorites,
      folders: current.folders,
      memberships: current.memberships,
      tracking: tracking,
    );
  });

  /// Only IDs newly present on the line originally tracked count as updates.
  /// A changed synopsis/time, reorder, CDN token or missing response cannot
  /// produce an update badge. Never resurrect an unfollowed/removed film.
  Future<({int checked, int updated})> observeItems(
    String source,
    List<ApiVideoItem> items, {
    Set<String> missing = const {},
    bool acknowledge = false,
    Map<String, VideoLibraryEntry>? expectedTracking,
    bool Function()? isCurrent,
  }) async {
    var checked = 0, updated = 0;
    await _change((current, device, clock) {
      if (isCurrent?.call() == false) return current;
      final favorites = {...current.favorites},
          tracking = {...current.tracking};
      var changed = false;
      final values = {for (final item in items) item.id: item};
      for (final id in {...values.keys, ...missing}) {
        final key = itemKey(source, id);
        if (!current.follows(key)) continue;
        final previous = current.tracking[key]!, item = values[id];
        if (expectedTracking != null) {
          final expected = expectedTracking[key];
          if (expected == null ||
              expected.clock != previous.clock ||
              expected.device != previous.device ||
              _canonical(expected.data) != _canonical(previous.data))
            continue;
        }
        if (item != null &&
            videoPublicPage(item.detailUrl) !=
                videoPublicPage(
                  Uri.parse(
                    asJsonMap(current.favorites[key]!.data['item'])['detailUrl']
                        as String,
                  ),
                ))
          continue;
        final keys = item == null
            ? const <String>{}
            : _followEpisodeKeys(item, previous);
        final available = keys.isNotEmpty;
        final latest = available ? keys.toList() : previous.data['latest'];
        if (available) {
          checked++;
          final seen = {
            ...previous.data['latest'] as List,
            ...previous.data['known'] as List,
          };
          if (keys.any((key) => !seen.contains(key))) updated++;
        }
        tracking[key] = VideoLibraryEntry(
          clock: clock,
          device: device,
          deleted: false,
          data: {
            'itemKey': key,
            'known': acknowledge && available ? latest : previous.data['known'],
            'latest': latest,
            'checkedAt': DateTime.now().millisecondsSinceEpoch,
            'available': available,
          },
        );
        if (item != null) {
          favorites[key] = VideoLibraryEntry(
            clock: clock,
            device: device,
            deleted: false,
            data: {
              ...current.favorites[key]!.data,
              'item': _itemWithKnownDuration(
                item,
                current.favorites[key]!.data['item'],
              ),
            },
          );
        }
        changed = true;
      }
      if (!changed) return current;
      return VideoLibrarySnapshot(
        favorites: favorites,
        folders: current.folders,
        memberships: current.memberships,
        tracking: tracking,
      );
    });
    return (checked: checked, updated: updated);
  }
}
