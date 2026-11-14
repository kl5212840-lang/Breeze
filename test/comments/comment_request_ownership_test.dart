import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/comments/cubit/comments_cubit.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';

Map<String, dynamic> _row(String id) => {
  'id': id,
  'author': {'name': 'Fixture'},
  'content': id,
  'replyCount': 1,
};

Map<String, dynamic> _feed(String id) => {
  'data': {
    'items': [_row(id)],
    'replyMode': 'lazy',
    'paging': {'hasReachedMax': false},
    'canComment': {'comic': true, 'reply': true},
  },
};

void main() {
  test(
    'only the current feed can publish initial or paginated results',
    () async {
      final initial = Completer<Map<String, dynamic>>();
      final previousPage = Completer<Map<String, dynamic>>();
      var requests = 0;
      final cubit = CommentsCubit(
        from: 'comment-refresh-fixture',
        comicId: 'fixture',
        call:
            ({required from, required fnPath, required core, required extern}) {
              expect(fnPath, 'getCommentFeed');
              if (core['page'] == 2) return previousPage.future;
              return switch (++requests) {
                1 => initial.future,
                2 => Future.value(_feed('current')),
                _ => Future.value(_feed('refreshed')),
              };
            },
      );
      addTearDown(cubit.close);
      final first = cubit.loadInitial();
      await cubit.loadInitial();
      initial.complete(_feed('stale'));
      await first;
      expect(cubit.state.items.single.id, 'current');

      final page = cubit.loadMore();
      expect(cubit.state.loadingMore, isTrue);
      await cubit.loadInitial();
      expect(cubit.state.loadingMore, isFalse);
      previousPage.complete(_feed('old page'));
      await page;
      expect(cubit.state.items.single.id, 'refreshed');
      expect(cubit.state.page, 2);
    },
  );

  test(
    'reply submission requires positive confirmation for its exact parent',
    () async {
      var sends = 0;
      final pending = Completer<Map<String, dynamic>>();
      final cubit = CommentsCubit(
        from: 'comment-send-fixture',
        comicId: 'fixture',
        call:
            ({
              required from,
              required fnPath,
              required core,
              required extern,
            }) async {
              if (fnPath == 'getCommentFeed') return _feed('expected-parent');
              expect(fnPath, 'postCommentReply');
              expect(core['commentId'], 'expected-parent');
              if (++sends == 1) return pending.future;
              return {
                'data': {'ok': false},
              };
            },
      );
      addTearDown(cubit.close);
      await cubit.loadInitial();
      final parent = cubit.state.items.single;
      final sent = cubit.postReply(parent, 'Draft');
      expect(await cubit.postReply(parent, 'Draft'), isFalse);
      expect(sends, 1);
      pending.complete({
        'data': {
          'ok': true,
          'mode': 'postReply',
          'parentId': 'other-parent',
          'created': _row('unexpected'),
          'insertHint': {
            'strategy': 'prepend',
            'targetCommentId': 'other-parent',
          },
        },
      });
      expect(await sent, isFalse);
      expect(await cubit.postReply(parent, 'Draft'), isFalse);
      expect(cubit.state.replyItems, isEmpty);
      expect(cubit.state.items.single.id, 'expected-parent');
    },
  );

  test('account changes fence delayed writes and open composers', () async {
    const source = 'comment-account-fixture';
    var sends = 0;
    final pending = Completer<Map<String, dynamic>>();
    final cubit = CommentsCubit(
      from: source,
      comicId: 'fixture',
      call:
          ({
            required from,
            required fnPath,
            required core,
            required extern,
          }) async {
            if (fnPath == 'getCommentFeed') return _feed('same-parent');
            sends++;
            return pending.future;
          },
    );
    addTearDown(cubit.close);
    await cubit.loadInitial();
    final generation = cubit.feedGeneration;
    final old = cubit.state.items.single;
    final sent = cubit.postReply(old, 'Old draft', generation: generation);

    final owner = pluginSessionWriteFence.beginSessionChange(source);
    expect(cubit.state.items, isEmpty);
    expect(cubit.state.canCommentReply, isFalse);
    pluginSessionWriteFence.seal(source, owner);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.items.single.id, old.id);
    expect(
      await cubit.postReply(old, 'Old draft', generation: generation),
      isFalse,
    );
    expect(sends, 1);
    pending.complete({
      'data': {
        'ok': true,
        'mode': 'postReply',
        'parentId': old.id,
        'created': _row('old receipt'),
        'insertHint': {'strategy': 'prepend', 'targetCommentId': old.id},
      },
    });
    expect(await sent, isFalse);
    expect(cubit.state.replyItems, isEmpty);
    expect(cubit.state.noticeId, 0);
  });
}
