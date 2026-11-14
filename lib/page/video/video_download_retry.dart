import 'package:zephyr/page/video/video_download_continuation.dart';
import 'dart:async';
import 'package:zephyr/page/video/android_managed_video_attempt.dart';
import 'package:zephyr/network/source_network_policy.dart';
import 'package:zephyr/network/sync/sync_service.dart'
    show runExclusiveStorageOperation;
import 'package:zephyr/page/video/video_download.dart';
import 'package:zephyr/page/video/video_download_resolution.dart';
import 'package:zephyr/page/video/video_download_choice.dart';
import 'package:zephyr/page/video/video_hls_assets.dart';
import 'package:zephyr/page/video/video_episode_download_queue.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/service/download/download_admission.dart';
import 'package:zephyr/main.dart' show navigatorKey;
import 'package:zephyr/page/video/video_download_retry_host.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';

class VideoDownloadRetryFailure implements Exception {
  const VideoDownloadRetryFailure(this.reason);
  final String reason;
}

class VideoDownloadRetryResolution {
  VideoDownloadRetryResolution({
    required this.choices,
    this.networkContext,
    this.headersForChoice,
    Future<void> Function()? release,
  }) : _release = release;
  final List<VideoDownloadChoice> choices;
  final String? networkContext;
  final Map<String, String> Function(VideoDownloadChoice)? headersForChoice;
  final Future<void> Function()? _release;
  Future<void>? _released;
  Future<void> close() => _released ??= Future.sync(() async {
    await _release?.call();
  });
}

typedef VideoDownloadRetryResolver =
    Future<VideoDownloadRetryResolution> Function(
      Map<String, dynamic> publicTask,
    );

class _Resolver {
  _Resolver(
    this.resolve,
    this.current,
    this.accepts,
    this.cancel,
    this.cooperative,
  );
  final VideoDownloadRetryResolver resolve;
  final bool Function() current;
  final bool Function(Map<String, dynamic>)? accepts;
  final Future<void> Function(Map<String, dynamic>)? cancel;
  final bool cooperative;
}

/// Public identities live in task rows; signed addresses and authenticated
/// browser/transport owners live only in the active registered resolver.
abstract final class VideoDownloadRetry {
  static final _resolvers = <String, List<_Resolver>>{};
  static final _work = <String, _RetryWork>{};
  static bool isPending(String key) =>
      _work.containsKey(key) || VideoExportRecords.isLive(key);
  static bool _terminal(Map<String, dynamic> row) => const {
    'failed',
    'cancelled',
    'interrupted',
    'routeUnavailable',
    'unavailable',
    'unsupported',
    'busy',
  }.contains(row['status']);

  /// Recovery needs an exact public episode and a real selected quality.
  /// Unresolved batch intents and incomplete legacy rows remain viewable, but
  /// must return to their work rather than exposing a nonfunctional retry.
  static bool canRecover(Map<String, dynamic> row) {
    final source = row['source'], url = row['url'], quality = row['quality'];
    if (source is! String ||
        source.isEmpty ||
        source.length > 200 ||
        row['key'] is! String ||
        url is! String ||
        quality is! String ||
        quality.trim().isEmpty ||
        quality.length > 80)
      return false;
    final page = Uri.tryParse(url);
    if (page == null || videoPlaybackIdentity(page)?.toString() != url)
      return false;
    return row['format'] == null ||
        const {'hls', 'mp4'}.contains(row['format']);
  }

  static bool canRetry(Map<String, dynamic> row) =>
      _terminal(row) && canRecover(row);
  static bool isWaitingForNetwork(Map<String, dynamic> row) =>
      row['status'] == 'failed' &&
      DownloadNetworkWait.fromCode(row['failureReason']) != null;
  static bool needsSource(Map<String, dynamic> row) =>
      _terminal(row) &&
      (!canRecover(row) ||
          const {
            'sourceVisitRequired',
            'missingIdentity',
            'qualityUnavailable',
          }.contains(row['failureReason']));
  static Object register(
    String source,
    VideoDownloadRetryResolver resolve, {
    required bool Function() current,
    bool Function(Map<String, dynamic>)? accepts,
    Future<void> Function(Map<String, dynamic>)? cancel,
    bool cooperativeCancellation = false,
  }) {
    final resolver = _Resolver(
      resolve,
      current,
      accepts,
      cancel,
      cooperativeCancellation,
    );
    (_resolvers[source] ??= []).add(resolver);
    return resolver;
  }

