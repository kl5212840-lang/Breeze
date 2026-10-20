import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search_result/bloc/search_bloc.dart';
import 'package:zephyr/page/search_result/view/source_list_filter_bar.dart';
import 'package:zephyr/util/text/chinese_convert.dart';

/// Source-provided categories are a blocklist, not an inclusive search filter.
class SourceQuickCategoryBar extends StatefulWidget {
  const SourceQuickCategoryBar({
    super.key,
    required this.categories,
    required this.detailedView,
    required this.onViewChanged,
  });

  final List<String> categories;
  final bool detailedView;
  final ValueChanged<bool> onViewChanged;

  @override
  State<SourceQuickCategoryBar> createState() => _SourceQuickCategoryBarState();
}

class _SourceQuickCategoryBarState extends State<SourceQuickCategoryBar> {
  Timer? _searchTimer;

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  List<String> _selected(Object? value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    if (value is Map) {
      return value.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key.toString())
          .toList();
    }
    return const [];
  }

  void _scheduleSearch() {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 280), _runSearch);
  }

  void _runSearch() {
    if (!mounted) return;
    final bloc = context.read<SearchBloc>();
    if (bloc.state.status == SearchStatus.initial ||
        bloc.state.status == SearchStatus.loadingMore) {
      _searchTimer = Timer(const Duration(milliseconds: 180), _runSearch);
      return;
    }
    bloc.add(SearchEvent(searchStates: context.read<SearchCubit>().state));
  }

  void _toggleCategory(BuildContext context, String category) {
    final cubit = context.read<SearchCubit>();
    final current = cubit.state;
    final extern = <String, dynamic>{...current.pluginExtern};
    final blocked = _selected(extern['blockedCategories']).toSet();
    final isBlocking = blocked.add(category);
    if (!isBlocking) blocked.remove(category);
    extern['blockedCategories'] = blocked.toList();
    cubit.update(current.copyWith(pluginExtern: extern));
    _scheduleSearch();

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

  void _clearBlockedCategories() {
    final cubit = context.read<SearchCubit>();
    final current = cubit.state;
    final extern = <String, dynamic>{...current.pluginExtern};
    extern.remove('blockedCategories');
    cubit.update(current.copyWith(pluginExtern: extern));
    _scheduleSearch();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SearchCubit, SearchStates>(
      builder: (context, state) {
        final blocked = _selected(
          state.pluginExtern['blockedCategories'],
        ).toSet();
        return SourceListFilterBar(
          categories: widget.categories,
          blockedCategories: blocked,
          onCategoryTap: (category) => _toggleCategory(context, category),
          onClearBlockedCategories: _clearBlockedCategories,
          sortValue: state.sortBy.toString(),
          sortOptions: const {'1': '最新', '2': '最早', '3': '最多喜欢', '4': '最多观看'},
          onSortChanged: (value) => _changeSort(context, int.parse(value)),
          detailedView: widget.detailedView,
          onViewChanged: widget.onViewChanged,
        );
      },
    );
  }
}
