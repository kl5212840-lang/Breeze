import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/network/sync/backup_protection_adapter.dart';

import 'backup_protection_cloud_test.dart' as fixture;

class PausableCloud extends fixture.MemoryCloud {
  Completer<void>? listingStarted;
  Completer<void>? releaseListing;

  @override
  Future<List<String>> listRemoteDataFiles() async {
    final pause = releaseListing;
    if (pause != null) {
      releaseListing = null;
      listingStarted!.complete();
      await pause.future;
    }
    return super.listRemoteDataFiles();
  }
}

void main() {
  test(
    'a completed conversion with pending cleanup allows reading but fences writes',
    () async {
      final owner = fixture.manager(fixture.MemoryProfiles());
      await fixture.setup(owner);
      final cloud = fixture.MemoryCloud();
      fixture.seed(cloud);
      cloud.failDelete = true;
      await expectLater(owner.enableCloud(cloud), throwsStateError);
      expect((await owner.inspectCloud(cloud)).cleanupPending, isTrue);
      cloud.failDelete = false;

      final adapter = BackupProtectionSyncAdapter(cloud, manager: owner);
      const file = 'comic_1.bin';
      final latest = utf8.encode('valid replacement snapshot');
      final original = await adapter.downloadRemoteFile(file);
      await expectLater(
        adapter.uploadRemoteFile(file, latest),
        throwsA(fixture.failure('cloud_protection_transition_pending')),
      );
      expect(await adapter.downloadRemoteFile(file), original);
      await owner.resumeCloudTransition(cloud);
      expect(fixture.pendingFiles(cloud), isFalse);
      await adapter.uploadRemoteFile(file, latest);
      expect(await adapter.downloadRemoteFile(file), latest);
      owner.lock();
    },
  );

  test(
    'an endpoint switch during preflight fences writes using a different key',
    () async {
      final active = fixture.manager(fixture.MemoryProfiles());
      final firstRecovery = await fixture.setup(active);
      final first = PausableCloud();
      fixture.seed(first);
      await active.enableCloud(first);
      final firstId = active.session!.profile.archiveId;
      final adapter = BackupProtectionSyncAdapter(first, manager: active);
      await adapter.listRemoteDataFiles();

      final second = fixture.manager(fixture.MemoryProfiles());
      final recovery = await fixture.setup(second);
      final secondProfile = second.session!.profile;
      expect(secondProfile.archiveId, isNot(firstId));

      first.listingStarted = Completer<void>();
      final resume = Completer<void>();
      first.releaseListing = resume;
      const file = 'comic_9.bin';
      final result = expectLater(
        adapter.uploadRemoteFile(file, utf8.encode('cloud A write')),
        throwsA(fixture.failure('cloud_protection_changed_retry')),
      );
      try {
        await first.listingStarted!.future;
        await active.unlock(profile: secondProfile, recoveryCode: recovery);
      } finally {
        resume.complete();
      }
      await result;
      expect(first.files.containsKey(first.path(file)), isFalse);

      final cleanReader = fixture.manager(fixture.MemoryProfiles());
      final firstProfile = (await cleanReader.inspectCloud(first)).profile!;
      expect(firstProfile.archiveId, firstId);
      await cleanReader.unlock(
        profile: firstProfile,
        recoveryCode: firstRecovery,
      );
      final reader = BackupProtectionSyncAdapter(first, manager: cleanReader);
      expect(
        await reader.downloadRemoteFile('comic_1.bin'),
        utf8.encode('standard-coded comic snapshot'),
      );
      cleanReader.lock();
      active.lock();
      second.lock();
    },
  );
}
