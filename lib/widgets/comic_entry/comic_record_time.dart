import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/comic_entry/models/unified_comic_list_item.dart';
import 'package:zephyr/widgets/collection_record_time.dart';

/// Display dates without exposing ISO transport syntax. Date-only values keep
/// their calendar date; explicit instants use the device's local clock.
String formatComicRecordTimestamp(String value, {bool epochSeconds = false}) {
  final raw = value.trim();
  if (raw.isEmpty || raw == '0') return '';
  if (epochSeconds && RegExp(r'^\d+$').hasMatch(raw)) {
    if (raw.length != 10) return '';
    return formatComicRecordTimestamp(
      DateTime.fromMillisecondsSinceEpoch(
        int.parse(raw) * 1000,
        isUtc: true,
      ).toIso8601String(),
    );
  }
  final date = DateTime.tryParse(raw);
  if (date != null &&
      (date.toUtc().millisecondsSinceEpoch == 0 ||
          date.year == 1970 &&
              date.month == 1 &&
              date.day == 1 &&
              date.hour == 0 &&
              date.minute == 0 &&
              date.second == 0 &&
              date.millisecond == 0)) {
    return '';
  }
  if (date == null || !RegExp(r'^\d{4}-\d{2}-\d{2}(?:[T ]|$)').hasMatch(raw)) {
    return raw;
  }
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) return raw;
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

String comicLastReadTimestamp(UnifiedComicListItem item) {
  final raw = item.raw['lastReadAt'];
  if (raw is! String || DateTime.tryParse(raw) == null) return '';
  return formatComicRecordTimestamp(raw);
}

/// A reading event has its own readable line; descriptive metadata cannot
/// truncate or absorb it. Unknown legacy reading time remains absent.
class ComicLastReadLine extends StatelessWidget {
  const ComicLastReadLine({super.key, required this.item});
  final UnifiedComicListItem item;
  @override
  Widget build(BuildContext context) {
    final time = comicLastReadTimestamp(item);
    if (time.isEmpty) return const SizedBox.shrink();
    return Text(
      t.comicEntry.lastReadAt(time: time),
      key: ValueKey('comic-last-read:${item.source}:${item.id}'),
      softWrap: true,
      style: collectionRecordTimeStyle(context),
    );
  }
}
