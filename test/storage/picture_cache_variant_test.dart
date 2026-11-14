import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/network/http/picture/picture.dart';
import 'package:zephyr/page/source_shell/source_experience_preferences.dart';
import 'package:zephyr/service/download/download_asset_store.dart';
import 'package:zephyr/type/enum.dart';

import '../download_fixture.dart';

const _page = 'page.webp';
const _work = 'fixture';
const _chapter = 'ep-fixture';
const _urls = [
  'https://returned-original.example/$_page',
  'https://returned-high.example/$_page',
  'https://returned-medium.example/$_page',
  'https://returned-low.example/$_page',
];

String _variant(String url, {String source = bikaPlusSourceId}) =>
    onlinePictureCacheVariant(from: source, url: url, type: PictureType.page);

DownloadAssetStore _store({
  String variant = '',
  String from = bikaPlusSourceId,
}) => DownloadAssetStore(
  from: from,
  path: _page,
  cartoonId: _work,
  chapterId: _chapter,
  pictureType: PictureType.page,
  cacheVariant: variant,
);

Future<File> _seed(String path, String bytes) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  return file.writeAsString(bytes);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(useIsolatedDownloadFixture);

  test('Bika returned page URL distinguishes byte variants', () {
    final keys = _urls.map(_variant).toSet();
    expect(keys, hasLength(4));
    expect(
      keys.every((key) => RegExp(r'^[0-9a-f]{64}$').hasMatch(key)),
      isTrue,
    );
    expect(_variant('${_urls.first}#viewer'), _variant(_urls.first));
    expect(_variant('${_urls.first}?server=1'), isNot(_variant(_urls.first)));
    expect(_variant(''), isEmpty);
    expect(_variant(_urls.first, source: 'other-source'), isEmpty);
    expect(
      onlinePictureCacheVariant(
        from: bikaPlusSourceId,
        url: _urls.first,
        type: PictureType.cover,
      ),
      isEmpty,
    );
  });

  test(
    'lookup, repair and download copy use the selected online variant',
    () async {
      final base = _store();
      final legacyCache = await _seed(
        await base.canonicalCachePath(),
        'legacy',
      );
      final downloadPath = await base.canonicalDownloadPath();
      final downloadCandidates = (await base.downloadCandidates()).map(
        (candidate) => candidate.path,
      );
      final caches = <File>[];
      for (var i = 0; i < _urls.length; i++) {
        final variant = _store(variant: _variant(_urls[i]));
        expect(
          (await variant.downloadCandidates()).map(
            (candidate) => candidate.path,
          ),
          downloadCandidates,
        );
        caches.add(
          await _seed(await variant.canonicalCachePath(), 'quality-$i'),
        );
      }
      expect(caches.map((file) => file.path).toSet(), hasLength(4));
      expect(
        caches.every((file) => file.parent.path == legacyCache.parent.path),
        isTrue,
      );

      Future<String> read(String url) => getCachePicture(
        from: bikaPlusSourceId,
        cartoonId: _work,
        chapterId: _chapter,
        path: _page,
        url: url,
        applyRealSr: false,
      );
      for (var i = 0; i < _urls.length; i++) {
        expect(await read(_urls[i]), caches[i].path);
        expect(
          await findCachedPicturePath(
            from: bikaPlusSourceId,
            cartoonId: _work,
            chapterId: _chapter,
            path: _page,
            url: _urls[i],
          ),
          caches[i].path,
        );
      }

      final savedFile = await _seed(downloadPath, 'managed download');
      expect(await read(_urls.first), savedFile.path);
      expect(
        await getCachePicture(
          from: bikaPlusSourceId,
          cartoonId: _work,
          chapterId: _chapter,
          path: _page,
          url: _urls.first,
          useDownloads: false,
          applyRealSr: false,
        ),
        caches.first.path,
      );
      expect(
        await findCachedPicturePath(
          from: bikaPlusSourceId,
          cartoonId: _work,
          chapterId: _chapter,
          path: _page,
          offlineReader: true,
        ),
        savedFile.path,
      );
      await savedFile.delete();

      Future<bool> invalidate(String imagePath) => invalidateCachedPicture(
        from: bikaPlusSourceId,
        cartoonId: _work,
        chapterId: _chapter,
        path: _page,
        url: _urls.last,
        imagePath: imagePath,
      );
      expect(await invalidate(caches.first.path), isFalse);
      expect(await invalidate(caches.last.path), isTrue);
      expect(await caches.last.exists(), isFalse);
      expect(await legacyCache.readAsString(), 'legacy');

      final downloaded = await downloadPictureResult(
        from: bikaPlusSourceId,
        cartoonId: _work,
        chapterId: _chapter,
        path: _page,
        url: _urls[2],
        applyRealSr: false,
      );
      expect(downloaded.path, downloadPath);
      expect(await File(downloadPath).readAsString(), 'quality-2');
      expect(await read(''), downloadPath);
      expect(await read(_urls.last), downloadPath);
      expect(await invalidate(downloadPath), isFalse);
    },
  );

  test('other sources keep using existing cached bytes', () async {
    const source = 'other-source';
    final cached = await _seed(
      await _store(from: source).canonicalCachePath(),
      'previous cache',
    );
    expect(
      await getCachePicture(
        from: source,
        cartoonId: _work,
        chapterId: _chapter,
        path: _page,
        url: _urls.first,
        applyRealSr: false,
      ),
      cached.path,
    );
  });
}
