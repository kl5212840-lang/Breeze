import 'package:zephyr/widgets/native_view_occlusion.dart';
import 'package:zephyr/page/download/download_center_navigation.dart';
import 'package:zephyr/page/donwload_task/view/download_task.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_control_colors.dart';
import 'package:zephyr/widgets/breeze_navigation_bar.dart';
import 'dart:async';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/service/checkin/auto_checkin_notices.dart';
import 'package:zephyr/service/download/download_queue_manager.dart';
import 'package:zephyr/page/comic_follow/cubit/comic_follow_cubit.dart';
import 'package:zephyr/page/comic_follow/comic_follow_navigation.dart';
import 'package:zephyr/page/comic_follow/view/comic_follow_page.dart';
import 'package:zephyr/page/navigation/main_navigation_layout.dart';
import 'package:zephyr/service/comic_follow/comic_follow_reminders.dart';
import 'package:zephyr/service/comic_follow/comic_follow_foreground_scheduler.dart';
import 'package:zephyr/page/navigation/welcome_page_destination.dart';
import 'package:zephyr/service/lifecycle/foreground_task/foreground_task_service.dart';
import 'package:zephyr/service/lifecycle/notification_service.dart';
import 'package:zephyr/service/update/check_update.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/util/manage_cache.dart';
import 'package:zephyr/widgets/memory/memory_overlay_widget.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';

import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/sync_service.dart';
import 'package:zephyr/network/sync/sync_archive_service.dart'
    show SyncArchiveHooks;
import 'package:zephyr/network/sync/sync_operation_queue.dart';
import 'package:zephyr/network/sync/sync_archive_context.dart';
import 'package:zephyr/network/sync/sync_payload_compatibility.dart';
import 'package:zephyr/util/debouncer.dart';
import 'package:zephyr/util/event/event.dart';
import 'package:zephyr/page/bookshelf/bookshelf.dart';
import 'package:zephyr/page/discover/view/discover_page.dart';
import 'package:zephyr/page/more/view/more.dart';

VoidCallback automaticSyncStartNotification({
  required bool Function() canNotify,
}) => () {
  if (canNotify()) showInfoToast(t.settings.syncWorking);
};

@RoutePage()
class NavigationBar extends StatefulWidget {
  const NavigationBar({super.key});

  @override
  State<NavigationBar> createState() => _NavigationBarState();
}

class _NavigationBarState extends State<NavigationBar> {
  double? _nativeNavHeight;
  Timer? _syncTimer;
  StreamSubscription<NoticeSync>? _syncSubscription;
  StreamSubscription<NeedLogin>? _loginSubscription;
  StreamSubscription<ToastEvent>? _toastSubscription;
  late final AppLifecycleListener _autoCheckinLifecycle;
  bool _autoCheckinDeliveryScheduled = false;
  ComicFollowForegroundScheduler? _followForegroundScheduler;
  bool _autoSyncFailureNotified = false;
  late final PersistentTabController _controller;
  late MainNavigationLayout _layout;
  late MainNavigationDestination _selectedDestination;
  StreamSubscription<GlobalSettingState>? _layoutSubscription;
  bool _openingDownloads = false;
  bool _openingFollow = false;
  final _followReminders = ComicFollowReminderController.instance;
  final debouncer = Debouncer(milliseconds: 100);
  DateTime? _lastLoginNavigateAt;
  String? _lastLoginPluginId;
  late HideOnScrollSettings hideOnScrollSettings;

