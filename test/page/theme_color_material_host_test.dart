import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/page/theme_color/view/theme_color_page.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  for (final brightness in Brightness.values) {
    testWidgets('theme color input renders and persists in $brightness', (
      tester,
    ) async {
      final cubit = GlobalSettingCubit();
      final style = ValueNotifier('breeze');
      addTearDown(cubit.close);
      addTearDown(style.dispose);
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: AppInterfaceStyleScope(
            style: style,
            child: MaterialApp(
              theme: ThemeData(brightness: brightness),
              builder: (_, child) =>
                  // Match the real app bridge; it provides theme/localizations,
                  // not the Material ancestor required by a legacy TextField.
                  // ignore: deprecated_member_use
                  MaterialUiCompatibilityBridge(child: child!),
              home: const ThemeColorPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final ring = find.byType(ColorPickerHueRing);
      final ringSize = tester.getSize(ring);
      expect(ringSize.width, greaterThan(100));
      expect(ringSize.height, greaterThan(100));
      final beforeHue = cubit.state.seedColor;
      await tester.tapAt(
        tester.getTopLeft(ring) + Offset(ringSize.width / 2, 10),
      );
      await tester.pumpAndSettle();
      expect(cubit.state.seedColor, isNot(beforeHue));
      final input = find.byKey(const ValueKey('theme-color.hex'));
      expect(input, findsOneWidget);
      expect(Theme.of(tester.element(input)).brightness, brightness);
      await tester.ensureVisible(input);
      await tester.tap(input);
      await tester.pumpAndSettle();
      await tester.enterText(input, '1267AB');
      expect(
        tester.widget<TextField>(input).controller!.text,
        '1267AB',
        reason:
            'The real color input accepts editing before persistence is checked',
      );
      await tester.pumpAndSettle();
      expect(cubit.state.seedColor.toARGB32(), 0xFF1267AB);
      expect(
        objectbox.userSettingBox.get(1)!.globalSetting.seedColor.toARGB32(),
        0xFF1267AB,
      );
      final redPreset = find.text('红色');
      await tester.ensureVisible(redPreset);
      await tester.tap(redPreset);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(input).controller!.text.toUpperCase(),
        '#F44336',
        reason: 'Choosing a preset ends Hex editing and refreshes its value',
      );
      style.value = 'system';
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<TextField>(input).controller!.text.toUpperCase(),
        '#F44336',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
