import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/about/view/about_page.dart';
import 'package:zephyr/page/change_log_page.dart';
import 'package:zephyr/page/comic_follow/cubit/comic_follow_cubit.dart';
import 'package:zephyr/page/more/view/more.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/service/update/json/github_release_json.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../test_helper.dart';

GithubReleaseJson _release(int id, {bool draft = false}) => GithubReleaseJson(
  url: '',
  assetsUrl: '',
  uploadUrl: '',
  htmlUrl: 'https://github.com/deretame/Breeze/releases/tag/v3.0.$id',
  id: id,
  nodeId: '$id',
  tagName: 'v3.0.$id',
  targetCommitish: '',
  name: '$id',
  draft: draft,
  prerelease: false,
  createdAt: DateTime(2026, 10, id),
  publishedAt: DateTime(2026, 10, id),
  assets: [],
  tarballUrl: '',
  zipballUrl: '',
  body: 'Published release body $id',
  author: const Author(
    login: 'upstream',
    id: 1,
    nodeId: '',
    avatarUrl: '',
    gravatarId: '',
    url: '',
    htmlUrl: '',
    followersUrl: '',
    followingUrl: '',
    gistsUrl: '',
    starredUrl: '',
    subscriptionsUrl: '',
    organizationsUrl: '',
    reposUrl: '',
    eventsUrl: '',
    receivedEventsUrl: '',
    type: 'User',
    userViewType: 'public',
    siteAdmin: false,
  ),
);

void main() {
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    PackageInfo.setMockInitialValues(
      appName: 'Breeze',
      packageName: 'com.zephyr.breeze',
      version: '3.0.37',
      buildNumber: '2270',
      buildSignature: '',
    );
  });
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.single;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });
  Future<void> mount(
    WidgetTester tester,
    Widget child,
    Brightness brightness,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => GlobalSettingCubit()),
          BlocProvider(create: (_) => ComicFollowCubit()),
        ],
        child: MaterialApp(
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: ThemeData(brightness: brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            // Match the app's bridge for MarkdownWidget's legacy Material UI.
            // ignore: deprecated_member_use
            child: MaterialUiCompatibilityBridge(child: child!),
          ),
          home: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'More retains centered 88pt logo without duplicate bottom-bar entries at 320pt 2x $brightness',
      (tester) async {
        await mount(tester, const MorePage(), brightness);
        final logo = find.byType(Image).first;
        expect(tester.getSize(logo), const Size(88, 88));
        expect(tester.getCenter(logo).dx, 160);
        expect(find.byType(Card), findsNothing);
        final tiles = tester
            .widgetList<ListTile>(find.byType(ListTile))
            .map((tile) => (tile.title! as Text).data)
            .toList();
        expect(tiles, [
          t.more.sync,
          t.settings.globalTitle,
          t.more.changelog,
          t.about.title,
        ]);
        expect(
          tester.getTopLeft(find.text(t.settings.globalTitle)).dy,
          lessThan(tester.getTopLeft(find.text(t.more.others)).dy),
        );
        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(find.text(t.about.title).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'About restores avatars, contributor counts and original sections in $brightness',
      (tester) async {
        var reads = 0;
        await mount(
          tester,
          AboutPage(
            contributorLoader: () async {
              reads++;
              return [
                {
                  'login': 'author',
                  'contributions': 42,
                  'avatar_url': '',
                  'html_url': 'https://github.com/author',
                },
              ];
            },
          ),
          brightness,
        );
        expect(reads, 1);
        expect(find.byType(SettingPageShell), findsOneWidget);
        expect(tester.getSize(find.byType(Image).first), const Size(104, 104));
        expect(find.text(t.about.version(version: '3.0.37')), findsOneWidget);
        expect(
          find.text(t.about.version(version: '3.0.37 (2270)')),
          findsNothing,
        );
        expect(find.byType(ActionChip), findsNothing);
        await tester.scrollUntilVisible(find.text(t.about.contributors), 400);
        await tester.pumpAndSettle();
        expect(find.text(t.about.contributorsCount(count: 1)), findsOneWidget);
        final tooltip = t.about.contributionsTooltip(
          login: 'author',
          count: 42,
        );
        expect(find.byTooltip(tooltip), findsOneWidget);
        await tester.ensureVisible(find.byTooltip(tooltip));
        await tester.longPress(find.byTooltip(tooltip));
        await tester.pumpAndSettle();
        expect(find.text(tooltip), findsOneWidget);
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text(t.about.license), 500);
        expect(find.text(t.about.disclaimer), findsOneWidget);
        expect(find.text(t.about.license), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Changelog only shows published records and opens newest first in $brightness',
      (tester) async {
        await mount(
          tester,
          ChangelogPage(
            releaseLoader: (_, page) async => [
              _release(35),
              _release(37, draft: true),
              _release(36),
            ],
          ),
          brightness,
        );
        expect(find.text('v3.0.37'), findsNothing);
        expect(find.text('当前版本 3.0.37'), findsNothing);
        expect(find.textContaining('相较 3.0.36'), findsNothing);
        expect(
          tester
              .widget<ExpansionTile>(find.byType(ExpansionTile).first)
              .initiallyExpanded,
          isTrue,
        );
        expect(
          find.text('Published release body 36', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.text('Published release body 35', findRichText: true),
          findsNothing,
        );
        await tester.scrollUntilVisible(
          find.text('v3.0.35'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        final older = find.ancestor(
          of: find.text('v3.0.35'),
          matching: find.byType(ExpansionTile),
        );
        expect(tester.widget<ExpansionTile>(older).initiallyExpanded, isFalse);
        await tester.tap(find.text('v3.0.35'));
        await tester.pumpAndSettle();
        expect(
          find.text('Published release body 35', findRichText: true),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Changelog network error has retry and never substitutes unpublished notes',
    (tester) async {
      var calls = 0;
      await mount(
        tester,
        ChangelogPage(
          releaseLoader: (_, page) async {
            if (++calls == 1) throw StateError('offline');
            return [_release(36)];
          },
        ),
        Brightness.light,
      );
      expect(find.text(t.changelog.checkNetwork), findsOneWidget);
      expect(find.textContaining('相较 3.0.36'), findsNothing);
      await tester.tap(find.text(t.common.retry));
      await tester.pumpAndSettle();
      expect(
        find.text('Published release body 36', findRichText: true),
        findsOneWidget,
      );
      expect(calls, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Changelog keeps successful records when the next page fails', (
    tester,
  ) async {
    final pages = <int>[];
    await mount(
      tester,
      ChangelogPage(
        releaseLoader: (_, page) async {
          pages.add(page);
          if (page > 1) throw StateError('next page offline');
          return List.generate(20, (i) => _release(36 - i));
        },
      ),
      Brightness.dark,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -8000));
    await tester.pumpAndSettle();
    expect(pages, contains(2));
    expect(find.byType(SnackBar), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, 8000));
    await tester.pumpAndSettle();
    expect(
      find.text('Published release body 36', findRichText: true),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
