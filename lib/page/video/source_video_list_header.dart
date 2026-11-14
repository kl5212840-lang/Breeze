import 'package:zephyr/page/search/widget/search_toolbar_scope.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/widgets/collection_command_icons.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';

const sourceVideoCollectionInset = CollectionToolbarMetrics.sourceContentInset;

({IconData icon, String symbol}) sourceVideoMenuIcon(String key) {
  final value = key.toLowerCase();
  if (value.contains('sort') ||
      value == 'recent' ||
      value == 'title' ||
      value == 'year')
    return CollectionCommandIcons.sort;
  if (value.contains('view')) return CollectionCommandIcons.grid;
  if (value.contains('clear') ||
      value.contains('delete') ||
      value.contains('remove'))
    return (icon: Icons.delete_outline_rounded, symbol: 'trash');
  if (value.contains('import'))
    return (icon: Icons.download_outlined, symbol: 'square.and.arrow.down');
  if (value.contains('cloud') || value.contains('sync'))
    return (icon: Icons.cloud_sync_outlined, symbol: 'icloud');
  if (value.contains('update'))
    return (icon: Icons.update_rounded, symbol: 'arrow.triangle.2.circlepath');
  if (value.contains('following'))
    return (icon: Icons.favorite_border_rounded, symbol: 'heart');
  if (value.contains('folder'))
    return (icon: Icons.folder_outlined, symbol: 'folder');
  if (value.contains('refresh'))
    return (icon: Icons.refresh_rounded, symbol: 'arrow.clockwise');
  return (icon: Icons.checklist_rounded, symbol: 'checklist');
}

/// Omo's content commands share one header; records retain their own actions.
class SourceVideoListHeader extends StatelessWidget {
  const SourceVideoListHeader({
    super.key,
    required this.title,
    required this.onSearch,
    required this.options,
    required this.onMore,
    this.searchField,
    this.searchScope,
    this.leading,
    this.searching = false,
    this.reserveMoreSlot = false,
    this.menuKey,
    this.keyPrefix = 'source-video-list',
    this.horizontalInset = sourceVideoCollectionInset,
  });
  final String title, keyPrefix;
  final Key? menuKey;
  final double horizontalInset;
  final bool searching, reserveMoreSlot;
  final Widget? searchField, searchScope, leading;
  final VoidCallback? onSearch;
  final Map<String, String> options;
  final ValueChanged<String> onMore;
  @override
  Widget build(BuildContext context) => VideoControlAppearance(
    systemControls: usesNativeSourceChrome(context),
    child: Padding(
      padding: EdgeInsetsDirectional.only(
        start: leading == null ? horizontalInset : 0,
        end: horizontalInset,
      ),
      child: SearchToolbarScope(
        extent: searching && searchField != null
            ? SearchToolbarScope.breezeExtent(context)
            : null,
        child: Row(
          children: [
            if (leading != null)
              SizedBox(
                width: CollectionToolbarMetrics.sourceLeadingExtent,
                child: leading,
              ),
            Expanded(
              child: searching && searchField != null
                  ? searchField!
                  : Padding(
                      padding: EdgeInsetsDirectional.only(
                        start: leading == null ? 8 : 0,
                        end: 8,
                      ),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
            ),
            if (searching) ...[const SizedBox(width: 8), ?searchScope],
            SourceChromeIconButton(
              key: ValueKey('$keyPrefix.search-toggle'),
              tooltip: searching ? t.common.close : t.common.search,
              onPressed: onSearch,
              icon: searching ? Icons.close_rounded : Icons.search_rounded,
              symbol: searching ? 'xmark' : 'magnifyingglass',
            ),
            if (!searching) ...[
              CollectionCoverPrivacyButton(
                key: ValueKey('$keyPrefix.cover-privacy'),
              ),
              if (options.isNotEmpty)
                NativeVideoMenu(
                  key: menuKey ?? ValueKey('$keyPrefix.more'),
                  hostPresentation: true,
                  label: '',
                  width: CollectionToolbarMetrics.actionExtent,
                  tooltip: t.common.more,
                  selected: '',
                  icon: Icons.more_horiz_rounded,
                  symbol: 'ellipsis',
                  options: options,
                  optionIcons: {
                    for (final entry in options.entries)
                      entry.key:
                          entry.key.toLowerCase().contains('view') &&
                              entry.value == t.videoLibrary.detailList
                          ? CollectionCommandIcons.list
                          : sourceVideoMenuIcon(entry.key),
                  },
                  onSelected: onMore,
                )
              else if (reserveMoreSlot)
                const SizedBox.square(
                  dimension: CollectionToolbarMetrics.actionExtent,
                ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// The count shares the collection's content inset. Sort, layout and filter
/// change the current result set and stay together in the content toolbar.
class SourceVideoResultsToolbar extends StatelessWidget {
  const SourceVideoResultsToolbar({
    super.key,
    required this.count,
    required this.keyPrefix,
    this.sort = '',
    this.sortOptions = const {},
    this.onSort,
    this.gridView,
    this.onToggleView,
    this.filter,
    this.horizontalInset = sourceVideoCollectionInset,
  });

  final String count, keyPrefix, sort;
  final Map<String, String> sortOptions;
  final ValueChanged<String>? onSort;
  final bool? gridView;
  final VoidCallback? onToggleView;
  final Widget? filter;
  final double horizontalInset;

  @override
  Widget build(BuildContext context) => VideoControlAppearance(
    systemControls: usesNativeSourceChrome(context),
    child: Padding(
      padding: EdgeInsetsDirectional.symmetric(horizontal: horizontalInset),
      child: Row(
        children: [
          Expanded(
            child: Text(
              count,
              key: ValueKey('$keyPrefix.count'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (sortOptions.length > 1)
            if (onSort case final choose?)
              NativeVideoMenu(
                key: ValueKey('$keyPrefix.sort'),
                label: '',
                tooltip: sortOptions[sort] == null
                    ? t.videoLibrary.sort
                    : '${t.videoLibrary.sort} · ${sortOptions[sort]}',
                selected: sort,
                options: sortOptions,
                width: CollectionToolbarMetrics.actionExtent,
                hostPresentation: true,
                icon: CollectionCommandIcons.sort.icon,
                symbol: CollectionCommandIcons.sort.symbol,
                onSelected: (value) {
                  if (value != sort && sortOptions.containsKey(value)) {
                    choose(value);
                  }
                },
              )
            else
              SourceChromeIconButton(
                key: ValueKey('$keyPrefix.sort'),
                tooltip: t.videoLibrary.sort,
                onPressed: null,
                icon: CollectionCommandIcons.sort.icon,
                symbol: CollectionCommandIcons.sort.symbol,
              ),
          if (gridView case final grid?)
            SourceChromeIconButton(
              key: ValueKey('$keyPrefix.view'),
              tooltip: grid ? t.videoLibrary.detailList : t.videoLibrary.grid,
              onPressed: onToggleView,
              icon:
                  (grid
                          ? CollectionCommandIcons.list
                          : CollectionCommandIcons.grid)
                      .icon,
              symbol:
                  (grid
                          ? CollectionCommandIcons.list
                          : CollectionCommandIcons.grid)
                      .symbol,
            ),
          ?filter,
        ],
      ),
    ),
  );
}
