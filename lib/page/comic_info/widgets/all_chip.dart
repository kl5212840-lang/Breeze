// 通用的标签/分类 Widget
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart';
import 'package:zephyr/page/comic_info/models/comic_info_action.dart';
import 'package:zephyr/platform/desktop/window_logic.dart';
import 'package:zephyr/type/pipe.dart';
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
  Widget build(BuildContext context) {
    const runSpacings = 4.0;
    final processedTitle = processText(title).let(convertChineseForDisplay);
    final isTagGroup =
        widget.metadata.type == 'tags' ||
        processedTitle.contains('标签') ||
        processedTitle.contains('標籤');
    final chips = items
        .map(
          (item) => _ClickableChip(
            label: processText(item.name).let(convertChineseForDisplay),
            onTap: () => _onTap(item),
            onLongPress: () {
              final copyText = item.onLongPress?.trim().isNotEmpty == true
                  ? item.onLongPress!.trim()
                  : processText(item.name);
              Clipboard.setData(ClipboardData(text: copyText));
              showSuccessToast(
                t.comicInfo.copiedToClipboard(
                  name: item.name.let(convertChineseForDisplay),
                ),
              );
            },
          ),
        )
        .toList();
    final canCollapse = isTagGroup || chips.length > 4;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: runSpacings),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LabelChip(label: processedTitle),
            const SizedBox(width: 10),
            Expanded(
              child: canCollapse && !_expanded
                  ? SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: chips.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, index) => Center(child: chips[index]),
                      ),
                    )
                  : Wrap(spacing: 8, runSpacing: runSpacings, children: chips),
            ),
            if (canCollapse && chips.length > 1)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? '收起' : '展开'),
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

class _LabelChip extends StatelessWidget {
  final String label;

  const _LabelChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final textColor = context.textColor;

    return SizedBox(
      height: 44,
      child: Center(
        widthFactor: 1,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: context.backgroundColor,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: textColor.withValues(alpha: 0.7)),
          ),
          child: Center(
            widthFactor: 1,
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
          child: SizedBox(
            height: 44,
            child: Center(
              widthFactor: 1,
              child: AnimatedContainer(
                height: 36,
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 11),
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
