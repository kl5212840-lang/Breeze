import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show eventBus;
import 'package:zephyr/page/source_shell/view/source_shell_page.dart';
import 'package:zephyr/page/source_shell/models/source_shell_section.dart';
import 'package:zephyr/util/event/event.dart';

void main() {
  testWidgets('login failure is inline and clears after login succeeds', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SourceShellPage(
          source: 'test-source',
          sourceName: 'Test Source',
          sections: [],
        ),
      ),
    );

    expect(find.text(t.sourceShell.noSections), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text(t.sourceShell.search), findsOneWidget);
    eventBus.fire(NeedLogin(from: 'another-source'));
    await tester.pumpAndSettle();
    expect(find.text(t.navigation.needLoginTitle), findsNothing);

    eventBus.fire(NeedLogin(from: 'test-source'));
    await tester.pumpAndSettle();
    expect(find.text(t.navigation.needLoginTitle), findsOneWidget);
    expect(find.text(t.navigation.goLogin), findsOneWidget);
    expect(find.text(t.sourceShell.noSections), findsNothing);

    eventBus.fire(const PluginLoginSucceeded('test-source'));
    await tester.pumpAndSettle();
    expect(find.text(t.navigation.needLoginTitle), findsNothing);
    expect(find.text(t.sourceShell.noSections), findsOneWidget);
  });

  testWidgets('login error in a More dialog does not replace the More tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SourceShellPage(
          source: 'test-source',
          sourceName: 'Test Source',
          sections: [SourceShellSection.more(title: '更多', actions: [])],
        ),
      ),
    );

    eventBus.fire(NeedLogin(from: 'test-source'));
    await tester.pumpAndSettle();
    expect(find.text(t.navigation.needLoginTitle), findsNothing);
  });
}
