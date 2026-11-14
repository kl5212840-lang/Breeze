import 'dart:ui';

import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:zephyr/cubit/string_select.dart';
import 'package:zephyr/page/comic_info/comic_info.dart';
import 'package:zephyr/page/download/adapters/download_chapter_adapter.dart';
import 'package:zephyr/page/comic_read/cubit/reader_cubit.dart';
import 'package:zephyr/page/comic_read/method/jump_chapter.dart';
import 'package:zephyr/page/comic_read/method/get_local_info.dart';
import 'package:zephyr/page/comic_read/widgets/chrome/reader_tool_glyph.dart';
import 'package:zephyr/page/comic_read/widgets/settings/reader_settings_sheet.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/context/context_extensions.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/router/router.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_episode_ranges.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_control_colors.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';

class BottomWidget extends StatefulWidget {
  final ComicEntryType type;
  final dynamic comicInfo;
  final Widget? sliderWidget;
  final int order;
  final int epsNumber;
  final String comicId;
  final String from;
  final JumpChapter jumpChapter;
  final BuildContext? readerContext;
  final ValueChanged<bool>? onLandscapeChanged;
  final bool Function()? canChangePage;

  const BottomWidget({
    super.key,
    required this.type,
    required this.comicInfo,
    required this.sliderWidget,
    required this.order,
    required this.epsNumber,
    required this.comicId,
    required this.from,
    required this.jumpChapter,
    this.readerContext,
    this.onLandscapeChanged,
    this.canChangePage,
  });

  @override
  State<BottomWidget> createState() => _BottomWidgetState();
}

class _BottomWidgetState extends State<BottomWidget> {
  bool get isDownload =>
      widget.type == ComicEntryType.download ||
      widget.type == ComicEntryType.historyAndDownload;

  JumpChapter get jumpChapter => widget.jumpChapter;

  final Duration _animationDuration = const Duration(milliseconds: 300); // 动画时长

  late ComicEntryType tempType;
  late String comicId;
  List<UnifiedComicChapterRef> chapterRefs = [];

