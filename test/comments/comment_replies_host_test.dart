import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comments/cubit/comments_cubit.dart';
import 'package:zephyr/page/comments/view/plugin_comments_scaffold.dart';
import '../test_helper.dart';

Map<String, dynamic> _row(String id, String text, {int count = 0}) => {
  'id': id,
  'author': {'name': 'Fixture'},
  'content': text,
  'replyCount': count,
  'extern': {'commentId': id, 'replyId': id},
};
Map<String, dynamic> _feed() => {
  'data': {
    'items': [_row('parent-31', 'Parent', count: 2)],
    'replyMode': 'lazy',
    'paging': {'hasReachedMax': true},
    'canComment': {'comic': false, 'reply': false},
  },
};
void main() {
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'a failed reply read is inline retry, never no-replies; retry keeps the original parent ID',
    (tester) async {
      final settings = GlobalSettingCubit();
      addTearDown(settings.close);
      var replies = 0;
      final calls = <String>[];
      Future<Map<String, dynamic>> call({
        required String from,
        required String fnPath,
        required Map<String, dynamic> core,
        required Map<String, dynamic> extern,
      }) async {
        calls.add(fnPath);
        if (fnPath == 'getCommentFeed') return _feed();
        expect(fnPath, 'loadCommentReplies');
        expect(core['comicId'], 'comic-work');
        expect(core['commentId'], 'parent-31');
        expect(extern['replyId'], 'parent-31');
        if (++replies == 1) throw StateError('temporary network');
        return {
          'data': {
            'commentId': 'parent-31',
            'items': [_row('reply-7', 'Reply body')],
            'paging': {'hasReachedMax': true},
          },
        };
      }

      await tester.pumpWidget(
        BlocProvider.value(
          value: settings,
          child: MaterialApp(
            home: PluginCommentsScaffold(
              from: 'copy-fixture',
              comicId: 'comic-work',
              comicTitle: 'Work',
              pluginCall: call,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.comments.replyCount(count: 2)));
      await tester.pumpAndSettle();
      expect(find.text(t.comments.noReplies), findsNothing);
      final retry = find.byKey(
        const ValueKey('comment-replies-retry.parent-31'),
      );
      expect(retry.hitTestable(), findsOneWidget);
      expect(calls, ['getCommentFeed', 'loadCommentReplies']);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.text('Reply body'), findsOneWidget);
      expect(find.text(t.comments.noReplies), findsNothing);
      expect(calls, [
        'getCommentFeed',
        'loadCommentReplies',
        'loadCommentReplies',
      ]);
      final collapse = find.text(t.comments.collapseReplies);
      expect(collapse, findsOneWidget);
      expect(
        tester.getTopLeft(collapse).dy,
        greaterThan(tester.getBottomLeft(find.text('Reply body')).dy),
      );
      expect(
        tester.getCenter(collapse).dx,
        greaterThan(tester.getCenter(find.text('Reply body')).dx),
      );
      await tester.tap(collapse);
      await tester.pumpAndSettle();
      expect(find.text('Reply body'), findsNothing);
      await tester.tap(find.text(t.comments.replyCount(count: 2)));
      await tester.pumpAndSettle();
      expect(find.text('Reply body'), findsOneWidget);
      expect(calls.length, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a failed submission keeps the composer and typed draft', (
    tester,
  ) async {
    final settings = GlobalSettingCubit();
    addTearDown(settings.close);
    var writes = 0;
    await tester.pumpWidget(
      BlocProvider.value(
        value: settings,
        child: MaterialApp(
          home: PluginCommentsScaffold(
            from: 'write-fixture',
            comicId: 'work',
            comicTitle: 'Work',
            pluginCall:
                ({
                  required from,
                  required fnPath,
                  required core,
                  required extern,
                }) async {
                  if (fnPath == 'getCommentFeed') {
                    return {
                      'data': {
                        ..._feed()['data'] as Map,
                        'canComment': {'comic': true, 'reply': false},
                      },
                    };
                  }
                  expect(fnPath, 'postComment');
                  expect(core['content'], 'Kept draft');
                  writes++;
                  throw StateError('fixture failure');
                },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    final input = find.byType(TextField);
    await tester.enterText(input, 'Kept draft');
    await tester.pump();
    await tester.tap(find.text(t.comments.confirm));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Kept draft'), findsOneWidget);
    await tester.tap(find.text(t.comments.cancel));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(writes, 1);
  });

  test(
    'only the exact missing-function dispatch error permits a legacy alias',
    () async {
      for (final missing in [true, false]) {
        final paths = <String>[];
        final cubit = CommentsCubit(
          from: 'copy-fixture',
          comicId: 'comic-work',
          call:
              ({
                required from,
                required fnPath,
                required core,
                required extern,
              }) async {
                paths.add(fnPath);
                if (fnPath == 'getCommentFeed') return _feed();
                if (fnPath == 'loadCommentReplies')
                  throw StateError(
                    missing
                        ? 'target is not function: loadCommentReplies; targetType=undefined; ownerType=object;'
                        : 'network unavailable',
                  );
                expect(core['commentId'], 'parent-31');
                expect(core['page'], 1);
                return {
                  'data': {
                    'commentId': 'parent-31',
                    'items': [_row('reply-7', 'Reply')],
                    'paging': {'hasReachedMax': true},
                  },
                };
              },
        );
        await cubit.loadInitial();
        await cubit.toggleReplies(cubit.state.items.single);
        expect(
          paths,
          missing
              ? ['getCommentFeed', 'loadCommentReplies', 'getCommentReplies']
              : ['getCommentFeed', 'loadCommentReplies'],
        );
        expect(cubit.replyError('parent-31'), missing ? isNull : isNotNull);
        expect(cubit.state.replyItems['parent-31']?.length, missing ? 1 : null);
        await cubit.close();
      }
    },
  );
}
