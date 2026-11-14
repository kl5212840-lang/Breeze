import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/omofun_discussion_panel.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';

void main() {
  testWidgets('returning from replies restores the root list and scroll', (
    tester,
  ) async {
    final home = Uri.parse('https://www.omofuna.com/');
    final reply = Completer<Map<String, dynamic>>();
    final reads = <String>[];
    Uri? openedWebsite;
    final client = OmoSiteClient(
      home: home,
      request: (operation, args) async {
        final id = args['commentId']?.toString() ?? '';
        reads.add(id);
        if (id.isNotEmpty) return reply.future;
        return {
          'kind': 'comments',
          'items': [
            for (var i = 0; i < 30; i++)
              {
                'id': '${i + 1}',
                'author': 'Author',
                'text': 'Root comment ${i + 1}',
                'replies': i == 14 ? 1 : 0,
              },
          ],
          'rawCount': 30,
          'hasMore': false,
        };
      },
    );
    addTearDown(client.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OmoDiscussionPanel(
            client: client,
            vodId: '123',
            episodeId: '1',
            website: home,
            discussion: home,
            embedded: true,
            onWebsite: (uri) => openedWebsite = uri,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final website = find.byKey(const ValueKey('omo-discussion-website'));
    expect(website.hitTestable(), findsOneWidget);
    expect(tester.getSize(website).height, greaterThanOrEqualTo(44));
    expect(tester.getSize(website).height, lessThanOrEqualTo(48));
    await tester.tap(website);
    expect(openedWebsite, home);
    expect(reads, ['']);
    final toggle = find.text(t.videoSource.commentReplies(count: 1));
    await tester.scrollUntilVisible(
      toggle,
      220,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(toggle);
    await tester.tap(toggle);
    await tester.pump();
    expect(reads, ['', '15']);
    await tester.tap(find.byTooltip(t.common.back));
    await tester.pumpAndSettle();
    expect(reads, ['', '15']);
    expect(tester.getTopLeft(toggle).dy, closeTo(before.dy, 1));
    reply.complete({
      'kind': 'replies',
      'items': [
        {'id': 'reply', 'text': 'Late reply result'},
      ],
      'rawCount': 1,
    });
    await tester.pumpAndSettle();
    expect(find.text('Late reply result'), findsNothing);
    expect(tester.getTopLeft(toggle).dy, closeTo(before.dy, 1));
    expect(tester.takeException(), isNull);
  });

  for (final uncertain in [false, true]) {
    testWidgets(
      'comment like uses real write and authoritative readback, uncertain=$uncertain',
      (tester) async {
        final home = Uri.parse('https://www.omofuna.com/');
        bool liked = false;
        int writes = 0, reads = 0;
        final client = OmoSiteClient(
          home: home,
          request: (operation, args) async {
            if (operation == 'account') {
              return {
                'kind': 'account',
                'account': {'id': '1', 'name': 'Tester'},
              };
            }
            if (operation == 'commentLike' || operation == 'commentUnlike') {
              expect(args['commentId'], '9');
              writes++;
              liked = operation == 'commentLike';
              return {'kind': 'mutation', 'accepted': true};
            }
            reads++;
            if (uncertain && reads == 2) {
              throw TimeoutException('Readback failed');
            }
            return {
              'kind': 'comments',
              'items': [
                {
                  'id': '9',
                  'text': '正文内容',
                  'author': '昵称',
                  'createdAt': '2026-10-29',
                  'liked': liked,
                  'likes': liked ? 1 : 0,
                },
              ],
              'rawCount': 1,
              'hasMore': false,
            };
          },
        );
        addTearDown(client.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OmoDiscussionPanel(
                client: client,
                vodId: '123',
                episodeId: '1',
                website: home,
                discussion: home,
                embedded: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('昵称'), findsOneWidget);
        expect(find.text('2026-10-29'), findsOneWidget);
        expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
        final button = find.byKey(const ValueKey('omo-comment.like.9'));
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(writes, 1);
        if (uncertain) {
          expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(
            writes,
            1,
            reason: 'Uncertain writes must refresh, never submit twice',
          );
        }
        expect(find.byIcon(Icons.thumb_up_rounded), findsOneWidget);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(writes, 2);
        expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final kind in ['permissionDenied', 'rejected', 'sourceNotice']) {
    testWidgets('comment write $kind remains distinct from a read failure', (
      tester,
    ) async {
      final home = Uri.parse('https://www.omofuna.com/');
      final client = OmoSiteClient(
        home: home,
        request: (operation, _) async {
          if (operation == 'account') {
            return {
              'kind': 'account',
              'account': {'id': '1'},
            };
          }
          if (operation == 'commentLike') {
            if (kind == 'sourceNotice') {
              return {
                'kind': 'mutation',
                'accepted': false,
                'code': 0,
                'sourceNotice': '脱敏后的站点业务提示',
              };
            }
            return kind == 'rejected'
                ? {'kind': 'mutation', 'accepted': false, 'code': 0}
                : {'kind': kind, 'code': 0};
          }
          return {
            'kind': 'comments',
            'items': [
              {'id': '9', 'text': 'fixture', 'liked': false, 'likes': 0},
            ],
            'rawCount': 1,
          };
        },
      );
      addTearDown(client.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OmoDiscussionPanel(
              client: client,
              vodId: '1',
              episodeId: '1',
              website: home,
              discussion: home,
              embedded: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('omo-comment.like.9')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          kind == 'sourceNotice'
              ? '脱敏后的站点业务提示'
              : kind == 'permissionDenied'
              ? t.error.permissionDenied
              : t.videoCommunity.rejected,
        ),
        findsOneWidget,
      );
      expect(find.text(t.videoSource.readFailed), findsNothing);
      expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
    });
  }
  for (final exit in [false, true]) {
    testWidgets(
      'an old comment like skips readback after leaving its episode, exit=$exit',
      (tester) async {
        final home = Uri.parse('https://www.omofuna.com/');
        final mutation = Completer<Map<String, dynamic>>();
        final reads = <String>[], writes = <String>[];
        final client = OmoSiteClient(
          home: home,
          request: (operation, args) async {
            if (operation == 'account') {
              return {
                'kind': 'account',
                'account': {'id': '1'},
              };
            }
            if (operation == 'commentLike') {
              writes.add(args['commentId'] as String);
              return mutation.future;
            }
            expect(operation, 'comments');
            final episode = args['episodeId'] as String;
            reads.add(episode);
            return {
              'kind': 'comments',
              'items': [
                {
                  'id': episode == '1' ? '9' : '10',
                  'text': 'Episode $episode comment',
                  'liked': false,
                  'likes': 0,
                },
              ],
              'rawCount': 1,
            };
          },
        );
        addTearDown(client.dispose);
        var episode = '1';
        late StateSetter update;
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(navigatorKey: navigator, home: const Scaffold()),
        );
        unawaited(
          navigator.currentState!.push<void>(
            MaterialPageRoute<void>(
              builder: (_) => StatefulBuilder(
                builder: (_, setState) {
                  update = setState;
                  return Scaffold(
                    body: OmoDiscussionPanel(
                      client: client,
                      vodId: '123',
                      episodeId: episode,
                      website: home,
                      discussion: home,
                      embedded: true,
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('omo-comment.like.9')));
        await tester.pump();
        expect(writes, ['9']);

        if (exit) {
          navigator.currentState!.pop();
          await tester.pump();
          expect(
            find.byType(OmoDiscussionPanel, skipOffstage: false),
            findsOneWidget,
          );
        } else {
          update(() => episode = '2');
          await tester.pumpAndSettle();
          expect(find.text('Episode 2 comment'), findsOneWidget);
        }
        mutation.complete({'kind': 'mutation', 'accepted': true});
        await tester.pumpAndSettle();
        expect(reads, ['1', if (!exit) '2']);
        expect(writes, ['9']);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'comments-only has no second switch; a late episode cannot overwrite the newly selected episode',
    (tester) async {
      final slow = Completer<Map<String, dynamic>>(), calls = <String>[];
      final home = Uri.parse('https://www.omofuna.com/');
      final client = OmoSiteClient(
        home: home,
        request: (op, args) async {
          calls.add(op);
          expect(op, 'comments');
          expect(args['vodId'], '17482');
          if (args['episodeId'] == '2') return slow.future;
          expect(args['episodeId'], '3');
          return {
            'kind': 'comments',
            'items': [
              {'id': '3', 'author': '昵称', 'text': '当前第3集评论'},
            ],
            'rawCount': 1,
            'hasMore': false,
          };
        },
      );
      addTearDown(client.dispose);
      var episode = '2';
      late StateSetter update;
      Uri? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, set) {
              update = set;
              return Scaffold(
                body: OmoDiscussionPanel(
                  client: client,
                  vodId: '17482',
                  episodeId: episode,
                  website: home.resolve(
                    '/anime/1234567890abcdef/play/1/$episode.html',
                  ),
                  discussion: home.resolve('/square.html?vod_id=17482'),
                  embedded: true,
                  onWebsite: (uri) => opened = uri,
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(SegmentedButton<bool>), findsNothing);
      expect(find.text(t.videoLibrary.workDiscussion), findsNothing);
      update(() => episode = '3');
      await tester.pumpAndSettle();
      expect(find.text('当前第3集评论'), findsOneWidget);
      slow.complete({
        'kind': 'comments',
        'items': [
          {'id': '2', 'text': '过期第2集评论'},
        ],
        'rawCount': 1,
      });
      await tester.pumpAndSettle();
      expect(find.text('过期第2集评论'), findsNothing);
      await tester.tap(find.text(t.videoLibrary.openWebsite));
      await tester.pumpAndSettle();
      expect(opened, home.resolve('/anime/1234567890abcdef/play/1/3.html'));
      expect(calls, ['comments', 'comments']);
      expect(tester.takeException(), isNull);
    },
  );
}
