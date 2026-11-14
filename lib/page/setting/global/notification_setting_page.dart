import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comic_follow/widgets/comic_follow_reminder_widgets.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/widgets/interface_symbol.dart';
import 'package:zephyr/page/video/video_page_route.dart';
import 'package:zephyr/service/checkin/auto_checkin_notices.dart';
import 'package:zephyr/service/comic_follow/comic_follow_reminders.dart';
import 'package:zephyr/service/update/app_update_reminder_preferences.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';
import 'package:zephyr/widgets/breeze_switch.dart';

Future<void> openNotificationSettings(BuildContext context) =>
    Navigator.of(context, rootNavigator: true).push<void>(
      videoPageRoute<void>(
        settings: const RouteSettings(name: 'breeze.notifications.settings'),
        builder: (_) => const NotificationSettingPage(),
      ),
    );

class NotificationSettingPage extends StatefulWidget {
  const NotificationSettingPage({super.key});

  @override
  State<NotificationSettingPage> createState() =>
      _NotificationSettingPageState();
}

class _NotificationSettingPageState extends State<NotificationSettingPage> {
  final _autoCheckin = AutoCheckinNotices.instance;
  bool _autoCheckinSaving = false;
  final _followReminders = ComicFollowReminderController.instance;
  AppUpdateReminderPreferences? _updateReminder;
  bool _updateReminderSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUpdateReminder();
    _loadAutoCheckin();
    _followReminders.load().catchError((Object _) {});
  }

  Future<void> _loadAutoCheckin() async {
    try {
      await _autoCheckin.load();
    } catch (_) {
      if (mounted) showErrorToast(t.error.loadFailed, context: context);
    }
  }

  Future<void> _setAutoCheckin(bool enabled) async {
    if (_autoCheckinSaving) return;
    setState(() => _autoCheckinSaving = true);
    try {
      await _autoCheckin.setEnabled(enabled);
    } catch (_) {
      if (mounted) showErrorToast(t.error.saveFailed, context: context);
    } finally {
      if (mounted) setState(() => _autoCheckinSaving = false);
    }
  }

  Future<void> _loadUpdateReminder() async {
    try {
      final preferences = await AppUpdateReminderPreferences.load();
      if (mounted) setState(() => _updateReminder = preferences);
    } catch (_) {
      if (mounted) showErrorToast(t.error.loadFailed, context: context);
    }
  }

  Future<void> _setUpdateReminder(bool enabled) async {
    final preferences = _updateReminder;
    if (preferences == null || _updateReminderSaving) return;
    setState(() => _updateReminderSaving = true);
    try {
      await preferences.setEnabled(enabled);
    } catch (_) {
      if (mounted) showErrorToast(t.error.saveFailed, context: context);
    } finally {
      if (mounted) setState(() => _updateReminderSaving = false);
    }
  }

  Widget _comicFollowRow(ComicFollowReminderMode? mode) {
    final title = t.notification.comicFollowTitle;
    final summary = switch (mode) {
      ComicFollowReminderMode.silent => t.followReminders.modeSilent,
      ComicFollowReminderMode.badge => t.followReminders.modeBadge,
      ComicFollowReminderMode.inApp => t.followReminders.modeInAppSummary,
      null => null,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final theme = Theme.of(context);
        final tile = ListTileTheme.of(context);
        final titleStyle = tile.titleTextStyle ?? theme.textTheme.bodyLarge;
        final valueStyle = theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );
        final gap = tile.horizontalTitleGap ?? 16;
        final leading = tile.minLeadingWidth ?? (theme.useMaterial3 ? 24 : 40);
        const chevronSize = 22.0;
        const valueGap = 8.0;
        double measure(String text, TextStyle? style) =>
            TextPainter.computeWidth(
              text: TextSpan(text: text, style: style),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
              maxLines: 1,
            ).ceilToDouble();
        final available =
            constraints.maxWidth -
            (tile.contentPadding?.horizontal ?? 32) -
            leading -
            2 * gap -
            chevronSize -
            valueGap;
        final inline =
            summary != null &&
            measure(title, titleStyle) + measure(summary, valueStyle) <=
                available;
        final value = summary == null ? null : Text(summary, style: valueStyle);

        return TouchHoverIntent(
          identity: 'notification-settings.comic-follow',
          builder: (context, hover) => ListTile(
            key: const ValueKey('notification-settings.comic-follow'),
            hoverColor: hover.hoverColor(),
            leading: const InterfaceSymbol(
              symbol: 'book',
              fallback: Icons.auto_stories_outlined,
            ),
            title: Text(title),
            subtitle: inline ? null : value,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (inline) ...[value!, const SizedBox(width: valueGap)],
                const InterfaceSymbol(
                  symbol: 'chevron.right',
                  fallback: Icons.chevron_right,
                  size: chevronSize,
                ),
              ],
            ),
            onTap: () => showComicFollowReminderSettings(context),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<GlobalSettingCubit>();
    final state = cubit.state;
    const modes = {'episode', 'work', 'off'};
    final completionMode = modes.contains(state.downloadCompletionNotice)
        ? state.downloadCompletionNotice
        : 'work';

    return SettingPageShell(
      grouped: true,
      title: t.notification.settingsTitle,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SettingSection(
            footer: t.notification.comicDownloadDescription,
            children: [
              TouchHoverIntent(
                identity: 'notification-settings.app-update',
                builder: (context, hover) => BreezeSwitchListTile(
                  SwitchListTile.adaptive(
                    key: const ValueKey('notification-settings.app-update'),
                    hoverColor: hover.hoverColor(),
                    secondary: const InterfaceSymbol(
                      symbol: 'arrow.down.to.line',
                      fallback: Icons.system_update_outlined,
                    ),
                    title: Text(t.update.reminder),
                    thumbIcon: settingSwitchThumbIcon(context),
                    value: _updateReminder?.enabled ?? true,
                    onChanged: _updateReminder == null || _updateReminderSaving
                        ? null
                        : _setUpdateReminder,
                  ),
                ),
              ),
              SettingChoiceTile<String>(
                key: const ValueKey(
                  'notification-settings.download-completion',
                ),
                leading: const InterfaceSymbol(
                  symbol: 'checkmark.circle',
                  fallback: Icons.download_done_outlined,
                ),
                title: t.download.completionNotice,
                value: completionMode,
                valueIsFallback:
                    completionMode != state.downloadCompletionNotice,
                items: {
                  'episode': t.download.noticeEpisode,
                  'work': t.download.noticeWork,
                  'off': t.download.noticeOff,
                },
                onChanged: (value) => cubit.updateState(
                  (current) =>
                      current.copyWith(downloadCompletionNotice: value),
                ),
              ),
              ValueListenableBuilder<ComicFollowReminderMode?>(
                valueListenable: _followReminders.mode,
                builder: (context, mode, _) => _comicFollowRow(mode),
              ),
              ValueListenableBuilder<bool?>(
                valueListenable: _autoCheckin.enabled,
                builder: (context, enabled, _) => TouchHoverIntent(
                  identity: 'notification-settings.auto-checkin',
                  builder: (context, hover) => BreezeSwitchListTile(
                    SwitchListTile.adaptive(
                      key: const ValueKey('notification-settings.auto-checkin'),
                      hoverColor: hover.hoverColor(),
                      secondary: const InterfaceSymbol(
                        symbol: 'calendar.badge.checkmark',
                        fallback: Icons.event_available_outlined,
                      ),
                      title: Text(t.notification.checkinResult),
                      subtitle: Text(t.notification.checkinResultDescription),
                      thumbIcon: settingSwitchThumbIcon(context),
                      value: enabled ?? true,
                      onChanged: enabled == null || _autoCheckinSaving
                          ? null
                          : _setAutoCheckin,
                    ),
                  ),
                ),
              ),
              TouchHoverIntent(
                identity: 'notification-settings.sync',
                builder: (context, hover) => BreezeSwitchListTile(
                  SwitchListTile.adaptive(
                    key: const ValueKey('notification-settings.sync'),
                    hoverColor: hover.hoverColor(),
                    secondary: const InterfaceSymbol(
                      symbol: 'arrow.triangle.2.circlepath',
                      fallback: Icons.cloud_sync_outlined,
                    ),
                    title: Text(t.settings.syncNotify),
                    thumbIcon: settingSwitchThumbIcon(context),
                    value: state.syncSetting.syncNotify,
                    onChanged: (enabled) => cubit.updateSyncSetting(
                      (current) => current.copyWith(syncNotify: enabled),
                    ),
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
