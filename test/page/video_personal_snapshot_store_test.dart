import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/page/video/video_personal_snapshot_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'survives recreation, isolates owner/page, excludes credentials and forms',
    () async {
      final owner = Uri.parse('https://hanime1.me/user/1');
      final page = owner.resolve('/user/1/likes');
      final key = VideoPersonalSnapshotStore.scope('hanime', owner, page);
      final store = VideoPersonalSnapshotStore(cacheSource: 'hanime');
      await store.write(key, {
        'account': {'cookie': 'private'},
        'playlistEditor': {'token': 'private'},
        'videos': [
          {
            'title': 'A',
            'watchUrl': 'https://hanime1.me/watch?v=1',
            'token': 'private',
            'tags': ['tag'],
          },
        ],
        'paging': {'currentPage': 1, 'totalPages': 3, 'token': 'private'},
      }, store.generation);
      final restored = VideoPersonalSnapshotStore(cacheSource: 'hanime');
      final snapshot = await restored.read(key);
      expect(snapshot?['videos'], [
        {
          'title': 'A',
          'watchUrl': 'https://hanime1.me/watch?v=1',
          'tags': ['tag'],
        },
      ]);
      expect(snapshot?.containsKey('account'), false);
      expect(snapshot?.containsKey('playlistEditor'), false);
      expect(
        await restored.read(
          VideoPersonalSnapshotStore.scope('other', owner, page),
        ),
        null,
      );
      expect(
        await restored.read(
          VideoPersonalSnapshotStore.scope(
            'hanime',
            owner.resolve('/user/2'),
            page,
          ),
        ),
        null,
      );
      expect(
        await restored.read(
          VideoPersonalSnapshotStore.scope(
            'hanime',
            owner,
            page.replace(queryParameters: {'page': '2'}),
          ),
        ),
        null,
      );
      expect(
        PortablePreferences.owns(
          '${VideoPersonalSnapshotStore.prefix}${Uri.encodeComponent(key)}',
        ),
        false,
      );
    },
  );
  test('invalidation fences late writes while retaining stale cards', () async {
    final store = VideoPersonalSnapshotStore(cacheSource: 'hanime');
    const key =
        'plugin|hanime|https://hanime1.me/user/1|https://hanime1.me/user/1/saves';
    await store.write(key, {
      'videos': [
        {'title': 'old'},
      ],
    }, store.generation);
    final pendingEpoch = store.generation;
    store.invalidate();
    await store.write(key, {
      'videos': [
        {'title': 'wrong account'},
      ],
    }, pendingEpoch);
    final cached = await store.read(key);
    expect((cached?['videos'] as List).single['title'], 'old');
    expect(store.fresh(cached!), false);
  });
  test(
    'oversized complete pages cannot silently replace a valid page',
    () async {
      final store = VideoPersonalSnapshotStore(cacheSource: 'hanime');
      const key = 'plugin|hanime|owner|likes';
      await store.write(key, {
        'videos': [
          {'title': 'valid'},
        ],
      }, store.generation);
      await store.write(key, {
        'videos': List.generate(161, (i) => {'title': '$i'}),
      }, store.generation);
      expect((await store.read(key))?['videos'], [
        {'title': 'valid'},
      ]);
    },
  );

  test('disk cleanup finds unopened sources and preserves other data', () async {
    final prefs = await SharedPreferences.getInstance();
    final a =
        '${VideoPersonalSnapshotStore.prefix}${Uri.encodeComponent('plugin|sourceA|owner|likes')}';
    final b =
        '${VideoPersonalSnapshotStore.prefix}${Uri.encodeComponent('plugin|sourceB|owner|likes')}';
    await prefs.setString(a, '{"videos":[]}');
    await prefs.setString(b, '{"videos":[]}');
    await prefs.setString('private.account.sourceA', 'protected');
    await VideoPersonalSnapshotStore.clearDisk(source: 'sourceA');
    expect(prefs.containsKey(a), false);
    expect(prefs.containsKey(b), true);
    expect(prefs.getString('private.account.sourceA'), 'protected');
    await VideoPersonalSnapshotStore.clearDisk();
    expect(prefs.containsKey(b), false);
    expect(prefs.getString('private.account.sourceA'), 'protected');
  });
}
