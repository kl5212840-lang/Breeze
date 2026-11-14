import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/video/api_video_detail_page.dart';
import 'package:zephyr/page/video/api_video_library_page.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_download_retry.dart';
import 'package:zephyr/page/video/video_download_retry_action.dart';
import 'package:zephyr/page/video/video_download_source_navigation.dart';
import 'package:zephyr/page/video/video_source_action.dart';
import '../test_helper.dart';

Map<String, dynamic> _row({
  String quality = '',
  String url = 'https://fixture.test/voddetail/42.html',
  String reason = 'missingIdentity',
}) => {
  'source': 'ccc2fe17-c0a8-4fd8-a596-835772686404',
  'url': url,
  'key': 'task',
  'title': 'Actual work',
  'quality': quality,
  'status': 'cancelled',
  'failureReason': reason,
  'at': 1234,
};
Map<String, dynamic> _module(String namespace) => {
  'type': 'openVideoLibrary',
  'payload': {
    'url': 'https://fixture.test/',
    'capabilities': {'itemNamespace': namespace},
  },
};

void main() {
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    await PluginRegistryService.I.init();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  test(
    'unresolved intent opens its real work without inventing an episode or quality',
    () {
      final row = _row();
      expect(VideoDownloadRetry.canRetry(row), isFalse);
      expect(VideoDownloadRetry.needsSource(row), isTrue);
      final target = videoDownloadWorkRow(row)!;
      expect(target.item.id, '42');
      expect(target.item.detailUrl.toString(), row['url']);
      expect(target.watchUrl, isNull);
      expect(target.localResourceId, isNull);
    },
  );
  test(
    'exact episode resume is retained separately from the public work page',
    () {
      final target = videoDownloadWorkRow(
        _row(url: 'https://fixture.test/voddetail/42.html?line=A&episode=2'),
      )!;
      expect(
        target.item.detailUrl.toString(),
        'https://fixture.test/voddetail/42.html',
      );
      expect(target.watchUrl?.queryParameters, {'line': 'A', 'episode': '2'});
    },
  );
  testWidgets(
    'downloads route exact episodes and work-only opens separately from recovery',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      const source = 'download-route-fixture';
      await tester.runAsync(() async {
        await PluginRegistryService.I.upsert(
          PluginInfo(
            uuid: source,
            version: 'fixture',
            originScript: '',
            insertedAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            isEnabled: true,
            isDeleted: false,
            debug: false,
            lastLoadSuccess: true,
            getInfoJson: jsonEncode({
              'function': [
                {
                  'action': {
                    'type': 'openVideoLibrary',
                    'payload': {
                      'protocol': 2,
                      'url': 'https://fixture.test/',
                      'catalogFnPath': 'video.catalog',
                      'detailFnPath': 'video.detail',
                      'playbackFnPath': 'video.playback',
                    },
                  },
                },
              ],
            }),
          ),
        );
      });
      final row = {
        ..._row(url: 'https://fixture.test/voddetail/42.html?line=B&episode=2'),
        'source': source,
      };
      late BuildContext caller;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                caller = context;
                return const Text('Download list with retained state');
              },
            ),
          ),
        ),
      );
      for (final (includeEpisode, recovery) in [
        (true, false),
        (false, false),
        (true, true),
      ]) {
        final result = openVideoDownloadWork(
          caller,
          row,
          includeEpisode: includeEpisode,
          forDownloadRecovery: recovery,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        final library = find.byType(ApiVideoLibraryPage);
        final detail = tester.widget<ApiVideoDetailPage>(
          find.byType(ApiVideoDetailPage),
        );
        expect(detail.requireExactResume, includeEpisode);
        expect(
          detail.resume?.queryParameters['episode'],
          includeEpisode ? '2' : null,
        );
        expect(
          detail.resume?.queryParameters['line'],
          includeEpisode ? 'B' : null,
        );
        expect(detail.forDownloadRecovery, recovery);
        Navigator.of(tester.element(library)).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await result;
        expect(find.text('Download list with retained state'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
  test('same-origin movie and anime identities select their actual module', () {
    final info = {
      'modules': [_module('bika:anime'), _module('bika:movie')],
    };
    for (final module in ['anime', 'movie']) {
      final row = {
        ..._row(url: 'https://fixture.test/videos/7'),
        'retryItemId': 'bika:$module:7',
      };
      final target = videoDownloadWorkRow(row, sourceInfo: info)!;
      expect(target.item.id, 'bika:$module:7');
      final action = videoSourceAction(
        info,
        home: target.item.detailUrl,
        itemId: target.item.id,
      )!;
      expect(
        ((action['payload'] as Map)['capabilities'] as Map)['itemNamespace'],
        'bika:$module',
      );
    }
    expect(
      videoDownloadWorkRow(
        _row(url: 'https://fixture.test/videos/7'),
        sourceInfo: info,
      ),
      isNull,
      reason: 'an ambiguous legacy module must not open the first module',
    );
  });
  test(
    'single module can qualify a legacy public videos identity, without changing stored rows',
    () {
      final row = _row(url: 'https://fixture.test/videos/7');
      final target = videoDownloadWorkRow(
        row,
        sourceInfo: _module('bika:movie'),
      )!;
      expect(target.item.id, 'bika:movie:7');
      expect(row.containsKey('retryItemId'), isFalse);
    },
  );
  test('saved public identity disambiguates a shared-origin work', () {
    final modules = {
      'modules': [_module('bika:anime'), _module('bika:movie')],
    };
    final row = {
      ..._row(url: 'https://fixture.test/videos/7?line=main&episode=2'),
      'source': 'fixture',
      'publicModuleNamespace': 'bika:movie',
      'publicWorkIdentity':
          'fixture|bika:movie|bika:movie:7|https://fixture.test/videos/7',
      'publicWorkTitle': 'Whole work',
    };
    final target = videoDownloadWorkRow(row, sourceInfo: modules)!;
    expect(target.item.id, 'bika:movie:7');
    expect(target.item.title, 'Whole work');
    expect(target.watchUrl?.queryParameters['episode'], '2');
    expect(
      videoDownloadWorkRow(
        row,
        sourceInfo: modules,
        includeEpisode: false,
      )?.watchUrl,
      isNull,
    );
    expect(
      videoDownloadWorkRow({
        ...row,
        'url': 'https://fixture.test/videos/8',
      }, sourceInfo: modules),
      isNull,
      reason: 'A binding to another public page cannot select the module.',
    );
  });
  test('invalid module URLs cannot block an exact source target', () {
    final invalid = [
      for (final url in ['relative-path', 'ftp://fixture.test/'])
        {
          'type': 'openVideoLibrary',
          'payload': {'url': url},
        },
    ];
    final modules = [...invalid, _module('bika:movie')];
    final row = _row(url: 'https://fixture.test/videos/7');
    expect(videoDownloadWorkRow(row, sourceInfo: invalid), isNull);
    expect(
      videoDownloadWorkRow(row, sourceInfo: modules)?.item.id,
      'bika:movie:7',
    );
    expect(videoDownloadWorkRow(_row(), sourceInfo: modules)?.item.id, '42');
  });
  test(
    'missing and media-only addresses never become a source/home/web shortcut',
    () {
      for (final url in [
        '',
        'https://fixture.test/',
        'https://cdn.test/video.mp4',
        'https://cdn.test/media.m3u8',
        'http://fixture.test/watch?v=1',
        'https://fixture.test/watch',
      ]) {
        expect(videoDownloadWorkRow(_row(url: url)), isNull);
      }
    },
  );
  for (final iconOnly in [true, false]) {
    testWidgets(
      'failed task exposes work instead of fake retry iconOnly=$iconOnly',
      (tester) async {
        Future<void> mount(Map<String, dynamic> row) => tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VideoDownloadRetryAction(row: row, iconOnly: iconOnly),
            ),
          ),
        );
        await mount(_row());
        expect(
          find.byKey(const ValueKey('download-source.task')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('download-retry.task')), findsNothing);
        expect(
          iconOnly
              ? find.byTooltip(t.download.openSourceVideo)
              : find.text(t.download.openSourceVideo),
          findsOneWidget,
        );
        await mount(_row(url: ''));
        expect(find.byType(IconButton), findsNothing);
        expect(find.byType(TextButton), findsNothing);
        await mount({
          ..._row(
            quality: '720p',
            url: 'https://fixture.test/watch?v=1',
            reason: 'network',
          ),
          'status': 'failed',
        });
        expect(
          find.byKey(const ValueKey('download-retry.task')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('download-source.task')),
          findsNothing,
        );
        await mount({
          ..._row(
            quality: '720p',
            url: 'https://fixture.test/watch?v=1',
            reason: 'qualityUnavailable',
          ),
          'status': 'failed',
        });
        expect(
          find.byKey(const ValueKey('download-source.task')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.android,
      }),
    );
  }
}
