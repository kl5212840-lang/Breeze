import 'package:zephyr/page/search/widget/search_toolbar_scope.dart';
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
  });
  final VoidCallback? onSearch;
  final Map<String, String> options;
  final List<List<String>> groups;
  final ValueChanged<String> onSelected;
  final bool searching, showSearch, inlineSearch;
  final String keyPrefix;
  @override
  Widget build(BuildContext context) {
    if (inlineSearch && searching) return const SizedBox.shrink();
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
                if (options.containsKey(collectionCoverSettingsAction))
                  collectionCoverSettingsAction,
              },
              options: options,
              optionIcons: collectionMenuIcons(options),
              groups: groups,
              onSelected: onSelected,
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
  });

  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onSelected;

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
    this.sortAction,
    this.viewAction,
    this.countKey,
  });
  final String countLabel;
  final Widget filterButton;
  final Widget? scope, sortAction, viewAction;
  final Key? countKey;
  @override
  Widget build(BuildContext context) {
    final actionExtent = CollectionToolbarMetrics.actionExtentOf(context);
    const gap = CollectionToolbarMetrics.searchControlGap;
    final actions = [?sortAction, filterButton, ?viewAction];
    final count = countLabel.isEmpty
        ? null
        : Text(
            countLabel,
            key: countKey,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          );
    return Padding(
      padding: CollectionToolbarMetrics.contentPaddingOf(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final minimumLabels = MediaQuery.textScalerOf(context).scale(144);
          final scopeOnOwnRow =
              scope != null &&
              count != null &&
              constraints.maxWidth <
                  actions.length * (actionExtent + gap) + minimumLabels;
          final tools = Row(
            spacing: gap,
            children: [
              if (scope != null && !scopeOnOwnRow)
                Expanded(flex: 2, child: scope!),
              if (count != null || scope == null || scopeOnOwnRow)
                Expanded(child: count ?? const SizedBox.shrink()),
              for (final action in actions)
                SizedBox.square(dimension: actionExtent, child: action),
            ],
          );
          return scopeOnOwnRow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [scope!, tools],
                )
              : tools;
        },
      ),
    );
  }
}
