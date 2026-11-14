import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

void main() {
  testWidgets('a source style follows its sheets and dialogs across Navigator', (
    tester,
  ) async {
    final global = ValueNotifier('system');
    final source = ValueNotifier('breeze');
    addTearDown(global.dispose);
    addTearDown(source.dispose);
    Widget appearance(BuildContext context, String where) => Text(
      '$where: ${AppInterfaceStyleScope.usesSystem(context) ? 'system' : 'breeze'}',
    );

    await tester.pumpWidget(
      AppInterfaceStyleScope(
        style: global,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  appearance(context, 'global'),
                  AppInterfaceStyleScope(
                    style: source,
                    child: Builder(
                      builder: (sourceContext) => Column(
                        children: [
                          TextButton(
                            onPressed: () => showModalBottomSheet<void>(
                              context: sourceContext,
                              useRootNavigator: true,
                              builder: (context) =>
                                  appearance(context, 'sheet'),
                            ),
                            child: const Text('Open sheet'),
                          ),
                          TextButton(
                            onPressed: () => showDialog<void>(
                              context: sourceContext,
                              builder: (context) => AlertDialog(
                                content: appearance(context, 'dialog'),
                              ),
                            ),
                            child: const Text('Open dialog'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
    expect(find.text('sheet: breeze'), findsOneWidget);
    source.value = 'system';
    await tester.pumpAndSettle();
    expect(find.text('sheet: system'), findsOneWidget);
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();

    source.value = 'breeze';
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    expect(find.text('dialog: breeze'), findsOneWidget);
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(find.text('global: system'), findsOneWidget);
  });
}
