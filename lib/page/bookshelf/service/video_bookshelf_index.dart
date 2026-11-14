import 'package:zephyr/widgets/plugin_installation_guard.dart';
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/cubit/search_status.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/discover/service/discover_router.dart';
import 'package:zephyr/page/donwload_task/service/download_work_pin_removal.dart';
import 'package:zephyr/page/video/api_video_history.dart';
import 'package:zephyr/page/video/api_video_catalog_index.dart';
import 'package:zephyr/page/video/video_cover_overlay.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_local_playback.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/page/video/video_source_action.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/util/text/public_search_text.dart';

class VideoBookshelfRow {
  const VideoBookshelfRow({
    required this.key,
    required this.source,
    required this.item,
    required this.updatedAt,
    this.watchUrl,
    this.folderIds = const {},
    this.recordKey,
    this.localResourceId,
    this.progress = '',
    this.facetFields = const {},
  });
  final String key, source;
  final ApiVideoItem item;
  final Uri? watchUrl;
  final DateTime updatedAt;
  final Set<String> folderIds;
  final String? recordKey;
  final String? localResourceId;
  final String progress;

  /// Public local-record attributes that are not film metadata (for example,
  /// the acknowledged export quality). These never populate release fields.
  final Map<String, Set<String>> facetFields;

  bool get _isStandaloneHistory =>
      recordKey == null &&
      localResourceId == null &&
      watchUrl?.path == '/watch' &&
      item.detailUrl.path == '/watch';

  Uri? resumeAt(Uri home) {
    final resume = watchUrl == null ? null : videoPlaybackIdentity(watchUrl!);
    if (resume == null || resume.origin != home.origin) return null;
    return videoPublicPage(resume) == videoPublicPage(item.detailUrl)
        ? resume
        : null;
  }
}

/// Keep the saved work authoritative; fill only missing public basics from an
/// exact local detail. No identity, episode order, timestamps or metrics move.
ApiVideoItem videoShelfItemWithKnownMetadata(
  ApiVideoItem item,
  ApiVideoItem? known,
) {
  if (known == null ||
      item.id.isEmpty ||
      known.id != item.id ||
      videoPublicPage(item.detailUrl) == null ||
      videoPublicPage(known.detailUrl) != videoPublicPage(item.detailUrl))
    return item;
  final json = item.toLibraryJson(), cached = known.toLibraryJson();
  var changed = false;
  for (final field in const [
    'description',
    'genres',
    'typeName',
    'year',
    'area',
    'language',
    'actors',
    'directors',
    'writers',
  ]) {
    if ((json[field] as String? ?? '').trim().isEmpty &&
        (cached[field] as String? ?? '').trim().isNotEmpty) {
      json[field] = cached[field];
      changed = true;
    }
  }
  return changed ? ApiVideoItem.fromJson(json, home: item.detailUrl) : item;
}

typedef VideoBookshelfSnapshot = ({
  List<VideoBookshelfRow> rows,
  Map<String, String> names,
  VideoLibrarySnapshot? library,
});

typedef _VideoBookshelfInventory = ({
  Map<String, String> names,
  VideoLibrarySnapshot library,
});

/// Reads the original stores directly. The bookshelf is a view, not a second
/// favorites/history database that can drift from individual plugins.
abstract final class VideoBookshelfIndex {
  static final store = VideoLibraryStore.shared;
  static final changes = ValueNotifier<int>(0);
  static bool _bound = false;
  static final _repositories = <String, ApiVideoRepository>{};
  static final _inventoryReads =
      <bool, ({int revision, Future<_VideoBookshelfInventory> task})>{};
  static void _bind() {
    if (_bound) return;
    _bound = true;
    void changed() => changes.value++;
    store.addListener(changed);
    VideoWatchHistory.changes.addListener(changed);
    VideoExportRecords.exportsChanged.addListener(changed);
    VideoLocalResources.changes.addListener(changed);
    VideoDownloadedDetails.changes.addListener(changed);
    PluginRegistryService.I.stream.listen((_) {
      _repositories.clear();
      changed();
    });
  }

