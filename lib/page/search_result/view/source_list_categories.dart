import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/util/text/chinese_convert.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';

Set<String> blockedCategoryNames(Object? value) {
  if (value is List) {
    return value.map((item) => item.toString()).toSet();
  }
  if (value is Map) {
    return value.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key.toString())
        .toSet();
  }
  return <String>{};
}

List<String> sourceQuickCategories(String source) {
  final info = PluginRegistryService.I.getCachedPluginInfo(source);
  final experience = asJsonMap(info?['breezeExperience']);
  return asJsonList(experience['searchQuickCategories'])
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

bool isEntryBlockedByCategory(
  UnifiedComicListItem entry,
  Set<String> blockedCategories,
) {
  if (blockedCategories.isEmpty) return false;
  final categories = entry.metadata
      .where((field) => field.type == 'categories' || field.type == 'category')
      .expand((field) => field.value)
      .map((value) => value.toString().trim())
      .where((value) => value.isNotEmpty)
      .expand((value) => value.split(RegExp(r'[,，、·|/]')))
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .toList();
  if (categories.isEmpty) return false;
  final blocked = blockedCategories
      .map((value) => value.trim().toLowerCase())
      .toSet();
  if (categories.any(blocked.contains)) return true;

  // A display preference must not change saved category matches. Fold the
  // source values consistently while retaining their original stored identity.
  final aliases = blocked.map(_categoryAlias).toSet();
  return categories.any(
    (category) => aliases.contains(_categoryAlias(category)),
  );
}

String _categoryAlias(String value) =>
    value.codeUnits.every((unit) => unit < 128) ? value : t2s(value);

List<UnifiedComicListItem> filterEntriesByBlockedCategories(
  Iterable<UnifiedComicListItem> entries,
  Set<String> blockedCategories,
) => entries
    .where((entry) => !isEntryBlockedByCategory(entry, blockedCategories))
    .toList();
