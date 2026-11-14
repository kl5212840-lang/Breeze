import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/search/widget/search_input_dialog.dart';
import 'package:zephyr/widgets/source_choice_menu.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_history.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/video_library_view.dart';
import 'package:zephyr/page/video/video_watch_history.dart';

VideoWatchRecord _record(Uri watch, {DateTime? updatedAt}) => VideoWatchRecord(
  watchUrl: watch,
  title: '恢复播放测试',
  position: const Duration(minutes: 3),
  duration: const Duration(minutes: 24),
  updatedAt: updatedAt ?? DateTime.utc(2026, 10, 28),
  completed: false,
);

void main() {
  final home = Uri.parse('https://video.example/');
  final cases = {
    '/anime/023c74a87da31be14245e313.html': '023c74a87da31be14245e313',
    '/voddetail/123.html': '123',
    '/index.php/vod/detail/id/456.html': '456',
    '/vod/789/': '789',
  };
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('video modules retain HID path and have distinct history IDs', () {
    for (final namespace in ['movie', 'animate']) {
      final watch = Uri.parse(
        'https://$namespace.test/videos/Same_Hid-1?token=omit',
      );
      final item = apiVideoHistoryItem(
        _record(watch),
        itemNamespace: namespace,
        containCover: namespace == 'animate',
      );
      expect(item.id, '$namespace:Same_Hid-1');
      expect(item.containCover, namespace == 'animate');
      expect(item.detailUrl.path, '/videos/Same_Hid-1');
      expect(item.detailUrl.hasQuery, isFalse);
      expect(item.title, '恢复播放测试');
    }
    expect(
      apiVideoHistoryItem(
        _record(home.resolve('/voddetail/123.html')),
        itemNamespace: 'movie',
      ).id,
      '123',
    );
  });

  for (final path in [
    '/videos/a.b',
    '/videos/${'a' * 65}',
    '/videos/a/extra',
  ]) {
    test('unsafe module HID $path is rejected', () {
      expect(
        () => apiVideoHistoryItem(
          _record(home.resolve(path)),
          itemNamespace: 'movie',
        ),
        throwsFormatException,
      );
    });
  }

  for (final history in [false, true]) {
    testWidgets(
      'module ${history ? 'history' : 'continue'} opens its own namespace',
      (tester) async {
        for (final namespace in ['movie', 'animate']) {
          await VideoWatchHistory.record(
            'hybrid-resume',
            _record(
              Uri.parse(
                'https://$namespace.test/videos/Same_Hid-1?line=main&episode=1',
              ),
            ),
          );
        }
        ApiVideoItem? opened;
        Uri? resume;
        Future<void> open(ApiVideoItem item, Uri watch) async {
          opened = item;
          resume = watch;
        }

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: history
                  ? ApiVideoHistory(
                      source: 'hybrid-resume',
                      home: Uri.parse('https://animate.test/'),
                      itemNamespace: 'animate',
                      posterAspectRatio: 4 / 3,
                      mode: ApiVideoView.grid,
                      onOpen: open,
                    )
                  : ApiVideoContinueEntry(
                      source: 'hybrid-resume',
                      home: Uri.parse('https://animate.test/'),
                      itemNamespace: 'animate',
                      posterAspectRatio: 4 / 3,
                      onOpen: open,
                    ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (history) {
          final collection = tester.widget<ApiVideoCollection>(
            find.byType(ApiVideoCollection),
          );
          expect(collection.items, hasLength(1));
          expect(collection.posterAspectRatio, 4 / 3);
          collection.onOpen(collection.items.single);
        } else {
          await tester.tap(find.byKey(const ValueKey('api-continue')));
        }
        await tester.pumpAndSettle();
        expect(opened?.id, 'animate:Same_Hid-1');
        expect(opened?.containCover, isTrue);
        expect(resume?.origin, 'https://animate.test');
        expect(await VideoWatchHistory.read('hybrid-resume'), hasLength(2));
        if (history) {
          await tester.tap(find.byKey(const ValueKey('api-history.manage')));
          await tester.pumpAndSettle();
          await tester.tap(find.text(t.videoLibrary.clearHistory));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(TextButton, t.common.delete));
          await tester.pumpAndSettle();
          final remaining = await VideoWatchHistory.read('hybrid-resume');
          expect(remaining, hasLength(1));
          expect(remaining.single.watchUrl.origin, 'https://movie.test');
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final narrow in [false, true]) {
    testWidgets(
      'history local search and sort restore across source/home and remount${narrow ? ' at 320pt large text' : ''}',
      (tester) async {
        tester.view.physicalSize = narrow
            ? const Size(320, 900)
            : const Size(800, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final source in ['history-a', 'history-b']) {
          for (final host in ['alpha.test', 'beta.test']) {
            for (final id in [1, 2]) {
              await VideoWatchHistory.record(
                source,
                VideoWatchRecord(
                  watchUrl: Uri.parse(
                    'https://$host/voddetail/$id.html?line=1&episode=1',
                  ),
                  title: id == 1 ? 'Alpha' : 'Beta',
                  position: const Duration(seconds: 30),
                  duration: const Duration(minutes: 10),
                  updatedAt: DateTime.utc(2026, 10, id),
                  completed: false,
                ),
              );
            }
          }
        }
        final bucket = PageStorageBucket();
        var source = 'history-a', host = 'alpha.test';
        var active = true, show = true;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: narrow ? const Size(320, 900) : const Size(800, 900),
                textScaler: TextScaler.linear(narrow ? 2 : 1),
              ),
              child: Scaffold(
                body: PageStorage(
                  bucket: bucket,
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      update = setState;
                      return show
                          ? ApiVideoHistory(
                              source: source,
                              home: Uri.parse('https://$host/'),
                              mode: ApiVideoView.grid,
                              active: active,
                              onOpen: (_, _) async {},
                            )
                          : const SizedBox.shrink();
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        List<String> titles() => tester
            .widget<ApiVideoCollection>(find.byType(ApiVideoCollection))
            .items
            .map((item) => item.title)
            .toList();
        SourceChoiceMenu<String> sort() =>
            tester.widget<SourceChoiceMenu<String>>(
              find.byKey(const ValueKey('api-video-history.sort')),
            );
        Finder search() => find.descendant(
          of: find.byType(SearchQueryField),
          matching: find.byType(TextField),
        );
        expect(titles(), ['Beta', 'Alpha']);
        sort().onChanged!('title');
        await tester.pumpAndSettle();
        expect(titles(), ['Alpha', 'Beta']);
        await tester.enterText(search(), 'ALP');
        await tester.pumpAndSettle();
        expect(titles(), ['Alpha']);
        update(() => active = false);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<SearchQueryField>(find.byType(SearchQueryField))
              .focusNode!
              .hasFocus,
          isFalse,
        );
        update(() {
          source = 'history-b';
          active = true;
        });
        await tester.pumpAndSettle();
        expect(titles(), ['Beta', 'Alpha']);
        expect(sort().value, 'recent');
        update(() => source = 'history-a');
        await tester.pumpAndSettle();
        expect(titles(), ['Alpha']);
        expect(sort().value, 'title');
        update(() => host = 'beta.test');
        await tester.pumpAndSettle();
        expect(titles(), ['Beta', 'Alpha']);
        update(() => host = 'alpha.test');
        await tester.pumpAndSettle();
        expect(titles(), ['Alpha']);
        update(() => show = false);
        await tester.pumpAndSettle();
        update(() => show = true);
        await tester.pumpAndSettle();
        expect(titles(), ['Alpha']);
        expect(sort().value, 'title');
        await tester.enterText(search(), 'missing');
        await tester.pumpAndSettle();
        expect(find.text(t.videoLibrary.noResults), findsOneWidget);
        // With no matching records, More still offers management of this
        // local source, but cannot clear hidden records from another query.
        await tester.tap(find.byKey(const ValueKey('api-history.manage')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('video-host-menu')), findsOneWidget);
        expect(find.text(t.videoLibrary.clearHistory), findsNothing);
        expect(find.text(t.videoSource.manage).hitTestable(), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, t.common.clear));
        await tester.pumpAndSettle();
        expect(titles(), ['Alpha', 'Beta']);
        expect(sort().value, 'title');
        expect(tester.widget<TextField>(search()).controller!.text, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final route in cases.entries) {
    test('history restores the exact plugin ID from ${route.key}', () async {
      final watch = home.resolve('${route.key}?line=3&episode=12');
      final item = apiVideoHistoryItem(_record(watch));
      final calls = <String>[];
      final repo = ApiVideoRepository(
        source: 'history-id',
        home: home,
        catalogFn: 'list',
        detailFn: 'item',
        playbackFn: 'play',
        pluginCall: (_, args) async {
          calls.add('${args['id']}');
          if (args['id'] != route.value) {
            throw const FormatException('Plugin rejects path instead of ID');
          }
          return {
            'data': {
              'id': route.value,
              'title': '恢复播放测试',
              'detailUrl': '${home.resolve(route.key)}',
            },
          };
        },
      );
      expect((await repo.item(item.id)).id, route.value);
      expect(calls, [route.value]);
      expect(item.detailUrl, home.resolve(route.key));
      expect(item.detailUrl.hasQuery, isFalse);
      expect(item.id, isNot(contains('/')));
      expect(item.containCover, isFalse);
    });
  }

  test('standalone history preserves the public watch query identity', () {
    final watch = home.resolve('/watch?v=123&token=private');
    final item = apiVideoHistoryItem(_record(watch));
    expect(item.id, '123');
    expect(item.detailUrl, home.resolve('/watch?v=123'));
  });

  testWidgets('standalone library opens the full watch identity', (tester) async {
    final watch = home.resolve('/watch?v=123');
    await VideoWatchHistory.record('standalone-history', _record(watch));
    Uri? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoLibraryView(
            source: 'standalone-history',
            siteHost: home.host,
            onOpenVideo: (url) => opened = url,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final collection = tester.widget<ApiVideoCollection>(
      find.byType(ApiVideoCollection),
    );
    expect(collection.items.single.detailUrl, watch);
    collection.onOpen(collection.items.single);
    await tester.pumpAndSettle();
    expect(opened, watch);
  });

  for (final path in [
    '/unknown/123.html',
    '/anime/not-a-hash.html',
    '/vod/123/extra/',
    '/watch?v=invalid',
  ]) {
    test('unsupported history route $path is never guessed into an ID', () {
      expect(
        () => apiVideoHistoryItem(_record(home.resolve(path))),
        throwsFormatException,
      );
    });
  }

  for (final history in [false, true]) {
    testWidgets(
      '${history ? 'history list' : 'continue watching'} preserves line and episode while restoring Omo ID',
      (tester) async {
        const id = '023c74a87da31be14245e313';
        final watch = home.resolve('/anime/$id.html?line=3&episode=12');
        await VideoWatchHistory.record(
          'history-resume-fixture',
          _record(watch),
        );
        // Storage accepts standalone watch URLs. This API library cannot
        // turn a same-origin standalone ID into an Omo detail request.
        await VideoWatchHistory.record(
          'history-resume-fixture',
          _record(
            home.resolve('/watch?v=999'),
            updatedAt: DateTime.utc(2026, 10, 29),
          ),
        );
        expect(
          await VideoWatchHistory.read('history-resume-fixture'),
          hasLength(2),
        );
        ApiVideoItem? openedItem;
        Uri? openedWatch;
        Future<void> open(ApiVideoItem item, Uri resume) async {
          openedItem = item;
          openedWatch = resume;
        }

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: history
                  ? ApiVideoHistory(
                      source: 'history-resume-fixture',
                      home: home,
                      mode: ApiVideoView.grid,
                      onOpen: open,
                    )
                  : ApiVideoContinueEntry(
                      source: 'history-resume-fixture',
                      home: home,
                      onOpen: open,
                    ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (history) {
          final collection = tester.widget<ApiVideoCollection>(
            find.byType(ApiVideoCollection),
          );
          expect(collection.items.single.id, id);
          collection.onOpen(collection.items.single);
        } else {
          await tester.tap(find.byKey(const ValueKey('api-continue')));
        }
        await tester.pumpAndSettle();
        expect(openedItem?.id, id);
        expect(openedItem?.detailUrl, home.resolve('/anime/$id.html'));
        expect(openedWatch, watch);
        expect(openedWatch?.queryParameters, {'line': '3', 'episode': '12'});
        expect(tester.takeException(), isNull);
      },
    );
  }
}
