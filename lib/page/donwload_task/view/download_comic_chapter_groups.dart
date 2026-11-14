import 'dart:math' as math;

import 'package:zephyr/page/comic_info/method/chapter_group.dart';
import 'package:zephyr/page/download/models/unified_comic_download.dart';

const _groupSize = 30;

class DownloadComicChapterGroup {
  DownloadComicChapterGroup._(this.volume, int offset, this.chapters)
    : key = '${volume.length}:$volume:$offset';

  final String key;
  final String volume;
  final List<UnifiedComicDownloadStoredChapter> chapters;

  String title({required String fallback}) {
    final names = chapters.map((chapter) => chapter.name.trim());
    final start = names.firstWhere((name) => name.isNotEmpty, orElse: () => '');
    final end = names.lastWhere((name) => name.isNotEmpty, orElse: () => '');
    final range = start == end ? start : '$start–$end';
    final realVolume = !const {
      '',
      'default',
      '默认',
      '默認',
    }.contains(volume.toLowerCase());
    return [
      if (range.isNotEmpty) range,
      if (realVolume && volume != range) volume,
      if (range.isEmpty && !realVolume) fallback,
    ].join(' · ');
  }

  String subtitle({required bool chinese}) {
    final count = chapters.length;
    final downloaded = chinese
        ? '已下载$count话'
        : count == 1
        ? '1 downloaded chapter'
        : '$count downloaded chapters';
    return _hasNumericChapterGap(chapters)
        ? '$downloaded · ${chinese ? '有缺话' : 'gaps'}'
        : downloaded;
  }
}

List<DownloadComicChapterGroup> groupDownloadedComicChapters(
  List<UnifiedComicDownloadStoredChapter> chapters,
) {
  final indexed = chapters.asMap().entries.toList()
    ..sort((left, right) {
      final order = left.value.order.compareTo(right.value.order);
      return order == 0 ? left.key.compareTo(right.key) : order;
    });
  final volumes = groupChaptersByTitle([
    for (final entry in indexed) entry.value,
  ], (chapter) => resolveChapterGroupTitle(groupTitle: chapter.groupTitle));

  return [
    for (final volume in volumes)
      for (var start = 0; start < volume.items.length; start += _groupSize)
        DownloadComicChapterGroup._(
          volume.title,
          start,
          List.unmodifiable(
            volume.items.getRange(
              start,
              math.min(start + _groupSize, volume.items.length),
            ),
          ),
        ),
  ];
}

final _simpleChapterTitle = RegExp(
  r'^(第\s*|Chapter\s+)?([0-9]+)(\s*[话話章回])?$',
  caseSensitive: false,
);

bool _hasNumericChapterGap(List<UnifiedComicDownloadStoredChapter> chapters) {
  if (chapters.length < 2) return false;

  final first = _simpleChapterTitle.firstMatch(chapters.first.name.trim());
  if (first == null) return false;
  final firstNumber = int.tryParse(first[2]!);
  if (firstNumber == null) return false;
  var previous = firstNumber;
  var hasGap = false;

  for (var index = 1; index < chapters.length; index++) {
    final match = _simpleChapterTitle.firstMatch(chapters[index].name.trim());
    final number = match == null ? null : int.tryParse(match[2]!);
    if (match == null ||
        number == null ||
        match[1]?.trim().toLowerCase() != first[1]?.trim().toLowerCase() ||
        match[3]?.trim() != first[3]?.trim() ||
        number <= previous) {
      return false;
    }
    if (number - previous > 1) hasGap = true;
    previous = number;
  }

  return hasGap;
}
