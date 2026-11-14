import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/cubit/comic_read_preference_cubit.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/util/context/context_extensions.dart';
import 'package:zephyr/util/debouncer.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_control_colors.dart';
import 'package:zephyr/widgets/breeze_switch.dart';

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
    final colorScheme = context.theme.colorScheme;

    final perComicAvailable =
        source.trim().isNotEmpty && comicId.trim().isNotEmpty;
    final tabLength = perComicAvailable ? 4 : 3;

    final breeze = !AppInterfaceStyleScope.usesSystem(context);
    final nativeChoices =
        !breeze && !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    return Material(
      color: breeze ? colorScheme.surfaceContainerLow : colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: breeze ? 8 : 16,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.24),
      borderRadius: BorderRadius.circular(24),
      // Rounded paint is enough here. A native choice must not inherit the
      // card's curved clip when Flutter slices overlays during transitions.
      clipBehavior: nativeChoices ? Clip.none : Clip.antiAlias,
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

class _SettingsSliderCard extends StatelessWidget {
  final String title;
  final int value;
  final int min;
  final int max;
  final int divisions;
  final String suffix;
  final bool enabled;
  final ValueChanged<int> onChanged;

  const _SettingsSliderCard({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.suffix,
    this.enabled = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(title, style: context.theme.textTheme.bodyMedium),
              Text(
                '$value $suffix',
                style: context.theme.textTheme.bodyMedium?.copyWith(
                  color: enabled
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Slider(
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: divisions,
            value: value.clamp(min, max).toDouble(),
            label: '$value$suffix',
            onChanged: !enabled
                ? null
                : (newValue) {
                    final nextValue = newValue.round().clamp(min, max);
                    if (nextValue != value) {
                      HapticFeedback.selectionClick();
                      onChanged(nextValue);
                    }
                  },
          ),
        ],
      ),
    );
  }
}
