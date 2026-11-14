import 'dart:async';
import 'dart:convert';
import 'dart:ui' show FilterQuality;

import 'package:flutter/foundation.dart';
import 'package:objectbox/objectbox.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/http/plugin/qjs_network_route.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';

const bikaPlusSourceId = 'e9f18928-3ba8-4d86-a12e-b53a62f47933';
const bikaExperienceAppearanceKey = 'ui.experienceStyle';
const bikaExperienceArtwork = 'bikaIos2585';
const bikaImageFilterQualityKey = 'ui.imageFilterQuality';
const bikaCategoryGridColumnsKey = 'ui.categoryGridColumns';

int parseBikaCategoryGridColumns(Object? value) =>
    value is int && const {3, 4}.contains(value) ? value : 3;

FilterQuality parseBikaImageFilterQuality(Object? value) => switch (value) {
  'none' => FilterQuality.none,
  'low' => FilterQuality.low,
  'high' => FilterQuality.high,
  _ => FilterQuality.medium,
};

enum SourceExperienceStyle { original, follow }

bool isBikaExperienceSource(String source) =>
    const {bikaPlusSourceId}.contains(canonicalQjsSource(source));

SourceExperienceStyle defaultSourceExperienceStyle(String source) =>
    canonicalQjsSource(source) == bikaPlusSourceId
    ? SourceExperienceStyle.follow
    : SourceExperienceStyle.original;

SourceExperienceStyle parseSourceExperienceStyle(
  Object? value, {
  SourceExperienceStyle fallback = SourceExperienceStyle.original,
}) => switch (value) {
  'follow' => SourceExperienceStyle.follow,
  'original' => SourceExperienceStyle.original,
  _ => fallback,
};

bool supportsBikaExperienceDeclaration(String source, Object? info) {
  if (!isBikaExperienceSource(source) || info is! Map) return false;
  final experience = info['breezeExperience'];
  if (experience is! Map) return false;
  final declaration = experience['bikaExperience'];
  return declaration is Map &&
      declaration['version'] is int &&
      declaration['version'] == 1 &&
      declaration['appearanceKey'] == bikaExperienceAppearanceKey &&
      declaration['loadingArtwork'] == bikaExperienceArtwork;
}

String resolveSourceControlsStyle({
  required String source,
  required Object? pluginInfo,
  required Object? preference,
  required String globalStyle,
}) =>
    supportsBikaExperienceDeclaration(source, pluginInfo) &&
        parseSourceExperienceStyle(
              preference,
              fallback: defaultSourceExperienceStyle(source),
            ) ==
            SourceExperienceStyle.original
    ? 'breeze'
    : globalStyle == 'breeze'
    ? 'breeze'
    : 'system';

/// A name-filtered owned query, notified by ObjectBox entity changes. Unlike
/// QueryBuilder.watch (which leaves its query open on cancel), this owner closes
/// both its stream subscription and query. It never writes a default or config.

class SourceExperiencePreferences extends ChangeNotifier {
  SourceExperiencePreferences({
    required String source,
    PluginRegistryService? registry,
    Store? store,
  }) : source = canonicalQjsSource(source),
       _registry = registry ?? PluginRegistryService.I {
    _style = defaultSourceExperienceStyle(this.source);
    if (!isBikaExperienceSource(this.source)) return;
    final database = store ?? objectbox.store;
    _query = database
        .box<PluginConfig>()
        .query(PluginConfig_.name.equals(this.source))
        .build();
    _refresh();
    _configWatch = database.entityChanges.listen((types) {
      if (types.contains(PluginConfig)) _refresh();
    });
    _registryWatch = _registry.stream.listen((_) => _refresh());
    LocalPluginInstallationState.instance.changes.addListener(_refresh);
  }

  final String source;
  final PluginRegistryService _registry;
  Query<PluginConfig>? _query;
  StreamSubscription<List<Type>>? _configWatch;
  StreamSubscription<Map<String, PluginRuntimeState>>? _registryWatch;
  bool _enabled = false, _disposed = false;
  SourceExperienceStyle _style = SourceExperienceStyle.original;
  FilterQuality _imageFilterQuality = FilterQuality.medium;
  int _categoryGridColumns = 3;
  bool get enabled => _enabled;
  SourceExperienceStyle get style => _style;
  FilterQuality get imageFilterQuality => _imageFilterQuality;
  int get categoryGridColumns => _categoryGridColumns;
  bool get isOriginal => enabled && style == SourceExperienceStyle.original;

  void _refresh() {
    if (_disposed || !isBikaExperienceSource(source)) return;
    final plugin = _registry.getByUuid(source);
    final enabled =
        plugin != null &&
        !plugin.isDeleted &&
        plugin.isEnabled &&
        supportsBikaExperienceDeclaration(
          source,
          _registry.getCachedPluginInfo(source),
        );
    var style = _style;
    var quality = _imageFilterQuality;
    var columns = _categoryGridColumns;
    try {
      final row = _query!.findFirst();
      Object? value, imageValue, columnsValue;
      if (row != null) {
        try {
          final data = jsonDecode(row.config);
          if (data is Map) {
            value = data[bikaExperienceAppearanceKey];
            imageValue = data[bikaImageFilterQualityKey];
            columnsValue = data[bikaCategoryGridColumnsKey];
          }
        } on FormatException {
          /* Invalid persisted data safely uses the default. */
        }
      }
      style = parseSourceExperienceStyle(
        value,
        fallback: defaultSourceExperienceStyle(source),
      );
      quality = parseBikaImageFilterQuality(imageValue);
      columns = source == bikaPlusSourceId
          ? parseBikaCategoryGridColumns(columnsValue)
          : 3;
    } catch (_) {
      // A storage read failure retains the last valid display choice. Removal
      // still disables this capability independently of the config read.
    }
    if (enabled == _enabled &&
        style == _style &&
        quality == _imageFilterQuality &&
        columns == _categoryGridColumns)
      return;
    _enabled = enabled;
    _style = style;
    _imageFilterQuality = quality;
    _categoryGridColumns = columns;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_configWatch?.cancel());
    unawaited(_registryWatch?.cancel());
    _query?.close();
    _query = null;
    if (isBikaExperienceSource(source)) {
      LocalPluginInstallationState.instance.changes.removeListener(_refresh);
    }
    super.dispose();
  }
}

/// Covers outside a source route share one source-filtered watcher rather than
/// creating a database query per thumbnail. The final consumer closes it.
class SharedBikaImagePreferences {
  SharedBikaImagePreferences._(this._key, this._entry);
  static final _entries = <(Store, String), _SharedBikaImagePreferencesEntry>{};
  factory SharedBikaImagePreferences.acquire({required String source}) {
    final store = objectbox.store;
    final owner = canonicalQjsSource(source);
    final key = (store, owner);
    final entry = _entries.putIfAbsent(
      key,
      () => _SharedBikaImagePreferencesEntry(
        SourceExperiencePreferences(source: owner, store: store),
      ),
    );
    entry.users++;
    return SharedBikaImagePreferences._(key, entry);
  }
  final (Store, String) _key;
  final _SharedBikaImagePreferencesEntry _entry;
  bool _released = false;
  SourceExperiencePreferences get preferences => _entry.preferences;
  void release() {
    if (_released) return;
    _released = true;
    if (--_entry.users == 0) {
      _entries.remove(_key);
      _entry.preferences.dispose();
    }
  }
}

class _SharedBikaImagePreferencesEntry {
  _SharedBikaImagePreferencesEntry(this.preferences);
  final SourceExperiencePreferences preferences;
  int users = 0;
}
