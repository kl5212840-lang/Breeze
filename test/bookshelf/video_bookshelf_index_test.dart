import '../video_local_fixture.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/bookshelf/cubit/search_status.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/bookshelf/service/video_bookshelf_index.dart';
import 'package:zephyr/page/bookshelf/service/shelf_facet_adapters.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_hls_assets.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/page/video/video_source_action.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await useIsolatedVideoResources();
  });
  ApiVideoItem item(String host) => ApiVideoItem(
    id: '1',
    title: '同名作品',
    detailUrl: Uri.parse('https://$host/voddetail/1.html'),
  );

  test('resume identity cannot cross a source origin or a different work', () {
    final home = Uri.parse('https://alpha.test/');
    VideoBookshelfRow row(String watch) => VideoBookshelfRow(
      key: 'alpha-1',
      source: 'alpha',
      item: item('alpha.test'),
      updatedAt: DateTime.utc(2026),
      watchUrl: Uri.parse(watch),
    );
    expect(
      row(
        'https://alpha.test/voddetail/1.html?line=2&episode=3&token=omit',
      ).resumeAt(home)?.queryParameters,
      {'line': '2', 'episode': '3'},
    );
    expect(
      row('https://beta.test/voddetail/1.html?line=2&episode=3').resumeAt(home),
      isNull,
    );
    expect(
      row(
        'https://alpha.test/voddetail/2.html?line=2&episode=3',
      ).resumeAt(home),
      isNull,
    );
  });

  test('standalone history uses only its matching browser catalog', () {
    final home = Uri.parse('https://omo.test/');
    final watch = home.resolve('/watch?v=123');
    final standalone = VideoBookshelfRow(
      key: 'standalone',
      source: 'source',
      item: ApiVideoItem(id: '123', title: 'Standalone', detailUrl: watch),
      watchUrl: watch,
      updatedAt: DateTime.utc(2026),
    );
    final api = VideoBookshelfRow(
      key: 'api',
      source: 'source',
      item: item(home.host),
      watchUrl: home.resolve('/voddetail/1.html?line=2&episode=3'),
      updatedAt: DateTime.utc(2026),
    );
    Map<String, Object> module(String type, String url) => {
      'type': type,
      'payload': {'url': url},
    };
    final library = module('openVideoLibrary', home.toString());
    final unrelated = module('openVideoCatalog', 'https://unrelated.test/');
    final browser = module('openVideoCatalog', home.toString());
    final mixed = [library, unrelated, browser];
    expect(
      VideoBookshelfIndex.actionForRow([library, unrelated], standalone),
      isNull,
    );
    expect(VideoBookshelfIndex.actionForRow(mixed, standalone), browser);
    expect(
      VideoBookshelfIndex.actionForRow([library, browser], api)?['type'],
      'openVideoLibrary',
    );
    expect(standalone.resumeAt(home), watch);
    final differentVideo = VideoBookshelfRow(
      key: standalone.key,
      source: standalone.source,
      item: standalone.item,
      watchUrl: home.resolve('/watch?v=456'),
      updatedAt: standalone.updatedAt,
    );
    expect(differentVideo.resumeAt(home), isNull);
  });

  test(
    'one plugin reopens favorite and history rows in their matching module',
    () {
      final modules = {
        'breezeVideoModules': [
          for (final namespace in ['movie', 'animate'])
            {
              'type': 'openVideoLibrary',
              'payload': {
                'url': 'https://$namespace.test/',
                'capabilities': {'itemNamespace': namespace},
              },
            },
        ],
      };
      expect(videoSourceActions(modules), hasLength(2));
      expect(
        VideoBookshelfIndex.videoAction(modules)?['payload']['url'],
        'https://movie.test/',
      );
      for (final namespace in ['movie', 'animate']) {
        final detail = Uri.parse('https://$namespace.test/videos/Same_Hid-1');
        final item = ApiVideoItem(
          id: '$namespace:Same_Hid-1',
          title: '同名',
          detailUrl: detail,
        );
        for (final history in [false, true]) {
          final row = VideoBookshelfRow(
            key: '$namespace-$history',
            source: 'hybrid',
            item: item,
            updatedAt: DateTime.utc(2026),
            watchUrl: history
                ? detail.replace(
                    queryParameters: {'line': 'main', 'episode': '1'},
                  )
                : null,
          );
          final action = VideoBookshelfIndex.actionForRow(modules, row)!;
          expect(action['payload']['capabilities']['itemNamespace'], namespace);
          if (history) {
            expect(
              row.resumeAt(Uri.parse(action['payload']['url'])),
              row.watchUrl,
            );
          }
        }
      }
      expect(
        videoSourceAction(modules, home: Uri.parse('https://other.test/')),
        isNull,
      );
    },
  );

  test(
    'legacy library and catalog declarations retain first-action behavior',
    () {
      for (final type in ['openVideoLibrary', 'openVideoCatalog']) {
        final info = {
          'sections': [
            {
              'action': {
                'type': type,
                'payload': {'url': 'https://legacy.test/'},
              },
            },
          ],
        };
        expect(videoSourceAction(info)?['type'], type);
        expect(
          videoSourceAction(
            info,
            home: Uri.parse('https://legacy.test/watch?v=1'),
          )?['type'],
          type,
        );
      }
    },
  );

  test(
    'shelf records do not wait for the shared native download inventory',
    () async {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = previousPlatform);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final firstList = Completer<void>();
      final releaseList = Completer<void>();
      addTearDown(() {
        if (!releaseList.isCompleted) releaseList.complete();
      });
      var lists = 0;
      const hlsSource = 'uninstalled-local-source';
      final page = Uri.parse(
        'https://local-only.test/voddetail/1.html?line=a&episode=1',
      );
      final nativeRows = [
        {
          'resourceId': VideoHlsAssets.identity(hlsSource, page, '720p'),
          'source': hlsSource,
          'url': page.toString(),
          'quality': '720p',
          'assetId': 'fixture',
          'generation': 'fixture-v1',
          'format': 'hls',
          'title': 'Local only',
          'bytes': 128,
          'taskKey': '',
          'showTask': false,
          'at': 1,
          'available': true,
          'filePresent': true,
        },
      ];
      messenger.setMockMethodCallHandler(VideoHlsAssets.channel, (call) async {
        expect(call.method, 'list');
        if (++lists == 1) {
          firstList.complete();
          await releaseList.future;
        }
        return nativeRows;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(VideoHlsAssets.channel, null),
      );
      await VideoBookshelfIndex.store.setFavorite(
        'alpha',
        item('alpha.test'),
        true,
      );
      final parentSources = VideoBookshelfIndex.sourceNames();
      final paneSources = VideoBookshelfIndex.sourceNames();
      final rows = VideoBookshelfIndex.load(
        ShelfPageMode.favorite,
        const SearchStatusState(),
      );
      await firstList.future.timeout(const Duration(seconds: 3));
      expect(
        (await rows.timeout(const Duration(seconds: 3))).single.source,
        'alpha',
      );
      expect(
        await VideoBookshelfIndex.recordSourceNames().timeout(
          const Duration(seconds: 3),
        ),
        allOf(contains('alpha'), isNot(contains(hlsSource))),
      );
      expect(lists, 1);
      releaseList.complete();
      final parent = await parentSources;
      final pane = await paneSources;
      expect(lists, 1);
      expect(pane.keys, containsAll(['alpha', hlsSource]));
      parent.remove(hlsSource);
      expect(pane, contains(hlsSource));

      nativeRows.clear();
      VideoLocalResources.invalidate();
      expect(
        await VideoBookshelfIndex.sourceNames(),
        isNot(contains(hlsSource)),
      );
      expect(lists, 2);
    },
  );

  test(
    'all-source favorites use real stores and keep duplicate IDs separate',
    () async {
      await VideoBookshelfIndex.store.setFavorite(
        'alpha',
        item('alpha.test'),
        true,
      );
      await VideoBookshelfIndex.store.setFavorite(
        'beta',
        item('beta.test'),
        true,
      );
      final rows = await VideoBookshelfIndex.load(
        ShelfPageMode.favorite,
        const SearchStatusState(),
      );
      expect(rows.length, 2);
      expect(rows.map((r) => r.key).toSet().length, 2);
      final selected = await VideoBookshelfIndex.load(
        ShelfPageMode.favorite,
        const SearchStatusState(sources: ['alpha']),
      );
      await VideoBookshelfIndex.remove(ShelfPageMode.favorite, selected);
      final remaining = await VideoBookshelfIndex.load(
        ShelfPageMode.favorite,
        const SearchStatusState(),
      );
      expect(remaining.single.source, 'beta');
    },
  );

  test(
    'mixed stored history skips unsupported third-party watch URLs and retains valid rows',
    () async {
      VideoWatchRecord record(String url, String title) => VideoWatchRecord(
        watchUrl: Uri.parse(url),
        title: title,
        position: const Duration(seconds: 42),
        duration: const Duration(minutes: 10),
        updatedAt: DateTime.utc(2026),
        completed: false,
        metadata: const {
          'genres': 'Actual history tag',
          'typeName': 'Actual category',
          'year': '2024',
          'area': 'Actual area',
          'language': 'Actual language',
        },
      );
      // Simulate an old/imported snapshot, rather than record(), which rejects
      // unsupported identities before persisting them.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'breeze.video.history.v1.unknown-vendor',
        jsonEncode([
          record('https://third.test/watch?id=123', 'Unsupported id').toJson(),
          record('https://third.test/watch', 'Missing id').toJson(),
          record('https://third.test/watch?v=abc', 'Invalid id').toJson(),
          record(
            'https://third.test/voddetail/7.html?line=2&episode=3',
            'API valid',
          ).toJson(),
        ]),
      );
      await VideoWatchHistory.record(
        'catalog-vendor',
        record('https://catalog.test/watch?v=123', 'Catalog valid'),
      );
      final rows = await VideoBookshelfIndex.load(
        ShelfPageMode.history,
        const SearchStatusState(),
      );
      expect(rows.map((row) => row.item.title).toSet(), {
        'API valid',
        'Catalog valid',
      });
      final api = rows.singleWhere((row) => row.source == 'unknown-vendor');
      expect(api.item.id, '7');
      expect(api.watchUrl!.queryParameters, {'line': '2', 'episode': '3'});
      final catalog = rows.singleWhere((row) => row.source == 'catalog-vendor');
      expect(catalog.item.id, '123');
      expect(catalog.watchUrl!.queryParameters, {'v': '123'});
      for (final row in rows) {
        expect(row.item.sourceDuration, '10:00');
        expect(row.progress, '0:42');
        expect(shelfFacetEntryFromVideo(row).fields, {
          'tags': {'Actual history tag'},
          'category': {'Actual category'},
          'year': {'2024'},
          'area': {'Actual area'},
          'language': {'Actual language'},
        });
        expect(
          row.item.year,
          isNot('2026'),
          reason: 'watch timestamp is not release year',
        );
      }
    },
  );

  test('history selection removes only its exact source and episode', () async {
    for (final source in ['alpha', 'beta']) {
      await VideoWatchHistory.record(
        source,
        VideoWatchRecord(
          watchUrl: Uri.parse(
            'https://example.test/anime/1234567890abcdef.html?line=2&episode=3',
          ),
          title: '正在观看',
          position: const Duration(seconds: 42),
          duration: const Duration(minutes: 10),
          updatedAt: DateTime.now().toUtc(),
          completed: false,
        ),
      );
    }
    final rows = await VideoBookshelfIndex.load(
      ShelfPageMode.history,
      const SearchStatusState(sources: ['alpha']),
    );
    expect(rows.single.watchUrl!.queryParameters['episode'], '3');
    await VideoBookshelfIndex.remove(ShelfPageMode.history, rows);
    expect(await VideoWatchHistory.read('alpha'), isEmpty);
    expect(await VideoWatchHistory.read('beta'), hasLength(1));
  });

  test(
    'export records are public acknowledgments and scope removal keeps others',
    () async {
      for (final source in ['alpha', 'beta']) {
        await VideoExportRecords.add(
          source: source,
          video: Uri.parse('https://example.test/watch?v=1&token=do-not-store'),
          title: '已导出作品',
          quality: '1080p',
        );
      }
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(VideoExportRecords.storageKey),
        isNot(contains('do-not-store')),
      );
      final rows = await VideoBookshelfIndex.load(
        ShelfPageMode.download,
        const SearchStatusState(sources: ['alpha']),
      );
      expect(rows, hasLength(1));
      expect(rows.single.facetFields, {
        'quality': {'1080p'},
      });
      expect(rows.single.item.year, isEmpty);
      expect(rows.single.item.genres, isEmpty);
      expect(rows.single.item.typeName, isEmpty);
      expect(rows.single.item.area, isEmpty);
      expect(rows.single.item.language, isEmpty);
      expect(shelfFacetEntryFromVideo(rows.single).fields, {
        'quality': {'1080p'},
      });
      await VideoBookshelfIndex.remove(ShelfPageMode.download, rows);
      expect((await VideoExportRecords.read()).single['source'], 'beta');
    },
  );
}