  static Map<String, dynamic>? videoAction(
    Object? value, {
    Uri? home,
    String? itemId,
    int depth = 0,
  }) => videoSourceAction(value, home: home, itemId: itemId, depth: depth);

  static Map<String, dynamic>? actionForRow(
    Object? pluginInfo,
    VideoBookshelfRow row,
  ) {
    final actions = row._isStandaloneHistory
        ? videoSourceActions(
            pluginInfo,
          ).where((action) => action['type'] == 'openVideoCatalog').toList()
        : pluginInfo;
    return videoAction(actions, home: row.item.detailUrl, itemId: row.item.id);
  }

  static bool isVideoSource(String id) =>
      videoAction(PluginRegistryService.I.getCachedPluginInfo(id)) != null;

  static Future<Map<String, String>> sourceNames() async =>
      Map.of((await _inventory(includeDownloads: true)).names);

  static Future<Map<String, String>> recordSourceNames() async =>
      Map.of((await _inventory(includeDownloads: false)).names);

  static Future<_VideoBookshelfInventory> _inventory({
    required bool includeDownloads,
  }) async {
    _bind();
    final revision = changes.value;
    final pending = _inventoryReads[includeDownloads];
    if (pending != null && pending.revision == revision) {
      return pending.task;
    }
    // Favorites/history and their source rail share the same record inventory.
    // A separate download projection can require native file verification.
    final task = _readInventory(includeDownloads: includeDownloads);
    _inventoryReads[includeDownloads] = (revision: revision, task: task);
    try {
      return await task;
    } finally {
      if (identical(_inventoryReads[includeDownloads]?.task, task)) {
        _inventoryReads.remove(includeDownloads);
      }
    }
  }

  static Future<_VideoBookshelfInventory> _readInventory({
    required bool includeDownloads,
  }) async {
    final snapshot = await store.read();
    final prefs = await SharedPreferences.getInstance();
    final ids = <String>{
      for (final row in snapshot.favorites.values)
        if (!row.deleted && row.data['source'] is String)
          row.data['source'] as String,
      for (final key in prefs.getKeys())
        if (key.startsWith('breeze.video.history.v1.'))
          key.substring('breeze.video.history.v1.'.length),
      if (includeDownloads) ...{
        for (final row in await VideoExportRecords.read())
          row['source'] as String,
        for (final row in await VideoLocalResources.read())
          row['source'] as String,
      },
      for (final id in PluginRegistryService.I.snapshot.keys)
        if (PluginRegistryService.I.getByUuid(id)?.isDeleted == false &&
            isVideoSource(id))
          id,
    };
    final names = <String, String>{
      for (final id in ids)
        if (id.isNotEmpty)
          id:
              (PluginRegistryService.I.getCachedPluginInfo(id)?['name']
                  as String?) ??
              t.bookshelf.unknownSource,
    };
    for (final id in names.keys.toList()) {
      if (PluginRegistryService.I.getByUuid(id)?.isDeleted != false) {
        names[id] = '${names[id]} · ${t.pluginLifecycle.notInstalled}';
      }
    }
    return (names: names, library: snapshot);
  }

  static String _key(String source, String kind, String id) =>
      sha256.convert(utf8.encode('$source|$kind|$id')).toString();

  static ApiVideoItem _withDuration(ApiVideoItem item, String duration) =>
      duration.isEmpty
      ? item
      : ApiVideoItem.fromJson({
          ...item.toLibraryJson(),
          'sourceDuration': duration,
        }, home: item.detailUrl);

  static String _resourceDuration(
    Map<String, dynamic> row,
    List<VideoWatchRecord> history,
  ) {
    final milliseconds = row['durationMs'];
    if (milliseconds is int && milliseconds > 0) {
      final known = formatKnownVideoDuration(
        Duration(milliseconds: milliseconds),
      );
      if (known.isNotEmpty) return known;
    }
    final declared = knownVideoDurationText(
      apiVideoText(row['sourceDuration']),
    );
    if (declared.isNotEmpty) return declared;
    final url = Uri.tryParse(apiVideoText(row['url']));
    final watch = url == null ? null : videoPlaybackIdentity(url);
    final record = watch == null
        ? null
        : history.where((record) => record.watchUrl == watch).firstOrNull;
    return record == null ? '' : formatKnownVideoDuration(record.duration);
  }

