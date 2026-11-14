import 'dart:async';
import 'dart:convert';
import 'package:zephyr/service/download/resource_download_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/page/video/video_download_failure.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/service/download/download_resource_lifecycle.dart';
import 'package:zephyr/service/download/download_admission.dart';

class VideoDownloadRemovalRecords {
  VideoDownloadRemovalRecords._(
    this._persistedTasks,
    this._sessions,
    this._exports,
    this.hasManagedTransfer,
  );
  final Map<String, String> _persistedTasks, _sessions, _exports;
  Set<String> get _taskKeys => {..._persistedTasks.keys, ..._sessions.keys};
  final bool hasManagedTransfer;
}

/// Local Files export acknowledgments and a bounded native-transfer log.
/// Never signed media URLs, credentials or a claim an external file still exists.
abstract final class VideoExportRecords {
  static const storageKey = 'breeze.video.exports.v1';
  // Explicitly outside PortablePreferences' export/settings domains.
  static const taskStorageKey = 'breeze.local.video.download-tasks.v1';
  static final changes = ValueNotifier<int>(0);
  static final exportsChanged = ValueNotifier<int>(0);
  static final completionInputsChanged = ValueNotifier<int>(0);

  static Map<Object?, Object?> _completionInputs(
    List<Map<String, dynamic>> rows,
  ) => {
    for (final row in rows)
      if (row['kind'] == 'transfer')
        row['key']: (
          row['source'],
          row['url'],
          row['attempt'],
          row['title'],
          row['status'] == 'saved' && row['resourceId'] != null
              ? 'saved'
              : row['status'] == 'cancelled'
              ? 'cancelled'
              : 'pending',
        ),
  };
  // Recovered jobs have no row in the process-only progress snapshot.
  static final recoveredHlsChanges = ValueNotifier<int>(0);
  static Future<void>? _writes;
  static final _liveTasks = <String>{};
  static final _sessionTasks = <String, Map<String, dynamic>>{};
  static final _recoveredTasks = <String, int>{};
  static final _recoveredMp4Tasks = <String, int>{};
  static final _networkWaitOwners = <String, int>{};
  static int _sequence = 0;

  static void retainNetworkWait(String key, int attempt) {
    _networkWaitOwners[key] = attempt;
  }

  static void releaseNetworkWait(String key, int attempt) {
    if (_networkWaitOwners[key] != attempt) return;
    _networkWaitOwners.remove(key);
    changes.value++;
  }

  static Future<void> flush() async {
    await _writes?.catchError((Object _) {});
  }

  /// Only records written successfully to local task storage count here.
  static Future<List<Map<String, dynamic>>> readCommittedTransferRows() async {
    await flush();
    return _read(await SharedPreferences.getInstance(), key: taskStorageKey)
        .where(
          (row) =>
              row['kind'] == 'transfer' &&
              _sessionTasks[row['key']]?['recordingFailed'] != true,
        )
        .toList();
  }

  static Future<List<Map<String, dynamic>>> read() async {
    await _writes?.catchError((_) {});
    return _read(
      await SharedPreferences.getInstance(),
    ).where((row) => row['kind'] != 'transfer').toList();
  }

