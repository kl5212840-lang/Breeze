import 'package:zephyr/page/video/video_download_continuation.dart';
import 'package:zephyr/page/video/ios_managed_video_recovery.dart';
import 'package:zephyr/page/video/ios_managed_video_transfer.dart';
import 'package:zephyr/service/download/ios_background_transfer.dart';
import 'package:zephyr/page/video/video_download_failure.dart';
import 'package:zephyr/page/video/android_managed_video_attempt.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/page/video/omo_network.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/network/source_network_policy.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/page/video/video_playback_download_adapter.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:zephyr/page/video/video_download_choice.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_download_retry.dart';
import 'package:zephyr/service/download/download_admission.dart';
import 'package:zephyr/service/cache_workspace_guard.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/page/video/video_hls_assets.dart';
import 'package:zephyr/page/video/video_hls_recovery.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/network/sync/sync_service.dart'
    show runExclusiveStorageOperation;

enum VideoDownloadStatus {
  saved,
  cancelled,
  unavailable,
  routeUnavailable,
  busy,
  failed,
  unsupported,
}

typedef VideoDownloadProgress = ({int received, int? total, bool saving});

/// A process-only video-task slot, held through resolution, transfer and commit.
class VideoDownloadPermit {
  VideoDownloadPermit._();
  bool _released = false;
  void release() {
    if (_released) return;
    _released = true;
    VideoSystemDownload._permits.remove(this);
    VideoSystemDownload.notifyConcurrencyChanged();
  }
}

class _VideoDownloadWaiter {
  _VideoDownloadWaiter({this.key, this.attempt, this.isCurrent});

  final String? key;
  final int? attempt;
  final bool Function()? isCurrent;
  bool cancelled = false;

  bool current() => !cancelled && isCurrent?.call() != false;
}

/// One user-initiated native transfer, independent of its initiating sheet.
/// Closing UI does not cancel it. Jobs are not resumable after process exit;
/// signed media URLs and headers remain transient.
class VideoSystemDownload {
  static const _channel = MethodChannel('breeze.video.download');
  static int _sequence = 0;
  static final _active = <VideoSystemDownload>{};
  static final _permits = <VideoDownloadPermit>{};
  static final _capacityChanges = StreamController<void>.broadcast(sync: true);
  static final _progressHandlers =
      <String, ({String channel, Future<void> Function(MethodCall) handle})>{};
  static final _installedChannels = <String>{};
  @visibleForTesting
  static int Function()? concurrencyLimitForTesting;
  static int get concurrencyLimit {
    if (defaultTargetPlatform != TargetPlatform.iOS) return 1;
    try {
      return (concurrencyLimitForTesting?.call() ??
              globalSetting.videoDownloadConcurrency)
          .clamp(1, 3)
          .toInt();
    } catch (_) {
      return 1;
    }
  }

  static final _waitingDownloads = <_VideoDownloadWaiter>[];
  static _VideoDownloadWaiter? _nextDownload;
  static final waitingChanges = ValueNotifier(0);

  static bool canPrioritize(String key, int attempt) => _waitingDownloads.any(
    (waiter) =>
        waiter.key == key && waiter.attempt == attempt && waiter.current(),
  );

  static bool prioritize(String key, int attempt) {
    final waiter = _waitingDownloads
        .where(
          (entry) =>
              entry.key == key && entry.attempt == attempt && entry.current(),
        )
        .firstOrNull;
    if (waiter == null) return false;
    _nextDownload = waiter;
    notifyConcurrencyChanged();
    return true;
  }

  static void notifyConcurrencyChanged() => _capacityChanges.add(null);

  static Future<VideoDownloadPermit?> reserveDownload({
    required String key,
    required int attempt,
    required Future<void> cancelled,
    required bool Function() current,
  }) => _reserve(
    _VideoDownloadWaiter(key: key, attempt: attempt, isCurrent: current),
    cancelled,
  );

  static Future<VideoDownloadPermit?> reserve({
    Future<void>? cancelled,
    bool Function()? current,
  }) => _reserve(_VideoDownloadWaiter(isCurrent: current), cancelled);

  static Future<VideoDownloadPermit?> _reserve(
    _VideoDownloadWaiter waiter,
    Future<void>? cancelled,
  ) async {
    final admission = DownloadAdmission.instance;
    var wake = Completer<void>();
    void changed() {
      if (!wake.isCompleted) wake.complete();
    }

    final subscription = _capacityChanges.stream.listen((_) => changed());
    admission.addListener(changed);
    if (cancelled != null) {
      unawaited(
        cancelled.then((_) {
          waiter.cancelled = true;
          changed();
          notifyConcurrencyChanged();
        }),
      );
    }
    _waitingDownloads.add(waiter);
    if (waiter.key != null) waitingChanges.value++;
    try {
      await admission.start();
      DownloadNetworkWait? publishedNetworkWait;
      while (waiter.current()) {
        wake = Completer<void>();
        final networkWait = admission.networkWait;
        if (waiter.key != null && networkWait != publishedNetworkWait) {
          await VideoExportRecords.updateTransfer(
            waiter.key!,
            expectedAttempt: waiter.attempt,
            received: null,
            status: 'preparing',
            failureReason: networkWait?.code,
            clearNetworkWait: networkWait == null,
          );
          publishedNetworkWait = networkWait;
          continue;
        }
        final next = _nextDownload;
        final first = next != null && next.current()
            ? next
            : _waitingDownloads.where((item) => item.current()).firstOrNull;
        if (identical(first, waiter) &&
            !admission.queuePaused &&
            networkWait == null) {
          final unreserved = _active.where((job) => job._permit == null).length;
          if (_permits.length +
                  unreserved +
                  VideoExportRecords.recoveredTransferCount <
              concurrencyLimit) {
            final permit = VideoDownloadPermit._();
            _permits.add(permit);
            return permit;
          }
        }
        await wake.future;
      }
      return null;
    } finally {
      _waitingDownloads.remove(waiter);
      if (identical(_nextDownload, waiter)) _nextDownload = null;
      admission.removeListener(changed);
      notifyConcurrencyChanged();
      if (waiter.key != null) waitingChanges.value++;
      await subscription.cancel();
    }
  }

  static void _installProgressDispatcher(MethodChannel channel) {
    if (!_installedChannels.add(channel.name)) return;
    channel.setMethodCallHandler((call) async {
      if (channel.name == VideoHlsAssets.channel.name &&
          call.method == 'recoveryChanged') {
        unawaited(VideoHlsRecovery.instance.refresh());
        return;
      }
      final args = call.arguments;
      final handler = args is Map ? _progressHandlers[args['id']] : null;
      if (handler != null && handler.channel == channel.name)
        await handler.handle(call);
    });
  }

