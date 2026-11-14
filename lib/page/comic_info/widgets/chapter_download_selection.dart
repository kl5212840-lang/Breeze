import 'package:zephyr/page/download/models/download_chapter.dart';

/// Ordinals belong to this immutable, currently displayed catalog snapshot.
/// Plugin order/group labels never become chapter identities or selection keys.
class ChapterDownloadSelection {
  ChapterDownloadSelection(Iterable<DownloadChapter> chapters)
    : chapters = List.unmodifiable(chapters);
  final List<DownloadChapter> chapters;
  final selectedIds = <String>{};
  List<DownloadChapter> get selected {
    final emitted = <String>{};
    return [
      for (final chapter in chapters)
        if (selectedIds.contains(chapter.id) && emitted.add(chapter.id))
          chapter,
    ];
  }

  void toggle(String id, {required Set<String> eligible}) {
    if (!eligible.contains(id)) return;
    if (!selectedIds.remove(id)) selectedIds.add(id);
  }

  void selectAll(Iterable<DownloadChapter> scope, Set<String> eligible) {
    selectedIds.addAll(
      scope.map((chapter) => chapter.id).where(eligible.contains),
    );
  }

  void deselectAll(Iterable<DownloadChapter> scope, Set<String> eligible) {
    selectedIds.removeAll(
      scope.map((chapter) => chapter.id).where(eligible.contains),
    );
  }

  void clear() => selectedIds.clear();
  void retainEligible(Set<String> eligible) => selectedIds.retainAll(eligible);
  bool applyRange(String from, String to, {required Set<String> eligible}) {
    final first = int.tryParse(from.trim()), last = int.tryParse(to.trim());
    if (first == null ||
        last == null ||
        first < 1 ||
        last < first ||
        last > chapters.length)
      return false;
    selectedIds.addAll([
      for (var index = first - 1; index < last; index++)
        if (eligible.contains(chapters[index].id)) chapters[index].id,
    ]);
    return true;
  }
}
