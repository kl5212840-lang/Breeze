import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:zephyr/util/text/public_search_text.dart';

import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/bookshelf/service/shelf_facet_adapters.dart';
import 'package:zephyr/page/donwload_task/service/download_center_resources.dart';
import 'package:zephyr/page/donwload_task/service/download_resource_metrics.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_download_progress.dart';
import 'package:zephyr/service/download/download_task_repository.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';

/// A display identity is opaque. Never recover source/ID by splitting a key.
class DownloadCenterItem {
  const DownloadCenterItem({
    required this.key,
    required this.source,
    required this.title,
    required this.priority,
    required this.at,
    this.comicId,
    this.tasks = const [],
    this.resource,
    this.video,
    this.videoFields = const {},
    this.comicSize,
  });

  final String key, source, title;
  final String? comicId;
  final List<DownloadTask> tasks;
  final DownloadComicResource? resource;
  final Map<String, dynamic>? video;
  final int priority, at;
  final DownloadResourceSize? comicSize;
  bool get isVideo => video != null;
  DateTime? get completedAt {
    final comicTime = resource?.downloadedAt;
    if (comicTime != null && comicTime.millisecondsSinceEpoch > 0) {
      return comicTime;
    }
    final value = video?['completedAt'];
    return video?['status'] == 'saved' &&
            video?['local'] == true &&
            video?['fileRemoved'] != true &&
            video?['fileInvalid'] != true &&
            value is int &&
            value > 0
        ? DateTime.fromMillisecondsSinceEpoch(value, isUtc: true)
        : null;
  }

  int? get sizeBytes {
    if (!isVideo) {
      return comicSize?.resourceKey == resource?.key &&
              comicSize?.version == resource?.metricsVersion
          ? comicSize?.sizeBytes
          : null;
    }
    final bytes = video?['bytes'];
    return video?['status'] == 'saved' &&
            video?['local'] == true &&
            video?['fileRemoved'] != true &&
            video?['fileInvalid'] != true &&
            bytes is int &&
            bytes > 0
        ? bytes
        : null;
  }

  int? get totalBytes {
    if (!isVideo) return null;
    if (sizeBytes case final bytes?) return bytes;
    return VideoDownloadByteProgress.fromRow(video!).total;
  }

  int? get receivedBytes {
    if (!isVideo) return null;
    if (sizeBytes case final bytes?) return bytes;
    final received = VideoDownloadByteProgress.fromRow(video!).received;
    return received is int && received >= 0 ? received : null;
  }

  final Map<String, Set<String>> videoFields;
  Map<String, Set<String>> get fields => resource?.fields ?? videoFields;
  Map<String, Set<String>> get facetFields {
    final result = {
      for (final entry in fields.entries) entry.key: {...entry.value},
    };
    if (isVideo) {
      final quality = '${video?['quality'] ?? ''}'.trim();
      if (quality.isNotEmpty) result['quality'] = {quality};
      final status = '${video?['status'] ?? ''}';
      if (status.isNotEmpty) result['status'] = {status};
      final duration = video?['durationMs'];
      if (duration is num && duration > 0) {
        result['duration'] = {
          duration < 600000
              ? 'short'
              : duration < 1800000
              ? 'medium'
              : duration < 3600000
              ? 'long'
              : 'hour',
        };
      }
    } else {
      final statuses = <String>{};
      for (final task in tasks) {
        final state = const DownloadTaskRepository()
            .readPayload(task)
            ?.stateCode;
        if (state == 'completed' ||
            ((state == null || state.isEmpty) && task.isCompleted)) {
          statuses.add('saved');
        } else if (state != null && state.isNotEmpty) {
          statuses.add(state == 'pending' ? 'queued' : state);
        }
      }
      if (statuses.isEmpty && resource != null) statuses.add('saved');
      if (statuses.isNotEmpty) result['status'] = statuses;
    }
    return result;
  }

  Set<String> get chapterKeys => chapterProgress(tasks).keys;

