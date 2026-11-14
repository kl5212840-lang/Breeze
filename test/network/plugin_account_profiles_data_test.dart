import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/network/sync/plugin_account_profiles_data.dart';
import 'package:zephyr/network/sync/plugin_config_merge.dart';
import 'package:zephyr/network/sync/plugin_account_projection.dart';
import 'package:zephyr/network/sync/sync_direction.dart';
import 'package:zephyr/network/sync/sync_payload_compatibility.dart';

const _source = 'fixture-source';
PluginAccountProfile _profile(String account,int revision,{bool deleted=false}) =>
  PluginAccountProfile(id:PluginAccountProfilesData.idFor(_source,account,''),
    revision:revision,deleted:deleted,identity:account,label:account,
    bundle:{'auth.account':account,'auth.authorization':'PRIVATE-$account'});
Map<String,dynamic> _data(List<PluginAccountProfile> profiles) =>
  PluginAccountProfilesData(_source,{for(final profile in profiles) profile.id:profile}).toJson();
void main() {
  test('multi account records converge as complete bundles and deletion beats stale snapshots',() {
    final a=_profile('A',1), b=_profile('B',2);
    final one=_data([a]), two=_data([b]);
    final merged=mergePluginAccountProfiles(one,two);
    expect(PluginAccountProfilesData.parse(merged)!.profiles.keys.toSet(),{a.id,b.id});
    expect(mergePluginAccountProfiles(two,one),merged);
    final removed=mergePluginAccountProfiles(merged,_data([_profile('A',3,deleted:true)]));
    final restored=PluginAccountProfilesData.parse(mergePluginAccountProfiles(one,removed))!;
    expect(restored.profiles[a.id]!.deleted,isTrue);
    expect(restored.profiles[a.id]!.bundle,isEmpty);
    expect(restored.profiles[b.id]!.bundle['auth.authorization'],'PRIVATE-B');
    expect(restored.toString(),isNot(contains('PRIVATE')));
  });
  test('directed and old-client writebacks retain records absent from old snapshots',() {
    final a=_profile('A',1),b=_profile('B',2);
    final local=updatePluginConfigField({},pluginAccountProfilesKey,_data([a]));
    final remote=updatePluginConfigField({},pluginAccountProfilesKey,_data([b]));
    for(final direction in SyncDirection.values) {
      final merged=jsonDecode(mergePluginConfigData(jsonEncode(local),jsonEncode(remote),
        localUpdatedAt:10,remoteUpdatedAt:20,preferRemoteOnConflict:true,direction:direction)) as Map;
      expect(PluginAccountProfilesData.parse(merged[pluginAccountProfilesKey])!.profiles.keys.toSet(),{a.id,b.id});
    }
    final legacy=jsonDecode(mergePluginConfigData('{}',jsonEncode(remote),
      localUpdatedAt:99,remoteUpdatedAt:20,preferRemoteOnConflict:false,direction:SyncDirection.upload)) as Map;
    expect(PluginAccountProfilesData.parse(legacy[pluginAccountProfilesKey])!.profiles.keys,[b.id]);
    expect(visiblePluginConfig(remote).containsKey(pluginAccountProfilesKey),isFalse);
  });
  test('future or cross-source profiles are rejected instead of projected or overwritten',() {
    final future={pluginAccountProfilesKey:{'version':99,'source':_source,'profiles':{}}};
    expect(()=>mergePluginConfigData('{}',jsonEncode(future),localUpdatedAt:1,
      remoteUpdatedAt:2,preferRemoteOnConflict:true),throwsA(isA<SyncCompatibilityException>()));
    expect(()=>pluginConfigForSync(jsonEncode(future)),throwsA(isA<SyncCompatibilityException>()));
    expect(()=>PluginAccountProfilesData.parse(_data([_profile('A',1)]),source:'other'),throwsA(isA<SyncCompatibilityException>()));
    final invalid=_data([_profile('A',1)]);
    ((invalid['profiles'] as Map).values.single as Map)['bundle']={'network.proxy':'PRIVATE'};
    expect(()=>PluginAccountProfilesData.parse(invalid),throwsA(isA<SyncCompatibilityException>()));
  });
  test('old client active auth cannot resurrect a deleted saved identity during cloud merge', () {
    final deleted = {pluginAccountProfilesKey:_data([_profile('A',30,deleted:true),_profile('B',20)])};
    final legacy = {'auth.account':'A','auth.authorization':'PRIVATE-A',
      'account.credentials':{'version':1,'account':'A','password':'PRIVATE','origin':'https://site.example'}};
    for(final direction in SyncDirection.values) {
      final merged=jsonDecode(mergePluginAccountConfigData(jsonEncode(deleted),jsonEncode(legacy),
        localUpdatedAt:20,remoteUpdatedAt:999,preferRemoteOnConflict:true,direction:direction)) as Map;
      expect(merged['auth.account'],isNull);
      expect(merged['auth.authorization'],isNull);
      expect(merged['account.credentials'],isNull);
      expect(PluginAccountProfilesData.parse(merged[pluginAccountProfilesKey])!.profiles[_profile('B',20).id]!.deleted,isFalse);
    }
    expect(legacy['auth.authorization'],'PRIVATE-A',reason:'transport cleanup never mutates the other device session');
  });
  test('web tombstones reject unbound legacy sessions but retain another exact saved account', () {
    const origin='https://site.example';
    final removed=PluginAccountProfile(id:PluginAccountProfilesData.idFor(_source,'1',origin,kind:'web'),
      revision:30,deleted:true,kind:'web');
    final live=PluginAccountProfile(id:PluginAccountProfilesData.idFor(_source,'2',origin,kind:'web'),
      revision:20,deleted:false,kind:'web',identity:'2',origin:origin,bundle:{
        'account.backup':{'version':1,'origin':origin,'cookies':[{'name':'session','value':'PRIVATE-B'}]}});
    final base={pluginAccountProfilesKey:_data([removed,live])};
    final stale={...base,'account.backup':{'version':1,'origin':origin,'cookies':[{'name':'session','value':'PRIVATE-A'}]}};
    expect(suppressRemovedAccountProjection(stale)['account.backup'],isNull);
    expect(suppressRemovedAccountProjection({...base,'account.backup':live.bundle['account.backup']})['account.backup'],isNotNull);
    expect(jsonEncode(removed.toJson()),isNot(contains('PRIVATE')));
    expect(PluginAccountProfilesData.parse(_data([removed]))!.profiles[removed.id]!.kind,'web');
  });

  test('profile identity follows the login primary field, not every display alias', () {
    final original=_data([_profile('A',1)]);
    final withAlias=jsonDecode(jsonEncode(original)) as Map;
    ((withAlias['profiles'] as Map).values.single as Map)['bundle']['auth.username']='Site nickname';
    expect(PluginAccountProfilesData.parse(withAlias),isNotNull);
    final mismatched=jsonDecode(jsonEncode(original)) as Map;
    ((mismatched['profiles'] as Map).values.single as Map)['bundle']['auth.account']='B';
    expect(()=>PluginAccountProfilesData.parse(mismatched),throwsA(isA<SyncCompatibilityException>()));
    final fallback=jsonDecode(jsonEncode(original)) as Map;
    ((fallback['profiles'] as Map).values.single as Map)['bundle']={
      'account.credentials':{'version':1,'account':'B','password':'PRIVATE','origin':'https://site.example'}};
    expect(()=>PluginAccountProfilesData.parse(fallback),throwsA(isA<SyncCompatibilityException>()));
  });
  test('restore preserves intervening active account as one group while merging saved profiles', () {
    final baseline={...updatePluginConfigField({},'auth.account','A',nowMs:1),
      'auth.authorization':'token-A', pluginAccountProfilesKey:_data([_profile('A',1)])};
    final current={...baseline,'auth.authorization':'refreshed-A',
      pluginAccountProfilesKey:_data([_profile('A',1),_profile('C',3)])};
    final incoming={'auth.account':'B','auth.authorization':'token-B','auth.password':'password-B',
      'network.choice':'cloud', pluginAccountProfilesKey:_data([_profile('A',1),_profile('B',2)])};
    final result=jsonDecode(preserveInterveningPluginConfigEdits(jsonEncode(baseline),jsonEncode(current),jsonEncode(incoming))) as Map;
    expect(result['auth.account'],'A');expect(result['auth.authorization'],'refreshed-A');
    expect(result['auth.password'],isNull,reason:'the old account cannot inherit the other account password');
    expect(result['network.choice'],'cloud');
    expect(PluginAccountProfilesData.parse(result[pluginAccountProfilesKey])!.profiles.values.map((p)=>p.identity).toSet(),{'A','B','C'});
  });

}
