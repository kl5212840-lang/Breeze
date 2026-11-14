import 'dart:typed_data';
import 'package:crypto/crypto.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/network/sync/backup_protection_adapter.dart';
import 'package:zephyr/network/sync/appearance_resource_paths.dart';
import 'package:zephyr/service/backup_security/backup_security.dart';

import 'backup_protection_cloud_test.dart' show MemoryCloud, MemoryProfiles, manager, setup;

class CountingCloud extends MemoryCloud {
  final reads=<String>[];
  @override Future<List<int>> downloadRemoteFile(String path) {
    reads.add(path);return super.downloadRemoteFile(path);
  }
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('resources authenticate on demand and protection transitions cover every byte',() async {
    final cloud=CountingCloud(),owner=manager(MemoryProfiles());await setup(owner);await owner.enableCloud(cloud);
    final name='appearance_resource_${sha256.convert([1,2,3,4])}.bin';
    final adapter=BackupProtectionSyncAdapter(cloud,manager:owner);
    await adapter.uploadRemoteFile(name,[1,2,3,4]);
    expect(BackupProtectionService.isProtectedBytes(cloud.files[cloud.path(name)]!),isTrue);
    cloud.reads.clear();
    final next=BackupProtectionSyncAdapter(cloud,manager:owner);await next.listRemoteDataFiles();
    expect(cloud.reads.where(isAppearanceResourcePath),isEmpty);
    expect(await next.downloadRemoteFile(name),[1,2,3,4]);
    expect(cloud.reads.where(isAppearanceResourcePath),hasLength(1));
    await owner.disableCloud(cloud);
    expect(cloud.files[cloud.path(name)],[1,2,3,4]);
  });
  test('an orphan encrypted resource cannot be overwritten after protection metadata loss',() async {
    final cloud=CountingCloud(),owner=manager(MemoryProfiles());await setup(owner);await owner.enableCloud(cloud);
    final name='appearance_resource_${sha256.convert([9,8])}.bin';
    await BackupProtectionSyncAdapter(cloud,manager:owner).uploadRemoteFile(name,[9,8]);
    final original=Uint8List.fromList(cloud.files[cloud.path(name)]!);
    cloud.files.removeWhere((path,_)=>path.split('/').last=='protection.json');
    final fresh=BackupProtectionSyncAdapter(cloud,manager:manager(MemoryProfiles()));
    await expectLater(fresh.uploadRemoteFile(name,[9,8]),throwsA(isA<BackupProtectionException>()));
    expect(cloud.files[cloud.path(name)],original);
  });
  test('bad encrypted resource is not silently skipped on access or mode transition',() async {
    final cloud=CountingCloud(),owner=manager(MemoryProfiles());await setup(owner);await owner.enableCloud(cloud);
    final name='appearance_resource_${sha256.convert([6,7])}.bin';
    await BackupProtectionSyncAdapter(cloud,manager:owner).uploadRemoteFile(name,[6,7]);
    final raw=Uint8List.fromList(cloud.files[cloud.path(name)]!);
    raw[raw.length-1] ^= 1;
    cloud.files[cloud.path(name)]=raw;
    final before=cloud.files.map((k,v)=>MapEntry(k,List<int>.of(v)));
    await expectLater(BackupProtectionSyncAdapter(cloud,manager:owner).downloadRemoteFile(name),throwsA(isA<BackupProtectionException>()));
    await expectLater(owner.disableCloud(cloud),throwsA(isA<BackupProtectionException>()));
    expect(cloud.files,before);
  });
}
