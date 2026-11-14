import 'package:zephyr/widgets/collection_command_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/collection_cover_settings.dart';

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
      'clear-blocked' => (
        icon: Icons.filter_alt_off_outlined,
        symbol: 'line.3.horizontal.decrease.circle',
      ),
      'folders' => (icon: Icons.folder_outlined, symbol: 'folder'),
      'refresh' => (icon: Icons.refresh_rounded, symbol: 'arrow.clockwise'),
      final value when value.startsWith('sort.') => CollectionCommandIcons.sort,
      final value when value.startsWith('category.') => (
        icon: Icons.block_outlined,
        symbol: 'nosign',
      ),
      _ => (icon: Icons.tune_rounded, symbol: 'slider.horizontal.3'),
    },
};
