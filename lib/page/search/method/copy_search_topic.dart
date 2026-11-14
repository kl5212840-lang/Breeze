import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/network/http/plugin/unified_plugin_envelope.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/util/json/json_value.dart';

typedef CopySearchTopic = ({String label, String value});

SearchStates copyTopicSearchState(SearchStates search, CopySearchTopic topic) =>
    search.copyWith(
      from: copyComicSourceId,
      searchKeyword: topic.label,
      pluginExtern: {
        for (final key in ['blockedCategories', 'settingsBlockedCategories'])
          if (search.pluginExtern.containsKey(key))
            key: search.pluginExtern[key],
        keywordSearchScopeKey: KeywordSearchScope.tags.name,
        copySearchTopicKey: topic.value,
      },
    );

Future<CopySearchTopic?> resolveCopySearchTopic(
  String keyword, {
  String? taskGroupKey,
}) async {
  final query = keyword.trim();
  if (query.isEmpty || query.length > 80) return null;
  final response = await callUnifiedComicPlugin(
    pluginId: copyComicSourceId,
    fnPath: 'resolveSearchTopic',
    core: {'keyword': query, 'variants': copySearchVariants(query)},
    taskGroupKey: taskGroupKey,
    notifyUnauthorized: false,
  );
  requireSuccessfulPluginEnvelope(response);
  if (response['source'] != copyComicSourceId) {
    throw const FormatException('Invalid topic source');
  }
  if (response['topic'] == null) return null;
  final topic = asJsonMap(response['topic']);
  final label = topic['label'];
  final value = topic['value'];
  if (label is! String ||
      label.trim().isEmpty ||
      value is! String ||
      !RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(value)) {
    throw const FormatException('Invalid topic');
  }
  return (label: label.trim(), value: value);
}
