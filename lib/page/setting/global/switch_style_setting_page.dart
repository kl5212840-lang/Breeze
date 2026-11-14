import 'package:auto_route/auto_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/widgets/breeze_switch.dart';
import 'package:zephyr/widgets/interface_symbol.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';

String switchStyleLabel(BreezeSwitchStyle style) => switch (style) {
  BreezeSwitchStyle.classic => t.settings.switchStyles.classic,
  BreezeSwitchStyle.symbols => t.settings.switchStyles.symbols,
  BreezeSwitchStyle.ring => t.settings.switchStyles.ring,
  BreezeSwitchStyle.relief => t.settings.switchStyles.relief,
  BreezeSwitchStyle.pixel => t.settings.switchStyles.pixel,
  BreezeSwitchStyle.thumb => t.settings.switchStyles.thumb,
  BreezeSwitchStyle.power => t.settings.switchStyles.power,
  BreezeSwitchStyle.spark => t.settings.switchStyles.spark,
};

@RoutePage()
class SwitchStyleSettingPage extends StatefulWidget {
  const SwitchStyleSettingPage({super.key});

  @override
  State<SwitchStyleSettingPage> createState() => _SwitchStyleSettingPageState();
}

class _SwitchStyleSettingPageState extends State<SwitchStyleSettingPage> {
  bool _trial = false;
  bool _saveFailed = false;

  void _select(BreezeSwitchStyle style) {
    final settings = context.read<GlobalSettingCubit>();
    if (settings.state.switchStyle == style) return;
    try {
      settings.updateState((state) => state.copyWith(switchStyle: style));
      if (_saveFailed) setState(() => _saveFailed = false);
    } catch (_) {
      setState(() => _saveFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = context.select(
      (GlobalSettingCubit settings) => settings.state.switchStyle,
    );
    final strings = t.settings.switchStyles;
    return SettingPageShell(
      grouped: true,
      title: strings.title,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SettingSection(
            hasLeading: false,
            children: [
              for (final style in BreezeSwitchStyle.values)
                TouchHoverIntent(
                  identity: style,
                  builder: (context, hover) => ListTile(
                    key: ValueKey('settings.switch-style.${style.name}'),
                    selected: style == active,
                    selectedColor: Theme.of(context).colorScheme.onSurface,
                    hoverColor: hover.hoverColor(),
                    title: Text(switchStyleLabel(style)),
                    trailing: style == active
                        ? const InterfaceSymbol(
                            symbol: 'checkmark',
                            fallback: Icons.check,
                          )
                        : null,
                    onTap: () => _select(style),
                  ),
                ),
              if (_saveFailed)
                SettingRowDescription(t.error.saveFailed, isError: true),
            ],
          ),
          SettingSection(
            title: strings.preview,
            hasLeading: false,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: 16,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      for (final value in [false, true])
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(value ? t.common.on : t.common.off),
                            const SizedBox(width: 8),
                            ExcludeSemantics(
                              child: ExcludeFocus(
                                child: IgnorePointer(
                                  child: BreezeSwitch(
                                    Switch.adaptive(
                                      value: value,
                                      onChanged: (_) {},
                                      thumbIcon: settingSwitchThumbIcon(
                                        context,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              TouchHoverIntent(
                builder: (context, hover) => BreezeSwitchListTile(
                  SwitchListTile.adaptive(
                    key: const ValueKey('settings.switch-style.trial'),
                    title: Text(strings.trySwitch),
                    hoverColor: hover.hoverColor(),
                    value: _trial,
                    thumbIcon: settingSwitchThumbIcon(context),
                    onChanged: (value) => setState(() => _trial = value),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
