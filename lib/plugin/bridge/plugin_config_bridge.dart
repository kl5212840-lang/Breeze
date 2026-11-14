import 'package:zephyr/service/plugin_account_identity.dart';
import 'package:zephyr/network/sync/plugin_account_profiles_data.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'dart:async';
import 'dart:convert';

import 'package:zephyr/main.dart';
import 'package:zephyr/network/http/plugin/qjs_network_route.dart';
import 'package:zephyr/network/sync/plugin_config_merge.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/src/rust/api/qjs.dart';

const _copySource = copyPluginConfigSource;
final _pluginEndpointChanges = StreamController<String>.broadcast();
final _settingsEndpointChanges =
    StreamController<({String source, bool refresh})>.broadcast();
final _pluginEndpointRevisions = <String, int>{};
final _pendingEndpointUpdates = <String, int>{};
final _deferredEndpointChanges = <String>{};
Stream<String> get pluginEndpointChanges => _pluginEndpointChanges.stream;
Stream<({String source, bool refresh})> get settingsPluginEndpointChanges =>
    _settingsEndpointChanges.stream;
int pluginEndpointRevision(String source) =>
    _pluginEndpointRevisions[canonicalQjsSource(source)] ?? 0;

bool isPluginEndpointUpdating(String source) =>
    _pendingEndpointUpdates.containsKey(canonicalQjsSource(source));

/// Invalidate old account reads before a runtime applies its new endpoint.
/// A bridge save can precede the in-memory update in the plugin callback.
int? beginPluginEndpointUpdate(String source, {bool supersede = false}) {
  source = canonicalQjsSource(source);
  if (!supersede && _pendingEndpointUpdates.containsKey(source)) return null;
  final revision = pluginEndpointRevision(source) + 1;
  _pluginEndpointRevisions[source] = revision;
  _pendingEndpointUpdates[source] = revision;
  return revision;
}

void finishPluginEndpointUpdate(
  String source,
  int revision, {
  required bool refreshSettings,
  bool refreshProfile = false,
}) {
  source = canonicalQjsSource(source);
  if (_pendingEndpointUpdates[source] != revision) return;
  _pendingEndpointUpdates.remove(source);
  final changed = _deferredEndpointChanges.remove(source) || refreshProfile;
  if (changed) _pluginEndpointChanges.add(source);
  _settingsEndpointChanges.add((
    source: source,
    refresh: refreshSettings || changed,
  ));
}

Object? _copyEffectiveRoute(Map<String, dynamic> configuration) {
  final choice = configuration['api.domain'];
  return choice == 'auto' ? configuration['network.autoRoute.v1'] : choice;
}

bool _copyEndpointChanged(
  Map<String, dynamic> previous,
  Map<String, dynamic> current,
) =>
    _copyEffectiveRoute(previous) != _copyEffectiveRoute(current) ||
    previous['api.platform'] != current['api.platform'];

void _publishEndpointChange(String source) {
  if (isPluginEndpointUpdating(source)) {
    // Wait for the plugin callback to finish before either surface rereads.
    _deferredEndpointChanges.add(source);
  } else {
    _pluginEndpointRevisions[source] = pluginEndpointRevision(source) + 1;
    _pluginEndpointChanges.add(source);
    _settingsEndpointChanges.add((source: source, refresh: true));
  }
}

/// External restore writes ObjectBox directly. Compare against committed
/// storage so a failed or rolled-back restore never publishes an endpoint.
void notifyCopyEndpointAfterExternalRestore(String? previousConfig) {
  if (_copyEndpointChanged(
    _decodeObjectMap(previousConfig ?? ''),
    readHostPluginConfiguration(_copySource),
  )) {
    _publishEndpointChange(_copySource);
  }
}

String onSavePluginConfig(
  String name,
  String key,
  String value, {
  bool fromRuntime = true,
}) {
  final runtime = name;
  name = canonicalQjsSource(name);
  if (fromRuntime && !pluginSessionWriteFence.permits(name, runtime)) {
    throw const PluginSessionChanged();
  }
  final box = objectbox.pluginConfigBox;

  // 使用同步事务确保原子性
  final endpointChanged = objectbox.store.runInTransaction(TxMode.write, () {
    var entity = box.query(PluginConfig_.name.equals(name)).build().findFirst();
    final parsedValue = _decodeMaybeJson(value);
    final previous = _decodeObjectMap(entity?.config ?? '');
    if (isActivePluginAccountField(key) || key == pluginAccountProfilesKey) {
      if (!fromRuntime &&
          isActivePluginAccountField(key) &&
          pluginSessionWriteFence.isChanging(name)) {
        throw const PluginSessionChanged();
      }
      validatePluginAccountProfilesConfiguration(previous);
      if (key == pluginAccountProfilesKey) {
        if (fromRuntime) throw const PluginSessionChanged();
        validatePluginAccountProfilesConfiguration({
          pluginAccountProfilesKey: parsedValue,
        });
        PluginAccountProfilesData.parse(parsedValue, source: name);
      }
    }

    final data = updatePluginConfigField(previous, key, parsedValue);
    entity ??= PluginConfig(name: name, config: '{}');
    entity.config = jsonEncode(data);

    box.put(entity);
    return name == _copySource && _copyEndpointChanged(previous, data);
  });
  if (endpointChanged) _publishEndpointChange(name);
  if (isActivePluginAccountField(key))
    PluginAccountIdentities.accountConfigurationChanged(name);
  return '{"ok":true}';
}

