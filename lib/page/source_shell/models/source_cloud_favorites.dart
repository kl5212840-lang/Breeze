import 'package:zephyr/page/comic_list/cubit/plugin_paged_comic_list_state.dart';
import 'package:zephyr/page/comic_list/cubit/jm_collection_snapshots.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/network/http/plugin/unified_plugin_envelope.dart';
import 'package:zephyr/util/json/json_dispose.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';

class SourceCloudFavoritePreview {
  const SourceCloudFavoritePreview({
    required this.items,
    this.total,
    this.pendingConfirmation = false,
  });

  final List<UnifiedComicListItem> items;
  final int? total;
  final bool pendingConfirmation;
}

class SourceCloudFavoriteQuery {
  SourceCloudFavoriteQuery(
    String source, {
    bool jmProfile = false,
    String functionPath = '',
  }) {
    final declared = functionPath.trim();
    function = declared.isNotEmpty
        ? declared
        : jmProfile
        ? 'getCloudFavoriteData'
        : 'getFavoriteData';
    extern = declared.isNotEmpty
        ? const {'source': 'cloudFavorite'}
        : jmProfile
        ? const {'source': 'cloudFavorite', 'order': 'mr', 'folderId': ''}
        : const {'source': 'cloudFavorite', 'sort': 'dd'};
    key = JmCollectionSnapshots.instance.key(source, function, core, extern);
  }
  final Map<String, dynamic> core = const {'page': 1};
  late final Map<String, dynamic> extern;
  late final String function, key;
}

class SourceCloudFavoriteReadSuperseded implements Exception {
  const SourceCloudFavoriteReadSuperseded();
}

Future<SourceCloudFavoritePreview> loadSourceCloudFavoritePreview(
  String source, {
  bool jmProfile = false,
  String functionPath = '',
}) async {
  final snapshots = JmCollectionSnapshots.instance;
  final query = SourceCloudFavoriteQuery(
    source,
    jmProfile: jmProfile,
    functionPath: functionPath,
  );
  final generation = pluginSessionWriteFence.generation(source);
  final revision = snapshots.revision(source);
  final headRead = snapshots.beginHeadRead(query.key);
  final response = await callUnifiedComicPlugin(
    from: source,
    // The profile owns its login state and retry. A late request must not
    // broadcast a login event after a newer account has become active.
    notifyUnauthorized: false,
    fnPath: query.function,
    core: query.core,
    extern: query.extern,
  );
  final preview = parseSourceCloudFavoriteSnapshot(
    response,
    fallbackSource: source,
  );
  if (preview.items.any((item) => item.source != source)) {
    throw const FormatException('站点收藏来源不匹配');
  }
  final pendingConfirmation = !snapshots.acceptsRemoteState(
    query.key,
    PluginPagedComicListState(
      list: preview.items,
      knownTotal: preview.total,
      hasReachedMax:
          preview.total != null && preview.total == preview.items.length,
    ),
  );
  final observed = await snapshots.observePreview(
    key: query.key,
    source: source,
    generation: generation,
    expectedRevision: revision,
    items: preview.items,
    total: preview.total,
    headRead: headRead,
  );
  if (observed == null) throw const SourceCloudFavoriteReadSuperseded();
  return SourceCloudFavoritePreview(
    items: observed.list
        .take(preview.items.isEmpty ? 20 : preview.items.length)
        .toList(),
    total: observed.knownTotal,
    pendingConfirmation: pendingConfirmation,
  );
}

List<UnifiedComicListItem> parseSourceCloudFavoritePreview(
  Map<String, dynamic> response, {
  required String fallbackSource,
}) {
  return parseSourceCloudFavoriteSnapshot(
    response,
    fallbackSource: fallbackSource,
  ).items;
}

SourceCloudFavoritePreview parseSourceCloudFavoriteSnapshot(
  Map<String, dynamic> response, {
  required String fallbackSource,
}) {
  final envelope = UnifiedPluginEnvelope.fromMap(response);
  final source = envelope.source.trim().isEmpty
      ? fallbackSource.trim()
      : envelope.source.trim();
  final rawItems = envelope.data['items'];
  if (rawItems is! List) {
    throw const FormatException('站点收藏暂时无法读取');
  }
  final items = rawItems
      .map((item) => asJsonMap(replaceNestedNullList(asJsonMap(item))))
      .map((item) => unifiedComicFromPluginListMap(item, source: source))
      .toList();
  // Bika/Copy return paging.total; JM returns data.total. A first-page
  // preview is not the complete collection, so never use its length as total.
  final paging = asJsonMap(envelope.data['paging']);
  final rawTotal = paging.containsKey('total')
      ? paging['total']
      : envelope.data['total'];
  final parsed = rawTotal is num
      ? rawTotal
      : rawTotal is String
      ? num.tryParse(rawTotal.trim())
      : null;
  final total =
      parsed != null &&
          parsed.isFinite &&
          parsed >= items.length &&
          parsed == parsed.truncateToDouble()
      ? parsed.toInt()
      : null;
  return SourceCloudFavoritePreview(items: items, total: total);
}
