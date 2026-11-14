import 'dart:async';

import 'package:zephyr/network/source_network_policy.dart';
import 'package:zephyr/page/video/ios_managed_video_transfer.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_hls_recovery.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/service/download/download_admission.dart';
import 'package:zephyr/service/download/download_resource_lifecycle.dart';
import 'package:zephyr/service/download/ios_background_transfer.dart';

abstract final class IosManagedVideoRecovery {
  static final live = <String>{};
  static final _cancelling = <String>{};
  static bool _started = false, _again = false;
  static Future<void>? _reading;
  static void Function()? _changed;

  static void start(void Function() onCapacityChanged) {
    if (!IosBackgroundTransfer.supported || _started) return;
    _started = true;
    _changed = onCapacityChanged;
    void recheck() => unawaited(refresh());
    IosBackgroundTransfer.changes.listen((_) => recheck());
    SourceNetworkPolicies.changes.listen((_) => recheck());
    PluginRegistryService.I.stream.listen((_) => recheck());
    pluginSessionWriteFence.changes.listen((_) => recheck());
    final admission = DownloadAdmission.instance;
    var wifi = admission.wifiOnly;
    admission.addListener(() {
      if (admission.wifiOnly == wifi) return;
      wifi = admission.wifiOnly;
      recheck();
    });
    unawaited(admission.start().then((_) => refresh()));
  }

  static Future<void> refresh() {
    if (!_started) return Future.value();
    if (_reading case final pending?) {
      _again = true;
      return pending;
    }
    return _reading = _drain().whenComplete(() => _reading = null);
  }

  static Future<void> _drain() async {
    do {
      _again = false;
      try {
        await _read();
      } catch (_) {
        // The native receipt remains available for the next scan.
      }
    } while (_again);
  }

  static bool _policyCurrent(Map receipt) =>
      VideoHlsRecovery.currentAccountScope(receipt['source'] as String) ==
          receipt['scope'] &&
      receipt['wifiOnly'] == DownloadAdmission.instance.wifiOnly;

  static Future<void> _read() async {
    final receipts = await IosBackgroundTransfer.snapshot();
    final rows = await VideoExportRecords.readMp4RecoveryTasks();
    final owned = <String, int>{};
    for (final receipt in receipts) {
      final id = receipt['batchId'], key = receipt['taskKey'];
      if (receipt['kind'] != 'mp4' ||
          id is! String ||
          key is! String ||
          receipt['source'] is! String ||
          receipt['attempt'] is! int ||
          receipt['resourceId'] is! String ||
          live.contains(id) ||
          VideoExportRecords.hasProcessTransfer(key)) {
        continue;
      }
      final task = rows[key], status = receipt['status'];
      final matches =
          task != null && VideoExportRecords.matchesMp4Receipt(task, receipt);
      final pending =
          matches &&
          const {
            'preparing',
            'downloading',
            'saving',
            'interrupted',
          }.contains(task['status']);
      if (matches && task['status'] == 'saved') {
        await IosBackgroundTransfer.ack(receipt);
        continue;
      }
      final allowed =
          pending &&
          _policyCurrent(receipt) &&
          await VideoHlsRecovery.directRoute(receipt['source'] as String) &&
          _policyCurrent(receipt) &&
          !_cancelling.contains(id);
      if (status == 'running') {
        if (allowed) {
          owned[key] = receipt['attempt'] as int;
        } else if (await IosBackgroundTransfer.cancel(receipt)) {
          if (pending)
            await VideoExportRecords.settleRecoveredMp4(
              receipt,
              status: 'cancelled',
            );
          await IosBackgroundTransfer.ack(receipt);
        }
        continue;
      }
      if (status == 'staged' && allowed) {
        await _publish(receipt, task);
      } else if (pending) {
        final terminal = status == 'failed' ? 'failed' : 'cancelled';
        await VideoExportRecords.settleRecoveredMp4(receipt, status: terminal);
      }
      await IosBackgroundTransfer.ack(receipt);
    }
    final before = VideoExportRecords.recoveredTransferCount;
    VideoExportRecords.setRecoveredMp4Tasks(owned);
    if (before != VideoExportRecords.recoveredTransferCount) _changed?.call();
  }

