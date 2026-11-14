import 'package:zephyr/page/setting/common/setting_page_route.dart';
import 'package:zephyr/page/theme_color/view/theme_color_page.dart';
import 'package:zephyr/page/webdav_sync/view/webdav_sync_page.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_socks_proxy/socks_proxy.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/src/rust/api/qjs.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/widgets/breeze_switch.dart';

String _proxyAddressForType(String raw, ProxyType type) {
  final value = raw.trim();
  return value.replaceFirst(
    RegExp(
      type == ProxyType.socks5 ? r'^(?:https?|socks5h?)://' : r'^socks5h?://',
    ),
    '',
  );
}

void applyGlobalProxySetting(
  ProxySettingState setting, {
  void Function(String)? setHttp,
  void Function(String)? setSocks,
  void Function(String)? setDart,
}) {
  final http = setHttp ?? (value) => setHttpProxy(proxy: value);
  final socks = setSocks ?? (value) => setSocks5Proxy(proxy: value);
  final dart = setDart ?? (value) => SocksProxy.initProxy(proxy: value);
  final address = _proxyAddressForType(setting.address, setting.type);
  if (!setting.enabled || address.isEmpty) {
    socks('');
    dart('DIRECT');
  } else if (setting.type == ProxyType.http) {
    final url = address.startsWith('http://') || address.startsWith('https://')
        ? address
        : 'http://$address';
    http(url);
    dart('PROXY ${url.replaceFirst(RegExp(r'^https?://'), '')}');
  } else {
    socks(address);
    dart('SOCKS5 ${address.replaceFirst(RegExp(r'^socks5h?://'), '')}');
  }
}

Widget changeThemeColor(BuildContext context) {
  return TouchHoverIntent(
    identity: 'widgets:0',
    builder: (context, hover) => ListTile(
      hoverColor: hover.hoverColor(),
      leading: const Icon(Icons.palette_outlined),
      title: Text(t.settings.themeColor),
      subtitle: Text(t.settings.themeColorSubtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        openSettingPage(
          context,
          route: const ThemeColorRoute(),
          builder: (_) => const ThemeColorPage(),
        );
      },
    ),
  );
}

Widget proxyToggle(
  BuildContext context, {
  required bool enabled,
  required ProxyType type,
  required String currentProxy,
  String? title,
  String? subtitle,
  void Function(ProxySettingState) applyProxy = applyGlobalProxySetting,
}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      TouchHoverIntent(
        identity: 'widgets.switch:0',
        builder: (context, hover) => BreezeSwitchListTile(
          SwitchListTile.adaptive(
            hoverColor: hover.hoverColor(),
            secondary: const Icon(Icons.router_outlined),
            title: Text(title ?? t.settings.proxy),
            subtitle: Text(subtitle ?? t.settings.proxyEnabledSubtitle),
            thumbIcon: settingSwitchThumbIcon(context),
            value: enabled,
            onChanged: (value) async {
              final globalSettingCubit = context.read<GlobalSettingCubit>();
              try {
                globalSettingCubit.updateState(
                  (current) => current.copyWith(
                    proxySetting: current.proxySetting.copyWith(enabled: value),
                  ),
                );

                applyProxy(globalSettingCubit.state.proxySetting);
                showSuccessToast(t.common.saved);
              } catch (_) {
                showErrorToast(t.error.saveFailed);
              }
            },
          ),
        ),
      ),
      SettingRowDescription(t.settings.proxyApplyScope),
      if (enabled) proxyTypeEdit(context, type, applyProxy: applyProxy),
      if (enabled)
        proxyAddressEdit(context, currentProxy, applyProxy: applyProxy),
    ],
  );
}

Widget proxyTypeEdit(
  BuildContext context,
  ProxyType type, {
  void Function(ProxySettingState) applyProxy = applyGlobalProxySetting,
}) {
  final items = <ProxyType, String>{
    ProxyType.http: t.settings.proxyTypeHttp,
    ProxyType.socks5: t.settings.proxyTypeSocks5,
  };
  return SettingChoiceTile<ProxyType>(
    leading: const Icon(Icons.lan_outlined),
    title: t.settings.proxyType,
    description: t.settings.proxyTypeSubtitle,
    value: type,
    items: items,
    onChanged: (ProxyType value) {
      if (value == type) return;
      final globalSettingCubit = context.read<GlobalSettingCubit>();
      try {
        globalSettingCubit.updateState(
          (current) => current.copyWith(
            proxySetting: current.proxySetting.copyWith(
              type: value,
              address: _proxyAddressForType(
                current.proxySetting.address,
                value,
              ),
            ),
          ),
        );
        applyProxy(globalSettingCubit.state.proxySetting);
        showSuccessToast(t.common.saved);
      } catch (_) {
        showErrorToast(t.error.saveFailed);
      }
    },
  );
}