  static void unregister(String source, Object lease) =>
      _resolvers[source]?.remove(lease);
  static _Resolver? _resolver(String source, Map<String, dynamic> row) =>
      _resolvers[source]?.reversed
          .where((r) => r.current() && (r.accepts?.call(row) ?? true))
          .firstOrNull;

  static void resumeAfterNetwork(
    String key, {
    required int attempt,
    required String source,
    required int accountGeneration,
  }) {
    unawaited(_resumeAfterNetwork(key, attempt, source, accountGeneration));
  }

  static Future<void> _resumeAfterNetwork(
    String key,
    int attempt,
    String source,
    int accountGeneration,
  ) async {
    final cancelled = Completer<void>();
    final installation = SourceNetworkPolicies.supports(source)
        ? LocalPluginInstallationState.instance
        : null;
    final installationEpoch = installation?.installationEpoch(source);
    void installationChanged() {
      if (installation != null &&
          !cancelled.isCompleted &&
          (installation.isRemoved(source) ||
              installation.isInstalling(source) ||
              installation.installationEpoch(source) != installationEpoch)) {
        cancelled.complete();
      }
    }

    installation?.changes.addListener(installationChanged);
    installationChanged();
    final boundaries = pluginSessionWriteFence.changes.listen((event) {
      if (event.source == source &&
          (event.changing || event.generation != accountGeneration) &&
          !cancelled.isCompleted)
        cancelled.complete();
    });
    final admission = DownloadAdmission.instance;
    try {
      if (!await admission.waitForNetwork(cancelled.future)) return;
      // The native writer, route lease and queue registration must settle first.
      await VideoSystemDownload.waitForQueuedTaskToSettle(key, attempt);
      final row = (await VideoExportRecords.readTaskSnapshot())
          .where(
            (row) =>
                row['key'] == key &&
                row['attempt'] == attempt &&
                DownloadNetworkWait.fromCode(row['failureReason']) != null,
          )
          .firstOrNull;
      if (row == null ||
          !canRetry(row) ||
          cancelled.isCompleted ||
          pluginSessionWriteFence.generation(source) != accountGeneration ||
          pluginSessionWriteFence.isChanging(source))
        return;
      final plugin = SourceNetworkPolicies.supports(source)
          ? PluginRegistryService.I.getByUuid(source)
          : null;
      if (SourceNetworkPolicies.supports(source) &&
          (plugin == null || plugin.isDeleted || !plugin.isActive))
        return;
      final overlay = navigatorKey.currentState?.overlay;
      if (_resolver(source, row) == null && (overlay == null || plugin == null))
        return;
      final owner = Object();
      await retry(
        row,
        fallback: overlay == null
            ? null
            : (task) =>
                  VideoDownloadRetryHosts.resolve(overlay, task, owner: owner),
        cancelResolution: () => VideoDownloadRetryHosts.cancel(source, owner),
        expectedAccountGeneration: accountGeneration,
      );
    } catch (_) {
      // An older, removed, or unsupported intent stays available for manual retry.
    } finally {
      installation?.changes.removeListener(installationChanged);
      await boundaries.cancel();
      VideoExportRecords.releaseNetworkWait(key, attempt);
    }
  }