  ({Set<String> keys, Set<String> completed}) chapterProgress(
    Iterable<DownloadTask> currentTasks,
  ) {
    final result = <String>{};
    final completed = <String>{};
    final ids = <String, String?>{}, requests = <String, String?>{};
    void alias(Map<String, String?> values, String key, String canonical) {
      key = key.trim();
      if (key.isEmpty) return;
      if (!values.containsKey(key)) {
        values[key] = canonical;
      } else if (values[key] != canonical) {
        values[key] = null; // A shared alias cannot merge distinct chapters.
      }
    }

    final chapters = resource?.downloadChapters;
    final stored = resource?.chapters;
    if (chapters != null && stored != null) {
      for (var i = 0; i < chapters.length; i++) {
        final chapter = chapters[i];
        final raw = i < stored.length ? stored[i] : null;
        final canonical =
            (raw?.logicalKey.isNotEmpty == true
                    ? raw!.logicalKey
                    : raw?.taskChapterId.isNotEmpty == true
                    ? raw!.taskChapterId
                    : raw?.id ?? chapter.id)
                .trim();
        if (canonical.isEmpty) continue;
        result.add(canonical);
        completed.add(canonical);
        alias(ids, chapter.id, canonical);
        alias(requests, chapter.effectiveRequestId, canonical);
        alias(requests, raw?.taskChapterId ?? '', canonical);
      }
    }
    for (final task in currentTasks) {
      final payload = const DownloadTaskRepository().readPayload(task);
      if (payload == null) continue;
      final key = payload.chapterKey.trim();
      if (key.isEmpty) continue;
      // Legacy task refs may retain request IDs while the saved chapter now
      // exposes its logical ID. Only exact, unambiguous identities converge.
      final canonical = ids.containsKey(key)
          ? ids[key] ?? key
          : requests[key] ?? key;
      result.add(canonical);
      if (payload.phaseCode != 'fileRemoved' &&
          (payload.stateCode == 'completed' ||
              (payload.stateCode.isEmpty && task.isCompleted))) {
        completed.add(canonical);
      }
    }
    return (keys: result, completed: completed);
  }

  bool matches({
    String query = '',
    bool titleOnly = false,
    String type = 'all',
    String? source,
    Set<String> categories = const {},
    Set<String> tags = const {},
    Map<String, Set<String>> facetValues = const {},
  }) {
    if (type == 'comic' && isVideo || type == 'video' && !isVideo) return false;
    if (source != null && this.source != source) return false;
    if (categories.isNotEmpty &&
        !categories.any(
          (value) => fields['category']?.contains(value) == true,
        )) {
      return false;
    }
    if (tags.isNotEmpty &&
        !tags.any((value) => fields['tags']?.contains(value) == true)) {
      return false;
    }
    if (facetValues.values.any((values) => values.isNotEmpty)) {
      final facets = facetFields;
      for (final selected in facetValues.entries) {
        if (selected.value.isNotEmpty &&
            !selected.value.any(
              (value) => facets[selected.key]?.contains(value) == true,
            )) {
          return false;
        }
      }
    }
    final needle = normalizePublicSearchText(query);
    return needle.isEmpty ||
        normalizePublicSearchText(
          [
            title,
            if (!titleOnly) ...[
              this.source,
              if (video?['publicSearchText'] case final String text) text,
              ...fields.values.expand((values) => values),
            ],
          ].join(' '),
        ).contains(needle);
  }
}

int downloadComicPriority(DownloadTask task) {
  final payload = const DownloadTaskRepository().readPayload(task);
  if (payload?.phaseCode == 'cancelling' ||
      payload?.phaseCode == downloadTaskDeletionPhase) {
    return 0;
  }
  if (payload?.stateCode == 'paused') return 1;
  if (payload?.stateCode == 'completed' && payload?.phaseCode != 'fileRemoved')
    return 3;
  if (task.isCompleted || payload?.stateCode == 'failed') return 2;
  return 0;
}

