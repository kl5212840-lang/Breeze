import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/video/api_video_browser.dart';
import 'package:zephyr/page/video/api_video_episode_download.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/video_site_browser.dart';
import 'package:zephyr/page/video/video_download_resolution.dart';

class _HeadlessPlatform extends InAppWebViewPlatform {
  _HeadlessPlatform(this.controller, this.home);
  final InAppWebViewController controller;
  final Uri home;
  int runs = 0, disposals = 0;

  @override
  PlatformHeadlessInAppWebView createPlatformHeadlessInAppWebView(
    PlatformHeadlessInAppWebViewCreationParams params,
  ) => view = _HeadlessView(params, this);

  late _HeadlessView view;
}

class _HeadlessView extends PlatformHeadlessInAppWebView {
  _HeadlessView(PlatformHeadlessInAppWebViewCreationParams params, this.host)
    : super.implementation(params);
  final _HeadlessPlatform host;

  @override
  Future<void> run() async {
    host.runs++;
    params.onWebViewCreated?.call(host.controller);
  }

  void loaded() =>
      params.onLoadStop?.call(host.controller, WebUri(host.home.toString()));

  @override
  Future<void> dispose() async {
    host.disposals++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('breeze.video.browser.background-fixture');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final home = Uri.parse('https://www.omofuna.com/');
  final detail = home.resolve('anime/667b4dd8c5ce08e51e654188.html');

  test(
    'library owner disposal preserves same-origin reads until the last batch lease releases exactly once',
    () async {
      var nativeHolds = 0, releases = 0, closed = 0, reads = 0;
      var platformViewUnmounted = false;
      final navigationRequested = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'retainBackground':
            nativeHolds++;
            return true;
          case 'releaseBackground':
            nativeHolds--;
            releases++;
            if (platformViewUnmounted && nativeHolds == 0) closed++;
            return true;
          case 'url':
            expect(closed, 0);
            return navigationRequested.isCompleted ? home.toString() : null;
          case 'load':
            expect((call.arguments as Map)['url'], home.toString());
            navigationRequested.complete();
            return null;
          case 'evaluate':
            expect(navigationRequested.isCompleted, isTrue);
            return {
              'url': home.toString(),
              'documentId': 'fixture-document',
              'cards': [],
              'links': [],
            };
          case 'evaluateAsync':
            expect(closed, 0);
            final expression = (call.arguments as Map)['source'] as String;
            expect(expression, contains("credentials:'same-origin'"));
            expect(expression, contains(detail.toString()));
            reads++;
            return {
              'kind': 'public-detail',
              'url': detail.toString(),
              'verification': false,
              'html': '<h1>Public same-origin detail</h1>',
            };
          default:
            throw TestFailure('Unexpected browser command ${call.method}');
        }
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final session = ApiVideoBrowserSession(
        home: home,
        paths: ['/anime/'],
        itemPrefix: '/anime/',
      );
      final controller = InAppWebViewController.fromPlatform(
        platform: VideoSiteBrowserController(channel, 81),
      );
      session.created(controller);
      final catalog = session.read(home);
      await navigationRequested.future;
      await session.loaded(controller, home);
      await catalog;
      final releaseFirst = await session.retainForDownloads();
      final releaseSecond = await session.retainForDownloads();
      expect(nativeHolds, 2);
      session.dispose(); // The library no longer owns this controller.
      platformViewUnmounted = true;
      expect((await session.readDetail(detail))['kind'], 'public-detail');
      await releaseFirst();
      expect(nativeHolds, 1);
      expect(closed, 0);
      expect((await session.readDetail(detail))['kind'], 'public-detail');
      await releaseSecond();
      await releaseFirst();
      await releaseSecond();
      session.dispose();
      expect(reads, 2);
      expect(releases, 2);
      expect(nativeHolds, 0);
      expect(closed, 1);
      await expectLater(session.readDetail(detail), throwsFormatException);
      await expectLater(session.retainForDownloads(), throwsStateError);
    },
  );

  for (final challenged in [false, true]) {
    test(
      'Android resolves from a leased WebView after the page closes (challenge=$challenged)',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final controller = InAppWebViewController.fromPlatform(
          platform: VideoSiteBrowserController(channel, 82),
        );
        final platform = _HeadlessPlatform(controller, home);
        final previous = InAppWebViewPlatform.instance;
        InAppWebViewPlatform.instance = platform;
        addTearDown(() => InAppWebViewPlatform.instance = previous ?? platform);
        var details = 0;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'load') {
            scheduleMicrotask(platform.view.loaded);
            return null;
          }
          return switch (call.method) {
            'url' => home.toString(),
            'evaluate'
                when (call.arguments as Map)['source'].toString().startsWith(
                  'String(',
                ) =>
              'previous-document',
            'evaluate' => {
              'url': home.toString(),
              'documentId': 'headless-document',
              'verification': challenged,
              'cards': [],
              'links': [],
            },
            'evaluateAsync' => {
              'kind': 'public-detail',
              'url': detail.toString(),
              'html': '<p>Local test document ${++details}</p>',
            },
            _ => throw TestFailure('Unexpected command ${call.method}'),
          };
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final repository = ApiVideoRepository(
          source: 'android-browser-fixture',
          home: home,
          catalogFn: 'catalog',
          detailFn: 'item',
          playbackFn: 'play',
          retainBrowserForDownloads: () async =>
              throw TestFailure('Android retained the disposed visible view'),
        );
        expect(ApiVideoEpisodeDownloads.supportsBatch(repository), isTrue);
        final lease = await repository.acquireDownloadBrowser();
        expect(platform.runs, 0);
        try {
          final reader = lease.repository.browserDetailRead!;
          if (challenged) {
            await expectLater(
              reader(detail),
              throwsA(
                isA<VideoDownloadResolutionFailure>().having(
                  (error) => error.reason,
                  'reason',
                  'verificationRequired',
                ),
              ),
            );
            expect(details, 0);
          } else {
            expect(
              (await reader(detail))['html'],
              '<p>Local test document 1</p>',
            );
            expect(
              (await reader(detail))['html'],
              '<p>Local test document 2</p>',
            );
          }
          expect(platform.runs, 1);
        } finally {
          await lease.release!();
          await lease.release!();
        }
        expect(platform.disposals, 1);
      },
    );
  }

  test(
    'repository network and browser clones retain the same background ownership contract',
    () async {
      var acquired = 0, released = 0;
      final repository = ApiVideoRepository(
        source: 'browser-owner-fixture',
        home: home,
        catalogFn: 'catalog',
        detailFn: 'item',
        playbackFn: 'play',
        pluginCall: (_, _) async => const {},
      );
      final browserBound = repository.withBrowserRead(
        (_) async => const {},
        detailReader: (_) async => const {},
        retainForDownloads: () async {
          acquired++;
          var done = false;
          return () async {
            if (!done) {
              done = true;
              released++;
            }
          };
        },
      );
      final queueRepository = browserBound.withNetwork(Future.value(null));
      final release = await queueRepository.retainBrowserForDownloads!();
      expect(acquired, 1);
      await release();
      await release();
      expect(released, 1);
    },
  );
}
