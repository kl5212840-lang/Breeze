import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/downloaded_video_playback_page.dart';
import 'package:zephyr/page/video/video_page_route.dart';

/// Downloads owns a local playback route, independent of the source's pages.
Future<void> openLocalVideo(
  BuildContext context,
  String id, {
  ApiVideoRepository? repository,
  Map<String, dynamic>? resource,
  bool matchAutoRouteTransition = false,
}) async {
  if (!context.mounted) return;
  final snapshot = resource == null ? null : Map<String, dynamic>.of(resource);
  await Navigator.of(context, rootNavigator: true).push<void>(
    videoPageRoute<void>(
      settings: const RouteSettings(name: 'breeze.video.local'),
      matchAutoRouteTransition: matchAutoRouteTransition,
      builder: (_) =>
          DownloadedVideoPlaybackPage(resourceId: id, resource: snapshot),
    ),
  );
}