  static Future<List<VideoBookshelfRow>> load(
    ShelfPageMode mode,
    SearchStatusState search,
  ) async => (await readPane(mode, search)).rows;

  static Future<VideoBookshelfSnapshot> readPane(
    ShelfPageMode mode,
    SearchStatusState search,
  ) async {
    final inventory = await _inventory(
      includeDownloads: mode == ShelfPageMode.download,
    );
    final names = inventory.names, snapshot = inventory.library;
    final sources = search.sources.isEmpty
        ? names.keys.toSet()
        : search.sources.toSet();
    final rows = <VideoBookshelfRow>[];
    final histories = <String, Future<List<VideoWatchRecord>>>{};
    Future<List<VideoWatchRecord>> historyFor(String source) =>
        histories.putIfAbsent(source, () => VideoWatchHistory.read(source));
    for (final source in sources) {
      if (mode == ShelfPageMode.favorite) {
        final favorites = snapshot.itemsFor(source).toList();
        Map<String, ApiVideoItem> known = {};
        try {
          known = await VideoDownloadedDetails.readKnownItems(
            source,
            favorites.map((row) => row.item),
          );
        } catch (_) {
          /* Optional local basics never prevent showing favorites. */
        }
        for (final row in favorites) {
          final cached = known[row.item.id];
          final displayed = videoShelfItemWithKnownMetadata(row.item, cached);
          var duration = videoCoverDurationText(
            row.item.sourceDuration,
            clockFallback: row.item.remarks,
          );
          if (duration.isEmpty) {
            duration = cached == null
                ? ''
                : videoCoverDurationText(
                    cached.sourceDuration,
                    clockFallback: cached.remarks,
                  );
            if (duration.isEmpty) {
              final exact = videoPlaybackIdentity(row.item.detailUrl);
              // A work's arbitrary episode is not its total. Only an explicit
              // single complete episode or an exact video identity grants this
              // projection; unknown/ongoing series keep their unknown badge.
              final singleComplete =
                  cached != null &&
                  cached.lines.isNotEmpty &&
                  cached.plannedEpisodes <= 1 &&
                  (cached.plannedEpisodes == 1 || cached.finished) &&
                  cached.lines.every((line) => line.episodes.length == 1);
              if (exact != null || singleComplete) {
                final watches = <Uri>{
                  if (exact != null) exact,
                  if (singleComplete)
                    for (final line in cached.lines)
                      line.episodes.single.watchUrl,
                };
                final record = (await historyFor(source))
                    .where((record) => watches.contains(record.watchUrl))
                    .firstOrNull;
                if (record != null)
                  duration = formatKnownVideoDuration(record.duration);
              }
            }
          }
          rows.add(
            VideoBookshelfRow(
              key: _key(source, 'favorite', row.item.id),
              source: source,
              item: _withDuration(displayed, duration),
              recordKey: row.key,
              folderIds: snapshot.foldersOf(row.key),
              updatedAt: DateTime.fromMillisecondsSinceEpoch(row.clock),
            ),
          );
        }
      } else if (mode == ShelfPageMode.history) {
        for (final row in await historyFor(source)) {
          ApiVideoItem item;
          try {
            final action = videoAction(
              PluginRegistryService.I.getCachedPluginInfo(source),
              home: row.watchUrl,
            );
            final capabilities = ApiVideoCapabilities.fromJson(
              asJsonMap(asJsonMap(action?['payload'])['capabilities']),
            );
            final watchId = row.watchUrl.queryParameters['v'];
            // History reads already validate identities; keep this branch safe
            // if a future reader supplies an unsupported third-party /watch.
            item =
                row.watchUrl.path == '/watch' &&
                    watchId != null &&
                    RegExp(r'^\d+$').hasMatch(watchId)
                ? ApiVideoItem(
                    id: watchId,
                    title: row.title,
                    detailUrl: row.watchUrl,
                    coverUrl: row.coverUrl,
                    sourceDuration: formatKnownVideoDuration(row.duration),
                    typeName: row.metadata['typeName'] ?? '',
                    genres: row.metadata['genres'] ?? '',
                    year: row.metadata['year'] ?? '',
                    area: row.metadata['area'] ?? '',
                    language: row.metadata['language'] ?? '',
                    writers: row.metadata['writers'] ?? '',
                  )
                : apiVideoHistoryItem(
                    row,
                    itemNamespace: capabilities.itemNamespace,
                    containCover: capabilities.posterAspectRatio > 1,
                  );
          } on FormatException {
            continue;
          }
          rows.add(
            VideoBookshelfRow(
              key: _key(source, 'history', '${row.watchUrl}'),
              source: source,
              item: item,
              watchUrl: row.watchUrl,
              updatedAt: row.updatedAt,
              progress:
                  '${row.position.inMinutes}:${(row.position.inSeconds % 60).toString().padLeft(2, '0')}',
            ),
          );
        }
      }
    }
    if (mode == ShelfPageMode.download) {
      final managed = await VideoLocalResources.read();
      final present = managed.where((row) => row['available'] == true).toList();
      final publicMetadata = await VideoDownloadedDetails.readForResources(
        present,
      );
      for (var position = 0; position < present.length; position++) {
        final row = present[position];
        final candidate = publicMetadata[position];
        final metadata =
            candidate != null &&
                candidate.source == row['source'] &&
                candidate.resourceId == row['resourceId'] &&
                candidate.watchUrl.toString() == row['url'] &&
                candidate.canonicalWorkId?.isNotEmpty == true
            ? candidate
            : null;
        final source = row['source'] as String;
        if (!sources.contains(source)) continue;
        final url = Uri.parse(row['url'] as String),
            id = row['resourceId'] as String;
        rows.add(
          VideoBookshelfRow(
            key: _key(source, 'local', id),
            source: source,
            localResourceId: id,
            watchUrl: url,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(row['at'] as int),
            item: ApiVideoItem(
              id: id,
              title: row['title'] as String,
              detailUrl: url,
              coverUrl: apiVideoHttps(row['cover']),
              remarks: '${t.download.videoSaved} · ${row['quality']}',
              description: metadata?.description ?? '',
              genres: metadata?.tags.join(' / ') ?? '',
              typeName: metadata?.typeName ?? '',
              year: metadata?.year ?? '',
              area: metadata?.region ?? '',
              language: metadata?.language ?? '',
              actors: metadata?.actors ?? '',
              directors: metadata?.directors ?? '',
              writers: metadata?.writers ?? '',
              sourceDuration: _resourceDuration(row, await historyFor(source)),
            ),
            facetFields: {
              'quality': {row['quality'] as String},
            },
          ),
        );
      }
      for (final row in await VideoExportRecords.read()) {
        if (present.any(
          (item) =>
              item['source'] == row['source'] && item['url'] == row['url'],
        )) {
          continue;
        }
        final source = row['source'] as String;
        if (!sources.contains(source)) continue;
        final url = Uri.parse(row['url'] as String);
        rows.add(
          VideoBookshelfRow(
            key: _key(source, 'export', row['key'] as String),
            source: source,
            recordKey: row['key'] as String,
            watchUrl: url,
            item: ApiVideoItem(
              id: url.queryParameters['v'] ?? url.path,
              title: row['title'] as String,
              detailUrl: url,
              coverUrl: apiVideoHttps(row['cover']),
              remarks:
                  '${t.bookshelf.exportedVideo} · ${apiVideoText(row['quality'])}',
              sourceDuration: _resourceDuration(row, await historyFor(source)),
            ),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(row['at'] as int),
            facetFields: {
              if (apiVideoText(row['quality']).trim().isNotEmpty)
                'quality': {apiVideoText(row['quality']).trim()},
            },
          ),
        );
      }
    }
    final query = normalizePublicSearchText(search.keyword);
    if (query.isNotEmpty) {
      rows.removeWhere(
        (row) => !normalizePublicSearchText(
          '${apiCatalogFacetEntry(row.item).searchText} ${names[row.source] ?? ''}',
        ).contains(query),
      );
    }
    final ascending = search.sort.endsWith('a');
    rows.sort(
      (a, b) => ascending
          ? a.updatedAt.compareTo(b.updatedAt)
          : b.updatedAt.compareTo(a.updatedAt),
    );
    return (
      rows: rows,
      names: names,
      library: mode == ShelfPageMode.favorite ? snapshot : null,
    );
  }

