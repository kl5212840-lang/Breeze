import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/video/video_page_route.dart';

/// Keep each settings hierarchy in the navigator that owns its current page.
/// A pageless route may inherit RouterScope from the page underneath it.
Future<void> openSettingPage(
  BuildContext context, {
  required PageRouteInfo route,
  required WidgetBuilder builder,
}) async {
  if (ModalRoute.of(context)?.settings is AutoRoutePage &&
      context.findAncestorWidgetOfExactType<RouterScope>() != null &&
      StackRouterScope.of(context) != null) {
    await context.pushRoute<void>(route);
  } else {
    await Navigator.of(context).push<void>(
      videoPageRoute<void>(
        settings: RouteSettings(name: route.routeName),
        builder: builder,
      ),
    );
  }
}
