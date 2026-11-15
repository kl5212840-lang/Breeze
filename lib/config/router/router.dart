import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:zephyr/config/router/router.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Screen|Page,Route')
class AppRouter extends RootStackRouter {
  @override
  RouteType get defaultRouteType =>
      const RouteType.material(enablePredictiveBackGesture: false);

  @override
  List<AutoRoute> get routes => [
    AutoRoute(page: AppBootstrapRoute.page, initial: true),
    if (kDebugMode) AutoRoute(page: CoreMLUpscaleDebugRoute.page),
    AutoRoute(page: NavigationBar.page),
    AutoRoute(page: LoginRoute.page),
    AutoRoute(page: ComicListRoute.page),
    AutoRoute(page: SourceShellRoute.page),
    AutoRoute(page: SourceSettingsHubRoute.page),
    AutoRoute(page: DiscoverRoute.page),
    AutoRoute(page: SearchResultRoute.page),
    AutoRoute(page: SearchAggregateResultRoute.page),
    AutoRoute(page: ComicInfoRoute.page),
    AutoRoute(page: CommentsRoute.page),
    AutoRoute(page: PluginCommentsScaffoldRoute.page),
    AutoRoute(page: ComicReadRoute.page),
    AutoRoute(page: WebViewRoute.page),
    AutoRoute(page: GlobalSettingRoute.page),
    AutoRoute(page: AppearanceSettingRoute.page),
    AutoRoute(page: SwitchStyleSettingRoute.page),
    AutoRoute(page: ContentNetworkSettingRoute.page),
    AutoRoute(page: SyncSettingRoute.page),
    AutoRoute(page: AppBehaviorSettingRoute.page),
    AutoRoute(page: EInkSettingRoute.page),
    AutoRoute(page: StorageSettingRoute.page),
    AutoRoute(page: DebugSettingRoute.page),
    AutoRoute(page: ThemeColorRoute.page),
    AutoRoute(page: WebDavSyncRoute.page),
    if (kDebugMode) AutoRoute(page: ShowColorRoute.page),
    AutoRoute(page: AboutRoute.page),
    AutoRoute(page: FullRouteImageRoute.page),
    AutoRoute(page: ChangelogRoute.page),
    AutoRoute(page: SearchRoute.page),
    AutoRoute(page: PluginStoreRoute.page),
    AutoRoute(page: PluginSettingsRoute.page),
    AutoRoute(page: PluginDetailRoute.page),
    AutoRoute(page: PluginFunctionRoute.page),
    AutoRoute(page: OldHomeRoute.page),
    AutoRoute(page: OldRankingRoute.page),
    AutoRoute(page: MoreRoute.page),
    if (kDebugMode) AutoRoute(page: QjsRuntimeDebugRoute.page),
    AutoRoute(page: CacheSettingRoute.page),
    AutoRoute(page: RealSrSettingRoute.page),
    AutoRoute(page: BookshelfSettingRoute.page),
    AutoRoute(page: DataBackupRoute.page),
    AutoRoute(page: ComicFollowRoute.page),
    AutoRoute(page: DownloadCenterRoute.page),
  ];

  @override
  List<AutoRouteGuard> get guards => [];
}

void popToRoot(BuildContext context) {
  context.router.popUntil((route) => route.settings.name == 'NavigationBar');
}
