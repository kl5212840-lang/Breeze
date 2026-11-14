import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/video/api_video_download_retry.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/video_download_retry.dart';
import 'package:zephyr/page/video/video_download_retry_host.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/page/video/video_episode_download_queue.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/src/rust/frb_generated.dart';

import '../download_fixture.dart';
import '../test_helper.dart';

const _source = 'video-api-retry-identity-fixture';
const _detail = 'https://source.test/videos/7';
const _watch = '$_detail?line=main&episode=7';
const _fresh = 'https://media.test/fresh.mp4?signature=current';
var _attempts = 0;

Map<String, dynamic> _module(String name, {bool snapshot = false}) => {
  'type': 'openVideoLibrary',
  'payload': {
    'url': 'https://source.test/',
    'catalogFnPath': '${name}Catalog',
    'detailFnPath': '${name}Detail',
    'playbackFnPath': '${name}Playback',
    'capabilities': {'itemNamespace': name, 'detailFromSnapshot': snapshot},
  },
};

const _item = {
  'id': 'movie:7',
  'title': 'Saved public work',
  'detailUrl': _detail,
  'lines': [
    {
      'id': 'main',
      'label': 'Main',
      'episodes': [
        {
          'id': '7',
          'title': 'Episode',
          'watchUrl': _watch,
          'resolveOnPlayback': true,
        },
      ],
    },
  ],
};

class _RetryApi extends RustLibApi {
  _RetryApi({required this.snapshot});

  final bool snapshot;
  final functions = <String>[];

  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({
    required String name,
  }) async => true;

  @override
  Future<String> crateApiQjsQjsCurrentBundle({
    required String runtimeName,
  }) async => jsonEncode('retry-fixture');

  @override
  Future<Uint8List> crateApiQjsQjsTaskCall({
    required String runtimeName,
    required String taskGroupKey,
    required bool isOnce,
    String? bundleJs,
    String? bundleUrl,
    required String fnPath,
    required String argsJson,
  }) async {
    if (fnPath == 'init') return Uint8List.fromList(utf8.encode('{}'));
    functions.add(fnPath);
    final args = jsonDecode(argsJson) as Map;
    if (fnPath != 'movieDetail' && fnPath != 'moviePlayback') {
      throw StateError('Unexpected plugin function: $fnPath');
    }
    expect(args['id'], _item['id']);
    if (snapshot) {
      final item = args['snapshot'] as Map;
      expect(item['id'], _item['id']);
      expect(item['title'], _item['title']);
      expect(item['detailUrl'], _detail);
      expect(item, isNot(contains('lines')));
    }
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'data': fnPath == 'movieDetail'
              ? _item
              : {
                  'item': _item,
                  'lineId': 'main',
                  'episodeId': '7',
                  'watchUrl': _watch,
                  'sources': [
                    {'quality': '720p', 'url': _fresh},
                  ],
                },
        }),
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected bridge call ${invocation.memberName}');
}

