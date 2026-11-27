import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/config/global/global_setting.dart';

/// Coordinates scroll intent with a bottom bar while keeping the bar's layout
/// extent and the content viewport stable during the transition.
class BreezeScrollNavigation extends StatefulWidget {
  const BreezeScrollNavigation({
    super.key,
    required this.content,
    required this.builder,
    this.ownsNavigation = true,
    this.acceptsScroll = true,
    this.rootTabOnly = false,
  });

  final Object? content;
  final bool ownsNavigation;
  final bool acceptsScroll;
  final bool rootTabOnly;
  final Widget Function(BuildContext, BreezeScrollNavigationState) builder;

  @override
  State<BreezeScrollNavigation> createState() => BreezeScrollNavigationState();
}

class BreezeScrollNavigationState extends State<BreezeScrollNavigation>
    with WidgetsBindingObserver {
  static const _hideDistance = 18.0;
  static const _showDistance = 10.0;
  static const _edgeTolerance = 0.5;
  static const _hideDuration = Duration(milliseconds: 160);
  static const _showDuration = Duration(milliseconds: 200);

  final _hidden = ValueNotifier(false);
  bool _foreground = true;
  bool _automatic = false;
  ModalRoute<dynamic>? _route;
  bool _routeIsCurrent = true;
  bool _keyboardVisible = false;
  double _travel = 0;
  BuildContext? _scrollSource;

  bool get automatic => _automatic;

  @override
  void initState() {
    super.initState();
    final initialState = WidgetsBinding.instance.lifecycleState;
    _foreground =
        initialState == null || initialState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) restore();
  }

  @override
  void handleStatusBarTap() {
    if (_automatic && _routeIsCurrent && _foreground && widget.acceptsScroll) {
      restore();
    }
  }

  @override
  void didUpdateWidget(BreezeScrollNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.content != oldWidget.content ||
        widget.acceptsScroll != oldWidget.acceptsScroll ||
        widget.ownsNavigation != oldWidget.ownsNavigation) {
      restore();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hidden.dispose();
    super.dispose();
  }

  void restore() {
    _travel = 0;
    _scrollSource = null;
    _hidden.value = false;
  }

  bool _onScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    final source = notification.context;
    if (!_automatic ||
        !widget.acceptsScroll ||
        !_foreground ||
        !_routeIsCurrent ||
        _keyboardVisible ||
        metrics.axis != Axis.vertical ||
        source == null ||
        source.getInheritedWidgetOfExactType<_NavigationOwner>()?.state !=
            this ||
        !TickerMode.getValuesNotifier(source).value.enabled) {
      return false;
    }
    final route = ModalRoute.of(source);
    if (widget.rootTabOnly
        ? route != null && (!route.isFirst || !route.isCurrent)
        : route != _route) {
      return false;
    }
    _trackTravel(notification, metrics, source);
    return false;
  }

  void _trackTravel(
    ScrollNotification notification,
    ScrollMetrics metrics,
    BuildContext source,
  ) {
    final atStart = metrics.pixels <= metrics.minScrollExtent + _edgeTolerance;
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _scrollSource = source;
      _travel = 0;
      return;
    }
    if (notification is ScrollEndNotification && _scrollSource == source) {
      if (_travel < 0 && atStart) restore();
      _travel = 0;
      _scrollSource = null;
      return;
    }
    if (notification is OverscrollNotification &&
        notification.dragDetails != null &&
        notification.overscroll < 0 &&
        atStart) {
      restore();
      return;
    }
    if (notification is! ScrollUpdateNotification ||
        notification.dragDetails == null ||
        metrics.maxScrollExtent <= metrics.minScrollExtent) {
      return;
    }

    final scrollDelta = notification.scrollDelta ?? 0;
    if (scrollDelta < 0 && atStart) {
      restore();
      return;
    }

    // Ignore spring and elastic movement outside the actual content range.
    final current = metrics.pixels.clamp(
      metrics.minScrollExtent,
      metrics.maxScrollExtent,
    );
    final previous = (metrics.pixels - scrollDelta).clamp(
      metrics.minScrollExtent,
      metrics.maxScrollExtent,
    );
    final delta = (current - previous).toDouble();
    if (delta == 0) return;
    if (_scrollSource != source) {
      _scrollSource = source;
      _travel = 0;
    }
    if (delta.sign != _travel.sign) _travel = 0;
    _travel += delta;
    if (_hidden.value && _travel <= -_showDistance) {
      restore();
    } else if (!_hidden.value && _travel >= _hideDistance) {
      _hidden.value = true;
      _travel = 0;
    }
  }

  /// Translate painting and hit testing together without changing the bar's
  /// layout. The viewport clips the translation at the bottom of the screen.
  Widget bar(Widget child, {bool hideForKeyboard = false}) =>
      ValueListenableBuilder<bool>(
        valueListenable: _hidden,
        child: child,
        builder: (context, hidden, child) {
          final concealed =
              _automatic && hidden || hideForKeyboard && _keyboardVisible;
          return AnimatedSlide(
            offset: concealed ? const Offset(0, 1) : Offset.zero,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : concealed
                ? _hideDuration
                : _showDuration,
            curve: Curves.easeOutCubic,
            child: ExcludeFocus(
              excluding: concealed,
              child: ExcludeSemantics(
                excluding: concealed,
                child: IgnorePointer(ignoring: concealed, child: child),
              ),
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final platform = defaultTargetPlatform;
    final preference = context.select<GlobalSettingCubit?, bool>(
      (cubit) => cubit?.state.navigationHidesOnScroll ?? false,
    );
    final automatic =
        widget.ownsNavigation &&
        !kIsWeb &&
        (platform == TargetPlatform.iOS ||
            platform == TargetPlatform.android) &&
        preference;
    final route = ModalRoute.of(context);
    final routeIsCurrent = route?.isCurrent ?? true;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (automatic != _automatic ||
        route != _route ||
        routeIsCurrent != _routeIsCurrent ||
        keyboardVisible != _keyboardVisible) {
      restore();
    }
    _automatic = automatic;
    _route = route;
    _routeIsCurrent = routeIsCurrent;
    _keyboardVisible = keyboardVisible;
    final owner = widget.ownsNavigation
        ? this
        : context.dependOnInheritedWidgetOfExactType<_NavigationOwner>()?.state;
    return _NavigationOwner(
      state: owner,
      child: NotificationListener<ScrollNotification>(
        onNotification: _automatic ? _onScroll : null,
        child: ClipRect(
          clipBehavior: _automatic ? Clip.hardEdge : Clip.none,
          child: widget.builder(context, this),
        ),
      ),
    );
  }
}

class _NavigationOwner extends InheritedWidget {
  const _NavigationOwner({required this.state, required super.child});

  final BreezeScrollNavigationState? state;

  @override
  bool updateShouldNotify(_NavigationOwner oldWidget) =>
      state != oldWidget.state;
}
