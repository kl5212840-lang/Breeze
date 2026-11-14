import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show eventBus;
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart';
import 'package:zephyr/page/comic_info/models/comic_like.dart';
import 'package:zephyr/page/comic_info/widgets/comic_operation.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/jm_list_like_counts.dart';
import 'package:zephyr/service/plugin_account_authentication.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_theme_colors.dart';
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
    await tester.pumpWidget(const SizedBox.shrink());
    pending.last.complete((liked: true, totalLikes: 28));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Bika shows progress and only displays numbers returned by the site',
    (tester) async {
      final detail = _detail(true).copyWith(totalLikes: 227);
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
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
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
    'an unchanged vote retains the last known count without a success notice',
    (tester) async {
      final detail = _detail(true).copyWith(totalLikes: 20);
      final messages = <String>[];
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
                cloudLikeAction: (_) async => (liked: false, totalLikes: null),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.comicInfo.likes(count: 20)));
      await tester.pumpAndSettle();
      expect(find.text(t.comicInfo.likes(count: 20)), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(messages, contains(t.comicInfo.likeUnconfirmed));
      expect(messages, isNot(contains(t.comicInfo.unlikeSuccess)));
      expect(messages, isNot(contains(t.comicInfo.likeSuccess)));
    },
  );

  testWidgets('JM shows a typed unconfirmed write without reporting failure', (
    tester,
  ) async {
    final messages = <ToastEvent>[];
    final notices = eventBus.on<ToastEvent>().listen(messages.add);
    addTearDown(notices.cancel);
    final detail = _detail(true).copyWith(totalLikes: 20);
    final replies = [
      AnyhowException(
        '[bundle:jm.cjs] Error: {"type":"comic_like_unconfirmed",'
        '"diagnostic":{"submit":{"result":"readable","http":200},'
        '"readback":{"result":"business-rejected","http":200}}}',
      ),
      AnyhowException('request was explicitly rejected'),
    ];
    await tester.pumpWidget(
      BlocProvider(
        create: (_) => GlobalSettingCubit(),
        child: MaterialApp(
          home: Scaffold(
            body: ComicOperationWidget(
              normalInfo: detail,
              from: JmListLikeCounts.source,
              comicInfo: detail,
              showCollectAction: false,
              cloudLikeAction: (liked) => toggleCloudComicLike(
                from: JmListLikeCounts.source,
                comicId: '51',
                currentStatus: liked,
                previousTotalLikes: 20,
                invoke: (function, payload) async {
                  expect(function, 'toggleLike');
                  expect(payload['includeLikeDiagnostic'], true);
                  expect(payload['previousTotalLikes'], 20);
                  throw replies.removeAt(0);
                },
              ),
            ),
          ),
        ),
      ),
    );
    final count = find.text(t.comicInfo.likes(count: 20));
    await tester.pumpAndSettle();
    await tester.tap(count);
    await tester.pumpAndSettle();
    expect(messages.single.message, t.comicInfo.likeUnconfirmed);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(count, findsOneWidget);

    messages.clear();
    await tester.tap(count);
    await tester.pumpAndSettle();
    expect(
      messages.single.message,
      t.comicInfo.likeFailed(error: 'request was explicitly rejected'),
    );
    expect(replies, isEmpty);
  });

  Map<String, dynamic> jmDetail({bool liked = false, String id = '51'}) => {
    'source': JmListLikeCounts.source,
    'comicId': id,
    'data': {
      'normal': {
        'comicInfo': {'id': id},
        'isLiked': liked,
        'totalLikes': 42,
        'extern': {
          'metricAvailability': {'totalLikes': true},
        },
      },
    },
  };

  test(
    'legacy JM acknowledgement is rejected without exact positive readback',
    () async {
      for (final reply in [jmDetail(), jmDetail(liked: true, id: '52')]) {
        final calls = <String>[];
        await expectLater(
          toggleCloudComicLike(
            from: JmListLikeCounts.source,
            comicId: '51',
            currentStatus: false,
            invoke: (fn, _) async {
              calls.add(fn);
              return fn == 'toggleLike' ? {'liked': true} : reply;
            },
          ),
          throwsFormatException,
        );
        expect(calls, ['toggleLike', 'getComicDetail']);
      }
    },
  );

  testWidgets('JM confirmed count updates its cover with no duplicate read', (
    tester,
  ) async {
    const source = JmListLikeCounts.source;
    addTearDown(() => pluginSessionWriteFence.advance(source));
    final calls = <String>[];
    final result = await toggleCloudComicLike(
      from: source,
      comicId: '51',
      currentStatus: false,
      invoke: (fn, _) async {
        calls.add(fn);
        return {'liked': true, 'verified': true, 'totalLikes': 42};
      },
    );
    expect(result, (liked: true, totalLikes: 42));
    expect(calls, ['toggleLike']);
    expect(JmListLikeCounts.instance.countFor('51'), 42);
    pluginSessionWriteFence.advance(source);
    expect(JmListLikeCounts.instance.countFor('51'), isNull);
  });

  test(
    'legacy Bika takes the fresh same-work state and explicit zero',
    () async {
      final source = PluginAccountAuthenticationService.bika.single;
      final result = await toggleCloudComicLike(
        from: source,
        comicId: '51',
        currentStatus: true,
        invoke: (fn, _) async => fn == 'toggleLike'
            ? {'liked': false}
            : {
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
              },
      );
      expect(result, (liked: false, totalLikes: 0));
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
