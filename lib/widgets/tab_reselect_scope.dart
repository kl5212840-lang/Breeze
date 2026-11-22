import 'dart:async';

import 'package:flutter/widgets.dart';

/// Sends a return-to-top request to the currently visible tab's root list.
class TabReselectController extends ChangeNotifier {
  void request() => notifyListeners();
}

class TabReselectScope extends InheritedWidget {
  const TabReselectScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final TabReselectController controller;

  static final _blockingOverlays = <Object>{};

  /// For platform-view menus displayed outside Flutter's Navigator.
  static void setBlockingOverlay(Object owner, {required bool visible}) {
    if (visible) {
      _blockingOverlays.add(owner);
    } else {
      _blockingOverlays.remove(owner);
    }
  }

  static TabReselectController? _of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<TabReselectScope>()
      ?.controller;

  static bool canHandle(BuildContext context) {
    if (_blockingOverlays.isNotEmpty ||
        !TickerMode.valuesOf(context).enabled ||
        MediaQuery.viewInsetsOf(context).bottom > 0) {
      return false;
    }
    var route = ModalRoute.of(context);
    while (route != null) {
      if (!route.isCurrent || route.secondaryAnimation?.isDismissed == false) {
        return false;
      }
      final parentContext = route.navigator?.context;
      route = parentContext == null ? null : ModalRoute.of(parentContext);
    }
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    if (focusedContext == null || !focusedContext.mounted) return true;
    return focusedContext.widget is! EditableText &&
        focusedContext.findAncestorWidgetOfExactType<EditableText>() == null;
  }

  static void scrollToStart(BuildContext context, ScrollController controller) {
    if (controller.positions.length == 1) {
      scrollPositionToStart(context, controller.position);
    }
  }

  static void scrollPositionToStart(
    BuildContext context,
    ScrollPosition position,
  ) {
    if (!position.hasContentDimensions ||
        position.pixels <= position.minScrollExtent) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context) ||
        position.extentBefore >= position.viewportDimension * 2) {
      position.jumpTo(position.minScrollExtent);
    } else {
      unawaited(
        position.animateTo(
          position.minScrollExtent,
          duration: const Duration(milliseconds: 230),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  @override
  bool updateShouldNotify(TabReselectScope oldWidget) =>
      oldWidget.controller != controller;
}

class TabReselectListener extends StatefulWidget {
  const TabReselectListener({
    super.key,
    this.enabled = true,
    required this.onReselect,
    required this.child,
  });

  final bool enabled;
  final VoidCallback onReselect;
  final Widget child;

  @override
  State<TabReselectListener> createState() => _TabReselectListenerState();
}

class _TabReselectListenerState extends State<TabReselectListener> {
  TabReselectController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = TabReselectScope._of(context);
    if (_controller == controller) return;
    _controller?.removeListener(_onReselect);
    _controller = controller;
    _controller?.addListener(_onReselect);
  }

  void _onReselect() {
    if (widget.enabled && TabReselectScope.canHandle(context)) {
      widget.onReselect();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onReselect);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