  static ApiVideoRepository? _repository(String source, Uri detailUrl) {
    final action = videoAction(
      PluginRegistryService.I.getCachedPluginInfo(source),
      home: detailUrl,
    );
    if (action?['type'] != 'openVideoLibrary') return null;
    final payload = asJsonMap(action!['payload']);
    final home = apiVideoHttps(payload['url']);
    if (home == null) return null;
    return _repositories.putIfAbsent(
      '$source|$home',
      () => ApiVideoRepository(
        source: source,
        home: home,
        catalogFn: apiVideoText(payload['catalogFnPath']),
        detailFn: apiVideoText(payload['detailFnPath']),
        playbackFn: apiVideoText(payload['playbackFnPath']),
        capabilities: ApiVideoCapabilities.fromJson(
          asJsonMap(payload['capabilities']),
        ),
      ),
    );
  }

  static Future<ApiVideoItem> enrich(VideoBookshelfRow row) async =>
      row.localResourceId != null || row._isStandaloneHistory
      ? row.item
      : await _repository(row.source, row.item.detailUrl)?.enrich(row.item) ??
            row.item;

  static Future<void> open(
    BuildContext context,
    VideoBookshelfRow row, {
    bool forDownloadRecovery = false,
    bool fromDownloadDetails = false,
  }) async {
    if (row.localResourceId != null) {
      await openLocalVideo(context, row.localResourceId!);
      return;
    }
    var plugin = PluginRegistryService.I.getByUuid(row.source);
    if (plugin == null || plugin.isDeleted) {
      if (!await ensurePluginInstalled(context, row.source) ||
          !context.mounted) {
        return;
      }
      plugin = PluginRegistryService.I.getByUuid(row.source);
    }
    final action = actionForRow(
      PluginRegistryService.I.getCachedPluginInfo(row.source),
      row,
    );
    final payload = asJsonMap(action?['payload']);
    final home = apiVideoHttps(payload['url']);
    if (plugin?.isActive != true ||
        action == null ||
        home == null ||
        row.item.detailUrl.origin != home.origin) {
      await showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
          content: Text(t.bookshelf.videoSourceUnavailable),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: Text(t.common.done),
            ),
          ],
        ),
      );
      return;
    }
    final resume = row.resumeAt(home);
    await DiscoverRouter.route(
      context,
      action: {
        ...action,
        'payload': {
          ...payload,
          'source': row.source,
          'bookshelfItem': row.item.toLibraryJson(),
          if (resume != null) 'bookshelfResume': resume.toString(),
          if (forDownloadRecovery) 'forDownloadRecovery': true,
          if (fromDownloadDetails) 'fromDownloadDetails': true,
          if (action['type'] == 'openVideoCatalog')
            'initialWatchUrl':
                resume?.toString() ?? row.item.detailUrl.toString(),
        },
      },
      currentFrom: row.source,
    );
  }

  static Future<void> remove(
    ShelfPageMode mode,
    List<VideoBookshelfRow> rows,
  ) async {
    if (mode == ShelfPageMode.favorite) {
      await store.removeFavorites(rows.map((r) => r.recordKey!).toSet());
    } else if (mode == ShelfPageMode.history) {
      for (final row in rows) {
        if (row.watchUrl != null) {
          await VideoWatchHistory.remove(row.source, row.watchUrl);
        }
      }
    } else {
      for (final row in rows) {
        if (row.localResourceId != null) {
          await VideoLocalResources.remove(row.localResourceId!);
        }
      }
      final receipts = rows
          .where((row) => row.localResourceId == null)
          .map((row) => row.recordKey!)
          .toSet();
      if (receipts.isNotEmpty) {
        await VideoExportRecords.remove(receipts);
        await afterVideoRemoval();
      }
    }
  }
}
