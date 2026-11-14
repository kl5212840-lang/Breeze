import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart'
    as normal;
import 'package:zephyr/page/comic_read/model/normal_comic_ep_info.dart';
import 'package:zephyr/service/reader/reader_history_service.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/service/local_import_recovery.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/service/plugin_data_removal.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/util/get_path.dart';

import '../test_helper.dart';

const _source = '99999999-1111-4222-8333-444444444444';
const _other = '88888888-1111-4222-8333-444444444444';

class _Api extends RustLibApi {
  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({
    required String name,
  }) async => false;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected native call: ${invocation.memberName}');
}

class _HeldReaderHistoryService extends ReaderHistoryService {
  _HeldReaderHistoryService({required super.writePayload})
    : super.forTesting(readHistory: (_, _) => null);

  final settling = Completer<void>();

  @override
  Future<void> settlePendingWrites() {
    settling.complete();
    return super.settlePendingWrites();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final registry = PluginRegistryService.I,
      local = LocalPluginInstallationState.instance;
  late Directory root, downloads, recovery, artwork;
  late LocalAppearanceImages images;
  late VideoLibraryStore library;
  late File media, otherMedia, sourceImage, otherImage;
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    RustLib.initMock(api: _Api());
    await registry.init();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await local.reload();
    TestObjectBoxHelper.cleanComicFolderBoxes();
    objectbox.comicFollowBox.removeAll();
    objectbox.comicReadPreferenceBox.removeAll();
    objectbox.pluginInfoBox.removeAll();
    objectbox.pluginConfigBox.removeAll();
    objectbox.downloadTaskBox.removeAll();
    root = await Directory.systemTemp.createTemp('plugin-personal-removal-');
    recovery = Directory('${root.path}/recovery');
    artwork = await Directory('${root.path}/images').create();
    downloads = Directory(await getDownloadPath());
    for (final entry in await downloads.list().toList()) {
      await entry.delete(recursive: true);
    }
    VideoLocalResources.invalidate();
    library = VideoLibraryStore(deviceId: 'test_device');
    final now = DateTime.utc(2026);
    await registry.upsert(
      PluginInfo(
        uuid: _source,
        version: '1',
        originScript: 'retained script',
        insertedAt: now,
        updatedAt: now,
        isEnabled: true,
        isDeleted: false,
        lastLoadSuccess: true,
        debug: false,
      ),
    );
    objectbox.pluginConfigBox.putMany([
      PluginConfig(name: _source, config: '{"account":"fixture"}'),
      PluginConfig(name: _other, config: '{"keep":true}'),
    ]);
    objectbox.unifiedFavoriteBox.putMany([
      createTestFavorite('$_source:comic')..source = _source,
      createTestFavorite('$_other:comic')..source = _other,
    ]);
    objectbox.unifiedHistoryBox.put(
      createTestHistory('$_source:comic')..source = _source,
    );
    final sourceRoot = await Directory(
      '${downloads.path}/f_1/comic',
    ).create(recursive: true);
    media = await File('${sourceRoot.path}/page').writeAsBytes([1, 2, 3]);
    final otherRoot = await Directory(
      '${downloads.path}/f_2/comic',
    ).create(recursive: true);
    otherMedia = await File('${otherRoot.path}/page').writeAsBytes([4, 5, 6]);
    objectbox.unifiedDownloadBox.put(
      createTestDownload('$_source:comic', storageRoot: sourceRoot.path)
        ..source = _source
        ..comicId = 'comic',
    );
    String basename(String key, List<int> bytes) =>
        'appearance-${sha256.convert(utf8.encode(key))}-${sha256.convert(bytes)}.jpg';
    final sourceName = basename('plugin-icon:$_source', [7, 8]),
        otherName = basename('plugin-icon:$_other', [9]);
    sourceImage = await File(
      '${artwork.path}/$sourceName',
    ).writeAsBytes([7, 8]);
    otherImage = await File('${artwork.path}/$otherName').writeAsBytes([9]);
    await (await SharedPreferences.getInstance()).setString(
      LocalAppearanceImages.preferencesKey,
      jsonEncode({
        'plugin-icon:$_source': sourceName,
        'plugin-icon:$_other': otherName,
      }),
    );
    images = LocalAppearanceImages(rootDirectory: artwork);
    await images.load();
  });
  tearDown(() async {
    if (await File('${recovery.path}/pending.json').exists()) {
      await recoverPendingBackupImport(
        recoveryDirectory: recovery,
        downloadDirectory: downloads,
        appearanceImages: images,
      );
    }
    images.paths.dispose();
    library.dispose();
    await root.delete(recursive: true);
  });

  PluginDataRemovalDependencies services([
    Future<void> Function(String)? checkpoint,
  ]) => PluginDataRemovalDependencies(
    images: images,
    downloads: downloads,
    recoveryDirectory: recovery,
    videoStore: library,
    encodeSource: (_) => 'f_1',
    checkpoint: checkpoint,
  );
  Future<PluginDataRemovalResult> clear({
    bool files = false,
    bool cloud = false,
    bool removeInstallation = false,
    Future<void> Function(String)? checkpoint,
  }) => clearPluginPersonalData(
    _source,
    expectedEpoch: local.installationEpoch(_source),
    choice: PluginDataRemovalChoice(
      cloudDelete: cloud,
      includeDownloads: files,
    ),
    dependencies: services(checkpoint),
    removeInstallation: removeInstallation,
  );
  bool sourceFavoriteExists() => objectbox.unifiedFavoriteBox.getAll().any(
    (row) => row.source == _source && !row.deleted,
  );

  test(
    'queued final reader save cannot resurrect local-only deleted history',
    () async {
      final writing = Completer<void>();
      final release = Completer<void>();
      final reader = _HeldReaderHistoryService(
        writePayload: (payload) async {
          writing.complete();
          await release.future;
          return applyReaderHistorySnapshot(objectbox, payload);
        },
      );
      final owner = reader.loadHistory(
        source: _source,
        comicId: 'comic',
        comicInfo: const normal.ComicInfo(
          id: 'comic',
          title: 'Comic',
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
          pageIndex: 17,
          chapterOrder: 2,
          epInfo: NormalComicEpInfo(epId: 'chapter-2'),
        ),
      );
      final write = reader.stop(owner);
      await writing.future;
      final removal = clearPluginPersonalData(
        _source,
        expectedEpoch: local.installationEpoch(_source),
        choice: const PluginDataRemovalChoice(
          cloudDelete: false,
          includeDownloads: true,
        ),
        dependencies: PluginDataRemovalDependencies(
          images: images,
          downloads: downloads,
          recoveryDirectory: recovery,
          videoStore: library,
          encodeSource: (_) => 'f_1',
          readerHistory: reader,
        ),
        removeInstallation: true,
      );
      try {
        // Release the writer when removal actually waits for it. A regression
        // that clears without waiting would release it after the deletion.
        await Future.any([
          reader.settling.future,
          removal.then<void>((_) {}),
        ]);
      } finally {
        release.complete();
        await write;
      }
      expect((await removal).cleanupPending, isFalse);
      expect(
        objectbox.unifiedHistoryBox.getAll().where((row) => row.source == _source),
        isEmpty,
      );
    },
  );

  test('staged installation marker rolls back with local data before DB commit', () async {
    await expectLater(
      clear(
        files: true,
        removeInstallation: true,
        checkpoint: (stage) async {
          if (stage == 'installation-staged') {
            expect(local.removedAt(_source), isNotNull);
            throw StateError('fixture interrupted before DB commit');
          }
        },
      ),
      throwsStateError,
    );
    expect(local.removedAt(_source), isNull);
    expect(local.isRemoved(_source), isFalse);
    expect(sourceFavoriteExists(), isTrue);
    expect(await media.readAsBytes(), [1, 2, 3]);
  });

  test('DB commit gap retains durable plugin removal as well as cleared data', () async {
    final result = await clear(
      files: true,
      removeInstallation: true,
      checkpoint: (stage) async {
        if (stage == 'database-committed') {
          throw StateError('fixture interrupted after DB commit');
        }
      },
    );
    await local.reload();
    expect(result.cleanupPending, isFalse);
    expect(local.removedAt(_source), isNotNull);
    expect(local.isRemoved(_source), isTrue);
    expect(sourceFavoriteExists(), isFalse);
    expect(await media.exists(), isFalse);
    expect(await otherMedia.readAsBytes(), [4, 5, 6]);
  });

  test('cloud phase failure preserves installation and all local data before journal starts', () async {
    final before = objectbox.pluginInfoBox.getAll().single.toJson();
    await expectLater(clearPluginPersonalData(
      _source,
      expectedEpoch: local.installationEpoch(_source),
      choice: const PluginDataRemovalChoice(cloudDelete: false, includeDownloads: true),
      dependencies: services(),
      removeInstallation: true,
      beforeLocalMutation: () async { throw StateError('cloud unavailable'); },
    ), throwsStateError);
    expect(sourceFavoriteExists(), isTrue);
    expect(objectbox.pluginInfoBox.getAll().single.toJson(), before);
    expect(local.isRemoved(_source), isFalse);
    expect(local.isDataExcluded(_source, PluginDataScope.records), isFalse);
    expect(await media.readAsBytes(), [1, 2, 3]);
    expect(await sourceImage.readAsBytes(), [7, 8]);
    expect(await File('${recovery.path}/pending.json').exists(), isFalse);
  });

  test('successful cloud phase precedes journaled local data plus installation removal', () async {
    var cloud = false;
    final result = await clearPluginPersonalData(
      _source,
      expectedEpoch: local.installationEpoch(_source),
      choice: const PluginDataRemovalChoice(cloudDelete: false, includeDownloads: true),
      dependencies: services(),
      removeInstallation: true,
      beforeLocalMutation: () async {
        expect(sourceFavoriteExists(), isTrue);
        expect(local.isRemoved(_source), isTrue, reason: 'temporary runtime stop already excludes sync participation');
        expect(await media.exists(), isTrue);
        cloud = true;
      },
    );
    expect(cloud, isTrue);
    expect(result.cleanupPending, isFalse);
    expect(local.isRemoved(_source), isTrue);
    expect(sourceFavoriteExists(), isFalse);
    expect(await media.exists(), isFalse);
    expect(await sourceImage.exists(), isFalse);
    expect(await otherMedia.readAsBytes(), [4, 5, 6]);
  });

  test(
    'local-only clear preserves installation, other source, downloaded bytes and reader records',
    () async {
      final plugin = objectbox.pluginInfoBox.getAll().single.toJson();
      final counts = await inspectPluginPersonalData(
        _source,
        expectedEpoch: 0,
        cloudDelete: false,
        dependencies: services(),
      );
      expect(counts.favorites, 1);
      expect(counts.history, 1);
      expect(counts.images, 1);
      expect(counts.downloads, 1);
      final result = await clear();
      expect(result.cleanupPending, isFalse);
      expect(objectbox.pluginInfoBox.getAll().single.toJson(), plugin);
      expect(local.isRemoved(_source), isFalse);
      expect(registry.getByUuid(_source)!.isDeleted, isFalse);
      expect(sourceFavoriteExists(), isFalse);
      expect(objectbox.pluginConfigBox.getAll().map((row) => row.name), [
        _other,
      ]);
      expect(objectbox.unifiedDownloadBox.count(), 1);
      expect(await media.readAsBytes(), [1, 2, 3]);
      expect(await otherMedia.readAsBytes(), [4, 5, 6]);
      expect(await sourceImage.exists(), isFalse);
      expect(await otherImage.readAsBytes(), [9]);
      expect(local.isDataExcluded(_source, PluginDataScope.records), isTrue);
      expect(
        local.isDataExcluded(_source, PluginDataScope.accountSettings),
        isTrue,
      );
      expect(await File('${recovery.path}/pending.json').exists(), isFalse);
    },
  );

  test(
    'explicit downloaded-files choice commits same-volume stages and leaves other source intact',
    () async {
      final result = await clear(files: true);
      expect(result.cleanupPending, isFalse);
      expect(await media.exists(), isFalse);
      expect(await otherMedia.readAsBytes(), [4, 5, 6]);
      expect(objectbox.unifiedDownloadBox.count(), 0);
      expect(local.isRemoved(_source), isFalse);
    },
  );

  for (final stage in ['files-staged', 'preferences-applied']) {
    test(
      'failure at $stage restores source files, preferences and images before DB commit',
      () async {
        final config = objectbox.pluginConfigBox
            .getAll()
            .map((row) => row.toJson())
            .toList();
        await expectLater(
          clear(
            files: true,
            checkpoint: (current) async {
              if (current == stage) throw StateError('fixture failure');
            },
          ),
          throwsStateError,
        );
        expect(sourceFavoriteExists(), isTrue);
        expect(
          objectbox.pluginConfigBox
              .getAll()
              .map((row) => row.toJson())
              .toList(),
          config,
        );
        expect(await media.readAsBytes(), [1, 2, 3]);
        expect(await sourceImage.readAsBytes(), [7, 8]);
        expect(images.pluginIconPath(_source), sourceImage.path);
        expect(local.isDataExcluded(_source, PluginDataScope.records), isFalse);
        expect(local.isRemoved(_source), isFalse);
        expect(await File('${recovery.path}/pending.json').exists(), isFalse);
      },
    );
  }

  test(
    'a new installation intention prevents an old clear from committing',
    () async {
      LocalPluginInstallationLease? installing;
      try {
        await expectLater(
          clear(
            files: true,
            checkpoint: (stage) async {
              if (stage == 'preferences-applied')
                installing = local.beginExplicitInstallation(_source);
            },
          ),
          throwsA(isA<PluginLifecycleChanged>()),
        );
        expect(sourceFavoriteExists(), isTrue);
        expect(await media.readAsBytes(), [1, 2, 3]);
        expect(local.isDataExcluded(_source, PluginDataScope.records), isFalse);
      } finally {
        installing?.release();
      }
    },
  );

  test(
    'DB commit proof keeps the newly cleared state after the journal-commit gap',
    () async {
      final result = await clear(
        files: true,
        checkpoint: (stage) async {
          if (stage == 'database-committed')
            throw StateError('fixture commit gap');
        },
      );
      expect(result.cleanupPending, isFalse);
      expect(sourceFavoriteExists(), isFalse);
      expect(await media.exists(), isFalse);
      expect(objectbox.pluginConfigBox.getAll().map((row) => row.name), [
        _other,
      ]);
      expect(local.isRemoved(_source), isFalse);
      expect(await File('${recovery.path}/pending.json').exists(), isFalse);
    },
  );

  test(
    'already removed plugin stays removed after its independent personal-data clear',
    () async {
      await local.markRemoved(_source);
      await registry.refreshFromDb();
      await clear();
      expect(local.isRemoved(_source), isTrue);
      expect(registry.getByUuid(_source)!.isDeleted, isTrue);
      expect(objectbox.pluginInfoBox.getAll().single.isDeleted, isFalse);
    },
  );

  test(
    'cloud choice creates current personal tombstones without a plugin-installation tombstone',
    () async {
      await clear(cloud: true);
      final record = objectbox.unifiedFavoriteBox.getAll().singleWhere(
        (row) => row.source == _source,
      );
      expect(record.deleted, isTrue);
      final config =
          jsonDecode(
                objectbox.pluginConfigBox
                    .getAll()
                    .singleWhere((row) => row.name == _source)
                    .config,
              )
              as Map;
      expect(config.containsKey('account'), isFalse);
      expect(config['__breezeSyncFields']['account']['deleted'], isTrue);
      expect(objectbox.pluginInfoBox.getAll().single.isDeleted, isFalse);
      expect(local.isRemoved(_source), isFalse);
    },
  );
}
