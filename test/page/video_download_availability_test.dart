import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_download_availability.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import '../download_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('only actual exact files prove downloaded; source/work/module/quality/format remain separate', () async {
    SharedPreferences.setMockInitialValues({});
    await useIsolatedDownloadFixture();
    VideoLocalResources.invalidate();
    const source = 'download-availability-fixture';
    final page = Uri.parse('https://fixture.test/voddetail/42.html');
    final watch = page.replace(queryParameters: {'line': 'A', 'episode': '1'});
    final item = ApiVideoItem(id: '42', title: 'Actual work', detailUrl: page,
      lines: [ApiVideoLine(id: 'A', label: 'A', episodes: [
        ApiVideoEpisode(id: '1', title: 'Episode 1', url: null, watchUrl: watch),
      ])]);
    await VideoDownloadedDetails.captureItem(source, item, item.episodeCards('A'), namespace: 'movie');
    final id = VideoLocalResources.identity(source, watch, '720p');
    final key = await VideoExportRecords.beginTransfer(source: source, video: watch,
      title: 'Actual work', quality: '720p', resourceId: id, queued: true);
    final file = await VideoLocalResources.file(id);
    await file.parent.create(recursive: true);
    await file.writeAsBytes([0,0,0,24,102,116,121,112,...List.filled(16,0)]);
    await VideoLocalResources.saved(resourceId: id, bytes: 24, source: source,
      video: watch, title: 'Actual work', quality: '720p', taskKey: key);
    await VideoExportRecords.updateTransfer(key, received: 24, total: 24,
      status: 'saved', resourceId: id, terminal: true);
    Future<VideoDownloadAvailability> read({String from = source, String work = '42', String namespace = 'movie'}) =>
      VideoDownloadAvailability.read(source: from, watch: watch, workId: work, namespace: namespace);
    final available = await read();
    expect(available.episode(watch, quality: '720p', format: 'mp4').downloaded, isTrue);
    expect(available.episode(watch, quality: '1080p', format: 'mp4').downloaded, isFalse);
    expect(available.episode(watch, quality: '720p', format: 'hls').downloaded, isFalse);
    expect((await read(from: 'other')).episode(watch).downloaded, isFalse);
    expect((await read(work: '43')).episode(watch).downloaded, isFalse);
    expect((await read(namespace: 'anime')).episode(watch).downloaded, isFalse);
    await file.delete();
    VideoLocalResources.invalidate();
    final missing = await read();
    expect(missing.episode(watch).latestTask!['status'], 'saved');
    expect(missing.episode(watch).downloaded, isFalse,
      reason: 'The retained saved acknowledgment is not proof of a file');
  });
}
