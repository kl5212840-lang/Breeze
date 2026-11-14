import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:zephyr/service/plugin_comic_file_removal.dart';

const _source = '99999999-1111-4222-8333-444444444444';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('plugin-comic-removal-');
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });
  Future<File> write(
    String relative, [
    List<int> bytes = const [1, 2, 3],
  ]) async {
    final file = File(p.join(root.path, relative));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<PluginComicFileRemovalPlan> prepare() =>
      PluginComicFileRemovalPlan.prepare(
        _source,
        downloadsRoot: root,
        encodeSource: (_) => 'f_123',
      );

  test(
    'preview is read-only; every same-volume move is journaled before staging',
    () async {
      final canonical = await write('f_123/comic/chapter/page');
      final legacy = await write('$_source/original/comic/page', [4, 5]);
      final other = await write('f_456/comic/page', [7]);
      final plan = await prepare();
      expect(plan.fileCount, 2);
      expect(plan.directoryCount, 2);
      expect(await canonical.exists(), isTrue);
      expect(await legacy.exists(), isTrue);
      var journaled = false;
      await plan.stage(
        beforeFileMoves: (moves) async {
          expect(moves, hasLength(2));
          for (final move in moves) {
            expect(await Directory(move.original).exists(), isTrue);
            expect(
              await FileSystemEntity.type(move.staged),
              FileSystemEntityType.notFound,
            );
            expect(p.dirname(move.original), p.dirname(move.staged));
            expect(move.replacementSha256, isNull);
          }
          journaled = true;
        },
      );
      expect(journaled, isTrue);
      expect(await canonical.exists(), isFalse);
      expect(await legacy.exists(), isFalse);
      expect(await other.readAsBytes(), [7]);
      await plan.rollback();
      expect(await canonical.readAsBytes(), [1, 2, 3]);
      expect(await legacy.readAsBytes(), [4, 5]);
    },
  );

  test(
    'failed journal preparation leaves original bytes and paths untouched',
    () async {
      final original = await write('f_123/comic/page');
      final plan = await prepare();
      await expectLater(
        plan.stage(
          beforeFileMoves: (_) async {
            throw StateError('fixture journal failure');
          },
        ),
        throwsStateError,
      );
      expect(await original.readAsBytes(), [1, 2, 3]);
      expect(await plan.finish(committed: false), isTrue);
    },
  );

  test(
    'file changes invalidate preview before any move is registered',
    () async {
      await write('f_123/comic/page');
      final plan = await prepare();
      await write('f_123/comic/another-page');
      var journaled = false;
      await expectLater(
        plan.stage(
          beforeFileMoves: (_) async {
            journaled = true;
          },
        ),
        throwsStateError,
      );
      expect(journaled, isFalse);
      expect(await Directory(p.join(root.path, 'f_123')).exists(), isTrue);
    },
  );

  test('committed cleanup deletes only retained source stages', () async {
    await write('f_123/comic/page');
    final other = await write('f_456/comic/page', [9]);
    final plan = await prepare();
    await plan.stage(beforeFileMoves: (_) async {});
    expect(await plan.finish(committed: true), isTrue);
    for (final move in plan.moves) {
      expect(await Directory(move.staged).exists(), isFalse);
    }
    expect(await other.readAsBytes(), [9]);
  });

  test('rollback never overwrites files created after the stage', () async {
    await write('f_123/comic/page');
    final plan = await prepare();
    await plan.stage(beforeFileMoves: (_) async {});
    final newFile = await write('f_123/new-page', [8]);
    await expectLater(plan.rollback(), throwsStateError);
    expect(await newFile.readAsBytes(), [8]);
    expect(await Directory(plan.moves.single.staged).exists(), isTrue);
  });

  test(
    'missing root preview creates no directory and performs no native encoding',
    () async {
      final missing = Directory(p.join(root.path, 'missing'));
      final plan = await PluginComicFileRemovalPlan.prepare(
        _source,
        downloadsRoot: missing,
        encodeSource: (_) => throw StateError('must not encode'),
      );
      expect(plan.fileCount, 0);
      expect(plan.moves, isEmpty);
      expect(await missing.exists(), isFalse);
    },
  );

  test(
    'a plugin cannot claim the shared video directory as a legacy comic root',
    () async {
      final video = await write('video-v1/index.json', [7]);
      final plan = await PluginComicFileRemovalPlan.prepare(
        'video-v1',
        downloadsRoot: root,
        ownedStorageRoots: [video.parent.path],
        encodeSource: (_) => 'f_123',
      );
      expect(plan.moves, isEmpty);
      expect(await video.readAsBytes(), [7]);
    },
  );

  test(
    'linked entries are rejected without touching their target',
    () async {
      final target = await File(
        p.join(root.parent.path, '${p.basename(root.path)}-outside'),
      ).writeAsBytes([6]);
      try {
        final source = Directory(p.join(root.path, 'f_123'));
        await source.create();
        await Link(p.join(source.path, 'linked-page')).create(target.path);
        await expectLater(prepare(), throwsFormatException);
        expect(await target.readAsBytes(), [6]);
      } finally {
        await target.delete();
      }
    },
    skip: Platform.isWindows
        ? 'Symlink creation requires separate Windows privilege.'
        : false,
  );
}
