import 'package:flutter/widgets.dart';

/// The mounted main navigation opens the sole Downloads center (tab or route). Hosts
/// without that owner report failure instead of creating a second task page.
abstract final class DownloadCenterNavigation {
  static Object? _owner;
  static Future<bool> Function()? _open;

  static void attach(Object owner, Future<bool> Function() open) {
    _owner = owner;
    _open = open;
  }

  static void detach(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _open = null;
  }

  static bool get available => _open != null;

  static Future<bool> open({BuildContext? from}) async {
    // Plain source routes and sheets can live inside PersistentTabView's
    // navigators, outside AutoRoute's root stack. Capture those owners while
    // the launch context is live; a confirmed main-tab switch may dispose it.
    final nested = <NavigatorState>[];
    if (from != null && from.mounted) {
      final root = Navigator.maybeOf(from, rootNavigator: true);
      from.visitAncestorElements((element) {
        if (element is StatefulElement && element.state is NavigatorState) {
          final navigator = element.state as NavigatorState;
          if (!identical(navigator, root)) nested.add(navigator);
        }
        return true;
      });
    }
    if (await _open?.call() != true) return false;
    // Only an actual main owner may close this source stack. A standalone
    // window keeps its popup/player and reports that no main owner is ready.
    for (final navigator in nested) {
      if (navigator.mounted && !_clearNested(navigator)) return false;
    }
    return true;
  }

  static Route<dynamic>? _top(NavigatorState navigator) {
    Route<dynamic>? top;
    // A predicate that accepts its first route only inspects the current top;
    // unlike popUntil(first), a refused pop cannot cause an unbounded loop.
    navigator.popUntil((route) {
      top = route;
      return true;
    });
    return top;
  }

  static bool _clearNested(NavigatorState navigator) {
    for (var count = 0; count < 32 && navigator.mounted; count++) {
      final top = _top(navigator);
      if (top == null || top.isFirst) return true;
      // This tab is now offstage. Animated pops can remain mounted forever
      // under its disabled TickerMode; explicit removal needs no exit ticker.
      navigator.removeRoute(top);
      if (identical(_top(navigator), top)) return false;
    }
    return !navigator.mounted || _top(navigator)?.isFirst == true;
  }
}
