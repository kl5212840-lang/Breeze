import 'package:zephyr/page/source_shell/source_experience_preferences.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/comic_list/models/comic_list_scene.dart';
import 'package:zephyr/page/discover/service/discover_router.dart';
import 'package:zephyr/page/source_shell/models/source_video_module.dart';
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
       videoBrowseOnly = null,
       profileVideoRecords = false,
       legacySources = const [],
       profileAvatarFunction = '',
       profileBioFunction = '',
       profileKind = '',
       profileCheckinFunction = '',
       profileNotificationsFunction = '',
       profileCheckinStatusFunction = '',
       profileCheckinStatusSource = 'serverCalendar',
       profileMarkNotificationReadFunction = '',
       profileMarkNotificationsReadFunction = '',

       profileCloudFavoriteFunction = '',
       actions = const [];

  /// A host destination, never a synthetic plugin function callback.
  const SourceShellSection.settings()
    : this(id: 'bikaSettings', title: '设置', scene: null);

  const SourceShellSection.games()
    : this(id: 'bikaGames', title: '游戏', scene: null);

  const SourceShellSection.function({
    required this.id,
    required this.title,
    required this.functionId,
  }) : scene = null,
       cloudFavorite = false,
       profile = false,
       videoBrowseOnly = null,
       profileVideoRecords = false,
       legacySources = const [],
       profileAvatarFunction = '',
       profileBioFunction = '',
       profileKind = '',
       profileCheckinFunction = '',
       profileNotificationsFunction = '',
       profileCheckinStatusFunction = '',
       profileCheckinStatusSource = 'serverCalendar',
       profileMarkNotificationReadFunction = '',
       profileMarkNotificationsReadFunction = '',

       profileCloudFavoriteFunction = '',
       actions = const [];

  const SourceShellSection.cloudFavorite({
    required this.id,
    required this.title,
  }) : scene = null,
       functionId = null,
       cloudFavorite = true,
       profile = false,
       videoBrowseOnly = null,
       profileVideoRecords = false,
       legacySources = const [],
       profileAvatarFunction = '',
       profileBioFunction = '',
       profileKind = '',
       profileCheckinFunction = '',
       profileNotificationsFunction = '',
       profileCheckinStatusFunction = '',
       profileCheckinStatusSource = 'serverCalendar',
       profileMarkNotificationReadFunction = '',
       profileMarkNotificationsReadFunction = '',

       profileCloudFavoriteFunction = '',
       actions = const [];

  const SourceShellSection.profile({
    this.legacySources = const [],
    this.profileAvatarFunction = '',
    this.profileBioFunction = '',
    this.profileKind = '',
    this.profileVideoRecords = false,
    this.profileCheckinFunction = '',
    this.profileNotificationsFunction = '',
    this.profileCheckinStatusFunction = '',
    this.profileCheckinStatusSource = 'serverCalendar',
    this.profileMarkNotificationReadFunction = '',
    this.profileMarkNotificationsReadFunction = '',

    this.profileCloudFavoriteFunction = '',
  }) : id = 'profile',
       title = '我的',
       scene = null,
       functionId = null,
       cloudFavorite = false,
       profile = true,
       videoBrowseOnly = null,
       actions = const [];

  const SourceShellSection.more({required this.title, required this.actions})
    : id = 'more',
      scene = null,
      functionId = null,
      cloudFavorite = false,
      profile = false,
      videoBrowseOnly = null,
      profileVideoRecords = false,
      legacySources = const [],
      profileAvatarFunction = '',
      profileBioFunction = '',
      profileKind = '',
      profileCheckinFunction = '',
      profileNotificationsFunction = '',
      profileCheckinStatusFunction = '',
      profileCheckinStatusSource = 'serverCalendar',
      profileMarkNotificationReadFunction = '',
      profileMarkNotificationsReadFunction = '',

      profileCloudFavoriteFunction = '';

  const SourceShellSection.video({required this.actions, this.videoBrowseOnly})
    : id = 'video',
      title = '视频',
      scene = null,
      functionId = null,
      cloudFavorite = false,
      profile = false,
      profileVideoRecords = false,
      legacySources = const [],
      profileAvatarFunction = '',
      profileBioFunction = '',
      profileKind = '',
      profileCheckinFunction = '',
      profileNotificationsFunction = '',
      profileCheckinStatusFunction = '',
      profileCheckinStatusSource = 'serverCalendar',
      profileMarkNotificationReadFunction = '',
      profileMarkNotificationsReadFunction = '',

      profileCloudFavoriteFunction = '';

  final String id;
  final String title;
  final ComicListScene? scene;
  final String? functionId;
  final bool cloudFavorite;
  final bool profile;
  final bool? videoBrowseOnly;
  final bool profileVideoRecords;
  final List<String> legacySources;
  final String profileAvatarFunction;
  final String profileBioFunction;
  final String profileKind;
  final String profileCheckinFunction;
  final String profileNotificationsFunction;
  final String profileCheckinStatusFunction;
  final String profileCheckinStatusSource;
  final String profileMarkNotificationReadFunction;
  final String profileMarkNotificationsReadFunction;

  final String profileCloudFavoriteFunction;
  final List<SourceShellAction> actions;

  bool get sourceSettings =>
      id == 'bikaSettings' && functionId == null && scene == null;

  bool get bikaGames =>
      id == 'bikaGames' && functionId == null && scene == null;

  bool get videoGroup => id == 'video' && actions.isNotEmpty;

  IconData get icon => switch (id) {
    'recommend' => Icons.auto_awesome_outlined,
    'newest' || 'latest' => Icons.new_releases_outlined,
    'discover' => Icons.explore_outlined,
    'navigation' || 'categories' => Icons.grid_view_outlined,
    'rank' || 'ranking' => Icons.leaderboard_outlined,
    'cloudFavorite' => Icons.bookmark_outline,
    'profile' => Icons.person_outline,
    'bikaSettings' => Icons.settings_outlined,
    'bikaGames' => Icons.sports_esports_outlined,
    'video' => Icons.video_library_outlined,
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
    final videos = <SourceShellAction>[];
    final homes = <String>{};
    for (final raw in asJsonList(info['breezeVideoModules'])) {
      final action = DiscoverRouter.attachSource(asJsonMap(raw), source);
      final module = SourceVideoModule.fromAction(action, source);
      if (module == null || !homes.add(module.id)) continue;
      videos.add(SourceShellAction(title: module.title, action: action));
    }
    if (videos.isNotEmpty && seenIds.add('video')) {
      sections.add(
        SourceShellSection.video(
          videoBrowseOnly: experience['videoBrowseOnly'] is bool
              ? experience['videoBrowseOnly'] as bool
              : null,
          actions: List<SourceShellAction>.unmodifiable(videos),
        ),
      );
    }

    if (experience['profileTab'] == true && seenIds.add('profile')) {
      sections.add(
        SourceShellSection.profile(
          profileVideoRecords: experience['profileVideoRecords'] == true,
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
          profileCheckinStatusFunction:
              experience['profileCheckinStatusFunction']?.toString().trim() ??
              '',
          profileCheckinStatusSource:
              experience['profileCheckinStatusSource'] == 'serverProfile'
              ? 'serverProfile'
              : 'serverCalendar',
          profileMarkNotificationReadFunction:
              experience['profileMarkNotificationReadFunction']
                  ?.toString()
                  .trim() ??
              '',
          profileMarkNotificationsReadFunction:
              experience['profileMarkNotificationsReadFunction']
                  ?.toString()
                  .trim() ??
              '',
          profileCloudFavoriteFunction:
              experience['profileCloudFavoriteFunction']?.toString().trim() ??
              '',
        ),
      );
    }

    if (supportsBikaExperienceDeclaration(source, info) &&
        seenIds.add('bikaSettings')) {
      sections.add(const SourceShellSection.settings());
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
