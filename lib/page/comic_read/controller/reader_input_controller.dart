import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/cubit/comic_read_preference_cubit.dart';
import 'package:zephyr/page/comic_read/controller/reader_action_controller.dart';
import 'package:zephyr/page/comic_read/cubit/reader_cubit.dart';
import 'package:zephyr/page/comic_read/method/key.dart';
import 'package:zephyr/page/comic_read/method/reader_gesture_logic.dart';
import 'package:zephyr/page/comic_read/widgets/layout/read_layout.dart';

/// 阅读器输入控制器。
///
/// 负责键盘、手势、滚轮、缩放交互的识别与分发，
/// 把具体动作委托给 [ReaderActionController]，把页面级回调交回 State。
class ReaderInputController {
  ReaderInputController({
    required this.context,
    required this.readerCubit,
    required this.pageController,
    required this.transformationController,
    required TickerProvider vsync,
    required this.onToggleMenu,
    required this._onToggleDesktopFullscreen,
    required this.onRefreshState,
    required this.isScrollLockedByMultiTouch,
    required this.onUpdateScrollLock,
    required this.buildColumnMode,
    required this.buildRowMode,
  }) : _zoomAnimation = AnimationController(
         vsync: vsync,
         duration: const Duration(milliseconds: 160),
       );

  final BuildContext context;
  final ReaderCubit readerCubit;
  late ReaderActionController actionController;
  final PageController pageController;
  final TransformationController transformationController;
  final VoidCallback onToggleMenu;
  final Future<void> Function() _onToggleDesktopFullscreen;
  final VoidCallback onRefreshState;
  final bool Function() isScrollLockedByMultiTouch;
  final void Function(bool locked) onUpdateScrollLock;
  final Widget Function(bool enableDoublePage) buildColumnMode;
  final Widget Function() buildRowMode;

  final FocusNode focusNode = FocusNode();
  final Set<int> _activeTouchPointers = <int>{};
  final AnimationController _zoomAnimation;
  final _viewerKey = GlobalKey();
  ({Matrix4Tween tween, int slot})? _zoom;
  bool _applyingZoomFrame = false;
  ({double focalY, double translationY})? _columnPan;
  Drag? _columnScrollDrag;
  ScrollHoldController? _columnScrollHold;
  bool _columnDragMovedList = false;

  static const _menuTapTravel = 8.0;
  _ReaderMenuTouch? _menuTouch;
  _ReaderMenuTouch? _previousMenuTouch;
  TapDownDetails? _tapDownDetails;
  TapDownDetails? _doubleTapDownDetails;
  bool _isCtrlPressed = false;
  bool _readerIsScrolling = false;
  int _scrollNotificationEpoch = 0;

  bool get _isDesktopPlatform =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  void setActionController(ReaderActionController controller) {
    actionController = controller;
  }

  void init() {
    transformationController.addListener(_onTransformationChanged);
    _zoomAnimation.addListener(_onZoomFrame);
  }

  void dispose() {
    _columnScrollHold?.cancel();
    _cancelColumnPan();
    transformationController.removeListener(_onTransformationChanged);
    _zoomAnimation.dispose();
    focusNode.dispose();
  }

