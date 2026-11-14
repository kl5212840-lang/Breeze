import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/discover/service/discover_plugin_visibility.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart'
    show settingSwitchThumbIcon;
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_management_island.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_switch.dart';

class DiscoverPluginVisibilityOption {
  const DiscoverPluginVisibilityOption({required this.id, required this.title});
  final String id, title;
}

/// Switches edit a draft. Dismissing the sheet cancels; Done persists once.
class PluginVisibilitySheet extends StatefulWidget {
  const PluginVisibilitySheet({
    super.key,
    required this.plugins,
    required this.preferences,
    this.systemControls = true,
  });
  final List<DiscoverPluginVisibilityOption> plugins;
  final DiscoverPluginVisibility preferences;
  final bool systemControls;

  @override
  State<PluginVisibilitySheet> createState() => _PluginVisibilitySheetState();
}

class _PluginVisibilitySheetState extends State<PluginVisibilitySheet> {
  late final Set<String> _hidden = {...widget.preferences.hiddenIds};
  bool _saving = false, _failed = false;
  ValueChanged<bool>? _setIslandBusy;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setIslandBusy = BookshelfManagementIslandScope.maybeOf(context)?.setBusy;
  }

  Future<void> _save() async {
    if (_saving) return;
    _setIslandBusy?.call(true);
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await widget.preferences.saveHiddenIds(_hidden);
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final titleCounts = <String, int>{};
    for (final plugin in widget.plugins) {
      titleCounts[plugin.title] = (titleCounts[plugin.title] ?? 0) + 1;
    }
    return VideoControlAppearance(
      systemControls: widget.systemControls,
      child: Material(
        type: MaterialType.transparency,
        child: PopScope(
          canPop: !_saving,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.discover.visiblePlugins,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: t.common.cancel,
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  t.discover.visiblePluginsHint,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colors.onSurface),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.plugins.length,
                  itemBuilder: (context, index) {
                    final plugin = widget.plugins[index];
                    return BreezeSwitchListTile(
                      SwitchListTile.adaptive(
                        key: ValueKey('discover.visibility.${plugin.id}'),
                        title: Text(
                          plugin.title,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: colors.onSurface),
                        ),
                        subtitle: titleCounts[plugin.title]! > 1
                            ? Text(plugin.id)
                            : null,
                        value: !_hidden.contains(plugin.id),
                        thumbIcon: AppInterfaceStyleScope.usesSystem(context)
                            ? null
                            : settingSwitchThumbIcon(context),
                        onChanged: _saving
                            ? null
                            : (shown) => setState(() {
                                _failed = false;
                                if (shown) {
                                  _hidden.remove(plugin.id);
                                } else {
                                  _hidden.add(plugin.id);
                                }
                              }),
                      ),
                    );
                  },
                ),
              ),
              if (_failed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Text(
                    t.error.saveFailed,
                    style: TextStyle(color: colors.error),
                    semanticsLabel: t.error.saveFailed,
                  ),
                ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: VideoControlAppearance(
                  systemControls: widget.systemControls,
                  child: LayoutBuilder(
                    builder: (context, constraints) => OverflowBar(
                      alignment: MainAxisAlignment.spaceBetween,
                      spacing: 12,
                      overflowSpacing: 8,
                      children: [
                        TextButton(
                          onPressed: _saving
                              ? null
                              : () => setState(() {
                                  _failed = false;
                                  _hidden.removeAll(
                                    widget.plugins.map((p) => p.id),
                                  );
                                }),
                          child: Text(t.discover.showAllPlugins),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_saving)
                              const Padding(
                                padding: EdgeInsets.only(right: 12),
                                child: SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            FilledButton(
                              onPressed: _saving ? null : _save,
                              child: Text(t.common.done),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
