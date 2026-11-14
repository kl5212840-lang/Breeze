import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/donwload_task/service/download_center_projection.dart';
import 'package:zephyr/page/donwload_task/service/download_center_resources.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import '../download_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await useIsolatedDownloadFixture();
    VideoLocalResources.invalidate();
    addTearDown(() async {
      await VideoLocalResources.flush();
      VideoLocalResources.invalidate();
    });
  });
  test('download facets reopen actual saved tags across sources; old rows remain unknown', () async {
    const a = '0c252c72-b4f4-4543-8ab3-341f65aef978';
    const b = 'dd52fcaf-e178-467f-95ba-112e9e5e5216';
    final page = Uri.parse('https://public.example/watch?v=1');
    final oldPage = Uri.parse('https://public.example/watch?v=2');
    for (final entry in [(a, page, ['动作', '剧情']), (b, page, ['旅行']), (a, oldPage, <String>[])]) {
      if (entry.$3.isNotEmpty) {
        await VideoDownloadedDetails.saveSession(entry.$1, NativePlaybackSession(
          title: '旅行 动作 are not inferred from titles', description: '', watchUrl: entry.$2,
          sources: const [], tags: entry.$3));
      }
      final id = VideoLocalResources.identity(entry.$1, entry.$2, '720p');
      final file = await VideoLocalResources.file(id);
      await file.parent.create(recursive: true);
      await file.writeAsBytes([0, 0, 0, 24, ...ascii.encode('ftyp'), ...List.filled(16, 0)]);
      await VideoLocalResources.saved(resourceId: id, bytes: 24, source: entry.$1,
        video: entry.$2, title: '旅行 动作 are not inferred from titles', quality: '720p', taskKey: id);
    }
    Future<List<DownloadCenterItem>> snapshot() async => projectDownloadCenter(
      tasks: [], comics: [], videos: await DownloadCenterResources.readVideos());
    final first = await snapshot();
    expect(first, hasLength(3));
    expect(first.where((item) => item.matches(tags: {'动作'})), hasLength(1));
    expect(first.singleWhere((item) => item.matches(tags: {'动作'})).source, a);
    expect(first.singleWhere((item) => item.matches(tags: {'旅行'})).source, b);
    expect(first.where((item) => item.matches(source: a, tags: {'旅行'})), isEmpty);
    expect(first.where((item) => item.matches(tags: {'not saved'})), isEmpty);
    expect(first.singleWhere((item) => item.video!['url'] == '$oldPage').fields, isEmpty);
    // Reopening uses persisted basics rather than an in-memory facet cache.
    VideoLocalResources.invalidate();
    final reopened = await snapshot();
    expect(reopened.where((item) => item.matches(tags: {'剧情'})), hasLength(1));
    expect(reopened.where((item) => item.matches(tags: {})), hasLength(3));
  });
  test('known API category and language survive saved resource to download facets', () async {
    const source = '0c252c72-b4f4-4543-8ab3-341f65aef978';
    final page = Uri.parse('https://public.example/voddetail/7.html');
    final watch = page.replace(queryParameters: {'line': 'a', 'episode': '1'});
    final item = ApiVideoItem(id: '7', title: '作品', detailUrl: page,
      typeName: '动画', language: 'ja', genres: '奇幻', lines: [
        ApiVideoLine(id: 'a', label: '线路', episodes: [
          ApiVideoEpisode(id: '1', title: '第一集', url: null, watchUrl: watch),
        ]),
      ]);
    await VideoDownloadedDetails.captureItem(source, item, item.episodeCards('a'), namespace: 'movie');
    final id = VideoLocalResources.identity(source, watch, '720p');
    final file = await VideoLocalResources.file(id);
    await file.parent.create(recursive: true);
    await file.writeAsBytes([0, 0, 0, 24, ...ascii.encode('ftyp'), ...List.filled(16, 0)]);
    await VideoLocalResources.saved(resourceId: id, bytes: 24, source: source,
      video: watch, title: '第一集', quality: '720p', taskKey: id);
    final itemRow = projectDownloadCenter(tasks: [], comics: [],
      videos: await DownloadCenterResources.readVideos()).single;
    expect(itemRow.fields['category'], contains('动画'));
    expect(itemRow.fields['tags'], contains('奇幻'));
    expect(itemRow.facetFields['language'], contains('ja'));
  });

}
