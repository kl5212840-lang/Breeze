import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/models/source_shell_section.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/source_shell/source_return_preferences.dart';
import 'package:zephyr/page/source_shell/view/source_shell_page.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SourceReturnPreferences.load();
  });

  test('return mode defaults safely and persists an explicit choice', () async {
    expect(SourceReturnPreferences.changes.value, SourceReturnMode.byFunction);
    await SourceReturnPreferences.setMode(SourceReturnMode.stepByStep);
    expect(SourceReturnPreferences.includesTabHistory, isTrue);
    await SourceReturnPreferences.load();
    expect(SourceReturnPreferences.includesTabHistory, isTrue);
    await SourceReturnPreferences.setMode(SourceReturnMode.byFunction);
    await SourceReturnPreferences.load();
    expect(SourceReturnPreferences.includesTabHistory, isFalse);
  });

  test('the last rapid return-mode choice is what survives a reload', () async {
    await Future.wait([
      SourceReturnPreferences.setMode(SourceReturnMode.stepByStep),
      SourceReturnPreferences.setMode(SourceReturnMode.byFunction),
    ]);
    await SourceReturnPreferences.load();
    expect(SourceReturnPreferences.changes.value, SourceReturnMode.byFunction);
  });

  testWidgets('back is a plain 44pt button without long-press exit actions', (
    tester,
  ) async {
    var backs = 0;
    var contentTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(leading: SourceBackButton(onPressed: () => backs++)),
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => contentTaps++,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    final button = find.descendant(
      of: find.byType(SourceBackButton),
      matching: find.byType(IconButton),
    );
    expect(tester.getSize(button), const Size(44, 44));
    expect(find.byIcon(Icons.more_horiz), findsNothing);
    await tester.tap(button);
    expect(backs, 1);
    await tester.longPress(button);
    await tester.pumpAndSettle();
    expect(find.text(t.sourceShell.exitPlugin), findsNothing);
    expect(backs, 1);
    await tester.tapAt(const Offset(300, 400));
    await tester.pumpAndSettle();
    expect(contentTaps, 1);
  });

  testWidgets('explicit More exit skips nested source pages', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (sourceContext) => Scaffold(
                    body: TextButton(
                      onPressed: () => Navigator.of(sourceContext).push(
                        MaterialPageRoute<void>(
                          builder: (detailContext) => Scaffold(
                            body: TextButton(
                              onPressed: () =>
                                  exitSourceToDiscover(detailContext),
                              child: Text(t.sourceShell.exitPlugin),
                            ),
                          ),
                        ),
                      ),
                      child: const Text('Open detail'),
                    ),
                  ),
                ),
              ),
              child: const Text('Discover'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.sourceShell.exitPlugin));
    await tester.pumpAndSettle();
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Open detail'), findsNothing);
  });

  testWidgets(
    'by-function mode exits from the current tab without tab replay',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SourceShellPage(
                      source: 'test-source',
                      sourceName: 'Source',
                      sections: [
                        SourceShellSection.more(title: 'First', actions: []),
                        SourceShellSection.more(title: 'Second', actions: []),
                      ],
                    ),
                  ),
                ),
                child: const Text('Discover'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NavigationDestination).last);
      await tester.pumpAndSettle();
      expect(find.byTooltip('${t.common.back} · First'), findsNothing);
      await tester.tap(find.byTooltip(t.sourceShell.navigationActions));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.sourceShell.exitPlugin));
      await tester.pumpAndSettle();
      expect(find.text('Discover'), findsOneWidget);
    },
  );
}
