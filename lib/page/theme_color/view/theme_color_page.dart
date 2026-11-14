import 'package:auto_route/annotations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/config/global/color_theme_types.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/theme_color/theme_color.dart';

@RoutePage()
class ThemeColorPage extends StatelessWidget {
  const ThemeColorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentColor = context.select<GlobalSettingCubit, Color>(
      (cubit) => cubit.state.seedColor,
    );
    void setThemeColor(Color color) {
      final cubit = context.read<GlobalSettingCubit>();
      if (cubit.state.seedColor == color) return;
      cubit.updateState((current) => current.copyWith(seedColor: color));
    }

    return Scaffold(
      appBar: AppBar(
        leading: const SourceBackButton(),
        title: Text(t.settings.themeColor),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 颜色选择器
            ColorPickerPage(
              currentColor: currentColor,
              onColorChanged: setThemeColor,
            ),
            // 颜色块网格
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Wrap(
                spacing: 16.0,
                runSpacing: 16.0,
                children: colorThemeList.map((colorInfo) {
                  return ColorThemeItem(
                    colorInfo: colorInfo,
                    currentColor: currentColor,
                    onColorSelected: (color) {
                      FocusScope.of(context).unfocus();
                      setThemeColor(color);
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
