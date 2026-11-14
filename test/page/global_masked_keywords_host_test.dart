import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/setting/global/widgets.dart';

import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  testWidgets('keyword edits preserve the latest saved list across redraws', (
    tester,
  ) async {
    final cubit = GlobalSettingCubit()
      ..updateALl(const GlobalSettingState(maskedKeywords: ['one', 'two']));
    addTearDown(cubit.close);
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          home: Scaffold(body: Builder(builder: editMaskedKeywords)),
        ),
      ),
    );
    await tester.tap(find.text(t.settings.maskedKeywords));
    await tester.pumpAndSettle();

    final removeIcons = find.byIcon(Icons.close);
    await tester.tap(removeIcons.at(0));
    await tester.tap(removeIcons.at(1));
    expect(cubit.state.maskedKeywords, isEmpty);

    await tester.enterText(find.byType(TextField), 'draft');
    cubit.updateState(
      (current) => current.copyWith(
        maskedKeywords: ['restored'],
        readSetting: current.readSetting.copyWith(readMode: 2),
      ),
    );
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.common.done));
    await tester.pumpAndSettle();

    final reloaded = GlobalSettingCubit();
    addTearDown(reloaded.close);
    await reloaded.initBox();
    expect(reloaded.state.maskedKeywords, ['restored', 'draft']);
    expect(reloaded.state.readSetting.readMode, 2);
  });
}
