import 'package:flutter/widgets.dart';

/// Each layout owns its pixels. An unvisited layout starts at the beginning;
/// visited layouts resume without guessing a variable-height item's position.
class SourceListScrollPositions {
  // Keep the public argument distinct from the mutable private state.
  // ignore: prefer_initializing_formals
  SourceListScrollPositions({bool detailed = false}) : _detailed = detailed;

  final _grid = _RememberedScrollController();
  final _details = _RememberedScrollController();
  bool _detailed;
  bool _changing = false;
  bool _disposed = false;
  int _epoch = 0;

  ScrollController get controller => _detailed ? _details : _grid;
  bool get isChanging => _changing;

  void addListener(VoidCallback listener) {
    _grid.addListener(listener);
    _details.addListener(listener);
  }

  void removeListener(VoidCallback listener) {
    _grid.removeListener(listener);
    _details.removeListener(listener);
  }

  void select(bool detailed) {
    if (_detailed == detailed) return;
    _detailed = detailed;
    _settle();
  }

  void reset({bool afterLayout = false}) {
    if (_disposed) return;
    _settle(resetAfterLayout: afterLayout);
    if (!afterLayout) _reset();
  }

  void _reset() {
    _grid.reset();
    _details.reset();
  }

  void _settle({bool resetAfterLayout = false}) {
    _changing = true;
    final epoch = ++_epoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || epoch != _epoch) return;
      if (resetAfterLayout) _reset();
      _changing = false;
    });
  }

  void dispose() {
    _disposed = true;
    _epoch++;
    _grid.dispose();
    _details.dispose();
  }
}

class _RememberedScrollController extends ScrollController {
  _RememberedScrollController() : super(keepScrollOffset: false);
  double _saved = 0;
  final _listeners = <ScrollPosition, VoidCallback>{};

  @override
  double get initialScrollOffset => _saved;

  @override
  void attach(ScrollPosition position) {
    super.attach(position);
    void listener() => _saved = position.pixels;
    _listeners[position] = listener;
    position.addListener(listener);
  }

  @override
  void detach(ScrollPosition position) {
    _saved = position.pixels;
    position.removeListener(_listeners.remove(position)!);
    super.detach(position);
  }

  void reset() {
    _saved = 0;
    for (final position in positions.toList()) {
      position.jumpTo(0);
    }
  }

  @override
  void dispose() {
    for (final entry in _listeners.entries) {
      entry.key.removeListener(entry.value);
    }
    _listeners.clear();
    super.dispose();
  }
}
