import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/video/video_account_backup.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/plugin_account_profiles.dart';
import 'package:zephyr/service/plugin_account_sync_coordinator.dart';

final _origin=Uri.parse('https://site.example');
Map<String,dynamic> _cookie(String value)=>{'name':'session','value':value,
  'domain':_origin.host,'path':'/','secure':true,'httpOnly':true,'expires':null};
class _Cookies implements VideoAccountCookies {
  List<Map<String,dynamic>> values=[_cookie('synthetic-A')];
  @override Future<List<Map<String,dynamic>>> read(Uri origin) async {
    expect(origin,_origin);return values.map((c)=>Map<String,dynamic>.from(c)).toList();
  }
  @override Future<void> set(Uri origin,Map<String,dynamic> cookie) async {
    expect(origin,_origin);values.removeWhere((c)=>c['name']==cookie['name']);values.add(Map<String,dynamic>.from(cookie));
  }
  @override Future<void> delete(Uri origin,Map<String,dynamic> cookie) async {
    expect(origin,_origin);values.removeWhere((c)=>c['name']==cookie['name']);
  }
}
final _target=PluginAccountProfile(id:'fixture',revision:1,deleted:false,kind:'web',
  identity:'server-B',serverIdentity:'server-B',origin:_origin.origin,bundle:{
    'account.backup':{'version':1,'origin':_origin.origin,'cookies':[_cookie('synthetic-B')]}});
Future<Object> _register(PluginAccountSyncCoordinator coordinator,_Cookies cookies,
  Future<PluginAccountAuthentication?> Function() identity)=>coordinator.register(
    source:'web-fixture',origin:_origin,cookies:cookies,identity:identity,
    authenticated:() async=>true,
    accountSync:{'version':1,'origin':_origin.origin,'readFn':'read','saveFn':'save','forgetFn':'forget'},
    call:(_,_) async=>{'data':{'saved':true}});
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(()=>SharedPreferences.setMockInitialValues({}));
  test('Web profile waits for fresh same-store identity after actual cookie readback',() async {
    final cookies=_Cookies(), proof=Completer<PluginAccountAuthentication?>();
    final coordinator=PluginAccountSyncCoordinator.forTesting(readConfiguration:(_)=>{});
    await _register(coordinator,cookies,() {
      expect(cookies.values.single['value'],'synthetic-B');return proof.future;
    });
    var complete=false;
    final operation=coordinator.activateProfile('web-fixture',_target).then((value){complete=true;return value;});
    await Future<void>.delayed(Duration.zero);expect(complete,isFalse);
    proof.complete(const PluginAccountAuthentication(serverIdentity:'server-B'));
    expect((await operation).serverIdentity,'server-B');
    expect(cookies.values.single['value'],'synthetic-B');
  });
  test('rejected Web identity rolls candidate cookies back and no live browser never pretends to authenticate',() async {
    final cookies=_Cookies();
    final coordinator=PluginAccountSyncCoordinator.forTesting(readConfiguration:(_)=>{});
    await expectLater(coordinator.activateProfile('web-fixture',_target),throwsA(isA<PluginAccountNeedsLogin>()));
    await _register(coordinator,cookies,() async=>null);
    await expectLater(coordinator.activateProfile('web-fixture',_target),throwsA(isA<PluginAccountSwitchFailed>()));
    expect(cookies.values.single['value'],'synthetic-A');
  });
  test('late Web verification cannot roll back a newer source login or a replacement view store',() async {
    final cookies=_Cookies(),newCookies=_Cookies()..values=[_cookie('synthetic-C')];
    final coordinator=PluginAccountSyncCoordinator.forTesting(readConfiguration:(_)=>{});
    await _register(coordinator,cookies,() async {
      await _register(coordinator,newCookies,() async=>const PluginAccountAuthentication(serverIdentity:'server-C'));
      return const PluginAccountAuthentication(serverIdentity:'server-B');
    });
    await expectLater(coordinator.activateProfile('web-fixture',_target),throwsA(isA<PluginSessionChanged>()));
    expect(newCookies.values.single['value'],'synthetic-C');
    expect(cookies.values.single['value'],'synthetic-B',reason:'the closed old view is not modified after replacement');
    await _register(coordinator,newCookies,() async {
      pluginSessionWriteFence.advance('web-fixture');newCookies.values=[_cookie('synthetic-D')];
      return const PluginAccountAuthentication(serverIdentity:'server-B');
    });
    await expectLater(coordinator.activateProfile('web-fixture',_target),throwsA(isA<PluginSessionChanged>()));
    expect(newCookies.values.single['value'],'synthetic-D');
  });
}