  @override
  void initState() {
    super.initState();

    tempType = widget.type;
    comicId = widget.comicId;
    if (tempType == ComicEntryType.historyAndDownload) {
      tempType = ComicEntryType.download;
    }
    if (tempType == ComicEntryType.history) {
      tempType = ComicEntryType.normal;
    }
    chapterRefs = resolveReaderChapters(
      widget.comicInfo,
      widget.from,
      offline: tempType == ComicEntryType.download,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMenuVisible = context.select(
      (ReaderCubit cubit) => cubit.state.isMenuVisible,
    );
    // 墨水屏：控制条滑动的中间帧只会攒成残影，直接出图。
    final eInkInstant = context.select(
      (GlobalSettingCubit cubit) => cubit.state.eInkSetting.enabled,
    );
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final animationDuration = eInkInstant || reduceMotion
        ? Duration.zero
        : _animationDuration;
    final bottomSafeHeight = context.bottomSafeHeight;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWideLayout = screenWidth >= 840;
    final topMaxWidth = (screenWidth * 0.56).clamp(380.0, 720.0).toDouble();
    final bottomMaxWidth = (screenWidth * (screenWidth >= 1200 ? 0.62 : 0.74))
        .clamp(560.0, 980.0)
        .toDouble();
    final isCompactLayout =
        screenWidth >= 600 && MediaQuery.sizeOf(context).height <= 600;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !isMenuVisible,
        child: AnimatedSlide(
          duration: animationDuration,
          curve: Curves.easeOutCubic,
          offset: isMenuVisible ? Offset.zero : const Offset(0, 1),
          child: Padding(
            padding: EdgeInsets.only(bottom: 6 + bottomSafeHeight),
            child: isCompactLayout
                ? _buildCompactControls(
                    maxWidth: bottomMaxWidth,
                    isWideLayout: isWideLayout,
                  )
                : _buildRegularControls(
                    topMaxWidth: topMaxWidth,
                    bottomMaxWidth: bottomMaxWidth,
                    isWideLayout: isWideLayout,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegularControls({
    required double topMaxWidth,
    required double bottomMaxWidth,
    required bool isWideLayout,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWideLayout ? topMaxWidth : double.infinity,
              ),
              child: _buildControlButtons(),
            ),
          ),
        ),
        if (widget.sliderWidget case final slider?) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWideLayout ? bottomMaxWidth : double.infinity,
                ),
                child: Row(children: [slider]),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompactControls({
    required double maxWidth,
    required bool isWideLayout,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isWideLayout ? maxWidth : double.infinity,
          ),
          child: Row(
            mainAxisAlignment: widget.sliderWidget == null
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              _buildControlButtons(),
              if (widget.sliderWidget case final slider?) ...[
                const SizedBox(width: 12),
                slider,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ChapterNavigationButton(
          icon: Icons.skip_previous_rounded,
          tooltip: t.reader.previousChapter,
          isEnabled: jumpChapter.havePrev,
          onTap: () => _jumpToChapter(true),
        ),
        const SizedBox(width: 10),
        FloatingActionIconButton(
          icon: Icons.home_outlined,
          tooltip: t.reader.backToHome,
          onPressed: () => popToRoot(context),
        ),
        const SizedBox(width: 10),
        FloatingActionIconButton(
          icon: Icons.view_list_outlined,
          tooltip: t.reader.selectChapter,
          isEnabled: chapterRefs.isNotEmpty,
          onPressed: _selectJumpChapter,
        ),
        const SizedBox(width: 10),
        FloatingActionIconButton(
          icon: Icons.tune_rounded,
          tooltip: t.reader.settings,
          onPressed: _openSettingsPanel,
        ),
        const SizedBox(width: 10),
        ChapterNavigationButton(
          icon: Icons.skip_next_rounded,
          tooltip: t.reader.nextChapter,
          isEnabled: jumpChapter.haveNext,
          onTap: () => _jumpToChapter(false),
        ),
      ],
    );
  }

  void _openSettingsPanel() {
    final readerCubit = context.read<ReaderCubit>();
    final canChangePage = widget.canChangePage;
    showReaderSettingsSheet(
      context,
      changePageIndex: (int value) {
        if (readerCubit.isClosed || canChangePage?.call() == false) return;
        readerCubit.updateCurrentSlot(value);
        readerCubit.updateSliderChanged(0.0);
      },
      onLandscapeChanged: widget.onLandscapeChanged,
      source: widget.from,
      comicId: widget.comicId,
    );
  }

  Future<bool> _bottomButtonDialog(
    BuildContext context,
    String title,
    String content,
  ) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false, // 不允许点击外部区域关闭对话框
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(title),
              content: Text(content),
              actions: [
                TextButton(
                  child: Text(t.common.cancel),
                  onPressed: () {
                    Navigator.of(context).pop(false); // 返回 false
                  },
                ),
                TextButton(
                  child: Text(t.common.ok),
                  onPressed: () {
                    Navigator.of(context).pop(true); // 返回 true
                  },
                ),
              ],
            );
          },
        ) ??
        false; // 处理返回值为空的情况
  }

  Future<void> _jumpToChapter(bool isPrev) async {
    final readerContext = widget.readerContext ?? context;
    final chapterNavigation = jumpChapter;
    final dialogMessage = isPrev
        ? t.reader.previousChapter
        : t.reader.nextChapter;
    final result = await _bottomButtonDialog(
      readerContext,
      t.reader.jumpToChapterTitle,
      t.reader.jumpToChapterMessage(chapter: dialogMessage),
    );
    if (!result || !_isCurrentReader(readerContext)) return;
    chapterNavigation.jumpToChapter(readerContext, isPrev);
  }

  Future<void> _selectJumpChapter() async {
    final config = widget;
    final readerContext = config.readerContext ?? context;
    final router = AutoRouter.of(readerContext);
    final initialIndex = jumpChapter.currentChapterIndexIn(chapterRefs);
    final result = await showDialog<UnifiedComicChapterRef?>(
      context: readerContext,
      barrierDismissible: false, // 不允许点击外部区域关闭对话框
      builder: (BuildContext context) {
        return ChapterPickerDialog(
          refs: chapterRefs,
          initialIndex: initialIndex,
          onSelected: (ep) =>
              Navigator.of(context, rootNavigator: false).pop(ep),
        );
      },
    );
    if (result != null && _isCurrentReader(readerContext)) {
      final chapter = const DownloadChapterAdapter().fromChapterRef(result);
      router.replace(
        ComicReadRoute(
          key: Key(Uuid().v4()),
          comicInfo: config.comicInfo,
          comicId: comicId,
          type: tempType,
          order: chapter.order,
          chapterId: chapter.id,
          requestId: result.requestId.trim(),
          storageChapterId: result.storageChapterId.trim(),
          logicalKey: chapter.id,
          chapterExtern: Map<String, dynamic>.from(chapter.extern),
          epsNumber: config.epsNumber,
          from: config.from,
          stringSelectCubit: readerContext.read<StringSelectCubit>(),
        ),
      );
    }
  }

  bool _isCurrentReader(BuildContext context) =>
      context.mounted && ModalRoute.of(context)?.isCurrent == true;
}

