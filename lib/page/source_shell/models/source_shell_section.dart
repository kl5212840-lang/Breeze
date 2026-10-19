import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/comic_list/models/comic_list_scene.dart';
import 'package:zephyr/page/discover/service/discover_router.dart';
import 'package:zephyr/util/json/json_value.dart';

/// A list scene exposed by a plugin for the persistent source navigation.
/// Other plugin actions keep their existing Discover shortcuts.
class SourceShellSection {
  const SourceShellSection({
    required this.id,
    required this.title,
    required this.scene,
  });

  final String id;
  final String title;
  final ComicListScene scene;

  IconData get icon => switch (id) {
    'recommend' => Icons.auto_awesome_outlined,
    'newest' => Icons.new_releases_outlined,
    'discover' => Icons.explore_outlined,
    'rank' => Icons.leaderboard_outlined,
    'cloudFavorite' => Icons.bookmark_outline,
    _ => Icons.view_list_outlined,
  };

  static List<SourceShellSection> fromPluginInfo(
    Map<String, dynamic> info,
    String source,
  ) {
    final functions = asJsonList(
      info['functions'] ?? info['function'] ?? const <dynamic>[],
    );
    final sections = <SourceShellSection>[];
    final seenIds = <String>{};

    for (final item in functions) {
      final function = asJsonMap(item);
      final action = asJsonMap(function['action']);
      if (action['type']?.toString() != 'openComicList') continue;

      final attached = DiscoverRouter.attachSource(action, source);
      final sceneMap = asJsonMap(asJsonMap(attached['payload'])['scene']);
      if (sceneMap.isEmpty) continue;

      final scene = ComicListScene.fromMap(sceneMap);
      final request = scene.body.request;
      if (scene.from.isEmpty || request == null || request.fnPath.isEmpty) {
        continue;
      }

      final id = function['id']?.toString().trim() ?? '';
      final title = function['title']?.toString().trim().isNotEmpty == true
          ? function['title'].toString().trim()
          : scene.title.trim();
      final uniqueId = id.isNotEmpty ? id : request.fnPath;
      if (title.isEmpty || !seenIds.add(uniqueId)) continue;

      sections.add(
        SourceShellSection(id: uniqueId, title: title, scene: scene),
      );
    }

    return List<SourceShellSection>.unmodifiable(sections);
  }
}
