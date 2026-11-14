import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_community_page.dart';
import 'package:zephyr/page/video/video_comment_drafts.dart';
import 'package:zephyr/page/video/video_engagement.dart';
import 'package:zephyr/page/video/video_site_action_models.dart';
import 'package:zephyr/page/video/video_playlist_editor.dart';
import 'package:zephyr/page/video/video_site_operations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/video/video_local_favorite_action.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/native_playback_session.dart';

class _Operations extends VideoSiteOperations {
  _Operations(this.respond, {super.drafts})
    : super(
        page: Uri.parse('https://hanime1.me/watch?v=42'),
        evaluate: (_) async => null,
      );
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
  respond;
  final calls = <String>[];
  final payloads = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> run(
    String operation, [
    Map<String, dynamic> payload = const {},
  ]) {
    calls.add(operation);
    payloads.add(Map<String, dynamic>.from(payload));
    return respond(operation, payload);
  }
}

class _Engagement extends StatefulWidget {
  const _Engagement({required this.operations, required this.onLogin});
  final VideoSiteOperations operations;
  final VoidCallback onLogin;
  @override
  State<_Engagement> createState() => _EngagementState();
}

class _EngagementState extends State<_Engagement> {
  late VideoEngagementController controller;
  void create() {
    controller = VideoEngagementController(
      operations: widget.operations,
      onLogin: widget.onLogin,
    );
    unawaited(controller.load());
  }

  @override
  void initState() {
    super.initState();
    create();
  }

  @override
  void didUpdateWidget(covariant _Engagement old) {
    super.didUpdateWidget(old);
    if (old.operations != widget.operations) {
      controller.dispose();
      create();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      VideoFollowButton(controller: controller),
      VideoEngagement(
        controller: controller,
        onFavorite: () {},
        onShare: (_) {},
      ),
      VideoEngagementStatus(controller: controller),
    ],
  );
}

