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
  (double, double)? _searchOrigin;

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
    _settle(afterLayout: afterLayout ? _reset : null);
    if (!afterLayout) _reset();
  }

  void beginSearch() {
    _searchOrigin ??= (_grid.savedOffset, _details.savedOffset);
  }

  void endSearch() {
    final origin = _searchOrigin;
    _searchOrigin = null;
    if (_disposed || origin == null) return;
    _settle(
      afterLayout: () {
        _grid.restore(origin.$1);
        _details.restore(origin.$2);
      },
    );
  }

  void _reset() {
    _grid.reset();
    _details.reset();
  }

  void _settle({VoidCallback? afterLayout}) {
    _changing = true;
    final epoch = ++_epoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || epoch != _epoch) return;
      afterLayout?.call();
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

  double get savedOffset => _saved;

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

  void restore(double offset) {
    _saved = offset;
    for (final position in positions.toList()) {
      if (position.hasContentDimensions) {
        position.jumpTo(
          offset.clamp(position.minScrollExtent, position.maxScrollExtent),
        );
      }
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
