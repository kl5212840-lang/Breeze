import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/comic_read/json/common_ep_info_json/common_ep_info_json.dart';
import 'package:zephyr/page/comic_read/model/seamless_transition_state.dart';
import 'package:zephyr/page/comic_read/widgets/transition/chapter_transition_card.dart';

/// 阅读模式条目类型：图片或章节过渡卡片。
enum ReadModeEntryType { image, transition }

/// 列/行阅读模式共用的条目数据模型。
class ReadModeEntry {
  const ReadModeEntry._({
    required this.type,
    required this.doc,
    required this.chapterId,
    required this.chapterOrder,
    required this.chapterTitle,
    required this.chapterPageIndex,
    required this.transitionStatus,
    this.previousChapterOrder,
    this.previousChapterTitle,
  });

  const ReadModeEntry.image({
    required Doc doc,
    required String chapterId,
    required int chapterOrder,
    required String chapterTitle,
    required int chapterPageIndex,
  }) : this._(
         type: ReadModeEntryType.image,
         doc: doc,
         chapterId: chapterId,
         chapterOrder: chapterOrder,
         chapterTitle: chapterTitle,
         chapterPageIndex: chapterPageIndex,
         transitionStatus: SeamlessTransitionStatus.ready,
       );

  const ReadModeEntry.transition({
    required int chapterOrder,
    required String chapterTitle,
    required int previousChapterOrder,
    required String previousChapterTitle,
    required SeamlessTransitionStatus transitionStatus,
  }) : this._(
         type: ReadModeEntryType.transition,
         doc: null,
         chapterId: null,
         chapterOrder: chapterOrder,
         chapterTitle: chapterTitle,
         chapterPageIndex: null,
         previousChapterOrder: previousChapterOrder,
         previousChapterTitle: previousChapterTitle,
         transitionStatus: transitionStatus,
       );

  final ReadModeEntryType type;
  final Doc? doc;
  final String? chapterId;
  final int chapterOrder;
  final String chapterTitle;
  final int? chapterPageIndex;
  final int? previousChapterOrder;
  final String? previousChapterTitle;
  final SeamlessTransitionStatus transitionStatus;
}

/// 双页槽位中的单个条目包装。
class ReadModeSlotItem {
  const ReadModeSlotItem({required this.entryIndex, required this.entry});

  final int entryIndex;
  final ReadModeEntry entry;
}

/// 列/行双页模式共用的显示槽位：过渡卡片或左右两张图片。
class ReadModeDoublePageSlot {
  const ReadModeDoublePageSlot._({
    required this.transition,
    required this.left,
    required this.right,
  });

  const ReadModeDoublePageSlot.transition(ReadModeSlotItem transition)
    : this._(transition: transition, left: null, right: null);

  const ReadModeDoublePageSlot.images({
    ReadModeSlotItem? left,
    ReadModeSlotItem? right,
  }) : this._(transition: null, left: left, right: right);

  final ReadModeSlotItem? transition;
  final ReadModeSlotItem? left;
  final ReadModeSlotItem? right;
}

/// 把 [entries] 按顺序合并为双页显示槽位。
///
/// 规则：
/// - 遇到过渡条目单独占一个槽位；
/// - 普通图片两两合并为一个槽位（左 + 可选右），若下一条是过渡则右侧为空；
/// - 不跨章拼双页。启用 [insertLeadingBlank] 时每章以「空白 | 首页」开始。
List<ReadModeDoublePageSlot> buildReadModeDoublePageSlots(
  List<ReadModeEntry> entries, {
  bool insertLeadingBlank = false,
}) {
  final slots = <ReadModeDoublePageSlot>[];
  forEachReadModeSlot(
    entries: entries,
    enableDoublePage: true,
    insertLeadingBlank: insertLeadingBlank,
    onSlot: (_, primary, secondary) {
      final entry = entries[primary];
      final first = ReadModeSlotItem(entryIndex: primary, entry: entry);
      if (entry.type == ReadModeEntryType.transition) {
        slots.add(ReadModeDoublePageSlot.transition(first));
      } else if (insertLeadingBlank && entry.chapterPageIndex == 0) {
        slots.add(ReadModeDoublePageSlot.images(right: first));
      } else {
        slots.add(
          ReadModeDoublePageSlot.images(
            left: first,
            right: secondary == null
                ? null
                : ReadModeSlotItem(
                    entryIndex: secondary,
                    entry: entries[secondary],
                  ),
          ),
        );
      }
    },
  );
  return slots;
}

/// The chapter is the pairing boundary even when no transition is shown.
void forEachReadModeSlot({
  required List<ReadModeEntry> entries,
  required bool enableDoublePage,
  required bool insertLeadingBlank,
  required void Function(int slot, int primary, int? secondary) onSlot,
}) {
  var index = 0;
  var slot = 0;
  while (index < entries.length) {
    final primary = index++;
    final entry = entries[primary];
    int? secondary;
    if (enableDoublePage &&
        entry.type == ReadModeEntryType.image &&
        !(insertLeadingBlank && entry.chapterPageIndex == 0) &&
        index < entries.length &&
        entries[index].type == ReadModeEntryType.image &&
        entries[index].chapterOrder == entry.chapterOrder) {
      secondary = index++;
    }
    onSlot(slot++, primary, secondary);
  }
}

/// 为 [entry] 构建一个居中的过渡卡片容器。
///
/// [containerWidth] 为外层容器宽度；[fixedCardSize] 非空时会把卡片约束为固定
/// 尺寸（列模式正方形），否则卡片在水平方向内边距中自适应。
Widget buildReadModeTransitionItem({
  required ReadModeEntry entry,
  required Color backgroundColor,
  required VoidCallback onTap,
  required double containerWidth,
  Size? fixedCardSize,
  EdgeInsets? outerPadding,
  EdgeInsets cardPadding = const EdgeInsets.symmetric(horizontal: 24),
  double minHeight = 320,
  double lineSpacing = 34,
}) {
  Widget card = ChapterTransitionCard(
    previousChapterOrder: entry.previousChapterOrder,
    previousChapterTitle: entry.previousChapterTitle,
    nextChapterOrder: entry.chapterOrder,
    nextChapterTitle: entry.chapterTitle,
    transitionStatus: entry.transitionStatus,
    backgroundColor: backgroundColor,
    minHeight: minHeight,
    padding: cardPadding,
    lineSpacing: lineSpacing,
    onTap: onTap,
  );

  if (fixedCardSize != null) {
    card = SizedBox(
      width: fixedCardSize.width,
      height: fixedCardSize.height,
      child: card,
    );
  }

  return Container(
    color: backgroundColor,
    width: containerWidth,
    alignment: Alignment.center,
    padding: outerPadding,
    child: card,
  );
}
