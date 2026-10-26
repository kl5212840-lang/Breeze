import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/page/search_result/view/source_list_categories.dart';

/// Plugin schemes own the meaning of sort values. Never label every source
/// with the Bika order: JM uses the same numbers for different sort modes.
final Map<String, Future<List<Map<String, dynamic>>>> _fieldCache = {};

Future<List<Map<String, dynamic>>> sourceAdvancedFields(String source) {
  final id = source.trim();
  if (id.isEmpty) return Future.value(const []);
  return _fieldCache.putIfAbsent(id, () async {
    try {
      final response = await callUnifiedComicPlugin(
        pluginId: id,
        fnPath: 'getAdvancedSearchScheme',
        core: const <String, dynamic>{},
        extern: const <String, dynamic>{},
      );
      final scheme = response['scheme'];
      if (scheme is! Map) return const [];
      final fields = scheme['fields'];
      if (fields is! List) return const [];
      return fields
          .whereType<Map>()
          .map((field) => Map<String, dynamic>.from(field))
          .toList();
    } catch (_) {
      _fieldCache.remove(id);
      return const [];
    }
  });
}

List<Map<String, dynamic>> uniqueAdvancedFields(
  String source,
  List<Map<String, dynamic>> fields,
) {
  final hasQuickCategories = sourceQuickCategories(source).isNotEmpty;
  final hasScope = sourceSearchScopeOptions(fields).isNotEmpty;
  return fields.where((field) {
    final key = field['key']?.toString();
    if (hasScope && key == 'q_type') return false;
    return !hasQuickCategories ||
        (key != 'sortBy' && key != 'blockedCategories');
  }).toList();
}

Map<String, String> sourceSearchScopeOptions(
  List<Map<String, dynamic>> fields,
) {
  for (final field in fields) {
    if (field['key'] != 'q_type' ||
        field['kind'] != 'choice' ||
        field['options'] is! List) {
      continue;
    }
    return {
      for (final option in (field['options'] as List).whereType<Map>())
        if (option['label']?.toString().trim().isNotEmpty == true)
          option['value']?.toString() ?? '': option['label'].toString(),
    };
  }
  return const {};
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
