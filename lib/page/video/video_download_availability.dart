import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/page/video/video_hls_assets.dart';

String videoDownloadFormat(Map<String, dynamic> row) {
  if (row['format'] == 'hls') return 'hls';
  final source = row['source'], quality = row['quality'];
  final watch = Uri.tryParse('${row['url']}');
  if (source is String &&
      quality is String &&
      watch != null &&
      videoPlaybackIdentity(watch) != null &&
      row['resourceId'] == VideoHlsAssets.identity(source, watch, quality))
    return 'hls';
  return 'mp4';
}

bool videoDownloadIsActive(Map<String, dynamic> row) =>
    const {'preparing', 'downloading', 'saving'}.contains(row['status']);

class VideoEpisodeDownloadAvailability {
  const VideoEpisodeDownloadAvailability({
    this.tasks = const [],
    this.files = const [],
  });
  final List<Map<String, dynamic>> tasks, files;
  bool get downloading => tasks.any(videoDownloadIsActive);
  bool get downloaded => files.isNotEmpty;
  Map<String, dynamic>? get latestTask => tasks.firstOrNull;
}

/// Source/public episode identities only. The validated local index, rather
/// than a saved acknowledgment or title, proves that an episode is downloaded.
class VideoDownloadAvailability {
  const VideoDownloadAvailability({
    this.tasks = const [],
    this.files = const [],
  });
  final List<Map<String, dynamic>> tasks, files;

  VideoEpisodeDownloadAvailability episode(
    Uri watch, {
    String? quality,
    String? format,
  }) {
    final identity = videoPlaybackIdentity(watch);
    bool matches(Map<String, dynamic> row) =>
        identity != null &&
        row['url'] == identity.toString() &&
        (quality == null || row['quality'] == quality) &&
        (format == null || videoDownloadFormat(row) == format);
    return VideoEpisodeDownloadAvailability(
      tasks: tasks.where(matches).toList(growable: false),
      files: files.where(matches).toList(growable: false),
    );
  }

  static Future<VideoDownloadAvailability> read({
    required String source,
    required Uri watch,
    String workId = '',
    String namespace = '',
  }) async {
    final page = videoPublicPage(watch);
    if (source.isEmpty || page == null)
      return const VideoDownloadAvailability();
    final snapshots = await Future.wait([
      VideoExportRecords.readTaskSnapshot(),
      VideoLocalResources.read(),
    ]);
    bool belongs(Map<String, dynamic> row) {
      final uri = Uri.tryParse('${row['url']}');
      return row['source'] == source &&
          uri != null &&
          videoPlaybackIdentity(uri) != null &&
          videoPublicPage(uri) == page &&
          (workId.isEmpty ||
              row['retryItemId'] == null ||
              row['retryItemId'] == workId);
    }

    final tasks = snapshots[0].where(belongs).toList();
    final resources = snapshots[1]
        .where(belongs)
        .where((row) => row['available'] == true && row['filePresent'] == true)
        .toList();
    if (workId.isNotEmpty && (tasks.isNotEmpty || resources.isNotEmpty)) {
      final metadata = await VideoDownloadedDetails.readForResources([
        ...tasks,
        ...resources,
      ]);
      final canonical = '$source|$namespace|$workId|$page';
      bool different(String? identity) =>
          identity != null && identity != canonical ||
          namespace.isNotEmpty && identity == null;
      for (var index = resources.length - 1; index >= 0; index--) {
        final identity = metadata[tasks.length + index]?.canonicalWorkId;
        // A known different module/work must not borrow this file. For a
        // namespaced work an unknown legacy identity cannot prove membership.
        if (different(identity)) resources.removeAt(index);
      }
      for (var index = tasks.length - 1; index >= 0; index--) {
        if (different(metadata[index]?.canonicalWorkId)) tasks.removeAt(index);
      }
    }
    return VideoDownloadAvailability(tasks: tasks, files: resources);
  }
}
