import 'package:zephyr/widgets/touch_hover_intent.dart';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/navigation/main_navigation_layout.dart';
import 'package:zephyr/page/navigation/welcome_page_destination.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/setting/bookshelf/bookshelf_setting_page.dart';
import 'package:zephyr/widgets/interface_symbol.dart';
import 'package:zephyr/platform/desktop/window_logic.dart';
import 'package:zephyr/service/lifecycle/foreground_task/foreground_task_service.dart';
import 'package:zephyr/widgets/gesture_lock.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/page/source_shell/source_return_preferences.dart';
import 'package:zephyr/page/source_shell/source_return_mode_tile.dart';
import 'package:zephyr/widgets/breeze_switch.dart';

@RoutePage()
class AppBehaviorSettingPage extends StatefulWidget {
  const AppBehaviorSettingPage({super.key});

  @override
  State<AppBehaviorSettingPage> createState() => _AppBehaviorSettingPageState();
}

class _AppBehaviorSettingPageState extends State<AppBehaviorSettingPage> {
  DesktopCloseBehavior _desktopCloseBehavior = DesktopCloseBehavior.ask;
  bool _desktopSaving = false;
  String? _desktopError;

  List<String> _splashPageList() => [
    t.navigation.discover,
    t.navigation.bookshelf,
    t.common.download,
    t.navigation.more,
  ];

  Map<String, int> _splashPageMap() => {
    t.navigation.discover: storedWelcomePageValue(
      WelcomePageDestination.discover,
      oldPageRollbackEnabled: false,
    ),
    t.navigation.bookshelf: storedWelcomePageValue(
      WelcomePageDestination.bookshelf,
      oldPageRollbackEnabled: false,
    ),
    t.common.download: storedWelcomePageValue(
      WelcomePageDestination.downloads,
      oldPageRollbackEnabled: false,
    ),
    t.navigation.more: storedWelcomePageValue(
      WelcomePageDestination.more,
      oldPageRollbackEnabled: false,
    ),
  };

  @override
  void initState() {
    super.initState();
    SourceReturnPreferences.load();
    _loadDesktopCloseBehavior();
  }