void main() {
  Map<String, dynamic> interaction({bool liked = false}) => {
    'status': 'ok',
    'signedIn': true,
    'canLike': true,
    'canFollow': true,
    'canCreatePlaylist': true,
    'liked': liked,
    'following': false,
  };

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'paired votes and combined favorites stay usable at 320pt scale $scale',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = VideoLibraryStore(
          deviceId: 'fixture',
          storageKey: 'paired-favorites-$scale',
        );
        addTearDown(store.dispose);
        final operations = _Operations((_, __) async => interaction());
        addTearDown(operations.dispose);
        var siteOpens = 0;
        final controller = VideoEngagementController(
          operations: operations,
          onLogin: () {},
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: VideoEngagement(
                    controller: controller,
                    onFavorite: () => siteOpens++,
                    onDownload: () {},
                    onShare: (_) {},
                    compact: true,
                    localFavorite: VideoLocalFavoriteAction(
                      source: 'hanime',
                      store: store,
                      detailAction: true,
                      session: NativePlaybackSession(
                        title: 'Work',
                        watchUrl: operations.page,
                        sources: const [],
                        description: '',
                        tags: const [],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final favorite = find.byKey(const ValueKey('video-favorite'));
        final site = find.byKey(const ValueKey('video.site-favorite'));
        final local = find.byKey(const ValueKey('video.local-favorite'));
        final like = find.byKey(const ValueKey('video-like'));
        final dislike = find.byKey(const ValueKey('video-dislike'));
        final vote = find.byKey(const ValueKey('video-vote-actions'));
        final download = find.byKey(const ValueKey('video-download'));
        final share = find.byKey(const ValueKey('video-share'));
        expect(find.descendant(of: vote, matching: like), findsOneWidget);
        expect(find.descendant(of: vote, matching: dislike), findsOneWidget);
        for (final action in [like, dislike, favorite, download, share]) {
          expect(tester.getSize(action).width, greaterThanOrEqualTo(44));
          expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
        }
        expect(tester.getRect(like).top, tester.getRect(dislike).top);
        if (scale == 1) {
          for (final action in [favorite, download, share]) {
            expect(tester.getRect(action).top, tester.getRect(like).top);
          }
        }
        expect(site, findsNothing);
        expect(local, findsNothing);
        await tester.tap(favorite);
        await tester.pumpAndSettle();
        expect(find.text(t.videoCommunity.siteFavorite), findsOneWidget);
        expect(find.text(t.videoSource.localFavorites), findsOneWidget);
        await tester.tap(local);
        await tester.pumpAndSettle();
        expect((await store.read()).contains('hanime', '42'), isTrue);
        expect(siteOpens, 0);
        await tester.tap(site);
        await tester.pumpAndSettle();
        expect(siteOpens, 1);
        expect(local, findsNothing);
        expect(
          find.descendant(
            of: favorite,
            matching: find.byIcon(Icons.star_rounded),
          ),
          findsOneWidget,
        );
        await tester.tap(favorite);
        await tester.pumpAndSettle();
        await tester.tap(local);
        await tester.pumpAndSettle();
        expect((await store.read()).contains('hanime', '42'), isFalse);
        expect(siteOpens, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  test(
    'drafts follow the confirmed header account and invalidate old services on a change',
    () {
      final store = VideoCommentDraftStore();
      final first = Uri.parse('https://hanime1.me/user/7');
      store.bindOwner(first);
      store.write('video#root', 'Private draft');
      final generation = store.generation;
      store.bindOwner(first);
      expect(store.read('video#root').text, 'Private draft');
      expect(store.generation, generation);
      final old = VideoSiteOperations(
        page: Uri.parse('https://hanime1.me/watch?v=42'),
        evaluate: (_) async => null,
        drafts: store,
      );
      store.bindOwner(Uri.parse('https://hanime1.me/user/8'));
      expect(store.read('video#root').text, isEmpty);
      expect(store.generation, generation + 1);
      old.retainCommentDraft(null, 'A late update');
      expect(old.commentDraft(null).text, isEmpty);
      old.dispose();
    },
  );

  testWidgets(
    'comments append only the matching revision and retain unsent input',
    (tester) async {
      final operations = _Operations(
        (_, payload) async => {
          'status': 'ok',
          'canPost': true,
          'revision': 'r1',
          'nextOffset': payload['offset'] == 100 ? null : 100,
          'items': [
            {
              'id': payload['offset'] == 100 ? '2' : '1',
              'author': 'Author',
              'text': payload['offset'] == 100 ? 'Second batch' : 'First batch',
            },
          ],
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: VideoCommunityPage(operations: operations, onLogin: () {}),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Unsent draft');
      await tester.tap(find.byKey(const ValueKey('video-comments-more')));
      await tester.pumpAndSettle();
      expect(operations.payloads.last, {'offset': 100, 'revision': 'r1'});
      expect(find.text('First batch'), findsOneWidget);
      expect(find.text('Second batch'), findsOneWidget);
      expect(find.byKey(const ValueKey('video-comments-more')), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Unsent draft',
      );
    },
  );

  testWidgets(
    'leaving during submission keeps the same comment blocked on reentry',
    (tester) async {
      final drafts = VideoCommentDraftStore();
      final reply = Completer<Map<String, dynamic>>();
      final first = VideoSiteOperations(
        page: Uri.parse('https://hanime1.me/watch?v=42'),
        drafts: drafts,
        evaluate: (script) async {
          if (script.contains('const operation = "comment"')) {
            return reply.future;
          }
          return {'status': 'ok', 'canPost': true, 'items': []};
        },
      );
      Widget comments(VideoSiteOperations operations) => MaterialApp(
        home: VideoCommunityPage(operations: operations, onLogin: () {}),
      );
      await tester.pumpWidget(comments(first));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Possibly posted');
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(first.writeInFlight, isTrue);

      first.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      reply.complete({'status': 'ok', 'canPost': true, 'items': []});
      await tester.pump();

      final next = _Operations(
        (_, _) async => {'status': 'ok', 'canPost': true, 'items': []},
        drafts: drafts,
      );
      addTearDown(next.dispose);
      await tester.pumpWidget(comments(next));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Possibly posted',
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.text(t.videoCommunity.unconfirmed), findsOneWidget);
      expect(next.calls, ['comments']);
      await tester.enterText(find.byType(TextField), ' Possibly posted ');
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), 'A different comment');
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    },
  );

  test(
    'comment readback settles only the submitted draft and account',
    () async {
      final drafts = VideoCommentDraftStore();
      drafts.bindOwner(Uri.parse('https://hanime1.me/user/7'));
      var response = Completer<Map<String, dynamic>>();
      final operations = _Operations((_, _) => response.future, drafts: drafts);
      const posted = {'status': 'ok', 'items': []};

      final confirmed = operations.submitComment('  Confirmed  ', replyId: '7');
      expect(operations.commentDraft('7').unconfirmed, isTrue);
      expect(operations.commentDraft(null).text, isEmpty);
      expect(operations.payloads.single['text'], 'Confirmed');
      response.complete(posted);
      expect((await confirmed).status, VideoSiteStatus.ok);
      expect(operations.commentDraft('7').text, isEmpty);

      response = Completer<Map<String, dynamic>>();
      final rejected = operations.submitComment('  Rejected  ');
      response.complete({'status': 'rejected'});
      expect((await rejected).status, VideoSiteStatus.rejected);
      expect(operations.commentDraft(null).text, '  Rejected  ');
      expect(operations.commentDraft(null).unconfirmed, isFalse);

      response = Completer<Map<String, dynamic>>();
      final previous = operations.submitComment('Previous');
      operations.retainCommentDraft(null, 'New edit');
      response.complete(posted);
      await previous;
      expect(operations.commentDraft(null).text, 'New edit');

      response = Completer<Map<String, dynamic>>();
      final oldAccount = operations.submitComment('Previous account');
      drafts.bindOwner(Uri.parse('https://hanime1.me/user/8'));
      final next = _Operations((_, _) async => posted, drafts: drafts);
      next.retainCommentDraft(null, 'New account');
      response.complete(posted);
      expect((await oldAccount).status, VideoSiteStatus.changed);
      expect(next.commentDraft(null).text, 'New account');
      expect(
        (await operations.submitComment('Old account')).status,
        VideoSiteStatus.changed,
      );
      expect(operations.calls.length, 4);
    },
  );

  testWidgets(
    'an unconfirmed draft survives route/service replacement and still blocks duplicate posting',
    (tester) async {
      final drafts = VideoCommentDraftStore();
      Future<Map<String, dynamic>> respond(
        String operation,
        Map<String, dynamic> _,
      ) async => operation == 'comment'
          ? {'status': 'unconfirmed', 'writeUnconfirmed': true}
          : {'status': 'ok', 'canPost': true, 'items': []};
      final first = _Operations(respond, drafts: drafts);
      await tester.pumpWidget(
        MaterialApp(
          home: VideoCommunityPage(operations: first, onLogin: () {}),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Sent but unconfirmed');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      first.dispose();
      final next = _Operations(respond, drafts: drafts);
      await tester.pumpWidget(
        MaterialApp(
          home: VideoCommunityPage(operations: next, onLogin: () {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Sent but unconfirmed',
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text(t.common.retry));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(next.calls.where((value) => value == 'comment'), isEmpty);
      drafts.clear();
      expect(next.commentDraft(null).text, isEmpty);
      next.retainCommentDraft(null, 'stale route');
      expect(drafts.read('https://hanime1.me/watch?v=42#root').text, isEmpty);
    },
  );

  testWidgets(
    'closing a read cancels it, releases idle, and does not block later requests',
    (tester) async {
      var cancels = 0;
      final operations = VideoSiteOperations(
        page: Uri.parse('https://hanime1.me/watch?v=42'),
        evaluate: (script) async {
          if (script.contains('if (true)')) {
            cancels++;
            return {'status': 'cancelled'};
          }
          if (script.contains('const operation = "state"')) {
            return {'status': 'ok', 'signedIn': false};
          }
          return {'status': 'pending', 'id': 'read-job'};
        },
      );
      final pending = operations.readPlaylists();
      await tester.pump();
      final cancel = operations.cancelRead();
      await tester.pump(const Duration(milliseconds: 200));
      await cancel;
      expect((await pending).status, VideoSiteStatus.cancelled);
      expect(cancels, greaterThan(0));
      expect((await operations.readInteraction()).status, VideoSiteStatus.ok);
      operations.dispose();
    },
  );

  testWidgets(
    'closing a read waits for local idle even when WebKit never acknowledges',
    (tester) async {
      final reply = Completer<Map<String, dynamic>>();
      final acknowledgement = Completer<Map<String, dynamic>>();
      final operations = VideoSiteOperations(
        page: Uri.parse('https://hanime1.me/watch?v=42'),
        evaluate: (script) async {
          if (script.contains('if (true)')) return acknowledgement.future;
          if (script.contains('const operation = "state"')) {
            return {'status': 'ok', 'signedIn': false};
          }
          return reply.future;
        },
      );
      addTearDown(operations.dispose);
      final pending = operations.readPlaylists();
      final closed = expectLater(operations.cancelRead(), completes);
      await tester.pump(const Duration(seconds: 2));
      expect((await operations.readInteraction()).status, VideoSiteStatus.busy);
      await tester.pump(const Duration(seconds: 1));
      await closed;
      expect((await pending).status, VideoSiteStatus.cancelled);

      reply.complete({'status': 'ok', 'lists': []});
      acknowledgement.complete({'status': 'cancelled'});
      await tester.pump();
      expect((await operations.readInteraction()).status, VideoSiteStatus.ok);
    },
  );

  test(
    'typed interaction keeps unknown capability distinct from a false value',
    () {
      final state = VideoInteractionState.fromWire({
        'actor': 'unknown',
        'canLike': false,
        'liked': false,
      });
      expect(
        state.capability(VideoSiteAction.like),
        VideoActionCapability.unknown,
      );
      expect(state.liked, isNull);
      final unreadable = VideoInteractionState.fromWire({
        'signedIn': true,
        'canLike': false,
      });
      expect(
        unreadable.capability(VideoSiteAction.like),
        VideoActionCapability.unrecognized,
      );
    },
  );

  testWidgets(
    'initial interaction failure retains actions and retries the real state read',
    (tester) async {
      final operations = _Operations(
        (operation, payload) async => switch (operation) {
          'state' => {'status': 'network'},
          'like' => interaction(liked: true),
          _ => interaction(),
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _Engagement(operations: operations, onLogin: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in [
        t.videoCommunity.like,
        t.videoCommunity.followShort,
        t.videoCommunity.share,
        t.videoCommunity.favorite,
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text(t.videoCommunity.network), findsOneWidget);
      await tester.tap(find.text(t.common.retry));
      await tester.pumpAndSettle();
      expect(operations.calls, ['state', 'refreshState']);
      expect(find.text(t.videoCommunity.network), findsNothing);
      await tester.tap(find.text(t.videoCommunity.like));
      await tester.pumpAndSettle();
      expect(operations.payloads.last, {'enabled': true});
      expect(find.text(t.videoCommunity.liked), findsOneWidget);
    },
  );

  testWidgets(
    'unrecognized actions remain visible and do not send blind writes',
    (tester) async {
      final operations = _Operations(
        (_, _) async => {'status': 'ok', 'signedIn': true},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _Engagement(operations: operations, onLogin: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(t.videoCommunity.actionsUnreadable), findsOneWidget);
      await tester.tap(find.text(t.videoCommunity.like));
      await tester.pumpAndSettle();
      expect(operations.calls, ['state', 'refreshState']);
      expect(find.text(t.videoCommunity.like), findsOneWidget);
    },
  );

  testWidgets('signed-out actions offer native login instead of vanishing', (
    tester,
  ) async {
    var logins = 0;
    final operations = _Operations(
      (_, _) async => {'status': 'ok', 'actor': 'signedOut', 'signedIn': false},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _Engagement(operations: operations, onLogin: () => logins++),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.videoCommunity.followShort));
    await tester.pumpAndSettle();
    expect(logins, 1);
    expect(operations.calls, ['state']);
  });

  testWidgets(
    'uncertain like keeps its old value and requires a confirmed refresh before another write',
    (tester) async {
      final operations = _Operations(
        (operation, _) async => switch (operation) {
          'like' => {'status': 'unconfirmed', 'writeUnconfirmed': true},
          'refreshState' => interaction(liked: true),
          _ => interaction(),
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _Engagement(operations: operations, onLogin: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.videoCommunity.like));
      await tester.pumpAndSettle();
      expect(find.text(t.videoCommunity.liked), findsNothing);
      expect(find.text(t.videoCommunity.unconfirmed), findsOneWidget);
      await tester.tap(find.text(t.videoCommunity.like));
      await tester.pumpAndSettle();
      expect(
        operations.calls.where((operation) => operation == 'like').length,
        1,
      );
      await tester.tap(find.text(t.common.retry));
      await tester.pumpAndSettle();
      expect(find.text(t.videoCommunity.liked), findsOneWidget);
      expect(find.text(t.videoCommunity.unconfirmed), findsNothing);
    },
  );

  testWidgets(
    'two rapid action calls produce one request even before the next frame',
    (tester) async {
      final pending = Completer<Map<String, dynamic>>();
      final operations = _Operations(
        (operation, _) async =>
            operation == 'like' ? pending.future : interaction(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _Engagement(operations: operations, onLogin: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, t.videoCommunity.like),
      );
      button.onPressed!();
      button.onPressed!();
      await tester.pump();
      expect(
        operations.calls.where((operation) => operation == 'like').length,
        1,
      );
      pending.complete(interaction(liked: true));
      await tester.pumpAndSettle();
      expect(find.text(t.videoCommunity.liked), findsOneWidget);
    },
  );

  testWidgets(
    'a late state from a previous service cannot overwrite a new video',
    (tester) async {
      final pending = Completer<Map<String, dynamic>>();
      final old = _Operations((_, _) => pending.future);
      final current = _Operations((_, _) async => interaction(liked: true));
      Widget view(VideoSiteOperations operations) => MaterialApp(
        home: Scaffold(
          body: _Engagement(operations: operations, onLogin: () {}),
        ),
      );
      await tester.pumpWidget(view(old));
      await tester.pump();
      await tester.pumpWidget(view(current));
      await tester.pumpAndSettle();
      pending.complete({'status': 'network'});
      await tester.pumpAndSettle();
      expect(find.text(t.videoCommunity.liked), findsOneWidget);
      expect(find.text(t.videoCommunity.network), findsNothing);
    },
  );

  test(
    'malformed target confirmations cannot emit a confirmed mutation',
    () async {
      var confirmed = 0, uncertain = 0, writes = 0;
      final operations = VideoSiteOperations(
        page: Uri.parse('https://hanime1.me/watch?v=42'),
        onMutation: () => confirmed++,
        onUncertainWrite: () => uncertain++,
        evaluate: (script) async {
          if (script.contains('if (true)')) return {'status': 'cancelled'};
          if (script.contains('const operation = "playlistMembership"')) {
            return {
              'status': 'ok',
              'lists': [
                {'id': 'abc', 'title': 'Owned list', 'containsVideo': true},
              ],
            };
          }
          writes++;
          return {'status': 'ok', 'lists': []};
        },
      );
      expect(
        (await operations.setPlaylistMembership('abc', true)).status,
        VideoSiteStatus.unconfirmed,
      );
      expect(
        (await operations.setPlaylistMembership('abc', true)).status,
        VideoSiteStatus.unconfirmed,
      );
      expect([confirmed, uncertain, writes], [0, 1, 1]);
      final read = await operations.readPlaylistMembership('abc');
      expect(read.value?.lists.single.containsVideo, true);
      await operations.setPlaylistMembership('abc', true);
      expect(
        writes,
        2,
        reason: 'only a confirmed read releases the uncertain target guard',
      );
      operations.dispose();
    },
  );

  testWidgets(
    'disposing during a write invalidates possible stale state without confirming it',
    (tester) async {
      var confirmed = 0, uncertain = 0;
      final operations = VideoSiteOperations(
        page: Uri.parse('https://hanime1.me/watch?v=42'),
        onMutation: () => confirmed++,
        onUncertainWrite: () => uncertain++,
        evaluate: (script) async => script.contains('if (true)')
            ? {'status': 'cancelled'}
            : {'status': 'pending', 'id': 'fixture'},
      );
      final pending = operations.setLiked(true);
      await tester.pump();
      operations.dispose();
      expect([confirmed, uncertain], [0, 1]);
      await tester.pump(const Duration(milliseconds: 200));
      expect((await pending).status, VideoSiteStatus.changed);
      expect([confirmed, uncertain], [0, 1]);
    },
  );

  testWidgets(
    'signed-out comment readers have an explicit native login action',
    (tester) async {
      var logins = 0;
      final operations = _Operations(
        (_, _) async => {
          'status': 'ok',
          'items': [],
          'canPost': false,
          'signedIn': false,
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: VideoCommunityPage(
            operations: operations,
            onLogin: () => logins++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.videoCommunity.login));
      expect(logins, 1);
      expect(find.byType(TextField), findsNothing);
    },
  );

  testWidgets('a failed comment keeps its draft with keyboard and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 340);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    var websites = 0;
    final operations = _Operations(
      (operation, _) async => operation == 'comment'
          ? {'status': 'verification', 'writeUnconfirmed': true}
          : {'status': 'ok', 'items': [], 'canPost': true},
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: VideoCommunityPage(
          operations: operations,
          onLogin: () {},
          onWebsite: () => websites++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'A retained draft');
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'A retained draft',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -220));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.videoPlayback.backToWeb).hitTestable());
    expect(websites, 1);
    expect(operations.calls, ['comments', 'comment']);
  });

  testWidgets(
    'comments retain drafts on rejection and prevent concurrent posts',
    (tester) async {
      final pending = Completer<Map<String, dynamic>>();
      final operations = _Operations(
        (operation, payload) async => operation == 'comment'
            ? pending.future
            : {'status': 'ok', 'items': [], 'canPost': true},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: VideoCommunityPage(operations: operations, onLogin: () {}),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'A draft written by the user',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, t.videoCommunity.post),
      );
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(operations.calls.where((c) => c == 'comment').length, 1);
      pending.complete({'status': 'rejected'});
      await tester.pumpAndSettle();
      expect(find.text(t.videoCommunity.rejected), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'A draft written by the user',
      );
    },
  );

  testWidgets(
    'reply threads expand inline, retain the parent and can post only when supported',
    (tester) async {
      final operations = _Operations(
        (operation, payload) async => {
          'status': 'ok',
          'canPost': operation == 'replies',
          'items': operation == 'comments'
              ? [
                  {
                    'id': '12',
                    'author': 'Example',
                    'text': 'A comment',
                    'hasReplies': true,
                  },
                ]
              : [
                  {'author': 'Reply author', 'text': 'A reply'},
                ],
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: VideoCommunityPage(operations: operations, onLogin: () {}),
        ),
      );
      await tester.pumpAndSettle();
      final toggle = find.byKey(const ValueKey('video-comment-replies.12'));
      final collapsedPosition = tester.getTopLeft(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.text(t.videoCommunity.replies), findsOneWidget);
      expect(find.text('A reply'), findsOneWidget);
      expect(find.text(t.comments.collapseReplies), findsOneWidget);
      final replyBounds = tester.getRect(
        find.byKey(const ValueKey('video-inline-replies.12')),
      );
      final collapseBounds = tester.getRect(toggle);
      expect(collapseBounds.top, greaterThanOrEqualTo(replyBounds.bottom));
      expect(collapseBounds.right, closeTo(replyBounds.right, 1));
      final input = find.byType(TextField);
      expect(input, findsOneWidget);
      await tester.enterText(input, 'Native reply draft');
      await tester.pump();
      expect(find.text('Native reply draft'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, t.videoCommunity.post),
        findsOneWidget,
      );
      expect(operations.calls, ['comments', 'replies']);
      expect(operations.payloads.last['id'], '12');
      expect(find.text('A comment'), findsOneWidget);
      expect(
        find.byType(Scaffold),
        findsOneWidget,
        reason: 'Replies must not push another page',
      );
      await tester.tap(find.byKey(const ValueKey('video-comment-replies.12')));
      await tester.pumpAndSettle();
      expect(find.text('A reply'), findsNothing);
      expect(find.text('A comment'), findsOneWidget);
      expect(tester.getTopLeft(toggle), collapsedPosition);
    },
  );

  testWidgets('embedded comments refresh from their own list at large text', (
    tester,
  ) async {
    final operations = _Operations(
      (operation, payload) async => {
        'status': 'ok',
        'canPost': false,
        'items': [
          {
            'id': '12',
            'author': 'Author',
            'text': 'First comment',
            'time': '2026-11-13',
            'hasReplies': true,
          },
          {'id': '13', 'author': 'Second author', 'text': 'Second comment'},
        ],
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
          child: VideoCommunityPage(
            operations: operations,
            onLogin: () {},
            embedded: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip(t.common.refresh), findsNothing);
    final replies = find.byKey(const ValueKey('video-comment-replies.12'));
    expect(tester.getSize(replies).height, greaterThanOrEqualTo(44));
    expect(
      tester.getTopLeft(find.text('First comment')).dy,
      lessThan(tester.getTopLeft(replies).dy),
    );
    await tester.drag(find.byType(ListView), const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(operations.calls, ['comments', 'comments']);
    expect(find.text('First comment'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'closing a page with an inline reply read drops its late result without navigation',
    (tester) async {
      final pending = Completer<Map<String, dynamic>>();
      final operations = _Operations((operation, payload) async {
        if (operation == 'comments')
          return {
            'status': 'ok',
            'items': [
              {
                'id': '12',
                'author': 'Fixture',
                'text': 'Parent body',
                'hasReplies': true,
              },
            ],
          };
        expect(operation, 'replies');
        expect(payload['id'], '12');
        return pending.future;
      });
      await tester.pumpWidget(
        MaterialApp(
          home: VideoCommunityPage(operations: operations, onLogin: () {}),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('video-comment-replies.12')));
      await tester.pump();
      expect(find.text('Parent body'), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete({
        'status': 'ok',
        'items': [
          {'author': 'Reply', 'text': 'Late reply'},
        ],
      });
      await tester.pumpAndSettle();
      expect(find.text('Late reply'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'verification is an inline recovery state without automatic navigation',
    (tester) async {
      var logins = 0;
      final operations = _Operations(
        (_, _) async => {'status': 'verification'},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: VideoCommunityPage(
            operations: operations,
            onLogin: () => logins++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(t.videoCommunity.verificationRequired), findsOneWidget);
      expect(find.byType(VideoCommunityPage), findsOneWidget);
      expect(logins, 0);
      expect(operations.calls, ['comments']);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'native comments fit a narrow large-text $brightness viewport',
      (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final operations = _Operations(
          (_, _) async => {
            'status': 'ok',
            'canPost': true,
            'items': [
              {
                'author': 'A long author name 用户名字',
                'time': 'Today',
                'text': 'Long comment text 中文 ' * 15,
              },
            ],
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: VideoCommunityPage(operations: operations, onLogin: () {}),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'playlist deletion requires confirmation and cancellation writes nothing',
    (tester) async {
      final operations = _Operations((_, _) async => {'status': 'ok'});
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open editor'),
                onPressed: () async {
                  result = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) => VideoPlaylistEditor(
                        initial: const {
                          'title': 'Example',
                          'description': 'Description',
                          'canDelete': true,
                        },
                        operations: operations,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, t.videoCommunity.deletePlaylist),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.common.cancel));
      await tester.pumpAndSettle();
      expect(operations.calls, isEmpty);
      await tester.tap(
        find.widgetWithText(TextButton, t.videoCommunity.deletePlaylist),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, t.common.delete));
      await tester.pumpAndSettle();
      expect(operations.calls, ['deletePlaylist']);
      expect(result, 'deleted');
    },
  );

  testWidgets('WK job start is polled and cleaned without a Promise bridge', (
    tester,
  ) async {
    var start = 0, poll = 0, cleanup = 0;
    final operations = VideoSiteOperations(
      page: Uri.parse('https://hanime1.me/watch?v=42'),
      evaluate: (script) async {
        if (script.contains('const expected =')) {
          start++;
          return {'status': 'pending', 'id': 'fixture'};
        }
        if (script.contains('if (true)')) {
          cleanup++;
          return {'status': 'cancelled'};
        }
        poll++;
        return {'status': 'ok', 'items': []};
      },
    );
    final result = operations.run('comments');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect((await result)['status'], 'ok');
    await tester.pump();
    expect([start, poll, cleanup], [1, 1, 1]);
    operations.dispose();
  });

  testWidgets('leaving a route immediately aborts its browser job', (
    tester,
  ) async {
    var cancellations = 0, polls = 0;
    final operations = VideoSiteOperations(
      page: Uri.parse('https://hanime1.me/watch?v=42'),
      evaluate: (script) async {
        if (script.contains('const expected =')) {
          return {'status': 'pending', 'id': 'fixture'};
        }
        if (script.contains('if (true)')) {
          cancellations++;
          return {'status': 'cancelled'};
        }
        polls++;
        return {'status': 'pending'};
      },
    );
    final pending = operations.run('comments');
    await tester.pump();
    operations.dispose();
    expect(cancellations, 1);
    await tester.pump(const Duration(milliseconds: 200));
    expect((await pending)['status'], 'changed');
    expect(polls, 0);
    expect(cancellations, 1);
  });

  test('vote fields retain positive, negative and total semantics', () {
    final state = VideoInteractionState.fromWire({
      'actor': 'signedIn',
      'capabilities': {'like': 'ready', 'dislike': 'ready'},
      'liked': false,
      'disliked': true,
      'positiveVotes': 100,
      'negativeVotes': 2,
      'totalVotes': 102,
    });
    expect(state.liked, false);
    expect(state.disliked, true);
    expect(
      [state.positiveVotes, state.negativeVotes, state.totalVotes],
      [100, 2, 102],
    );
    expect(
      VideoInteractionState.fromWire({
        'positiveVotes': -1,
        'totalVotes': '102',
      }).totalVotes,
      isNull,
    );
  });

  test(
    'pending and rejected votes never alter the last confirmed tally',
    () async {
      final pending = Completer<Map<String, dynamic>>();
      final operations = _Operations(
        (operation, _) async => operation == 'like'
            ? pending.future
            : {...interaction(), 'positiveVotes': 7},
      );
      final controller = VideoEngagementController(
        operations: operations,
        onLogin: () {},
      );
      addTearDown(controller.dispose);
      addTearDown(operations.dispose);
      await controller.load();
      final write = controller.set(VideoSiteAction.like, true);
      await Future<void>.delayed(Duration.zero);
      expect(controller.pendingVote, VideoSiteAction.like);
      expect(controller.state.liked, false);
      expect(controller.state.positiveVotes, 7);
      await controller.set(VideoSiteAction.like, true);
      expect(operations.calls, ['state', 'like']);
      pending.complete({'status': 'rejected'});
      await write;
      expect(controller.pendingVote, isNull);
      expect(controller.state.liked, false);
      expect(controller.state.positiveVotes, 7);
    },
  );

  test(
    'dislike dispatches a distinct target action and uses the confirmed paired vote result',
    () async {
      final operations = _Operations(
        (operation, payload) async => {
          ...interaction(),
          'canDislike': true,
          'disliked': operation == 'dislike' ? payload['enabled'] : false,
          'positiveVotes': 100,
          'negativeVotes': operation == 'dislike' ? 3 : 2,
          'totalVotes': operation == 'dislike' ? 103 : 102,
        },
      );
      final controller = VideoEngagementController(
        operations: operations,
        onLogin: () {},
      );
      await controller.load();
      await controller.set(VideoSiteAction.dislike, true);
      expect(operations.calls, ['state', 'dislike']);
      expect(operations.payloads.last, {'enabled': true});
      expect(controller.state.disliked, true);
      expect(controller.state.liked, false);
      expect(controller.state.negativeVotes, 3);
      controller.dispose();
    },
  );

  testWidgets(
    'OTP publishing gate leaves comments and replies readable without automatic login',
    (tester) async {
      var logins = 0, websites = 0;
      final operations = _Operations(
        (operation, _) async => {
          'status': 'ok',
          'signedIn': true,
          'canPost': false,
          'postGate': operation == 'replies'
              ? 'unrecognized'
              : 'siteVerification',
          'items': operation == 'replies'
              ? [
                  {
                    'id': '13',
                    'author': 'Reply author',
                    'text': 'Readable reply',
                  },
                ]
              : [
                  {
                    'id': '12',
                    'author': 'Public author',
                    'text': 'Readable comment',
                    'hasReplies': true,
                  },
                ],
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: VideoCommunityPage(
            operations: operations,
            onLogin: () => logins++,
            onWebsite: () => websites++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Readable comment'), findsOneWidget);
      expect(find.text(t.videoCommunity.postVerificationOnly), findsOneWidget);
      expect(find.text(t.videoCommunity.viewReplies), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect([logins, websites], [0, 0]);
      await tester.tap(find.text(t.videoCommunity.viewReplies));
      await tester.pumpAndSettle();
      expect(find.text('Readable reply'), findsOneWidget);
      expect(find.text(t.videoCommunity.postVerificationOnly), findsOneWidget);
      expect(find.text(t.videoCommunity.publishingUnavailable), findsNothing);
      final website = find.widgetWithText(
        TextButton,
        t.videoPlayback.backToWeb,
      );
      expect(website, findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(operations.calls, ['comments', 'replies']);
      await tester.tap(website);
      expect([logins, websites], [0, 1]);
    },
  );

  testWidgets(
    'known created playlist recovers by reading and adding the same entity without duplicate creation',
    (tester) async {
      final operations = _Operations(
        (operation, payload) async => switch (operation) {
          'createPlaylist' => {
            'status': 'unconfirmed',
            'writeUnconfirmed': true,
            'createdId': 'new',
            'createdVerified': true,
          },
          'reconcileCreatedPlaylist' => {
            'status': 'ok',
            'createdId': 'new',
            'createdVerified': true,
            'lists': [
              {'id': 'new', 'title': 'New list', 'containsVideo': false},
            ],
          },
          'savePlaylist' => {
            'status': 'ok',
            'lists': [
              {'id': 'new', 'title': 'New list', 'containsVideo': true},
            ],
          },
          _ => {'status': 'unsupported'},
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => VideoPlaylistEditor(
                      initial: const {},
                      operations: operations,
                      create: true,
                    ),
                  ),
                ),
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'New list');
      await tester.tap(find.text(t.common.save));
      await tester.pumpAndSettle();
      expect(find.text(t.videoCommunity.unconfirmed), findsOneWidget);
      await tester.tap(find.text(t.videoCommunity.checkStatus));
      await tester.pumpAndSettle();
      expect(find.text(t.videoCommunity.createdNotAdded), findsOneWidget);
      await tester.tap(find.text(t.videoCommunity.addToCreatedPlaylist));
      await tester.pumpAndSettle();
      expect(operations.calls, [
        'createPlaylist',
        'reconcileCreatedPlaylist',
        'savePlaylist',
      ]);
      expect(operations.payloads.last, {'id': 'new', 'enabled': true});
      expect(find.text('Open editor'), findsOneWidget);
    },
  );

  test(
    'reconciling one known new playlist does not release an earlier uncertain creation',
    () async {
      final creates = <String>[];
      final operations = VideoSiteOperations(
        page: Uri.parse('https://hanime1.me/watch?v=42'),
        evaluate: (script) async {
          if (script.contains('if (true)')) return {'status': 'cancelled'};
          if (script.contains('const operation = "createPlaylist"')) {
            final title = script.contains('"title":"A"') ? 'A' : 'B';
            creates.add(title);
            return {
              'status': 'unconfirmed',
              'writeUnconfirmed': true,
              'createdId': title.toLowerCase(),
              'createdVerified': true,
            };
          }
          return {
            'status': 'ok',
            'createdId': 'b',
            'createdVerified': true,
            'lists': [
              {'id': 'b', 'title': 'B', 'containsVideo': true},
            ],
          };
        },
      );
      await operations.createPlaylistAndAdd(title: 'A');
      await operations.createPlaylistAndAdd(title: 'B');
      await operations.run('reconcileCreatedPlaylist');
      expect(
        (await operations.createPlaylistAndAdd(title: 'A')).status,
        VideoSiteStatus.unconfirmed,
      );
      expect(creates, ['A', 'B']);
      await operations.createPlaylistAndAdd(title: 'B');
      expect(creates, ['A', 'B', 'B']);
      operations.dispose();
    },
  );
}