String onLoadPluginConfig(String name, String key, String fallback) {
  name = canonicalQjsSource(name);
  final box = objectbox.pluginConfigBox;

  return objectbox.store.runInTransaction(TxMode.read, () {
    final entity = box
        .query(PluginConfig_.name.equals(name))
        .build()
        .findFirst();

    final data = _decodeObjectMap(entity?.config ?? '');
    final value = key.isEmpty
        ? visiblePluginConfig(data)
        : key == pluginConfigSyncFields || key == pluginAccountProfilesKey
        ? _decodeMaybeJson(fallback)
        : data.containsKey(key)
        ? data[key]
        : _decodeMaybeJson(fallback);

    return '{"ok":true,"value":${jsonEncode(value)}}';
  });
}

Map<String, dynamic> _decodeObjectMap(String raw) {
  final text = raw.trim();
  if (text.isEmpty) {
    return <String, dynamic>{};
  }
  try {
    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
  } catch (_) {}
  return <String, dynamic>{};
}

dynamic _decodeMaybeJson(String value) {
  final text = value.trim();
  if (text.isEmpty) {
    return value;
  }

  try {
    return jsonDecode(text);
  } catch (_) {
    return value;
  }
}

void _register(
  String functionName,
  FutureOr<String> Function(String) dartCallback,
) {
  registerFunction(functionName: functionName, dartCallback: dartCallback);
}

void registerPersistentCallbacks() {
  _register('save_plugin_config', (String data) async {
    final args = jsonDecode(data) as List<dynamic>;
    final runtime = args[0] as String;
    final pluginName = args[1] as String;
    final value = args[2] as String;
    return onSavePluginConfig(runtime, pluginName, value);
  });

  _register('load_plugin_config', (String data) async {
    final args = jsonDecode(data) as List<dynamic>;
    final runtime = args[0] as String;
    final pluginName = args[1] as String;
    final fallback = args[2] as String;
    return onLoadPluginConfig(runtime, pluginName, fallback);
  });
}

Future<void> savePluginConfigValue(
  String pluginName,
  String key,
  dynamic value,
) async {
  onSavePluginConfig(pluginName, key, jsonEncode(value), fromRuntime: false);
}

void savePluginConfigValueSync(String pluginName, String key, dynamic value) {
  onSavePluginConfig(pluginName, key, jsonEncode(value), fromRuntime: false);
}

T loadPluginConfigValue<T>(
  String pluginName,
  String key, {
  required T fallback,
}) {
  final raw = onLoadPluginConfig(pluginName, key, jsonEncode(fallback));
  final parsed = jsonDecode(raw) as Map<String, dynamic>;
  final value = parsed['value'];
  if (value is T) {
    return value;
  }
  return fallback;
}

/// Host-only snapshot; saved account profiles are never exposed to plugin JS.
Map<String, dynamic> readHostPluginConfiguration(String source) {
  source = canonicalQjsSource(source);
  final query = objectbox.pluginConfigBox
      .query(PluginConfig_.name.equals(source))
      .build();
  try {
    return _decodeObjectMap(query.findFirst()?.config ?? '');
  } finally {
    query.close();
  }
}

Map<String, dynamic> activePluginAccountSnapshot(Map<String, dynamic> data) => {
  for (final entry in data.entries)
    if (isActivePluginAccountField(entry.key)) entry.key: entry.value,
};

/// All active fields replace as one DB transaction. Non-account preferences,
/// profiles and their independent revisions survive the compatibility view.
void replaceActivePluginAccount(
  String source,
  Map<String, dynamic> replacement, {
  String? expectedDigest,
  int? expectedGeneration,
}) {
  source = canonicalQjsSource(source);
  if (replacement.keys.any((key) => !isActivePluginAccountField(key))) {
    throw const PluginSessionChanged();
  }
  final owner = source;
  objectbox.store.runInTransaction(TxMode.write, () {
    if (expectedGeneration != null &&
        pluginSessionWriteFence.generation(owner) != expectedGeneration) {
      throw const PluginSessionChanged();
    }
    final query = objectbox.pluginConfigBox
        .query(PluginConfig_.name.equals(owner))
        .build();
    PluginConfig? row;
    try {
      row = query.findFirst();
    } finally {
      query.close();
    }
    var data = _decodeObjectMap(row?.config ?? '');
    validatePluginAccountProfilesConfiguration(data);
    if (expectedDigest != null &&
        accountProfileDigest(activePluginAccountSnapshot(data)) !=
            expectedDigest) {
      throw const PluginSessionChanged();
    }
    final keys = {
      ...data.keys.where(isActivePluginAccountField),
      ...replacement.keys,
    };
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final key in keys) {
      data = replacement.containsKey(key)
          ? updatePluginConfigField(data, key, replacement[key], nowMs: now)
          : deletePluginConfigField(data, key, nowMs: now);
    }
    final target = row ?? PluginConfig(name: owner, config: '{}');
    target.config = jsonEncode(data);
    objectbox.pluginConfigBox.put(target);
  });
  PluginAccountIdentities.accountConfigurationChanged(source);
}
