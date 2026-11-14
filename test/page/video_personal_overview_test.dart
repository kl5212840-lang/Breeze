import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_personal_overview.dart';
import 'package:zephyr/page/video/source_profile_video_preview.dart';

final _page = Uri.parse('https://hanime1.me/user/42');
final _tabs = [
  for (final kind in ['histories', 'saves', 'likes', 'playlists'])
    (title: kind, url: _page.replace(path: '${_page.path}/$kind')),
];
List<Map<String, dynamic>> _cards(String kind) => [
  for (var i = 1; i <= 6; i++)
    {
      'title': '$kind Video $i',
      'coverUrl': '',
      'creatorName': 'Creator',
      'viewCount': 10000,
      if (kind == 'playlists')
        'pageUrl': 'https://hanime1.me/playlist?list=list$i'
      else
        'watchUrl': 'https://hanime1.me/watch?v=$i',
    },
];
Finder _section(String kind) => find.byKey(ValueKey('video-personal.$kind'));
Finder _viewAll(String kind) => find.byKey(
  ValueKey<(String, Key)>((
    'profile-view-all',
    ValueKey('site-personal.$kind'),
  )),
);
Future<void> _see(WidgetTester tester, String kind) async {
  final vertical = find
      .descendant(
        of: find.byType(VideoPersonalOverview),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      )
      .first;
  await tester.scrollUntilVisible(_section(kind), 180, scrollable: vertical);
}

SourceProfileVideoPreview _rail(WidgetTester tester, String kind) =>
    tester.widget<SourceProfileVideoPreview>(
      find.descendant(
        of: _section(kind),
        matching: find.byType(SourceProfileVideoPreview),
      ),
    );

void main() {
  testWidgets(
    'each observed collection has a horizontal bounded preview and exact View All target',
    (tester) async {
      final opened = <Uri>[], reads = <Uri>[];
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoPersonalOverview(
              account: const {'status': 'signedIn', 'name': 'Account'},
              page: _page,
              tabs: _tabs,
              onTab: opened.add,
              onVideo: opened.add,
              readRecent: (url) async {
                reads.add(url);
                return _cards(url.path.split('/').last);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(reads, unorderedEquals(_tabs.map((tab) => tab.url)));
      expect(find.byType(TabBar), findsNothing);
      for (final tab in _tabs) {
        final kind = tab.url.path.split('/').last;
        await _see(tester, kind);
        expect(_rail(tester, kind).items, hasLength(4));
        expect(_rail(tester, kind).responsivePreview, isTrue);
        expect(_rail(tester, kind).posterAspectRatio, 2 / 3);
        await Scrollable.ensureVisible(
          tester.element(_viewAll(kind)),
          alignment: .15,
        );
        await tester.pumpAndSettle();
        await tester.tap(_viewAll(kind));
        expect(opened.last, tab.url);
        _rail(tester, kind).items[1].onOpen();
        expect(
          opened.last,
          Uri.parse(
            kind == 'playlists'
                ? 'https://hanime1.me/playlist?list=list2'
                : 'https://hanime1.me/watch?v=2',
          ),
        );
      }
      expect(find.textContaining('10000'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('cached cards render while the document is still preparing', (
    tester,
  ) async {
    var siteReads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoPersonalOverview(
            account: const {'status': 'signedIn', 'name': 'Account'},
            page: _page,
            tabs: _tabs,
            readReady: false,
            onTab: (_) {},
            onVideo: (_) {},
            readCached: (url) async => _cards(url.path.split('/').last),
            readRecent: (url) async {
              siteReads++;
              return [];
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(siteReads, 0);
    expect(_rail(tester, 'histories').items, hasLength(4));
    expect(_rail(tester, 'histories').loading, false);
  });
  testWidgets(
    'document readiness fences all four old reads without losing the current account',
    (tester) async {
      var reads = 0;
      final old = Completer<List<Map<String, dynamic>>>();
      Widget tree(bool ready) => MaterialApp(
        home: Scaffold(
          body: VideoPersonalOverview(
            account: const {'status': 'signedIn', 'name': 'Account'},
            page: _page,
            tabs: _tabs,
            readReady: ready,
            onTab: (_) {},
            onVideo: (_) {},
            readRecent: (url) {
              reads++;
              return reads <= 4
                  ? old.future
                  : Future.value(_cards(url.path.split('/').last));
            },
          ),
        ),
      );
      await tester.pumpWidget(tree(false));
      await tester.pump();
      expect(reads, 0);
      await tester.pumpWidget(tree(true));
      await tester.pump();
      expect(reads, 4);
      await tester.pumpWidget(tree(false));
      await tester.pump();
      old.completeError(StateError('old document'));
      await tester.pump();
      expect(find.text(t.videoSource.readFailed), findsNothing);
      await tester.pumpWidget(tree(true));
      await tester.pumpAndSettle();
      expect(reads, 8);
      expect(find.text('Account'), findsOneWidget);
      expect(_rail(tester, 'histories').items.first.title, 'histories Video 1');
    },
  );
  testWidgets(
    'a section failure retries only that section and remains distinct from confirmed empty',
    (tester) async {
      var fail = true;
      final reads = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoPersonalOverview(
              account: const {'status': 'signedIn', 'name': 'Account'},
              page: _page,
              tabs: _tabs,
              onTab: (_) {},
              onVideo: (_) {},
              readRecent: (url) async {
                reads.add(url);
                if (url.path.endsWith('/histories') && fail)
                  throw StateError('unavailable');
                return url.path.endsWith('/histories')
                    ? []
                    : _cards(url.path.split('/').last);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_rail(tester, 'histories').failed, isTrue);
      expect(reads, hasLength(4));
      fail = false;
      await tester.tap(
        find.descendant(
          of: _section('histories'),
          matching: find.widgetWithText(TextButton, t.common.retry),
        ),
      );
      await tester.pumpAndSettle();
      expect(reads, hasLength(5));
      expect(reads.last, _tabs.first.url);
      expect(_rail(tester, 'histories').failed, isFalse);
      expect(_rail(tester, 'histories').items, isEmpty);
    },
  );
  testWidgets(
    '320pt large text keeps all section actions and bottom navigation clearance',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              padding: const EdgeInsets.only(bottom: 83),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: VideoPersonalOverview(
              account: const {
                'status': 'signedIn',
                'name': 'Long account name 账户名字',
              },
              page: _page,
              tabs: _tabs,
              onTab: (_) {},
              onVideo: (_) {},
              readRecent: (url) async => _cards(url.path.split('/').last),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final tab in _tabs) {
        final kind = tab.url.path.split('/').last;
        await _see(tester, kind);
        await Scrollable.ensureVisible(
          tester.element(_viewAll(kind)),
          alignment: .15,
        );
        await tester.pumpAndSettle();
        expect(_viewAll(kind).hitTestable(), findsOneWidget);
        expect(tester.getSize(_viewAll(kind)).height, greaterThanOrEqualTo(44));
      }
      final list = tester.widget<ListView>(
        find.byKey(PageStorageKey('video-personal.overview.$_page')),
      );
      expect((list.padding! as EdgeInsets).bottom, greaterThanOrEqualTo(83));
      expect(tester.takeException(), isNull);
    },
  );
}
