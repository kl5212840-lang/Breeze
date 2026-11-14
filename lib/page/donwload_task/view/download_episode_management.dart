import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';

const downloadWorkEpisodeRangeSize = 25;

enum DownloadWorkSection { transferring, pending, downloaded }

List<({int index, DownloadWorkSection? heading})> downloadWorkSectionRows(
  int start,
  int end,
  DownloadWorkSection Function(int) sectionAt,
) {
  final rows = <({int index, DownloadWorkSection? heading})>[];
  DownloadWorkSection? previous;
  for (var index = start; index < end; index++) {
    final section = sectionAt(index);
    rows.add((index: index, heading: section == previous ? null : section));
    previous = section;
  }
  return rows;
}

class DownloadWorkSectionHeading extends StatelessWidget {
  const DownloadWorkSectionHeading(this.section, {super.key});
  final DownloadWorkSection section;

  @override
  Widget build(BuildContext context) {
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    final text = switch (section) {
      DownloadWorkSection.transferring => chinese ? '正在下载' : 'Downloading',
      DownloadWorkSection.pending => chinese ? '待处理' : 'Pending',
      DownloadWorkSection.downloaded => chinese ? '已下载' : 'Downloaded',
    };
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(2, 12, 2, 6),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Keeps the chosen range on the same chapter or episode across a refresh.
class DownloadEpisodeRangeSelection {
  DownloadEpisodeRangeSelection({this.pageSize = downloadWorkEpisodeRangeSize})
    : assert(pageSize > 0);

  final int pageSize;
  Object? _anchor;
  int _index = 0;

  ({int index, int start, int end}) resolve(List<Object> keys) {
    if (keys.isEmpty) {
      _anchor = null;
      _index = 0;
      return (index: 0, start: 0, end: 0);
    }
    final anchor = _anchor;
    final anchorIndex = anchor == null ? -1 : keys.indexOf(anchor);
    final lastIndex = (keys.length - 1) ~/ pageSize;
    final index = anchorIndex < 0
        ? _index.clamp(0, lastIndex)
        : anchorIndex ~/ pageSize;
    final start = index * pageSize;
    // Stay on the first page until the user chooses another range, even
    // when its first active item completes and moves down the list.
    if (index == 0) {
      _anchor = null;
    } else if (anchorIndex < 0) {
      _anchor = keys[start];
    }
    _index = index;
    return (
      index: index,
      start: start,
      end: (start + pageSize).clamp(start, keys.length),
    );
  }

  void select(List<Object> keys, int index) {
    final start = index * pageSize;
    if (start < 0 || start >= keys.length) return;
    _anchor = index == 0 ? null : keys[start];
    _index = index;
  }
}

/// Selection is tied to a visible resource version, not just an episode ID.
class DownloadEpisodeSelection {
  bool active = false;
  final _selected = <String, Object>{};

  bool contains(String key, Object version) => _selected[key] == version;

  void start([String? key, Object? version]) {
    active = true;
    _selected.clear();
    if (key != null && version != null) _selected[key] = version;
  }

  void close() {
    active = false;
    _selected.clear();
  }

  void clearKeys(Iterable<String> keys) => keys.forEach(_selected.remove);

  void toggle(String key, Object version) {
    if (contains(key, version)) {
      _selected.remove(key);
    } else {
      _selected[key] = version;
    }
  }

  Set<String> matching(Map<String, Object> candidates) => {
    for (final entry in candidates.entries)
      if (contains(entry.key, entry.value)) entry.key,
  };

  void toggleAll(Map<String, Object> candidates) {
    final all = matching(candidates).length == candidates.length;
    _selected.clear();
    if (!all) _selected.addAll(candidates);
  }
}

class DownloadEpisodeManagementBar extends StatelessWidget {
  const DownloadEpisodeManagementBar({
    super.key,
    required this.count,
    required this.allSelected,
    required this.onToggleAll,
    required this.onDelete,
    this.showDelete = true,
    this.pauseCount,
    this.resumeCount,
    this.onPause,
    this.onResume,
  });

  final int count;
  final bool allSelected;
  final VoidCallback? onToggleAll, onDelete;
  final bool showDelete;
  final int? pauseCount, resumeCount;
  final VoidCallback? onPause, onResume;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final chinese = LocaleSettings.currentLocale.languageCode == 'zh';
    final pause = chinese ? '暂停' : 'Pause';
    final resume = chinese ? '继续' : 'Resume';
    return Material(
      color: colors.surfaceContainerLow,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Center(
          heightFactor: 1,
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              TextButton(
                key: const ValueKey('download-episodes-select-all'),
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                onPressed: onToggleAll,
                child: Text(
                  allSelected ? t.bookshelf.deselectAll : t.common.selectAll,
                ),
              ),
              Text(t.bookshelf.selectedCount(count: count)),
              if (pauseCount case final selected?)
                TextButton.icon(
                  key: const ValueKey('download-episodes-pause'),
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  onPressed: onPause,
                  icon: const Icon(Icons.pause_rounded),
                  label: Text(selected > 0 ? '$pause $selected' : pause),
                ),
              if (resumeCount case final selected?)
                TextButton.icon(
                  key: const ValueKey('download-episodes-resume'),
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  onPressed: onResume,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(selected > 0 ? '$resume $selected' : resume),
                ),
              if (showDelete)
                TextButton.icon(
                  key: const ValueKey('download-episodes-delete'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    foregroundColor: colors.error,
                  ),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(t.common.delete),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
