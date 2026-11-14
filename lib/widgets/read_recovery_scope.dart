import 'package:flutter/widgets.dart';

/// Persistent tabs must explicitly publish visibility; IndexedStack alone does
/// not disable their tickers or their asynchronous read demand.
class ReadRecoveryScope extends InheritedWidget {
  const ReadRecoveryScope({
    super.key,
    required this.active,
    required super.child,
  });
  final bool active;
  static bool activeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReadRecoveryScope>()?.active ??
      true;
  @override
  bool updateShouldNotify(ReadRecoveryScope oldWidget) =>
      active != oldWidget.active;
}

/// Reports tab + route + foreground visibility to a read owner. Reuses the
/// actual route host, including ordinary Navigator and embedded source tabs.
class ReadRecoveryHost extends StatefulWidget {
  const ReadRecoveryHost({
    super.key,
    required this.onActiveChanged,
    this.keepActiveWhileCovered,
    required this.child,
  });
  final ValueChanged<bool> onActiveChanged;
  final bool Function()? keepActiveWhileCovered;
  final Widget child;
  @override
  State<ReadRecoveryHost> createState() => _ReadRecoveryHostState();
}

class _ReadRecoveryHostState extends State<ReadRecoveryHost>
    with WidgetsBindingObserver {
  bool? _active;
  bool _scopeActive = true, _tickerActive = true, _routeActive = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _update() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final active =
        _scopeActive &&
        _tickerActive &&
        (_routeActive || widget.keepActiveWhileCovered?.call() == true) &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
    if (_active == active) return;
    _active = active;
    widget.onActiveChanged(active);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scopeActive = ReadRecoveryScope.activeOf(context);
    _tickerActive = TickerMode.of(context);
    _routeActive = ModalRoute.of(context)?.isCurrent != false;
    _update();
  }

  @override
  void didUpdateWidget(ReadRecoveryHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onActiveChanged != widget.onActiveChanged) {
      widget.onActiveChanged(_active ?? false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _update();
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
