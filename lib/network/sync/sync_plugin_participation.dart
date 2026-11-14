import 'dart:convert';

import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/network/sync/plugin_config_merge.dart';
import 'package:zephyr/network/sync/plugin_portable_scope.dart';
import 'package:zephyr/network/sync/plugin_record_scope.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';

/// Device installation is the only participation decision. Disabled plugins
/// remain installed. This snapshot creates no persisted sync preference.
class SyncPluginParticipation {
  SyncPluginParticipation._(Set<String> sources, this._fingerprint)
    : sources = Set.unmodifiable(sources);
  final Set<String> sources;
  final String _fingerprint;

  static Set<String> _uuids({bool liveOnly = false}) {
    // Property queries avoid materializing installed CJS bundles on each guard.
    final query = objectbox.pluginInfoBox
        .query(liveOnly ? PluginInfo_.isDeleted.equals(false) : null)
        .build();
    final property = query.property(PluginInfo_.uuid);
    try {
      return {
        for (final value in property.find())
          if (value.trim().isNotEmpty) value.trim(),
      };
    } finally {
      property.close();
      query.close();
    }
  }

  static String _currentFingerprint() {
    final local = LocalPluginInstallationState.instance;
    final live = _uuids(liveOnly: true);
    final keys = {..._uuids(), ...local.removedUuids}.toList()..sort();
    return jsonEncode([
      for (final key in keys)
        [
          key,
          live.contains(key),
          local.isRemoved(key),
          local.installationEpoch(key),
          local.isInstalling(key),
        ],
    ]);
  }

  static Future<SyncPluginParticipation> capture() async {
    final local = LocalPluginInstallationState.instance;
    await local.load();
    return SyncPluginParticipation._({
      for (final source in _uuids(liveOnly: true))
        if (!local.isRemoved(source)) source,
    }, _currentFingerprint());
  }

  void check() {
    if (_currentFingerprint() != _fingerprint ||
        sources.any(LocalPluginInstallationState.instance.isInstalling)) {
      throw const PluginLifecycleChanged();
    }
  }
}

Set<String> comicPayloadSources(Map<String, dynamic> data) => {
  for (final field in ['favorites', 'histories', 'follows', 'readPreferences'])
    for (final row in data[field] as List? ?? const [])
      if (row is Map && row['source'] is String) row['source'] as String,
};

/// Choose participant rows from candidate, nonparticipants from retained.
/// This is used in opposite directions for cloud publication and local apply.
/// Both inputs must be validated before projection; no future fields are hidden.
Map<String, dynamic> projectPluginComicData(
  Map<String, dynamic> candidate,
  Map<String, dynamic> retained,
  Set<String> sources,
) {
  final owners = <String, String>{};
  for (final data in [candidate, retained]) {
    for (final field in [
      'favorites',
      'histories',
      'follows',
      'readPreferences',
    ]) {
      for (final row in data[field] as List? ?? const []) {
        if (row is Map &&
            row['uniqueKey'] is String &&
            row['source'] is String) {
          owners[row['uniqueKey'] as String] = row['source'] as String;
        }
      }
    }
  }
  final output = <String, dynamic>{...candidate};
  for (final field in [
    'favorites',
    'histories',
    'follows',
    'readPreferences',
  ]) {
    output[field] = [
      for (final row in candidate[field] as List? ?? const [])
        if (row is Map && sources.contains(row['source']))
          Map<String, dynamic>.from(row),
      for (final row in retained[field] as List? ?? const [])
        if (row is Map && !sources.contains(row['source']))
          Map<String, dynamic>.from(row),
    ];
  }
  output['links'] = [
    for (final row in candidate['links'] as List? ?? const [])
      if (row is Map &&
          (owners[row['comicUniqueKey']] == null ||
              sources.contains(owners[row['comicUniqueKey']])))
        Map<String, dynamic>.from(row),
    for (final row in retained['links'] as List? ?? const [])
      if (row is Map &&
          owners[row['comicUniqueKey']] != null &&
          !sources.contains(owners[row['comicUniqueKey']]))
        Map<String, dynamic>.from(row),
  ];
  // Folders are global/shared, never inferred as owned by a plugin.
  return output;
}

Map<String, dynamic> projectPluginSettingsData(
  Map<String, dynamic> candidate,
  Map<String, dynamic> retained,
  Set<String> sources,
) {
  final names = {
    for (final source in sources) ...pluginConfigNamesForSource(source),
  };
  return {
    ...candidate,
    'pluginInfos': [
      for (final row in candidate['pluginInfos'] as List? ?? const [])
        if (row is Map && sources.contains('${row['uuid'] ?? ''}'.trim()))
          Map<String, dynamic>.from(row),
      for (final row in retained['pluginInfos'] as List? ?? const [])
        if (row is Map && !sources.contains('${row['uuid'] ?? ''}'.trim()))
          Map<String, dynamic>.from(row),
    ],
    'pluginConfigs': [
      for (final row in candidate['pluginConfigs'] as List? ?? const [])
        if (row is Map && names.contains('${row['name'] ?? ''}'.trim()))
          Map<String, dynamic>.from(row),
      for (final row in retained['pluginConfigs'] as List? ?? const [])
        if (row is Map && !names.contains('${row['name'] ?? ''}'.trim()))
          Map<String, dynamic>.from(row),
    ],
  };
}

VideoLibrarySnapshot projectPluginVideoData(
  VideoLibrarySnapshot candidate,
  VideoLibrarySnapshot retained,
  Set<String> sources,
) {
  final all = <String>{
    for (final snapshot in [candidate, retained]) ...{
      for (final row in snapshot.favorites.values)
        if (row.data['source'] is String) row.data['source'] as String,
      for (final row in snapshot.folders.values)
        if (row.data['source'] is String) row.data['source'] as String,
      for (final row in snapshot.memberships.values)
        if (videoItemSource('${row.data['itemKey'] ?? ''}')
            case final String source)
          source,
      for (final key in snapshot.tracking.keys)
        if (videoItemSource(key) case final String source) source,
    },
  };
  return applyVideoRecordExclusions(
    candidate,
    retained,
    all.difference(sources),
  );
}

PortablePreferencesSnapshot projectPluginPortableData(
  PortablePreferencesSnapshot candidate,
  PortablePreferencesSnapshot retained,
  Set<String> sources,
) {
  final ownership = pluginPortableScopes(
    {...candidate.entries, ...retained.entries},
    evidence: [...candidate.entries.values, ...retained.entries.values],
  );
  return PortablePreferencesSnapshot({
    for (final entry in candidate.entries.entries)
      if (ownership[entry.key] == null ||
          sources.contains(ownership[entry.key]!.source))
        entry.key: entry.value,
    for (final entry in retained.entries.entries)
      if (ownership[entry.key] != null &&
          !sources.contains(ownership[entry.key]!.source))
        entry.key: entry.value,
  });
}
