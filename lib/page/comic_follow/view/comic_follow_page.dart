import 'dart:async';

import 'package:zephyr/widgets/tab_reselect_scope.dart';
import 'package:zephyr/widgets/collection_cover_fit.dart';
import 'package:zephyr/widgets/work_list_divider.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart' show CupertinoColors;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/cubit/plugin_registry_cubit.dart';
import 'package:zephyr/network/http/plugin/qjs_network_route.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/comic_follow/cubit/comic_follow_cubit.dart';
import 'package:zephyr/page/comic_follow/view/follow_display.dart';
import 'package:zephyr/page/comic_follow/widgets/comic_follow_reminder_widgets.dart';
import 'package:zephyr/page/comic_follow/widgets/comic_follow_row_actions.dart';
import 'package:zephyr/page/search/widget/search_input_dialog.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/widget/keyword_scope_menu.dart';
import 'package:zephyr/page/search/widget/search_keyboard.dart';
import 'package:zephyr/page/search/widget/search_toolbar_scope.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/text/public_search_text.dart';
import 'package:zephyr/util/json/shelf_metadata_fields.dart';
import 'package:zephyr/widgets/breeze_theme_colors.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';
import 'package:zephyr/widgets/comic_simplify_entry/cover.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/widgets/collection_cover_settings.dart';
import 'package:zephyr/widgets/collection_press_feedback.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/error_view.dart';
import 'package:zephyr/widgets/pull_refresh_feedback.dart';
import 'package:zephyr/widgets/short_alert.dart';
import 'package:zephyr/widgets/toast.dart';

const _followContentWidth = 768.0;
const _followContentInset = 16.0;

String _followSourceName(String source) {
  final info = PluginRegistryService.I.getCachedPluginInfo(source);
  final name = info?['name']?.toString().trim() ?? '';
  return name.isNotEmpty ? name : t.bookshelf.unknownSource;
}

@RoutePage()
class ComicFollowPage extends StatefulWidget {
  const ComicFollowPage({
    super.key,
    this.embedded = false,
    this.active = true,
    this.openSwipe,
  });

  final bool embedded, active;
  final ValueNotifier<String?>? openSwipe;

  @override
  State<ComicFollowPage> createState() => _ComicFollowPageState();
}

