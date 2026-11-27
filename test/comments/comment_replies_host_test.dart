import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final controller = VisibilityDetectorController.instance;
    final savedInterval = controller.updateInterval;
    controller.updateInterval = Duration.zero;
    addTearDown(() => controller.updateInterval = savedInterval);
  });
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
            'items': core['page'] == 2
                ? [_row('reply-9', 'Paginated reply')]
                : [
                    _row('reply-7', 'Reply body'),
                    _row('reply-8', 'Second reply'),
                  ],
            'paging': {'hasReachedMax': core['page'] == 2},
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
      expect(calls, ['getCommentFeed', 'loadCommentReplies']);
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
      final toggle = find.byKey(
        const ValueKey('comment-replies-toggle.parent-31'),
      );
      final collapsePosition = tester.getTopLeft(toggle);
      expect(find.text(t.comments.collapseReplies), findsOneWidget);
      expect(
        collapsePosition.dy,
        greaterThan(tester.getBottomLeft(find.text('Reply body')).dy),
      );
      expect(
        collapsePosition.dy,
        lessThan(tester.getTopLeft(find.text('Second reply')).dy),
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.text('Reply body'), findsOneWidget);
      expect(find.text('Second reply'), findsNothing);
      expect(tester.getTopLeft(toggle), collapsePosition);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.text('Reply body'), findsOneWidget);
      expect(find.text('Second reply'), findsOneWidget);
      expect(tester.getTopLeft(toggle), collapsePosition);
      expect(calls.length, 3);
      await tester.tap(find.text(t.comments.loadMoreReplies));
      await tester.pumpAndSettle();
      expect(calls.length, 4);
      expect(find.text('Paginated reply'), findsOneWidget);
      expect(find.text(t.comments.loadMoreReplies), findsNothing);
      expect(tester.getTopLeft(toggle), collapsePosition);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('lazy previews load for visible parents with bounded reads', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 440));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final settings = GlobalSettingCubit();
    addTearDown(settings.close);
    final reads = <String, Completer<Map<String, dynamic>>>{};
    await tester.pumpWidget(
      BlocProvider.value(
        value: settings,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.4)),
            child: child!,
          ),
          home: PluginCommentsScaffold(
            from: 'preview-fixture',
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
                        'items': [
                          for (var i = 0; i < 3; i++)
                            _row('parent-$i', 'Parent $i', count: 2),
                          for (var i = 0; i < 14; i++)
                            _row('spacer-$i', 'Other comment $i'),
                          _row('far-parent', 'Far parent', count: 2),
                        ],
                      },
                    };
                  }
                  expect(fnPath, 'loadCommentReplies');
                  expect(core['page'], 1);
                  final id = core['commentId'] as String;
                  expect(reads, isNot(contains(id)));
                  return (reads[id] = Completer()).future;
                },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(reads.keys, ['parent-0', 'parent-1']);

    void finish(String id) {
      reads[id]!.complete({
        'data': {
          'commentId': id,
          'items': [
            _row('$id-preview', 'Preview $id'),
            _row('$id-extra', 'Extra $id'),
          ],
          'paging': {'hasReachedMax': true},
        },
      });
    }

    finish('parent-0');
    await tester.pumpAndSettle();
    expect(reads.keys, ['parent-0', 'parent-1', 'parent-2']);
    expect(find.text('Preview parent-0'), findsOneWidget);
    expect(find.text('Extra parent-0'), findsNothing);
    finish('parent-1');
    finish('parent-2');
    await tester.pumpAndSettle();

    for (var i = 0; i < 8 && !reads.containsKey('far-parent'); i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    expect(reads.keys, ['parent-0', 'parent-1', 'parent-2', 'far-parent']);
    finish('far-parent');
    await tester.pumpAndSettle();
    expect(find.text('Preview far-parent').hitTestable(), findsOneWidget);
    expect(find.text('Extra far-parent'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('embedded replies start with one compact preview', (
    tester,
  ) async {
    final settings = GlobalSettingCubit();
    addTearDown(settings.close);
    final calls = <String>[];
    await tester.pumpWidget(
      BlocProvider.value(
        value: settings,
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: PluginCommentsScaffold(
            from: 'embedded-fixture',
            comicId: 'work',
            comicTitle: 'Work',
            pluginCall:
                ({
                  required from,
                  required fnPath,
                  required core,
                  required extern,
                }) async {
                  calls.add(fnPath);
                  return {
                    'data': {
                      ..._feed()['data'] as Map,
                      'replyMode': 'embedded',
                      'items': [
                        {
                          ..._row('parent-31', 'Parent', count: 2),
                          'createdAt': '10:05',
                          'replies': [
                            _row('reply-7', 'Preview'),
                            _row('reply-8', 'Second embedded reply'),
                          ],
                        },
                      ],
                    },
                  };
                },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final parent = find.widgetWithText(SelectableText, 'Parent');
    final preview = find.widgetWithText(SelectableText, 'Preview');
    final second = find.text('Second embedded reply');
    final toggle = find.byKey(
      const ValueKey('comment-replies-toggle.parent-31'),
    );
    expect(preview, findsOneWidget);
    expect(second, findsNothing);
    final parentStyle = tester.widget<SelectableText>(parent).style!;
    final previewStyle = tester.widget<SelectableText>(preview).style!;
    expect(previewStyle.fontSize, lessThan(parentStyle.fontSize!));
    expect(
      previewStyle.color,
      Theme.of(tester.element(preview)).colorScheme.onSurfaceVariant,
    );
    expect(
      tester.getTopLeft(preview).dx,
      greaterThan(tester.getTopLeft(parent).dx),
    );
    expect(
      tester.getTopLeft(preview).dy,
      greaterThan(tester.getBottomLeft(find.text('10:05')).dy),
    );
    final position = tester.getTopLeft(toggle);
    expect(position.dx, tester.getTopLeft(parent).dx);
    expect(tester.getSize(toggle).height, greaterThanOrEqualTo(44));
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(second, findsOneWidget);
    expect(tester.getTopLeft(toggle), position);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(preview, findsOneWidget);
    expect(second, findsNothing);
    expect(tester.getTopLeft(toggle), position);
    expect(calls, ['getCommentFeed']);
  });

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
