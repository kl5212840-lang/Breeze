import 'dart:async';

import 'package:zephyr/page/bookshelf/widgets/bookshelf_management_island.dart';

import 'package:zephyr/page/search/widget/search_toolbar_scope.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/source_shell/source_settings_destination.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/widgets/collection_cover_settings.dart';
import 'package:zephyr/widgets/source_collection_menu_icons.dart';
import 'package:zephyr/widgets/source_choice_menu.dart';
import 'package:zephyr/page/search/widget/search_field_decoration.dart';
import 'package:zephyr/page/video/video_interaction.dart';

/// A profile child may lend its navigation actions to that source's AppBar.
/// Ownership prevents a disposed/older record view from clearing a newer view.
class JmCollectionHeaderController extends ChangeNotifier {
  Object? _owner;
  JmCollectionNavigationActions? _actions;
  Widget? _searchField;
  bool _closed = false;
  JmCollectionNavigationActions? get actions => _actions;
  Widget? get searchField => _searchField;
  void publish(
    Object owner,
    JmCollectionNavigationActions actions, {
    Widget? searchField,
  }) {
    if (_closed) return;
    _owner = owner;
    _actions = actions;
    _searchField = searchField;
    notifyListeners();
  }

  void release(Object owner) {
    if (_closed || !identical(_owner, owner)) return;
    _owner = null;
    _actions = null;
    _searchField = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    _owner = null;
    _actions = null;
    _searchField = null;
    super.dispose();
  }
}

