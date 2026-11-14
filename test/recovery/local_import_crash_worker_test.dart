// Executed only by script/test/local_import_crash_test.py in isolated stores.
// exit() intentionally bypasses every Dart catch/finally in the importer.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:objectbox/objectbox.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/object_box.dart';
import 'package:zephyr/object_box/objectbox.g.dart' show openStore;
import 'package:zephyr/network/sync/sync_device_id.dart';
import 'package:zephyr/page/setting/data_backup/method.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/service/local_import_recovery.dart';

import '../test_helper.dart' show createTestFavorite;

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;
  @override Future<String?> getApplicationSupportPath() async => root;
  @override Future<String?> getApplicationDocumentsPath() async => root;
  @override Future<String?> getTemporaryPath() async => root;
}

class _DiskPreferences extends SharedPreferencesStorePlatform {
  _DiskPreferences(this.file);
  final File file;
  bool crashOnWrite = false;
  void Function()? crash;
  Map<String, Object> read() {
    if (!file.existsSync()) return {};
    return (jsonDecode(file.readAsStringSync()) as Map).map((key, value) => MapEntry(key as String, value is List ? value.cast<String>() : value as Object));
  }
  void save(Map<String, Object> data) {
    final pending = File('${file.path}.new'); pending.writeAsStringSync(jsonEncode(data), flush: true); pending.renameSync(file.path);
    if (crashOnWrite) crash!();
  }
  @override Future<Map<String, Object>> getAll() async => read();
  @override Future<bool> setValue(String valueType, String key, Object value) async { save(read()..[key] = value); return true; }
  @override Future<bool> remove(String key) async { save(read()..remove(key)); return true; }
  @override Future<bool> clear() async { save({}); return true; }
}

class _ProbeRollback implements Exception { const _ProbeRollback(); }