  /// Returns after one atomic queued attempt, not after a transfer. A failed
  /// resolution remains in this same row with a finite, safe failure category.
  static Future<bool> retry(
    Map<String, dynamic> row, {
    VideoDownloadRetryResolver? fallback,
    Future<void> Function()? cancelResolution,
    int? expectedAccountGeneration,
    bool userInitiated = false,
  }) async {
    if (!canRetry(row)) return false;
    final key = row['key'] as String;
    if (_work.containsKey(key) || VideoExportRecords.isLive(key)) return false;
    final source = row['source'], raw = row['url'], quality = row['quality'];
    if (source is! String ||
        source.isEmpty ||
        raw is! String ||
        videoPlaybackIdentity(Uri.tryParse(raw) ?? Uri()) == null ||
        quality is! String ||
        quality.isEmpty)
      return false;
    final work = _RetryWork(
      Map<String, dynamic>.from(row),
      fallback,
      cancelResolution,
    );
    _work[key] = work;
    try {
      await work.prepare(expectedAccountGeneration: expectedAccountGeneration);
      if (userInitiated) {
        VideoSystemDownload.beginContinuedAttempts([
          (key: key, attempt: work.attempt),
        ]);
      }
      VideoEpisodeDownloadQueue.schedule(work.run);
      return true;
    } catch (_) {
      if (identical(_work[key], work)) _work.remove(key);
      work.installation?.changes.removeListener(work.installationChanged);
      rethrow;
    }
  }
}

class _RetryCancelled implements Exception {
  const _RetryCancelled();
}

class _RetryWork {
  _RetryWork(this.original, this.fallback, this.cancelResolution);
  final Future<void> Function()? cancelResolution;
  bool usingFallback = false;
  Future<void>? _fallbackStop;
  Future<void> _closeFallback() => _fallbackStop ??= Future.sync(() async {
    await cancelResolution?.call();
  });
  final VideoDownloadRetryResolver? fallback;
  final Map<String, dynamic> original;
  String get key => original['key'] as String;
  String get source => original['source'] as String;
  final cancelled = Completer<void>();
  late int attempt, accountGeneration;
  LocalPluginInstallationState? installation;
  int? installationEpoch;
  VideoSystemDownload? engine;
  AndroidManagedVideoAttempt? attachment;
  VideoDownloadRetryResolution? resolution;
  VideoDownloadPermit? permit;
  VideoDownloadResolutionOwner? resolutionOwner;
  StreamSubscription<PluginSessionBoundary>? subscription;

  bool get current =>
      !cancelled.isCompleted &&
      !pluginSessionWriteFence.isChanging(source) &&
      pluginSessionWriteFence.generation(source) == accountGeneration &&
      VideoExportRecords.isAttemptCurrent(key, attempt) &&
      (installation == null ||
          !installation!.isRemoved(source) &&
              !installation!.isInstalling(source) &&
              installation!.installationEpoch(source) == installationEpoch);
  Future<T> wait<T>(Future<T> future) => Future.any([
    future,
    cancelled.future.then<T>((_) => throw const _RetryCancelled()),
  ]);
  Future<void> prepare({int? expectedAccountGeneration}) async {
    accountGeneration = pluginSessionWriteFence.generation(source);
    installation = SourceNetworkPolicies.supports(source)
        ? LocalPluginInstallationState.instance
        : null;
    await installation?.load();
    installationEpoch = installation?.installationEpoch(source);
    final candidate = AndroidManagedVideoAttempt.interrupted(original);
    final nativeStatus = await candidate?.status();
    if (nativeStatus == 'busy') {
      throw const VideoDownloadRetryFailure('unavailable');
    }
    if (nativeStatus == 'active' || nativeStatus == 'settled')
      attachment = candidate;

    final reset = await runExclusiveStorageOperation(() {
      final expectedGeneration =
          expectedAccountGeneration ??
          (attachment != null ? accountGeneration : null);
      if (expectedGeneration != null &&
          (pluginSessionWriteFence.isChanging(source) ||
              pluginSessionWriteFence.generation(source) !=
                  expectedGeneration)) {
        return Future<Map<String, dynamic>?>.value();
      }
      return VideoExportRecords.restartTransfer(
        original,
        reattach: attachment != null,
      );
    });
    if (reset == null) throw const VideoDownloadRetryFailure('missingIdentity');
    attempt = reset['attempt'] as int;
    installation?.changes.addListener(installationChanged);
    VideoSystemDownload.registerQueuedTask(
      key,
      source,
      cancel,
      attempt: attempt,
    );
    subscription = pluginSessionWriteFence.changes.listen((event) {
      if (event.source == source &&
          (event.changing || event.generation != accountGeneration))
        unawaited(cancel(reason: 'accountChanged'));
    });
  }

