import 'package:zephyr/network/sync/plugin_account_profiles_data.dart';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:zephyr/network/sync/sync_direction.dart';

/// Reserved host-only field persisted alongside plugin settings.
const pluginConfigSyncFields = '__breezeSyncFields';

Map<String, dynamic>? _object(String raw) {
  try {
    final value = jsonDecode(raw);
    return value is Map<String, dynamic> ? value : null;
  } catch (_) {
    return null;
  }
}

dynamic _canonical(dynamic value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List) return value.map(_canonical).toList();
  return value;
}

String _digest(dynamic value) =>
    sha256.convert(utf8.encode(jsonEncode(_canonical(value)))).toString();

Map<String, dynamic> _metadata(Map<String, dynamic> data) {
  final value = data[pluginConfigSyncFields];
  return value is Map ? Map<String, dynamic>.from(value) : {};
}

/// Applies one plugin write. Explicit null and empty values are retained.
/// Identical values retain their previous revision.
Map<String, dynamic> updatePluginConfigField(
  Map<String, dynamic> data,
  String key,
  dynamic value, {
  int? nowMs,
}) {
  final result = Map<String, dynamic>.from(data);
  if (key.isEmpty || key == pluginConfigSyncFields) return result;
  if (result.containsKey(key) && _digest(result[key]) == _digest(value)) {
    return result;
  }
  final meta = _metadata(result);
  final old = meta[key];
  final oldTime = old is Map && old['updatedAt'] is int
      ? old['updatedAt'] as int
      : 0;
  final clock = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  meta[key] = {
    'updatedAt': clock > oldTime ? clock : oldTime + 1,
    'hash': _digest(value),
  };
  result[key] = value;
  result[pluginConfigSyncFields] = meta;
  return result;
}

/// A profile tombstone also rejects an older client's single-account projection.
/// This sanitizes transport results, never the other device's live cookie store.
Map<String, dynamic> suppressRemovedAccountProjection(
  Map<String, dynamic> data,
) {
  final profiles = PluginAccountProfilesData.parse(
    data[pluginAccountProfilesKey],
  );
  if (profiles == null) return data;
  final identity = pluginAccountBundleIdentity(data);
  final removed = identity is String
      ? profiles.profiles[PluginAccountProfilesData.idFor(
          profiles.source,
          identity,
          '',
        )]
      : null;
  final backup = data['account.backup'];
  final backupId = backup is Map ? backup['profileId'] : null;
  final removedWeb =
      backup is Map &&
      backup['deleted'] != true &&
      (backupId is String
          ? profiles.profiles[backupId]?.deleted == true
          : profiles.profiles.values.any((p) => p.deleted && p.kind == 'web') &&
                !profiles.profiles.values.any(
                  (p) =>
                      !p.deleted &&
                      p.kind == 'web' &&
                      p.bundle['account.backup'] is Map &&
                      accountProfileDigest(
                            (p.bundle['account.backup'] as Map)['cookies'],
                          ) ==
                          accountProfileDigest(backup['cookies']),
                ));
  var result = data;
  for (final key in data.keys.toList()) {
    if (removed?.deleted == true &&
            (key.startsWith('auth.') || key == 'account.credentials') ||
        removedWeb && key == 'account.backup') {
      result = deletePluginConfigField(
        result,
        key,
        nowMs:
            removed?.revision ??
            profiles.profiles.values
                .where((p) => p.deleted)
                .map((p) => p.revision)
                .fold<int>(0, (a, b) => a > b ? a : b),
      );
    }
  }
  return result;
}

/// Removes host metadata before returning a full configuration to a plugin.
Map<String, dynamic> visiblePluginConfig(Map<String, dynamic> data) =>
    Map<String, dynamic>.from(data)
      ..remove(pluginConfigSyncFields)
      ..remove(pluginAccountProfilesKey);

