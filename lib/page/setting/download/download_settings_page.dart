import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/donwload_task/view/download_storage_status.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/widgets/interface_symbol.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';
import 'package:zephyr/page/video/video_page_route.dart';
import 'package:zephyr/service/download/download_admission.dart';
import 'package:zephyr/widgets/breeze_switch.dart';

Future<void> openDownloadSettings(BuildContext context) =>
    Navigator.of(context, rootNavigator: true).push<void>(
      videoPageRoute<void>(
        settings: const RouteSettings(name: 'breeze.download.settings'),
        builder: (_) => const DownloadSettingsPage(),
      ),
    );

class DownloadSettingsPage extends StatelessWidget {
  const DownloadSettingsPage({super.key});
  @override
  Widget build(BuildContext context) => DownloadStorageStatus(
    builder: (context, used, available) =>
        BlocBuilder<GlobalSettingCubit, GlobalSettingState>(
          builder: (context, state) {
            final cubit = context.read<GlobalSettingCubit>();
            return SettingPageShell(
              grouped: true,
              title: t.download.settings,
              child: SettingListView(
                children: [
                  if (DownloadAdmission.supportsMobileControls)
                    SettingChoiceTile<int>(
                      key: const ValueKey('download-concurrency'),
                      leading: const InterfaceSymbol(
                        symbol: 'arrow.down.circle',
                        fallback: Icons.downloading_rounded,
                      ),
                      title: t.download.concurrentVideos,
                      value: state.videoDownloadConcurrency.clamp(1, 3),
                      valueIsFallback:
                          state.videoDownloadConcurrency < 1 ||
                          state.videoDownloadConcurrency > 3,
                      items: const {1: '1', 2: '2', 3: '3'},
                      onChanged: (value) => cubit.updateState(
                        (current) =>
                            current.copyWith(videoDownloadConcurrency: value),
                      ),
                    ),
                  if (DownloadAdmission.supportsMobileControls)
                    _DownloadSwitchRow(
                      controlKey: const ValueKey('download-wifi-only'),
                      secondary: const InterfaceSymbol(
                        symbol: 'wifi',
                        fallback: Icons.wifi_rounded,
                      ),
                      title: Text(t.download.wifiOnly),
                      value: state.downloadWifiOnly,
                      onChanged: (enabled) => cubit.updateState(
                        (current) =>
                            current.copyWith(downloadWifiOnly: enabled),
                      ),
                    ),
                  _DownloadSwitchRow(
                    controlKey: const ValueKey('download-keep-retrying'),
                    secondary: const InterfaceSymbol(
                      symbol: 'arrow.down.circle',
                      fallback: Icons.download_outlined,
                    ),
                    title: Text(t.settings.retryDownloadUntilSuccess),
                    subtitle: Text(
                      t.settings.retryDownloadUntilSuccessSubtitle,
                    ),
                    value: state.retryDownloadUntilSuccess,
                    onChanged: (value) => cubit.updateState(
                      (current) =>
                          current.copyWith(retryDownloadUntilSuccess: value),
                    ),
                  ),
                  settingSectionTitle(context, t.download.storageSpace),
                  ListTile(
                    key: const ValueKey('download-settings-used-space'),
                    leading: const InterfaceSymbol(
                      symbol: 'checkmark.circle',
                      fallback: Icons.download_done_rounded,
                    ),
                    title: Text(t.download.savedDownloadSpace),
                    subtitle: Text(used ?? t.common.loading),
                  ),
                  ListTile(
                    key: const ValueKey('download-settings-free-space'),
                    leading: const InterfaceSymbol(
                      symbol: 'internaldrive',
                      fallback: Icons.storage_rounded,
                    ),
                    title: Text(t.download.deviceFreeSpace),
                    subtitle: Text(available ?? t.common.loading),
                  ),
                ],
              ),
            );
          },
        ),
  );
}

/// These switches keep the same hover, focus and thumb appearance as the
/// Appearance settings, including when a page opens under a static pointer.
class _DownloadSwitchRow extends StatelessWidget {
  const _DownloadSwitchRow({
    required this.controlKey,
    required this.secondary,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final Widget secondary, title;
  final Key controlKey;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => TouchHoverIntent(
    identity: controlKey,
    builder: (context, hover) => BreezeSwitchListTile(
      SwitchListTile.adaptive(
        key: controlKey,
        hoverColor: hover.hoverColor(),
        secondary: secondary,
        title: title,
        subtitle: subtitle,
        thumbIcon: settingSwitchThumbIcon(context),
        value: value,
        onChanged: onChanged,
      ),
    ),
  );
}
