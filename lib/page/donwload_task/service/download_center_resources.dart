import 'dart:async';
import 'package:zephyr/service/known_comic_metadata.dart';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/page/download/models/unified_comic_download.dart';
import 'package:zephyr/page/download/models/download_chapter.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/page/bookshelf/service/shelf_facet_adapters.dart';

typedef DownloadVideoRead = ({
  int revision,
  Future<List<Map<String, dynamic>>> verified,
  Future<List<Map<String, dynamic>>> enriched,
  Future<List<Map<String, dynamic>>> Function() readTransfers,
  Future<List<Map<String, dynamic>>> Function() readCheckedMp4,
});

class IncompleteDownloadVideoInventory implements Exception {
  const IncompleteDownloadVideoInventory(this.checkedRows);

  final List<Map<String, dynamic>> checkedRows;
}

/// A persistent resource is independent of its disposable transfer history.
/// No task, path or completion claim is written while building this view.
class DownloadComicResource {
  factory DownloadComicResource(UnifiedComicDownload record) =>
      DownloadComicResource._(record, resolveDownloadChapterViews(record));

  DownloadComicResource._(
    UnifiedComicDownload record,
    ({
      List<UnifiedComicDownloadStoredChapter> stored,
      List<DownloadChapter> download,
    })
    views,
  ) : key = record.uniqueKey,
      source = record.source,
      comicId = record.comicId,
      title = record.title,
      cover = record.cover,
      chapters = views.stored,
      downloadChapters = views.download,
      metricsVersion = sha256
          .convert(
            utf8.encode(
              '${record.updatedAt.microsecondsSinceEpoch}|${record.cover}|${record.chapters}|${record.detailJson}',
            ),
          )
          .toString(),
      fields = shelfFacetFieldsFromMetadata(record.metadata),
      downloadedAt = record.downloadedAt;

  final String source, comicId, title, cover;
  final String key;
  final List<UnifiedComicDownloadStoredChapter> chapters;
  final List<DownloadChapter> downloadChapters;
  final String metricsVersion;
  final Map<String, Set<String>> fields;
  int get chapterCount => chapters.length;
  final DateTime downloadedAt;
}

/// Retains at most the current inventory. Exact raw comparisons also cover
/// metadata repairs and imports which may retain the original timestamp.
class DownloadComicResourceProjection {
  var _previous =
      <
        String,
        ({UnifiedComicDownload record, DownloadComicResource resource})
      >{};
  List<DownloadComicResource> _result = const [];
  List<DownloadComicResource> get snapshot => _result;

  List<DownloadComicResource> project(List<UnifiedComicDownload> records) {
    final next =
        <
          String,
          ({UnifiedComicDownload record, DownloadComicResource resource})
        >{};
    for (final record in records) {
      if (record.deleted || record.source.isEmpty || record.comicId.isEmpty)
        continue;
      final resource = projectOne(record);
      next[record.uniqueKey] = (record: record, resource: resource);
    }
    final unchanged =
        next.length == _previous.length && _sameOrderAndResources(next);
    _previous = next;
    if (!unchanged) {
      _result = List.unmodifiable(
        next.values.map((entry) => entry.resource).toList()
          ..sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt)),
      );
    }
    return _result;
  }

  bool _sameOrderAndResources(
    Map<String, ({UnifiedComicDownload record, DownloadComicResource resource})>
    next,
  ) {
    final prior = _previous.values.iterator;
    return next.values.every(
      (value) =>
          prior.moveNext() && identical(value.resource, prior.current.resource),
    );
  }

  DownloadComicResource projectOne(UnifiedComicDownload record) {
    final prior = _previous[record.uniqueKey];
    return prior != null && _matches(prior.record, record)
        ? prior.resource
        : DownloadComicResource(record);
  }

  bool _matches(UnifiedComicDownload a, UnifiedComicDownload b) =>
      a.source == b.source &&
      a.comicId == b.comicId &&
      a.title == b.title &&
      a.cover == b.cover &&
      a.downloadedAt == b.downloadedAt &&
      a.updatedAt == b.updatedAt &&
      a.chapters == b.chapters &&
      a.detailJson == b.detailJson &&
      a.metadata == b.metadata;
}