  void installationChanged() {
    if (installation != null &&
        (installation!.isRemoved(source) ||
            installation!.isInstalling(source) ||
            installation!.installationEpoch(source) != installationEpoch))
      unawaited(cancel(reason: 'sourceRemoved'));
  }

  Future<void> cancel({String? reason}) async {
    if (cancelled.isCompleted) return;
    cancelled.complete();
    final activeEngine = engine;
    final stopEngine = activeEngine?.cancel();
    if (activeEngine?.taskKey == null) await attachment?.cancel();
    try {
      await resolutionOwner?.stop();
    } catch (_) {
      /* The source gate stays held until actual completion. */
    }
    if (activeEngine != null) {
      // Native cancellation is a request. The engine still owns the result
      // and may already have committed the resource.
      try {
        await stopEngine;
      } catch (_) {}
      return;
    }
    if (usingFallback) {
      try {
        await _closeFallback();
      } catch (_) {}
    }
    await VideoExportRecords.updateTransfer(
      key,
      received: null,
      status: 'cancelled',
      terminal: true,
      expectedAttempt: attempt,
      failureReason: reason,
    );
    VideoSystemDownload.unregisterQueuedTask(key, attempt: attempt);
    if (identical(VideoDownloadRetry._work[key], this))
      VideoDownloadRetry._work.remove(key);
    await subscription?.cancel();
    installation?.changes.removeListener(installationChanged);
  }

