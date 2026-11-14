import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/setting/data_backup/method.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/service/local_import_recovery.dart';
import 'package:zephyr/plugin/plugin_host_compatibility.dart';
import 'package:zephyr/service/offline_backup_merge.dart';

import '../test_helper.dart';

const source = '11111111-2222-4333-8444-555555555555';
const globalKey = 'breeze.bookshelf.media.v1';
const pluginKey = 'breeze.source.diagnostics.v1.$source';
const progressKey = 'breeze.video.progress.import-options';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  late Directory root, incoming;
  late LocalAppearanceImages images;
  late SharedPreferences prefs;
  late String localGallery, foreignGallery;
  late Uint8List localImage, foreignImage;

  PluginInfo plugin(int revision) => PluginInfo(
    uuid: source,
    version: '0.1.$revision',
    originScript: 'script-$revision',
    insertedAt: DateTime.utc(2026),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(revision, isUtc: true),
    isEnabled: true,
    isDeleted: false,
    lastLoadSuccess: false,
    debug: false,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'sync.device_id': 'backup-options-local',
      globalKey: 'comic',
      pluginKey: false,
      progressKey: 3,
    });
    prefs = await SharedPreferences.getInstance();
    await LocalPluginInstallationState.instance.reload();
    PluginHostCompatibilityNotices.instance.takePending();
    objectbox.pluginInfoBox.removeAll();
    objectbox.pluginConfigBox.removeAll();
    objectbox.unifiedFavoriteBox.removeAll();
    final user = objectbox.userSettingBox.get(1)!;
    user.globalSetting = const GlobalSettingState(
      themeMode: ThemeMode.dark,
      syncSetting: SyncSettingState(syncSettings: false, syncPlugins: false),
    );
    user.jmJwt = 'local-jwt';
    objectbox.userSettingBox.put(user);
    objectbox.pluginInfoBox.put(plugin(1000));
    objectbox.pluginConfigBox.put(
      PluginConfig(name: source, config: '{"token":"local"}'),
    );
    root = await Directory.systemTemp.createTemp('backup-options-');
    incoming = await Directory(p.join(root.path, 'incoming')).create();
    images = LocalAppearanceImages(
      rootDirectory: Directory(p.join(root.path, 'local-images')),
    );
    await images.load();
    localImage = img.encodeJpg(img.Image(width: 8, height: 8));
    foreignImage = img.encodeJpg(img.Image(width: 9, height: 9));
    await images.save('collection-cover', localImage);
    await images.savePluginIcon(source, localImage);
    localImage = await File(images.pluginIconPath(source)!).readAsBytes();
    localGallery = images.collectionCovers.keys.single;
    final mapping = prefs.getString(LocalAppearanceImages.preferencesKey);
    await prefs.remove(LocalAppearanceImages.preferencesKey);
    final foreign = LocalAppearanceImages(
      rootDirectory: Directory(p.join(root.path, 'foreign-images')),
    );
    await foreign.load();
    try {
      await foreign.save('collection-cover', foreignImage);
      await foreign.savePluginIcon(source, foreignImage);
      foreignImage = await File(foreign.pluginIconPath(source)!).readAsBytes();
      foreignGallery = foreign.collectionCovers.keys.single;
      await foreign.exportBackup(incoming);
    } finally {
      foreign.paths.dispose();
      if (mapping == null) {
        await prefs.remove(LocalAppearanceImages.preferencesKey);
      } else {
        await prefs.setString(LocalAppearanceImages.preferencesKey, mapping);
      }
    }
    final future = DateTime.now().millisecondsSinceEpoch + 100000;
    final backupUser = UserSetting.fromJson(user.toJson())
      ..globalSetting = user.globalSetting.copyWith(
        themeMode: ThemeMode.light,
        switchStyle: BreezeSwitchStyle.ring,
      )
      ..bikaSetting = user.bikaSetting.copyWith(
        account: 'backup-bika',
        password: 'backup-bika-pass',
        authorization: 'backup-bika-session',
      )
      ..jmSetting = user.jmSetting.copyWith(
        account: 'backup-jm',
        password: 'backup-jm-pass',
      )
      ..jmJwt = 'backup-jwt';
    final db =
        jsonDecode(objectbox.collectAllDataJson(removeIds: true))
            as Map<String, dynamic>;
    db['userSetting'] = [backupUser.toJson()];
    db['pluginInfo'] = [plugin(future).toJson()];
    db['pluginConfig'] = [
      PluginConfig(name: source, config: '{"token":"backup"}').toJson(),
    ];
    db['unifiedComicFavorite'] = [
      UnifiedComicFavorite(
        uniqueKey: '$source::work',
        source: source,
        comicId: 'work',
        title: 'Imported record',
        description: '',
        cover: '',
        creator: '',
        titleMeta: '',
        metadata: '{}',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        deleted: false,
        schemaVersion: 2,
      ).toJson(),
    ];
    await File(p.join(incoming.path, 'config.json')).writeAsString(
      '{"format":"BreezeBackup","schemaVersion":1,"includeDownloads":false}',
    );
    await File(
      p.join(incoming.path, 'objectbox.json'),
    ).writeAsString(jsonEncode(db));
    await File(p.join(incoming.path, 'sync-settings.json')).writeAsString(
      jsonEncode({
        'version': 'v1',
        'schemaVersion': 'v2',
        'syncTime': future,
        'blocks': {
          'appearance': {
            'updatedAt': future,
            'data': {'themeMode': 'light', 'switchStyle': 'ring'},
          },
          'plugins': {
            'updatedAt': future,
            'data': {
              'pluginInfos': db['pluginInfo'],
              'pluginConfigs': db['pluginConfig'],
            },
          },
        },
      }),
    );
    final portable = PortablePreferencesSnapshot({
      for (final entry in {
        globalKey: 'video',
        pluginKey: true,
        progressKey: 9,
      }.entries)
        '${entry.key}#${sha256.convert(utf8.encode(''))}': {
          'key': entry.key,
          'kind': 'preference',
          'value': entry.value,
          'deleted': false,
          'updatedAt': future,
        },
    });
    await File(p.join(incoming.path, 'portable-data.json')).writeAsString(
      jsonEncode({
        'format': 'breeze-portable-data',
        'version': 1,
        'preferences': portable.toJson(),
        'videoLibrary': VideoLibrarySnapshot().toJson(),
      }),
    );
  });
  tearDown(() async {
    images.paths.dispose();
    await root.delete(recursive: true);
  });

  for (final mode in BackupImportMode.values) {
    for (final settings in [false, true]) {
      for (final plugins in [false, true]) {
        test(
          '$mode uses explicit settings=$settings plugins=$plugins despite both cloud choices off',
          () async {
            await importExtractedBreezeData(
              incoming.path,
              mode: mode,
              options: BackupImportOptions(
                importSettings: settings,
                importPlugins: plugins,
              ),
              hooks: BackupImportHooks(
                appearanceImages: images,
                recoveryDirectory: Directory(p.join(root.path, 'recovery')),
              ),
            );
            final user = objectbox.userSettingBox.get(1)!;
            expect(
              user.globalSetting.themeMode,
              settings ? ThemeMode.light : ThemeMode.dark,
            );
            expect(
              user.globalSetting.switchStyle,
              settings ? BreezeSwitchStyle.ring : BreezeSwitchStyle.classic,
            );
            expect(user.globalSetting.syncSetting.syncSettings, isFalse);
            expect(user.globalSetting.syncSetting.syncPlugins, isFalse);
            expect(
              objectbox.pluginInfoBox.getAll().single.originScript ==
                  'script-1000',
              !plugins,
            );
            expect(
              objectbox.pluginConfigBox.getAll().single.config,
              contains(plugins ? 'backup' : 'local'),
            );
            expect(prefs.getString(globalKey), settings ? 'video' : 'comic');
            expect(prefs.getBool(pluginKey), plugins);
            expect(prefs.getInt(progressKey), 9);
            expect(
              objectbox.unifiedFavoriteBox.getAll().single.title,
              'Imported record',
            );
            if (mode == BackupImportMode.restore)
              expect(user.jmJwt, plugins ? 'backup-jwt' : 'local-jwt');
            final gallery = images.collectionCovers.keys.toSet();
            expect(gallery.contains(foreignGallery), settings);
            expect(
              gallery.contains(localGallery),
              mode == BackupImportMode.merge || !settings,
            );
            final image = File(images.pluginIconPath(source)!);
            expect(
              sha256.convert(await image.readAsBytes()).toString(),
              sha256.convert(plugins ? foreignImage : localImage).toString(),
            );
          },
        );
      }
    }
  }

  test(
    'merge fills empty legacy credential groups and refuses cross-account or unidentified token mixing',
    () {
      Map<String, dynamic> account(
        String id, {
        String pass = '',
        String token = '',
        String jwt = '',
      }) {
        final user = UserSetting();
        user.bikaSetting = user.bikaSetting.copyWith(
          account: id,
          password: pass,
          authorization: token,
        );
        user.jmSetting = user.jmSetting.copyWith(account: id, password: pass);
        user.jmJwt = jwt;
        return {
          'userSetting': [user.toJson()],
        };
      }

      UserSetting result(Map<String, dynamic> rows) => UserSetting.fromJson(
        Map<String, dynamic>.from((rows['userSetting'] as List).first as Map),
      );
      const options = BackupImportOptions();
      final empty = account(
        'backup',
        pass: 'backup-pass',
        token: 'backup-token',
        jwt: 'backup-jwt',
      );
      options.mergeLegacyAccounts(empty, account(''));
      expect(result(empty).bikaSetting.account, 'backup');
      expect(result(empty).jmJwt, 'backup-jwt');
      final same = account(
        'same',
        pass: 'backup-pass',
        token: 'backup-token',
        jwt: 'backup-jwt',
      );
      options.mergeLegacyAccounts(same, account('same', pass: 'local-pass'));
      expect(result(same).bikaSetting.password, 'local-pass');
      expect(result(same).bikaSetting.authorization, 'backup-token');
      expect(result(same).jmJwt, 'backup-jwt');
      final other = account(
        'backup',
        pass: 'backup-pass',
        token: 'backup-token',
        jwt: 'backup-jwt',
      );
      options.mergeLegacyAccounts(
        other,
        account('local', token: 'local-token', jwt: 'local-jwt'),
      );
      expect(result(other).bikaSetting.account, 'local');
      expect(result(other).bikaSetting.password, isEmpty);
      expect(result(other).jmJwt, 'local-jwt');
      final unknown = account(
        'backup',
        pass: 'backup-pass',
        token: 'backup-token',
        jwt: 'backup-jwt',
      );
      options.mergeLegacyAccounts(
        unknown,
        account('', token: 'unknown-local-token', jwt: 'unknown-local-jwt'),
      );
      expect(result(unknown).bikaSetting.account, isEmpty);
      expect(result(unknown).jmSetting.account, isEmpty);
      expect(result(unknown).jmJwt, 'unknown-local-jwt');
    },
  );

  test(
    'explicit offline merge restores old account-only fields into an empty local identity',
    () async {
      final user = objectbox.userSettingBox.get(1)!..jmJwt = '';
      objectbox.userSettingBox.put(user);
      await importExtractedBreezeData(
        incoming.path,
        options: const BackupImportOptions(importSettings: false),
        hooks: BackupImportHooks(
          appearanceImages: images,
          recoveryDirectory: Directory(p.join(root.path, 'recovery')),
        ),
      );
      final restored = objectbox.userSettingBox.get(1)!;
      expect(restored.bikaSetting.account, 'backup-bika');
      expect(restored.bikaSetting.authorization, 'backup-bika-session');
      expect(restored.jmSetting.account, 'backup-jm');
      expect(restored.jmJwt, 'backup-jwt');
    },
  );

  for (final mode in BackupImportMode.values) {
    for (final settings in [false, true]) {
      test(
        '$mode preserves prepared-checkpoint late writes in the unselected category ($settings)',
        () async {
          late Set<String> lateGallery;
          late String lateIcon;
          await importExtractedBreezeData(
            incoming.path,
            mode: mode,
            options: BackupImportOptions(
              importSettings: settings,
              importPlugins: !settings,
            ),
            hooks: BackupImportHooks(
              appearanceImages: images,
              recoveryDirectory: Directory(p.join(root.path, 'recovery')),
              checkpoint: (point) async {
                if (point != 'prepared') return;
                final user = objectbox.userSettingBox.get(1)!;
                final bytes = img.encodeJpg(img.Image(width: 10, height: 10));
                if (!settings) {
                  user.globalSetting = user.globalSetting.copyWith(
                    themeMode: ThemeMode.system,
                  );
                  await prefs.setString(globalKey, 'video');
                  await images.save('collection-cover', bytes);
                  lateGallery = images.collectionCovers.keys.toSet();
                } else {
                  user.jmJwt = 'late-local-jwt';
                  final row = objectbox.pluginInfoBox.getAll().single
                    ..originScript = 'late-local-script';
                  objectbox.pluginInfoBox.put(row);
                  final config = objectbox.pluginConfigBox.getAll().single
                    ..config = '{"token":"late-local"}';
                  objectbox.pluginConfigBox.put(config);
                  await prefs.setBool(pluginKey, true);
                  await images.savePluginIcon(source, bytes);
                  lateIcon = images.pluginIconPath(source)!;
                }
                objectbox.userSettingBox.put(user);
              },
            ),
          );
          if (!settings) {
            expect(
              objectbox.userSettingBox.get(1)!.globalSetting.themeMode,
              ThemeMode.system,
            );
            expect(prefs.getString(globalKey), 'video');
            expect(images.collectionCovers.keys.toSet(), lateGallery);
          } else {
            expect(
              objectbox.pluginInfoBox.getAll().single.originScript,
              'late-local-script',
            );
            expect(
              objectbox.pluginConfigBox.getAll().single.config,
              contains('late-local'),
            );
            expect(objectbox.userSettingBox.get(1)!.jmJwt, 'late-local-jwt');
            expect(prefs.getBool(pluginKey), isTrue);
            expect(images.pluginIconPath(source), lateIcon);
          }
        },
      );
    }
  }

  test(
    'failed partial restore rolls back selected artwork and leaves late unselected artwork and preferences intact',
    () async {
      late Set<String> lateGallery;
      await expectLater(
        importExtractedBreezeData(
          incoming.path,
          mode: BackupImportMode.restore,
          options: const BackupImportOptions(importSettings: false),
          hooks: BackupImportHooks(
            appearanceImages: images,
            recoveryDirectory: Directory(p.join(root.path, 'recovery')),
            checkpoint: (point) async {
              if (point != 'prepared') return;
              await images.save(
                'collection-cover',
                img.encodeJpg(img.Image(width: 10, height: 10)),
              );
              lateGallery = images.collectionCovers.keys.toSet();
              await prefs.setString(globalKey, 'video');
            },
            beforeCommit: () => throw StateError('fixture rollback'),
          ),
        ),
        throwsA(anything),
      );
      expect(images.collectionCovers.keys.toSet(), lateGallery);
      expect(prefs.getString(globalKey), 'video');
      expect(
        sha256
            .convert(await File(images.pluginIconPath(source)!).readAsBytes())
            .toString(),
        sha256.convert(localImage).toString(),
      );
    },
  );

  test(
    'cold rollback uses the true pre-activation mapping after a late unselected artwork save',
    () async {
      final recoveryDir = Directory(p.join(root.path, 'cold-recovery'));
      final downloads = await Directory(
        p.join(root.path, 'downloads'),
      ).create();
      final recovery = await LocalImportRecovery.begin(
        recoveryDirectory: recoveryDir,
        downloads: downloads,
        images: images,
      );
      final plan = (await prepareSelectedBackupAppearanceRestore(
        incoming,
        images,
        const BackupImportOptions(importSettings: false),
      ))!;
      await recovery.beforeImages(plan.recoveryBasenames);
      await images.save(
        'collection-cover',
        img.encodeJpg(img.Image(width: 10, height: 10)),
      );
      final retained = images.collectionCovers.keys.toSet();
      await plan.activate(
        beforePersist: (mapping) => recovery.beforePreferences(
          {LocalAppearanceImages.preferencesKey: mapping},
          beforeValues: {
            LocalAppearanceImages.preferencesKey: prefs.getString(
              LocalAppearanceImages.preferencesKey,
            ),
          },
        ),
      );
      await plan.releaseForRecovery();
      await recoverPendingBackupImport(
        recoveryDirectory: recoveryDir,
        downloadDirectory: downloads,
        appearanceImages: images,
      );
      final restored = LocalAppearanceImages(
        rootDirectory: Directory(p.join(root.path, 'local-images')),
      );
      await restored.load();
      try {
        expect(restored.collectionCovers.keys.toSet(), retained);
        expect(
          sha256
              .convert(
                await File(restored.pluginIconPath(source)!).readAsBytes(),
              )
              .toString(),
          sha256.convert(localImage).toString(),
        );
      } finally {
        restored.paths.dispose();
      }
    },
  );

  for (final mode in BackupImportMode.values) {
    test(
      '$mode keeps the latest local script for an incompatible candidate while importing its data',
      () async {
        final dbFile = File(p.join(incoming.path, 'objectbox.json'));
        final db =
            jsonDecode(await dbFile.readAsString()) as Map<String, dynamic>;
        final row = (db['pluginInfo'] as List).single as Map;
        row['getInfoJson'] = jsonEncode({
          'uuid': source,
          'name': 'Future fixture',
          'function': [
            {
              'action': {
                'type': 'openVideoLibrary',
                'payload': {'protocol': 3},
              },
            },
          ],
        });
        await dbFile.writeAsString(jsonEncode(db));
        final metadataFile = File(p.join(incoming.path, 'sync-settings.json'));
        final metadata = jsonDecode(await metadataFile.readAsString()) as Map;
        metadata['blocks']['plugins']['data']['pluginInfos'] = db['pluginInfo'];
        await metadataFile.writeAsString(jsonEncode(metadata));
        await importExtractedBreezeData(
          incoming.path,
          mode: mode,
          options: const BackupImportOptions(),
          hooks: BackupImportHooks(
            appearanceImages: images,
            recoveryDirectory: Directory(p.join(root.path, 'recovery')),
            checkpoint: (point) async {
              if (point != 'prepared') return;
              final current = objectbox.pluginInfoBox.getAll().single
                ..originScript = 'late-compatible-local';
              objectbox.pluginInfoBox.put(current);
            },
          ),
        );
        expect(
          objectbox.pluginInfoBox.getAll().single.originScript,
          'late-compatible-local',
        );
        expect(
          objectbox.pluginConfigBox.getAll().single.config,
          contains('backup'),
        );
        expect(
          objectbox.unifiedFavoriteBox.getAll().single.title,
          'Imported record',
        );
        expect(
          PluginHostCompatibilityNotices.instance.takePending().single.uuid,
          source,
        );
      },
    );
  }

  test(
    'journal mapping override rejects unmanaged keys and non-string values',
    () async {
      final recovery = await LocalImportRecovery.begin(
        recoveryDirectory: Directory(p.join(root.path, 'guard-recovery')),
        downloads: await Directory(p.join(root.path, 'downloads')).create(),
        images: images,
      );
      try {
        await expectLater(
          recovery.beforePreferences(
            {'unmanaged': 'target'},
            beforeValues: {'unmanaged': 'before'},
          ),
          throwsA(isA<LocalImportRecoveryFailed>()),
        );
        await expectLater(
          recovery.beforePreferences(
            {LocalAppearanceImages.preferencesKey: 'target'},
            beforeValues: {LocalAppearanceImages.preferencesKey: 42},
          ),
          throwsA(isA<LocalImportRecoveryFailed>()),
        );
      } finally {
        await recovery.markRolledBack();
        await recovery.finish();
      }
    },
  );
}
