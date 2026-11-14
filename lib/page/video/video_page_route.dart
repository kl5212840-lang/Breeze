import 'package:zephyr/page/video/omo_network.dart';
import 'package:zephyr/page/video/video_network_scope.dart';
import 'package:cupertino_ui/cupertino_ui.dart' as cupertino_ui;
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

// Bounded geometry-based composition trials for the two reported video
// entrances. Other sources keep their existing route identity and behavior.
const bikaVideoDetailRouteName = 'breeze.video.bika-detail';
const omoVideoDetailRouteName = 'breeze.video.omo-detail';
const apiVideoLibraryRouteName = 'breeze.video.library';
RouteSettings? videoDetailRouteSettings(String source) => switch (source) {
  'e9f18928-3ba8-4d86-a12e-b53a62f47933' => const RouteSettings(
    name: bikaVideoDetailRouteName,
  ),
  omoNetworkSource => const RouteSettings(name: omoVideoDetailRouteName),
  _ => null,
};

/// Hierarchy navigation on iOS has one owner: the native-style route. Data
/// refreshes and web-document restoration never push another visual page.
PageRoute<T> videoPageRoute<T>({
  required WidgetBuilder builder,
  String? networkSource,
  Future<OmoNetworkContext?>? network,
  RouteSettings? settings,
  bool matchAutoRouteTransition = false,
}) {
  Widget build(BuildContext context) {
    final child = builder(context);
    return networkSource == null
        ? child
        : VideoNetworkScope(
            source: networkSource,
            network: network,
            child: child,
          );
  }

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    // AutoRoute recognizes the cupertino_ui route family when linking the
    // underlying page's secondary animation to this destination.
    if (matchAutoRouteTransition) {
      return cupertino_ui.CupertinoPageRoute<T>(
        builder: build,
        settings: settings,
      );
    }
    return CupertinoPageRoute<T>(builder: build, settings: settings);
  }
  return MaterialPageRoute<T>(builder: build, settings: settings);
}
