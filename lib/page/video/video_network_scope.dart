import 'package:flutter/widgets.dart';
import 'package:zephyr/page/video/omo_network.dart';

/// A source visit explicitly passed across page and overlay boundaries.
class VideoNetworkScope extends InheritedWidget {
  const VideoNetworkScope({
    super.key,
    required this.source,
    required this.network,
    required super.child,
  });
  final String source;
  final Future<OmoNetworkContext?>? network;

  static VideoNetworkScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<VideoNetworkScope>();

  @override
  bool updateShouldNotify(VideoNetworkScope oldWidget) =>
      source != oldWidget.source || !identical(network, oldWidget.network);
}
