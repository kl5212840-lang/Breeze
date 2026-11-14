import 'dart:async';
import 'dart:convert';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/service/comic_public_metadata.dart';
import 'package:zephyr/page/bookshelf/bloc/folder_shelf_bloc.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/bookshelf/cubit/search_status.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry_info.dart';
import 'package:zephyr/page/donwload_task/service/download_center_resources.dart';
import 'package:zephyr/page/donwload_task/service/download_center_projection.dart';
import 'package:zephyr/util/text/public_search_text.dart';
import '../test_helper.dart';

class _SearchApi extends RustLibApi {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected native fixture API ${invocation.memberName}');

  @override
  String crateApiQjsOpenccConvert({required String text, required String config}) =>
      config == 'tw2sp.json' ? text.replaceAll('繁體', '繁体').replaceAll('標籤', '标签') : text;
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async { await TestObjectBoxHelper.setUpTestObjectBox(); RustLib.initMock(api: _SearchApi()); });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(TestObjectBoxHelper.cleanComicFolderBoxes);
  test('public fields update existing exact-source records without timestamps, membership, files or resurrection', () {
    final savedAt = DateTime.utc(2026, 11, 7);
    final favorite = createTestFavorite('source:1', updatedAt: savedAt)..source = 'source'..comicId = '1';
    final history = createTestHistory('source:1', updatedAt: savedAt)..source = 'source'..comicId = '1';
    final download = createTestDownload('source:1', storageRoot: '/fixture/managed', updatedAt: savedAt)..source = 'source'..comicId = '1';
    final deleted = createTestFavorite('source:deleted', deleted: true)..source = 'source'..comicId = 'deleted';
    final foreign = createTestFavorite('other:1')..source = 'other'..comicId = '1';
    objectbox.unifiedFavoriteBox.putMany([favorite, deleted, foreign]);
    objectbox.unifiedHistoryBox.put(history); objectbox.unifiedDownloadBox.put(download);
    final favoriteTime = favorite.createdAt, historyTime = history.lastReadAt,
      historyUpdated = history.updatedAt, downloaded = download.downloadedAt, chapters = download.chapters;
    final fields = [{'type': 'tags', 'name': '标签', 'value': ['繁體標籤']}, {'type': 'author', 'name': '作者', 'value': ['AUTHOR']}];
    ComicPublicMetadata.apply('source', {'1': fields, 'deleted': fields, 'not-saved': fields});
    final saved = objectbox.unifiedFavoriteBox.get(favorite.id)!;
    expect(jsonDecode(saved.metadata).first['value'], ['繁體標籤']);
    expect(saved.createdAt.millisecondsSinceEpoch, favoriteTime.millisecondsSinceEpoch);
    expect(objectbox.unifiedHistoryBox.get(history.id)!.lastReadAt.millisecondsSinceEpoch, historyTime.millisecondsSinceEpoch);
    expect(objectbox.unifiedHistoryBox.get(history.id)!.updatedAt.millisecondsSinceEpoch, historyUpdated.millisecondsSinceEpoch);
    final local = objectbox.unifiedDownloadBox.get(download.id)!;
    expect(local.downloadedAt.millisecondsSinceEpoch, downloaded.millisecondsSinceEpoch); expect(local.storageRoot, '/fixture/managed'); expect(local.chapters, chapters);
    expect(objectbox.unifiedFavoriteBox.get(deleted.id)!.deleted, isTrue);
    expect(objectbox.unifiedFavoriteBox.get(deleted.id)!.metadata, deleted.metadata);
    expect(objectbox.unifiedFavoriteBox.get(foreign.id)!.metadata, foreign.metadata);
    expect(objectbox.unifiedFavoriteBox.count(), 3);
    final projected = DownloadCenterResources.readComics().single;
    expect(projected.fields['tags'], {'繁體標籤'});
    final entry = DownloadCenterItem(key: projected.key, source: projected.source, title: projected.title,
      priority: 0, at: 0, comicId: projected.comicId, resource: projected);
    expect(entry.matches(query: '繁体标签'), isTrue); expect(entry.matches(query: 'author'), isTrue);
    expect(normalizePublicSearchText('繁體 ABC'), normalizePublicSearchText('繁体 abc'));
  });
  test('missing fields retain known values and confirmed empty fields clear them', () {
    const previous = '[{"type":"tags","value":["旧标签"]},{"type":"author","value":["旧作者"]}]';
    final missing = mergeComicPublicMetadata(previous, [{'type': 'tags', 'value': []}, {'type': 'author', 'value': ['新作者']}], fieldsMissing: {'tags'});
    expect(missing, contains('旧标签')); expect(missing, contains('新作者'));
    final cleared = mergeComicPublicMetadata(missing, [{'type': 'tags', 'value': []}]);
    expect(cleared, isNot(contains('旧标签'))); expect(cleared, contains('"type":"tags","name":"","value":[]'));
  });
  test('metadata event quietly reloads a relevant shelf without clearing search or showing a loading state', () async {
    final record = createTestFavorite('source:1')..source = 'source'..comicId = '1';
    objectbox.unifiedFavoriteBox.put(record);
    var calls = 0;
    var changed = Completer<void>();
    final bloc = FolderShelfBloc(mode: ShelfPageMode.favorite, loadTask: (_) async {
      calls++; if (calls > 1 && !changed.isCompleted) changed.complete();
      return {'comics': <ComicSimplifyEntryInfo>[], 'folders': <ComicFolder>[],
        'comicSearchTexts': <String,String>{}, 'comicFolderLabels': <String,String>{}};
    });
    const search = SearchStatusState(keyword: 'kept query', sort: 'da', sources: ['source']);
    bloc.add(const FolderShelfLoadRequested(search: search));
    await Future<void>.delayed(Duration.zero);
    await bloc.refresh();
    final baseline = calls;
    changed = Completer<void>();
    final states = <bool>[]; final sub = bloc.stream.listen((s) => states.add(s.isLoading));
    ComicPublicMetadata.apply('source', {'1': [{'type': 'tags', 'value': ['new']}]});
    await changed.future.timeout(const Duration(seconds: 3));
    await Future<void>.delayed(Duration.zero);
    expect(calls, baseline + 1); expect(states, isNot(contains(true)));
    expect(bloc.state.search, search); expect(bloc.state.sortAscending, isTrue);
    await sub.cancel(); await bloc.close();
  });
}
