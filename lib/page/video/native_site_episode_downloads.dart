import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/omo_network.dart';
import 'package:zephyr/page/video/video_download_choice.dart';
import 'package:zephyr/page/video/video_download_resolution.dart';
import 'package:zephyr/page/video/video_download_retry.dart';
import 'package:zephyr/page/video/video_download_retry_host.dart';
import 'package:zephyr/page/video/video_episode_download_queue.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/page/video/video_site_action_models.dart';
import 'package:zephyr/page/video/video_site_browser.dart';
import 'package:zephyr/page/video/video_site_operations.dart';

/// Only a source-declared sequence containing the current video is eligible.
List<NativeVideoCard> nativeSiteDownloadEntries(NativePlaybackSession session) {
  final current = videoPlaybackIdentity(session.watchUrl);
  if (current == null) return const [];
  final entries = <Uri, NativeVideoCard>{};
  for (final card in session.playbackEntries) {
    final watch = card.watchUrl;
    if (watch.origin == current.origin &&
        watch.path == '/watch' &&
        RegExp(r'^[0-9]+$').hasMatch(watch.queryParameters['v'] ?? '') &&
        watch == videoPlaybackIdentity(watch) &&
        card.title.trim().isNotEmpty) {
      entries.putIfAbsent(watch, () => card);
    }
  }
  return entries.containsKey(current) ? entries.values.toList() : const [];
}

/// Read the selected episodes without moving the live playback document.
/// A fixed quality is offered only when the site exposes it for every entry.
Future<Set<VideoEpisodeDownloadQuality>> readNativeSiteEpisodeQualities({
  required InAppWebViewController web,
  required List<NativeVideoCard> episodes,
  required bool Function() current,
}) async {
  final owner = VideoDownloadResolutionOwner.current;
  Set<VideoEpisodeDownloadQuality>? common;
  for (final episode in episodes) {
    owner?.check();
    if (!current()) throw const VideoResolutionCancelled();
    final operations = VideoSiteOperations(
      page: episode.watchUrl,
      evaluate: (script) => web.evaluateJavascript(source: script),
    );
    try {
      final result = await operations.readDownloadChoices();
      owner?.check();
      if (!current()) throw const VideoResolutionCancelled();
      if (result.status == VideoSiteStatus.unsupported) return const {};
      if (result.status != VideoSiteStatus.ok) {
        throw const VideoDownloadResolutionFailure('qualityUnavailable');
      }
      final qualities = {
        for (final choice in result.value ?? const <VideoDownloadChoice>[])
          if (choice.format case final String format)
            (label: choice.label, format: format),
      };
      common = common?.intersection(qualities) ?? qualities;
      if (common.isEmpty) break;
    } finally {
      operations.dispose();
    }
  }
  return common ?? const {};
}

/// Retains the site document for same-origin download-page reads. The queue
/// owns the lease after admission, so the player may close during resolution.
Future<List<String>> enqueueNativeSiteEpisodes({
  required String source,
  InAppWebViewController? web,
  VideoBrowserBackgroundLifetime? lifetime,
  OverlayState? coldOverlay,
  required NativePlaybackSession session,
  required List<NativeVideoCard> selected,
  required bool Function() current,
  String? preferredQuality,
  String? preferredFormat,
}) async {
  final allowed = {
    for (final card in nativeSiteDownloadEntries(session)) card.watchUrl: card,
  };
  if (selected.isEmpty ||
      selected.any((card) => !allowed.containsKey(card.watchUrl))) {
    throw const FormatException('Video is outside the current sequence');
  }
  if (!current()) throw StateError('Download session changed');
  final episodes = [for (final card in selected) allowed[card.watchUrl]!];
  if (web == null || lifetime == null) {
    if (coldOverlay == null || !coldOverlay.mounted) {
      throw StateError('Download browser unavailable');
    }
    return VideoEpisodeDownloadQueue.enqueue(
      source: source,
      episodes: episodes,
      preferredQuality: preferredQuality,
      preferredFormat: preferredFormat,
      userInitiated: true,
      canAdmit: current,
      resolveTask: (row) async {
        final owner = VideoDownloadResolutionOwner.current!;
        owner.onCancel(() => VideoDownloadRetryHosts.cancel(source, owner));
        try {
          final resolved = await VideoDownloadRetryHosts.resolve(
            coldOverlay,
            row,
            owner: owner,
          );
          return (
            choices: resolved.choices,
            networkContext: resolved.networkContext,
            headersForChoice: resolved.headersForChoice,
            release: resolved.close,
          );
        } on VideoDownloadRetryFailure catch (error) {
          if (error.reason == 'cancelled') {
            throw const VideoResolutionCancelled();
          }
          throw VideoDownloadResolutionFailure(error.reason);
        }
      },
    );
  }
  await lifetime.retainBackground();
  OmoNetworkContext? network;
  var released = false;
  Future<void> release() async {
    if (released) return;
    released = true;
    try {
      await network?.close();
    } finally {
      await lifetime.releaseBackground();
    }
  }

  try {
    network = await OmoNetworkContext.open(
      null,
      source: source,
      siteOrigins: [session.watchUrl],
    );
    if (!current()) throw StateError('Download session changed');
    return await VideoEpisodeDownloadQueue.enqueue(
      source: source,
      episodes: episodes,
      networkContext: network?.token,
      preferredQuality: preferredQuality,
      preferredFormat: preferredFormat,
      userInitiated: true,
      canAdmit: current,
      release: release,
      resolve: (card) async {
        final operations = VideoSiteOperations(
          page: card.watchUrl,
          evaluate: (script) => web.evaluateJavascript(source: script),
        );
        try {
          final result = await operations.readDownloadChoices();
          final choices = result.value;
          if (choices == null || choices.isEmpty) {
            if (result.status == VideoSiteStatus.cancelled) {
              throw const VideoResolutionCancelled();
            }
            throw VideoDownloadResolutionFailure(switch (result.status) {
              VideoSiteStatus.login => 'loginRequired',
              VideoSiteStatus.verification => 'verificationRequired',
              VideoSiteStatus.changed => 'accountChanged',
              VideoSiteStatus.unsupported => 'unsupported',
              _ => 'network',
            });
          }
          await network?.prepare();
          return (
            session: NativePlaybackSession(
              title: card.title,
              watchUrl: card.watchUrl,
              coverUrl: card.coverUrl,
              description: '',
              tags: const [],
              sources: [
                for (final choice in choices)
                  NativePlaybackSource(
                    url: choice.url,
                    label: choice.label,
                    headers: const {},
                  ),
              ],
            ),
            sourceDuration: card.metadata.duration,
          );
        } finally {
          operations.dispose();
        }
      },
    );
  } catch (_) {
    await release();
    rethrow;
  }
}
