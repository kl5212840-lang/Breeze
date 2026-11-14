import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_management_island.dart';
import 'package:zephyr/page/discover/service/discover_plugin_management.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart'
    show settingSwitchThumbIcon;
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/plugin_icon.dart';
import 'package:zephyr/widgets/breeze_switch.dart';

class DiscoverPluginManagementOption {
  const DiscoverPluginManagementOption({
    required this.id,
    required this.title,
    this.iconUrl = '',
    this.enabled = true,
    this.toggling = false,
  });
  final String id, title, iconUrl;
  final bool enabled, toggling;
}

/// Visibility and order share one draft, identified by stable plugin UUIDs.
/// All controls are Flutter-painted to keep text readable inside the island.
class PluginManagementIsland extends StatefulWidget {
  const PluginManagementIsland({
    super.key,
    required this.plugins,
    required this.defaultOrder,
    required this.hiddenIds,
    required this.onSave,
    this.onSettings,
    this.onToggleEnabled,
  });
  final List<DiscoverPluginManagementOption> plugins;
  final List<String> defaultOrder;
  final Set<String> hiddenIds;
  final Future<void> Function(DiscoverPluginManagementDraft) onSave;
  final Future<void> Function(DiscoverPluginManagementOption)? onSettings;
  final Future<void> Function(String, bool)? onToggleEnabled;
  @override
  State<PluginManagementIsland> createState() => _PluginManagementIslandState();
}

