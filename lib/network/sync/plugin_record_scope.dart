import 'dart:convert';

import 'package:zephyr/page/video/video_library_store.dart';

Map<String, dynamic> comicPluginRecords(
  Map<String, dynamic> input,
  String source,
) {
  final result = <String, dynamic>{'version': input['version']};
  final keys = <String>{};
  for (final field in [
    'favorites',
    'histories',
    'follows',
    'readPreferences',
  ]) {
    final rows = (input[field] as List? ?? const [])
        .whereType<Map>()
        .where((row) => row['source'] == source)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    result[field] = rows;
    keys.addAll(rows.map((row) => row['uniqueKey'] as String));
  }
  result['links'] = (input['links'] as List? ?? const [])
      .whereType<Map>()
      .where((row) => keys.contains(row['comicUniqueKey']))
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
  // Comic folders are shared across sources. Their names/membership from other
  // plugins are never treated as owned source data by a scoped clear.
  result['folders'] = <Map<String, dynamic>>[];
  return result;
}

String? videoItemSource(String key) {
  try {
    final value = jsonDecode(key);
    if (value is List &&
        value.length == 2 &&
        value.every((part) => part is String) &&
        (value.first as String).isNotEmpty) {
      return value.first as String;
    }
  } catch (_) {
    /* Unknown identities do not acquire guessed ownership. */
  }
  return null;
}

VideoLibrarySnapshot videoPluginRecords(
  VideoLibrarySnapshot input,
  String source,
) => VideoLibrarySnapshot(
  favorites: {
    for (final entry in input.favorites.entries)
      if (entry.value.data['source'] == source) entry.key: entry.value,
  },
  folders: {
    for (final entry in input.folders.entries)
      if (entry.value.data['source'] == source) entry.key: entry.value,
  },
  memberships: {
    for (final entry in input.memberships.entries)
      if (videoItemSource('${entry.value.data['itemKey'] ?? ''}') == source)
        entry.key: entry.value,
  },
  tracking: {
    for (final entry in input.tracking.entries)
      if (videoItemSource(entry.key) == source) entry.key: entry.value,
  },
);

/// Filters only the local application. The caller retains the complete merged
/// projection for upload; fresh existing local edits in excluded sources stay.
VideoLibrarySnapshot applyVideoRecordExclusions(
  VideoLibrarySnapshot merged,
  VideoLibrarySnapshot local,
  Set<String> excluded,
) {
  Map<String, VideoLibraryEntry> select(
    Map<String, VideoLibraryEntry> all,
    Map<String, VideoLibraryEntry> before,
    String? Function(String, VideoLibraryEntry) source,
  ) => {
    for (final entry in all.entries)
      if (!excluded.contains(source(entry.key, entry.value)))
        entry.key: entry.value,
    for (final entry in before.entries)
      if (excluded.contains(source(entry.key, entry.value)))
        entry.key: entry.value,
  };
  return VideoLibrarySnapshot(
    favorites: select(
      merged.favorites,
      local.favorites,
      (_, value) => value.data['source'] as String?,
    ),
    folders: select(
      merged.folders,
      local.folders,
      (_, value) => value.data['source'] as String?,
    ),
    memberships: select(
      merged.memberships,
      local.memberships,
      (_, value) => videoItemSource('${value.data['itemKey'] ?? ''}'),
    ),
    tracking: select(
      merged.tracking,
      local.tracking,
      (key, _) => videoItemSource(key),
    ),
  );
}
