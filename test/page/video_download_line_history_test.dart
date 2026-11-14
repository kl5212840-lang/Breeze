import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/downloaded_video_metadata.dart';
import 'package:zephyr/page/video/video_download_line_history.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import '../download_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final work = Uri.parse('https://fixture.test/videos/7');
  const canonical = 'source|movie|7|https://fixture.test/videos/7';
  Map<String, dynamic> file(String line, int at) => {
    'resourceId': line, 'source': 'source', 'url': '$work?line=$line&episode=1',
    'quality': '720p', 'available': true, 'filePresent': true, 'at': at,
  };
  Map<String, dynamic> task(String line, int at) => {...file(line, at), 'status': 'saved'};
  DownloadedVideoMetadata metadata(String line, {String source = 'source', String identity = canonical}) =>
    DownloadedVideoMetadata(source: source, resourceId: line,
      watchUrl: Uri.parse('$work?line=$line&episode=1'), title: 'Actual work',
      canonicalWorkId: identity, quality: '720p');
  String? select(List<Map<String, dynamic>> tasks, List<Map<String, dynamic>> resources,
    List<DownloadedVideoMetadata?> metadata) => lastSuccessfulVideoDownloadLine(
      source: 'source', canonicalWorkId: canonical, workPage: work,
      lineIds: {'A', 'B'}, tasks: tasks, resources: resources, metadata: metadata);
  test('latest completed local success uses exact line ID, not a quality label or speed', () {
    expect(select([task('A', 999), task('B', 1)], [file('A', 10), file('B', 20)],
      [metadata('A'), metadata('B')]), 'B', reason: 'actual completed-file time wins over enqueue time');
  });
  test('source, namespace, work, quality, availability and current lines all fence a badge', () {
    for (final changed in [
      {...file('A', 1), 'available': false}, {...file('A', 1), 'filePresent': false},
      {...file('A', 1), 'source': 'other'}, {...file('A', 1), 'quality': '1080p'},
      {...file('A', 1), 'url': 'https://fixture.test/videos/8?line=A&episode=1'},
    ]) { expect(select([task('A', 1)], [changed], [metadata('A')]), isNull); }
    for (final wrong in [metadata('A', source: 'other'), metadata('A', identity: 'source|anime|7|$work'),
      metadata('A', identity: 'source|movie|8|$work'), null]) {
      expect(select([task('A', 1)], [file('A', 1)], [wrong]), isNull);
    }
    expect(select([{...task('A', 1), 'status': 'failed'}], [file('A', 1)], [metadata('A')]), isNull);
    expect(select([task('removed-line', 1)], [file('removed-line', 1)], [metadata('removed-line')]), isNull);
  });
  test('actual saved file plus durable metadata produces a read-only success mark', () async {
    const source = 'ccc2fe17-c0a8-4fd8-a596-835772686404';
    SharedPreferences.setMockInitialValues({});
    await useIsolatedDownloadFixture();
    VideoLocalResources.invalidate();
    final watch = Uri.parse('$work?line=A&episode=1');
    final item = ApiVideoItem(id: '7', title: 'Actual work', detailUrl: work,
      lines: [ApiVideoLine(id: 'A', label: 'Line A', episodes: [
        ApiVideoEpisode(id: '1', title: 'Episode 1', url: null, watchUrl: watch),
      ])]);
    await VideoDownloadedDetails.captureItem(source, item, item.episodeCards('A'), namespace: 'movie');
    final id = VideoLocalResources.identity(source, watch, '720p');
    final key = await VideoExportRecords.beginTransfer(source: source, video: watch,
      title: 'Actual work', quality: '720p', resourceId: id, queued: true);
    final media = await VideoLocalResources.file(id);
    await media.parent.create(recursive: true);
    await media.writeAsBytes([0, 0, 0, 24, ...ascii.encode('ftyp'), ...List.filled(16, 0)]);
    await VideoLocalResources.saved(resourceId: id, bytes: 24, source: source,
      video: watch, title: 'Actual work', quality: '720p', taskKey: key);
    final row = (await VideoLocalResources.read()).single;
    await VideoDownloadedDetails.retainForResource(row, frameFallback: false);
    await VideoExportRecords.updateTransfer(key, received: 24, total: 24, status: 'saved', terminal: true);
    final prefs = await SharedPreferences.getInstance();
    final before = prefs.getString(VideoExportRecords.taskStorageKey);
    expect(await readLastSuccessfulVideoDownloadLine(source: source, workId: '7', namespace: 'movie',
      currentWatch: watch, lineIds: {'A', 'B'}), 'A');
    expect(prefs.getString(VideoExportRecords.taskStorageKey), before, reason: 'a badge cannot select or alter a task');
    expect(await readLastSuccessfulVideoDownloadLine(source: source, workId: '7', namespace: 'anime',
      currentWatch: watch, lineIds: {'A', 'B'}), isNull);
    await VideoLocalResources.flush(); VideoLocalResources.invalidate();
  });
}
