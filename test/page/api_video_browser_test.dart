import 'dart:async';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/video/api_video_browser.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';

class _Browser extends Fake implements InAppWebViewController {
  _Browser({this.blank = false});
  final bool blank;
  bool probedBlank = false;
  String document = 'old';
  String documentState = 'loading';
  Map<String, dynamic> snapshot = {};
  final loads = <Uri>[];
  @override
  Future<dynamic> evaluateJavascript({
    required String source,
    ContentWorld? contentWorld,
  }) async {
    if (source == 'document.readyState') return documentState;
    if (source == 'String(performance.timeOrigin)' && blank) {
      probedBlank = true;
      return Completer<dynamic>().future;
    }
    return source == 'String(performance.timeOrigin)' ? document : snapshot;
  }

  @override
  Future<WebUri?> getUrl() async =>
      blank ? null : WebUri('https://www.omofuna.com/');
  @override
  Future<void> loadUrl({
    required URLRequest urlRequest,
    Uri? iosAllowingReadAccessTo,
    WebUri? allowingReadAccessTo,
  }) async {
    loads.add(Uri.parse(urlRequest.url.toString()));
  }
}

void main() {
  final home = Uri.parse('https://www.omofuna.com/');
  final query = home.resolve('search/-------------.html?wd=demo');
  const capabilities = ApiVideoCapabilities(browserCatalog: true);
  test(
    'catalog reads parsed HTML without waiting for slow subresources',
    () async {
      final session = ApiVideoBrowserSession(
        home: home,
        paths: ['/search/'],
        itemPrefix: '/anime/',
      );
      final web = _Browser();
      session.created(web);
      final pending = session.read(home);
      await Future<void>.delayed(Duration.zero);
      web.documentState = 'interactive';
      web.snapshot = {
        'url': '$home',
        'documentId': 'new',
        'cards': [
          {'title': 'ready'},
        ],
        'links': [],
      };
      // WebKit has committed/parsed the main HTML, but never fires load-stop
      // while a slow advertisement/subframe is still loading.
      await session.committed(web, home);
      expect((await pending)['cards'], hasLength(1));
      session.dispose();
    },
  );

  testWidgets('cancel retires the parsed-document probe before a later query', (
    tester,
  ) async {
    final session = ApiVideoBrowserSession(
      home: home,
      paths: ['/search/'],
      itemPrefix: '/anime/',
    );
    final web = _Browser();
    session.created(web);
    final first = session.read(home);
    final cancelled = expectLater(first, throwsFormatException);
    await tester.pump();
    await session.committed(web, home);
    session.cancel();
    await cancelled;
    web.documentState = 'interactive';
    web.snapshot = {
      'url': '$home',
      'documentId': 'stale',
      'cards': [],
      'links': [],
    };
    final next = session.read(query);
    await tester.pump(const Duration(milliseconds: 200));
    var complete = false;
    next.then((_) => complete = true);
    expect(complete, isFalse);
    web.snapshot = {
      'url': '$query',
      'documentId': 'query',
      'cards': [],
      'links': [],
    };
    await session.committed(web, query);
    expect((await next)['documentId'], 'query');
    session.dispose();
  });
  test(
    'fresh iOS browser navigates before probing a nonexistent document',
    () async {
      final session = ApiVideoBrowserSession(
        home: home,
        paths: ['/search/'],
        itemPrefix: '/anime/',
      );
      final web = _Browser(blank: true);
      session.created(web);
      final pending = session.read(query);
      await Future<void>.delayed(Duration.zero);
      expect(web.loads, [query]);
      expect(web.probedBlank, false);
      web.snapshot = {
        'url': '$query',
        'documentId': 'first',
        'cards': [],
        'links': [],
      };
      await session.loaded(web, query);
      expect((await pending)['documentId'], 'first');
      session.dispose();
    },
  );
  test(
    'catalog uses one public snapshot and rejects repeated browser requests',
    () async {
      final calls = <Map<String, dynamic>>[];
      final snapshot = {
        'url': query.toString(),
        'cards': [],
        'links': [],
        'empty': true,
      };
      final repo = ApiVideoRepository(
        source: 'omo',
        home: home,
        catalogFn: 'catalog',
        detailFn: 'detail',
        playbackFn: 'play',
        capabilities: capabilities,
        browserRead: (url) async {
          expect(url, query);
          return snapshot;
        },
        pluginCall: (_, args) async {
          calls.add(args);
          return {
            'data': args.containsKey('browserSnapshot')
                ? {
                    'items': [],
                    'categories': [],
                    'page': 1,
                    'pageCount': 1,
                    'totalKnown': false,
                  }
                : {
                    'browserRequest': {'url': query.toString()},
                  },
          };
        },
      );
      expect((await repo.page(query: 'demo')).items, isEmpty);
      expect(calls.length, 2);
      expect(calls.last['browserSnapshot'], same(snapshot));
      expect(calls.last['clientProtocol'], 2);
      final invalid = ApiVideoRepository(
        source: 'omo',
        home: home,
        catalogFn: 'catalog',
        detailFn: 'detail',
        playbackFn: 'play',
        capabilities: capabilities,
        browserRead: (_) async => snapshot,
        pluginCall: (_, _) async => {
          'data': {
            'browserRequest': {'url': query.toString()},
          },
        },
      );
      await expectLater(invalid.page(), throwsFormatException);
    },
  );
  test('foreign catalog origin never reaches the browser', () async {
    var reads = 0;
    final repo = ApiVideoRepository(
      source: 'omo',
      home: home,
      catalogFn: 'catalog',
      detailFn: 'detail',
      playbackFn: 'play',
      capabilities: capabilities,
      browserRead: (_) async {
        reads++;
        return {};
      },
      pluginCall: (_, _) async => {
        'data': {
          'browserRequest': {'url': 'https://other.example/search/'},
        },
      },
    );
    await expectLater(repo.page(), throwsFormatException);
    expect(reads, 0);
  });
  test(
    'verification keeps the pending request and same browser until normal reload',
    () async {
      final session = ApiVideoBrowserSession(
        home: home,
        paths: ['/search/'],
        itemPrefix: '/anime/',
      );
      final web = _Browser();
      session.created(web);
      var complete = false;
      final result = session.read(query)..then((_) => complete = true);
      await Future<void>.delayed(Duration.zero);
      web.snapshot = {
        'url': query.toString(),
        'documentId': 'challenge',
        'verification': true,
      };
      await session.loaded(web, query);
      expect(session.visible, isTrue);
      expect(complete, isFalse);
      expect(web.loads, [query]);
      web.snapshot = {
        'url': query.toString(),
        'documentId': 'verified',
        'cards': [],
        'links': [],
        'empty': true,
      };
      await session.loaded(web, query);
      expect((await result)['empty'], isTrue);
      expect(session.visible, isFalse);
      session.dispose();
    },
  );
  test(
    'same-URL stale document and cancelled old request cannot replace a newer result',
    () async {
      final session = ApiVideoBrowserSession(
        home: home,
        paths: ['/search/'],
        itemPrefix: '/anime/',
      );
      final web = _Browser();
      session.created(web);
      final first = session.read(query);
      final cancelled = expectLater(first, throwsFormatException);
      await Future<void>.delayed(Duration.zero);
      final second = session.read(query);
      await Future<void>.delayed(Duration.zero);
      var complete = false;
      second.then((_) => complete = true);
      web.snapshot = {
        'url': query.toString(),
        'documentId': 'old',
        'cards': [],
        'links': [],
      };
      await session.loaded(web, query);
      expect(complete, isFalse);
      web.snapshot = {
        'url': query.toString(),
        'documentId': 'new',
        'cards': [],
        'links': [],
      };
      await session.loaded(web, query);
      expect((await second)['documentId'], 'new');
      await cancelled;
      session.dispose();
    },
  );
}
