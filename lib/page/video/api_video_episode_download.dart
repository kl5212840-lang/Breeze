import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:flutter/foundation.dart';
import 'package:zephyr/network/source_network_policy.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/omo_network.dart';
import 'package:zephyr/page/video/video_episode_download_queue.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/page/video/api_video_download_retry.dart';
import 'package:zephyr/page/video/video_download_retry.dart';
import 'package:zephyr/page/video/video_download_availability.dart';

/// Enqueue independently of detail-page state, retaining the current source
/// route and native authentication context until the complete selection ends.
abstract final class ApiVideoEpisodeDownloads {
  /// The work already owns a repository: retry here rather than navigating to
  /// this same work through the download center's recovery shortcut.
  static Future<List<String>> retry(
    ApiVideoRepository repository,
    ApiVideoItem item,
    NativeVideoCard episode,
    Map<String, dynamic> row,
  ) async {
    if (row['source'] != repository.source ||
        videoPlaybackIdentity(episode.watchUrl)?.toString() != row['url'] ||
        videoPublicPage(episode.watchUrl) != videoPublicPage(item.detailUrl) ||
        row['retryItemId'] != null && row['retryItemId'] != item.id) {
      throw const FormatException('Download is outside this work');
    }
    if (row['status'] == 'saved' || !VideoDownloadRetry.canRecover(row)) {
      return enqueue(
        repository,
        item,
        [episode],
        preferredQuality:
            row['quality'] is String && (row['quality'] as String).isNotEmpty
            ? row['quality'] as String
            : null,
        preferredFormat: videoDownloadFormat(row),
      );
    }
    final task = {...row, 'retryItemId': item.id};
    final queued = await VideoDownloadRetry.retry(
      task,
      userInitiated: true,
      fallback: (current) => resolveApiVideoDownloadRetry(
        repository,
        current,
        current: () => true,
        snapshot: item,
      ),
    );
    return queued ? [row['key'] as String] : const [];
  }

  /// Sources resolved without a page-owned browser can queue on either media
  /// platform. The retained WebKit document bridge is currently iOS-only.
  static bool supportsBatch(ApiVideoRepository repository) =>
      repository.retainBrowserForDownloads == null ||
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  static Future<List<String>> enqueue(
    ApiVideoRepository repository,
    ApiVideoItem item,
    List<NativeVideoCard> episodes, {
    String? preferredQuality,
    String? preferredFormat,
  }) async {
    if (!supportsBatch(repository)) {
      throw UnsupportedError('Background browser downloads unavailable');
    }
    final installation = SourceNetworkPolicies.supports(repository.source)
        ? LocalPluginInstallationState.instance
        : null;
    await installation?.load();
    final epoch = installation?.installationEpoch(repository.source);
    bool current() =>
        installation == null ||
        (!installation.isRemoved(repository.source) &&
            !installation.isInstalling(repository.source) &&
            installation.installationEpoch(repository.source) == epoch);
    if (!current()) throw const PluginLifecycleChanged();
    for (final card in episodes) {
      final page = videoPlaybackIdentity(card.watchUrl);
      final line = item.lines
          .where((line) => line.id == page?.queryParameters['line'])
          .firstOrNull;
      if (page == null ||
          page.origin != item.detailUrl.origin ||
          page.path != item.detailUrl.path ||
          line == null ||
          !line.episodes.any(
            (episode) => episode.id == page.queryParameters['episode'],
          )) {
        throw const FormatException('Episode outside this item');
      }
    }
    SourceNetworkLease? lease;
    OmoNetworkContext? network;
    Future<void> Function()? releaseBrowser;
    Future<void> releaseOwners() async {
      try {
        await releaseBrowser?.call();
      } finally {
        try {
          await network?.close();
        } finally {
          await lease?.close();
        }
      }
    }

    try {
      await VideoDownloadedDetails.saveItem(
        repository.source,
        item,
      ).catchError((Object _) {});
      releaseBrowser = await repository.retainBrowserForDownloads?.call();
      if (!current()) throw const PluginLifecycleChanged();
      if (SourceNetworkPolicies.supports(repository.source)) {
        lease = await SourceNetworkPolicies.acquire(repository.source);
        network = await OmoNetworkContext.open(
          null,
          source: repository.source,
          siteOrigins: [repository.home],
        );
      }
      if (!current()) throw const PluginLifecycleChanged();
      await VideoDownloadedDetails.captureItem(
        repository.source,
        item,
        episodes,
        network: network,
        namespace: repository.capabilities.itemNamespace,
        sourceDisplayName:
            '${PluginRegistryService.I.getCachedPluginInfo(repository.source)?['name'] ?? ''}',
      ).catchError((Object _) {});
      final retained = repository.withNetwork(Future.value(network));
      return await VideoEpisodeDownloadQueue.enqueue(
        userInitiated: true,
        source: repository.source,
        cooperativeResolution: repository.cancellableDownloadTransport,
        retryItemId: item.id,
        preferredQuality: preferredQuality,
        preferredFormat: preferredFormat,
        episodes: [
          for (final episode in episodes)
            NativeVideoCard(
              title: item.title,
              watchUrl: episode.watchUrl,
              coverUrl: episode.coverUrl ?? item.coverUrl,
              episodeLabel: episode.episodeLabel,
              metadata: episode.metadata,
              creator: episode.creator,
              subtitle: episode.subtitle,
            ),
        ],
        networkContext: network?.token,
        resolve: (episode) async {
          final result = await retained.session(
            item.id,
            lineId: episode.watchUrl.queryParameters['line'],
            episodeId: episode.watchUrl.queryParameters['episode'],
            refresh: true,
            snapshot: item,
          );
          return (
            session: result.session,
            sourceDuration: result.item.sourceDuration,
          );
        },
        release: releaseOwners,
      );
    } catch (_) {
      await releaseOwners();
      rethrow;
    }
  }
}
