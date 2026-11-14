import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/service/video_bookshelf_index.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/page/video/video_source_action.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/widgets/toast.dart';

/// Public work identity only. Never opens a CDN URL, website or local player.
VideoBookshelfRow? videoDownloadWorkRow(
  Map<String, dynamic> row, {
  Object? sourceInfo,
  bool includeEpisode = true,
}) {
  final source = row['source'], raw = row['url'];
  if (source is! String ||
      source.trim().isEmpty ||
      source.length > 200 ||
      raw is! String) {
    return null;
  }
  final uri = Uri.tryParse(raw);
  final page = uri == null ? null : videoPublicPage(uri);
  if (page == null) return null;
  final candidates = sourceInfo == null
      ? null
      : videoSourceActions(sourceInfo)
            .where(
              (action) =>
                  apiVideoHttps(
                    (action['payload'] as Map)['url'],
                    origin: page,
                  ) !=
                  null,
            )
            .toList();
  final publicIdentity = row['publicWorkIdentity'];
  final namespace = row['publicModuleNamespace'];
  final prefix = '$source|${namespace is String ? namespace : ''}|';
  final suffix = '|$page';
  final boundId =
      publicIdentity is String &&
          publicIdentity.startsWith(prefix) &&
          publicIdentity.endsWith(suffix) &&
          publicIdentity.length > prefix.length + suffix.length
      ? publicIdentity.substring(
          prefix.length,
          publicIdentity.length - suffix.length,
        )
      : null;
  final storedId = boundId ?? row['retryItemId'];
  String? id =
      storedId is String &&
          RegExp(r'^[A-Za-z0-9_.:-]{1,300}$').hasMatch(storedId)
      ? storedId
      : null;
  if (id == null) {
    id = page.path == '/watch' ? page.queryParameters['v'] : null;
    for (final pattern in [
      r'^/anime/([a-f0-9]{16,64})\.html$',
      r'^/voddetail/([1-9][0-9]{0,14})\.html$',
      r'^/index\.php/vod/detail/id/([1-9][0-9]{0,14})\.html$',
      r'^/vod/([1-9][0-9]{0,14})/$',
    ]) {
      id ??= RegExp(pattern).firstMatch(page.path)?.group(1);
    }
    final video = RegExp(
      r'^/videos/([A-Za-z0-9_-]{1,64})$',
    ).firstMatch(page.path)?.group(1);
    if (id == null && video != null && candidates != null) {
      if (candidates.length != 1) {
        return null; // Never guess a shared-origin module.
      }
      final payload = candidates.single['payload'] as Map;
      final caps = payload['capabilities'];
      final namespace = caps is Map ? '${caps['itemNamespace'] ?? ''}' : '';
      id = namespace.isEmpty ? video : '$namespace:$video';
    }
  }
  if (id == null || id.isEmpty) return null;
  final workId = id;
  if (candidates != null) {
    String namespace(Map<String, dynamic> action) {
      final caps = (action['payload'] as Map)['capabilities'];
      return caps is Map ? '${caps['itemNamespace'] ?? ''}' : '';
    }

    final explicit = candidates.any(
      (action) =>
          namespace(action).isNotEmpty &&
          workId.startsWith('${namespace(action)}:'),
    );
    if (candidates.isEmpty ||
        candidates.length > 1 && !explicit ||
        candidates.any((action) => namespace(action).isNotEmpty) &&
            workId.contains(':') &&
            !explicit) {
      return null;
    }
  }
  final stamp = row['at'];
  return VideoBookshelfRow(
    key: '${row['key'] ?? ''}',
    source: source,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      stamp is int && stamp >= 0 && stamp <= 8640000000000000 ? stamp : 0,
    ),
    watchUrl: includeEpisode ? videoPlaybackIdentity(uri!) : null,
    item: ApiVideoItem(
      id: workId,
      title: '${row['publicWorkTitle'] ?? row['title'] ?? id}',
      detailUrl: page,
    ),
  );
}

VideoBookshelfRow? videoDownloadSourceTarget(
  Map<String, dynamic> row, {
  bool includeEpisode = true,
}) => videoDownloadWorkRow(
  row,
  includeEpisode: includeEpisode,
  sourceInfo: PluginRegistryService.I.getCachedPluginInfo('${row['source']}'),
);

final _openingWorks = <(String, String, String)>{};

Future<void> openVideoDownloadWork(
  BuildContext context,
  Map<String, dynamic> row, {
  bool includeEpisode = true,
  bool forDownloadRecovery = true,
}) async {
  final target = videoDownloadSourceTarget(row, includeEpisode: includeEpisode);
  if (target == null) {
    showErrorToast(t.download.sourceUnavailableHint);
    return;
  }
  final key = (target.source, target.item.detailUrl.toString(), target.item.id);
  if (!_openingWorks.add(key)) return;
  try {
    await VideoBookshelfIndex.open(
      context,
      target,
      forDownloadRecovery: forDownloadRecovery,
      fromDownloadDetails: true,
    );
  } finally {
    _openingWorks.remove(key);
  }
}
