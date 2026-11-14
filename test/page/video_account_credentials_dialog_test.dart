import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/page/account/plugin_saved_accounts_page.dart';
import 'package:zephyr/page/video/omofun_account_details_page.dart';
import 'package:zephyr/page/video/omofun_account_page.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';
import 'package:zephyr/page/video/video_account_credentials.dart';
import 'package:zephyr/page/video/video_account_credentials_dialog.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/service/plugin_account_profiles.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

import '../test_helper.dart';

const _source = '78617c71-313f-42fe-9317-460d691890b2';
final _home = Uri.parse('https://credentials.example/');
const _account = Key('video-credentials.account');
const _password = Key('video-credentials.password');
Finder _button(String action) =>
    find.byKey(ValueKey('video-credentials.$action'));
Finder _confirmation() =>
    find.widgetWithText(AlertDialog, t.videoCommunity.deleteSavedLoginTitle);
String _stored() =>
    onLoadPluginConfig(_source, VideoAccountCredentials.key, '{}');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    objectbox.pluginConfigBox.removeAll();
    await VideoAccountCredentials.save(
      _source,
      _home,
      'synthetic-account',
      'synthetic-password',
    );
  });
  Future<void> mountDialog(
    WidgetTester tester, {
    String style = 'breeze',
    Future<void> Function(String, String)? save,
    Future<void> Function()? clear,
  }) async {
    final preference = ValueNotifier(style);
    addTearDown(preference.dispose);
    await tester.pumpWidget(
      AppInterfaceStyleScope(
        style: preference,
        child: MaterialApp(
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => showVideoAccountCredentialsDialog(
                      context,
                      initial: VideoAccountCredentials.load(_source, _home),
                      onSave:
                          save ??
                          (account, password) => VideoAccountCredentials.save(
                            _source,
                            _home,
                            account,
                            password,
                          ),
                      onDelete:
                          clear ??
                          () => VideoAccountCredentials.clear(_source, _home),
                    ),
                    child: const Text('Open synthetic credentials'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open synthetic credentials'));
    await tester.pumpAndSettle();
    expect(find.byKey(_account), findsOneWidget);
    final navigators = tester
        .stateList<NavigatorState>(find.byType(Navigator))
        .toList();
    expect(navigators, hasLength(2));
    expect(
      Navigator.of(tester.element(find.byKey(_account))),
      same(navigators.first),
    );
  }

  for (final style in ['system', 'breeze']) {
    testWidgets(
      '$style cancellation, barrier and back leave credentials and sync record untouched',
      (tester) async {
        final before = _stored();
        var clears = 0;
        for (final exit in ['cancel', 'barrier', 'back']) {
          await mountDialog(
            tester,
            style: style,
            clear: () async {
              clears++;
              await VideoAccountCredentials.clear(_source, _home);
            },
          );
          await tester.tap(_button('delete'));
          await tester.pumpAndSettle();
          expect(_confirmation(), findsOneWidget);
          expect(
            find.text(t.videoCommunity.deleteSavedLoginPrompt),
            findsOneWidget,
          );
          if (exit == 'cancel') {
            await tester.tap(
              find.descendant(
                of: _confirmation(),
                matching: find.text(t.common.cancel),
              ),
            );
          } else if (exit == 'barrier') {
            await tester.tapAt(const Offset(2, 2));
          } else {
            await tester.binding.handlePopRoute();
          }
          await tester.pumpAndSettle();
          expect(_confirmation(), findsNothing);
          expect(find.byKey(_account), findsOneWidget);
          expect(clears, 0);
          expect(_stored(), before);
          if (exit == 'cancel') {
            await tester.tap(_button('cancel'));
          } else if (exit == 'barrier') {
            await tester.tapAt(const Offset(2, 2));
          } else {
            await tester.binding.handlePopRoute();
          }
          await tester.pumpAndSettle();
          expect(find.byKey(_account), findsNothing);
          expect(_stored(), before);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
  testWidgets(
    'delete is explicit, locks repeat callbacks and only writes after confirmation',
    (tester) async {
      final before = _stored();
      final pending = Completer<void>();
      var clears = 0;
      await mountDialog(
        tester,
        clear: () async {
          clears++;
          await pending.future;
          await VideoAccountCredentials.clear(_source, _home);
        },
      );
      final start = tester.widget<TextButton>(_button('delete')).onPressed!;
      start();
      start();
      await tester.pumpAndSettle();
      expect(_confirmation(), findsOneWidget);
      expect(clears, 0);
      expect(_stored(), before);
      final confirm = tester
          .widget<TextButton>(
            find.descendant(
              of: _confirmation(),
              matching: find.widgetWithText(TextButton, t.common.delete),
            ),
          )
          .onPressed!;
      confirm();
      confirm();
      await tester.pump(const Duration(milliseconds: 350));
      expect(clears, 1);
      expect(_stored(), before);
      expect(tester.widget<TextButton>(_button('save')).onPressed, isNull);
      expect(tester.widget<TextButton>(_button('delete')).onPressed, isNull);
      start();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byKey(_account), findsOneWidget);
      expect(clears, 1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(_account), findsNothing);
      expect(VideoAccountCredentials.load(_source, _home), isNull);
      expect(_stored(), contains('"deleted":true'));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'failed deletion keeps saved data and editors and permits a confirmed retry',
    (tester) async {
      final before = _stored();
      var calls = 0;
      await mountDialog(
        tester,
        clear: () async {
          calls++;
          if (calls == 1) throw StateError('synthetic write failure');
          await VideoAccountCredentials.clear(_source, _home);
        },
      );
      Future<void> confirm() async {
        await tester.tap(_button('delete'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: _confirmation(),
            matching: find.text(t.common.delete),
          ),
        );
        await tester.pumpAndSettle();
      }

      await confirm();
      expect(_stored(), before);
      expect(find.text(t.error.saveFailed), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(_account)).controller!.text,
        'synthetic-account',
      );
      expect(
        tester.widget<TextField>(find.byKey(_password)).controller!.text,
        'synthetic-password',
      );
      await confirm();
      expect(calls, 2);
      expect(VideoAccountCredentials.load(_source, _home), isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'save failure preserves drafts and the old saved credentials without logging them',
    (tester) async {
      final before = _stored();
      var calls = 0;
      await mountDialog(
        tester,
        save: (_, _) async {
          calls++;
          throw StateError('synthetic write failure');
        },
      );
      await tester.enterText(find.byKey(_account), 'edited-account');
      await tester.enterText(find.byKey(_password), 'edited-password');
      await tester.tap(_button('save'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(_stored(), before);
      expect(find.text(t.error.saveFailed), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(_account)).controller!.text,
        'edited-account',
      );
      expect(
        tester.widget<TextField>(find.byKey(_password)).controller!.text,
        'edited-password',
      );
      await tester.tap(_button('cancel'));
      await tester.pumpAndSettle();
      expect(_stored(), before);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'editors remain alive during the reverse transition and dispose on unmount',
    (tester) async {
      await mountDialog(tester);
      final account = tester
          .widget<TextField>(find.byKey(_account))
          .controller!;
      final password = tester
          .widget<TextField>(find.byKey(_password))
          .controller!;
      await tester.tap(_button('cancel'));
      await tester.pump();
      expect(
        find.byKey(_account),
        findsOneWidget,
        reason: 'the route is still rendering its reverse transition',
      );
      expect(() {
        account.text = 'exit-account';
        password.text = 'exit-password';
      }, returnsNormally);
      await tester.pumpAndSettle();
      expect(find.byKey(_account), findsNothing);
      expect(() => account.addListener(() {}), throwsFlutterError);
      expect(() => password.addListener(() {}), throwsFlutterError);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'real Omo account entry removes a noncurrent saved account only after confirmation',
    (tester) async {
      final operations = <String>[];
      final before = _stored();
      await PluginAccountProfiles.rememberCredentials(_source, {
        'version': 1,
        'account': 'secondary-account',
        'password': 'synthetic-secondary-password',
        'origin': _home.origin,
        'updatedAt': 1,
        'deleted': false,
      });
      final profile = PluginAccountProfiles.read(_source).profiles.values
          .singleWhere((profile) => profile.identity == 'secondary-account');
      final client = OmoSiteClient(
        home: _home,
        request: (operation, _) async {
          operations.add(operation);
          return {
            'kind': 'account',
            'account': {
              'id': 'synthetic',
              'name': 'Synthetic account',
              'group': 'Member',
            },
          };
        },
      );
      addTearDown(client.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OmoAccountPage(
              client: client,
              source: _source,
              active: true,
              onLocalHistory: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('omo-my.avatar')));
      await tester.pumpAndSettle();
      final savedAccounts = find.byKey(
        const ValueKey('omo-account.saved-accounts'),
      );
      await tester.scrollUntilVisible(
        savedAccounts,
        250,
        scrollable: find
            .descendant(
              of: find.byType(OmoAccountDetailsPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(savedAccounts);
      await tester.pumpAndSettle();
      expect(find.byType(PluginSavedAccountsPage), findsOneWidget);
      final row = find.byKey(ValueKey('saved-account-${profile.id}'));
      Future<void> openRemove() async {
        await tester.drag(row, const Offset(-160, 0));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(
            ValueKey('download-swipe.saved-account-${profile.id}.delete'),
          ),
        );
        await tester.pumpAndSettle();
      }

      await openRemove();
      expect(_stored(), before);
      expect(find.text(t.accountProfiles.removeConfirm), findsOneWidget);
      await tester.tap(find.text(t.common.cancel));
      await tester.pumpAndSettle();
      expect(
        PluginAccountProfiles.read(_source).profiles[profile.id]!.deleted,
        isFalse,
      );
      await openRemove();
      await tester.tap(find.text(t.common.delete));
      await tester.pumpAndSettle();
      expect(
        PluginAccountProfiles.read(_source).profiles[profile.id]!.deleted,
        isTrue,
      );
      expect(row, findsNothing);
      expect(_stored(), before);
      expect(client.account?.id, 'synthetic');
      expect(
        operations,
        isNot(contains('logout')),
        reason:
            'Removing a different saved account must not sign out the current website session',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'small keyboard host keeps the credential actions reachable and cancellable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final before = _stored();
      await mountDialog(tester);
      expect(tester.getRect(_button('cancel')).bottom, lessThanOrEqualTo(308));
      expect(tester.getRect(_button('save')).bottom, lessThanOrEqualTo(308));
      expect(
        tester.getSize(_button('cancel')).height,
        greaterThanOrEqualTo(44),
      );
      await tester.tap(_button('cancel'));
      await tester.pumpAndSettle();
      expect(_stored(), before);
      expect(tester.takeException(), isNull);
    },
  );
}
