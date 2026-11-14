import 'package:zephyr/page/video/omofun_native_history_scope.dart';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/page/video/api_video_detail_page.dart';
import 'package:zephyr/page/video/api_video_library_page.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/native_video_page.dart';
import 'package:zephyr/page/video/omofun_account_page.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';
import 'package:zephyr/page/video/source_profile_video_preview.dart';
import '../download_fixture.dart';
import '../test_helper.dart';

// Diagnostic stage labels contain no source/account/media data.
// ignore: avoid_print
void _stage(String value) => print('OMO_HOST_STAGE:$value');

class _Player extends VideoPlayerPlatform {
  final events = StreamController<VideoEvent>.broadcast();
  @override
  Future<void> init() async {}
  @override
  Future<void> setMixWithOthers(bool mix) async {}
  @override
  Future<int?> create(DataSource source) async {
    Timer.run(
      () => events.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(minutes: 2),
          size: const Size(1920, 1080),
        ),
      ),
    );
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int id) => events.stream;
  @override
  Widget buildView(int id) => const ColoredBox(color: Colors.black);
  @override
  Future<void> dispose(int id) async {
    _stage('player.dispose.close.begin');
    await events.close();
    _stage('player.dispose.close.done');
  }

  @override
  Future<void> setLooping(int id, bool v) async {}
  @override
  Future<void> setVolume(int id, double v) async {}
  @override
  Future<void> setPlaybackSpeed(int id, double v) async {}
  @override
  Future<void> play(int id) async {}
  @override
  Future<void> pause(int id) async {}
  @override
  Future<void> seekTo(int id, Duration v) async {}
  @override
  Future<Duration> getPosition(int id) async => Duration.zero;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final connectivity = DownloadConnectivityFixture();
  tearDownAll(connectivity.close);
  setUpAll(() async {
    _stage('setup.begin');
    await TestObjectBoxHelper.setUpTestObjectBox();
    _stage('setup.done');
  });
  tearDownAll(() async {
    _stage('teardown.begin');
    await TestObjectBoxHelper.tearDownTestObjectBox();
    _stage('teardown.done');
  });
  testWidgets(
    'live Omo account history opens its existing repository at the exact line and episode and returns to filtered records',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'breeze.video.defaults.controlsStyle': 'breeze',
      });
      final home = Uri.parse('https://www.omofuna.com/');
      final detail = home.resolve('/anime/1234567890abcdef.html');
      final plays = <Map<String, dynamic>>[];
      final item = <String, dynamic>{
        'id': '1234567890abcdef',
        'title': 'Record work',
        'detailUrl': '$detail',
        'vodId': '42',
        'description': 'Description',
        'lines': [
          for (final line in ['1', '2'])
            {
              'id': line,
              'label': line,
              'episodes': [
                {
                  'id': line == '1' ? '1' : '7',
                  'title': line == '1' ? '第1集' : '第7集',
                  'resolveOnPlayback': true,
                  'watchUrl':
                      '$detail?line=$line&episode=${line == '1' ? '1' : '7'}',
                },
              ],
            },
        ],
      };
      final client = OmoSiteClient(
        home: home,
        request: (op, _) async {
          if (op == 'account')
            return {
              'kind': 'account',
              'account': {'id': '1', 'name': 'Fixture'},
            };
          if (op == 'favorites') return {'kind': 'favorites', 'items': [], 'rawCount': 0};
          if (op == 'history')
            return {
              'kind': 'history',
              'items': [
                {
                  'recordId': '9',
                  'title': 'Record work',
                  'url': '${home}anime/1234567890abcdef/play/2/7.html',
                  'episodeLabel': '第7集',
                  'watchedAt': '2026-11-06',
                },
              ],
              'rawCount': 1,
              'hasMore': false,
            };
          if (op == 'favoriteState')
            return {'kind': 'favoriteState', 'favorite': false};
          throw StateError('Unexpected $op');
        },
      );
      addTearDown(() { _stage('client.dispose'); client.dispose(); });
      final repo = ApiVideoRepository(
        source: 'history-native-flow',
        home: home,
        catalogFn: 'list',
        detailFn: 'item',
        playbackFn: 'play',
        capabilities: const ApiVideoCapabilities(
          presentation: 'anime',
          siteAccount: true,
        ),
        pluginCall: (path, args) async {
          if (path == 'item') return {'data': item};
          if (path == 'list')
            return {
              'data': {
                'items': [item],
                'hasMore': false,
              },
            };
          plays.add(Map<String, dynamic>.from(args));
          return {
            'data': {
              'item': item,
              'lineId': args['lineId'],
              'episodeId': args['episodeId'],
              'watchUrl':
                  '$detail?line=${args['lineId']}&episode=${args['episodeId']}',
              'sources': [
                {'url': 'https://fixture.test/movie.mp4', 'quality': 'A'},
              ],
            },
          };
        },
      );
      final old = VideoPlayerPlatform.instance;
      VideoPlayerPlatform.instance = _Player();
      final settings = GlobalSettingCubit();
      addTearDown(() async {
        _stage('settings.close.begin');
        await settings.close();
        _stage('settings.close.done');
      });
      try {
        _stage('mount.begin');
        await tester.pumpWidget(
          BlocProvider.value(
            value: settings,
            child: MaterialApp(
              home: ApiVideoLibraryPage(
                repository: repo,
                title: 'Omo',
                siteClient: client,
                initialSection: 'me',
              ),
            ),
          ),
        );
        await tester.pump();
        _stage('mount.done');
        expect(find.byType(SourceProfileLocalVideoPreviews), findsOneWidget);
        _stage('local.read.begin');
        // The managed-file read starts in the widget's fake zone. Alternate
        // frames and real I/O so its queued continuations can both progress;
        // awaiting a second queued read inside runAsync would block those frames.
        final readElapsed = Stopwatch()..start();
        SourceProfileVideoPreview localDownloads() =>
            tester.widget<SourceProfileVideoPreview>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is SourceProfileVideoPreview &&
                    widget.identity.startsWith('local-downloads.'),
              ),
            );
        while (localDownloads().loading &&
            readElapsed.elapsed < const Duration(seconds: 5)) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(
          localDownloads().loading,
          isFalse,
          reason: 'Actual local index must finish within the host I/O budget',
        );
        expect(localDownloads().failed, isFalse);
        _stage('local.read.done');
        await tester.pumpAndSettle();
        // My now previews site following. This regression still exercises the
        // retained history route against the live source's native callback.
        final myContext = tester.element(find.byType(OmoAccountPage));
        final scope = OmoNativeHistoryScope.maybeOf(myContext)!;
        _stage('history.open.begin');
        unawaited(Navigator.of(myContext).push<void>(MaterialPageRoute(builder: (_) =>
          OmoPrivateIndexPage(client: client, source: repo.source, kind: 'history',
            onOpenRecord: scope.openEntry))));
        await tester.pumpAndSettle();
        _stage('history.visible');
        expect(find.byType(OmoPrivateIndexPage), findsOneWidget);
        final search = find
            .descendant(
              of: find.byType(OmoPrivateIndexPage),
              matching: find.byType(TextField),
            )
            .first;
        _stage('history.search.begin');
        await tester.enterText(search, 'Record');
        await tester.pumpAndSettle();
        _stage('history.search.done');
        await tester.tap(find.text('Record work'));
        _stage('play.open.pump.begin');
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        _stage('play.open.pump.done');
        expect(find.byType(ApiVideoDetailPage), findsOneWidget);
        expect(find.byType(NativeVideoPage), findsOneWidget);
        expect(plays.single['lineId'], '2');
        expect(plays.single['episodeId'], '7');
        expect(find.byType(OmoSiteWebPage), findsNothing);
        _stage('pop.begin');
        await tester.binding.handlePopRoute();
        _stage('pop.returned');
        await tester.pumpAndSettle();
        expect(find.byType(OmoPrivateIndexPage), findsOneWidget);
        expect(tester.widget<TextField>(search).controller!.text, 'Record');
        expect(find.text('Record work'), findsOneWidget);
        expect(tester.takeException(), isNull);
        _stage('assertions.done');
      } finally {
        _stage('unmount.begin');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        VideoPlayerPlatform.instance = old;
        _stage('unmount.done');
      }
    },
  );
}