void _probeColdDatabase(Map database) {
  void probe(String table, void Function() write) {
    void writeAndAbort() {
      write();
      throw const _ProbeRollback();
    }
    try {
      objectbox.store.runInTransaction<void>(TxMode.write, writeAndAbort);
    } catch (cause) {
      if (cause is _ProbeRollback) return;
      final text = cause.toString().replaceAll(RegExp(r'/\S+'), '<fixture-path>');
      stderr.writeln('isolated recovery $table cause: ${text.length > 450 ? text.substring(0, 450) : text}');
    }
  }
  probe('favorite', () {
    objectbox.unifiedFavoriteBox.removeAll();
    objectbox.unifiedFavoriteBox.putMany((database['unifiedComicFavorite'] as List)
      .map((row) => UnifiedComicFavorite.fromJson(Map<String, dynamic>.from(row as Map))).toList());
  });
  probe('settings', () {
    objectbox.userSettingBox.removeAll();
    objectbox.userSettingBox.putMany((database['userSetting'] as List).map((row) => UserSetting(
      id: row['id'] as int, globalSettingData: row['globalSettingData'] as String?, bikaSettingData: row['bikaSettingData'] as String?,
      jmSettingData: row['jmSettingData'] as String?, jmJwt: row['jmJwt'] as String)).toList());
  });
  probe('tasks', () {
    objectbox.downloadTaskBox.removeAll();
    objectbox.downloadTaskBox.putMany((database['downloadTask'] as List).map((row) => DownloadTask()
      ..id = row['id'] as int..comicId = row['comicId'] as String..comicName = row['comicName'] as String
      ..isCompleted = row['isCompleted'] as bool..isDownloading = row['isDownloading'] as bool
      ..status = row['status'] as String..dbTaskInfoStr = row['dbTaskInfoStr'] as String?).toList());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final location = Platform.environment['BREEZE_IMPORT_CRASH_ROOT'];
  test('isolated local import process checkpoint', () async {
    if (location == null) return;
    final root = Directory(location);
    PathProviderPlatform.instance = _Paths(root.path);
    final phase = Platform.environment['BREEZE_IMPORT_CRASH_PHASE']!;
    final recover = Platform.environment['BREEZE_IMPORT_CRASH_RECOVER'] == '1';
    final include = Platform.environment['BREEZE_IMPORT_CRASH_DOWNLOADS'] != '0';
    final downloads = Directory('${root.path}/downloads');
    final checkpoint = Directory('${root.path}/recovery');
    final images = LocalAppearanceImages(rootDirectory: Directory('${root.path}/images'));
    final prefsBackend = _DiskPreferences(File('${root.path}/preferences.json'));
    SharedPreferences.resetStatic(); SharedPreferencesStorePlatform.instance = prefsBackend;
    // ObjectBox creates its final breeze_db directory, not a missing parent.
    // TestObjectBoxHelper normally supplies an already-created root; this
    // separate-process fixture must provide the same prerequisite itself.
    final dbRoot = await Directory('${root.path}/db').create(recursive: true);
    ObjectBox.resetForTests();
    try {
      objectbox = await ObjectBox.create(dbRootPath: dbRoot.path);
    } catch (_) {
      // The app wrapper collapses I/O errors into its retry/lock message.
      // Expose the native cause only for this empty, isolated fixture store.
      try {
        final diagnostic = await openStore(directory: '${dbRoot.path}/breeze_db');
        diagnostic.close();
      } catch (cause) {
        final text = cause.toString().replaceAll(root.path, '<fixture>');
        stderr.writeln('isolated ObjectBox cause: ${text.length > 400 ? text.substring(0, 400) : text}');
      }
      rethrow;
    }
    void stop() { File('${root.path}/stopped').writeAsStringSync(phase, flush: true); exit(79); }
    if (recover) {
      try {
        await recoverPendingBackupImport(recoveryDirectory: checkpoint, downloadDirectory: downloads, appearanceImages: images);
      } catch (_) {
        // Only this disposable fixture probes native causes; every probe is a
        // deliberately aborted transaction, never a second recovery path.
        final raw = jsonDecode(await File('${checkpoint.path}/snapshot.json').readAsString()) as Map;
        _probeColdDatabase(raw['database'] as Map);
        rethrow;
      }
      await recoverPendingBackupImport(recoveryDirectory: checkpoint, downloadDirectory: downloads, appearanceImages: images);
      final committed = phase == 'committed' || phase == 'database-committed';
      expect(objectbox.unifiedFavoriteBox.getAll().single.uniqueKey, committed ? 'incoming' : 'original');
      final taskId = int.parse(await File('${root.path}/task-id').readAsString());
      final task = objectbox.downloadTaskBox.get(taskId);
      if (!committed || !include) {
        expect(task, isNotNull); expect(task!.dbTaskInfoStr, ' { "future" : [ 1, 2 ] } ');
        expect(task.isDownloading, isTrue);
      }
      expect(await File('${downloads.path}/${committed && include ? 'new' : 'old'}.txt').readAsString(), committed && include ? 'incoming' : 'original');
      if (!committed) {
        expect((await SharedPreferences.getInstance()).getString('breeze.video.library.view.fixture'), 'grid');
        await images.load();
        final mapping = jsonDecode(await File('${root.path}/old-image.json').readAsString()) as Map;
        expect(images.paths.value['collection-cover'], mapping['path']);
      }
      expect(await File('${checkpoint.path}/pending.json').exists(), isFalse);
      File('${root.path}/verified').writeAsStringSync('ok', flush: true);
      objectbox.store.close(); images.paths.dispose(); return;
    }
    await downloads.create(recursive: true);
    await File('${downloads.path}/old.txt').writeAsString('original');
    objectbox.unifiedFavoriteBox.put(createTestFavorite('original'));
    syncDeviceId = 'isolated-crash-fixture';
    objectbox.userSettingBox.put(UserSetting());
    final task = DownloadTask()..comicId = 'local-task'..isDownloading = true..dbTaskInfoStr = ' { "future" : [ 1, 2 ] } ';
    objectbox.downloadTaskBox.put(task);
    await File('${root.path}/task-id').writeAsString('${task.id}');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('breeze.video.library.view.fixture', 'grid');
    final incoming = await Directory('${root.path}/incoming').create();
    await File('${incoming.path}/config.json').writeAsString(jsonEncode({'includeDownloads': include}));
    await File('${incoming.path}/objectbox.json').writeAsString(jsonEncode({'unifiedComicFavorite': [createTestFavorite('incoming').toJson()..remove('id')]}));
    final portable = await PortablePreferences.capture();
    await File('${incoming.path}/portable-data.json').writeAsString(jsonEncode({'format': 'breeze-portable-data', 'version': 1,
      'preferences': portable.toJson(), 'videoLibrary': VideoLibrarySnapshot().toJson()}));
    final sourceImages = LocalAppearanceImages(rootDirectory: Directory('${root.path}/source-images'));
    final changed = img.Image(width: 2, height: 2); img.fill(changed, color: img.ColorRgb8(220, 0, 0));
    await sourceImages.save('collection-cover', img.encodeJpg(changed)); await sourceImages.exportBackup(incoming);
    // Both injected image stores still use the one real preferences key.
    // Finish producing the foreign archive before establishing device state.
    final oldImage = await images.save('collection-cover', img.encodeJpg(img.Image(width: 2, height: 2)));
    await File('${root.path}/old-image.json').writeAsString(jsonEncode({'path': oldImage}));
    final beforeMapping = jsonDecode(prefs.getString(LocalAppearanceImages.preferencesKey)!) as Map;
    expect(beforeMapping['collection-cover'], File(oldImage).uri.pathSegments.last);
    expect(await File(oldImage).exists(), isTrue);
    if (include) { final dir = await Directory('${incoming.path}/downloads').create(); await File('${dir.path}/new.txt').writeAsString('incoming'); }
    prefsBackend.crash = stop;
    await importExtractedBreezeData(incoming.path, mode: BackupImportMode.restore, restoreDownloadFiles: true,
      hooks: BackupImportHooks(recoveryDirectory: checkpoint, downloadDirectory: downloads, appearanceImages: images,
        beforeCommit: () { if (phase == 'database-before-commit') stop(); },
        checkpoint: (current) async {
          if (phase == 'preferences-partial' && current == 'preferences-planned') prefsBackend.crashOnWrite = true;
          if (current == phase) stop();
        }));
    fail('Requested checkpoint was not reached');
  }, skip: location == null);
}
