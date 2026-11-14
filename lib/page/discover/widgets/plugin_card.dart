import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/discover/cubit/discover_cubit.dart';
import 'package:zephyr/page/discover/widgets/plugin_icon_veil.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart'
    show settingSwitchThumbIcon;
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/plugin/plugin_display_name.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/type/pipe.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/util/text/chinese_convert.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_switch.dart';
import 'package:zephyr/widgets/plugin_icon.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';

class PluginCard extends StatelessWidget {
  const PluginCard({
    super.key,
    required this.pluginUuid,
    required this.pluginState,
    required this.infoState,
    this.pendingEnabled,
    required this.onSearch,
    this.showSearch = true,
    required this.onOpen,
    required this.onSettings,
    required this.onToggleEnabled,
    required this.onRetry,
    required this.onAction,
  });

  final String pluginUuid;
  final PluginRuntimeState pluginState;
  final DiscoverPluginInfoState infoState;
  final bool? pendingEnabled;
  bool get isToggling => pendingEnabled != null;
  final VoidCallback onSearch;
  final bool showSearch;
  final VoidCallback? onOpen;
  final ValueChanged<String> onSettings;
  final ValueChanged<bool> onToggleEnabled;
  final VoidCallback onRetry;
  final Future<void> Function(Map<String, dynamic> action) onAction;

  @override
  Widget build(BuildContext context) {
    if (infoState.loading) {
      return _buildFrame(
        primary: _buildLoading(context),
        controls: _buildControls(context, pluginUuid, searchAvailable: false),
        separateControls: true,
      );
    }
    if (infoState.error != null || infoState.data == null) {
      return _buildFrame(
        primary: _buildError(context, infoState.error),
        controls: _buildControls(context, pluginUuid, searchAvailable: false),
        separateControls: true,
      );
    }
    return _buildLoaded(context, infoState.data!);
  }

