import 'package:zephyr/page/source_shell/source_experience_preferences.dart';
import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart'
    show normalizePluginId;
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/src/rust/api/qjs.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/util/text/public_search_text.dart';

enum KeywordSearchScope { title, all, author, tags, team }

/// A host-only query condition. Plugin actions with no marker retain their
/// declared browse, author or tag request unchanged.
const keywordSearchScopeKey = 'breezeKeywordScope';

const copyComicSourceId = 'b28da416-f2d4-4208-a85e-8b4c7c648e48';
const _jmSource = '6886291b-f524-441c-844b-c2efae9899a9';
const copySearchTopicKey = 'copySearchTopic';
const defaultKeywordSearchScopes = [
  KeywordSearchScope.title,
  KeywordSearchScope.all,
];

bool supportsCopyTopicSearch(String source, [Map<String, dynamic>? info]) {
  if (source != copyComicSourceId) return false;
  final metadata = info ?? PluginRegistryService.I.getCachedPluginInfo(source);
  return asJsonMap(metadata?['breezeExperience'])['copyTopicSearch'] == 1;
}

List<KeywordSearchScope> sourceKeywordSearchScopes(String source) {
  final experience = asJsonMap(
    PluginRegistryService.I.getCachedPluginInfo(
      normalizePluginId(source),
    )?['breezeExperience'],
  );
  if (source == copyComicSourceId) {
    return [
      ...defaultKeywordSearchScopes,
      KeywordSearchScope.author,
      if (experience['copyTopicSearch'] == 1) KeywordSearchScope.tags,
      KeywordSearchScope.team,
    ];
  }
  if (source == _jmSource) {
    return [
      ...defaultKeywordSearchScopes,
      KeywordSearchScope.author,
      KeywordSearchScope.tags,
    ];
  }
  if (isBikaExperienceSource(source) && experience['publicSearchFields'] == 1) {
    return [
      ...defaultKeywordSearchScopes,
      KeywordSearchScope.author,
      KeywordSearchScope.tags,
      KeywordSearchScope.team,
    ];
  }
  return defaultKeywordSearchScopes;
}

KeywordSearchScope? explicitKeywordSearchScope(Map<String, dynamic> extern) =>
    parseSourceKeywordSearchScope(extern[keywordSearchScopeKey]);

KeywordSearchScope? parseKeywordSearchScope(Object? value) => switch (value) {
  'title' => KeywordSearchScope.title,
  'all' => KeywordSearchScope.all,
  _ => null,
};

KeywordSearchScope? parseSourceKeywordSearchScope(Object? value) =>
    switch (value) {
      'author' => KeywordSearchScope.author,
      'tags' => KeywordSearchScope.tags,
      'team' => KeywordSearchScope.team,
      _ => parseKeywordSearchScope(value),
    };

KeywordSearchScope keywordSearchScope(Map<String, dynamic> extern) =>
    explicitKeywordSearchScope(extern) ?? KeywordSearchScope.all;

KeywordSearchScope sourceKeywordSearchScope(
  String source,
  Map<String, dynamic> extern,
) {
  final explicit = explicitKeywordSearchScope(extern);
  if (explicit != null) return explicit;
  if (source == copyComicSourceId) {
    if (extern[copySearchTopicKey] is String) return KeywordSearchScope.tags;
    return switch (extern['q_type']) {
      'name' => KeywordSearchScope.title,
      'author' => KeywordSearchScope.author,
      'local' => KeywordSearchScope.team,
      _ => KeywordSearchScope.all,
    };
  }
  if (source == _jmSource) {
    return switch (extern['main_tag']?.toString()) {
      '2' => KeywordSearchScope.author,
      '3' => KeywordSearchScope.tags,
      _ => KeywordSearchScope.all,
    };
  }
  if (isBikaExperienceSource(source)) {
    return switch (extern['bikaSearchField']) {
      'author' => KeywordSearchScope.author,
      'tag' => KeywordSearchScope.tags,
      'team' => KeywordSearchScope.team,
      _ => KeywordSearchScope.all,
    };
  }
  return KeywordSearchScope.all;
}

Map<String, dynamic> changeKeywordSearchScope(
  Map<String, dynamic> extern,
  KeywordSearchScope scope,
) => {...extern, keywordSearchScopeKey: scope.name}
  ..remove(copySearchTopicKey)
  ..remove('copySearchVariants')
  ..remove('bikaSearchField')
  ..remove('q_type')
  ..remove('main_tag');

List<String> copySearchVariants(String keyword) {
  if (!RegExp(r'[\u3400-\u9fff]').hasMatch(keyword)) return const [];
  final variants = <String>{};
  for (final config in ['tw2sp.json', 's2twp.json']) {
    try {
      final converted = openccConvert(text: keyword, config: config);
      if (converted.isNotEmpty && converted != keyword) variants.add(converted);
    } catch (_) {
      // The original site term is still usable without a conversion.
    }
  }
  return variants.toList();
}

Map<String, dynamic> keywordSearchRequestExtern(
  String source,
  Map<String, dynamic> extern, {
  String keyword = '',
}) {
  final scope = explicitKeywordSearchScope(extern);
  final request = {...extern}..remove(keywordSearchScopeKey);
  if (scope == null) return request;
  if (source == copyComicSourceId) {
    if (scope == KeywordSearchScope.tags) {
      request.remove('q_type');
      request[copySearchTopicKey] = extern[copySearchTopicKey] is String
          ? extern[copySearchTopicKey]
          : true;
      if (request[copySearchTopicKey] == true) {
        request['copySearchVariants'] = copySearchVariants(keyword);
      }
    } else {
      request['q_type'] = switch (scope) {
        KeywordSearchScope.title => 'name',
        KeywordSearchScope.author => 'author',
        KeywordSearchScope.team => 'local',
        _ => '',
      };
      request.remove(copySearchTopicKey);
      request.remove('copySearchVariants');
    }
  } else if (source == _jmSource) {
    request['main_tag'] = switch (scope) {
      KeywordSearchScope.author => 2,
      KeywordSearchScope.tags => 3,
      _ => 0,
    };
  } else if (isBikaExperienceSource(source)) {
    request.remove('bikaSearchField');
    switch (scope) {
      case KeywordSearchScope.author:
        request['bikaSearchField'] = 'author';
      case KeywordSearchScope.tags:
        request['bikaSearchField'] = 'tag';
      case KeywordSearchScope.team:
        request['bikaSearchField'] = 'team';
      case KeywordSearchScope.title || KeywordSearchScope.all:
        break;
    }
  }
  return request;
}

bool needsLoadedTitleMatch(String source, Map<String, dynamic> extern) =>
    source != copyComicSourceId &&
    explicitKeywordSearchScope(extern) == KeywordSearchScope.title;

final _keywordWhitespace = RegExp(r'\s+');

bool Function(Iterable<String>) keywordTitleMatcher(String query) {
  final needle = normalizePublicSearchText(query);
  if (needle.isEmpty) return (_) => true;
  final terms = needle.split(_keywordWhitespace);
  return (titles) => titles.any((title) {
    final plain = title.toLowerCase();
    if (terms.every(plain.contains)) return true;
    return terms.every(normalizePublicSearchText(title).contains);
  });
}
