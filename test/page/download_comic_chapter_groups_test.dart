import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/donwload_task/view/download_comic_chapter_groups.dart';
import 'package:zephyr/page/download/models/unified_comic_download.dart';

UnifiedComicDownloadStoredChapter _chapter(
  int order,
  String name, {
  String volume = '',
}) => UnifiedComicDownloadStoredChapter(
  id: '$order:$name',
  name: name,
  order: order,
  groupTitle: volume,
);

void main() {
  test('splits each source volume after 30 actual downloads', () {
    final chapters = [
      _chapter(200, '第1话', volume: '第二卷'),
      for (var number = 32; number >= 1; number--)
        _chapter(number, '第$number话', volume: ' 第一卷 '),
    ];
    final original = [...chapters];
    final groups = groupDownloadedComicChapters(chapters);

    expect(groups.map((group) => group.volume), ['第一卷', '第一卷', '第二卷']);
    expect(groups.map((group) => group.chapters.length), [30, 2, 1]);
    expect(groups[0].title(fallback: '已下载章节'), '第1话–第30话 · 第一卷');
    expect(groups[1].title(fallback: '已下载章节'), '第31话–第32话 · 第一卷');
    expect(groups[2].title(fallback: '已下载章节'), '第1话 · 第二卷');
    expect(groups.map((group) => group.subtitle(chinese: true)), [
      '已下载30话',
      '已下载2话',
      '已下载1话',
    ]);
    expect(chapters, original);
    expect(() => groups.first.chapters.clear(), throwsUnsupportedError);
  });

  test('uses directory order and keeps source order for tied positions', () {
    final groups = groupDownloadedComicChapters([
      _chapter(5, '侧篇', volume: '附录'),
      _chapter(2, '序曲', volume: '正篇'),
      _chapter(2, '过场', volume: '正篇'),
      _chapter(3, '片段', volume: '附录'),
      _chapter(4, '终章', volume: '正篇'),
    ]);

    expect(groups.map((group) => group.volume), ['正篇', '附录']);
    expect(groups.first.chapters.map((chapter) => chapter.name), [
      '序曲',
      '过场',
      '终章',
    ]);
    expect(groups.last.chapters.map((chapter) => chapter.name), ['片段', '侧篇']);
    expect(groups.first.title(fallback: '已下载章节'), '序曲–终章 · 正篇');
  });

  test('uses real titles for gaps, duplicates, specials, and blank names', () {
    for (final (titles, title, subtitle) in [
      (
        ['Chapter 1', 'Chapter 3'],
        'Chapter 1–Chapter 3',
        '2 downloaded chapters · gaps',
      ),
      (['Chapter 1', 'Chapter 1'], 'Chapter 1', '2 downloaded chapters'),
      (['Chapter 1', 'Special'], 'Chapter 1–Special', '2 downloaded chapters'),
      (['Chapter 1', '2'], 'Chapter 1–2', '2 downloaded chapters'),
      (
        ['', 'Chapter 2', 'Chapter 3', ''],
        'Chapter 2–Chapter 3',
        '4 downloaded chapters',
      ),
    ]) {
      final group = groupDownloadedComicChapters([
        for (final (index, name) in titles.indexed) _chapter(index, name),
      ]).single;

      expect(group.title(fallback: 'Downloaded chapters'), title);
      expect(group.subtitle(chinese: false), subtitle);
    }

    final blank = groupDownloadedComicChapters([_chapter(1, '')]).single;
    expect(blank.title(fallback: 'Downloaded chapters'), 'Downloaded chapters');
    expect(blank.subtitle(chinese: false), '1 downloaded chapter');
    expect(groupDownloadedComicChapters([]), isEmpty);
  });

  test(
    'placeholder volumes retain identity and expose real boundary names',
    () {
      for (final volume in ['默认', '默認', 'DEFAULT']) {
        final groups = groupDownloadedComicChapters([
          for (var index = 0; index < 59; index++)
            _chapter(index, '$index', volume: volume),
          _chapter(59, '后记', volume: volume),
        ]);
        expect(groups.map((group) => group.title(fallback: '已下载章节')), [
          '0–29',
          '30–后记',
        ]);
        expect(groups.map((group) => group.subtitle(chinese: true)), [
          '已下载30话',
          '已下载30话',
        ]);
        expect(groups.map((group) => group.key), [
          '${volume.length}:$volume:0',
          '${volume.length}:$volume:30',
        ]);
      }
    },
  );

  test('anchors are scoped to volume and offset as downloads grow', () {
    final chapters = [
      for (var number = 1; number <= 31; number++)
        _chapter(number, '$number', volume: '卷:A'),
      _chapter(60, '1', volume: '卷:B'),
    ];
    final before = groupDownloadedComicChapters(chapters);
    final after = groupDownloadedComicChapters([
      ...chapters,
      _chapter(32, '32', volume: '卷:A'),
    ]);

    expect(before.map((group) => group.key).toSet(), hasLength(3));
    expect(after.map((group) => group.key), before.map((group) => group.key));
  });
}
