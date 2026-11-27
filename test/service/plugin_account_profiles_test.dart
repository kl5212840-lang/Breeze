import 'package:zephyr/main.dart' show objectbox;
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/sync/plugin_account_profiles_data.dart';
import 'package:zephyr/network/sync/sync_payload_compatibility.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart';
import 'package:zephyr/service/plugin_account_profiles.dart';

import '../test_helper.dart';
const _source='78617c71-313f-42fe-9317-460d691890b2';
Future<void> _active(String account) async {
  replaceActivePluginAccount(_source,{'auth.account':account,'auth.password':'password-$account','auth.authorization':'token-$account'});
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    objectbox.pluginConfigBox.removeMany(objectbox.pluginConfigBox.getAll()
      .where((row)=>row.name==_source).map((row)=>row.id).toList());
    await savePluginConfigValue(_source,pluginAccountProfilesKey,
      PluginAccountProfilesData(_source,const {}).toJson());
    await _active('A');
    await PluginAccountProfiles.rememberCurrent(_source,serverIdentity:'server-A',select:true);
    await _active('B');
    await PluginAccountProfiles.rememberCurrent(_source,serverIdentity:'server-B');
    await _active('A');
  });

  test('login hint requires the local selection and an exact active account', () async {
    expect(await PluginAccountProfiles.currentLoginHint(_source), 'A');
    await _active('B');
    expect(
      await PluginAccountProfiles.currentLoginHint(
        _source, legacySessionKey: 'auth.authorization',
      ),
      isNull,
    );
    replaceActivePluginAccount(_source, {});
    expect(await PluginAccountProfiles.currentLoginHint(_source), isNull);
    expect(PluginAccountProfiles.read(_source).profiles.values, hasLength(2));
  });

  test('a token-only login cannot inherit the previous account password', () async {
    await PluginAccountProfiles.submitLogin(
      _source,
      submit: () async {
        replaceActivePluginAccount(_source, {
          'auth.account': 'new-legacy-account',
          'auth.authorization': 'new-legacy-session',
          'auth.password': 'password-A',
        });
      },
    );
    final profiles = PluginAccountProfiles.read(_source).profiles.values;
    final current = profiles.singleWhere((entry) => entry.identity == 'new-legacy-account');
    final previous = profiles.singleWhere((entry) => entry.identity == 'A');
    expect(PluginAccountProfiles.savedNativePassword(current), isNull);
    expect(PluginAccountProfiles.savedNativePassword(previous), 'password-A');
  });

  test('legacy active login can seed its username without reading saved list order', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PluginAccountProfiles.selectedKey);
    await _active('legacy');
    expect(await PluginAccountProfiles.currentLoginHint(_source), 'legacy');
    expect(
      await PluginAccountProfiles.currentLoginHint(
        _source, legacySessionKey: 'auth.authorization',
      ),
      'legacy',
    );
    replaceActivePluginAccount(_source, {'auth.account': 'unverified-draft'});
    expect(
      await PluginAccountProfiles.currentLoginHint(
        _source, legacySessionKey: 'auth.authorization',
      ),
      isNull,
    );
  });

  test('real DB switch snapshots old account and commits selection only after positive readback',() async {
    final records=PluginAccountProfiles.read(_source);
    final b=records.profiles.values.singleWhere((p)=>p.identity=='B');
    final pending=Completer<PluginAccountAuthentication>();
    final result=PluginAccountProfiles.switchTo(_source,b.id,authenticate:(profile) {
      expect(readHostPluginConfiguration(_source)['auth.authorization'],'token-B');
      return pending.future;
    });
    await Future<void>.delayed(Duration.zero);
    expect(await PluginAccountProfiles.selected(_source),isNull,
      reason:'the compatibility view is not confirmed selection');
    pending.complete(const PluginAccountAuthentication(serverIdentity:'server-B'));
    await result;
    expect(await PluginAccountProfiles.selected(_source),b.id);
    final a=PluginAccountProfiles.read(_source).profiles.values.singleWhere((p)=>p.identity=='A');
    expect(a.bundle['auth.authorization'],'token-A');
    expect(jsonDecode(onLoadPluginConfig(_source,pluginAccountProfilesKey,'null'))['value'],isNull,
      reason:'plugin code cannot read the other saved accounts');
  });
  test('a queued save cannot attach a stale receipt to the next account', () async {
    const proofA = PluginAccountAuthentication(serverIdentity: 'server-A');
    expect(
      PluginAccountIdentities.confirm(
        _source,
        proofA,
        generation: pluginSessionWriteFence.generation(_source),
      ),
      isTrue,
    );
    final b = PluginAccountProfiles.read(_source)
        .profiles
        .values
        .singleWhere((profile) => profile.identity == 'B');
    final authentication = Completer<PluginAccountAuthentication>();
    final switching = PluginAccountProfiles.switchTo(
      _source,
      b.id,
      authenticate: (_) => authentication.future,
    );
    // The switch owns the queue but has not advanced the session yet.
    expect(PluginAccountIdentities.current(_source), same(proofA));
    final saving = expectLater(
      PluginAccountProfiles.rememberVerifiedCurrent(_source, proofA),
      throwsA(isA<PluginSessionChanged>()),
    );
    authentication.complete(
      const PluginAccountAuthentication(serverIdentity: 'server-B'),
    );
    await switching;
    await saving;
    expect(
      PluginAccountProfiles.read(_source).profiles[b.id]?.serverIdentity,
      'server-B',
    );
    expect(await PluginAccountProfiles.selected(_source), b.id);
  });

  test('failed verification preserves old active fields and selection; newer owner is never rolled back',() async {
    final b=PluginAccountProfiles.read(_source).profiles.values.singleWhere((p)=>p.identity=='B');
    final before=await PluginAccountProfiles.selected(_source);
    await expectLater(PluginAccountProfiles.switchTo(_source,b.id,authenticate:(_) async=>
      throw const PluginAccountSwitchFailed()),throwsA(isA<PluginAccountSwitchFailed>()));
    expect(readHostPluginConfiguration(_source)['auth.authorization'],'token-A');
    expect(await PluginAccountProfiles.selected(_source),before);
    await expectLater(PluginAccountProfiles.switchTo(_source,b.id,authenticate:(_) async {
      pluginSessionWriteFence.advance(_source);
      replaceActivePluginAccount(_source,{'auth.account':'C','auth.authorization':'token-C'});
      return const PluginAccountAuthentication(serverIdentity:'server-B');
    }),throwsA(isA<PluginSessionChanged>()));
    expect(readHostPluginConfiguration(_source)['auth.account'],'C');
  });
  test('removing saved current account signs out but never resurrects through automatic snapshots',() async {
    final a=PluginAccountProfiles.read(_source).profiles.values.singleWhere((p)=>p.identity=='A');
    final b=PluginAccountProfiles.read(_source).profiles.values.singleWhere((p)=>p.identity=='B');
    await expectLater(PluginAccountProfiles.delete(_source,a.id),throwsA(isA<PluginAccountNeedsLogin>()));
    expect(PluginAccountProfiles.read(_source).profiles[a.id]!.deleted,isFalse);
    await PluginAccountProfiles.delete(_source,a.id,signOutCurrent:() async {
      replaceActivePluginAccount(_source,{});
    });
    expect(readHostPluginConfiguration(_source)['auth.authorization'],isNull);
    await _active('A');
    await PluginAccountProfiles.rememberCurrent(_source);
    expect(PluginAccountProfiles.read(_source).profiles[a.id]!.deleted,isTrue);
    await PluginAccountProfiles.switchTo(_source,b.id,authenticate:(_) async=>
      const PluginAccountAuthentication(serverIdentity:'server-B'));
    expect(PluginAccountProfiles.read(_source).profiles[a.id]!.deleted,isTrue);
    expect(await PluginAccountProfiles.selected(_source),b.id);
    await _active('A');
    await PluginAccountProfiles.rememberCurrent(_source,explicitSave:true);
    expect(PluginAccountProfiles.read(_source).profiles[a.id]!.deleted,isFalse);
  });

  test('a profile tombstoned during authentication cannot be selected or revived',() async {
    final b=PluginAccountProfiles.read(_source).profiles.values.singleWhere((p)=>p.identity=='B');
    await expectLater(PluginAccountProfiles.switchTo(_source,b.id,authenticate:(_) async {
      final data=PluginAccountProfiles.read(_source);
      await savePluginConfigValue(_source,pluginAccountProfilesKey,
        PluginAccountProfilesData(_source,{...data.profiles,
          b.id:PluginAccountProfile(id:b.id,revision:b.revision+100,deleted:true)}).toJson());
      return const PluginAccountAuthentication(serverIdentity:'server-B');
    }),throwsA(isA<PluginSessionChanged>()));
    expect(PluginAccountProfiles.read(_source).profiles[b.id]!.deleted,isTrue);
    expect(readHostPluginConfiguration(_source)['auth.account'],'A');
  });

  test('nested login reuses its source operation owner and future profiles block all account writes',() async {
    await runPluginSessionChange(_source,() async {
      final owner=pluginSessionWriteFence.generation(_source);
      await runPluginSessionChange(_source,() async {
        expect(pluginSessionWriteFence.generation(_source),owner);
      });
      expect(pluginSessionWriteFence.generation(_source),owner);
    });
    final row = objectbox.pluginConfigBox.getAll().singleWhere((row)=>row.name==_source);
    row.config = jsonEncode({...readHostPluginConfiguration(_source),
      pluginAccountProfilesKey:{'version':99,'source':_source,'profiles':{}}});
    objectbox.pluginConfigBox.put(row);
    final before = row.config;
    expect(()=>replaceActivePluginAccount(_source,{'auth.account':'future overwrite'}),
      throwsA(isA<SyncCompatibilityException>()));
    await expectLater(savePluginConfigValue(_source,'auth.account','future overwrite'),
      throwsA(isA<SyncCompatibilityException>()));
    await expectLater(PluginAccountProfiles.rememberCurrent(_source),
      throwsA(isA<SyncCompatibilityException>()));
    expect(objectbox.pluginConfigBox.get(row.id)!.config,before);

  });
  test('declared login failure rolls back the real compatibility group and keeps both saved accounts', () async {
    await expectLater(PluginAccountProfiles.submitLogin(_source, submit:() async {
      replaceActivePluginAccount(_source,{'auth.account':'B','auth.authorization':'candidate'});
      return true;
    }, verify:() async => throw const PluginAccountSwitchFailed()), throwsA(isA<PluginAccountSwitchFailed>()));
    expect(readHostPluginConfiguration(_source)['auth.authorization'],'token-A');
    expect(PluginAccountProfiles.read(_source).profiles.values.where((p)=>!p.deleted).length,2);
  });
  test('declared login is source serialized and unknown authentication never selects a profile', () async {
    final gate=Completer<bool>(), order=<String>[];
    final first=PluginAccountProfiles.submitLogin(_source,submit:() async {
      order.add('first'); await gate.future;
      replaceActivePluginAccount(_source,{'auth.account':'B','auth.authorization':'fresh-B'});
      return true;
    },verify:() async=>const PluginAccountAuthentication(serverIdentity:'server-B'));
    final second=PluginAccountProfiles.submitLogin(_source,submit:() async {
      order.add('second');
      expect(readHostPluginConfiguration(_source)['auth.authorization'],'fresh-B');
      replaceActivePluginAccount(_source,{'auth.account':'C','auth.privateToken':'synthetic-C'});
      return true;
    });
    await Future<void>.delayed(Duration.zero);expect(order,['first']);
    gate.complete(true);await first;await second;
    expect(order,['first','second']);
    expect(await PluginAccountProfiles.selected(_source),isNull);
    final saved=PluginAccountProfiles.read(_source).profiles.values.singleWhere((p)=>p.identity=='C');
    expect(saved.serverIdentity,isEmpty);
    expect(saved.bundle['auth.privateToken'],'synthetic-C');
  });

}
