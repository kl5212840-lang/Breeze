import 'dart:async';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:zephyr/page/bookshelf/service/shelf_facet_preferences.dart';
import 'package:zephyr/page/bookshelf/widgets/shelf_tag_pin.dart';
import 'package:zephyr/page/bookshelf/widgets/facet_reorder_motion.dart';
import 'package:zephyr/page/bookshelf/widgets/facet_filter_body.dart';
import 'package:zephyr/page/bookshelf/widgets/facet_option_list.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/search/widget/search_field_decoration.dart';

const downloadFilterGroups = [
  'category',
  'tags',
  'author',
  'quality',
  'status',
  'duration',
  'year',
  'area',
  'language',
];

Map<String, String> downloadFilterGroupLabels() => {
  'category': t.bookshelf.facets.category,
  'tags': t.bookshelf.facets.tags,
  'author': t.bookshelf.facets.author,
  'quality': t.download.versionFilter,
  'status': t.download.statusFilter,
  'duration': t.download.durationFilter,
  'year': t.bookshelf.facets.year,
  'area': t.bookshelf.facets.area,
  'language': t.bookshelf.facets.language,
};

String downloadFilterValueLabel(String group, String value) => switch ((
  group,
  value,
)) {
  ('status', 'saved') || ('status', 'completed') => t.download.filterCompleted,
  ('status', 'queued') || ('status', 'pending') => t.download.filterQueued,
  ('status', 'preparing') => t.download.filterPreparing,
  ('status', 'downloading') => t.download.filterDownloading,
  ('status', 'failed') => t.download.filterFailed,
  ('status', 'cancelled') => t.download.filterCancelled,
  ('status', 'paused') => t.download.filterPaused,
  ('duration', 'short') => t.download.durationShort,
  ('duration', 'medium') => t.download.durationMedium,
  ('duration', 'long') => t.download.durationLong,
  ('duration', 'hour') => t.download.durationHour,
  _ => value,
};

List<String> downloadFilterOrderedValues(
  String group,
  Iterable<String> values,
) {
  final order = switch (group) {
    'duration' => const ['short', 'medium', 'long', 'hour'],
    'status' => const [
      'queued',
      'pending',
      'preparing',
      'downloading',
      'paused',
      'failed',
      'cancelled',
      'saved',
      'completed',
    ],
    _ => const <String>[],
  };
  int rank(String value) {
    final index = order.indexOf(value);
    return index < 0 ? order.length : index;
  }

  return values.toSet().toList()..sort((a, b) {
    final compared = rank(a).compareTo(rank(b));
    return compared != 0 ? compared : a.compareTo(b);
  });
}

// Download metadata is already public raw values; do not interpret a plugin's
// literal value as the bookshelf's synthetic missing-metadata sentinel.
bool downloadFacetMatches(
  ShelfFacetEntry entry,
  ShelfFacetSelection selection,
) {
  for (final group in downloadFilterGroups) {
    final selected = selection.values[group] ?? const <String>{};
    if (selected.isNotEmpty &&
        !selected.any((value) => entry.fields[group]?.contains(value) == true))
      return false;
  }
  return true;
}

Future<ShelfFacetSelection?> showDownloadFilterSheet(
  BuildContext context, {
  required List<ShelfFacetEntry> entries,
  required ShelfFacetSelection initial,
  String preferenceKey = 'download',
  bool initialSizeOrder = false,
  ValueChanged<bool>? onApplySizeOrder,
}) => showVideoTaskSheet<ShelfFacetSelection>(
  context: context,
  useRootNavigator: true,
  builder: (_) => DownloadFilterSheet(
    entries: entries,
    initial: initial,
    preferenceKey: preferenceKey,
    initialSizeOrder: initialSizeOrder,
    onApplySizeOrder: onApplySizeOrder,
  ),
);

/// A snapshot-scoped draft. Only Apply returns it to the download center.
class DownloadFilterSheet extends StatefulWidget {
  const DownloadFilterSheet({
    super.key,
    required this.entries,
    required this.initial,
    this.preferenceKey = 'download',
    this.initialSizeOrder = false,
    this.onApplySizeOrder,
  });
  final List<ShelfFacetEntry> entries;
  final ShelfFacetSelection initial;
  final String preferenceKey;
  final bool initialSizeOrder;
  final ValueChanged<bool>? onApplySizeOrder;
  @override
  State<DownloadFilterSheet> createState() => _DownloadFilterSheetState();
}

