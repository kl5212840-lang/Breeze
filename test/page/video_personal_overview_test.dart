import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_personal_overview.dart';

void main() {
  final page = Uri.parse('https://hanime1.me/user/42');
  final tabs = [
    for (final suffix in [
      '',
      'histories',
      'saves',
      'likes',
      'playlists',
      'uploaded',
    ])
      (
        title: suffix.isEmpty ? 'Home' : suffix,
        url: page.replace(
          path: '${page.path}${suffix.isEmpty ? '' : '/$suffix'}',
        ),
      ),
  ];
  final videos = [
    for (var i = 1; i <= 5; i++)
      {
        'title': 'Video $i',
        'watchUrl': 'https://hanime1.me/watch?v=$i',
        'coverUrl': '',
        'creatorName': 'Creator',
        'viewCount': 10000,
      },
  ];
  testWidgets(
    'preview waits for the current document and ignores a superseded read',
    (tester) async {
      var reads = 0;
      final old = Completer<List<Map<String, dynamic>>>();
      Widget overview(bool ready) => MaterialApp(
        home: Scaffold(
          body: VideoPersonalOverview(
            account: const {'status': 'signedIn', 'name': 'Account'},
            page: page,
            tabs: tabs,
            readReady: ready,
            onTab: (_) {},
            onVideo: (_) {},
            readRecent: (_) {
              reads++;
              return reads == 1 ? old.future : Future.value(videos);
            },
          ),
        ),
      );
      await tester.pumpWidget(overview(false));
      await tester.pump();
      expect(reads, 0);
      await tester.pumpWidget(overview(true));
      await tester.pump();
      expect(reads, 1);
      await tester.pumpWidget(overview(false));
      await tester.pump();
      old.completeError(StateError('old document navigated'));
      await tester.pump();
      expect(find.text(t.videoPersonal.recentUnavailable), findsNothing);
      await tester.pumpWidget(overview(true));
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(find.text('Video 1'), findsOneWidget);
      expect(find.text(t.videoPersonal.recentUnavailable), findsNothing);
    },
  );
  testWidgets(
    'overview uses observed library URLs, bounded history and original video identity',
    (tester) async {
      final opened = <Uri>[];
      var reads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoPersonalOverview(
              account: const {
                'status': 'signedIn',
                'name': 'Account',
                'summary': 'Joined recently',
              },
              page: page,
              tabs: tabs,
              onTab: opened.add,
              onVideo: opened.add,
              onAccountSettings: () {},
              readRecent: (url) async {
                reads++;
                expect(url, tabs[1].url);
                return videos;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(reads, 1);
      expect(find.text('Video 3'), findsOneWidget);
      expect(find.text('Video 4'), findsNothing);
      expect(find.textContaining('10000'), findsNothing);
      for (final suffix in ['histories', 'saves', 'likes', 'playlists']) {
        await tester.tap(find.byKey(ValueKey('video-personal.$suffix')));
        expect(
          opened.last,
          tabs.firstWhere((tab) => tab.url.path.endsWith('/$suffix')).url,
        );
      }
      await tester.tap(find.text('Video 2'));
      expect(opened.last, Uri.parse('https://hanime1.me/watch?v=2'));
      await tester.tap(find.text(t.videoPersonal.viewAll));
      expect(opened.last, tabs[1].url);
    },
  );
  testWidgets(
    'history failure is distinct from empty and retries without changing the account or page',
    (tester) async {
      var fail = true;
      var reads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoPersonalOverview(
              account: const {'status': 'signedIn', 'name': 'Account'},
              page: page,
              tabs: tabs,
              onTab: (_) {},
              onVideo: (_) {},
              readRecent: (_) async {
                reads++;
                if (fail) throw StateError('unavailable');
                return [];
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(t.videoPersonal.recentUnavailable), findsOneWidget);
      expect(find.text(t.videoPersonal.emptyHistory), findsNothing);
      fail = false;
      await tester.tap(find.text(t.common.retry));
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(find.text(t.videoPersonal.emptyHistory), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
    },
  );
  testWidgets(
    'narrow large text keeps the profile and all library entry points reachable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pending = Completer<List<Map<String, dynamic>>>();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: VideoPersonalOverview(
              account: const {
                'status': 'signedIn',
                'name': 'Long account name 账户名字',
                'summary': 'Joined recently',
              },
              page: page,
              tabs: tabs,
              onTab: (_) {},
              onVideo: (_) {},
              onAccountSettings: () {},
              readRecent: (_) => pending.future,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      pending.complete(videos);
      await tester.pumpAndSettle();
      for (final suffix in ['histories', 'saves', 'likes', 'playlists']) {
        final target = find.byKey(ValueKey('video-personal.$suffix'));
        await tester.scrollUntilVisible(target, 100);
        expect(tester.getSize(target).height, greaterThanOrEqualTo(44));
      }
      expect(tester.takeException(), isNull);
    },
  );
}
