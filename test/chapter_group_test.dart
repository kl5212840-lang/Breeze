import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/comic_info/method/chapter_group.dart';

void main() {
  test(
    'folded chapter groups keep their identity when display order changes',
    () {
      const titles = ['卷一', '卷二', '卷一', '卷二'];
      final forward = splitLongChapterGroups(
        groupIndicesByTitle(titles.length, (i) => titles[i]),
      );
      final reverse = splitLongChapterGroups(
        groupIndicesByTitle(titles.length, (i) => titles[titles.length - 1 - i]),
      );
      final folded = {forward.first.collapseKey};
      expect(reverse.first.title, '卷二');
      expect(folded.contains(reverse.first.collapseKey), isFalse);
      expect(folded.contains(reverse.last.collapseKey), isTrue);
    },
  );

  test('split ranges stay distinct from source groups with the same label', () {
    final groups = splitLongChapterGroups([
      ChapterGroup(title: '卷一', items: List.generate(51, (i) => i)),
      ChapterGroup(title: '卷一 1-50', items: [51]),
    ]);
    expect(groups.first.title, groups.last.title);
    expect(groups.map((group) => group.collapseKey).toSet(), hasLength(3));
  });

  test(
    'long groups split in displayed order, including reversed and untitled groups',
    () {
      final input = [for (var i = 100; i >= 0; i--) i];
      final groups = splitLongChapterGroups([
        ChapterGroup(title: '卷一', items: input),
        ChapterGroup(title: '', items: [1, 2]),
      ]);
      expect(groups.map((g) => g.title), [
        '卷一 1-50',
        '卷一 51-100',
        '卷一 101-101',
        '',
      ]);
      expect(groups.expand((g) => g.items).take(101), input);
    },
  );
  test('顶层 groupTitle 去空白，缺省为空=不分组', () {
    expect(resolveChapterGroupTitle(groupTitle: '连载'), '连载');
    expect(resolveChapterGroupTitle(groupTitle: ' 单行本 '), '单行本');
    expect(resolveChapterGroupTitle(), '');
  });

  test('空组显示未分组文案', () {
    expect(chapterGroupDisplayTitle('', '未分组'), '未分组');
    expect(chapterGroupDisplayTitle('连载', '未分组'), '连载');
  });

  test('分组保持元素顺序且组按首次出现排序', () {
    final groups = groupChaptersByTitle<String>(const [
      'a1',
      'b1',
      'a2',
      'c1',
      'b2',
    ], (item) => item[0]);
    expect(groups.map((g) => g.title), ['a', 'b', 'c']);
    expect(groups[0].items, ['a1', 'a2']);
    expect(groups[1].items, ['b1', 'b2']);
    expect(groups[2].items, ['c1']);
  });

  test('空标题自成一组（调用方显示未分组）', () {
    final groups = groupChaptersByTitle<String>(const ['x', 'y'], (_) => '');
    expect(groups.length, 1);
    expect(groups.single.title, '');
    expect(groups.single.items, ['x', 'y']);
  });

  test('下标分组与通用分组一致且无中间 List 分配', () {
    const items = ['a1', 'b1', 'a2', 'c1', 'b2'];
    final indexed = groupIndicesByTitle(items.length, (i) => items[i][0]);
    expect(indexed.map((g) => g.title), ['a', 'b', 'c']);
    expect(indexed[0].items, [0, 2]);
    expect(indexed[1].items, [1, 4]);
    expect(indexed[2].items, [3]);
  });
}
