import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/comic_read/cubit/image_size_cubit.dart';
import 'package:zephyr/page/comic_read/json/common_ep_info_json/common_ep_info_json.dart';
import 'package:zephyr/page/comic_read/method/image_size_cache_store.dart';
import 'package:zephyr/page/comic_read/method/prefetch_image_sizes.dart';
import 'package:zephyr/page/comic_read/widgets/layout/read_layout.dart';

class _Store extends ImageSizeCacheStore {
  _Store() : super(sourceTag: 'source', pageKeys: ['work/chapter/page']);
  final hydrated = Completer<Map<int, Size>>();
  final firstWrite = Completer<void>();
  final writes = <Map<int, Size>>[];
  @override
  Future<Map<int, Size>> readIndexedSizes({
    required List<String> pageKeys,
    required int count,
  }) => hydrated.future;
  @override
  Future<void> write({
    required List<String> pageKeys,
    required Map<int, Size> sizeCache,
    required Set<int> resolvedIndices,
    required int count,
  }) async {
    writes.add(Map.of(sizeCache));
    if (writes.length == 1) await firstWrite.future;
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  test('late header prefetch preserves a newer display measurement', () async {
    final store = _Store();
    final cubit = ImageSizeCubit.create(
      defaultWidth: 100,
      count: 1,
      sourceTag: 'source',
      pageKeys: ['work/chapter/page'],
      chapterOrder: 7,
      persistedCache: {},
      cacheStore: store,
    );
    final index = resolveStableSizeCacheIndex(
      chapterOrder: 7,
      localPageIndex: 0,
    );
    final headerSize = Completer<Size?>();
    var reads = 0;
    final prefetch = prefetchChapterImageSizes(
      imageSizeCubit: cubit,
      docs: [
        Doc(originalName: 'page', path: 'page.jpg', fileServer: '', id: 'page'),
      ],
      comicId: 'work',
      from: 'source',
      chapterId: 'chapter',
      chapterOrder: 7,
      contentWidth: 100,
      readCachedSize: (_) {
        reads++;
        return headerSize.future;
      },
    );
    expect(reads, 1);
    cubit.updateSize(index, const Size(80, 240));
    headerSize.complete(const Size(100, 300));
    await prefetch;
    expect(cubit.getSize(index).size, const Size(80, 240));
    store.firstWrite.complete();
    await cubit.close();
  });

  test('size prefetch resumes from the interrupted page after background', () async {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    addTearDown(
      () => binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
    );
    final store = _Store()..firstWrite.complete();
    final cubit = ImageSizeCubit.create(
      defaultWidth: 100,
      count: 3,
      sourceTag: 'source',
      pageKeys: ['first', 'second', 'third'],
      chapterOrder: 7,
      persistedCache: {},
      cacheStore: store,
    );
    addTearDown(cubit.close);
    final secondPage = Completer<Size?>();
    final reads = <String>[];
    final docs = [
      for (final id in ['first', 'second', 'third'])
        Doc(originalName: id, path: '$id.jpg', fileServer: '', id: id),
    ];

    Future<int> scan({int startPage = 0}) => prefetchChapterImageSizes(
      imageSizeCubit: cubit,
      docs: docs,
      comicId: 'work',
      from: 'source',
      chapterId: 'chapter',
      chapterOrder: 7,
      contentWidth: 100,
      startPage: startPage,
      readCachedSize: (doc) async {
        reads.add(doc.id);
        if (doc.id == 'first') return null;
        if (doc.id == 'second') return secondPage.future;
        return const Size(100, 400);
      },
    );

    final foreground = scan();
    await Future<void>.delayed(Duration.zero);
    expect(reads, ['first', 'second']);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    secondPage.complete(const Size(100, 300));
    final interruptedPage = await foreground;
    expect(interruptedPage, 1);
    expect(reads, ['first', 'second']);
    final secondIndex = resolveStableSizeCacheIndex(
      chapterOrder: 7,
      localPageIndex: 1,
    );
    expect(cubit.getSize(secondIndex).isCached, isFalse);

    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(await scan(startPage: interruptedPage), docs.length);
    expect(reads, ['first', 'second', 'second', 'third']);
    expect(cubit.getSize(secondIndex).size, const Size(100, 300));
  });

  test('a replaced reader rejects a late header and starts no more probes', () async {
    final store = _Store()..firstWrite.complete();
    final cubit = ImageSizeCubit.create(
      defaultWidth: 100,
      count: 2,
      sourceTag: 'source',
      pageKeys: ['first', 'second'],
      chapterOrder: 7,
      persistedCache: {},
      cacheStore: store,
    );
    addTearDown(cubit.close);
    final headerSize = Completer<Size?>();
    var ownsSession = true;
    var reads = 0;
    Future<int> scan() => prefetchChapterImageSizes(
      imageSizeCubit: cubit,
      docs: [
        for (final id in ['first', 'second'])
          Doc(originalName: id, path: '$id.jpg', fileServer: '', id: id),
      ],
      comicId: 'work',
      from: 'source',
      chapterId: 'chapter',
      chapterOrder: 7,
      contentWidth: 100,
      ownsReaderSession: () => ownsSession,
      readCachedSize: (_) {
        reads++;
        return headerSize.future;
      },
    );

    final oldReader = scan();
    expect(reads, 1);
    ownsSession = false;
    headerSize.complete(const Size(100, 300));
    expect(await oldReader, 0);
    expect(await scan(), 0);
    expect(reads, 1);
    expect(cubit.state.resolvedIndices, isEmpty);
  });

  test(
    'late hydration preserves a newer display measurement and close drains a busy final write',
    () async {
      final store = _Store();
      final cubit = ImageSizeCubit.create(
        defaultWidth: 100,
        count: 1,
        sourceTag: 'source',
        pageKeys: ['work/chapter/page'],
        chapterOrder: 7,
        cacheStore: store,
      );
      final index = resolveStableSizeCacheIndex(
        chapterOrder: 7,
        localPageIndex: 0,
      );
      cubit.updateSize(index, const Size(100, 200));
      store.hydrated.complete({0: const Size(200, 900)});
      await Future<void>.delayed(Duration.zero);
      expect(cubit.getSize(index).size, const Size(100, 200));
      final first = cubit.flushNow();
      expect(store.writes.single[0], const Size(100, 200));
      cubit.updateSize(index, const Size(100, 300));
      final closing = cubit.close();
      store.firstWrite.complete();
      await closing;
      await first;
      expect(store.writes.map((row) => row[0]), [
        const Size(100, 200),
        const Size(100, 300),
      ]);
      expect(cubit.isClosed, isTrue);
    },
  );

  test(
    'persisted dimensions follow current viewport width without decoding the image',
    () async {
      final store = _Store();
      final cubit = ImageSizeCubit.create(
        defaultWidth: 100,
        count: 1,
        sourceTag: 'source',
        pageKeys: ['work/chapter/page'],
        chapterOrder: 7,
        persistedCache: {0: const Size(200, 600)},
        cacheStore: store,
      );
      final index = resolveStableSizeCacheIndex(
        chapterOrder: 7,
        localPageIndex: 0,
      );
      expect(cubit.getSize(index).size, const Size(100, 300));
      await cubit.close();
      expect(store.writes, isEmpty);
    },
  );
}
