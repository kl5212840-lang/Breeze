import 'package:flutter/foundation.dart';
import 'package:zephyr/page/donwload_task/service/download_interaction_trace.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/breeze_theme_colors.dart';

typedef DownloadSwipeAction = ({
  String id,
  String label,
  IconData icon,
  VoidCallback run,
});

/// A slide reveals commands only. A destructive command still goes through
/// the row's existing, version-bound confirmation.
class DownloadSwipeActions extends StatefulWidget {
  const DownloadSwipeActions({
    super.key,
    required this.rowKey,
    required this.openRow,
    required this.actions,
    required this.child,
    this.exposeActions = false,
    this.actionVersion,
    this.completedAt,
    this.lastReadAt,
  });

  final String rowKey;
  final ValueNotifier<String?> openRow;
  final List<DownloadSwipeAction> actions;
  final Widget child;
  final bool exposeActions;
  final Object? actionVersion;
  final DateTime? completedAt;
  final DateTime? lastReadAt;

  @override
  State<DownloadSwipeActions> createState() => _DownloadSwipeActionsState();
}

class _DownloadSwipeActionsState extends State<DownloadSwipeActions>
    with SingleTickerProviderStateMixin {
  static const _inset = 6.0;
  static const _verticalInset = 5.0;
  static const _backGestureEdge = 28.0;
  late final _slide = AnimationController(vsync: this);
  late final _outsideTap = _DownloadDismissTap()
    ..onTap = _dismiss
    ..onSecondaryTap = _dismiss;
  bool _dragging = false;
  bool _wasOpen = false;
  bool _dispatching = false;
  final _loggedLayouts = <String>{};

  double _actionExtent([DownloadSwipeAction? action]) {
    final labelSize = MediaQuery.textScalerOf(context).scale(12);
    if (widget.actions.length == 1 &&
        labelSize <= 16 &&
        (widget.completedAt != null || widget.lastReadAt != null)) {
      return 100;
    }
    final width = switch (widget.actions.length) {
      <= 2 => 66.0,
      3 => 60.0,
      _ => 54.0,
    };
    final slot = action?.id == 'pin' || action?.id == 'unpin' ? 66.0 : width;
    return slot +
        (MediaQuery.textScalerOf(context).scale(13) - 13).clamp(0.0, 16.0);
  }

  bool get _open => widget.openRow.value == widget.rowKey;
  double get _direction =>
      Directionality.of(context) == TextDirection.ltr ? 1 : -1;

  TickerFuture _animateTo(double value) => _slide.animateTo(
    value,
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Duration(
            milliseconds: 100 + (100 * (value - _slide.value).abs()).round(),
          ),
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    _slide.value = _open ? 1 : 0;
    widget.openRow.addListener(_sync);
  }

  @override
  void didUpdateWidget(covariant DownloadSwipeActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.openRow != widget.openRow) {
      oldWidget.openRow.removeListener(_sync);
      widget.openRow.addListener(_sync);
    }
    if (oldWidget.rowKey != widget.rowKey ||
        oldWidget.openRow != widget.openRow ||
        oldWidget.actionVersion != widget.actionVersion ||
        !listEquals(
          oldWidget.actions.map((action) => (action.id, action.label)).toList(),
          widget.actions.map((action) => (action.id, action.label)).toList(),
        )) {
      _reset();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!TickerMode.valuesOf(context).enabled && _open) _reset();
  }

  void _reset() {
    _dragging = false;
    _slide.value = 0;
    if (!_open) return;
    final owner = widget.openRow;
    final key = widget.rowKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && owner.value == key && _slide.value == 0 && !_dragging) {
        owner.value = null;
      }
    });
  }

  @override
  void dispose() {
    widget.openRow.removeListener(_sync);
    _outsideTap.dispose();
    _slide.dispose();
    super.dispose();
  }

  void _sync() {
    if (_open && (_dragging || _dispatching)) return;
    _dragging = false;
    _animateTo(_open ? 1 : 0);
  }

  void _start(DragStartDetails _) {
    if (_dispatching) return;
    _wasOpen = _open;
    _dragging = true;
    _slide.stop();
    widget.openRow.value = widget.rowKey;
  }

  void _update(DragUpdateDetails details, double width) {
    if (!_dragging) return;
    _slide.value = (_slide.value - details.delta.dx * _direction / width).clamp(
      0,
      1,
    );
  }

  void _end(DragEndDetails details, double width) {
    if (!_dragging) return;
    final velocity = -(details.primaryVelocity ?? 0) * _direction;
    // Adding another command widens the tray without making it harder to open.
    final openThreshold =
        (_actionExtent() * widget.actions.length.clamp(1, 2) + _inset * 2) *
        .42;
    final reveal = velocity.abs() > 420
        ? velocity > 0
        : _slide.value * width >= (_wasOpen ? width * .34 : openThreshold);
    _settle(reveal);
  }

  void _cancel() {
    if (!_dragging) return;
    _settle(_wasOpen);
  }

  void _settle(bool reveal) {
    _dragging = false;
    if (reveal) {
      _animateTo(1);
    } else {
      widget.openRow.value = null;
    }
  }

  void _reveal() {
    if (_dispatching || widget.actions.isEmpty || _open) return;
    widget.openRow.value = widget.rowKey;
  }

  void _dismiss() {
    if (_open) widget.openRow.value = null;
  }

  Future<void> _run(DownloadSwipeAction action) async {
    if (_dispatching || !_open || _slide.value < 1) return;
    final trace = DownloadInteractionTrace('swipe.${action.id}');
    final version = widget.actionVersion;
    _dispatching = true;
    try {
      await _animateTo(0).orCancel;
      trace.mark('close-complete');
      if (!mounted || !_open) return;
      widget.openRow.value = null;
      _perform(action, version);
      trace.mark('callback-dispatched');
    } on TickerCanceled {
      // A row that has scrolled out or changed scope no longer owns the action.
    } finally {
      if (mounted) setState(() => _dispatching = false);
    }
  }

  void _perform(DownloadSwipeAction action, Object? version) {
    if (mounted &&
        widget.actionVersion == version &&
        ModalRoute.of(context)?.isCurrent == true &&
        widget.actions.any((current) => current.id == action.id)) {
      action.run();
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _buildSlide(
      (widget.actions.fold(
                0.0,
                (width, action) => width + _actionExtent(action),
              ) +
              _inset * 2)
          .clamp(0.0, constraints.maxWidth),
    ),
  );

  Widget _buildSlide(double width) => AnimatedBuilder(
    animation: Listenable.merge([_slide, widget.openRow]),
    child: widget.child,
    builder: (context, child) {
      final direction = _direction;
      final revealed = _slide.value > 0;
      final revealedWidth = _slide.value * width;
      final interactive = _open && !_dispatching && _slide.value == 1;
      final version = widget.actionVersion;
      final exposeActions = widget.exposeActions;
      final theme = Theme.of(context);
      final colors = theme.colorScheme;
      final surface = Color.alphaBlend(
        Scaffold.maybeOf(context)?.widget.backgroundColor ??
            theme.scaffoldBackgroundColor,
        colors.surface,
      );
      final well = Color.alphaBlend(
        colors.onSurface.withValues(alpha: .06),
        surface,
      );
      final tray = Color.alphaBlend(
        colors.primary.withValues(alpha: .045),
        surface,
      );
      final separation = Curves.easeOut.transform(_slide.value);
      // Observe outside pointers without consuming their drags. Only a tap
      // wins dismissal ahead of the underlying button's ordinary arena sweep.
      return TapRegion(
        enabled: _open,
        onTapOutside: (event) {
          if (!_open) return;
          if (event.pointer != 0) {
            _outsideTap.addPointer(event);
          } else {
            _dismiss();
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _open ? _dismiss : null,
          child: ClipRect(
            clipBehavior: revealed ? Clip.hardEdge : Clip.none,
            child: Stack(
              children: [
                if (revealed)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        key: ValueKey('download-swipe-well.${widget.rowKey}'),
                        decoration: BoxDecoration(
                          color: well,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                if (revealed)
                  PositionedDirectional(
                    top: 0,
                    bottom: 0,
                    end: 0,
                    width: width,
                    child: IgnorePointer(
                      ignoring: !interactive,
                      child: ExcludeSemantics(
                        excluding: !interactive,
                        child: _tray(context, tray),
                      ),
                    ),
                  ),
                Transform.translate(
                  offset: Offset(-revealedWidth * direction, 0),
                  child: RawGestureDetector(
                    behavior: HitTestBehavior.opaque,
                    gestures: {
                      _DownloadRowDrag:
                          GestureRecognizerFactoryWithHandlers<
                            _DownloadRowDrag
                          >(_DownloadRowDrag.new, (gesture) {
                            final screen = MediaQuery.sizeOf(context).width;
                            gesture.canStart = (point) =>
                                width > 0 &&
                                widget.actions.isNotEmpty &&
                                !_dispatching &&
                                (direction == 1
                                    ? point.dx >= _backGestureEdge
                                    : point.dx <= screen - _backGestureEdge);
                            gesture
                              ..onStart = _start
                              ..onUpdate = (details) {
                                _update(details, width);
                              }
                              ..onEnd = (details) {
                                _end(details, width);
                              }
                              ..onCancel = _cancel;
                          }),
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onSecondaryTap: exposeActions && widget.actions.isNotEmpty
                          ? _reveal
                          : null,
                      child: Semantics(
                        customSemanticsActions: exposeActions && !revealed
                            ? {
                                for (final action in widget.actions)
                                  CustomSemanticsAction(
                                    label: action.label,
                                  ): () {
                                    if (!_dispatching) {
                                      _perform(action, version);
                                    }
                                  },
                              }
                            : null,
                        child: AbsorbPointer(
                          absorbing: revealed || _dispatching,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: revealed ? surface : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: revealed
                                  ? [
                                      BoxShadow(
                                        color: colors.shadow.withValues(
                                          alpha:
                                              (colors.brightness ==
                                                      Brightness.dark
                                                  ? .14
                                                  : .07) *
                                              separation,
                                        ),
                                        blurRadius: 5,
                                        offset: Offset(direction, 1),
                                      ),
                                    ]
                                  : const [],
                            ),
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _tray(BuildContext context, Color background) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final scaler = MediaQuery.textScalerOf(context);
    final scaled = scaler.scale(12);
    final timeHeight = (scaler.scale(10) * 1.1).ceilToDouble() + 2;
    final detail = widget.completedAt ?? widget.lastReadAt;
    final local = detail != null && detail.millisecondsSinceEpoch > 0
        ? detail.toLocal()
        : null;
    final locale = MaterialLocalizations.of(context);
    final date = local == null
        ? null
        : local.year == DateTime.now().year
        ? locale.formatShortMonthDay(local)
        : locale.formatShortDate(local);
    final time = local == null
        ? null
        : locale.formatTimeOfDay(
            TimeOfDay.fromDateTime(local),
            alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
          );
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    return LayoutBuilder(
      builder: (context, box) {
        final available = (box.maxHeight - 2 * _verticalInset).clamp(
          0.0,
          box.maxHeight,
        );
        final showTime =
            date != null && scaled <= 16 && available >= 44 + timeHeight;
        final tall = available >= 100;
        final trayHeight = tall
            ? 72.0
            : showTime
            ? 44 + timeHeight
            : (scaled > 16 ? 62.0 : 52.0);
        return Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _inset / 2),
            child: SizedBox(
              height: trayHeight.clamp(0.0, available),
              child: Material(
                key: ValueKey('download-swipe-tray.${widget.rowKey}'),
                color: background,
                surfaceTintColor: Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                clipBehavior: Clip.hardEdge,
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final action in widget.actions)
                            Expanded(
                              flex: (_actionExtent(action) * 100).round(),
                              child: _command(
                                context,
                                action,
                                background,
                                tall: tall,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (showTime)
                      SizedBox(
                        height: timeHeight,
                        child: Text(
                          '$date $time',
                          key: ValueKey('download-swipe-time.${widget.rowKey}'),
                          semanticsLabel: widget.completedAt != null
                              ? (chinese
                                    ? '下载于 $date $time'
                                    : 'Downloaded $date $time')
                              : (chinese
                                    ? '阅读于 $date $time'
                                    : 'Read $date $time'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: BreezeThemeColors.readableOn(
                              colors.onSurfaceVariant,
                              background,
                            ),
                            fontSize: 10,
                            height: 1.1,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _command(
    BuildContext context,
    DownloadSwipeAction action,
    Color background, {
    required bool tall,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final destructive = colors.brightness == Brightness.dark
        ? const Color(0xffff453a)
        : const Color(0xffd51920);
    final color = BreezeThemeColors.readableOn(
      action.id == 'delete' ? destructive : colors.onSurface,
      background,
    );
    final caption = switch (action.id) {
      'details' => t.common.detail,
      'export' => t.common.export,
      'delete' => t.common.delete,
      'cancel' => t.common.cancel,
      'unpin' when Localizations.localeOf(context).languageCode == 'zh' => '取消',
      'next' when Localizations.localeOf(context).languageCode == 'zh' => '优先',
      _ => action.label,
    };
    return InkWell(
      key: ValueKey('download-swipe.${widget.rowKey}.${action.id}'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => _run(action),
      child: LayoutBuilder(
        builder: (context, box) {
          assert(() {
            final style = theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontSize: tall ? 13 : null,
            );
            final painter = TextPainter(
              text: TextSpan(text: caption, style: style),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout();
            final signature = '${action.id}:${box.maxWidth}:${painter.width}';
            if (_loggedLayouts.add(signature)) {
              debugPrint(
                '[download-layout] action=${action.id} '
                'count=${widget.actions.length} slot=${box.maxWidth} '
                'textAvailable=${box.maxWidth - 10} '
                'textIntrinsic=${painter.width} '
                'font=${style?.fontFamily} size=${style?.fontSize} '
                'scale13=${MediaQuery.textScalerOf(context).scale(13)}',
              );
            }
            painter.dispose();
            return true;
          }());
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: tall ? 5 : 3,
                children: [
                  if (box.maxHeight >= 36 &&
                      MediaQuery.textScalerOf(context).scale(14) <= 20)
                    Icon(action.icon, size: tall ? 20 : 16, color: color),
                  Flexible(
                    child: SizedBox(
                      height:
                          tall &&
                              MediaQuery.textScalerOf(context).scale(13) > 16
                          ? MediaQuery.textScalerOf(context).scale(13) * 2.6
                          : null,
                      child: Align(
                        alignment: Alignment.topCenter,
                        heightFactor: 1,
                        child: Text(
                          caption,
                          semanticsLabel: action.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: color,
                            fontSize: tall ? 13 : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DownloadRowDrag extends HorizontalDragGestureRecognizer {
  bool Function(Offset)? canStart;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      (canStart?.call(event.position) ?? true) && super.isPointerAllowed(event);
}

class _DownloadDismissTap extends TapGestureRecognizer {
  @override
  void handlePrimaryPointer(PointerEvent event) {
    if (event is PointerUpEvent) resolve(GestureDisposition.accepted);
    super.handlePrimaryPointer(event);
  }
}
