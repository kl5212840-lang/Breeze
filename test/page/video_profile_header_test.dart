import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_profile_header.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    Map<String, dynamic> account, {
    double width = 390,
    double scale = 1,
    bool compact = false,
    VoidCallback? onAccountSettings,
    VoidCallback? onOpenSite,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: SingleChildScrollView(
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: VideoProfileHeader(
                    account: account,
                    page: Uri.parse('https://hanime1.me/user/11'),
                    onOpenSite: onOpenSite ?? () {},
                    compact: compact,
                    onAccountSettings: onAccountSettings,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'public raw counts retain zero and approximate wording without duplicate summary',
    (tester) async {
      await mount(tester, {
        'status': 'profile',
        'name': 'Public author',
        'subscriberCountRaw': '1.2万位订阅者',
        'videoCountRaw': '0 个视频',
        'summary': '1.2万位订阅者 · 0 个视频',
      });
      expect(find.text('1.2万位订阅者'), findsOneWidget);
      expect(find.text('0 个视频'), findsOneWidget);
      expect(find.text('1.2万位订阅者 · 0 个视频'), findsNothing);
      expect(find.textContaining('12000'), findsNothing);
      expect(
        find.byKey(const ValueKey('profile.subscriberCountRaw')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('profile.videoCountRaw')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'summary survives absent raw fields and retains unrelated source text',
    (tester) async {
      await mount(tester, {
        'status': 'profile',
        'name': 'Public author',
        'summary': 'Original profile summary',
      });
      expect(find.text('Original profile summary'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile.videoCountRaw')), findsNothing);
      await mount(tester, {
        'status': 'profile',
        'name': 'Public author',
        'subscriberCountRaw': '8 位订阅者',
        'videoCountRaw': '2 个视频',
        'summary': '8 位订阅者 · 2 个视频 · Original note',
      });
      expect(find.text('Original note'), findsOneWidget);
      expect(find.text('8 位订阅者'), findsOneWidget);
      expect(find.text('2 个视频'), findsOneWidget);
    },
  );

  testWidgets(
    'count wrap supports narrow large text and public profile action',
    (tester) async {
      var opened = 0;
      await mount(
        tester,
        {
          'status': 'profile',
          'name': 'Long public author name',
          'subscriberCountRaw': '1.2万位订阅者',
          'videoCountRaw': '135 个视频',
        },
        width: 288,
        scale: 2,
        onOpenSite: () => opened++,
      );
      expect(tester.takeException(), isNull);
      final subscribers = tester.getRect(
        find.byKey(const ValueKey('profile.subscriberCountRaw')),
      );
      final videos = tester.getRect(
        find.byKey(const ValueKey('profile.videoCountRaw')),
      );
      expect(videos.top, greaterThan(subscribers.top));
      expect(subscribers.right, lessThanOrEqualTo(288));
      expect(videos.right, lessThanOrEqualTo(288));
      final button = find.widgetWithText(TextButton, t.videoPlayback.backToWeb);
      expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
      await tester.tap(button);
      expect(opened, 1);
    },
  );

  testWidgets('compact owner keeps direct account action and private summary', (
    tester,
  ) async {
    var settings = 0;
    await mount(
      tester,
      {
        'status': 'signedIn',
        'name': 'Current account',
        'summary': 'Joined recently',
        'subscriberCountRaw': 'not public metadata',
      },
      compact: true,
      width: 288,
      scale: 2,
      onAccountSettings: () => settings++,
    );
    expect(find.text('Joined recently'), findsOneWidget);
    expect(find.text('not public metadata'), findsNothing);
    final button = find.widgetWithText(TextButton, t.videoSiteAccount.title);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
    await tester.tap(button);
    expect(settings, 1);
    expect(tester.takeException(), isNull);
  });
}
