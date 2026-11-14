import 'package:zephyr/widgets/native_material_surface.dart';
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
    this.onSchema,
    this.onCancelRead,
  });
  final String? source;
  final VideoSearchFilters initial;
  final VideoFilterSchema schema;
  final VideoFilterSection initialSection;
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
        ? widget.initialSection.index
        : _tabs.index;
    if (_tabDuration != null) _tabs.dispose();
    _tabDuration = duration;
    _tabs = TabController(
      length: VideoFilterSection.values.length,
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
    _year.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _tabChanged() {
    if (_visibleSection != _tabs.index) {
      setState(() => _visibleSection = _tabs.index);
    }
    if (_tabs.index == VideoFilterSection.tags.index &&
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
        if (section == VideoFilterSection.date)
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
        if (value.isNotEmpty)
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
        final grid = _tagGrid(context, constraints.maxWidth, choices);
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
                  : GridView.builder(
                      key: ValueKey(
                        'video-filter.tags.${_selectedOnly
                            ? 'selected'
                            : query.isNotEmpty
                            ? 'search'
                            : current}',
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
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
                                avatar: const SizedBox.square(dimension: 20),
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
                                selected: _draft.tags.contains(choice.value),
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
                        final known = knownTags?.contains(choice.value) ?? true;
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
                    ),
            ),
          ],
        );
      },
    );
  }

  Iterable<Widget> _tagMatchChoices(BuildContext context) sync* {
    // Match mode is a fixed control, distinct from collectible tag values.
    for (final any in [false, true]) {
      yield ChoiceChip(
        label: Text(any ? t.videoFilters.anyMatch : t.videoFilters.allMatch),
        selected: _draft.anyTag == any,
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
    _draft = all ? const VideoSearchFilters() : _draft.clearFilters();
    if (all) _query.clear();
    _tagSearch.clear();
    _year.clear();
    _month = null;
    _customDate = false;
  });

  void _apply() {
    FocusScope.of(context).unfocus();
    Navigator.of(
      context,
    ).pop(_draft.copyWith(query: _query.text.trim(), page: 1));
  }

  void _cancel() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Theme(
      data: videoBrowseTheme(Theme.of(context)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final tags = _tabs.index == VideoFilterSection.tags.index;
          final grid = _tagGrid(context, constraints.maxWidth, _tagChoices());
          // Small groups should not stretch to a nearly full-screen sheet. Large
          // groups still get the available viewport and retain lazy grid scrolling.
          final desired = tags
              ? 340 * scale + grid.rows * (grid.extent + 8) + 40
              : (_customDate && _tabs.index == VideoFilterSection.date.index
                        ? 640.0
                        : 420.0) *
                    scale;
          return SizedBox(
            key: const ValueKey('video-filter.panel'),
            height: desired.clamp(0.0, constraints.maxHeight),
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
                                ? PopupMenuButton<VideoFilterSection>(
                                    tooltip: t.videoFilters.allFilters,
                                    onSelected: (section) {
                                      _tabs.index = section.index;
                                      setState(() {});
                                    },
                                    itemBuilder: (_) => [
                                      for (final section
                                          in VideoFilterSection.values)
                                        PopupMenuItem(
                                          value: section,
                                          child: Text(
                                            videoFilterTitle(section),
                                          ),
                                        ),
                                    ],
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      child: Text(
                                        videoFilterTitle(
                                          VideoFilterSection.values[_tabs
                                              .index],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                    ),
                                  )
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
                          else
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
                          for (final section in VideoFilterSection.values)
                            Tab(text: videoFilterTitle(section)),
                        ],
                      ),
                    Expanded(
                      child: NativeMaterialSurface(
                        key: const ValueKey('video-filter.readable-content'),
                        radius: 0,
                        readableContent: true,
                        systemStyle: VideoControlAppearance.usesSystem(context),
                        child: TabBarView(
                          physics: keyboard
                              ? const NeverScrollableScrollPhysics()
                              : null,
                          controller: _tabs,
                          children: [
                            for (final section in VideoFilterSection.values)
                              section == VideoFilterSection.tags
                                  ? _tags()
                                  : ListView(
                                      key: PageStorageKey(
                                        'video-filter.${section.name}',
                                      ),
                                      keyboardDismissBehavior:
                                          ScrollViewKeyboardDismissBehavior
                                              .onDrag,
                                      padding: const EdgeInsets.all(16),
                                      children: [
                                        section == VideoFilterSection.query
                                            ? _queryMode(context)
                                            : _single(context, section),
                                      ],
                                    ),
                          ],
                        ),
                      ),
                    ),
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
          child: ListView(
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
                          onTap: () => Navigator.of(context).pop(choice.value),
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
  });
  final VideoSearchFilters filters;
  final VideoFilterSchema schema;
  final ValueChanged<VideoSearchFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final entries = <({String label, VideoSearchFilters next})>[];
    for (final section in [
      VideoFilterSection.genre,
      VideoFilterSection.sort,
      VideoFilterSection.date,
      VideoFilterSection.duration,
    ]) {
      final value = switch (section) {
        VideoFilterSection.genre => filters.genre,
        VideoFilterSection.sort => filters.sort,
        VideoFilterSection.date => filters.date,
        _ => filters.duration,
      };
      if (value.isEmpty) continue;
      final label =
          schema.options[section.name]
              ?.where((choice) => choice.value == value)
              .firstOrNull
              ?.label ??
          value;
      entries.add((
        label: '${videoFilterTitle(section)}: $label',
        next: filters.change(section, ''),
      ));
    }
    entries.addAll(
      filters.tags.map((tag) => (label: tag, next: filters.removeTag(tag))),
    );
    if (filters.author) {
      entries.add((
        label: t.videoFilters.authors,
        next: filters.copyWith(author: false, page: 1),
      ));
    }
    if (filters.anyTag) {
      entries.add((
        label: t.videoFilters.anyMatch,
        next: filters.copyWith(anyTag: false, page: 1),
      ));
    }
    if (entries.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label: t.videoFilters.active,
      child: SizedBox(
        height: MediaQuery.textScalerOf(context).scale(14) * 1.5 + 28,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: entries.length + 1,
          itemBuilder: (_, index) => Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Center(
              child: index == 0
                  ? TextButton(
                      onPressed: () => onChanged(filters.clearFilters()),
                      child: Text(t.videoFilters.clearFilters),
                    )
                  : InputChip(
                      label: Text(entries[index - 1].label),
                      chipAnimationStyle: VideoMotion.chip(context),
                      deleteButtonTooltipMessage: t.videoFilters.removeFilter,
                      onDeleted: () => onChanged(entries[index - 1].next),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
