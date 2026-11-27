import 'package:flutter/widgets.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/cubit/comic_read_preference_cubit.dart';
import 'package:zephyr/page/comic_read/controller/reader_action_controller.dart';

class ReaderGestureLogic {
  static bool isToolbarTap(
    BuildContext context,
    Offset position,
    ReadSettingState setting,
  ) {
    final viewport = context.findRenderObject();
    return viewport is RenderBox &&
        viewport.hasSize &&
        _toolbarContains(
          viewport.globalToLocal(position),
          viewport.size,
          setting,
        );
  }

  static bool _toolbarContains(
    Offset position,
    Size size,
    ReadSettingState setting,
  ) {
    if (!(Offset.zero & size).contains(position)) return false;
    if (!setting.customToolbarTapArea) return true;
    final fraction =
        normalizeToolbarTapAreaPercent(setting.toolbarTapAreaPercent) / 100;
    final inset = size.width * (1 - fraction) / 2;
    return position.dx >= inset && position.dx < size.width - inset;
  }

  static void handleTap({
    required ReaderActionController actionController,
    required BuildContext context,
    required TapDownDetails details,
    required VoidCallback onToggleMenu,
    VoidCallback? onBeforePageTurn,
  }) {
    final readSetting = context.readEffectiveReadSetting();
    final isWebtoon = readSetting.readMode == 0;
    final viewport = context.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return;
    final tapPosition = viewport.globalToLocal(details.globalPosition);
    final Size viewportSize = viewport.size;
    if (!(Offset.zero & viewportSize).contains(tapPosition)) return;

    final screenWidth = viewportSize.width;
    final screenHeight = viewportSize.height;
    if (_toolbarContains(tapPosition, viewportSize, readSetting)) {
      onToggleMenu();
      return;
    }
    if (isWebtoon && !readSetting.tapPageTurnInWebtoon) return;

    final shouldNext = isWebtoon
        ? _shouldNextForWebtoonTap(
            mode: readSetting.tapPageTurnMode,
            tapY: tapPosition.dy,
            screenHeight: screenHeight,
          )
        : switch (readSetting.tapPageTurnMode) {
            ReaderTapPageTurnMode.fullScreen => true,
            ReaderTapPageTurnMode.leftHand =>
              tapPosition.dx < (screenWidth / 2),
            ReaderTapPageTurnMode.rightHand =>
              tapPosition.dx >= (screenWidth / 2),
          };

    onBeforePageTurn?.call();
    if (shouldNext) {
      actionController.onPageActionNext();
    } else {
      actionController.onPageActionPrev();
    }
  }

  static bool _shouldNextForWebtoonTap({
    required ReaderTapPageTurnMode mode,
    required double tapY,
    required double screenHeight,
  }) {
    return switch (mode) {
      ReaderTapPageTurnMode.fullScreen => true,
      ReaderTapPageTurnMode.leftHand => tapY < (screenHeight / 2),
      ReaderTapPageTurnMode.rightHand => tapY >= (screenHeight / 2),
    };
  }
}
