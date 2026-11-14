import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/page/navigation/main_navigation_layout.dart';
import 'package:zephyr/page/navigation_bar.dart' as app;

void main() {
  const discover = MainNavigationDestination.discover;
  const bookshelf = MainNavigationDestination.bookshelf;
  const follow = MainNavigationDestination.follow;
  const downloads = MainNavigationDestination.downloads;
  const more = MainNavigationDestination.more;

  test(
    'previous or invalid preferences get Follow at the center by default',
    () {
      for (final value in [null, '', 2, 'unknown', 'right,unknown']) {
        final settings = GlobalSettingState.fromJson({
          'mainNavigationSlots': value,
        });
        expect(
          MainNavigationLayout.decode(
            settings.mainNavigationSlots,
          ).destinations,
          [discover, bookshelf, follow, downloads, more],
        );
      }
    },
  );

  test('moving one shortcut preserves the other and serializes both', () {
    final layout = MainNavigationLayout.defaults
        .withPosition(
          MainNavigationShortcut.follow,
          MainNavigationPosition.left,
        )
        .withPosition(
          MainNavigationShortcut.downloads,
          MainNavigationPosition.more,
        );
    final settings = GlobalSettingState.fromJson(
      const GlobalSettingState()
          .copyWith(mainNavigationSlots: layout.encoded)
          .toJson(),
    );
    final restored = MainNavigationLayout.decode(settings.mainNavigationSlots);
    expect(restored.destinations, [discover, follow, bookshelf, more]);
    expect(restored.contains(downloads), isFalse);
    expect(
      restored
          .withPosition(
            MainNavigationShortcut.downloads,
            MainNavigationPosition.left,
          )
          .destinations,
      [discover, follow, downloads, bookshelf, more],
    );
  });

  testWidgets('wide rail reorders Follow without replacing its active page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(980, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final layout = ValueNotifier(MainNavigationLayout.defaults);
    addTearDown(layout.dispose);
    final followKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder(
          valueListenable: layout,
          builder: (_, layout, _) => app.MainWideTabHost(
            screens: [
              for (final item in MainNavigationDestination.values)
                SizedBox(
                  key: item == follow ? followKey : null,
                  child: Text('page-${item.name}'),
                ),
            ],
            destinations: [
              for (final item in layout.destinations)
                NavigationRailDestination(
                  icon: const Icon(Icons.circle),
                  label: Text(item.name),
                ),
            ],
            selectedIndex: layout.destinations.indexOf(follow),
            screenIndex: follow.index,
            onSelected: (_) {},
            onSearch: () {},
          ),
        ),
      ),
    );
    final initial = followKey.currentContext;
    expect(find.text('page-follow').hitTestable(), findsOneWidget);
    layout.value = MainNavigationLayout.decode('left,more');
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      1,
    );
    expect(find.text('page-follow').hitTestable(), findsOneWidget);
    expect(followKey.currentContext, same(initial));
    expect(find.text('downloads'), findsNothing);
  });
}
