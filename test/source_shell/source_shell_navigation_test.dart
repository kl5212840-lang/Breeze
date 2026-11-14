import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/source_shell/source_return_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/widget/keyword_scope_menu.dart';
import 'package:zephyr/page/bookshelf/widgets/folder_shelf_page.dart';
import 'package:zephyr/page/source_shell/models/source_shell_section.dart';
import 'package:zephyr/page/source_shell/view/source_shell_page.dart';
import 'package:zephyr/page/source_shell/view/source_video_content.dart';
import 'package:zephyr/page/video/api_video_library_page.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/page/video/video_search_page.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_navigation_bar.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      SourceReturnPreferences.storageKey: 'stepByStep',
    });
    await SourceReturnPreferences.load();
  });

  testWidgets('a search-only source edits with All as the initial scope', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SourceShellPage(
          source: 'search-only-fixture',
          sourceName: 'Search source',
          sections: [],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final input = find.byType(TextField);
    final scopeMenu = find.byType(KeywordScopeMenu);
    expect(
      tester.widget<KeywordScopeMenu>(scopeMenu).scope,
      KeywordSearchScope.all,
    );
    await tester.enterText(input, '片名');
    tester
        .widget<KeywordScopeMenu>(scopeMenu)
        .onChanged(KeywordSearchScope.title);
    await tester.pumpAndSettle();
    expect(
      tester.widget<KeywordScopeMenu>(scopeMenu).scope,
      KeywordSearchScope.title,
    );
    expect(tester.widget<TextField>(input).controller!.text, '片名');
  });

  test('embedded folder back stays inside the folder until its root', () async {
    final controller = FolderShelfBackController();
    var backCount = 0;
    controller.attach(() => backCount++);
    expect(controller.canGoBack, isFalse);

    controller.updateIsRoot(false);
    await Future<void>.delayed(Duration.zero);
    expect(controller.canGoBack, isTrue);
    controller.goBack();
    expect(backCount, 1);

    controller.updateIsRoot(true);
    await Future<void>.delayed(Duration.zero);
    expect(controller.canGoBack, isFalse);
    controller.detach();
    controller.dispose();
  });

  testWidgets('top-level back visits previous tab before exiting source', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SourceShellPage(
                    source: 'test-source',
                    sourceName: 'Test Source',
                    sections: [
                      SourceShellSection(
                        id: 'first',
                        title: 'First',
                        scene: null,
                      ),
                      SourceShellSection(
                        id: 'second',
                        title: 'Second',
                        scene: null,
                      ),
                    ],
                  ),
                ),
              ),
              child: const Text('Launch source'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Launch source'));
    await tester.pumpAndSettle();
    expect(find.byType(SourceBackButton), findsOneWidget);
    expect(find.byTooltip(t.common.back), findsOneWidget);

    await tester.tap(find.byType(NavigationDestination).last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('${t.common.back} · First'), findsOneWidget);
    expect(find.byTooltip(t.common.back), findsNothing);

    await tester.longPress(find.byType(SourceBackButton));
    await tester.pumpAndSettle();
    expect(find.text(t.sourceShell.exitPlugin), findsNothing);
    expect(find.byTooltip('${t.common.back} · First'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byTooltip(t.common.back), findsOneWidget);
    expect(find.text('Launch source'), findsNothing);

    await tester.tap(find.byType(NavigationDestination).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(t.sourceShell.navigationActions));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.sourceShell.exitPlugin));
    await tester.pumpAndSettle();
    expect(find.text('Launch source'), findsOneWidget);
  });

  testWidgets(
    'Breeze source navigation retains the current tab and back stack',
    (tester) async {
      final style = ValueNotifier('system');
      final reduceMotion = ValueNotifier(false);
      addTearDown(style.dispose);
      addTearDown(reduceMotion.dispose);
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: style,
          child: MaterialApp(
            builder: (context, child) => ValueListenableBuilder(
              valueListenable: reduceMotion,
              builder: (context, reduce, _) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: reduce),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: child!,
                ),
              ),
            ),
            home: SourceShellPage(
              source: 'test-source',
              sourceName: 'Test Source',
              sections: const [
                SourceShellSection(id: 'first', title: 'First', scene: null),
                SourceShellSection(id: 'second', title: 'Second', scene: null),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NavigationDestination).last);
      await tester.pumpAndSettle();
      expect(find.byTooltip('${t.common.back} · First'), findsOneWidget);

      style.value = 'breeze';
      await tester.pumpAndSettle();
      final bar = find.byType(BreezeNavigationBar);
      expect(tester.widget<BreezeNavigationBar>(bar).selectedIndex, 1);

      await tester.tap(find.byType(SourceBackButton));
      await tester.pumpAndSettle();
      expect(tester.widget<BreezeNavigationBar>(bar).selectedIndex, 0);
      final secondTab = find.descendant(of: bar, matching: find.text('Second'));
      expect(secondTab.hitTestable(), findsOneWidget);
      final firstTab = find.descendant(of: bar, matching: find.text('First'));
      Color? color(Finder tab) => tester.widget<Text>(tab).style?.color;
      final firstRect = tester.getRect(firstTab);
      final secondRect = tester.getRect(secondTab);
      final selectedColor = color(firstTab);
      final idleColor = color(secondTab);
      expect(selectedColor, isNot(idleColor));
      expect(firstRect.center.dx, greaterThan(secondRect.center.dx));
      await tester.tap(secondTab);
      await tester.pump();
      expect(tester.widget<BreezeNavigationBar>(bar).selectedIndex, 1);
      expect(find.byTooltip('${t.common.back} · First'), findsOneWidget);
      expect(color(firstTab), idleColor);
      expect(color(secondTab), selectedColor);
      expect(tester.getRect(firstTab), firstRect);
      expect(tester.getRect(secondTab), secondRect);

      reduceMotion.value = true;
      await tester.pump();
      expect(color(secondTab), selectedColor);
      await tester.tap(firstTab);
      await tester.pump();
      expect(color(firstTab), selectedColor);
      expect(color(secondTab), idleColor);
      expect(tester.widget<BreezeNavigationBar>(bar).selectedIndex, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'video tab owns the only visible header and returns through shell history',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SourceShellPage(
            source: 'test-source',
            sourceName: 'Source',
            sections: [
              const SourceShellSection.more(title: '分类', actions: []),
              SourceShellSection.video(
                actions: [
                  SourceShellAction(
                    title: '电影',
                    action: {
                      'type': 'openVideoLibrary',
                      'payload': {
                        'title': '电影',
                        'url': 'https://movie.test/',
                        'protocol': 2,
                        'catalogFnPath': 'catalog',
                        'detailFnPath': 'detail',
                        'playbackFnPath': 'play',
                        'capabilities': {
                          'search': 'full',
                          'year': false,
                          'recent': false,
                          'sourceSort': false,
                        },
                      },
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NavigationDestination).last);
      await tester.pumpAndSettle();
      expect(find.byType(SourceVideoContent), findsOneWidget);
      expect(find.byType(ApiVideoLibraryPage), findsOneWidget);
      expect(find.byType(VideoSearchEntry), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(VideoNativeNavigation), findsNothing);
      final state = tester.state(find.byType(ApiVideoLibraryPage));
      await tester.tap(find.byType(SourceBackButton));
      await tester.pumpAndSettle();
      expect(find.byType(SourceVideoContent), findsNothing);
      expect(find.byType(AppBar), findsOneWidget);
      await tester.tap(find.byType(NavigationDestination).last);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(ApiVideoLibraryPage)), same(state));
      expect(tester.takeException(), isNull);
    },
  );
}
