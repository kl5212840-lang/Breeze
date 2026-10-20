import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/comic_list/models/comic_list_scene.dart';
import 'package:zephyr/page/discover/service/discover_router.dart';
import 'package:zephyr/util/json/json_value.dart';

/// A plugin entry exposed in the persistent source navigation.
class SourceShellSection {
  const SourceShellSection({
    required this.id,
    required this.title,
    required this.scene,
  }) : functionId = null,
       cloudFavorite = false,
       profile = false,
       legacySources = const [],
       profileAvatarFunction = '',
       profileBioFunction = '',
       profileKind = '',
       profileCheckinFunction = '',
       profileNotificationsFunction = '',
       actions = const [];

  const SourceShellSection.function({
    required this.id,
    required this.title,
    required this.functionId,
  }) : scene = null,
       cloudFavorite = false,
       profile = false,
       legacySources = const [],
       profileAvatarFunction = '',
       profileBioFunction = '',
       profileKind = '',
       profileCheckinFunction = '',
       profileNotificationsFunction = '',
       actions = const [];

  const SourceShellSection.cloudFavorite({
    required this.id,
    required this.title,
  }) : scene = null,
       functionId = null,
       cloudFavorite = true,
       profile = false,
       legacySources = const [],
       profileAvatarFunction = '',
       profileBioFunction = '',
       profileKind = '',
       profileCheckinFunction = '',
       profileNotificationsFunction = '',
       actions = const [];

  const SourceShellSection.profile({
    this.legacySources = const [],
    this.profileAvatarFunction = '',
    this.profileBioFunction = '',
    this.profileKind = '',
    this.profileCheckinFunction = '',
    this.profileNotificationsFunction = '',
  }) : id = 'profile',
       title = '我的',
       scene = null,
       functionId = null,
       cloudFavorite = false,
       profile = true,
       actions = const [];

  const SourceShellSection.more({required this.title, required this.actions})
    : id = 'more',
      scene = null,
      functionId = null,
      cloudFavorite = false,
      profile = false,
      legacySources = const [],
      profileAvatarFunction = '',
      profileBioFunction = '',
      profileKind = '',
      profileCheckinFunction = '',
      profileNotificationsFunction = '';

  final String id;
  final String title;
  final ComicListScene? scene;
  final String? functionId;
  final bool cloudFavorite;
  final bool profile;
  final List<String> legacySources;
  final String profileAvatarFunction;
  final String profileBioFunction;
  final String profileKind;
  final String profileCheckinFunction;
  final String profileNotificationsFunction;
  final List<SourceShellAction> actions;

  IconData get icon => switch (id) {
    'recommend' => Icons.auto_awesome_outlined,
    'newest' || 'latest' => Icons.new_releases_outlined,
    'discover' => Icons.explore_outlined,
    'navigation' || 'categories' => Icons.grid_view_outlined,
    'rank' || 'ranking' => Icons.leaderboard_outlined,
    'cloudFavorite' => Icons.bookmark_outline,
    'profile' => Icons.person_outline,
    'more' => Icons.apps_outlined,
    _ => Icons.view_list_outlined,
  };

  /// A source with no declared home functions opens a search-first shell.
  /// Keep legacy shortcuts if functions were declared but none can be rendered.
  static bool canLaunch(
    Map<String, dynamic>? info,
    List<SourceShellSection> sections,
  ) {
    if (info == null) return false;
    final functions = asJsonList(info['functions'] ?? info['function']);
    return sections.isNotEmpty || functions.isEmpty;
  }

  static List<SourceShellSection> fromPluginInfo(
    Map<String, dynamic> info,
    String source,
  ) {
    final functions = asJsonList(
      info['functions'] ?? info['function'] ?? const <dynamic>[],
    );
    final sections = <SourceShellSection>[];
    final otherActions = <SourceShellAction>[];
    final seenIds = <String>{};

    for (final item in functions) {
      final function = asJsonMap(item);
      var action = asJsonMap(function['action']);
      final id = function['id']?.toString().trim() ?? '';
      final functionTitle = function['title']?.toString().trim() ?? '';
      if (action.isEmpty && id.isNotEmpty) {
        action = {
          'type': 'openPluginFunction',
          'payload': {'id': id, 'title': functionTitle, 'presentation': 'page'},
        };
      }
      if (action['type']?.toString() != 'openComicList') {
        if (action['type']?.toString() == 'openCloudFavorite' &&
            functionTitle.isNotEmpty &&
            seenIds.add(id.isNotEmpty ? id : 'cloudFavorite')) {
          sections.add(
            SourceShellSection.cloudFavorite(
              id: id.isNotEmpty ? id : 'cloudFavorite',
              title: functionTitle,
            ),
          );
          continue;
        }
        if (action['type']?.toString() == 'openPluginFunction') {
          final payload = asJsonMap(action['payload']);
          final presentation = payload['presentation']?.toString() ?? 'page';
          final functionId = payload['id']?.toString().trim() ?? id;
          final uniqueId = id.isNotEmpty ? id : functionId;
          if (presentation != 'dialog' &&
              functionId.isNotEmpty &&
              functionTitle.isNotEmpty &&
              seenIds.add(uniqueId)) {
            sections.add(
              SourceShellSection.function(
                id: uniqueId,
                title: functionTitle,
                functionId: functionId,
              ),
            );
            continue;
          }
        }
        if (action.isNotEmpty &&
            action['type']?.toString() != 'none' &&
            functionTitle.isNotEmpty) {
          otherActions.add(
            SourceShellAction(
              title: functionTitle,
              action: DiscoverRouter.attachSource(action, source),
            ),
          );
        }
        continue;
      }

      final attached = DiscoverRouter.attachSource(action, source);
      final sceneMap = asJsonMap(asJsonMap(attached['payload'])['scene']);
      if (sceneMap.isEmpty) continue;

      final scene = ComicListScene.fromMap(sceneMap);
      final request = scene.body.request;
      if (scene.from.isEmpty || request == null || request.fnPath.isEmpty) {
        continue;
      }

      final title = functionTitle.isNotEmpty
          ? functionTitle
          : scene.title.trim();
      final uniqueId = id.isNotEmpty ? id : request.fnPath;
      if (title.isEmpty || !seenIds.add(uniqueId)) continue;

      sections.add(
        SourceShellSection(id: uniqueId, title: title, scene: scene),
      );
    }

    final experience = asJsonMap(info['breezeExperience']);
    if (experience['profileTab'] == true && seenIds.add('profile')) {
      sections.add(
        SourceShellSection.profile(
          legacySources: asJsonList(experience['legacySources'])
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList(),
          profileAvatarFunction:
              experience['profileAvatarFunction']?.toString().trim() ?? '',
          profileBioFunction:
              experience['profileBioFunction']?.toString().trim() ?? '',
          profileKind: experience['profileKind']?.toString().trim() ?? '',
          profileCheckinFunction:
              experience['profileCheckinFunction']?.toString().trim() ?? '',
          profileNotificationsFunction:
              experience['profileNotificationsFunction']?.toString().trim() ??
              '',
        ),
      );
    }

    if (otherActions.isNotEmpty) {
      sections.add(
        SourceShellSection.more(
          title: 'more',
          actions: List<SourceShellAction>.unmodifiable(otherActions),
        ),
      );
    }

    return List<SourceShellSection>.unmodifiable(sections);
  }
}

class SourceShellAction {
  const SourceShellAction({required this.title, required this.action});

  final String title;
  final Map<String, dynamic> action;
}
