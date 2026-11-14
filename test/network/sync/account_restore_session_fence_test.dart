import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:objectbox/objectbox.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/sync_service.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import '../../test_helper.dart';
const _source='99999999-1111-4222-8333-444444444444';
const _state=GlobalSettingState(syncSetting:SyncSettingState(syncPlugins:true));
Future<List<int>> _identity(List<int> bytes) async=>bytes;
const _codec=SettingsSyncCodec(encode:_identity,decode:_identity);
class _Archive implements ComicSyncRemoteAdapter {
  _Archive(Map<String,dynamic> data):bytes=utf8.encode(jsonEncode(data));
  final List<int> bytes;
  @override Future<List<String>> listRemoteDataFiles() async=>['${ComicSyncCore.syncRemoteRootName}/settings_10000.bin'];
  @override Future<List<int>> downloadRemoteFile(String path) async=>path.endsWith('settings.md5')?utf8.encode(ComicSyncCore.calculateMd5(bytes)):bytes;
  @override Future<String> downloadRemoteMd5() async=>'';
  @override Future<void> testConnection() async {}
  @override Future<void> ensureRemoteReady() async {}
  @override Future<void> uploadRemoteMd5(String value) async=>throw StateError('read only');
  @override Future<void> uploadRemoteFile(String path,List<int> bytes,{String contentType='application/octet-stream'}) async=>throw StateError('read only');
  @override Future<void> deleteRemoteFiles(List<String> paths) async=>throw StateError('read only');
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    objectbox.pluginConfigBox.removeAll();objectbox.pluginInfoBox.removeAll();
    objectbox.pluginInfoBox.put(PluginInfo(uuid:_source,version:'1.0.0',originScript:'fixture',isEnabled:true,
      insertedAt:DateTime.fromMillisecondsSinceEpoch(1,isUtc:true),updatedAt:DateTime.fromMillisecondsSinceEpoch(1,isUtc:true),isDeleted:false,lastLoadSuccess:false,debug:false));
    final user=objectbox.userSettingBox.get(1)!;user.globalSetting=_state;objectbox.userSettingBox.put(user);
    replaceActivePluginAccount(_source,{'auth.account':'A','auth.authorization':'token-A'});
  });
  Future<SettingsArchiveImportPlan> plan(Map<String,dynamic> config) async {
    final payload={'version':'v1','schemaVersion':'v2','syncTime':10000,'blocks':{'plugins':{'updatedAt':10000,'data':{
      'pluginInfos':objectbox.pluginInfoBox.getAll().map((r)=>r.toJson()).toList(),
      'pluginConfigs':[PluginConfig(name:_source,config:jsonEncode(config)).toJson()]}}}};
    return prepareSettingsArchiveImport(await readSettingsArchiveData(_Archive(payload),codec:_codec),
      state:_state,includeAll:true,importSettings:false,importPlugins:true,direction:SyncDirection.restore);
  }
  test('real archive transaction replacing active account rejects the old runtime write',() async {
    final oldRuntime=pluginSessionWriteFence.runtime(_source,_source),before=pluginSessionWriteFence.generation(_source);
    final restore=await plan({'auth.account':'B','auth.authorization':'token-B'});
    objectbox.store.runInTransaction(TxMode.write,restore.persistDatabase);
    expect(readHostPluginConfiguration(_source)['auth.account'],'B');
    expect(pluginSessionWriteFence.generation(_source),greaterThan(before));
    expect(()=>onSavePluginConfig(oldRuntime,'auth.authorization','"late-A"'),throwsA(isA<PluginSessionChanged>()));
    expect(readHostPluginConfiguration(_source)['auth.authorization'],'token-B');
  });
  test('ordinary preference restore does not invalidate unchanged active login',() async {
    final before=pluginSessionWriteFence.generation(_source),runtime=pluginSessionWriteFence.runtime(_source,_source);
    final restore=await plan({'auth.account':'A','auth.authorization':'token-A','network.choice':'new'});
    objectbox.store.runInTransaction(TxMode.write,restore.persistDatabase);
    expect(pluginSessionWriteFence.generation(_source),before);
    expect(readHostPluginConfiguration(_source)['network.choice'],'new');
    expect(()=>onSavePluginConfig(runtime,'auth.authorization','"fresh-A"'),returnsNormally);
  });
  test('account refreshed during archive I/O stays a complete group and does not fence its own active login',() async {
    final restore=await plan({'auth.account':'B','auth.authorization':'token-B','auth.password':'password-B'});
    replaceActivePluginAccount(_source,{'auth.account':'A','auth.authorization':'fresh-A'});
    final before=pluginSessionWriteFence.generation(_source);
    objectbox.store.runInTransaction(TxMode.write,restore.persistDatabase);
    final active=readHostPluginConfiguration(_source);
    expect(active['auth.account'],'A');expect(active['auth.authorization'],'fresh-A');expect(active['auth.password'],isNull);
    expect(pluginSessionWriteFence.generation(_source),before);
  });
}