  /// 构建阅读核心交互层：键盘、手势、缩放、多指锁滚动。
  Widget buildInteractiveViewer() {
    final readSetting = context.watchEffectiveReadSetting();
    final isDoubleTapActionEnabled =
        readSetting.doubleTapZoom || readSetting.doubleTapOpenMenu;

    return Focus(
      focusNode: focusNode,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUpOrCancel,
        onPointerCancel: _onPointerUpOrCancel,
        onPointerSignal: _onPointerSignal,
        child: GestureDetector(
          onTap: _onTap,
          onTapDown: (details) => _tapDownDetails = details,
          onTapCancel: () => _tapDownDetails = null,
          onDoubleTapDown: isDoubleTapActionEnabled
              ? (details) => _doubleTapDownDetails = details
              : null,
          onDoubleTap: isDoubleTapActionEnabled ? _onDoubleTap : null,
          onDoubleTapCancel: isDoubleTapActionEnabled
              ? () => _doubleTapDownDetails = null
              : null,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onReaderScroll,
            child: InteractiveViewer(
              key: _viewerKey,
              transformationController: transformationController,
              boundaryMargin: EdgeInsets.zero,
              minScale: kMinReaderScale,
              maxScale: kMaxReaderScale,
              scaleEnabled:
                  !_isDesktopPlatform ||
                  _isCtrlPressed ||
                  _activeTouchPointers.length >= 2 ||
                  transformationController.value.getMaxScaleOnAxis() >
                      kScaleLockThreshold,
              interactionEndFrictionCoefficient: kReaderPanFriction,
              onInteractionStart: _onViewerInteractionStart,
              onInteractionUpdate: _onViewerInteractionUpdate,
              onInteractionEnd: _onViewerInteractionEnd,
              child: isColumnReadMode(readSetting.readMode)
                  ? buildColumnMode(readSetting.doublePageMode)
                  : buildRowMode(),
            ),
          ),
        ),
      ),
    );
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f11) {
      unawaited(_onToggleDesktopFullscreen());
      return KeyEventResult.handled;
    }
    final handled = handleGlobalKeyEvent(
      event,
      actionController,
      reverseHorizontal: context
          .readEffectiveReadSetting()
          .reverseHorizontalPageTurn,
    );
    return handled ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  Future<void> _onTap() async {
    final details = _tapDownDetails;
    _tapDownDetails = null;
    if (details == null || !_isStillMenuTap(details)) return;

    // 保留单击和双击之间的调度顺序，点按数据在等待前已取出。
    await Future.delayed(Duration.zero);
    if (!context.mounted) return;

    final readSetting = context.readEffectiveReadSetting();
    ReaderGestureLogic.handleTap(
      actionController: actionController,
      context: context,
      details: details,
      onToggleMenu: () {
        if (readSetting.doubleTapOpenMenu && !readerCubit.state.isMenuVisible) {
          return;
        }
        onToggleMenu();
      },
      onBeforePageTurn: restoreScaleForPageTurnAction,
    );
  }

  void _onDoubleTap() {
    if (!context.mounted) return;
    _tapDownDetails = null;
    final readSetting = context.readEffectiveReadSetting();
    if (readSetting.doubleTapZoom) {
      _onDoubleTapZoom(readSetting);
      return;
    }
    final details = _doubleTapDownDetails;
    _doubleTapDownDetails = null;
    if (!readSetting.doubleTapOpenMenu || details == null) return;
    if (!_isStillMenuTap(details) ||
        !ReaderGestureLogic.isToolbarTap(
          context,
          details.globalPosition,
          readSetting,
        )) {
      return;
    }
    if (_isTouchPointer(details.kind)) {
      final firstTap = _previousMenuTouch;
      if (firstTap == null ||
          !firstTap.isStillTap ||
          !ReaderGestureLogic.isToolbarTap(
            context,
            firstTap.origin,
            readSetting,
          )) {
        return;
      }
    }
    onToggleMenu();
  }

  bool _isStillMenuTap(TapDownDetails details) {
    if (!_isTouchPointer(details.kind)) return true;
    final touch = _menuTouch;
    return touch != null &&
        touch.origin == details.globalPosition &&
        touch.isStillTap;
  }

  void _onDoubleTapZoom(ReadSettingState setting) {
    final details = _doubleTapDownDetails;
    _doubleTapDownDetails = null;
    if (details == null) return;

    final animate =
        setting.doubleTapZoomAnimation &&
        !MediaQuery.disableAnimationsOf(context) &&
        !context.read<GlobalSettingCubit>().state.eInkSetting.enabled &&
        !setting.einkOptimization;
    final pendingTarget = _zoom?.tween.end;
    final zoomOut = pendingTarget == null
        ? _viewerIsTransformed
        : pendingTarget.getMaxScaleOnAxis() > kScaleLockThreshold;
    if (zoomOut) {
      if (animate) {
        _zoomTo(Matrix4.identity());
      } else {
        resetViewerTransformIfNeeded();
      }
      return;
    }

    final renderObject = _viewerKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;

    // 以双击点为锚点放大，手感更自然。
    final localPosition = renderObject.globalToLocal(details.globalPosition);
    const targetScale = kDoubleTapZoomScale;
    final size = renderObject.size;
    final anchor =
        Offset(size.width / 2, size.height / 2) - localPosition * targetScale;
    final translation = isColumnReadMode(setting.readMode)
        ? Offset(
            anchor.dx.clamp(size.width * (1 - targetScale), 0.0),
            anchor.dy.clamp(size.height * (1 - targetScale), 0.0),
          )
        : anchor;
    final matrix = Matrix4.identity()
      ..translateByDouble(translation.dx, translation.dy, 0, 1)
      ..scaleByDouble(targetScale, targetScale, 1, 1);

    if (animate) {
      _zoomTo(matrix);
    } else {
      stopZoomAnimation();
      transformationController.value = matrix;
    }
  }

  void _zoomTo(Matrix4 target) {
    _zoom = (
      tween: Matrix4Tween(
        begin: transformationController.value.clone(),
        end: target,
      ),
      slot: readerCubit.state.currentSlot,
    );
    _zoomAnimation.forward(from: 0);
    _updateMultiTouchScrollLock();
  }

  void _onZoomFrame() {
    final zoom = _zoom;
    if (zoom == null) return;
    // A previous drag or automatic scroll can still settle on another page.
    if (readerCubit.state.currentSlot != zoom.slot) {
      resetViewerTransformIfNeeded();
      return;
    }
    final progress = _zoomAnimation.value;
    final finished = progress >= 1;
    if (finished) _zoom = null;
    _applyingZoomFrame = true;
    try {
      transformationController.value = finished
          ? zoom.tween.end!
          : zoom.tween.transform(Curves.easeOutCubic.transform(progress));
    } finally {
      _applyingZoomFrame = false;
    }
    _updateMultiTouchScrollLock();
  }

  void stopZoomAnimation() {
    if (_zoom == null) return;
    _zoom = null;
    _zoomAnimation.stop();
    _updateMultiTouchScrollLock();
  }

  void cancelViewerInteraction() {
    stopZoomAnimation();
    _columnScrollHold?.cancel();
    _cancelColumnPan();
  }

  void _onViewerInteractionStart(ScaleStartDetails details) {
    stopZoomAnimation();
    _cancelColumnPan();
    if (details.pointerCount == 1 &&
        _isTouchPointer(details.kind) &&
        isColumnReadMode(context.readEffectiveReadMode()) &&
        transformationController.value.getMaxScaleOnAxis() >
            kScaleLockThreshold) {
      _columnPan = (
        focalY: details.localFocalPoint.dy,
        translationY: transformationController.value.storage[13],
      );
    }
  }

  void _onViewerInteractionUpdate(ScaleUpdateDetails details) {
    _updateMultiTouchScrollLock();
    final previous = _columnPan;
    if (previous == null || details.pointerCount != 1) return;

    final matrix = transformationController.value;
    final focalY = details.localFocalPoint.dy;
    final translationY = matrix.storage[13];
    _columnPan = (focalY: focalY, translationY: translationY);

    // InteractiveViewer has already applied the part of this update that fits
    // inside its zoomed viewport. Continue the same drag in the underlying list.
    final fingerDelta = focalY - previous.focalY;
    final remainder = fingerDelta - (translationY - previous.translationY);
    final scroll = actionController.scrollController;
    _columnDragMovedList =
        remainder.abs() > precisionErrorTolerance &&
        remainder.sign == fingerDelta.sign &&
        scroll.hasClients;
    if (!_columnDragMovedList) return;

    // The scale recognizer already crossed its movement threshold, so the
    // forwarded drag starts immediately, without a second scroll threshold.
    _columnScrollDrag ??= scroll.position.drag(
      DragStartDetails(globalPosition: details.focalPoint),
      () => _columnScrollDrag = null,
    );
    final delta = remainder / matrix.getMaxScaleOnAxis();
    _columnScrollDrag?.update(
      DragUpdateDetails(
        delta: Offset(0, delta),
        primaryDelta: delta,
        globalPosition: details.focalPoint,
      ),
    );
  }

  void _onViewerInteractionEnd(ScaleEndDetails details) {
    if (details.pointerCount == 0 && _columnDragMovedList) {
      final velocity =
          details.velocity.pixelsPerSecond.dy /
          transformationController.value.getMaxScaleOnAxis();
      _columnScrollDrag?.end(
        DragEndDetails(
          velocity: Velocity(pixelsPerSecond: Offset(0, velocity)),
          primaryVelocity: velocity,
        ),
      );
    }
    _cancelColumnPan();
    _updateMultiTouchScrollLock();
  }

  void _cancelColumnPan() {
    _columnScrollDrag?.cancel();
    _columnScrollDrag = null;
    _columnPan = null;
    _columnDragMovedList = false;
  }

  bool _onReaderScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification) {
      _scrollNotificationEpoch++;
      _readerIsScrolling = true;
    } else if (notification is ScrollEndNotification) {
      final epoch = ++_scrollNotificationEpoch;
      // A tap can stop a fling in the inner Scrollable before this Listener
      // receives the same pointer down. Retain the scroll state for that event.
      scheduleMicrotask(() {
        if (epoch == _scrollNotificationEpoch) _readerIsScrolling = false;
      });
    }
    return false;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!_isTouchPointer(event.kind)) return;
    _activeTouchPointers.add(event.pointer);
    _previousMenuTouch = _menuTouch;
    _menuTouch = _ReaderMenuTouch(event.pointer, event.position)
      ..isStillTap = !_readerIsScrolling;
    if (_activeTouchPointers.length > 1) {
      _previousMenuTouch?.isStillTap = false;
      _menuTouch?.isStillTap = false;
    } else if (isColumnReadMode(context.readEffectiveReadMode()) &&
        transformationController.value.getMaxScaleOnAxis() >
            kScaleLockThreshold) {
      final scroll = actionController.scrollController;
      if (scroll.hasClients && scroll.position.isScrollingNotifier.value) {
        _columnScrollHold = scroll.position.hold(
          () => _columnScrollHold = null,
        );
      }
    }
    _updateMultiTouchScrollLock();
  }

  void _onPointerMove(PointerMoveEvent event) => _trackMenuTouch(event);

  void _onPointerUpOrCancel(PointerEvent event) {
    if (!_isTouchPointer(event.kind)) return;
    _trackMenuTouch(event);
    if (event is PointerCancelEvent) _cancelColumnPan();
    _activeTouchPointers.remove(event.pointer);
    if (_activeTouchPointers.isEmpty) _columnScrollHold?.cancel();
    _updateMultiTouchScrollLock();
  }

  void _trackMenuTouch(PointerEvent event) {
    final touch = _menuTouch;
    if (touch == null || touch.pointer != event.pointer || !touch.isStillTap) {
      return;
    }
    // Scroll can leave the recognizer arena undecided for short drags.
    // Remember movement even if the finger returns to the start before lifting.
    if (event is PointerCancelEvent ||
        (event.position - touch.origin).distanceSquared >
            _menuTapTravel * _menuTapTravel) {
      touch.isStillTap = false;
    }
  }

  bool _isTouchPointer(PointerDeviceKind? kind) {
    return kind == PointerDeviceKind.touch ||
        kind == PointerDeviceKind.stylus ||
        kind == PointerDeviceKind.invertedStylus;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    stopZoomAnimation();
    if (!_isDesktopPlatform) return;

    final newCtrlPressed =
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.controlLeft,
        ) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.controlRight,
        );

    if (_isCtrlPressed != newCtrlPressed) {
      _isCtrlPressed = newCtrlPressed;
      onRefreshState();
    }

    final readMode = context.readEffectiveReadMode();
    if (!newCtrlPressed && readMode != 0) {
      if (event.scrollDelta.dy > 0) {
        actionController.onPageActionNext();
      } else if (event.scrollDelta.dy < 0) {
        actionController.onPageActionPrev();
      }
    }
  }

  void _onTransformationChanged() {
    if (!_applyingZoomFrame && _zoom != null) stopZoomAnimation();
    _updateMultiTouchScrollLock();
  }

  // 多指触控或放大状态下锁定滚动，减少与翻页手势互相干扰。
  void _updateMultiTouchScrollLock() {
    final currentScale = transformationController.value.getMaxScaleOnAxis();
    final shouldLock =
        _activeTouchPointers.length >= 2 ||
        _zoom != null ||
        currentScale > kScaleLockThreshold;
    if (isScrollLockedByMultiTouch() == shouldLock || !context.mounted) return;
    onUpdateScrollLock(shouldLock);
  }

  bool get _viewerIsTransformed {
    final matrix = transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final tx = matrix.storage[12].abs();
    final ty = matrix.storage[13].abs();
    return scale > kScaleLockThreshold || tx > 0.5 || ty > 0.5;
  }

  /// 翻页前统一归位缩放与位移，避免跨页后仍停留在局部放大状态。
  bool resetViewerTransformIfNeeded() {
    final wasAnimating = _zoom != null;
    cancelViewerInteraction();
    if (!wasAnimating && !_viewerIsTransformed) return false;

    transformationController.value = Matrix4.identity();
    _activeTouchPointers.clear();
    _updateMultiTouchScrollLock();
    return true;
  }

  /// 供 [ReaderActionController] 翻页前调用。
  bool restoreScaleBeforeTurnPage(bool _) {
    resetViewerTransformIfNeeded();
    return false;
  }

  /// 供 State 在点击翻页前调用。
  void restoreScaleForPageTurnAction() {
    resetViewerTransformIfNeeded();
  }

  /// 供 State 在拖拽翻页前调用。
  void restoreScaleForPageDrag() {
    resetViewerTransformIfNeeded();
  }
}

class _ReaderMenuTouch {
  _ReaderMenuTouch(this.pointer, this.origin);

  final int pointer;
  final Offset origin;
  bool isStillTap = true;
}
