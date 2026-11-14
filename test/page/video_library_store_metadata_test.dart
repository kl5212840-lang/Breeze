import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_library_store.dart';

void main() {
  final home = Uri.parse('https://example.org/');
  ApiVideoItem item({
    String description = '',
    String genres = '',
    String title = '作品',
    String year = '',
    String remarks = '',
    Uri? cover,
    bool episodes = false,
  }) => ApiVideoItem(
    id: '1',
    title: title,
    detailUrl: home.resolve('/detail/1'),
    description: description,
    genres: genres,
    year: year,
    remarks: remarks,
    coverUrl: cover,
    lines: [
      if (episodes)
        ApiVideoLine(
          id: 'line',
          label: '线路',
          episodes: [
            for (final id in ['1', '2'])
              ApiVideoEpisode(
                id: id,
                title: '第$id集',
                url: home.resolve('/$id.m3u8'),
                watchUrl: home.resolve('/play/$id'),
              ),
          ],
        ),
    ],
  );
  late VideoLibraryStore store;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = VideoLibraryStore(
      deviceId: 'metadata',
      storageKey: 'store.metadata',
    );
  });
  tearDown(() => store.dispose());

  test('opening details also updates an ordinary saved film', () async {
    await store.setFavorite('source', item(), true);
    await store.observeDetails('source', [
      item(description: '详情简介', genres: '奇幻'),
    ], acknowledge: true);
    final saved = (await store.read()).itemsFor('source').single.item;
    expect(saved.description, '详情简介');
    expect(saved.genres, '奇幻');
  });

  test(
    'equal public metadata is a no-op and preserves date and folders',
    () async {
      final full = item(description: '详情简介', genres: '奇幻');
      final folder = await store.createFolder('source', '在看');
      await store.setFavorite('source', full, true, folderIds: {folder});
      final before = await store.read();
      var notifications = 0;
      store.addListener(() => notifications++);
      await store.observeDetails('source', [full]);
      final after = await store.read();
      expect(after.toJson(), before.toJson());
      expect(notifications, 0);
    },
  );

  test('full-detail explicit empty values clear old public metadata', () async {
    await store.setFavorite(
      'source',
      item(
        description: '旧简介',
        genres: '旧题材',
        year: '2026',
        remarks: '旧状态',
        cover: home.resolve('/old-cover.jpg'),
      ),
      true,
    );
    await store.observeDetails('source', [item(title: '权威新标题')]);
    final saved = (await store.read()).itemsFor('source').single.item;
    expect(saved.title, '权威新标题');
    expect(saved.description, isEmpty);
    expect(saved.genres, isEmpty);
    expect(saved.year, isEmpty);
    expect(saved.remarks, isEmpty);
    expect(saved.coverUrl, isNull);
  });

  test(
    'observing details neither imports nor resurrects deleted favorites',
    () async {
      await store.setFavorite('source', item(), true);
      await store.setFavorite('source', item(), false);
      final before = await store.read();
      var notifications = 0;
      store.addListener(() => notifications++);
      await store.observeDetails('source', [item(description: '不复活')]);
      await store.observeDetails('other', [item(description: '不跨来源')]);
      expect((await store.read()).toJson(), before.toJson());
      expect(notifications, 0);
    },
  );

  test('acknowledging details updates a follow baseline only once', () async {
    final series = item(episodes: true, description: '详情');
    final key = VideoLibraryStore.itemKey('source', '1');
    await store.setFollow('source', series, true);
    await store.observeDetails('source', [series], acknowledge: true);
    final before = await store.read();
    var notifications = 0;
    store.addListener(() => notifications++);
    await store.observeDetails('source', [series], acknowledge: true);
    expect((await store.read()).toJson(), before.toJson());
    expect((await store.read()).newEpisodes(key), 0);
    expect(notifications, 0);
  });

  test(
    'explicit empty detail lines mark a followed work unavailable once',
    () async {
      final key = VideoLibraryStore.itemKey('source', '1');
      await store.setFollow('source', item(episodes: true), true);
      await store.observeDetails('source', [item()], acknowledge: true);
      expect((await store.read()).tracking[key]!.data['available'], false);
      final before = await store.read();
      var notifications = 0;
      store.addListener(() => notifications++);
      await store.observeDetails('source', [item()], acknowledge: true);
      expect((await store.read()).toJson(), before.toJson());
      expect(notifications, 0);
    },
  );
}
