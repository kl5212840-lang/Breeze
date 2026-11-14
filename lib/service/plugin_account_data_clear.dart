import 'dart:convert';

import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/plugin_config_merge.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';

/// Prepared within the existing local recovery journal. Its caller owns the
/// ObjectBox transaction and checks the installation publication hold.
class PluginAccountDataClearPlan {
  PluginAccountDataClearPlan._(
    this.source,
    this.epoch,
    this.cloudDelete,
    this._original,
    this._next,
    this.fieldCount,
  );
  final String source;
  final int epoch;
  final bool cloudDelete;
  final List<PluginConfig> _original, _next;
  final int fieldCount;
  int get configCount => cloudDelete ? _next.length : _original.length;

  void persistDatabase() {
    final installations = LocalPluginInstallationState.instance;
    if (installations.installationEpoch(source) != epoch ||
        installations.isInstalling(source)) {
      throw const PluginLifecycleChanged();
    }
    final names = pluginConfigNamesForSource(source);
    final currentRows = objectbox.pluginConfigBox
        .getAll()
        .where((row) => names.contains(row.name.trim()))
        .toList();
    if (currentRows.length != _original.length ||
        !currentRows.every((row) => _original.any((old) => old.id == row.id))) {
      throw const PluginLifecycleChanged();
    }
    // Validate all captured rows before changing any of them. A late plugin
    // callback must never lose a setting entered after the clear was prepared.
    for (final row in _original) {
      final current = objectbox.pluginConfigBox.get(row.id);
      if (current == null ||
          current.name != row.name ||
          current.config != row.config) {
        throw const PluginLifecycleChanged();
      }
    }
    if (cloudDelete) {
      if (_next.isNotEmpty) objectbox.pluginConfigBox.putMany(_next);
    } else {
      objectbox.pluginConfigBox.removeMany(
        _original.map((row) => row.id).toList(),
      );
    }
  }
}

PluginAccountDataClearPlan preparePluginAccountDataClear(
  String source, {
  required bool cloudDelete,
  int? expectedEpoch,
  int? nowMs,
  Iterable<PluginConfig> knownCloudConfigs = const [],
}) {
  source = source.trim();
  final installations = LocalPluginInstallationState.instance;
  final epoch = installations.installationEpoch(source);
  if ((expectedEpoch != null && epoch != expectedEpoch) ||
      installations.isInstalling(source)) {
    throw const PluginLifecycleChanged();
  }
  final names = pluginConfigNamesForSource(source);
  final original = objectbox.pluginConfigBox
      .getAll()
      .where((row) => names.contains(row.name.trim()))
      .map(
        (row) => PluginConfig(id: row.id, name: row.name, config: row.config),
      )
      .toList();
  final next = <PluginConfig>[];
  var fields = 0;
  final grouped = <String, List<PluginConfig>>{};
  for (final row in original) {
    grouped.putIfAbsent(row.name.trim(), () => []).add(row);
  }
  if (cloudDelete) {
    for (final row in knownCloudConfigs) {
      if (!names.contains(row.name.trim())) continue;
      grouped
          .putIfAbsent(row.name.trim(), () => [])
          .add(
            PluginConfig(
              name: row.name.trim(),
              config: pluginConfigForSync(row.config),
            ),
          );
    }
  }
  for (final entry in grouped.entries) {
    Map<String, dynamic>? data;
    for (final row in entry.value) {
      try {
        final value = jsonDecode(row.config);
        if (value is! Map<String, dynamic>) throw const FormatException();
        data = data == null
            ? value
            : jsonDecode(
                    mergePluginConfigData(
                      jsonEncode(data),
                      jsonEncode(value),
                      localUpdatedAt: 0,
                      remoteUpdatedAt: 0,
                      preferRemoteOnConflict: true,
                    ),
                  )
                  as Map<String, dynamic>;
      } catch (_) {
        if (cloudDelete) {
          throw const FormatException(
            'Invalid plugin settings cannot create field deletions',
          );
        }
      }
    }
    if (data == null) {
      if (cloudDelete) {
        throw const FormatException(
          'Invalid plugin settings cannot create field deletions',
        );
      }
      continue;
    }
    fields += visiblePluginConfig(data).length;
    if (cloudDelete) {
      final deleted = jsonEncode(
        deleteAllPluginConfigFields(data, nowMs: nowMs, localPurge: true),
      );
      final locals = original
          .where((row) => row.name.trim() == entry.key)
          .toList();
      if (locals.isEmpty) {
        next.add(PluginConfig(name: entry.key, config: deleted));
      } else
        for (final local in locals) {
          next.add(
            PluginConfig(id: local.id, name: local.name, config: deleted),
          );
        }
    }
  }
  return PluginAccountDataClearPlan._(
    source,
    epoch,
    cloudDelete,
    original,
    next,
    fields,
  );
}

/// Called only after successful explicit installation and before its epoch is
/// advanced. This withdraws matching local purge projections, not remote data.
/// A later field write or an ordinary per-field deletion is preserved.
void discardPluginAccountDeletionTombstones(
  String source, {
  required int expectedEpoch,
}) {
  if (LocalPluginInstallationState.instance.installationEpoch(source) !=
      expectedEpoch) {
    throw const PluginLifecycleChanged();
  }
  final names = pluginConfigNamesForSource(source);
  final changed = <PluginConfig>[];
  for (final row in objectbox.pluginConfigBox.getAll()) {
    if (!names.contains(row.name.trim())) continue;
    final next = discardLocalPluginPurgeTombstones(row.config);
    if (next != row.config) {
      changed.add(PluginConfig(id: row.id, name: row.name, config: next));
    }
  }
  if (changed.isNotEmpty) objectbox.pluginConfigBox.putMany(changed);
}
