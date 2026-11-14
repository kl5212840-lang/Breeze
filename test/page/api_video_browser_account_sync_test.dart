import 'package:zephyr/page/video/video_site_browser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/service/plugin_account_profiles.dart';
import '../test_helper.dart';
import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/video/api_video_browser.dart';
import 'package:zephyr/page/video/video_account_backup.dart';
import 'package:zephyr/service/plugin_account_sync_coordinator.dart';

class _Cookies implements VideoAccountCookies {
  @override
  Future<List<Map<String, dynamic>>> read(Uri origin) async => [];
  @override
  Future<void> set(Uri origin, Map<String, dynamic> cookie) async {}
  @override
  Future<void> delete(Uri origin, Map<String, dynamic> cookie) async {}
}

class _AccountGate extends PluginAccountSyncCoordinator {
  _AccountGate() : super.forTesting(readConfiguration: (_) => {});
  final restore = Completer<void>();
  final lease = Object();
  Future<bool> Function()? authenticated;
  Future<PluginAccountAuthentication?> Function()? identity;
  final captureModes=<bool>[];
  String? capturedIdentity;
  bool active = false;
  int captures = 0, registrations = 0;
  @override
  Future<Object> registerStoredSession({
    required String source,
    required Uri origin,
    required VideoAccountCookies cookies,
    required Future<bool> Function() authenticated,
    Future<PluginAccountAuthentication?> Function()? identity,
    Future<void> Function()? continueLogin,
  }) async {
    this.authenticated = authenticated;
    this.identity=identity;
    expect(identity,isNotNull,reason:'Omo exposes fresh same-store identity');
    expect(continueLogin,isNull,reason:'the retained API browser is not a second login page');
    registrations++;
    active = true;
    return lease;
  }

  @override
  bool isRegistered(String source, Object lease) => active;
  @override
  Future<AccountSessionRestoreResult> restoreOnEntry(String source) async {
    await restore.future;
    return AccountSessionRestoreResult.restored;
  }

  @override
  Future<void> captureAuthenticated(String source,{bool explicitSave=false}) async {
    captures++;captureModes.add(explicitSave);
    final proof=await identity!();
    expect(proof,isNotNull);
    capturedIdentity=proof!.serverIdentity;
  }

  @override
  void unregister(String source, Object lease) {
    active = false;
  }
}

class _Browser extends PlatformInAppWebViewController implements VideoBrowserBackgroundLifetime {
  _Browser()
    : super.implementation(
        const PlatformInAppWebViewControllerCreationParams(id: 'account-gate'),
      );
  final loads = <Uri>[];
  int accountCalls = 0;
  int retains=0,releases=0;
  @override Future<void> retainBackground() async {retains++;}
  @override Future<void> releaseBackground() async {releases++;}
  @override
  Future<WebUri?> getUrl() async =>
      loads.isEmpty ? null : WebUri('${loads.last}');
  @override
  Future<void> loadUrl({
    required URLRequest urlRequest,
    Uri? iosAllowingReadAccessTo,
    WebUri? allowingReadAccessTo,
  }) async {
    loads.add(Uri.parse('${urlRequest.url}'));
  }

  @override
  Future<dynamic> evaluateJavascript({
    required String source,
    ContentWorld? contentWorld,
  }) async => source == 'String(performance.timeOrigin)'
      ? 'old'
      : {'url': '${loads.last}', 'documentId': 'new', 'cards': [], 'links': []};
  @override
  Future<CallAsyncJavaScriptResult?> callAsyncJavaScript({
    required String functionBody,
    Map<String, dynamic> arguments = const {},
    ContentWorld? contentWorld,
  }) async {
    accountCalls++;
    return CallAsyncJavaScriptResult(
      value: {
        'kind': 'account',
        'account': {'id': 'synthetic-user'},
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await TestObjectBoxHelper.setUpTestObjectBox();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  test(
    'existing Omo browser waits for restore, then captures with a nonrecursive fresh account read',
    () async {
      final coordinator = _AccountGate();
      final platform = _Browser();
      final web = InAppWebViewController.fromPlatform(platform: platform);
      final home = Uri.parse('https://site.example/');
      final session = ApiVideoBrowserSession(
        home: home,
        paths: ['/'],
        itemPrefix: '/anime/',
        accountSource: 'omo-source',
        accountCoordinator: coordinator,
        accountCookieAdapter: (_) => _Cookies(),
      );
      session.created(web);
      final operation = session.requestOmoSite('account', const {});
      await Future<void>.delayed(Duration.zero);
      expect(platform.loads, isEmpty);
      expect(platform.accountCalls, 0);
      coordinator.restore.complete();
      for (var i = 0; i < 10 && platform.loads.isEmpty; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(platform.loads, [home]);
      await session.loaded(web, home);
      expect((await operation)['kind'], 'account');
      await Future<void>.delayed(Duration.zero);
      expect(coordinator.captures, 1);
      expect(coordinator.capturedIdentity,'synthetic-user');
      expect(coordinator.captureModes,[false],reason:'passive account read must not revive a removed saved profile');
      expect(
        platform.accountCalls,
        2,
        reason: 'one request and one fresh backup proof; no recursion',
      );
      // A temporary foreground login host can replace the source registration.
      // The retained API browser re-registers the same controller on its next use.
      coordinator.active = false;
      await session.requestOmoSite('account', const {});
      await Future<void>.delayed(Duration.zero);
      expect(coordinator.registrations, 2);
      expect(platform.loads, [
        home,
      ], reason: 're-registration creates no additional navigation');
      session.dispose();
      expect(coordinator.active, isFalse);
    },
  );
  test('retained media browser releases account ownership as soon as source owner closes', () async {
    final coordinator=_AccountGate(),platform=_Browser();
    final session=ApiVideoBrowserSession(home:Uri.parse('https://site.example/'),paths:['/'],itemPrefix:'/anime/',
      accountSource:'omo-source',accountCoordinator:coordinator,accountCookieAdapter:(_)=>_Cookies());
    session.created(InAppWebViewController.fromPlatform(platform:platform));
    coordinator.restore.complete();await Future<void>.delayed(Duration.zero);
    final release=await session.retainForDownloads();
    expect(coordinator.active,isTrue);expect(platform.retains,1);
    session.dispose();
    expect(coordinator.active,isFalse,reason:'a retained download is not a live account UI owner');
    expect(platform.releases,0,reason:'account retirement must not stop media downloads');
    await release();await release();
    expect(platform.releases,1);
  });

}