/// Exact host namespaces used by UUID, wrapper and legacy runtime storage.
/// This does not infer a plugin from a private key or a URL.
Set<String> pluginConfigNamesForSource(String source) {
  var value = source.trim();
  final normalized = <String>{};
  while (value.isNotEmpty) {
    normalized.add(value);
    if (value.length < 2 || !value.startsWith('(') || !value.endsWith(')')) {
      break;
    }
    value = value.substring(1, value.length - 1).trim();
  }
  return {
    for (final name in normalized) ...{
      name,
      '($name)',
      'plugin_info_${name.replaceAll('-', '_')}',
      '(plugin_info_${name.replaceAll('-', '_')})',
    },
  };
}

bool _validRevision(dynamic meta, {required bool hasValue, dynamic value}) =>
    meta is Map &&
    meta['updatedAt'] is int &&
    (meta['updatedAt'] as int) >= 0 &&
    (meta['updatedAt'] as int) < 8640000000000000 &&
    (meta['deleted'] == true
        ? !hasValue && meta['hash'] == _digest(null)
        : hasValue && meta['hash'] == _digest(value));

/// A field deletion is a first-class revision even though its visible value is
/// absent. A later explicit plugin write creates a new live field revision.
Map<String, dynamic> deletePluginConfigField(
  Map<String, dynamic> data,
  String key, {
  int? nowMs,
  bool localPurge = false,
}) {
  final result = Map<String, dynamic>.from(data);
  if (key.isEmpty || key == pluginConfigSyncFields) return result;
  final metadata = _metadata(result);
  final old = metadata[key];
  if (old is Map &&
      old['deleted'] == true &&
      _validRevision(
        old,
        hasValue: result.containsKey(key),
        value: result[key],
      )) {
    return result;
  }
  final oldTime = old is Map && old['updatedAt'] is int
      ? old['updatedAt'] as int
      : 0;
  final clock = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  final revision = clock > oldTime ? clock : oldTime + 1;
  final hash = _digest(null);
  metadata[key] = {
    'updatedAt': revision,
    'hash': hash,
    'deleted': true,
    if (localPurge) 'localPurge': {'updatedAt': revision, 'hash': hash},
  };
  result.remove(key);
  result[pluginConfigSyncFields] = metadata;
  return result;
}

Map<String, dynamic> deleteAllPluginConfigFields(
  Map<String, dynamic> data, {
  int? nowMs,
  bool localPurge = false,
}) {
  var result = Map<String, dynamic>.from(data);
  final keys = {...data.keys, ..._metadata(data).keys}
    ..remove(pluginConfigSyncFields);
  for (final key in keys) {
    result = deletePluginConfigField(
      result,
      key,
      nowMs: nowMs,
      localPurge: localPurge,
    );
  }
  return result;
}

const copyPluginConfigSource = 'b28da416-f2d4-4208-a85e-8b4c7c648e48';
const _copyAutoRouteField = 'network.autoRoute.v1';
const _copyDeviceRouteFields = {_copyAutoRouteField, 'network.speed.v1'};
final _copyPluginConfigNames = pluginConfigNamesForSource(
  copyPluginConfigSource,
);

/// Mode and request identifier are preferences; probe results belong to the
/// device and network that produced them, including their per-field clocks.
String stripCopyDeviceRouteSettings(String name, String encoded) {
  if (!_copyPluginConfigNames.contains(name.trim())) return encoded;
  final data = _object(encoded);
  if (data == null) return encoded;
  final metadata = _metadata(data);
  var changed = false;
  for (final key in _copyDeviceRouteFields) {
    if (data.containsKey(key) || metadata.containsKey(key)) changed = true;
    data.remove(key);
    metadata.remove(key);
  }
  if (!changed) return encoded;
  if (metadata.isEmpty) {
    data.remove(pluginConfigSyncFields);
  } else {
    data[pluginConfigSyncFields] = metadata;
  }
  return jsonEncode(data);
}

