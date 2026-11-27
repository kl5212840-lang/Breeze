import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/widgets/native_material_surface.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/cubit/comic_read_preference_cubit.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/util/context/context_extensions.dart';
import 'package:zephyr/util/debouncer.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_control_colors.dart';
import 'package:zephyr/widgets/breeze_switch.dart';
import 'package:zephyr/widgets/task_dialog.dart';

part 'reader_settings_gesture_tab.dart';
part 'reader_settings_info_tab.dart';
part 'reader_settings_read_tab.dart';
part 'reader_settings_per_comic_tab.dart';

Future<void> showReaderSettingsSheet(
  BuildContext context, {
  ValueChanged<int>? changePageIndex,
  ValueChanged<bool>? onLandscapeChanged,
  String source = '',
  String comicId = '',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: AppInterfaceStyleScope.usesAndroidSystem(context) ? 0 : null,
    barrierLabel: t.common.close,
    isDismissible: true,
    enableDrag: true,
    builder: (context) {
      // 外层钉死全局：前三个 tab 与全局入口恒写全局，不回退读 cubit；
      // 第四个 tab 内层的 perComic:true 会覆盖这一层。
      return _PerComicScope(
        perComic: false,
        child: _ReaderSettingsSheet(
          changePageIndex: changePageIndex ?? (_) {},
          onLandscapeChanged: onLandscapeChanged,
          source: source,
          comicId: comicId,
        ),
      );
    },
  );
}

class _ReaderSettingsSheet extends StatelessWidget {
  final ValueChanged<int> changePageIndex;
  final ValueChanged<bool>? onLandscapeChanged;
  final String source;
  final String comicId;

  const _ReaderSettingsSheet({
    required this.changePageIndex,
    this.onLandscapeChanged,
    this.source = '',
    this.comicId = '',
  });

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final maxHeight = mediaSize.height * 0.7;
    final isAndroidPhone =
        !kIsWeb && Platform.isAndroid && mediaSize.shortestSide < 600;

