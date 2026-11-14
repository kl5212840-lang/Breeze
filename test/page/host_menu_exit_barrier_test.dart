import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

void main() {
  for (final (styleName, platform) in [
    ('breeze', TargetPlatform.iOS),
    ('system', TargetPlatform.android),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        '$styleName $brightness menu shields touches through its exit',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          final style = ValueNotifier(styleName);
          addTearDown(style.dispose);
          var contentTaps = 0;
          var selections = 0;
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: style,
              child: MaterialApp(
                theme: ThemeData(brightness: brightness),
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar: AppBar(
                              actions: [
                                SourceMoreButton(
                                  actions: [
                                    SourceMenuAction(
                                      id: 'page-action',
                                      label: 'Page action',
                                      icon: Icons.settings_outlined,
                                      symbol: 'gearshape',
                                      onSelected: () => selections++,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            body: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => contentTaps++,
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                      child: const Text('Open source'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open source'));
          await tester.pumpAndSettle();
          final trigger = find.byTooltip(t.sourceShell.navigationActions);
          final panel = find.byKey(const ValueKey('video-host-menu'));
          for (final select in [false, true]) {
            final before = contentTaps;
            await tester.tap(trigger);
            await tester.pumpAndSettle();
            expect(panel, findsOneWidget);
            if (select) {
              await tester.tap(find.text('Page action'));
            } else {
              await tester.tapAt(const Offset(100, 400));
            }
            await tester.pump();
            expect(
              selections,
              select ? 1 : 0,
              reason: 'selection stays immediate',
            );
            await tester.pump(const Duration(milliseconds: 20));
            expect(
              panel,
              findsOneWidget,
              reason: 'the panel is still fading out',
            );
            await tester.tapAt(const Offset(100, 400));
            await tester.pump();
            expect(
              contentTaps,
              before,
              reason: 'visible exit must not tap through',
            );
            await tester.tapAt(tester.getCenter(trigger));
            await tester.pump();
            expect(
              panel,
              findsOneWidget,
              reason: 'an exiting menu must not reopen on the same touch',
            );
            await tester.pumpAndSettle();
            expect(panel, findsNothing);
            await tester.tapAt(const Offset(100, 400));
            await tester.pump();
            expect(
              contentTaps,
              before + 1,
              reason: 'the shield ends with the route',
            );
          }
          expect(selections, 1);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(platform),
      );
    }
  }
}