  static Future<void> _publish(
    Map<String, dynamic> receipt,
    Map<String, dynamic> task,
  ) async {
    final resource = receipt['resourceId'] as String;
    if (!VideoLocalResources.tryHold(resource)) {
      throw StateError('Video resource has another owner');
    }
    String? stageId;
    try {
      final current =
          (await VideoExportRecords.readMp4RecoveryTasks())[task['key']];
      if (current == null ||
          !VideoExportRecords.matchesMp4Receipt(current, receipt))
        return;
      final existing = (await VideoLocalResources.read())
          .where((row) => row['resourceId'] == resource)
          .firstOrNull;
      final items = receipt['items'];
      final item = items is List && items.length == 1 ? items.single : null;
      final bytes = item is Map ? item['bytes'] : null;
      if (bytes is! int || bytes <= 0)
        throw const FormatException('Invalid MP4 receipt');
      final expected = receipt['expectedVersion'];
      final actual = existing == null
          ? ''
          : VideoLocalResources.resourceVersion(existing);
      if (actual != expected &&
          existing?['taskKey'] == task['key'] &&
          existing?['bytes'] == bytes &&
          existing?['available'] == true) {
        await VideoExportRecords.settleRecoveredMp4(
          receipt,
          status: 'saved',
          bytes: bytes,
        );
        return;
      }
      if (expected is! String || expected != actual) {
        // A replacement may only supersede the generation it originally saw.
        await VideoExportRecords.settleRecoveredMp4(
          receipt,
          status: 'cancelled',
        );
        return;
      }
      bool cancelled() =>
          _cancelling.contains(receipt['batchId']) ||
          !_policyCurrent(receipt) ||
          DownloadResourceLifecycle.removing(
                DownloadResourceLifecycle.video(resource),
              ) !=
              null;
      if (cancelled()) {
        await VideoExportRecords.settleRecoveredMp4(
          receipt,
          status: 'cancelled',
        );
        return;
      }
      final stage = await IosManagedVideoTransfer.makeManagedStage(
        receipt,
        bytes,
      );
      stageId = stage['stageId'] as String?;
      if (stageId == null)
        throw const FormatException('MP4 receipt has no staged file');
      final saved = await VideoLocalResources.commitStaged(
        stageId: stageId,
        resourceId: resource,
        bytes: bytes,
        source: task['source'] as String,
        video: Uri.parse(task['url'] as String),
        title: task['title'] as String,
        quality: task['quality'] as String,
        taskKey: task['key'] as String,
        cover: task['cover'] as String?,
        durationMs: task['durationMs'] as int?,
        sourceDuration: task['sourceDuration'] as String?,
        expectedVersion: expected,
        cancelled: cancelled,
      );
      await VideoExportRecords.settleRecoveredMp4(
        receipt,
        status: saved ? 'saved' : 'cancelled',
        bytes: saved ? bytes : null,
      );
    } finally {
      try {
        if (stageId != null) await VideoLocalResources.discardStage(stageId);
      } finally {
        VideoLocalResources.release(resource);
      }
    }
  }

  static Future<void> cancelTask(String key, int? attempt) => _cancelWhere(
    (row) =>
        row['taskKey'] == key && (attempt == null || row['attempt'] == attempt),
  );

  static Future<void> stopSource(String source) =>
      _cancelWhere((row) => row['source'] == source);

  static Future<void> _cancelWhere(bool Function(Map row) matches) async {
    if (!_started) return;
    for (final row in await IosBackgroundTransfer.snapshot()) {
      if (row['kind'] == 'mp4' &&
          !live.contains(row['batchId']) &&
          matches(row)) {
        final id = row['batchId'] as String;
        _cancelling.add(id);
        try {
          if (!await IosBackgroundTransfer.cancel(row)) {
            throw StateError('The background video transfer is still active');
          }
        } finally {
          _cancelling.remove(id);
        }
      }
    }
    await refresh();
  }
}
