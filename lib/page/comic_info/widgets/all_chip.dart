// 通用的标签/分类 Widget
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart';
import 'package:zephyr/page/comic_info/models/comic_info_action.dart';
import 'package:zephyr/platform/desktop/window_logic.dart';
import 'package:zephyr/util/context/context_extensions.dart';
import 'package:zephyr/util/text/chinese_convert.dart';
import 'package:zephyr/widgets/toast.dart';

class AllChipWidget extends StatefulWidget {
  final String comicId;
  final ComicInfoMetadata metadata;
  final String from;

  const AllChipWidget({
    super.key,
    required this.comicId,
    required this.metadata,
    required this.from,
  });

  @override
  State<AllChipWidget> createState() => _AllChipWidgetState();
}

class _AllChipWidgetState extends State<AllChipWidget> {
  bool _expanded = false;
  List<ComicInfoActionItem> get items => widget.metadata.value;
  String get title => widget.metadata.name;

  @override
  void didUpdateWidget(covariant AllChipWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comicId != widget.comicId ||
        oldWidget.from != widget.from ||
        oldWidget.metadata.name != widget.metadata.name ||
        !listEquals(oldWidget.metadata.value, widget.metadata.value)) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    const runSpacings = 4.0;
    final rowHeight = _chipRowHeight(context);
    final display = watchChineseDisplayConverter(context);
    final processedTitle = display(processText(title));
    final labels = items
        .map((item) => display(processText(item.name)))
        .toList();
    final chips = items
        .map(
          (item) => _ClickableChip(
            label: display(processText(item.name)),
            onTap: () => _onTap(item),
            onLongPress: () {
              final copyText = item.onLongPress?.trim().isNotEmpty == true
                  ? item.onLongPress!.trim()
                  : processText(item.name);
              Clipboard.setData(ClipboardData(text: copyText));
              showSuccessToast(
                t.comicInfo.copiedToClipboard(name: display(item.name)),
              );
            },
          ),
        )
        .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: runSpacings),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LabelChip(label: processedTitle),
            const SizedBox(width: 10),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Measure the full rail before reserving the disclosure. A
                  // disclosure must not create the overflow that justifies it.
                  final contentWidth =
                      labels.fold<double>(
                        0,
                        (width, label) => width + _chipWidth(context, label),
                      ) +
                      (chips.length - 1).clamp(0, chips.length) * 8;
                  final overflowing = contentWidth > constraints.maxWidth + 0.5;
                  final expanded = overflowing && _expanded;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, rail) => overflowing && !expanded
                              ? SizedBox(
                                  height: rowHeight,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: chips.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(width: 8),
                                    itemBuilder: (_, index) =>
                                        Center(child: chips[index]),
                                  ),
                                )
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: runSpacings,
                                  children: [
                                    for (final chip in chips)
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: rail.maxWidth,
                                        ),
                                        child: chip,
                                      ),
                                  ],
                                ),
                        ),
                      ),
                      if (overflowing)
                        TextButton(
                          key: const ValueKey('comic-metadata.expand'),
                          onPressed: () =>
                              setState(() => _expanded = !expanded),
                          child: Text(expanded ? '收起' : '展开'),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  String processText(String text) {
    return text.replaceAll('\r', '').trim();
  }

  void _onTap(ComicInfoActionItem item) {
    if (item.onTap.isNotEmpty) {
      handleComicInfoAction(context, item.onTap, fallbackPluginId: widget.from);
    }
  }
}

double _chipWidth(BuildContext context, String label) {
  final painter = TextPainter(
    text: TextSpan(
      text: label,
      style: DefaultTextStyle.of(
        context,
      ).style.merge(const TextStyle(fontSize: 12)),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    locale: Localizations.maybeLocaleOf(context),
  )..layout();
  final width = (painter.width + 22).clamp(44.0, double.infinity);
  painter.dispose();
  return width;
}

class _LabelChip extends StatelessWidget {
  final String label;

  const _LabelChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final textColor = context.textColor;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: context.backgroundColor,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: textColor.withValues(alpha: 0.7)),
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: textColor),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClickableChip extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ClickableChip({
    required this.label,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_ClickableChip> createState() => _ClickableChipState();
}

class _ClickableChipState extends State<_ClickableChip> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final primary = context.theme.colorScheme.primary;
    final background = context.backgroundColor;
    final hovering = isDesktop && _hovering;

    return Semantics(
      button: true,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: AnimatedContainer(
                constraints: const BoxConstraints(minHeight: 36),
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: hovering
                      ? primary.withValues(alpha: 0.08)
                      : background,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: primary.withValues(alpha: hovering ? 0.9 : 0.55),
                  ),
                ),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: primary),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Preserve the one-line collapsed tag rail while allowing Dynamic Type to grow.
double _chipRowHeight(BuildContext context) {
  final painter = TextPainter(
    text: const TextSpan(text: '标签', style: TextStyle(fontSize: 12)),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final height = (painter.height + 16).clamp(44.0, double.infinity);
  painter.dispose();
  return height;
}
