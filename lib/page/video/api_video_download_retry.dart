import 'package:zephyr/network/source_network_policy.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/omo_network.dart';
import 'package:zephyr/page/video/video_download_retry.dart';
import 'package:zephyr/page/video/video_download_source_navigation.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/page/video/video_playback_download_adapter.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/page/video/video_source_action.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';

String? _registeredRetryWorkId(
  ApiVideoRepository repository,
  Map<String, dynamic> row,
) {
  final info = PluginRegistryService.I.getCachedPluginInfo(repository.source);
  final hasDeclaredModule =
      videoSourceAction(info, home: repository.home) != null;
  final target = videoDownloadWorkRow(
    row,
    sourceInfo: hasDeclaredModule ? info : null,
  );
  if (target == null ||
      target.item.detailUrl.origin != repository.home.origin ||
      target.watchUrl?.queryParameters['line'] == null) {
    return null;
  }
  final id = target.item.id;
  final namespace = repository.capabilities.itemNamespace;
  if (namespace.isNotEmpty && !id.startsWith('$namespace:')) return null;
  if (!hasDeclaredModule) return id;

  final action = videoSourceAction(info, home: repository.home, itemId: id);
  final payload = action?['payload'] as Map?;
  if (apiVideoText(payload?['catalogFnPath']) != repository.catalogFn ||
      apiVideoText(payload?['detailFnPath']) != repository.detailFn ||
      apiVideoText(payload?['playbackFnPath']) != repository.playbackFn) {
    return null;
  }
  final capabilities = payload?['capabilities'];
  final declaredNamespace = capabilities is Map
      ? capabilities['itemNamespace']
      : null;
  return apiVideoText(declaredNamespace) == namespace ? id : null;
}

Object registerApiVideoDownloadRetry(
  ApiVideoRepository repository, {
  required bool Function() current,
}) => VideoDownloadRetry.register(
  repository.source,
  (row) {
    final id = _registeredRetryWorkId(repository, row);
    if (id == null) throw const VideoDownloadRetryFailure('missingIdentity');
    return resolveApiVideoDownloadRetry(repository, {
      ...row,
      'retryItemId': id,
    }, current: current);
  },
  current: current,
  accepts: (row) => _registeredRetryWorkId(repository, row) != null,
  cooperativeCancellation: repository.cancellableDownloadTransport,
);

Future<VideoDownloadRetryResolution> resolveApiVideoDownloadRetry(
  ApiVideoRepository repository,
  Map<String, dynamic> row, {
  required bool Function() current,
  ApiVideoItem? snapshot,
}) async {
  final page = videoPlaybackIdentity(Uri.parse(row['url'] as String));
  if (page == null || page.origin != repository.home.origin)
    throw const VideoDownloadRetryFailure('missingIdentity');
  String? id = row['retryItemId'] is String
      ? row['retryItemId'] as String
      : null;
  if (id == null) {
    for (final pattern in [
      r'^/anime/([a-f0-9]{16,64})\.html$',
      r'^/voddetail/([1-9][0-9]{0,14})\.html$',
      r'^/index\.php/vod/detail/id/([1-9][0-9]{0,14})\.html$',
      r'^/vod/([1-9][0-9]{0,14})/$',
    ]) {
      id = RegExp(pattern).firstMatch(page.path)?.group(1);
      if (id != null) break;
    }
    final video = RegExp(
      r'^/videos/([A-Za-z0-9_-]{1,64})$',
    ).firstMatch(page.path)?.group(1);
    if (id == null && video != null)
      id = repository.capabilities.itemNamespace.isEmpty
          ? video
          : '${repository.capabilities.itemNamespace}:$video';
  }
  final namespace = repository.capabilities.itemNamespace;
  if (id == null ||
      namespace.isNotEmpty && !id.startsWith('$namespace:') ||
      page.queryParameters['line'] == null ||
      page.queryParameters['episode'] == null)
    throw const VideoDownloadRetryFailure('missingIdentity');
  Future<void> Function()? releaseBrowser;
  SourceNetworkLease? lease;
  OmoNetworkContext? network;
  Future<void> release() async {
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
    if (!current())
      throw const VideoDownloadRetryFailure('sourceVisitRequired');
    if (repository.capabilities.detailFromSnapshot) {
      snapshot ??= await VideoDownloadedDetails.readItem(
        repository.source,
        page,
      ).onError((_, _) => null);
      if (snapshot == null ||
          snapshot.id != id ||
          videoPublicPage(snapshot.detailUrl) != videoPublicPage(page)) {
        throw const VideoDownloadRetryFailure('sourceVisitRequired');
      }
      if (!current()) throw const VideoDownloadRetryFailure('accountChanged');
    }
    releaseBrowser = await repository.retainBrowserForDownloads?.call();
    if (SourceNetworkPolicies.supports(repository.source)) {
      lease = await SourceNetworkPolicies.acquire(repository.source);
      network = await OmoNetworkContext.open(
        null,
        source: repository.source,
        siteOrigins: [repository.home],
      );
    }
    final retained = repository.withNetwork(Future.value(network));
    final item = await retained.item(id, refresh: true, snapshot: snapshot);
    if (!current()) throw const VideoDownloadRetryFailure('accountChanged');
    final line = item.lines
        .where((line) => line.id == page.queryParameters['line'])
        .firstOrNull;
    if (item.detailUrl.origin != page.origin ||
        item.detailUrl.path != page.path ||
        line == null ||
        !line.episodes.any(
          (episode) => episode.id == page.queryParameters['episode'],
        ))
      throw const VideoDownloadRetryFailure('missingIdentity');
    final resolved = await retained.session(
      item.id,
      lineId: line.id,
      episodeId: page.queryParameters['episode'],
      refresh: true,
      snapshot: item,
    );
    if (!current()) throw const VideoDownloadRetryFailure('accountChanged');
    if (videoPlaybackIdentity(resolved.session.watchUrl) != page)
      throw const VideoDownloadRetryFailure('missingIdentity');
    final adapter = VideoPlaybackDownloadAdapter(resolved.session);
    return VideoDownloadRetryResolution(
      choices: adapter.choices,
      headersForChoice: adapter.headersForChoice,
      networkContext: network?.token,
      release: release,
    );
  } catch (_) {
    await release();
    rethrow;
  }
}
