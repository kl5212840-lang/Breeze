import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/comic_read/controller/reader_image_prefetch_controller.dart';
import 'package:zephyr/page/comic_read/bloc/page_bloc.dart';
import 'package:zephyr/page/comic_read/json/common_ep_info_json/common_ep_info_json.dart';
import 'package:zephyr/page/comic_read/model/normal_comic_ep_info.dart';
import 'package:zephyr/page/comic_read/widgets/modes/read_mode_utils.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';

ReadModeEntry image(int page, {String chapter = 'logical'}) =>
    ReadModeEntry.image(
      doc: Doc(
        originalName: '$page',
        path: '$page.jpg',
        fileServer: '',
        id: '$page',
      ),
      chapterId: chapter,
      chapterOrder: 1,
      chapterTitle: '',
      chapterPageIndex: page,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'a completed prefetch cannot suppress a new account generation',
    () async {
      const source = 'reader-prefetch-session-fixture';
      var reads = 0;
      final controller = ReaderImagePrefetchController(
        load: (_, _, _) async {
          reads++;
          return 'cached';
        },
      );
      Future<void> warm() => controller.prefetch(
        entries: [image(1)],
        comicId: 'work',
        from: source,
        count: 1,
      );
      await warm();
      await warm();
      expect(reads, 1);
      pluginSessionWriteFence.advance(source);
      await warm();
      expect(reads, 2);
      controller.dispose();
    },
  );
  test(
    'rapid scroll replaces queued ten-image windows with one bounded worker',
    () async {
      final started = <int>[];
      final gates = <Completer<String>>[];
      final prefetch = ReaderImagePrefetchController(
        load: (entry, source, work) {
          expect(source, 'source');
          expect(work, 'work');
          started.add(entry.chapterPageIndex!);
          final gate = Completer<String>();
          gates.add(gate);
          return gate.future;
        },
      );
      final first = prefetch.prefetch(
        entries: List.generate(10, image),
        comicId: 'work',
        from: 'source',
        count: 10,
      );
      expect(started, [0]);
      final latest = prefetch.prefetch(
        entries: [image(20), image(21)],
        comicId: 'work',
        from: 'source',
        count: 2,
      );
      gates[0].complete('cached');
      await Future<void>.delayed(Duration.zero);
      expect(started, [0, 20]);
      prefetch.setActive(false);
      gates[1].complete('cached');
      await latest;
      await first;
      expect(started, [0, 20]);
      prefetch.setActive(true);
      final resumed = prefetch.prefetch(
        entries: [image(20), image(21)],
        comicId: 'work',
        from: 'source',
        count: 2,
      );
      expect(started, [0, 20, 21]);
      prefetch.dispose();
      gates[2].complete('cached');
      await resumed;
      await prefetch.prefetch(
        entries: [image(22)],
        comicId: 'work',
        from: 'source',
        count: 1,
      );
      expect(started, [0, 20, 21]);
    },
  );

  test(
    'failed image can retry and shared storage does not merge logical chapters',
    () async {
      final chapters = <String>[];
      var failed = true;
      final controller = ReaderImagePrefetchController(
        load: (entry, _, __) async {
          chapters.add(entry.chapterId!);
          if (failed) throw StateError('offline');
          return 'cached';
        },
      );
      await controller.prefetch(
        entries: [image(1)],
        comicId: 'work',
        from: 'source',
        count: 1,
      );
      failed = false;
      await controller.prefetch(
        entries: [image(1)],
        comicId: 'work',
        from: 'source',
        count: 1,
      );
      await controller.prefetch(
        entries: [image(1, chapter: 'other')],
        comicId: 'work',
        from: 'source',
        count: 1,
      );
      expect(chapters, ['logical', 'logical', 'other']);
      controller.dispose();
    },
  );

  test(
    'a newer chapter request wins even while the older request is pending',
    () async {
      final gates = <String, Completer<NormalComicEpInfo>>{};
      final bloc = PageBloc(
        loadPage: (event) => (gates[event.chapterId] = Completer()).future,
      );
      PageEvent open(String chapter) => PageEvent(
        'work',
        1,
        chapter,
        chapter,
        '',
        chapter,
        {},
        'source',
        ComicEntryType.normal,
      );
      bloc.add(open('old'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(open('new'));
      await Future<void>.delayed(Duration.zero);
      expect(gates.keys, ['old', 'new']);
      final ready = bloc.stream.firstWhere(
        (state) => state.status == PageStatus.success,
      );
      gates['new']!.complete(NormalComicEpInfo(epId: 'new'));
      expect((await ready).epInfo!.epId, 'new');
      gates['old']!.complete(NormalComicEpInfo(epId: 'old'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.epInfo!.epId, 'new');
      await bloc.close();
    },
  );
}
