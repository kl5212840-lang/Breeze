import 'package:zephyr/widgets/collection_cover_fit.dart';
import 'package:zephyr/widgets/work_list_divider.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/cubit/plugin_registry_cubit.dart';
import 'package:zephyr/network/http/plugin/qjs_network_route.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/comic_follow/cubit/comic_follow_cubit.dart';
import 'package:zephyr/page/comic_follow/view/follow_display.dart';
import 'package:zephyr/page/comic_follow/widgets/comic_follow_reminder_widgets.dart';
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
import 'package:zephyr/widgets/comic_entry/models/models.dart';
import 'package:zephyr/widgets/comic_simplify_entry/cover.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/widgets/collection_cover_settings.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/error_view.dart';
import 'package:zephyr/widgets/pull_refresh_feedback.dart';
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
  const ComicFollowPage({super.key, this.embedded = false, this.active = true});

  final bool embedded, active;

  @override
  State<ComicFollowPage> createState() => _ComicFollowPageState();
}

class _ComicFollowPageState extends State<ComicFollowPage>
    with WidgetsBindingObserver, AutoRouteAwareStateMixin<ComicFollowPage> {
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ComicFollowPageContent(embedded: widget.embedded);
}

/// Foreground-only update checks keep the detailed list and reading position.
class _ComicFollowPageContent extends StatefulWidget {
  const _ComicFollowPageContent({required this.embedded});

  final bool embedded;

  @override
  State<_ComicFollowPageContent> createState() =>
      _ComicFollowPageContentState();
}

