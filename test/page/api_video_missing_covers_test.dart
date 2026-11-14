import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_library_page.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';

import '../download_fixture.dart';

ApiVideoItem _item(String id, {bool cover = false, String title = ''}) =>
    ApiVideoItem(
      id: id,
      title: title.isEmpty ? '更新作品$id' : title,
      detailUrl: Uri.parse('https://video.example/anime/$id.html'),
      coverUrl: cover ? Uri.parse('https://images.example/$id.jpg') : null,
      remarks: '2026-11-08 19:48:02',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final connectivity = DownloadConnectivityFixture();
  tearDownAll(connectivity.close);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'Omo updates host fills RSS posters without opening detail or changing feed labels',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final home = Uri.parse('https://www.omofuna.com/');
      final calls = <String>[];
      final client = OmoSiteClient(
        home: home,
        request: (_, _) async => {'kind': 'signedOut'},
      );
      addTearDown(client.dispose);
      final repo = ApiVideoRepository(
        source: 'omo-missing-covers-host',
        home: home,
        catalogFn: 'list',
        detailFn: 'detail',
        playbackFn: 'play',
        capabilities: const ApiVideoCapabilities(
          presentation: 'anime',
          siteAccount: true,
          recent: false,
        ),
        pluginCall: (fn, args) async {
          calls.add(fn);
          if (fn == 'detail') {
            return {
              'data': {
                'id': args['id'],
                'title': '不同详情标题',
                'detailUrl': '${home}anime/${args['id']}.html',
                'coverUrl': 'https://images.example/${args['id']}.jpg',
              },
            };
          }
          return {
            'data': {
              'items': args['typeId'] != 'recent:feed'
                  ? []
                  : [
                      for (var i = 0; i < 30; i++)
                        {
                          'id': i.toRadixString(16).padLeft(16, '0'),
                          'title': '订阅作品$i 更新集数',
                          'remarks': '2026-11-08 19:48:02',
                          'detailUrl':
                              '${home}anime/${i.toRadixString(16).padLeft(16, '0')}.html',
                        },
                    ],
              'page': 1,
              'pageCount': 1,
            },
          };
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ApiVideoLibraryPage(
            repository: repo,
            title: 'OmoFun',
            siteClient: client,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls.where((fn) => fn == 'detail'), isEmpty);
      await tester.tap(
        find.descendant(
          of: find.byType(VideoNativeNavigation),
          matching: find.text(t.videoSource.weeklyTab),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls.where((fn) => fn == 'detail'), isEmpty);
      final feed = find.byKey(const ValueKey('api-recommendation.week-feed'));
      expect(feed, findsOneWidget);
      expect(tester.widget<NativeVideoSegmentedControl>(feed).selected, 'week');
      await tester.tap(
        find.descendant(of: feed, matching: find.text(t.videoSource.updates)),
      );
      await tester.pumpAndSettle();
      final reads = calls.where((fn) => fn == 'detail').length;
      expect(reads, greaterThan(0));
      expect(reads, lessThan(12));
      expect(find.text('订阅作品0 更新集数'), findsOneWidget);
      expect(find.text('不同详情标题'), findsNothing);
      final posters = tester
          .widgetList<ApiVideoPoster>(find.byType(ApiVideoPoster))
          .where((p) => p.item.id == '0000000000000000');
      expect(posters, isNotEmpty);
      expect(posters.first.item.coverUrl, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'missing grid posters hydrate only visible rows and retain feed labels',
    (tester) async {
      tester.view.physicalSize = const Size(390, 650);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requested = <String>[];
      final pending = <String, Completer<ApiVideoItem>>{};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ApiVideoCollection(
              items: [for (var i = 0; i < 30; i++) _item('$i', cover: i == 0)],
              mode: ApiVideoView.grid,
              storageKey: 'recent:feed',
              onOpen: (_) {},
              loadDetail: (item) {
                requested.add(item.id);
                return (pending[item.id] = Completer<ApiVideoItem>()).future;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(requested, isNotEmpty);
      expect(requested, isNot(contains('0')));
      expect(requested.length, lessThan(12));
      pending['1']!.complete(_item('1', cover: true, title: '详情中的不同标题'));
      await tester.pump();
      await tester.pump();
      final poster = tester
          .widgetList<ApiVideoPoster>(find.byType(ApiVideoPoster))
          .firstWhere((poster) => poster.item.id == '1');
      expect(poster.item.coverUrl, Uri.parse('https://images.example/1.jpg'));
      expect(find.text('更新作品1'), findsOneWidget);
      expect(find.text('详情中的不同标题'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      for (final entry in pending.entries.where((entry) => entry.key != '1')) {
        entry.value.complete(_item(entry.key));
      }
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'hidden grid defers reads; failed covers do not loop and explicit refresh retries',
    (tester) async {
      var active = false, token = 0;
      var calls = 0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, set) {
                update = set;
                return ApiVideoCollection(
                  items: [_item('1')],
                  mode: ApiVideoView.grid,
                  storageKey: 'hidden-grid',
                  onOpen: (_) {},
                  detailsActive: active,
                  imageRefreshToken: token,
                  loadDetail: (_) async {
                    calls++;
                    if (calls == 1) throw StateError('offline');
                    return _item('1', cover: true);
                  },
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(calls, 0);
      update(() => active = true);
      await tester.pump();
      await tester.pump();
      expect(calls, 1);
      update(() {});
      await tester.pump();
      expect(calls, 1);
      update(() => token++);
      await tester.pump();
      await tester.pump();
      expect(calls, 2);
      expect(
        tester
            .widget<ApiVideoPoster>(find.byType(ApiVideoPoster))
            .item
            .coverUrl,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'grid rejects another detail identity and ignores completion while hidden',
    (tester) async {
      var active = true, token = 0;
      late StateSetter update;
      final pending = <Completer<ApiVideoItem>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, set) {
                update = set;
                return ApiVideoCollection(
                  items: [_item('1')],
                  mode: ApiVideoView.grid,
                  storageKey: 'identity-grid',
                  onOpen: (_) {},
                  detailsActive: active,
                  imageRefreshToken: token,
                  loadDetail: (_) {
                    final request = Completer<ApiVideoItem>();
                    pending.add(request);
                    return request.future;
                  },
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      pending.first.complete(_item('2', cover: true));
      await tester.pump();
      expect(
        tester
            .widget<ApiVideoPoster>(find.byType(ApiVideoPoster))
            .item
            .coverUrl,
        isNull,
      );
      update(() => token++);
      await tester.pump();
      update(() => active = false);
      await tester.pump();
      pending.last.complete(_item('1', cover: true));
      await tester.pump();
      expect(
        tester
            .widget<ApiVideoPoster>(find.byType(ApiVideoPoster))
            .item
            .coverUrl,
        isNull,
      );
      update(() => active = true);
      await tester.pump();
      await tester.pump();
      expect(pending, hasLength(2));
      expect(
        tester
            .widget<ApiVideoPoster>(find.byType(ApiVideoPoster))
            .item
            .coverUrl,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
