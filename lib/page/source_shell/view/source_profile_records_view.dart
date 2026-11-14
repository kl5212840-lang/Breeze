import 'package:zephyr/page/source_shell/view/jm_collection_toolbar.dart';
import 'package:zephyr/widgets/work_list_divider.dart';
import 'package:zephyr/page/search/widget/search_keyboard.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/source_shell/source_list_view_toggle.dart';
import 'package:zephyr/page/source_shell/source_list_presentation.dart';
import 'package:zephyr/widgets/collection_cover_settings.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/widgets/pull_refresh_feedback.dart';
import 'package:zephyr/widgets/read_recovery_scope.dart';

import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_content_layout.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_content_toolbar.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_detailed_content.dart';
import 'package:zephyr/widgets/collection_cover_fit.dart';
import 'package:zephyr/widgets/comic_entry/comic_record_time.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/page/search_result/view/source_search_detail_list.dart';
import 'package:zephyr/page/search_result/view/source_list_categories.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/text/chinese_convert.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry.dart';
import 'package:zephyr/widgets/comic_simplify_entry/cover.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';
import 'package:zephyr/page/source_shell/source_list_block_preferences.dart';
import 'package:zephyr/page/search_result/view/source_loaded_result_filter.dart';

String sourceProfileRecordLabel(ShelfPageMode mode) => switch (mode) {
  ShelfPageMode.favorite => t.comicInfo.collected,
  ShelfPageMode.history => t.videoPersonal.recent,
  ShelfPageMode.download => '下载管理',
};

IconData sourceProfileRecordIcon(ShelfPageMode mode) => switch (mode) {
  ShelfPageMode.favorite => Icons.bookmark_outline,
  ShelfPageMode.history => Icons.history,
  ShelfPageMode.download => Icons.download_outlined,
};

String sourceProfileRecordEmptyMessage(ShelfPageMode mode) => switch (mode) {
  ShelfPageMode.favorite => '还没有收藏的漫画',
  ShelfPageMode.history => t.videoPlayback.historyEmpty,
  ShelfPageMode.download => '还没有下载的漫画',
};

ComicEntryType _entryType(ShelfPageMode mode) => switch (mode) {
  ShelfPageMode.favorite => ComicEntryType.favorite,
  ShelfPageMode.history => ComicEntryType.history,
  ShelfPageMode.download => ComicEntryType.download,
};

class SourceProfilePreviewSection extends StatelessWidget {
  const SourceProfilePreviewSection({
    super.key,
    required this.mode,
    required this.entries,
    required this.onViewAll,
    required this.onReturned,
    this.source = '',
    this.jmCollection = false,
    this.compactLayout = false,
  });

  final bool jmCollection, compactLayout;
  final ShelfPageMode mode;
  final List<UnifiedComicListItem> entries;
  final VoidCallback onViewAll;
  final VoidCallback onReturned;
  final String source;

  @override
  Widget build(BuildContext context) => SourceProfileComicPreviewCard(
    previewKey: ValueKey('profile-preview-${mode.name}'),
    source: source,
    jmCollection: jmCollection,
    compactLayout: compactLayout,
    title: sourceProfileRecordLabel(mode),
    icon: sourceProfileRecordIcon(mode),
    countLabel: '${entries.length}',
    emptyMessage: sourceProfileRecordEmptyMessage(mode),
    entries: entries,
    type: _entryType(mode),
    onViewAll: onViewAll,
    onReturned: onReturned,
  );
}

class SourceProfileComicPreviewCard extends StatelessWidget {
  const SourceProfileComicPreviewCard({
    super.key,
    required this.previewKey,
    required this.title,
    required this.icon,
    required this.entries,
    required this.type,
    required this.emptyMessage,
    required this.onViewAll,
    required this.onReturned,
    this.countLabel,
    this.loading = false,
    this.error,
    this.onRetry,
    this.source = '',
    this.jmCollection = false,
    this.compactLayout = false,
  });

  final bool jmCollection, compactLayout;
  final Key previewKey;
  final String title;
  final IconData icon;
  final List<UnifiedComicListItem> entries;
  final ComicEntryType type;
  final String emptyMessage;
  final VoidCallback onViewAll;
  final VoidCallback onReturned;
  final String? countLabel;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final String source;
  bool get _compact => jmCollection || compactLayout;

