import 'package:zephyr/widgets/touch_hover_intent.dart';
import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/widgets/interface_symbol.dart';
import 'package:zephyr/page/setting/global/widgets.dart';
import 'package:zephyr/page/setting/network/routing_rules_page.dart';

@RoutePage()
class ContentNetworkSettingPage extends StatelessWidget {
  const ContentNetworkSettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<GlobalSettingCubit>();
    final state = cubit.state;

    return SettingPageShell(
      grouped: true,
      title: t.settings.contentAndNetwork,
      child: SettingListView(
        children: [
          settingSectionTitle(
            context,
            t.settings.content,
            icon: Icons.filter_alt_outlined,
          ),
          editMaskedKeywords(context),
          _chineseConvertMode(state, cubit),

          const SizedBox(height: 8),
          const Divider(height: 1, thickness: 0.3),
          settingSectionTitle(
            context,
            t.settings.network,
            icon: Icons.wifi_outlined,
          ),
          TouchHoverIntent(
            identity: 'content_network_setting_page:0',
            builder: (context, hover) => ListTile(
              hoverColor: hover.hoverColor(),
              leading: const InterfaceSymbol(
                symbol: 'arrow.triangle.branch',
                fallback: Icons.alt_route_rounded,
              ),
              title: Text(t.routingRules.title),
              subtitle: Text(t.routingRules.entryHint),
              trailing: const InterfaceSymbol(
                symbol: 'chevron.right',
                fallback: Icons.chevron_right,
              ),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const RoutingRulesPage()),
              ),
            ),
          ),
          proxyToggle(
            context,
            enabled: state.proxySetting.enabled,
            type: state.proxySetting.type,
            currentProxy: state.proxySetting.address,
            title: t.routingRules.internalProxy,
            subtitle: t.routingRules.internalHint,
          ),
          // _updateAccelerate(state, cubit),
        ],
      ),
    );
  }

  Widget _chineseConvertMode(
    GlobalSettingState state,
    GlobalSettingCubit cubit,
  ) {
    final chineseConvertItems = <ChineseConvertMode, String>{
      ChineseConvertMode.off: t.settings.chineseConvertOff,
      ChineseConvertMode.simplified: t.settings.chineseConvertSimplified,
      ChineseConvertMode.traditional: t.settings.chineseConvertTraditional,
    };

    return SettingChoiceTile<ChineseConvertMode>(
      leading: const InterfaceSymbol(
        symbol: 'character.bubble',
        fallback: Icons.translate_outlined,
      ),
      title: t.settings.chineseConvert,
      description: t.settings.chineseConvertSubtitle,
      value: state.chineseConvertMode,
      items: chineseConvertItems,
      onChanged: (ChineseConvertMode value) {
        if (value == state.chineseConvertMode) return;
        cubit.updateState(
          (current) => current.copyWith(chineseConvertMode: value),
        );
      },
    );
  }

  // Widget _updateAccelerate(GlobalSettingState state, GlobalSettingCubit cubit) {
  //   return SwitchListTile.adaptive(
  //     secondary: const Icon(Icons.rocket_launch_outlined),
  //     title: Text(t.settings.updateAccelerate),
  //     subtitle: Text(t.settings.updateAccelerateSubtitle),
  //     thumbIcon: kSettingSwitchThumbIcon,
  //     value: state.updateAccelerate,
  //     onChanged: (bool value) {
  //       cubit.updateState(
  //         (current) => current.copyWith(updateAccelerate: value),
  //       );
  //     },
  //   );
  // }
}