  static void startHlsRecovery() {
    if (!VideoHlsAssets.supported || _hlsRecoveryStarted) return;
    _hlsRecoveryStarted = true;
    IosManagedVideoRecovery.start(notifyConcurrencyChanged);
    _installProgressDispatcher(VideoHlsAssets.channel);
    final recovery = VideoHlsRecovery.instance;
    recovery.onCapacityChanged = notifyConcurrencyChanged;
    void recheck() => unawaited(recovery.refresh());
    final admission = DownloadAdmission.instance;
    var wifiOnly = admission.wifiOnly;
    admission.addListener(() {
      if (wifiOnly == admission.wifiOnly) return;
      wifiOnly = admission.wifiOnly;
      recheck();
    });
    pluginSessionWriteFence.changes.listen((_) => recheck());
    PluginRegistryService.I.stream.listen((_) => recheck());
    SourceNetworkPolicies.changes.listen((_) => recheck());
    recheck();
  }

  static bool _hlsRecoveryStarted = false;

  static final _queuedCancels =
      <
        String,
        ({
          String source,
          Future<void> Function() cancel,
          int? attempt,
          Completer<void> settled,
        })
      >{};
  static void registerQueuedTask(
    String key,
    String source,
    Future<void> Function() cancel, {
    int? attempt,
  }) {
    _queuedCancels.remove(key)?.settled.complete();
    _queuedCancels[key] = (
      source: source,
      cancel: cancel,
      attempt: attempt,
      settled: Completer<void>(),
    );
  }

  static void unregisterQueuedTask(String key, {int? attempt}) {
    if (attempt == null || _queuedCancels[key]?.attempt == attempt)
      _queuedCancels.remove(key)?.settled.complete();
  }

  static Future<void> waitForQueuedTaskToSettle(String key, int attempt) async {
    final queued = _queuedCancels[key];
    if (queued?.attempt == attempt) await queued?.settled.future;
  }

  static bool isQueuedTask(String key) => _queuedCancels.containsKey(key);
  static bool get hasActiveTransfer => _active.isNotEmpty;
  static Future<void> waitForIdle() async {
    while (_active.isNotEmpty) {
      await Future.any<void>([
        for (final job in _active.toList())
          if (job._settled != null) job._settled!.future,
      ]);
    }
  }

  String? _job;
  String? _androidTransferKey, _androidScope;
  IosManagedVideoTransfer? _iosTransfer;
  String? _taskKey;
  int? _taskAttempt;
  String? _failureReason;
  String? _failureStage;
  int? _failureHttpStatus;
  String? get taskKey => _taskKey;
  String? lastTaskKey;
  String? get failureReason => _failureReason;
  String? get failureStage => _failureStage;
  String? _source;
  Completer<void>? _settled;
  bool _cancelRequested = false;
  Completer<void>? _queuedCancellation;
  VideoDownloadPermit? _permit;
  MethodChannel? _transferChannel;

  static void beginContinuedAttempts(Iterable<VideoDownloadAttempt> attempts) {
    VideoDownloadContinuation.add({
      for (final attempt in attempts)
        if (_queuedCancels[attempt.key] case final owner?)
          if (owner.attempt == attempt.attempt)
            attempt: () async {
              if (!identical(
                    _queuedCancels[attempt.key]?.settled,
                    owner.settled,
                  ) ||
                  !VideoExportRecords.isAttemptCurrent(
                    attempt.key,
                    attempt.attempt,
                  ))
                return;
              await owner.cancel();
              await owner.settled.future;
            },
    });
  }

  static Future<void> cancelTask(String key, {int? expectedAttempt}) async {
    if (expectedAttempt != null &&
        !VideoExportRecords.isAttemptCurrent(key, expectedAttempt)) {
      return;
    }
    final queued = _queuedCancels[key];
    if (queued != null &&
        (expectedAttempt == null || queued.attempt == expectedAttempt)) {
      await queued.cancel();
      return;
    }
    final active = _active
        .where(
          (job) =>
              job._taskKey == key &&
              (expectedAttempt == null || job._taskAttempt == expectedAttempt),
        )
        .firstOrNull;
    if (active != null) {
      await active.cancel();
    } else if (VideoHlsAssets.supported) {
      await VideoHlsRecovery.instance.cancel(key, expectedAttempt);
      await IosManagedVideoRecovery.cancelTask(key, expectedAttempt);
    }
  }

  static Future<void> stopSource(String source) async {
    await VideoHlsRecovery.instance.stopSource(source);
    await IosManagedVideoRecovery.stopSource(source);
    for (final queued
        in _queuedCancels.values
            .where((entry) => entry.source == source)
            .toList()) {
      await queued.cancel();
    }
    final active = _active.where((job) => job._source == source).toList();
    final settled = [
      for (final job in active)
        if (job._settled != null) job._settled!.future,
    ];
    await Future.wait(active.map((job) => job.cancel()));
    await Future.wait(settled).timeout(const Duration(seconds: 20));
  }

  static bool get available =>
      !kIsWeb &&
      [
        TargetPlatform.iOS,
        TargetPlatform.android,
      ].contains(defaultTargetPlatform);

  bool _savingRequest = false;
  Future<VideoDownloadStatus> save({
    required VideoDownloadChoice choice,
    String? networkContext,
    Map<String, String> headers = const {},
    String source = '',
    String? cover,
    int? durationMs,
    String? sourceDuration,
    bool replaceExisting = false,
    bool userInitiated = false,
    String? queuedTaskKey,
    VideoDownloadPermit? permit,
    ValueChanged<double>? onMediaProgress,
    required Uri video,
    required String title,
    required ValueChanged<VideoDownloadProgress> onProgress,
  }) async {
    if (_savingRequest) return VideoDownloadStatus.busy;
    _savingRequest = true;
    try {
      return await _saveRequest(
        choice: choice,
        networkContext: networkContext,
        headers: headers,
        source: source,
        cover: cover,
        durationMs: durationMs,
        sourceDuration: sourceDuration,
        replaceExisting: replaceExisting,
        userInitiated: userInitiated,
        queuedTaskKey: queuedTaskKey,
        permit: permit,
        onMediaProgress: onMediaProgress,
        video: video,
        title: title,
        onProgress: onProgress,
      );
    } finally {
      _savingRequest = false;
    }
  }