class _ComicFollowPageContentState extends State<_ComicFollowPageContent> {
  final _searchFocus = FocusNode();
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
    if (_searching) {
      _searchFocus.unfocus();
      setState(() {
        _searching = false;
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
            (searchHeight) => AppBar(
              automaticallyImplyLeading: !widget.embedded && !_searching,
              leading: widget.embedded || _searching
                  ? null
                  : const SourceBackButton(),
              titleSpacing: _followContentInset,
              toolbarHeight: math.max(toolbarHeight, searchHeight ?? 0.0),
              title: _searching
                  ? SearchQueryField(
                      key: const ValueKey('follow-search-input'),
                      query: _query,
                      inline: true,
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
                      : const SizedBox(
                          width: CollectionToolbarMetrics.actionExtent,
                        ),
                ),
                const CollectionCoverPrivacyButton(
                  key: ValueKey('follow-cover-privacy'),
                ),
                const _FollowMoreButton(),
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
            _FollowToolbar(state: state, onMarkRead: _markAllRead),
            Expanded(child: _withRefresh(context, state, list)),
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
  const _FollowMoreButton();

  static const _reminderSettings = 'reminder-settings';

  @override
  Widget build(BuildContext context) => VideoControlAppearance(
    systemControls: usesNativeSourceChrome(context),
    child: NativeVideoMenu(
      key: const ValueKey('follow-more'),
      width: CollectionToolbarMetrics.actionExtent,
      label: '',
      tooltip: t.common.more,
      selected: '',
      icon: Icons.more_horiz,
      symbol: 'ellipsis',
      hostPresentation: true,
      selectAfterDismissal: const {
        collectionCoverSettingsAction,
        _reminderSettings,
      },
      options: {
        collectionCoverSettingsAction: collectionCoverSettingsLabel(context),
        _reminderSettings: t.followReminders.title,
      },
      optionIcons: const {
        collectionCoverSettingsAction: (
          icon: Icons.visibility_off_outlined,
          symbol: 'eye.slash',
        ),
        _reminderSettings: (icon: Icons.notifications_outlined, symbol: 'bell'),
      },
      onSelected: (value) {
        if (!context.mounted) return;
        switch (value) {
          case collectionCoverSettingsAction:
            unawaited(openCollectionCoverSettings(context));
          case _reminderSettings:
            unawaited(showComicFollowReminderSettings(context));
        }
      },
    ),
  );
}

/// One filter and one sort. Status belongs to the row being checked; the
/// toolbar never reports “no updates” while a previous result is still shown.
class _FollowToolbar extends StatelessWidget {
  const _FollowToolbar({required this.state, required this.onMarkRead});
  final ComicFollowState state;
  final VoidCallback onMarkRead;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ComicFollowCubit>();
    final statuses = {
      ComicFollowFilter.all.name: t.common.all,
      ComicFollowFilter.unread.name: t.comicFollow.unread,
    };
    final sorts = {
      ComicFollowSort.lastRead.name: t.comicFollow.lastRead,
      ComicFollowSort.update.name: t.comicFollow.lastUpdate,
    };
    final sort = VideoControlAppearance(
      systemControls: usesNativeSourceChrome(context),
      child: NativeVideoMenu(
        key: const ValueKey('follow-sort'),
        label: '',
        tooltip: '${t.comicFollow.sort} · ${sorts[state.sort.name]}',
        selected: state.sort.name,
        options: sorts,
        width: CollectionToolbarMetrics.actionExtent,
        hostPresentation: true,
        icon: Icons.swap_vert_rounded,
        symbol: 'arrow.up.arrow.down',
        onSelected: (value) {
          if (value != state.sort.name) {
            cubit.setSort(ComicFollowSort.values.byName(value));
          }
        },
      ),
    );
    final markAllRead = state.updateCount > 0
        ? SourceChromeIconButton(
            tooltip: t.comicFollow.markAllReadHint,
            onPressed: state.isCheckingUpdates ? null : onMarkRead,
            icon: Icons.done_all_outlined,
            symbol: 'checkmark.circle',
          )
        : null;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        _followContentInset,
        0,
        _followContentInset,
        4,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const actionExtent = CollectionToolbarMetrics.actionExtent;
          const gap = 8.0;
          final actions = [?markAllRead, sort];
          final segmentWidth =
              NativeVideoSegmentedControl.minimumHorizontalWidth(
                context,
                statuses.values,
              );
          final filter = VideoControlAppearance(
            systemControls: usesNativeSourceChrome(context),
            child: NativeVideoSegmentedControl(
              key: const ValueKey('follow-filter'),
              options: statuses,
              selected: state.filter.name,
              onSelected: (value) =>
                  cubit.setFilter(ComicFollowFilter.values.byName(value)),
            ),
          );
          if (constraints.maxWidth >=
              segmentWidth + actions.length * actionExtent + gap) {
            return Row(
              children: [
                Expanded(child: filter),
                const SizedBox(width: gap),
                ...actions,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              filter,
              Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
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
    required this.items,
    required this.state,
    required this.scrollKey,
    required this.bottomPadding,
  });

  final List<ComicFollow> items;
  final ComicFollowState state;
  final PageStorageKey<(String, bool)> scrollKey;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ComicFollowCubit>();
    // 外层已用 ConstrainedBox(768) 居中，这里只留固定边距。
    return ListView.separated(
      key: scrollKey,
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
          history: history,
          readChapterPosition: cubit.readChapterPositionFor(follow, history),
          hasUnreadUpdate: state.hasUnreadUpdate(follow),
          unreadChapterCount: state.unreadChapterCount(follow),
          checking: state.checkingKeys.contains(follow.uniqueKey),
          checkDeferred: cubit.isCheckDeferred(follow),
          failure: state.checkErrors[follow.uniqueKey],
          lastAttempt: state.lastAttempts[follow.uniqueKey],
        );
      },
    );
  }
}

class _FollowCard extends StatelessWidget {
  const _FollowCard({
    super.key,
    required this.follow,
    required this.history,
    required this.readChapterPosition,
    required this.hasUnreadUpdate,
    required this.unreadChapterCount,
    required this.checking,
    required this.checkDeferred,
    this.failure,
    this.lastAttempt,
  });

  final ComicFollow follow;
  final UnifiedComicHistory? history;
  final int? readChapterPosition;
  final bool hasUnreadUpdate;
  final int unreadChapterCount;
  final bool checking;
  final bool checkDeferred;
  final ComicFollowCheckFailure? failure;
  final DateTime? lastAttempt;

  // Use the bookshelf frame as the minimum; follow cards can grow to 96×144.
  static const _minimumCoverWidth = 80.0;
  static const _maximumCoverWidth = 96.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cover = resolveFollowCover(follow);

    return Dismissible(
      key: ValueKey('dismiss-${follow.uniqueKey}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      confirmDismiss: (_) => _askUnfollow(context),
      onDismissed: (_) => _removeFollow(context),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openDetail(context),
          onLongPress: () => _onLongPress(context),
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
                    final chaptersBelow = _chaptersBelow(
                      context,
                      theme,
                      textWidth,
                      coverHeight,
                    );
                    final identity = Column(
                      key: ValueKey('follow-identity-${follow.uniqueKey}'),
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTitleRow(theme),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(child: _buildSourceLine(theme)),
                            if (hasUnreadUpdate)
                              Flexible(
                                child: ComicFollowReminderBadge(
                                  child: Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                      start: 6,
                                    ),
                                    child: _UnreadPill(
                                      count: unreadChapterCount,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                    final chapters = Column(
                      key: ValueKey('follow-chapters-${follow.uniqueKey}'),
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLatestLine(context, theme),
                        const SizedBox(height: 6),
                        _buildReadingLine(theme),
                        _buildProgress(theme),
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
                const SizedBox(height: 8),
                _buildBottomRow(context, theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 长按走“菜单式”二次确认：先弹取消追更确认框，确认后真正移除并 toast。
  Future<void> _onLongPress(BuildContext context) async {
    final confirmed = await _askUnfollow(context);
    if (confirmed == true && context.mounted) {
      await _removeFollow(context);
    }
  }

  Widget _buildCover(UnifiedComicCover cover, double width, double height) =>
      CollectionCoverFitBuilder(
        builder: (context, fit) => ClipRRect(
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
      );

  Widget _buildTitleRow(ThemeData theme) => Text(
    follow.title,
    key: ValueKey('follow-title-${follow.uniqueKey}'),
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
  );

  String get _latestText {
    final title = follow.detectedChapterTitle.trim();
    final count = follow.detectedChapterCount;
    if (follow.lastCheckFailed || checkDeferred) {
      return title.isEmpty
          ? t.comicFollow.knownCount(count: count)
          : t.comicFollow.knownChapter(count: count, chapter: title);
    }
    return title.isEmpty
        ? t.comicFollow.latestCount(count: count)
        : t.comicFollow.latestChapter(count: count, chapter: title);
  }

  bool _chaptersBelow(
    BuildContext context,
    ThemeData theme,
    double width,
    double coverHeight,
  ) {
    final scale = MediaQuery.textScalerOf(context);
    if (width < scale.scale(150)) return true;
    double height(
      String text,
      TextStyle? style,
      int lines, [
      double? available,
    ]) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: lines,
        textScaler: scale,
        textDirection: Directionality.of(context),
      )..layout(maxWidth: (available ?? width).clamp(1.0, double.infinity));
      final value = painter.height;
      painter.dispose();
      return value;
    }

    final title = height(
      follow.title,
      theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      2,
    );
    final source = height(_pluginLabel(), theme.textTheme.bodySmall, 1);
    final badge = hasUnreadUpdate
        ? height(
                t.comicFollow.newChaptersShort(diff: unreadChapterCount),
                theme.textTheme.labelSmall,
                1,
              ) +
              6
        : 0.0;
    final identity = title + 4 + (source > badge ? source : badge);
    final chapter = history?.chapterTitle.trim() ?? '';
    final chapters =
        height(
          _latestText,
          theme.textTheme.bodyMedium?.copyWith(
            fontWeight: hasUnreadUpdate ? FontWeight.w600 : FontWeight.normal,
          ),
          2,
          width - 18,
        ) +
        6 +
        height(
          chapter.isEmpty
              ? t.comicFollow.notRead
              : t.comicFollow.lastReadChapter(chapter: chapter),
          theme.textTheme.bodyMedium,
          1,
        ) +
        (readChapterPosition != null ? 8 : 0);
    return identity + 8 + chapters > coverHeight;
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

  /// A small progress track complements the chapter title without repeating
  /// its total a second time. Unknown progress is not presented as zero.
  Widget _buildProgress(ThemeData theme) {
    final position = readChapterPosition;
    final total = follow.detectedChapterCount;
    if (position == null || position <= 0 || position > total) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Semantics(
        label: t.comicFollow.readProgress(read: position, total: total),
        child: LinearProgressIndicator(
          value: followReadProgress(
            chapterPosition: position,
            detectedTotal: total,
          ),
          minHeight: 2,
          borderRadius: BorderRadius.circular(2),
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          color: theme.colorScheme.outlineVariant,
        ),
      ),
    );
  }

  Widget _buildLatestLine(BuildContext context, ThemeData theme) {
    final scheme = theme.colorScheme;
    final latest = _latestText;
    return Row(
      children: [
        Icon(
          hasUnreadUpdate
              ? Icons.fiber_new_outlined
              : follow.lastCheckFailed || checkDeferred
              ? Icons.history
              : Icons.check_circle_outline,
          size: 14,
          color: hasUnreadUpdate ? scheme.primary : scheme.outline,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            latest,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: hasUnreadUpdate
                  ? scheme.onSurface
                  : scheme.onSurfaceVariant,
              fontWeight: hasUnreadUpdate ? FontWeight.w600 : FontWeight.normal,
            ),
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

  /// Keep reading and check times aligned below the entire card.
  Widget _buildBottomRow(BuildContext context, ThemeData theme) {
    final timeStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final checkTime = switch ((
      follow.lastCheckFailed,
      checkDeferred,
      lastAttempt,
    )) {
      (true, _, final DateTime attemptedAt) => t.comicFollow.lastCheckAttempt(
        time: formatFollowCheckTime(attemptedAt),
      ),
      (true, _, null) => null,
      (false, true, _) => t.comicFollow.lastSuccessfulCheck(
        time: formatFollowCheckTime(follow.updateTime),
      ),
      (false, false, _) => t.comicFollow.checkTime(
        time: formatFollowCheckTime(follow.updateTime),
      ),
    };
    final readAt = history?.lastReadAt;
    final readTime = readAt == null
        ? const SizedBox.shrink()
        : Text(
            t.comicFollow.lastReadAt(time: formatFollowCheckTime(readAt)),
            style: timeStyle,
          );
    final checkLabel = checkTime == null
        ? const SizedBox.shrink()
        : Text(
            checkTime,
            textAlign: follow.lastCheckFailed ? TextAlign.start : TextAlign.end,
            style: timeStyle,
          );
    final timesKey = ValueKey('follow-times-${follow.uniqueKey}');
    return Column(
      key: ValueKey('follow-check-${follow.uniqueKey}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (follow.lastCheckFailed) _buildCheckFailure(context, theme),
        if (checkDeferred && !follow.lastCheckFailed)
          _buildCheckFailureStatus(
            context,
            theme,
            ComicFollowCheckFailure.sourceUnavailable,
          ),
        SizedBox(
          width: double.infinity,
          child: follow.lastCheckFailed
              ? OverflowBar(
                  key: timesKey,
                  alignment: MainAxisAlignment.spaceBetween,
                  spacing: 12,
                  children: [readTime, checkLabel],
                )
              : Row(
                  key: timesKey,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: readTime),
                    const SizedBox(width: 12),
                    Expanded(
                      child: checking && !checkDeferred
                          ? Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: _buildCheckingLabel(timeStyle),
                            )
                          : checkLabel,
                    ),
                  ],
                ),
        ),
        if (follow.lastCheckFailed)
          Text(
            t.comicFollow.lastSuccessfulCheck(
              time: formatFollowCheckTime(follow.updateTime),
            ),
            style: timeStyle,
          ),
      ],
    );
  }

  Widget _buildCheckFailure(BuildContext context, ThemeData theme) {
    if (failure != ComicFollowCheckFailure.pluginDisabled &&
        failure != ComicFollowCheckFailure.pluginMissing) {
      return _buildCheckFailureStatus(
        context,
        theme,
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
          _buildCheckFailureStatus(context, theme, unavailable),
    );
  }

  Widget _buildCheckFailureStatus(
    BuildContext context,
    ThemeData theme,
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
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final status = checking
        ? _buildCheckingLabel(style)
        : message == null
        ? null
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(message, style: style),
          );
    if (needsPlugin) return status!;
    return OverflowBar(
      spacing: 8,
      alignment: status == null
          ? MainAxisAlignment.end
          : MainAxisAlignment.spaceBetween,
      children: [
        ?status,
        TextButton.icon(
          key: ValueKey('follow-retry-${follow.uniqueKey}'),
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          onPressed: checking ? null : () => _retry(context),
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(t.common.retry),
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
      Flexible(child: Text(t.comicFollow.checkingUpdates, style: style)),
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

  Future<bool?> _askUnfollow(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.comicFollow.unfollow),
        content: Text(t.comicFollow.unfollowConfirm(title: follow.title)),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => dialogContext.pop(true),
            child: Text(t.common.ok),
          ),
        ],
      ),
    );
  }

  Future<void> _removeFollow(BuildContext context) async {
    await context.read<ComicFollowCubit>().removeFollow(
      follow.source,
      follow.comicId,
    );
    showSuccessToast(t.comicFollow.unfollowed);
  }
}

class _UnreadPill extends StatelessWidget {
  const _UnreadPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        t.comicFollow.newChaptersShort(diff: count),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
