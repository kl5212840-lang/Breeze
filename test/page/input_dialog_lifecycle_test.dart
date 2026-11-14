import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comic_info/models/collect_comic.dart';
import 'package:zephyr/page/comic_info/models/favorite_workflow.dart';
import 'package:zephyr/page/setting/common/plugin_scheme_widgets.dart';
import 'package:zephyr/widgets/multi_choice_list_dialog.dart';
import '../test_helper.dart';

const _select = FavoriteWorkflowInput(
  type: 'select',
  key: 'folder',
  title: 'Select folder',
  allowCreate: true,
  options: [FavoriteWorkflowOption(id: 'one', label: 'Existing folder')],
);
const _text = FavoriteWorkflowInput(
  type: 'text',
  key: 'name',
  title: 'Folder name',
);
const _form = FavoriteWorkflowInput(
  type: 'form',
  title: 'Folder form',
  fields: [
    FavoriteWorkflowField(
      key: 'name',
      type: 'text',
      label: 'Name',
      defaultValue: 'Default name',
      required: true,
    ),
    FavoriteWorkflowField(
      key: 'private',
      type: 'switch',
      label: 'Private',
      defaultValue: true,
    ),
  ],
);

Future<void> _open(
  WidgetTester tester,
  Future<Object?> Function(BuildContext) show,
  ValueChanged<Object?> onResult, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => onResult(await show(context)),
            child: const Text('Open dialog'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open dialog'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  testWidgets('multi-choice keeps actions above the keyboard at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    Object? result = 'pending';
    await _open(
      tester,
      (context) => showMultiChoiceListDialog(
        context,
        title: 'Tags',
        options: [
          for (var i = 0; i < 40; i++)
            MultiChoiceDialogOption(label: 'Long tag $i', value: '$i'),
        ],
        useFilledConfirmButton: true,
      ),
      (value) => result = value,
      textScale: 2,
    );
    expect(
      tester.getRect(find.byType(FilledButton)).bottom,
      lessThanOrEqualTo(400),
    );
    await tester.scrollUntilVisible(
      find.text('Long tag 39'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Long tag 39').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Long tag 39'));
    await tester.tap(find.text(t.common.cancel));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a short multi-choice task does not reserve a full-height list', (
    tester,
  ) async {
    Object? result;
    await _open(
      tester,
      (context) => showMultiChoiceListDialog(
        context,
        title: 'Tags',
        options: const [
          MultiChoiceDialogOption(label: 'First', value: 'one'),
          MultiChoiceDialogOption(label: 'Second', value: 'two'),
        ],
      ),
      (value) => result = value,
    );
    expect(tester.getSize(find.byType(ListView)).height, lessThan(160));
    await tester.tap(find.text('Second'));
    await tester.tap(find.text(t.common.ok));
    await tester.pumpAndSettle();
    expect(result, {'two'});
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'multi-choice cancel keeps draft private and its scrollbar alive during exit',
    (tester) async {
      final initial = {'0'};
      Object? result = 'pending';
      await _open(
        tester,
        (context) => showMultiChoiceListDialog(
          context,
          title: 'Tags',
          options: [
            for (var i = 0; i < 40; i++)
              MultiChoiceDialogOption(label: 'Tag $i', value: '$i'),
          ],
          initialSelected: initial,
        ),
        (value) => result = value,
      );
      final controller = tester
          .widget<Scrollbar>(find.byType(Scrollbar))
          .controller!;
      await tester.tap(find.text('Tag 1'));
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.common.cancel));
      await tester.pump(const Duration(milliseconds: 40));
      expect(result, isNull);
      expect(initial, {'0'});
      expect(controller.hasClients, true);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final kind in ['setting', 'select', 'text', 'form']) {
    for (final barrier in [true, false]) {
      testWidgets(
        '$kind ${barrier ? 'barrier' : 'button'} cancel retains input during exit animation',
        (tester) async {
          Object? result = 'pending';
          await _open(
            tester,
            (context) => kind == 'setting'
                ? showPluginSettingInputDialog(
                    context,
                    title: 'Setting',
                    initialValue: 'Original',
                    obscure: false,
                  )
                : showFavoriteWorkflowInput(context, switch (kind) {
                    'select' => _select,
                    'text' => _text,
                    _ => _form,
                  }),
            (value) => result = value,
          );
          await tester.enterText(find.byType(TextField).first, 'Edited name');
          await tester.pump();
          if (barrier) {
            await tester.tapAt(const Offset(8, 8));
          } else {
            await tester.tap(find.text(t.common.cancel));
          }
          // Route result completes before its reverse transition unmounts fields.
          await tester.pump();
          expect(result, isNull);
          await tester.pump(const Duration(milliseconds: 40));
          expect(tester.takeException(), isNull);
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('setting saves edited value after animated close', (
    tester,
  ) async {
    Object? result;
    await _open(
      tester,
      (context) => showPluginSettingInputDialog(
        context,
        title: 'Setting',
        initialValue: 'Original',
        obscure: true,
      ),
      (v) => result = v,
    );
    await tester.enterText(find.byType(TextField), 'Changed value');
    await tester.tap(find.text(t.common.save));
    await tester.pumpAndSettle();
    expect(result, 'Changed value');
    expect(tester.takeException(), isNull);
  });

  testWidgets('select folder clears created name and keeps choice result', (
    tester,
  ) async {
    Object? result;
    await _open(
      tester,
      (context) => showFavoriteWorkflowInput(context, _select),
      (v) => result = v,
    );
    await tester.enterText(find.byType(TextField), 'Created folder');
    await tester.pump();
    await tester.tap(find.text('Existing folder'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    await tester.tap(find.text(t.common.confirm));
    await tester.pumpAndSettle();
    expect(result, {'key': 'folder', 'value': 'one'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('select folder submits created name instead of old choice', (
    tester,
  ) async {
    Object? result;
    await _open(
      tester,
      (context) => showFavoriteWorkflowInput(context, _select),
      (v) => result = v,
    );
    await tester.tap(find.text('Existing folder'));
    await tester.enterText(find.byType(TextField), '  Created folder  ');
    await tester.pump();
    await tester.tap(find.text(t.common.confirm));
    await tester.pumpAndSettle();
    expect(result, {
      'key': 'folder',
      'value': null,
      'created': 'Created folder',
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('required text disables empty save and preserves input payload', (
    tester,
  ) async {
    Object? result;
    await _open(
      tester,
      (context) => showFavoriteWorkflowInput(context, _text),
      (v) => result = v,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), 'My name');
    await tester.pump();
    await tester.tap(find.text(t.common.confirm));
    await tester.pumpAndSettle();
    expect(result, {'key': 'name', 'value': 'My name'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('form keeps defaults and validates edited required fields', (
    tester,
  ) async {
    Object? result;
    await _open(
      tester,
      (context) => showFavoriteWorkflowInput(context, _form),
      (v) => result = v,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Default name',
    );
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), 'Edited name');
    await tester.pump();
    await tester.tap(find.text(t.common.confirm));
    await tester.pumpAndSettle();
    expect(result, {
      'values': {'name': 'Edited name', 'private': true},
    });
    expect(tester.takeException(), isNull);
  });
}
