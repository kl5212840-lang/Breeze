import 'package:zephyr/widgets/collection_command_icons.dart';
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/collection_cover_settings.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'package:zephyr/widgets/source_collection_menu_icons.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_content_layout.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_actions_scope.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_header_slots.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_selection_toolbar.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/video_interaction.dart';

/// Common reading controls stay direct; organization joins one labelled menu.
class BookshelfContentToolbar extends StatelessWidget {
  const BookshelfContentToolbar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.view,
    required this.onToggleView,
    required this.onManage,
    this.onBack,
    this.onRoot,
    this.folderRootLabel,
    this.onFilter,
    this.filterActive = false,
    this.showFilter = false,
    this.showCreateFolder = false,
    this.onCreateFolder,
    this.moreOptions = const {},
    this.moreGroups = const [],
    this.onMore,
    this.arrangement,
    this.headerIdentity,
    this.selection,
    this.canRun,
    this.privacyAction,
    this.keyPrefix = 'shelf',
    this.horizontalInset = CollectionToolbarMetrics.horizontalInset,
  });
  final String title, subtitle, keyPrefix;
  final String? folderRootLabel;
  final BookshelfContentView view;
  final VoidCallback? onBack,
      onRoot,
      onCreateFolder,
      onToggleView,
      onManage,
      onFilter;
  final bool filterActive, showFilter, showCreateFolder;
  final Map<String, String> moreOptions;
  final List<List<String>> moreGroups;
  final ValueChanged<String>? onMore;
  final BookshelfActionsScope? arrangement;
  final Object? headerIdentity;
  final Widget? selection;
  final bool Function()? canRun;
  final Widget? privacyAction;
  final double horizontalInset;

  @override
  Widget build(BuildContext context) {
    final hostHeader = BookshelfActionsScope.of(context)?.header;
    final lifted = hostHeader != null;
    final scope = arrangement;
    final breadcrumb = lifted && onBack != null
        ? _layout(context, const [], breadcrumbOnly: true)
        : const SizedBox.shrink();
    if (lifted && scope?.header != hostHeader) return breadcrumb;
    bool canUseHeader() =>
        context.mounted &&
        (!lifted ||
            (scope != null &&
                hostHeader.isCurrent(scope.headerGeneration) &&
                scope.canUseHeader?.call() != false));
    bool canUseMenu() => canUseHeader() && canRun?.call() != false;
    VoidCallback? directAction(VoidCallback? action) =>
        !lifted || action == null
        ? action
        : () {
            if (canUseHeader()) action();
          };
    const helpKeys = {'help', '__help'};
    final help = {
      for (final entry in moreOptions.entries)
        if (helpKeys.contains(entry.key)) entry.key: entry.value,
    };
    final options = <String, String>{
      if (onManage != null) '__manage': t.bookshelf.manage,
      if (showCreateFolder && onCreateFolder != null)
        '__new': t.bookshelf.newFolder,
      if (arrangement?.onSort != null)
        '__sort':
            '${t.bookshelf.sort} · ${arrangement!.sortOptions['__sort.${arrangement!.sort}'] ?? ''}',
      for (final entry in moreOptions.entries)
        if (!helpKeys.contains(entry.key)) entry.key: entry.value,
      if (privacyAction != null)
        collectionCoverSettingsAction: collectionCoverSettingsLabel(context),
      ...help,
    };
    final sourceSortOptions = {
      for (final e in moreOptions.entries)
        if (e.key.startsWith('sort.')) e.key: e.value,
    };
    options.removeWhere((key, _) => key.startsWith('sort.'));
    final controls = <Widget>[
      if (sourceSortOptions.isNotEmpty)
        VideoControlAppearance(
          systemControls: usesNativeSourceChrome(context),
          child: NativeVideoMenu(
            key: ValueKey('$keyPrefix.sort'),
            label: '',
            tooltip: t.bookshelf.sort,
            selected:
                sourceSortOptions.entries
                    .where((entry) => entry.value == subtitle)
                    .firstOrNull
                    ?.key ??
                '',
            icon: CollectionCommandIcons.sort.icon,
            symbol: CollectionCommandIcons.sort.symbol,
            bare: usesNativeSourceChrome(context),
            width: CollectionToolbarMetrics.actionExtent,
            hostPresentation: true,
            options: sourceSortOptions,
            optionIcons: collectionMenuIcons(sourceSortOptions),
            onSelected: (value) {
              if (canUseMenu()) onMore?.call(value);
            },
          ),
        ),
      if (showFilter || onFilter != null)
        Semantics(
          selected: filterActive,
          child: SourceFilterIconButton(
            key: ValueKey('$keyPrefix.filter'),
            active: filterActive,
            bare: false,
            tooltip: filterActive ? t.videoFilters.active : t.bookshelf.filter,
            onPressed: lifted && onFilter != null
                ? () {
                    if (canUseMenu()) onFilter!.call();
                  }
                : onFilter,
          ),
        ),
      SourceChromeIconButton(
        key: ValueKey('$keyPrefix.view'),
        icon: view == BookshelfContentView.grid
            ? Icons.view_list_outlined
            : Icons.grid_view_outlined,
        symbol: view == BookshelfContentView.grid
            ? CollectionCommandIcons.list.symbol
            : CollectionCommandIcons.grid.symbol,
        tooltip: view == BookshelfContentView.grid
            ? t.videoLibrary.detailList
            : t.videoLibrary.grid,
        onPressed: directAction(onToggleView),
      ),
    ];
    final more = options.isEmpty
        ? null
        : Builder(
            builder: (triggerContext) => VideoControlAppearance(
              systemControls: usesNativeSourceChrome(triggerContext),
              child: NativeVideoMenu(
                key: ValueKey('$keyPrefix.more'),
                label: '',
                tooltip: t.common.more,
                selected: '',
                width: CollectionToolbarMetrics.actionExtent,
                icon: Icons.more_horiz,
                symbol: 'ellipsis',
                light: false,
                hostPresentation: true,
                selectAfterDismissal: {
                  if (options.containsKey(collectionCoverSettingsAction))
                    collectionCoverSettingsAction,
                },
                options: options,
                optionIcons: {
                  ...collectionMenuIcons(options),
                  '__manage': (icon: Icons.checklist, symbol: 'checklist'),
                  '__new': (
                    icon: Icons.create_new_folder_outlined,
                    symbol: 'folder.badge.plus',
                  ),
                  '__sort': (icon: Icons.sort, symbol: 'arrow.up.arrow.down'),
                  'help': (
                    icon: Icons.help_outline_rounded,
                    symbol: 'questionmark.circle',
                  ),
                  '__help': (
                    icon: Icons.help_outline_rounded,
                    symbol: 'questionmark.circle',
                  ),
                  collectionCoverSettingsAction: (
                    icon: Icons.visibility_off_outlined,
                    symbol: 'eye.slash',
                  ),
                },
                groups: [
                  ['__manage', '__new'],
                  ['__sort'],
                  for (final group in moreGroups)
                    [
                      for (final value in group)
                        if (!helpKeys.contains(value)) value,
                    ],
                  [collectionCoverSettingsAction],
                  help.keys.toList(),
                ],
                onSelected: (value) {
                  if (!triggerContext.mounted ||
                      !options.containsKey(value) ||
                      !canUseMenu()) {
                    return;
                  }
                  if (value == collectionCoverSettingsAction) {
                    unawaited(openCollectionCoverSettings(context));
                    return;
                  }
                  if (value == '__manage') {
                    onManage?.call();
                    return;
                  }
                  if (value == '__new') {
                    onCreateFolder?.call();
                    return;
                  }
                  if (value == '__sort') {
                    unawaited(_showSort(context, canUseMenu));
                    return;
                  }
                  if (arrangement?.handle(value) == true) return;
                  onMore?.call(value);
                },
              ),
            ),
          );
    if (hostHeader == null) {
      final regular = _layout(context, [
        // Keep source sorting before protection in standalone toolbars.
        if (sourceSortOptions.isNotEmpty) controls.first,
        ?privacyAction,
        ...controls.skip(sourceSortOptions.isEmpty ? 0 : 1),
        ?more,
      ]);
      return BookshelfSelectionHeader(regular: regular, selection: selection);
    }
    return BookshelfHeaderPublisher(
      controller: hostHeader,
      generation: scope!.headerGeneration,
      slots: BookshelfHeaderSlots(
        subtitle: onBack == null ? subtitle : '',
        identity: headerIdentity,
        controls: controls,
        more: more,
        selection: selection,
      ),
      child: breadcrumb,
    );
  }

  Widget _layout(
    BuildContext context,
    List<Widget> actions, {
    bool breadcrumbOnly = false,
  }) {
    final hasCaption = title.isNotEmpty || subtitle.isNotEmpty;
    final theme = Theme.of(context);
    final folder = onBack != null && folderRootLabel != null;
    final caption = Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        spacing: 8,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (title.isNotEmpty)
            Tooltip(
              message: title,
              excludeFromSemantics: true,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: folder
                    ? theme.textTheme.titleSmall
                    : theme.textTheme.bodyMedium,
              ),
            ),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalInset,
        vertical: breadcrumbOnly ? 0 : 4,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const controlSize = CollectionToolbarMetrics.actionExtent;
          const backGap = 4.0;
          const separatorSize = 16.0;
          const linkPadding = 4.0;
          final rootLabel = folder && onRoot != null ? folderRootLabel : null;
          final textScaler = MediaQuery.textScalerOf(context);
          final linkStyle = theme.textTheme.titleSmall;
          var linkWidth = controlSize;
          if (rootLabel != null) {
            final label = TextPainter(
              text: TextSpan(text: rootLabel, style: linkStyle),
              textDirection: Directionality.of(context),
              textScaler: textScaler,
              maxLines: 1,
            )..layout();
            linkWidth = (label.width.ceilToDouble() + 2 * linkPadding).clamp(
              controlSize,
              double.infinity,
            );
            label.dispose();
          }
          final actionWidth = actions.length * controlSize;
          final separateCaption = folder
              ? constraints.maxWidth <
                    actionWidth +
                        controlSize +
                        backGap +
                        (rootLabel == null ? 0 : linkWidth + separatorSize) +
                        72 * textScaler.scale(14) / 14
              : onBack != null ||
                    hasCaption &&
                        (folderRootLabel == null || title.isNotEmpty) &&
                        (constraints.maxWidth < actionWidth + 96 ||
                            textScaler.scale(14) > 20);
          final back = onBack == null
              ? null
              : SourceChromeIconButton(
                  key: ValueKey('$keyPrefix.back'),
                  icon: Icons.arrow_back,
                  symbol: 'chevron.left',
                  tooltip: !folder
                      ? t.common.back
                      : onRoot == null
                      ? t.bookshelf.returnToRoot
                      : t.bookshelf.returnToParent,
                  onPressed: breadcrumbOnly && selection != null
                      ? null
                      : onBack,
                );
          final heading = back == null
              ? caption
              : Row(
                  children: [
                    back,
                    const SizedBox(width: backGap),
                    if (rootLabel != null) ...[
                      Tooltip(
                        message: t.bookshelf.returnToRoot,
                        excludeFromSemantics: true,
                        child: TextButton(
                          key: ValueKey('$keyPrefix.root'),
                          onPressed: breadcrumbOnly && selection != null
                              ? null
                              : onRoot,
                          style: TextButton.styleFrom(
                            textStyle: linkStyle,
                            foregroundColor: theme.colorScheme.onSurfaceVariant,
                            minimumSize: Size(linkWidth, controlSize),
                            padding: const EdgeInsets.symmetric(
                              horizontal: linkPadding,
                            ),
                            visualDensity: VisualDensity.standard,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            rootLabel,
                            maxLines: 1,
                            semanticsLabel: t.bookshelf.returnToRoot,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: separatorSize,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                    Expanded(child: caption),
                  ],
                );
          if (breadcrumbOnly) return heading;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (separateCaption && !folder) heading,
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    if ((hasCaption || back != null) && !separateCaption)
                      Expanded(child: heading)
                    else
                      const Spacer(),
                    for (final action in actions)
                      SizedBox(width: controlSize, child: action),
                  ],
                ),
              ),
              if (separateCaption && folder) heading,
            ],
          );
        },
      ),
    );
  }

  Future<void> _showSort(
    BuildContext context,
    bool Function() canUseMenu,
  ) async {
    final scope = arrangement;
    if (scope?.onSort == null || !canUseMenu()) return;
    await showVideoTaskSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t.bookshelf.sort,
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: t.common.close,
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final entry in scope!.sortOptions.entries)
                    ListTile(
                      key: ValueKey('$keyPrefix.sort.${entry.key}'),
                      title: Text(entry.value),
                      selected: entry.key == '__sort.${scope.sort}',
                      trailing: entry.key == '__sort.${scope.sort}'
                          ? const Icon(Icons.check)
                          : const SizedBox(width: 24),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        if (entry.key != '__sort.${scope.sort}' &&
                            canUseMenu()) {
                          scope.handle(entry.key);
                        }
                      },
                    ),
                  if (scope.sort != 'dd') ...[
                    const Divider(height: 1),
                    ListTile(
                      key: ValueKey('$keyPrefix.sort.reset'),
                      title: Text(t.bookshelf.ordering.reset),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        if (canUseMenu()) scope.onSort?.call('dd');
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