  static bool _notificationsInitialized = false; // ← 使用静态变量，跨实例共享
  bool _isInitializingNotifications = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      unawaited(checkUpdateReminder(context));
      _autoSync();
      manageCacheSize(context);
      DownloadQueueManager.instance.resetStuckTasks();
      DownloadQueueManager.instance.watchTasks(
        startupResumeDelay: const Duration(minutes: 1),
      );
      if (Platform.isAndroid) {
        await ForegroundTaskService.instance.syncOnAppStart();
      }
    });
    final settings = context.read<GlobalSettingCubit>();
    _layout = MainNavigationLayout.decode(settings.state.mainNavigationSlots);
    final welcome = resolveWelcomePageDestination(
      settings.state.welcomePageNum,
      oldPageRollbackEnabled: false,
    );
    final destination = switch (welcome) {
      WelcomePageDestination.bookshelf => MainNavigationDestination.bookshelf,
      WelcomePageDestination.downloads => MainNavigationDestination.downloads,
      WelcomePageDestination.more => MainNavigationDestination.more,
      _ => MainNavigationDestination.discover,
    };
    final unpinnedWelcome = !_layout.contains(destination);
    _selectedDestination = unpinnedWelcome
        ? MainNavigationDestination.more
        : destination;
    _controller = PersistentTabController(
      initialIndex: _selectedDestination.index,
    );
    _layoutSubscription = settings.stream.listen(_onSettings);
    DownloadCenterNavigation.attach(this, _openDownloads);
    ComicFollowNavigation.attach(this, _openFollow);
    if (unpinnedWelcome) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openDownloads());
      });
    }
    unawaited(_followReminders.load().catchError((Object _) {}));
    ForegroundTaskService.instance.init();

    initializeNotificationsOnce();
    _followForegroundScheduler = ComicFollowForegroundScheduler(
      cubit: context.read<ComicFollowCubit>(),
    )..start();

    // 每隔 5 分钟执行一次
    const duration = Duration(minutes: 5);
    _syncTimer = Timer.periodic(duration, (Timer timer) async {
      await _autoSync();
    });

    // 用来手动触发同步
    _syncSubscription = eventBus.on<NoticeSync>().listen((event) {
      _autoSync(force: event.force);
    });

    _loginSubscription = eventBus.on<NeedLogin>().listen((event) {
      _goToLoginPage(event.from);
    });

    _toastSubscription = eventBus.on<ToastEvent>().listen((event) {
      _showToast(event);
    });
    _autoCheckinLifecycle = AppLifecycleListener(
      onResume: _scheduleAutoCheckinNotices,
    );
    AutoCheckinNotices.instance.addListener(_scheduleAutoCheckinNotices);
    _scheduleAutoCheckinNotices();
  }

  @override
  void dispose() {
    _followForegroundScheduler?.dispose();
    _syncTimer?.cancel();
    _syncSubscription?.cancel();
    _layoutSubscription?.cancel();
    _loginSubscription?.cancel();
    _toastSubscription?.cancel();
    _autoCheckinLifecycle.dispose();
    AutoCheckinNotices.instance.removeListener(_scheduleAutoCheckinNotices);
    DownloadCenterNavigation.detach(this);
    ComicFollowNavigation.detach(this);
    _controller.dispose();
    super.dispose();
  }

  void _onSettings(GlobalSettingState state) {
    final next = MainNavigationLayout.decode(state.mainNavigationSlots);
    if (!mounted || next.encoded == _layout.encoded) return;
    final selected = next.contains(_selectedDestination)
        ? _selectedDestination
        : MainNavigationDestination.more;
    setState(() => _layout = next);
    _select(selected);
  }

  void _select(MainNavigationDestination destination) {
    if (!mounted || !_layout.contains(destination)) return;
    if (destination == _selectedDestination) return;
    _controller.jumpToTab(destination.index);
    setState(() => _selectedDestination = destination);
  }

  Future<bool> _openDownloads() async {
    if (!mounted) return false;
    final router = AutoRouter.of(context).root;
    if (!router.stack.any((page) => page.name == 'NavigationBar')) {
      return false;
    }
    if (_layout.contains(MainNavigationDestination.downloads)) {
      router.popUntilRouteWithName('NavigationBar');
      _select(MainNavigationDestination.downloads);
    } else {
      if (_openingDownloads ||
          router.current.name == DownloadCenterRoute.name) {
        return true;
      }
      if (router.stack.any((page) => page.name == DownloadCenterRoute.name)) {
        router.popUntilRouteWithName(DownloadCenterRoute.name);
      } else {
        router.popUntilRouteWithName('NavigationBar');
        _openingDownloads = true;
        unawaited(
          router.push<void>(const DownloadCenterRoute()).whenComplete(() {
            _openingDownloads = false;
          }),
        );
      }
    }
    return true;
  }

  Future<bool> _openFollow() async {
    if (!mounted) return false;
    final router = AutoRouter.of(context).root;
    if (_layout.contains(MainNavigationDestination.follow)) {
      router.popUntilRouteWithName('NavigationBar');
      _select(MainNavigationDestination.follow);
    } else {
      if (_openingFollow || router.current.name == ComicFollowRoute.name) {
        return true;
      }
      if (router.stack.any((page) => page.name == ComicFollowRoute.name)) {
        router.popUntilRouteWithName(ComicFollowRoute.name);
      } else {
        _openingFollow = true;
        unawaited(
          router.push<void>(ComicFollowRoute()).whenComplete(() {
            _openingFollow = false;
          }),
        );
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final global = context.watch<GlobalSettingCubit>().state;
    final backPressExitEnabled =
        Platform.isAndroid && global.backPressExitEnabled;
    final destinations = _layout.destinations;
    final selected = destinations.indexOf(_selectedDestination);
    final followUpdates = context.select(
      (ComicFollowCubit cubit) => cubit.state.updateCount,
    );

    return MemoryOverlayWidget(
      enabled: global.enableMemoryDebug,
      updateInterval: const Duration(seconds: 1),
      child: _MainNavigationState(
        layout: _layout,
        selected: _selectedDestination,
        child: ValueListenableBuilder<ComicFollowReminderMode?>(
          valueListenable: _followReminders.mode,
          builder: (context, mode, _) {
            final badge =
                mode != null &&
                    mode != ComicFollowReminderMode.silent &&
                    followUpdates > 0
                ? followUpdates
                : null;
            final entries = [
              for (final destination in destinations)
                _mainNavigationEntry(destination, followBadge: badge),
            ];
            void onSelected(int index) {
              if (index >= 0 && index < destinations.length) {
                _select(destinations[index]);
              }
            }

            if (isTablet(context) ||
                Platform.isWindows ||
                Platform.isLinux ||
                Platform.isMacOS) {
              return MainWideTabHost(
                screens: _pages,
                destinations: [
                  for (final entry in entries)
                    NavigationRailDestination(
                      icon: entry.icon,
                      selectedIcon: entry.selectedIcon,
                      label: Text(entry.label),
                    ),
                ],
                selectedIndex: selected,
                screenIndex: _selectedDestination.index,
                onSelected: onSelected,
                onSearch: () => context.pushRoute(
                  SearchRoute(
                    searchState: SearchStates.initial(),
                    aggregateMode: true,
                  ),
                ),
              );
            }
            return _buildMobileLayout(
              context,
              entries: entries,
              selected: selected,
              onSelected: onSelected,
              backPressExitEnabled: backPressExitEnabled,
            );
          },
        ),
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context, {
    required List<_MainNavigationEntry> entries,
    required int selected,
    required ValueChanged<int> onSelected,
    required bool backPressExitEnabled,
  }) {
    final media = MediaQuery.of(context);
    final system = AppInterfaceStyleScope.usesSystem(context);
    final floating = system && Platform.isIOS;
    final height = switch ((system, floating)) {
      (true, true) => _nativeNavHeight ?? 49 + media.viewPadding.bottom,
      (true, false) => kBottomNavigationBarHeight + media.padding.bottom,
      _ => BreezeNavigationBar.contentHeightOf(context) + media.padding.bottom,
    };
    return MainNativeTabHost(
      controller: _controller,
      screens: _pages,
      floatingNavigation: floating,
      navBarHeight: height,
      handleAndroidBackButtonPress: !backPressExitEnabled,
      onWillPop: backPressExitEnabled ? _handleExitOnBack : null,
      navigation: MediaQuery(
        data: media,
        child: system
            ? VideoNativeNavigation(
                currentIndex: selected,
                onTap: onSelected,
                onHeightChanged: floating
                    ? (height) {
                        if (mounted && height != _nativeNavHeight) {
                          setState(() => _nativeNavHeight = height);
                        }
                      }
                    : null,
                symbols: [for (final entry in entries) entry.symbol],
                selectedSymbols: [
                  for (final entry in entries) entry.selectedSymbol,
                ],
                badgeValues: [for (final entry in entries) entry.badgeLabel],
                items: [
                  for (final entry in entries)
                    BottomNavigationBarItem(
                      icon: entry.icon,
                      activeIcon: entry.selectedIcon,
                      label: entry.label,
                    ),
                ],
              )
            : BreezeNavigationBar(
                contentHeight: BreezeNavigationBar.contentHeightOf(context),
                selectedIndex: selected,
                destinations: [
                  for (final entry in entries)
                    NavigationDestination(
                      icon: entry.icon,
                      selectedIcon: entry.selectedIcon,
                      label: entry.label,
                    ),
                ],
                onSelected: onSelected,
              ),
      ),
    );
  }

  Future<bool> _handleExitOnBack(BuildContext? _) async {
    if (_selectedDestination != MainNavigationDestination.discover) {
      _select(MainNavigationDestination.discover);
      return false;
    }
    await SystemNavigator.pop();
    return false;
  }

  static const _pages = <Widget>[
    DiscoverPage(),
    BookshelfPage(),
    _MainNavigationOptionalPage(MainNavigationDestination.follow),
    _MainNavigationOptionalPage(MainNavigationDestination.downloads),
    MorePage(),
  ];

  Future<void> _autoSync({bool force = false}) async {
    if (!mounted || (!force && syncStorageOperations.busy.value)) return;
    final globalSettingCubit = context.read<GlobalSettingCubit>();
    final globalState = globalSettingCubit.state;

    if (!force && globalState.syncSetting.autoSync == false) {
      return;
    }

    if (!isSyncServiceConfigured(globalState)) {
      return;
    }

    try {
      final result = await autoSync(
        globalState,
        globalSettingCubit: globalSettingCubit,
        comicFollowCubit: context.read<ComicFollowCubit>(),
        hooks: SyncArchiveHooks(
          onStarted: automaticSyncStartNotification(
            canNotify: () =>
                mounted &&
                (force ||
                    context
                        .read<GlobalSettingCubit>()
                        .state
                        .syncSetting
                        .syncNotify),
          ),
        ),
      );
      if (!mounted) return;
      if (result.runtimeReloadPending) {
        showWarningToast(t.settings.archiveReloadPending, context: context);
        return;
      }
      _autoSyncFailureNotified = false;
      if (result.newArchiveSynced &&
          (force || globalSettingCubit.state.syncSetting.syncNotify)) {
        showSuccessToast(
          force ? t.navigation.syncSuccess : t.navigation.autoSyncSuccess,
        );
      }
    } catch (e, stackTrace) {
      logger.e(e.toString(), stackTrace: stackTrace);
      if (!mounted) return;
      if (!force) {
        if (!_autoSyncFailureNotified) {
          _autoSyncFailureNotified = true;
          showWarningToast(
            e is LegacyArchiveAvailable || e is SyncCompatibilityException
                ? e.toString()
                : t.navigation.autoSyncFailed,
            context: context,
          );
        }
        return;
      }
      showErrorToast(
        t.navigation.syncFailedMessage(error: normalizeSearchErrorMessage(e)),
        title: force ? t.navigation.syncFailed : t.navigation.autoSyncFailed,
      );
    }
  }

  void _goToLoginPage(String from) {
    try {
      final pluginId = from.trim();
      if (pluginId.isEmpty) {
        logger.w('Skip login navigation: empty plugin id');
        return;
      }

      final navigator = Navigator.maybeOf(context);
      if (navigator == null) {
        logger.w('Navigator not available');
        return;
      }

      debouncer.run(() {
        if (!mounted) {
          return;
        }

        final now = DateTime.now();
        final recentDuplicate =
            _lastLoginPluginId == pluginId &&
            _lastLoginNavigateAt != null &&
            now.difference(_lastLoginNavigateAt!).inMilliseconds < 1500;
        if (recentDuplicate) {
          return;
        }

        final hasLoginRoute = navigator.widget.pages.any(
          (route) => (route.name ?? '').contains('LoginRoute'),
        );
        if (hasLoginRoute) {
          return;
        }
        // The source shell shows an inline login action for the failed tab.
        // Do not cover that state with a second, global login dialog.
        if (navigator.widget.pages.isNotEmpty &&
            (navigator.widget.pages.last.name == SourceShellRoute.name ||
                navigator.widget.pages.last.name == PluginFunctionRoute.name)) {
          return;
        }
        _lastLoginNavigateAt = now;
        _lastLoginPluginId = pluginId;
        unawaited(_confirmAndGoToLogin(pluginId));
      });
    } catch (e, stackTrace) {
      logger.e('Failed to navigate to login', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _confirmAndGoToLogin(String pluginId) async {
    if (!mounted) {
      return;
    }
    final goLogin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.navigation.needLoginTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.navigation.goLogin),
          ),
        ],
      ),
    );
    if (goLogin != true || !mounted) {
      return;
    }
    try {
      final navigator = Navigator.maybeOf(context);
      if (navigator == null) {
        return;
      }
      final hasLoginRoute = navigator.widget.pages.any(
        (route) => (route.name ?? '').contains('LoginRoute'),
      );
      if (hasLoginRoute) {
        return;
      }
      context.navigateTo(LoginRoute(from: pluginId));
    } catch (e, stackTrace) {
      logger.e('Failed to navigate to login', error: e, stackTrace: stackTrace);
    }
  }

  void _scheduleAutoCheckinNotices() {
    if (_autoCheckinDeliveryScheduled) return;
    final binding = WidgetsBinding.instance;
    _autoCheckinDeliveryScheduled = true;
    binding.addPostFrameCallback((_) {
      _autoCheckinDeliveryScheduled = false;
      if (!mounted || binding.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay == null || !overlay.mounted) return;
      for (final event in AutoCheckinNotices.instance.takePending()) {
        showToastEvent(context, event, overlayState: overlay);
      }
    });
    binding.ensureVisualUpdate();
  }

  void _showToast(ToastEvent event) {
    if (mounted) showToastEvent(context, event);
  }

  Future<void> initializeNotificationsOnce() async {
    // 应用级别检查
    if (_notificationsInitialized) {
      logger.d('Notifications already initialized globally');
      return;
    }

    // 实例级别检查
    if (_isInitializingNotifications) {
      logger.w('Notification initialization already in progress');
      return;
    }

    try {
      _isInitializingNotifications = true;

      // 延迟执行，避免与其他初始化冲突
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      await initializeNotifications();

      _notificationsInitialized = true;
      logger.d('Notifications initialized successfully');
    } catch (e, stackTrace) {
      logger.e(
        'Failed to initialize notifications',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _isInitializingNotifications = false;
    }
  }
}

class _MainNavigationState extends InheritedWidget {
  const _MainNavigationState({
    required this.layout,
    required this.selected,
    required super.child,
  });

  final MainNavigationLayout layout;
  final MainNavigationDestination selected;

  @override
  bool updateShouldNotify(_MainNavigationState oldWidget) =>
      selected != oldWidget.selected ||
      layout.encoded != oldWidget.layout.encoded;
}

class _MainNavigationOptionalPage extends StatefulWidget {
  const _MainNavigationOptionalPage(this.destination);

  final MainNavigationDestination destination;

  @override
  State<_MainNavigationOptionalPage> createState() =>
      _MainNavigationOptionalPageState();
}

class _MainNavigationOptionalPageState
    extends State<_MainNavigationOptionalPage> {
  bool _visited = false;

  @override
  Widget build(BuildContext context) {
    final navigation = context
        .dependOnInheritedWidgetOfExactType<_MainNavigationState>()!;
    if (!navigation.layout.contains(widget.destination)) {
      _visited = false;
      return const SizedBox.shrink();
    }
    final active = navigation.selected == widget.destination;
    if (active) _visited = true;
    if (!_visited) return const SizedBox.shrink();
    return switch (widget.destination) {
      MainNavigationDestination.follow => ComicFollowPage(
        embedded: true,
        active: active,
      ),
      MainNavigationDestination.downloads => const DownloadTaskPage(
        embedded: true,
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _MainNavigationEntry {
  const _MainNavigationEntry(
    this.label,
    this.symbol,
    this._icon,
    this._selectedIcon, {
    this.selectedSymbol,
    this.badge,
  });

  final String label, symbol;
  final String? selectedSymbol;
  final IconData _icon, _selectedIcon;
  final int? badge;

  String? get badgeLabel => switch (badge) {
    null => null,
    > 99 => '99+',
    final value => '$value',
  };

  Widget get icon => _withBadge(_icon);
  Widget get selectedIcon => _withBadge(_selectedIcon);

  Widget _withBadge(IconData data) {
    final label = badgeLabel;
    final icon = Icon(data);
    return label == null ? icon : Badge(label: Text(label), child: icon);
  }
}

_MainNavigationEntry _mainNavigationEntry(
  MainNavigationDestination destination, {
  required int? followBadge,
}) => switch (destination) {
  MainNavigationDestination.discover => _MainNavigationEntry(
    t.navigation.discover,
    'safari',
    CupertinoIcons.compass,
    CupertinoIcons.compass_fill,
  ),
  MainNavigationDestination.bookshelf => _MainNavigationEntry(
    t.navigation.bookshelf,
    'book.closed',
    Icons.book_outlined,
    CupertinoIcons.book_fill,
    selectedSymbol: 'book.fill',
  ),
  MainNavigationDestination.follow => _MainNavigationEntry(
    t.more.comicFollow,
    'breeze.follow',
    Icons.notifications_none_rounded,
    Icons.notifications_active,
    selectedSymbol: 'breeze.follow.selected',
    badge: followBadge,
  ),
  MainNavigationDestination.downloads => _MainNavigationEntry(
    t.common.download,
    'arrow.down.circle',
    CupertinoIcons.arrow_down_circle,
    CupertinoIcons.arrow_down_circle_fill,
  ),
  MainNavigationDestination.more => _MainNavigationEntry(
    t.navigation.more,
    'ellipsis.circle',
    CupertinoIcons.ellipsis_circle,
    CupertinoIcons.ellipsis_circle_fill,
  ),
};

/// The main navigation on wide windows keeps the same tab instances alive.
class MainWideTabHost extends StatelessWidget {
  const MainWideTabHost({
    super.key,
    required this.screens,
    required this.destinations,
    required this.selectedIndex,
    this.screenIndex,
    required this.onSelected,
    required this.onSearch,
  });

  final List<Widget> screens;
  final List<NavigationRailDestination> destinations;
  final int selectedIndex;
  final int? screenIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final breeze = !AppInterfaceStyleScope.usesSystem(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final surface = theme.scaffoldBackgroundColor;
    final railSurface = breeze
        ? BreezeControlColors.navigationSurface(theme)
        : surface;
    final navigationAccent = BreezeControlColors.navigation(
      colors,
      backdrop: railSurface,
      highContrast: breeze && MediaQuery.highContrastOf(context),
    );
    final label = breeze
        ? theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500)
        : null;
    return Scaffold(
      backgroundColor: surface,
      body: Row(
        children: [
          ColoredBox(
            color: railSurface,
            child: Column(
              children: [
                Expanded(
                  child: NavigationRail(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: onSelected,
                    labelType: NavigationRailLabelType.all,
                    backgroundColor: railSurface,
                    indicatorColor: breeze ? navigationAccent.indicator : null,
                    selectedIconTheme: breeze
                        ? IconThemeData(color: navigationAccent.foreground)
                        : null,
                    selectedLabelTextStyle: label?.copyWith(
                      color: navigationAccent.foreground,
                    ),
                    unselectedLabelTextStyle: label?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    destinations: destinations,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: t.common.search,
                    onPressed: onSearch,
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: IndexedStack(
              index: screenIndex ?? selectedIndex,
              children: screens,
            ),
          ),
        ],
      ),
    );
  }
}

/// The production native main-tab scaffold, separate from startup services so
/// its actual viewport and scroll boundaries can be exercised in host tests.
class MainNativeTabHost extends StatefulWidget {
  const MainNativeTabHost({
    super.key,
    required this.controller,
    required this.screens,
    required this.navBarHeight,
    required this.navigation,
    this.floatingNavigation = true,
    this.handleAndroidBackButtonPress = true,
    this.onWillPop,
  });
  final PersistentTabController controller;
  final List<Widget> screens;
  final double navBarHeight;
  final Widget navigation;
  final bool floatingNavigation;
  final bool handleAndroidBackButtonPress;
  final Future<bool> Function(BuildContext?)? onWillPop;
  @override
  State<MainNativeTabHost> createState() => _MainNativeTabHostState();
}

class _MainNativeTabHostState extends State<MainNativeTabHost> {
  // Each tab owns its own real Navigator stack, including plain Flutter pages.
  // Keep the same observer/list identity when parent preferences rebuild.
  final _routes = <RouteAndNavigatorSettings>[];
  void _ensureRoutes() {
    while (_routes.length < widget.screens.length) {
      _routes.add(
        RouteAndNavigatorSettings(
          navigatorObservers: [
            NativeCompositionObserver(geometryBasedOcclusion: true),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _ensureRoutes();
    return PersistentTabView.custom(
      context,
      controller: widget.controller,
      screens: [
        for (var index = 0; index < widget.screens.length; index++)
          CustomNavBarScreen(
            routeAndNavigatorSettings: _routes[index],
            screen: NativeNavigationInset(
              bottom: widget.floatingNavigation ? widget.navBarHeight : 0,
              child: widget.screens[index],
            ),
          ),
      ],
      itemCount: widget.screens.length,
      navBarHeight: widget.navBarHeight,
      confineToSafeArea: false,
      bottomScreenMargin: widget.floatingNavigation ? 0 : widget.navBarHeight,
      // The dependency paints this color across the entire custom-bar bounds.
      backgroundColor: Colors.transparent,
      handleAndroidBackButtonPress: widget.handleAndroidBackButtonPress,
      onWillPop: widget.onWillPop,
      resizeToAvoidBottomInset: false,
      hideNavigationBarWhenKeyboardAppears: true,
      customWidget: widget.navigation,
    );
  }
}
