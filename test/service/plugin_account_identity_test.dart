import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/plugin_account_authentication.dart';
import 'package:zephyr/service/plugin_account_profiles.dart';
import 'package:zephyr/service/plugin_account_sync_coordinator.dart';
import 'package:zephyr/page/video/video_account_backup.dart';
import 'package:zephyr/page/video/video_site_verified_identity.dart';
import '../test_helper.dart';
const _source='78617c71-313f-42fe-9317-460d691890b2';
class _UnavailableCookies implements VideoAccountCookies {
  int writes=0;
  @override Future<List<Map<String,dynamic>>> read(Uri origin) async=>throw StateError('Synthetic store unavailable');
  @override Future<void> set(Uri origin,Map<String,dynamic> cookie) async {writes++;}
  @override Future<void> delete(Uri origin,Map<String,dynamic> cookie) async {writes++;}
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {SharedPreferences.setMockInitialValues({});await TestObjectBoxHelper.setUpTestObjectBox();});tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    objectbox.pluginConfigBox.removeAll();
    pluginSessionWriteFence.advance(_source);
    pluginSessionWriteFence.advance(PluginAccountAuthenticationService.copy);
    replaceActivePluginAccount(_source,{'auth.account':'A','auth.authorization':'token-A'});
  });
  test('confirmed switch publishes after seal and checkin/backup metadata cannot demote it',() async {
    await PluginAccountProfiles.rememberCurrent(_source,serverIdentity:'server-A',select:true);
    replaceActivePluginAccount(_source,{'auth.account':'B','auth.authorization':'token-B','auth.userInfo':{'uid':'server-B','nickName':'before'}});
    await PluginAccountProfiles.rememberCurrent(_source,serverIdentity:'server-B');
    final b=PluginAccountProfiles.read(_source).profiles.values.singleWhere((p)=>p.identity=='B');
    replaceActivePluginAccount(_source,{'auth.account':'A','auth.authorization':'token-A'});
    await PluginAccountProfiles.switchTo(_source,b.id,authenticate:(_) async=>const PluginAccountAuthentication(serverIdentity:'server-B',label:'Current B'));
    final receipt=PluginAccountIdentities.current(_source);
    expect(receipt?.serverIdentity,'server-B');
    expect(pluginSessionWriteFence.isChanging(_source),isFalse);
    await savePluginConfigValue(_source,'auth.checkin',{'date':'2026-11-06','signed':true});
    await savePluginConfigValue(_source,'auth.userInfo',{'uid':'server-B','nickName':'changed','avatar':'new-avatar'});
    await savePluginConfigValue(_source,'account.credentials',{'version':1,'account':'B','password':'saved','updatedAt':999});
    expect(PluginAccountIdentities.current(_source),same(receipt));
    expect(PluginAccountIdentities.current('another-source'),isNull);
    await savePluginConfigValue(_source,'auth.authorization','new-token');
    expect(PluginAccountIdentities.current(_source),isNull);
  });
  test('fresh website identity remains usable when portable cookie enumeration fails; signed-out is distinct',() async {
    final cookies=_UnavailableCookies(),home=Uri.parse('https://site.example');
    final coordinator=PluginAccountSyncCoordinator.forTesting(readConfiguration:readHostPluginConfiguration);
    var signedOut=false;
    await coordinator.registerStoredSession(source:_source,origin:home,cookies:cookies,
      authenticated:() async=>true,identity:() async {
        if(signedOut)throw const PluginAccountAuthenticationRejected();
        return const PluginAccountAuthentication(serverIdentity:'web-42',label:'Website member');
      });
    await coordinator.captureAuthenticated(_source);
    expect(readHostPluginConfiguration(_source)['account.backup'], isNull);
    expect(PluginAccountIdentities.current(_source)?.label,'Website member');
    expect(PluginAccountIdentities.current(_source)?.origin,home.origin);
    expect(cookies.writes,0);
    signedOut=true;expect(await coordinator.refreshCurrentIdentity(_source),isNull);
    expect(PluginAccountIdentities.current(_source),isNull);expect(cookies.writes,0);
  });
  test('late API identity cannot replace a newer session receipt',() async {
    final source=PluginAccountAuthenticationService.copy,gate=Completer<Map<String,dynamic>>();
    replaceActivePluginAccount(source,{'auth.username':'A','auth.token':'token-A'});
    final auth=PluginAccountAuthenticationService(source,call:(_,_)=>gate.future);
    final pending=auth.verify();
    pluginSessionWriteFence.advance(source);
    replaceActivePluginAccount(source,{'auth.username':'B','auth.token':'token-B'});
    PluginAccountIdentities.confirm(source,const PluginAccountAuthentication(serverIdentity:'copy-B',label:'Current B'),generation:pluginSessionWriteFence.generation(source));
    gate.complete({'data':{'extern':{'userId':'copy-A','username':'Old A'}}});
    await expectLater(pending,throwsA(isA<PluginSessionChanged>()));
    expect(PluginAccountIdentities.current(source)?.serverIdentity,'copy-B');
  });
  test('website adapter accepts real numeric UID, rejects malformed identity, and separates CF from signout',() {
    final home=Uri.parse('https://site.example');
    expect(videoSiteVerifiedIdentity({'id':'123','label':'Member'},home)?.serverIdentity,'123');
    expect(videoSiteVerifiedIdentity({'id':'123\$'},home),isNull);
    expect(videoSiteVerifiedIdentity({},home),isNull);
    expect(()=>videoSiteVerifiedIdentity({'status':'signedOut'},home),throwsA(isA<PluginAccountAuthenticationRejected>()));
  });
}
