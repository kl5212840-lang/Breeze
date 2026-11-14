import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/widgets/scroll_return_to_top.dart';
import 'package:zephyr/widgets/list_position_scrollbar.dart';

/// Listens to the work viewport without taking over its scroll controller.
class BookshelfReturnToTop extends StatefulWidget {
  const BookshelfReturnToTop({
    super.key,
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  State<BookshelfReturnToTop> createState() => _BookshelfReturnToTopState();
}

class _BookshelfReturnToTopState extends State<BookshelfReturnToTop> {
  ScrollableState? _scrollable;
  bool _show = false;

  bool _observe(int depth, ScrollMetrics metrics, BuildContext? origin) {
    if (depth != 0 || metrics.axis != Axis.vertical || origin == null) {
      return false;
    }
    _scrollable = Scrollable.maybeOf(origin, axis: Axis.vertical);
    final show = ScrollReturnToTop.canReturn(metrics);
    if (show != _show) setState(() => _show = show);
    return false;
  }

  void _returnToTop() {
    final scrollable = _scrollable;
    if (scrollable == null || !scrollable.mounted) return;
    final position = scrollable.position;
    final target = position.minScrollExtent;
    if (MediaQuery.disableAnimationsOf(context) ||
        position.extentBefore >= position.viewportDimension * 2) {
      position.jumpTo(target);
    } else {
      unawaited(
        position.animateTo(
          target,
          duration: const Duration(milliseconds: 230),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      NotificationListener<ScrollMetricsNotification>(
        onNotification: (n) => _observe(n.depth, n.metrics, n.context),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) => _observe(n.depth, n.metrics, n.context),
          child: ListPositionScrollbar(
            bottomInset: NativeNavigationInset.scrollBottom(context),
            child: widget.child,
          ),
        ),
      ),
      ScrollReturnToTop(
        actionKey: const ValueKey('bookshelf.return-to-top'),
        visible: widget.enabled && _show,
        bottom: NativeNavigationInset.scrollBottom(context) + 16,
        onPressed: _returnToTop,
      ),
    ],
  );
}