  Future<void> run() async {
    var status = VideoDownloadStatus.failed;
    String? reason;
    String? failureStage;
    var stage = 'resolution';
    try {
      if (installation?.isRemoved(source) == true ||
          installation?.isInstalling(source) == true)
        throw const VideoDownloadRetryFailure('sourceRemoved');
      if (pluginSessionWriteFence.generation(source) != accountGeneration ||
          pluginSessionWriteFence.isChanging(source))
        throw const VideoDownloadRetryFailure('accountChanged');
      if (!current) throw const _RetryCancelled();
      permit = await VideoSystemDownload.reserveDownload(
        key: key,
        attempt: attempt,
        cancelled: cancelled.future,
        current: () => current,
      );
      if (permit == null) throw const _RetryCancelled();
      if (!current) throw const _RetryCancelled();
      if (installation?.isRemoved(source) == true)
        throw const VideoDownloadRetryFailure('sourceRemoved');
      if (attachment case final native?) {
        stage = 'retryTransfer';
        final transfer = engine = VideoSystemDownload();
        status = await transfer.reattachAndroidManaged(
          native,
          original,
          permit: permit!,
        );
        reason = status == VideoDownloadStatus.routeUnavailable
            ? 'routeUnavailable'
            : transfer.failureReason;
        failureStage = transfer.failureStage;
        return;
      }
      final resolver = VideoDownloadRetry._resolver(source, original);
      usingFallback = resolver == null;
      final resolve = resolver?.resolve ?? fallback;
      if (resolve == null)
        throw const VideoDownloadRetryFailure('sourceVisitRequired');
      final owner = resolutionOwner = VideoDownloadResolutionOwner(
        source,
        cooperative: resolver?.cooperative == true,
      );
      if (resolver?.cancel != null)
        owner.onCancel(
          () => resolver!.cancel!({...original, 'attempt': attempt}),
        );
      if (usingFallback && cancelResolution != null)
        owner.onCancel(_closeFallback);
      final pending = VideoEpisodeDownloadQueue.resolveSource(source, () {
        if (!current) throw const _RetryCancelled();
        final raw = resolve(
          Map<String, dynamic>.unmodifiable({...original, 'attempt': attempt}),
        );
        unawaited(
          raw.then<void>((value) async {
            if (!current) await value.close();
          }, onError: (Object _, StackTrace _) {}),
        );
        return raw;
      }, owner: owner);
      // Even cancellation before a late resolver completes releases its lease.
      unawaited(
        pending.then<void>((value) async {
          if (!current) await value.close();
        }, onError: (Object _, StackTrace _) {}),
      );
      resolution = await wait(pending);
      if (!current) throw const _RetryCancelled();
      final originalPage = Uri.parse(original['url'] as String);
      // Older HLS rows can lack format, but their exact resource hash still
      // proves HLS. Never substitute another quality or infer from a title.
      final expectedFormat =
          original['format'] == 'hls' ||
              original['resourceId'] ==
                  VideoHlsAssets.identity(
                    source,
                    originalPage,
                    original['quality'] as String,
                  )
          ? 'hls'
          : 'mp4';
      final choice = resolution!.choices
          .where(
            (choice) =>
                choice.label == original['quality'] &&
                (choice.url.path.toLowerCase().endsWith('.m3u8')
                        ? 'hls'
                        : 'mp4') ==
                    expectedFormat,
          )
          .firstOrNull;
      if (choice == null) {
        if (resolution!.choices.any(
          (value) => value.label == original['quality'],
        ))
          throw const VideoDownloadRetryFailure('unsupported');
        throw const VideoDownloadRetryFailure('qualityUnavailable');
      }
      do {
        if (!current) throw const _RetryCancelled();
        stage = 'retryTransfer';
        final transfer = engine = VideoSystemDownload();
        status = await transfer.save(
          choice: choice,
          source: source,
          video: Uri.parse(original['url'] as String),
          title: original['title'] is String ? original['title'] as String : '',
          cover: original['cover'] is String
              ? original['cover'] as String
              : null,
          durationMs: original['durationMs'] is int
              ? original['durationMs'] as int
              : null,
          sourceDuration: original['sourceDuration'] is String
              ? original['sourceDuration'] as String
              : null,
          queuedTaskKey: key,
          permit: permit,
          networkContext: resolution!.networkContext,
          headers: resolution!.headersForChoice?.call(choice) ?? const {},
          onProgress: (_) {},
        );
        reason = transfer.failureReason;
        failureStage = transfer.failureStage;
        if (status == VideoDownloadStatus.busy &&
            VideoSystemDownload.hasActiveTransfer)
          await wait(VideoSystemDownload.waitForIdle());
      } while (status == VideoDownloadStatus.busy &&
          VideoSystemDownload.hasActiveTransfer &&
          current);
      if (status == VideoDownloadStatus.routeUnavailable)
        reason = 'routeUnavailable';
      if (status == VideoDownloadStatus.unsupported) reason = 'unsupported';
    } on VideoDownloadRetryFailure catch (error) {
      reason = error.reason;
    } on VideoResolutionCancelled {
      status = VideoDownloadStatus.cancelled;
    } on _RetryCancelled {
      status = VideoDownloadStatus.cancelled;
    } on TimeoutException {
      reason = 'timeout';
      if (usingFallback) {
        try {
          await _closeFallback();
        } catch (_) {}
      }
    } catch (_) {
      reason = 'downloadFailed';
      failureStage = stage;
    } finally {
      if (!cancelled.isCompleted &&
          status != VideoDownloadStatus.saved &&
          status != VideoDownloadStatus.busy) {
        await attachment?.cancel();
      }
      try {
        await resolution?.close();
      } catch (_) {}
      permit?.release();
      await subscription?.cancel();
      installation?.changes.removeListener(installationChanged);
      await VideoExportRecords.updateTransfer(
        key,
        received: null,
        status: status.name,
        terminal: true,
        expectedAttempt: attempt,
        failureReason: reason,
        failureStage: failureStage,
      );
      VideoSystemDownload.unregisterQueuedTask(key, attempt: attempt);
      VideoDownloadContinuation.finish((
        key: key,
        attempt: attempt,
      ), saved: status == VideoDownloadStatus.saved);
      if (identical(VideoDownloadRetry._work[key], this))
        VideoDownloadRetry._work.remove(key);
    }
  }
}
