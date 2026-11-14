import 'package:zephyr/page/video/video_account_backup.dart';
import 'package:zephyr/page/video/omofun_account_details_page.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'dart:io';
import 'package:zephyr/service/plugin_account_sync_coordinator.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'dart:async';
import 'package:flutter/cupertino.dart' as sdk;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/account/plugin_saved_accounts_page.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/service/plugin_account_authentication.dart';
import 'package:zephyr/service/plugin_account_profiles.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_theme_colors.dart';
import 'package:zephyr/widgets/native_view_occlusion.dart';
import '../test_helper.dart';

const _source = '78617c71-313f-42fe-9317-460d691890b2';

class _Auth extends PluginAccountAuthenticationService {
  _Auth() : super(_source);
  Completer<PluginAccountAuthentication>? pending;
  @override
  bool get hasApiVerification => true;
  @override
  Future<PluginAccountAuthentication> verify({
    bool includeSummary = false,
  }) async {
    if (pending case final pending?) return pending.future;
    final account = readHostPluginConfiguration(_source)['auth.account'];
    if (account is! String) throw const PluginAccountSwitchFailed();
    return PluginAccountAuthentication(
      serverIdentity: 'server-$account',
      label: 'Member $account',
    );
  }

  @override
  Future<void> signOut() async => replaceActivePluginAccount(_source, {});
}

class _SwitchReceiptAuth extends _Auth {
  int reads = 0;
  bool failRefresh = false;
  @override
  Future<PluginAccountAuthentication> verify({
    bool includeSummary = false,
  }) async {
    reads++;
    if (failRefresh)
      throw StateError('Synthetic post-switch transport failure');
    return super.verify();
  }

  @override
  Future<PluginAccountAuthentication> authenticate(
    PluginAccountProfile profile,
  ) async => const PluginAccountAuthentication(
    serverIdentity: 'server-B',
    label: 'Member B',
  );
}

