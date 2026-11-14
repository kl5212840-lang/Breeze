import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/service/app_icon_controller.dart';
import 'package:zephyr/widgets/current_app_icon.dart';

class AppIconSetting extends StatefulWidget {
  const AppIconSetting({super.key, this.controller});
  final AppIconController? controller;
  @override
  State<AppIconSetting> createState() => _AppIconSettingState();
}

class _AppIconSettingState extends State<AppIconSetting> {
  AppIconController get controller =>
      widget.controller ?? AppIconController.instance;
  @override
  void initState() {
    super.initState();
    controller.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (!controller.supported) return const SizedBox.shrink();
      final chinese = Localizations.localeOf(context).languageCode == 'zh';
      return SettingChoiceTile<String>(
        key: const ValueKey('settings.app-icon'),
        leading: CurrentAppIcon(size: 28, controller: controller),
        title: chinese ? '应用图标' : 'App Icon',
        value: controller.iconName,
        items: {
          '': 'Breeze',
          AppIconController.classicName: chinese ? '插画' : 'Illustration',
        },
        enabled: !controller.changing,
        error: controller.failed
            ? (chinese
                  ? '无法切换应用图标，请重试'
                  : 'Could not change the app icon. Try again.')
            : null,
        onChanged: (name) async {
          await controller.select(name);
        },
      );
    },
  );
}