class ChapterPickerDialog extends StatefulWidget {
  final List<UnifiedComicChapterRef> refs;
  final int initialIndex;
  final ValueChanged<UnifiedComicChapterRef> onSelected;

  const ChapterPickerDialog({
    required this.refs,
    required this.initialIndex,
    required this.onSelected,
  });

  @override
  State<ChapterPickerDialog> createState() => _ChapterPickerDialogState();
}

class _ChapterPickerDialogState extends State<ChapterPickerDialog> {
  // 行高只是估算（章节名可能换行），用于对话框高度与首屏定位；
  // 精确定位靠 _targetKey + ensureVisible。
  static const double _estimatedRowHeight = 52.0;
  static const double _estimatedGroupHeaderHeight = 36.0;
  static const int _maxRevealAttempts = 3;

  GlobalKey? _targetKey;
  late final ScrollController _scrollController;
  int _revealAttempts = 0;
  late int _range = _hasValidInitial ? widget.initialIndex ~/ 50 : 0;

  /// 扁平行：组头（不可点）与章节交错，单组时无组头，与今天一致。
  late final List<_PickerRow> _allRows = _buildRows(widget.refs);
  int? _cachedRange;
  List<_PickerRow>? _cachedRows;
  List<_PickerRow> get _rows {
    if (widget.refs.length <= 50) return _allRows;
    if (_cachedRange == _range) return _cachedRows!;
    final result = <_PickerRow>[];
    _PickerGroupRow? header;
    for (final row in _allRows) {
      if (row is _PickerGroupRow) {
        header = row;
      } else if (row is _PickerChapterRow && row.globalIndex ~/ 50 == _range) {
        if (header != null) {
          result.add(header);
          header = null;
        }
        result.add(row);
      }
    }
    _cachedRange = _range;
    return _cachedRows = result;
  }

  int get _initialRow => _hasValidInitial
      ? _rows.indexWhere(
          (row) =>
              row is _PickerChapterRow &&
              row.globalIndex == widget.initialIndex,
        )
      : -1;

  bool get _hasValidInitial =>
      widget.initialIndex >= 0 && widget.initialIndex < widget.refs.length;

