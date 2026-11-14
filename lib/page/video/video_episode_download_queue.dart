import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'dart:async';

import 'package:zephyr/network/source_network_policy.dart';
import 'package:zephyr/network/sync/sync_service.dart'
    show runExclusiveStorageOperation;
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_download.dart';
import 'package:zephyr/page/video/video_download_resolution.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_playback_download_adapter.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';

typedef VideoResolvedEpisodeDownload = ({
  NativePlaybackSession session,
  String? sourceDuration,
});

/// Process-owned bounded work. Durable rows contain public episodes only; after
/// restart their existing task reader marks them interrupted, never resumable.
abstract final class VideoEpisodeDownloadQueue {
  static Future<void> _tail = Future.value();
  static final _resolutionTails = <String, Future<void>>{};

  /// One site's browser/runtime may navigate only one parsing document at a
  /// time. This gate ends at resolution, never at native transfer completion.
  static Future<T> resolveSource<T>(
    String source,
    Future<T> Function() work, {
    VideoDownloadResolutionOwner? owner,
  }) async {
    final previous = _resolutionTails[source];
    final done = Completer<void>();
    _resolutionTails[source] = done.future;
    try {
      if (previous != null) await previous;
      owner?.check();
      final raw = owner == null ? work() : owner.run(work);
      // A timeout asks the owned transport to stop; it does not unlock a shared
      // browser while an unknown, uncancellable callback is still running.
      var timedOut = false;
      final timer = Timer(const Duration(seconds: 120), () {
        timedOut = true;
        if (owner != null) unawaited(owner.stop().catchError((Object _) {}));
      });
      try {
        return await Future.any<T>([
          raw,
          if (owner != null)
            owner.stopped.then<T>((_) {
              if (timedOut)
                throw TimeoutException('Video resolution timed out');
              throw const VideoResolutionCancelled();
            }),
        ]);
      } finally {
        timer.cancel();
      }
    } finally {
      if (identical(_resolutionTails[source], done.future))
        _resolutionTails.remove(source);
      owner?.close();
      done.complete();
    }
  }

  static Future<List<String>> enqueue({
    required String source,
    required List<NativeVideoCard> episodes,
    required Future<VideoResolvedEpisodeDownload> Function(NativeVideoCard)
    resolve,
    String? networkContext,
    Future<void> Function()? release,
    String? retryItemId,
    String? preferredQuality,
    String? preferredFormat,
    bool cooperativeResolution = false,
    bool userInitiated = false,
  }) async {
    final unique = <Uri, NativeVideoCard>{};
    for (final episode in episodes) {
      final page = videoPlaybackIdentity(episode.watchUrl);
      if (page == null || page != episode.watchUrl) {
        throw const FormatException('Invalid public download episode');
      }
      unique.putIfAbsent(page, () => episode);
    }
    if (unique.isEmpty || source.isEmpty || source.length > 200) {
      throw const FormatException('No download episodes');
    }
    final installation = SourceNetworkPolicies.supports(source)
        ? LocalPluginInstallationState.instance
        : null;
    await installation?.load();
    final batch = _EpisodeDownloadBatch(
      source,
      unique.values.toList(),
      resolve,
      networkContext,
      installation,
      installation?.installationEpoch(source),
      release,
      cooperativeResolution,
      preferredQuality,
      preferredFormat,
    );
    if (!batch.current) throw const PluginLifecycleChanged();
    try {
      await runExclusiveStorageOperation(() async {
        for (final episode in batch.episodes) {
          if (!batch.current) throw const PluginLifecycleChanged();
          final existing = VideoExportRecords.sessionTaskSnapshot()
              .where(
                (row) =>
                    VideoExportRecords.isLive('${row['key']}') &&
                    row['source'] == source &&
                    row['url'] == episode.watchUrl.toString() &&
                    (retryItemId == null ||
                        row['retryItemId'] == retryItemId) &&
                    (preferredQuality == null ||
                        (row['quality'] == preferredQuality &&
                            (preferredFormat == null ||
                                (row['format'] ?? 'mp4') == preferredFormat))),
              )
              .firstOrNull;
          if (existing != null) {
            batch.resultKeys.add(existing['key'] as String);
            continue;
          }
          final key = await VideoExportRecords.beginTransfer(
            source: source,
            video: episode.watchUrl,
            title: episode.episodeLabel.isEmpty
                ? episode.title
                : '${episode.title} · ${episode.episodeLabel}',
            quality: preferredQuality ?? '',
            format: preferredFormat ?? 'mp4',
            cover: episode.coverUrl?.toString(),
            queued: true,
            reuseTerminal: true,
            retryItemId: retryItemId,
          );
          batch.keys.add(key);
          batch.resultKeys.add(key);
          batch.queuedEpisodes.add(episode);
          batch.attempts[key] = VideoExportRecords.currentAttempt(key)!;
          if (!batch.current) {
            await VideoExportRecords.updateTransfer(
              key,
              expectedAttempt: batch.attempts[key],
              received: null,
              status: 'cancelled',
              terminal: true,
            );
            throw const PluginLifecycleChanged();
          }
          VideoSystemDownload.registerQueuedTask(
            key,
            source,
            () => batch.cancelTask(key),
            attempt: batch.attempts[key],
          );
        }
      });
    } catch (_) {
      await batch.cancel();
      for (final key in batch.keys) {
        VideoSystemDownload.unregisterQueuedTask(
          key,
          attempt: batch.attempts[key],
        );
      }
      rethrow;
    }
    if (batch.keys.isEmpty) {
      await batch.releaseOwner();
    } else {
      schedule(batch.run);
    }
    return List.unmodifiable(batch.resultKeys);
  }

