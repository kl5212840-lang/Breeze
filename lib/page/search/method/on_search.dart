import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart'
    show normalizePluginId;
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/method/search_scope_preferences.dart';
import 'package:zephyr/page/search_result/bloc/search_bloc.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/toast.dart';

Map<String, dynamic> searchSubmissionExtern(
  SearchStates current, {
  required bool aggregateMode,
  Map<String, dynamic>? pluginExtern,
}) {
  if (pluginExtern != null) {
    return Map<String, dynamic>.from(
      aggregateMode
          ? pluginExtern
          : migrateBikaKeywordSearchDraft(current.from, pluginExtern),
    );
  }

  final extern = Map<String, dynamic>.from(
    aggregateMode
        ? current.pluginExtern
        : migrateBikaKeywordSearchDraft(current.from, current.pluginExtern),
  );
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

bool _hasSearchScope(SearchStates state) =>
    state.searchKeyword.trim().isNotEmpty ||
    explicitKeywordSearchScope(state.pluginExtern) != null ||
    state.pluginExtern.keys.any(
      const {
        'url',
        'searchUrl',
        'apiUrl',
        'path',
        'pathWord',
        'searchType',
        'mode',
        'creatorId',
        'bikaSearchField',
        'q_type',
        'main_tag',
        'search_type',
        bikaLoadedTitleOnlyKey,
        copySearchTopicKey,
      }.contains,
    );

Future<KeywordSearchScope> readKeywordSearchDefault({String? source}) async {
  final saved = await SearchScopePreferences.read(
    surface: source == null
        ? SearchScopePreferences.aggregate
        : SearchScopePreferences.comic,
    source: source,
  ).catchError((Object _) => null);
  final scope = parseSourceKeywordSearchScope(saved);
  final options = source == null
      ? defaultKeywordSearchScopes
      : sourceKeywordSearchScopes(normalizePluginId(source));
  return options.contains(scope) ? scope! : KeywordSearchScope.all;
}

final _latestSubmission = Expando<Object>();

void onSearch(
  BuildContext context,
  String keyword, {
  Map<String, dynamic>? pluginExtern,
  bool aggregateMode = true,
  KeywordSearchScope? historyScope,
}) async {
  final trimmedKeyword = keyword.trim();
  if (trimmedKeyword.isEmpty) {
    showWarningToast(t.search.enterKeyword);
    return;
  }
  FocusManager.instance.primaryFocus?.unfocus();

  final searchCubit = context.read<SearchCubit>();
  final submission = _latestSubmission[searchCubit] = Object();
  final route = ModalRoute.of(context);
  var current = searchCubit.state;
  final source = normalizePluginId(current.from);
  KeywordSearchScope validated(KeywordSearchScope? scope) {
    final options = aggregateMode
        ? defaultKeywordSearchScopes
        : sourceKeywordSearchScopes(source);
    return options.contains(scope) ? scope! : KeywordSearchScope.all;
  }

  if (historyScope != null) {
    current = current.copyWith(
      pluginExtern: changeKeywordSearchScope(
        current.pluginExtern,
        validated(historyScope),
      ),
    );
  } else if (pluginExtern == null && !_hasSearchScope(current)) {
    final revision = searchCubit.queryRevision.value;
    final scope = await readKeywordSearchDefault(
      source: aggregateMode ? null : source,
    );
    if (!context.mounted ||
        route?.isCurrent == false ||
        _latestSubmission[searchCubit] != submission ||
        searchCubit.queryRevision.value != revision ||
        normalizePluginId(searchCubit.state.from) != source) {
      return;
    }
    current = searchCubit.state;
    if (!_hasSearchScope(current)) {
      current = current.copyWith(
        pluginExtern: changeKeywordSearchScope(current.pluginExtern, scope),
      );
    }
  }
  final nextExtern = searchSubmissionExtern(
    current,
    aggregateMode: aggregateMode,
    pluginExtern: pluginExtern,
  );
  searchCubit.submit(
    searchCubit.state.copyWith(
      searchKeyword: trimmedKeyword,
      pluginExtern: nextExtern,
    ),
  );

  final event = SearchEvent().copyWith(searchStates: searchCubit.state);

  if (aggregateMode) {
    context.pushRoute(
      SearchAggregateResultRoute(searchEvent: event, searchCubit: searchCubit),
    );
    return;
  }

  context.pushRoute(
    SearchResultRoute(searchEvent: event, searchCubit: searchCubit),
  );
}
