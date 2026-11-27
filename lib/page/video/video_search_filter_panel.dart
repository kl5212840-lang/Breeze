import 'package:zephyr/page/bookshelf/widgets/filter_scroll_rail.dart';
import 'package:zephyr/page/bookshelf/widgets/filter_sheet_detents.dart';
import 'package:zephyr/widgets/applied_filter_bar.dart';
import 'package:zephyr/page/bookshelf/widgets/facet_filter_body.dart';
import 'package:zephyr/widgets/native_material_surface.dart';
import 'package:zephyr/widgets/android_glass_plate.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_theme_colors.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/search/widget/search_field_decoration.dart';
import 'package:zephyr/page/video/video_browse_theme.dart';
import 'dart:async';
import 'package:zephyr/widgets/compact_filter_choice.dart';
import 'package:zephyr/widgets/filter_option_favorites.dart';
import 'package:zephyr/widgets/year_filter_picker.dart';
import 'package:zephyr/widgets/selection_choice_grid.dart';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_community_page.dart';
import 'package:zephyr/page/video/video_search_filters.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/page/video/video_site_action_models.dart';

String videoFilterTitle(VideoFilterSection section) => switch (section) {
  VideoFilterSection.genre => t.videoFilters.genre,
  VideoFilterSection.tags => t.videoFilters.tags,
  VideoFilterSection.sort => t.videoFilters.sort,
  VideoFilterSection.date => t.videoFilters.date,
  VideoFilterSection.duration => t.videoFilters.duration,
  VideoFilterSection.query => t.videoFilters.searchMode,
};

class VideoSearchFilterPanel extends StatefulWidget {
  const VideoSearchFilterPanel({
    super.key,
    required this.initial,
    required this.schema,
    required this.readSchema,
    this.source,
    this.initialSection = VideoFilterSection.genre,
    this.sections = VideoFilterSection.values,
    this.structuredLayout = false,
    this.onSchema,
    this.onCancelRead,
  });
  final String? source;
  final VideoSearchFilters initial;
  final VideoFilterSchema schema;
  final VideoFilterSection initialSection;
  final List<VideoFilterSection> sections;
  final bool structuredLayout;
  final Future<VideoSiteResult<VideoFilterSchema>> Function() readSchema;
  final ValueChanged<VideoFilterSchema>? onSchema;
  final VoidCallback? onCancelRead;
  @override
  State<VideoSearchFilterPanel> createState() => _VideoSearchFilterPanelState();
}

