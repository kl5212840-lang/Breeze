import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/sync/appearance_image_sync.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/sync_direction.dart';
import 'package:zephyr/network/sync/sync_plugin_participation.dart';
import 'package:zephyr/service/local_appearance_images.dart';

import '../../test_helper.dart';
import 'sync_installed_fixture.dart';

const _source = '99999999-1111-4222-8333-444444444444';
class _Cloud implements ComicSyncRemoteAdapter {
  final files = <String, List<int>>{};
  final readbackStarted = Completer<void>();
  Completer<void>? readbackGate;
  bool corrupt = false;
  @override Future<void> testConnection() async {}
  @override Future<void> ensureRemoteReady() async {}
  @override Future<List<String>> listRemoteDataFiles() async => files.keys.toList();
  @override Future<List<int>> downloadRemoteFile(String path) async {
    if (path.contains('/appearance_resource_')) {
      if (!readbackStarted.isCompleted) readbackStarted.complete();
      await readbackGate?.future;
      if (corrupt) return [0];
    }
    return files[path]!;
  }
  @override Future<String> downloadRemoteMd5() async => '';
  @override Future<void> uploadRemoteMd5(String value) async => throw UnimplementedError();
  @override Future<void> uploadRemoteFile(String path, List<int> bytes,
      {String contentType = 'application/octet-stream'}) async { files[path] = List.of(bytes); }
  @override Future<void> deleteRemoteFiles(List<String> paths) async { for (final path in paths) { files.remove(path); } }
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  late Directory root;
  late LocalAppearanceImages images;
  late SyncPluginParticipation participation;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await installSyncPlugins([_source]);
    participation = await SyncPluginParticipation.capture();
    root = await Directory.systemTemp.createTemp('sync-image-progress-');
    images = LocalAppearanceImages(rootDirectory: root);
    final bytes = Uint8List.fromList(img.encodeJpg(img.Image(width: 2, height: 2)));
    await images.save('profile:$_source', bytes);
    await images.save('plugin-icon:$_source', bytes);
  });
  tearDown(() async { images.paths.dispose(); await root.delete(recursive: true); });
  Future<void> sync(_Cloud cloud, List<(int, int)> progress) => syncAppearanceImages(
      cloud, participation: participation, images: images, deviceId: 'fixture',
      includeGlobal: false, includePlugins: true, direction: SyncDirection.upload,
      onUploadProgress: (done, total) => progress.add((done, total)));

  test('shared image counts once and completes only after verified cloud readback', () async {
    final cloud = _Cloud()..readbackGate = Completer<void>();
    final progress = <(int, int)>[];
    final pending = sync(cloud, progress);
    await cloud.readbackStarted.future.timeout(const Duration(seconds: 5));
    expect(progress, [(0, 1)]);
    cloud.readbackGate!.complete();
    await pending;
    expect(progress, [(0, 1), (1, 1)]);
    expect(cloud.files.keys.where((p) => p.contains('/appearance_resource_')), hasLength(1));
  });
  test('restore exposes only the known image preparation batch and keeps the whole round unestimated', () async {
    final cloud = _Cloud();
    await sync(cloud, []);
    SharedPreferences.setMockInitialValues({});
    final restored = LocalAppearanceImages(rootDirectory: Directory('${root.path}/receiver'));
    final prepared = <(int, int)>[];
    try {
      await syncAppearanceImages(cloud, participation: participation,
        images: restored, deviceId: 'receiver', includeGlobal: false,
        includePlugins: true, direction: SyncDirection.restore,
        onPrepareProgress: (done, total) => prepared.add((done, total)));
      expect(prepared, [(0, 2), (1, 2), (2, 2)]);
      expect(restored.paths.value.keys, containsAll(['profile:$_source', 'plugin-icon:$_source']));
    } finally { restored.paths.dispose(); }
  });
  test('a corrupt cloud readback never advances the image batch to completion', () async {
    final cloud = _Cloud()..corrupt = true;
    final progress = <(int, int)>[];
    await expectLater(sync(cloud, progress), throwsFormatException);
    expect(progress, [(0, 1)]);
  });
}
