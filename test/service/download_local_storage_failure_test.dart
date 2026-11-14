import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/service/download/download_asset_store.dart';
import 'package:zephyr/service/download/download_progress_reporter.dart';
import 'package:zephyr/service/download/image_download.dart';
import 'package:zephyr/type/enum.dart';

import '../download_fixture.dart';

const _source = 'download-storage-fixture';
const _comic = 'work';
const _chapter = 'chapter';
const _path = 'image.png';
const _url = 'https://example.invalid/image.png';

class _Reporter extends DownloadProgressReporter {
  @override
  Future<void> sendNotification(String title, String body) async {}
}

Future<File> blockDestination(PictureType type) async {
  final asset = DownloadAssetStore(
    from: _source,
    path: _path,
    cartoonId: _comic,
    chapterId: type == PictureType.cover ? '' : _chapter,
    pictureType: type,
  );
  final cached = File(await asset.canonicalCachePath());
  await cached.parent.create(recursive: true);
  await cached.writeAsString('valid cached image bytes');

  final destination = File(await asset.canonicalDownloadPath());
  final blocker = File(destination.parent.path);
  await blocker.parent.create(recursive: true);
  await blocker.writeAsString('a file occupies the target directory');
  return cached;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(useIsolatedDownloadFixture);

  test(
    'a local page write fault stops continuous retry and keeps cache',
    () async {
      final cached = await blockDestination(PictureType.page);
      var checks = 0;
      var retryChecks = 0;
      await expectLater(
        downloadImageJobs(
          from: _source,
          jobs: const [
            DownloadImageJob(
              url: _url,
              path: _path,
              cartoonId: _comic,
              chapterId: _chapter,
            ),
          ],
          qjsRuntimeName: _source,
          qjsTaskGroupKey: 'storage-failure',
          concurrency: 1,
          ensureTaskRunning: () async {
            checks++;
          },
          shouldRetryUntilSuccess: () => retryChecks++ < 2,
          reporter: _Reporter(),
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(checks, 2); // Worker and first attempt, no second attempt.
      expect(await cached.readAsString(), 'valid cached image bytes');
    },
  );

  test('a cover storage fault is not reported as a missing image', () async {
    final cached = await blockDestination(PictureType.cover);
    await expectLater(
      downloadCoverAsset(
        from: _source,
        url: _url,
        path: _path,
        cartoonId: _comic,
        qjsName: _source,
        qjsTaskGroupKey: 'cover-storage-failure',
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(await cached.readAsString(), 'valid cached image bytes');
  });
}
