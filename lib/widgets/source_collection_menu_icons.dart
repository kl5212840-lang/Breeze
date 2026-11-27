import 'package:zephyr/widgets/collection_command_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/collection_cover_settings.dart';
import 'package:zephyr/page/source_shell/source_settings_destination.dart';

/// Semantic command glyphs for all source collection menu branches.
Map<String, ({IconData icon, String symbol})> collectionMenuIcons(
  Map<String, String> options,
) => {
  for (final key in options.keys)
    key: switch (key) {
      'view.toggle' when options[key] == t.comicList.switchToGrid =>
        CollectionCommandIcons.grid,
      'view.toggle' || 'view.list' => CollectionCommandIcons.list,
      'view.grid' => CollectionCommandIcons.grid,
      'cover' || collectionCoverSettingsAction => (
        icon: Icons.visibility_off_outlined,
        symbol: 'eye.slash',
      ),
      'remote-filter' => CollectionCommandIcons.filter,
      sourceSettingsMenuAction => (
        icon: Icons.settings_outlined,
        symbol: 'gearshape',
      ),
      'cloud-folder.select' => (
        icon: Icons.checklist_rounded,
        symbol: 'checklist',
      ),
      'cloud-folder.create' => (
        icon: Icons.create_new_folder_outlined,
        symbol: 'folder.badge.plus',
      ),
      'cloud-folder.rename' => (icon: Icons.edit_outlined, symbol: 'pencil'),
      'cloud-folder.delete' => (icon: Icons.delete_outline, symbol: 'trash'),
      'folders' => (icon: Icons.folder_outlined, symbol: 'folder'),
      'refresh' || 'cloud-folder.refresh' => (
        icon: Icons.refresh_rounded,
        symbol: 'arrow.clockwise',
      ),
      final value when value.startsWith('sort.') => CollectionCommandIcons.sort,
      _ => (icon: Icons.tune_rounded, symbol: 'slider.horizontal.3'),
    },
};