  Future<void> _loadDesktopCloseBehavior() async {
    if (!isDesktop) return;
    final value = await WindowLogic.loadCloseBehavior();
    if (!mounted) return;
    setState(() => _desktopCloseBehavior = value);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<GlobalSettingCubit>();
    final state = cubit.state;

    return SettingPageShell(
      grouped: true,
      title: t.settings.appBehavior,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _mainNavigation(state, cubit),
          SettingSection(
            children: [
              _splashPage(state, cubit),
              const BookshelfDefaultSectionTile(),
              const SourceReturnModeTile(),
            ],
          ),
          SettingSection(
            children: [
              if (isDesktop) _desktopCloseBehaviorTile(),
              if (Platform.isAndroid) _androidKeepAlive(state, cubit),
              if (Platform.isAndroid) _backPressExit(state, cubit),
              _appLockSetting(state, cubit),
              _cloudFavoritePreferred(state, cubit),
              _autoFollowOnCollect(state, cubit),
              _leftHandMode(state, cubit),
              _clickCoverToStartReading(state, cubit),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mainNavigation(GlobalSettingState state, GlobalSettingCubit cubit) {
    final layout = MainNavigationLayout.decode(state.mainNavigationSlots);
    final labels = t.settings.mainNavigation;
    return SettingSection(
      title: labels.title,
      footer: labels.hiddenHint,
      children: [
        for (final shortcut in MainNavigationShortcut.values)
          BreezeSwitchListTile(
            key: ValueKey('settings.main-navigation.${shortcut.name}'),
            SwitchListTile.adaptive(
              secondary: shortcut == MainNavigationShortcut.follow
                  ? const InterfaceSymbol(
                      symbol: 'bell',
                      fallback: Icons.notifications_none_rounded,
                    )
                  : const InterfaceSymbol(
                      symbol: 'arrow.down.circle',
                      fallback: Icons.download_outlined,
                    ),
              title: Text(
                shortcut == MainNavigationShortcut.follow
                    ? t.comicFollow.title
                    : t.common.download,
              ),
              thumbIcon: settingSwitchThumbIcon(context),
              value: layout.positionOf(shortcut) != MainNavigationPosition.more,
              onChanged: (visible) => cubit.updateState((current) {
                final saved = MainNavigationLayout.decode(
                  current.mainNavigationSlots,
                );
                final alreadyVisible =
                    saved.positionOf(shortcut) != MainNavigationPosition.more;
                if (visible == alreadyVisible) return current;
                return current.copyWith(
                  mainNavigationSlots: saved
                      .withPosition(
                        shortcut,
                        visible
                            ? MainNavigationPosition.right
                            : MainNavigationPosition.more,
                      )
                      .encoded,
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _splashPage(GlobalSettingState state, GlobalSettingCubit cubit) {
    final splashPageList = _splashPageList();
    final splashPage = _splashPageMap();
    final selectedIndex = welcomePageTabIndex(
      resolveWelcomePageDestination(
        state.welcomePageNum,
        oldPageRollbackEnabled: false,
      ),
      oldPageRollbackEnabled: false,
    );

    final splashPageItems = {for (final page in splashPageList) page: page};

    return SettingChoiceTile<String>(
      leading: const InterfaceSymbol(
        symbol: 'paperplane',
        fallback: Icons.rocket_launch_outlined,
      ),
      title: t.settings.splashPage,
      value: splashPageList[selectedIndex],
      items: splashPageItems,
      onChanged: (String value) {
        if (value == splashPageList[selectedIndex]) return;
        cubit.updateState(
          (current) => current.copyWith(welcomePageNum: splashPage[value]!),
        );
        showSuccessToast(t.common.restartToTakeEffect);
      },
    );
  }

  Widget _cloudFavoritePreferred(
    GlobalSettingState state,
    GlobalSettingCubit cubit,
  ) {
    return TouchHoverIntent(
      identity: 'app_behavior_setting_page.switch:1',
      builder: (context, hover) => BreezeSwitchListTile(
        SwitchListTile.adaptive(
          hoverColor: hover.hoverColor(),
          secondary: const InterfaceSymbol(
            symbol: 'cloud',
            fallback: Icons.cloud_outlined,
          ),
          title: Text(t.settings.cloudFavoritePreferred),
          subtitle: Text(t.settings.cloudFavoritePreferredSubtitle),
          thumbIcon: settingSwitchThumbIcon(context),
          value: state.cloudFavoritePreferred,
          onChanged: (bool value) {
            cubit.updateState(
              (current) => current.copyWith(cloudFavoritePreferred: value),
            );
            showSuccessToast(t.common.settingSaved);
          },
        ),
      ),
    );
  }

  Widget _autoFollowOnCollect(
    GlobalSettingState state,
    GlobalSettingCubit cubit,
  ) {
    return TouchHoverIntent(
      identity: 'app_behavior_setting_page.switch:2',
      builder: (context, hover) => BreezeSwitchListTile(
        SwitchListTile.adaptive(
          hoverColor: hover.hoverColor(),
          secondary: const InterfaceSymbol(
            symbol: 'bell.badge',
            fallback: Icons.notifications_active_outlined,
          ),
          title: Text(t.settings.autoFollowOnCollect),
          subtitle: Text(t.settings.autoFollowOnCollectSubtitle),
          thumbIcon: settingSwitchThumbIcon(context),
          value: state.autoFollowOnCollect,
          onChanged: (bool value) {
            cubit.updateState(
              (current) => current.copyWith(autoFollowOnCollect: value),
            );
            showSuccessToast(t.common.settingSaved);
          },
        ),
      ),
    );
  }

  Widget _leftHandMode(GlobalSettingState state, GlobalSettingCubit cubit) {
    return TouchHoverIntent(
      identity: 'app_behavior_setting_page.switch:3',
      builder: (context, hover) => BreezeSwitchListTile(
        SwitchListTile.adaptive(
          hoverColor: hover.hoverColor(),
          secondary: const InterfaceSymbol(
            symbol: 'space',
            fallback: Icons.space_bar_rounded,
          ),
          title: Text(t.settings.leftHandMode),
          subtitle: Text(t.settings.leftHandModeSubtitle),
          thumbIcon: settingSwitchThumbIcon(context),
          value: state.leftHandModeEnabled,
          onChanged: (bool value) {
            cubit.updateState(
              (current) => current.copyWith(leftHandModeEnabled: value),
            );
            showSuccessToast(t.common.settingSaved);
          },
        ),
      ),
    );
  }

  Widget _clickCoverToStartReading(
    GlobalSettingState state,
    GlobalSettingCubit cubit,
  ) {
    return TouchHoverIntent(
      identity: 'app_behavior_setting_page.switch:4',
      builder: (context, hover) => BreezeSwitchListTile(
        SwitchListTile.adaptive(
          hoverColor: hover.hoverColor(),
          secondary: const InterfaceSymbol(
            symbol: 'hand.tap',
            fallback: Icons.touch_app_outlined,
          ),
          title: Text(t.settings.clickCoverToStartReading),
          subtitle: Text(t.settings.clickCoverToStartReadingSubtitle),
          thumbIcon: settingSwitchThumbIcon(context),
          value: state.clickCoverToStartReading,
          onChanged: (bool value) {
            cubit.updateState(
              (current) => current.copyWith(clickCoverToStartReading: value),
            );
            showSuccessToast(t.common.settingSaved);
          },
        ),
      ),
    );
  }

  Widget _androidKeepAlive(GlobalSettingState state, GlobalSettingCubit cubit) {
    return TouchHoverIntent(
      identity: 'app_behavior_setting_page.switch:5',
      builder: (context, hover) => BreezeSwitchListTile(
        SwitchListTile.adaptive(
          hoverColor: hover.hoverColor(),
          secondary: const InterfaceSymbol(
            symbol: 'battery.100.bolt',
            fallback: Icons.battery_charging_full_outlined,
          ),
          title: Text(t.settings.androidKeepAlive),
          subtitle: Text(t.settings.androidKeepAliveSubtitle),
          thumbIcon: settingSwitchThumbIcon(context),
          value: state.androidKeepAliveEnabled,
          onChanged: (bool value) async {
            cubit.updateState(
              (current) => current.copyWith(androidKeepAliveEnabled: value),
            );
            try {
              if (value) {
                await ForegroundTaskService.instance.enableKeepAlive();
              } else {
                await ForegroundTaskService.instance.disableKeepAlive();
              }
              showSuccessToast(t.common.settingSaved);
            } catch (e) {
              cubit.updateState(
                (current) => current.copyWith(androidKeepAliveEnabled: !value),
              );
              showErrorToast(e.toString());
            }
          },
        ),
      ),
    );
  }

  Widget _backPressExit(GlobalSettingState state, GlobalSettingCubit cubit) {
    return TouchHoverIntent(
      identity: 'app_behavior_setting_page.switch:6',
      builder: (context, hover) => BreezeSwitchListTile(
        SwitchListTile.adaptive(
          hoverColor: hover.hoverColor(),
          secondary: const InterfaceSymbol(
            symbol: 'rectangle.portrait.and.arrow.right',
            fallback: Icons.exit_to_app_outlined,
          ),
          title: Text(t.settings.backPressExit),
          subtitle: Text(t.settings.backPressExitSubtitle),
          thumbIcon: settingSwitchThumbIcon(context),
          value: state.backPressExitEnabled,
          onChanged: (bool value) {
            cubit.updateState(
              (current) => current.copyWith(backPressExitEnabled: value),
            );
            showSuccessToast(t.common.settingSaved);
          },
        ),
      ),
    );
  }

  Widget _desktopCloseBehaviorTile() {
    final closeBehaviorItems = <DesktopCloseBehavior, String>{
      DesktopCloseBehavior.ask: t.settings.desktopCloseAsk,
      DesktopCloseBehavior.hide: t.settings.desktopCloseHide,
      DesktopCloseBehavior.close: t.settings.desktopCloseClose,
    };

    return SettingChoiceTile<DesktopCloseBehavior>(
      leading: const InterfaceSymbol(
        symbol: 'arrow.down.right.and.arrow.up.left',
        fallback: Icons.close_fullscreen_outlined,
      ),
      title: t.settings.desktopCloseBehavior,
      description: t.settings.desktopCloseBehaviorSubtitle,
      value: _desktopCloseBehavior,
      enabled: !_desktopSaving,
      error: _desktopError,
      items: closeBehaviorItems,
      onChanged: (DesktopCloseBehavior value) async {
        if (_desktopSaving || value == _desktopCloseBehavior) return;
        setState(() {
          _desktopSaving = true;
          _desktopError = null;
        });
        try {
          await WindowLogic.saveCloseBehavior(value);
          if (!mounted) return;
          setState(() => _desktopCloseBehavior = value);
          showSuccessToast(t.common.settingSaved);
        } catch (_) {
          if (mounted) setState(() => _desktopError = t.error.saveFailed);
        } finally {
          if (mounted) setState(() => _desktopSaving = false);
        }
      },
    );
  }

  Widget _appLockSetting(GlobalSettingState state, GlobalSettingCubit cubit) {
    final lockSetting = state.appLockSetting;
    final isReady = lockSetting.isReady;

    return Column(
      children: [
        TouchHoverIntent(
          identity: 'app_behavior_setting_page.switch:7',
          builder: (context, hover) => BreezeSwitchListTile(
            SwitchListTile.adaptive(
              hoverColor: hover.hoverColor(),
              secondary: const InterfaceSymbol(
                symbol: 'lock',
                fallback: Icons.lock_outline,
              ),
              title: Text(t.settings.appLock),
              subtitle: Text(t.settings.appLockSubtitle),
              thumbIcon: settingSwitchThumbIcon(context),
              value: lockSetting.enabled,
              onChanged: (bool value) async {
                if (value && !isReady) {
                  final nextSetting = await _configureAppLock();
                  if (nextSetting == null) {
                    return;
                  }
                  cubit.updateState(
                    (current) => current.copyWith(appLockSetting: nextSetting),
                  );
                  showSuccessToast(t.common.settingSaved);
                  return;
                }

                cubit.updateState(
                  (current) => current.copyWith(
                    appLockSetting: current.appLockSetting.copyWith(
                      enabled: value,
                    ),
                  ),
                );
                showSuccessToast(t.common.settingSaved);
              },
            ),
          ),
        ),
        TouchHoverIntent(
          identity: 'app_behavior_setting_page:0',
          builder: (context, hover) => ListTile(
            hoverColor: hover.hoverColor(),
            leading: const InterfaceSymbol(
              symbol: 'hand.draw',
              fallback: Icons.gesture_outlined,
            ),
            title: Text(t.gestureLock.gestureTitle),
            subtitle: Text(t.gestureLock.gestureHint),
            trailing: const InterfaceSymbol(
              symbol: 'chevron.right',
              fallback: Icons.chevron_right,
            ),
            onTap: () async {
              final nextSetting = await _configureAppLock();
              if (nextSetting == null) {
                return;
              }
              cubit.updateState(
                (current) => current.copyWith(appLockSetting: nextSetting),
              );
              showSuccessToast(t.common.settingSaved);
            },
          ),
        ),
        if (isReady)
          TouchHoverIntent(
            identity: 'app_behavior_setting_page:1',
            builder: (context, hover) => ListTile(
              hoverColor: hover.hoverColor(),
              leading: const InterfaceSymbol(
                symbol: 'number.square',
                fallback: Icons.pin_outlined,
              ),
              title: Text(t.gestureLock.pinTitle),
              subtitle: Text(t.gestureLock.pinHint),
              trailing: const InterfaceSymbol(
                symbol: 'chevron.right',
                fallback: Icons.chevron_right,
              ),
              onTap: () async {
                final pin = await showPinCodeSetupDialog(
                  context,
                  title: t.gestureLock.pinTitle,
                  confirmTitle: t.gestureLock.pinHint,
                );
                if (pin == null) {
                  return;
                }
                cubit.updateState(
                  (current) => current.copyWith(
                    appLockSetting: current.appLockSetting.copyWith(
                      resetPinHash: hashPinCode(pin),
                    ),
                  ),
                );
                showSuccessToast(t.common.settingSaved);
              },
            ),
          ),
        if (isReady)
          TouchHoverIntent(
            identity: 'app_behavior_setting_page:2',
            builder: (context, hover) => ListTile(
              hoverColor: hover.hoverColor(),
              leading: const InterfaceSymbol(
                symbol: 'trash',
                fallback: Icons.delete_outline,
              ),
              title: Text(t.common.delete),
              subtitle: Text(t.settings.appLock),
              trailing: const InterfaceSymbol(
                symbol: 'chevron.right',
                fallback: Icons.chevron_right,
              ),
              onTap: () async {
                final shouldDelete = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(t.common.delete),
                    content: Text(t.settings.appLockSubtitle),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(t.common.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(t.common.delete),
                      ),
                    ],
                  ),
                );
                if (shouldDelete != true) {
                  return;
                }
                cubit.updateState(
                  (current) => current.copyWith(
                    appLockSetting: const AppLockSettingState(),
                  ),
                );
                showSuccessToast(t.common.settingSaved);
              },
            ),
          ),
      ],
    );
  }

  Future<AppLockSettingState?> _configureAppLock() async {
    final pattern = await showGesturePasswordSetupDialog(
      context,
      title: t.gestureLock.gestureTitle,
      confirmTitle: t.gestureLock.confirmGesture,
    );
    if (pattern == null) {
      return null;
    }

    if (!mounted) {
      return null;
    }

    final pin = await showPinCodeSetupDialog(
      context,
      title: t.gestureLock.setResetPin,
      confirmTitle: t.gestureLock.confirmResetPin,
    );
    if (pin == null) {
      return null;
    }

    return AppLockSettingState(
      enabled: true,
      gesturePasswordHash: hashGesturePattern(pattern),
      resetPinHash: hashPinCode(pin),
    );
  }
}
