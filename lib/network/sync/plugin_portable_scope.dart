import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';

/// Source ownership follows existing host keys or explicit row.source only.
/// Private keys, browser stores, global settings and URL hosts are not inferred.
class PluginPortableScope {
  const PluginPortableScope(this.source, this.scope);
  final String source;
  final PluginDataScope scope;
}

/// One pass over history evidence avoids rescanning all records per progress key.
Map<String, PluginPortableScope> pluginPortableScopes(
  Map<String, Map<String, dynamic>> entries, {
  Iterable<Map<String, dynamic>> evidence = const [],
}) {
  final progressOwners = <String, Set<String>>{};
  for (final row in [...entries.values, ...evidence]) {
    final key = row['key'];
    if (key is! String || !key.startsWith('breeze.video.history.v1.')) continue;
    final record = VideoWatchRecord.fromJson(row['value']);
    if (record != null) {
      progressOwners
          .putIfAbsent(videoPlaybackProgressKey(record.watchUrl), () => {})
          .add(key.substring('breeze.video.history.v1.'.length));
    }
  }
  final result = <String, PluginPortableScope>{};
  for (final entry in entries.entries) {
    final direct = pluginPortableScope(entry.value);
    if (direct != null) {
      result[entry.key] = direct;
      continue;
    }
    final owners = progressOwners[entry.value['key']];
    if (owners?.length == 1) {
      result[entry.key] = PluginPortableScope(
        owners!.single,
        PluginDataScope.records,
      );
    }
  }
  return result;
}

PluginPortableScope? pluginPortableScope(
  Map<String, dynamic> row, {
  Iterable<Map<String, dynamic>> evidence = const [],
}) {
  final key = row['key'];
  if (key is! String) return null;
  String? suffix(String prefix) =>
      key.startsWith(prefix) && key.length > prefix.length
      ? key.substring(prefix.length)
      : null;
  for (final prefix in [
    'breeze.video.history.v1.',
    'breeze.video.recentSearches.v1.',
  ]) {
    final source = suffix(prefix);
    if (source != null) {
      return PluginPortableScope(source, PluginDataScope.records);
    }
  }
  for (final prefix in [
    'breeze.source.list-details.v1.',
    'breeze.source.diagnostics.v1.',
    'breeze.video.library.view.',
  ]) {
    final source = suffix(prefix);
    if (source != null) {
      return PluginPortableScope(source, PluginDataScope.accountSettings);
    }
  }
  // Scopes are produced by host collection/facet adapters; never infer an
  // owner from a URL host or a tag's text. Mixed/all-source scopes stay global.
  String? scopedOwner(String raw) {
    if (raw.isEmpty || raw.length > 200 || raw.contains(',') || raw == '*')
      return null;
    return raw;
  }

  for (final prefix in [
    'breeze.source.blocked-categories.v1.',
    'breeze.bookshelf.facet-tags.v1.',
    'breeze.source.results-filters.v1.',
  ]) {
    if (!key.startsWith(prefix)) continue;
    try {
      final scope = Uri.decodeComponent(key.substring(prefix.length));
      final parts = scope.split('|');
      final facetScoped =
          prefix == 'breeze.bookshelf.facet-tags.v1.' &&
          parts.last.startsWith('facet:');
      const sourceDownloads = 'source-downloads.';
      String? owner;
      if (prefix == 'breeze.source.results-filters.v1.' && parts.length >= 2) {
        owner = scopedOwner(parts.first);
      } else if (prefix == 'breeze.source.blocked-categories.v1.' &&
          parts.length >= 2) {
        owner = scopedOwner(parts.first);
      } else if (parts.length >= 2 &&
          const {
            'source-results',
            'api-video.history',
            'api-video.favorites',
            'api-video.catalog',
            'plugin',
            'bika.ranking',
          }.contains(parts.first)) {
        owner = scopedOwner(parts[1]);
      } else if (facetScoped &&
          parts.length >= 4 &&
          parts.first == 'source-filter') {
        owner = scopedOwner(parts[1]);
      } else if ((parts.length == 3 || parts.length == 4 && facetScoped) &&
          parts.first == 'download') {
        owner = scopedOwner(parts[2]);
      } else if (parts.length == 2 &&
          facetScoped &&
          parts.first.startsWith(sourceDownloads)) {
        owner = scopedOwner(parts.first.substring(sourceDownloads.length));
      } else if (parts.first.startsWith('omo.site-favorites.') &&
          (parts.length == 1 || parts.length == 2 && facetScoped)) {
        owner = scopedOwner(
          parts.first.substring('omo.site-favorites.'.length),
        );
      }
      if (owner != null)
        return PluginPortableScope(owner, PluginDataScope.accountSettings);
    } catch (_) {
      /* An unrecognized scope has no certified plugin owner. */
    }
  }
  if (key.startsWith('breeze.collection.view.v1.') ||
      key.startsWith('breeze.video.personal.preferences.v1.')) {
    try {
      final scope = Uri.decodeComponent(
        key.substring(
          key.startsWith('breeze.collection.view.v1.')
              ? 'breeze.collection.view.v1.'.length
              : 'breeze.video.personal.preferences.v1.'.length,
        ),
      ).split('|');
      if (scope.length >= 4 && scope.first == 'plugin' && scope[1].isNotEmpty) {
        return PluginPortableScope(scope[1], PluginDataScope.accountSettings);
      }
    } catch (_) {
      /* An unknown encoding has no certified owner. */
    }
  }
  if (key == 'breeze.video.exports.v1') {
    final value = row['value'];
    if (value is Map &&
        value['source'] is String &&
        (value['source'] as String).isNotEmpty) {
      return PluginPortableScope(
        value['source'] as String,
        PluginDataScope.records,
      );
    }
  }
  if (key.startsWith('breeze.video.progress.')) {
    final sources = <String>{};
    for (final item in evidence) {
      final historyKey = item['key'];
      if (historyKey is! String ||
          !historyKey.startsWith('breeze.video.history.v1.')) {
        continue;
      }
      final record = VideoWatchRecord.fromJson(item['value']);
      if (record != null && videoPlaybackProgressKey(record.watchUrl) == key) {
        sources.add(historyKey.substring('breeze.video.history.v1.'.length));
      }
    }
    if (sources.length == 1) {
      return PluginPortableScope(sources.single, PluginDataScope.records);
    }
  }
  // A locally created purge tombstone has no remaining private value. Its
  // validated local-only provenance preserves ownership for reinstall cleanup.
  final marker = row['localPurge'];
  if (validPluginPortablePurgeMarker(row) && marker is Map) {
    return PluginPortableScope(
      marker['source'] as String,
      PluginDataScope.values.byName(marker['scope'] as String),
    );
  }
  return null;
}

