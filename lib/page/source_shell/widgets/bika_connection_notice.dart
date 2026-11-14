import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoAlertDialog, CupertinoDialogAction, CupertinoDialogRoute;
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_experience_preferences.dart';
import 'package:zephyr/page/source_shell/source_loading_indicator.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/read_recovery_scope.dart';

class BikaConnectionNotice extends StatefulWidget {
  const BikaConnectionNotice._({
    super.key,
    required this.failure,
    required this.ready,
    required this.retry,
    required this.child,
  });

  final String? failure;
  final bool ready;
  final VoidCallback retry;
  final Widget child;

  static Widget wrap({
    required String source,
    Object? scope,
    required String? failure,
    required bool ready,
    required VoidCallback retry,
    required Widget child,
  }) => isBikaExperienceSource(source)
      ? BikaConnectionNotice._(
          key: ValueKey((source, scope)),
          failure: failure,
          ready: ready,
          retry: retry,
          child: child,
        )
      : child;

  @override
  State<BikaConnectionNotice> createState() => _BikaConnectionNoticeState();
}

class _BikaConnectionNoticeState extends State<BikaConnectionNotice> {
  static final _serverFailure = RegExp(
    r'哔咔服务暂时无法响应|\bHTTP\s+5\d\d\b',
    caseSensitive: false,
  );
  bool _shown = false;
  bool _queued = false;
  Animation<double>? _routeAnimation;
  ModalRoute<bool>? _dialog;

  bool get _serverUnavailable => _serverFailure.hasMatch(widget.failure ?? '');

  bool get _blockedByConnection =>
      _serverUnavailable ||
      (widget.failure?.contains('连接哔咔超时') ?? false) ||
      (widget.failure?.contains('无法连接哔咔') ?? false);

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
    if (widget.ready) {
      _shown = false;
      _dismissAfterFrame();
    }
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
    final useCupertino =
        AppInterfaceStyleScope.usesSystem(context) &&
        Theme.of(context).platform == TargetPlatform.iOS;
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
    final route = useCupertino
        ? CupertinoDialogRoute<bool>(
            context: context,
            builder: (dialogContext) => CupertinoAlertDialog(
              title: title,
              content: content,
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(t.common.close),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(t.common.retry),
                ),
              ],
            ),
          )
        : DialogRoute<bool>(
            context: context,
            themes: InheritedTheme.capture(
              from: context,
              to: navigator.context,
            ),
            builder: (dialogContext) => AlertDialog(
              title: title,
              content: content,
              scrollable: true,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(t.common.close),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
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
