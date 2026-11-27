import 'package:zephyr/widgets/collection_cover_settings.dart';
import 'dart:async';

import 'package:zephyr/page/search/widget/keyword_scope_menu.dart';
import 'package:zephyr/page/search/widget/search_field_surface.dart';
import 'package:zephyr/page/search/widget/search_toolbar_scope.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/widgets/collection_command_icons.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'package:zephyr/widgets/collection_results_row.dart';

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
    this.menuKey,
    this.keyPrefix = 'source-video-list',
    this.horizontalInset = sourceVideoCollectionInset,
  });
  final String title, keyPrefix;
  final Key? menuKey;
  final double horizontalInset;
  final bool searching;
  final Widget? searchField, searchScope, leading;
  final VoidCallback? onSearch;
  final Map<String, String> options;
  final ValueChanged<String> onMore;
  @override
  Widget build(BuildContext context) {
    final searchExtent = searching && searchField != null
        ? SearchToolbarScope.fieldExtent(context)
        : null;
    return VideoControlAppearance(
      systemControls: usesNativeSourceChrome(context),
      child: Padding(
        padding: CollectionToolbarMetrics.contentPaddingOf(
          context,
          inset: horizontalInset,
        ),
        child: SearchToolbarScope(
          extent: searchExtent,
          onClose: searchExtent == null ? null : onSearch,
          closeKey: ValueKey('$keyPrefix.search-toggle'),
          leadingControl: searchScope,
          leadingWidth: searchExtent == null || searchScope == null
              ? 0
              : KeywordScopeMenu.leadingWidth(context).clamp(
                  CollectionToolbarMetrics.actionExtentOf(context),
                  (MediaQuery.sizeOf(context).width - 270).clamp(48.0, 80.0),
                ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: SearchToolbarScope.stableHeight(
                context,
                CollectionToolbarMetrics.actionExtentOf(context),
              ),
            ),
            child: Row(
              spacing: CollectionToolbarMetrics.searchControlGap,
              children: [
                if (leading != null && searchExtent == null) leading!,
                Expanded(
                  child: searching && searchField != null
                      ? AndroidSearchExpansion(child: searchField!)
                      : Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                ),
                if (searchExtent == null)
                  SourceChromeIconButton(
                    key: ValueKey('$keyPrefix.search-toggle'),
                    tooltip: searching ? t.common.close : t.common.search,
                    onPressed: onSearch,
                    icon: searching
                        ? Icons.close_rounded
                        : Icons.search_rounded,
                    symbol: searching ? 'xmark' : 'magnifyingglass',
                  ),
                if (searchExtent == null)
                  CollectionCoverPrivacyButton(
                    key: ValueKey('$keyPrefix.cover-privacy'),
                  ),
                if (searchExtent == null)
                  NativeVideoMenu(
                    key: menuKey ?? ValueKey('$keyPrefix.more'),
                    hostPresentation: true,
                    label: '',
                    width: CollectionToolbarMetrics.actionExtent,
                    tooltip: t.common.more,
                    selected: '',
                    icon: Icons.more_horiz_rounded,
                    symbol: 'ellipsis',
                    options: {
                      ...options,
                      collectionCoverSettingsAction:
                          collectionCoverSettingsLabel(context),
                    },
                    selectAfterDismissal: const {collectionCoverSettingsAction},
                    optionIcons: {
                      collectionCoverSettingsAction: (
                        icon: Icons.visibility_off_outlined,
                        symbol: 'eye.slash',
                      ),
                      for (final entry in options.entries)
                        entry.key:
                            entry.key.toLowerCase().contains('view') &&
                                entry.value == t.videoLibrary.detailList
                            ? CollectionCommandIcons.list
                            : sourceVideoMenuIcon(entry.key),
                    },
                    onSelected: (value) {
                      if (value == collectionCoverSettingsAction) {
                        unawaited(openCollectionCoverSettings(context));
                      } else {
                        onMore(value);
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
    this.layout,
    this.leading,
    this.showSortValue = false,
    this.horizontalInset = sourceVideoCollectionInset,
  });

  final String count, keyPrefix, sort;
  final Map<String, String> sortOptions;
  final ValueChanged<String>? onSort;
  final bool? gridView;
  final VoidCallback? onToggleView;
  final Widget? filter, layout, leading;
  final bool showSortValue;
  final double horizontalInset;

  @override
  Widget build(BuildContext context) => VideoControlAppearance(
    systemControls: usesNativeSourceChrome(context),
    child: LayoutBuilder(
      builder: (context, constraints) {
        const gap = CollectionToolbarMetrics.searchControlGap;
        final padding = CollectionToolbarMetrics.contentPaddingOf(
          context,
          inset: horizontalInset,
        );
        final actionExtent = CollectionToolbarMetrics.actionExtentOf(context);
        final scale = MediaQuery.textScalerOf(context);
        final sortWidth = (94 * scale.scale(1)).clamp(
          94.0,
          (MediaQuery.sizeOf(context).width * .42).clamp(94.0, 144.0),
        );
        final actions = [?filter, ?gridView, ?layout].length;
        final sortHasLabel =
            showSortValue &&
            onSort != null &&
            constraints.maxWidth - padding.horizontal >=
                sortWidth +
                    gap +
                    actions * (actionExtent + gap) +
                    scale.scale(56);
        final sortValue = sortOptions[sort];
        final sortTooltip = sortValue == null
            ? t.videoLibrary.sort
            : '${t.videoLibrary.sort} · $sortValue';
        final choose = onSort;
        final sortAction = sortOptions.length < 2
            ? null
            : choose != null
            ? NativeVideoMenu(
                key: ValueKey('$keyPrefix.sort'),
                label: sortHasLabel ? sortValue ?? t.videoLibrary.sort : '',
                tooltip: sortTooltip,
                selected: sort,
                options: sortOptions,
                width: sortHasLabel
                    ? sortWidth
                    : CollectionToolbarMetrics.actionExtent,
                hostPresentation: true,
                compactTextChoice: sortHasLabel,
                bare: true,
                icon: sortHasLabel ? null : CollectionCommandIcons.sort.icon,
                symbol: sortHasLabel ? '' : CollectionCommandIcons.sort.symbol,
                onSelected: (value) {
                  if (value != sort && sortOptions.containsKey(value)) {
                    choose(value);
                  }
                },
              )
            : SourceChromeIconButton(
                key: ValueKey('$keyPrefix.sort'),
                tooltip: sortTooltip,
                onPressed: null,
                bare: true,
                icon: CollectionCommandIcons.sort.icon,
                symbol: CollectionCommandIcons.sort.symbol,
              );
        final grid = gridView;
        final viewAction = grid == null
            ? null
            : SourceChromeIconButton(
                key: ValueKey('$keyPrefix.view'),
                tooltip: grid ? t.videoLibrary.detailList : t.videoLibrary.grid,
                onPressed: onToggleView,
                bare: true,
                icon: CollectionCommandIcons.toggleTarget(grid).icon,
                symbol: CollectionCommandIcons.toggleTarget(grid).symbol,
              );
        final countKey = ValueKey('$keyPrefix.count');
        return CollectionResultsRow(
          countLabel: leading == null ? count : '',
          countKey: countKey,
          scope: leading,
          sortAction: sortAction,
          sortWidth: sortHasLabel ? sortWidth : null,
          filterButton: filter,
          viewAction: viewAction,
          extraAction: layout,
          horizontalInset: horizontalInset,
        );
      },
    ),
  );
}
