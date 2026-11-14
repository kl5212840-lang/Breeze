import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
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

/// JM's cloud favorites and local record pages share the same three actions.
/// The More trigger is icon-only; a sort check never adds selection chevrons.
class JmCollectionNavigationActions extends StatelessWidget {
  const JmCollectionNavigationActions({
    super.key,
    required this.onSearch,
    required this.options,
    required this.groups,
    required this.onSelected,
    this.searching = false,
    this.selected = '',
    this.keyPrefix = 'jm-collection',
    this.reserveSortSlot = false,
    this.inlineSearch = false,
  });
  final VoidCallback? onSearch;
  final Map<String, String> options;
  final List<List<String>> groups;
  final ValueChanged<String> onSelected;
  final bool searching, reserveSortSlot, inlineSearch;
  final String selected, keyPrefix;
  @override
  Widget build(BuildContext context) {
    final sortOptions = {
      for (final e in options.entries)
        if (e.key.startsWith('sort.')) e.key: e.value,
    };
    final moreOptions = {
      for (final e in options.entries)
        if (!e.key.startsWith('sort.')) e.key: e.value,
    };
    final icons = collectionMenuIcons(options);
    final showActions = !inlineSearch || !searching;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        end: CollectionToolbarMetrics.horizontalInset,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SourceChromeIconButton(
            key: ValueKey('$keyPrefix.search'),
            tooltip: searching ? t.common.close : t.common.search,
            icon: searching ? Icons.close_rounded : Icons.search_rounded,
            symbol: searching ? 'xmark' : 'magnifyingglass',
            onPressed: onSearch,
          ),
          if (showActions && (sortOptions.isNotEmpty || reserveSortSlot))
            VideoControlAppearance(
              systemControls: usesNativeSourceChrome(context),
              child: NativeVideoMenu(
                key: ValueKey('$keyPrefix.sort'),
                label: '',
                tooltip:
                    '排序${options[selected] == null ? '' : ' · ${options[selected]}'}',
                selected: selected,
                icon: Icons.sort_rounded,
                symbol: 'arrow.up.arrow.down',
                width: CollectionToolbarMetrics.actionExtent,
                hostPresentation: true,
                options: sortOptions,
                optionIcons: icons,
                onSelected: onSelected,
              ),
            ),
          if (showActions) const CollectionCoverPrivacyButton(),
          if (showActions)
            VideoControlAppearance(
              systemControls: usesNativeSourceChrome(context),
              child: NativeVideoMenu(
                key: ValueKey('$keyPrefix.more'),
                label: '',
                tooltip: t.common.more,
                selected: selected,
                icon: Icons.more_horiz,
                symbol: 'ellipsis',
                width: CollectionToolbarMetrics.actionExtent,
                hostPresentation: true,
                selectAfterDismissal: {
                  if (moreOptions.containsKey(collectionCoverSettingsAction))
                    collectionCoverSettingsAction,
                },
                options: moreOptions,
                optionIcons: icons,
                groups: [
                  for (final group in groups)
                    [
                      for (final key in group)
                        if (moreOptions.containsKey(key)) key,
                    ],
                ],
                onSelected: onSelected,
              ),
            ),
        ],
      ),
    );
  }
}

/// Mount all collection controls with the destination body on its first frame.
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
      return JmCollectionNavigationActions(
        keyPrefix: 'jm-record',
        reserveSortSlot: true,
        inlineSearch: true,
        onSearch: actions?.onSearch,
        searching: actions?.searching ?? false,
        options: actions?.options ?? const {},
        groups: actions?.groups ?? const [],
        selected: actions?.selected ?? '',
        onSelected: (value) => controller.actions?.onSelected(value),
      );
    },
  );
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
  });
  final String label, value;
  final Map<String, String> options;
  final ValueChanged<String>? onChanged;

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
                builder: (context) => _JmFolderSelection(
                  label: label,
                  value: value,
                  options: options,
                ),
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

class _JmFolderSelection extends StatefulWidget {
  const _JmFolderSelection({
    required this.label,
    required this.value,
    required this.options,
  });
  final String label, value;
  final Map<String, String> options;
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
        const SizedBox(height: 8),
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

/// Scope and counts form the left reading group; the filter has a fixed trailing
/// slot, regardless of a missing folder selector or a short/long folder name.
class JmCollectionResultsRow extends StatelessWidget {
  const JmCollectionResultsRow({
    super.key,
    required this.countLabel,
    required this.filterButton,
    this.scope,
    this.viewAction,
    this.countKey,
  });
  final String countLabel;
  final Widget filterButton;
  final Widget? scope, viewAction;
  final Key? countKey;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: CollectionToolbarMetrics.horizontalInset,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (scope != null) ...[
          Expanded(flex: 2, child: scope!),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            countLabel,
            key: countKey,
            maxLines: 2,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(width: 8),
        ?viewAction,
        SizedBox.square(
          dimension: CollectionToolbarMetrics.actionExtent,
          child: filterButton,
        ),
      ],
    ),
  );
}
