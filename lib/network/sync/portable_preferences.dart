import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search_result/source_result_filter_preferences.dart';
import 'package:zephyr/page/video/video_personal_preferences.dart';
import 'package:zephyr/widgets/collection_cover_fit.dart';
import 'package:zephyr/network/sync/sync_plugin_participation.dart';
import 'dart:convert';
import 'package:zephyr/network/sync/routing_portable_preferences.dart';
import 'package:zephyr/page/source_shell/source_list_block_preferences.dart';
import 'package:zephyr/page/bookshelf/service/bookshelf_source_preferences.dart';
import 'package:zephyr/network/routing/routing_domain_catalog.dart';
import 'package:zephyr/network/routing/routing_saved_rules.dart';
import 'package:zephyr/network/routing/routing_observed_media.dart';
import 'package:zephyr/network/sync/sync_direction.dart';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/bookshelf/service/shelf_facet_preferences.dart';
import 'package:zephyr/page/source_shell/source_list_presentation.dart';
import 'package:zephyr/page/source_shell/source_diagnostic_preferences.dart';
import 'package:zephyr/page/source_shell/source_return_preferences.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/page/video/video_playback_preferences.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/page/video/video_search_history.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/service/collection_view_preferences.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/network/sync/plugin_portable_scope.dart';

/// Portable user data only. Device IDs, cloud transport keys, WebKit caches,
/// loopback proxy settings and media files are deliberately outside this scope.
class PortablePreferencesSnapshot {
  PortablePreferencesSnapshot([Map<String, Map<String, dynamic>>? values])
    : entries = values ?? {};
  final Map<String, Map<String, dynamic>> entries;
  static const maxBytes = 16 * 1024 * 1024;
  Map<String, dynamic> toJson({bool includeLocalMetadata = false}) => {
    'version': 1,
    'entries': includeLocalMetadata
        ? entries
        : {
            for (final entry in entries.entries)
              entry.key: entry.value.containsKey('localPurge')
                  ? (Map<String, dynamic>.from(entry.value)
                      ..remove('localPurge'))
                  : entry.value,
          },
  };

  factory PortablePreferencesSnapshot.fromJson(
    dynamic raw, {
    bool allowLocalMetadata = false,
  }) {
    if (raw is! Map ||
        raw['version'] != 1 ||
        raw['entries'] is! Map ||
        (raw['entries'] as Map).length > 12000 ||
        jsonEncode(raw).length > maxBytes) {
      throw const FormatException('Invalid portable application data');
    }
    final entries = <String, Map<String, dynamic>>{};
    for (final item in (raw['entries'] as Map).entries) {
      if (item.key is! String || item.value is! Map) {
        throw const FormatException('Invalid portable entry');
      }
      final row = Map<String, dynamic>.from(item.value as Map);
      if (row.keys.any(
        (key) => !{
          'key',
          'kind',
          'value',
          'deleted',
          'updatedAt',
          if (allowLocalMetadata) 'localPurge',
        }.contains(key),
      )) {
        throw const FormatException('Unknown portable entry fields');
      }
      final key = row['key'], kind = row['kind'], time = row['updatedAt'];
      if (row.containsKey('localPurge') &&
          !validPluginPortablePurgeMarker(row)) {
        throw const FormatException('Invalid local portable provenance');
      }
      if (key is! String ||
          !PortablePreferences.owns(key) ||
          !['preference', 'history', 'search', 'export'].contains(kind) ||
          time is! int ||
          time < 0 ||
          time > 8640000000000000 ||
          row['deleted'] is! bool ||
          kind != PortablePreferences.kind(key) ||
          !RegExp(
            '^${RegExp.escape(key)}#[a-f0-9]{64}\$',
          ).hasMatch(item.key as String) ||
          (row['deleted'] != true && !_validValue(key, kind, row['value']))) {
        throw const FormatException('Invalid portable entry');
      }
      entries[item.key as String] = row;
    }
    return PortablePreferencesSnapshot(entries);
  }

