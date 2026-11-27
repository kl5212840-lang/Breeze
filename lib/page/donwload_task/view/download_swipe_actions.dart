import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/donwload_task/service/download_interaction_trace.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/widgets/breeze_theme_colors.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'package:zephyr/widgets/swipe_row_tap_region.dart';

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
    this.swipeActionIds = const [],
    this.information,
    this.groupSecondaryActions = true,
    this.title,
    this.actionVersion,
    this.completedAt,
    this.lastReadAt,
  });

  final String rowKey;
  final ValueNotifier<String?> openRow;
  final List<DownloadSwipeAction> actions;
  final Widget child;
  final bool exposeActions;

  /// Ordered shortcuts selected by the row's scope and transfer state.
  final List<String> swipeActionIds;

  /// Local information for rows that own a download rather than a work route.
  final List<String>? information;
  final bool groupSecondaryActions;
  final String? title;
  final Object? actionVersion;
  final DateTime? completedAt;
  final DateTime? lastReadAt;

  static bool bodyEnabled(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_DownloadMoreScope>()
          ?.bodyEnabled ??
      true;

  @override
  State<DownloadSwipeActions> createState() => _DownloadSwipeActionsState();
}

/// The row menu has a full touch target and a quiet mark on the title line.
class DownloadRowMoreButton extends StatelessWidget {
  const DownloadRowMoreButton({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_DownloadMoreScope>();
    final show = scope?.onPressed;
    if (show == null) return const SizedBox.shrink();
    final extent = CollectionToolbarMetrics.actionExtentOf(context);
    final colors = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.titleSmall;
    final lineHeight =
        MediaQuery.textScalerOf(context).scale(titleStyle?.fontSize ?? 14) *
        (titleStyle?.height ?? 1.2);
    const glyphSize = 16.0;
    final markInset = ((lineHeight - glyphSize) / 2).clamp(
      2.0,
      extent - glyphSize,
    );
    final surface = _rowSurface(context);
    final highContrast = MediaQuery.highContrastOf(context);
    final iconColor = BreezeThemeColors.readableOn(
      Color.lerp(surface, colors.onSurfaceVariant, .54)!,
      surface,
      minimumContrast: highContrast ? 4.5 : 3,
    );
    return IconButton(
      key: key == null ? ValueKey('download-row-more.${scope!.rowKey}') : null,
      onPressed: show,
      tooltip: t.common.more,
      icon: const Icon(Icons.more_vert_rounded, size: glyphSize),
      style: IconButton.styleFrom(
        fixedSize: Size.square(extent),
        minimumSize: Size.square(extent),
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        alignment: Alignment.topCenter,
        padding: EdgeInsets.only(top: markInset),
        foregroundColor: iconColor,
      ),
    );
  }
}

/// Keeps the command in its layout slot while the row is sliding.
class DownloadRowControl extends StatelessWidget {
  const DownloadRowControl({
    super.key,
    required this.child,
    this.visible = true,
  });

  final Widget child;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !DownloadSwipeActions.bodyEnabled(context),
      child: Visibility(
        visible: visible,
        maintainAnimation: true,
        maintainState: true,
        maintainSize: true,
        child: child,
      ),
    );
  }
}

class _DownloadMoreScope extends InheritedWidget {
  const _DownloadMoreScope({
    required this.rowKey,
    required this.onPressed,
    required this.bodyEnabled,
    required super.child,
  });

  final String rowKey;
  final VoidCallback? onPressed;
  final bool bodyEnabled;

  @override
  bool updateShouldNotify(_DownloadMoreScope oldWidget) =>
      rowKey != oldWidget.rowKey ||
      onPressed != oldWidget.onPressed ||
      bodyEnabled != oldWidget.bodyEnabled;
}

Color _rowSurface(BuildContext context) {
  final theme = Theme.of(context);
  return Color.alphaBlend(
    Scaffold.maybeOf(context)?.widget.backgroundColor ??
        theme.scaffoldBackgroundColor,
    theme.colorScheme.surface,
  );
}