class _ComicFollowPageState extends State<ComicFollowPage>
    with WidgetsBindingObserver, AutoRouteAwareStateMixin<ComicFollowPage> {
  ValueNotifier<String?>? _localOpenRow;
  ValueNotifier<String?> get _openRow =>
      widget.openSwipe ?? (_localOpenRow ??= ValueNotifier<String?>(null));
  ComicFollowCubit? _cubit;
  bool _routeVisible = true, _active = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    if (context.findAncestorWidgetOfExactType<RouteDataScope>() != null &&
        context.findAncestorWidgetOfExactType<RouterScope>() != null) {
      super.didChangeDependencies();
    }
    _cubit = context.read<ComicFollowCubit>();
    final routeCurrent = ModalRoute.isCurrentOf(context) ?? true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateActivity(routeCurrent: routeCurrent);
    });
  }

  @override
  void didUpdateWidget(covariant ComicFollowPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateActivity();
      });
    }
  }

  void _updateActivity({bool? routeCurrent, bool requestCheck = true}) {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final visible = routeCurrent ?? (ModalRoute.isCurrentOf(context) ?? true);
    final active =
        widget.active &&
        _routeVisible &&
        visible &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
    if (!active) _openRow.value = null;
    if (_active == active) return;
    _active = active;
    _cubit?.setPageCheckingActive(this, active);
    if (active) {
      unawaited(_cubit!.refreshHistories());
      if (requestCheck) unawaited(_checkDue());
    }
  }

  Future<void> _checkDue() async {
    try {
      await _cubit!.checkDueUpdates();
    } catch (_) {
      /* Existing rows keep their per-item failure feedback. */
    }
  }

  @override
  void didPushNext() {
    _routeVisible = false;
    _updateActivity();
  }

  @override
  void didPopNext() {
    _routeVisible = true;
    _updateActivity();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _updateActivity(requestCheck: false);

  @override
  void dispose() {
    _cubit?.setPageCheckingActive(this, false);
    _localOpenRow?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ComicFollowPageContent(embedded: widget.embedded, openRow: _openRow);
}

/// Foreground-only update checks keep the detailed list and reading position.
class _ComicFollowPageContent extends StatefulWidget {
  const _ComicFollowPageContent({
    required this.embedded,
    required this.openRow,
  });

  final bool embedded;
  final ValueNotifier<String?> openRow;

  @override
  State<_ComicFollowPageContent> createState() =>
      _ComicFollowPageContentState();
}

class _ComicFollowPageContentState extends State<_ComicFollowPageContent> {
  final _searchFocus = FocusNode();
  final _scroll = ScrollController();
  final _normalizedSearch = <(String, String, String, String), String>{};
  KeywordSearchScope _keywordScope = KeywordSearchScope.all;
  bool _searching = false;
  String _query = '';

  Future<void> _markAllRead() async {
    final cubit = context.read<ComicFollowCubit>();
    try {
      await cubit.markAllAsRead();
      if (mounted) showSuccessToast(t.comicFollow.markAllReadDone);
    } catch (_) {
      if (mounted) showErrorToast(t.common.loadingFailed);
    }
  }

  void _toggleSearch() {
    widget.openRow.value = null;
    if (_searching) {
      _searchFocus.unfocus();
      setState(() {
        _searching = false;
        _query = '';
      });
      return;
    }
    setState(() => _searching = true);
    requestSearchKeyboard(
      _searchFocus,
      isCurrent: () =>
          mounted && _searching && ModalRoute.of(context)?.isCurrent != false,
    );
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableWidth =
        MediaQuery.sizeOf(context).width -
        MediaQuery.paddingOf(context).horizontal;
    final outerInset = ((availableWidth - _followContentWidth) / 2).clamp(
      0.0,
      double.infinity,
    );
    final toolbarHeight = (MediaQuery.textScalerOf(context).scale(24) * 1.34)
        .clamp(60.0, double.infinity);
    return PopScope(
      canPop: !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _searching) _toggleSearch();
      },
      child: CollectionCoverPrivacyScope(
        child: Scaffold(
          appBar: SearchToolbarScope.appBar(
            context,
            (_) => AppBar(
              automaticallyImplyLeading: !widget.embedded && !_searching,
              leading: widget.embedded || _searching
                  ? null
                  : Padding(
                      padding: EdgeInsetsDirectional.only(start: outerInset),
                      child: TapRegion(
                        groupId: widget.openRow,
                        child: CollectionToolbarMetrics.leading(
                          context,
                          const SourceBackButton(),
                        ),
                      ),
                    ),
              leadingWidth:
                  CollectionToolbarMetrics.leadingExtentOf(context) +
                  outerInset,
              titleSpacing: widget.embedded || _searching
                  ? _followContentInset + outerInset
                  : 0,
              toolbarHeight: SearchToolbarScope.stableHeight(
                context,
                toolbarHeight,
              ),
              title: _searching
                  ? SearchQueryField(
                      key: const ValueKey('follow-search-input'),
                      onClose: _toggleSearch,
                      closeKey: const ValueKey('follow-search-toggle'),
                      query: _query,
                      inline: true,
                      animateExpansion: true,
                      focusNode: _searchFocus,
                      leadingControlWidth: KeywordScopeMenu.leadingWidth(
                        context,
                      ),
                      leadingControl: KeywordScopeMenu(
                        compact: true,
                        scope: _keywordScope,
                        onChanged: (scope) =>
                            setState(() => _keywordScope = scope),
                      ),
                      hintText: t.bookshelf.searchList,
                      semanticLabel: t.bookshelf.searchList,
                      onChanged: (value) => setState(() => _query = value),
                      onSubmitted: (_) => _searchFocus.unfocus(),
                    )
                  : Text(
                      t.comicFollow.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              scrolledUnderElevation: 0,
              actionsPadding: EdgeInsetsDirectional.only(
                end: outerInset + _followContentInset,
              ),
              actions: [
                if (!_searching)
                  BlocSelector<ComicFollowCubit, ComicFollowState, bool>(
                    selector: (state) => state.items.isNotEmpty,
                    builder: (context, hasItems) => hasItems || _searching
                        ? SourceChromeIconButton(
                            key: const ValueKey('follow-search-toggle'),
                            tooltip: _searching
                                ? t.common.close
                                : t.bookshelf.searchList,
                            icon: _searching
                                ? Icons.close_rounded
                                : Icons.search_rounded,
                            symbol: _searching ? 'xmark' : 'magnifyingglass',
                            onPressed: _toggleSearch,
                          )
                        : SizedBox(
                            width: CollectionToolbarMetrics.actionExtentOf(
                              context,
                            ),
                          ),
                  ),
                if (!_searching)
                  const CollectionCoverPrivacyButton(
                    key: ValueKey('follow-cover-privacy'),
                  ),
                if (!_searching) _FollowMoreButton(onMarkAllRead: _markAllRead),
              ],
            ),
            searching: _searching,
          ),
          body: SafeArea(
            top: false,
            bottom: false,
            child: BlocBuilder<ComicFollowCubit, ComicFollowState>(
              builder: (context, state) {
                switch (state.status) {
                  case ComicFollowStatus.initial:
                  case ComicFollowStatus.loading:
                    if (state.items.isNotEmpty) {
                      return _buildContent(context, state);
                    }
                    return const Center(child: CircularProgressIndicator());
                  case ComicFollowStatus.failure:
                    if (state.items.isNotEmpty || _searching) {
                      return _buildContent(context, state);
                    }
                    return ErrorView(
                      errorMessage: t.comicFollow.loadFailed,
                      onRetry: () =>
                          context.read<ComicFollowCubit>().loadFromDatabase(),
                    );
                  case ComicFollowStatus.success:
                    return _buildContent(context, state);
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyView(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none_outlined,
                size: 44,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              t.comicFollow.empty,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              t.comicFollow.emptyHint,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _withRefresh(
    BuildContext context,
    ComicFollowState state,
    Widget child,
  ) {
    final cubit = context.read<ComicFollowCubit>();
    return PullRefreshFeedback.indicator(
      scope: (state.filter, _query, _keywordScope),
      onRefresh: () async {
        try {
          final status = await cubit.checkUpdatesForRefresh();
          if (!mounted) return PullRefreshResult.ignored;
          return switch (status) {
            ComicFollowRefreshStatus.updated ||
            ComicFollowRefreshStatus.partial => PullRefreshResult.updated,
            ComicFollowRefreshStatus.incomplete => PullRefreshResult.retained,
            ComicFollowRefreshStatus.unchanged => PullRefreshResult.unchanged,
            ComicFollowRefreshStatus.ignored => PullRefreshResult.ignored,
          };
        } catch (_) {
          return PullRefreshResult.retained;
        }
      },
      child: child,
    );
  }

  Widget _scrollableEmpty(Widget child) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: child,
      ),
    ),
  );

  Widget _buildContent(BuildContext context, ComicFollowState state) {
    final keyword = normalizePublicSearchText(_query);
    final visibleItems = keyword.isEmpty
        ? state.visibleItems
        : state.visibleItems
              .where((item) {
                final all = _keywordScope == KeywordSearchScope.all;
                return _normalizedSearch
                    .putIfAbsent(
                      (
                        item.title,
                        all ? item.creator : '',
                        all ? item.description : '',
                        all ? item.metadata : '',
                      ),
                      () => normalizePublicSearchText(
                        all
                            ? [
                                item.title,
                                parseFollowCreatorName(item.creator) ?? '',
                                item.description,
                                ...shelfFacetFieldsFromMetadata(
                                  item.metadata,
                                ).values.expand((values) => values),
                              ].join(' ')
                            : item.title,
                      ),
                    )
                    .contains(keyword);
              })
              .toList(growable: false);
    final Widget list;
    if (visibleItems.isNotEmpty) {
      list = _FollowList(
        controller: widget.embedded ? _scroll : null,
        openRow: widget.openRow,
        items: visibleItems,
        state: state,
        scrollKey: PageStorageKey(('follow-list', keyword.isNotEmpty)),
        bottomPadding: widget.embedded
            ? _followContentInset + NativeNavigationInset.scrollBottom(context)
            : 88,
      );
    } else if (keyword.isNotEmpty) {
      list = _scrollableEmpty(
        Center(child: Text(t.bookshelf.facets.noResults)),
      );
    } else if (state.items.isEmpty) {
      list = _scrollableEmpty(_buildEmptyView(context));
    } else {
      list = _scrollableEmpty(_buildFilteredEmptyView(context, state));
    }
    // 桌面端窄栏居中：与 more/plugin_store 等页一致，Align + 768 上限，
    // 摘要条/筛选行/列表整体收进同一栏，不再全宽拉伸。
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _followContentWidth),
        child: Column(
          children: [
            _FollowToolbar(state: state),
            Expanded(
              child: TabReselectListener(
                enabled: widget.embedded,
                onReselect: () =>
                    TabReselectScope.scrollToStart(context, _scroll),
                child: _withRefresh(context, state, list),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilteredEmptyView(BuildContext context, ComicFollowState state) {
    final scheme = Theme.of(context).colorScheme;
    final incomplete = context.read<ComicFollowCubit>().incompleteCheckCount;
    final checking = state.isCheckingUpdates;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            checking
                ? Icons.sync_outlined
                : incomplete > 0
                ? Icons.info_outline
                : Icons.check_circle_outline,
            size: 56,
            color: scheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            checking
                ? t.comicFollow.checkingUpdates
                : incomplete > 0
                ? t.comicFollow.checkIncomplete(count: incomplete)
                : t.comicFollow.noUnread,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.read<ComicFollowCubit>().setFilter(
              ComicFollowFilter.all,
            ),
            child: Text(t.comicFollow.showAll),
          ),
        ],
      ),
    );
  }
}

class _FollowMoreButton extends StatelessWidget {
  const _FollowMoreButton({required this.onMarkAllRead});

  static const _reminderSettings = 'reminder-settings';
  static const _markAllRead = 'mark-all-read';
  final VoidCallback onMarkAllRead;

  @override
  Widget build(BuildContext context) =>
      BlocSelector<ComicFollowCubit, ComicFollowState, bool>(
        selector: (state) => state.updateCount > 0 && !state.isCheckingUpdates,
        builder: (context, canMarkAllRead) => VideoControlAppearance(
          systemControls: usesNativeSourceChrome(context),
          child: NativeVideoMenu(
            key: const ValueKey('follow-more'),
            width: CollectionToolbarMetrics.actionExtentOf(context),
            label: '',
            tooltip: t.common.more,
            selected: '',
            icon: Icons.more_horiz,
            symbol: 'ellipsis',
            hostPresentation: true,
            selectAfterDismissal: const {
              collectionCoverSettingsAction,
              _reminderSettings,
              _markAllRead,
            },
            options: {
              collectionCoverSettingsAction: collectionCoverSettingsLabel(
                context,
              ),
              _reminderSettings: t.followReminders.title,
              if (canMarkAllRead) _markAllRead: t.comicFollow.markAllReadHint,
            },
            optionIcons: const {
              collectionCoverSettingsAction: (
                icon: Icons.visibility_off_outlined,
                symbol: 'eye.slash',
              ),
              _reminderSettings: (
                icon: Icons.notifications_outlined,
                symbol: 'bell',
              ),
              _markAllRead: (
                icon: Icons.done_all_outlined,
                symbol: 'checkmark.circle',
              ),
            },
            onSelected: (value) {
              if (!context.mounted) return;
              switch (value) {
                case collectionCoverSettingsAction:
                  unawaited(openCollectionCoverSettings(context));
                case _reminderSettings:
                  unawaited(showComicFollowReminderSettings(context));
                case _markAllRead:
                  final state = context.read<ComicFollowCubit>().state;
                  if (state.updateCount > 0 && !state.isCheckingUpdates) {
                    onMarkAllRead();
                  }
              }
            },
          ),
        ),
      );
}

/// One filter and one sort. Status belongs to the row being checked; the
/// toolbar never reports “no updates” while a previous result is still shown.
class _FollowToolbar extends StatelessWidget {
  const _FollowToolbar({required this.state});
  final ComicFollowState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ComicFollowCubit>();
    final systemControls = usesNativeSourceChrome(context);
    final statuses = {
      ComicFollowFilter.all.name: t.common.all,
      ComicFollowFilter.unread.name: t.comicFollow.unread,
    };
    final sorts = {
      ComicFollowSort.lastRead.name: t.comicFollow.lastRead,
      ComicFollowSort.recentUpdate.name: t.comicFollow.recentUpdate,
      ComicFollowSort.update.name: t.comicFollow.lastUpdate,
    };
    final sortLabel = sorts[state.sort.name]!;
    Widget sort({required bool showLabel, required double width}) =>
        VideoControlAppearance(
          systemControls: systemControls,
          child: NativeVideoMenu(
            key: const ValueKey('follow-sort'),
            bare: true,
            label: showLabel ? sortLabel : '',
            tooltip: '${t.comicFollow.sort} · $sortLabel',
            selected: state.sort.name,
            options: sorts,
            width: showLabel
                ? width
                : CollectionToolbarMetrics.actionExtentOf(context),
            hostPresentation: true,
            icon: showLabel ? null : Icons.swap_vert_rounded,
            symbol: showLabel ? '' : 'arrow.up.arrow.down',
            compactTextChoice: showLabel,
            onSelected: (value) {
              if (value != state.sort.name) {
                cubit.setSort(ComicFollowSort.values.byName(value));
              }
            },
          ),
        );
    final labelPainter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    );
    double sortLabelWidth = 0;
    for (final label in sorts.values) {
      labelPainter.text = TextSpan(
        text: label,
        style: Theme.of(context).textTheme.labelLarge,
      );
      labelPainter.layout();
      if (labelPainter.width > sortLabelWidth) {
        sortLabelWidth = labelPainter.width;
      }
    }
    labelPainter.dispose();
    final labeledSortWidth = sortLabelWidth.ceilToDouble() + 38;
    return Padding(
      padding: CollectionToolbarMetrics.contentPaddingOf(
        context,
        inset: _followContentInset,
        bottom: 4,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final actionExtent = CollectionToolbarMetrics.actionExtentOf(context);
          const gap = 8.0;
          final segmentWidth =
              NativeVideoSegmentedControl.minimumHorizontalWidth(
                context,
                statuses.values,
              ).ceilToDouble();
          final filter = VideoControlAppearance(
            systemControls: systemControls,
            child: NativeVideoSegmentedControl(
              key: const ValueKey('follow-filter'),
              options: statuses,
              selected: state.filter.name,
              onSelected: (value) =>
                  cubit.setFilter(ComicFollowFilter.values.byName(value)),
            ),
          );
          final hasLabeledSort =
              constraints.maxWidth >= segmentWidth + labeledSortWidth + gap;
          final sortControl = ConstrainedBox(
            constraints: BoxConstraints(minHeight: actionExtent),
            child: sort(showLabel: hasLabeledSort, width: labeledSortWidth),
          );
          if (constraints.maxWidth >= segmentWidth + actionExtent + gap) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(width: segmentWidth, child: filter),
                sortControl,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              filter,
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: sortControl,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 单列列表：最大宽度约束居中。
class _FollowList extends StatelessWidget {
  const _FollowList({
    required this.controller,
    required this.openRow,
    required this.items,
    required this.state,
    required this.scrollKey,
    required this.bottomPadding,
  });

  final ScrollController? controller;
  final ValueNotifier<String?> openRow;
  final List<ComicFollow> items;
  final ComicFollowState state;
  final PageStorageKey<(String, bool)> scrollKey;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ComicFollowCubit>();
    // 外层已用 ConstrainedBox(768) 居中，这里只留固定边距。
    final list = ListView.separated(
      key: scrollKey,
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsetsDirectional.fromSTEB(
        _followContentInset,
        8,
        _followContentInset,
        bottomPadding,
      ),
      itemCount: items.length,
      separatorBuilder: (_, _) => const WorkListDivider(height: 10),
      itemBuilder: (context, index) {
        final follow = items[index];
        final history = state.historyFor(follow);
        return _FollowCard(
          key: ValueKey(follow.uniqueKey),
          follow: follow,
          openRow: openRow,
          history: history,
          hasUnreadUpdate: state.hasUnreadUpdate(follow),
          unreadChapterCount: state.unreadChapterCount(follow),
          checking: state.checkingKeys.contains(follow.uniqueKey),
          checkDeferred: cubit.isCheckDeferred(follow),
          failure: state.checkErrors[follow.uniqueKey],
        );
      },
    );
    return NotificationListener<ScrollStartNotification>(
      onNotification: (notification) {
        if (notification.dragDetails != null) openRow.value = null;
        return false;
      },
      child: list,
    );
  }
}

class _FollowCard extends StatelessWidget {
  const _FollowCard({
    super.key,
    required this.follow,
    required this.openRow,
    required this.history,
    required this.hasUnreadUpdate,
    required this.unreadChapterCount,
    required this.checking,
    required this.checkDeferred,
    this.failure,
  });

  final ComicFollow follow;
  final ValueNotifier<String?> openRow;
  final UnifiedComicHistory? history;
  final bool hasUnreadUpdate;
  final int unreadChapterCount;
  final bool checking;
  final bool checkDeferred;
  final ComicFollowCheckFailure? failure;

  // Use the bookshelf frame as the minimum; follow cards can grow to 96×144.
  static const _minimumCoverWidth = 80.0;
  static const _maximumCoverWidth = 96.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cover = resolveFollowCover(follow);

    return ComicFollowRowActions(
      rowKey: follow.uniqueKey,
      openRow: openRow,
      onMarkRead: hasUnreadUpdate ? () => _markRead(context) : null,
      onUnfollow: () => _confirmUnfollow(context),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashFactory: NoSplash.splashFactory,
          highlightColor: CollectionPressFeedback.surfaceHighlight(context),
          onTap: () {
            openRow.value = null;
            unawaited(_openDetail(context));
          },
          onLongPress: () => openRow.value = follow.uniqueKey,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final coverWidth = (constraints.maxWidth / 4).clamp(
                      _minimumCoverWidth,
                      _maximumCoverWidth,
                    );
                    final coverHeight = coverWidth / (2 / 3);
                    final textWidth = constraints.maxWidth - coverWidth - 12;
                    final chaptersBelow =
                        textWidth < MediaQuery.textScalerOf(context).scale(150);
                    final identity = Column(
                      key: ValueKey('follow-identity-${follow.uniqueKey}'),
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTitleRow(theme),
                        const SizedBox(height: 4),
                        _buildSourceLine(theme),
                      ],
                    );
                    final chapters = Column(
                      key: ValueKey('follow-chapters-${follow.uniqueKey}'),
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLatestLine(theme),
                        const SizedBox(height: 6),
                        _buildReadingLine(theme),
                        _buildActivity(context, theme),
                      ],
                    );
                    final body = Row(
                      crossAxisAlignment: chaptersBelow
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.start,
                      children: [
                        _buildCover(cover, coverWidth, coverHeight),
                        const SizedBox(width: 12),
                        Expanded(
                          child: chaptersBelow
                              ? identity
                              : ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: coverHeight,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      identity,
                                      const SizedBox(height: 8),
                                      chapters,
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    );
                    // Keep the cover's ancestry stable across width/text-size
                    // changes so the existing loader and protection layer live on.
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        body,
                        if (chaptersBelow) ...[
                          const SizedBox(height: 8),
                          chapters,
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _markRead(BuildContext context) async {
    try {
      final marked = await context.read<ComicFollowCubit>().markAsRead(follow);
      if (marked) showSuccessToast(t.sourceNotices.read);
    } catch (_) {
      if (context.mounted) showErrorToast(t.common.loadingFailed);
    }
  }

  Future<void> _confirmUnfollow(BuildContext context) async {
    final confirmed = await _askUnfollow(context);
    if (confirmed != true || !context.mounted) return;
    final removed = await context.read<ComicFollowCubit>().removeFollow(
      follow.source,
      follow.comicId,
      confirmedFollow: follow,
    );
    if (removed) showSuccessToast(t.comicFollow.unfollowed);
  }

  Widget _buildCover(UnifiedComicCover cover, double width, double height) =>
      CollectionCoverFitBuilder(
        builder: (context, fit) => Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CoverWidget(
                key: ValueKey('follow-cover-${follow.uniqueKey}'),
                fileServer: cover.url,
                path: cover.cachePath,
                id: follow.comicId,
                pictureType: PictureType.cover,
                from: follow.source,
                roundedCorner: false,
                width: width,
                height: height,
                fit: fit,
                containBackground: true,
              ),
            ),
            if (hasUnreadUpdate)
              PositionedDirectional(
                top: -4,
                start: -4,
                child: ComicFollowReminderBadge(
                  child: IgnorePointer(
                    child: SizedBox.square(
                      key: ValueKey('follow-update-dot-${follow.uniqueKey}'),
                      dimension: 14,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemRed.resolveFrom(context),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _buildTitleRow(ThemeData theme) => Text(
    follow.title,
    key: ValueKey('follow-title-${follow.uniqueKey}'),
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
  );

  String get _chapterSummary {
    final title = follow.detectedChapterTitle.trim();
    final count = follow.detectedChapterCount;
    return title.isEmpty
        ? t.comicFollow.readProgressUnknown(total: count)
        : t.comicFollow.chapterSummary(count: count, chapter: title);
  }

  /// 来源插件名 + 作者，插件名走 getCachedPluginInfo（含 DB 兜底）。
  Widget _buildSourceLine(ThemeData theme) {
    final scheme = theme.colorScheme;
    return BlocSelector<
      PluginRegistryCubit,
      Map<String, PluginRuntimeState>,
      String
    >(
      selector: (_) => _pluginLabel(),
      builder: (context, pluginLabel) {
        final parts = [
          if (pluginLabel.isNotEmpty) pluginLabel,
          ?parseFollowCreatorName(follow.creator),
        ];
        if (parts.isEmpty) {
          return const SizedBox.shrink();
        }
        return Row(
          children: [
            Expanded(
              child: Text(
                parts.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _pluginLabel() => _followSourceName(follow.source);

  TextStyle? _latestStyle(ThemeData theme) =>
      theme.textTheme.bodyMedium?.copyWith(
        color: hasUnreadUpdate
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSurfaceVariant,
        fontWeight: hasUnreadUpdate ? FontWeight.w600 : FontWeight.normal,
      );

  Widget _buildLatestLine(ThemeData theme) {
    final latest = Text(
      _chapterSummary,
      key: ValueKey('follow-latest-${follow.uniqueKey}'),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: _latestStyle(theme),
    );
    if (!hasUnreadUpdate) return latest;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        latest,
        ComicFollowReminderBadge(
          child: _FollowUpdateBadge(
            key: ValueKey('follow-update-${follow.uniqueKey}'),
            count: unreadChapterCount,
          ),
        ),
      ],
    );
  }

  Widget _buildReadingLine(ThemeData theme) {
    final chapter = history?.chapterTitle.trim() ?? '';
    return Column(
      key: ValueKey('follow-reading-${follow.uniqueKey}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          chapter.isEmpty
              ? t.comicFollow.notRead
              : t.comicFollow.lastReadChapter(chapter: chapter),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildActivity(BuildContext context, ThemeData theme) {
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final actionExtent = CollectionToolbarMetrics.actionExtentOf(context);
    final readAt = history?.lastReadAt;
    return ConstrainedBox(
      key: ValueKey('follow-check-${follow.uniqueKey}'),
      constraints: BoxConstraints(minHeight: actionExtent),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        heightFactor: 1,
        child: checking
            ? _buildCheckingLabel(style)
            : follow.lastCheckFailed
            ? _buildCheckFailure(context, style)
            : checkDeferred
            ? _buildCheckFailureStatus(
                context,
                style,
                ComicFollowCheckFailure.sourceUnavailable,
              )
            : readAt == null
            ? null
            : Text(
                t.comicFollow.lastReadAt(time: formatFollowCheckTime(readAt)),
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
      ),
    );
  }

  Widget _buildCheckFailure(BuildContext context, TextStyle? style) {
    if (failure != ComicFollowCheckFailure.pluginDisabled &&
        failure != ComicFollowCheckFailure.pluginMissing) {
      return _buildCheckFailureStatus(
        context,
        style,
        failure ?? ComicFollowCheckFailure.unknown,
      );
    }

    final source = canonicalQjsSource(follow.source);
    return BlocSelector<
      PluginRegistryCubit,
      Map<String, PluginRuntimeState>,
      ComicFollowCheckFailure?
    >(
      selector: (plugins) {
        final plugin = plugins[source];
        if (plugin == null || plugin.isDeleted) {
          return ComicFollowCheckFailure.pluginMissing;
        }
        return plugin.isEnabled ? null : ComicFollowCheckFailure.pluginDisabled;
      },
      builder: (context, unavailable) =>
          _buildCheckFailureStatus(context, style, unavailable),
    );
  }

  Widget _buildCheckFailureStatus(
    BuildContext context,
    TextStyle? style,
    ComicFollowCheckFailure? reason,
  ) {
    final message = switch (reason) {
      ComicFollowCheckFailure.network => t.comicFollow.checkNetworkUnavailable,
      ComicFollowCheckFailure.sourceUnavailable =>
        t.comicFollow.checkSourceUnavailable,
      ComicFollowCheckFailure.invalidResponse =>
        t.comicFollow.checkInvalidResponse,
      ComicFollowCheckFailure.signInRequired =>
        t.comicFollow.checkSignInRequired,
      ComicFollowCheckFailure.notFound => t.comicFollow.checkComicNotFound,
      ComicFollowCheckFailure.pluginDisabled =>
        t.comicFollow.checkPluginDisabled,
      ComicFollowCheckFailure.pluginMissing => t.comicFollow.checkPluginMissing,
      ComicFollowCheckFailure.unknown => t.comicFollow.checkFailedReason,
      null => null,
    };
    final needsPlugin =
        reason == ComicFollowCheckFailure.pluginDisabled ||
        reason == ComicFollowCheckFailure.pluginMissing;
    final status = message == null
        ? null
        : Text(
            message,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
    if (needsPlugin) return status!;
    final actionExtent = CollectionToolbarMetrics.actionExtentOf(context);
    return Row(
      spacing: 8,
      children: [
        if (status != null) Flexible(child: status),
        TextButton(
          key: ValueKey('follow-retry-${follow.uniqueKey}'),
          style: TextButton.styleFrom(
            textStyle: Theme.of(context).textTheme.labelMedium,
            minimumSize: Size.square(actionExtent),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.standard,
          ),
          onPressed: () => _retry(context),
          child: Text(t.common.retry, maxLines: 1),
        ),
      ],
    );
  }

  Widget _buildCheckingLabel(TextStyle? style) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox.square(
        dimension: 14,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          t.comicFollow.checkingUpdates,
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );

  Future<void> _openDetail(BuildContext context) async {
    await context.pushRoute(
      ComicInfoRoute(
        comicId: follow.comicId,
        from: follow.source,
        type: ComicEntryType.normal,
      ),
    );
    if (context.mounted) {
      await context.read<ComicFollowCubit>().refreshHistories();
    }
  }

  /// 单项重试：需要 context 拿 cubit；失败由 cubit 写回 lastCheckFailed。
  Future<void> _retry(BuildContext context) {
    return context.read<ComicFollowCubit>().checkUpdateForItem(follow);
  }

  Future<bool?> _askUnfollow(BuildContext context) => confirmShortAlert(
    context: context,
    title: Text(t.comicFollow.unfollow),
    content: Text(t.comicFollow.unfollowConfirm(title: follow.title)),
    confirmLabel: t.comicInfo.unfollow,
    destructive: true,
    barrierDismissible: false,
    adaptiveRoute: true,
  );
}

class _FollowUpdateBadge extends StatelessWidget {
  const _FollowUpdateBadge({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ink = BreezeThemeColors.readableOn(scheme.onPrimary, scheme.primary);
    final style = (theme.textTheme.labelSmall ?? const TextStyle(fontSize: 11))
        .copyWith(color: ink, fontWeight: FontWeight.w700);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(t.comicFollow.newChaptersShort(diff: count), style: style),
      ),
    );
  }
}