  Future<VideoDownloadStatus> _saveRequest({
    VideoDownloadChoice? choice,
    AndroidManagedVideoAttempt? attachment,
    String? networkContext,
    Map<String, String> headers = const {},
    String source = '',
    String? cover,
    int? durationMs,
    String? sourceDuration,
    bool replaceExisting = false,
    bool userInitiated = false,
    String? queuedTaskKey,
    VideoDownloadPermit? permit,
    ValueChanged<double>? onMediaProgress,
    required Uri video,
    required String title,
    required ValueChanged<VideoDownloadProgress> onProgress,
  }) async {
    if (_queuedCancellation != null || _active.contains(this))
      return VideoDownloadStatus.busy;
    lastTaskKey = null;
    _cancelRequested = false;
    _failureReason = null;
    _failureStage = null;
    _failureHttpStatus = null;
    // Only registry UUIDs have an installation lifecycle. Built-in sources and
    // ordinary non-plugin callers retain their existing download behavior.
    final installation = SourceNetworkPolicies.supports(source)
        ? LocalPluginInstallationState.instance
        : null;
    await installation?.load();
    final epoch = installation?.installationEpoch(source);
    final accountGeneration = pluginSessionWriteFence.generation(source);
    var effectiveQueuedKey = queuedTaskKey;
    var queuedAttempt = queuedTaskKey == null
        ? null
        : VideoExportRecords.currentAttempt(queuedTaskKey);
    bool sourceCurrent() =>
        !_cancelRequested &&
        !pluginSessionWriteFence.isChanging(source) &&
        pluginSessionWriteFence.generation(source) == accountGeneration &&
        (effectiveQueuedKey == null ||
            queuedAttempt != null &&
                VideoExportRecords.isAttemptCurrent(
                  effectiveQueuedKey!,
                  queuedAttempt!,
                )) &&
        (_taskKey == null ||
            _taskAttempt != null &&
                VideoExportRecords.isAttemptCurrent(
                  _taskKey!,
                  _taskAttempt!,
                )) &&
        (installation == null ||
            (!installation.isRemoved(source) &&
                !installation.isInstalling(source) &&
                installation.installationEpoch(source) == epoch));
    if (!sourceCurrent()) return VideoDownloadStatus.cancelled;
    if (choice != null &&
        queuedTaskKey == null &&
        !replaceExisting &&
        source.isNotEmpty &&
        available &&
        _validRequest(choice, video, headers, source)) {
      try {
        final existing = await _availableChoice(source, video, choice);
        if (!sourceCurrent()) return VideoDownloadStatus.cancelled;
        if (existing != null) {
          lastTaskKey = existing['taskKey'] as String?;
          onProgress((
            received: existing['bytes'] as int,
            total: existing['bytes'] as int,
            saving: false,
          ));
          onMediaProgress?.call(1);
          return VideoDownloadStatus.saved;
        }
      } catch (_) {
        _failureReason = 'storage';
        return VideoDownloadStatus.failed;
      }
    }
    Future<VideoDownloadStatus> transfer(
      String? key,
      VideoDownloadPermit? slot,
    ) => CacheWorkspaceGuard.withWorkspace(
      () => _withRoute(
        source,
        networkContext,
        () => _save(
          choice: choice,
          attachment: attachment,
          headers: headers,
          networkContext: networkContext,
          source: source,
          cover: cover,
          durationMs: durationMs,
          sourceDuration: sourceDuration,
          replaceExisting: replaceExisting,
          queuedTaskKey: key,
          permit: slot,
          onMediaProgress: (fraction) {
            final attempt = queuedAttempt;
            if (key != null && attempt != null) {
              VideoDownloadContinuation.progress((
                key: key,
                attempt: attempt,
              ), fraction);
            }
            onMediaProgress?.call(fraction);
          },
          video: video,
          title: title,
          onProgress: (progress) {
            final attempt = queuedAttempt;
            final total = progress.total;
            if (key != null &&
                attempt != null &&
                choice?.url.path.toLowerCase().endsWith('.m3u8') != true &&
                total != null &&
                total > 0) {
              VideoDownloadContinuation.progress((
                key: key,
                attempt: attempt,
              ), progress.received / total);
            }
            onProgress(progress);
          },
          sourceCurrent: sourceCurrent,
        ),
      ),
    );
    if (choice != null &&
        queuedTaskKey == null &&
        source.isNotEmpty &&
        available &&
        _validRequest(choice, video, headers, source)) {
      if (choice.url.path.toLowerCase().endsWith('.m3u8') &&
          !VideoHlsAssets.supported)
        return VideoDownloadStatus.unsupported;
      return _admitTransfer(
        source: source,
        video: video,
        title: title,
        choice: choice,
        cover: cover,
        durationMs: durationMs,
        sourceDuration: sourceDuration,
        networkContext: networkContext,
        current: sourceCurrent,
        admitted: (key, attempt) {
          effectiveQueuedKey = key;
          queuedAttempt = attempt;
          if (userInitiated)
            beginContinuedAttempts([(key: key, attempt: attempt)]);
        },
        transfer: transfer,
      );
    }
    if (queuedTaskKey != null && permit == null) {
      final slot = await reserve(current: sourceCurrent);
      if (slot == null) return VideoDownloadStatus.cancelled;
      try {
        return await transfer(queuedTaskKey, slot);
      } finally {
        slot.release();
      }
    }
    return transfer(queuedTaskKey, permit);
  }

  Future<VideoDownloadStatus> reattachAndroidManaged(
    AndroidManagedVideoAttempt attachment,
    Map<String, dynamic> row, {
    required VideoDownloadPermit permit,
  }) async {
    if (_savingRequest) return VideoDownloadStatus.busy;
    _savingRequest = true;
    try {
      return await _saveRequest(
        attachment: attachment,
        source: attachment.source,
        video: attachment.video,
        title: row['title'] is String ? row['title'] as String : '',
        cover: row['cover'] is String ? row['cover'] as String : null,
        durationMs: row['durationMs'] is int ? row['durationMs'] as int : null,
        sourceDuration: row['sourceDuration'] is String
            ? row['sourceDuration'] as String
            : null,
        queuedTaskKey: attachment.taskKey,
        permit: permit,
        onProgress: (_) {},
      );
    } finally {
      _savingRequest = false;
    }
  }

