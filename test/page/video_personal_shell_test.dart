import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/video/video_personal_shell.dart';

void main() {
  testWidgets(
    'personal tabs honor motion changes while retaining the actual library',
    (tester) async {
      final reduced = ValueNotifier(false);
      addTearDown(reduced.dispose);
      final page = Uri.parse('https://hanime1.me/user/fixture');
      final histories = page.replace(path: '${page.path}/histories');
      var current = page;
      StateSetter? updateShell;
      await tester.pumpWidget(
        ValueListenableBuilder(
          valueListenable: reduced,
          builder: (_, value, _) => MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: value),
              child: child!,
            ),
            home: StatefulBuilder(
              builder: (_, setState) {
                updateShell = setState;
                return Scaffold(
                  body: VideoPersonalShell(
                    account: const {'status': 'signedIn', 'name': 'Account'},
                    page: page,
                    current: current,
                    tabs: [
                      (title: 'Home', url: page),
                      (title: 'Histories', url: histories),
                    ],
                    onTab: (url) => setState(() => current = url),
                    onOpenSite: () {},
                    child: Text(current.path),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Histories'));
      await tester.pump(const Duration(milliseconds: 20));
      expect(current, histories);
      reduced.value = true;
      await tester.pump();
      var tabs = tester.widget<TabBar>(find.byType(TabBar)).controller!;
      expect(tabs.animationDuration, Duration.zero);
      expect(tabs.index, 1);
      expect(tabs.indexIsChanging, isFalse);
      expect(find.text('Account'), findsOneWidget);
      expect(find.text(histories.path), findsOneWidget);
      await tester.tap(find.widgetWithText(Tab, 'Home'));
      await tester.pump();
      expect(current, page);
      expect(tabs.animation!.value, 0);
      expect(tabs.indexIsChanging, isFalse);
      // An external return to a saved library must use its actual current URI.
      updateShell!(() => current = histories);
      await tester.pump();
      reduced.value = false;
      await tester.pump();
      tabs = tester.widget<TabBar>(find.byType(TabBar)).controller!;
      expect(tabs.index, 1);
      expect(tabs.animationDuration, const Duration(milliseconds: 160));
      expect(tester.takeException(), isNull);
    },
  );
}