class _VideoSearchFilterPanelState extends State<VideoSearchFilterPanel>
    with TickerProviderStateMixin {
  FilterOptionFavorites? _favorites;
  late VideoSearchFilters _draft = widget.initial;
  late VideoFilterSchema _schema = widget.schema;
  late TabController _tabs;
  Duration? _tabDuration;
  late final _query = TextEditingController(text: _draft.query);
  final _tagSearch = TextEditingController();
  final _tagSearchKey = GlobalKey();
  final _structuredScroll = ScrollController();
  final _tagOptionsScroll = ScrollController();
  final _sectionScrolls = <VideoFilterSection, ScrollController>{};
  final _structuredOffsets = <int, double>{};
  late final _year = TextEditingController();
  int? _month;
  bool _customDate = false, _loading = false;
  String? _error;
  String? _group;
  bool _selectedOnly = false;
  int? _visibleSection;
  Object? _tagGridKey;
  ({double extent, double width, int rows})? _tagGridMetrics;
  bool get _invalidYear =>
      _customDate &&
      _year.text.isNotEmpty &&
      !RegExp(r'^\d{4}$').hasMatch(_year.text);

  @override
  void initState() {
    super.initState();
    final date = RegExp(
      r'^(?:(\d{4}) 年)?(?:\s*(\d{1,2}) 月)?$',
    ).firstMatch(_draft.date);
    if (_draft.date.isNotEmpty && date != null) {
      _customDate = true;
      _year.text = date[1] ?? '';
      _month = int.tryParse(date[2] ?? '');
    }
    _tagSearch.addListener(_refresh);
    if (widget.source case final source?) {
      final favorites = FilterOptionFavorites(
        'source-filter|$source|hanime-video',
      );
      _favorites = favorites..addListener(_refresh);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final duration = VideoMotion.feedback(context);
    if (_tabDuration == duration) return;
    final index = _tabDuration == null
        ? widget.sections
              .indexOf(widget.initialSection)
              .clamp(0, widget.sections.length - 1)
        : _tabs.index;
    if (_tabDuration != null) _tabs.dispose();
    _tabDuration = duration;
    _tabs = TabController(
      length: widget.sections.length,
      vsync: this,
      initialIndex: index,
      animationDuration: duration,
    )..addListener(_tabChanged);
    _tabChanged();
  }

  @override
  void dispose() {
    widget.onCancelRead?.call();
    _favorites?.dispose();
    _tabs.dispose();
    _query.dispose();
    _tagSearch.dispose();
    _structuredScroll.dispose();
    _tagOptionsScroll.dispose();
    for (final scroll in _sectionScrolls.values) {
      scroll.dispose();
    }
    _year.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _tabChanged() {
    if (_visibleSection != _tabs.index) {
      final previous = _visibleSection, next = _tabs.index;
      if (widget.structuredLayout &&
          previous != null &&
          _structuredScroll.hasClients) {
        _structuredOffsets[previous] = _structuredScroll.offset;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              _tabs.index != next ||
              !_structuredScroll.hasClients) {
            return;
          }
          final position = _structuredScroll.position;
          if (!position.hasContentDimensions) return;
          _structuredScroll.jumpTo(
            (_structuredOffsets[next] ?? 0).clamp(
              position.minScrollExtent,
              position.maxScrollExtent,
            ),
          );
        });
      }
      setState(() => _visibleSection = next);
    }
    if (widget.sections[_tabs.index] == VideoFilterSection.tags &&
        _schema.tagGroups.isEmpty &&
        !_loading &&
        _error == null) {
      unawaited(_read());
    }
  }

  Future<void> _read() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await widget.readSchema();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.value case final value? when value.tagGroups.isNotEmpty) {
        _schema = _schema.merge(value);
        widget.onSchema?.call(_schema);
      } else {
        _error = videoOperationMessage(
          result.status == VideoSiteStatus.ok
              ? 'unsupported'
              : result.status.name,
        );
      }
    });
  }

  void _set(VideoFilterSection section, String value) => setState(() {
    _draft = _draft.change(section, value);
    if (section == VideoFilterSection.date) {
      _customDate = false;
      if (value.isEmpty) {
        _year.clear();
        _month = null;
      }
    }
  });
  void _setMonth() => setState(() {
    _customDate = true;
    _draft = _draft.copyWith(
      date: [
        if (_year.text.isNotEmpty) '${_year.text} 年',
        if (_month != null) '$_month 月',
      ].join(' '),
      page: 1,
    );
  });

  static const _customDateChoice = '__breeze_custom_date__';
  String _localized(BuildContext context, String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

  Widget _single(BuildContext context, VideoFilterSection section) {
    final value = switch (section) {
      VideoFilterSection.genre => _draft.genre,
      VideoFilterSection.sort => _draft.sort,
      VideoFilterSection.date => _draft.date,
      VideoFilterSection.duration => _draft.duration,
      _ => '',
    };
    final choices = _schema.options[section.name] ?? const [];
    final options = {for (final choice in choices) choice.value: choice.label};
    final ordered = options;
    final customDate =
        section == VideoFilterSection.date && _schema.customDate && _customDate;
    final years = {
      '': t.videoFilters.allYears,
      if (customDate)
        for (final year
            in (_schema.years
                .where((value) => RegExp(r'^\d{4}$').hasMatch(value))
                .toSet()
                .toList()
              ..sort((a, b) => b.compareTo(a))))
          year: year,
    };
    final months = {
      '': t.videoFilters.allMonths,
      if (customDate)
        for (var month = 1; month <= 12; month++)
          '$month': t.videoFilters.month(value: month),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (choices.isEmpty) Text(t.videoFilters.optionsUnavailable),
        if (widget.structuredLayout) ...[
          if (section == VideoFilterSection.date && _schema.customDate)
            Text(
              _localized(context, '常用日期', 'Date presets'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          if (section == VideoFilterSection.date && _schema.customDate)
            const SizedBox(height: 10),
          SelectionChoiceGrid<String>(
            options: {
              ...ordered,
              if (value.isNotEmpty &&
                  !customDate &&
                  !ordered.containsKey(value))
                value: value,
            },
            value: customDate ? _customDateChoice : value,
            maxColumns: 3,
            optionKey: (value) => ValueKey(
              'video-filter.${section.name}.${value.isEmpty ? 'all' : value}',
            ),
            onChanged: (value) => _set(section, value),
          ),
          if (section == VideoFilterSection.date && _schema.customDate)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  key: const ValueKey('hanime-filter.custom-date'),
                  icon: const Icon(Icons.calendar_month_outlined, size: 20),
                  label: Text(t.videoFilters.yearMonth),
                  onPressed: customDate ? null : _setMonth,
                ),
              ),
            ),
        ] else if (section == VideoFilterSection.date)
          CompactFilterChoice(
            keyPrefix: 'video-filter.date',
            label: videoFilterTitle(section),
            options: {
              ...ordered,
              if (value.isNotEmpty &&
                  !customDate &&
                  !options.containsKey(value))
                value: value,
              if (_schema.customDate)
                _customDateChoice: _customDate && value.isNotEmpty
                    ? '${t.videoFilters.yearMonth} · $value'
                    : t.videoFilters.yearMonth,
            },
            selected: customDate ? _customDateChoice : value,
            searchHint: t.videoFilters.date,
            onSelected: (picked) => picked == _customDateChoice
                ? _setMonth()
                : _set(section, picked),
          )
        else ...[
          SelectionChoiceGrid<String>(
            options: ordered,
            value: value,
            optionKey: (value) => ValueKey(
              'video-filter.${section.name}.${value.isEmpty ? 'all' : value}',
            ),
            onChanged: (value) => _set(section, value),
          ),
          if (value.isNotEmpty &&
              !_customFor(section) &&
              !choices.any((choice) => choice.value == value))
            InputChip(label: Text(value), onDeleted: () => _set(section, '')),
        ],
        if (section == VideoFilterSection.date && _schema.customDate) ...[
          if (_customDate) ...[
            const SizedBox(height: 12),
            if (years.length > 1)
              YearFilterPicker(
                keyPrefix: 'video-filter.year',
                label: t.videoFilters.year,
                options: years,
                selected: _year.text,
                onSelected: (value) {
                  _year.text = value;
                  _setMonth();
                },
              )
            else
              TextField(
                key: const ValueKey('video-filter.custom-year'),
                controller: _year,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: InputDecoration(
                  labelText: t.videoFilters.year,
                  hintText: t.videoFilters.allYears,
                  errorText: _invalidYear ? t.videoFilters.invalidYear : null,
                ),
                onChanged: (_) => _setMonth(),
              ),
            const SizedBox(height: 12),
            CompactFilterChoice(
              keyPrefix: 'video-filter.month',
              label: t.videoFilters.yearMonth,
              options: months,
              selected: _month?.toString() ?? '',
              onSelected: (picked) {
                _month = int.tryParse(picked);
                _setMonth();
              },
            ),
          ],
        ],
        if (value.isNotEmpty && !widget.structuredLayout)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: TextButton(
              onPressed: () => _set(section, ''),
              child: Text(t.common.clear),
            ),
          ),
      ],
    );
  }

  bool _customFor(VideoFilterSection section) =>
      section == VideoFilterSection.date && _customDate;

  Widget _tagSearchField(BuildContext context) => SearchFieldSurface(
    key: _tagSearchKey,
    child: TextField(
      key: const ValueKey('video-filter.tag-search'),
      controller: _tagSearch,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
      decoration: searchFieldDecoration(
        context,
        hintText: t.videoFilters.searchTags,
        suffixIcon: _tagSearch.text.isEmpty
            ? null
            : IconButton(
                tooltip: t.common.clear,
                icon: const Icon(Icons.cancel_rounded, size: 20),
                onPressed: _tagSearch.clear,
              ),
      ),
    ),
  );

  List<VideoFilterChoice> _tagChoices() {
    final query = _tagSearch.text.trim().toLowerCase();
    final groups = _schema.tagGroups;
    final current = groups.containsKey(_group)
        ? _group
        : groups.keys.firstOrNull;
    final known = {
      for (final group in groups.values)
        for (final choice in group) choice.value: choice,
    };
    final choices =
        (_selectedOnly
                ? _draft.tags.map(
                    (tag) =>
                        known[tag] ?? VideoFilterChoice(value: tag, label: tag),
                  )
                : query.isNotEmpty
                ? groups.values.expand((group) => group)
                : groups[current] ?? const <VideoFilterChoice>[])
            .where(
              (choice) =>
                  query.isEmpty ||
                  choice.label.toLowerCase().contains(query) ||
                  choice.value.toLowerCase().contains(query),
            )
            .toList();
    final seen = <String>{};
    choices.removeWhere((choice) => !seen.add(choice.value));
    return _favorites
            ?.order('tags', choices, (choice) => choice.value)
            .toList() ??
        choices;
  }

  Widget _structuredTagControls(BuildContext context) {
    final groups = _schema.tagGroups;
    final group = groups.containsKey(_group) ? _group : groups.keys.firstOrNull;
    final count = _draft.tags.length;
    final browsingGroups = !_selectedOnly && _tagSearch.text.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tagSearchField(context),
          SingleChildScrollView(
            key: const PageStorageKey('hanime.filter.groups'),
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 6,
              children: [
                FilterChip(
                  key: const ValueKey('video-filter.selected'),
                  label: Text(t.videoFilters.selected(count: count)),
                  selected: _selectedOnly,
                  showCheckmark: false,
                  onSelected: count == 0 && !_selectedOnly
                      ? null
                      : (value) {
                          _tagSearch.clear();
                          setState(() => _selectedOnly = value);
                        },
                ),
                for (final name in groups.keys)
                  ChoiceChip(
                    label: Text(name),
                    selected: browsingGroups && group == name,
                    showCheckmark: false,
                    chipAnimationStyle: _chipMotion(context),
                    onSelected: (_) {
                      _tagSearch.clear();
                      FocusScope.of(context).unfocus();
                      setState(() {
                        _selectedOnly = false;
                        _group = name;
                      });
                      if (_structuredScroll.hasClients)
                        _structuredScroll.jumpTo(0);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _structuredTagOptions(BuildContext context, double width) {
    final choices = _tagChoices();
    final favorites = _favorites;
    final known = _selectedOnly
        ? {
            for (final items in _schema.tagGroups.values)
              for (final item in items) item.value,
          }
        : null;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final scale = MediaQuery.textScalerOf(context).scale(14);
    final columns = width - 32 >= 320 * scale / 14 ? 2 : 1;
    return SliverMainAxisGroup(
      slivers: [
        if (_loading)
          const SliverToBoxAdapter(
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (_error != null && choices.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(liveRegion: true, child: Text(_error!)),
                  TextButton(onPressed: _read, child: Text(t.common.retry)),
                ],
              ),
            ),
          )
        else if (choices.isEmpty && !_loading)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Text(
                _selectedOnly
                    ? t.videoFilters.noSelection
                    : t.videoFilters.noMatchingTags,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisExtent: (scale * 2.5 + 12).clamp(48.0, double.infinity),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: choices.length,
              itemBuilder: (context, index) {
                final choice = choices[index];
                final selected = _draft.tags.contains(choice.value);
                return Material(
                  color: selected
                      ? colors.secondaryContainer
                      : colors.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: selected ? colors.primary : colors.outlineVariant,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Semantics(
                          selected: selected,
                          button: true,
                          child: InkWell(
                            key: ValueKey('hanime-filter.tag.${choice.value}'),
                            onTap: () => setState(
                              () => _draft = selected
                                  ? _draft.removeTag(choice.value)
                                  : _draft.change(
                                      VideoFilterSection.tags,
                                      choice.value,
                                    ),
                            ),
                            child: Padding(
                              padding: const EdgeInsetsDirectional.only(
                                start: 10,
                                end: 4,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    selected
                                        ? Icons.check_circle_rounded
                                        : Icons.circle_outlined,
                                    size: 17,
                                    color: selected
                                        ? colors.primary
                                        : colors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      choice.label,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            color: selected
                                                ? colors.onSecondaryContainer
                                                : colors.onSurface,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (favorites != null &&
                          (known?.contains(choice.value) ?? true))
                        favorites.star(
                          context,
                          'tags',
                          choice.value,
                          choice.label,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _structuredPanel(BuildContext context, double width) {
    final section = widget.sections[_tabs.index];
    final colors = Theme.of(context).colorScheme;
    final android =
        AppInterfaceStyleScope.usesAndroidSystem(context) &&
        VideoControlAppearance.usesSystem(context) &&
        !MediaQuery.highContrastOf(context);
    final track = android
        ? AndroidGlassPlate.track(colors)
        : colors.surfaceContainerLow;
    final selected = android
        ? AndroidGlassPlate.selected(colors, track)
        : colors.primaryContainer;
    final scrollTabs =
        width - 32 < 295 * MediaQuery.textScalerOf(context).scale(14) / 14;
    double labelWidth(String label, TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final theme = Theme.of(context);
    final match = Wrap(
      key: const ValueKey('hanime-filter.match-mode'),
      spacing: 4,
      children: _tagMatchChoices(context, showCheckmark: false).toList(),
    );
    final fits =
        width >=
        24 +
            44 +
            62 +
            labelWidth(t.videoFilters.title, theme.textTheme.titleMedium) +
            labelWidth(
              t.videoFilters.clearFilters,
              theme.textTheme.labelLarge,
            ) +
            labelWidth(t.videoFilters.allMatch, theme.textTheme.labelLarge) +
            labelWidth(t.videoFilters.anyMatch, theme.textTheme.labelLarge);
    return SafeArea(
      top: false,
      child: FacetFilterBody(
        scrollKey: const ValueKey('hanime.filter.options'),
        maxHeight: 680,
        scrollController: _structuredScroll,
        header: Padding(
          padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    t.videoFilters.title,
                    style: theme.textTheme.titleMedium,
                  ),
                  if (fits) ...[
                    const SizedBox(width: 6),
                    Expanded(child: match),
                  ] else
                    const Spacer(),
                  TextButton(
                    key: const ValueKey('video-filter.reset'),
                    onPressed: _reset,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    child: Text(t.videoFilters.clearFilters),
                  ),
                  IconButton(
                    tooltip: t.common.cancel,
                    onPressed: _cancel,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              if (!fits) match,
            ],
          ),
        ),
        controls: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: track,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabs,
                  isScrollable: scrollTabs,
                  tabAlignment: scrollTabs
                      ? TabAlignment.start
                      : TabAlignment.fill,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.all(3),
                  indicator: BoxDecoration(
                    color: selected,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelColor: android
                      ? BreezeThemeColors.readableOn(colors.onSurface, selected)
                      : colors.onPrimaryContainer,
                  tabs: [
                    for (final value in widget.sections)
                      Tab(text: videoFilterTitle(value)),
                  ],
                ),
              ),
            ),
            if (section == VideoFilterSection.tags)
              _structuredTagControls(context),
          ],
        ),
        options: section == VideoFilterSection.tags
            ? _structuredTagOptions(context, width)
            : SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _single(context, section),
                ),
              ),
        footer: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('video-filter.apply'),
              style: FilledButton.styleFrom(minimumSize: const Size(44, 44)),
              onPressed: _invalidYear ? null : _apply,
              child: Text(t.videoFilters.apply),
            ),
          ),
        ),
      ),
    );
  }

  ({double extent, double width, int rows}) _tagGrid(
    BuildContext context,
    double width,
    List<VideoFilterChoice> choices,
  ) {
    final scale = MediaQuery.textScalerOf(context);
    final starWidth = _favorites == null ? 0.0 : 44.0;
    final maxWidth = (160.0 + starWidth) * (scale.scale(14) / 14).clamp(1, 1.8);
    final available = (width - 32).clamp(1.0, double.infinity);
    final columns = (available / (maxWidth + 8)).ceil().clamp(1, 100);
    final cellWidth = (available - (columns - 1) * 8) / columns;
    var extent = 48.0;
    final style =
        Theme.of(context).chipTheme.labelStyle ??
        Theme.of(context).textTheme.labelLarge;
    final direction = Directionality.of(context);
    final key = (
      width,
      style,
      scale,
      direction,
      choices.length,
      Object.hashAll(choices.map((choice) => choice.label)),
    );
    if (key == _tagGridKey && _tagGridMetrics != null) {
      return _tagGridMetrics!;
    }
    for (final choice in choices) {
      final label =
          TextPainter(
            text: TextSpan(text: choice.label, style: style),
            textDirection: direction,
            textScaler: scale,
            maxLines: 2,
            ellipsis: '…',
          )..layout(
            maxWidth: (cellWidth - 44 - starWidth).clamp(1.0, double.infinity),
          );
      final needed = label.height + 20;
      if (needed > extent) extent = needed;
      label.dispose();
    }
    final metrics = (
      extent: extent,
      width: maxWidth,
      rows: (choices.length / columns).ceil(),
    );
    _tagGridKey = key;
    _tagGridMetrics = metrics;
    return metrics;
  }

  Widget _tags() {
    final query = _tagSearch.text.trim().toLowerCase();
    final groups = _schema.tagGroups;
    final current = groups.containsKey(_group)
        ? _group
        : groups.keys.firstOrNull;
    final choices = _tagChoices();
    final knownTags = _selectedOnly && _favorites != null
        ? {
            for (final group in groups.values)
              for (final option in group) option.value,
          }
        : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final nominalGrid = _tagGrid(context, constraints.maxWidth, choices);
        final inputLine = TextPainter(
          text: TextSpan(
            text: 'M',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final inputHeight = inputLine.height + 24 + 8;
        inputLine.dispose();
        // At large text sizes above a small keyboard, keep the real input
        // scrollable rather than shrinking it or overflowing the pinned actions.
        if (constraints.maxHeight < inputHeight) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: _tagSearchField(context),
          );
        }
        final compact =
            constraints.maxHeight < 340 ||
            MediaQuery.textScalerOf(context).scale(14) > 22;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                compact ? 4 : 8,
                16,
                compact ? 4 : 8,
              ),
              child: _tagSearchField(context),
            ),
            if (compact && constraints.maxHeight >= 180)
              SizedBox(
                height: MediaQuery.textScalerOf(context).scale(14) * 1.5 + 24,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Center(
                      child: TextButton.icon(
                        key: const ValueKey('video-filter.selected'),
                        style: TextButton.styleFrom(
                          alignment: AlignmentDirectional.centerStart,
                        ),
                        onPressed: () =>
                            setState(() => _selectedOnly = !_selectedOnly),
                        icon: const Icon(Icons.checklist_rounded, size: 20),
                        label: VideoFeedbackLabel(
                          t.videoFilters.selected(count: _draft.tags.length),
                        ),
                      ),
                    ),
                    for (final option in _tagMatchChoices(context))
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: Center(child: option),
                      ),
                    if (!_selectedOnly && query.isEmpty)
                      for (final group in groups.keys)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: Center(
                            child: ChoiceChip(
                              label: Text(group),
                              selected: current == group,
                              onSelected: (_) => setState(() => _group = group),
                              chipAnimationStyle: _chipMotion(context),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            if (!compact) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        key: const ValueKey('video-filter.selected'),
                        style: TextButton.styleFrom(
                          alignment: AlignmentDirectional.centerStart,
                        ),
                        onPressed: () =>
                            setState(() => _selectedOnly = !_selectedOnly),
                        icon: Icon(
                          _selectedOnly
                              ? Icons.check_circle_rounded
                              : Icons.checklist_rounded,
                          size: 20,
                        ),
                        label: VideoFeedbackLabel(
                          t.videoFilters.selected(count: _draft.tags.length),
                        ),
                      ),
                    ),
                    if (_draft.tags.isNotEmpty)
                      IconButton(
                        tooltip: t.common.clear,
                        onPressed: () => setState(
                          () => _draft = _draft.copyWith(tags: [], page: 1),
                        ),
                        icon: const Icon(Icons.clear_all_rounded),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [..._tagMatchChoices(context)],
                ),
              ),
              if (!_selectedOnly && query.isEmpty && groups.isNotEmpty)
                SizedBox(
                  height: MediaQuery.textScalerOf(context).scale(14) * 1.5 + 24,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final group in groups.keys)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: Center(
                            child: ChoiceChip(
                              label: Text(group),
                              selected: current == group,
                              onSelected: (_) => setState(() => _group = group),
                              chipAnimationStyle: _chipMotion(context),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: _error != null
                  ? ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Semantics(liveRegion: true, child: Text(_error!)),
                        TextButton(
                          onPressed: _loading ? null : _read,
                          child: Text(t.common.retry),
                        ),
                      ],
                    )
                  : choices.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _loading
                              ? t.common.loading
                              : _selectedOnly && _draft.tags.isEmpty
                              ? t.videoFilters.noSelection
                              : t.videoFilters.noMatchingTags,
                        ),
                      ),
                    )
                  : FilterScrollRail(
                      controller: _tagOptionsScroll,
                      // Preserve the compact layout for short groups. A small
                      // amount of padding overflow needs only normal scrolling.
                      enabled: nominalGrid.rows > 3,
                      child: LayoutBuilder(
                        builder: (context, space) {
                          final grid = _tagGrid(
                            context,
                            space.maxWidth,
                            choices,
                          );
                          return GridView.builder(
                            controller: _tagOptionsScroll,
                            primary: false,
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.manual,
                            key: ValueKey(
                              'video-filter.tags.${_selectedOnly
                                  ? 'selected'
                                  : query.isNotEmpty
                                  ? 'search'
                                  : current}',
                            ),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            gridDelegate:
                                SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: grid.width,
                                  mainAxisExtent: grid.extent,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                            itemCount: choices.length,
                            itemBuilder: (context, index) {
                              final choice = choices[index];
                              final chip = LayoutBuilder(
                                builder: (context, cell) => Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Tooltip(
                                    message: choice.label,
                                    child: FilterChip(
                                      // RawChip measures label height before reserving
                                      // its checkmark. Reserve the same fixed width in
                                      // that first pass so wrapped text cannot be cut.
                                      avatarBoxConstraints:
                                          const BoxConstraints.tightFor(
                                            width: 20,
                                            height: 20,
                                          ),
                                      avatar: const SizedBox.square(
                                        dimension: 20,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      labelPadding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.padded,
                                      label: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: (cell.maxWidth - 44).clamp(
                                            1,
                                            double.infinity,
                                          ),
                                        ),
                                        child: Text(
                                          choice.label,
                                          maxLines: 2,
                                          softWrap: true,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      selected: _draft.tags.contains(
                                        choice.value,
                                      ),
                                      showCheckmark: true,
                                      chipAnimationStyle: _chipMotion(context),
                                      onSelected: (selected) => setState(
                                        () => _draft = selected
                                            ? _draft.change(
                                                VideoFilterSection.tags,
                                                choice.value,
                                              )
                                            : _draft.removeTag(choice.value),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                              final favorites = _favorites;
                              if (favorites == null) return chip;
                              final known =
                                  knownTags?.contains(choice.value) ?? true;
                              return Row(
                                key: ValueKey(choice.value),
                                children: [
                                  Expanded(child: chip),
                                  known
                                      ? favorites.star(
                                          context,
                                          'tags',
                                          choice.value,
                                          choice.label,
                                        )
                                      : const SizedBox(width: 44),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _sectionOptions(BuildContext context, VideoFilterSection section) {
    final controller = _sectionScrolls.putIfAbsent(
      section,
      ScrollController.new,
    );
    return FilterScrollRail(
      controller: controller,
      child: ListView(
        key: PageStorageKey('video-filter.${section.name}'),
        controller: controller,
        primary: false,
        padding: const EdgeInsets.all(16),
        children: [
          section == VideoFilterSection.query
              ? _queryMode(context)
              : _single(context, section),
        ],
      ),
    );
  }

  Iterable<Widget> _tagMatchChoices(
    BuildContext context, {
    bool showCheckmark = true,
  }) sync* {
    // Match mode is a fixed control, distinct from collectible tag values.
    for (final any in [false, true]) {
      yield ChoiceChip(
        label: Text(any ? t.videoFilters.anyMatch : t.videoFilters.allMatch),
        selected: _draft.anyTag == any,
        showCheckmark: showCheckmark,
        onSelected: (_) =>
            setState(() => _draft = _draft.copyWith(anyTag: any, page: 1)),
        chipAnimationStyle: _chipMotion(context),
      );
    }
  }

  ChipAnimationStyle _chipMotion(BuildContext context) =>
      VideoMotion.chip(context);

  Widget _queryMode(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SearchFieldSurface(
        child: TextField(
          controller: _query,
          decoration: searchFieldDecoration(
            context,
            hintText: t.videoPlayback.searchVideos,
          ),
          onChanged: (value) => _draft = _draft.copyWith(query: value, page: 1),
        ),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final author in [false, true])
            ChoiceChip(
              label: Text(
                author ? t.videoFilters.authors : t.videoFilters.videos,
              ),
              selected: _draft.author == author,
              chipAnimationStyle: _chipMotion(context),
              showCheckmark: false,
              onSelected: (_) => setState(
                () => _draft = _draft.copyWith(author: author, page: 1),
              ),
            ),
        ],
      ),
    ],
  );

  void _reset({bool all = false}) => setState(() {
    final resetQuery =
        all && widget.sections.contains(VideoFilterSection.query);
    _draft = resetQuery
        ? const VideoSearchFilters()
        : _draft.copyWith(
            genre: widget.sections.contains(VideoFilterSection.genre)
                ? ''
                : _draft.genre,
            sort: widget.sections.contains(VideoFilterSection.sort)
                ? ''
                : _draft.sort,
            date: '',
            duration: '',
            tags: const [],
            anyTag: false,
            completed: false,
            page: 1,
          );
    if (resetQuery) _query.clear();
    _tagSearch.clear();
    _year.clear();
    _month = null;
    _customDate = false;
    if (widget.structuredLayout) _selectedOnly = false;
  });

  void _apply() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(
      _draft.copyWith(
        query: _query.text.trim(),
        anyTag:
            _draft.anyTag &&
            (!widget.structuredLayout || _draft.tags.length > 1),
        page: 1,
      ),
    );
  }

  void _cancel() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
  }

  Widget _readableOptions(BuildContext context, bool keyboard) {
    const key = ValueKey('video-filter.readable-content');
    final options = TabBarView(
      physics: keyboard ? const NeverScrollableScrollPhysics() : null,
      controller: _tabs,
      children: [
        for (final section in widget.sections)
          section == VideoFilterSection.tags
              ? _tags()
              : _sectionOptions(context, section),
      ],
    );
    final system = VideoControlAppearance.usesSystem(context);
    if (system && AppInterfaceStyleScope.usesAndroidSystem(context)) {
      // The task sheet owns the readable material behind all of its content.
      return KeyedSubtree(key: key, child: options);
    }
    return NativeMaterialSurface(
      key: key,
      radius: 0,
      readableContent: true,
      systemStyle: system,
      child: options,
    );
  }

  Widget _filterSectionMenu(BuildContext context) {
    void select(VideoFilterSection section) {
      _tabs.index = widget.sections.indexOf(section);
      setState(() {});
    }

    final current = widget.sections[_tabs.index];
    final title = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Text(
        videoFilterTitle(current),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
    final tooltip = t.videoFilters.allFilters;
    if (AppInterfaceStyleScope.usesAndroidSystem(context) &&
        VideoControlAppearance.usesSystem(context)) {
      return NativeVideoMenu(
        label: videoFilterTitle(current),
        tooltip: tooltip,
        selected: current.name,
        options: {
          for (final section in widget.sections)
            section.name: videoFilterTitle(section),
        },
        onSelected: (value) => select(VideoFilterSection.values.byName(value)),
        hostTriggerBuilder: (_, open) => Tooltip(
          message: tooltip,
          child: InkWell(
            onTap: open,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: title,
              ),
            ),
          ),
        ),
      );
    }
    return PopupMenuButton<VideoFilterSection>(
      tooltip: tooltip,
      onSelected: select,
      itemBuilder: (_) => [
        for (final section in widget.sections)
          PopupMenuItem(value: section, child: Text(videoFilterTitle(section))),
      ],
      child: title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Theme(
      data: videoBrowseTheme(Theme.of(context)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          if (widget.structuredLayout) {
            return SizedBox(
              key: const ValueKey('video-filter.panel'),
              height: FilterSheetDetents.heightOf(
                context,
                compact: constraints.maxHeight.clamp(0.0, 680.0),
                expanded: constraints.maxHeight,
                tracksHandle: false,
              ),
              child: _structuredPanel(context, constraints.maxWidth),
            );
          }
          final section = widget.sections[_tabs.index];
          final tags = section == VideoFilterSection.tags;
          final grid = _tagGrid(context, constraints.maxWidth, _tagChoices());
          final desired = tags
              ? 340 * scale + grid.rows * (grid.extent + 8) + 40
              : (_customDate && section == VideoFilterSection.date
                        ? 640
                        : 420) *
                    scale;
          return SizedBox(
            key: const ValueKey('video-filter.panel'),
            height: FilterSheetDetents.heightOf(
              context,
              compact: desired.clamp(0.0, constraints.maxHeight),
              expanded: constraints.maxHeight,
              tracksHandle: false,
            ),
            child: Scaffold(
              primary: false,
              resizeToAvoidBottomInset: false,
              backgroundColor: Colors.transparent,
              body: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: keyboard
                                ? _filterSectionMenu(context)
                                : Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      t.videoFilters.title,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                          ),
                          if (keyboard)
                            IconButton(
                              tooltip: t.videoFilters.closeKeyboard,
                              onPressed: () => FocusScope.of(context).unfocus(),
                              icon: const Icon(Icons.keyboard_hide_rounded),
                            )
                          else if (widget.sections.contains(
                            VideoFilterSection.query,
                          ))
                            Tooltip(
                              message: t.videoFilters.clearAll,
                              child: TextButton(
                                onPressed: () => _reset(all: true),
                                child: Text(t.videoFilters.reset),
                              ),
                            ),
                          IconButton(
                            tooltip: t.common.cancel,
                            onPressed: _cancel,
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    if (!keyboard)
                      TabBar(
                        controller: _tabs,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        labelStyle: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                        unselectedLabelStyle: Theme.of(
                          context,
                        ).textTheme.labelLarge,
                        tabs: [
                          for (final section in widget.sections)
                            Tab(text: videoFilterTitle(section)),
                        ],
                      ),
                    Expanded(child: _readableOptions(context, keyboard)),
                    const Divider(height: 1),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: keyboard ? 0 : 8,
                      ),
                      child: Row(
                        children: [
                          if (keyboard)
                            IconButton(
                              key: const ValueKey('video-filter.reset'),
                              tooltip: t.videoFilters.clearFilters,
                              onPressed: _reset,
                              icon: const Icon(Icons.filter_alt_off_outlined),
                            )
                          else
                            Expanded(
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: TextButton(
                                  key: const ValueKey('video-filter.reset'),
                                  onPressed: _reset,
                                  child: Text(t.videoFilters.clearFilters),
                                ),
                              ),
                            ),
                          if (keyboard) const Spacer(),
                          FilledButton(
                            key: const ValueKey('video-filter.apply'),
                            onPressed: _invalidYear ? null : _apply,
                            child: Text(
                              keyboard
                                  ? t.videoFilters.applyShort
                                  : t.videoFilters.apply,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class VideoSearchFilterBar extends StatelessWidget {
  const VideoSearchFilterBar({
    super.key,
    required this.filters,
    required this.schema,
    required this.onOpen,
    this.onAll,
  });
  final VideoSearchFilters filters;
  final VideoFilterSchema schema;
  final ValueChanged<VideoFilterSection> onOpen;
  final VoidCallback? onAll;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final options = ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        for (final section in [
          VideoFilterSection.genre,
          VideoFilterSection.tags,
          VideoFilterSection.sort,
          VideoFilterSection.date,
          VideoFilterSection.duration,
        ])
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Center(
              child: Builder(
                builder: (_) {
                  final value = switch (section) {
                    VideoFilterSection.genre => filters.genre,
                    VideoFilterSection.sort => filters.sort,
                    VideoFilterSection.date => filters.date,
                    VideoFilterSection.duration => filters.duration,
                    VideoFilterSection.tags =>
                      filters.tags.isEmpty ? '' : '${filters.tags.length}',
                    VideoFilterSection.query =>
                      filters.author
                          ? '${t.videoFilters.authors}: ${filters.query}'
                          : filters.query,
                  };
                  final selected = value.isNotEmpty;
                  final display =
                      schema.options[section.name]
                          ?.where((choice) => choice.value == value)
                          .firstOrNull
                          ?.label ??
                      value;
                  return TextButton.icon(
                    key: ValueKey('video-filter-open.${section.name}'),
                    onPressed: () => onOpen(section),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      backgroundColor: selected
                          ? colors.secondaryContainer
                          : colors.surfaceContainer,
                      foregroundColor: selected
                          ? colors.onSecondaryContainer
                          : colors.onSurfaceVariant,
                    ),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.expand_more_rounded, size: 20),
                    label: Text(
                      section == VideoFilterSection.tags && selected
                          ? '${videoFilterTitle(section)} $value'
                          : selected
                          ? display
                          : videoFilterTitle(section),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
    return SizedBox(
      height: MediaQuery.textScalerOf(context).scale(14) * 1.5 + 28,
      child: Row(
        children: [
          Expanded(child: options),
          if (onAll != null)
            IconButton(
              key: const ValueKey('video-filter.all'),
              tooltip: t.videoFilters.allFilters,
              onPressed: onAll,
              icon: const Icon(Icons.tune_rounded),
            ),
        ],
      ),
    );
  }
}

/// Small, single-choice task: selecting an option commits only this field.
class VideoQuickFilterPanel extends StatefulWidget {
  const VideoQuickFilterPanel({
    super.key,
    required this.section,
    required this.initial,
    required this.schema,
    this.source,
  });
  final VideoFilterSection section;
  final VideoSearchFilters initial;
  final VideoFilterSchema schema;
  final String? source;

  @override
  State<VideoQuickFilterPanel> createState() => _VideoQuickFilterPanelState();
}

class _VideoQuickFilterPanelState extends State<VideoQuickFilterPanel> {
  final _optionScroll = ScrollController();

  @override
  void dispose() {
    _optionScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    final initial = widget.initial;
    final schema = widget.schema;
    final value = switch (section) {
      VideoFilterSection.genre => initial.genre,
      VideoFilterSection.sort => initial.sort,
      VideoFilterSection.date => initial.date,
      VideoFilterSection.duration => initial.duration,
      _ => '',
    };
    final options = schema.options[section.name] ?? const [];
    final choices = options;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  videoFilterTitle(section),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: t.common.close,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Flexible(
          child: FilterScrollRail(
            controller: _optionScroll,
            child: ListView(
              controller: _optionScroll,
              primary: false,
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                if (choices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(t.videoFilters.optionsUnavailable),
                  ),
                for (final choice in choices)
                  Row(
                    key: ValueKey(choice.value),
                    children: [
                      Expanded(
                        child: Semantics(
                          selected: choice.value == value,
                          child: ListTile(
                            title: Text(choice.label),
                            trailing: choice.value == value
                                ? const Icon(Icons.check_rounded)
                                : null,
                            onTap: () =>
                                Navigator.of(context).pop(choice.value),
                          ),
                        ),
                      ),
                    ],
                  ),
                if (value.isNotEmpty &&
                    !choices.any((choice) => choice.value == value))
                  ListTile(
                    title: Text(t.common.clear),
                    onTap: () => Navigator.of(context).pop(''),
                  ),
                if (section == VideoFilterSection.date && schema.customDate)
                  ListTile(
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: Text(t.videoFilters.yearMonth),
                    onTap: () => Navigator.of(context).pop(section),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Applied request state remains visible even when the result set is empty.
class VideoActiveFilters extends StatelessWidget {
  const VideoActiveFilters({
    super.key,
    required this.filters,
    required this.schema,
    required this.onChanged,
    this.sections = VideoFilterSection.values,
    this.onEdit,
  });
  final VideoSearchFilters filters;
  final VideoFilterSchema schema;
  final ValueChanged<VideoSearchFilters> onChanged;
  final List<VideoFilterSection> sections;
  final ValueChanged<VideoFilterSection>? onEdit;

  @override
  Widget build(BuildContext context) {
    final entries =
        <
          ({
            String id,
            String label,
            VideoSearchFilters next,
            VideoFilterSection section,
          })
        >[];
    for (final section in [
      VideoFilterSection.sort,
      VideoFilterSection.date,
      VideoFilterSection.duration,
    ]) {
      final value = switch (section) {
        VideoFilterSection.sort => filters.sort,
        VideoFilterSection.date => filters.date,
        _ => filters.duration,
      };
      if (value.isEmpty || !sections.contains(section)) continue;
      final label =
          schema.options[section.name]
              ?.where((choice) => choice.value == value)
              .firstOrNull
              ?.label ??
          value;
      entries.add((
        id: section.name,
        label: section == VideoFilterSection.duration
            ? label
            : '${videoFilterTitle(section)}: $label',
        next: filters.change(section, ''),
        section: section,
      ));
    }
    if (sections.contains(VideoFilterSection.tags)) {
      entries.addAll(
        filters.tags.map(
          (tag) => (
            id: 'tag.$tag',
            label: tag,
            next: filters
                .removeTag(tag)
                .copyWith(anyTag: filters.anyTag && filters.tags.length > 2),
            section: VideoFilterSection.tags,
          ),
        ),
      );
    }
    if (filters.author && sections.contains(VideoFilterSection.query)) {
      entries.add((
        id: 'author',
        label: t.videoFilters.authors,
        next: filters.copyWith(author: false, page: 1),
        section: VideoFilterSection.query,
      ));
    }
    if (filters.anyTag && sections.contains(VideoFilterSection.tags)) {
      entries.add((
        id: 'any',
        label: t.videoFilters.anyMatch,
        next: filters.copyWith(anyTag: false, page: 1),
        section: VideoFilterSection.tags,
      ));
    }
    return AppliedFilterBar(
      entries: [
        for (final entry in entries)
          (
            id: entry.id,
            label: entry.label,
            remove: () => onChanged(entry.next),
            edit: onEdit == null ? null : () => onEdit!(entry.section),
          ),
      ],
      onClearAll: () => onChanged(
        filters.copyWith(
          tags: sections.contains(VideoFilterSection.tags)
              ? const []
              : filters.tags,
          anyTag: sections.contains(VideoFilterSection.tags)
              ? false
              : filters.anyTag,
          sort: sections.contains(VideoFilterSection.sort) ? '' : filters.sort,
          date: sections.contains(VideoFilterSection.date) ? '' : filters.date,
          duration: sections.contains(VideoFilterSection.duration)
              ? ''
              : filters.duration,
          author: sections.contains(VideoFilterSection.query)
              ? false
              : filters.author,
          page: 1,
        ),
      ),
    );
  }
}
