import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show eventBus;
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart';
import 'package:zephyr/page/comic_info/models/comic_detail_presentation.dart';
import 'package:zephyr/page/comic_info/models/comic_like.dart';
import 'package:zephyr/page/comic_info/widgets/comic_operation.dart';
import 'package:zephyr/page/comic_info/widgets/particulars.dart';
import 'package:zephyr/page/search_result/view/source_search_detail_list.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/comic_like_updates.dart';
import 'package:zephyr/service/jm_list_like_counts.dart';
import 'package:zephyr/service/plugin_account_authentication.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_theme_colors.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';
import 'package:zephyr/widgets/toast.dart';

import '../test_helper.dart';

NormalComicAllInfo _detail(bool zeroKnown) => NormalComicAllInfo.fromJson({
  'comicInfo': {
    'id': '51',
    'title': 'fixture',
    'titleMeta': [],
    'description': '',
    'cover': {'id': '51', 'url': '', 'name': ''},
    'metadata': [],
  },
  'eps': [],
  'recommend': [],
  'allowComments': true,
  'allowLike': true,
  if (zeroKnown) ...{'totalLikes': 0, 'totalComments': 0},
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await TestObjectBoxHelper.setUpTestObjectBox();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  test('JM never dispatches a vote even with an older bundle', () async {
    for (final source in [
      JmListLikeCounts.source,
      'bf99008d-010b-4f17-ac7c-61a9b57dc3d9',
    ]) {
      var requests = 0;
      for (final liked in [false, true]) {
        await expectLater(
          toggleCloudComicLike(
            from: source,
            comicId: '51',
            currentStatus: liked,
            invoke: (_, _) async {
              requests++;
              return {'liked': !liked, 'verified': true, 'totalLikes': 42};
            },
          ),
          throwsStateError,
        );
      }
      expect(requests, isZero);
    }
  });

  testWidgets('like submits once and discards a previous session result', (
    tester,
  ) async {
    const source = 'like-session-fixture';
    final detail = _detail(false);
    final requests = <bool>[];
    final pending = <Completer<ComicLikeResult>>[];
    await tester.pumpWidget(
      BlocProvider(
        create: (_) => GlobalSettingCubit(),
        child: MaterialApp(
          home: Scaffold(
            body: ComicOperationWidget(
              normalInfo: detail,
              from: source,
              comicInfo: detail,
              showCollectAction: false,
              cloudLikeAction: (liked) {
                requests.add(liked);
                final response = Completer<ComicLikeResult>();
                pending.add(response);
                return response.future;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final like = find.text(t.comicInfo.likeAction);
    await tester.tap(like);
    await tester.tap(like); // The handler also guards before the next frame.
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    await tester.tap(like);
    expect(requests, [false]);

    pluginSessionWriteFence.advance(source);
    pending.single.complete((liked: true, totalLikes: 28));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);

    await tester.tap(like);
    expect(requests, [false, false]);
    pending.last.complete((liked: true, totalLikes: 28));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.text(t.comicInfo.likes(count: 28)), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite));
    expect(requests, [false, false, true]);
    pending.last.complete((liked: false, totalLikes: 27));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      navigator.push<void>(
        MaterialPageRoute(builder: (_) => const Scaffold(body: Text('cover'))),
      ),
    );
    await tester.pumpAndSettle();
    pending.last.completeError(
      const PluginLoginRequiredException(
        UnauthorizedPayload(pluginId: source, message: 'login required'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('cover'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    navigator.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.favorite_border));
    pending.last.completeError(
      const PluginLoginRequiredException(
        UnauthorizedPayload(pluginId: source, message: 'login required'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpWidget(const SizedBox.shrink());
    pending.last.complete((liked: true, totalLikes: 28));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Bika retains the current vote display until the site confirms a change',
    (tester) async {
      final detail = _detail(true).copyWith(totalLikes: 227);
      addTearDown(
        () => pluginSessionWriteFence.advance(
          PluginAccountAuthenticationService.bika.single,
        ),
      );
      final replies = <Completer<ComicLikeResult>>[];
      await tester.pumpWidget(
        BlocProvider(
          create: (_) => GlobalSettingCubit(),
          child: MaterialApp(
            home: Scaffold(
              body: ComicOperationWidget(
                normalInfo: detail,
                from: PluginAccountAuthenticationService.bika.single,
                comicInfo: detail,
                showCollectAction: false,
                cloudLikeAction: (_) {
                  final reply = Completer<ComicLikeResult>();
                  replies.add(reply);
                  return reply.future;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Finder count(Object value) => find.text(t.comicInfo.likes(count: value));
      await tester.tap(count(227));
      await tester.pump();
      expect(count(227), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      await tester.tap(count(227));
      expect(replies, hasLength(1));
      replies.last.complete((liked: true, totalLikes: null));
      await tester.pumpAndSettle();
      expect(count(227), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);

      await tester.tap(count(227));
      await tester.pump();
      expect(count(227), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsNothing);
      replies.last.completeError(StateError('write failed'));
      await tester.pumpAndSettle();
      expect(count(227), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);

      await tester.tap(count(227));
      replies.last.complete((liked: false, totalLikes: 230));
      await tester.pumpAndSettle();
      expect(count(230), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      await tester.tap(count(230));
      replies.last.complete((liked: true, totalLikes: 0));
      await tester.pumpAndSettle();
      expect(count(0), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    },
  );

  testWidgets(
    'an unchanged vote stays unconfirmed until the site reports the new selection',
    (tester) async {
      final detail = _detail(true).copyWith(totalLikes: 20);
      final messages = <String>[];
      var writes = 0;
      var reads = 0;
      final notices = eventBus.on<ToastEvent>().listen(
        (e) => messages.add(e.message),
      );
      addTearDown(notices.cancel);
      await tester.pumpWidget(
        BlocProvider(
          create: (_) => GlobalSettingCubit(),
          child: MaterialApp(
            home: Scaffold(
              body: ComicOperationWidget(
                normalInfo: detail,
                from: 'unconfirmed-like-fixture',
                comicInfo: detail,
                showCollectAction: false,
                cloudLikeAction: (_) async {
                  writes++;
                  return (liked: false, totalLikes: null);
                },
                cloudLikeRead: () async {
                  reads++;
                  return (liked: false, totalLikes: null);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.comicInfo.likes(count: 20)));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text(t.comicInfo.likes(count: 20)), findsOneWidget);
      expect(messages, isEmpty);
      expect((writes, reads), (1, 2));
      await tester.tap(find.text(t.comicInfo.likes(count: 20)));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text(t.comicInfo.likes(count: 20)), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect((writes, reads), (2, 5));

      final likes = ComicLikeUpdates.instance;
      final work = comicLikeWork('unconfirmed-like-fixture', '51');
      expect(likes.needsCheck(work), isTrue);
      likes.observeDetail(work, likes.markRead(work), (
        liked: true,
        totalLikes: 21,
      ));
      await tester.pump();
      expect(find.text(t.comicInfo.likes(count: 21)), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(likes.needsCheck(work), isFalse);
    },
  );

  testWidgets('JM displays the count as a non-interactive detail metric', (
    tester,
  ) async {
    final detail = _detail(true).copyWith(totalLikes: 19, isLiked: true);
    final presentation = comicInfoForDetailPresentation(
      detail,
      showReadOnlyLikes: true,
    );
    var requests = 0;
    await tester.pumpWidget(
      BlocProvider(
        create: (_) => GlobalSettingCubit(),
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ComicMetadataCopyPill(item: presentation.titleMeta.single),
                ComicOperationWidget(
                  normalInfo: detail,
                  from: JmListLikeCounts.source,
                  comicInfo: detail,
                  showCollectAction: false,
                  cloudLikeAction: (_) async {
                    requests++;
                    return (liked: false, totalLikes: 18);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final count = find.text(t.comicInfo.likes(count: 19));
    final pill = tester.widget<InkWell>(
      find.descendant(
        of: find.byType(ComicMetadataCopyPill),
        matching: find.byType(InkWell),
      ),
    );
    expect(pill.onTap, isNull);
    expect(pill.onLongPress, isNull);
    expect(count, findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);
    expect(find.byIcon(Icons.mode_comment_outlined), findsOneWidget);
    await tester.tap(count);
    await tester.pumpAndSettle();
    expect(requests, isZero);
    expect(count, findsOneWidget);
  });

  testWidgets(
    'Bika refreshes even when a confirmed receipt repeats the old total',
    (tester) async {
      final detail = _detail(true).copyWith(totalLikes: 3928);
      final source = PluginAccountAuthenticationService.bika.single;
      addTearDown(() => pluginSessionWriteFence.advance(source));
      final readback = Completer<int>();
      var writes = 0;
      var reads = 0;
      await tester.pumpWidget(
        BlocProvider(
          create: (_) => GlobalSettingCubit(),
          child: MaterialApp(
            home: Scaffold(
              body: ComicOperationWidget(
                normalInfo: detail,
                from: source,
                comicInfo: detail,
                showCollectAction: false,
                cloudLikeAction: (liked) => toggleCloudComicLike(
                  from: source,
                  comicId: '51',
                  currentStatus: liked,
                  previousTotalLikes: 3928,
                  invoke: (fn, input) async {
                    expect(fn, 'toggleLike');
                    expect(input['currentLiked'], isFalse);
                    writes++;
                    return {
                      'liked': true,
                      'verified': true,
                      'totalLikes': 3928,
                    };
                  },
                ),
                cloudLikeRead: () => readCloudComicLike(
                  from: source,
                  comicId: '51',
                  invoke: (fn, _) async {
                    expect(fn, 'getComicDetail');
                    final count = ++reads == 1 ? 3928 : await readback.future;
                    return {
                      'source': source,
                      'comicId': '51',
                      'data': {
                        'normal': {
                          'comicInfo': {'id': '51'},
                          'totalLikes': count,
                          'extern': {
                            'metricAvailability': {'totalLikes': true},
                          },
                        },
                        'raw': {
                          'comicInfo': {'isLiked': true, 'likesCount': count},
                        },
                      },
                    };
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.comicInfo.likes(count: 3928)));
      await tester.pump();
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.text(t.comicInfo.likes(count: 3929)), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      readback.complete(3931);
      await tester.pumpAndSettle();
      expect(find.text(t.comicInfo.likes(count: 3931)), findsOneWidget);
      expect((writes, reads), (1, 2));
    },
  );

  testWidgets('reopening does not replace a vote with the old site tally', (
    tester,
  ) async {
    var elapsed = Duration.zero;
    final likes = ComicLikeUpdates.withClock(() => elapsed);
    addTearDown(likes.dispose);
    final work = comicLikeWork('reopen-tally-fixture', '51');
    final owner = likes.beginWrite(work)!;
    const oldTally = (liked: true, totalLikes: 196);
    likes.accept(
      work,
      owner: owner,
      before: (liked: false, totalLikes: 196),
      receipt: oldTally,
      read: () async => oldTally,
    );
    likes.finishWrite(work, owner);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    elapsed = const Duration(minutes: 1);
    likes.observeDetail(work, likes.markRead(work), oldTally);
    expect(likes.valueFor(work), (liked: true, totalLikes: 197));

    likes.observeDetail(work, likes.markRead(work), (
      liked: true,
      totalLikes: 198,
    ));
    expect(likes.valueFor(work), (liked: true, totalLikes: 198));
    likes.observeDetail(work, likes.markRead(work), oldTally);
    expect(likes.valueFor(work), oldTally);
  });

  test('a later authenticated detail confirms a write with a lost receipt', () {
    final likes = ComicLikeUpdates.withClock(() => Duration.zero);
    addTearDown(likes.dispose);
    final work = comicLikeWork('lost-receipt-fixture', '52');
    final early = likes.markRead(work);
    final owner = likes.beginWrite(work)!;
    likes.finishWrite(
      work,
      owner,
      unconfirmedBefore: (liked: false, totalLikes: 100),
    );
    const read = (liked: true, totalLikes: 100);
    likes.observeDetail(work, early, read);
    expect(likes.valueFor(work), isNull);
    likes.observeDetail(work, likes.markRead(work), read);
    expect(likes.valueFor(work), (liked: true, totalLikes: 101));
    expect(likes.needsCheck(work), isFalse);
  });

  testWidgets('likes reach the open list and reconcile after leaving detail', (
    tester,
  ) async {
    const source = 'like-list-fixture';
    final detail = _detail(true).copyWith(totalLikes: 257);
    final row = UnifiedComicListItem.fromJson({
      'id': '51',
      'source': source,
      'title': 'list work',
      'cover': {'id': '51', 'url': '', 'name': ''},
      'likesCount': 257,
    });
    final receipt = Completer<ComicLikeResult>();
    final readback = Completer<ComicLikeResult>();
    var reads = 0;
    var writes = 0;
    await tester.pumpWidget(
      BlocProvider(
        create: (_) => GlobalSettingCubit(),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  SourceSearchDetailTile(entry: row),
                  SourceSearchDetailTile(entry: row.copyWith(source: 'other')),
                  TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(),
                          body: ComicOperationWidget(
                            normalInfo: detail,
                            from: source,
                            comicInfo: detail,
                            showCollectAction: false,
                            cloudLikeAction: (_) async {
                              writes++;
                              return receipt.future;
                            },
                            cloudLikeRead: () async => ++reads == 1
                                ? (liked: true, totalLikes: 257)
                                : readback.future,
                          ),
                        ),
                      ),
                    ),
                    child: const Text('Open detail'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('257'), findsNWidgets(2));
    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.comicInfo.likes(count: 257)));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('257'), findsNWidgets(2));
    await tester.tap(find.text('Open detail'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text(t.comicInfo.likes(count: 257)));
    expect(writes, 1);
    await tester.pageBack();
    await tester.pumpAndSettle();
    receipt.complete((liked: true, totalLikes: 257));
    await tester.pumpAndSettle();
    expect(find.text('258'), findsOneWidget);
    expect(find.text('257'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    readback.complete((liked: true, totalLikes: 259));
    await tester.pumpAndSettle();
    expect(find.text('259'), findsOneWidget);
    expect(find.text('257'), findsOneWidget);
    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();
    expect(find.text(t.comicInfo.likes(count: 259)), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect((writes, reads), (1, 2));
    pluginSessionWriteFence.advance(source);
  });

  testWidgets(
    'confirmed selection beats an older detail and updates its count',
    (tester) async {
      const source = 'like-detail-fixture';
      final likes = ComicLikeUpdates.instance;
      final work = comicLikeWork(source, '51');
      final oldRead = likes.markRead(work);
      addTearDown(() => pluginSessionWriteFence.advance(source));
      final oldDetail = _detail(true).copyWith(totalLikes: 20);
      final mutation = Completer<ComicLikeResult>();
      final countRead = Completer<ComicLikeResult>();
      Widget host(NormalComicAllInfo detail) => BlocProvider(
        create: (_) => GlobalSettingCubit(),
        child: MaterialApp(
          home: Scaffold(
            body: ComicOperationWidget(
              normalInfo: detail,
              from: source,
              comicInfo: detail,
              showCollectAction: false,
              cloudLikeAction: (_) => mutation.future,
              cloudLikeRead: () => countRead.future,
            ),
          ),
        ),
      );
      await tester.pumpWidget(host(oldDetail));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.comicInfo.likes(count: 20)));
      mutation.complete((liked: true, totalLikes: null));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.text(t.comicInfo.likes(count: 21)), findsOneWidget);

      likes.observeDetail(work, oldRead, (liked: false, totalLikes: 19));
      await tester.pumpWidget(host(oldDetail.copyWith(totalLikes: 19)));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.text(t.comicInfo.likes(count: 21)), findsOneWidget);
      countRead.complete((liked: true, totalLikes: 21));
      await tester.pumpAndSettle();
      expect(find.text(t.comicInfo.likes(count: 21)), findsOneWidget);

      likes.observeDetail(work, likes.markRead(work), (
        liked: true,
        totalLikes: 18,
      ));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.text(t.comicInfo.likes(count: 18)), findsOneWidget);
    },
  );

  for (final unlike in [false, true]) {
    testWidgets(
      'accepted comic vote settles silently after readback (unlike: $unlike)',
      (tester) async {
        final source = 'vote-readback-fixture-$unlike';
        addTearDown(() => pluginSessionWriteFence.advance(source));
        final detail = _detail(true).copyWith(isLiked: unlike, totalLikes: 20);
        final messages = <ToastEvent>[];
        final notices = eventBus.on<ToastEvent>().listen(messages.add);
        addTearDown(notices.cancel);
        var writes = 0;
        var reads = 0;
        await tester.pumpWidget(
          BlocProvider(
            create: (_) => GlobalSettingCubit(),
            child: MaterialApp(
              home: Scaffold(
                body: ComicOperationWidget(
                  normalInfo: detail,
                  from: source,
                  comicInfo: detail,
                  showCollectAction: false,
                  cloudLikeAction: (current) async {
                    expect(current, unlike);
                    writes++;
                    return (liked: !unlike, totalLikes: 20);
                  },
                  cloudLikeRead: () async {
                    reads++;
                    // The first write never persisted. The cancellation did,
                    // but the site's aggregate still has its pre-write value.
                    return (liked: false, totalLikes: 20);
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.comicInfo.likes(count: 20)));
        await tester.pump();
        expect(
          find.text(t.comicInfo.likes(count: unlike ? 19 : 21)),
          findsOneWidget,
        );
        expect(
          find.byIcon(unlike ? Icons.favorite_border : Icons.favorite),
          findsOneWidget,
        );
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(
          find.text(t.comicInfo.likes(count: unlike ? 19 : 20)),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.favorite_border), findsOneWidget);
        expect(messages, isEmpty);
        expect((writes, reads), (1, 2));
      },
    );
  }

  test(
    'legacy Bika takes the fresh same-work state and explicit zero',
    () async {
      for (final source in [
        PluginAccountAuthenticationService.bika.single,
        '0a0e5858-a467-4702-994a-79e608a4589d',
      ]) {
        final calls = <String>[];
        final result = await toggleCloudComicLike(
          from: source,
          comicId: '51',
          currentStatus: true,
          invoke: (fn, _) async {
            calls.add(fn);
            if (fn == 'toggleLike') return {'liked': false};
            return {
              'source': source,
              'comicId': '51',
              'data': {
                'normal': {
                  'comicInfo': {'id': '51'},
                  'totalLikes': 0,
                },
                'raw': {
                  'comicInfo': {'isLiked': false, 'likesCount': '0'},
                },
              },
            };
          },
        );
        expect(result, (liked: false, totalLikes: 0));
        expect(calls, ['toggleLike', 'getComicDetail']);
      }
    },
  );
  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'unsupported like is absent and comments retain the row $style $brightness',
        (tester) async {
          final styleValue = ValueNotifier(style);
          addTearDown(styleValue.dispose);
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: styleValue,
              child: BlocProvider(
                create: (_) => GlobalSettingCubit(),
                child: MaterialApp(
                  theme: ThemeData(brightness: brightness),
                  home: Scaffold(
                    body: SizedBox(
                      width: 320,
                      child: ComicOperationWidget(
                        normalInfo: _detail(true).copyWith(allowLike: false),
                        from: 'copy-fixture',
                        comicInfo: _detail(true),
                        showCollectAction: false,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byIcon(Icons.favorite_border), findsNothing);
          expect(find.text(t.comicInfo.likeAction), findsNothing);
          expect(find.text(t.comicInfo.likes(count: 0)), findsNothing);
          expect(find.text(t.comicInfo.comments(count: 0)), findsOneWidget);
          expect(tester.getSize(find.byType(InkWell).last).width, 320);
          expect(tester.takeException(), isNull);
        },
      );
      testWidgets(
        'detail metrics keep unknown distinct from zero and comments reachable: $style $brightness',
        (tester) async {
          var zeroKnown = false;
          PluginCommentsScaffoldRouteArgs? opened;
          final notifier = ValueNotifier(style);
          final router = RootStackRouter.build(
            routes: [
              NamedRouteDef(
                name: 'DetailOperationHost',
                path: '/',
                initial: true,
                builder: (_, _) => Scaffold(
                  body: StatefulBuilder(
                    builder: (context, update) => Column(
                      children: [
                        ComicOperationWidget(
                          key: ValueKey(zeroKnown),
                          normalInfo: _detail(zeroKnown),
                          from: 'unknown-source',
                          comicInfo: _detail(zeroKnown),
                          showCollectAction: false,
                        ),
                        TextButton(
                          onPressed: () => update(() => zeroKnown = true),
                          child: const Text('load explicit zero'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              NamedRouteDef(
                name: PluginCommentsScaffoldRoute.name,
                path: '/comments',
                builder: (_, data) {
                  opened = data.argsAs<PluginCommentsScaffoldRouteArgs>();
                  return const Scaffold(body: Text('comments destination'));
                },
              ),
            ],
          );
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          ThemeData seededTheme(Color seed, {bool amoled = false}) {
            final colors = BreezeThemeColors.fromSeed(seed, brightness);
            return ThemeData(
              colorScheme: colors,
              scaffoldBackgroundColor: amoled ? Colors.black : colors.surface,
              platform: TargetPlatform.iOS,
            );
          }

          final rose = seededTheme(Colors.pink);
          final themes = [
            rose,
            seededTheme(Colors.teal),
            sourceOriginalPinkTheme(rose),
            if (brightness == Brightness.dark)
              seededTheme(Colors.pink, amoled: true),
          ];
          final routerConfig = router.config();
          Widget host(ThemeData theme) => AppInterfaceStyleScope(
            style: notifier,
            child: BlocProvider(
              create: (_) => GlobalSettingCubit(),
              child: MaterialApp.router(
                routerConfig: routerConfig,
                theme: theme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.7)),
                  child: child!,
                ),
              ),
            ),
          );

          try {
            final comment = find.text(t.comicInfo.commentsAction);
            final like = find.text(t.comicInfo.likeAction);
            Color plateFill(Finder action) {
              final plate = tester.widget<Ink>(
                find.ancestor(of: action, matching: find.byType(Ink)),
              );
              return (plate.decoration! as BoxDecoration).color!;
            }

            for (final theme in themes) {
              await tester.pumpWidget(host(theme));
              await tester.pumpAndSettle();
              final fill = plateFill(comment);
              final colors = theme.colorScheme;
              final page = theme.scaffoldBackgroundColor;
              final visibleFill = Color.alphaBlend(fill, page);
              expect(fill, colors.primary.withValues(alpha: .06));
              expect(plateFill(like), fill);
              expect(visibleFill, isNot(page));
              expect(
                BreezeThemeColors.contrast(visibleFill, page),
                lessThan(
                  BreezeThemeColors.contrast(
                    Color.alphaBlend(
                      colors.primary.withValues(alpha: .08),
                      page,
                    ),
                    page,
                  ),
                ),
              );
              expect(
                BreezeThemeColors.contrast(colors.onSurface, visibleFill),
                greaterThanOrEqualTo(4.5),
              );
            }
            expect(like, findsOneWidget);
            expect(comment, findsOneWidget);
            expect(find.text(t.comicInfo.likes(count: 0)), findsNothing);
            expect(find.text(t.comicInfo.comments(count: 0)), findsNothing);
            await tester.tap(comment);
            await tester.pumpAndSettle();
            expect(find.text('comments destination'), findsOneWidget);
            expect(opened?.comicId, '51');
            expect(opened?.from, 'unknown-source');
            await router.maybePop();
            await tester.pumpAndSettle();
            await tester.tap(find.text('load explicit zero'));
            await tester.pumpAndSettle();
            expect(find.text(t.comicInfo.likes(count: 0)), findsOneWidget);
            expect(find.text(t.comicInfo.comments(count: 0)), findsOneWidget);
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            router.dispose();
            notifier.dispose();
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          }
        },
      );
    }
  }
}
