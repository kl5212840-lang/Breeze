import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/cubit/plugin_registry_cubit.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search_result/bloc/search_bloc.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/toast.dart';

Map<String, dynamic> searchSubmissionExtern(
  SearchStates current, {
  required bool aggregateMode,
  Map<String, dynamic>? pluginExtern,
}) {
  if (pluginExtern != null) return Map<String, dynamic>.from(pluginExtern);

  final extern = Map<String, dynamic>.from(current.pluginExtern);
  final scope = sourceKeywordSearchScope(current.from, extern);
  // A newly typed keyword does not inherit a site browse/creator URL.
  for (final key in [
    'url',
    'searchUrl',
    'apiUrl',
    'path',
    'pathWord',
    'searchType',
    'mode',
    'creatorId',
    'keyword',
    copySearchTopicKey,
    'copySearchVariants',
  ]) {
    extern.remove(key);
  }
  if (aggregateMode && !defaultKeywordSearchScopes.contains(scope)) {
    return changeKeywordSearchScope(extern, KeywordSearchScope.all);
  }
  final submissionScope = aggregateMode ? keywordSearchScope(extern) : scope;
  return extern..[keywordSearchScopeKey] = submissionScope.name;
}

void onSearch(
  BuildContext context,
  String keyword, {
  Map<String, dynamic>? pluginExtern,
  bool aggregateMode = true,
  Map<String, bool>? aggregateSources,
}) async {
  final trimmedKeyword = keyword.trim();
  if (trimmedKeyword.isEmpty) {
    showWarningToast(t.search.enterKeyword);
    return;
  }
  FocusManager.instance.primaryFocus?.unfocus();

  final searchCubit = context.read<SearchCubit>();
  final nextExtern = searchSubmissionExtern(
    searchCubit.state,
    aggregateMode: aggregateMode,
    pluginExtern: pluginExtern,
  );
  final nextAggregateSources = aggregateSources == null
      ? Map<String, bool>.from(searchCubit.state.aggregateSources)
      : Map<String, bool>.from(aggregateSources);
  searchCubit.submit(
    searchCubit.state.copyWith(
      searchKeyword: trimmedKeyword,
      pluginExtern: nextExtern,
      aggregateSources: nextAggregateSources,
    ),
  );

  final event = SearchEvent().copyWith(searchStates: searchCubit.state);

  if (aggregateMode) {
    final pluginStates = context.read<PluginRegistryCubit>().state;
    final availableSources = PluginRegistryService.I
        .sortPlugins(
          pluginStates.values.where(
            (plugin) => plugin.isEnabled && !plugin.isDeleted,
          ),
        )
        .map((plugin) => plugin.uuid)
        .toList();
    final selected = {
      for (final source in availableSources)
        source: nextAggregateSources[source] ?? true,
    };
    context.pushRoute(
      SearchAggregateResultRoute(
        searchEvent: event,
        searchCubit: searchCubit,
        selectedSources: selected,
      ),
    );
    return;
  }

  context.pushRoute(
    SearchResultRoute(searchEvent: event, searchCubit: searchCubit),
  );
}
