import 'package:flutter_test/flutter_test.dart';
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
  test('builds ordered tabs from plugin list actions and replaces source', () {
    final sections = SourceShellSection.fromPluginInfo({
      'function': [
        listFunction('recommend', '漫画推荐', 'getHomeRecommend'),
        {'id': 'search', 'title': '搜索', 'action': {'type': 'openSearch'}},
        listFunction('newest', '全新上架', 'getHomeNewest'),
      ],
    }, 'current-source');

    expect(sections.map((section) => section.id), ['recommend', 'newest']);
    expect(sections.first.scene.from, 'current-source');
    expect(sections.last.scene.body.request?.fnPath, 'getHomeNewest');
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

    expect(sections.length, 1);
    expect(sections.single.title, '排行');
  });

  test('does not offer a source shell when there are no list functions', () {
    expect(SourceShellSection.fromPluginInfo({}, 'source'), isEmpty);
    expect(
      SourceShellSection.fromPluginInfo({
        'function': [
          {'id': 'settings', 'action': {'type': 'openPluginFunction'}},
        ],
      }, 'source'),
      isEmpty,
    );
  });
}
