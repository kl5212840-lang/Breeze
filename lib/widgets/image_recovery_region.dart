import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:zephyr/service/image_recovery.dart';

/// A successful refresh belongs to the list or detail page that initiated it.
class PageImageRefreshScope extends InheritedWidget {
  const PageImageRefreshScope({
    super.key,
    required this.revision,
    required super.child,
  });

  final Object revision;

  static Object? revisionOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PageImageRefreshScope>()
      ?.revision;

  @override
  bool updateShouldNotify(PageImageRefreshScope oldWidget) =>
      !identical(revision, oldWidget.revision);
}

/// Visibility, current route and app activity are one admission decision for
/// recoverable content. This widget never owns or cancels content itself.
class ImageRecoveryRegion extends StatefulWidget {
  const ImageRecoveryRegion({
    super.key,
    required this.child,
    required this.onActiveChanged,
    this.onPageRefreshed,
  });
  final Widget child;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback? onPageRefreshed;
  @override
  State<ImageRecoveryRegion> createState() => _ImageRecoveryRegionState();
}

class _ImageRecoveryRegionState extends State<ImageRecoveryRegion> {
  final _key = UniqueKey();
  bool _visible = false;
  bool? _last;
  Object? _refresh;
  StreamSubscription<void>? _activity;
  @override
  void initState() {
    super.initState();
    _activity = ImageRecoveryHub.instance.activity.listen((_) => _update());
  }

  void _update() {
    if (!mounted) return;
    final active =
        _visible &&
        TickerMode.valuesOf(context).enabled &&
        ModalRoute.of(context)?.isCurrent != false &&
        ImageRecoveryHub.instance.foreground;
    if (_last == active) return;
    _last = active;
    widget.onActiveChanged(active);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _update();
    if (widget.onPageRefreshed == null) return;
    final previous = _refresh;
    final next = _refresh = PageImageRefreshScope.revisionOf(context);
    if (previous == null || next == null || identical(previous, next)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _last == true && identical(_refresh, next)) {
        widget.onPageRefreshed?.call();
      }
    });
  }

  @override
  void didUpdateWidget(ImageRecoveryRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    _last = null;
    _update();
  }

  @override
  void dispose() {
    unawaited(_activity?.cancel());
    VisibilityDetectorController.instance.forget(_key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => VisibilityDetector(
    key: _key,
    onVisibilityChanged: (info) {
      _visible = info.visibleFraction > 0;
      _update();
    },
    child: widget.child,
  );
}