/// Apply portable preferences without replacing this device's measurements.
/// Entering Auto through restore uses this device's own prior manual fallback.
String preserveCopyDeviceRouteSettings(
  String name,
  String? previous,
  String incoming,
) {
  if (!_copyPluginConfigNames.contains(name.trim())) return incoming;
  final portable = stripCopyDeviceRouteSettings(name, incoming);
  final old = previous == null ? null : _object(previous);
  final next = _object(portable);
  if (old == null || next == null) return portable;
  final oldMetadata = _metadata(old), metadata = _metadata(next);
  for (final key in _copyDeviceRouteFields) {
    if (old.containsKey(key)) next[key] = old[key];
    if (oldMetadata.containsKey(key)) metadata[key] = oldMetadata[key];
  }
  if (metadata.isNotEmpty) next[pluginConfigSyncFields] = metadata;
  final oldMode = old['api.domain'];
  if (next['api.domain'] == 'auto' &&
      oldMode is String &&
      oldMode.isNotEmpty &&
      oldMode != 'auto') {
    return jsonEncode(
      updatePluginConfigField(next, _copyAutoRouteField, oldMode),
    );
  }
  return jsonEncode(next);
}

/// Purge provenance is device-only, not a deletion queue or a cloud instruction.
/// Export only the ordinary field revision/tombstone representation.
String pluginConfigForSync(String encoded, {String name = ''}) {
  encoded = stripCopyDeviceRouteSettings(name, encoded);
  final data = _object(encoded);
  if (data == null) return encoded;
  validatePluginAccountProfilesConfiguration(data);
  final metadata = _metadata(data);
  var changed = false;
  for (final key in metadata.keys.toList()) {
    final value = metadata[key];
    if (value is Map && value.containsKey('localPurge')) {
      metadata[key] = Map<String, dynamic>.from(value)..remove('localPurge');
      changed = true;
    }
  }
  if (!changed)
    return data.containsKey(pluginAccountProfilesKey)
        ? jsonEncode(suppressRemovedAccountProjection(data))
        : encoded;
  if (metadata.isNotEmpty) data[pluginConfigSyncFields] = metadata;
  return jsonEncode(suppressRemovedAccountProjection(data));
}

/// A normal merge must not lose the local reinstall guard merely because the
/// same tombstone was read back from an archive without local-only provenance.
String preserveLocalPluginPurgeProvenance(String previous, String incoming) {
  final old = _object(previous), next = _object(incoming);
  if (old == null || next == null) return incoming;
  final oldMetadata = _metadata(old), metadata = _metadata(next);
  var changed = false;
  for (final entry in oldMetadata.entries) {
    final before = entry.value, after = metadata[entry.key];
    if (before is! Map ||
        after is! Map ||
        before['localPurge'] is! Map ||
        before['deleted'] != true ||
        after['deleted'] != true ||
        before['updatedAt'] != after['updatedAt'] ||
        before['hash'] != after['hash'] ||
        !_validRevision(
          after,
          hasValue: next.containsKey(entry.key),
          value: next[entry.key],
        )) {
      continue;
    }
    metadata[entry.key] = {
      ...Map<String, dynamic>.from(after),
      'localPurge': before['localPurge'],
    };
    changed = true;
  }
  if (!changed) return incoming;
  if (metadata.isNotEmpty) next[pluginConfigSyncFields] = metadata;
  return jsonEncode(next);
}

/// Remove only the exact device-generated purge projection after an explicit
/// successful reinstall. Ordinary deletions and later edits remain untouched.
String discardLocalPluginPurgeTombstones(String encoded) {
  final data = _object(encoded);
  if (data == null) return encoded;
  final metadata = _metadata(data);
  var changed = false;
  for (final entry in metadata.entries.toList()) {
    final meta = entry.value;
    final marker = meta is Map ? meta['localPurge'] : null;
    if (meta is Map &&
        marker is Map &&
        meta['deleted'] == true &&
        marker['updatedAt'] == meta['updatedAt'] &&
        marker['hash'] == meta['hash'] &&
        _validRevision(
          meta,
          hasValue: data.containsKey(entry.key),
          value: data[entry.key],
        )) {
      metadata.remove(entry.key);
      changed = true;
    }
  }
  if (!changed) return encoded;
  if (metadata.isEmpty) {
    data.remove(pluginConfigSyncFields);
  } else {
    data[pluginConfigSyncFields] = metadata;
  }
  return jsonEncode(data);
}