    return SafeArea(
      top: false,
      maintainBottomViewPadding: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Stack(
          children: [
            // 卡片外部的空白点击直接关闭（框体自身占满全屏，默认遮罩点不透）。
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: const SizedBox.expand(),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: SizedBox(
                  height: maxHeight,
                  child: _ReaderSettingsCard(
                    changePageIndex: changePageIndex,
                    isAndroidPhone: isAndroidPhone,
                    onLandscapeChanged: onLandscapeChanged,
                    source: source,
                    comicId: comicId,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderSettingsCard extends StatelessWidget {
  final ValueChanged<int> changePageIndex;
  final bool isAndroidPhone;
  final ValueChanged<bool>? onLandscapeChanged;
  final String source;
  final String comicId;

  const _ReaderSettingsCard({
    required this.changePageIndex,
    required this.isAndroidPhone,
    this.onLandscapeChanged,
    this.source = '',
    this.comicId = '',
  });

  @override
  Widget build(BuildContext context) {
    final perComicAvailable =
        source.trim().isNotEmpty && comicId.trim().isNotEmpty;
    final tabLength = perComicAvailable ? 4 : 3;

    return NativeMaterialSurface(
      readableContent: true,
      floating: true,
      androidGlass: true,
      child: DefaultTabController(
        length: tabLength,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ReaderSettingsHeader(showPerComicTab: perComicAvailable),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                children: [
                  _SettingsTabVisibility(
                    index: 0,
                    child: _ReaderSettingsReadTab(
                      changePageIndex: changePageIndex,
                      onLandscapeChanged: onLandscapeChanged,
                      source: source,
                      comicId: comicId,
                    ),
                  ),
                  _SettingsTabVisibility(
                    index: 1,
                    child: _ReaderSettingsGestureTab(
                      isAndroidPhone: isAndroidPhone,
                    ),
                  ),
                  const _SettingsTabVisibility(
                    index: 2,
                    child: _ReaderSettingsInfoTab(),
                  ),
                  if (perComicAvailable)
                    _SettingsTabVisibility(
                      index: 3,
                      child: _ReaderSettingsPerComicTab(
                        changePageIndex: changePageIndex,
                        onLandscapeChanged: onLandscapeChanged,
                        source: source,
                        comicId: comicId,
                        isAndroidPhone: isAndroidPhone,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 设置页头部：把手 + TabBar（阅读页入口多一个“本漫”tab）。
class _ReaderSettingsHeader extends StatelessWidget {
  final bool showPerComicTab;

  const _ReaderSettingsHeader({this.showPerComicTab = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: t.common.close,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).maybePop(),
              child: SizedBox(
                height: 44,
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final labels = [
                t.reader.settings,
                t.reader.gesture,
                t.reader.infoBar,
                if (showPerComicTab) t.reader.perComicThisComic,
              ];
              final style = context.theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              );
              var widestLabel = 0.0;
              for (final label in labels) {
                final painter = TextPainter(
                  text: TextSpan(text: label, style: style),
                  textDirection: Directionality.of(context),
                  locale: Localizations.localeOf(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout();
                if (painter.width > widestLabel) widestLabel = painter.width;
                painter.dispose();
              }
              // Fixed tabs get equal slots. A short label cannot give unused
              // space to the longest label.
              const minimumPadding = 8.0;
              const preferredPadding = 16.0;
              final availablePadding =
                  (constraints.maxWidth / labels.length - widestLabel.ceil()) /
                  2;
              final scroll = availablePadding < minimumPadding;
              final labelPadding = EdgeInsets.symmetric(
                horizontal: scroll
                    ? preferredPadding
                    : availablePadding.clamp(minimumPadding, preferredPadding),
              );
              return TabBar(
                dividerColor: Colors.transparent,
                labelStyle: style,
                unselectedLabelStyle: style?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                labelColor: colorScheme.primary,
                unselectedLabelColor: colorScheme.onSurfaceVariant,
                labelPadding: labelPadding,
                isScrollable: scroll,
                tabAlignment: scroll ? TabAlignment.start : TabAlignment.fill,
                tabs: [for (final label in labels) Tab(text: label)],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// PageView may keep adjacent pages alive. Explicit TickerMode lets the shared
/// disclosure reset when a tab is left, as it already does for covered routes.
class _SettingsTabVisibility extends StatelessWidget {
  const _SettingsTabVisibility({required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) =>
          TickerMode(enabled: controller.index == index, child: child!),
    );
  }
}

class _SettingsNoticeCard extends StatelessWidget {
  final String text;

  const _SettingsNoticeCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return SettingNote(text, padding: EdgeInsets.zero);
  }
}

class _SettingsTabContent extends StatelessWidget {
  final Widget child;

  const _SettingsTabContent({required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: child,
    );
  }
}

/// 阅读设置 sheet 内通用的“读目标值 + 按目标写”。
/// 读：[watchTargetReadSetting]——本漫 tab 读有效值（patch 已合并），其余只读全局。
/// 写：按当前编辑目标路由——改全局走 `GlobalSettingCubit`，
/// 改本漫走 `ComicReadPreferenceCubit.updateField`，只写变化的 key。
/// 需要震动反馈由调用方自己加；需要跳页（如切阅读模式）也由调用方自己调。
///
/// 写目标只看 [_PerComicScope]：外层恒包 `perComic: false`，
/// 第四个“本漫”tab 内层包 `perComic: true`，里面所有控件读写全钉本漫。
/// 加新设置项只写一遍 Section，第四 tab 复用同一个，不写第二遍。
extension EffectiveReadSettingX on BuildContext {
  /// 当前编辑目标是不是本漫：只看最近的 [_PerComicScope]，不回退读 cubit。
  ///
  /// 旧漫画的绑定状态漏不进全局页——全局入口与前三个 tab 恒为 false。
  bool get isEditingPerComic => _PerComicScope.maybeOf(this)?.perComic ?? false;

  /// 当前编辑目标的值：本漫 tab 读有效值，其余只读全局。
  ///
  /// 设置 UI 一律读这个，保证“显示什么就改什么”；渲染层继续用
  /// [ComicReadPreferenceContextX.watchEffectiveReadSetting]。
  ReadSettingState watchTargetReadSetting() {
    if (isEditingPerComic) return watchEffectiveReadSetting();
    return watch<GlobalSettingCubit>().state.readSetting;
  }

  /// 按编辑目标写入：本漫→patch（只含变化 key），全局→全局设置。
  Future<Set<String>> updateEffectiveReadSetting(
    ReadSettingState Function(ReadSettingState current) fn,
  ) {
    final global = read<GlobalSettingCubit>();
    if (isEditingPerComic) {
      return read<ComicReadPreferenceCubit>().updateField(
        global.state.readSetting,
        fn,
      );
    }
    global.updateReadSetting(fn);
    return Future.value(const <String>{});
  }
}

/// 钉死子树写目标：`perComic: true` 包住第四 tab，里面全写本漫。
class _PerComicScope extends InheritedWidget {
  final bool perComic;

  const _PerComicScope({required this.perComic, required super.child});

  static _PerComicScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_PerComicScope>();
  }

  @override
  bool updateShouldNotify(_PerComicScope oldWidget) {
    return perComic != oldWidget.perComic;
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  /// 标题行右侧动作（如本漫 tab 阅读模式旁的“跟随全局”）。
  final Widget? trailing;
  final Map<String, String> details;

  const _SettingsSection({
    required this.title,
    required this.children,
    this.trailing,
    this.details = const {},
  });

  bool _isRow(Widget child) =>
      child is _SettingsSwitchTile ||
      child is _SettingsDropdownTile ||
      child is _SettingsSliderCard;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colorScheme;
    final breeze = !AppInterfaceStyleScope.usesSystem(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: breeze
              ? colors.surfaceContainerLowest
              : colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < children.length; index++) ...[
                  if (_isRow(children[index]))
                    children[index]
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: children[index],
                    ),
                  if (index < children.length - 1 &&
                      _isRow(children[index]) &&
                      _isRow(children[index + 1]))
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 16,
                      endIndent: 16,
                      color: colors.outlineVariant.withValues(alpha: .55),
                    ),
                ],
              ],
            ),
          ),
        ),
        if (details.isNotEmpty)
          SettingDetailsNotes(sectionTitle: title, details: details),
      ],
    );
  }
}

class _SettingsChoiceChip extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _SettingsChoiceChip({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    final breeze = !AppInterfaceStyleScope.usesSystem(context);

    return ChoiceChip(
      label: Text(title),
      selected: selected,
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      backgroundColor: breeze
          ? BreezeControlColors.tool(colorScheme)
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      selectedColor: breeze
          ? colorScheme.surfaceContainerHighest
          : colorScheme.primaryContainer.withValues(alpha: 0.92),
      side: breeze && !selected && !MediaQuery.highContrastOf(context)
          ? BorderSide.none
          : BorderSide(
              color: selected
                  ? colorScheme.primary
                  : breeze
                  ? colorScheme.outline
                  : colorScheme.outlineVariant.withValues(alpha: 0.7),
              width: selected ? 1.4 : 1,
            ),
      labelStyle: context.theme.textTheme.bodyMedium?.copyWith(
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected
            ? (breeze ? colorScheme.primary : colorScheme.onPrimaryContainer)
            : colorScheme.onSurface,
      ),
      onSelected: (_) => onTap(),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.title,
    this.subtitle = '',
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          minTileHeight: 44,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text(title),
          onTap: () => onChanged(!value),
          trailing: BreezeSwitch(
            Switch.adaptive(
              thumbIcon: settingSwitchThumbIcon(context),
              value: value,
              onChanged: onChanged,
            ),
          ),
        ),
        if (subtitle.trim().isNotEmpty)
          SettingNote(
            subtitle,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          ),
      ],
    );
  }
}

class _SettingsDropdownTile extends StatelessWidget {
  final String title;
  final int value;
  final List<int> values;
  final ValueChanged<int> onChanged;

  const _SettingsDropdownTile({
    required this.title,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SettingChoiceTile<int>(
      title: title,
      value: value,
      items: {for (final option in values) option: option.toString()},
      onChanged: onChanged,
    );
  }
}

class _SettingsSliderCard extends StatefulWidget {
  const _SettingsSliderCard({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.onChanged,
    this.divisions,
    this.enabled = true,
    this.sliderKey,
    this.preview,
  });

  final String title, suffix;
  final int value, min, max;
  final int? divisions;
  final bool enabled;
  final Key? sliderKey;
  final Widget Function(BuildContext, double)? preview;
  final ValueChanged<int> onChanged;

  @override
  State<_SettingsSliderCard> createState() => _SettingsSliderCardState();
}

class _SettingsSliderCardState extends State<_SettingsSliderCard> {
  double? _draft;
  PointerDownEvent? _pointer;
  bool _released = false, _vertical = false, _dragging = false;
  int? _hapticBucket;
  Duration? _lastHaptic;

  bool _editing = false;

  bool get _canEdit => widget.enabled && widget.suffix.startsWith('%');

  Future<void> _startEditor() async {
    if (!_canEdit || _editing) return;
    _editing = true;
    final result = await showDialog<int>(
      context: context,
      builder: (_) => _ReaderPercentageDialog(
        title: widget.title,
        value: widget.value.clamp(widget.min, widget.max),
        min: widget.min,
        max: widget.max,
        preview: widget.preview,
        onDraft: (value) {
          if (mounted) setState(() => _draft = value?.toDouble());
        },
      ),
    );
    if (!mounted) return;
    setState(() {
      _editing = false;
      _draft = null;
    });
    if (result == null || result == widget.value || !_canEdit) return;
    HapticFeedback.selectionClick();
    widget.onChanged(result);
  }

  int? get _markedDivisions =>
      widget.suffix.startsWith('%') ? null : widget.divisions;

  int _rounded(double value) => value.round().clamp(widget.min, widget.max);

  String _label(double value) =>
      '${_rounded(value)}${widget.suffix.startsWith('%') ? '' : ' '}${widget.suffix}';

  void _pointerDown(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event;
    _released = _vertical = _dragging = false;
    _hapticBucket = _bucket(widget.value.toDouble());
    _lastHaptic = null;
  }

  int _bucket(double value) {
    final fraction = (value - widget.min) / (widget.max - widget.min);
    final divisions = _markedDivisions;
    return divisions == null
        ? (fraction * 10).floor()
        : (fraction * divisions).round();
  }

  void _pointerMove(PointerMoveEvent event) {
    final pointer = _pointer;
    if (pointer?.pointer != event.pointer || _vertical || _dragging) return;
    final delta = event.position - pointer!.position;
    if (delta.distanceSquared <= 64) return;
    _vertical = delta.dy.abs() > delta.dx.abs();
    _dragging = !_vertical;
    if (_vertical && _draft != null) setState(() => _draft = null);
  }

  void _pointerFinished(PointerEvent event) {
    final pointer = _pointer;
    if (pointer?.pointer != event.pointer) return;
    _released = event is PointerUpEvent && !_vertical;
    scheduleMicrotask(() {
      if (!mounted || !identical(_pointer, pointer)) return;
      _pointer = null;
      _released = _vertical = _dragging = false;
      if (_draft != null) setState(() => _draft = null);
    });
  }

  void _preview(double value) {
    if (_vertical || value == _draft) return;
    setState(() => _draft = value);
    if (!_dragging || _released || _pointer == null) return;
    final bucket = _bucket(value);
    if (bucket == _hapticBucket) return;
    // Only confirmed horizontal travel generates milestone haptics.
    final now = SchedulerBinding.instance.currentSystemFrameTimeStamp;
    final endpoint = value == widget.min || value == widget.max;
    if (!endpoint &&
        _lastHaptic != null &&
        now - _lastHaptic! < const Duration(milliseconds: 60)) {
      return;
    }
    _hapticBucket = bucket;
    _lastHaptic = now;
    HapticFeedback.selectionClick();
  }

  void _commit(double value) {
    if (_draft != null) setState(() => _draft = null);
    if (_pointer != null && !_released) return;
    final next = _rounded(value);
    if (next == widget.value) return;
    if (!_dragging || _lastHaptic == null) HapticFeedback.selectionClick();
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colorScheme;
    final value =
        _draft ?? widget.value.clamp(widget.min, widget.max).toDouble();
    final divisions = _markedDivisions;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.preview case final preview?) ...[
            preview(context, value),
            const SizedBox(height: 8),
          ],
          _valueRow(
            _canEdit
                ? Semantics(
                    button: true,
                    label: t.reader.editSliderPercentage(title: widget.title),
                    value: _label(value),
                    onTap: _startEditor,
                    excludeSemantics: true,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        alignment: AlignmentDirectional.centerEnd,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(44, 44),
                      ),
                      onPressed: _startEditor,
                      child: _valueLabel(value, theme),
                    ),
                  )
                : ExcludeSemantics(child: _valueLabel(value, theme)),
          ),
          SizedBox(
            height: 44,
            child: Listener(
              onPointerDown: _pointerDown,
              onPointerMove: _pointerMove,
              onPointerUp: _pointerFinished,
              onPointerCancel: _pointerFinished,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  trackShape: divisions == null
                      ? const RoundedRectSliderTrackShape()
                      : _SettingsTickTrack(divisions),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                  activeTrackColor: colors.primary,
                  inactiveTrackColor: colors.outlineVariant,
                  activeTickMarkColor: colors.onPrimary,
                  inactiveTickMarkColor: colors.onSurfaceVariant,
                  disabledActiveTickMarkColor: colors.onSurfaceVariant
                      .withValues(alpha: .46),
                  disabledInactiveTickMarkColor: colors.onSurfaceVariant
                      .withValues(alpha: .46),
                  tickMarkShape: SliderTickMarkShape.noTickMark,
                  showValueIndicator: ShowValueIndicator.never,
                ),
                child: Slider(
                  key: widget.sliderKey,
                  min: widget.min.toDouble(),
                  max: widget.max.toDouble(),
                  divisions: widget.divisions,
                  value: value,
                  label: widget.title,
                  semanticFormatterCallback: _label,
                  onChanged: widget.enabled && !_editing ? _preview : null,
                  onChangeEnd: widget.enabled && !_editing ? _commit : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _valueRow(Widget value) => Row(
    crossAxisAlignment: _canEdit
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start,
    children: [
      Expanded(
        flex: 3,
        child: ExcludeSemantics(
          child: Text(widget.title, style: context.theme.textTheme.bodyMedium),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(flex: 2, child: value),
    ],
  );

  Widget _valueLabel(double value, ThemeData theme) => Text(
    _label(value),
    textAlign: TextAlign.end,
    style: theme.textTheme.bodyMedium?.copyWith(
      color: _canEdit
          ? theme.colorScheme.primary
          : widget.enabled
          ? theme.colorScheme.onSurface
          : theme.colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}

class _ReaderPercentageDialog extends StatefulWidget {
  const _ReaderPercentageDialog({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.onDraft,
    this.preview,
  });

  final String title;
  final int value, min, max;
  final ValueChanged<int?> onDraft;
  final Widget Function(BuildContext, double)? preview;

  @override
  State<_ReaderPercentageDialog> createState() =>
      _ReaderPercentageDialogState();
}

class _ReaderPercentageDialogState extends State<_ReaderPercentageDialog> {
  late final _input = TextEditingController.fromValue(
    TextEditingValue(
      text: widget.value.toString(),
      selection: TextSelection(
        baseOffset: 0,
        extentOffset: widget.value.toString().length,
      ),
    ),
  );
  final _focus = FocusNode();
  final _fieldKey = GlobalKey();
  int? _draft;
  bool _invalid = false, _closing = false;

  int? _readPercentage() {
    final normalized = _input.text
        .trim()
        .replaceAll('％', '%')
        .replaceAllMapped(
          RegExp(r'[０-９]'),
          (match) => String.fromCharCode(match[0]!.codeUnitAt(0) - 0xfee0),
        );
    final digits = RegExp(r'^([0-9]+)\s*%?$').firstMatch(normalized)?[1];
    final value = int.tryParse(digits ?? '');
    if (value == null || value < widget.min || value > widget.max) return null;
    return value;
  }

  void _close([int? value]) {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop(value);
  }

  void _confirm() {
    final value = _readPercentage();
    if (value == null) {
      setState(() => _invalid = true);
      _focus.requestFocus();
      return;
    }
    _close(value);
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final media = MediaQuery.of(context);
    final viewportHeight = media.size.height - media.viewInsets.vertical;
    final compact = viewportHeight < 250 + 55 * (media.textScaler.scale(1) - 1);
    final title = t.reader.editSliderPercentage(title: widget.title);
    final field = CallbackShortcuts(
      key: _fieldKey,
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): _confirm,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _confirm,
      },
      child: TextField(
        key: const ValueKey('reader.slider-percent.input'),
        controller: _input,
        focusNode: _focus,
        autofocus: true,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        textAlign: TextAlign.end,
        decoration: InputDecoration(
          suffixText: '%',
          errorText: _invalid
              ? t.reader.sliderPercentageRange(min: widget.min, max: widget.max)
              : null,
          errorMaxLines: 3,
        ),
        onEditingComplete: _confirm,
        onChanged: (_) {
          if (_closing || ModalRoute.of(context)?.isCurrent != true) return;
          final value = _readPercentage();
          setState(() {
            _draft = value;
            if (value != null) _invalid = false;
          });
          widget.onDraft(value);
        },
      ),
    );
    final preview = widget.preview?.call(
      context,
      (_draft ?? widget.value).toDouble(),
    );
    final actions = <Widget>[
      TextButton(onPressed: _close, child: Text(t.common.cancel)),
      FilledButton(onPressed: _confirm, child: Text(t.common.confirm)),
    ];
    return CallbackShortcuts(
      key: const ValueKey('reader.slider-percent.dialog'),
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
      child: compact
          ? TaskDialogSurface(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        namesRoute: true,
                        child: Text(title, style: theme.textTheme.titleMedium),
                      ),
                      const SizedBox(height: 8),
                      field,
                      const SizedBox(height: 8),
                      OverflowBar(
                        alignment: MainAxisAlignment.end,
                        spacing: 8,
                        children: actions,
                      ),
                      if (preview != null) ...[
                        const SizedBox(height: 8),
                        preview,
                      ],
                    ],
                  ),
                ),
              ),
            )
          : TaskDialog(
              title: title,
              width: 320,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (preview != null) ...[preview, const SizedBox(height: 8)],
                  field,
                  const SizedBox(height: 12),
                ],
              ),
              actions: actions,
            ),
    );
  }
}

class _SettingsTickTrack extends RoundedRectSliderTrackShape {
  const _SettingsTickTrack(this.divisions);

