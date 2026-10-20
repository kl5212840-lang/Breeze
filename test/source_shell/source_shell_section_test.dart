import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/source_shell/models/source_shell_section.dart';

Map<String, dynamic> listFunction(String id, String title, String fnPath) => {
  'id': id,
  'title': title,
  'action': {
    'type': 'openComicList',
    'payload': {
      'scene': {
        'title': title,
        'source': 'stale-source',
        'body': {
          'type': 'pluginPagedComicList',
          'request': {'fnPath': fnPath, 'core': {}, 'extern': {}},
        },
      },
    },
  },
};

void main() {
  test('navigation and ranking use distinct section icons', () {
    const navigation = SourceShellSection.function(
      id: 'navigation',
      title: '导航',
      functionId: 'navigation',
    );
    const ranking = SourceShellSection.function(
      id: 'ranking',
      title: '排行榜',
      functionId: 'ranking',
    );
    expect(navigation.icon, Icons.grid_view_outlined);
    expect(ranking.icon, Icons.leaderboard_outlined);
    const latest = SourceShellSection.function(
      id: 'latest',
      title: '最新',
      functionId: 'latest',
    );
    expect(latest.icon, Icons.new_releases_outlined);
  });

  test('builds ordered tabs from plugin list actions and replaces source', () {
    final sections = SourceShellSection.fromPluginInfo({
      'function': [
        listFunction('recommend', '漫画推荐', 'getHomeRecommend'),
        {
          'id': 'search',
          'title': '搜索',
          'action': {'type': 'openSearch'},
        },
        listFunction('newest', '全新上架', 'getHomeNewest'),
      ],
    }, 'current-source');

    expect(sections.map((section) => section.id), [
      'recommend',
      'newest',
      'more',
    ]);
    expect(sections.first.scene?.from, 'current-source');
    expect(sections[1].scene?.body.request?.fnPath, 'getHomeNewest');
    expect(sections.last.actions.single.title, '搜索');
    expect(sections.last.actions.single.action['payload'], {
      'source': 'current-source',
    });
  });

  test('skips malformed and duplicate list scenes', () {
    final sections = SourceShellSection.fromPluginInfo({
      'functions': [
        listFunction('rank', '排行', 'getHomeRank'),
        listFunction('rank', '重复', 'getOtherRank'),
        listFunction('empty', '空', ''),
        {'id': 'no-action', 'title': '无动作'},
      ],
    }, 'source');

    expect(sections.length, 2);
    expect(sections.first.title, '排行');
    expect(sections.last.id, 'no-action');
    expect(sections.last.functionId, 'no-action');
  });

  test('keeps a plugin-defined home page first, ahead of list tabs', () {
    expect(SourceShellSection.fromPluginInfo({}, 'source'), isEmpty);
    final sections = SourceShellSection.fromPluginInfo({
      'function': [
        {'id': 'recommend', 'title': '推荐'},
        listFunction('latest', '最新', 'getLatest'),
      ],
    }, 'source');
    expect(sections.map((section) => section.id), ['recommend', 'latest']);
    expect(sections.first.functionId, 'recommend');
    expect(sections.last.scene?.body.request?.fnPath, 'getLatest');
  });

  test('puts dialog actions in More without changing the home tab', () {
    final sections = SourceShellSection.fromPluginInfo({
      'function': [
        listFunction('latest', '最新', 'getLatest'),
        {
          'id': 'tool',
          'title': '工具',
          'action': {
            'type': 'openPluginFunction',
            'payload': {'id': 'tool', 'presentation': 'dialog'},
          },
        },
      ],
    }, 'source');
    expect(sections.map((section) => section.id), ['latest', 'more']);
    expect(sections.last.actions.single.title, '工具');
  });

  test('keeps cloud favorites inside the source navigation', () {
    final sections = SourceShellSection.fromPluginInfo({
      'function': [
        listFunction('ranking', '排行榜', 'getRankingData'),
        {
          'id': 'cloudFavorite',
          'title': '云端收藏',
          'action': {
            'type': 'openCloudFavorite',
            'payload': {'title': '云端收藏'},
          },
        },
      ],
    }, 'source');

    expect(sections.map((section) => section.id), ['ranking', 'cloudFavorite']);
    expect(sections.last.cloudFavorite, isTrue);
    expect(sections.last.scene, isNull);
  });

  test(
    'personal profile stays separate and keeps old local records visible',
    () {
      final sections = SourceShellSection.fromPluginInfo({
        'breezeExperience': {
          'profileTab': true,
          'legacySources': ['old-source'],
          'profileAvatarFunction': 'updateAvatar',
          'profileBioFunction': 'updateProfile',
        },
        'function': [
          {
            'id': 'navigation',
            'title': '分类',
            'action': {
              'type': 'openPluginFunction',
              'payload': {'id': 'navigation', 'presentation': 'page'},
            },
          },
        ],
      }, 'personal-source');

      expect(sections.map((section) => section.id), ['navigation', 'profile']);
      expect(sections.last.profile, isTrue);
      expect(sections.last.legacySources, ['old-source']);
      expect(sections.last.profileAvatarFunction, 'updateAvatar');
      expect(sections.last.profileBioFunction, 'updateProfile');
    },
  );

  test('mixed source keeps browse tabs and groups only dialog tools', () {
    final sections = SourceShellSection.fromPluginInfo({
      'function': [
        listFunction('ranking', '排行榜', 'getRankingData'),
        {
          'id': 'categories',
          'title': '分类',
          'action': {
            'type': 'openPluginFunction',
            'payload': {'id': 'categories', 'presentation': 'page'},
          },
        },
        listFunction('latest', '最新', 'getLatestData'),
        {
          'id': 'cloudFavorite',
          'title': '云端收藏',
          'action': {'type': 'openCloudFavorite'},
        },
        {
          'id': 'tagRecommendations',
          'title': '标签推荐',
          'action': {
            'type': 'openPluginFunction',
            'payload': {'id': 'tagRecommendations', 'presentation': 'dialog'},
          },
        },
      ],
    }, 'source');

    expect(sections.map((section) => section.id), [
      'ranking',
      'categories',
      'latest',
      'cloudFavorite',
      'more',
    ]);
    expect(sections[1].functionId, 'categories');
    expect(sections[3].cloudFavorite, isTrue);
    expect(sections.last.actions.single.title, '标签推荐');
  });

  test('allows search-first launch only when no functions were declared', () {
    expect(SourceShellSection.canLaunch(null, const []), isFalse);
    expect(SourceShellSection.canLaunch({'function': []}, const []), isTrue);
    expect(
      SourceShellSection.canLaunch({
        'function': [
          {
            'title': '无效动作',
            'action': {'type': 'none'},
          },
        ],
      }, const []),
      isFalse,
    );
  });

  test('keeps one-off comic details as an action rather than a bottom tab', () {
    final sections = SourceShellSection.fromPluginInfo({
      'function': [
        listFunction('latest', '最新', 'getLatest'),
        {
          'id': 'random',
          'title': '随机漫画',
          'action': {
            'type': 'openComicInfo',
            'payload': {'comicId': 'random'},
          },
        },
      ],
    }, 'source');

    expect(sections.map((section) => section.id), ['latest', 'more']);
    expect(sections.last.actions.single.action['payload'], {
      'comicId': 'random',
      'source': 'source',
    });
  });
}
