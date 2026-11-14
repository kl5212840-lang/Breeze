import 'package:zephyr/page/donwload_task/service/download_work_pin_removal.dart';
import 'package:zephyr/page/donwload_task/service/download_interaction_trace.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/service/download/download_resource_lifecycle.dart';

/// Remove exactly one public page + quality identity. No external Photos/Files
/// location is ever treated as an application-owned resource.
Future<void> removeVideoDownload({
  required String source,
  required Uri page,
  required String quality,
  String format = 'mp4',
  VideoDownloadRemovalToken? expected,
}) => const VideoDownloadRemoval().remove(
  source: source,
  page: page,
  quality: quality,
  format: format,
  expected: expected,
);

class VideoDownloadRemovalToken {
  VideoDownloadRemovalToken._(this._identity, this._resource, this._records);
  final String _identity;
  final ManagedVideoRemovalVersion? _resource;
  final VideoDownloadRemovalRecords _records;
}

bool isVideoExternalReceipt(Map<String, dynamic> row) =>
    row['external'] == true || row['externalKey'] is String;

bool isVideoDownloadRecordOnly(Map<String, dynamic> row) =>
    isVideoExternalReceipt(row) ||
    row['kind'] == 'transfer' && row['status'] != 'saved';

/// Capture before the confirmation; this performs reads only and holds no
/// removal/native lease across user interaction.
Future<VideoDownloadRemovalToken> bindVideoDownloadRemoval({
  required String source,
  required Uri page,
  required String quality,
  String format = 'mp4',
  Map<String, dynamic>? displayedTask,
}) async {
  final id = VideoLocalResources.identity(
    source,
    page,
    format == 'hls' ? 'hls|$quality' : quality,
  );
  if (displayedTask != null &&
      isVideoExternalReceipt(displayedTask) &&
      displayedTask['externalKey'] is! String) {
    throw StateError('Video export record identity is missing');
  }
  final onlyRecord =
      displayedTask != null && isVideoDownloadRecordOnly(displayedTask);
  final trace = DownloadInteractionTrace('bind-video');
  final resource = onlyRecord
      ? null
      : await VideoLocalResources.bindRemovalVersion(
          id,
          expectedResourceVersion: displayedTask?['resourceVersion'] as String?,
        );
  trace.mark('resource-version-read');
  if (resource?.hasResource == true &&
      displayedTask?['local'] == true &&
      displayedTask?['resourceVersion'] == null) {
    throw StateError('Video resource changed before confirmation');
  }
  final records = await VideoExportRecords.bindDownloadRemoval(
    id,
    displayedTask: displayedTask,
    onlyDisplayedRecord: onlyRecord,
  );
  trace.mark('records-bound');
  return VideoDownloadRemovalToken._(id, resource, records);
}

Future<void> _removeOwnedVideoResource(ManagedVideoRemovalLease lease) =>
    lease.remove(allowUnindexedOwnedFile: true);

class VideoDownloadRemoval {
  const VideoDownloadRemoval({this.removeResource = _removeOwnedVideoResource});
  final Future<void> Function(ManagedVideoRemovalLease lease) removeResource;

  Future<void> remove({
    required String source,
    required Uri page,
    required String quality,
    String format = 'mp4',
    VideoDownloadRemovalToken? expected,
  }) async {
    final identity = VideoLocalResources.identity(
      source,
      page,
      format == 'hls' ? 'hls|$quality' : quality,
    );
    if (expected != null && expected._identity != identity) {
      throw ArgumentError(
        'Video removal token belongs to a different resource',
      );
    }
    if (expected != null && expected._resource == null) {
      await VideoExportRecords.removeBoundDownloadRecords(expected._records);
      await afterVideoRemoval(identity);
      return;
    }
    final lifecycle = DownloadResourceLifecycle.acquireRemoval(
      DownloadResourceLifecycle.video(identity),
    );
    try {
      await VideoLocalResources.withRemovalLease(identity, (lease) async {
        final bound = await VideoExportRecords.bindDownloadRemoval(identity);
        if (expected != null) {
          lease.requireExpectedVersion(expected._resource!);
          VideoExportRecords.requireExpectedDownloadRemoval(
            bound,
            expected._records,
          );
        }
        // The held native resource and the raw log snapshot belong to the same
        // execution. No read/clear API here may reacquire the storage queue.
        if (lease.hasResource ||
            (expected?._resource?.hasResource != true &&
                bound.hasManagedTransfer)) {
          await removeResource(lease);
        }
        await VideoExportRecords.removeBoundDownloadRecords(bound);
      });
      await afterVideoRemoval(identity);
    } finally {
      lifecycle.release();
    }
  }
}
