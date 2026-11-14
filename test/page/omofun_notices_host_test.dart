import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/omo_network.dart';
import 'package:zephyr/page/video/omofun_account_page.dart';
import 'package:zephyr/page/video/omofun_notice_page.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';
import 'package:zephyr/page/video/video_network_scope.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

final _home = Uri.parse('https://www.omofuna.com/');
final _articleUrl = _home.resolve('/artdetail-7beb9acef0e760dcbd60abb3.html');
const _listTitle = '公开资讯';
const _articleTitle = '资讯正文';
const _paragraph = '第一段公开内容。';

// Only the fixed site-request boundary is synthetic. The client, index page,
// native article, refresh indicators and both Navigator pushes are production.
class _Requests {
  int accounts = 0, indexes = 0, articles = 0;
  final indexRetry = Completer<Map<String, dynamic>>();
  final indexRefresh = Completer<Map<String, dynamic>>();
  final articleRetry = Completer<Map<String, dynamic>>();
  final articleRefresh = Completer<Map<String, dynamic>>();

  Map<String, dynamic> get index => {
    'kind': 'notices',
    'items': [
      {'url': _articleUrl.toString(), 'title': _listTitle},
    ],
  };
  Map<String, dynamic> get article => {
    'kind': 'notice',
    'title': _articleTitle,
    'paragraphs': [_paragraph, '第二段公开内容。'],
    'hasRichMedia': false,
  };

  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, dynamic> args,
  ) async {
    switch (operation) {
      case 'account':
        accounts++;
        return {'kind': 'unavailable'};
      case 'notices':
        indexes++;
        if (indexes == 1) return {'kind': 'unavailable'};
        if (indexes == 2) return indexRetry.future;
        if (indexes == 3) return indexRefresh.future;
        return index;
      case 'notice':
        articles++;
        expect(args['url'], _articleUrl.toString());
        if (articles == 1) return {'kind': 'unavailable'};
        if (articles == 2) return articleRetry.future;
        if (articles == 3) return articleRefresh.future;
        return article;
      default:
        throw TestFailure('Unexpected notice host request: $operation');
    }
  }

  void releasePending() {
    for (final gate in [
      indexRetry,
      indexRefresh,
      articleRetry,
      articleRefresh,
    ]) {
      if (!gate.isCompleted) gate.complete({'kind': 'unavailable'});
    }
  }
}

