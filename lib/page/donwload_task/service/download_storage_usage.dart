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
  }) async {
    final videoRead = videos == null
        ? VideoLocalResources.readStorageInventory()
              .then<({List<Map<String, dynamic>> rows, bool complete})?>(
                (inventory) => inventory,
              )
              .catchError((Object _) => null)
        : Future.value((rows: videos, complete: true));
    try {
      comics ??= await DownloadCenterResources.readComicsAsync();
    } catch (_) {
      // Read each media type independently so one error leaves the other usable.
    }
    final comicSizes = await measureSavedComicSizes(
      comics ?? const [],
      current: current,
    );
    final videoInventory = await videoRead;
    final videoRows = videoInventory?.rows ?? const [];
    return DownloadStorageUsage(
      knownBytes:
          comicSizes.values.fold(0, (sum, size) => sum + size.knownBytes) +
          savedVideoSizes(videoRows).values.fold(0, (sum, size) => sum + size),
      partial:
          partial ||
          comics == null ||
          videoInventory?.complete != true ||
          comicSizes.values.any((size) => !size.complete) ||
          hasUnmeasuredSavedVideo(videoRows),
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