  Widget _buildLoading(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(t.common.loading)),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, String? error) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              t.discover.pluginInfoLoadFailed(
                error: userFacingErrorMessage(error ?? ''),
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(t.common.retry)),
        ],
      ),
    );
  }

  Widget _buildLoaded(BuildContext context, Map<String, dynamic> info) {
    final name = info['name']?.toString().trim() ?? '';
    return PluginDisplayNameBuilder(
      source: pluginUuid,
      fallback: name.isEmpty ? t.discover.pluginCapability : name,
      builder: (context, displayName) =>
          _buildLoadedWithName(context, info, displayName),
    );
  }

  Widget _buildLoadedWithName(
    BuildContext context,
    Map<String, dynamic> info,
    String displayName,
  ) {
    final enabled = pluginState.isActive;
    final canInteract = enabled && !isToggling;
    final colors = Theme.of(context).colorScheme;
    // The source shell already presents its declared functions. Sources without
    // a shell keep their independent shortcuts.
    final shortcuts = onOpen == null
        ? asJsonList(
            info['functions'] ?? info['function'],
          ).map(asJsonMap).toList()
        : const <Map<String, dynamic>>[];
    final iconUrl = info['iconUrl']?.toString().trim() ?? '';
    final name = Text(
      displayName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
    );
    final identity = Row(
      key: ValueKey('plugin-card.$pluginUuid.identity'),
      children: [
        SizedBox.square(
          dimension: 56,
          child: PluginIconVeil(
            enabled: enabled,
            radius: 12,
            child: PluginIcon(
              pluginUuid: pluginUuid,
              url: iconUrl,
              placeholder: ColoredBox(
                color: colors.surfaceContainerHighest,
                child: const Center(child: Icon(Icons.extension_outlined)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          // Reserve room for the closed state at large text sizes.
          child: Stack(
            alignment: AlignmentDirectional.centerStart,
            children: [
              Visibility(
                visible: !enabled,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    name,
                    const SizedBox(height: 4),
                    Text(
                      t.discover.disabled,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (enabled) name,
            ],
          ),
        ),
      ],
    );

    final title = info['name']?.toString().trim() ?? '';
    final body = _buildFrame(
      primary: InkWell(
        key: ValueKey('plugin-card.$pluginUuid.open'),
        onTap: canInteract ? onOpen : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            AppInterfaceStyleScope.usesSystem(context) ? 16 : 0,
            10,
            8,
            10,
          ),
          child: identity,
        ),
      ),
      controls: _buildControls(
        context,
        title.isEmpty ? t.discover.pluginCapability : title,
        searchAvailable: showSearch,
      ),
    );
    if (shortcuts.isEmpty) return body;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        body,
        Visibility(
          visible: canInteract,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _buildFunctionButtons(context, shortcuts, colors),
          ),
        ),
      ],
    );
  }

  Widget _buildFrame({
    required Widget primary,
    required Widget controls,
    bool separateControls = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
        if (separateControls || constraints.maxWidth < 328 || textScale > 1.3) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              primary,
              Align(alignment: AlignmentDirectional.centerEnd, child: controls),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: primary),
            controls,
          ],
        );
      },
    );
  }

  Widget _buildControls(
    BuildContext context,
    String title, {
    required bool searchAvailable,
  }) {
    final enabled = pluginState.isActive;
    final system = AppInterfaceStyleScope.usesSystem(context);
    final android = AppInterfaceStyleScope.usesAndroidSystem(context);
    final shownEnabled = pendingEnabled ?? enabled;
    final power = context.select<GlobalSettingCubit?, bool>(
      (cubit) => cubit?.state.switchStyle == BreezeSwitchStyle.power,
    );
    final native = usesNativeSourceChrome(context);
    final readableSurface = VideoControlAppearance.needsReadableSurface(
      context,
    );
    final actionDiameter = native && readableSurface
        ? VideoControlMetrics.touchExtent
        : VideoControlMetrics.touchExtent -
              VideoControlMetrics.backgroundInset * 2;
    final VoidCallback? search = enabled && !isToggling ? onSearch : null;
    void settings() => onSettings(title);
    final actions = <Widget>[
      if (native)
        VideoControlAppearance(
          systemControls: true,
          readableSurface: readableSurface,
          child: NativeVideoIconButtonGroup(
            flatSurface: true,
            buttons: {
              if (searchAvailable)
                'search': NativeVideoIconButton(
                  tooltip: t.sourceShell.search,
                  onPressed: search,
                  icon: Icons.search,
                  symbol: 'magnifyingglass',
                  light: false,
                ),
              'settings': NativeVideoIconButton(
                tooltip: t.discover.settings,
                onPressed: settings,
                icon: Icons.settings_outlined,
                symbol: 'gearshape',
                light: false,
              ),
            },
          ),
        )
      else ...[
        if (searchAvailable)
          SourceChromeIconButton(
            tooltip: t.sourceShell.search,
            onPressed: search,
            icon: Icons.search,
            symbol: 'magnifyingglass',
          ),
        SourceChromeIconButton(
          tooltip: t.discover.settings,
          onPressed: settings,
          icon: Icons.settings_outlined,
          symbol: 'gearshape',
        ),
      ],
    ];
    final toggle = Semantics(
      label: title,
      enabled: isToggling ? false : null,
      toggled: isToggling ? shownEnabled : null,
      child: SizedBox(
        key: ValueKey('plugin-card.$pluginUuid.toggle'),
        width: power ? VideoControlMetrics.touchExtent : 60,
        height: 48,
        child: AbsorbPointer(
          absorbing: isToggling,
          child: ExcludeSemantics(
            excluding: isToggling,
            child: AnimatedOpacity(
              opacity: isToggling ? .65 : 1,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              child: TouchHoverIntent(
                identity: pluginUuid,
                builder: (_, hover) {
                  final control = Switch.adaptive(
                    value: shownEnabled,
                    thumbIcon: android
                        ? const WidgetStateProperty<Icon?>.fromMap({
                            WidgetState.selected: Icon(Icons.check_rounded),
                            WidgetState.any: null,
                          })
                        : system
                        ? null
                        : settingSwitchThumbIcon(context),
                    overlayColor: hover.overlayColor(null),
                    onChanged: (value) {
                      if (!isToggling) onToggleEnabled(value);
                    },
                  );
                  return BreezeSwitch(control, powerDiameter: actionDiameter);
                },
              ),
            ),
          ),
        ),
      ),
    );
    final direction = Directionality.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.only(end: system ? 12 : 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        // Paint the Flutter switch first. Its glow can cross the adjacent
        // UIKit view's edge, which would otherwise need a separate Flutter
        // overlay surface on every row. Keep the same positions in both directions.
        textDirection: native
            ? (direction == TextDirection.ltr
                  ? TextDirection.rtl
                  : TextDirection.ltr)
            : direction,
        children: native ? [toggle, ...actions] : [...actions, toggle],
      ),
    );
  }

  Widget _buildFunctionButtons(
    BuildContext context,
    List<Map<String, dynamic>> rawFunctions,
    ColorScheme colorScheme,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: rawFunctions.map((function) {
        final id = function['id']?.toString().trim() ?? '';
        final text = function['title']?.toString().trim() ?? t.discover.unnamed;
        var action = asJsonMap(function['action']);
        if (action.isEmpty && id.isNotEmpty) {
          action = {
            'type': 'openPluginFunction',
            'payload': {'id': id, 'title': text, 'presentation': 'page'},
          };
        }
        final enabled = action.isNotEmpty;
        return ActionChip(
          label: Text(text.let(convertChineseForDisplay)),
          onPressed: enabled ? () => onAction(action) : null,
          backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.16),
          disabledColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.35,
          ),
          side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.1)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
          visualDensity: VisualDensity.standard,
          materialTapTargetSize: MaterialTapTargetSize.padded,
          labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colorScheme.primary.withValues(alpha: 0.78),
            fontWeight: FontWeight.w500,
          ),
        );
      }).toList(),
    );
  }
}