/// A completed transfer can describe a saved chapter, but cannot create one.
bool downloadCenterShowsComicTask(
  DownloadTask task,
  DownloadTaskJson? payload,
  DownloadComicResource? resource,
) {
  if (payload == null) return true;
  if (payload.phaseCode == 'fileRemoved') return false;
  if (payload.phaseCode == 'cancelling') return true;
  final completed =
      payload.stateCode == 'completed' ||
      task.isCompleted &&
          !const {'cancelled', 'failed', 'paused'}.contains(payload.stateCode);
  if (!completed) return true;
  final key = payload.chapterKey;
  return resource?.chapters.any(
        (chapter) =>
            chapter.logicalKey == key ||
            chapter.taskChapterId == key ||
            chapter.id == key,
      ) ??
      false;
}

/// Pure projection: no file scans, writes, network requests or invented tasks.
List<DownloadCenterItem> projectDownloadCenter({
  required List<DownloadTask> tasks,
  required List<DownloadComicResource> comics,
  required List<Map<String, dynamic>> videos,
  Map<String, DownloadResourceSize> comicSizes = const {},
}) {
  const repository = DownloadTaskRepository();
  final resources = {for (final comic in comics) comic.key: comic};
  final groups = <String, List<DownloadTask>>{};
  for (final task in tasks) {
    final payload = repository.readPayload(task);
    final key = payload == null
        ? 'unreadable-task:${task.id}'
        : buildDownloadTaskKey(payload.from, payload.comicId);
    if (!downloadCenterShowsComicTask(task, payload, resources[key])) continue;
    groups.putIfAbsent(key, () => []).add(task);
  }
  final result = <DownloadCenterItem>[];
  for (final key in {...groups.keys, ...resources.keys}) {
    final rows = groups[key] ?? const <DownloadTask>[];
    final resource = resources[key];
    final payload = rows.isEmpty ? null : repository.readPayload(rows.first);
    final priorities = rows.map(downloadComicPriority);
    final priority = priorities.isEmpty
        ? 3
        : priorities.reduce((a, b) => a < b ? a : b);
    result.add(
      DownloadCenterItem(
        key: 'comic:$key',
        comicId: resource?.comicId ?? payload?.comicId,
        source: resource?.source ?? payload?.from ?? '',
        title: resource?.title ?? rows.first.comicName,
        priority: priority,
        at:
            resource?.downloadedAt.millisecondsSinceEpoch ??
            (rows.isEmpty ? 0 : rows.last.id),
        tasks: rows,
        resource: resource,
        comicSize: comicSizes[key],
      ),
    );
  }
  final videoGroups = <String, List<Map<String, dynamic>>>{};
  for (final row in videos) {
    if (!DownloadCenterResources.showsVideo(row)) continue;
    String identity;
    try {
      identity = VideoLocalResources.identity(
        row['source'] as String,
        Uri.parse(row['url'] as String),
        row['format'] == 'hls'
            ? 'hls|${row['quality'] as String? ?? ''}'
            : row['quality'] as String? ?? '',
      );
    } catch (_) {
      identity = 'record:${row['key']}';
    }
    videoGroups.putIfAbsent(identity, () => []).add(row);
  }
  int videoPriority(Map<String, dynamic> row) =>
      const {'preparing', 'downloading', 'saving'}.contains(row['status'])
      ? 0
      : row['status'] == 'saved' &&
            row['fileRemoved'] != true &&
            row['fileInvalid'] != true
      ? 3
      : 2;
  for (final entry in videoGroups.entries) {
    final rows = entry.value
      ..sort((a, b) {
        final state = videoPriority(a).compareTo(videoPriority(b));
        return state != 0 ? state : (b['at'] as int).compareTo(a['at'] as int);
      });
    // A valid local resource wins over an external acknowledgment if neither
    // has an active transfer. Retain every log key for the single remove action.
    final row = rows.firstWhere(
      (row) =>
          row['local'] == true &&
          row['fileRemoved'] != true &&
          row['fileInvalid'] != true &&
          videoPriority(rows.first) == 3,
      orElse: () => rows.first,
    );
    final merged = <String, dynamic>{
      ...row,
      'recordKeys': <String>{
        for (final candidate in rows)
          if (candidate['resourceOnly'] != true) ...[
            candidate['key'] as String,
            if (candidate['recordKeys'] is List<String>)
              ...candidate['recordKeys'] as List<String>,
          ],
      }.toList(),
    };
    result.add(
      DownloadCenterItem(
        key: 'video:${entry.key}',
        source: row['source'] as String,
        title: row['title'] as String,
        priority: videoPriority(rows.first),
        at: row['at'] as int,
        video: merged,
        videoFields: _savedVideoFields(rows),
      ),
    );
  }
  result.sort((a, b) {
    bool failed(DownloadCenterItem item) => item.isVideo
        ? (item.video?['status'] == 'failed')
        : item.tasks.any(
            (task) =>
                !task.isCompleted &&
                const DownloadTaskRepository().readPayload(task)?.stateCode ==
                    'failed',
          );
    final failure = (failed(a) ? 0 : 1).compareTo(failed(b) ? 0 : 1);
    if (failure != 0) return failure;
    final state = a.priority.compareTo(b.priority);
    if (state != 0) return state;
    final time = b.at.compareTo(a.at);
    return time != 0 ? time : a.key.compareTo(b.key);
  });
  return result;
}

