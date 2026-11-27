import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';

/// Filter sheets keep their draft mounted while changing height.
class FilterSheetDetents extends StatefulWidget {
  const FilterSheetDetents({super.key, required this.builder});

  final Widget Function(BuildContext context, Widget handle) builder;

  static bool isActiveOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_FilterSheetHeight>() != null;

  static double expandedHeight(
    BuildContext context,
    double available, {
    double reservedBottom = 0,
  }) {
    final media = MediaQuery.of(context);
    return (media.size.height * .90 - media.viewInsets.bottom - reservedBottom)
        .clamp(0.0, available);
  }

  static double heightOf(
    BuildContext context, {
    required double compact,
    required double expanded,
    bool tracksHandle = true,
  }) {
    final sheet = context
        .dependOnInheritedWidgetOfExactType<_FilterSheetHeight>();
    if (sheet == null) return compact;
    final travel = math.max(0.0, expanded - compact);
    if (tracksHandle) sheet.reportTravel(travel);
    return compact + travel * sheet.progress;
  }

  @override
  State<FilterSheetDetents> createState() => _FilterSheetDetentsState();
}

class _FilterSheetDetentsState extends State<FilterSheetDetents>
    with SingleTickerProviderStateMixin {
  final _focusScope = FocusScopeNode(debugLabel: 'filter sheet');
  late final _position = AnimationController(vsync: this);
  bool _expanded = false;
  double _travel = 0;
  double _dragStart = 0;

  void _settle(bool expanded) {
    _expanded = expanded;
    final target = expanded ? 1.0 : 0.0;
    if (MediaQuery.disableAnimationsOf(context) || _travel == 0) {
      _position.stop();
      _position.value = target;
      return;
    }
    final remaining = (target - _position.value).abs();
    _position.animateTo(
      target,
      duration: Duration(
        milliseconds: (220 * remaining).round().clamp(90, 220),
      ),
      curve: Curves.easeOutCubic,
    );
  }

  void _finishDrag(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() >= 180) {
      _settle(velocity < 0);
      return;
    }
    final distance = (_position.value - _dragStart) * _travel;
    final threshold = math.min(24.0, _travel * .5);
    _settle(distance.abs() > threshold ? distance > 0 : _expanded);
  }

  @override
  void dispose() {
    _position.dispose();
    _focusScope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FocusScope(
    node: _focusScope,
    child: PopScope<Object?>(
      onPopInvokedWithResult: (popped, _) {
        if (popped && _focusScope.hasFocus) _focusScope.unfocus();
      },
      child: AnimatedBuilder(
        animation: _position,
        builder: (context, _) => _FilterSheetHeight(
          progress: _position.value,
          reportTravel: (value) => _travel = value,
          child: Builder(
            builder: (context) => widget.builder(
              context,
              Semantics(
                label: _expanded
                    ? t.common.collapseFilterPanel
                    : t.common.expandFilterPanel,
                button: true,
                onTap: () => _settle(!_expanded),
                child: GestureDetector(
                  key: const ValueKey('filter-sheet-detent-handle'),
                  excludeFromSemantics: true,
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _settle(!_expanded),
                  onVerticalDragStart: (_) {
                    _position.stop();
                    _dragStart = _position.value;
                  },
                  onVerticalDragUpdate: (details) {
                    if (_travel == 0) return;
                    _position.value =
                        (_position.value - details.delta.dy / _travel).clamp(
                          0.0,
                          1.0,
                        );
                  },
                  onVerticalDragEnd: _finishDrag,
                  onVerticalDragCancel: () => _settle(_expanded),
                  child: SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: Center(
                      child: Container(
                        width: 32,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _FilterSheetHeight extends InheritedWidget {
  const _FilterSheetHeight({
    required this.progress,
    required this.reportTravel,
    required super.child,
  });
  final double progress;
  final ValueChanged<double> reportTravel;
  @override
  bool updateShouldNotify(_FilterSheetHeight oldWidget) =>
      oldWidget.progress != progress;
}
