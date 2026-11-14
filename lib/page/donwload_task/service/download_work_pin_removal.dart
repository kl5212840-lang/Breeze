import 'package:zephyr/page/donwload_task/service/download_center_projection.dart';
import 'package:zephyr/page/donwload_task/service/download_center_resources.dart';
import 'package:zephyr/page/donwload_task/service/download_work_pins.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/service/download/download_task_repository.dart';

/// Called after committing a video removal and leaving the storage queue.
Future<void> afterVideoRemoval([String? resourceId]) async {
  try {
    final pins = await DownloadWorkPins.read();
    final alias = resourceId == null ? null : 'video:$resourceId';
    final rank = alias == null ? null : pins[alias];
    if (pins.isEmpty || (alias != null && rank == null)) return;
    final pinRevision = DownloadWorkPins.changes.value;
    final files = VideoLocalResources.changes.value;
    final records = VideoExportRecords.changes.value;
    final videos = await DownloadCenterResources.readVideos(
      waitForStorage: true,
      fresh: true,
      afterCurrentRead: true,
    );
    await DownloadWorkPins.reconcile(
      () {
        if (files != VideoLocalResources.changes.value ||
            records != VideoExportRecords.changes.value ||
            (alias == null && pinRevision != DownloadWorkPins.changes.value)) {
          return null;
        }
        return projectDownloadCenter(
          tasks: const DownloadTaskRepository().getAll(),
          comics: DownloadCenterResources.readComics(),
          videos: videos,
        );
      },
      removedPin: alias != null && rank != null
          ? (alias: alias, rank: rank)
          : null,
    );
  } catch (_) {
    // The deletion has committed. Leave the pin for the next complete read.
  }
}