  final int divisions;

  @override
  bool operator ==(Object other) =>
      other is _SettingsTickTrack && other.divisions == divisions;

  @override
  int get hashCode => divisions.hashCode;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
      additionalActiveTrackHeight: additionalActiveTrackHeight,
    );
    final track = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
    ).deflate((sliderTheme.trackHeight ?? 0) / 2);
    if (track.width <= 0) return;
    // Dense ranges show evenly spaced marks on real stops. The Slider
    // still handles every step, including steps between major marks.
    final intervals = (track.width / 14).floor().clamp(
      1,
      math.min(divisions, 24),
    );
    final active = Color.lerp(
      sliderTheme.disabledActiveTickMarkColor,
      sliderTheme.activeTickMarkColor,
      enableAnimation.value,
    )!;
    final inactive = Color.lerp(
      sliderTheme.disabledInactiveTickMarkColor,
      sliderTheme.inactiveTickMarkColor,
      enableAnimation.value,
    )!;
    final mark = Paint();
    for (var i = 0; i <= intervals; i++) {
      final fraction = (i * divisions / intervals).round() / divisions;
      final x = track.left + fraction * track.width;
      final isActive = textDirection == TextDirection.ltr
          ? x <= thumbCenter.dx
          : x >= thumbCenter.dx;
      mark.color = isActive ? active : inactive;
      context.canvas.drawCircle(Offset(x, track.center.dy), 1, mark);
    }
  }
}