  static bool _validValue(String key, dynamic kind, dynamic value) {
    if (key.startsWith(SourceResultFilterPreferences.prefix))
      return SourceResultFilterPreferences.validValue(value);
    if (key.startsWith(VideoPersonalPreferences.prefix)) {
      if (value is! String || value.length > 64000) return false;
      try {
        final data = jsonDecode(value);
        return data is Map &&
            data.keys.every(
              (k) =>
                  const ['query', 'keywordScope', 'sort', 'facets'].contains(k),
            ) &&
            (data['query'] == null || data['query'] is String) &&
            (data['keywordScope'] == null ||
                parseKeywordSearchScope(data['keywordScope']) != null) &&
            (data['sort'] == null ||
                const ['source', 'title'].contains(data['sort'])) &&
            (data['facets'] == null ||
                data['facets'] is Map &&
                    (data['facets'] as Map).values.every(
                      (v) => v is List && v.every((x) => x is String),
                    ));
      } catch (_) {
        return false;
      }
    }
    if (key == CollectionCoverFitController.storageKey) {
      return value == 'contain' || value == 'cover';
    }
    if (key == CollectionCoverPrivacyController.styleKey) {
      return value is String &&
          CollectionCoverStyle.values.any((style) => style.name == value);
    }
    if (portableRoutingKeys.contains(key))
      return validPortableRoutingValue(key, value);
    if (key.startsWith('breeze.source.blocked-categories.v1.') ||
        key.startsWith('breeze.bookshelf.facet-tags.v1.')) {
      if (value is! String) return false;
      try {
        final tags = jsonDecode(value);
        return tags is List &&
            tags.length <= 2000 &&
            tags.every((tag) => tag is String && tag.trim().isNotEmpty);
      } catch (_) {
        return false;
      }
    }
    if (kind == 'history') {
      return key.startsWith(PortablePreferences.historyPrefix) &&
          VideoWatchRecord.fromJson(value) != null;
    }
    if (kind == 'search') {
      return key.startsWith(PortablePreferences.searchPrefix) &&
          value is String &&
          value.trim().isNotEmpty &&
          value.length <= 500;
    }
    if (kind == 'export') {
      return key == VideoExportRecords.storageKey &&
          _validExternalExport(value);
    }
    if (key.startsWith('breeze.video.progress.')) {
      return value is int && value >= 0;
    }
    if (key.startsWith('breeze.source.list-details.v1.') ||
        key.startsWith('breeze.source.diagnostics.v1.')) {
      return value is bool;
    }
    if (key.startsWith('breeze.video.library.view.') ||
        key.startsWith(CollectionViewPreferences.prefix)) {
      return value == 'grid' || value == 'list';
    }
    if (key == SourceReturnPreferences.storageKey) {
      return value == 'byFunction' || value == 'stepByStep';
    }
    if (key == 'breeze.bookshelf.media.v1') {
      return value == 'comic' || value == 'video';
    }
    if (key == 'breeze.bookshelf.video.sorts.v1' ||
        key == 'discover_hidden_plugin_ids_v1') {
      return value is List && value.every((v) => v is String);
    }
    if (key == 'breeze.bookshelf.video.sorts.v2') {
      return value is List &&
          value.length == 2 &&
          value.every((v) => v == 'dd' || v == 'da');
    }
    if (value is! String) return false;
    try {
      final data = jsonDecode(value);
      if (data is! Map || data['version'] != 1) return false;
      if (key == VideoPlaybackPreferences.snapshotKey) {
        return data['values'] is Map && data['updatedAt'] is int;
      }
      if (key.startsWith('breeze.bookshelf.source-tabs.')) {
        return data['order'] is List &&
            data['hidden'] is List &&
            (data['order'] as List).every((v) => v is String) &&
            (data['hidden'] as List).every((v) => v is String);
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  /// An acknowledgment of an external Files export is public metadata only.
  /// Device-owned resource IDs, paths and transfer phases are another store.
  static bool _validExternalExport(dynamic value) {
    if (value is! Map ||
        value.keys.any(
          (key) => !const {
            'key',
            'source',
            'url',
            'title',
            'quality',
            'cover',
            'at',
          }.contains(key),
        )) {
      return false;
    }
    final source = value['source'],
        url = value['url'],
        title = value['title'],
        at = value['at'];
    if (source is! String ||
        source.isEmpty ||
        source.length > 200 ||
        url is! String ||
        url.length > 4096 ||
        title is! String ||
        title.length > 300 ||
        at is! int ||
        at < 0 ||
        at > 8640000000000000) {
      return false;
    }
    final page = videoPublicPage(Uri.tryParse(url) ?? Uri());
    if (page == null ||
        page.toString() != url ||
        value['key'] != '$source|$page') {
      return false;
    }
    if (value.containsKey('quality') &&
        (value['quality'] is! String ||
            (value['quality'] as String).length > 80)) {
      return false;
    }
    final cover = value['cover'];
    if (cover == null) return true;
    final image = cover is String && cover.length <= 4096
        ? Uri.tryParse(cover)
        : null;
    if (image == null ||
        image.scheme != 'https' ||
        image.host.isEmpty ||
        image.userInfo.isNotEmpty ||
        (image.hasPort && image.port != 443) ||
        image.hasFragment) {
      return false;
    }
    // Retain established public image transforms, without allowing signed or
    // credential-bearing query parameters from old acknowledgments.
    const imageKeys = {
      'w',
      'h',
      'width',
      'height',
      'q',
      'quality',
      'format',
      'fit',
      'crop',
      'resize',
      'auto',
      'dpr',
    };
    return image.queryParametersAll.entries.every(
      (entry) =>
          (imageKeys.contains(entry.key) ||
              RegExp(
                r'^(?:imageView2|imageMogr2)(?:/[A-Za-z0-9_,.:-]+)*$',
              ).hasMatch(entry.key)) &&
          entry.value.every(
            (value) =>
                value.length <= 200 &&
                RegExp(r'^[A-Za-z0-9_,./:-]*$').hasMatch(value),
          ),
    );
  }

  PortablePreferencesSnapshot merged(
    PortablePreferencesSnapshot other, {
    bool preferOtherOnTie = false,
  }) {
    final result = Map<String, Map<String, dynamic>>.from(entries);
    for (final item in other.entries.entries) {
      final old = result[item.key], next = item.value;
      final time = next['updatedAt'] as int;
      if (old == null ||
          time > (old['updatedAt'] as int) ||
          time == old['updatedAt'] &&
              (next['deleted'] == true && old['deleted'] != true ||
                  next['deleted'] == old['deleted'] &&
                      (preferOtherOnTie ||
                          jsonEncode(next).compareTo(jsonEncode(old)) > 0))) {
        if (old != null &&
            validPluginPortablePurgeMarker(old) &&
            next['deleted'] == true &&
            !next.containsKey('value') &&
            old['updatedAt'] == next['updatedAt'] &&
            old['key'] == next['key'] &&
            old['kind'] == next['kind']) {
          result[item.key] = {...next, 'localPurge': old['localPurge']};
        } else {
          result[item.key] = next;
        }
      }
    }
    return PortablePreferencesSnapshot(result);
  }
}

abstract final class PortablePreferences {
  static const journalKey = 'breeze.sync.portable.v1';
  static const historyPrefix = 'breeze.video.history.v1.';
  static const searchPrefix = 'breeze.video.recentSearches.v1.';
  static final changes = ValueNotifier<int>(0);
  static bool owns(String key) =>
      key.length < 500 &&
      (key.startsWith(SourceResultFilterPreferences.prefix) ||
          key.startsWith(VideoPersonalPreferences.prefix) ||
          key.startsWith(historyPrefix) ||
          key.startsWith(searchPrefix) ||
          key.startsWith('breeze.video.library.view.') ||
          key.startsWith(CollectionViewPreferences.prefix) ||
          key.startsWith('breeze.video.progress.') ||
          key.startsWith('breeze.source.list-details.v1.') ||
          key.startsWith('breeze.source.blocked-categories.v1.') ||
          portableRoutingKeys.contains(key) ||
          key.startsWith('breeze.source.diagnostics.v1.') ||
          key.startsWith('breeze.bookshelf.source-tabs.') ||
          key.startsWith('breeze.bookshelf.facet-tags.v1.') ||
          key == VideoPlaybackPreferences.snapshotKey ||
          key == VideoExportRecords.storageKey ||
          key == SourceReturnPreferences.storageKey ||
          key == CollectionCoverPrivacyController.styleKey ||
          key == CollectionCoverFitController.storageKey ||
          key == 'breeze.bookshelf.media.v1' ||
          key == 'breeze.bookshelf.video.sorts.v1' ||
          key == 'breeze.bookshelf.video.sorts.v2' ||
          key == 'discover_hidden_plugin_ids_v1');

  static String kind(String key) => key.startsWith(historyPrefix)
      ? 'history'
      : key.startsWith(searchPrefix)
      ? 'search'
      : key == VideoExportRecords.storageKey
      ? 'export'
      : 'preference';

  static PortablePreferencesSnapshot forSync(
    PortablePreferencesSnapshot snapshot, {
    bool includeSettings = true,
    bool? includePluginSettings,
  }) => PortablePreferencesSnapshot({
    for (final entry in snapshot.entries.entries)
      if (settingsKeySelected(
        entry.value['key'] as String,
        includeSettings: includeSettings,
        includePluginSettings: includePluginSettings ?? includeSettings,
      ))
        entry.key: entry.value,
  });

  static bool settingsKeySelected(
    String key, {
    required bool includeSettings,
    required bool includePluginSettings,
  }) =>
      kind(key) != 'preference' ||
      key.startsWith('breeze.video.progress.') ||
      (pluginPortableScope({'key': key}) == null
          ? includeSettings
          : includePluginSettings);

  /// Missing cloud preferences are not deletions. Records still merge by
  /// identity/revision, while selected preferences follow the chosen direction.
  static PortablePreferencesSnapshot directed(
    PortablePreferencesSnapshot local,
    PortablePreferencesSnapshot remote, {
    required SyncDirection direction,
    bool forCloud = false,
    bool includeSettings = true,
    bool includePluginSettings = true,
  }) {
    final merged = local.merged(remote);
    if (direction == SyncDirection.merge &&
        includeSettings &&
        includePluginSettings)
      return merged;
    final entries = {...merged.entries};
    for (final id in {...local.entries.keys, ...remote.entries.keys}) {
      final row = local.entries[id] ?? remote.entries[id]!;
      final key = row['key'] as String;
      if (row['kind'] != 'preference' ||
          key.startsWith('breeze.video.progress.'))
        continue;
      final selected = settingsKeySelected(
        key,
        includeSettings: includeSettings,
        includePluginSettings: includePluginSettings,
      );
      final mode = selected ? direction : SyncDirection.recordsOnly;
      var value = switch (mode) {
        SyncDirection.merge => merged.entries[id],
        SyncDirection.upload => local.entries[id] ?? remote.entries[id],
        SyncDirection.restore =>
          forCloud
              ? remote.entries[id]
              : remote.entries[id] ?? local.entries[id],
        SyncDirection.recordsOnly =>
          forCloud ? remote.entries[id] : local.entries[id],
      };
      final own = local.entries[id], cloud = remote.entries[id];
      if (forCloud &&
          mode == SyncDirection.upload &&
          own != null &&
          cloud != null &&
          (own['updatedAt'] as int) <= (cloud['updatedAt'] as int)) {
        // Every device keeps its own archive. Merely choosing the local row
        // would let another device's older intent win the next timestamp merge.
        // Keep an equivalent cloud revision stable on repeated uploads; only
        // a different selected value/deletion needs to supersede it.
        final same =
            own['deleted'] == cloud['deleted'] &&
            _same(own['value'], cloud['value']);
        final time = (cloud['updatedAt'] as int) + (same ? 0 : 1);
        if (time > 8640000000000000) {
          throw const FormatException(
            'Portable preference revision exceeds limit',
          );
        }
        value = {...own, 'updatedAt': time};
      }
      if (value == null) {
        entries.remove(id);
      } else {
        entries[id] = value;
      }
    }
    return PortablePreferencesSnapshot(entries);
  }

  static String _id(String key, String identity) =>
      '$key#${sha256.convert(utf8.encode(identity))}';
  static bool _same(dynamic a, dynamic b) => jsonEncode(a) == jsonEncode(b);
  static Future<void> _flush() async {
    await Future.wait([
      VideoWatchHistory.flush(),
      VideoSearchHistory.flush(),
      VideoExportRecords.flush(),
      CollectionCoverPrivacyController.instance.flushStyle(),
      CollectionCoverFitController.instance.flush(),
      ShelfFacetPreferences.flush(),
      SourceResultFilterPreferences.flush(),
      CollectionViewPreferences.flush(),
      SourceListPreferences.flush(),
      VideoPersonalPreferences.flush(),
      SourceListBlockPreferences.flush(),
      BookshelfSourcePreferenceStore.flush(),
      SourceReturnPreferences.flush(),
      RoutingObservedMediaDomains.flush(),
      RoutingDomainCatalogStore.flush(),
      RoutingSavedRulesStore.flush(),
    ]);
    await VideoPlaybackPreferences.read();
  }

  static Future<SharedPreferences> _snapshotStore() async {
    await LocalPluginInstallationState.instance.load();
    await _flush();
    return SharedPreferences.getInstance();
  }

  static Future<PortablePreferencesSnapshot> capture({
    bool persist = true,
  }) async => _capture(await _snapshotStore(), persist: persist);

  static Future<PortablePreferencesSnapshot> _capture(
    SharedPreferences prefs, {
    required bool persist,
    PortablePreferencesSnapshot? localAtPreparation,
  }) async {
    if (persist &&
        !prefs.containsKey(VideoPlaybackPreferences.snapshotKey) &&
        VideoPlaybackPreferences.defaults.keys.any(
          (key) => prefs.containsKey('${VideoPlaybackPreferences.prefix}$key'),
        )) {
      await VideoPlaybackPreferences.restore(
        (await VideoPlaybackPreferences.read()).toValues(),
        updatedAt: 1,
      );
    }
    final raw = prefs.getString(journalKey);
    final recorded = raw == null
        ? PortablePreferencesSnapshot()
        : PortablePreferencesSnapshot.fromJson(
            jsonDecode(raw),
            allowLocalMetadata: true,
          );
    // A staged file merge may have observed records before their first journal
    // write. A removal since staging must still generate a newer tombstone.
    final previous =
        localAtPreparation?.merged(recorded, preferOtherOnTie: true) ??
        recorded;
    final observed = <String, Map<String, dynamic>>{};
    final now = DateTime.now().millisecondsSinceEpoch;
    void put(
      String key,
      String kind,
      dynamic value,
      String identity,
      int initialTime,
    ) {
      final id = _id(key, identity), old = previous.entries[_id(key, identity)];
      observed[id] = {
        'key': key,
        'kind': kind,
        'value': value,
        'deleted': false,
        'updatedAt':
            old != null && old['deleted'] != true && _same(old['value'], value)
            ? old['updatedAt']
            : old != null
            ? now > (old['updatedAt'] as int)
                  ? now
                  : (old['updatedAt'] as int) + 1
            : initialTime,
      };
    }

    for (final key in prefs.getKeys().where(owns)) {
      final value = prefs.get(key);
      if (key.startsWith(historyPrefix)) {
        final decoded = jsonDecode(value as String);
        if (decoded is! List) {
          throw const FormatException('Invalid video history');
        }
        for (final raw in decoded) {
          final record = VideoWatchRecord.fromJson(raw);
          if (record != null) {
            put(
              key,
              'history',
              record.toJson(),
              record.watchUrl.toString(),
              record.updatedAt.millisecondsSinceEpoch,
            );
          }
        }
      } else if (key.startsWith(searchPrefix)) {
        if (value is! List) {
          throw const FormatException('Invalid search history');
        }
        for (var i = 0; i < value.length; i++) {
          final word = value[i];
          if (word is String && word.trim().isNotEmpty) {
            put(key, 'search', word, word, now - i);
          }
        }
      } else if (key == VideoExportRecords.storageKey) {
        final decoded = jsonDecode(value as String);
        if (decoded is! List) {
          throw const FormatException('Invalid export records');
        }
        for (final row in decoded.whereType<Map>()) {
          if (PortablePreferencesSnapshot._validExternalExport(row)) {
            put(
              key,
              'export',
              Map<String, dynamic>.from(row),
              '${row['source']}:${row['key']}',
              row['at'] as int,
            );
          }
        }
      } else if (value != null) {
        final optionalPreference =
            key.startsWith(VideoPersonalPreferences.prefix) ||
            key.startsWith(CollectionViewPreferences.prefix) ||
            key.startsWith('breeze.video.library.view.') ||
            key.startsWith(SourceListPreferences.prefix);
        if (optionalPreference &&
            !PortablePreferencesSnapshot._validValue(
              key,
              'preference',
              value,
            )) {
          // A damaged optional preference must neither block the whole backup nor
          // turn a previously valid saved value into an intentional deletion.
          for (final entry in previous.entries.entries) {
            if (entry.value['key'] == key) observed[entry.key] = entry.value;
          }
          continue;
        }
        var time = 1;
        if (key == VideoPlaybackPreferences.snapshotKey && value is String) {
          final data = jsonDecode(value);
          if (data is Map && data['updatedAt'] is int) {
            time = data['updatedAt'] as int;
          }
        }
        put(key, 'preference', value, '', time);
      }
    }
    final scopes = pluginPortableScopes({
      ...previous.entries,
      ...observed,
    }, evidence: previous.entries.values);
    for (final entry in previous.entries.entries) {
      if (!observed.containsKey(entry.key)) {
        final old = entry.value;
        final scope = scopes[entry.key];
        final excluded =
            scope != null &&
            LocalPluginInstallationState.instance.isDataExcluded(
              scope.source,
              scope.scope,
            );
        observed[entry.key] = old['deleted'] == true || excluded
            ? old
            : {
                'key': old['key'],
                'kind': old['kind'],
                'deleted': true,
                'updatedAt': now > (old['updatedAt'] as int)
                    ? now
                    : (old['updatedAt'] as int) + 1,
              };
      }
    }
    final snapshot = PortablePreferencesSnapshot(observed);
    PortablePreferencesSnapshot.fromJson(snapshot.toJson());
    if (persist &&
        !await prefs.setString(
          journalKey,
          jsonEncode(snapshot.toJson(includeLocalMetadata: true)),
        )) {
      throw StateError('Portable data status was not saved');
    }
    return snapshot;
  }

  static Future<bool> _write(
    SharedPreferences prefs,
    String key,
    dynamic value,
  ) {
    if (value == null) return prefs.remove(key);
    if (value is String) return prefs.setString(key, value);
    if (value is bool) return prefs.setBool(key, value);
    if (value is int) return prefs.setInt(key, value);
    if (value is double) return prefs.setDouble(key, value);
    return prefs.setStringList(key, (value as List).cast<String>());
  }

  static Future<void> restore(
    PortablePreferencesSnapshot incoming, {
    bool replace = false,
    PortablePreferencesSnapshot? localAtPreparation,
    Set<String>? participatingSources,
    bool preferIncomingOnTie = false,
    SyncDirection direction = SyncDirection.merge,
    Future<void> Function(Map<String, dynamic> updates)? beforeWrite,
    bool Function(String key)? shouldWriteKey,
  }) async {
    // Validate the whole payload before the first mutation.
    PortablePreferencesSnapshot.fromJson(incoming.toJson());
    final prefs = await _snapshotStore();
    Future<Set<String>> apply() => _restoreSnapshot(
      prefs,
      incoming,
      replace: replace,
      localAtPreparation: localAtPreparation,
      participatingSources: participatingSources,
      preferIncomingOnTie: preferIncomingOnTie,
      direction: direction,
      beforeWrite: beforeWrite,
      shouldWriteKey: shouldWriteKey,
    );
    final keys = await VideoWatchHistory.serializePortableWrite(
      () => ShelfFacetPreferences.serializePortableWrite(apply),
    );
    await notifyRestored(keys: keys);
  }

  static Future<Set<String>> _restoreSnapshot(
    SharedPreferences prefs,
    PortablePreferencesSnapshot incoming, {
    required bool replace,
    required PortablePreferencesSnapshot? localAtPreparation,
    required Set<String>? participatingSources,
    required bool preferIncomingOnTie,
    required SyncDirection direction,
    required Future<void> Function(Map<String, dynamic> updates)? beforeWrite,
    required bool Function(String key)? shouldWriteKey,
  }) async {
    final current = await _capture(
      prefs,
      persist: !replace && localAtPreparation == null,
      localAtPreparation: localAtPreparation,
    );
    final candidate = replace
        ? incoming
        : direction == SyncDirection.merge
        ? current.merged(incoming, preferOtherOnTie: preferIncomingOnTie)
        : directed(current, incoming, direction: direction);
    final merged = participatingSources == null
        ? candidate
        : projectPluginPortableData(candidate, current, participatingSources);
    final scopes = pluginPortableScopes(
      merged.entries,
      evidence: current.entries.values,
    );
    final maskedKeys = <String>{
      if (!replace && participatingSources == null)
        for (final entry in scopes.entries)
          if (LocalPluginInstallationState.instance.isDataExcluded(
            entry.value.source,
            entry.value.scope,
          ))
            merged.entries[entry.key]!['key'] as String,
    }..remove(VideoExportRecords.storageKey);
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final row in merged.entries.values) {
      groups.putIfAbsent(row['key'] as String, () => []).add(row);
    }
    final updates = <String, dynamic>{};
    if (replace) {
      for (final key in prefs.getKeys().where(owns)) {
        updates[key] = null;
      }
    }
    for (final entry in groups.entries) {
      if (maskedKeys.contains(entry.key)) continue;
      final active = entry.value.where((r) => r['deleted'] != true).toList()
        ..sort(
          (a, b) => (b['updatedAt'] as int).compareTo(a['updatedAt'] as int),
        );
      final kind = entry.value.first['kind'];
      if (!replace &&
          participatingSources == null &&
          entry.key == VideoExportRecords.storageKey) {
        active.removeWhere((row) => pluginPortableRowExcluded(row));
        final raw = prefs.getString(VideoExportRecords.storageKey);
        final local = raw == null ? const [] : jsonDecode(raw);
        if (local is List) {
          for (final value in local.whereType<Map>()) {
            if (!PortablePreferencesSnapshot._validExternalExport(value)) {
              continue;
            }
            final row = <String, dynamic>{
              'key': VideoExportRecords.storageKey,
              'value': value,
            };
            if (pluginPortableRowExcluded(row)) {
              active.add({'value': value, 'updatedAt': value['at']});
            }
          }
          active.sort(
            (a, b) => (b['updatedAt'] as int).compareTo(a['updatedAt'] as int),
          );
        }
      }
      updates[entry.key] = kind == 'preference'
          ? (active.isEmpty ? null : active.first['value'])
          : kind == 'search'
          ? active
                .take(VideoSearchHistory.limit)
                .map((r) => r['value'] as String)
                .toList()
          : jsonEncode(active.take(200).map((r) => r['value']).toList());
    }
    if (shouldWriteKey != null)
      updates.removeWhere((key, _) => !shouldWriteKey(key));
    updates[journalKey] = jsonEncode(merged.toJson(includeLocalMetadata: true));
    await beforeWrite?.call(Map<String, dynamic>.unmodifiable(updates));
    final before = {for (final key in updates.keys) key: prefs.get(key)};
    try {
      // All cache changes start in the same turn before yielding to UI writes.
      final results = await Future.wait([
        for (final entry in updates.entries)
          _write(prefs, entry.key, entry.value),
      ]);
      if (results.any((ok) => !ok)) {
        throw StateError('Application data was not restored');
      }
    } catch (_) {
      await Future.wait([
        for (final entry in before.entries)
          if (_same(prefs.get(entry.key), updates[entry.key]))
            _write(prefs, entry.key, entry.value),
      ]);
      rethrow;
    }
    return updates.keys.toSet();
  }

  static Future<void> notifyRestored({Set<String> keys = const {}}) async {
    await VideoPlaybackPreferences.refreshAfterRestore();
    VideoWatchHistory.changes.value++;
    VideoExportRecords.changes.value++;
    SourceListPreferences.changes.value++;
    SourceListBlockPreferences.changes.value++;
    BookshelfSourcePreferenceStore.changes.value++;
    CollectionViewPreferences.changes.value++;
    SourceDiagnosticPreferences.changes.value++;
    await SourceReturnPreferences.load();
    if (keys.contains(CollectionCoverPrivacyController.styleKey)) {
      await CollectionCoverPrivacyController.instance.reloadStyle();
    }
    if (keys.contains(CollectionCoverFitController.storageKey)) {
      await CollectionCoverFitController.instance.reload();
    }
    changes.value++;
  }
}