Widget proxyAddressEdit(
  BuildContext context,
  String currentProxy, {
  void Function(ProxySettingState) applyProxy = applyGlobalProxySetting,
}) {
  return TouchHoverIntent(
    identity: 'widgets:1',
    builder: (context, hover) => ListTile(
      hoverColor: hover.hoverColor(),
      leading: const Icon(Icons.link_outlined),
      title: Text(t.settings.proxyAddress),
      subtitle: Text(
        currentProxy.isEmpty
            ? t.settings.proxySubtitle
            : t.settings.proxyCurrent(currentProxy: currentProxy),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final globalSettingCubit = context.read<GlobalSettingCubit>();
        var inputValue = currentProxy;

        final result = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(t.settings.proxyAddress),
            content: TextFormField(
              initialValue: currentProxy,
              autofocus: true,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              smartDashesType: SmartDashesType.disabled,
              smartQuotesType: SmartQuotesType.disabled,
              onChanged: (value) => inputValue = value.trim(),
              decoration: InputDecoration(
                hintText: t.settings.proxyHint,
                border: const OutlineInputBorder(),
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

        if (result != null && result != currentProxy) {
          try {
            globalSettingCubit.updateState(
              (current) => current.copyWith(
                proxySetting: current.proxySetting.copyWith(
                  address: _proxyAddressForType(
                    result,
                    current.proxySetting.type,
                  ),
                ),
              ),
            );
            applyProxy(globalSettingCubit.state.proxySetting);
            showSuccessToast(t.common.saved);
          } catch (_) {
            showErrorToast(t.error.saveFailed);
          }
        }
      },
    ),
  );
}

Widget webdavSync(
  BuildContext context,
  SyncServiceType syncServiceType, {
  bool enabled = true,
  bool showDescription = true,
}) {
  final title = switch (syncServiceType) {
    SyncServiceType.none => t.settings.syncConfig,
    _ => t.webdavSync.serviceTitle(
      service: switch (syncServiceType) {
        SyncServiceType.webdav => t.settings.syncServiceWebdav,
        SyncServiceType.s3 => t.settings.syncServiceS3,
        SyncServiceType.none => '',
      },
    ),
  };

  return TouchHoverIntent(
    identity: 'widgets:2',
    builder: (context, hover) => ListTile(
      enabled: enabled,
      hoverColor: hover.hoverColor(),
      leading: const Icon(Icons.cloud_outlined),
      title: Text(title),
      subtitle: showDescription ? Text(t.settings.syncConfigSubtitle) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: !enabled
          ? null
          : () {
              openSettingPage(
                context,
                route: const WebDavSyncRoute(),
                builder: (_) => const WebDavSyncPage(),
              );
            },
    ),
  );
}

Widget editMaskedKeywords(BuildContext context) {
  return TouchHoverIntent(
    identity: 'widgets:3',
    builder: (context, hover) => ListTile(
      hoverColor: hover.hoverColor(),
      leading: const Icon(Icons.shield_outlined),
      title: Text(t.settings.maskedKeywords),
      subtitle: Text(t.settings.maskedKeywordsSubtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => const _KeywordManagementDialog(),
        );
      },
    ),
  );
}

class _KeywordManagementDialog extends StatefulWidget {
  const _KeywordManagementDialog();

  @override
  State<_KeywordManagementDialog> createState() =>
      _KeywordManagementDialogState();
}

class _KeywordManagementDialogState extends State<_KeywordManagementDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 只需要在这里获取 Cubit
    final globalSettingCubit = context.read<GlobalSettingCubit>();

    return BlocBuilder<GlobalSettingCubit, GlobalSettingState>(
      builder: (context, state) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.settings.maskedKeywords,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t.settings.maskedKeywordsSubtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(
                    minHeight: 120,
                    maxHeight: 240,
                  ),
                  width: double.infinity,
                  child: SingleChildScrollView(
                    child: state.maskedKeywords.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 36),
                              child: Text(
                                t.settings.maskedKeywordsEmpty,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(
                              state.maskedKeywords.length,
                              (index) {
                                final keyword = state.maskedKeywords[index];
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  constraints: const BoxConstraints(
                                    maxWidth: 280,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          keyword,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onPrimaryContainer,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        child: GestureDetector(
                                          onTap: () {
                                            globalSettingCubit.updateState(
                                              (current) => current.copyWith(
                                                maskedKeywords: [
                                                  ...current.maskedKeywords,
                                                ]..remove(keyword),
                                              ),
                                            );
                                          },
                                          child: Icon(
                                            Icons.close,
                                            size: 14,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimaryContainer
                                                .withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: t.settings.maskedKeywordsInputHint,
                          hintStyle: const TextStyle(fontSize: 14),
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _addKeyword(globalSettingCubit),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: () => _addKeyword(globalSettingCubit),
                      icon: const Icon(Icons.add, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(t.common.done),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _addKeyword(GlobalSettingCubit cubit) {
    final text = _controller.text.trim();
    if (text.isEmpty || cubit.state.maskedKeywords.contains(text)) return;
    cubit.updateState(
      (current) =>
          current.copyWith(maskedKeywords: [...current.maskedKeywords, text]),
    );
    _controller.clear();
  }
}
