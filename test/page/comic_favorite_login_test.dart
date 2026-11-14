import 'dart:async';
import 'dart:convert';
import 'package:auto_route/auto_route.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/page/comic_info/models/collect_comic.dart';
import 'package:zephyr/page/comic_info/models/favorite_workflow.dart';
import 'package:zephyr/page/comic_info/models/plugin_action_login.dart';
import 'package:zephyr/util/event/event.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

void main() {
  for (final style in ['system', 'breeze']) {
    testWidgets(
      'explicit login keeps the caller route and refreshes on return $style',
      (tester) async {
        final styleValue = ValueNotifier(style);
        addTearDown(styleValue.dispose);
        var refreshes = 0;
        var loginOpens = 0;
        final router = RootStackRouter.build(
          routes: [
            NamedRouteDef(
              name: 'RetainedDetail',
              path: '/',
              initial: true,
              builder: (_, _) => Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => requestPluginActionLogin(
                      context,
                      source: 'copy',
                      refresh: () async {
                        refreshes++;
                      },
                    ),
                    child: const Text('perform account action'),
                  ),
                ),
              ),
            ),
            NamedRouteDef(
              name: LoginRoute.name,
              path: '/login',
              builder: (_, data) {
                expect(data.argsAs<LoginRouteArgs>().from, 'copy');
                loginOpens++;
                return Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () {
                        eventBus.fire(const PluginLoginSucceeded('copy'));
                        context.router.pop();
                      },
                      child: const Text('complete login'),
                    ),
                  ),
                );
              },
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: styleValue,
            child: MaterialApp.router(routerConfig: router.config()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('perform account action'));
        await tester.pumpAndSettle();
        expect(loginOpens, 0);
        await tester.tap(find.text(t.common.cancel));
        await tester.pumpAndSettle();
        expect(refreshes, 0);
        expect(router.stack.length, 1);
        await tester.tap(find.text('perform account action'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.navigation.goLogin));
        await tester.pumpAndSettle();
        expect(router.stack.length, 2);
        await tester.tap(find.text('complete login'));
        await tester.pumpAndSettle();
        expect(refreshes, 1);
        expect(loginOpens, 1);
        expect(router.stack.length, 1);
        expect(find.text('perform account action'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  test('only an explicit unauthorized envelope signals login', () {
    for (final message in [
      'HTTP 401',
      '请先登录',
      'not supported',
      '{broken',
      null,
    ]) {
      expect(pluginActionLoginRequirement(message, pluginId: 'copy'), isNull);
    }
    final result = pluginActionLoginRequirement(
      jsonEncode({
        'type': 'unauthorized',
        'source': 'unrelated-source',
        'message': 'token=private-content',
      }),
      pluginId: 'copy',
    )!;
    expect(result.payload.pluginId, 'copy');
    expect(result.toString(), isNot(contains('private-content')));
  });

  for (final mode in [
    'returned',
    'thrown',
    'missing',
    'unsupported',
    'committed',
    'completed',
  ]) {
    testWidgets('favorite workflow preserves $mode outcome without retry', (
      tester,
    ) async {
      late BuildContext host;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              host = context;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );
      var calls = 0;
      const typed = PluginLoginRequiredException(
        UnauthorizedPayload(
          pluginId: 'copy',
          message: 'startFavoriteAction undefined: login required',
        ),
      );
      final future = executeCloudFavoriteWorkflow(
        context: host,
        from: 'copy',
        comicId: 'fixture-comic',
        action: FavoriteWorkflowAction.add,
        currentStatus: false,
        legacyAllowCollected: false,
        invokePlugin:
            ({
              required pluginId,
              required fnPath,
              required core,
              required extern,
            }) async {
              calls++;
              expect(fnPath, 'startFavoriteAction');
              if (mode == 'completed') {
                return {
                  'status': 'completed',
                  'favorited': true,
                  'committed': true,
                };
              }
              if (mode == 'thrown') {
                throw typed;
              }
              if (mode == 'missing') {
                throw StateError('startFavoriteAction function path not found');
              }
              return {
                'status': 'failed',
                'committed': mode == 'committed',
                'errorCode': mode == 'unsupported'
                    ? 'UNSUPPORTED_ACTION'
                    : 'FAVORITE_REQUEST_FAILED',
                'message': mode == 'unsupported'
                    ? '点赞不受支持'
                    : jsonEncode({
                        'type': 'unauthorized',
                        'source': 'copy',
                        'message': '请先登录',
                      }),
              };
            },
      );
      if (mode == 'completed') {
        expect(
          (await future).favorited,
          isTrue,
          reason:
              'legacyAllowCollected=false does not disable a working modern action',
        );
      } else {
        await expectLater(
          future,
          throwsA(switch (mode) {
            'thrown' => same(typed),
            'returned' => isA<PluginLoginRequiredException>(),
            'missing' => isA<FavoriteWorkflowUnsupportedException>(),
            _ => isA<StateError>(),
          }),
        );
      }
      expect(calls, 1);
    });
  }

  for (final outcome in [
    'success',
    'cancel',
    'other-source',
    'unmounted',
    'failure',
  ]) {
    test(
      'login $outcome returns to caller and refreshes only same-source success',
      () async {
        final events = StreamController<PluginLoginSucceeded>();
        addTearDown(events.close);
        var refreshes = 0;
        final result = runPluginActionLogin(
          source: 'copy',
          loginEvents: events.stream,
          openLogin: () async {
            if (outcome == 'success' || outcome == 'unmounted') {
              events.add(const PluginLoginSucceeded('copy'));
            } else if (outcome == 'other-source') {
              events.add(const PluginLoginSucceeded('bika'));
            }
            if (outcome == 'failure') throw StateError('navigation failed');
          },
          refresh: () async {
            refreshes++;
          },
          isActive: () => outcome != 'unmounted',
        );
        if (outcome == 'failure') {
          await expectLater(result, throwsStateError);
        } else {
          expect(await result, outcome == 'success');
        }
        expect(refreshes, outcome == 'success' ? 1 : 0);
        expect(events.hasListener, isFalse);
      },
    );
  }
}
