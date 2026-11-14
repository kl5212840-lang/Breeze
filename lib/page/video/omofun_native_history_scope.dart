import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';

/// Reuses the live library's repository, browser and network owner. A record
/// route captures this callback before pushing, rather than creating a new source.
class OmoNativeHistoryScope extends InheritedWidget {
  const OmoNativeHistoryScope({
    super.key,
    required this.source,
    required this.mode,
    required this.openEntry,
    required super.child,
  });
  final String source;
  final ApiVideoView mode;
  final Future<void> Function(OmoHistoryEntry entry) openEntry;
  static OmoNativeHistoryScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OmoNativeHistoryScope>();
  @override
  bool updateShouldNotify(OmoNativeHistoryScope oldWidget) =>
      oldWidget.source != source ||
      oldWidget.mode != mode ||
      oldWidget.openEntry != openEntry;
}