String _publicRowHash(Map<String, dynamic> row) => sha256
    .convert(
      utf8.encode(
        jsonEncode({
          for (final key in ['key', 'kind', 'deleted', 'updatedAt'])
            key: row[key],
        }),
      ),
    )
    .toString();

bool validPluginPortablePurgeMarker(Map<String, dynamic> row) {
  final marker = row['localPurge'];
  return row['deleted'] == true &&
      !row.containsKey('value') &&
      marker is Map &&
      marker.length == 4 &&
      marker['source'] is String &&
      (marker['source'] as String).isNotEmpty &&
      (marker['source'] as String).length <= 200 &&
      PluginDataScope.values.any((scope) => scope.name == marker['scope']) &&
      marker['updatedAt'] == row['updatedAt'] &&
      marker['hash'] == _publicRowHash(row);
}

Map<String, dynamic> pluginPortablePurgeTombstone(
  Map<String, dynamic> row,
  PluginPortableScope scope, {
  required int nowMs,
}) {
  final previous = row['updatedAt'] as int;
  final tombstone = <String, dynamic>{
    'key': row['key'],
    'kind': row['kind'],
    'deleted': true,
    'updatedAt': nowMs > previous ? nowMs : previous + 1,
  };
  tombstone['localPurge'] = {
    'source': scope.source,
    'scope': scope.scope.name,
    'updatedAt': tombstone['updatedAt'],
    'hash': _publicRowHash(tombstone),
  };
  return tombstone;
}

bool pluginPortableRowExcluded(
  Map<String, dynamic> row, {
  Iterable<Map<String, dynamic>> evidence = const [],
}) {
  final scope = pluginPortableScope(row, evidence: evidence);
  return scope != null &&
      LocalPluginInstallationState.instance.isDataExcluded(
        scope.source,
        scope.scope,
      );
}
