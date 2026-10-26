import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_library_store.dart';

ApiVideoItem film(String id) => ApiVideoItem(
  id: id,
  title: '作品$id',
  detailUrl: Uri.parse('https://www.ikunzy.com/voddetail/$id.html'),
);

ApiVideoItem series(List<String> labels, {String title = '作品7'}) =>
    ApiVideoItem(
      id: '7',
      title: title,
      detailUrl: Uri.parse('https://www.ikunzy.com/voddetail/7.html'),
      plannedEpisodes: 12,
      lines: [
        ApiVideoLine(
          id: 'ikm3u8',
          label: 'iKun',
          episodes: [
            for (final label in labels)
              ApiVideoEpisode(
                id: label,
                title: label,
                url: Uri.parse('https://cdn.example.test/$label.m3u8'),
                watchUrl: Uri.https('www.ikunzy.com', '/voddetail/7.html', {
                  'line': 'ikm3u8',
                  'episode': label,
                }),
              ),
          ],
        ),
      ],
    );

void main() {
  late VideoLibraryStore a, b;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    a = VideoLibraryStore(deviceId: 'A', storageKey: 'test.A');
    b = VideoLibraryStore(deviceId: 'B', storageKey: 'test.B');
  });
  tearDown(() {
    a.dispose();
    b.dispose();
  });
  test('favorite survives restart and supports multiple folders', () async {
    final first = await a.createFolder('ikun', '想看'),
        second = await a.createFolder('ikun', '科幻');
    await a.setFavorite('ikun', film('7'), true, folderIds: {first, second});
    final snapshot = await a.read();
    expect(snapshot.foldersOf(VideoLibraryStore.itemKey('ikun', '7')), {
      first,
      second,
    });
    final restarted = VideoLibraryStore(deviceId: 'A', storageKey: 'test.A');
    expect((await restarted.read()).contains('ikun', '7'), isTrue);
    restarted.dispose();
  });
  test(
    'folder rename is stable, duplicate names fail, deletion preserves films',
    () async {
      final id = await a.createFolder('ikun', '剧情');
      await a.setFavorite('ikun', film('7'), true, folderIds: {id});
      await a.renameFolder(id, '剧情佳作');
      await expectLater(a.createFolder('ikun', '剧情佳作'), throwsStateError);
      await a.deleteFolder(id);
      final snapshot = await a.read();
      expect(snapshot.contains('ikun', '7'), isTrue);
      expect(
        snapshot.foldersOf(VideoLibraryStore.itemKey('ikun', '7')),
        isEmpty,
      );
      expect(snapshot.folders[id]!.deleted, isTrue);
    },
  );
  test(
    'offline additions and independent memberships merge without lost folders',
    () async {
      final f = await a.createFolder('ikun', 'A夹');
      await a.setFavorite('ikun', film('7'), true, folderIds: {f});
      await b.merge(await a.read());
      final g = await b.createFolder('ikun', 'B夹');
      await b.assignFolders({VideoLibraryStore.itemKey('ikun', '7')}, {f, g});
      await a.renameFolder(f, 'A新名');
      final left = await a.read(), right = await b.read();
      final merged = left.merged(right), reverse = right.merged(left);
      expect(
        jsonEncode(merged.toJson()),
        jsonEncode(merged.merged(reverse).toJson()),
      );
      expect(merged.foldersOf(VideoLibraryStore.itemKey('ikun', '7')), {f, g});
      expect(merged.folders[f]!.data['name'], 'A新名');
    },
  );
  test(
    'removal tombstone prevents stale resurrection and re-add is unfiled',
    () async {
      final folder = await a.createFolder('ikun', '待看');
      await a.setFavorite('ikun', film('7'), true, folderIds: {folder});
      final old = await a.read();
      await a.setFavorite('ikun', film('7'), false);
      await a.merge(old);
      expect((await a.read()).contains('ikun', '7'), isFalse);
      await a.setFavorite('ikun', film('7'), true);
      expect(
        (await a.read()).foldersOf(VideoLibraryStore.itemKey('ikun', '7')),
        isEmpty,
      );
    },
  );
  test(
    'batch folder moves, source isolation and corrupt backup safety',
    () async {
      await a.setFavorite('ikun', film('7'), true);
      await a.setFavorite('ikun', film('8'), true);
      await a.setFavorite('hanime', film('7'), true);
      final folder = await a.createFolder('ikun', '精选');
      final keys = {
        '7',
        '8',
      }.map((id) => VideoLibraryStore.itemKey('ikun', id)).toSet();
      await a.assignFolders(keys, {folder});
      await a.removeFavorites(keys);
      expect((await a.read()).itemsFor('ikun'), isEmpty);
      expect((await a.read()).itemsFor('hanime'), hasLength(1));
      final raw = (await a.read()).toJson();
      raw['version'] = 99;
      expect(() => VideoLibrarySnapshot.fromJson(raw), throwsFormatException);
      expect((await a.read()).contains('hanime', '7'), isTrue);
    },
  );
  test(
    'tracking detects new episode identities, not metadata edits or reordering',
    () async {
      final key = VideoLibraryStore.itemKey('ikun', '7');
      await a.setFollow('ikun', series(['1', '2']), true);
      final added = (await a.read()).itemsFor('ikun').single.clock;
      await a.observeItems('ikun', [
        series(['2', '1'], title: '名称修正'),
      ]);
      expect((await a.read()).newEpisodes(key), 0);
      await a.observeItems('ikun', [
        series(['1', '2', '3']),
      ]);
      expect((await a.read()).newEpisodes(key), 1);
      expect(
        (await a.read()).itemsFor('ikun').single.clock,
        added,
        reason: 'Source refresh must not change date added',
      );
      await a.observeItems('ikun', [], missing: {'7'});
      expect(
        (await a.read()).newEpisodes(key),
        1,
        reason: 'Missing source response does not erase an existing badge',
      );
      await a.observeItems('ikun', [
        series(['1', '2', '3']),
      ], acknowledge: true);
      expect((await a.read()).newEpisodes(key), 0);
    },
  );
  test(
    'unfollow and favorite removal cannot be undone by pending update checks',
    () async {
      final key = VideoLibraryStore.itemKey('ikun', '7');
      await a.setFollow('ikun', series(['1', '2']), true);
      await a.setFollow('ikun', series(['1', '2']), false);
      await a.observeItems('ikun', [
        series(['1', '2', '3']),
      ]);
      expect((await a.read()).follows(key), false);
      expect((await a.read()).contains('ikun', '7'), true);
      await a.setFollow('ikun', series(['1', '2']), true);
      final stale = await a.read();
      await a.setFavorite('ikun', series(['1', '2']), false);
      await a.merge(stale);
      await a.observeItems('ikun', [
        series(['1', '2', '3']),
      ]);
      await a.setFavorite('ikun', film('7'), true);
      expect((await a.read()).follows(key), false);
    },
  );
  test(
    'following and update baselines survive sync and folder changes',
    () async {
      final key = VideoLibraryStore.itemKey('ikun', '7');
      await a.setFollow('ikun', series(['1']), true);
      final folder = await a.createFolder('ikun', '在追');
      await a.assignFolders({key}, {folder});
      await a.observeItems('ikun', [
        series(['1', '2']),
      ]);
      await b.merge(await a.read());
      expect((await b.read()).follows(key), true);
      expect((await b.read()).newEpisodes(key), 1);
      expect((await b.read()).foldersOf(key), {folder});
    },
  );
}