  Future<VideoDownloadStatus> _admitTransfer({
    required String source,
    required Uri video,
    required String title,
    required VideoDownloadChoice choice,
    required bool Function() current,
    required Future<VideoDownloadStatus> Function(String, VideoDownloadPermit?)
    transfer,
    required void Function(String, int) admitted,
    String? networkContext,
    String? cover,
    int? durationMs,
    String? sourceDuration,
  }) async {
    if (_queuedCancellation != null || _active.contains(this))
      return VideoDownloadStatus.busy;
    final cancelled = _queuedCancellation = Completer<void>();
    String? key;
    int? attempt;
    StreamSubscription<PluginSessionBoundary>? subscription;
    VideoDownloadPermit? slot;
    OmoNetworkContext? visitOwner;
    var status = VideoDownloadStatus.failed;
    try {
      if (networkContext != null &&
          OmoNetworkContext.findActiveVisit(source, networkContext) != null) {
        visitOwner = await OmoNetworkContext.open(
          null,
          source: source,
          siteOrigins: [Uri.parse(video.origin)],
        );
        if (visitOwner?.token != networkContext)
          return status = VideoDownloadStatus.routeUnavailable;
      }
      key = await runExclusiveStorageOperation(() async {
        if (cancelled.isCompleted || !current()) return null;
        final page = videoPlaybackIdentity(video).toString();
        final format = choice.url.path.toLowerCase().endsWith('.m3u8')
            ? 'hls'
            : 'mp4';
        if (VideoExportRecords.sessionTaskSnapshot().any(
          (row) =>
              VideoExportRecords.isLive('${row['key']}') &&
              row['source'] == source &&
              row['url'] == page &&
              row['quality'] == choice.label &&
              (row['format'] ?? 'mp4') == format,
        ))
          return null;
        return VideoExportRecords.beginTransfer(
          source: source,
          video: video,
          title: title,
          quality: choice.label,
          cover: cover,
          durationMs: durationMs,
          sourceDuration: sourceDuration,
          format: format,
          queued: true,
          reuseTerminal: true,
        );
      });
      if (key == null)
        return status = cancelled.isCompleted || !current()
            ? VideoDownloadStatus.cancelled
            : VideoDownloadStatus.busy;
      lastTaskKey = key;
      attempt = VideoExportRecords.currentAttempt(key)!;
      subscription = pluginSessionWriteFence.changes.listen((boundary) {
        if (boundary.source == source && !current()) {
          _failureReason = 'accountChanged';
          unawaited(cancel());
        }
      });
      registerQueuedTask(key, source, cancel, attempt: attempt);
      admitted(key, attempt);
      slot = await reserveDownload(
        key: key,
        attempt: attempt,
        cancelled: cancelled.future,
        current: () => !cancelled.isCompleted && current(),
      );
      if (slot == null) return status = VideoDownloadStatus.cancelled;
      do {
        if (cancelled.isCompleted || !current())
          return status = VideoDownloadStatus.cancelled;
        status = await transfer(key, slot);
        if (status == VideoDownloadStatus.busy && hasActiveTransfer)
          await Future.any<void>([waitForIdle(), cancelled.future]);
      } while (status == VideoDownloadStatus.busy &&
          hasActiveTransfer &&
          !cancelled.isCompleted);
      return status;
    } catch (_) {
      _failureReason ??= 'storage';
      return status = VideoDownloadStatus.failed;
    } finally {
      try {
        await subscription?.cancel();
        if (key != null && VideoExportRecords.isLive(key)) {
          await VideoExportRecords.updateTransfer(
            key,
            received: null,
            status: status.name,
            terminal: true,
            expectedAttempt: attempt,
            failureReason: _failureReason,
            failureStage: _failureStage,
          );
        }
      } finally {
        slot?.release();
        try {
          await visitOwner?.close();
        } catch (_) {
          /* Retire this owner only. */
        }
        if (key != null) {
          unregisterQueuedTask(key, attempt: attempt);
          if (attempt != null)
            VideoDownloadContinuation.finish((
              key: key,
              attempt: attempt,
            ), saved: status == VideoDownloadStatus.saved);
        }
        if (identical(_queuedCancellation, cancelled))
          _queuedCancellation = null;
      }
    }
  }

  static bool _validRequest(
    VideoDownloadChoice choice,
    Uri video,
    Map<String, String> headers,
    String source,
  ) {
    final media = choice.url;
    final page = videoPlaybackIdentity(video);
    bool https(Uri value) =>
        value.scheme == 'https' &&
        value.host.isNotEmpty &&
        value.userInfo.isEmpty &&
        (!value.hasPort || value.port == 443) &&
        !value.hasFragment;
    return https(media) &&
        (media.path.toLowerCase().endsWith('.mp4') ||
            media.path.toLowerCase().endsWith('.m3u8')) &&
        media.toString().length <= 8192 &&
        page != null &&
        videoPublicPage(page) != null &&
        VideoPlaybackDownloadAdapter.publicHeaders(headers, page) != null &&
        (source.isNotEmpty || page.path == '/watch') &&
        source.length <= 200 &&
        choice.label.length <= 80;
  }

  static Future<Map<String, dynamic>?> _availableChoice(
    String source,
    Uri video,
    VideoDownloadChoice choice,
  ) async {
    final hls = choice.url.path.toLowerCase().endsWith('.m3u8');
    final id = hls
        ? VideoHlsAssets.identity(source, video, choice.label)
        : VideoLocalResources.identity(source, video, choice.label);
    final page = videoPlaybackIdentity(video)?.toString();
    return (await VideoLocalResources.read())
        .where(
          (row) =>
              row['resourceId'] == id &&
              row['source'] == source &&
              row['url'] == page &&
              row['quality'] == choice.label &&
              (row['format'] == 'hls' ? 'hls' : 'mp4') ==
                  (hls ? 'hls' : 'mp4') &&
              row['available'] == true &&
              row['filePresent'] == true,
        )
        .firstOrNull;
  }

  static bool _routeSupported(SourceNetworkLease? route, String? context) =>
      route == null ||
      route.snapshot.proxy.isEmpty ||
      defaultTargetPlatform == TargetPlatform.iOS &&
          context?.isNotEmpty == true;

  static Future<bool> supportsRoute(String source, String? context) async {
    if (!SourceNetworkPolicies.supports(source)) return true;
    final route = await SourceNetworkPolicies.acquire(source);
    try {
      return _routeSupported(route, context);
    } finally {
      await route.close();
    }
  }

  Future<VideoDownloadStatus> _withRoute(
    String source,
    String? context,
    Future<VideoDownloadStatus> Function() action,
  ) async {
    SourceNetworkLease? route;
    try {
      if (SourceNetworkPolicies.supports(source))
        route = await SourceNetworkPolicies.acquire(source);
      if (!_routeSupported(route, context))
        return VideoDownloadStatus.routeUnavailable;
      return await action();
    } catch (_) {
      _failureStage ??= 'routeSetup';
      return VideoDownloadStatus.failed;
    } finally {
      await route?.close();
    }
  }