  static List<_PickerRow> _buildRows(List<UnifiedComicChapterRef> refs) {
    final groups = groupIndicesByTitle(refs.length, (i) => refs[i].groupTitle);
    if (groups.length <= 1) {
      return [
        for (var i = 0; i < refs.length; i++)
          _PickerChapterRow(ref: refs[i], globalIndex: i),
      ];
    }
    final rows = <_PickerRow>[];
    for (final group in groups) {
      rows.add(_PickerGroupRow(title: group.title));
      for (final index in group.items) {
        rows.add(_PickerChapterRow(ref: refs[index], globalIndex: index));
      }
    }
    return rows;
  }

  double _estimatedOffsetForRow(int row) {
    var offset = 0.0;
    for (var i = 0; i < row && i < _rows.length; i++) {
      offset += _rows[i] is _PickerGroupRow
          ? _estimatedGroupHeaderHeight
          : _estimatedRowHeight;
    }
    return offset;
  }

  @override
  void initState() {
    super.initState();
    // 原来是 List.generate(refs.length) 建 N 个 GlobalKey，
    // 全局注册 + 阻碍复用；现在只给当前章节留 1 个。
    if (_initialRow >= 0) {
      _targetKey = GlobalKey();
      _scrollController = ScrollController(
        initialScrollOffset: _estimatedOffsetForRow(_initialRow),
      );
    } else {
      _scrollController = ScrollController();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealInitial());
  }

