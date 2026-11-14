import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/search/widget/search_keyboard.dart';

void main() {
  testWidgets('explicit search reopens an already focused editor without changing composing text', (tester) async {
    final focus = FocusNode(), controller = TextEditingController();
    addTearDown(focus.dispose); addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: TextField(
      focusNode: focus, controller: controller,
    ))));
    focus.requestFocus();
    await tester.pump();
    const composing = TextEditingValue(text: 'pin', selection: TextSelection.collapsed(offset: 3),
      composing: TextRange(start: 0, end: 3));
    tester.testTextInput.updateEditingValue(composing);
    await tester.pump();
    tester.testTextInput.hide();
    expect(focus.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isFalse);
    final shows = tester.testTextInput.log.where((call) => call.method == 'TextInput.show').length;
    requestSearchKeyboard(focus, isCurrent: () => true);
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(tester.testTextInput.log.where((call) => call.method == 'TextInput.show').length, greaterThan(shows));
    expect(controller.value, composing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a cancelled request or covered route cannot reopen the old search keyboard', (tester) async {
    final focus = FocusNode(); addTearDown(focus.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: TextField(focusNode: focus))));
    focus.requestFocus(); await tester.pump();
    tester.testTextInput.hide();
    var current = true;
    requestSearchKeyboard(focus, isCurrent: () => current);
    current = false;
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
    final context = tester.element(find.byType(TextField));
    final closed = showDialog<void>(context: context,
      builder: (_) => const AlertDialog(content: Text('Other task')));
    await tester.pumpAndSettle();
    tester.testTextInput.hide();
    requestSearchKeyboard(focus, isCurrent: () => true);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
    Navigator.of(tester.element(find.byType(AlertDialog))).pop();
    await tester.pumpAndSettle(); await closed;
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