/// Merge complete configurations, including absent-valued field tombstones.
/// An unversioned archive cannot certify a write after a versioned deletion.
String mergePluginConfigData(
  String localJSON,
  String remoteJSON, {
  required int localUpdatedAt,
  required int remoteUpdatedAt,
  required bool preferRemoteOnConflict,
  bool protectVersionedLocalFields = false,
  SyncDirection direction = SyncDirection.merge,
}) {
  final local = _object(localJSON), remote = _object(remoteJSON);
  if (local == null) {
    if (remote != null) validatePluginAccountProfilesConfiguration(remote);
    return remote == null
        ? '{}'
        : jsonEncode(suppressRemovedAccountProjection(remote));
  }
  if (remote == null) {
    validatePluginAccountProfilesConfiguration(local);
    return jsonEncode(suppressRemovedAccountProjection(local));
  }
  validatePluginAccountProfilesConfiguration(local);
  validatePluginAccountProfilesConfiguration(remote);
  final lm = _metadata(local), rm = _metadata(remote);
  final result = <String, dynamic>{}, metadata = <String, dynamic>{};
  final keys = {...local.keys, ...remote.keys, ...lm.keys, ...rm.keys}
    ..remove(pluginConfigSyncFields);
  for (final key in keys) {
    final hasLocal = local.containsKey(key),
        hasRemote = remote.containsKey(key);
    final lmeta = lm[key], rmeta = rm[key];
    final lv = _validRevision(lmeta, hasValue: hasLocal, value: local[key]);
    final rv = _validRevision(rmeta, hasValue: hasRemote, value: remote[key]);
    final ld = lv && lmeta['deleted'] == true,
        rd = rv && rmeta['deleted'] == true;
    if (!hasLocal && !hasRemote && !lv && !rv) continue;
    bool chooseRemote;
    if (!hasLocal && !lv) {
      chooseRemote = true;
    } else if (!hasRemote && !rv)
      chooseRemote = false;
    else if (direction == SyncDirection.upload)
      chooseRemote = false;
    else if (direction == SyncDirection.restore)
      chooseRemote = true;
    else if (ld && !rv)
      chooseRemote = false;
    else if (rd && !lv)
      chooseRemote = true;
    else if (protectVersionedLocalFields && lv && !rv)
      chooseRemote = false;
    else {
      final lt = lv ? lmeta['updatedAt'] as int : localUpdatedAt;
      final rt = rv ? rmeta['updatedAt'] as int : remoteUpdatedAt;
      if (lt != rt) {
        chooseRemote = rt > lt;
      } else if (ld != rd)
        chooseRemote = rd;
      else if (lv && rv && lmeta['hash'] != rmeta['hash']) {
        chooseRemote =
            (rmeta['hash'] as String).compareTo(lmeta['hash'] as String) > 0;
      } else
        chooseRemote = preferRemoteOnConflict;
    }
    final deleted = chooseRemote ? rd : ld;
    if (!deleted) result[key] = chooseRemote ? remote[key] : local[key];
    if (chooseRemote ? rv : lv) metadata[key] = chooseRemote ? rmeta : lmeta;
  }
  if (metadata.isNotEmpty) result[pluginConfigSyncFields] = metadata;
  if (result.containsKey(pluginAccountProfilesKey) &&
      local.containsKey(pluginAccountProfilesKey) &&
      remote.containsKey(pluginAccountProfilesKey)) {
    final combined = mergePluginAccountProfiles(
      local[pluginAccountProfilesKey],
      remote[pluginAccountProfilesKey],
    );
    return jsonEncode(
      suppressRemovedAccountProjection(
        updatePluginConfigField(
          result,
          pluginAccountProfilesKey,
          combined,
          nowMs: [
            pluginConfigFieldRevision(local, pluginAccountProfilesKey) ?? 0,
            pluginConfigFieldRevision(remote, pluginAccountProfilesKey) ?? 0,
          ].reduce((a, b) => a > b ? a : b),
        ),
      ),
    );
  }
  return jsonEncode(suppressRemovedAccountProjection(result));
}