/// ObjectBox materializes fresh entities after each checkpoint. Reuse exact
/// unchanged snapshots so their cached parsed payload remains available.
List<DownloadTask> reuseDownloadTaskRows(
  List<DownloadTask> next,
  Map<int, DownloadTask> previous,
) => [
  for (final row in next)
    if (previous[row.id] case final old?
        when old.comicId == row.comicId &&
            old.comicName == row.comicName &&
            old.status == row.status &&
            old.isCompleted == row.isCompleted &&
            old.isDownloading == row.isDownloading &&
            old.dbTaskInfoStr == row.dbTaskInfoStr)
      old
    else
      row,
];

bool sameDownloadTaskStructure(
  List<DownloadTask> before,
  List<DownloadTask> after,
) {
  if (identical(before, after)) return true;
  if (before.length != after.length) return false;
  const repository = DownloadTaskRepository();
  for (var i = 0; i < before.length; i++) {
    final a = before[i], b = after[i];
    if (identical(a, b)) continue;
    if (a.id != b.id ||
        a.comicId != b.comicId ||
        a.isCompleted != b.isCompleted ||
        a.isDownloading != b.isDownloading) {
      return false;
    }
    final x = repository.readPayload(a), y = repository.readPayload(b);
    if (x?.from != y?.from ||
        x?.stateCode != y?.stateCode ||
        (x?.phaseCode == 'cancelling') != (y?.phaseCode == 'cancelling') ||
        (x?.phaseCode == 'fileRemoved') != (y?.phaseCode == 'fileRemoved'))
      return false;
  }
  return true;
}

/// Progress checkpoints rebuild their own visible row; only membership and
/// terminal/paused transitions invalidate the list projection.
String downloadTaskStructure(List<DownloadTask> tasks) => tasks
    .map((task) {
      final payload = const DownloadTaskRepository().readPayload(task);
      return '${task.id}|${payload?.from}|${task.comicId}|${payload?.stateCode}|'
          '${task.isCompleted}|${task.isDownloading}|'
          '${payload?.phaseCode == 'cancelling'}|${payload?.phaseCode == 'fileRemoved'}';
    })
    .join('\n');

