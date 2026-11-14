import 'package:zephyr/page/comic_list/models/list_filter_bundle.dart';
import 'package:zephyr/page/comic_list/scene_filter/plugin_list_filter_schema.dart';

/// Preserve the plugin's selection key and option-to-request mapping. These
/// keys cover current cloud schemas; unknown or nested fields stay in the dialog.
PluginChoiceField? cloudFavoriteSortField(ListFilterBundle? bundle) {
  if (bundle == null) return null;
  for (final field in bundle.scheme.fields) {
    if (const {'order', 'ordering', 'sort'}.contains(field.key) &&
        field.options.isNotEmpty &&
        field.options.every((option) => option.children.isEmpty)) {
      return field;
    }
  }
  return null;
}

bool cloudFavoriteNeedsFilterDialog(ListFilterBundle? bundle) {
  if (bundle == null) return true;
  final sort = cloudFavoriteSortField(bundle);
  return bundle.scheme.fields.any(
    (field) => field != sort && field.key != 'folderId',
  );
}

/// Prefer an actual remote condition UI over a second local search/filter UI.
/// Only the host's established sorting and collection-range fields are exempt;
/// arbitrary third-party field names are never translated into local facets.
bool cloudFavoriteHasRemoteResultFilters(ListFilterBundle? bundle) {
  if (bundle == null) return false;
  final sort = cloudFavoriteSortField(bundle);
  return bundle.scheme.fields.any(
    (field) =>
        field != sort && field.key != 'folderId' && field.options.isNotEmpty,
  );
}
