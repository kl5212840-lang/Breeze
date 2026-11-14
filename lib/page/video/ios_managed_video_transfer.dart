import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:zephyr/page/video/video_hls_recovery.dart';
import 'package:zephyr/service/download/download_admission.dart';
import 'package:zephyr/service/download/ios_background_transfer.dart';

/// An already resolved, credential-free direct MP4 transfer.
final class IosManagedVideoTransfer {
  IosManagedVideoTransfer({
    required String source,
    required String scope,
    required String taskKey,
    required int attempt,
    required String resourceId,
    required Uri media,
    required Map<String, String> headers,
    required bool wifiOnly,
    String expectedVersion = '',
  }) : _media = media,
       _headers = headers,
       binding = {
         'batchId': const Uuid().v4(),
         'kind': 'mp4',
         'source': source,
         'scope': scope,
         'taskKey': taskKey,
         'attempt': attempt,
         'resourceId': resourceId,
         'manifestId': sha256.convert(utf8.encode(media.toString())).toString(),
         'wifiOnly': wifiOnly,
         'expectedVersion': expectedVersion,
       };

  final Uri _media;
  final Map<String, String> _headers;
  final Map<String, dynamic> binding;
  bool get scopeIsCurrent =>
      VideoHlsRecovery.currentAccountScope(binding['source'] as String) ==
          binding['scope'] &&
      DownloadAdmission.instance.wifiOnly == binding['wifiOnly'];
  bool _cancelled = false;
  bool submitted = false;
  Future<bool>? _submission;

  Future<Map<String, dynamic>?> download({
    required Future<void> Function(int bytes, bool saving) onProgress,
    void Function(int total)? onExpectedBytes,
  }) async {
    final signals = StreamIterator<void>(IosBackgroundTransfer.changes);
    var next = signals.moveNext();
    try {
      final submitted = _submission = IosBackgroundTransfer.submit(binding, [
        {
          'index': 0,
          'url': _media.toString(),
          'headers': _headers,
          'maxBytes': 16 * 1024 * 1024 * 1024,
          'redirectPolicy': 'same-url',
        },
      ], concurrency: 1);
      if (!await submitted) return null;
      this.submitted = true;
      int? lastBytes;
      while (true) {
        final snapshot = await IosBackgroundTransfer.snapshot();
        final row = snapshot
            .where((item) => item['batchId'] == binding['batchId'])
            .firstOrNull;
        if (row == null) return {'status': 'failed'};
        final items = row['items'];
        final item = items is List && items.length == 1 ? items.single : null;
        final bytes = item is Map ? item['bytes'] as int? : null;
        final total = item is Map ? item['total'] : null;
        if (total is int && total > 0 && (bytes == null || total >= bytes)) {
          onExpectedBytes?.call(total);
        }
        final status = row['status'];
        if (status == 'cancelled' || _cancelled && status != 'running') {
          return {'status': 'cancelled'};
        }
        if (status == 'failed') {
          return {
            'status': 'failed',
            if (item is Map) 'reason': item['reason'],
          };
        }
        if (status == 'staged' && bytes != null && bytes > 0) {
          await onProgress(bytes, true);
          return await makeManagedStage(binding, bytes);
        }
        if (bytes != null && bytes != lastBytes) {
          lastBytes = bytes;
          await onProgress(bytes, false);
        }
        if (!await next) return {'status': 'failed'};
        next = signals.moveNext();
      }
    } finally {
      await signals.cancel();
    }
  }

  static Object? ifMapReason(Object? item) =>
      item is Map ? item['reason'] : null;

  static Future<Map<String, dynamic>> makeManagedStage(
    Map<String, dynamic> binding,
    int bytes,
  ) async {
    final stageId = await IosBackgroundTransfer.linkVideoStage(binding);
    if (stageId == null || !RegExp(r'^[a-f0-9]{32}$').hasMatch(stageId)) {
      return {'status': 'failed'};
    }
    return {
      'status': 'staged',
      'resourceId': binding['resourceId'],
      'stageId': stageId,
      'bytes': bytes,
    };
  }

  Future<void> cancel() async {
    _cancelled = true;
    if (await _submission == true) await IosBackgroundTransfer.cancel(binding);
  }

  Future<void> acknowledge() async {
    if (await _submission == true) await IosBackgroundTransfer.ack(binding);
  }
}
