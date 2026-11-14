import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/video/api_video_browser.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';

class _Browser extends PlatformInAppWebViewController {
  _Browser()
    : super.implementation(
        const PlatformInAppWebViewControllerCreationParams(id: 'recovery'),
      );
  final loads = <Uri>[];
  Map<String, dynamic> snapshot = {};
  Map<String, dynamic>? asyncResult;
  int accountCalls = 0;
  @override
  Future<WebUri?> getUrl() async =>
      loads.isEmpty ? null : WebUri('${loads.last}');
  @override
  Future<dynamic> evaluateJavascript({
    required String source,
    ContentWorld? contentWorld,
  }) async => source == 'String(performance.timeOrigin)' ? 'old' : snapshot;
  @override
  Future<void> loadUrl({
    required URLRequest urlRequest,
    Uri? iosAllowingReadAccessTo,
    WebUri? allowingReadAccessTo,
  }) async => loads.add(Uri.parse('${urlRequest.url}'));
  @override
  Future<CallAsyncJavaScriptResult?> callAsyncJavaScript({
    required String functionBody,
    Map<String, dynamic> arguments = const {},
    ContentWorld? contentWorld,
  }) async {
    accountCalls++;
    return CallAsyncJavaScriptResult(
      value:
          asyncResult ??
          {
            'kind': 'account',
            'account': {'id': '1'},
          },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final home = Uri.parse('https://www.omofuna.com/');
  final detail = home.resolve('/anime/0123456789abcdef.html');
  test(
    'detail waits for the first document and loads without a retry',
    () async {
      final session = ApiVideoBrowserSession(
        home: home,
        paths: ['/search/'],
        itemPrefix: '/anime/',
      );
      final platform = _Browser();
      final web = InAppWebViewController.fromPlatform(platform: platform);
      session.created(web);
      final catalog = session.read(home);
      var complete = false;
      final result = session.readDetail(detail)..then((_) => complete = true);
      await Future<void>.delayed(Duration.zero);
      expect(complete, isFalse);
      expect(platform.accountCalls, 0);
      platform.snapshot = {
        'url': '$home',
        'documentId': 'fresh',
        'cards': [],
        'links': [],
      };
      platform.asyncResult = {
        'kind': 'public-detail',
        'url': '$detail',
        'html': 'ok',
      };
      await session.loaded(web, home);
      await catalog;
      expect((await result)['html'], 'ok');
      expect(platform.accountCalls, 1);
      session.dispose();
    },
  );

  test('verification and disposal end a waiting detail read', () async {
    for (final verification in [true, false]) {
      final session = ApiVideoBrowserSession(
        home: home,
        paths: ['/search/'],
        itemPrefix: '/anime/',
      );
      final platform = _Browser();
      final web = InAppWebViewController.fromPlatform(platform: platform);
      session.created(web);
      final catalog = session.read(home);
      final cancelledCatalog = expectLater(catalog, throwsFormatException);
      final detailResult = expectLater(
        session.readDetail(detail),
        throwsFormatException,
      );
      await Future<void>.delayed(Duration.zero);
      if (verification) {
        platform.snapshot = {
          'url': '$home',
          'documentId': 'challenge',
          'verification': true,
        };
        await session.loaded(web, home);
        await detailResult;
        session.dispose();
      } else {
        session.dispose();
        await detailResult;
      }
      await cancelledCatalog;
      expect(platform.accountCalls, 0);
    }
  });

  testWidgets('detail wait times out and a replacement navigation cancels it', (
    tester,
  ) async {
    for (final replace in [false, true]) {
      final session = ApiVideoBrowserSession(
        home: home,
        paths: ['/search/'],
        itemPrefix: '/anime/',
      );
      final platform = _Browser();
      final web = InAppWebViewController.fromPlatform(platform: platform);
      session.created(web);
      final catalog = session.read(home);
      final cancelledCatalog = expectLater(catalog, throwsFormatException);
      final result = expectLater(
        session.readDetail(detail),
        replace ? throwsFormatException : throwsA(isA<TimeoutException>()),
      );
      await tester.pump();
      if (replace) {
        session.cancel();
      } else {
        await tester.pump(const Duration(seconds: 16));
      }
      await result;
      session.dispose();
      await cancelledCatalog;
      expect(platform.accountCalls, 0);
    }
  });

  test(
    'an account retry recovers a failed first catalog in the same session',
    () async {
      final session = ApiVideoBrowserSession(
        home: home,
        paths: ['/search/'],
        itemPrefix: '/anime/',
      );
      final platform = _Browser();
      final web = InAppWebViewController.fromPlatform(platform: platform);
      session.created(web);
      final first = session.read(home);
      final failed = expectLater(first, throwsFormatException);
      await Future<void>.delayed(Duration.zero);
      session.cancel();
      await failed;
      final retry = session.requestOmoSite('account', const {});
      final concurrent = session.requestOmoSite('account', const {});
      await Future<void>.delayed(Duration.zero);
      try {
        expect(platform.loads, [home, home]);
      } finally {
        // Finish readiness even on the old implementation's expected failure.
        if (platform.loads.length < 2) {
          unawaited(session.read(home));
          await Future<void>.delayed(Duration.zero);
        }
        platform.snapshot = {
          'url': '$home',
          'documentId': 'fresh',
          'cards': [],
          'links': [],
        };
        await session.loaded(web, home);
        expect((await retry)['kind'], 'account');
        expect((await concurrent)['kind'], 'account');
        expect(platform.accountCalls, 2);
        session.dispose();
      }
    },
  );

  test(
    'account preparation leaves an active verification document intact',
    () async {
      final session = ApiVideoBrowserSession(
        home: home,
        paths: ['/search/'],
        itemPrefix: '/anime/',
      );
      final platform = _Browser();
      final web = InAppWebViewController.fromPlatform(platform: platform);
      session.created(web);
      final catalog = session.read(home);
      await Future<void>.delayed(Duration.zero);
      platform.snapshot = {
        'url': '$home',
        'documentId': 'challenge',
        'verification': true,
      };
      await session.loaded(web, home);
      final account = session.requestOmoSite('account', const {});
      await Future<void>.delayed(Duration.zero);
      expect(session.visible, isTrue);
      expect(platform.loads, [home]);
      platform.snapshot = {
        'url': '$home',
        'documentId': 'verified',
        'cards': [],
        'links': [],
      };
      await session.loaded(web, home);
      await catalog;
      expect((await account)['kind'], 'account');
      expect(platform.loads, [home]);
      session.dispose();
    },
  );

  test(
    'a newer catalog cancels account recovery without replacing its page',
    () async {
      final session = ApiVideoBrowserSession(
        home: home,
        paths: ['/search/'],
        itemPrefix: '/anime/',
      );
      final platform = _Browser();
      final web = InAppWebViewController.fromPlatform(platform: platform);
      session.created(web);
      final account = session.requestOmoSite('account', const {});
      final cancelled = expectLater(account, throwsA(isA<Exception>()));
      await Future<void>.delayed(Duration.zero);
      final next = home.resolve('/search/example.html');
      final catalog = session.read(next);
      await Future<void>.delayed(Duration.zero);
      platform.snapshot = {
        'url': '$home',
        'documentId': 'stale',
        'cards': [],
        'links': [],
      };
      await session.loaded(web, home);
      platform.snapshot = {
        'url': '$next',
        'documentId': 'new',
        'cards': [],
        'links': [],
      };
      await session.loaded(web, next);
      await catalog;
      await cancelled;
      expect(platform.loads, [home, next]);
      expect(platform.accountCalls, 0);
      session.dispose();
    },
  );
  testWidgets('a recovery timeout preserves the user verification page', (
    tester,
  ) async {
    final session = ApiVideoBrowserSession(
      home: home,
      paths: ['/search/'],
      itemPrefix: '/anime/',
    );
    final platform = _Browser();
    final web = InAppWebViewController.fromPlatform(platform: platform);
    session.created(web);
    final account = session.requestOmoSite('account', const {});
    final timedOut = expectLater(
      account,
      throwsA(
        isA<OmoSiteException>().having((e) => e.kind, 'kind', 'verification'),
      ),
    );
    await tester.pump();
    platform.snapshot = {
      'url': '$home',
      'documentId': 'challenge',
      'verification': true,
    };
    await session.loaded(web, home);
    await tester.pump(const Duration(seconds: 35));
    await timedOut;
    expect(session.visible, isTrue);
    expect(platform.loads, [home]);
    platform.snapshot = {
      'url': '$home',
      'documentId': 'verified',
      'cards': [],
      'links': [],
    };
    await session.loaded(web, home);
    expect(
      (await session.requestOmoSite('account', const {}))['kind'],
      'account',
    );
    expect(platform.loads, [home]);
    session.dispose();
  });
}