abstract final class DownloadCenterResources {
  static final _comicProjection = DownloadComicResourceProjection();
  static int _comicProjectionRevision = 0;

  static List<DownloadComicResource> _projectComics(
    List<UnifiedComicDownload> records,
  ) {
    _comicProjectionRevision++;
    return _comicProjection.project(records);
  }

  static List<DownloadComicResource> readComics() =>
      _projectComics(objectbox.unifiedDownloadBox.getAll());

  static Future<List<DownloadComicResource>> readComicsAsync() async {
    final query = objectbox.unifiedDownloadBox
        .query(UnifiedComicDownload_.deleted.equals(false))
        .build();
    final revision = _comicProjectionRevision;
    try {
      final records = await query.findAsync();
      if (revision != _comicProjectionRevision)
        return _comicProjection.snapshot;
      return _projectComics(records);
    } finally {
      query.close();
    }
  }

  static Stream<List<DownloadComicResource>> watchComics() {
    unawaited(restoreKnownComicMetadata(kind: 'download'));
    return objectbox.unifiedDownloadBox
        .query(UnifiedComicDownload_.deleted.equals(false))
        .watch(triggerImmediately: true)
        .map((query) => _projectComics(query.find()))
        .distinct();
  }

  static Stream<DownloadComicResource?> watchComic(
    String source,
    String comicId,
  ) {
    return objectbox.unifiedDownloadBox
        .query(
          UnifiedComicDownload_.deleted
              .equals(false)
              .and(UnifiedComicDownload_.source.equals(source))
              .and(UnifiedComicDownload_.comicId.equals(comicId)),
        )
        .watch(triggerImmediately: true)
        .map((query) {
          final row = query.find().firstOrNull;
          return row == null ? null : _comicProjection.projectOne(row);
        })
        .distinct();
  }

  /// The transfer log can retain historical file-removal evidence. A saved
  /// row enters the center only with resource evidence or an export receipt.
  static bool showsVideo(Map<String, dynamic> row) =>
      row['status'] != 'saved' ||
      (row['fileRemoved'] != true &&
          (row['kind'] != 'transfer' ||
              row['available'] == true ||
              row['fileInvalid'] == true));

  static DownloadVideoRead? _videoRead;
  static int _videoRevision = 0;
  static bool _videoReadFresh = false;
  static Future<List<Map<String, dynamic>>> readVideos({
    bool waitForStorage = false,
    bool fresh = false,
    bool afterCurrentRead = false,
  }) {
    final read = readVideoPhases(
      fresh: fresh,
      afterRevision: afterCurrentRead ? _videoRead?.revision : null,
    ).enriched;
    return waitForStorage ? read : read.timeout(const Duration(seconds: 8));
  }

  static DownloadVideoRead readVideoPhases({
    int? afterRevision,
    bool fresh = false,
  }) {
    // Keep the in-flight read until it actually finishes. A caller deadline
    // cannot cancel native work or remove a read from the storage queue.
    final current = _videoRead;
    if (current != null &&
        current.revision != afterRevision &&
        (!fresh || _videoReadFresh)) {
      return current;
    }
    // A caller that already received this verified snapshot can refresh it
    // while the old display-only fallbacks are still pending.
    return _startVideoRead(fresh: fresh);
  }

