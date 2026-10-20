import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/discover/cubit/discover_cubit.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/widgets/plugin_icon.dart';

enum _PluginGridAction { search, settings, toggle }

/// A compact app-style launcher. Secondary actions remain visible in the
/// overflow menu, including the enable action for disabled plugins.
class PluginGridTile extends StatelessWidget {
  const PluginGridTile({
    super.key,
    required this.pluginState,
    required this.infoState,
    required this.isToggling,
    required this.onOpen,
    required this.onSearch,
    required this.onSettings,
    required this.onToggleEnabled,
    required this.onRetry,
    required this.onAction,
  });

  final PluginRuntimeState pluginState;
  final DiscoverPluginInfoState infoState;
  final bool isToggling;
  final VoidCallback? onOpen;
  final VoidCallback onSearch;
  final void Function(String title) onSettings;
  final ValueChanged<bool> onToggleEnabled;
  final VoidCallback onRetry;
  final Future<void> Function(Map<String, dynamic> action) onAction;

  @override
  Widget build(BuildContext context) {
    final info = infoState.data;
    final name = info?['name']?.toString().trim();
    final title = name?.isNotEmpty == true ? name! : pluginState.uuid;
    final enabled = pluginState.isEnabled;
    final functions = asJsonList(
      info?['functions'] ?? info?['function'] ?? const <dynamic>[],
    ).map(asJsonMap).toList();
    final canOpen = enabled && !infoState.loading && infoState.error == null;
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: infoState.error != null
            ? onRetry
            : canOpen
            ? onOpen ??
                  (functions.isNotEmpty
                      ? () => _showFunctions(context, title, functions)
                      : null)
            : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
          child: Column(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: ColoredBox(
                    color: colorScheme.surfaceContainerHighest,
                    child: _buildIcon(context, info),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      infoState.error != null
                          ? t.common.retry
                          : enabled
                          ? ''
                          : t.discover.disabled,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (isToggling)
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else
                    PopupMenuButton<_PluginGridAction>(
                      tooltip: t.discover.moreActions(title: title),
                      icon: const Icon(Icons.more_horiz, size: 20),
                      padding: EdgeInsets.zero,
                      onSelected: (action) {
                        switch (action) {
                          case _PluginGridAction.search:
                            onSearch();
                          case _PluginGridAction.settings:
                            onSettings(title);
                          case _PluginGridAction.toggle:
                            onToggleEnabled(!enabled);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: _PluginGridAction.search,
                          enabled: enabled,
                          child: Text(t.sourceShell.search),
                        ),
                        PopupMenuItem(
                          value: _PluginGridAction.settings,
                          child: Text(t.discover.settings),
                        ),
                        PopupMenuItem(
                          value: _PluginGridAction.toggle,
                          child: Text(
                            enabled
                                ? t.discover.disablePlugin
                                : t.discover.enablePlugin,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context, Map<String, dynamic>? info) {
    if (infoState.loading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (infoState.error != null || info == null) {
      return Icon(Icons.refresh, color: Theme.of(context).colorScheme.error);
    }
    return PluginIcon(
      url: info['iconUrl']?.toString().trim() ?? '',
      placeholder: const Center(child: Icon(Icons.extension_outlined)),
    );
  }

  Future<void> _showFunctions(
    BuildContext context,
    String title,
    List<Map<String, dynamic>> functions,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final function in functions)
              ListTile(
                title: Text(
                  function['title']?.toString().trim() ?? t.discover.unnamed,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final id = function['id']?.toString().trim() ?? '';
                  var action = asJsonMap(function['action']);
                  if (action.isEmpty && id.isNotEmpty) {
                    action = {
                      'type': 'openPluginFunction',
                      'payload': {
                        'id': id,
                        'title': function['title']?.toString() ?? '',
                        'presentation': 'page',
                      },
                    };
                  }
                  Navigator.pop(sheetContext);
                  if (action.isNotEmpty && context.mounted) {
                    await onAction(action);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
