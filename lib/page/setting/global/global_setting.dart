import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/i18n_helper.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comic_read/widgets/settings/reader_settings_sheet.dart';
import 'package:zephyr/page/video/video_playback_settings_page.dart';
import 'package:zephyr/page/setting/download/download_settings_page.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/setting/common/setting_page_route.dart';
import 'package:zephyr/page/setting/global/appearance_setting_page.dart';
import 'package:zephyr/page/setting/global/content_network_setting_page.dart';
import 'package:zephyr/page/setting/global/app_behavior_setting_page.dart';
import 'package:zephyr/page/setting/global/notification_setting_page.dart';
import 'package:zephyr/page/setting/global/eink_setting_page.dart';
import 'package:zephyr/page/setting/global/storage_setting_page.dart';
import 'package:zephyr/page/setting/global/debug_setting_page.dart';
import 'package:zephyr/page/setting/real_sr/real_sr_setting_page.dart';
import 'package:zephyr/page/setting/real_sr/service/real_sr_super_resolution.dart';

@RoutePage()
class GlobalSettingPage extends StatefulWidget {
  const GlobalSettingPage({super.key});

  @override
  State<GlobalSettingPage> createState() => _GlobalSettingPageState();
}

class _GlobalSettingPageState extends State<GlobalSettingPage> {
  late final Future<bool> _realSrAvailable;

  @override
  void initState() {
    super.initState();
    _realSrAvailable = RealSrSuperResolution.isDeviceSupported;
  }

  Future<void> _openSubPage(PageRouteInfo route, WidgetBuilder builder) async {
    await openSettingPage(context, route: route, builder: builder);
    if (mounted) setState(() {});
  }

  String _themeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => t.common.followSystem,
      ThemeMode.light => t.common.lightMode,
      ThemeMode.dark => t.common.darkMode,
    };
  }

  String _languageLabel(GlobalSettingState state) {
    if (state.localeFollowsSystem) return t.settings.followSystemLanguage;
    return I18nHelper.displayName(
      I18nHelper.toAppLocale(state.locale) ?? AppLocale.enUs,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GlobalSettingCubit>().state;

    return SettingPageShell(
      grouped: true,
      title: t.settings.globalTitle,
      child: FutureBuilder<bool>(
        future: _realSrAvailable,
        builder: (context, snapshot) => _settingsList(
          context,
          state,
          realSrAvailable: snapshot.data == true,
        ),
      ),
    );
  }

  Widget _settingsList(
    BuildContext context,
    GlobalSettingState state, {
    required bool realSrAvailable,
  }) => SettingListView(
    children: [
      settingCategoryTile(
        icon: Icons.palette_outlined,
        symbol: 'paintpalette',
        title: t.settings.appearance,
        subtitle: '${_languageLabel(state)} · ${_themeLabel(state.themeMode)}',
        onTap: () => _openSubPage(
          const AppearanceSettingRoute(),
          (_) => const AppearanceSettingPage(),
        ),
      ),
      const Divider(height: 1, thickness: 0.3),
      settingCategoryTile(
        icon: Icons.menu_book_outlined,
        symbol: 'book',
        title: t.reader.settings,
        subtitle: '${t.reader.readingMode} · ${t.reader.doubleTapAction}',
        onTap: () => showReaderSettingsSheet(context),
      ),
      const Divider(height: 1, thickness: 0.3),
      settingCategoryTile(
        icon: Icons.video_settings_outlined,
        symbol: 'film',
        title: t.videoPlayback.playbackSettings,
        subtitle: t.videoPlayback.hostSettingsScope,
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const VideoPlaybackSettingsPage()),
        ),
      ),
      const Divider(height: 1, thickness: 0.3),
      settingCategoryTile(
        icon: Icons.download_outlined,
        symbol: 'arrow.down.circle',
        title: t.download.settings,
        subtitle: t.download.settingsSummary,
        onTap: () => openDownloadSettings(context),
      ),
      const Divider(height: 1, thickness: 0.3),
      settingCategoryTile(
        icon: Icons.notifications_outlined,
        symbol: 'bell',
        title: t.notification.settingsTitle,
        subtitle: t.notification.settingsSummary,
        onTap: () => openNotificationSettings(context),
      ),
      const Divider(height: 1, thickness: 0.3),
      settingCategoryTile(
        icon: Icons.tune_outlined,
        symbol: 'slider.horizontal.3',
        title: t.settings.contentAndNetwork,
        subtitle: '${t.settings.maskedKeywords} · ${t.settings.proxy}',
        onTap: () => _openSubPage(
          const ContentNetworkSettingRoute(),
          (_) => const ContentNetworkSettingPage(),
        ),
      ),
      const Divider(height: 1, thickness: 0.3),
      settingCategoryTile(
        icon: Icons.settings_outlined,
        symbol: 'gearshape',
        title: t.settings.appBehavior,
        subtitle:
            '${t.settings.splashPage} · ${t.settings.mainNavigation.title}',
        onTap: () => _openSubPage(
          const AppBehaviorSettingRoute(),
          (_) => const AppBehaviorSettingPage(),
        ),
      ),
      const Divider(height: 1, thickness: 0.3),
      settingCategoryTile(
        icon: Icons.tablet_mac_outlined,
        symbol: 'ipad',
        title: t.settings.eink,
        subtitle: state.eInkSetting.enabled
            ? '${t.settings.einkEnabled} · ${state.eInkSetting.refreshMode.label}'
            : t.settings.einkSubtitle,
        onTap: () => _openSubPage(
          const EInkSettingRoute(),
          (_) => const EInkSettingPage(),
        ),
      ),
      const Divider(height: 1, thickness: 0.3),
      settingCategoryTile(
        icon: Icons.storage_outlined,
        symbol: 'internaldrive',
        title: t.settings.storage,
        subtitle: '${t.settings.cache} · ${t.settings.dataBackup}',
        onTap: () => _openSubPage(
          const StorageSettingRoute(),
          (_) => const StorageSettingPage(),
        ),
      ),
      if (realSrAvailable)
        settingCategoryTile(
          icon: Icons.auto_fix_high_outlined,
          symbol: 'wand.and.stars',
          title: t.settings.realSr,
          subtitle: t.settings.realSrSubtitle,
          onTap: () => _openSubPage(
            const RealSrSettingRoute(),
            (_) => const RealSrSettingPage(),
          ),
        ),
      const Divider(height: 1, thickness: 0.3),
      settingCategoryTile(
        icon: Icons.bug_report_outlined,
        symbol: 'ladybug',
        title: t.settings.debug,
        subtitle: t.settings.logAddress,
        onTap: () => _openSubPage(
          const DebugSettingRoute(),
          (_) => const DebugSettingPage(),
        ),
      ),
    ],
  );
}
