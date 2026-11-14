import 'package:zephyr/page/setting/common/setting_page_route.dart';
import 'package:zephyr/debug/show_color.dart';
import 'package:zephyr/debug/qjs_runtime_debug_page.dart';
import 'package:zephyr/debug/coreml_upscale_debug_page.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/src/rust/api/qjs.dart';
import 'package:zephyr/util/impeller_config.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/main.dart' show logForwarding;
import 'package:zephyr/widgets/breeze_switch.dart';

@RoutePage()
class DebugSettingPage extends StatefulWidget {
  const DebugSettingPage({super.key});

  @override
  State<DebugSettingPage> createState() => _DebugSettingPageState();
}

class _DebugSettingPageState extends State<DebugSettingPage> {
  bool _savingLogAddress = false;
  @override
  void initState() {
    super.initState();
    _loadImpellerConfig();
  }

  Future<void> _loadImpellerConfig() async {
    final supported = await ImpellerConfig.isForceEnableSupported();
    final forceEnableImpeller = supported
        ? await ImpellerConfig.getForceEnableImpeller()
        : false;

    if (!mounted) return;

    final cubit = context.read<GlobalSettingCubit>();
    if (cubit.state.forceEnableImpeller != forceEnableImpeller) {
      cubit.updateState(
        (current) => current.copyWith(forceEnableImpeller: forceEnableImpeller),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<GlobalSettingCubit>();
    final state = cubit.state;

    return SettingPageShell(
      grouped: true,
      title: t.settings.debug,
      child: SettingListView(
        children: [
          settingSectionTitle(
            context,
            t.settings.debug,
            icon: Icons.bug_report_outlined,
          ),
          _logAddress(state, cubit),
          _enableMemoryDebug(state, cubit),
          _blockRustHttpRequests(state, cubit),
          if (defaultTargetPlatform == TargetPlatform.android)
            _forceEnableImpeller(state, cubit),
          if (kDebugMode) ...[
            TouchHoverIntent(
              identity: 'debug_setting_page:0',
              builder: (context, hover) => ListTile(
                hoverColor: hover.hoverColor(),
                leading: const Icon(Icons.colorize_outlined),
                title: Text(t.settings.colorPreview),
                subtitle: Text(t.settings.colorPreviewSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openSettingPage(
                  context,
                  route: const ShowColorRoute(),
                  builder: (_) => const ShowColorPage(),
                ),
              ),
            ),
            TouchHoverIntent(
              identity: 'debug_setting_page:1',
              builder: (context, hover) => ListTile(
                hoverColor: hover.hoverColor(),
                leading: const Icon(Icons.developer_mode_outlined),
                title: Text(t.settings.qjsRuntimeDebug),
                subtitle: Text(t.settings.qjsRuntimeDebugSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openSettingPage(
                  context,
                  route: const QjsRuntimeDebugRoute(),
                  builder: (_) => const QjsRuntimeDebugPage(),
                ),
              ),
            ),
            TouchHoverIntent(
              identity: 'debug_setting_page:2',
              builder: (context, hover) => ListTile(
                hoverColor: hover.hoverColor(),
                leading: const Icon(Icons.memory_outlined),
                title: Text(t.settings.coremlDebug),
                subtitle: Text(t.settings.coremlDebugSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openSettingPage(
                  context,
                  route: const CoreMLUpscaleDebugRoute(),
                  builder: (_) => const CoreMLUpscaleDebugPage(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _enableMemoryDebug(
    GlobalSettingState state,
    GlobalSettingCubit cubit,
  ) {
    return TouchHoverIntent(
      identity: 'debug_setting_page.switch:0',
      builder: (context, hover) => BreezeSwitchListTile(
        SwitchListTile.adaptive(
          hoverColor: hover.hoverColor(),
          secondary: const Icon(Icons.memory_outlined),
          title: Text(t.settings.memoryDebug),
          subtitle: Text(t.settings.memoryDebugSubtitle),
          thumbIcon: settingSwitchThumbIcon(context),
          value: state.enableMemoryDebug,
          onChanged: (bool value) {
            cubit.updateState(
              (current) => current.copyWith(enableMemoryDebug: value),
            );
          },
        ),
      ),
    );
  }

  Widget _logAddress(GlobalSettingState state, GlobalSettingCubit cubit) {
    final logAddress = state.logAddress.trim();
    return TouchHoverIntent(
      identity: 'debug_setting_page:3',
      builder: (context, hover) => ListTile(
        hoverColor: hover.hoverColor(),
        leading: const Icon(Icons.link_outlined),
        title: Text(t.settings.logAddress),
        subtitle: Text(
          logAddress.isEmpty ? t.settings.logAddressSubtitle : logAddress,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: _savingLogAddress
            ? null
            : () async {
                var inputValue = logAddress;
                final result = await showDialog<String>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(t.settings.logAddress),
                    content: TextFormField(
                      initialValue: logAddress,
                      autofocus: true,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      enableSuggestions: false,
                      smartDashesType: SmartDashesType.disabled,
                      smartQuotesType: SmartQuotesType.disabled,
                      onChanged: (value) => inputValue = value.trim(),
                      decoration: const InputDecoration(
                        hintText: 'https://example.com/log',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    actions: [
                      TextButton(
                        child: Text(t.common.cancel),
                        onPressed: () => Navigator.pop(context),
                      ),
                      TextButton(
                        child: Text(t.common.ok),
                        onPressed: () => Navigator.pop(context, inputValue),
                      ),
                    ],
                  ),
                );

                if (!mounted || result == null || result == logAddress) return;
                setState(() => _savingLogAddress = true);
                try {
                  await logForwarding.save(
                    result,
                    persist: (address) => cubit.updateState(
                      (current) => current.copyWith(logAddress: address),
                    ),
                  );
                  if (mounted) showSuccessToast(t.common.settingSaved);
                } catch (_) {
                  if (mounted) showErrorToast(t.error.saveFailed);
                } finally {
                  if (mounted) setState(() => _savingLogAddress = false);
                }
              },
      ),
    );
  }

  Widget _blockRustHttpRequests(
    GlobalSettingState state,
    GlobalSettingCubit cubit,
  ) {
    return TouchHoverIntent(
      identity: 'debug_setting_page.switch:1',
      builder: (context, hover) => BreezeSwitchListTile(
        SwitchListTile.adaptive(
          hoverColor: hover.hoverColor(),
          secondary: const Icon(Icons.cloud_off_outlined),
          title: Text(t.settings.blockRustHttpRequests),
          subtitle: Text(t.settings.blockRustHttpRequestsSubtitle),
          thumbIcon: settingSwitchThumbIcon(context),
          value: state.blockRustHttpRequests,
          onChanged: (bool value) {
            setHttpRequestsBlocked(blocked: value);
            cubit.updateState(
              (current) => current.copyWith(blockRustHttpRequests: value),
            );
          },
        ),
      ),
    );
  }

  Widget _forceEnableImpeller(
    GlobalSettingState state,
    GlobalSettingCubit cubit,
  ) {
    return TouchHoverIntent(
      identity: 'debug_setting_page.switch:2',
      builder: (context, hover) => BreezeSwitchListTile(
        SwitchListTile.adaptive(
          hoverColor: hover.hoverColor(),
          secondary: const Icon(Icons.auto_awesome_outlined),
          title: Text(t.settings.forceEnableImpeller),
          subtitle: Text(t.settings.forceEnableImpellerSubtitle),
          thumbIcon: settingSwitchThumbIcon(context),
          value: state.forceEnableImpeller,
          onChanged: (bool value) async {
            cubit.updateState(
              (current) => current.copyWith(forceEnableImpeller: value),
            );
            await ImpellerConfig.setForceEnableImpeller(value);
            showSuccessToast(t.common.restartToTakeEffect);
          },
        ),
      ),
    );
  }
}
