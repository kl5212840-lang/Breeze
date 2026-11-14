import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:objectbox/objectbox.dart' show TxMode;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/service/local_import_recovery.dart';

import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  late Directory root, recovery, downloads;
  late LocalAppearanceImages images;
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'owned': 'old',
      'unrelated': 'kept',
    });
    TestObjectBoxHelper.cleanComicFolderBoxes();
    objectbox.downloadTaskBox.removeAll();
    objectbox.pluginConfigBox.removeAll();
    objectbox.comicReadPreferenceBox.removeAll();
    root = await Directory.systemTemp.createTemp('local_import_recovery_');
    recovery = Directory('${root.path}/recovery');
    downloads = await Directory('${root.path}/downloads').create();
    images = LocalAppearanceImages(
      rootDirectory: Directory('${root.path}/images'),
    );
    await File('${downloads.path}/old.txt').writeAsString('original');
  });
  tearDown(() async {
    images.paths.dispose();
    await root.delete(recursive: true);
  });
  Future<LocalImportRecovery> begin() => LocalImportRecovery.begin(
    recoveryDirectory: recovery,
    downloads: downloads,
    images: images,
  );
  Future<void> recover() => recoverPendingBackupImport(
    recoveryDirectory: recovery,
    downloadDirectory: downloads,
    appearanceImages: images,
  );
  Future<void> makeLegacyJournal() async {
    final file = File('${recovery.path}/pending.json');
    final envelope = jsonDecode(await file.readAsString()) as Map;
    final journal = envelope['journal'] as Map;
    journal.remove('operationToken');
    envelope['sha256'] = sha256
        .convert(utf8.encode(jsonEncode(journal)))
        .toString();
    await file.writeAsString(jsonEncode(envelope));
  }

  for (final databaseCommitted in [false, true]) {
    test(
      'HLS removal recovery follows atomic database proof: $databaseCommitted',
      () async {
        const channel = MethodChannel('breeze.video.hls');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final methods = <String>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          methods.add(call.method);
          expect((call.arguments as Map)['token'], 'native-removal-1');
          return true;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final checkpoint = await begin();
        await checkpoint.beforeNativeHlsRemoval('native-removal-1');
        if (databaseCommitted) {
          objectbox.store.runInTransaction<void>(
            TxMode.write,
            checkpoint.markDatabaseCommitted,
          );
        }
        await recover();
        expect(methods, [
          databaseCommitted ? 'commitRemoval' : 'rollbackRemoval',
        ]);
        await recover();
        expect(methods, hasLength(1));
        expect(await File('${recovery.path}/pending.json').exists(), isFalse);
      },
    );
  }

  for (final afterInstall in [false, true]) {
    test(
      'fresh recovery restores original tree after ${afterInstall ? 'second' : 'first'} rename and is repeatable',
      () async {
        final favorite = createTestFavorite('old');
        objectbox.unifiedFavoriteBox.put(favorite);
        final checkpoint = await begin();
        final stage = await root.createTemp('.breeze-download-restore-');
        final incoming = await Directory('${stage.path}/incoming').create();
        await File('${incoming.path}/new.txt').writeAsString('incoming');
        await checkpoint.beforeDownloadSwap(stage, hadTarget: true);
        await downloads.rename('${stage.path}/previous');
        if (afterInstall) await incoming.rename(downloads.path);
        try {
          objectbox.store.runInTransaction<void>(TxMode.write, () {
            objectbox.unifiedFavoriteBox.removeAll();
            objectbox.unifiedFavoriteBox.put(createTestFavorite('new'));
            checkpoint.markDatabaseCommitted();
            throw StateError('abort before commit');
          });
        } on StateError {
          /* Transaction and proof both abort. */
        }
        await checkpoint.beforePreferences({'owned': 'new'});
        await (await SharedPreferences.getInstance()).setString('owned', 'new');
        await recover();
        await recover();
        expect(objectbox.unifiedFavoriteBox.getAll().single.uniqueKey, 'old');
        expect(objectbox.unifiedFavoriteBox.getAll().single.id, favorite.id);
        expect(
          (await SharedPreferences.getInstance()).getString('owned'),
          'old',
        );
        expect(
          (await SharedPreferences.getInstance()).getString('unrelated'),
          'kept',
        );
        expect(
          await File('${downloads.path}/old.txt').readAsString(),
          'original',
        );
        expect(await File('${downloads.path}/new.txt').exists(), isFalse);
        expect(await File('${recovery.path}/pending.json').exists(), isFalse);
      },
    );
  }

  test(
    'legacy journal restores raw local tasks, setting JSON and read column exactly',
    () async {
      const raw = ' { "future-local-field" : [ 1, 2 ] } ';
      final task = DownloadTask()
        ..comicId = 'local'
        ..comicName = 'Local'
        ..isDownloading = true
        ..status = 'local-active'
        ..dbTaskInfoStr = raw;
      objectbox.downloadTaskBox.put(task);
      final setting = objectbox.userSettingBox.get(1)!;
      setting.jmSettingData = raw;
      objectbox.userSettingBox.put(setting);
      final pref = ComicReadPreference(
        uniqueKey: 'local:read',
        source: 'local',
        comicId: 'read',
        overridesJson: raw,
        readMode: 2,
        updatedAt: DateTime.utc(2024),
      );
      objectbox.comicReadPreferenceBox.put(pref);
      await begin();
      await makeLegacyJournal();
      objectbox.downloadTaskBox.removeAll();
      objectbox.comicReadPreferenceBox.removeAll();
      setting.jmSettingData = '{}';
      objectbox.userSettingBox.put(setting);
      await recover();
      final restored = objectbox.downloadTaskBox.get(task.id)!;
      expect(restored.dbTaskInfoStr, raw);
      expect(restored.isDownloading, isTrue);
      expect(restored.status, 'local-active');
      expect(objectbox.userSettingBox.get(1)!.jmSettingData, raw);
      expect(objectbox.comicReadPreferenceBox.get(pref.id)!.readMode, 2);
      expect(objectbox.comicReadPreferenceBox.get(pref.id)!.overridesJson, raw);
      // Keep other tests' typed settings valid; recovery itself never decoded it.
      setting.jmSettingData = '{}';
      objectbox.userSettingBox.put(setting);
    },
  );

  test(
    'legacy database dates restore UTC instants without rewriting opaque text',
    () async {
      const opaque =
          '{"updatedAt":"2024-11-03T01:37:00-04:00","localText":"2024-11-03T09:37:00+08:00"}';
      final inputs = [
        '2024-11-03T09:37:00+08:00',
        '2024-11-03T01:37:00-04:00',
        '2024-11-03T01:37:00-05:00',
      ];
      for (var i = 0; i < inputs.length; i++) {
        final instant = DateTime.parse(inputs[i]);
        objectbox.unifiedFavoriteBox.put(
          createTestFavorite('date:$i', updatedAt: instant.toLocal())
            ..metadata = opaque,
        );
      }
      final before = await LocalImportRecovery.captureDatabaseSnapshot();
      final rows = (before['unifiedComicFavorite'] as List).cast<Map>();
      for (var i = 0; i < inputs.length; i++) {
        final row = rows.singleWhere((r) => r['uniqueKey'] == 'date:$i');
        expect(
          row['updatedAt'],
          DateTime.parse(inputs[i]).toUtc().toIso8601String(),
        );
        expect((row['updatedAt'] as String).endsWith('Z'), isTrue);
        expect(row['metadata'], opaque);
      }
      await begin();
      await makeLegacyJournal();
      objectbox.unifiedFavoriteBox.removeAll();
      await recover();
      for (var i = 0; i < inputs.length; i++) {
        final actual = objectbox.unifiedFavoriteBox.getAll().singleWhere(
          (r) => r.uniqueKey == 'date:$i',
        );
        expect(
          actual.updatedAt.isAtSameMomentAs(DateTime.parse(inputs[i])),
          isTrue,
        );
        expect(actual.metadata, opaque);
      }
    },
  );

  test(
    'committed checkpoint cleans only old staging and retains imported values',
    () async {
      final checkpoint = await begin();
      final stage = await root.createTemp('.breeze-download-restore-');
      final incoming = await Directory('${stage.path}/incoming').create();
      await File('${incoming.path}/new.txt').writeAsString('incoming');
      await checkpoint.beforeDownloadSwap(stage, hadTarget: true);
      await downloads.rename('${stage.path}/previous');
      await incoming.rename(downloads.path);
      await checkpoint.beforePreferences({'owned': 'new'});
      await (await SharedPreferences.getInstance()).setString('owned', 'new');
      objectbox.unifiedFavoriteBox.put(createTestFavorite('new'));
      await checkpoint.markCommitted();
      await recover();
      await recover();
      expect(objectbox.unifiedFavoriteBox.getAll().single.uniqueKey, 'new');
      expect((await SharedPreferences.getInstance()).getString('owned'), 'new');
      expect(
        await File('${downloads.path}/new.txt').readAsString(),
        'incoming',
      );
      expect(await stage.exists(), isFalse);
    },
  );

  test(
    'database commit proof finishes new state when intent is still prepared',
    () async {
      objectbox.unifiedFavoriteBox.put(createTestFavorite('old'));
      final checkpoint = await begin();
      await checkpoint.beforePreferences({'owned': 'new'});
      await (await SharedPreferences.getInstance()).setString('owned', 'new');
      objectbox.store.runInTransaction<void>(TxMode.write, () {
        objectbox.unifiedFavoriteBox.removeAll();
        objectbox.unifiedFavoriteBox.put(createTestFavorite('new'));
        checkpoint.markDatabaseCommitted();
      });
      expect(checkpoint.hasDatabaseCommit, isTrue);
      expect(checkpoint.journal['phase'], 'prepared');
      final snapshot = await LocalImportRecovery.captureDatabaseSnapshot();
      expect(
        snapshot.keys.any((key) => key.toLowerCase().contains('commit')),
        isFalse,
      );
      expect(objectbox.collectAllDataJson(), isNot(contains('operationToken')));
      await recover();
      await recover();
      expect(objectbox.unifiedFavoriteBox.getAll().single.uniqueKey, 'new');
      expect((await SharedPreferences.getInstance()).getString('owned'), 'new');
      expect(objectbox.store.box<LocalStorageCommit>().getAll(), isEmpty);
    },
  );

  test(
    'aborted database transaction also aborts its proof and restores old state',
    () async {
      final old = createTestFavorite('old');
      objectbox.unifiedFavoriteBox.put(old);
      final checkpoint = await begin();
      try {
        objectbox.store.runInTransaction<void>(TxMode.write, () {
          objectbox.unifiedFavoriteBox.removeAll();
          objectbox.unifiedFavoriteBox.put(createTestFavorite('new'));
          checkpoint.markDatabaseCommitted();
          throw StateError('synthetic transaction abort');
        });
      } on StateError {
        /* Expected atomic rollback of rows and proof. */
      }
      expect(checkpoint.hasDatabaseCommit, isFalse);
      await recover();
      expect(objectbox.unifiedFavoriteBox.getAll().single.uniqueKey, 'old');
      expect(objectbox.unifiedFavoriteBox.getAll().single.id, old.id);
    },
  );

  test(
    'prepared atomic journal preserves later unrelated database and preference writes',
    () async {
      objectbox.unifiedFavoriteBox.put(createTestFavorite('old'));
      final checkpoint = await begin();
      await checkpoint.beforePreferences({'owned': 'operation-value'});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('owned', 'operation-value');
      objectbox.unifiedFavoriteBox.put(createTestFavorite('other-source-new'));
      await prefs.setString('owned', 'later-unrelated-value');
      await recover();
      expect(
        objectbox.unifiedFavoriteBox.getAll().map((row) => row.uniqueKey),
        unorderedEquals(['old', 'other-source-new']),
      );
      expect(prefs.getString('owned'), 'later-unrelated-value');
      expect(await File('${recovery.path}/pending.json').exists(), isFalse);
    },
  );

  for (final damage in ['snapshot', 'stage', 'phase']) {
    test(
      'corrupt $damage checkpoint fails closed before touching current user data',
      () async {
        final checkpoint = await begin();
        objectbox.unifiedFavoriteBox.put(createTestFavorite('current'));
        await checkpoint.beforePreferences({'owned': 'new'});
        await (await SharedPreferences.getInstance()).setString('owned', 'new');
        if (damage == 'snapshot') {
          await File('${recovery.path}/snapshot.json').writeAsString('{}');
        } else {
          final file = File('${recovery.path}/pending.json');
          final json = jsonDecode(await file.readAsString()) as Map;
          final journal = json['journal'] as Map;
          if (damage == 'stage') {
            journal['downloads'] = {'hadTarget': true, 'stage': '../user-data'};
          } else {
            journal['phase'] = 'unknown';
          }
          json['sha256'] = sha256
              .convert(utf8.encode(jsonEncode(journal)))
              .toString();
          await file.writeAsString(jsonEncode(json));
        }
        await expectLater(recover(), throwsA(isA<LocalImportRecoveryFailed>()));
        expect(
          objectbox.unifiedFavoriteBox.getAll().single.uniqueKey,
          'current',
        );
        expect(
          (await SharedPreferences.getInstance()).getString('owned'),
          'new',
        );
        expect(
          await File('${downloads.path}/old.txt').readAsString(),
          'original',
        );
        expect(await File('${recovery.path}/pending.json').exists(), isTrue);
      },
    );
  }
}
