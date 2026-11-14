import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search_result/bloc/search_bloc.dart';
import 'package:zephyr/page/search_result/view/source_list_filter_bar.dart';
import 'package:zephyr/page/search_result/view/source_list_categories.dart';
import 'package:zephyr/page/search_result/view/source_search_capabilities.dart';
import 'package:zephyr/util/text/chinese_convert.dart';
import 'package:zephyr/page/source_shell/source_list_block_preferences.dart';
import 'package:zephyr/page/source_shell/source_category_settings_scope.dart';
import 'package:zephyr/widgets/read_recovery_scope.dart';
import 'package:zephyr/page/source_shell/source_experience_preferences.dart';

/// Source-provided categories are a blocklist, not an inclusive search filter.
class SourceQuickCategoryBar extends StatefulWidget {
  const SourceQuickCategoryBar({
    super.key,
    required this.categories,
    required this.detailedView,
    required this.onViewChanged,
    this.pageLabel,
    this.onPageTap,
    this.trailingAction,
  });

  final List<String> categories;
  final bool detailedView;
  final ValueChanged<bool> onViewChanged;
  final String? pageLabel;
  final VoidCallback? onPageTap;
  final Widget? trailingAction;

  @override
  State<SourceQuickCategoryBar> createState() => _SourceQuickCategoryBarState();
}

class _SourceQuickCategoryBarState extends State<SourceQuickCategoryBar> {
  Timer? _searchTimer;
  int _reconcileEpoch = 0;
  bool _active = false, _pendingRefresh = false;
  void _setActive(bool active) {
    _active = active;
    if (!active) {
      if (_searchTimer != null) _pendingRefresh = true;
      _searchTimer?.cancel();
      _searchTimer = null;
    } else if (_pendingRefresh) {
      _scheduleSearch();
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  void _scheduleSearch() {
    _searchTimer?.cancel();
    if (!_active) {
      _pendingRefresh = true;
      return;
    }
    _pendingRefresh = false;
    _searchTimer = Timer(const Duration(milliseconds: 280), _runSearch);
  }

  void _runSearch() {
    if (!mounted) return;
    _searchTimer = null;
    if (!_active) {
      _pendingRefresh = true;
      return;
    }
    final bloc = context.read<SearchBloc>();
    bloc.add(SearchEvent(searchStates: context.read<SearchCubit>().state));
  }

  void _setBlockedCategories(
    Set<String> blocked, {
    Set<String> inherited = const {},
  }) {
    final cubit = context.read<SearchCubit>();
    final current = cubit.state;
    final inheritedChanged = !setEquals(
      blockedCategoryNames(current.pluginExtern['settingsBlockedCategories']),
      inherited,
    );
    if (!inheritedChanged &&
        setEquals(
          blockedCategoryNames(current.pluginExtern['blockedCategories']),
          blocked,
        )) {
      return;
    }
    final extern = <String, dynamic>{...current.pluginExtern};
    extern['blockedCategories'] = blocked.toList();
    if (inherited.isEmpty) {
      extern.remove('settingsBlockedCategories');
    } else {
      extern['settingsBlockedCategories'] = inherited.toList();
    }
    cubit.update(current.copyWith(pluginExtern: extern));
    if (inheritedChanged || !isBikaExperienceSource(current.from)) {
      _scheduleSearch();
    }
  }

  void _toggleCategory(
    BuildContext context,
    String category,
    Set<String> currentBlocked,
    ValueChanged<Set<String>> persist,
    Set<String> inherited,
  ) {
    final blocked = {...currentBlocked};
    final isBlocking = blocked.add(category);
    if (!isBlocking) blocked.remove(category);
    persist(blocked);
    _setBlockedCategories(blocked, inherited: inherited);

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          isBlocking
              ? '已屏蔽「${convertChineseForDisplay(category)}」· 再点恢复'
              : '已恢复「${convertChineseForDisplay(category)}」',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _changeSort(BuildContext context, int sortBy) {
    final cubit = context.read<SearchCubit>();
    final current = cubit.state;
    final extern = <String, dynamic>{...current.pluginExtern, 'sortBy': sortBy};
    extern.remove('sort');
    cubit.update(current.copyWith(sortBy: sortBy, pluginExtern: extern));
    _scheduleSearch();
  }

  @override
  Widget build(BuildContext context) {
    return ReadRecoveryHost(
      onActiveChanged: _setActive,
      child: BlocBuilder<SearchCubit, SearchStates>(
        builder: (context, state) {
          final blocked = blockedCategoryNames(
            state.pluginExtern['blockedCategories'],
          );
          return SourceCategorySettingsScope(
            source: state.from,
            builder: (context, inherited) => SourceCategoryBlockScope(
              scope: '${state.from}|search',
              initial: blocked,
              onRestored: (local) =>
                  _setBlockedCategories(local, inherited: inherited),
              builder: (context, savedBlocked, persist) {
                final reconcileEpoch = ++_reconcileEpoch;
                final effective = {...inherited, ...savedBlocked};
                if (!setEquals(blocked, savedBlocked) ||
                    !setEquals(
                      blockedCategoryNames(
                        state.pluginExtern['settingsBlockedCategories'],
                      ),
                      inherited,
                    )) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted &&
                        reconcileEpoch == _reconcileEpoch &&
                        context.read<SearchCubit>().state == state) {
                      _setBlockedCategories(savedBlocked, inherited: inherited);
                    }
                  });
                }
                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: sourceAdvancedFields(state.from),
                  builder: (context, snapshot) {
                    final fields = snapshot.data ?? const [];
                    return SourceListFilterBar(
                      categories: widget.categories,
                      blockedCategories: effective,
                      lockedCategories: inherited,
                      onLockedCategoryTap: (_) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已在插件设置中屏蔽，请到屏蔽设置中修改')),
                        );
                      },
                      onCategoryTap: (category) => _toggleCategory(
                        context,
                        category,
                        savedBlocked,
                        persist,
                        inherited,
                      ),
                      onClearBlockedCategories:
                          savedBlocked.difference(inherited).isEmpty
                          ? null
                          : () {
                              persist({});
                              _setBlockedCategories({}, inherited: inherited);
                            },
                      sortValue: state.sortBy.toString(),
                      sortOptions: sourceSortOptions(fields),
                      onSortChanged: (value) =>
                          _changeSort(context, int.parse(value)),
                      detailedView: widget.detailedView,
                      onViewChanged: widget.onViewChanged,
                      pageLabel: widget.pageLabel,
                      onPageTap: widget.onPageTap,
                      trailingAction: widget.trailingAction,
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
