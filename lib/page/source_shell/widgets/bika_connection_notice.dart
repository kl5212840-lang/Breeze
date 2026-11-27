import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_experience_preferences.dart';
import 'package:zephyr/page/source_shell/source_loading_indicator.dart';
import 'package:zephyr/widgets/read_recovery_scope.dart';
import 'package:zephyr/widgets/short_alert.dart';

class BikaConnectionNotice extends StatefulWidget {
  const BikaConnectionNotice._({
    super.key,
    required this.failure,
    required this.ready,
    required this.retry,
    required this.manualAttempt,
    required this.child,
  });

  final String? failure;
  final bool ready;
  final VoidCallback retry;
  final int manualAttempt;
  final Widget child;

  static final _serverFailure = RegExp(
    r'哔咔服务暂时无法响应|\bHTTP\s+5\d\d\b',
    caseSensitive: false,
  );

  static bool handlesFailure(String? failure) =>
      _serverFailure.hasMatch(failure ?? '') ||
      (failure?.contains('连接哔咔超时') ?? false) ||
      (failure?.contains('无法连接哔咔') ?? false);

  static Widget wrap({
    required String source,
    Object? scope,
    required String? failure,
    required bool ready,
    required VoidCallback retry,
    int manualAttempt = 0,
    required Widget child,
  }) => isBikaExperienceSource(source)
      ? BikaConnectionNotice._(
          key: ValueKey((source, scope)),
          failure: failure,
          ready: ready,
          retry: retry,
          manualAttempt: manualAttempt,
          child: child,
        )
      : child;

  @override
  State<BikaConnectionNotice> createState() => _BikaConnectionNoticeState();
}

class _BikaConnectionNoticeState extends State<BikaConnectionNotice> {
  bool _shown = false;
  bool _queued = false;
  Animation<double>? _routeAnimation;
  ModalRoute<bool>? _dialog;

  bool get _serverUnavailable =>
      BikaConnectionNotice._serverFailure.hasMatch(widget.failure ?? '');

  bool get _blockedByConnection =>
      BikaConnectionNotice.handlesFailure(widget.failure);

  bool get _canPresent {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return mounted &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed) &&
        ReadRecoveryScope.activeOf(context) &&
        TickerMode.valuesOf(context).enabled &&
        ModalRoute.isCurrentOf(context) != false &&
        _routeAnimation?.status != AnimationStatus.forward &&
        _routeAnimation?.status != AnimationStatus.reverse;
  }

  void _routeChanged(AnimationStatus _) => _schedule();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (!identical(animation, _routeAnimation)) {
      _routeAnimation?.removeStatusListener(_routeChanged);
      _routeAnimation = animation;
      _routeAnimation?.addStatusListener(_routeChanged);
    }
  }

  @override
  void didUpdateWidget(BikaConnectionNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ready || widget.manualAttempt != oldWidget.manualAttempt) {
      _shown = false;
    }
    if (widget.ready) _dismissAfterFrame();
  }

  void _schedule() {
    if (_shown || _queued || !_blockedByConnection || !_canPresent) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (!_canPresent || !_blockedByConnection || _shown) return;
      _shown = true;
      unawaited(_show());
    });
  }

  Future<void> _show() async {
    final title = Text(t.sourceShell.bikaConnectionNotice);
    final description = Text(
      _serverUnavailable
          ? t.sourceShell.bikaServerUnavailable
          : t.sourceShell.bikaConnectionUnavailable,
      textAlign: TextAlign.center,
    );
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox.square(
          dimension: 64,
          child: BikaStatusArtwork(kind: BikaStatusKind.error, extent: 64),
        ),
        const SizedBox(height: 8),
        description,
      ],
    );
    final navigator = Navigator.of(context);
    final route = shortAlertRoute<bool>(
      context: context,
      navigator: navigator,
      builder: (dialog) => ShortAlert(
        title: title,
        content: content,
        actions: [
          ShortAlertAction(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(t.common.close),
          ),
          ShortAlertAction(
            onPressed: () => Navigator.pop(dialog, true),
            isDefaultAction: true,
            child: Text(t.common.retry),
          ),
        ],
      ),
    );
    _dialog = route;
    final retry = await navigator.push(route);
    if (identical(_dialog, route)) _dialog = null;
    if (retry == true && mounted && _blockedByConnection) widget.retry();
  }

  void _dismissAfterFrame() {
    final route = _dialog;
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = route.navigator;
      if (route.isCurrent) {
        navigator?.pop(false);
      } else if (route.isActive) {
        navigator?.removeRoute(route, false);
      }
    });
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_routeChanged);
    _dismissAfterFrame();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _schedule();
    return widget.child;
  }
}
