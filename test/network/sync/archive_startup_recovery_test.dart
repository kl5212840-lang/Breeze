import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/network/sync/sync_archive_context.dart';
import 'package:zephyr/network/sync/sync_archive_recovery.dart';
import 'package:zephyr/network/sync/sync_service.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart' show TxMode;
import 'package:zephyr/page/video/video_playback_preferences.dart';
import 'package:zephyr/util/get_path.dart';

import '../../test_helper.dart';

GlobalSettingState _connection(String host) => GlobalSettingState(
  syncSetting: SyncSettingState(
    syncServiceType: SyncServiceType.webdav,
    webdavSetting: WebDavSettingState(
      host: host,
      username: 'fixture',
      password: 'fixture',
    ),
  ),
);

Future<ArchivePreferenceTransaction> _stagePlayback(String identity) async {
  final transaction = await ArchivePreferenceTransaction.create(identity);
  await VideoPlaybackPreferences.restore(
    {'defaultSpeed': 1.5},
    updatedAt: 10,
    beforeWrite: (next) =>
        transaction.prepare({VideoPlaybackPreferences.snapshotKey: next}),
  );
  return transaction;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    objectbox.store.box<LocalStorageCommit>().removeAll();
    final directory = Directory(
      '${await getFilePath(create: false)}/archive-recovery',
    );
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('startup and adapters derive the same configured archive identity', () {
    final webdav = _connection('https://fixture.invalid');
    final s3 = GlobalSettingState(
      syncSetting: SyncSettingState(
        syncServiceType: SyncServiceType.s3,
        s3Setting: const S3SettingState(
          endpoint: 'https://fixture.invalid',
          accessKey: 'fixture',
          secretKey: 'fixture',
          bucket: 'fixture',
        ),
      ),
    );
    for (final state in [webdav, s3]) {
      final adapter = createSyncArchiveAdapter(state)!;
      expect(syncArchiveIdentityForState(state), adapter.identity);
      expect(adapter.legacyReader!.identity, adapter.identity);
    }
    expect(
      syncArchiveIdentityForState(webdav),
      isNot(syncArchiveIdentityForState(s3)),
    );
    expect(syncArchiveIdentityForState(const GlobalSettingState()), isNull);
  });

  test(
    'startup undoes interrupted playback before the first user edit',
    () async {
      final state = _connection('https://fixture.invalid');
      final identity = syncArchiveIdentityForState(state)!;
      await VideoPlaybackPreferences.save('defaultSpeed', 1.25);
      final transaction = await _stagePlayback(identity);
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      expect((await VideoPlaybackPreferences.read()).defaultSpeed, 1.5);

      expect(await recoverStartupCloudArchive(state), isTrue);
      await VideoPlaybackPreferences.save('cover', true);
      final result = await VideoPlaybackPreferences.read();
      expect(result.defaultSpeed, 1.25);
      expect(result.cover, isTrue);
      expect(await transaction.file!.exists(), isFalse);
    },
  );

  test(
    'startup keeps a committed playback apply and removes its proof',
    () async {
      final state = _connection('https://fixture.invalid');
      final identity = syncArchiveIdentityForState(state)!;
      await VideoPlaybackPreferences.save('defaultSpeed', 1.25);
      final transaction = await _stagePlayback(identity);
      objectbox.store.runInTransaction(
        TxMode.write,
        transaction.markDatabaseCommitted,
      );

      expect(await recoverStartupCloudArchive(state), isTrue);
      expect((await VideoPlaybackPreferences.read()).defaultSpeed, 1.5);
      expect(objectbox.store.box<LocalStorageCommit>().getAll(), isEmpty);
      expect(await transaction.file!.exists(), isFalse);
    },
  );

  test('corrupt active checkpoint and commit proof survive startup', () async {
    final state = _connection('https://fixture.invalid');
    final identity = syncArchiveIdentityForState(state)!;
    final transaction = await _stagePlayback(identity);
    objectbox.store.runInTransaction(
      TxMode.write,
      transaction.markDatabaseCommitted,
    );
    final commits = objectbox.store.box<LocalStorageCommit>();
    final before = commits.getAll().single.operationToken;
    final file = transaction.file!;
    await file.writeAsString('broken-checkpoint', flush: true);

    expect(await recoverStartupCloudArchive(state), isFalse);
    expect(await file.readAsString(), 'broken-checkpoint');
    expect(commits.getAll().single.operationToken, before);
    expect((await VideoPlaybackPreferences.read()).defaultSpeed, 1.5);
    await expectLater(
      ArchivePreferenceTransaction.recover(identity),
      throwsA(isA<ArchiveRestoreFailed>()),
    );
  });

  test('startup leaves another connection checkpoint untouched', () async {
    final previous = _connection('https://previous.invalid');
    final current = _connection('https://current.invalid');
    final transaction = await _stagePlayback(
      syncArchiveIdentityForState(previous)!,
    );
    final file = transaction.file!;
    final raw = await file.readAsString();

    expect(await recoverStartupCloudArchive(current), isTrue);
    expect(
      await recoverStartupCloudArchive(const GlobalSettingState()),
      isTrue,
    );
    expect(await file.readAsString(), raw);
    expect((await VideoPlaybackPreferences.read()).defaultSpeed, 1.5);
  });
}