/// Preserve a plugin field edited after a restore captured its local baseline.
/// Missing optional incoming fields already retain their previous values through
/// the directed merge; this guard also includes explicit field tombstones.
String preserveInterveningPluginConfigEdits(
  String baselineJSON,
  String currentJSON,
  String incomingJSON,
) {
  final baseline = _object(baselineJSON) ?? {}, current = _object(currentJSON);
  final incoming = _object(incomingJSON);
  if (current == null || incoming == null) return incomingJSON;
  final bm = _metadata(baseline),
      cm = _metadata(current),
      im = _metadata(incoming);
  validatePluginAccountProfilesConfiguration(current);
  validatePluginAccountProfilesConfiguration(incoming);
  final accountKeys = {
    ...baseline.keys,
    ...current.keys,
    ...bm.keys,
    ...cm.keys,
    ...incoming.keys,
    ...im.keys,
  }.where(isActivePluginAccountField).toSet();
  bool changedField(String key) =>
      _digest({
        'present': baseline.containsKey(key),
        'value': baseline[key],
        'meta': bm[key],
      }) !=
      _digest({
        'present': current.containsKey(key),
        'value': current[key],
        'meta': cm[key],
      });
  final accountChanged = accountKeys.any(changedField);

  final keys = {...baseline.keys, ...current.keys, ...bm.keys, ...cm.keys}
    ..remove(pluginConfigSyncFields);
  for (final key in keys) {
    if (key == pluginAccountProfilesKey &&
        current.containsKey(key) &&
        incoming.containsKey(key)) {
      final combined = mergePluginAccountProfiles(current[key], incoming[key]);
      final updated = updatePluginConfigField(incoming, key, combined);
      incoming[key] = updated[key];
      im[key] = _metadata(updated)[key];
      continue;
    }
    if (isActivePluginAccountField(key) && accountChanged) continue;
    if (_digest({
          'present': baseline.containsKey(key),
          'value': baseline[key],
          'meta': bm[key],
        }) ==
        _digest({
          'present': current.containsKey(key),
          'value': current[key],
          'meta': cm[key],
        }))
      continue;
    if (current.containsKey(key)) {
      incoming[key] = current[key];
    } else {
      incoming.remove(key);
    }
    if (cm.containsKey(key)) {
      im[key] = cm[key];
    } else {
      im.remove(key);
    }
  }
  if (accountChanged) {
    for (final key in accountKeys) {
      if (current.containsKey(key))
        incoming[key] = current[key];
      else
        incoming.remove(key);
      if (cm.containsKey(key))
        im[key] = cm[key];
      else
        im.remove(key);
    }
  }
  if (im.isEmpty) {
    incoming.remove(pluginConfigSyncFields);
  } else {
    incoming[pluginConfigSyncFields] = im;
  }
  return jsonEncode(incoming);
}

/// Validated field clock for account-bundle selection; unversioned values do
/// not gain the authority of a versioned deletion through a block timestamp.
int? pluginConfigFieldRevision(Map<String, dynamic> configuration, String key) {
  final meta = _metadata(configuration)[key];
  return _validRevision(
        meta,
        hasValue: configuration.containsKey(key),
        value: configuration[key],
      )
      ? meta['updatedAt'] as int
      : null;
}