Map<String, Set<String>> _savedVideoFields(List<Map<String, dynamic>> rows) {
  // Only metadata actually stored on this exact video identity participates.
  // Cache it with the projection; typing/progress does not repeatedly parse it.
  final result = <String, Set<String>>{};
  for (final row in rows) {
    final creator = row['publicCreatorName'];
    if (creator is String && creator.isNotEmpty) {
      result.putIfAbsent('author', () => <String>{}).add(creator);
    }
    final tags = row['publicTags'];
    if (tags is List) {
      final values = tags
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty && value.length <= 120)
          .take(80);
      if (values.isNotEmpty)
        result.putIfAbsent('tags', () => <String>{}).addAll(values);
    }
    final metadata = row['metadata'];
    if (metadata is! String && metadata is! List) continue;
    final fields = shelfFacetFieldsFromMetadata(
      metadata is String ? metadata : jsonEncode(metadata),
    );
    for (final key in const [
      'category',
      'tags',
      'author',
      'year',
      'area',
      'language',
    ]) {
      final values = fields[key];
      if (values != null && values.isNotEmpty) {
        result.putIfAbsent(key, () => <String>{}).addAll(values);
      }
    }
  }
  return result;
}

/// A presentation group, never a task/resource identity or storage authority.
class DownloadVideoWorkIdentity {
  const DownloadVideoWorkIdentity(this.source, this.namespace, this.canonical);
  final String source, namespace, canonical;
  String get key =>
      'video-work:${sha256.convert(utf8.encode(jsonEncode([source, namespace, canonical])))}';
  bool contains(DownloadCenterItem item) =>
      item.isVideo &&
      item.source == source &&
      item.video?['publicWorkIdentity'] == canonical &&
      (item.video?['publicModuleNamespace'] ?? '') == namespace;
  @override
  bool operator ==(Object other) =>
      other is DownloadVideoWorkIdentity &&
      source == other.source &&
      namespace == other.namespace &&
      canonical == other.canonical;
  @override
  int get hashCode => Object.hash(source, namespace, canonical);
}

DownloadVideoWorkIdentity? downloadVideoWorkIdentity(DownloadCenterItem item) {
  final canonical = item.video?['publicWorkIdentity'];
  final title = item.video?['publicWorkTitle'];
  if (!item.isVideo ||
      canonical is! String ||
      canonical.isEmpty ||
      item.source.isEmpty ||
      title is! String ||
      title.trim().isEmpty)
    return null;
  final namespace = item.video?['publicModuleNamespace'];
  return DownloadVideoWorkIdentity(
    item.source,
    namespace is String ? namespace : '',
    canonical,
  );
}

class DownloadVideoWork {
  DownloadVideoWork({
    required this.identity,
    required this.episodes,
    required this.totalEpisodes,
    this.inventory,
  });
  final DownloadVideoWorkIdentity identity;
  final List<DownloadCenterItem> episodes;
  final int totalEpisodes;

  /// The complete work before download-center filters were applied.
  final List<DownloadCenterItem>? inventory;
  String get key => identity.key;
  String get title =>
      episodes
          .map((item) => item.video?['publicWorkTitle'])
          .whereType<String>()
          .where((title) => title.trim().isNotEmpty)
          .firstOrNull ??
      episodes.first.title;
  DownloadCenterItem get poster =>
      episodes.where((item) => item.sizeBytes != null).firstOrNull ??
      episodes.first;
  bool _complete(DownloadCenterItem item) =>
      item.video?['status'] == 'saved' &&
      item.video?['local'] == true &&
      item.video?['fileRemoved'] != true &&
      item.video?['fileInvalid'] != true;
  int get completed => episodes.where(_complete).length;
  Iterable<DownloadCenterItem> get failedEpisodes => episodes.where(
    (item) =>
        const {
          'failed',
          'interrupted',
          'unavailable',
          'unsupported',
          'routeUnavailable',
          'busy',
        }.contains(item.video?['status']) ||
        item.video?['fileInvalid'] == true,
  );
  int get failed => failedEpisodes.length;
  int get waiting => episodes
      .where(
        (item) => const {
          'queued',
          'pending',
          'preparing',
        }.contains(item.video?['status']),
      )
      .length;
  int get cancelled =>
      episodes.where((item) => item.video?['status'] == 'cancelled').length;
  int get paused =>
      episodes.where((item) => item.video?['status'] == 'paused').length;
  bool get transferring => episodes.any(
    (item) => const {'downloading', 'saving'}.contains(item.video?['status']),
  );