class _DownloadFilterSheetState extends State<DownloadFilterSheet>
    with SingleTickerProviderStateMixin {
  late final _reorder = FacetReorderController(vsync: this);
  late ShelfFacetSelection _draft;
  late bool _sizeOrder;
  final _query = TextEditingController();
  final _pinned = <String, Set<String>>{};
  final _pinErrors = <String, _PinFailure>{};
  bool _pinSaving = false;
  int _pinEpoch = 0;

  // Keep the original key for tags so existing stars carry over unchanged.
  String _pinKey(String group) => group == 'tags'
      ? widget.preferenceKey
      : '${widget.preferenceKey}|facet:$group';

  void _pinsChanged() => unawaited(_loadPins());
  Future<void> _loadPins() async {
    final epoch = ++_pinEpoch;
    final loaded = await Future.wait(
      downloadFilterGroups.map((group) async {
        try {
          return await ShelfFacetPreferences.load(_pinKey(group));
        } catch (_) {
          return null;
        }
      }),
    );
    if (!mounted || epoch != _pinEpoch) return;
    final active = _activeGroup(_availableGroups);
    final activePins = loaded[downloadFilterGroups.indexOf(active)];
    if (activePins != null &&
        !setEquals(activePins, _pinned[active] ?? const <String>{})) {
      _reorder.capture(animate: !MediaQuery.disableAnimationsOf(context));
    }
    setState(() {
      for (var i = 0; i < loaded.length; i++) {
        final group = downloadFilterGroups[i];
        final pins = loaded[i];
        if (pins == null) {
          _pinErrors[group] = _PinFailure.load;
        } else {
          _pinned[group] = pins;
          _pinErrors.remove(group);
        }
      }
    });
  }

  Future<void> _pin(String group, String value) async {
    if (_pinSaving || _pinErrors.containsKey(group)) return;
    setState(() => _pinSaving = true);
    try {
      await ShelfFacetPreferences.toggle(
        _pinKey(group),
        shelfFacetEncodeValue(value),
      );
      await _loadPins();
    } catch (_) {
      if (mounted) setState(() => _pinErrors[group] = _PinFailure.save);
    } finally {
      if (mounted) setState(() => _pinSaving = false);
    }
  }

  String _group = 'tags';
  String _activeGroup(List<String> available) =>
      available.contains(_group) ? _group : available.firstOrNull ?? 'tags';

  List<String> get _availableGroups => downloadFilterGroups
      .where(
        (group) =>
            (_draft.values[group]?.isNotEmpty ?? false) ||
            widget.entries.any(
              (entry) => (entry.fields[group] ?? const <String>{}).any(
                (value) => value.trim().isNotEmpty,
              ),
            ),
      )
      .toList();
  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
    _sizeOrder = widget.initialSizeOrder;
    ShelfFacetPreferences.changes.addListener(_pinsChanged);
    PortablePreferences.changes.addListener(_pinsChanged);
    _pinsChanged();
  }

  @override
  void dispose() {
    _pinEpoch++;
    ShelfFacetPreferences.changes.removeListener(_pinsChanged);
    PortablePreferences.changes.removeListener(_pinsChanged);
    _query.dispose();
    _reorder.dispose();
    super.dispose();
  }

  void _toggle(String group, String value) {
    final values = {
      for (final entry in _draft.values.entries) entry.key: {...entry.value},
    };
    final selected = values.putIfAbsent(group, () => <String>{});
    selected.contains(value) ? selected.remove(value) : selected.add(value);
    setState(() => _draft = _draft.copyWith(values: values));
  }

  @override
  Widget build(BuildContext context) {
    final allLabels = downloadFilterGroupLabels();
    final available = _availableGroups;
    final labels = {for (final group in available) group: allLabels[group]!};
    final group = _activeGroup(available);
    final pins = _pinned[group] ?? const <String>{};
    final pinError = _pinErrors[group];
    final isChinese = Localizations.localeOf(context).languageCode == 'zh';
    final selected = _draft.values[group] ?? const <String>{};
    final rest = _draft.copyWith(values: {..._draft.values}..remove(group));
    final counts = <String, int>{};
    for (final entry in widget.entries) {
      final options = entry.fields[group];
      if (options == null || options.isEmpty) continue;
      final matched = downloadFacetMatches(entry, rest);
      for (final value in options) {
        counts[value] = (counts[value] ?? 0) + (matched ? 1 : 0);
      }
    }
    final ordered = downloadFilterOrderedValues(group, {
      ...counts.keys,
      ...selected,
      ...pins.map(shelfFacetDisplayValue),
    });
    bool isPinned(String value) => pins.contains(shelfFacetEncodeValue(value));
    final values = pins.isEmpty
        ? ordered
        : [...ordered.where(isPinned), ...ordered.where((v) => !isPinned(v))];
    final count = widget.entries
        .where((entry) => downloadFacetMatches(entry, _draft))
        .length;
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.onApplySizeOrder == null
                  ? t.bookshelf.filter
                  : isChinese
                  ? '筛选与排序'
                  : 'Filter and sort',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          TextButton(
            key: const ValueKey('download-filter-reset'),
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            onPressed: () => setState(() {
              _draft = const ShelfFacetSelection();
              _sizeOrder = false;
              _query.clear();
            }),
            child: Text(t.common.reset),
          ),
          IconButton(
            key: const ValueKey('download-filter-cancel'),
            tooltip: t.common.cancel,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
    final search = Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: SearchFieldSurface(
        child: TextField(
          key: const ValueKey('download-filter-search'),
          controller: _query,
          decoration: searchFieldDecoration(
            context,
            hintText: t.bookshelf.facets.search(name: allLabels[group]!),
          ),
        ),
      ),
    );
    final groups = SingleChildScrollView(
      key: const ValueKey('download-filter-groups'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          for (final entry in labels.entries)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                key: ValueKey('download-filter-group-${entry.key}'),
                label: Text(
                  (_draft.values[entry.key]?.isNotEmpty ?? false)
                      ? '${entry.value} · ${_draft.values[entry.key]!.length}'
                      : entry.value,
                ),
                selected: group == entry.key,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onSelected: (_) => setState(() {
                  _group = entry.key;
                  _query.clear();
                }),
              ),
            ),
        ],
      ),
    );
    final footer = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          key: const ValueKey('download-filter-apply'),
          style: FilledButton.styleFrom(minimumSize: const Size(44, 44)),
          onPressed: () {
            widget.onApplySizeOrder?.call(_sizeOrder);
            Navigator.pop(context, _draft.copyWith(applied: true));
          },
          child: Text(
            widget.onApplySizeOrder == null
                ? t.bookshelf.facets.resultTitle(count: count)
                : '${t.common.apply} · ${t.common.itemsCount(count: count)}',
            key: const ValueKey('download-filter-count'),
          ),
        ),
      ),
    );
    return FacetFilterBody(
      header: header,
      controls: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.onApplySizeOrder != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: VideoControlAppearance(
                systemControls: usesNativeSourceChrome(context),
                child: NativeVideoSegmentedControl(
                  key: const ValueKey('download-order'),
                  options: {
                    'default': t.download.defaultDownloadOrder,
                    'size': t.download.largestDownloadsFirst,
                  },
                  selected: _sizeOrder ? 'size' : 'default',
                  onSelected: (value) =>
                      setState(() => _sizeOrder = value == 'size'),
                ),
              ),
            ),
          if (labels.length > 1) groups,
          if (labels.isNotEmpty) search,
          if (pinError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ShelfTagPinError(
                message: group == 'tags'
                    ? switch (pinError) {
                        _PinFailure.load =>
                          t.bookshelf.facets.loadFavoritesFailed,
                        _PinFailure.save =>
                          t.bookshelf.facets.saveFavoritesFailed,
                      }
                    : switch ((pinError, isChinese)) {
                        (_PinFailure.load, true) => '筛选收藏读取失败',
                        (_PinFailure.load, false) =>
                          'Unable to load pinned filters',
                        (_PinFailure.save, true) => '筛选收藏保存失败',
                        (_PinFailure.save, false) =>
                          'Unable to save pinned filters',
                      },
                onRetry: _pinSaving ? null : _pinsChanged,
              ),
            ),
        ],
      ),
      footer: footer,
      scrollKey: const ValueKey('download-filter-options'),
      options: SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: FacetOptionSliver(
          values: values,
          query: _query,
          counts: counts,
          selected: selected,
          onToggle: (value) => _toggle(group, value),
          optionKey: (value) =>
              ValueKey('download-filter-option-$group-$value'),
          label: (value) => downloadFilterValueLabel(group, value),
          reorderController: _reorder,
          trailing: (value) {
            final pinned = isPinned(value);
            final label = downloadFilterValueLabel(group, value);
            return ShelfTagPinButton(
              key: ValueKey(
                group == 'tags'
                    ? 'download-star-$value'
                    : 'download-star-$group-$value',
              ),
              pinned: pinned,
              tooltip: ShelfTagPinButton.optionTooltip(
                context,
                label: label,
                pinned: pinned,
              ),
              onPressed:
                  !_pinSaving &&
                      pinError == null &&
                      _pinned.containsKey(group) &&
                      value.trim().isNotEmpty
                  ? () => _pin(group, value)
                  : null,
            );
          },
          empty: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              labels.isEmpty
                  ? t.bookshelf.facets.emptyMetadata
                  : t.bookshelf.facets.emptyOptions,
            ),
          ),
        ),
      ),
    );
  }
}

enum _PinFailure { load, save }
