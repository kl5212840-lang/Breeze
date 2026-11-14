import 'dart:convert';

import 'package:zephyr/network/sync/plugin_config_merge.dart';
import 'package:zephyr/network/sync/sync_direction.dart';

bool isPluginAccountField(String key) =>
    key.startsWith('auth.') || key.startsWith('account.');

Map<String, dynamic> _configuration(String encoded) {
  final decoded = jsonDecode(encoded);
  if (decoded is! Map)
    throw const FormatException('Invalid plugin account configuration');
  return Map<String, dynamic>.from(decoded);
}

Map<String, dynamic> _metadata(Map<String, dynamic> data) =>
    data[pluginConfigSyncFields] is Map
    ? Map<String, dynamic>.from(data[pluginConfigSyncFields] as Map)
    : {};

/// Select a changed auth identity as a bundle. Account A's secret/token must
/// never be combined with account B's identity by independent field clocks.
String mergePluginAccountConfigData(
  String localJSON,
  String remoteJSON, {
  required int localUpdatedAt,
  required int remoteUpdatedAt,
  required bool preferRemoteOnConflict,
  bool protectVersionedLocalFields = false,
  SyncDirection direction = SyncDirection.merge,
}) {
  final merged = mergePluginConfigData(
    localJSON,
    remoteJSON,
    localUpdatedAt: localUpdatedAt,
    remoteUpdatedAt: remoteUpdatedAt,
    preferRemoteOnConflict: preferRemoteOnConflict,
    protectVersionedLocalFields: protectVersionedLocalFields,
    direction: direction,
  );
  Map<String, dynamic> local, remote;
  try {
    local = _configuration(localJSON);
    remote = _configuration(remoteJSON);
  } catch (_) {
    return merged;
  }
  final lm = _metadata(local), rm = _metadata(remote);
  bool hasAuth(Map<String, dynamic> data, Map<String, dynamic> meta) =>
      {...data.keys, ...meta.keys}.any((key) => key.startsWith('auth.'));
  if (!hasAuth(local, lm) || !hasAuth(remote, rm)) return merged;
  final result = _configuration(merged), metadata = _metadata(result);
  Map<String, dynamic> winner;
  if (direction == SyncDirection.upload) {
    winner = local;
  } else if (direction == SyncDirection.restore) {
    winner = remote;
  } else if (local['auth.account'] != remote['auth.account']) {
    // The identity field's existing deletion/revision rule selects the account.
    winner = result['auth.account'] == remote['auth.account'] ? remote : local;
  } else {
    int? latest(Map<String, dynamic> data, Map<String, dynamic> meta) {
      final times = <int>[
        for (final key in {...data.keys, ...meta.keys})
          if (key.startsWith('auth.') &&
              pluginConfigFieldRevision(data, key) != null)
            pluginConfigFieldRevision(data, key)!,
      ]..sort();
      return times.isEmpty ? null : times.last;
    }

    final lt = latest(local, lm), rt = latest(remote, rm);
    if (lt == null && rt != null)
      winner = remote;
    else if (rt == null && lt != null)
      winner = local;
    else if ((lt ?? localUpdatedAt) != (rt ?? remoteUpdatedAt)) {
      winner = (rt ?? remoteUpdatedAt) > (lt ?? localUpdatedAt)
          ? remote
          : local;
    } else {
      String signature(Map<String, dynamic> meta) {
        final keys = meta.keys.where((key) => key.startsWith('auth.')).toList()
          ..sort();
        return keys
            .map((key) => '$key:${meta[key] is Map ? meta[key]['hash'] : ''}')
            .join('|');
      }

      winner = signature(rm).compareTo(signature(lm)) > 0 ? remote : local;
    }
  }
  final winnerMeta = _metadata(winner);
  final authKeys = {
    ...local.keys,
    ...remote.keys,
    ..._metadata(local).keys,
    ..._metadata(remote).keys,
  }.where((key) => key.startsWith('auth.')).toSet();
  for (final key in authKeys) {
    result.remove(key);
    metadata.remove(key);
    if (winner.containsKey(key)) result[key] = winner[key];
    if (winnerMeta.containsKey(key)) metadata[key] = winnerMeta[key];
  }
  if (metadata.isEmpty) {
    result.remove(pluginConfigSyncFields);
  } else {
    result[pluginConfigSyncFields] = metadata;
  }
  return jsonEncode(suppressRemovedAccountProjection(result));
}

/// Automatic rounds publish only account changes. Every remote plugin info,
/// non-account field, unrelated plugin and global settings block is retained.
Map<String, dynamic> mergePluginAccountsForBackup(
  Map<String, dynamic> local,
  Map<String, dynamic> remote, {
  required Set<String> sources,
  required int localUpdatedAt,
  required int remoteUpdatedAt,
}) {
  final names = {
    for (final source in sources) ...pluginConfigNamesForSource(source),
  };
  final rows = <String, Map<String, dynamic>>{
    for (final row in remote['pluginConfigs'] as List? ?? const [])
      if (row is Map) '${row['name']}': Map<String, dynamic>.from(row),
  };
  for (final row in local['pluginConfigs'] as List? ?? const []) {
    if (row is! Map || !names.contains(row['name'])) continue;
    Map<String, dynamic> configuration;
    try {
      configuration = _configuration('${row['config']}');
    } catch (_) {
      continue;
    }
    final meta = _metadata(configuration);
    final account = <String, dynamic>{
      for (final entry in configuration.entries)
        if (isPluginAccountField(entry.key)) entry.key: entry.value,
    };
    final accountMeta = {
      for (final entry in meta.entries)
        if (isPluginAccountField(entry.key)) entry.key: entry.value,
    };
    if (account.isEmpty && accountMeta.isEmpty) continue;
    if (accountMeta.isNotEmpty) account[pluginConfigSyncFields] = accountMeta;
    final name = '${row['name']}';
    final existing = rows[name];
    rows[name] = {
      ...?existing,
      'name': name,
      'config': pluginConfigForSync(
        mergePluginAccountConfigData(
          jsonEncode(account),
          '${existing?['config'] ?? '{}'}',
          localUpdatedAt: localUpdatedAt,
          remoteUpdatedAt: remoteUpdatedAt,
          preferRemoteOnConflict: true,
        ),
      ),
    };
  }
  final ordered = rows.keys.toList()..sort();
  return {
    ...remote,
    'pluginConfigs': [for (final name in ordered) rows[name]!],
    'pluginInfos': remote['pluginInfos'] ?? const [],
  };
}
