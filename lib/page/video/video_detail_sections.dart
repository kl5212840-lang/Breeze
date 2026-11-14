import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/video/video_interaction.dart';

class _DetailSectionSwipeRecognizer extends HorizontalDragGestureRecognizer {
  double width = double.infinity;
  bool Function()? enabled;
  bool _inside(Offset point) => point.dx >= 24 && point.dx <= width - 24;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      (enabled?.call() ?? true) &&
      _inside(event.localPosition) &&
      super.isPointerAllowed(event);

  @override
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) =>
      (enabled?.call() ?? true) &&
      _inside(event.localPosition) &&
      super.isPointerPanZoomAllowed(event);
}

/// One horizontal viewport below the player. Page physics provide real drag
/// progress and settling; rejected edge/input/child gestures never move it.
class VideoDetailSections extends StatefulWidget {
  const VideoDetailSections({
    super.key,
    this.storageKey = 'api-detail',
    required this.commentsSelected,
    required this.onSelected,
    required this.onPrepareComments,
    required this.children,
  });
  final String storageKey;
  final bool commentsSelected;
  final ValueChanged<bool> onSelected;
  final VoidCallback onPrepareComments;
  final List<Widget> children;
  @override
  State<VideoDetailSections> createState() => VideoDetailSectionsState();
}

class VideoDetailSectionsState extends State<VideoDetailSections> {
  late final PageController _pages;
  late int _reportedPage;
  int _dragStartPage = 0;
  int? _animationTarget;
  Drag? _drag;

  @override
  void initState() {
    super.initState();
    _reportedPage = widget.commentsSelected ? 1 : 0;
    _pages = PageController(initialPage: _reportedPage);
  }

  @override
  void didUpdateWidget(covariant VideoDetailSections oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = widget.commentsSelected ? 1 : 0;
    if (oldWidget.commentsSelected != widget.commentsSelected &&
        _drag == null &&
        (selected != _reportedPage ||
            _animationTarget != null && _animationTarget != selected)) {
      _settle(selected);
    }
  }

  @override
  void dispose() {
    _drag?.cancel();
    _pages.dispose();
    super.dispose();
  }

  void _settle(int page) {
    if (!_pages.hasClients || _animationTarget == page) return;
    _animationTarget = page;
    final duration = VideoMotion.feedback(context);
    if (duration == Duration.zero) {
      _pages.jumpToPage(page);
      _animationTarget = null;
    } else {
      unawaited(
        _pages
            .animateToPage(page, duration: duration, curve: Curves.easeOutCubic)
            .whenComplete(() {
              if (mounted && _animationTarget == page) _animationTarget = null;
            }),
      );
    }
  }

  void _cancel() {
    final drag = _drag;
    if (drag == null) return;
    _drag = null;
    drag.cancel();
    widget.onSelected(_dragStartPage == 1);
    _settle(_dragStartPage);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => RawGestureDetector(
      key: ValueKey('${widget.storageKey}.section-swipe'),
      behavior: HitTestBehavior.translucent,
      gestures: {
        _DetailSectionSwipeRecognizer:
            GestureRecognizerFactoryWithHandlers<_DetailSectionSwipeRecognizer>(
              _DetailSectionSwipeRecognizer.new,
              (recognizer) {
                recognizer.width = constraints.maxWidth;
                recognizer.gestureSettings = MediaQuery.gestureSettingsOf(
                  context,
                );
                recognizer.dragStartBehavior = DragStartBehavior.down;
                recognizer.enabled = () {
                  final focus = FocusManager.instance.primaryFocus?.context;
                  return ModalRoute.of(context)?.isCurrent != false &&
                      focus?.widget is! EditableText &&
                      focus?.findAncestorWidgetOfExactType<EditableText>() ==
                          null;
                };
                recognizer.onStart = (details) {
                  _dragStartPage = (_pages.page ?? 0)
                      .round()
                      .clamp(0, 1)
                      .toInt();
                  _animationTarget = null;
                  _drag = _pages.position.drag(details, () => _drag = null);
                };
                recognizer.onUpdate = (details) {
                  _drag?.update(details);
                  if ((_pages.page ?? 0) > 0) widget.onPrepareComments();
                };
                recognizer.onCancel = _cancel;
                recognizer.onEnd = (details) {
                  final drag = _drag;
                  _drag = null;
                  if (MediaQuery.disableAnimationsOf(context)) {
                    final page = _pages.page ?? 0;
                    final velocity =
                        details.velocity.pixelsPerSecond.dx *
                        (Directionality.of(context) == TextDirection.rtl
                            ? 1
                            : -1);
                    final target =
                        (page + (velocity.abs() > 500 ? velocity.sign * .5 : 0))
                            .round()
                            .clamp(0, 1)
                            .toInt();
                    drag?.cancel();
                    _pages.jumpToPage(target);
                  } else {
                    drag?.end(details);
                  }
                };
              },
            ),
      },
      child: PageView(
        key: ValueKey('${widget.storageKey}.section-pages'),
        controller: _pages,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (page) {
          _reportedPage = page;
          if (page == 1) widget.onPrepareComments();
          widget.onSelected(page == 1);
        },
        children: [
          for (var index = 0; index < widget.children.length; index++)
            _RetainedDetailSection(
              key: ValueKey(index),
              child: widget.children[index],
            ),
        ],
      ),
    ),
  );
}

class _RetainedDetailSection extends StatefulWidget {
  const _RetainedDetailSection({super.key, required this.child});
  final Widget child;
  @override
  State<_RetainedDetailSection> createState() => _RetainedDetailSectionState();
}

class _RetainedDetailSectionState extends State<_RetainedDetailSection>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
