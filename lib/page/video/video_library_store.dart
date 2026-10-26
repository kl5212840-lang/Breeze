import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:zephyr/network/sync/sync_device_id.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/util/json/json_value.dart';

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
      if (!e.value.deleted && e.value.data['source'] == source) e.key: e.value,
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

  Map<String, Set<String>> _indexFolders() {
    final result = <String, Set<String>>{};
    for (final e in memberships.values) {
      final key = e.data['itemKey'], folder = e.data['folderId'];
      if (!e.deleted &&
          folders[folder]?.deleted == false &&
          folders[folder]?.data['source'] == favorites[key]?.data['source']) {
        (result[key as String] ??= <String>{}).add(folder as String);
      }
    }
    return result;
  }

  Set<String> foldersOf(String itemKey) =>
      Set.unmodifiable(_foldersByItem[itemKey] ?? const <String>{});

  List<({String key, ApiVideoItem item, int clock})> itemsFor(String source) =>
      [
        for (final e in favorites.entries)
          if (!e.value.deleted && e.value.data['source'] == source)
            (
              key: e.key,
              item: ApiVideoItem.fromJson(
                asJsonMap(e.value.data['item']),
                home: Uri.parse(
                  asJsonMap(e.value.data['item'])['detailUrl'] as String,
                ),
              ),
              clock: apiVideoInt(e.value.data['addedAt'], e.value.clock),
            ),
      ];
}

class VideoLibraryStore extends ChangeNotifier {
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
    VideoLibrarySnapshot Function(VideoLibrarySnapshot, String, int) mutate,
  ) {
    final operation = (_pending ?? Future<void>.value())
        .catchError((Object _) {})
        .then((_) async {
          final current = await _read(),
              device = deviceId ?? await ensureSyncDeviceId();
          final now = DateTime.now().toUtc().millisecondsSinceEpoch;
          final clock = (current.maxClock >= now ? current.maxClock : now) + 1;
          final next = mutate(current, device, clock);
          if (identical(next, current)) return;
          // Validate before replacing the only persisted copy.
          final normalized = VideoLibrarySnapshot.fromJson(next.toJson());
          final data = _canonical(normalized.toJson());
          if (utf8.encode(data).length > VideoLibrarySnapshot.maxBytes) {
            throw const FormatException('Video library is too large');
          }
          final prefs = await SharedPreferences.getInstance();
          if (!await prefs.setString(storageKey, data)) {
            throw StateError('library_save_failed');
          }
          notifyListeners();
        });
    _pending = operation;
    void release() {
      if (identical(_pending, operation)) _pending = null;
    }

    unawaited(
      operation.then(
        (_) => release(),
        onError: (Object _, StackTrace _) => release(),
      ),
    );
    return operation;
  }

  Future<void> merge(VideoLibrarySnapshot remote) =>
      _change((current, _, _) => current.merged(remote));

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
  Future<void> deleteFolder(String id) => _change((current, device, clock) {
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
            'item': item.toLibraryJson(),
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
                  'item': item.toLibraryJson(),
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

  /// Only IDs newly present in the first real line count as new episodes.
  /// A changed synopsis/time, reorder, CDN token or missing response cannot
  /// produce an update badge. Never resurrect an unfollowed/removed film.
  Future<void> observeItems(
    String source,
    List<ApiVideoItem> items, {
    Set<String> missing = const {},
    bool acknowledge = false,
  }) => _change((current, device, clock) {
    final favorites = {...current.favorites}, tracking = {...current.tracking};
    var changed = false;
    final values = {for (final item in items) item.id: item};
    for (final id in {...values.keys, ...missing}) {
      final key = itemKey(source, id);
      if (!current.follows(key)) continue;
      final previous = current.tracking[key]!, item = values[id];
      final available = item != null && item.lines.isNotEmpty;
      final latest = available
          ? item.episodeKeys.toList()
          : previous.data['latest'];
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
          data: {...current.favorites[key]!.data, 'item': item.toLibraryJson()},
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
}
