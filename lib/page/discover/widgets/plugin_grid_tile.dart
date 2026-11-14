import 'package:zephyr/plugin/plugin_display_name.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/discover/cubit/discover_cubit.dart';
import 'package:zephyr/page/discover/widgets/plugin_icon_veil.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/widgets/plugin_icon.dart';

/// A compact source launcher with its management actions in a separate menu.
class PluginGridTile extends StatelessWidget {
  const PluginGridTile({
    super.key,
    required this.pluginState,
    required this.infoState,
    required this.isToggling,
    required this.onOpen,
    required this.onSearch,
    this.showSearch = true,
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
  final bool showSearch;
  final ValueChanged<String> onSettings;
  final ValueChanged<bool> onToggleEnabled;
  final VoidCallback onRetry;
  final Future<void> Function(Map<String, dynamic> action) onAction;

  @override
  Widget build(BuildContext context) {
    final name = infoState.data?['name']?.toString().trim() ?? '';
    return PluginDisplayNameBuilder(
      source: pluginState.uuid,
      fallback: name.isEmpty ? pluginState.uuid : name,
      builder: (context, displayName) => _buildWithName(context, displayName),
    );
  }

  Widget _buildWithName(BuildContext context, String displayName) {
    final info = infoState.data;
    final name = info?['name']?.toString().trim();
    final title = name?.isNotEmpty == true ? name! : pluginState.uuid;
    final enabled = pluginState.isActive;
    final functions = asJsonList(
      info?['functions'] ?? info?['function'] ?? const <dynamic>[],
    ).map(asJsonMap).toList();
    final loaded =
        !infoState.loading && infoState.error == null && info != null;
    final canOpen = enabled && !isToggling && loaded;
    final colorScheme = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: enabled ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
    );
    final VoidCallback? open = !infoState.loading && !loaded
        ? onRetry
        : canOpen
        ? onOpen ??
              (functions.isNotEmpty
                  ? () => _showFunctions(context, title, functions)
                  : null)
        : null;

    return Material(
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      // UIKit owns its controls' shapes. A rounded Flutter clip here also
      // clips later route overlays in the iOS 3.47 platform-view slicer.
      clipBehavior: Clip.none,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
        child: Column(
          children: [
            // Keep the native menu outside the Flutter launch recognizer.
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final measure = TextPainter(
                    text: TextSpan(text: displayName, style: titleStyle),
                    textDirection: Directionality.of(context),
                    textScaler: MediaQuery.textScalerOf(context),
                    maxLines: 2,
                  )..layout(maxWidth: constraints.maxWidth);
                  final iconSize = (constraints.maxHeight - measure.height - 4)
                      .clamp(44.0, 80.0);
                  measure.dispose();
                  return InkWell(
                    key: ValueKey('plugin-grid.${pluginState.uuid}.open'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: open,
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        children: [
                          SizedBox.square(
                            dimension: iconSize,
                            child: Stack(
                              children: [
                                PluginIconVeil(
                                  enabled: enabled || !loaded,
                                  radius: 15,
                                  child: ColoredBox(
                                    color: colorScheme.surfaceContainerHighest,
                                    child: _buildIcon(context, info),
                                  ),
                                ),
                                if (isToggling)
                                  const Positioned(
                                    right: 2,
                                    bottom: 2,
                                    child: SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                else if (!enabled)
                                  Positioned(
                                    right: 2,
                                    bottom: 2,
                                    child: Tooltip(
                                      message: t.discover.disabled,
                                      child: Icon(
                                        Icons.pause_circle_filled_rounded,
                                        size: 18,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: titleStyle,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox.square(
              dimension: 44,
              child: _buildManagementMenu(
                context,
                title,
                displayName,
                searchAvailable: canOpen && showSearch,
                enabled: enabled,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementMenu(
    BuildContext context,
    String title,
    String displayName, {
    required bool searchAvailable,
    required bool enabled,
  }) {
    return VideoControlAppearance(
      systemControls: usesNativeSourceChrome(context),
      child: NativeVideoMenu(
        key: ValueKey('plugin-grid.${pluginState.uuid}.manage'),
        label: '',
        tooltip: '$displayName · ${t.discover.pluginManagement}',
        selected: '',
        width: 44,
        bare: true,
        secondary: true,
        icon: Icons.more_horiz,
        symbol: 'ellipsis',
        hostPresentation: true,
        selectAfterDismissal: const {'search', 'settings'},
        options: {
          if (searchAvailable) 'search': t.sourceShell.search,
          'settings': t.discover.settings,
          if (!isToggling && enabled) 'disable': t.discover.disablePlugin,
          if (!isToggling && !enabled) 'enable': t.discover.enablePlugin,
        },
        optionIcons: {
          'search': (icon: Icons.search, symbol: 'magnifyingglass'),
          'settings': (icon: Icons.settings_outlined, symbol: 'gearshape'),
          'disable': (icon: Icons.pause_circle_outline, symbol: 'pause.circle'),
          'enable': (icon: Icons.power_settings_new, symbol: 'power'),
        },
        onSelected: (action) {
          if (!context.mounted) return;
          switch (action) {
            case 'search':
              if (searchAvailable) onSearch();
            case 'settings':
              onSettings(title);
            case 'disable':
              if (!isToggling && enabled) onToggleEnabled(false);
            case 'enable':
              if (!isToggling && !enabled) onToggleEnabled(true);
          }
        },
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
      pluginUuid: pluginState.uuid,
      url: info['iconUrl']?.toString().trim() ?? '',
      placeholder: const Center(
        child: Icon(Icons.extension_outlined, size: 32),
      ),
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