Future<void> _withColdAttempt(
  WidgetTester tester, {
  bool snapshot = false,
  String? id = 'movie:7',
  String? savedId,
  String quality = '720p',
  required Future<void> Function(OverlayState, Map<String, dynamic>, _RetryApi)
  verify,
}) async {
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(navigatorKey: navigator, home: const SizedBox.shrink()),
  );
  await tester.runAsync(() async {
    SharedPreferences.setMockInitialValues({});
    final source = '$_source-${++_attempts}';
    final api = _RetryApi(snapshot: snapshot);
    RustLib.initMock(api: api);
    await PluginRegistryService.I.upsert(
      PluginInfo(
        uuid: source,
        version: 'fixture',
        originScript: 'retry-fixture',
        insertedAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        isEnabled: true,
        isDeleted: false,
        debug: false,
        lastLoadSuccess: true,
        getInfoJson: jsonEncode({
          'modules': [_module('anime'), _module('movie', snapshot: snapshot)],
        }),
      ),
    );
    if (savedId != null) {
      await VideoDownloadedDetails.saveItem(
        source,
        ApiVideoItem.fromJson({
          ..._item,
          'id': savedId,
        }, home: Uri.parse(_detail)),
      );
    }
    final key = await VideoExportRecords.beginTransfer(
      source: source,
      video: Uri.parse(_watch),
      title: 'Saved public work',
      quality: quality,
      retryItemId: id,
    );
    try {
      final row = (await VideoExportRecords.readTaskSnapshot()).singleWhere(
        (row) => row['key'] == key,
      );
      await verify(navigator.currentState!.overlay!, row, api);
    } finally {
      await VideoExportRecords.updateTransfer(
        key,
        received: null,
        status: 'cancelled',
        terminal: true,
      );
      RustLib.dispose();
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await TestObjectBoxHelper.setUpTestObjectBox();
    await PluginRegistryService.I.init();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  testWidgets('cold retry runs the module named by the saved work', (
    tester,
  ) async {
    await _withColdAttempt(
      tester,
      verify: (overlay, row, api) async {
        final result = await VideoDownloadRetryHosts.resolve(
          overlay,
          row,
          owner: Object(),
        );
        try {
          expect(result.choices.single.url.toString(), _fresh);
          expect(api.functions, ['movieDetail', 'moviePlayback']);
        } finally {
          await result.close();
        }
      },
    );
  });

  testWidgets(
    'cold retry reuses exact public data for a snapshot-only module',
    (tester) async {
      await _withColdAttempt(
        tester,
        snapshot: true,
        id: null,
        savedId: 'movie:7',
        verify: (overlay, row, api) async {
          final result = await VideoDownloadRetryHosts.resolve(overlay, {
            ...row,
            'publicModuleNamespace': 'movie',
            'publicWorkIdentity': '${row['source']}|movie|movie:7|$_detail',
          }, owner: Object());
          try {
            expect(result.choices.single.url.toString(), _fresh);
            expect(api.functions, ['movieDetail', 'moviePlayback']);
          } finally {
            await result.close();
          }
        },
      );
    },
  );

  testWidgets('cold retry refuses to guess between same-origin modules', (
    tester,
  ) async {
    await _withColdAttempt(
      tester,
      id: null,
      verify: (overlay, row, api) async {
        await expectLater(
          VideoDownloadRetryHosts.resolve(overlay, row, owner: Object()),
          throwsA(
            isA<VideoDownloadRetryFailure>().having(
              (e) => e.reason,
              'reason',
              'missingIdentity',
            ),
          ),
        );
        expect(api.functions, isEmpty);
      },
    );
  });

  testWidgets('cold retry does not pass a different module’s saved snapshot', (
    tester,
  ) async {
    await _withColdAttempt(
      tester,
      snapshot: true,
      savedId: 'anime:7',
      verify: (overlay, row, api) async {
        await expectLater(
          VideoDownloadRetryHosts.resolve(overlay, row, owner: Object()),
          throwsA(
            isA<VideoDownloadRetryFailure>().having(
              (e) => e.reason,
              'reason',
              'sourceVisitRequired',
            ),
          ),
        );
        expect(api.functions, isEmpty);
      },
    );
  });

  testWidgets('warm retry ignores a more recent unrelated module', (
    tester,
  ) async {
    await _withColdAttempt(
      tester,
      quality: '4K',
      verify: (overlay, row, api) async {
        final connectivity = DownloadConnectivityFixture();
        final source = row['source'] as String;
        ApiVideoRepository repository(String namespace) => ApiVideoRepository(
          source: source,
          home: Uri.parse('https://source.test/'),
          catalogFn: '${namespace}Catalog',
          detailFn: '${namespace}Detail',
          playbackFn: '${namespace}Playback',
          capabilities: ApiVideoCapabilities(itemNamespace: namespace),
        );
        final movie = registerApiVideoDownloadRetry(
          repository('movie'),
          current: () => true,
        );
        final anime = registerApiVideoDownloadRetry(
          repository('anime'),
          current: () => true,
        );
        try {
          final key = row['key'] as String;
          await VideoExportRecords.updateTransfer(
            key,
            received: null,
            status: 'failed',
            terminal: true,
            failureReason: 'httpForbidden',
          );
          final failed = (await VideoExportRecords.readTaskSnapshot())
              .singleWhere((row) => row['key'] == key);
          expect(await VideoDownloadRetry.retry(failed), isTrue);
          await VideoEpisodeDownloadQueue.flush();
          final retried = (await VideoExportRecords.readTaskSnapshot())
              .singleWhere((row) => row['key'] == key);
          expect(api.functions, ['movieDetail', 'moviePlayback']);
          expect(retried['attempt'], 2);
          expect(retried['failureReason'], 'qualityUnavailable');
        } finally {
          VideoDownloadRetry.unregister(source, anime);
          VideoDownloadRetry.unregister(source, movie);
          await connectivity.close();
        }
      },
    );
  });
}
