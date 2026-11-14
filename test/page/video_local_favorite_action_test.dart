import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_local_favorite_action.dart';

NativePlaybackSession session(String id) => NativePlaybackSession(
  title: '公开作品$id',
  watchUrl: Uri.parse('https://hanime1.me/watch?v=$id&private=do-not-save'),
  coverUrl: Uri.parse('https://images.test/cover.jpg'),
  description: '公开简介',
  tags: const ['动画'],
  sources: [
    NativePlaybackSource(
      url: Uri.parse('https://secret-media.test/video.mp4?token=do-not-save'),
      label: '媒体',
      headers: const {'Cookie': 'do-not-save'},
    ),
  ],
);

class SlowFavoriteStore extends VideoLibraryStore {
  SlowFavoriteStore() : super(deviceId: 'test', storageKey: 'slow-local');
  final gate = Completer<void>();
  int writes = 0;
  @override
  Future<void> setFavorite(
    String source,
    ApiVideoItem item,
    bool favorite, {
    Set<String>? folderIds,
  }) async {
    writes++;
    await gate.future;
    await super.setFavorite(source, item, favorite, folderIds: folderIds);
  }
}

class RecoveringStore extends VideoLibraryStore {
  RecoveringStore() : super(deviceId: 'test', storageKey: 'read-recovery');
  bool failing = true;
  @override
  Future<VideoLibrarySnapshot> read() async {
    if (failing) throw StateError('test read failed');
    return super.read();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'one tap saves public metadata and one tap removes without dialogs',
    (tester) async {
      final store = VideoLibraryStore(
        deviceId: 'test',
        storageKey: 'local-action',
      );
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoLocalFavoriteAction(
              source: 'hanime-plugin',
              session: session('42'),
              store: store,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final action = find.byKey(const ValueKey('video.local-favorite'));
      expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text(t.videoSource.localSaved), findsOneWidget);
      final snapshot = await store.read();
      expect(snapshot.contains('hanime-plugin', '42'), isTrue);
      final saved = snapshot.itemsFor('hanime-plugin').single.item;
      expect(saved.detailUrl.toString(), 'https://hanime1.me/watch?v=42');
      expect(saved.description, '公开简介');
      expect(saved.coverUrl?.host, 'images.test');
      final serialized = jsonEncode(snapshot.toJson());
      expect(serialized, isNot(contains('secret-media')));
      expect(serialized, isNot(contains('do-not-save')));
      expect(serialized, isNot(contains('Cookie')));
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect((await store.read()).contains('hanime-plugin', '42'), isFalse);
      expect(find.text(t.videoSource.localFavorites), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'same local id in a different source does not share favorite state',
    (tester) async {
      final store = VideoLibraryStore(
        deviceId: 'test',
        storageKey: 'source-action',
      );
      addTearDown(store.dispose);
      var source = 'a';
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, set) {
                update = set;
                return VideoLocalFavoriteAction(
                  source: source,
                  session: session('42'),
                  store: store,
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('video.local-favorite')));
      await tester.pumpAndSettle();
      update(() => source = 'b');
      await tester.pumpAndSettle();
      expect(find.text(t.videoSource.localFavorites), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('video.local-favorite')));
      await tester.pumpAndSettle();
      expect((await store.read()).contains('a', '42'), isTrue);
      expect((await store.read()).contains('b', '42'), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rapid second tap cannot enqueue a second favorite write', (
    tester,
  ) async {
    final store = SlowFavoriteStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoLocalFavoriteAction(
            source: 'a',
            session: session('42'),
            store: store,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final action = find.byKey(const ValueKey('video.local-favorite'));
    await tester.tap(action);
    await tester.pump();
    await tester.tap(action);
    expect(store.writes, 1);
    store.gate.complete();
    await tester.pumpAndSettle();
    expect((await store.read()).contains('a', '42'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'unknown local state retries reading before allowing a mutation',
    (tester) async {
      final store = RecoveringStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoLocalFavoriteAction(
              source: 'a',
              session: session('42'),
              store: store,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(t.common.loadingFailed), findsOneWidget);
      store.failing = false;
      await tester.tap(find.byKey(const ValueKey('video.local-favorite')));
      await tester.pumpAndSettle();
      expect((await store.read()).contains('a', '42'), isFalse);
      expect(find.text(t.common.loadingFailed), findsNothing);
      await tester.tap(find.byKey(const ValueKey('video.local-favorite')));
      await tester.pumpAndSettle();
      expect((await store.read()).contains('a', '42'), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
