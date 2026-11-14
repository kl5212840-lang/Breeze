import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search/method/on_search.dart';
import 'package:zephyr/page/search/method/search_history_entries.dart';
import 'package:zephyr/page/search/widget/search_history_section.dart';

class HistoryWidget extends StatelessWidget {
  const HistoryWidget({
    super.key,
    this.aggregateMode = true,
    this.source,
    this.embedded = false,
  });
  final bool aggregateMode, embedded;
  final String? source;
  @override
  Widget build(BuildContext context) {
    final scope = aggregateMode
        ? ''
        : source ??
              context.select<SearchCubit, String>((cubit) => cubit.state.from);
    final entries = context.watch<GlobalSettingCubit>().state.searchHistory;
    final visible = SearchHistoryEntries.words(
      entries,
      scope: !aggregateMode && scope.isEmpty ? '__unknown_source__' : scope,
    );
    final section = SearchHistorySection(
      key: ValueKey('comic-history.$scope'),
      words: visible,
      compact: !aggregateMode,
      scopeLabel: aggregateMode
          ? t.search.aggregateHistory
          : t.search.currentSourceHistory,
      onSubmit: (keyword) =>
          onSearch(context, keyword, aggregateMode: aggregateMode),
      onRemove: (selected) async {
        context.read<GlobalSettingCubit>().updateState(
          (current) => current.copyWith(
            searchHistory: SearchHistoryEntries.remove(
              current.searchHistory,
              selected,
              scope: !aggregateMode && scope.isEmpty
                  ? '__unknown_source__'
                  : scope,
            ),
          ),
        );
      },
    );
    return embedded
        ? section
        : SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: section,
          );
  }
}
