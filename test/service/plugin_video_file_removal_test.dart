import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:objectbox/objectbox.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/service/local_import_recovery.dart';

import '../test_helper.dart';
import '../video_local_fixture.dart';

const source = '99999999-1111-4222-8333-444444444444';
const other = '88888888-1111-4222-8333-444444444444';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  late Directory directory, recoveryRoot;
  late LocalAppearanceImages images;
  late File ownFile, otherFile, index;
  late String ownId;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await useIsolatedVideoResources();
    directory = await VideoLocalResources.root();
    await directory.create(recursive: true);
    final resources = <Map<String, dynamic>>[];
    for (final src in [source, other]) {
      final watch = Uri.parse(
        'https://fixture.invalid/watch?v=${src == source ? 7 : 8}',
      );
      final id = VideoLocalResources.identity(src, watch, 'original');
      final file = File('${directory.path}/$id.mp4');
      await file.writeAsBytes(
        Uint8List.fromList([
          0,
          0,
          0,
          24,
          102,
          116,
          121,
          112,
          ...List.filled(16, 0),
        ]),
      );
      if (src == source) {
        ownId = id;
        ownFile = file;
      } else {
        otherFile = file;
      }
      resources.add({
        'resourceId': id,
        'source': src,
        'url': watch.toString(),
        'title': 'synthetic',
        'quality': 'original',
        'bytes': 24,
        'taskKey': '$src:task',
        'showTask': true,
        'at': 1000,
      });
    }
    index = File('${directory.path}/index.json');
    await index.writeAsString(
      jsonEncode({
        'format': 'breeze-local-video',
        'version': 1,
        'resources': resources,
      }),
    );
    recoveryRoot = Directory('${directory.parent.path}/recovery');
    images = LocalAppearanceImages(
      rootDirectory: Directory('${directory.parent.path}/images'),
    );
    await VideoLocalResources.read(fresh: true);
  });
  tearDown(() {
    images.paths.dispose();
  });
  Future<LocalImportRecovery> begin() => LocalImportRecovery.begin(
    recoveryDirectory: recoveryRoot,
    downloads: directory.parent,
    images: images,
  );

  test(
    'source removal refuses player leases and stages only owned media plus shared index',
    () async {
      final beforeIndex = await index.readAsString(),
          otherBytes = await otherFile.readAsBytes();
      final lease = VideoLocalResources.acquireReadLease(ownFile.uri, ownId);
      await expectLater(
        PluginVideoRemovalPlan.prepare(source),
        throwsA(isA<ManagedVideoResourceBusy>()),
      );
      lease.release();
      final plan = await PluginVideoRemovalPlan.prepare(source);
      final checkpoint = await begin();
      try {
        expect(plan.resourceCount, 1);
        expect(plan.fileCount, 1);
        await plan.stage(beforeFileMoves: checkpoint.beforeFileMoves);
        expect(await ownFile.exists(), isFalse);
        expect(await otherFile.readAsBytes(), otherBytes);
        expect(
          (jsonDecode(await index.readAsString())['resources'] as List)
              .single['source'],
          other,
        );
        await plan.rollback();
        expect(await ownFile.exists(), isTrue);
        expect(await index.readAsString(), beforeIndex);
        expect(await plan.finish(committed: false), isTrue);
        await checkpoint.markRolledBack();
        await checkpoint.finish();
      } finally {
        await plan.finish(committed: false);
      }
    },
  );

  test(
    'prepared journal with atomic DB proof completes scoped removal as new state',
    () async {
      final checkpoint = await begin();
      final plan = await PluginVideoRemovalPlan.prepare(
        source,
        recovery: checkpoint,
      );
      try {
        await plan.stage(beforeFileMoves: checkpoint.beforeFileMoves);
        objectbox.store.runInTransaction<void>(
          TxMode.write,
          checkpoint.markDatabaseCommitted,
        );
        await recoverPendingBackupImport(
          recoveryDirectory: recoveryRoot,
          downloadDirectory: directory.parent,
          appearanceImages: images,
        );
        expect(await plan.finish(committed: true), isTrue);
        expect(await ownFile.exists(), isFalse);
        expect(await otherFile.exists(), isTrue);
        expect(
          (await VideoLocalResources.read(fresh: true)).single['source'],
          other,
        );
        expect(
          await directory.list().any(
            (entry) => entry.path.contains('.breeze-removal-'),
          ),
          isFalse,
        );
      } finally {
        await plan.finish(committed: true);
      }
    },
  );

  test(
    'rollback never deletes a newer unrelated index to restore the old one',
    () async {
      final checkpoint = await begin();
      final plan = await PluginVideoRemovalPlan.prepare(
        source,
        recovery: checkpoint,
      );
      try {
        await plan.stage(beforeFileMoves: checkpoint.beforeFileMoves);
        final ownedReplacement = await index.readAsString();
        await index.writeAsString('{"newer":"keep"}');
        await expectLater(plan.rollback(), throwsStateError);
        expect(await index.readAsString(), '{"newer":"keep"}');
        expect(
          plan.moves.any((move) => File(move.staged).existsSync()),
          isTrue,
        );
        // Restore the fixture's action-owned replacement, then perform a normal
        // rollback so this test leaves no pending checkpoint for the next case.
        await index.writeAsString(ownedReplacement);
        await plan.rollback();
        expect(await plan.finish(committed: false), isTrue);
        await checkpoint.markRolledBack();
        await checkpoint.finish();
      } finally {
        await plan.finish(committed: false);
      }
    },
  );
}
