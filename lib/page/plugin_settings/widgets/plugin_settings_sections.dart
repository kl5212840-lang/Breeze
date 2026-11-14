import 'package:zephyr/widgets/touch_hover_intent.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';

class PluginSettingsSectionCard extends StatelessWidget {
  const PluginSettingsSectionCard({
    super.key,
    required this.title,
    required this.colorScheme,
    required this.children,
    this.footer,
    this.headerTrailing,
    this.details = const {},
    this.hasLeading = false,
  });

  final String title;
  final ColorScheme colorScheme;
  final List<Widget> children;
  final String? footer;
  final Widget? headerTrailing;
  final Map<String, String> details;
  final bool hasLeading;

  @override
  Widget build(BuildContext context) {
    return SettingSection(
      title: title,
      footer: footer,
      headerTrailing: headerTrailing,
      details: details,
      hasLeading: hasLeading,
      children: children,
    );
  }
}

class PluginSettingsFieldRow extends StatelessWidget {
  const PluginSettingsFieldRow({
    super.key,
    required this.title,
    this.subtitle = '',
    this.trailing,
    required this.onTap,
    this.destructive = false,
    this.currentValue,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final String? currentValue;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => TouchHoverIntent(
        identity: title,
        builder: (context, hover) => ListTile(
          hoverColor: hover.hoverColor(),
          minTileHeight: 44,
          onTap: onTap,
          title: Text(
            title,
            style: destructive
                ? TextStyle(
                    color: onTap == null
                        ? colorScheme.outline
                        : colorScheme.error,
                  )
                : null,
          ),
          subtitle: subtitle.trim().isEmpty ? null : Text(subtitle),
          trailing: currentValue == null
              ? trailing
              : ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.hasBoundedWidth
                        ? ((constraints.maxWidth - 32) / 2).clamp(
                            44.0,
                            double.infinity,
                          )
                        : 180,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Tooltip(
                          message: currentValue!,
                          child: Text(
                            currentValue!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ),
                      if (trailing case final control?) ...[
                        const SizedBox(width: 8),
                        control,
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class PluginSettingsOptionPair {
  const PluginSettingsOptionPair({required this.label, required this.value});

  final String label;
  final dynamic value;
}