  int? _reportedBytes(DownloadCenterItem item) =>
      item.sizeBytes ??
      (const {
            'preparing',
            'downloading',
            'saving',
          }.contains(item.video?['status'])
          ? item.receivedBytes
          : null);
  bool get active => episodes.any(
    (item) => const {
      'preparing',
      'downloading',
      'saving',
    }.contains(item.video?['status']),
  );
  int? get knownBytes {
    final bytes = episodes.map(_reportedBytes).whereType<int>().toList();
    return bytes.isEmpty
        ? null
        : bytes.fold<int>(0, (sum, value) => sum + value);
  }

  bool get completeBytes =>
      episodes.every((item) => _reportedBytes(item) != null);
  double? get progress {
    if (!transferring) return null;
    final fractions = <double>[];
    for (final item in episodes) {
      final row = item.video!;
      if (_complete(item)) {
        fractions.add(1);
        continue;
      }
      if (!const {
        'preparing',
        'downloading',
        'saving',
      }.contains(row['status'])) {
        fractions.add(0);
        continue;
      }
      final fraction = VideoDownloadByteProgress.fromRow(row).fraction;
      if (fraction != null) {
        fractions.add(fraction);
        continue;
      }
      if (active) return null;
      fractions.add(0);
    }
    return fractions.isEmpty
        ? null
        : fractions.reduce((a, b) => a + b) / fractions.length;
  }
}

class DownloadCenterDisplayItem {
  const DownloadCenterDisplayItem(this.item, [this.work]);
  final DownloadCenterItem item;
  final DownloadVideoWork? work;
  String get key => work?.key ?? item.key;
}

/// Filter leaves first; a known work remains a work when only one episode matches.
/// Unknown/Hanime single-item metadata never acquires a guessed series identity.
List<DownloadCenterDisplayItem> groupVideoDownloadItems(
  List<DownloadCenterItem> visible, {
  required List<DownloadCenterItem> universe,
}) {
  final all = <DownloadVideoWorkIdentity, List<DownloadCenterItem>>{};
  for (final item in universe) {
    final identity = downloadVideoWorkIdentity(item);
    if (identity != null) (all[identity] ??= []).add(item);
  }
  final series = {
    for (final entry in all.entries)
      if (entry.value.map((item) => item.video?['url']).toSet().length >= 2 ||
          entry.value.any((item) {
            final planned = item.video?['publicPlannedEpisodes'];
            return planned is int && planned > 1;
          }))
        entry.key: entry.value.length,
  };
  final grouped = <DownloadVideoWorkIdentity, List<DownloadCenterItem>>{};
  final identities = <String, DownloadVideoWorkIdentity>{};
  for (final item in visible) {
    final identity = downloadVideoWorkIdentity(item);
    if (identity == null || !series.containsKey(identity)) continue;
    identities[item.key] = identity;
    (grouped[identity] ??= []).add(item);
  }
  final emitted = <DownloadVideoWorkIdentity>{};
  final result = <DownloadCenterDisplayItem>[];
  for (final item in visible) {
    final identity = identities[item.key];
    if (identity == null) {
      result.add(DownloadCenterDisplayItem(item));
    } else if (emitted.add(identity)) {
      result.add(
        DownloadCenterDisplayItem(
          item,
          DownloadVideoWork(
            identity: identity,
            episodes: List.unmodifiable(grouped[identity]!),
            totalEpisodes: series[identity]!,
            inventory: List.unmodifiable(all[identity]!),
          ),
        ),
      );
    }
  }
  return result;
}
