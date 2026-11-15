import 'package:zephyr/page/donwload_task/service/download_center_projection.dart';
import 'package:zephyr/page/donwload_task/service/download_center_resources.dart';
import 'package:zephyr/page/donwload_task/service/download_resource_metrics.dart';
import 'package:zephyr/page/video/video_local_resources.dart';

typedef SavedComicSize = ({String version, int knownBytes, bool complete});

class DownloadStorageUsage {
  const DownloadStorageUsage({required this.knownBytes, required this.partial});

  final int knownBytes;
  final bool partial;

  static Future<DownloadStorageUsage> read({
    List<DownloadComicResource>? comics,
    List<Map<String, dynamic>>? videos,
    bool partial = false,
    required bool Function() current,
    void Function(DownloadStorageUsage)? onPartial,
  }) async {
    var comicBytes = 0, videoBytes = 0;
    var videoComplete = false;
    void publish() {
      final knownBytes = comicBytes + videoBytes;
      if (knownBytes > 0 && current()) {
        onPartial?.call(
          DownloadStorageUsage(knownBytes: knownBytes, partial: true),
        );
      }
    }

    final videoRead =
        () async {
          final inventory = videos == null
              ? await VideoLocalResources.readStorageInventory()
              : (rows: videos, complete: true);
          final rows = inventory.rows;
          videoBytes = savedVideoSizes(
            rows,
          ).values.fold(0, (sum, size) => sum + size);
          videoComplete = inventory.complete && !hasUnmeasuredSavedVideo(rows);
          publish();
        }().catchError((Object _) {
          // Comic measurements are still useful when the video index is unavailable.
        });
    try {
      comics ??= await DownloadCenterResources.readComicsAsync();
    } catch (_) {
      // Video measurements are still useful when the comic index is unavailable.
    }
    final comicSizes = await measureSavedComicSizes(
      comics ?? const [],
      current: current,
      onBatch: onPartial == null
          ? null
          : (batch) {
              comicBytes += batch.fold(0, (sum, size) => sum + size.knownBytes);
              publish();
            },
    );
    await videoRead;
    return DownloadStorageUsage(
      knownBytes:
          comicSizes.values.fold(0, (sum, size) => sum + size.knownBytes) +
          videoBytes,
      partial:
          partial ||
          comics == null ||
          comicSizes.length != comics.length ||
          !videoComplete ||
          comicSizes.values.any((size) => !size.complete),
    );
  }
}

bool hasUnmeasuredSavedVideo(Iterable<Map<String, dynamic>> rows) => rows.any(
  (row) =>
      row['external'] != true &&
      row['filePresent'] == true &&
      (row['available'] != true ||
          row['resourceId'] is! String ||
          row['bytes'] is! int ||
          (row['bytes'] as int) <= 0),
);

/// Saved entries share the normal versioned file measurements. Feed them in
/// small batches so opening the summary does not enqueue an entire library.
Future<Map<String, SavedComicSize>> measureSavedComicSizes(
  List<DownloadComicResource> comics, {
  required bool Function() current,
  void Function(List<DownloadResourceSize>)? onBatch,
}) async {
  final sizes = <String, SavedComicSize>{};
  for (var index = 0; index < comics.length && current(); index += 2) {
    final results = await Future.wait([
      DownloadResourceMetrics.instance.readComic(comics[index]),
      if (index + 1 < comics.length)
        DownloadResourceMetrics.instance.readComic(comics[index + 1]),
    ]);
    for (final size in results) {
      sizes[size.resourceKey] = (
        version: size.version,
        knownBytes: size.knownBytes,
        complete: size.sizeBytes != null,
      );
    }
    onBatch?.call(results);
  }
  return sizes;
}

Map<String, int> savedVideoSizes(Iterable<Map<String, dynamic>> rows) {
  final sizes = <String, int>{};
  for (final row in rows) {
    final id = row['resourceId'];
    final bytes = row['bytes'];
    if (id is String &&
        bytes is int &&
        bytes > 0 &&
        row['available'] == true &&
        row['filePresent'] == true &&
        row['external'] != true) {
      sizes.putIfAbsent('video:$id', () => bytes);
    }
  }
  return sizes;
}

/// The existing order breaks ties. A group's size covers the same visible
/// episodes as its management actions, including when filters narrow it.
List<DownloadCenterDisplayItem> orderDownloadsBySize(
  List<DownloadCenterDisplayItem> rows, {
  required Map<String, SavedComicSize> comicSizes,
  required Map<String, int> videoSizes,
}) {
  int? itemBytes(DownloadCenterItem item) {
    if (item.isVideo) return videoSizes[item.key] ?? item.sizeBytes;
    final resource = item.resource;
    final size = comicSizes[resource?.key];
    return size != null &&
            size.version == resource?.metricsVersion &&
            size.knownBytes > 0
        ? size.knownBytes
        : null;
  }

  int? rowBytes(DownloadCenterDisplayItem row) {
    final work = row.work;
    if (work == null) return itemBytes(row.item);
    final bytes = work.episodes
        .map(itemBytes)
        .whereType<int>()
        .fold(0, (sum, bytes) => sum + bytes);
    return bytes > 0 ? bytes : null;
  }

  final ranked =
      [for (final (index, row) in rows.indexed) (index, row, rowBytes(row))]
        ..sort((a, b) {
          final order = (b.$3 ?? -1).compareTo(a.$3 ?? -1);
          return order == 0 ? a.$1.compareTo(b.$1) : order;
        });
  return ranked.map((entry) => entry.$2).toList();
}
