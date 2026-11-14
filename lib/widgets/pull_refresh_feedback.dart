import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/image_recovery_region.dart';

enum PullRefreshResult {
  updated,
  unchanged,
  checked,
  failed,
  retained,
  ignored,
}

/// Keeps feedback inside the list that requested it. A successful update is
/// visible in the content itself; background reads never enter this widget.
class PullRefreshFeedback extends StatefulWidget {
  const PullRefreshFeedback.indicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.active = true,
    this.scope,
    this.indicatorKey,
    this.notificationPredicate = defaultScrollNotificationPredicate,
  });

  final Future<PullRefreshResult> Function() onRefresh;
  final Widget child;
  final GlobalKey<RefreshIndicatorState>? indicatorKey;
  final ScrollNotificationPredicate notificationPredicate;
  final bool active;
  final Object? scope;

  @override
  State<PullRefreshFeedback> createState() => _PullRefreshFeedbackState();
}

class _PullRefreshFeedbackState extends State<PullRefreshFeedback> {
  Timer? _expiry;
  PullRefreshResult? _result;
  int _generation = 0;
  Object _imageRefresh = Object();

  @override
  void didUpdateWidget(PullRefreshFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active || oldWidget.scope != widget.scope) {
      _generation++;
      _expiry?.cancel();
      _result = null;
    }
  }

  Future<void> _refresh() async {
    if (!widget.active) return;
    final generation = ++_generation;
    _expiry?.cancel();
    if (_result != null) setState(() => _result = null);
    final result = await widget.onRefresh();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (!mounted ||
        lifecycle != null && lifecycle != AppLifecycleState.resumed ||
        generation != _generation ||
        !widget.active ||
        !TickerMode.valuesOf(context).enabled ||
        ModalRoute.isCurrentOf(context) == false ||
        result == PullRefreshResult.ignored) {
      return;
    }
    setState(() {
      if (result == PullRefreshResult.updated ||
          result == PullRefreshResult.unchanged ||
          result == PullRefreshResult.checked) {
        _imageRefresh = Object();
      }
      _result = result == PullRefreshResult.updated ? null : result;
    });
    if (_result == null) return;
    _expiry = Timer(
      Duration(
        seconds:
            result == PullRefreshResult.failed ||
                result == PullRefreshResult.retained
            ? 4
            : 2,
      ),
      () => setState(() => _result = null),
    );
  }

  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = switch (_result) {
      PullRefreshResult.checked => t.common.refreshChecked,
      PullRefreshResult.unchanged => t.common.refreshUnchanged,
      PullRefreshResult.retained => t.common.refreshRetained,
      PullRefreshResult.failed => t.common.refreshFailed,
      _ => null,
    };
    final colors = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        RefreshIndicator(
          key: widget.indicatorKey,
          notificationPredicate: (notification) =>
              widget.active && widget.notificationPredicate(notification),
          onRefresh: _refresh,
          child: PageImageRefreshScope(
            revision: _imageRefresh,
            child: widget.child,
          ),
        ),
        if (message != null &&
            TickerMode.valuesOf(context).enabled &&
            ModalRoute.isCurrentOf(context) != false)
          Positioned(
            top: 8,
            left: 16,
            right: 16,
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.topCenter,
                child: Semantics(
                  liveRegion: true,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
