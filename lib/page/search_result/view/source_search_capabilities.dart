import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/page/search_result/view/source_list_categories.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';

/// Plugin schemes own the meaning of sort values. Never label every source
/// with the Bika order: JM uses the same numbers for different sort modes.
final _fieldCache =
    <String, ({int owner, Future<List<Map<String, dynamic>>> fields})>{};

Future<List<Map<String, dynamic>>> sourceAdvancedFields(String source) {
  final id = normalizePluginId(source);
  if (id.isEmpty) return Future.value(const []);
  final owner = pluginSessionWriteFence.generation(id);
  final cached = _fieldCache[id];
  if (cached != null && cached.owner == owner) return cached.fields;

  final fields = _loadAdvancedFields(id, owner);
  _fieldCache[id] = (owner: owner, fields: fields);
  return fields;
}

Future<List<Map<String, dynamic>>> _loadAdvancedFields(
  String id,
  int owner,
) async {
  try {
    final response = await callUnifiedComicPlugin(
      pluginId: id,
      fnPath: 'getAdvancedSearchScheme',
      core: const <String, dynamic>{},
      extern: const <String, dynamic>{},
      notifyUnauthorized: false,
    );
    if (pluginSessionWriteFence.generation(id) != owner) return const [];
    final scheme = response['scheme'];
    if (scheme is! Map) return const [];
    final fields = scheme['fields'];
    if (fields is! List) return const [];
    return fields
        .whereType<Map>()
        .map((field) => Map<String, dynamic>.from(field))
        .toList();
  } catch (_) {
    // An earlier runtime failure must not evict the replacement's schema.
    if (_fieldCache[id]?.owner == owner) _fieldCache.remove(id);
    return const [];
  }
}

List<Map<String, dynamic>> uniqueAdvancedFields(
  String source,
  List<Map<String, dynamic>> fields,
) {
  final hasQuickCategories = sourceQuickCategories(source).isNotEmpty;
  final scope = sourceSearchScope(fields);
  return fields.where((field) {
    final key = field['key']?.toString();
    if (scope != null && key == scope.field) return false;
    return !hasQuickCategories ||
        (key != 'sortBy' && key != 'blockedCategories');
  }).toList();
}

({String field, Map<String, String> options})? sourceSearchScope(
  List<Map<String, dynamic>> fields,
) {
  for (final field in fields) {
    final key = field['key'];
    if (key is! String ||
        !const {'q_type', 'main_tag'}.contains(key) ||
        field['kind'] != 'choice' ||
        field['options'] is! List) {
      continue;
    }
    final options = {
      for (final option in (field['options'] as List).whereType<Map>())
        if (option['label']?.toString().trim().isNotEmpty == true)
          option['value']?.toString() ?? '': option['label'].toString(),
    };
    if (options.isNotEmpty) return (field: key, options: options);
  }
  return null;
}

Future<bool> hasUniqueAdvancedFields(String source) async {
  final fields = await sourceAdvancedFields(source);
  return uniqueAdvancedFields(source, fields).isNotEmpty;
}

Map<String, String> sourceSortOptions(List<Map<String, dynamic>> fields) {
  for (final field in fields) {
    if (field['key'] != 'sortBy' || field['options'] is! List) continue;
    final result = <String, String>{};
    for (final option in field['options'] as List) {
      if (option is! Map) continue;
      final value = option['value']?.toString() ?? '';
      final label = option['label']?.toString() ?? '';
      if (value.isNotEmpty && label.isNotEmpty) result[value] = label;
    }
    return result;
  }
  return const {};
}
