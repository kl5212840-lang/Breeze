import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_library_page.dart';
import 'package:zephyr/page/video/video_thumbnail.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/page/video/api_video_detail_page.dart';
import 'package:zephyr/page/video/api_video_favorites.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';

const _source = 'snapshot-module-fixture';
const _hid = 'Same-Hid_1';
Uri _home(String module) => Uri.parse('https://$module.example/');
ApiVideoItem _item(String module) => ApiVideoItem(
  id: '$module:$_hid',
  title: '$module saved title',
  description: 'Saved public description',
  detailUrl: _home(module).resolve('videos/$_hid'),
);

Map<String, dynamic> _detail(Map<String, dynamic> snapshot) => {
  ...snapshot,
  'lines': [
    {
      'id': 'default',
      'label': 'Default',
      'episodes': [
        {
          'id': _hid,
          'title': 'Play',
          'resolveOnPlayback': true,
          'watchUrl': '${snapshot['detailUrl']}?line=default&episode=$_hid',
        },
      ],
    },
  ],
};

ApiVideoRepository _repository(String module, ApiVideoPluginCall call) =>
    ApiVideoRepository(
      source: _source,
      home: _home(module),
      catalogFn: 'catalog',
      detailFn: 'detail',
      playbackFn: 'playback',
      capabilities: ApiVideoCapabilities(
        detailFromSnapshot: true,
        itemNamespace: module,
        year: false,
        recent: false,
        filtersOnSearch: false,
      ),
      pluginCall: call,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'wide module catalog $style $brightness keeps all cover content and hides unsupported filters',
        (tester) async {
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final preference = ValueNotifier(style);
          addTearDown(preference.dispose);
          final channels = <MethodChannel>[];
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
            call,
          ) async {
            if (call.method == 'create') {
              final args = call.arguments as Map;
              final channel = MethodChannel(
                '${args['viewType']}.${args['id']}',
              );
              channels.add(channel);
              messenger.setMockMethodCallHandler(channel, (_) async => null);
            }
            return null;
          });
          addTearDown(() {
            messenger.setMockMethodCallHandler(
              SystemChannels.platform_views,
              null,
            );
            for (final channel in channels) {
              messenger.setMockMethodCallHandler(channel, null);
            }
          });
          final repo = ApiVideoRepository(
            source: _source,
            home: _home('animate'),
            catalogFn: 'catalog',
            detailFn: 'detail',
            playbackFn: 'playback',
            capabilities: const ApiVideoCapabilities(
              search: 'none',
              year: false,
              recent: false,
              detailFromSnapshot: true,
              itemNamespace: 'animate',
              posterAspectRatio: 4 / 3,
            ),
            pluginCall: (path, args) async => {
              'data': {
                'page': 1,
                'pageCount': 1,
                'total': 2,
                'categories': [],
                'items': [
                  for (final id in [1, 2])
                    {
                      ..._item('animate').toLibraryJson(),
                      'id': 'animate:$id',
                      'detailUrl': '${_home('animate')}videos/$id',
                      'containCover': true,
                    },
                ],
              },
            },
          );
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: preference,
              child: MaterialApp(
                theme: ThemeData(brightness: brightness),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
                home: ApiVideoLibraryPage(
                  repository: repo,
                  title: 'Animation library',
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final collection = tester.widget<ApiVideoCollection>(
            find.byType(ApiVideoCollection).first,
          );
          expect(collection.posterAspectRatio, 4 / 3);
          expect(collection.items, hasLength(2));
          expect(
            find.byKey(const ValueKey('api-library.filters')),
            findsNothing,
          );
          final poster = find.byType(ApiVideoPoster).first;
          final size = tester.getSize(poster);
          expect(size.width / size.height, closeTo(4 / 3, .01));
          expect(
            tester
                .widget<VideoThumbnail>(
                  find.descendant(
                    of: poster,
                    matching: find.byType(VideoThumbnail),
                  ),
                )
                .fit,
            BoxFit.contain,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }

  testWidgets(
    'keyword-only movie search does not expose unsupported year or completion filters',
    (tester) async {
      final repo = _repository(
        'movie',
        (path, args) async => {
          'data': {
            'page': 1,
            'pageCount': 1,
            'total': 1,
            'categories': [],
            'items': [_item('movie').toLibraryJson()],
          },
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ApiVideoLibraryPage(
            repository: repo,
            title: 'Movie library',
            initialQuery: '720p',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('api-library.filters')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  test(
    'saved public snapshot reopens in a new repository and resolves fresh media',
    () async {
      final store = VideoLibraryStore(
        deviceId: 'one',
        storageKey: 'module-reopen',
      );
      await store.setFavorite(_source, _item('movie'), true);
      final saved =
          jsonDecode(jsonEncode((await store.read()).toJson()))
              as Map<String, dynamic>;
      final restored = VideoLibrarySnapshot.fromJson(
        saved,
      ).itemsFor(_source).single.item;
      store.dispose();
      final requests = <({String path, Map<String, dynamic> args})>[];
      final repo = _repository('movie', (path, args) async {
        requests.add((path: path, args: args));
        expect(args['home'], _home('movie').toString());
        final snapshot = args['snapshot'] as Map<String, dynamic>;
        expect(snapshot['title'], restored.title);
        expect(snapshot.containsKey('lines'), isFalse);
        final item = _detail(snapshot);
        return {
          'data': path == 'playback'
              ? {
                  'item': item,
                  'lineId': 'default',
                  'episodeId': _hid,
                  'watchUrl':
                      '${snapshot['detailUrl']}?line=default&episode=$_hid',
                  'sources': [
                    {
                      'url': 'https://media.example/fresh.m3u8',
                      'quality': 'HLS',
                    },
                  ],
                }
              : item,
        };
      });
      final detail = await repo.item(restored.id, snapshot: restored);
      expect(detail.description, restored.description);
      expect(detail.lines.single.episodes.single.url, isNull);
      final playback = await repo.session(
        detail.id,
        snapshot: detail,
        lineId: 'default',
        episodeId: _hid,
      );
      expect(
        playback.session.sources.single.url.toString(),
        'https://media.example/fresh.m3u8',
      );
      expect(videoPublicPage(playback.session.watchUrl), restored.detailUrl);
      expect(requests.map((r) => r.path), ['detail', 'playback']);
      expect(jsonEncode(saved), isNot(contains('fresh.m3u8')));
    },
  );

  test(
    'a wrong module, identity or missing snapshot fails before plugin I/O',
    () async {
      var calls = 0;
      final repo = _repository('movie', (_, _) async {
        calls++;
        return {};
      });
      for (final seed in [
        null,
        _item('animate'),
        ApiVideoItem(
          id: 'movie:$_hid',
          title: 'wrong origin',
          detailUrl: _home('animate').resolve('videos/$_hid'),
        ),
      ]) {
        expect(
          () => repo.item('movie:$_hid', snapshot: seed),
          throwsFormatException,
        );
        await expectLater(
          repo.session('movie:$_hid', snapshot: seed),
          throwsFormatException,
        );
      }
      expect(calls, 0);
    },
  );

  testWidgets(
    'favorites inside one module exclude the other module without deleting it',
    (tester) async {
      final store = VideoLibraryStore(
        deviceId: 'one',
        storageKey: 'module-favorites',
      );
      addTearDown(store.dispose);
      for (final module in ['movie', 'animate']) {
        await store.setFavorite(_source, _item(module), true);
      }
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ApiVideoFavorites(
              source: _source,
              store: store,
              mode: ApiVideoView.grid,
              repository: _repository(
                'animate',
                (_, _) async => throw StateError('No source request expected'),
              ),
              onOpen: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rows = tester
          .widget<ApiVideoCollection>(find.byType(ApiVideoCollection))
          .items;
      expect(rows.map((i) => i.id), ['animate:$_hid']);
      expect((await store.read()).itemsFor(_source), hasLength(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'detail host forwards a saved snapshot to playback while keeping metadata readable',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pending = Completer<Map<String, dynamic>>();
      final calls = <String>[];
      final repo = _repository('movie', (path, args) async {
        calls.add(path);
        expect((args['snapshot'] as Map)['id'], 'movie:$_hid');
        if (path == 'detail') {
          return {'data': _detail(args['snapshot'] as Map<String, dynamic>)};
        }
        return pending.future;
      });
      await tester.pumpWidget(
        MaterialApp(
          home: ApiVideoDetailPage(
            repository: repo,
            initialItem: _item('movie'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(calls, ['detail', 'playback']);
      await tester.scrollUntilVisible(
        find.text('Saved public description'),
        200,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(find.text('Saved public description'), findsOneWidget);
      pending.completeError(StateError('fixture playback unavailable'));
      await tester.pumpAndSettle();
      expect(find.text('Saved public description'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