  static void schedule(Future<void> Function() work) {
    final next = Future<void>.sync(work);
    _tail = Future.wait<void>([
      _tail,
      next,
    ]).then<void>((_) {}, onError: (Object _, StackTrace _) {});
  }

  static Future<void> flush() => _tail;
}

class _EpisodeDownloadCancelled implements Exception {
  const _EpisodeDownloadCancelled();
}

class _EpisodeDownloadBatch {
  _EpisodeDownloadBatch(
    this.source,
    this.episodes,
    this.resolve,
    this.networkContext,
    this.installation,
    this.epoch,
    this.release,
    this.cooperativeResolution,
    this.preferredQuality,
    this.preferredFormat,
  );
  final String source;
  final List<NativeVideoCard> episodes;
  final Future<VideoResolvedEpisodeDownload> Function(NativeVideoCard) resolve;
  final String? networkContext;
  final LocalPluginInstallationState? installation;
  final int? epoch;
  final Future<void> Function()? release;
  final bool cooperativeResolution;
  final String? preferredQuality, preferredFormat;
  final keys = <String>[];
  final resultKeys = <String>[];
  final queuedEpisodes = <NativeVideoCard>[];
  final _cancelledKeys = <String, Completer<void>>{};
  final attempts = <String, int>{};
  late final int accountGeneration = pluginSessionWriteFence.generation(source);
  final _cancelled = Completer<void>();
  final _engines = <String, VideoSystemDownload>{};
  final _resolutionOwners = <String, VideoDownloadResolutionOwner>{};
  bool _running = false;
  Future<void>? _releaseFuture;
  Future<void> releaseOwner() => _releaseFuture ??= () async {
    await release?.call();
  }();
  bool get current =>
      !_cancelled.isCompleted &&
      !pluginSessionWriteFence.isChanging(source) &&
      pluginSessionWriteFence.generation(source) == accountGeneration &&
      (installation == null ||
          (!installation!.isRemoved(source) &&
              !installation!.isInstalling(source) &&
              installation!.installationEpoch(source) == epoch));

  Future<void> cancelTask(String key) async {
    final signal = _cancelledKeys.putIfAbsent(key, () => Completer<void>());
    if (signal.isCompleted) return;
    signal.complete();
    try {
      await _resolutionOwners[key]?.stop();
    } catch (_) {
      /* Do not unlock an unconfirmed stop. */
    }
    final engine = _engines[key];
    if (engine != null) {
      await engine.cancel();
    } else {
      await VideoExportRecords.updateTransfer(
        key,
        expectedAttempt: attempts[key],
        received: null,
        status: 'cancelled',
        terminal: true,
      );
    }
  }

  Future<void> cancel() async {
    if (_cancelled.isCompleted) return;
    _cancelled.complete();
    await Future.wait([for (final key in keys.toList()) cancelTask(key)]);
    if (!_running) await releaseOwner();
  }

  Future<void> run() async {
    _running = true;
    final subscription = pluginSessionWriteFence.changes.listen((boundary) {
      if (boundary.source == source && !current) unawaited(cancel());
    });
    try {
      await Future.wait([
        for (var index = 0; index < keys.length; index++) _runEpisode(index),
      ]);
    } finally {
      await subscription.cancel();
      for (final key in keys) {
        VideoSystemDownload.unregisterQueuedTask(key, attempt: attempts[key]);
      }
      await releaseOwner();
    }
  }

