import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_selection_toolbar.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/native_video_controls.dart';

/// Lives in the bookshelf body viewport, which already excludes the host dock.
/// Callers reserve [contentBottomPadding] inside the actual list, not outside it.
class BookshelfFloatingSelectionActions extends StatefulWidget {
  const BookshelfFloatingSelectionActions({
    super.key,
    required this.child,
    required this.selecting,
    required this.selectedCount,
    required this.actions,
    this.overflowActions = const [],
    this.busy = false,
    this.keyPrefix = 'shelf-selection',
  });
  static const double contentBottomPadding = 88;
  final Widget child;
  final bool selecting, busy;
  final int selectedCount;
  final List<BookshelfBatchAction> actions, overflowActions;
  final String keyPrefix;

  @override
  State<BookshelfFloatingSelectionActions> createState() =>
      _BookshelfFloatingSelectionActionsState();
}

class _BookshelfFloatingSelectionActionsState
    extends State<BookshelfFloatingSelectionActions> {
  bool _visible = true;
  double _distance = 0;
  int _direction = 0;

  @override
  void didUpdateWidget(BookshelfFloatingSelectionActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.selecting && widget.selecting) {
      // A previous success message must not cover the next batch's actions.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.selecting) {
          ScaffoldMessenger.maybeOf(context)?.removeCurrentSnackBar();
        }
      });
    }
    if (oldWidget.selecting != widget.selecting ||
        oldWidget.selectedCount != widget.selectedCount ||
        widget.busy) {
      _visible = true;
      _distance = 0;
      _direction = 0;
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (!widget.selecting ||
        widget.busy ||
        MediaQuery.accessibleNavigationOf(context) ||
        notification.depth != 0 ||
        notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification is ScrollEndNotification) {
      _distance = 0;
      _direction = 0;
    }
    // dragDetails excludes jumps, restored positions and automatic scrolling.
    if (notification is! ScrollUpdateNotification ||
        notification.dragDetails == null) {
      return false;
    }
    final delta = notification.scrollDelta ?? 0;
    if (delta == 0) return false;
    final direction = delta.sign.toInt();
    if (_direction != direction) {
      _direction = direction;
      _distance = 0;
    }
    _distance += delta.abs();
    if (_distance >= 12) {
      final visible = direction < 0;
      if (_visible != visible) setState(() => _visible = visible);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final visible =
        _visible || widget.busy || MediaQuery.accessibleNavigationOf(context);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 140);
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AbsorbPointer(absorbing: widget.busy, child: widget.child),
          if (widget.selecting)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12 + NativeNavigationInset.of(context),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth:
                        widget.actions.length == 1 &&
                            widget.overflowActions.isEmpty
                        ? 88
                        : 420,
                  ),
                  child: IgnorePointer(
                    ignoring: !visible,
                    child: ExcludeSemantics(
                      excluding: !visible,
                      child: AnimatedOpacity(
                        opacity: visible ? 1 : 0,
                        duration: duration,
                        curve: Curves.easeOut,
                        child: AnimatedSlide(
                          offset: visible ? Offset.zero : const Offset(0, .25),
                          duration: duration,
                          curve: Curves.easeOut,
                          child: _Actions(
                            key: ValueKey(
                              '${widget.keyPrefix}.floating-actions',
                            ),
                            keyPrefix: widget.keyPrefix,
                            actions: widget.actions,
                            overflowActions: widget.overflowActions,
                            busy: widget.busy,
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
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    super.key,
    required this.actions,
    required this.overflowActions,
    required this.busy,
    required this.keyPrefix,
  });
  final List<BookshelfBatchAction> actions, overflowActions;
  final bool busy;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final native = usesNativeSourceChrome(context);
    final colors = Theme.of(context).colorScheme;
    final highContrast = MediaQuery.highContrastOf(context);
    return VideoControlAppearance(
      systemControls: native,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = actions.length + (overflowActions.isEmpty ? 0 : 1);
          if (count == 0) return const SizedBox.shrink();
          const padding = 4.0;
          final available =
              constraints.maxWidth -
              2 * padding -
              (overflowActions.isEmpty ? 0 : 44);
          final width = (available / actions.length.clamp(1, count)).clamp(
            60.0,
            144.0,
          );
          final compact =
              MediaQuery.textScalerOf(context).scale(14) > 20 ||
              (count >= 3 && width < 76);
          Widget iconButton({
            required IconData icon,
            required String symbol,
            required String label,
            required VoidCallback? onPressed,
          }) => NativeVideoIconButton(
            icon: icon,
            symbol: symbol,
            tooltip: label,
            onPressed: onPressed,
            light: false,
            bare: true,
          );
          Widget actionButton(BookshelfBatchAction action) {
            final onPressed = busy ? null : action.onPressed;
            if (compact) {
              return iconButton(
                icon: action.icon,
                symbol: action.symbol,
                label: action.label,
                onPressed: onPressed,
              );
            }
            if (native) {
              return NativeVideoTextButton(
                label: action.label,
                tooltip: action.label,
                light: false,
                bare: true,
                maxWidth: width,
                onPressed: onPressed,
              );
            }
            return ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width),
              child: Tooltip(
                message: action.label,
                excludeFromSemantics: true,
                child: TextButton(
                  onPressed: onPressed,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.onSurface,
                    minimumSize: const Size(60, 44),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.standard,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Text(
                    action.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            );
          }

          final options = {
            for (final action in overflowActions)
              if (!busy && action.onPressed != null) action.id: action.label,
          };
          final border = highContrast
              ? colors.onSurface
              : colors.outlineVariant;
          return Listener(
            behavior: HitTestBehavior.opaque,
            child: Material(
              color: colors.surfaceContainerHigh,
              elevation: highContrast ? 0 : 3,
              shadowColor: colors.shadow.withValues(alpha: .25),
              shape: StadiumBorder(side: BorderSide(color: border)),
              child: Padding(
                padding: const EdgeInsets.all(padding),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final action in actions)
                      KeyedSubtree(
                        key: ValueKey('$keyPrefix.${action.id}'),
                        child: actionButton(action),
                      ),
                    if (overflowActions.isNotEmpty)
                      KeyedSubtree(
                        key: ValueKey('$keyPrefix.more'),
                        child: options.isEmpty
                            ? iconButton(
                                icon: Icons.more_horiz,
                                symbol: 'ellipsis',
                                label: t.common.more,
                                onPressed: null,
                              )
                            : NativeVideoMenu(
                                label: '',
                                icon: Icons.more_horiz,
                                symbol: 'ellipsis',
                                tooltip: t.common.more,
                                selected: '',
                                light: false,
                                bare: true,
                                hostPresentation: native,
                                width: 44,
                                options: options,
                                optionIcons: {
                                  for (final action in overflowActions)
                                    action.id: (
                                      icon: action.icon,
                                      symbol: action.symbol,
                                    ),
                                },
                                onSelected: (id) {
                                  for (final action in overflowActions) {
                                    if (action.id == id)
                                      action.onPressed?.call();
                                  }
                                },
                              ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
