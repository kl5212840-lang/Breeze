import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:zephyr/service/source_image_cache_store.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('source_image_cache_test_');
  });
  tearDown(() async => root.delete(recursive: true));

  Future<File> write(String path, String value) async {
    final file = File(p.join(root.path, path));
    await file.parent.create(recursive: true);
    return file.writeAsString(value);
  }

  test('one source removes only its verified image partition', () async {
    final image = await write('cache/f_101/f_1/f_2/f_3', 'image');
    final other = await write('cache/f_202/f_1/f_2/f_3', 'other');
    final protected = <File>[
      other,
      await write('cache/backup-private-v1/draft', 'backup'),
      await write('cache/recovery-export/result', 'export'),
      await write('cache/breeze-video-staging/video.mp4', 'video'),
      await write('cache/sentry/event', 'event'),
      await write('cache/f_999/unattributed', 'unknown'),
      await write('downloads/f_101/page', 'download'),
      await write('files/appearance/picture', 'local image'),
      await write('plugins/source.cjs', 'plugin'),
      await write('db/settings', 'account and records'),
    ];
    final store = SourceImageCacheStore(
      root: p.join(root.path, 'cache'), sourceSegments: ['f_101'],
    );
    expect(await store.sizeBytes(), 5);
    await store.clear();
    expect(await image.exists(), isFalse);
    for (final file in protected) expect(await file.exists(), isTrue);
    expect(await store.sizeBytes(), 0);
  });

  test('global scope includes known partitions and retains unknown roots', () async {
    final first = await write('cache/f_101/image', 'one');
    final second = await write('cache/f_202/image', 'two');
    final unknown = await write('cache/f_303/image', 'unknown');
    final store = SourceImageCacheStore(
      root: p.join(root.path, 'cache'), sourceSegments: ['f_101', 'f_202', 'f_101'],
    );
    expect(await store.sizeBytes(), 6);
    await store.clear();
    expect(await first.exists(), isFalse);
    expect(await second.exists(), isFalse);
    expect(await unknown.readAsString(), 'unknown');
  });

  test('rejects traversal and linked partitions without touching target', () async {
    expect(
      () => SourceImageCacheStore(root: root.path, sourceSegments: ['../downloads']),
      throwsArgumentError,
    );
    final outside = await write('downloads/page', 'keep');
    await Directory(p.join(root.path, 'cache')).create();
    await Link(p.join(root.path, 'cache', 'f_101')).create(outside.parent.path);
    final store = SourceImageCacheStore(
      root: p.join(root.path, 'cache'), sourceSegments: ['f_101'],
    );
    await expectLater(store.clear(), throwsA(isA<FileSystemException>()));
    expect(await outside.readAsString(), 'keep');
  });

  test('nested symbolic links never expose protected files', () async {
    final outside = await write('downloads/page', 'keep');
    await Directory(p.join(root.path, 'cache', 'f_101')).create(recursive: true);
    await Link(p.join(root.path, 'cache', 'f_101', 'linked')).create(outside.parent.path);
    final store = SourceImageCacheStore(
      root: p.join(root.path, 'cache'), sourceSegments: ['f_101'],
    );
    await expectLater(store.sizeBytes(), throwsA(isA<FileSystemException>()));
    await expectLater(store.clear(), throwsA(isA<FileSystemException>()));
    expect(await outside.readAsString(), 'keep');
  });
}