/// Actions that belong to the collection's navigation bar.
class JmCollectionNavigationActions extends StatelessWidget {
  const JmCollectionNavigationActions({
    super.key,
    required this.onSearch,
    required this.options,
    required this.groups,
    required this.onSelected,
    this.searching = false,
    this.keyPrefix = 'jm-collection',
    this.showSearch = true,
    this.inlineSearch = false,
    this.source = '',
  });
  final VoidCallback? onSearch;
  final Map<String, String> options;
  final List<List<String>> groups;
  final ValueChanged<String> onSelected;
  final bool searching, showSearch, inlineSearch;
  final String keyPrefix, source;
  @override
  Widget build(BuildContext context) {
    if (inlineSearch && searching) return const SizedBox.shrink();
    final menuOptions = {
      ...options,
      if (source.isNotEmpty) sourceSettingsMenuAction: t.plugin.pluginSettings,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: CollectionToolbarMetrics.searchControlGap,
      children: [
        if (showSearch)
          SourceChromeIconButton(
            key: ValueKey('$keyPrefix.search'),
            tooltip: searching ? t.common.close : t.common.search,
            icon: searching ? Icons.close_rounded : Icons.search_rounded,
            symbol: searching ? 'xmark' : 'magnifyingglass',
            onPressed: onSearch,
          ),
        const CollectionCoverPrivacyButton(),
        SizedBox(
          width: CollectionToolbarMetrics.actionExtentOf(context),
          child: VideoControlAppearance(
            systemControls: usesNativeSourceChrome(context),
            child: NativeVideoMenu(
              key: ValueKey('$keyPrefix.more'),
              label: '',
              tooltip: t.common.more,
              selected: '',
              icon: Icons.more_horiz,
              symbol: 'ellipsis',
              width: CollectionToolbarMetrics.actionExtent,
              hostPresentation: true,
              selectAfterDismissal: {
                ...options.keys.where((key) => key.startsWith('cloud-folder.')),
                if (options.containsKey(collectionCoverSettingsAction))
                  collectionCoverSettingsAction,
                if (source.isNotEmpty) sourceSettingsMenuAction,
              },
              options: menuOptions,
              optionIcons: collectionMenuIcons(menuOptions),
              groups: [
                ...groups,
                if (source.isNotEmpty) [sourceSettingsMenuAction],
              ],
              onSelected: (value) {
                if (value == sourceSettingsMenuAction) {
                  unawaited(openSourceSettings(context, source: source));
                } else {
                  onSelected(value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Mount the collection navigation controls on the destination's first frame.
/// A child publishes callbacks after build; this slot keeps their native views
/// in place while that happens instead of adding a second set next frame.
class JmCollectionHeaderActions extends StatelessWidget {
  const JmCollectionHeaderActions({super.key, required this.controller});
  final JmCollectionHeaderController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final actions = controller.actions;
      return SearchToolbarScope(
        extent: actions?.searching == true
            ? SearchToolbarScope.fieldExtent(context)
            : null,
        child: JmCollectionNavigationActions(
          keyPrefix: 'jm-record',
          source: actions?.source ?? '',
          inlineSearch: true,
          onSearch: actions?.onSearch,
          searching: actions?.searching ?? false,
          options: actions?.options ?? const {},
          groups: actions?.groups ?? const [],
          onSelected: (value) => controller.actions?.onSelected(value),
        ),
      );
    },
  );
}

class JmCollectionSortAction extends StatelessWidget {
  const JmCollectionSortAction({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.bare = false,
  });

  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final bool bare;

  @override
  Widget build(BuildContext context) {
    final selectedLabel = options[selected];
    final sortLabel = t.videoFilters.sort;
    return VideoControlAppearance(
      systemControls: usesNativeSourceChrome(context),
      child: NativeVideoMenu(
        label: '',
        tooltip: selectedLabel == null
            ? sortLabel
            : '$sortLabel · $selectedLabel',
        selected: selected,
        icon: Icons.sort_rounded,
        symbol: 'arrow.up.arrow.down',
        width: CollectionToolbarMetrics.actionExtent,
        hostPresentation: true,
        bare: bare,
        options: options,
        optionIcons: collectionMenuIcons(options),
        onSelected: onSelected,
      ),
    );
  }
}

String jmCollectionCountLabel({
  required bool complete,
  required int shown,
  required int loaded,
  int? knownTotal,
}) => t.videoLibrary.results(
  count: !complete && knownTotal != null ? knownTotal : shown,
);

/// Official folders are a remote collection scope, not local shelf folders.
/// Keep small choices immediate; large collections have searchable, lazy rows.
class JmCollectionFolderChoice extends StatelessWidget {
  const JmCollectionFolderChoice({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.onRoute,
  });
  final String label, value;
  final Map<String, String> options;
  final ValueChanged<String>? onChanged;
  final ValueChanged<ModalRoute<dynamic>?>? onRoute;

  @override
  Widget build(BuildContext context) {
    if (options.length <= 8) {
      return SourceChoiceMenu<String>(
        label: options[value] ?? options.values.first,
        tooltip: label,
        value: value,
        options: options,
        maximumWidth: 160,
        onChanged: onChanged,
      );
    }
    return TextButton(
      onPressed: onChanged == null
          ? null
          : () async {
              final picked = await showVideoTaskSheet<String>(
                context: context,
                builder: (context) {
                  onRoute?.call(ModalRoute.of(context));
                  return _JmFolderSelection(
                    label: label,
                    value: value,
                    options: options,
                  );
                },
              );
              if (context.mounted && picked != null && picked != value) {
                onChanged?.call(picked);
              }
            },
      child: Text(
        options[value] ?? options.values.first,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

Future<String?> pickJmCloudFolder(
  BuildContext context, {
  required String label,
  required Map<String, String> options,
  required ValueChanged<ModalRoute<dynamic>?> onRoute,
}) => showBookshelfManagementIsland<String>(
  context: context,
  builder: (context) {
    onRoute(ModalRoute.of(context));
    return _JmFolderSelection(
      label: label,
      value: '',
      options: options,
      showCreate: true,
    );
  },
);

const jmCreateFolderChoice = 'cloud-folder.create';

class _JmFolderSelection extends StatefulWidget {
  const _JmFolderSelection({
    required this.label,
    required this.value,
    required this.options,
    this.showCreate = false,
  });
  final String label, value;
  final Map<String, String> options;
  final bool showCreate;
  @override
  State<_JmFolderSelection> createState() => _JmFolderSelectionState();
}

class _JmFolderSelectionState extends State<_JmFolderSelection> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final needle = _query.trim().toLowerCase();
    final rows = widget.options.entries
        .where((e) => e.value.toLowerCase().contains(needle))
        .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: t.common.close,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        if (widget.options.length > 8)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SearchFieldSurface(
              child: TextField(
                key: const ValueKey('jm-folder.search'),
                decoration: searchFieldDecoration(
                  context,
                  hintText: t.comicList.searchOptions,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
          ),
        if (widget.showCreate)
          ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: Text(t.bookshelf.createFolder),
            onTap: () => Navigator.of(context).pop(jmCreateFolderChoice),
          ),
        const SizedBox(height: 8),
        if (widget.options.isNotEmpty)
          Flexible(
            child: rows.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(t.comicList.noMatchingOptions),
                  )
                : ListView.builder(
                    key: const ValueKey('jm-folder.options'),
                    primary: false,
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: rows.length,
                    itemBuilder: (context, index) => ListTile(
                      title: Text(rows[index].value),
                      selected: rows[index].key == widget.value,
                      trailing: rows[index].key == widget.value
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () => Navigator.of(context).pop(rows[index].key),
                    ),
                  ),
          ),
      ],
    );
  }
}
