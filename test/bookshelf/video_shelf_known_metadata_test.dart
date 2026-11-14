import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/page/bookshelf/service/video_bookshelf_index.dart';

ApiVideoItem item(String id, {String genres = '', String title = 'Work', String path = '/videos/42'}) => ApiVideoItem(
  id: id, title: title, detailUrl: Uri.https('known.test', path), genres: genres,
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('exact local detail fills missing basics without changing identity or making duration from a series', () async {
    final source = item('movie:42');
    final detail = ApiVideoItem(id: source.id, title: source.title, detailUrl: source.detailUrl,
      genres: '科幻 / Comedy', writers: 'Actual writer', year: '2024', sourceDuration: '2:10');
    await VideoDownloadedDetails.saveItem('source-one', detail);
    final known = await VideoDownloadedDetails.readKnownItems('source-one', [source]);
    final projected = videoShelfItemWithKnownMetadata(source, known[source.id]);
    expect(projected.genres, '科幻 / Comedy'); expect(projected.writers, 'Actual writer');
    expect(projected.year, '2024'); expect(projected.id, source.id); expect(projected.detailUrl, source.detailUrl);
    expect(projected.sourceDuration, isEmpty);
    final authoritative = item('movie:42', genres: 'Current');
    expect(videoShelfItemWithKnownMetadata(authoritative, detail).genres, 'Current');
  });
  test('same numeric ID in another module/source or URL cannot borrow tags', () async {
    await VideoDownloadedDetails.saveItem('source-one', item('movie:42', genres: 'Movie tag'));
    expect(await VideoDownloadedDetails.readKnownItems('source-two', [item('movie:42')]), isEmpty);
    expect(await VideoDownloadedDetails.readKnownItems('source-one', [item('anime:42')]), isEmpty);
    expect(videoShelfItemWithKnownMetadata(item('anime:42'), item('movie:42', genres: 'Movie tag')).genres, isEmpty);
    expect(videoShelfItemWithKnownMetadata(item('movie:42', path: '/videos/43'), item('movie:42', genres: 'Movie tag')).genres, isEmpty);
  });
  test('durable downloaded work basics survive eviction of the legacy detail row', () async {
    final known = item('movie:42', genres: 'Persisted tag');
    await VideoDownloadedDetails.captureItem('source-one', known, const [], namespace: 'movie');
    await (await SharedPreferences.getInstance()).remove(VideoDownloadedDetails.storageKey);
    final rows = await VideoDownloadedDetails.readKnownItems('source-one', [item('movie:42'), item('anime:42')]);
    expect(rows['movie:42']!.genres, 'Persisted tag'); expect(rows.containsKey('anime:42'), isFalse);
    final absent = await VideoDownloadedDetails.readKnownItems('source-one', [item('movie:99', title: '2026 Science Fiction')]);
    expect(absent, isEmpty);
  });
}
