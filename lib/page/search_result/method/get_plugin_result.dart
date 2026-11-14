import 'package:zephyr/widgets/comic_entry/models/models.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/page/search_result/bloc/search_bloc.dart';
import 'package:zephyr/page/search_result/models/bloc_state.dart';
import 'package:zephyr/page/search_result/models/comic_number.dart';
import 'package:zephyr/page/search_result/models/unified_plugin_search.dart';
import 'package:zephyr/page/source_shell/source_experience_preferences.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';

int trustworthyTotalPages(UnifiedPluginSearchPaging paging) {
  if (!paging.hasReachedMax && paging.pages <= paging.page) return 0;
  return paging.pages;
}

Future<BlocState> getPluginSearchResult(
  SearchEvent event,
  BlocState blocState, {
  String? taskGroupKey,
  bool notifyUnauthorized = true,
  Map<String, dynamic>? externOverride,
  void Function(UnifiedPluginSearchPaging)? onPaging,
}) async {
  final pluginId = event.searchStates.from.trim();
  if (pluginId.isEmpty) {
    throw StateError('search source is empty');
  }
  final extern = Map<String, dynamic>.from(
    externOverride ?? event.searchStates.pluginExtern,
  );
  final requestExtern = keywordSearchRequestExtern(
    pluginId,
    extern,
    keyword: event.searchStates.searchKeyword,
  );
  final response = await callUnifiedComicPlugin(
    pluginId: pluginId,
    fnPath: 'searchComic',
    core: {'keyword': event.searchStates.searchKeyword, 'page': event.page},
    // Page exclusions are a host view preference. Older Bika scripts save this
    // parameter as source settings, so keep it out of the transport entirely.
    // The script still applies its own settings; the host applies page extras.
    extern: isBikaExperienceSource(pluginId)
        ? (requestExtern
            ..remove('blockedCategories')
            ..remove('settingsBlockedCategories'))
        : requestExtern,
    taskGroupKey: taskGroupKey,
    notifyUnauthorized: notifyUnauthorized,
  );
  final parsed = UnifiedPluginSearchResponse.fromMap(response);

  final list = parsed.items
      .map((item) => _toUnifiedComic(item, event.page, parsed.source))
      .toList();

  blocState.pagesCount = parsed.paging.page;
  // A few older plugins reported the current page as the total page count.
  // Do not present "1 / 1" while the same response says more pages exist.
  blocState.totalPages = trustworthyTotalPages(parsed.paging);
  blocState.totalResults = parsed.paging.total;
  blocState.hasReachedMax = parsed.paging.hasReachedMax;
  blocState.comics = [...blocState.comics, ...list];
  // The blocklist is a local presentation preference. Some plugins return a
  // fresh pagination extern and omit it, so keep it across page responses.
  blocState.pluginExtern = {
    ...extern,
    ...parsed.extern,
    if (extern.containsKey(keywordSearchScopeKey))
      keywordSearchScopeKey: extern[keywordSearchScopeKey],
    if (isBikaExperienceSource(pluginId) ||
        extern.containsKey('blockedCategories'))
      'blockedCategories': extern['blockedCategories'] ?? const <String>[],
  };
  onPaging?.call(parsed.paging);
  return blocState;
}

ComicNumber _toUnifiedComic(
  UnifiedPluginSearchItem item,
  int page,
  String source,
) {
  return ComicNumber(
    buildNumber: page,
    comic: unifiedComicFromPluginSearchItem(item, source),
  );
}
