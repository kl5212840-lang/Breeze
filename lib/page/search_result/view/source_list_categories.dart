import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/util/text/chinese_convert.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';

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
  final categories = entry
      .metadataValues('categories')
      .map((value) => value.toString().trim())
      .where((value) => value.isNotEmpty)
      .toList();
  if (categories.isEmpty) return false;
  final blocked = blockedCategories.map(convertChineseForDisplay).toSet();
  return categories.any(
    (category) =>
        blockedCategories.contains(category) ||
        blocked.contains(convertChineseForDisplay(category)),
  );
}