  Future<VideoDownloadStatus> _save({
    required bool Function() sourceCurrent,
    VideoDownloadChoice? choice,
    AndroidManagedVideoAttempt? attachment,
    String? networkContext,
    Map<String, String> headers = const {},
    String source = '',
    String? cover,
    int? durationMs,
    String? sourceDuration,
    bool replaceExisting = false,
    String? queuedTaskKey,
    VideoDownloadPermit? permit,
    ValueChanged<double>? onMediaProgress,
    required Uri video,
    required String title,
    required ValueChanged<VideoDownloadProgress> onProgress,
  }) async {
    if (!available) return VideoDownloadStatus.unavailable;
    final admission = DownloadAdmission.instance;
    await admission.start();
    if (!sourceCurrent()) return VideoDownloadStatus.cancelled;
    if (permit?._released == true) return VideoDownloadStatus.cancelled;
    if (permit == null &&
        _active.length + VideoExportRecords.recoveredTransferCount >=
            concurrencyLimit)
      return VideoDownloadStatus.busy;
    final media = choice?.url;
    final quality = choice?.label ?? attachment!.quality;
    final hls = media?.path.toLowerCase().endsWith('.m3u8') == true;
    if (hls && (!VideoHlsAssets.supported || source.isEmpty))
      return VideoDownloadStatus.unsupported;
    if (choice != null && !_validRequest(choice, video, headers, source)) {
      _failureStage = 'transferPreparation';
      return VideoDownloadStatus.failed;
    }
    final page = videoPlaybackIdentity(video)!;
    final referer = videoPublicPage(page)!;
    final safeHeaders = VideoPlaybackDownloadAdapter.publicHeaders(
      headers,
      page,
    )!;
    final managedId = source.isEmpty
        ? null
        : hls
        ? VideoHlsAssets.identity(source, video, quality)
        : VideoLocalResources.identity(source, video, quality);
    if (attachment != null &&
        (attachment.resourceId != managedId ||
            attachment.taskKey != queuedTaskKey ||
            !VideoExportRecords.isAttemptCurrent(
              attachment.taskKey,
              attachment.attempt,
            ))) {
      return VideoDownloadStatus.cancelled;
    }
    if (managedId != null && !VideoLocalResources.tryHold(managedId)) {
      return VideoDownloadStatus.busy;
    }
    if (choice != null && managedId != null && !replaceExisting) {
      try {
        final existing = await _availableChoice(source, video, choice);
        if (!sourceCurrent()) return VideoDownloadStatus.cancelled;
        if (existing != null) {
          if (queuedTaskKey != null) {
            await VideoExportRecords.prepareQueuedTransfer(
              queuedTaskKey,
              source: source,
              video: video,
              quality: choice.label,
              format: hls ? 'hls' : 'mp4',
              resourceId: managedId,
              expectedAttempt: VideoExportRecords.currentAttempt(queuedTaskKey),
            );
          }
          if (!sourceCurrent()) return VideoDownloadStatus.cancelled;
          lastTaskKey = queuedTaskKey ?? existing['taskKey'] as String?;
          onProgress((
            received: existing['bytes'] as int,
            total: existing['bytes'] as int,
            saving: false,
          ));
          onMediaProgress?.call(1);
          return VideoDownloadStatus.saved;
        }
      } catch (_) {
        _failureReason = 'storage';
        _failureStage = 'transferPreparation';
        return VideoDownloadStatus.failed;
      } finally {
        // No native writer has started yet. Retain the lock only when entering
        // the normal transfer below; checking existing files is otherwise read-only.
        VideoLocalResources.release(managedId);
      }
      if (!VideoLocalResources.tryHold(managedId))
        return VideoDownloadStatus.busy;
    }
    final hasSpace = attachment != null || await admission.hasSpace();
    if (!sourceCurrent() ||
        permit?._released == true ||
        !hasSpace ||
        (permit == null &&
            _active.length + VideoExportRecords.recoveredTransferCount >=
                concurrencyLimit)) {
      if (managedId != null) VideoLocalResources.release(managedId);
      if (!sourceCurrent() || permit?._released == true) {
        return VideoDownloadStatus.cancelled;
      }
      if (!hasSpace) {
        _failureReason = 'outOfSpace';
        _failureStage = 'transferPreparation';
        return VideoDownloadStatus.failed;
      }
      return VideoDownloadStatus.busy;
    }
    final job = 'video-file-${++_sequence}';
    _job = job;
    _failureReason = null;
    _failureHttpStatus = null;
    _source = source;
    _settled = Completer<void>();
    _cancelRequested = false;
    _permit = permit;
    _active.add(this);
    final accountGeneration = pluginSessionWriteFence.generation(source);
    final accountSubscription = pluginSessionWriteFence.changes.listen((
      boundary,
    ) {
      if (boundary.source == source &&
          (boundary.changing || boundary.generation != accountGeneration)) {
        _failureReason = 'accountChanged';
        unawaited(cancel().catchError((Object _) {}));
      }
    });
    final routeSubscription = SourceNetworkPolicies.changes.listen((changed) {
      final transfer = _iosTransfer;
      if (changed != source || transfer == null) return;
      unawaited(() async {
        if (!await VideoHlsRecovery.directRoute(source) &&
            identical(_iosTransfer, transfer)) {
          _failureReason = 'routeUnavailable';
          await cancel().catchError((Object _) {});
        }
      }());
    });
    final pluginSubscription = PluginRegistryService.I.stream.listen((_) {
      final transfer = _iosTransfer;
      if (transfer != null && !transfer.scopeIsCurrent) {
        _failureReason = 'accountChanged';
        unawaited(cancel().catchError((Object _) {}));
      }
    });
    VideoDownloadProgress latest = (received: 0, total: null, saving: false);
    int? measuredReceived = hls ? null : 0;
    int? measuredPackageBytes, measuredNetworkBytes, measuredNetworkTotal;
    String? receivedSource;
    DateTime? lastCheckpoint;
    bool? lastSaving;
    final channel = _transferChannel = hls ? VideoHlsAssets.channel : _channel;
    DownloadNetworkWait? interruptedBy;
    DownloadNetworkWait? hlsObservedNetworkWait;
    var nativeStarted = false;
    var nativeWifiOnly = false;
    void networkChanged() {
      if (!sourceCurrent() || interruptedBy != null) return;
      final wait = admission.networkWait;
      if (nativeStarted && (hls || _iosTransfer != null)) {
        if (nativeWifiOnly == admission.wifiOnly) {
          // iOS owns connectivity and cellular admission for this session.
          // Remember an outage only for a confirmed native failure.
          hlsObservedNetworkWait = wait ?? hlsObservedNetworkWait;
          return;
        }
        // Session configuration is fixed after creation. Recreate this
        // attempt when the user changes the active Wi-Fi policy.
        interruptedBy = wait ?? DownloadNetworkWait.wifi;
      } else {
        if (wait == null) return;
        interruptedBy = wait;
      }
      if (nativeStarted) {
        final iosTransfer = _iosTransfer;
        if (iosTransfer != null) {
          unawaited(iosTransfer.cancel().catchError((Object _) {}));
          return;
        }
        unawaited(
          channel
              .invokeMethod<void>('cancel', {
                'id': job,
                'transferKey': ?_androidTransferKey,
                'scope': ?_androidScope,
              })
              .catchError((Object _) {}),
        );
      }
    }

    admission.addListener(networkChanged);
    networkChanged();
    double? mediaProgress;
    _installProgressDispatcher(channel);
    _progressHandlers[job] = (
      channel: channel.name,
      handle: (call) async {
        final args = call.arguments;
        if (call.method != 'progress' ||
            args is! Map ||
            args['id'] != job ||
            _job != job) {
          return;
        }
        final received = args['received'];
        final total = args['total'];
        if (!hls && (received is! int || received < 0)) {
          return;
        }
        if (received is int && received >= 0) {
          measuredReceived = received;
          receivedSource = hls && args['receivedSource'] == 'package'
              ? 'package'
              : 'network';
        }
        final packageBytes = args['packageBytes'];
        final networkBytes = args['networkBytes'];
        final networkTotal = args['networkTotal'];
        if (packageBytes is int && packageBytes >= 0) {
          measuredPackageBytes = packageBytes;
        } else if (hls && receivedSource == 'package') {
          measuredPackageBytes = measuredReceived;
        }
        if (networkBytes is int && networkBytes >= 0) {
          measuredNetworkBytes = networkBytes;
          measuredNetworkTotal =
              networkTotal is int &&
                  networkTotal > 0 &&
                  networkTotal >= networkBytes
              ? networkTotal
              : null;
        } else if (received is int &&
            received >= 0 &&
            receivedSource == 'network') {
          measuredNetworkBytes = received;
          measuredNetworkTotal = total is int && total > 0 && total >= received
              ? total
              : null;
        }
        latest = (
          received: received is int && received >= 0
              ? received
              : latest.received,
          total: total is int && total > 0 ? total : null,
          saving: args['saving'] == true,
        );
        onProgress(latest);
        final loaded = args['loadedTimeMs'], expected = args['totalTimeMs'];
        if (hls &&
            loaded is int &&
            loaded >= 0 &&
            expected is int &&
            expected > 0) {
          mediaProgress = (loaded / expected).clamp(0.0, 1.0);
          onMediaProgress?.call(mediaProgress!);
        }
        final key = _taskKey;
        final now = DateTime.now();
        final checkpoint = lastCheckpoint;
        if (key != null &&
            (checkpoint == null ||
                lastSaving != latest.saving ||
                now.difference(checkpoint) >= const Duration(seconds: 1))) {
          lastCheckpoint = now;
          lastSaving = latest.saving;
          unawaited(
            VideoExportRecords.updateTransfer(
              key,
              expectedAttempt: _taskAttempt,
              received: measuredReceived,
              receivedSource: receivedSource,
              packageBytes: measuredPackageBytes,
              networkBytes: measuredNetworkBytes,
              networkTotal: measuredNetworkTotal,
              total: latest.total,
              status: latest.saving ? 'saving' : 'downloading',
              mediaProgress: mediaProgress,
            ),
          );
        }
      },
    );
    var status = VideoDownloadStatus.failed;
    String? storedId, stageId;
    Map? hlsCandidate;
    Map? hlsReceipt;
    String? failureStage, failureDomain, underlyingDomain;
    var exceptionStage = 'transferPreparation';
    int? failureCode, underlyingCode;
    String? expectedGeneration;
    int? committedDuration;
    String? committedHlsGeneration;
    try {
      if (hls) {
        expectedGeneration =
            (await VideoHlsAssets.read())
                    .where((row) => row['resourceId'] == managedId)
                    .firstOrNull?['generation']
                as String?;
      }
      if (source.isNotEmpty) {
        if (queuedTaskKey != null) {
          _taskKey = queuedTaskKey;
          _taskAttempt = VideoExportRecords.currentAttempt(queuedTaskKey);
          if (attachment == null) {
            await VideoExportRecords.prepareQueuedTransfer(
              queuedTaskKey,
              source: source,
              video: video,
              quality: quality,
              format: hls ? 'hls' : 'mp4',
              resourceId: managedId!,
              expectedAttempt: _taskAttempt,
            );
          }
        } else {
          _taskKey = await VideoExportRecords.beginTransfer(
            source: source,
            video: video,
            title: title,
            quality: quality,
            resourceId: managedId,
            cover: cover,
            durationMs: durationMs,
            sourceDuration: sourceDuration,
            format: hls ? 'hls' : 'mp4',
          );
          _taskAttempt = VideoExportRecords.currentAttempt(_taskKey!);
        }
        lastTaskKey = _taskKey;
      }
      if (_cancelRequested || !sourceCurrent()) {
        status = VideoDownloadStatus.cancelled;
        return status;
      }
      if (interruptedBy case final wait?) {
        _failureReason = wait.code;
        return status = VideoDownloadStatus.failed;
      }
      exceptionStage = 'nativeBridge';
      final androidScope = !hls && managedId != null
          ? AndroidManagedVideoAttempt.scopeFor(source)
          : null;
      if (attachment != null && androidScope != attachment.scope) {
        _failureReason = 'accountChanged';
        return status = VideoDownloadStatus.cancelled;
      }
      final recoveryScope = hls && _taskAttempt != null
          ? await VideoHlsRecovery.scopeForStart(source)
          : null;
      if (!sourceCurrent() || _cancelRequested) {
        return status = VideoDownloadStatus.cancelled;
      }
      nativeWifiOnly = admission.wifiOnly;
      nativeStarted = true;
      _androidTransferKey = androidScope != null
          ? AndroidManagedVideoAttempt.keyFor(_taskKey, _taskAttempt)
          : null;
      _androidScope = _androidTransferKey == null ? null : androidScope;
      Object? iosResult;
      if (IosBackgroundTransfer.supported &&
          !hls &&
          managedId != null &&
          media != null &&
          !media.hasQuery &&
          media.host.contains('.') &&
          networkContext == null &&
          _taskKey != null &&
          _taskAttempt != null) {
        final scope = await VideoHlsRecovery.scopeForStart(source);
        if (scope != null && sourceCurrent() && !_cancelRequested) {
          final current = (await VideoLocalResources.read(
            fresh: true,
          )).where((row) => row['resourceId'] == managedId).firstOrNull;
          if (!sourceCurrent() || _cancelRequested) {
            return status = VideoDownloadStatus.cancelled;
          }
          final transfer = _iosTransfer = IosManagedVideoTransfer(
            source: source,
            scope: scope,
            taskKey: _taskKey!,
            attempt: _taskAttempt!,
            resourceId: managedId,
            media: media,
            headers: {'Referer': referer.toString(), ...safeHeaders},
            wifiOnly: nativeWifiOnly,
            expectedVersion: current == null
                ? ''
                : VideoLocalResources.resourceVersion(current),
          );
          IosManagedVideoRecovery.live.add(
            transfer.binding['batchId'] as String,
          );
          try {
            int? expectedBytes;
            iosResult = await transfer.download(
              onExpectedBytes: (total) => expectedBytes = total,
              onProgress: (bytes, saving) => _progressHandlers[job]!.handle(
                MethodCall('progress', {
                  'id': job,
                  'received': bytes,
                  'total': saving ? bytes : expectedBytes,
                  'saving': saving,
                }),
              ),
            );
          } on MissingPluginException {
            if (transfer.submitted) rethrow;
          }
          if (iosResult == null) {
            IosManagedVideoRecovery.live.remove(transfer.binding['batchId']);
            _iosTransfer = null;
          }
        }
      }
      if (_cancelRequested && iosResult == null) {
        return status = VideoDownloadStatus.cancelled;
      }
      final result =
          iosResult ??
          (attachment != null
              ? await attachment.attach(job)
              : await channel.invokeMethod<Object?>('start', {
                  'id': job,
                  'managedId': ?managedId,
                  'transferKey': ?_androidTransferKey,
                  'scope': ?_androidScope,
                  'networkContext': ?networkContext,
                  if (nativeWifiOnly) 'wifiOnly': true,
                  'url': media!.toString(),
                  // Never forward cookies, session parameters or CDN URL as Referer.
                  'referer': referer.toString(),
                  if (safeHeaders.isNotEmpty) 'headers': safeHeaders,
                  'title': title.length > 160 ? title.substring(0, 160) : title,
                  'quality': quality,
                  if (hls) ...{
                    'source': source,
                    'video': page.toString(),
                    'taskKey': _taskKey,
                    'cover': ?cover,
                    'durationMs': ?durationMs,
                    'sourceDuration': ?sourceDuration,
                    'expectedGeneration': ?expectedGeneration,
                    if (recoveryScope != null) ...{
                      'attempt': _taskAttempt,
                      'recoveryScope': recoveryScope,
                    },
                  },
                }));
      nativeStarted = false;
      if (recoveryScope != null &&
          result is Map &&
          result['resourceId'] == managedId &&
          result['assetId'] is String &&
          result['generation'] is String) {
        hlsReceipt = result;
      }
      final nativeNetworkFailure =
          result is Map && result['reason'] == 'network';
      final retryWait =
          interruptedBy ??
          ((hls || _iosTransfer != null) && nativeNetworkFailure
              ? admission.networkWait ?? hlsObservedNetworkWait
              : null);
      if (sourceCurrent() &&
          retryWait != null &&
          (result == 'cancelled' ||
              result is Map && result['status'] == 'cancelled' ||
              nativeNetworkFailure)) {
        _failureReason = retryWait.code;
        return status = VideoDownloadStatus.failed;
      }
      if (result is Map && result['status'] != 'staged') {
        if (hls) {
          failureStage = result['failureStage'] is String
              ? result['failureStage'] as String
              : null;
          failureDomain = result['failureDomain'] is String
              ? result['failureDomain'] as String
              : null;
          failureCode = result['failureCode'] is int
              ? result['failureCode'] as int
              : null;
          underlyingDomain = result['underlyingDomain'] is String
              ? result['underlyingDomain'] as String
              : null;
          underlyingCode = result['underlyingCode'] is int
              ? result['underlyingCode'] as int
              : null;
        }
        if (videoDownloadFailureReasons.contains(result['reason']))
          _failureReason = result['reason'] as String;
        final httpStatus = result['httpStatus'];
        if (httpStatus is int && httpStatus >= 100 && httpStatus <= 599)
          _failureHttpStatus = httpStatus;
        status = VideoDownloadStatus.values.firstWhere(
          (value) =>
              value.name == result['status'] &&
              value != VideoDownloadStatus.saved,
          orElse: () => VideoDownloadStatus.failed,
        );
        if (status == VideoDownloadStatus.failed) {
          failureStage ??= 'nativeBridge';
        }
        return status;
      }
      exceptionStage = 'transferPreparation';
      if (hls) {
        if (result is Map &&
            result['status'] == 'staged' &&
            result['resourceId'] == managedId) {
          hlsCandidate = result;
          if (_cancelRequested || !sourceCurrent()) {
            status = VideoDownloadStatus.cancelled;
          } else {
            final row = await runExclusiveStorageOperation(() async {
              if (_cancelRequested || !sourceCurrent()) return null;
              return VideoHlsAssets.commit(result);
            });
            if (row == null) {
              status = VideoDownloadStatus.cancelled;
            } else {
              hlsCandidate = null;
              storedId = managedId;
              committedDuration = row['durationMs'] as int?;
              committedHlsGeneration = row['generation'] as String;
              latest = (
                received: row['bytes'] as int,
                total: row['bytes'] as int,
                saving: true,
              );
              measuredReceived = row['bytes'] as int;
              measuredPackageBytes = measuredReceived;
              receivedSource = 'package';
              onProgress(latest);
              onMediaProgress?.call(1);
              VideoLocalResources.invalidate();
              status = VideoDownloadStatus.saved;
            }
          }
        } else {
          status = VideoDownloadStatus.values.firstWhere(
            (value) =>
                value.name == result && value != VideoDownloadStatus.saved,
            orElse: () => VideoDownloadStatus.failed,
          );
        }
      } else if (managedId != null) {
        if (result is! Map ||
            result['status'] != 'staged' ||
            result['resourceId'] != managedId ||
            result['bytes'] is! int ||
            result['stageId'] is! String ||
            !RegExp(r'^[a-f0-9]{32}$').hasMatch(result['stageId'] as String)) {
          status = result is String
              ? VideoDownloadStatus.values.firstWhere(
                  (value) =>
                      value.name == result &&
                      value != VideoDownloadStatus.saved,
                  orElse: () => VideoDownloadStatus.failed,
                )
              : VideoDownloadStatus.failed;
        } else {
          stageId = result['stageId'] as String;
          final bytes = result['bytes'] as int;
          if (latest.total != null && latest.total != bytes) {
            throw const FormatException('Incomplete native transfer');
          }
          final committed = await VideoLocalResources.commitStaged(
            stageId: stageId,
            resourceId: managedId,
            bytes: bytes,
            source: source,
            video: video,
            title: title.length > 300 ? title.substring(0, 300) : title,
            quality: quality,
            taskKey: _taskKey!,
            cover: cover,
            durationMs: durationMs,
            sourceDuration: sourceDuration,
            expectedVersion:
                _iosTransfer?.binding['expectedVersion'] as String?,
            cancelled: () =>
                _cancelRequested ||
                !sourceCurrent() ||
                attachment?.scopeIsCurrent == false ||
                (_iosTransfer?.scopeIsCurrent == false),
          );
          if (committed) {
            storedId = managedId;
            status = VideoDownloadStatus.saved;
          } else {
            if (attachment?.scopeIsCurrent == false)
              _failureReason = 'accountChanged';
            status = VideoDownloadStatus.cancelled;
          }
        }
      } else {
        final value = result is Map ? result['status'] : result;
        if (result is Map &&
            result['reason'] is String &&
            const {
              'network',
              'httpForbidden',
              'httpNotFound',
              'loginRequired',
              'mediaRejected',
              'outOfSpace',
              'routeUnavailable',
            }.contains(result['reason']))
          _failureReason = result['reason'] as String;
        status = VideoDownloadStatus.values.firstWhere(
          (status) => status.name == value,
          orElse: () => VideoDownloadStatus.failed,
        );
      }
    } on MissingPluginException {
      status = VideoDownloadStatus.unavailable;
    } on PlatformException catch (error) {
      failureStage ??= exceptionStage;
      _failureReason =
          const {
            'network',
            'httpForbidden',
            'httpNotFound',
            'loginRequired',
            'mediaRejected',
            'outOfSpace',
            'routeUnavailable',
          }.contains(error.code)
          ? error.code
          : 'downloadFailed';
      if (_failureReason == 'network' &&
          sourceCurrent() &&
          interruptedBy != null) {
        _failureReason = interruptedBy!.code;
      }
      // Native error text may contain the signed URL. Never surface or log it.
      status = VideoDownloadStatus.failed;
    } catch (_) {
      failureStage ??= exceptionStage;
      // A task record must exist before starting a tracked native transfer.
      status = VideoDownloadStatus.failed;
    } finally {
      admission.removeListener(networkChanged);
      _failureStage = failureStage;
      // A completed job may still emit a late native callback while terminal
      // metadata is flushing. Retire only this id before publishing its result.
      _progressHandlers.remove(job);
      if (status == VideoDownloadStatus.saved && storedId != null) {
        try {
          final rows = await VideoLocalResources.read();
          final row = rows
              .where((row) => row['resourceId'] == storedId)
              .firstOrNull;
          if (row != null) {
            OmoNetworkContext? coverNetwork;
            if (networkContext != null)
              coverNetwork = OmoNetworkContext.findActiveVisit(
                source,
                networkContext,
              );
            await VideoDownloadedDetails.retainForResource(
              row,
              network: coverNetwork,
            );
          }
        } catch (_) {
          /* Presentation metadata never changes a saved result. */
        }
      }
      try {
        final key = _taskKey;
        if (key != null) {
          final attempt = _taskAttempt;
          final reconnect =
              DownloadNetworkWait.fromCode(_failureReason) != null &&
              !_cancelRequested &&
              attempt != null;
          if (reconnect) VideoExportRecords.retainNetworkWait(key, attempt);
          await VideoExportRecords.updateTransfer(
            key,
            expectedAttempt: _taskAttempt,
            failureReason: _failureReason,
            failureStage: failureStage,
            failureDomain: failureDomain,
            failureCode: failureCode,
            underlyingDomain: underlyingDomain,
            underlyingCode: underlyingCode,
            httpStatus: _failureHttpStatus,
            received: measuredReceived,
            receivedSource: receivedSource,
            packageBytes: measuredPackageBytes,
            networkBytes: measuredNetworkBytes,
            networkTotal: measuredNetworkTotal,
            total: latest.total,
            status: status.name,
            terminal: true,
            resourceId: storedId,
            mediaProgress: hls && status == VideoDownloadStatus.saved
                ? 1
                : mediaProgress,
            durationMs: committedDuration,
            hlsGeneration: committedHlsGeneration,
          );
          if (reconnect) {
            VideoDownloadRetry.resumeAfterNetwork(
              key,
              attempt: attempt,
              source: source,
              accountGeneration: accountGeneration,
            );
          }
          if (status == VideoDownloadStatus.saved && storedId == null) {
            await VideoExportRecords.add(
              source: source,
              video: video,
              title: title,
              quality: quality,
              cover: cover,
            ).catchError((Object _) {});
          }
        }
        if (stageId != null) {
          await VideoLocalResources.discardStage(
            stageId,
          ).catchError((Object _) {});
        }
        if (hlsCandidate != null) {
          await VideoHlsAssets.discard(hlsCandidate).catchError((Object _) {});
        }
        final iosTransfer = _iosTransfer;
        if (iosTransfer != null &&
            await VideoExportRecords.confirmMp4Terminal(
              iosTransfer.binding,
              status.name,
            )) {
          await iosTransfer.acknowledge().catchError((Object _) {});
        }
        if (hlsReceipt != null && key != null) {
          // Replay through the same durable writer before native drops its receipt.
          if (await VideoExportRecords.confirmHlsTerminal(
            key,
            _taskAttempt,
            status.name,
            committedHlsGeneration,
          )) {
            await VideoHlsRecovery.acknowledge(hlsReceipt);
          }
        }
      } finally {
        await accountSubscription.cancel();
        await routeSubscription.cancel();
        await pluginSubscription.cancel();
        if (managedId != null) VideoLocalResources.release(managedId);
        _taskKey = null;
        _taskAttempt = null;
        _androidTransferKey = null;
        _androidScope = null;
        final iosTransfer = _iosTransfer;
        _iosTransfer = null;
        _job = null;
        _active.remove(this);
        _permit = null;
        notifyConcurrencyChanged();
        _source = null;
        _progressHandlers.remove(job);
        _transferChannel = null;
        _settled?.complete();
        _settled = null;
        if (iosTransfer != null) {
          IosManagedVideoRecovery.live.remove(iosTransfer.binding['batchId']);
          unawaited(IosManagedVideoRecovery.refresh());
        }
        if (hlsReceipt != null) {
          await VideoHlsRecovery.releaseLiveReceipt(hlsReceipt);
        }
      }
    }
    return status;
  }

