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
    final runSpacings = isDesktop ? 5.0 : 8.0;
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
                      height: 48,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: chips.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, index) => Center(child: chips[index]),
                      ),
                    )
                  : Wrap(spacing: 10, runSpacing: runSpacings, children: chips),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: textColor),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: textColor)),
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
          child: AnimatedContainer(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: _hovering ? primary.withValues(alpha: 0.08) : background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: primary.withValues(alpha: _hovering ? 0.9 : 0.55),
              ),
              boxShadow: [
                BoxShadow(
                  color: context.textColor.withValues(
                    alpha: _hovering ? 0.28 : 0.18,
                  ),
                  blurRadius: _hovering ? 10 : 6,
                  offset: Offset(0, _hovering ? 3 : 2),
                  spreadRadius: _hovering ? 0.5 : 0,
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              widget.label,
              style: TextStyle(fontSize: 12, color: primary),
            ),
          ),
        ),
      ),
    );
  }
}
