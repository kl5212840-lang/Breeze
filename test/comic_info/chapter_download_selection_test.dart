import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/comic_info/widgets/chapter_download_selection.dart';
import 'package:zephyr/page/comic_info/cubit/episode_download_status_cubit.dart';
import 'package:zephyr/page/download/models/download_chapter.dart';

DownloadChapter chapter(
  String id, {
  String? request,
  int order = 1,
  String group = '',
}) => DownloadChapter(
  id: id,
  displayName: id,
  order: order,
  requestId: request,
  groupTitle: group,
  extern: const {},
  images: const [],
);
void main() {
  final chapters = [
    chapter('a', group: '第一卷'),
    chapter('b', group: '第一卷'),
    chapter('c', group: '第二卷'),
    chapter('d', group: '第二卷'),
  ];
  test(
    'selection is empty by default and ranges use catalog positions across repeated group orders',
    () {
      final selection = ChapterDownloadSelection(chapters),
          eligible = {'a', 'b', 'c', 'd'};
      expect(selection.selected, isEmpty);
      expect(selection.applyRange('2', '4', eligible: eligible), isTrue);
      expect(selection.selected.map((c) => c.id), ['b', 'c', 'd']);
      expect(selection.selected.map((c) => c.order), [
        1,
        1,
        1,
      ], reason: 'Repeated plugin order never merges chapter identities');
      selection.clear();
      expect(selection.selected, isEmpty);
      selection.selectAll(chapters, eligible);
      expect(selection.selected.map((c) => c.id), ['a', 'b', 'c', 'd']);
    },
  );
  test(
    'scoped selection and numeric ranges accumulate eligible identities',
    () {
      final catalog = List.generate(
        102,
        (i) => chapter('id-$i', order: i % 50, group: i < 51 ? 'A' : 'B'),
      ).reversed.toList();
      final selection = ChapterDownloadSelection(catalog),
          eligible = catalog.map((c) => c.id).toSet()..remove('id-101');
      selection.selectAll(catalog.take(50), eligible);
      expect(selection.selectedIds.length, 49);
      selection.selectAll(catalog.skip(50).take(50), eligible);
      expect(selection.selectedIds.length, 99);
      selection.deselectAll(catalog.take(50), eligible);
      expect(selection.selectedIds.length, 50);
      selection.selectAll(catalog.take(50), eligible);
      expect(selection.applyRange('101', '102', eligible: eligible), isTrue);
      expect(
        selection.selected.map((c) => c.id),
        catalog.skip(1).map((c) => c.id),
      );
      selection.clear();
      expect(selection.selectedIds, isEmpty);
    },
  );
  test(
    'reverse snapshot retains user order, skips unavailable chapters and rejects invalid ranges without changing the draft',
    () {
      final selection = ChapterDownloadSelection(chapters.reversed),
          eligible = {'a', 'b', 'd'};
      expect(selection.applyRange('1', '3', eligible: eligible), isTrue);
      expect(selection.selected.map((c) => c.id), ['d', 'b']);
      for (final input in [
        ('0', '2'),
        ('3', '2'),
        ('1', '5'),
        ('x', '2'),
        ('', '2'),
      ]) {
        expect(
          selection.applyRange(input.$1, input.$2, eligible: eligible),
          isFalse,
        );
        expect(selection.selected.map((c) => c.id), ['d', 'b']);
      }
      selection.retainEligible({'b'});
      expect(selection.selected.single.id, 'b');
    },
  );
  test(
    'download status matches actual chapter/request aliases, never a coincident order number',
    () {
      const state = EpisodeDownloadStatusState(
        downloadedIds: {'1', 'logical-old'},
      );
      expect(
        state.isDownloaded(
          chapter('unrelated', request: 'request-new', order: 1),
        ),
        isFalse,
      );
      expect(state.isDownloaded(chapter('logical-old', order: 99)), isTrue);
      expect(
        state.isDownloaded(chapter('logical-new', request: '1', order: 99)),
        isTrue,
      );
    },
  );
}
