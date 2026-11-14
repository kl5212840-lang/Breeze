import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/plugin_config_merge.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/network/sync/sync_payload_compatibility.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/bookshelf/service/comic_link_service.dart';
import 'package:zephyr/page/bookshelf/service/shelf_facet_adapters.dart';
import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart'
    as normal;
import 'package:zephyr/page/comic_read/model/normal_comic_ep_info.dart';
import 'package:zephyr/page/setting/data_backup/method.dart'
    show BackupImportHooks, importExtractedBreezeData;
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/service/offline_backup_merge.dart';
import 'package:zephyr/service/reader/reader_history_service.dart';
import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root, incoming, downloads;
  late LocalAppearanceImages images;
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestObjectBoxHelper.cleanComicFolderBoxes();
    objectbox.comicFollowBox.removeAll();
    objectbox.pluginConfigBox.removeAll();
    objectbox.pluginInfoBox.removeAll();
    final user = objectbox.userSettingBox.get(1)!;
    user.globalSetting = const GlobalSettingState();
    objectbox.userSettingBox.put(user);
    root = await Directory.systemTemp.createTemp('breeze_offline_merge_');
    incoming = await Directory(p.join(root.path, 'incoming')).create();
    downloads = await Directory(p.join(root.path, 'downloads')).create();
    images = LocalAppearanceImages(
      rootDirectory: Directory(p.join(root.path, 'images')),
    );
    await images.load();
  });
  tearDown(() async {
    images.paths.dispose();
    await root.delete(recursive: true);
  });

  Future<void> write(
    Map<String, dynamic> database, {
    bool media = false,
  }) async {
    await File(p.join(incoming.path, 'config.json')).writeAsString(
      jsonEncode({
        'format': 'BreezeBackup',
        'schemaVersion': 1,
        'version': 'fixture',
        'exportedAt': '2026-11-02T00:00:00Z',
        'includeDownloads': media,
      }),
    );
    await File(
      p.join(incoming.path, 'objectbox.json'),
    ).writeAsString(jsonEncode(database));
  }

  Future<OfflineBackupMergePlan> prepare({bool media = false}) =>
      prepareOfflineBackupMerge(
        incoming,
        stagingParent: root,
        appearanceImages: images,
        downloadDirectory: downloads,
        restoreDownloadFiles: media,
      );
  Future<Map<String, dynamic>> database(OfflineBackupMergePlan plan) async =>
      jsonDecode(
            await File(
              p.join(plan.directory.path, 'objectbox.json'),
            ).readAsString(),
          )
          as Map<String, dynamic>;
  Future<Map<String, dynamic>> imageManifest(Directory directory) async =>
      jsonDecode(
            await File(
              p.join(directory.path, 'appearance-local', 'manifest.json'),
            ).readAsString(),
          )
          as Map<String, dynamic>;
  Future<void> expectRestorable(OfflineBackupMergePlan plan) async {
    final restore = await images.prepareBackupRestore(plan.directory);
    expect(restore, isNotNull);
    await restore!.finish(committed: false);
  }

  Future<LocalAppearanceImages> foreignImages() async {
    // Separate device ownership despite SharedPreferences being process-global.
    final preferences = await SharedPreferences.getInstance();
    final previous = preferences.getString(
      LocalAppearanceImages.preferencesKey,
    );
    await preferences.remove(LocalAppearanceImages.preferencesKey);
    final foreign = LocalAppearanceImages(
      rootDirectory: Directory(p.join(root.path, 'foreign-images')),
    );
    await foreign.load();
    if (previous != null) {
      await preferences.setString(
        LocalAppearanceImages.preferencesKey,
        previous,
      );
    }
    return foreign;
  }

  test(
    'read-only portable capture neither migrates nor saves metadata',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('breeze.video.defaults.controlsStyle', 'breeze');
      final before = {for (final key in prefs.getKeys()) key: prefs.get(key)};
      await PortablePreferences.capture(persist: false);
      expect({for (final key in prefs.getKeys()) key: prefs.get(key)}, before);
      expect(prefs.containsKey(PortablePreferences.journalKey), isFalse);
    },
  );

  test(
    'planning reuses comic merge but never commits local rows or preferences',
    () async {
      objectbox.unifiedFavoriteBox.put(createTestFavorite('local'));
      await write({
        'unifiedComicFavorite': [createTestFavorite('incoming').toJson()],
      });
      final before = objectbox.collectAllDataJson(removeIds: true);
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().toSet();
      final plan = await prepare();
      try {
        final rows = (await database(plan))['unifiedComicFavorite'] as List;
        expect(rows.map((row) => row['uniqueKey']).toSet(), {
          'local',
          'incoming',
        });
        expect(objectbox.collectAllDataJson(removeIds: true), before);
        expect(prefs.getKeys(), keys);
        expect(
          await File(p.join(incoming.path, 'objectbox.json')).exists(),
          isTrue,
        );
      } finally {
        await plan.dispose();
      }
    },
  );

  test(
    'newer local tombstone wins over older file; repeat planning is stable',
    () async {
      objectbox.unifiedFavoriteBox.put(
        createTestFavorite(
          'removed',
          deleted: true,
          updatedAt: DateTime.utc(2026, 11, 2),
        ),
      );
      await write({
        'unifiedComicFavorite': [
          createTestFavorite(
            'removed',
            updatedAt: DateTime.utc(2026, 10, 1),
          ).toJson(),
        ],
      });
      final first = await prepare();
      final second = await prepare();
      try {
        final rows = (await database(first))['unifiedComicFavorite'] as List;
        expect(rows.single['deleted'], isTrue);
        expect((await database(second))['unifiedComicFavorite'], rows);
      } finally {
        await first.dispose();
        await second.dispose();
      }
    },
  );

  for (final failCommit in [false, true]) {
    test('file merge preserves a video favorite removed during preparation '
        '(rollback: $failCommit)', () async {
      final store = VideoLibraryStore.shared;
      final item = ApiVideoItem(
        id: 'removed',
        title: 'Removed',
        detailUrl: Uri.https('example.test', '/removed'),
      );
      final imported = ApiVideoItem(
        id: 'imported',
        title: 'Imported',
        detailUrl: Uri.https('example.test', '/imported'),
      );
      final foreign = VideoLibraryStore(
        deviceId: 'foreign',
        storageKey: 'test.backup.video-library',
      );
      addTearDown(foreign.dispose);
      await foreign.setFavorite('test', imported, true);
      await store.setFavorite('test', item, true);
      final backup = (await foreign.read()).merged(await store.read());
      await write({'unifiedComicFavorite': []});
      await File(p.join(incoming.path, 'portable-data.json')).writeAsString(
        jsonEncode({
          'format': 'breeze-portable-data',
          'version': 1,
          'preferences': PortablePreferencesSnapshot().toJson(),
          'videoLibrary': backup.toJson(),
        }),
      );
      final operation = importExtractedBreezeData(
        incoming.path,
        hooks: BackupImportHooks(
          appearanceImages: images,
          recoveryDirectory: Directory(p.join(root.path, 'recovery')),
          checkpoint: (point) async {
            if (point == 'prepared') {
              await store.setFavorite('test', item, false);
            }
          },
          beforeCommit: failCommit
              ? () => throw StateError('synthetic commit failure')
              : null,
        ),
      );
      if (failCommit) {
        await expectLater(operation, throwsA(anything));
      } else {
        await operation;
      }
      final library = await store.read();
      expect(
        library.favorites[VideoLibraryStore.itemKey('test', 'removed')]!.deleted,
        isTrue,
      );
      expect(library.contains('test', 'imported'), !failCommit);
    });

    test('file merge preserves watch history deleted during preparation '
        '(rollback: $failCommit)', () async {
      final removed = Uri.https('example.test', '/watch', {'v': '1'});
      final imported = Uri.https('example.test', '/watch', {'v': '2'});
      VideoWatchRecord entry(Uri url) => VideoWatchRecord(
        watchUrl: url,
        title: url.path,
        position: const Duration(minutes: 1),
        duration: const Duration(minutes: 10),
        updatedAt: DateTime.utc(2026),
        completed: false,
      );
      await VideoWatchHistory.record('test', entry(removed));
      await VideoWatchHistory.record('test', entry(imported));
      final resumeKey = entry(removed).legacyProgressKey;
      await (await SharedPreferences.getInstance()).setInt(resumeKey, 60000);
      final backup = await PortablePreferences.capture(persist: false);
      SharedPreferences.setMockInitialValues({});
      await VideoWatchHistory.record('test', entry(removed));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(resumeKey, 60000);
      expect(await VideoWatchHistory.read('test'), hasLength(1));
      await write({'unifiedComicFavorite': []});
      await File(p.join(incoming.path, 'portable-data.json')).writeAsString(
        jsonEncode({
          'format': 'breeze-portable-data',
          'version': 1,
          'preferences': backup.toJson(),
          'videoLibrary': VideoLibrarySnapshot().toJson(),
        }),
      );
      final operation = importExtractedBreezeData(
        incoming.path,
        hooks: BackupImportHooks(
          appearanceImages: images,
          recoveryDirectory: Directory(p.join(root.path, 'recovery')),
          checkpoint: (point) async {
            if (point == 'prepared') {
              await VideoWatchHistory.remove('test', removed);
            }
          },
          beforeCommit: failCommit
              ? () => throw StateError('synthetic commit failure')
              : null,
        ),
      );
      if (failCommit) {
        await expectLater(operation, throwsA(anything));
      } else {
        await operation;
      }
      expect(
        (await VideoWatchHistory.read('test')).map((row) => row.watchUrl),
        failCommit ? isEmpty : [imported],
      );
      expect(prefs.containsKey(resumeKey), isFalse);
    });
  }

  for (final mode in BackupImportMode.values) {
    test('$mode handles comic writes after backup preparation', () async {
      final original = DateTime.utc(2026, 11, 1);
      final incomingTime = DateTime.utc(2026, 11, 2);
      final lateTime = DateTime.utc(2026, 11, 3);
      final history = createTestHistory('test:work', updatedAt: original)
        ..comicId = 'work'
        ..pageIndex = 3;
      final favorite = createTestFavorite('test:work', updatedAt: original)
        ..comicId = 'work';
      objectbox.unifiedHistoryBox.put(history);
      objectbox.unifiedFavoriteBox.put(favorite);
      final rootLink = ComicLinkService.addComic(
        favorite.uniqueKey,
        null,
        ComicFolderType.favorite,
      );
      final follow = ComicFollow(
        uniqueKey: 'test:work',
        source: 'test',
        comicId: 'work',
        title: 'Work',
        description: '',
        cover: '{}',
        creator: '{}',
        titleMeta: '[]',
        metadata: '[]',
        lastChapterCount: 1,
        detectedChapterCount: 1,
        hasUpdate: false,
        updateTime: original,
        deleted: false,
        createdAt: original,
        updatedAt: original,
        schemaVersion: 1,
      );
      objectbox.comicFollowBox.put(follow);
      await write({
        'unifiedComicHistory': [
          {
            ...history.toJson(),
            'id': 0,
            'updatedAt': incomingTime.toIso8601String(),
            'pageIndex': 6,
          },
          createTestHistory('test:imported', updatedAt: incomingTime).toJson(),
        ],
        'unifiedComicFavorite': [
          {
            ...favorite.toJson(),
            'id': 0,
            'updatedAt': incomingTime.toIso8601String(),
          },
        ],
        'comicFollow': [follow.copyWith(id: 0, updatedAt: incomingTime).toJson()],
        'comicLink': [{...rootLink.toJson(), 'id': 0}],
      });
      await importExtractedBreezeData(
        incoming.path,
        mode: mode,
        hooks: BackupImportHooks(
          appearanceImages: images,
          recoveryDirectory: Directory(p.join(root.path, 'recovery')),
          checkpoint: (point) async {
            if (point != 'prepared') return;
            applyReaderHistorySnapshot(objectbox, {
              'source': 'test',
              'comicId': 'work',
              'normalInfo': {
                'id': 'work',
                'title': 'Work',
                'titleMeta': [],
                'description': '',
                'cover': {'id': '', 'url': '', 'name': ''},
                'metadata': [],
              },
              'chapterId': 'chapter',
              'chapterTitle': 'Chapter',
              'chapterOrder': 1,
              'pageIndex': 14,
              'timestamp': lateTime.toIso8601String(),
            });
            objectbox.unifiedFavoriteBox.put(
              favorite
                ..updatedAt = lateTime
                ..deleted = true,
            );
            objectbox.comicFollowBox.put(
              follow.copyWith(
                updatedAt: lateTime,
                detectedChapterCount: 4,
                hasUpdate: true,
              ),
            );
          },
        ),
      );
      final merging = mode == BackupImportMode.merge;
      final histories = {
        for (final row in objectbox.unifiedHistoryBox.getAll()) row.uniqueKey: row,
      };
      expect(histories.keys, unorderedEquals(['test:work', 'test:imported']));
      expect(histories['test:work']!.pageIndex, merging ? 14 : 6);
      expect(
        objectbox.comicFollowBox.getAll().single.detectedChapterCount,
        merging ? 4 : 1,
      );
      expect(objectbox.unifiedFavoriteBox.getAll().single.deleted, merging);
      expect(objectbox.comicLinkBox.getAll().single.comicUniqueKey, 'test:work');
      final shelf = loadComicShelfFacetIndex(type: ComicFolderType.favorite);
      expect(shelf.comics.containsKey('test:work'), !merging);
    });
  }

  for (final failCommit in [false, true]) {
    test('full restore waits for the reader tail (rollback: $failCommit)',
        () async {
      final original = createTestHistory(
        'test:work',
        updatedAt: DateTime.utc(2020),
      )
        ..comicId = 'work'
        ..pageIndex = 3;
      objectbox.unifiedHistoryBox.put(original);
      await write({
        'unifiedComicHistory': [{...original.toJson(), 'id': 0, 'pageIndex': 6}],
      });

      final writerStarted = Completer<void>();
      final releaseWriter = Completer<void>();
      final restoreWaiting = Completer<bool>();
      final reader = ReaderHistoryService.forTesting(
        readHistory: (_, _) => original,
        writePayload: (payload) async {
          writerStarted.complete();
          await releaseWriter.future;
          return applyReaderHistorySnapshot(objectbox, payload);
        },
      );
      final owner = reader.loadHistory(
        source: 'test',
        comicId: 'work',
        comicInfo: const normal.ComicInfo(
          id: 'work',
          title: 'Work',
          titleMeta: [],
          description: '',
          cover: normal.ComicImage(id: '', url: '', name: ''),
          metadata: [],
        ),
      );
      reader.markLoaded(owner);
      reader.startPeriodicSave(
        owner,
        () => HistorySnapshot(
          pageIndex: 14,
          chapterOrder: 1,
          epInfo: NormalComicEpInfo(epId: 'chapter', epName: 'Chapter'),
        ),
      );
      final readerTail = reader.stop(owner);
      await writerStarted.future;

      final restore = importExtractedBreezeData(
        incoming.path,
        mode: BackupImportMode.restore,
        hooks: BackupImportHooks(
          appearanceImages: images,
          recoveryDirectory: Directory(p.join(root.path, 'recovery')),
          settleReaderHistoryWrites: () {
            restoreWaiting.complete(true);
            return reader.settlePendingWrites();
          },
          beforeCommit: () {
            if (!restoreWaiting.isCompleted) restoreWaiting.complete(false);
            if (failCommit) throw StateError('fixture commit failure');
          },
        ),
      );
      final restoreCheck = expectLater(
        restore,
        failCommit ? throwsStateError : completion(isFalse),
      );
      try {
        final waited = await Future.any([
          restoreWaiting.future,
          restore.then((_) => false, onError: (Object _) => false),
        ]);
        expect(waited, isTrue);
        expect(objectbox.unifiedHistoryBox.getAll().single.pageIndex, 3);
      } finally {
        releaseWriter.complete();
        await readerTail;
        await restoreCheck;
      }
      expect(
        objectbox.unifiedHistoryBox.getAll().single.pageIndex,
        failCommit ? 14 : 6,
      );
    });
  }

  test(
    'future entity fields are rejected before staging or mutation',
    () async {
      await write({
        'unifiedComicFavorite': [
          {...createTestFavorite('future').toJson(), 'futureSecret': 'fixture'},
        ],
      });
      final before = objectbox.collectAllDataJson(removeIds: true);
      await expectLater(prepare(), throwsA(isA<SyncCompatibilityException>()));
      expect(objectbox.collectAllDataJson(removeIds: true), before);
      expect(
        root.listSync().whereType<Directory>().where(
          (d) => p.basename(d.path).startsWith('breeze-merged-'),
        ),
        isEmpty,
      );
    },
  );

  test(
    'legacy settings cannot overwrite versioned local plugin deletion',
    () async {
      final user = objectbox.userSettingBox.get(1)!;
      user.globalSetting = const GlobalSettingState(
        syncSetting: SyncSettingState(syncPlugins: true),
      );
      objectbox.userSettingBox.put(user);
      final config = updatePluginConfigField(
        {},
        'account.credentials',
        null,
        nowMs: 500,
      );
      objectbox.pluginConfigBox.put(
        PluginConfig(name: 'fixture', config: jsonEncode(config)),
      );
      await write({
        'pluginConfig': [
          PluginConfig(
            name: 'fixture',
            config: jsonEncode({
              'account.credentials': {'token': 'offline-fixture'},
            }),
          ).toJson(),
        ],
      });
      final plan = await prepare();
      try {
        final row = ((await database(plan))['pluginConfig'] as List).single;
        final restored = jsonDecode(row['config'] as String) as Map;
        expect(restored.containsKey('account.credentials'), isTrue);
        expect(restored['account.credentials'], isNull);
        expect(
          jsonDecode(
            objectbox.pluginConfigBox.getAll().single.config,
          )['account.credentials'],
          isNull,
        );
      } finally {
        await plan.dispose();
      }
    },
  );

  test(
    'disabled settings/plugins keep local configuration and connection',
    () async {
      final user = objectbox.userSettingBox.get(1)!;
      user.globalSetting = const GlobalSettingState(themeMode: ThemeMode.dark);
      objectbox.userSettingBox.put(user);
      objectbox.pluginConfigBox.put(
        PluginConfig(name: 'fixture', config: '{"value":"local"}'),
      );
      final foreign = UserSetting();
      foreign.globalSetting = const GlobalSettingState(
        themeMode: ThemeMode.light,
      );
      await write({
        'userSetting': [foreign.toJson()],
        'pluginConfig': [
          PluginConfig(
            name: 'fixture',
            config: '{"value":"incoming"}',
          ).toJson(),
        ],
      });
      final plan = await prepare();
      try {
        final data = await database(plan);
        final retained = UserSetting.fromJson(
          Map<String, dynamic>.from(
            (data['userSetting'] as List).single as Map,
          ),
        );
        expect(retained.globalSetting.themeMode, ThemeMode.dark);
        expect(
          jsonDecode((data['pluginConfig'] as List).single['config'])['value'],
          'local',
        );
      } finally {
        await plan.dispose();
      }
    },
  );

  test(
    'newer backup selection follows its stable gallery key without mutating local planning',
    () async {
      final bytes = img.encodeJpg(img.Image(width: 8, height: 8));
      final localPath = await images.save('collection-cover', bytes);
      final localKey = images.collectionCovers.keys.single;
      final foreign = await foreignImages();
      final icon = LocalAppearanceImages.pluginIconKey(
        '11111111-2222-3333-4444-555555555555',
      )!;
      try {
        await foreign.save(
          'collection-cover',
          img.encodeJpg(img.Image(width: 9, height: 9)),
        );
        final foreignKey = foreign.collectionCovers.keys.single;
        final foreignPath = foreign.collectionCovers[foreignKey]!;
        await foreign.save(icon, bytes);
        await foreign.exportBackup(incoming);
        final selectedChange =
            ((await imageManifest(incoming))['changes']
                as Map)['collection-cover'];
        // The two stores share only the test preference fixture. Reloading the
        // current store here would falsely substitute foreign device ownership.
        await write({'unifiedComicFavorite': []});
        final plan = await prepare();
        try {
          final manifest =
              jsonDecode(
                    await File(
                      p.join(
                        plan.directory.path,
                        'appearance-local',
                        'manifest.json',
                      ),
                    ).readAsString(),
                  )
                  as Map;
          final rows = manifest['images'] as Map;
          expect(rows.keys.toSet(), {
            'collection-cover',
            localKey,
            foreignKey,
            icon,
          });
          expect(
            (rows['collection-cover'] as Map)['file'],
            p.basename(foreignPath),
          );
          expect(
            (manifest['changes'] as Map)['collection-cover'],
            selectedChange,
          );
          expect(images.paths.value['collection-cover'], localPath);
          final restore = (await images.prepareBackupRestore(plan.directory))!;
          final publishedSelections = <String?>[];
          void observe() =>
              publishedSelections.add(images.paths.value['collection-cover']);
          images.paths.addListener(observe);
          try {
            await restore.activate();
            expect(publishedSelections, [images.collectionCovers[foreignKey]]);
            final snapshot = await images.snapshotForSync();
            expect(
              snapshot.records['collection-cover']!.changeJson,
              selectedChange,
            );
            await snapshot.dispose();
          } finally {
            images.paths.removeListener(observe);
            await restore.finish(committed: false);
          }
        } finally {
          await plan.dispose();
        }
      } finally {
        foreign.paths.dispose();
      }
    },
  );

  test(
    'newer local gallery selection wins over an older backup choice',
    () async {
      await images.saveCollectionCover(
        img.encodeJpg(img.Image(width: 8, height: 8)),
      );
      final first = images.collectionCovers.entries.single;
      await images.saveCollectionCover(
        img.encodeJpg(img.Image(width: 9, height: 9)),
      );
      await images.exportBackup(incoming);
      await images.selectCollectionCover(first.key, first.value);
      final snapshot = await images.snapshotForSync();
      final selectedChange = snapshot.records['collection-cover']!.changeJson;
      await snapshot.dispose();
      await write({'unifiedComicFavorite': []});
      final plan = await prepare();
      try {
        final merged = await imageManifest(plan.directory);
        expect(
          ((merged['images'] as Map)['collection-cover'] as Map)['file'],
          p.basename(first.value),
        );
        expect((merged['changes'] as Map)['collection-cover'], selectedChange);
        await expectRestorable(plan);
      } finally {
        await plan.dispose();
      }
    },
  );

  test(
    'legacy image alias without selection revision preserves the local choice',
    () async {
      await images.saveCollectionCover(
        img.encodeJpg(img.Image(width: 8, height: 8)),
      );
      final first = images.collectionCovers.entries.single;
      await images.saveCollectionCover(
        img.encodeJpg(img.Image(width: 9, height: 9)),
      );
      final other = images.collectionCovers.keys.singleWhere(
        (key) => key != first.key,
      );
      await images.selectCollectionCover(first.key, first.value);
      await images.exportBackup(incoming);
      final legacy = await imageManifest(incoming);
      final selectedChange = (legacy['changes'] as Map).remove(
        'collection-cover',
      );
      (legacy['images'] as Map)['collection-cover'] =
          (legacy['images'] as Map)[other];
      await File(
        p.join(incoming.path, 'appearance-local', 'manifest.json'),
      ).writeAsString(jsonEncode(legacy));
      await write({'unifiedComicFavorite': []});
      final plan = await prepare();
      try {
        final merged = await imageManifest(plan.directory);
        expect(
          ((merged['images'] as Map)['collection-cover'] as Map)['file'],
          p.basename(first.value),
        );
        expect((merged['changes'] as Map)['collection-cover'], selectedChange);
        await expectRestorable(plan);
      } finally {
        await plan.dispose();
      }
    },
  );

  test(
    'equal selection revisions converge on the same stable gallery identity',
    () async {
      await images.saveCollectionCover(
        img.encodeJpg(img.Image(width: 8, height: 8)),
      );
      await images.saveCollectionCover(
        img.encodeJpg(img.Image(width: 9, height: 9)),
      );
      final keys = images.collectionCovers.keys.toList()..sort();
      await images.selectCollectionCover(
        keys.first,
        images.collectionCovers[keys.first]!,
      );
      await images.exportBackup(incoming);
      final manifest = await imageManifest(incoming);
      final changes = manifest['changes'] as Map;
      final revision = (changes['collection-cover'] as Map)['modifiedAt'];
      changes['collection-cover'] = {
        ...changes[keys.last] as Map,
        'modifiedAt': revision,
      };
      (manifest['images'] as Map)['collection-cover'] =
          (manifest['images'] as Map)[keys.last];
      await File(
        p.join(incoming.path, 'appearance-local', 'manifest.json'),
      ).writeAsString(jsonEncode(manifest));
      await write({'unifiedComicFavorite': []});
      final plan = await prepare();
      try {
        final merged = await imageManifest(plan.directory);
        expect(
          ((merged['images'] as Map)['collection-cover'] as Map)['sha256'],
          keys.last.substring('collection-cover:'.length),
        );
        expect(
          ((merged['changes'] as Map)['collection-cover'] as Map)['modifiedAt'],
          revision,
        );
        await expectRestorable(plan);
      } finally {
        await plan.dispose();
      }
    },
  );

  test(
    'local gallery tombstone defeats an older image backup without resurrection',
    () async {
      await images.saveCollectionCover(
        img.encodeJpg(img.Image(width: 8, height: 8)),
      );
      final removed = images.collectionCovers.entries.single;
      await images.exportBackup(incoming);
      await images.removeCollectionCover(removed.key, removed.value);
      final snapshot = await images.snapshotForSync();
      final tombstone = snapshot.records[removed.key]!.changeJson;
      await snapshot.dispose();
      await write({'unifiedComicFavorite': []});
      final plan = await prepare();
      try {
        final manifest = await imageManifest(plan.directory);
        expect((manifest['images'] as Map).containsKey(removed.key), isFalse);
        expect((manifest['changes'] as Map)[removed.key], tombstone);
        expect(images.collectionCovers, isEmpty);
        await expectRestorable(plan);
      } finally {
        await plan.dispose();
      }
    },
  );

  test(
    'newer explicit backup deletion removes only its gallery identity',
    () async {
      await images.saveCollectionCover(
        img.encodeJpg(img.Image(width: 8, height: 8)),
      );
      final removed = images.collectionCovers.entries.single;
      await images.saveCollectionCover(
        img.encodeJpg(img.Image(width: 9, height: 9)),
      );
      final retained = images.collectionCovers.keys.singleWhere(
        (key) => key != removed.key,
      );
      await images.selectCollectionCover(removed.key, removed.value);
      await images.exportBackup(incoming);
      final manifest = await imageManifest(incoming);
      final rows = manifest['images'] as Map;
      final metadata = (manifest['changes'] as Map)[removed.key] as Map;
      metadata['modifiedAt'] = (metadata['modifiedAt'] as int) + 1;
      metadata['deleted'] = true;
      final filename = (rows.remove(removed.key) as Map)['file'] as String;
      rows.remove('collection-cover');
      final selection = (manifest['changes'] as Map)['collection-cover'] as Map;
      selection['modifiedAt'] = (metadata['modifiedAt'] as int) + 1;
      await File(p.join(incoming.path, 'appearance-local', filename)).delete();
      await File(
        p.join(incoming.path, 'appearance-local', 'manifest.json'),
      ).writeAsString(jsonEncode(manifest));
      await write({'unifiedComicFavorite': []});
      final before = Map.of(images.paths.value);
      final plan = await prepare();
      try {
        final merged = await imageManifest(plan.directory);
        expect((merged['images'] as Map).containsKey(removed.key), isFalse);
        expect((merged['images'] as Map).containsKey(retained), isTrue);
        expect(
          ((merged['images'] as Map)['collection-cover'] as Map)['sha256'],
          ((merged['images'] as Map)[retained] as Map)['sha256'],
        );
        expect((merged['changes'] as Map)[removed.key], metadata);
        expect(
          ((merged['changes'] as Map)['collection-cover'] as Map)['modifiedAt'],
          greaterThan(selection['modifiedAt'] as int),
        );
        expect(images.paths.value, before);
        await expectRestorable(plan);
      } finally {
        await plan.dispose();
      }
    },
  );

  test(
    'unversioned backup adds unseen gallery keys but preserves local live and deleted keys',
    () async {
      final first = img.encodeJpg(img.Image(width: 8, height: 8));
      final second = img.encodeJpg(img.Image(width: 9, height: 9));
      await images.saveCollectionCover(first);
      final removed = images.collectionCovers.entries.single;
      await images.saveCollectionCover(second);
      final retained = images.collectionCovers.entries.singleWhere(
        (entry) => entry.key != removed.key,
      );
      await images.removeCollectionCover(removed.key, removed.value);
      final foreign = await foreignImages();
      try {
        await foreign.saveCollectionCover(first);
        await foreign.saveCollectionCover(second);
        await foreign.saveCollectionCover(
          img.encodeJpg(img.Image(width: 10, height: 10)),
        );
        final added = foreign.collectionCovers.keys.singleWhere(
          (key) => key != removed.key && key != retained.key,
        );
        await foreign.exportBackup(incoming);
        final legacy = await imageManifest(incoming);
        legacy.remove('changes');
        await File(
          p.join(incoming.path, 'appearance-local', 'manifest.json'),
        ).writeAsString(jsonEncode(legacy));
        await write({'unifiedComicFavorite': []});
        final plan = await prepare();
        try {
          final merged = await imageManifest(plan.directory);
          final rows = merged['images'] as Map;
          expect(rows.keys.toSet(), {'collection-cover', retained.key, added});
          expect(
            (rows['collection-cover'] as Map)['file'],
            p.basename(retained.value),
          );
          expect(
            ((merged['changes'] as Map)[removed.key] as Map)['deleted'],
            isTrue,
          );
          await expectRestorable(plan);
        } finally {
          await plan.dispose();
        }
      } finally {
        foreign.paths.dispose();
      }
    },
  );

  test(
    'backup with no image manifest preserves the entire local gallery and changes',
    () async {
      await images.saveCollectionCover(
        img.encodeJpg(img.Image(width: 8, height: 8)),
      );
      final removed = images.collectionCovers.entries.single;
      await images.saveCollectionCover(
        img.encodeJpg(img.Image(width: 9, height: 9)),
      );
      await images.removeCollectionCover(removed.key, removed.value);
      final expectedRoot = await Directory(
        p.join(root.path, 'expected'),
      ).create();
      await images.exportBackup(expectedRoot);
      await write({'unifiedComicFavorite': []});
      final plan = await prepare();
      try {
        expect(
          await imageManifest(plan.directory),
          await imageManifest(expectedRoot),
        );
        await expectRestorable(plan);
      } finally {
        await plan.dispose();
      }
    },
  );

  test(
    'gallery merge exceeding seven rejects the plan without dropping either gallery',
    () async {
      for (var size = 8; size < 12; size++) {
        await images.saveCollectionCover(
          img.encodeJpg(img.Image(width: size, height: size)),
        );
      }
      final before = Map.of(images.paths.value);
      final foreign = await foreignImages();
      try {
        for (var size = 12; size < 16; size++) {
          await foreign.saveCollectionCover(
            img.encodeJpg(img.Image(width: size, height: size)),
          );
        }
        await foreign.exportBackup(incoming);
        final manifest = await imageManifest(incoming);
        await write({'unifiedComicFavorite': []});
        await expectLater(prepare(), throwsStateError);
        expect(images.paths.value, before);
        expect(await imageManifest(incoming), manifest);
        expect(
          root.listSync().whereType<Directory>().where(
            (d) => p.basename(d.path).startsWith('breeze-merged-'),
          ),
          isEmpty,
        );
      } finally {
        foreign.paths.dispose();
      }
    },
  );

  test(
    'download merge preserves both trees and refuses conflicting bytes',
    () async {
      await write({'unifiedComicFavorite': []}, media: true);
      final source = await Directory(
        p.join(incoming.path, 'downloads'),
      ).create();
      await File(p.join(downloads.path, 'local.jpg')).writeAsString('local');
      await File(p.join(source.path, 'foreign.jpg')).writeAsString('incoming');
      final plan = await prepare(media: true);
      try {
        expect(
          await File(
            p.join(plan.directory.path, 'downloads', 'local.jpg'),
          ).readAsString(),
          'local',
        );
        expect(
          await File(
            p.join(plan.directory.path, 'downloads', 'foreign.jpg'),
          ).readAsString(),
          'incoming',
        );
      } finally {
        await plan.dispose();
      }
      await File(p.join(source.path, 'local.jpg')).writeAsString('conflict');
      await expectLater(prepare(media: true), throwsA(isA<FormatException>()));
      expect(
        await File(p.join(downloads.path, 'local.jpg')).readAsString(),
        'local',
      );
      expect(
        (await SharedPreferences.getInstance()).containsKey(
          PortablePreferences.journalKey,
        ),
        isFalse,
      );
    },
  );
}
