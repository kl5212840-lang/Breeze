import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoRouteTransitionMixin;
import 'package:material_ui/material_ui.dart';

const einkPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.iOS: _InstantCupertinoTransition(),
    TargetPlatform.macOS: _InstantCupertinoTransition(),
    TargetPlatform.android: _InstantTransition(),
    TargetPlatform.fuchsia: _InstantTransition(),
    TargetPlatform.linux: _InstantTransition(),
    TargetPlatform.windows: _InstantTransition(),
  },
);

class _InstantTransition extends PageTransitionsBuilder {
  const _InstantTransition();

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

class _InstantCupertinoTransition extends _InstantTransition {
  const _InstantCupertinoTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _withBackGesture(route, context, child);
}

Widget _withBackGesture<T>(
  PageRoute<T> route,
  BuildContext context,
  Widget child,
) => CupertinoRouteTransitionMixin.buildPageTransitions(
  route,
  context,
  kAlwaysCompleteAnimation,
  kAlwaysDismissedAnimation,
  child,
);

/// Pageless iOS routes have their own Cupertino transition, outside the theme.
class EinkCupertinoPageRoute<T> extends CupertinoPageRoute<T> {
  EinkCupertinoPageRoute({required super.builder, super.settings});

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  DelegatedTransitionBuilder? get delegatedTransition => null;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _withBackGesture(this, context, child);
}