  Future<void> _runEpisode(int index) async {
    final key = keys[index], episode = queuedEpisodes[index];
    final cancelled = _cancelledKeys.putIfAbsent(key, () => Completer<void>());
    bool episodeCurrent() =>
        current &&
        !cancelled.isCompleted &&
        VideoExportRecords.isAttemptCurrent(key, attempts[key]!);
    Future<T> wait<T>(Future<T> work) => Future.any<T>([
      work,
      _cancelled.future.then<T>((_) => throw const _EpisodeDownloadCancelled()),
      cancelled.future.then<T>((_) => throw const _EpisodeDownloadCancelled()),
    ]);
    var status = VideoDownloadStatus.failed;
    var resolving = false;
    String? failureStage;
    String? failureReason;
    VideoDownloadPermit? permit;
    try {
      if (!episodeCurrent()) throw const _EpisodeDownloadCancelled();
      permit = await VideoSystemDownload.reserveDownload(
        key: key,
        attempt: attempts[key]!,
        cancelled: Future.any<void>([_cancelled.future, cancelled.future]),
        current: episodeCurrent,
      );
      if (permit == null) throw const _EpisodeDownloadCancelled();
      if (!episodeCurrent()) throw const _EpisodeDownloadCancelled();
      // Resolve only when this episode reaches the engine, using the
      // retained source visit rather than a disposed detail-page callback.
      final owner = _resolutionOwners[key] = VideoDownloadResolutionOwner(
        source,
        cooperative: cooperativeResolution,
      );
      resolving = true;
      final resolved = await wait(
        VideoEpisodeDownloadQueue.resolveSource(source, () {
          if (!episodeCurrent()) throw const _EpisodeDownloadCancelled();
          return resolve(episode);
        }, owner: owner),
      );
      resolving = false;
      if (!episodeCurrent()) throw const _EpisodeDownloadCancelled();
      if (videoPlaybackIdentity(resolved.session.watchUrl) !=
          episode.watchUrl) {
        throw const FormatException('Resolved a different episode');
      }
      final adapter = VideoPlaybackDownloadAdapter(resolved.session);
      if (adapter.choices.isEmpty) {
        status = VideoDownloadStatus.unsupported;
      } else {
        final choice = preferredQuality == null
            ? adapter.choices.first
            : adapter.choices
                  .where(
                    (choice) =>
                        choice.label == preferredQuality &&
                        (preferredFormat == null ||
                            (choice.url.path.toLowerCase().endsWith('.m3u8')
                                    ? 'hls'
                                    : 'mp4') ==
                                preferredFormat),
                  )
                  .firstOrNull;
        if (choice == null) {
          await VideoExportRecords.updateTransfer(
            key,
            expectedAttempt: attempts[key],
            received: null,
            status: 'failed',
            failureReason: 'qualityUnavailable',
          );
          return;
        }
        while (episodeCurrent()) {
          if (!episodeCurrent()) throw const _EpisodeDownloadCancelled();
          final engine = _engines[key] = VideoSystemDownload();
          status = await engine.save(
            choice: choice,
            source: source,
            video: episode.watchUrl,
            title: episode.episodeLabel.isEmpty
                ? episode.title
                : '${episode.title} · ${episode.episodeLabel}',
            cover: episode.coverUrl?.toString(),
            sourceDuration: resolved.sourceDuration,
            queuedTaskKey: key,
            permit: permit,
            networkContext: networkContext,
            headers: adapter.headersForChoice(choice),
            onProgress: (_) {},
          );
          failureReason = engine.failureReason;
          failureStage = engine.failureStage;
          _engines.remove(key);
          if (status != VideoDownloadStatus.busy ||
              !VideoSystemDownload.hasActiveTransfer)
            break;
          await wait(VideoSystemDownload.waitForIdle());
        }
        if (!current && status != VideoDownloadStatus.saved) {
          status = VideoDownloadStatus.cancelled;
        }
      }
    } on VideoResolutionCancelled {
      status = VideoDownloadStatus.cancelled;
    } on _EpisodeDownloadCancelled {
      status = VideoDownloadStatus.cancelled;
    } on VideoDownloadResolutionFailure catch (error) {
      status = VideoDownloadStatus.failed;
      failureReason = error.reason;
      failureStage = 'resolution';
    } catch (_) {
      if (resolving && episodeCurrent()) failureStage = 'resolution';
      // Keep a safe terminal state, never raw parser errors/signed URLs.
      status = episodeCurrent()
          ? VideoDownloadStatus.failed
          : VideoDownloadStatus.cancelled;
    } finally {
      _engines.remove(key);
      _resolutionOwners.remove(key);
      await VideoExportRecords.updateTransfer(
        key,
        expectedAttempt: attempts[key],
        received: null,
        status: status.name,
        failureReason: failureReason,
        failureStage: failureStage,
        terminal: true,
      );
      VideoSystemDownload.unregisterQueuedTask(key, attempt: attempts[key]);
      permit?.release();
    }
    if (!current) await cancel();
  }
}