  static Future<VideoDownloadStatus> exportLocal(
    String id,
    String title, {
    String? expectedResourceVersion,
  }) => CacheWorkspaceGuard.withWorkspace(
    () => _exportLocal(id, title, expectedResourceVersion),
  );

  static Future<VideoDownloadStatus> _exportLocal(
    String id,
    String title,
    String? expectedResourceVersion,
  ) async {
    if (!VideoLocalResources.validId(id)) return VideoDownloadStatus.failed;
    // iOS uses a separate native worker for exports and managed transfers.
    if ((defaultTargetPlatform != TargetPlatform.iOS && _active.isNotEmpty) ||
        !VideoLocalResources.tryHold(id)) {
      return VideoDownloadStatus.busy;
    }
    try {
      if (expectedResourceVersion == null) {
        if ((await VideoHlsAssets.read()).any(
          (row) => row['resourceId'] == id,
        )) {
          return VideoDownloadStatus.unsupported;
        }
        final media = await VideoLocalResources.file(id);
        if (!await media.exists()) return VideoDownloadStatus.failed;
      } else {
        // Recheck while holding the same identity lock as a replacement writer.
        final current = await VideoLocalResources.readPlaybackResource(id);
        if (current.row['format'] == 'hls') {
          return VideoDownloadStatus.unsupported;
        }
        if (VideoLocalResources.resourceVersion(current.row) !=
            expectedResourceVersion) {
          return VideoDownloadStatus.failed;
        }
      }
      final result = await _channel.invokeMethod<String>('export', {
        'resourceId': id,
        'title': title,
      });
      return VideoDownloadStatus.values.firstWhere(
        (value) => value.name == result,
        orElse: () => VideoDownloadStatus.failed,
      );
    } on MissingPluginException {
      return VideoDownloadStatus.unavailable;
    } catch (_) {
      return VideoDownloadStatus.failed;
    } finally {
      VideoLocalResources.release(id);
    }
  }

  Future<void> cancel() async {
    _cancelRequested = true;
    final job = _job;
    final queued = _queuedCancellation;
    if (queued != null && !queued.isCompleted) queued.complete();
    if (job == null || !_active.contains(this)) return;
    try {
      if (_iosTransfer case final transfer?) {
        await transfer.cancel();
        return;
      }
      await (_transferChannel ?? _channel).invokeMethod<void>('cancel', {
        'id': job,
        'transferKey': ?_androidTransferKey,
        'scope': ?_androidScope,
      });
    } on MissingPluginException {
      // The pending start invocation supplies the resulting unavailable status.
    } on PlatformException {
      // Remain pending until the native task resolves; do not report success.
    }
  }
}