class _DownloadSwipeActionsState extends State<DownloadSwipeActions>
    with SingleTickerProviderStateMixin {
  static const _backGestureEdge = 28.0;
  static const _labelSize = 12.0;
  static const _rowRadius = BorderRadius.all(Radius.circular(12));
  late final _slide = AnimationController(vsync: this);
  bool _dragging = false;
  bool _wasOpen = false;
  bool _dispatching = false;
  int _actionEpoch = 0;

  List<DownloadSwipeAction> get _actions => [
    ...widget.actions,
    if (widget.information != null)
      (
        id: 'info',
        label: Localizations.localeOf(context).languageCode == 'zh'
            ? '下载详情'
            : 'Download details',
        icon: Icons.info_outline_rounded,
        run: _openInformation,
      ),
  ];

  double get _minimumTarget => CollectionToolbarMetrics.actionExtentOf(context);

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
    final ownerChanged =
        oldWidget.rowKey != widget.rowKey ||
        oldWidget.openRow != widget.openRow ||
        oldWidget.actionVersion != widget.actionVersion;
    if (ownerChanged ||
        oldWidget.groupSecondaryActions != widget.groupSecondaryActions ||
        !listEquals(oldWidget.swipeActionIds, widget.swipeActionIds) ||
        (oldWidget.information == null) != (widget.information == null) ||
        !listEquals(
          oldWidget.actions.map((action) => (action.id, action.label)).toList(),
          widget.actions.map((action) => (action.id, action.label)).toList(),
        )) {
      // Loading an additional shortcut may redraw the tray without changing
      // the download owned by an already open menu.
      _reset(invalidateActions: ownerChanged);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!TickerMode.valuesOf(context).enabled && _open) _reset();
  }

  void _reset({bool invalidateActions = true}) {
    if (invalidateActions) _actionEpoch++;
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
    final openThreshold = width.clamp(0.0, 132.0) * .42;
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
      if (_open) {
        widget.openRow.value = null;
      } else {
        _animateTo(0);
      }
    }
  }

  void _reveal() {
    if (_dispatching || _actions.isEmpty || _open) return;
    widget.openRow.value = widget.rowKey;
  }

  void _dismiss() {
    if (_open) widget.openRow.value = null;
  }

  Future<void> _run(String id) async {
    if (_dispatching || !_open || _slide.value < 1) return;
    final trace = DownloadInteractionTrace('swipe.$id');
    final epoch = _actionEpoch;
    _dispatching = true;
    try {
      await _animateTo(0).orCancel;
      trace.mark('close-complete');
      if (!_open || !_ownsAction(epoch)) return;
      widget.openRow.value = null;
      _perform(id, epoch);
      trace.mark('callback-dispatched');
    } on TickerCanceled {
      // A row that has scrolled out or changed scope no longer owns the action.
    } finally {
      if (mounted) setState(() => _dispatching = false);
    }
  }

  bool _ownsAction(int epoch) =>
      mounted &&
      _actionEpoch == epoch &&
      TickerMode.valuesOf(context).enabled &&
      ModalRoute.of(context)?.isCurrent == true;

  void _perform(String id, int epoch) {
    if (!_ownsAction(epoch)) return;
    _actions.where((action) => action.id == id).firstOrNull?.run();
  }

  Future<void> _openMore() async {
    final epoch = _actionEpoch;
    if (_dispatching ||
        _dragging ||
        !widget.groupSecondaryActions ||
        _actions.isEmpty ||
        !_ownsAction(epoch)) {
      return;
    }
    final rowKey = widget.rowKey;
    final title = widget.title?.trim() ?? '';
    final actions = _actions;
    _dispatching = true;
    widget.openRow.value = null;
    ModalRoute<String>? sheetRoute;
    try {
      final selected = await showVideoTaskSheet<String>(
        context: context,
        useRootNavigator: true,
        builder: (sheetContext) {
          sheetRoute = ModalRoute.of<String>(sheetContext);
          return _DownloadActionSheet(
            rowKey: rowKey,
            title: title.isEmpty ? t.common.more : title,
            actions: actions,
            completedAt: widget.information == null ? widget.completedAt : null,
            lastReadAt: widget.information == null ? widget.lastReadAt : null,
          );
        },
      );
      if (selected == null) return;
      await sheetRoute?.completed;
      await WidgetsBinding.instance.endOfFrame;
      _perform(selected, epoch);
    } finally {
      if (mounted) setState(() => _dispatching = false);
    }
  }

  void _openInformation() {
    final information = widget.information;
    if (information == null) return;
    unawaited(
      showVideoTaskSheet<void>(
        context: context,
        useRootNavigator: true,
        builder: (_) => _DownloadActionSheet(
          rowKey: widget.rowKey,
          title: widget.title?.trim().isNotEmpty == true
              ? widget.title!.trim()
              : t.common.detail,
          actions: const [],
          information: information,
          completedAt: widget.completedAt,
          lastReadAt: widget.lastReadAt,
        ),
      ),
    );
  }

  String _caption(BuildContext context, DownloadSwipeAction action) {
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    return switch (action.id) {
      'delete' => t.common.delete,
      'details' || 'info' => t.common.detail,
      'next' when chinese => '优先',
      'unpin' when chinese => '取消',
      _ => action.label,
    };
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final actions = _actions;
      final shortcuts = [
        for (final id in widget.swipeActionIds)
          ?actions.where((action) => action.id == id).firstOrNull,
      ];
      if (shortcuts.isEmpty || constraints.maxWidth < 2 * _minimumTarget) {
        return _buildSlide(
          const [],
          0,
          const [],
          const TextStyle(),
          actions.isNotEmpty,
        );
      }

      final labelStyle = DefaultTextStyle.of(context).style
          .merge(Theme.of(context).textTheme.labelMedium)
          .copyWith(inherit: false, fontSize: _labelSize, height: 1.15);
      final width = !widget.groupSecondaryActions
          ? 76.0
          : math.min(
              64.0 * shortcuts.length,
              math.max(
                _minimumTarget * shortcuts.length,
                constraints.maxWidth * .46,
              ),
            );
      final slot = widget.groupSecondaryActions
          ? width / shortcuts.length
          : 64.0;
      final captions = [
        for (final action in shortcuts)
          _captionThatFits(
            context,
            _caption(context, action),
            labelStyle,
            slot,
          ),
      ];
      return _buildSlide(
        shortcuts,
        width,
        captions,
        labelStyle,
        actions.isNotEmpty,
      );
    },
  );

  String _captionThatFits(
    BuildContext context,
    String text,
    TextStyle style,
    double width,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    )..layout();
    final fits = painter.width <= width - 8;
    painter.dispose();
    return fits ? text : '';
  }

  Widget _buildSlide(
    List<DownloadSwipeAction> shortcuts,
    double width,
    List<String> captions,
    TextStyle labelStyle,
    bool hasActions,
  ) => AnimatedBuilder(
    animation: Listenable.merge([_slide, widget.openRow]),
    child: widget.child,
    builder: (context, child) {
      final shortcut = shortcuts.firstOrNull;
      final reveal = width * _slide.value;
      final revealed = reveal > 0;
      final interactive = _open && !_dispatching && _slide.value == 1;
      final suspended = revealed || _dispatching;
      final direction = _direction;
      final epoch = _actionEpoch;
      final flat = widget.groupSecondaryActions;
      final surface = _rowSurface(context);
      final colors = Theme.of(context).colorScheme;
      final tone = shortcuts.length == 1 && shortcuts.first.id == 'delete'
          ? colors.error
          : colors.primary;
      final well = Color.alphaBlend(
        flat
            ? tone.withValues(
                alpha: colors.brightness == Brightness.dark ? .17 : .09,
              )
            : colors.onSurface.withValues(alpha: .06),
        surface,
      );
      final legacyPlate = Color.alphaBlend(
        colors.primary.withValues(alpha: .05),
        surface,
      );

      Widget actionWell() => DecoratedBox(
        key: ValueKey('download-swipe-well.${widget.rowKey}'),
        decoration: BoxDecoration(color: well, borderRadius: _rowRadius),
      );

      Widget tray() {
        final background = flat ? well : legacyPlate;
        final error = flat
            ? colors.error
            : colors.brightness == Brightness.dark
            ? const Color(0xffff453a)
            : const Color(0xffd51920);
        final material = Material(
          key: ValueKey('download-swipe-tray.${widget.rowKey}'),
          type: flat ? MaterialType.transparency : MaterialType.canvas,
          color: flat ? null : background,
          surfaceTintColor: flat ? null : Colors.transparent,
          borderRadius: flat ? null : _rowRadius,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < shortcuts.length; i++)
                Expanded(
                  child: _command(
                    shortcuts[i],
                    caption: captions[i],
                    style: labelStyle.copyWith(
                      color: BreezeThemeColors.readableOn(
                        shortcuts[i].id == 'delete' ? error : colors.primary,
                        background,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
        return IgnorePointer(
          ignoring: !interactive,
          child: ExcludeSemantics(
            excluding: !interactive,
            child: flat
                ? material
                : Center(
                    child: SizedBox(width: 64, height: 54, child: material),
                  ),
          ),
        );
      }

      return SwipeRowTapRegion(
        group: widget.openRow,
        enabled: width > 0 && _open,
        onDismiss: _dismiss,
        child: ClipRect(
          clipBehavior: revealed ? Clip.hardEdge : Clip.none,
          child: Stack(
            children: [
              if (revealed) ...[
                Positioned.fill(child: IgnorePointer(child: actionWell())),
                PositionedDirectional(
                  top: 0,
                  bottom: 0,
                  end: 0,
                  width: width,
                  child: tray(),
                ),
              ],
              Transform.translate(
                offset: Offset(-reveal * direction, 0),
                child: RawGestureDetector(
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  gestures: {
                    if (width > 0)
                      _DownloadRowDrag:
                          GestureRecognizerFactoryWithHandlers<
                            _DownloadRowDrag
                          >(_DownloadRowDrag.new, (gesture) {
                            final screen = MediaQuery.sizeOf(context).width;
                            gesture.canStart = (point) =>
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
                    onSecondaryTap: !widget.exposeActions || suspended
                        ? null
                        : width > 0
                        ? _reveal
                        : flat && hasActions
                        ? _openMore
                        : null,
                    child: Semantics(
                      customSemanticsActions:
                          widget.exposeActions &&
                              !flat &&
                              !suspended &&
                              shortcut != null
                          ? {
                              CustomSemanticsAction(
                                label: shortcut.label,
                              ): () =>
                                  _perform(shortcut.id, epoch),
                            }
                          : null,
                      child: AbsorbPointer(
                        absorbing: !flat && suspended,
                        child: ExcludeSemantics(
                          excluding: !flat && suspended,
                          child: ExcludeFocus(
                            excluding: !flat && suspended,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: revealed ? surface : Colors.transparent,
                                borderRadius: _rowRadius,
                              ),
                              child: _DownloadMoreScope(
                                rowKey: widget.rowKey,
                                onPressed: flat && hasActions
                                    ? _openMore
                                    : null,
                                bodyEnabled: !suspended,
                                child: child!,
                              ),
                            ),
                          ),
                        ),
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
  );

  Widget _command(
    DownloadSwipeAction action, {
    required String caption,
    required TextStyle style,
  }) => Tooltip(
    message: action.label,
    excludeFromSemantics: true,
    child: InkWell(
      key: ValueKey('download-swipe.${widget.rowKey}.${action.id}'),
      borderRadius: _rowRadius,
      onTap: () => _run(action.id),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 3,
          children: [
            Icon(
              action.icon,
              size: caption.isEmpty ? 20 : 17,
              color: style.color,
              semanticLabel: caption.isEmpty ? action.label : null,
            ),
            if (caption.isNotEmpty)
              Flexible(
                child: Text(
                  caption,
                  semanticsLabel: action.label,
                  maxLines: 1,
                  style: style,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

String? downloadRowTimeLabel(
  BuildContext context, {
  DateTime? completedAt,
  DateTime? lastReadAt,
}) {
  final timestamp = completedAt ?? lastReadAt;
  if (timestamp == null || timestamp.millisecondsSinceEpoch <= 0) return null;
  final local = timestamp.toLocal();
  final locale = MaterialLocalizations.of(context);
  final date = local.year == DateTime.now().year
      ? locale.formatShortMonthDay(local)
      : locale.formatShortDate(local);
  final time = locale.formatTimeOfDay(
    TimeOfDay.fromDateTime(local),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  final chinese = Localizations.localeOf(context).languageCode == 'zh';
  final label = completedAt != null
      ? (chinese ? '下载于' : 'Downloaded')
      : (chinese ? '阅读于' : 'Read');
  return '$label $date $time';
}

class _DownloadActionSheet extends StatelessWidget {
  const _DownloadActionSheet({
    required this.rowKey,
    required this.title,
    required this.actions,
    this.completedAt,
    this.lastReadAt,
    this.information = const [],
  });

  final String rowKey, title;
  final List<DownloadSwipeAction> actions;
  final DateTime? completedAt, lastReadAt;
  final List<String> information;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final extent = CollectionToolbarMetrics.actionExtentOf(context);
    final normal = actions.where((action) => action.id != 'delete').toList();
    final destructive = actions
        .where((action) => action.id == 'delete')
        .toList();
    final ink = BreezeThemeColors.readableOn(colors.onSurface, colors.surface);
    final error = BreezeThemeColors.readableOn(colors.error, colors.surface);
    final metadata = downloadRowTimeLabel(
      context,
      completedAt: completedAt,
      lastReadAt: lastReadAt,
    );
    Widget tile(DownloadSwipeAction action, Color color) => ListTile(
      key: ValueKey('download-swipe.$rowKey.${action.id}'),
      minTileHeight: extent,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18),
      tileColor: Colors.transparent,
      leading: Icon(action.icon, size: 20, color: color),
      title: Text(
        action.label,
        style: theme.textTheme.bodyMedium?.copyWith(color: color),
      ),
      onTap: () => Navigator.of(context).pop(action.id),
    );

    return SingleChildScrollView(
      key: ValueKey('download-action-sheet.$rowKey'),
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 18, end: 8),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      key: ValueKey('download-action-sheet-title.$rowKey'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(color: ink),
                    ),
                  ),
                ),
                IconButton(
                  key: ValueKey('download-action-sheet-close.$rowKey'),
                  tooltip: t.common.close,
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    fixedSize: Size.square(extent),
                    minimumSize: Size.square(extent),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.standard,
                    foregroundColor: ink,
                  ),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
          ),
          if (metadata != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(18, 0, 18, 8),
              child: Text(
                metadata,
                key: ValueKey('download-action-sheet-time.$rowKey'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: BreezeThemeColors.readableOn(
                    colors.onSurfaceVariant,
                    colors.surface,
                  ),
                ),
              ),
            ),
          for (final line in information)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(18, 0, 18, 8),
              child: Text(
                line,
                style: theme.textTheme.bodyMedium?.copyWith(color: ink),
              ),
            ),
          for (final action in normal) tile(action, ink),
          if (normal.isNotEmpty && destructive.isNotEmpty)
            Divider(
              key: ValueKey('download-action-sheet-divider.$rowKey'),
              indent: 18,
              endIndent: 18,
              color: colors.outlineVariant.withValues(alpha: .7),
            ),
          for (final action in destructive) tile(action, error),
        ],
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