class _SavedWebCookies implements VideoAccountCookies {
  _SavedWebCookies({this.empty = false});
  final bool empty;
  @override
  Future<List<Map<String, dynamic>>> read(Uri origin) async => empty
      ? []
      : [
          for (final name in ['user_id', 'user_name', 'user_check'])
            {
              'name': name,
              'value': 'synthetic-current-session',
              'domain': origin.host,
              'path': '/',
              'httpOnly': false,
              'secure': false,
              'expires': null,
            },
        ];
  @override
  Future<void> set(Uri origin, Map<String, dynamic> cookie) async {}
  @override
  Future<void> delete(Uri origin, Map<String, dynamic> cookie) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channels = <int, String>{};
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await TestObjectBoxHelper.setUpTestObjectBox();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    pluginSessionWriteFence.advance(_source);
    objectbox.pluginConfigBox.removeMany(
      objectbox.pluginConfigBox
          .getAll()
          .where((r) => r.name == _source)
          .map((r) => r.id)
          .toList(),
    );
    for (final account in ['B', 'A']) {
      replaceActivePluginAccount(_source, {
        'auth.account': account,
        'auth.authorization': 'private-$account',
      });
      await PluginAccountProfiles.rememberCurrent(
        _source,
        serverIdentity: 'server-$account',
        label: 'Member $account',
        select: account == 'A',
      );
    }
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final args = call.arguments as Map;
        final name = '${args['viewType']}.${args['id']}';
        channels[args['id'] as int] = name;
        messenger.setMockMethodCallHandler(
          MethodChannel(name),
          (_) async => null,
        );
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final name in channels.values) {
      messenger.setMockMethodCallHandler(MethodChannel(name), null);
    }
    channels.clear();
  });
  Future<void> back(WidgetTester tester) async {
    final widget = find.byType(SourceBackButton);
    final views = find.descendant(of: widget, matching: find.byType(UiKitView));
    if (views.evaluate().isNotEmpty) {
      final renders = <RenderUiKitView>[];
      void visit(RenderObject render) {
        if (render is RenderUiKitView) renders.add(render);
        render.visitChildren(visit);
      }

      visit(tester.element(views).findRenderObject()!);
      expect(renders, hasLength(1));
      final channel = channels[renders.single.viewController.id];
      expect(channel, isNotNull);
      tester.binding.channelBuffers.push(
        channel!,
        const StandardMethodCodec().encodeMethodCall(const MethodCall('press')),
        (_) {},
      );
    } else {
      await tester.tap(
        find.descendant(of: widget, matching: find.byTooltip(t.common.back)),
      );
    }
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Omo account details uses the existing saved-account root instead of a separate credential editor',
    (tester) async {
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('breeze-omo-account-host-'),
      ))!;
      final images = LocalAppearanceImages(rootDirectory: root);
      await tester.runAsync(images.load);
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final site = OmoSiteClient(
        home: Uri.parse('https://www.omofuna.com'),
        request: (_, _) async => {
          'kind': 'account',
          'account': {'id': '1', 'name': 'Member A', 'canComment': true},
        },
      );
      addTearDown(site.dispose);
      var websites = 0;
      final before = PluginAccountProfiles.read(_source).toJson();
      final samples = <Map<String, Object?>>[];
      final sourceNavigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [
            NativeCompositionObserver(
              geometryBasedOcclusion: true,
              diagnostics: samples.add,
              diagnosticBudget: 256,
            ),
          ],
          home: Navigator(
            key: sourceNavigator,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => OmoAccountDetailsPage(
                client: site,
                source: _source,
                images: images,
                onWebsite: (_, _, _) async {
                  websites++;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(t.videoCommunity.credentials), findsNothing);
      expect(find.text(t.coverPrivacy.imageLocalOnly), findsNothing);
      expect(find.text(t.omoAccount.websiteNote), findsNothing);
      final shortcut = find.byKey(const ValueKey('omo-account.saved-accounts'));
      await tester.scrollUntilVisible(shortcut, 250);
      await tester.tap(shortcut);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final destination = ModalRoute.of(
        tester.element(find.byType(PluginSavedAccountsPage)),
      )!;
      expect(destination.navigator, same(sourceNavigator.currentState));
      expect(destination, isA<sdk.CupertinoPageRoute<bool>>());
      expect(destination.animation!.value, inExclusiveRange(0, 1));
      expect(
        samples.any(
          (sample) =>
              sample['event'] == 'native-scene-audit' &&
              (sample['phase'] as String).endsWith('|forward'),
        ),
        isTrue,
        reason: 'the ancestor observer sees the installed nested route move',
      );
      await tester.pumpAndSettle();
      expect(find.byType(PluginSavedAccountsPage), findsOneWidget);
      expect(websites, 0);
      expect(PluginAccountProfiles.read(_source).toJson(), before);
      await back(tester);
      expect(find.byType(OmoAccountDetailsPage), findsOneWidget);
      expect(readHostPluginConfiguration(_source)['auth.account'], 'A');
      expect(websites, 0);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.iOS}),
  );

  testWidgets(
    'Copy saved row retries the selected account and distinguishes login rejection',
    (tester) async {
      const source = PluginAccountAuthenticationService.copy;
      replaceActivePluginAccount(source, {
        'auth.username': 'copy-host-test-member',
        'auth.token': 'synthetic-member-token',
      });
      await PluginAccountProfiles.rememberCurrent(
        source,
        label: 'Saved Copy member',
        serverIdentity: 'copy-host-test-id',
        select: true,
      );
      final id = (await PluginAccountProfiles.selected(source))!;
      var request = 0;
      var manualLogins = 0;
      var prepareCalls = 0;
      final service = PluginAccountAuthenticationService(
        source,
        call: (fn, _) async {
          expect(fn, 'getUserInfoBundle');
          expect(
            readHostPluginConfiguration(source)['auth.username'],
            'copy-host-test-member',
          );
          request++;
          if (request <= 2) throw StateError('Network request timed out');
          if (request == 3) {
            throw const PluginLoginRequiredException(
              UnauthorizedPayload(pluginId: source, message: 'Rejected'),
            );
          }
          return {
            'data': {
              'extern': {
                'userId': 'copy-host-test-id',
                'username': 'Saved Copy member',
              },
            },
          };
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PluginSavedAccountsPage(
            source: source,
            authentication: service,
            prepareSession: () async {
              prepareCalls++;
            },
            onAddAccount: () async {
              manualLogins++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(request, 1);
      expect(find.text(t.accountProfiles.needsVerification), findsOneWidget);
      final row = find.byKey(ValueKey('saved-account-$id'));
      // The selected saved row is a different account from the active bundle.
      replaceActivePluginAccount(source, {
        'auth.username': 'copy-previous-active-member',
        'auth.token': 'synthetic-previous-token',
      });
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(request, 2);
      expect(prepareCalls, 1);
      expect(
        readHostPluginConfiguration(source)['auth.token'],
        'synthetic-previous-token',
      );
      expect(find.text(t.login.networkUnavailable), findsOneWidget);
      expect(find.text(t.accountProfiles.continueLogin), findsNothing);
      expect(find.text(t.accountProfiles.savedSignInRequired), findsNothing);
      expect(find.textContaining('synthetic-member-token'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('saved-account-retry')));
      await tester.pumpAndSettle();
      expect(request, 3);
      expect(prepareCalls, 1);
      expect(
        readHostPluginConfiguration(source)['auth.token'],
        'synthetic-previous-token',
      );
      expect(find.text(t.accountProfiles.savedSignInRequired), findsOneWidget);
      expect(find.text(t.navigation.needLoginTitle), findsOneWidget);
      expect(find.text(t.accountProfiles.continueLogin), findsOneWidget);
      expect(manualLogins, 0);

      await tester.tap(find.byKey(const ValueKey('saved-account-retry')));
      await tester.pumpAndSettle();
      expect(request, 4);
      expect(find.text(t.accountProfiles.current), findsOneWidget);
      expect(await PluginAccountProfiles.selected(source), id);
      expect(
        readHostPluginConfiguration(source)['auth.token'],
        'synthetic-member-token',
      );
    },
  );

  for (final style in ['system', 'breeze']) {
    testWidgets(
      'saved accounts $style verifies before selection, retries, confirms removal and returns',
      (tester) async {
        final auth = _Auth(), preference = ValueNotifier(style);
        addTearDown(preference.dispose);
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: preference,
            child: MaterialApp(
              theme: ThemeData(
                brightness: style == 'system'
                    ? Brightness.light
                    : Brightness.dark,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PluginSavedAccountsPage(
                          source: _source,
                          authentication: auth,
                          onAddAccount: () async {},
                        ),
                      ),
                    ),
                    child: const Text('Open source accounts'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open source accounts'));
        await tester.pumpAndSettle();
        final b = PluginAccountProfiles.read(
          _source,
        ).profiles.values.singleWhere((p) => p.identity == 'B');
        final a = PluginAccountProfiles.read(
          _source,
        ).profiles.values.singleWhere((p) => p.identity == 'A');
        Finder row(String id) => find.byKey(ValueKey('saved-account-$id'));
        Finder removeAction(String id) =>
            find.byKey(ValueKey('download-swipe.saved-account-$id.delete'));
        Future<void> revealRemoval(String id) async {
          expect(removeAction(id), findsNothing);
          await tester.drag(row(id), const Offset(-160, 0));
          await tester.pumpAndSettle();
          final action = removeAction(id);
          expect(action.hitTestable(), findsOneWidget);
          expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
          final label = tester.widget<Text>(
            find.descendant(of: action, matching: find.text(t.common.delete)),
          );
          final deleteColor = label.style!.color!;
          final tray = tester.widget<Material>(
            find.byKey(ValueKey('download-swipe-tray.saved-account-$id')),
          );
          final red = HSVColor.fromColor(deleteColor);
          expect(red.hue, anyOf(lessThan(15), greaterThan(345)));
          expect(red.saturation, greaterThan(.65));
          expect(
            BreezeThemeColors.contrast(deleteColor, tray.color!),
            greaterThanOrEqualTo(4.5),
          );
          await tester.tap(action);
          await tester.pumpAndSettle();
        }

        expect(find.text(t.accountProfiles.current), findsOneWidget);
        auth.pending = Completer<PluginAccountAuthentication>();
        await tester.tap(find.byKey(ValueKey('saved-account-${b.id}')));
        await tester.pump();
        expect(await PluginAccountProfiles.selected(_source), isNull);
        auth.pending!.completeError(const PluginAccountSwitchFailed());
        auth.pending = null;
        await tester.pumpAndSettle();
        expect(find.text(t.accountProfiles.switchFailed), findsOneWidget);
        expect(
          readHostPluginConfiguration(_source)['auth.authorization'],
          'private-A',
        );
        await tester.tap(find.byKey(ValueKey('saved-account-${b.id}')));
        await tester.pumpAndSettle();
        expect(await PluginAccountProfiles.selected(_source), b.id);
        expect(
          PluginAccountProfiles.read(
            _source,
          ).profiles[a.id]!.bundle['auth.authorization'],
          'private-A',
        );
        await revealRemoval(b.id);
        expect(
          find.text(t.accountProfiles.removeCurrentConfirm),
          findsOneWidget,
        );
        await tester.tap(find.text(t.common.cancel));
        await tester.pumpAndSettle();
        expect(
          PluginAccountProfiles.read(_source).profiles[b.id]!.deleted,
          isFalse,
        );
        await revealRemoval(a.id);
        expect(find.text(t.accountProfiles.removeConfirm), findsOneWidget);
        // A session change after the prompt must not reinterpret this as a
        // confirmation to sign out a newly selected account.
        pluginSessionWriteFence.advance(_source);
        await tester.tap(find.text(t.common.delete));
        await tester.pumpAndSettle();
        expect(
          PluginAccountProfiles.read(_source).profiles[a.id]!.deleted,
          isFalse,
        );
        expect(await PluginAccountProfiles.selected(_source), b.id);
        await revealRemoval(a.id);
        await tester.tap(find.text(t.common.delete));
        await tester.pumpAndSettle();
        expect(
          PluginAccountProfiles.read(_source).profiles[a.id]!.deleted,
          isTrue,
        );
        expect(
          readHostPluginConfiguration(_source)['auth.authorization'],
          'private-B',
        );

        await revealRemoval(b.id);
        await tester.tap(find.text(t.common.delete));
        await tester.pumpAndSettle();
        expect(
          PluginAccountProfiles.read(_source).profiles[b.id]!.deleted,
          isTrue,
        );
        expect(
          readHostPluginConfiguration(_source)['auth.authorization'],
          isNull,
        );
        expect(find.textContaining('private-'), findsNothing);
        await back(tester);
        expect(find.text('Open source accounts'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
    testWidgets(
      'saved accounts $style keeps the actual switch receipt instead of demoting after a redundant refresh',
      (tester) async {
        final auth = _SwitchReceiptAuth(), preference = ValueNotifier(style);
        addTearDown(preference.dispose);
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: preference,
            child: MaterialApp(
              home: PluginSavedAccountsPage(
                source: _source,
                authentication: auth,
                onAddAccount: () async {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(auth.reads, 1);
        auth.failRefresh = true;
        final b = PluginAccountProfiles.read(
          _source,
        ).profiles.values.singleWhere((p) => p.identity == 'B');
        await tester.tap(find.byKey(ValueKey('saved-account-${b.id}')));
        await tester.pumpAndSettle();
        expect(
          auth.reads,
          1,
          reason:
              'the source transaction already performed authenticated readback',
        );
        expect(
          PluginAccountIdentities.current(_source)?.serverIdentity,
          'server-B',
        );
        expect(find.text(t.accountProfiles.current), findsOneWidget);
        expect(find.text(t.accountProfiles.needsVerification), findsNothing);
        expect(
          readHostPluginConfiguration(_source)['auth.authorization'],
          'private-B',
        );
        await savePluginConfigValue(_source, 'auth.checkin', {
          'checkedInDate': '2026-11-06',
        });
        await tester.pumpAndSettle();
        expect(find.text(t.accountProfiles.current), findsOneWidget);
        expect(auth.reads, 1);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
    testWidgets(
      'saved accounts $style bounded widths retain add return with keyboard and large text',
      (tester) async {
        final preference = ValueNotifier(style), auth = _Auth();
        addTearDown(preference.dispose);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.devicePixelRatio = 1;
        late BuildContext accountContext;
        for (final width in [320.0, 390.0, 440.0]) {
          tester.view.physicalSize = Size(width, 900);
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: preference,
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(1.6)),
                  child: child!,
                ),
                home: Builder(
                  builder: (context) {
                    accountContext = context;
                    return PluginSavedAccountsPage(
                      source: _source,
                      authentication: auth,
                      onAddAccount: () async {
                        await Navigator.of(accountContext).push(
                          MaterialPageRoute<void>(
                            builder: (_) => Scaffold(
                              appBar: AppBar(leading: const SourceBackButton()),
                              body: const TextField(
                                key: ValueKey('add-account-input'),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final add = find.byKey(const ValueKey('saved-account-add'));
          await tester.ensureVisible(add);
          await tester.tap(add);
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey('add-account-input')),
            'another-member',
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          await back(tester);
          expect(
            find.byKey(const ValueKey('saved-account-add')),
            findsOneWidget,
          );
          expect(
            PluginAccountProfiles.read(
              _source,
            ).profiles.values.where((p) => !p.deleted).length,
            2,
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
  for (final portable in [true, false]) {
    testWidgets(
      'saved Web account reconnects retired login reader before capture, portable=$portable',
      (tester) async {
        const source = 'ccc2fe17-c0a8-4fd8-a596-835772686404';
        final origin = Uri.parse('https://www.omofuna.com');
        pluginSessionWriteFence.advance(source);
        for (final row
            in objectbox.pluginConfigBox
                .getAll()
                .where((row) => row.name == source)
                .toList()) {
          objectbox.pluginConfigBox.remove(row.id);
        }
        final coordinator = PluginAccountSyncCoordinator.instance;
        const proof = PluginAccountAuthentication(
          serverIdentity: 'web-member-42',
          label: 'Current Web member',
        );
        Object? lease;
        final oldLease = await coordinator.registerStoredSession(
          source: source,
          origin: origin,
          cookies: _SavedWebCookies(),
          authenticated: () async => true,
          identity: () async => proof,
        );
        coordinator.unregister(source, oldLease);
        PluginAccountIdentities.confirm(
          source,
          proof.atOrigin(origin.origin),
          generation: pluginSessionWriteFence.generation(source),
        );
        expect(coordinator.hasProfileAccess(source), isFalse);
        var preparations = 0;
        Future<void> prepare() async {
          preparations++;
          lease = await coordinator.registerStoredSession(
            source: source,
            origin: origin,
            cookies: _SavedWebCookies(empty: !portable),
            authenticated: () async => true,
            identity: () async => proof,
          );
        }

        addTearDown(() {
          if (lease != null) coordinator.unregister(source, lease!);
        });
        await tester.pumpWidget(
          MaterialApp(
            home: PluginSavedAccountsPage(
              source: source,
              onAddAccount: () async {},
              prepareSession: prepare,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(preparations, 1);
        if (portable) {
          final stored = PluginAccountProfiles.read(
            source,
          ).profiles.values.where((p) => !p.deleted).single;
          expect(stored.serverIdentity, proof.serverIdentity);
          expect(stored.kind, 'web');
          expect(stored.bundle['account.backup'], isA<Map>());
          expect(find.text('Current Web member'), findsOneWidget);
          expect(find.text(t.accountProfiles.current), findsOneWidget);
          expect(find.text(t.accountProfiles.empty), findsNothing);
        } else {
          final stored = PluginAccountProfiles.read(
            source,
          ).profiles.values.singleWhere((p) => !p.deleted);
          expect(stored.serverIdentity, proof.serverIdentity);
          expect(PluginAccountProfiles.requiresWebLogin(stored), isTrue);
          expect(
            VideoAccountBackup.parse(
              stored.bundle['account.backup'],
              origin,
              source: source,
            ),
            isNull,
          );
          expect(
            find.text(t.accountProfiles.currentNeedsLogin),
            findsOneWidget,
          );
          expect(find.text('Current Web member'), findsOneWidget);
          expect(
            find.text(t.accountProfiles.empty),
            findsNothing,
            reason:
                'An authenticated but uncaptured session must not masquerade as no account',
          );
          expect(
            find.byKey(const ValueKey('saved-account-retry')),
            findsNothing,
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await tester.pumpWidget(
            MaterialApp(
              home: PluginSavedAccountsPage(
                source: source,
                onAddAccount: () async {},
                prepareSession: prepare,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            preparations,
            2,
            reason:
                'Reopening reconnects, rather than relying on the earlier receipt',
          );
          expect(
            PluginAccountProfiles.read(
              source,
            ).profiles.values.where((p) => !p.deleted),
            hasLength(1),
          );
          expect(
            find.text(t.accountProfiles.currentNeedsLogin),
            findsOneWidget,
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }
}
