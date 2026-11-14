import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:zephyr/network/http/picture/picture.dart';
import 'package:zephyr/service/download/download_asset_store.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/src/rust/api/simple.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/get_path.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
}

class _PathApi extends RustLibApi {
  @override
  String crateApiSimpleEncodePath({required String path}) =>
      'fixture-${path.codeUnits.join('-')}';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => RustLib.initMock(api: _PathApi()));
  tearDownAll(RustLib.dispose);

  test(
    'comic deletion removes supported layouts but ignores a foreign absolute directory',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'breeze-delete-boundary-',
      );
      final paths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(root.path);
      addTearDown(() async {
        PathProviderPlatform.instance = paths;
        await root.delete(recursive: true);
      });
      final downloads = await getDownloadPath();
      const source = 'source', id = 'comic';
      final foreign = Directory(p.join(root.path, 'private-backup'));
      final neighbor = Directory(p.join(downloads, 'another-comic'));
      final owned = [
        Directory(
          p.join(downloads, encodePath(path: source), encodePath(path: id)),
        ),
        Directory(p.join(downloads, source, 'original', encodePath(path: id))),
        Directory(p.join(downloads, source, 'original', id)),
      ];
      for (final dir in [...owned, foreign, neighbor]) {
        await dir.create(recursive: true);
        await File(
          p.join(dir.path, 'keep-or-remove'),
        ).writeAsString('synthetic');
      }
      await deleteComicDownloadDirectory(
        source,
        id,
        legacyStorageRoot: foreign.path,
      );
      expect(await foreign.exists(), isTrue);
      expect(
        await File(p.join(foreign.path, 'keep-or-remove')).readAsString(),
        'synthetic',
      );
      expect(await neighbor.exists(), isTrue);
      for (final dir in owned) {
        expect(await dir.exists(), isFalse);
      }
    },
  );

  Future<String> isolatePaths() async {
    final root = await Directory.systemTemp.createTemp('breeze-delete-owner-');
    final paths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root.path);
    addTearDown(() async {
      PathProviderPlatform.instance = paths;
      await root.delete(recursive: true);
    });
    return getDownloadPath();
  }

  Future<File> fixtureFile(String directory) async {
    final file = File(p.join(directory, 'synthetic'));
    await file.parent.create(recursive: true);
    return file.writeAsString('synthetic');
  }

  String canonical(String root, String source, String id) =>
      p.join(root, encodePath(path: source), encodePath(path: id));

  test('legacy traversal never deletes another source or comic', () async {
    final root = await isolatePaths();
    const source = 'source';
    const id = '../../other/original/victim';
    final owned = await fixtureFile(canonical(root, source, id));
    // The old traversal is resolved by the filesystem only if this prefix exists.
    await Directory(p.join(root, source, 'original')).create(recursive: true);
    final foreign = await fixtureFile(
      p.join(root, 'other', 'original', 'victim'),
    );

    await deleteComicDownloadDirectory(source, id, strict: true);

    expect(await foreign.readAsString(), 'synthetic');
    expect(await owned.exists(), isFalse);
  });

  test(
    'older nested paths remain readable without granting deletion',
    () async {
      final root = await isolatePaths();
      final dir = p.join(
        root,
        'source',
        'original',
        'parent',
        'comic',
        'chapter',
      );
      final file = await fixtureFile(dir);
      final asset = DownloadAssetStore(
        from: 'source',
        cartoonId: 'parent/comic',
        chapterId: 'chapter',
        path: 'synthetic',
        pictureType: PictureType.page,
      );

      expect((await asset.findExistingDownload())?.path, file.path);
      expect(
        (await asset.downloadCandidates(
          forRemoval: true,
        )).map((item) => item.path),
        isNot(contains(file.path)),
      );
    },
  );

  test(
    'linked legacy parent cannot delete external files or partially delete owned data',
    () async {
      final root = await isolatePaths();
      const source = 'source', id = 'comic';
      final owned = await fixtureFile(canonical(root, source, id));
      final foreignRoot = p.join(p.dirname(root), 'foreign');
      final foreign = await fixtureFile(p.join(foreignRoot, 'original', id));
      await Link(p.join(root, source)).create(foreignRoot);

      await expectLater(
        deleteComicDownloadDirectory(source, id, strict: true),
        throwsA(isA<FileSystemException>()),
      );

      expect(await foreign.readAsString(), 'synthetic');
      expect(await owned.readAsString(), 'synthetic');
    },
    skip: Platform.isWindows,
  );
}