  /// 直接定位到当前章节（无动画）。目标行还没建出来时先跳到估算位置，
  /// 下一帧再精确定位；超过次数就停在估算位置附近，不死循环。
  void _revealInitial() {
    if (!mounted || _revealAttempts >= _maxRevealAttempts) return;
    _revealAttempts++;
    final key = _targetKey;
    if (key == null || _initialRow < 0) return;
    final targetContext = key.currentContext;
    if (targetContext == null) {
      if (_scrollController.hasClients) {
        final max = _scrollController.position.maxScrollExtent;
        _scrollController.jumpTo(
          _estimatedOffsetForRow(_initialRow).clamp(0.0, max),
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealInitial());
      return;
    }
    Scrollable.ensureVisible(
      targetContext,
      alignment: 0.5,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final highlightStyle = TextButton.styleFrom(
      foregroundColor: colorScheme.onPrimaryContainer,
      backgroundColor: colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
    // 定高（按估算行高撑，封顶 60% 屏高）：ListView 高度有界，
    // 不用 shrinkWrap 也能懒加载，只建可视行。
    final screenSize = MediaQuery.sizeOf(context);
    final maxHeight = screenSize.height * 0.6;
    final listHeight = (_estimatedOffsetForRow(_rows.length) + 16).clamp(
      120.0,
      maxHeight,
    );
    // 桌面端别撑满：最多 440，手机上占 90% 屏宽。
    final listWidth = (screenSize.width * 0.9).clamp(0.0, 440.0).toDouble();

    return AlertDialog(
      title: Text(t.reader.selectChapter),
      content: SizedBox(
        width: listWidth,
        height: listHeight,
        child: Column(
          children: [
            if (widget.refs.length > 50)
              VideoEpisodeRanges(
                count: widget.refs.length,
                index: _range,
                onChanged: (value) {
                  setState(() => _range = value);
                  if (_scrollController.hasClients) _scrollController.jumpTo(0);
                },
              ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _rows.length,
                itemBuilder: (context, i) {
                  final row = _rows[i];
                  if (row is _PickerGroupRow) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
                      child: Text(
                        chapterGroupDisplayTitle(
                          row.title,
                          t.comicInfo.untitledGroup,
                        ),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }
                  final chapterRow = row as _PickerChapterRow;
                  final ref = chapterRow.ref;
                  final isCurrent = i == _initialRow;
                  return Padding(
                    key: isCurrent ? _targetKey : null,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: TextButton(
                      style: isCurrent ? highlightStyle : null,
                      onPressed: () => widget.onSelected(ref),
                      child: Row(
                        children: [
                          Expanded(child: Text(ref.name)),
                          if (isCurrent)
                            Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: Text(t.common.cancel),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

sealed class _PickerRow {
  const _PickerRow();
}

/// 组头行（不可点）。单组时无此行。
class _PickerGroupRow extends _PickerRow {
  const _PickerGroupRow({required this.title});

  final String title;
}

/// 章节行，[globalIndex] 对应 refs 下标（用于定位当前章）。
class _PickerChapterRow extends _PickerRow {
  const _PickerChapterRow({required this.ref, required this.globalIndex});

  final UnifiedComicChapterRef ref;
  final int globalIndex;
}

class ChapterNavigationButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isEnabled;
  final VoidCallback onTap;

  const ChapterNavigationButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;

    return _FrostedCircleIconButton(
      tooltip: tooltip,
      isEnabled: isEnabled,
      onPressed: onTap,
      icon: icon,
      foregroundColor: colorScheme.onSecondaryContainer,
      backgroundColor: colorScheme.secondaryContainer.withValues(alpha: 0.72),
      disabledBackgroundColor: colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.38,
      ),
    );
  }
}

class FloatingActionIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isEnabled;
  final VoidCallback onPressed;

  const FloatingActionIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.isEnabled = true,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    return _FrostedCircleIconButton(
      tooltip: tooltip,
      isEnabled: isEnabled,
      onPressed: onPressed,
      icon: icon,
      foregroundColor: colorScheme.onPrimaryContainer,
      backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.76),
      disabledBackgroundColor: colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.38,
      ),
    );
  }
}

class _FrostedCircleIconButton extends StatelessWidget {
  final String tooltip;
  final bool isEnabled;
  final VoidCallback onPressed;
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color disabledBackgroundColor;

  const _FrostedCircleIconButton({
    required this.tooltip,
    required this.isEnabled,
    required this.onPressed,
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.disabledBackgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;

    if (!AppInterfaceStyleScope.usesSystem(context)) {
      final highContrast = MediaQuery.highContrastOf(context);
      return TouchHoverIntent(
        identity: icon,
        builder: (context, hover) => IconButton(
          tooltip: tooltip,
          onPressed: isEnabled ? onPressed : null,
          style:
              IconButton.styleFrom(
                fixedSize: const Size(44, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                foregroundColor: colorScheme.onSurface,
                backgroundColor: Color.alphaBlend(
                  BreezeControlColors.tool(colorScheme),
                  colorScheme.surface,
                ),
                disabledForegroundColor: colorScheme.onSurface.withValues(
                  alpha: .38,
                ),
                disabledBackgroundColor: colorScheme.surface,
              ).copyWith(
                overlayColor: hover.overlayColor(
                  WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.pressed)) {
                      return colorScheme.primary.withValues(alpha: .16);
                    }
                    if (states.contains(WidgetState.focused)) {
                      return colorScheme.primary.withValues(alpha: .12);
                    }
                    if (states.contains(WidgetState.hovered)) {
                      return colorScheme.primary.withValues(alpha: .08);
                    }
                    return null;
                  }),
                ),
                side: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.focused)) {
                    return BorderSide(color: colorScheme.primary, width: 2);
                  }
                  if (highContrast && !states.contains(WidgetState.disabled)) {
                    return BorderSide(color: colorScheme.outline, width: 1.5);
                  }
                  return BorderSide.none;
                }),
              ),
          icon: ReaderToolGlyph(icon),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: IconButton(
          tooltip: tooltip,
          onPressed: isEnabled ? onPressed : null,
          style: IconButton.styleFrom(
            fixedSize: const Size(44, 44),
            shape: const CircleBorder(),
            foregroundColor: foregroundColor,
            backgroundColor: backgroundColor,
            disabledForegroundColor: colorScheme.onSurface.withValues(
              alpha: 0.38,
            ),
            disabledBackgroundColor: disabledBackgroundColor,
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          icon: ReaderToolGlyph(icon),
        ),
      ),
    );
  }
}
