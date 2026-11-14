import 'dart:async';

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/service/jm_cover_like_loader.dart';
import 'package:zephyr/service/jm_list_like_counts.dart';
import 'package:zephyr/widgets/read_recovery_scope.dart';

/// Each result surface owns its visible demand. Transport is shared by JM.
class JmCoverLikeScope extends StatefulWidget {
  const JmCoverLikeScope({
    super.key,
    required this.counts,
    required this.child,
    this.loader,
  });

  final JmListLikeCounts counts;
  final Widget child;
  final JmCoverLikeLoader? loader;

  static JmListLikeCounts? maybeOf(BuildContext context, String source) {
    if (source != JmListLikeCounts.source) return null;
    return _JmCoverLikeHost.maybeOf(context)?.widget.counts;
  }

  @override
  State<JmCoverLikeScope> createState() => _JmCoverLikeScopeState();
}

class _JmCoverLikeHost extends InheritedWidget {
  const _JmCoverLikeHost({
    required this.owner,
    required this.counts,
    required super.child,
  });

  final _JmCoverLikeScopeState owner;
  final JmListLikeCounts counts;

  static _JmCoverLikeScopeState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_JmCoverLikeHost>()?.owner;

  @override
  bool updateShouldNotify(_JmCoverLikeHost oldWidget) =>
      owner != oldWidget.owner || counts != oldWidget.counts;
}

class _JmCoverLikeScopeState extends State<JmCoverLikeScope> {
  final _visible = <Object, String>{};
  final _scrolling = <BuildContext>{};
  bool _active = false;
  bool _closed = false;
  bool _hasCovers = false;
  Timer? _settle;
  static const _settleDelay = Duration(milliseconds: 250);

  JmCoverLikeLoader? get _loader =>
      widget.loader ??
      (identical(widget.counts, JmListLikeCounts.instance)
          ? JmCoverLikeLoader.instance
          : null);

  void visible(Object cover, String? comicId) {
    if (_closed) return;
    if (comicId == null) {
      if (_visible.remove(cover) == null) return;
      _loader?.retainDemand(this, _visible.values.toSet());
    } else {
      if (_visible[cover] == comicId) return;
      _visible[cover] = comicId;
    }
    _schedule();
  }

  void hasCover() {
    if (_closed || _hasCovers) return;
    _hasCovers = true;
    _schedule();
  }

  void _publish(Set<String> visible) {
    _loader?.setDemand(
      this,
      _active && _scrolling.isEmpty && _settle == null ? visible : const {},
    );
  }

  void _schedule() {
    if (!_active || !_hasCovers || _scrolling.isNotEmpty) return;
    _settle?.cancel();
    _settle = Timer(_settleDelay, () {
      // Flush the shared visibility package's batched paint results after
      // settling. A card built for cacheExtent has no visible paint bounds.
      VisibilityDetectorController.instance.notifyNow();
      _settle?.cancel();
      _settle = null;
      _publish(_visible.values.toSet());
    });
  }

  bool _onScroll(ScrollNotification notification) {
    final source = notification.context;
    if (source == null) return false;
    _scrolling.removeWhere((element) => !element.mounted);
    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification) {
      if (_hasCovers && _scrolling.add(source)) {
        _settle?.cancel();
        _settle = null;
        _publish(const {});
      }
    } else if (notification is ScrollEndNotification) {
      _scrolling.remove(source);
      _schedule();
    }
    return false;
  }

  void _setActive(bool value) {
    if (_active == value) return;
    _active = value;
    if (value) {
      _scrolling.removeWhere((element) => !element.mounted);
      _schedule();
    } else {
      _scrolling.clear();
      _settle?.cancel();
      _settle = null;
      _publish(const {});
    }
  }

  @override
  void dispose() {
    _closed = true;
    _active = false;
    _settle?.cancel();
    _publish(const {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ReadRecoveryHost(
    onActiveChanged: _setActive,
    child: _JmCoverLikeHost(
      owner: this,
      counts: widget.counts,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: widget.child,
      ),
    ),
  );
}

/// Observe the whole cover, including when an unknown count has no badge.
class JmCoverLikeVisibility extends StatefulWidget {
  const JmCoverLikeVisibility({
    super.key,
    required this.comicId,
    required this.child,
  });

  final String comicId;
  final Widget child;

  @override
  State<JmCoverLikeVisibility> createState() => _JmCoverLikeVisibilityState();
}

class _JmCoverLikeVisibilityState extends State<JmCoverLikeVisibility> {
  final _visibilityKey = UniqueKey();
  _JmCoverLikeScopeState? _owner;
  double _bottomInset = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = _JmCoverLikeHost.maybeOf(context);
    final bottomInset = NativeNavigationInset.of(context);
    if (_owner == next && _bottomInset == bottomInset) return;
    _reset();
    _owner = next;
    _bottomInset = bottomInset;
    _owner?.hasCover();
  }

  @override
  void didUpdateWidget(JmCoverLikeVisibility oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comicId != widget.comicId) {
      _reset();
      _owner?._schedule();
    }
  }

  void _reset() {
    _owner?.visible(this, null);
    VisibilityDetectorController.instance.forget(_visibilityKey);
  }

  @override
  void dispose() {
    _reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => VisibilityDetector(
    key: _visibilityKey,
    onVisibilityChanged: (info) {
      if (!mounted) return;
      var visible = info.visibleFraction > 0;
      if (visible && _bottomInset > 0) {
        final box = context.findRenderObject();
        if (box is RenderBox && box.attached && box.hasSize) {
          final top = box.localToGlobal(Offset(0, info.visibleBounds.top)).dy;
          visible = top < MediaQuery.sizeOf(context).height - _bottomInset;
        }
      }
      _owner?.visible(this, visible ? widget.comicId : null);
    },
    child: widget.child,
  );
}

class JmCoverLikeBadge extends StatelessWidget {
  const JmCoverLikeBadge({
    super.key,
    required this.counts,
    required this.comicId,
  });

  static const inset = 5.0;
  final JmListLikeCounts counts;
  final String comicId;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: counts,
    builder: (context, _) {
      final count = counts.countFor(comicId);
      if (count == null) return const SizedBox.shrink();
      final label = count < 10000
          ? '$count'
          : NumberFormat.compact(
              locale: Localizations.localeOf(context).toLanguageTag(),
            ).format(count);
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: IgnorePointer(
          child: Semantics(
            label: t.comicInfo.likes(count: count),
            excludeSemantics: true,
            child: FittedBox(
              alignment: AlignmentDirectional.centerStart,
              fit: BoxFit.scaleDown,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(
                    alpha: MediaQuery.highContrastOf(context) ? 1 : 0.78,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 3,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.favorite_border,
                        color: Colors.white,
                        size: 11,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        label,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
