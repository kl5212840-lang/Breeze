import 'package:material_ui/material_ui.dart';

/// Indicates the vertical viewport's position without adding a gesture target.
class ListPositionScrollbar extends StatelessWidget {
  const ListPositionScrollbar({
    super.key,
    required this.child,
    this.bottomInset = 0,
  });

  final Widget child;
  final double bottomInset;

  static const double _thickness = 3;

  @override
  Widget build(BuildContext context) => RawScrollbar(
    interactive: false,
    padding: EdgeInsets.only(bottom: bottomInset),
    scrollbarOrientation: ScrollbarOrientation.right,
    notificationPredicate: (notification) =>
        notification.depth == 0 && notification.metrics.axis == Axis.vertical,
    thickness: _thickness,
    minThumbLength: 36,
    radius: const Radius.circular(_thickness / 2),
    crossAxisMargin: 4,
    mainAxisMargin: 4,
    thumbColor: Theme.of(context).colorScheme.onSurface.withValues(
      alpha: MediaQuery.highContrastOf(context) ? .68 : .52,
    ),
    timeToFade: const Duration(milliseconds: 550),
    fadeDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 150),
    child: ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: child,
    ),
  );
}
