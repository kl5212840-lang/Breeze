import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';

enum FilteredPageProgress {
  checking,
  incomplete,
  complete,
  failed;

  String? get emptyMessage => switch (this) {
    checking => t.searchResult.findingMatches,
    incomplete => t.searchResult.noMatchesYet,
    complete => t.searchResult.noMatchingWorks,
    failed => null,
  };
}

/// Requests source pages on behalf of the visible filtered list. A source
/// response and a displayed batch have separate lifetimes.
class FilteredResultPages extends StatefulWidget {
  const FilteredResultPages({
    super.key,
    required this.matches,
    required this.controller,
    required this.page,
    this.firstPage = 1,
    required this.ready,
    required this.complete,
    required this.failed,
    required this.paused,
    required this.batchSize,
    required this.loadMore,
    required this.builder,
  });

  final List<UnifiedComicListItem> matches;
  final ScrollController controller;
  final int page, firstPage, batchSize;
  final bool ready, complete, failed, paused;
  final bool Function() loadMore;
  final Widget Function(List<UnifiedComicListItem>, FilteredPageProgress)
  builder;

  @override
  State<FilteredResultPages> createState() => _FilteredResultPagesState();
}

class _FilteredResultPagesState extends State<FilteredResultPages>
    with WidgetsBindingObserver {
  static const _maxPagesPerLookahead = 9;
  static const _maxLookaheadTime = Duration(seconds: 12);
  static const _maxBatchWait = Duration(milliseconds: 850);
  static const _continueDragDistance = 28.0;

  late int _shown = widget.matches.length;
  int? _requestedFrom;
  int _requestCount = 0, _pagesInBatch = 0;
  double _demandOffset = 0, _upwardDrag = 0;
  bool _queued = false;
  final _elapsed = Stopwatch();
  Timer? _flushTimer;

  bool get _limited =>
      _requestCount >= _maxPagesPerLookahead ||
      _elapsed.elapsed >= _maxLookaheadTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant FilteredResultPages oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }

    final completedRequest =
        _requestedFrom != null &&
        (widget.page != _requestedFrom || widget.failed || widget.complete);
    if (completedRequest) {
      _requestedFrom = null;
      _pagesInBatch++;
      _elapsed.stop();
    }
    if (widget.page < oldWidget.page) _resetBudget();
    final pending = widget.matches.length - _shown;
    if (pending < 0 ||
        widget.complete ||
        widget.failed ||
        widget.paused ||
        _pagesInBatch == 0 && _requestedFrom == null ||
        pending >= widget.batchSize ||
        _pagesInBatch >= 3 ||
        completedRequest && _limited) {
      _publish();
    } else if (pending > 0) {
      _flushTimer ??= Timer(_maxBatchWait, () {
        if (mounted) setState(_publish);
      });
    }
  }

  void _publish() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _pagesInBatch = 0;
    _shown = widget.matches.length;
  }

  void _resetBudget() {
    _requestCount = 0;
    _elapsed.reset();
    _elapsed.stop();
  }

  bool get _needsResults {
    if (_shown == 0) return true;
    if (widget.controller.positions.length != 1) return false;
    final position = widget.controller.position;
    return position.hasContentDimensions &&
        position.extentAfter < position.viewportDimension * .85;
  }

  void _onScroll() {
    if (_requestedFrom == null && widget.controller.positions.length == 1) {
      final position = widget.controller.position;
      if (!_needsResults ||
          _limited &&
              position.hasContentDimensions &&
              position.pixels - _demandOffset >= position.viewportDimension) {
        _resetBudget();
      }
    }
    _schedule();
  }

  bool _continueOnDrag(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification ||
        notification is ScrollEndNotification) {
      _upwardDrag = 0;
    }
    if (!_limited ||
        widget.complete ||
        widget.failed ||
        widget.paused ||
        !widget.ready ||
        _requestedFrom != null ||
        !_needsResults) {
      return false;
    }

    // A short or empty list cannot advance by another viewport. Accept a
    // deliberate upward drag at the end under both clamping and bounce physics.
    final delta = switch (notification) {
      ScrollUpdateNotification(dragDetails: final details?) =>
        -details.delta.dy,
      OverscrollNotification(dragDetails: final details?) => -details.delta.dy,
      _ => 0.0,
    };
    _upwardDrag = delta <= 0 ? 0 : _upwardDrag + delta;
    if (_upwardDrag >= _continueDragDistance) {
      _upwardDrag = 0;
      _resetBudget();
      _schedule();
    }
    return false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedule();
  }

  void _schedule() {
    if (_queued ||
        widget.complete ||
        widget.failed ||
        widget.paused ||
        !widget.ready ||
        _requestedFrom != null ||
        _limited) {
      return;
    }
    _queued = true;
    WidgetsBinding.instance.ensureVisualUpdate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (!mounted ||
          widget.complete ||
          widget.failed ||
          widget.paused ||
          !widget.ready ||
          _requestedFrom != null ||
          _limited ||
          !_needsResults ||
          ModalRoute.isCurrentOf(context) == false ||
          !TickerMode.valuesOf(context).enabled) {
        return;
      }
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
      _requestedFrom = widget.page;
      if (!widget.loadMore()) {
        _requestedFrom = null;
        return;
      }
      if (_requestCount == 0 && widget.controller.positions.length == 1) {
        _demandOffset = widget.controller.position.pixels;
      }
      _requestCount++;
      _elapsed.start();
    });
  }

  @override
  Widget build(BuildContext context) {
    _schedule();
    final progress = switch (widget) {
      FilteredResultPages(failed: true) => FilteredPageProgress.failed,
      FilteredResultPages(complete: true) =>
        widget.firstPage == 1
            ? FilteredPageProgress.complete
            : FilteredPageProgress.incomplete,
      _ when _limited && _requestedFrom == null && widget.ready =>
        FilteredPageProgress.incomplete,
      _ => FilteredPageProgress.checking,
    };
    return NotificationListener<ScrollNotification>(
      onNotification: _continueOnDrag,
      child: widget.builder(
        _shown == widget.matches.length
            ? widget.matches
            : widget.matches.take(_shown).toList(),
        progress,
      ),
    );
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    widget.controller.removeListener(_onScroll);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
