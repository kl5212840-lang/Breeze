import 'package:zephyr/page/video/downloaded_video_metadata.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';

/// A past successful line is evidence, not a speed estimate or a selection.
String? lastSuccessfulVideoDownloadLine({
  required String source,
  required String canonicalWorkId,
  required Uri workPage,
  required Set<String> lineIds,
  required List<Map<String, dynamic>> tasks,
  required List<Map<String, dynamic>> resources,
  required List<DownloadedVideoMetadata?> metadata,
}) {
  final local = {for (final row in resources) row['resourceId']: row};
  final details = {
    for (final value in metadata)
      if (value != null) value.resourceId: value,
  };
  String? latest;
  var latestAt = -1;
  for (final row in tasks) {
    final id = row['resourceId'], file = local[id], detail = details[id];
    final url = row['url'] is String
        ? Uri.tryParse(row['url'] as String)
        : null;
    final watch = url == null ? null : videoPlaybackIdentity(url);
    final line = watch?.queryParameters['line'], at = file?['at'];
    if (row['status'] != 'saved' ||
        row['source'] != source ||
        file == null ||
        file['source'] != source ||
        file['available'] != true ||
        file['filePresent'] != true ||
        row['quality'] is! String ||
        (row['quality'] as String).trim().isEmpty ||
        file['quality'] != row['quality'] ||
        file['url'] != row['url'] ||
        detail == null ||
        detail.source != source ||
        detail.canonicalWorkId != canonicalWorkId ||
        detail.watchUrl != watch ||
        detail.resourceId != id ||
        detail.quality != row['quality'] ||
        videoPublicPage(watch ?? Uri()) != workPage ||
        !lineIds.contains(line) ||
        at is! int ||
        at < 0 ||
        at <= latestAt)
      continue;
    latest = line;
    latestAt = at;
  }
  return latest;
}

/// Optional UI enrichment: no network, mutations, poster work or browser.
/// The picker opens immediately; an unavailable snapshot simply has no badge.
Future<String?> readLastSuccessfulVideoDownloadLine({
  required String source,
  required String workId,
  required String namespace,
  required Uri currentWatch,
  required Set<String> lineIds,
}) async {
  final workPage = videoPublicPage(currentWatch);
  if (source.isEmpty || workId.isEmpty || workPage == null || lineIds.isEmpty)
    return null;
  Future<String?> read() async {
    final snapshot = await Future.wait([
      VideoExportRecords.readTaskSnapshot(),
      VideoLocalResources.read(),
    ]);
    final tasks = snapshot[0], allResources = snapshot[1];
    final matching =
        allResources.where((row) {
          final watch = Uri.tryParse('${row['url']}');
          return row['source'] == source &&
              row['available'] == true &&
              row['filePresent'] == true &&
              watch != null &&
              videoPublicPage(watch) == workPage &&
              lineIds.contains(watch.queryParameters['line']);
        }).toList()..sort(
          (a, b) => ((b['at'] as int?) ?? 0).compareTo((a['at'] as int?) ?? 0),
        );
    final resources = matching.take(64).toList();
    if (resources.isEmpty) return null;
    final metadata = await VideoDownloadedDetails.readForResources(resources);
    return lastSuccessfulVideoDownloadLine(
      source: source,
      canonicalWorkId: '$source|$namespace|$workId|$workPage',
      workPage: workPage,
      lineIds: lineIds,
      tasks: tasks,
      resources: resources,
      metadata: metadata,
    );
  }

  try {
    return await read().timeout(const Duration(seconds: 3));
  } catch (_) {
    return null;
  }
}