Future<void> _beginRefresh(WidgetTester tester) async {
  // Let RefreshIndicator.show animate to its actual onRefresh callback. Never
  // settle while the fixture's read is intentionally held open.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final channels = <MethodChannel>[];
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final args = call.arguments as Map;
        final channel = MethodChannel('${args['viewType']}.${args['id']}');
        channels.add(channel);
        messenger.setMockMethodCallHandler(channel, (_) async => null);
      }
      return null;
    });
  });
  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in channels)
      messenger.setMockMethodCallHandler(channel, null);
    channels.clear();
  });

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'anonymous notices use native routes, retry and retain content: $style $brightness',
        (tester) async {
          final requests = _Requests();
          final site = OmoSiteClient(home: _home, request: requests.call);
          final preference = ValueNotifier(style);
          // This transport is used only if the user explicitly opens the web
          // route. Hold it, then fail it locally so no WebKit document or real
          // network starts while still asserting the actual OmoSiteWebPage.
          final browserTransport = Completer<OmoNetworkContext?>();
          unawaited(
            browserTransport.future.then<void>((_) {}, onError: (Object _) {}),
          );
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          try {
            await expectLater(
              site.readAccount(),
              throwsA(isA<OmoSiteException>()),
            );
            expect(site.account, isNull);
            expect(requests.accounts, 1);
            await tester.pumpWidget(
              AppInterfaceStyleScope(
                style: preference,
                child: MaterialApp(
                  theme: ThemeData(
                    brightness: brightness,
                    platform: TargetPlatform.iOS,
                  ),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: const TextScaler.linear(1.7)),
                    child: child!,
                  ),
                  home: VideoNetworkScope(
                    source: omoNetworkSource,
                    network: browserTransport.future,
                    child: OmoPrivateIndexPage(client: site, kind: 'notices'),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text(t.videoSource.readFailed), findsOneWidget);
            expect(requests.indexes, 1);
            expect(
              requests.accounts,
              1,
              reason: 'public notices do not retry the failed account read',
            );
            expect(
              find.byType(OmoSiteWebPage, skipOffstage: false),
              findsNothing,
            );

            await tester.tap(find.text(t.common.retry));
            await tester.pump();
            expect(requests.indexes, 2);
            expect(find.byType(LinearProgressIndicator), findsOneWidget);
            requests.indexRetry.complete(requests.index);
            await tester.pumpAndSettle();
            expect(find.text(_listTitle), findsOneWidget);
            expect(find.text(t.videoSource.noNotices), findsNothing);
            expect(
              find.byType(OmoSiteWebPage, skipOffstage: false),
              findsNothing,
            );

            final indexRefresh = tester
                .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
                .show();
            await _beginRefresh(tester);
            expect(requests.indexes, 3);
            expect(
              find.text(_listTitle),
              findsOneWidget,
              reason: 'a pending refresh keeps the known index',
            );
            requests.indexRefresh.complete({'kind': 'unavailable'});
            await tester.pumpAndSettle();
            await indexRefresh;
            expect(find.text(t.videoSource.readFailed), findsOneWidget);
            expect(
              find.text(_listTitle),
              findsOneWidget,
              reason:
                  'failed refresh does not replace articles with empty data',
            );
            await tester.tap(find.text(t.common.retry));
            await tester.pumpAndSettle();
            expect(requests.indexes, 4);

            // The whole real index row navigates natively; no readNotice button
            // or injected onWebsite callback bypasses the production route.
            await tester.tap(find.text(_listTitle));
            await tester.pumpAndSettle();
            expect(find.byType(OmoNoticePage), findsOneWidget);
            expect(
              find.byType(OmoSiteWebPage, skipOffstage: false),
              findsNothing,
            );
            expect(
              find.byType(InAppWebView, skipOffstage: false),
              findsNothing,
            );
            expect(find.text(t.videoSource.readFailed), findsOneWidget);
            expect(requests.articles, 1);
            await tester.tap(find.text(t.common.retry));
            await tester.pump();
            expect(requests.articles, 2);
            expect(find.byType(LinearProgressIndicator), findsOneWidget);
            requests.articleRetry.complete(requests.article);
            await tester.pumpAndSettle();
            expect(find.text(_articleTitle), findsOneWidget);
            expect(find.text(_paragraph), findsOneWidget);
            expect(
              find.byType(OmoSiteWebPage, skipOffstage: false),
              findsNothing,
            );

            final articleRefresh = tester
                .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
                .show();
            await _beginRefresh(tester);
            expect(requests.articles, 3);
            expect(find.text(_paragraph), findsOneWidget);
            requests.articleRefresh.complete({'kind': 'unavailable'});
            await tester.pumpAndSettle();
            await articleRefresh;
            expect(find.text(t.videoSource.readFailed), findsOneWidget);
            expect(find.text(_articleTitle), findsOneWidget);
            expect(
              find.text(_paragraph),
              findsOneWidget,
              reason: 'failed article refresh retains the readable body',
            );
            expect(
              find.byType(OmoSiteWebPage, skipOffstage: false),
              findsNothing,
            );
            expect(requests.accounts, 1);

            final website = find.text(t.videoLibrary.openWebsite);
            await tester.ensureVisible(website);
            await tester.tap(website);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 500));
            expect(find.byType(OmoSiteWebPage), findsOneWidget);
            final web = tester.widget<OmoSiteWebPage>(
              find.byType(OmoSiteWebPage),
            );
            expect(web.url, _articleUrl);
            expect(web.finishOnSignIn, isFalse);
            browserTransport.completeError(
              StateError('offline test transport'),
            );
            await tester.pumpAndSettle();
            expect(
              find.byType(InAppWebView, skipOffstage: false),
              findsNothing,
            );
            expect(requests.accounts, 1);
            expect(tester.takeException(), isNull);
          } finally {
            requests.releasePending();
            if (!browserTransport.isCompleted)
              browserTransport.completeError(StateError('host disposed'));
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            site.dispose();
            preference.dispose();
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          }
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }
}