  static DownloadVideoRead _startVideoRead({required bool fresh}) {
    final checkedMp4 = Completer<List<Map<String, dynamic>>>();
    final verified =
        _readVerifiedVideos(
          fresh: fresh,
          onCheckedMp4: checkedMp4.complete,
        ).whenComplete(() {
          if (!checkedMp4.isCompleted) checkedMp4.complete([]);
        });
    final enriched = verified.then(_enrichVerifiedVideos);
    Future<List<Map<String, dynamic>>>? transfers;
    Future<List<Map<String, dynamic>>>? mp4;
    final DownloadVideoRead read = (
      revision: ++_videoRevision,
      verified: verified,
      enriched: enriched,
      readTransfers: () => transfers ??= _readEarlyTransfers(),
      readCheckedMp4: () => mp4 ??= checkedMp4.future.then(
        (resources) => mergeVideos(
          [],
          resources.where((row) => row['available'] == true).toList(),
        ),
      ),
    );
    _videoRead = read;
    _videoReadFresh = fresh;
    void release() {
      if (identical(_videoRead, read)) _videoRead = null;
    }

    enriched.then(
      (_) => release(),
      onError: (Object _, StackTrace _) => release(),
    );
    return read;
  }

  /// A transfer can be shown while file verification is pending. Its durable
  /// status cannot certify an MP4/HLS package or a system export receipt.
  static Future<List<Map<String, dynamic>>> _readEarlyTransfers() async {
    try {
      final snapshot = await VideoExportRecords.readTaskSnapshot();
      return [
        for (final row in snapshot)
          if (row['status'] != 'saved' && row['status'] != 'cancelled') row,
      ];
    } catch (_) {
      // The complete read has its own error/retention path.
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _readVerifiedVideos({
    required bool fresh,
    required void Function(List<Map<String, dynamic>>) onCheckedMp4,
  }) async {
    // One validated index snapshot per projection; task reading must not
    // enumerate the same native package list a second time.
    final inventory = await VideoLocalResources.readDownloadInventory(
      fresh: fresh,
      onCheckedMp4: onCheckedMp4,
    );
    final resources = inventory.rows;
    if (!inventory.complete) {
      throw IncompleteDownloadVideoInventory(mergeVideos([], resources));
    }
    final rows = mergeVideos(
      await VideoExportRecords.readTasks(resources: resources),
      resources,
    ).where(showsVideo).toList();
    await enrichVideoRows(rows, includeFavoriteFallback: false);
    return rows;
  }

  static Future<List<Map<String, dynamic>>> _enrichVerifiedVideos(
    List<Map<String, dynamic>> verified,
  ) async {
    final rows = [
      for (final row in verified) {...row},
    ];
    await enrichVideoRows(rows);
    // Older managed indexes may predate poster or total-duration metadata. Recover only an exact
    // source + canonical page match from existing local records, once per read.
    // This is a display projection: never rewrite the index or fetch a poster.
    final missing = rows
        .where(
          (row) =>
              row['local'] == true &&
              (_publicVideoCover(row['cover']) == null ||
                  !_hasVideoDurationMs(row)) &&
              row['source'] is String &&
              (row['source'] as String).isNotEmpty &&
              row['url'] is String &&
              VideoWatchRecord.canonicalUrl(
                    Uri.tryParse(row['url'] as String) ?? Uri(),
                  ) !=
                  null,
        )
        .toList();
    if (missing.isEmpty) return rows;
    final sources = missing.map((row) => row['source'] as String).toSet();
    final covers = <String, Map<Uri, String>>{};
    final durations = <String, Map<Uri, int>>{};
    final sourceDurations = <String, Map<Uri, String>>{};
    for (final source in sources) {
      final byPage = covers[source] = {};
      final byDuration = durations[source] = {};
      sourceDurations[source] = {};
      try {
        for (final history in await VideoWatchHistory.read(source)) {
          final page = VideoWatchRecord.canonicalUrl(history.watchUrl);
          final cover = _publicVideoCover(history.coverUrl?.toString());
          if (page != null) {
            if (cover != null) byPage.putIfAbsent(page, () => cover);
            final totalMs = history.duration.inMilliseconds;
            if (totalMs > 0) byDuration.putIfAbsent(page, () => totalMs);
          }
        }
      } catch (_) {
        // Optional viewing metadata must not make owned downloads disappear.
      }
    }
    try {
      final library = await VideoLibraryStore.shared.read();
      for (final source in sources) {
        for (final entry in library.itemsFor(source)) {
          final page = VideoWatchRecord.canonicalUrl(entry.item.detailUrl);
          final cover = _publicVideoCover(entry.item.coverUrl?.toString());
          if (page != null && cover != null) {
            covers[source]!.putIfAbsent(page, () => cover);
          }
          if (page != null && entry.item.sourceDuration.trim().isNotEmpty) {
            sourceDurations[source]!.putIfAbsent(
              page,
              () => entry.item.sourceDuration,
            );
          }
        }
      }
    } catch (_) {
      // A missing/invalid optional library is not authority to alter downloads.
    }
    for (final row in missing) {
      final page = VideoWatchRecord.canonicalUrl(
        Uri.parse(row['url'] as String),
      );
      final cover = covers[row['source']]?[page];
      if (_publicVideoCover(row['cover']) == null && cover != null)
        row['cover'] = cover;
      final duration = durations[row['source']]?[page];
      if (!_hasVideoDurationMs(row) && duration != null)
        row['durationMs'] = duration;
      final sourceDuration = sourceDurations[row['source']]?[page];
      if ((row['sourceDuration'] is! String ||
              (row['sourceDuration'] as String).trim().isEmpty) &&
          sourceDuration != null)
        row['sourceDuration'] = sourceDuration;
    }
    return rows;
  }

  /// Local metadata keeps the early transfer list grouped while native files
  /// are independently checked. This never claims that a file exists.
  static Future<void> enrichVideoRows(
    List<Map<String, dynamic>> rows, {
    bool includeFavoriteFallback = true,
  }) async {
    if (rows.isEmpty) return;
    // Read the exact source/page's existing public basics once per snapshot.
    // This is a display-only projection; unknown tags stay absent.
    try {
      final metadata = await VideoDownloadedDetails.readForResources(
        rows,
        includeFavoriteFallback: includeFavoriteFallback,
        includeLocalCover: false,
      );
      for (var index = 0; index < rows.length; index++) {
        final value = metadata[index];
        if (value == null) continue;
        final row = rows[index];
        if (value.tags.isNotEmpty) row['publicTags'] = value.tags;
        final exactPage =
            value.source == row['source'] &&
            value.resourceId == row['resourceId'] &&
            value.watchUrl.toString() == row['url'];
        final bound = exactPage && value.canonicalWorkId?.isNotEmpty == true;
        if (exactPage && value.creatorName.isNotEmpty) {
          row['publicCreatorName'] = value.creatorName;
        }
        if (bound || exactPage && value.creatorName.isNotEmpty) {
          row['publicSearchText'] = [
            if (bound) ...[
              value.title,
              value.episodeLabel,
              value.description,
              value.actors,
              value.directors,
              value.writers,
            ],
            value.creatorName,
          ].join(' ');
        }
        if (row['metadata'] == null) {
          final fields = [
            if (value.typeName.isNotEmpty)
              {'type': 'category', 'value': value.typeName},
            if (bound && value.writers.isNotEmpty)
              {'type': 'author', 'value': value.writers},
            if (value.year.isNotEmpty) {'type': 'year', 'value': value.year},
            if (value.region.isNotEmpty)
              {'type': 'area', 'value': value.region},
            if (value.language.isNotEmpty)
              {'type': 'language', 'value': value.language},
            if (value.tags.isNotEmpty) {'type': 'tag', 'value': value.tags},
          ];
          if (fields.isNotEmpty) row['metadata'] = jsonEncode(fields);
        }

        if (value.source == row['source'] &&
            value.watchUrl.toString() == row['url'] &&
            value.canonicalWorkId?.isNotEmpty == true) {
          row.addAll({
            'publicWorkIdentity': value.canonicalWorkId,
            'publicModuleNamespace': value.moduleNamespace,
            'publicWorkTitle': value.title,
            'publicPlannedEpisodes': value.plannedEpisodes,
            'publicEpisodeLabel': value.episodeLabel,
            if (value.episodeOrder != null)
              'publicEpisodeOrder': value.episodeOrder,
          });
        }
      }
    } catch (_) {
      // Optional metadata must never hide a transfer or a playable local file.
    }
  }

  static bool _hasVideoDurationMs(Map<String, dynamic> row) =>
      row['durationMs'] is int && (row['durationMs'] as int) > 0;

  static String? _publicVideoCover(Object? value) {
    if (value is! String || value.length > 4096) return null;
    final image = Uri.tryParse(value);
    if (image == null ||
        image.scheme != 'https' ||
        image.host.isEmpty ||
        image.userInfo.isNotEmpty ||
        image.hasQuery ||
        image.hasFragment ||
        (image.hasPort && image.port != 443))
      return null;
    return value;
  }

  static List<Map<String, dynamic>> mergeVideos(
    List<Map<String, dynamic>> tasks,
    List<Map<String, dynamic>> resources,
  ) {
    final rows = <Map<String, dynamic>>[];
    final saved = <String, Map<String, dynamic>>{};
    final indexed = {
      for (final row in resources)
        if (row['resourceId'] is String) row['resourceId'] as String: row,
    };
    for (final task in tasks) {
      final row = Map<String, dynamic>.from(task);
      final id = row['resourceId'];
      final indexedResource = indexed[id];
      if (row['status'] == 'saved' &&
          row['local'] == true &&
          indexedResource != null) {
        row['resourceVersion'] = VideoLocalResources.resourceVersion(
          indexedResource,
        );
      }
      if (row['status'] == 'saved' &&
          row['local'] == true &&
          row['fileRemoved'] != true &&
          row['fileInvalid'] != true &&
          id is String) {
        final previous = saved[id];
        if (previous != null) {
          (previous['recordKeys'] as List<String>).add(row['key'] as String);
          continue;
        }
        final resource = indexedResource?['available'] == true
            ? indexedResource
            : null;
        if (resource != null) {
          row['startedAt'] = row['at'];
          row['at'] = resource['at'];
          row['completedAt'] = resource['at'];
          row['bytes'] = resource['bytes'];
          // Preserve the validated resource contract on task-backed rows too.
          row['available'] = resource['available'];
          row['filePresent'] = resource['filePresent'];
          if (resource['format'] == 'hls') {
            for (final field in [
              'format',
              'assetId',
              'generation',
              'taskKey',
              'showTask',
            ]) {
              row[field] = resource[field];
            }
          }
          for (final field in [
            'source',
            'url',
            'title',
            'quality',
            'sourceDuration',
          ]) {
            if (resource[field] is String &&
                (resource[field] as String).isNotEmpty) {
              row[field] = resource[field];
            }
          }
          if (_hasVideoDurationMs(resource))
            row['durationMs'] = resource['durationMs'];
          final cover = _publicVideoCover(resource['cover']);
          if (cover != null) row['cover'] = cover;
        }
        row['recordKeys'] = <String>[row['key'] as String];
        saved[id] = row;
      }
      rows.add(row);
    }
    final represented = {
      for (final row in rows)
        if (row['status'] == 'saved' &&
            row['local'] == true &&
            row['fileRemoved'] != true &&
            row['resourceId'] is String)
          row['resourceId'] as String,
    };
    for (final resource in resources) {
      final id = resource['resourceId'];
      if ((resource['available'] != true && resource['filePresent'] != true) ||
          id is! String ||
          !represented.add(id))
        continue;
      rows.add({
        ...resource,
        'resourceVersion': VideoLocalResources.resourceVersion(resource),
        'key': 'resource:$id',
        'status': 'saved',
        'local': true,
        'resourceOnly': true,
        'fileRemoved': false,
        'fileInvalid': resource['available'] != true,
        'completedAt': resource['at'],
      });
    }
    rows.sort((a, b) => (b['at'] as int).compareTo(a['at'] as int));
    return rows;
  }
}