  static List<Map<String, dynamic>> _read(
    SharedPreferences prefs, {
    String key = storageKey,
  }) {
    try {
      final value = jsonDecode(prefs.getString(key) ?? '[]');
      if (value is! List) return [];
      return value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .where(
            (row) =>
                row['source'] is String &&
                row['title'] is String &&
                row['at'] is int &&
                row['key'] is String &&
                videoPublicPage(Uri.tryParse('${row['url']}') ?? Uri()) != null,
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Only local workers or exact native recovery bindings count as active.
  /// Durable transfer membership/progress only. Never waits for media files,
  /// native asset enumeration, poster work or the shared storage queue.
  static Future<List<Map<String, dynamic>>> readTaskSnapshot() async {
    await _writes?.catchError((Object _) {});
    final rows =
        <String, Map<String, dynamic>>{
            for (final row in _read(
              await SharedPreferences.getInstance(),
              key: taskStorageKey,
            ))
              if (row['kind'] == 'transfer') row['key'] as String: row,
            ..._sessionTasks,
          }.values.map((row) {
            final waitingWithoutOwner =
                row['status'] == 'failed' &&
                DownloadNetworkWait.fromCode(row['failureReason']) != null &&
                _networkWaitOwners[row['key']] != row['attempt'];
            final active = const {
              'preparing',
              'downloading',
              'saving',
            }.contains(row['status']);
            final attempt = row['attempt'];
            final hasNativeOwner =
                attempt is int &&
                (_recoveredTasks[row['key']] == attempt ||
                    _recoveredMp4Tasks[row['key']] == attempt);
            return waitingWithoutOwner ||
                    active &&
                        !_liveTasks.contains(row['key']) &&
                        !hasNativeOwner
                ? <String, dynamic>{...row, 'status': 'interrupted'}
                : row;
          }).toList()
          ..sort((a, b) => (b['at'] as int).compareTo(a['at'] as int));
    return [for (final row in rows) Map<String, dynamic>.from(row)];
  }

  /// Enriched resource projection for completed/downloaded files. Callers
  /// showing active tasks should publish [readTaskSnapshot] first.
  static Future<List<Map<String, dynamic>>> readTasks({
    List<Map<String, dynamic>>? resources,
  }) async {
    final rows = await readTaskSnapshot();
    resources ??= await VideoLocalResources.read();
    final byId = {for (final row in resources) row['resourceId']: row};
    final result = <Map<String, dynamic>>[];
    final physical = <String, bool>{};
    for (final row in rows) {
      final id = row['resourceId'];
      final local = byId[id];
      if (id is String && VideoLocalResources.validId(id) && local == null) {
        physical[id] ??= await (await VideoLocalResources.file(id)).exists();
      }
      result.add({
        ...row,
        if (_publicCover(row['cover']) == null &&
            _publicCover(local?['cover']) != null)
          'cover': _publicCover(local?['cover']),
        if (id != null)
          'fileRemoved': local == null
              ? physical[id] != true
              : local['filePresent'] != true,
        if (id != null)
          'fileInvalid': local == null
              ? physical[id] == true
              : local['filePresent'] == true && local['available'] != true,
        if (id != null) 'local': true,
      });
    }
    final keys = result.map((row) => row['key']).toSet();
    for (final resource in resources) {
      if (resource['showTask'] == true && !keys.contains(resource['taskKey'])) {
        result.add({
          ...resource,
          'key': resource['taskKey'],
          'status': 'saved',
          'local': true,
          'fileRemoved': resource['filePresent'] != true,
          'fileInvalid':
              resource['filePresent'] == true && resource['available'] != true,
          'received': resource['bytes'],
          'total': resource['bytes'],
        });
      }
    }
    for (final external in await read()) {
      if (resources.any(
        (row) =>
            row['available'] == true &&
            row['source'] == external['source'] &&
            row['url'] == external['url'] &&
            row['quality'] == external['quality'],
      )) {
        continue;
      }
      result.add({
        ...external,
        'key': 'external|${external['key']}',
        'externalKey': external['key'],
        'status': 'saved',
        'external': true,
      });
    }
    result.sort((a, b) => (b['at'] as int).compareTo(a['at'] as int));
    return result;
  }

  static bool isLive(String key) =>
      _recoveredTasks.containsKey(key) ||
      _recoveredMp4Tasks.containsKey(key) ||
      _liveTasks.contains(key) &&
          const {
            'preparing',
            'downloading',
            'saving',
          }.contains(_sessionTasks[key]?['status']);

  /// Process-only progress for already-known task rows. Consumers still read
  /// persisted resources on membership/terminal changes, never infer files from
  /// this snapshot or persist temporary media/credentials through it.
  static List<Map<String, dynamic>> sessionTaskSnapshot() => [
    for (final row in _sessionTasks.values) Map<String, dynamic>.from(row),
  ];

  static Future<String> beginTransfer({
    required String source,
    required Uri video,
    required String title,
    required String quality,
    String? resourceId,
    String? cover,
    int? durationMs,
    String? sourceDuration,
    String format = 'mp4',
    bool queued = false,
    bool reuseTerminal = false,
    String? retryItemId,
  }) async {
    final page = VideoLocalResources.resourcePage(video);
    if (source.isEmpty || source.length > 200 || page == null) {
      throw ArgumentError('Invalid public transfer identity');
    }
    DownloadResourceLifecycle.requireAvailable(
      DownloadResourceLifecycle.video(
        VideoLocalResources.identity(
          source,
          page,
          format == 'hls' ? 'hls|$quality' : quality,
        ),
      ),
    );
    if (reuseTerminal) {
      final previous = (await readTaskSnapshot())
          .where(
            (row) =>
                !isLive('${row['key']}') &&
                const {
                  'failed',
                  'cancelled',
                  'interrupted',
                  'unavailable',
                  'routeUnavailable',
                  'unsupported',
                  'busy',
                }.contains(row['status']) &&
                row['source'] == source &&
                row['url'] == page.toString() &&
                row['quality'] == quality &&
                (row['format'] ?? 'mp4') == format &&
                (quality.isNotEmpty ||
                    retryItemId != null && row['retryItemId'] == retryItemId),
          )
          .firstOrNull;
      if (previous != null) {
        final restarted = await restartTransfer(previous);
        if (restarted != null) return restarted['key'] as String;
      }
    }
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final key = 'transfer|$now|${++_sequence}';
    final row = <String, dynamic>{
      'kind': 'transfer',
      'key': key,
      'source': source,
      'url': page.toString(),
      'title': title.substring(0, title.length.clamp(0, 300)),
      'quality': quality.substring(0, quality.length.clamp(0, 80)),
      'at': now,
      'status': 'preparing',
      'attempt': 1,
      'received': queued || format == 'hls' ? null : 0,
      'resourceId': ?resourceId,
      'cover': ?_publicCover(cover),
      if (retryItemId != null &&
          RegExp(r'^[A-Za-z0-9_.:-]{1,300}$').hasMatch(retryItemId))
        'retryItemId': retryItemId,
      if (format == 'hls') 'format': 'hls',
      if (durationMs != null && durationMs > 0) 'durationMs': durationMs,
      if (sourceDuration != null &&
          sourceDuration.trim().isNotEmpty &&
          sourceDuration.length <= 300)
        'sourceDuration': sourceDuration,
    };
    _liveTasks.add(key);
    _sessionTasks[key] = row;
    try {
      await _persistTransfer(row);
      await ResourceDownloadNotifications.instance.observeBeforeWork();
      return key;
    } catch (_) {
      _liveTasks.remove(key);
      _sessionTasks.remove(key);
      rethrow;
    }
  }

  static int? currentAttempt(String key) =>
      _sessionTasks[key]?['attempt'] as int? ??
      _recoveredTasks[key] ??
      _recoveredMp4Tasks[key];
  static bool isAttemptCurrent(String key, int attempt) =>
      (_liveTasks.contains(key) ||
          _recoveredTasks.containsKey(key) ||
          _recoveredMp4Tasks.containsKey(key)) &&
      currentAttempt(key) == attempt;

  static void setRecoveredHlsTasks(Map<String, int> tasks) {
    if (mapEquals(tasks, _recoveredTasks)) return;
    _recoveredTasks
      ..clear()
      ..addAll(tasks);
    recoveredHlsChanges.value++;
    changes.value++;
  }

  static int get recoveredHlsCount => _recoveredTasks.length;
  static int get recoveredTransferCount =>
      recoveredHlsCount + _recoveredMp4Tasks.length;

  static void setRecoveredMp4Tasks(Map<String, int> tasks) {
    if (mapEquals(tasks, _recoveredMp4Tasks)) return;
    _recoveredMp4Tasks
      ..clear()
      ..addAll(tasks);
    recoveredHlsChanges.value++;
    changes.value++;
  }

  static bool hasProcessTransfer(String key) => _liveTasks.contains(key);

  static Future<Map<String, Map<String, dynamic>>>
  readMp4RecoveryTasks() async {
    await _writes?.catchError((Object _) {});
    return {
      for (final row in _read(
        await SharedPreferences.getInstance(),
        key: taskStorageKey,
      ))
        if (row['kind'] == 'transfer' && (row['format'] ?? 'mp4') == 'mp4')
          row['key'] as String: row,
    };
  }

  static bool matchesMp4Receipt(Map row, Map receipt) =>
      row['key'] == receipt['taskKey'] &&
      row['attempt'] == receipt['attempt'] &&
      row['source'] == receipt['source'] &&
      row['resourceId'] == receipt['resourceId'] &&
      (row['format'] ?? 'mp4') == 'mp4';

  static Future<bool> confirmMp4Terminal(Map receipt, String status) async {
    final rows = await readMp4RecoveryTasks();
    final row = rows[receipt['taskKey']];
    return row != null &&
        matchesMp4Receipt(row, receipt) &&
        row['status'] == status;
  }

  static Future<bool> settleRecoveredMp4(
    Map receipt, {
    required String status,
    int? bytes,
  }) async {
    var accepted = false;
    await _change(
      (rows) {
        final index = rows.indexWhere((row) => matchesMp4Receipt(row, receipt));
        if (index < 0 || _liveTasks.contains(receipt['taskKey'])) return;
        final old = rows[index];
        if (old['status'] == status) {
          accepted = true;
          return;
        }
        if (!const {
          'preparing',
          'downloading',
          'saving',
          'interrupted',
        }.contains(old['status']))
          return;
        rows[index] = {
          ...old,
          'status': status,
          if (bytes != null) 'received': bytes,
          if (bytes != null) 'total': bytes,
          if (status == 'failed') 'failureReason': 'downloadFailed',
        };
        accepted = true;
      },
      key: taskStorageKey,
      shouldWrite: () => accepted,
    );
    return accepted;
  }

  static Future<Map<String, Map<String, dynamic>>>
  readHlsRecoveryTasks() async {
    await _writes?.catchError((Object _) {});
    return {
      for (final row in _read(
        await SharedPreferences.getInstance(),
        key: taskStorageKey,
      ))
        if (row['kind'] == 'transfer' && row['format'] == 'hls')
          row['key'] as String: row,
    };
  }

  static Future<bool> confirmHlsTerminal(
    String key,
    int? attempt,
    String status,
    String? generation,
  ) async {
    if (attempt == null) return false;
    var matched = false;
    try {
      await _change(
        (rows) {
          matched = rows.any(
            (row) =>
                row['key'] == key &&
                row['attempt'] == attempt &&
                row['format'] == 'hls' &&
                row['status'] == status &&
                (status != 'saved' || row['hlsGeneration'] == generation),
          );
        },
        key: taskStorageKey,
        shouldWrite: () => matched,
      );
      return matched;
    } catch (_) {
      return false;
    }
  }

  static bool matchesHlsRecovery(
    Map<String, dynamic> row,
    Map<String, dynamic> receipt,
  ) =>
      row['kind'] == 'transfer' &&
      row['format'] == 'hls' &&
      row['key'] == receipt['taskKey'] &&
      row['attempt'] == receipt['attempt'] &&
      row['source'] == receipt['source'] &&
      row['url'] == receipt['url'] &&
      row['quality'] == receipt['quality'] &&
      row['resourceId'] == receipt['resourceId'];

  /// Run inside the shared storage operation. Hold the task writer across
  /// validation, native publication and persistence so deletion/retry cannot
  /// replace the bound attempt between those operations.
  static Future<bool> settleRecoveredHls(
    Map<String, dynamic> receipt, {
    required bool Function() canPublish,
    required Future<Map<String, dynamic>> Function() publish,
  }) async {
    var accepted = false;
    var changed = false;
    await _change(
      (rows) async {
        final index = rows.indexWhere(
          (row) => matchesHlsRecovery(row, receipt),
        );
        if (index < 0 || _liveTasks.contains(receipt['taskKey'])) return;
        final old = rows[index];
        final status = receipt['status'];
        if (old['status'] == 'saved' &&
            old['hlsGeneration'] == receipt['generation'] &&
            status == 'staged') {
          accepted = true;
          return;
        }
        if (!const {
          'preparing',
          'downloading',
          'saving',
          'interrupted',
        }.contains(old['status'])) {
          // A persisted terminal row may still have an unacknowledged receipt.
          accepted = old['status'] == status;
          return;
        }
        if (status == 'staged') {
          if (!canPublish()) return;
          final file = await publish();
          rows[index] = {
            ...old,
            'status': 'saved',
            'hlsGeneration': file['generation'],
            'received': file['bytes'],
            'total': file['bytes'],
            'packageBytes': file['bytes'],
            'receivedSource': 'package',
            'mediaProgress': 1.0,
            if (file['durationMs'] case final int duration)
              'durationMs': duration,
          }..remove('failureReason');
        } else {
          rows[index] = {
            ...old,
            'status': status,
            if (status == 'failed') 'failureReason': 'downloadFailed',
          };
        }
        accepted = true;
        changed = true;
      },
      key: taskStorageKey,
      shouldWrite: () => accepted,
    );
    if (changed) recoveredHlsChanges.value++;
    return accepted;
  }

  /// Atomically restart this exact public row. A stale menu or double tap can
  /// never create another task or replace a newer attempt.
  static Future<Map<String, dynamic>?> restartTransfer(
    Map<String, dynamic> expected, {
    bool reattach = false,
  }) async {
    Map<String, dynamic>? restarted;
    final key = expected['key'];
    if (key is! String) return null;
    try {
      await _change((rows) {
        final index = rows.indexWhere((row) => row['key'] == key);
        if (index < 0 ||
            _liveTasks.contains(key) ||
            _recoveredTasks.containsKey(key) ||
            _recoveredMp4Tasks.containsKey(key))
          return;
        final old = rows[index];
        for (final field in ['source', 'url', 'quality']) {
          if (old[field] != expected[field]) return;
        }
        if ((old['format'] ?? 'mp4') != (expected['format'] ?? 'mp4') ||
            (old['attempt'] ?? 0) != (expected['attempt'] ?? 0) ||
            old['status'] == 'saved')
          return;
        if (reattach &&
            (old['resourceId'] != expected['resourceId'] ||
                !const {
                  'preparing',
                  'downloading',
                  'saving',
                }.contains(old['status']))) {
          return;
        }
        final page = VideoLocalResources.resourcePage(
          Uri.tryParse('${old['url']}') ?? Uri(),
        );
        final source = old['source'];
        if (page == null || source is! String || source.isEmpty) return;
        DownloadResourceLifecycle.requireAvailable(
          DownloadResourceLifecycle.video(
            VideoLocalResources.identity(
              source,
              page,
              old['format'] == 'hls'
                  ? 'hls|${old['quality']}'
                  : '${old['quality']}',
            ),
          ),
        );
        final row =
            <String, dynamic>{
                ...old,
                if (!reattach)
                  'attempt':
                      (old['attempt'] is int ? old['attempt'] as int : 0) + 1,
                'at': DateTime.now().toUtc().millisecondsSinceEpoch,
                'status': 'preparing',
                'received': null,
                'total': null,
              }
              ..remove('failureReason')
              ..remove('failureStage')
              ..remove('failureDomain')
              ..remove('failureCode')
              ..remove('underlyingDomain')
              ..remove('underlyingCode')
              ..remove('httpStatus')
              ..remove('mediaProgress')
              ..remove('receivedSource')
              ..remove('packageBytes')
              ..remove('networkBytes')
              ..remove('networkTotal')
              ..remove('progressRevision')
              ..remove('recordingFailed');
        if (!reattach) row.remove('resourceId');
        if (!reattach) row.remove('hlsGeneration');
        restarted = row;
        rows[index] = row;
        _sessionTasks[key] = row;
        _liveTasks.add(key);
      }, key: taskStorageKey);
      if (restarted != null) {
        await ResourceDownloadNotifications.instance.observeBeforeWork();
      }
      return restarted == null ? null : Map<String, dynamic>.from(restarted!);
    } catch (_) {
      if (identical(_sessionTasks[key], restarted)) {
        _sessionTasks.remove(key);
        _liveTasks.remove(key);
      }
      rethrow;
    }
  }

  static Future<void> updateTransfer(
    String key, {
    required int? received,
    int? total,
    required String status,
    bool terminal = false,
    String? resourceId,
    double? mediaProgress,
    String? receivedSource,
    int? packageBytes,
    int? networkBytes,
    int? networkTotal,
    int? durationMs,
    String? hlsGeneration,
    int? expectedAttempt,
    String? failureReason,
    String? failureStage,
    String? failureDomain,
    int? failureCode,
    String? underlyingDomain,
    int? underlyingCode,
    int? httpStatus,
    bool clearNetworkWait = false,
  }) async {
    final previous = _sessionTasks[key];
    if (previous == null ||
        expectedAttempt != null && previous['attempt'] != expectedAttempt) {
      return;
    }
    final row = <String, dynamic>{
      ...previous,
      'received': received ?? (terminal ? previous['received'] : null),
      'total':
          total ?? (terminal && received == null ? previous['total'] : null),
      if (const {'network', 'package'}.contains(receivedSource))
        'receivedSource': receivedSource,
      if (packageBytes != null && packageBytes >= 0)
        'packageBytes': packageBytes,
      if (networkBytes != null && networkBytes >= 0) ...{
        'networkBytes': networkBytes,
        'networkTotal':
            networkTotal != null &&
                networkTotal > 0 &&
                networkTotal >= networkBytes
            ? networkTotal
            : null,
      },
      if (status == 'downloading')
        'progressRevision':
            (previous['progressRevision'] is int
                ? previous['progressRevision'] as int
                : 0) +
            1,
      'status': status,
      'recordingFailed': false,
      if (videoDownloadFailureReasons.contains(failureReason))
        'failureReason': failureReason,
      if (const {
        'resolution',
        'retryTransfer',
        'routeSetup',
        'transferPreparation',
        'nativeBridge',
        'nativePreflight',
        'nativeTransfer',
        'offlineValidation',
        'nativeStorage',
      }.contains(failureStage))
        'failureStage': failureStage,
      if (const {
            'NSURLErrorDomain',
            'NSCocoaErrorDomain',
            'NSPOSIXErrorDomain',
            'NSOSStatusErrorDomain',
            'AVFoundationErrorDomain',
            'other',
          }.contains(failureDomain) &&
          failureCode != null)
        'failureDomain': failureDomain,
      if (const {
            'NSURLErrorDomain',
            'NSCocoaErrorDomain',
            'NSPOSIXErrorDomain',
            'NSOSStatusErrorDomain',
            'AVFoundationErrorDomain',
            'other',
          }.contains(failureDomain) &&
          failureCode != null)
        'failureCode': failureCode,
      if (const {
            'NSURLErrorDomain',
            'NSCocoaErrorDomain',
            'NSPOSIXErrorDomain',
            'NSOSStatusErrorDomain',
            'AVFoundationErrorDomain',
            'other',
          }.contains(underlyingDomain) &&
          underlyingCode != null)
        'underlyingDomain': underlyingDomain,
      if (const {
            'NSURLErrorDomain',
            'NSCocoaErrorDomain',
            'NSPOSIXErrorDomain',
            'NSOSStatusErrorDomain',
            'AVFoundationErrorDomain',
            'other',
          }.contains(underlyingDomain) &&
          underlyingCode != null)
        'underlyingCode': underlyingCode,
      if (httpStatus != null && httpStatus >= 100 && httpStatus <= 599)
        'httpStatus': httpStatus,
      'resourceId': ?resourceId,
      if (hlsGeneration != null) 'hlsGeneration': hlsGeneration,
      if (mediaProgress != null && mediaProgress.isFinite)
        'mediaProgress': mediaProgress.clamp(0.0, 1.0),
      if (durationMs != null && durationMs > 0) 'durationMs': durationMs,
    };
    if ((clearNetworkWait || status == 'cancelled') &&
        DownloadNetworkWait.fromCode(row['failureReason']) != null) {
      row.remove('failureReason');
    }
    _sessionTasks[key] = row;
    try {
      await _persistTransfer(row);
    } catch (_) {
      // Keep the real native result visible for this process, while honestly
      // stating that it may be unavailable after restart.
      if (identical(_sessionTasks[key], row)) {
        _sessionTasks[key] = {...row, 'recordingFailed': true};
        changes.value++;
      }
    } finally {
      if (terminal && identical(_sessionTasks[key], row) ||
          terminal && _sessionTasks[key]?['attempt'] == row['attempt']) {
        _liveTasks.remove(key);
        if (_sessionTasks[key]?['recordingFailed'] != true) {
          _sessionTasks.remove(key);
        }
      }
    }
  }

  /// Resolve a queued public episode into a device resource identity. Media
  /// URLs and transport headers never enter the durable task record.
  static Future<void> prepareQueuedTransfer(
    String key, {
    required String source,
    required Uri video,
    required String quality,
    required String format,
    required String resourceId,
    int? expectedAttempt,
  }) async {
    final previous = _sessionTasks[key];
    if (!_liveTasks.contains(key) ||
        previous == null ||
        expectedAttempt != null && previous['attempt'] != expectedAttempt ||
        previous['source'] != source ||
        previous['url'] != VideoLocalResources.resourcePage(video).toString()) {
      throw StateError('Queued video task is no longer current');
    }
    final row = <String, dynamic>{
      ...previous,
      'quality': quality,
      'format': format,
      'resourceId': resourceId,
    };
    _sessionTasks[key] = row;
    await _persistTransfer(row);
  }

  static Future<void> _persistTransfer(Map<String, dynamic> row) =>
      _change((rows) {
        rows.removeWhere((value) => value['key'] == row['key']);
        rows.insert(0, row);
      }, key: taskStorageKey);

  static Future<void> _change(
    FutureOr<void> Function(List<Map<String, dynamic>>) change, {
    bool exportChange = false,
    String key = storageKey,
    bool Function()? shouldWrite,
  }) {
    final job = (_writes ?? Future<void>.value()).catchError((_) {}).then((
      _,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      final rows = _read(prefs, key: key);
      final before = key == taskStorageKey ? _completionInputs(rows) : null;
      await change(rows);
      if (shouldWrite?.call() == false) return;
      if (!await prefs.setString(key, jsonEncode(rows))) {
        throw StateError('Export record was not saved');
      }
      changes.value++;
      if (before != null && !mapEquals(before, _completionInputs(rows))) {
        completionInputsChanged.value++;
      }
      if (exportChange) exportsChanged.value++;
    });
    _writes = job;
    void releaseWrite() {
      if (identical(_writes, job)) _writes = null;
    }

    job.then(
      (_) => releaseWrite(),
      onError: (Object _, StackTrace _) => releaseWrite(),
    );
    return job;
  }

  static Future<void> add({
    required String source,
    required Uri video,
    required String title,
    required String quality,
    String? cover,
  }) {
    final page = videoPublicPage(video);
    if (source.isEmpty || source.length > 200 || page == null) {
      return Future.error(ArgumentError('Invalid public export identity'));
    }
    final publicCover = _publicCover(cover);
    return _change((rows) {
      final key = '$source|$page';
      rows.removeWhere((row) => row['key'] == key);
      rows.insert(0, {
        'key': key,
        'source': source,
        'url': page.toString(),
        'title': title.substring(0, title.length.clamp(0, 300)),
        'quality': quality.substring(0, quality.length.clamp(0, 80)),
        'cover': publicCover,
        'at': DateTime.now().toUtc().millisecondsSinceEpoch,
      });
    }, exportChange: true);
  }

  static String? _publicCover(Object? cover) {
    if (cover is! String || cover.length > 4096) return null;
    final image = Uri.tryParse(cover);
    return image?.scheme == 'https' &&
            image?.host.isNotEmpty == true &&
            image?.userInfo.isEmpty == true &&
            image?.hasQuery == false &&
            image?.hasFragment == false &&
            (image?.hasPort == false || image?.port == 443)
        ? cover
        : null;
  }

  static Future<void> clearTaskRecords(Set<String> keys) async {
    if (keys.isEmpty) return;
    if (keys.any(isLive)) throw StateError('Transfer is still active');
    final resources = await VideoLocalResources.read();
    final external = await read();
    final externalKeys = <String>{
      for (final key in keys)
        if (key.startsWith('external|')) key.substring('external|'.length),
      for (final row in external)
        if (resources.any(
          (item) =>
              keys.contains(item['taskKey']) &&
              item['source'] == row['source'] &&
              item['url'] == row['url'] &&
              item['quality'] == row['quality'],
        ))
          row['key'] as String,
    };
    await VideoLocalResources.hideTasks(keys);
    await _change(
      (rows) => rows.removeWhere(
        (row) => row['kind'] == 'transfer' && keys.contains(row['key']),
      ),
      key: taskStorageKey,
    );
    if (externalKeys.isNotEmpty) await remove(externalKeys);
    for (final key in keys) {
      _sessionTasks.remove(key);
    }
    changes.value++;
  }

  static String _removalFingerprint(Map<String, dynamic> row) => jsonEncode({
    for (final key in (row.keys.toList()..sort())) key: row[key],
  });

  /// Raw local logs only: safe inside an already-owned storage mutation lease,
  /// without recursively queueing VideoLocalResources.read/hideTasks.
  static Future<VideoDownloadRemovalRecords> bindDownloadRemoval(
    String id, {
    Map<String, dynamic>? displayedTask,
    bool onlyDisplayedRecord = false,
  }) async {
    await flush();
    final prefs = await SharedPreferences.getInstance();
    bool matches(Map<String, dynamic> row) {
      try {
        return VideoLocalResources.identity(
              row['source'] as String,
              Uri.parse(row['url'] as String),
              row['format'] == 'hls'
                  ? 'hls|${row['quality'] as String? ?? ''}'
                  : row['quality'] as String? ?? '',
            ) ==
            id;
      } catch (_) {
        return false;
      }
    }

    final displayedKey = displayedTask?['key'];
    final externalKey = displayedTask?['externalKey'];
    bool inScope(Map<String, dynamic> row) =>
        (!onlyDisplayedRecord ||
            (externalKey == null && row['key'] == displayedKey)) &&
        matches(row);
    final persisted = <String, Map<String, dynamic>>{
      for (final row in _read(prefs, key: taskStorageKey))
        if (row['kind'] == 'transfer' && inScope(row))
          row['key'] as String: row,
    };
    final sessions = <String, Map<String, dynamic>>{
      for (final entry in _sessionTasks.entries)
        if (inScope(entry.value)) entry.key: entry.value,
    };
    final latest = <String, Map<String, dynamic>>{...persisted, ...sessions};
    final displayedAttempt = displayedTask?['attempt'];
    final displayedLatest = latest[displayedKey];
    final latestAttempt = displayedLatest?['attempt'];
    if (displayedTask?['kind'] == 'transfer' &&
        (displayedLatest == null ||
            (displayedAttempt ?? 0) != (latestAttempt ?? 0))) {
      throw StateError('Video download changed before confirmation');
    }
    final tasks = latest.values;
    if (tasks.any((row) => isLive(row['key'] as String))) {
      throw StateError('Transfer is still active');
    }
    if (onlyDisplayedRecord && displayedLatest?['status'] == 'saved') {
      throw StateError('The download has completed');
    }
    final exports = {
      for (final row in _read(prefs))
        if (row['kind'] != 'transfer' &&
            (!onlyDisplayedRecord ||
                (row['key'] == externalKey &&
                    row['at'] == displayedTask?['at'] &&
                    row['title'] == displayedTask?['title'] &&
                    row['cover'] == displayedTask?['cover'])) &&
            matches(row))
          row['key'] as String: _removalFingerprint(row),
    };
    if (externalKey is String && onlyDisplayedRecord && exports.isEmpty) {
      throw StateError('Video export record changed before confirmation');
    }
    return VideoDownloadRemovalRecords._(
      {
        for (final entry in persisted.entries)
          entry.key: _removalFingerprint(entry.value),
      },
      {
        for (final entry in sessions.entries)
          entry.key: _removalFingerprint(entry.value),
      },
      exports,
      !onlyDisplayedRecord && tasks.any((row) => row['resourceId'] == id),
    );
  }

  /// Execution may observe fewer bound rows after another deletion, but never
  /// treat a new transfer/export generation as part of an older confirmation.
  static void requireExpectedDownloadRemoval(
    VideoDownloadRemovalRecords current,
    VideoDownloadRemovalRecords expected,
  ) {
    bool subset(Map<String, String> values, Map<String, String> bound) =>
        values.entries.every((entry) => bound[entry.key] == entry.value);
    if (!subset(current._persistedTasks, expected._persistedTasks) ||
        !subset(current._sessions, expected._sessions) ||
        !subset(current._exports, expected._exports)) {
      throw StateError('Video download changed after confirmation');
    }
  }

  /// Remove only the transfer generation and external acknowledgments bound
  /// before file I/O. A later export may reuse its public key and must survive.
  static Future<void> removeBoundDownloadRecords(
    VideoDownloadRemovalRecords bound,
  ) async {
    final keys = bound._taskKeys;
    if (keys.any(isLive)) throw StateError('Transfer became active');
    for (final key in keys) {
      final current = _sessionTasks[key];
      if (current != null &&
          _removalFingerprint(current) != bound._sessions[key]) {
        throw StateError('Session transfer changed during removal');
      }
    }
    if (keys.isNotEmpty) {
      await _change((rows) {
        for (final row in rows) {
          final fingerprint = bound._persistedTasks[row['key']];
          if (keys.contains(row['key']) &&
              _removalFingerprint(row) != fingerprint) {
            throw StateError('Transfer changed during removal');
          }
        }
        rows.removeWhere(
          (row) =>
              bound._persistedTasks[row['key']] == _removalFingerprint(row),
        );
      }, key: taskStorageKey);
    }
    if (bound._exports.isNotEmpty) {
      await _change(
        (rows) => rows.removeWhere(
          (row) => bound._exports[row['key']] == _removalFingerprint(row),
        ),
        exportChange: true,
      );
    }
    for (final entry in bound._sessions.entries) {
      final row = _sessionTasks[entry.key];
      if (row != null && _removalFingerprint(row) == entry.value) {
        _sessionTasks.remove(entry.key);
      }
    }
    changes.value++;
  }

  static Future<void> remove(Set<String> keys) => _change(
    (rows) => rows.removeWhere((row) => keys.contains(row['key'])),
    exportChange: true,
  );
}
