import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/widgets/folder_shelf_page.dart';
import 'package:zephyr/page/source_shell/models/source_shell_section.dart';
import 'package:zephyr/page/source_shell/view/source_shell_page.dart';

void main() {
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
                      SourceShellSection.more(title: 'First', actions: []),
                      SourceShellSection.more(title: 'Second', actions: []),
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
    expect(find.text(t.sourceShell.exitSource), findsOneWidget);
    expect(find.byTooltip(t.sourceShell.exitSourceHint), findsOneWidget);

    await tester.tap(find.byType(NavigationDestination).last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('${t.common.back} · First'), findsOneWidget);
    expect(find.text(t.sourceShell.exitSource), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(t.sourceShell.exitSource), findsOneWidget);
    expect(find.text('Launch source'), findsNothing);

    await tester.tap(find.text(t.sourceShell.exitSource));
    await tester.pumpAndSettle();
    expect(find.text('Launch source'), findsOneWidget);
  });
}