  @override
  Widget build(BuildContext context) => CollectionCoverPrivacyScope(
    child: _SourceProfileComicPreviewCardBody(
      key: PageStorageKey((
        'source-profile-preview',
        previewKey,
        type,
        source.isEmpty ? entries.firstOrNull?.source : source,
      )),
      card: this,
    ),
  );

  Widget _header(BuildContext context, bool expanded, VoidCallback onToggle) =>
      _compact
      ? _JmPreviewHeader(
          previewKey: previewKey,
          title: title,
          count: countLabel,
          onViewAll: onViewAll,
        )
      : SourceProfilePreviewHeader(
          previewKey: previewKey,
          title: title,
          icon: icon,
          hasEntries: entries.isNotEmpty,
          expanded: expanded,
          onToggle: onToggle,
          onViewAll: onViewAll,
          countLabel: countLabel,
        );

  Widget _build(
    BuildContext context,
    bool expanded,
    VoidCallback onToggle,
    PageStorageKey<Object> scrollKey,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      key: previewKey,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, expanded, onToggle),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: SizedBox(
              height: 2,
              child: loading
                  ? LinearProgressIndicator(
                      minHeight: 2,
                      value: MediaQuery.disableAnimationsOf(context)
                          ? .5
                          : null,
                    )
                  : null,
            ),
          ),
          if (!_compact && entries.isEmpty && !loading && error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 4, 0, 2),
              child: Text(
                emptyMessage,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
              ),
            ),
          if (entries.isNotEmpty)
            VideoDisclosureRegion(
              expanded: _compact || expanded,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final visibleColumns = (constraints.maxWidth / 112)
                      .floor()
                      .clamp(3, 4);
                  final width = _compact
                      ? (constraints.maxWidth - 12 * (visibleColumns - 1)) /
                            visibleColumns
                      : 80.0;
                  final previewEntries = _compact
                      ? entries.take(4).toList()
                      : entries;
                  final titlePainter = TextPainter(
                    text: TextSpan(
                      text: '国\n国',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    textDirection: Directionality.of(context),
                    textScaler: MediaQuery.textScalerOf(context),
                  )..layout(maxWidth: width);
                  final titleHeight = titlePainter.height;
                  titlePainter.dispose();
                  return SizedBox(
                    height:
                        width / BookshelfContentLayout.coverAspectRatio +
                        6 +
                        titleHeight,
                    child: ListView.separated(
                      key: scrollKey,
                      primary: false,
                      scrollDirection: Axis.horizontal,
                      itemCount: previewEntries.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) => SizedBox(
                        width: width,
                        child: _PreviewCover(
                          entry: previewEntries[index],
                          type: type,
                          onReturned: onReturned,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 2, 0, 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (onRetry != null)
                    TextButton(
                      onPressed: loading ? null : onRetry,
                      child: Text(t.common.retry),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _JmPreviewHeader extends StatelessWidget {
  const _JmPreviewHeader({
    required this.previewKey,
    required this.title,
    required this.count,
    required this.onViewAll,
  });
  final Key previewKey;
  final String title;
  final String? count;
  final VoidCallback onViewAll;
  @override
  Widget build(BuildContext context) => Row(
    key: ValueKey(('jm-preview-header', previewKey)),
    children: [
      Expanded(
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: title),
              if (count != null)
                TextSpan(
                  text: ' · $count',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      TextButton(
        key: ValueKey(('profile-view-all', previewKey)),
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        onPressed: onViewAll,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.videoPersonal.viewAll),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right_rounded, size: 18),
          ],
        ),
      ),
    ],
  );
}

class _SourceProfileComicPreviewCardBody extends StatefulWidget {
  const _SourceProfileComicPreviewCardBody({super.key, required this.card});
  final SourceProfileComicPreviewCard card;

  @override
  State<_SourceProfileComicPreviewCardBody> createState() =>
      _SourceProfileComicPreviewCardBodyState();
}

class _SourceProfileComicPreviewCardBodyState
    extends State<_SourceProfileComicPreviewCardBody> {
  bool _expanded = true;
  bool _restored = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restored) return;
    _restored = true;
    // The body PageStorageKey includes source and record kind; ancestor page
    // keys keep the same group isolated when used in another profile context.
    _expanded =
        PageStorage.maybeOf(context)?.readState(context) as bool? ?? true;
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    PageStorage.maybeOf(context)?.writeState(context, _expanded);
  }

  @override
  Widget build(BuildContext context) => widget.card._build(
    context,
    _expanded,
    _toggle,
    const PageStorageKey<Object>('profile-preview-scroll'),
  );
}

class _PreviewCover extends StatelessWidget {
  const _PreviewCover({
    required this.entry,
    required this.type,
    required this.onReturned,
  });

  final UnifiedComicListItem entry;
  final ComicEntryType type;
  final VoidCallback onReturned;

  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey('profile-cover-${entry.source}:${entry.id}'),
    borderRadius: BorderRadius.circular(9),
    onTap: () async {
      await context.pushRoute(
        ComicInfoRoute(comicId: entry.id, type: type, from: entry.from),
      );
      if (context.mounted) onReturned();
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: BookshelfContentLayout.coverAspectRatio,
          child: LayoutBuilder(
            builder: (context, constraints) => ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: CollectionCoverFitBuilder(
                builder: (_, fit) => CoverWidget(
                  fileServer: entry.cover.url,
                  path: entry.cover.cachePath,
                  id: entry.id,
                  pictureType: PictureType.cover,
                  from: entry.from,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  fit: fit,
                  containBackground: true,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          convertChineseForDisplay(entry.title),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class SourceProfileRecordsView extends StatefulWidget {
  const SourceProfileRecordsView({
    super.key,
    required this.mode,
    required this.entries,
    required this.onBack,
    this.onRefresh,
    this.onRefreshWithResult,
    this.error,
    this.onManageFolders,
    this.source,
    this.sourceName = '',
    this.showBackButton = true,
    this.jmCollection = false,
    this.compactLayout = false,
    this.jmHeaderController,
  }) : assert(onRefresh != null || onRefreshWithResult != null);

  final ShelfPageMode mode;
  final List<UnifiedComicListItem> entries;
  final VoidCallback onBack;
  final FutureOr<void> Function()? onRefresh;
  final FutureOr<PullRefreshResult> Function()? onRefreshWithResult;
  final String? error;
  final VoidCallback? onManageFolders;
  final String? source;
  final String sourceName;
  final bool showBackButton, jmCollection, compactLayout;
  final JmCollectionHeaderController? jmHeaderController;

  @override
  State<SourceProfileRecordsView> createState() =>
      _SourceProfileRecordsViewState();
}

class _SourceProfileRecordsViewState extends State<SourceProfileRecordsView> {
  bool _detailed = true;
  String _sort = 'new';
  bool get _compact => widget.jmCollection || widget.compactLayout;
  final _jmSearch = TextEditingController();
  final _jmSearchFocus = FocusNode();
  bool _jmSearchOpen = false;
  final _jmHeaderOwner = Object();
  String? _jmHeaderSignature;

  @override
  void didUpdateWidget(SourceProfileRecordsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.jmHeaderController != widget.jmHeaderController) {
      final previous = oldWidget.jmHeaderController;
      scheduleMicrotask(() => previous?.release(_jmHeaderOwner));
      _jmHeaderSignature = null;
    }
    if (oldWidget.source != widget.source ||
        oldWidget.mode != widget.mode ||
        oldWidget.jmCollection != widget.jmCollection ||
        oldWidget.compactLayout != widget.compactLayout) {
      _jmSearch.clear();
      _jmSearchFocus.unfocus();
      _jmSearchOpen = false;
    }
    if (oldWidget.source != widget.source || oldWidget.mode != widget.mode) {
      _refreshTask = null;
      _refreshError = null;
    }
  }

  @override
  void dispose() {
    final controller = widget.jmHeaderController;
    scheduleMicrotask(() => controller?.release(_jmHeaderOwner));
    _jmSearch.dispose();
    _jmSearchFocus.dispose();
    super.dispose();
  }

  final _refreshIndicator = GlobalKey<RefreshIndicatorState>();
  Future<PullRefreshResult>? _refreshTask;
  String? _refreshError;
  Object get _refreshScope => (widget.source, widget.mode);

  Future<PullRefreshResult> _refresh() {
    final pending = _refreshTask;
    if (pending != null) {
      return pending;
    }
    final task = _refreshNow();
    _refreshTask = task;
    return task.whenComplete(() {
      if (identical(_refreshTask, task)) {
        _refreshTask = null;
      }
    });
  }

  Future<PullRefreshResult> _refreshNow() async {
    final scope = _refreshScope;
    setState(() => _refreshError = null);
    try {
      final refresh = widget.onRefreshWithResult;
      if (refresh != null) return await refresh();
      await widget.onRefresh!();
    } catch (error) {
      if (mounted && _refreshScope == scope) {
        setState(() => _refreshError = userFacingErrorMessage(error));
      }
    }
    return PullRefreshResult.ignored;
  }

  void _toggleCategory(
    String category,
    Set<String> blocked,
    ValueChanged<Set<String>> change,
  ) {
    final wasBlocked = blocked.contains(category);
    final next = {...blocked};
    wasBlocked ? next.remove(category) : next.add(category);
    change(next);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          wasBlocked
              ? '已恢复「${convertChineseForDisplay(category)}」'
              : '已屏蔽「${convertChineseForDisplay(category)}」· 再点恢复',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  List<UnifiedComicListItem> _sortedEntries() {
    final visible = widget.entries.toList();
    if (widget.mode == ShelfPageMode.history &&
        (_sort == 'new' || _sort == 'old')) {
      final ranks = {
        for (var index = 0; index < visible.length; index++)
          visible[index]: index,
      };
      DateTime? readAt(UnifiedComicListItem item) {
        final value = item.raw['lastReadAt'];
        return value is String && formatSourceComicTimestamp(value).isNotEmpty
            ? DateTime.tryParse(value)
            : null;
      }

      visible.sort((a, b) {
        final first = readAt(a), second = readAt(b);
        if (first == null || second == null) {
          return first == second
              ? ranks[a]!.compareTo(ranks[b]!)
              : first == null
              ? 1
              : -1;
        }
        final order = _sort == 'old'
            ? first.compareTo(second)
            : second.compareTo(first);
        return order == 0 ? ranks[a]!.compareTo(ranks[b]!) : order;
      });
      return visible;
    }
    switch (_sort) {
      case 'old':
        return visible.reversed.toList();
      case 'likes':
        visible.sort((a, b) => b.likesCount.compareTo(a.likesCount));
      case 'views':
        visible.sort((a, b) => b.viewsCount.compareTo(a.viewsCount));
    }
    return visible;
  }

  @override
  Widget build(BuildContext context) {
    if (_compact) {
      return SourceListPresentation(
        source:
            widget.source ??
            (widget.entries.map((e) => e.source).toSet().length == 1
                ? widget.entries.first.source
                : ''),
        detailedByDefault: true,
        builder: (context, detailed, selectView) =>
            _buildFilter(context, detailed, selectView),
      );
    }
    return _buildFilter(
      context,
      _detailed,
      (value) => setState(() => _detailed = value),
    );
  }

  Widget _buildFilter(
    BuildContext context,
    bool detailed,
    ValueChanged<bool> selectView,
  ) {
    final sources = widget.entries.map((entry) => entry.source).toSet().toList()
      ..sort();
    final scope =
        '${widget.source ?? sources.join(',')}|profile:${widget.mode.name}';
    return SourceCategoryBlockScope(
      scope: scope,
      builder: (context, blocked, onBlockedChanged) => SourceLoadedResultFilter(
        compactControls: true,
        searchController: _compact ? _jmSearch : null,
        searchFocusNode: _compact ? _jmSearchFocus : null,
        searchExpanded: !_compact || _jmSearchOpen,
        focusedFacets: _compact,
        chromeBuilder: _compact
            ? (context, chrome) => _jmChrome(
                context,
                chrome,
                blocked,
                onBlockedChanged,
                detailed,
                selectView,
              )
            : null,
        entries: _sortedEntries(),
        blockedCategories: blocked,
        scope: scope,
        builder: (context, visible, controls) => _buildRecords(
          context,
          visible,
          controls,
          blocked,
          onBlockedChanged,
          detailed,
          selectView,
        ),
      ),
    );
  }

  Widget _jmChrome(
    BuildContext context,
    SourceLoadedResultChrome chrome,
    Set<String> blocked,
    ValueChanged<Set<String>> onBlockedChanged,
    bool detailed,
    ValueChanged<bool> selectView,
  ) {
    final mode = widget.mode, source = widget.source;
    final sortOptions = {
      'new': '最新',
      'old': '最早',
      if (widget.entries.any((entry) => entry.likesCount > 0)) 'likes': '最多喜欢',
      if (widget.entries.any((entry) => entry.viewsCount > 0)) 'views': '最多观看',
    };
    final sources = {
      if (widget.source != null) widget.source!,
      ...widget.entries.map((entry) => entry.source),
    };
    final categories =
        {for (final source in sources) ...sourceQuickCategories(source)}.where(
          (category) => widget.entries.any(
            (entry) => isEntryBlockedByCategory(entry, {category}),
          ),
        );
    final categoryActions = {
      for (final category in categories)
        'category.${Uri.encodeComponent(category)}': category,
    };
    final options = {
      for (final entry in sortOptions.entries) 'sort.${entry.key}': entry.value,
      collectionCoverSettingsAction: collectionCoverSettingsLabel(context),
      for (final entry in categoryActions.entries)
        entry.key:
            '${blocked.contains(entry.value) ? '恢复' : '屏蔽'} ${convertChineseForDisplay(entry.value)}',
      if (blocked.isNotEmpty) 'clear-blocked': '清除屏蔽 (${blocked.length})',
      if (widget.onManageFolders != null)
        'folders': t.videoSource.manageFolders,
    };
    final navigation = JmCollectionNavigationActions(
      keyPrefix: 'jm-record',
      inlineSearch: true,
      searching: _jmSearchOpen,
      selected: 'sort.$_sort',
      options: options,
      onSearch: () {
        if (!mounted) return;
        final accountGeneration = pluginSessionWriteFence.generation(
          source ?? '',
        );
        setState(() {
          _jmSearchOpen = !_jmSearchOpen;
          if (!_jmSearchOpen) {
            _jmSearchFocus.unfocus();
          }
        });
        if (_jmSearchOpen && widget.jmHeaderController == null)
          requestSearchKeyboard(
            _jmSearchFocus,
            isCurrent: () =>
                mounted &&
                _jmSearchOpen &&
                widget.mode == mode &&
                widget.source == source &&
                !pluginSessionWriteFence.isChanging(source ?? '') &&
                pluginSessionWriteFence.generation(source ?? '') ==
                    accountGeneration &&
                ModalRoute.of(context)?.isCurrent != false,
          );
      },
      groups: [
        [for (final key in sortOptions.keys) 'sort.$key'],
        [collectionCoverSettingsAction],
        [
          for (final key in [
            ...categoryActions.keys,
            'clear-blocked',
            'folders',
          ])
            if (options.containsKey(key)) key,
        ],
      ],
      onSelected: (value) {
        if (!mounted || widget.mode != mode || widget.source != source) return;
        if (value.startsWith('sort.') &&
            sortOptions.containsKey(value.substring(5)))
          setState(() => _sort = value.substring(5));
        else if (categoryActions[value] case final category?)
          _toggleCategory(category, blocked, onBlockedChanged);
        else if (value == 'clear-blocked')
          onBlockedChanged({});
        else if (value == 'folders')
          widget.onManageFolders?.call();
        else if (value == collectionCoverSettingsAction)
          unawaited(openCollectionCoverSettings(context));
      },
    );
    final controller = widget.jmHeaderController;
    if (controller != null) {
      final signature =
          '${widget.source}|${widget.mode}|$_jmSearchOpen|${_jmSearch.text.isEmpty}|$_sort|$detailed|${options.entries.join('|')}';
      if (_jmHeaderSignature != signature) {
        _jmHeaderSignature = signature;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              identical(widget.jmHeaderController, controller) &&
              _jmHeaderSignature == signature) {
            final opening = _jmSearchOpen && controller.searchField == null;
            controller.publish(
              _jmHeaderOwner,
              navigation,
              searchField: _jmSearchOpen ? chrome.searchField : null,
            );
            if (opening) {
              final generation = pluginSessionWriteFence.generation(
                source ?? '',
              );
              requestSearchKeyboard(
                _jmSearchFocus,
                isCurrent: () =>
                    mounted &&
                    _jmSearchOpen &&
                    widget.mode == mode &&
                    widget.source == source &&
                    identical(widget.jmHeaderController, controller) &&
                    !pluginSessionWriteFence.isChanging(source ?? '') &&
                    pluginSessionWriteFence.generation(source ?? '') ==
                        generation &&
                    ModalRoute.of(context)?.isCurrent != false,
              );
            }
          }
        });
      }
    }
    return Column(
      key: const ValueKey('profile-record-controls'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller == null)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: SizedBox(
              height: (MediaQuery.textScalerOf(context).scale(14) * 1.5 + 20)
                  .clamp(56.0, double.infinity),
              child: Row(
                children: [
                  if (widget.showBackButton)
                    SourceChromeIconButton(
                      icon: Icons.chevron_left_rounded,
                      symbol: 'chevron.left',
                      tooltip: t.common.back,
                      onPressed: widget.onBack,
                    ),
                  Expanded(
                    child: _jmSearchOpen
                        ? chrome.searchField
                        : Text(
                            sourceProfileRecordLabel(widget.mode),
                            maxLines: 2,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                  ),
                  navigation,
                ],
              ),
            ),
          ),
        JmCollectionResultsRow(
          key: const ValueKey('jm-record-tools'),
          countKey: const ValueKey('jm-record-count'),
          countLabel: jmCollectionCountLabel(
            complete: chrome.complete,
            shown: chrome.shown,
            loaded: chrome.total,
            knownTotal: chrome.knownTotal,
          ),
          filterButton: chrome.filterButton,
          viewAction: SourceListViewToggle(
            key: const ValueKey('jm-record-view'),
            detailed: detailed,
            onChanged: selectView,
          ),
        ),
        if (chrome.appliedFilters != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: chrome.appliedFilters!,
          ),
      ],
    );
  }

  Widget _buildRecords(
    BuildContext context,
    List<UnifiedComicListItem> visibleEntries,
    Widget controls,
    Set<String> blocked,
    ValueChanged<Set<String>> onBlockedChanged,
    bool detailed,
    ValueChanged<bool> selectView,
  ) {
    final sources = {
      if (widget.source != null) widget.source!,
      ...widget.entries.map((entry) => entry.source),
    };
    final categories = sources
        .expand(sourceQuickCategories)
        .toSet()
        .where(
          (category) => widget.entries.any(
            (entry) => isEntryBlockedByCategory(entry, {category}),
          ),
        )
        .toList();
    final sortOptions = {
      'new': '最新',
      'old': '最早',
      if (widget.entries.any((entry) => entry.likesCount > 0)) 'likes': '最多喜欢',
      if (widget.entries.any((entry) => entry.viewsCount > 0)) 'views': '最多观看',
    };
    final categoryActions = {
      for (final category in categories)
        'category.${Uri.encodeComponent(category)}': category,
    };
    final mode = widget.mode, source = widget.source;
    return CollectionCoverPrivacyScope(
      child: CollectionCoverFitScope(
        child: Column(
          children: [
            if (!_compact)
              BookshelfContentToolbar(
                key: const ValueKey('profile-record-controls'),
                keyPrefix: 'profile-record',
                title: sourceProfileRecordLabel(widget.mode),
                // The search/filter row already shows the complete local count.
                subtitle: sortOptions[_sort] ?? '',
                view: detailed
                    ? BookshelfContentView.list
                    : BookshelfContentView.grid,
                onBack: widget.showBackButton ? widget.onBack : null,
                onToggleView: () => selectView(!detailed),
                onManage: null,
                privacyAction: const CollectionCoverPrivacyButton(),
                moreOptions: {
                  for (final entry in sortOptions.entries)
                    'sort.${entry.key}': entry.value,
                  for (final entry in categoryActions.entries)
                    entry.key:
                        '${blocked.contains(entry.value) ? '恢复' : '屏蔽'} ${convertChineseForDisplay(entry.value)}',
                  if (blocked.isNotEmpty)
                    'clear-blocked': '清除屏蔽 (${blocked.length})',
                  if (widget.onManageFolders != null)
                    'folders': t.videoSource.manageFolders,
                },
                moreGroups: [
                  [for (final key in sortOptions.keys) 'sort.$key'],
                  [...categoryActions.keys, 'clear-blocked'],
                  if (widget.onManageFolders != null) ['folders'],
                ],
                onMore: (value) {
                  if (!mounted ||
                      widget.mode != mode ||
                      widget.source != source)
                    return;
                  if (value.startsWith('sort.') &&
                      sortOptions.containsKey(value.substring(5))) {
                    setState(() => _sort = value.substring(5));
                  } else if (categoryActions[value] case final category?) {
                    _toggleCategory(category, blocked, onBlockedChanged);
                  } else if (value == 'clear-blocked') {
                    onBlockedChanged({});
                  } else if (value == 'folders') {
                    widget.onManageFolders?.call();
                  }
                },
              ),
            controls,
            const Divider(height: 1),
            if (_refreshError != null || widget.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: Text(_refreshError ?? widget.error!)),
                    TextButton.icon(
                      onPressed: _refreshTask != null
                          ? null
                          : () => _refreshIndicator.currentState?.show(),
                      icon: const Icon(Icons.refresh),
                      label: Text(t.common.retry),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: PullRefreshFeedback.indicator(
                indicatorKey: _refreshIndicator,
                active: ReadRecoveryScope.activeOf(context),
                scope: _refreshScope,
                onRefresh: _refresh,
                child: visibleEntries.isEmpty
                    ? CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Center(
                                child: Text(
                                  widget.entries.isEmpty
                                      ? '暂无${sourceProfileRecordLabel(widget.mode)}的漫画'
                                      : '当前筛选没有匹配的漫画',
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : detailed
                    ? ListView.builder(
                        key: const ValueKey('profile-detailed-list'),
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.only(
                          bottom: NativeNavigationInset.scrollBottom(context),
                        ),
                        itemCount: visibleEntries.length,
                        itemBuilder: (context, index) => WorkListRow(
                          divided: index + 1 < visibleEntries.length,
                          inset: 12,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: _recordTile(
                              visibleEntries[index],
                              detailed: true,
                            ),
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) => GridView.builder(
                          key: const ValueKey('profile-cover-grid'),
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            12,
                            8,
                            12,
                            NativeNavigationInset.scrollBottom(context) + 12,
                          ),
                          gridDelegate: BookshelfContentLayout.gridDelegate(
                            context,
                            constraints.maxWidth,
                          ),
                          itemCount: visibleEntries.length,
                          itemBuilder: (context, index) => _recordTile(
                            visibleEntries[index],
                            detailed: false,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordTile(UnifiedComicListItem entry, {required bool detailed}) {
    final info = entry.toSimplifyEntryInfo();
    final readTime = widget.mode == ShelfPageMode.history
        ? comicLastReadTimestamp(entry)
        : '';
    final page = entry.raw['pageIndex'];
    final progress = widget.mode == ShelfPageMode.history
        ? shelfReadingPosition(
            entry.title,
            entry.subtitle,
            page is int ? page : -1,
          )
        : '';
    return ComicSimplifyEntry(
      key: ValueKey('profile-record.${entry.source}:${entry.id}'),
      info: info,
      type: _entryType(widget.mode),
      refresh: () => unawaited(_refresh()),
      horizontal: detailed,
      coverAspectRatio: BookshelfContentLayout.coverAspectRatio,
      caption: detailed
          ? BookshelfDetailedCaption(
              title: convertChineseForDisplay(info.title),
              source: widget.sourceName,
              metadata: info.detailMetadata,
              description: info.description,
              progress: progress,
              time: readTime.isEmpty
                  ? ''
                  : t.comicEntry.lastReadAt(time: readTime),
            )
          : BookshelfCardCaption(
              title: convertChineseForDisplay(info.title),
              subtitle: widget.sourceName,
            ),
      onTapOverride: (info) async {
        final mode = widget.mode, source = widget.source;
        await context.pushRoute(
          ComicInfoRoute(
            comicId: info.id,
            type: _entryType(mode),
            from: info.source.trim().isEmpty ? info.from : info.source,
          ),
        );
        if (mounted && widget.mode == mode && widget.source == source)
          await _refresh();
      },
    );
  }
}

/// Shared responsive heading for comic and video profile previews.
class SourceProfilePreviewHeader extends StatelessWidget {
  const SourceProfilePreviewHeader({
    super.key,
    required this.previewKey,
    required this.title,
    required this.icon,
    required this.hasEntries,
    required this.expanded,
    required this.onToggle,
    required this.onViewAll,
    this.countLabel,
  });
  final Key previewKey;
  final String title;
  final IconData icon;
  final bool hasEntries, expanded;
  final VoidCallback onToggle, onViewAll;
  final String? countLabel;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700);
    final countStyle = DefaultTextStyle.of(context).style.copyWith(
      color: colors.onSurfaceVariant,
      fontSize: Theme.of(context).textTheme.bodySmall?.fontSize,
    );
    final titleText = Text(
      title,
      style: titleStyle,
      key: ValueKey(('profile-title', previewKey)),
    );
    final countText = countLabel == null
        ? null
        : Text(
            countLabel!,
            style: countStyle,
            key: ValueKey(('profile-count', previewKey)),
          );
    final iconWidget = SizedBox(
      key: ValueKey(('profile-icon', previewKey)),
      width: 20,
      child: Icon(icon, size: 20, color: colors.primary),
    );
    final actionKey = ValueKey(('profile-view-all', previewKey));
    final actionStyle = TextButton.styleFrom(
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
    TextButton viewAll(ButtonStyle style) => TextButton(
      key: actionKey,
      onPressed: onViewAll,
      style: style,
      child: Text(t.videoPersonal.viewAll),
    );
    final action = TouchHoverIntent(
      identity: actionKey,
      builder: (_, hover) => viewAll(
        actionStyle.copyWith(
          overlayColor: hover.overlayColor(actionStyle.overlayColor),
        ),
      ),
    );
    final toggleKey = ValueKey((
      hasEntries ? 'profile-toggle' : 'profile-open',
      previewKey,
    ));
    final toggle = TouchHoverIntent(
      identity: toggleKey,
      builder: (_, hover) {
        final button = IconButton(
          key: toggleKey,
          tooltip: title,
          onPressed: hasEntries ? onToggle : onViewAll,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          hoverColor: hover.hoverColor(),
          style: ButtonStyle(overlayColor: hover.overlayColor(null)),
          icon: hasEntries
              ? VideoDisclosureIndicator(expanded: expanded)
              : const Icon(Icons.chevron_right_rounded),
        );
        if (!hasEntries) return button;
        return Semantics(
          button: true,
          expanded: expanded,
          label: title,
          excludeSemantics: true,
          onTap: onToggle,
          child: button,
        );
      },
    );
    final defaults = viewAll(actionStyle).defaultStyleOf(context);
    final buttonTheme = TextButtonTheme.of(context).style;
    const states = <WidgetState>{};
    final padding =
        actionStyle.padding?.resolve(states) ??
        buttonTheme?.padding?.resolve(states) ??
        defaults.padding?.resolve(states) ??
        EdgeInsets.zero;
    final minimum =
        actionStyle.minimumSize?.resolve(states) ??
        buttonTheme?.minimumSize?.resolve(states) ??
        defaults.minimumSize?.resolve(states) ??
        Size.zero;
    double textWidth(String text, TextStyle? style) => TextPainter.computeWidth(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    final actionWidth = math.max(
      minimum.width,
      textWidth(
            t.videoPersonal.viewAll,
            buttonTheme?.textStyle?.resolve(states) ??
                defaults.textStyle?.resolve(states),
          ) +
          padding.horizontal,
    );
    final requiredWidth =
        28 +
        textWidth(title, titleStyle) +
        (countLabel == null ? 0 : textWidth(countLabel!, countStyle) + 6) +
        actionWidth +
        44;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (requiredWidth <= constraints.maxWidth) {
          return Row(
            children: [
              iconWidget,
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(child: titleText),
                    if (countText != null) ...[
                      const SizedBox(width: 6),
                      countText,
                    ],
                  ],
                ),
              ),
              action,
              toggle,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                iconWidget,
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 2,
                    children: [titleText, ?countText],
                  ),
                ),
                toggle,
              ],
            ),
            Align(alignment: AlignmentDirectional.centerEnd, child: action),
          ],
        );
      },
    );
  }
}