class _PluginManagementIslandState extends State<PluginManagementIsland> {
  late List<String> _order = widget.plugins.map((plugin) => plugin.id).toList();
  late final _hidden = {...widget.hiddenIds};
  bool _saving = false, _failed = false, _restoreDefaultOrder = false;
  String? _expandedId;
  bool _openingSettings = false;
  ValueChanged<bool>? _setIslandBusy;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setIslandBusy = BookshelfManagementIslandScope.maybeOf(context)?.setBusy;
  }

  @override
  void didUpdateWidget(PluginManagementIsland oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = widget.plugins.map((plugin) => plugin.id).toSet();
    if (!current.contains(_expandedId)) _expandedId = null;
    _order = [
      for (final id in _order)
        if (current.contains(id)) id,
      for (final plugin in widget.plugins)
        if (!_order.contains(plugin.id)) plugin.id,
    ];
  }

  void _reset() => setState(() {
    final current = widget.plugins.map((plugin) => plugin.id).toSet();
    _order = [
      for (final id in widget.defaultOrder)
        if (current.contains(id)) id,
      for (final plugin in widget.plugins)
        if (!widget.defaultOrder.contains(plugin.id)) plugin.id,
    ];
    // Absent IDs remain hidden if the same plugin is reinstalled later.
    _hidden.removeAll(current);
    _restoreDefaultOrder = true;
    _failed = false;
  });

  void _toggle(String id, bool shown) => setState(() {
    shown ? _hidden.remove(id) : _hidden.add(id);
    _failed = false;
  });

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    _setIslandBusy?.call(true);
    try {
      await widget.onSave(
        DiscoverPluginManagementDraft(
          order: _order,
          hiddenIds: _hidden,
          restoreDefaultOrder: _restoreDefaultOrder,
        ),
      );
      if (mounted) {
        _setIslandBusy?.call(false);
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        _setIslandBusy?.call(false);
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _openSettings(DiscoverPluginManagementOption plugin) async {
    if (_openingSettings || _saving) return;
    setState(() => _openingSettings = true);
    try {
      await widget.onSettings!(plugin);
    } finally {
      if (mounted) setState(() => _openingSettings = false);
    }
  }

  Widget _buildPluginRow(
    BuildContext context,
    DiscoverPluginManagementOption plugin,
    int index, {
    required bool showId,
  }) {
    final shown = !_hidden.contains(plugin.id);
    final colors = Theme.of(context).colorScheme;
    return Material(
      key: ValueKey('plugin-manager.row.${plugin.id}'),
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _saving ? null : () => _toggle(plugin.id, !shown),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: SizedBox.square(
                            dimension: 36,
                            child: PluginIcon(
                              pluginUuid: plugin.id,
                              url: plugin.iconUrl,
                              placeholder: ColoredBox(
                                color: colors.surfaceContainerHighest,
                                child: const Icon(
                                  Icons.extension_outlined,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plugin.title,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              if (showId)
                                Text(
                                  plugin.id,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Semantics(
                  label: '${plugin.title} · ${t.discover.visiblePlugins}',
                  child: SizedBox(
                    width: 60,
                    height: 44,
                    child: BreezeSwitch(
                      Switch.adaptive(
                        key: ValueKey('plugin-manager.visible.${plugin.id}'),
                        value: shown,
                        thumbIcon: AppInterfaceStyleScope.usesSystem(context)
                            ? null
                            : settingSwitchThumbIcon(context),
                        onChanged: _saving
                            ? null
                            : (value) => _toggle(plugin.id, value),
                      ),
                    ),
                  ),
                ),
                ReorderableDragStartListener(
                  key: ValueKey('plugin-manager.drag.${plugin.id}'),
                  index: index,
                  enabled: !_saving,
                  child: Tooltip(
                    message: t.bookshelf.reorderSources,
                    child: const SizedBox.square(
                      dimension: 44,
                      child: Icon(Icons.drag_handle_rounded, size: 22),
                    ),
                  ),
                ),
                if (widget.onSettings != null || widget.onToggleEnabled != null)
                  Semantics(
                    expanded: _expandedId == plugin.id,
                    child: IconButton(
                      key: ValueKey('plugin-manager.actions.${plugin.id}'),
                      constraints: const BoxConstraints.tightFor(
                        width: 44,
                        height: 44,
                      ),
                      tooltip: t.discover.moreActions(title: plugin.title),
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                              _expandedId = _expandedId == plugin.id
                                  ? null
                                  : plugin.id;
                            }),
                      icon: Icon(
                        _expandedId == plugin.id
                            ? Icons.expand_less
                            : Icons.more_horiz,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_expandedId == plugin.id)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Wrap(
                spacing: 8,
                children: [
                  if (widget.onSettings != null)
                    TextButton.icon(
                      key: ValueKey('plugin-manager.settings.${plugin.id}'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                      onPressed: _saving || _openingSettings
                          ? null
                          : () => _openSettings(plugin),
                      icon: const Icon(Icons.settings_outlined),
                      label: Text(t.discover.settings),
                    ),
                  if (widget.onToggleEnabled != null)
                    TextButton.icon(
                      key: ValueKey('plugin-manager.enabled.${plugin.id}'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                      onPressed: _saving || plugin.toggling
                          ? null
                          : () => widget.onToggleEnabled!(
                              plugin.id,
                              !plugin.enabled,
                            ),
                      icon: plugin.toggling
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              plugin.enabled
                                  ? Icons.pause_circle_outline
                                  : Icons.power_settings_new,
                            ),
                      label: Text(
                        plugin.enabled
                            ? t.discover.disablePlugin
                            : t.discover.enablePlugin,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final byId = {for (final plugin in widget.plugins) plugin.id: plugin};
    final titleCounts = <String, int>{};
    for (final plugin in widget.plugins) {
      titleCounts[plugin.title] = (titleCounts[plugin.title] ?? 0) + 1;
    }
    return PopScope(
      canPop: !_saving,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t.discover.pluginManagement,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const ValueKey('plugin-manager.close'),
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  tooltip: t.common.close,
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          if (_saving) const LinearProgressIndicator(minHeight: 2),
          Flexible(
            fit: FlexFit.loose,
            child: CustomScrollView(
              key: const ValueKey('plugin-manager.scroll'),
              shrinkWrap: true,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.discover.visiblePlugins,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Text(
                          t.discover.visiblePluginsHint,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverReorderableList(
                  itemCount: _order.length,
                  onReorderItem: _saving
                      ? (_, _) {}
                      : (oldIndex, newIndex) => setState(() {
                          _order.insert(newIndex, _order.removeAt(oldIndex));
                          _restoreDefaultOrder = false;
                          _failed = false;
                        }),
                  itemBuilder: (context, index) {
                    final plugin = byId[_order[index]]!;
                    return _buildPluginRow(
                      context,
                      plugin,
                      index,
                      showId: titleCounts[plugin.title]! > 1,
                    );
                  },
                ),
                if (_order.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(t.common.empty),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: TextButton(
                        key: const ValueKey('plugin-manager.reset'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, 44),
                        ),
                        onPressed: _saving ? null : _reset,
                        child: Text(t.bookshelf.sourceLabelsReset),
                      ),
                    ),
                  ),
                ),
                if (_failed)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        t.error.saveFailed,
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                TextButton(
                  key: const ValueKey('plugin-manager.cancel'),
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: Text(t.common.cancel),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('plugin-manager.save'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(44, 44),
                    ),
                    onPressed: _saving ? null : _save,
                    child: Text(t.common.done, textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
