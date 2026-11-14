import 'package:zephyr/widgets/touch_hover_intent.dart';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/http/plugin/unified_plugin_envelope.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/widgets/source_choice_menu.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/widgets/breeze_switch.dart';

class PluginSettingSchemeSection extends StatefulWidget {
  const PluginSettingSchemeSection({
    super.key,
    required this.from,
    required this.pluginName,
    this.onValueChanged,
  });

  final String from;
  final String pluginName;
  final Future<void> Function(String key, dynamic value)? onValueChanged;

  @override
  State<PluginSettingSchemeSection> createState() =>
      _PluginSettingSchemeSectionState();
}

class _PluginSettingSchemeSectionState
    extends State<PluginSettingSchemeSection> {
  late Future<UnifiedPluginEnvelope> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<UnifiedPluginEnvelope> _load() async {
    final response = await callUnifiedComicPlugin(
      from: widget.from,
      fnPath: 'getSettingsBundle',
      core: const <String, dynamic>{},
      extern: const <String, dynamic>{},
    );
    return UnifiedPluginEnvelope.fromMap(response);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UnifiedPluginEnvelope>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return ListTile(title: Text(t.plugin.pluginSettingsLoading));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return ListTile(
            title: Text(t.plugin.pluginSettingsLoadFailed),
            subtitle: Text(snapshot.error.toString()),
            trailing: TouchHoverIntent(
              identity: (widget.from, 'retry'),
              builder: (context, hover) {
                const style = ButtonStyle();
                return IconButton(
                  style: style.copyWith(
                    overlayColor: hover.overlayColor(style.overlayColor),
                  ),
                  icon: const Icon(Icons.refresh),
                  onPressed: () => setState(() => _future = _load()),
                );
              },
            ),
          );
        }

        final envelope = snapshot.data!;
        final sections = asJsonList(
          envelope.scheme['sections'],
        ).map((item) => asJsonMap(item)).toList();
        final values = asJsonMap(envelope.data['values']);
        final widgets = <Widget>[];

        for (final section in sections) {
          final title = section['title']?.toString() ?? '';
          if (title.isNotEmpty) {
            widgets.add(
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(title, style: const TextStyle(fontSize: 13)),
              ),
            );
          }
          final fields = asJsonList(
            section['fields'],
          ).map((item) => asJsonMap(item));
          for (final field in fields) {
            widgets.add(_buildField(field, values));
          }
        }

        return Column(children: widgets);
      },
    );
  }

  Widget _buildField(Map<String, dynamic> field, Map<String, dynamic> values) {
    final key = field['key']?.toString() ?? '';
    final label = field['label']?.toString() ?? key;
    final kind = field['kind']?.toString() ?? 'text';
    final value = values[key];

    if (kind == 'select') {
      final options = asJsonList(
        field['options'],
      ).map((e) => e.toString()).toList();
      final current =
          value?.toString() ?? (options.isNotEmpty ? options.first : '');
      final effectiveValue = options.contains(current)
          ? current
          : (options.isEmpty ? '' : options.first);
      return ListTile(
        title: Text(label),
        trailing: SourceChoiceMenu<String>(
          label: effectiveValue,
          tooltip: label,
          value: effectiveValue,
          options: {for (final option in options) option: option},
          onChanged: options.isEmpty
              ? null
              : (next) async {
                  await _persistField(key, next);
                },
        ),
      );
    }

    if (kind == 'switch') {
      final current = value == true;
      return TouchHoverIntent(
        identity: key,
        builder: (context, hover) => BreezeSwitchListTile(
          SwitchListTile.adaptive(
            hoverColor: hover.hoverColor(),
            title: Text(label),
            value: current,
            onChanged: (next) async {
              await _persistField(key, next);
            },
          ),
        ),
      );
    }

    return TouchHoverIntent(
      identity: key,
      builder: (context, hover) => ListTile(
        hoverColor: hover.hoverColor(),
        title: Text(label),
        subtitle: Text(value?.toString() ?? ''),
        trailing: const Icon(Icons.edit_outlined),
        onTap: () async {
          final next = await showPluginSettingInputDialog(
            context,
            title: label,
            initialValue: value?.toString() ?? '',
            obscure: kind == 'password',
          );
          if (next == null || !mounted) return;
          await _persistField(key, next);
        },
      ),
    );
  }

  Future<void> _persistField(String key, dynamic value) async {
    await savePluginConfigValue(widget.pluginName, key, value);
    if (widget.onValueChanged != null) {
      await widget.onValueChanged!(key, value);
    }
    if (!mounted) return;
    showSuccessToast(t.plugin.saved);
    setState(() => _future = _load());
  }
}

class PluginAdvancedActionSection extends StatefulWidget {
  const PluginAdvancedActionSection({super.key, required this.from});

  final String from;

  @override
  State<PluginAdvancedActionSection> createState() =>
      _PluginAdvancedActionSectionState();
}

class _PluginAdvancedActionSectionState
    extends State<PluginAdvancedActionSection> {
  late Future<UnifiedPluginEnvelope> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<UnifiedPluginEnvelope> _load() async {
    final response = await callUnifiedComicPlugin(
      from: widget.from,
      fnPath: 'getCapabilitiesBundle',
      core: const <String, dynamic>{},
      extern: const <String, dynamic>{},
    );
    return UnifiedPluginEnvelope.fromMap(response);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UnifiedPluginEnvelope>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return ListTile(title: Text(t.common.loading));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final actions = asJsonList(
          snapshot.data!.scheme['actions'],
        ).map((item) => asJsonMap(item)).toList();
        if (actions.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          children: actions.map((action) {
            final title = action['title']?.toString() ?? t.plugin.unnamedAction;
            final fnPath = action['fnPath']?.toString() ?? '';
            return TouchHoverIntent(
              identity: fnPath,
              builder: (context, hover) => ListTile(
                hoverColor: hover.hoverColor(),
                leading: const Icon(Icons.extension_outlined),
                title: Text(title),
                subtitle: Text(fnPath),
                onTap: () async {
                  if (fnPath.isEmpty) {
                    showInfoToast(t.plugin.actionNotExecutable);
                    return;
                  }

                  try {
                    final dialogContext = this.context;
                    final result = await callUnifiedComicPlugin(
                      from: widget.from,
                      fnPath: fnPath,
                      core: const <String, dynamic>{},
                      extern: const <String, dynamic>{},
                    );

                    if (!dialogContext.mounted) return;
                    await showDialog<void>(
                      context: dialogContext,
                      builder: (context) => AlertDialog(
                        title: Text(title),
                        content: SingleChildScrollView(
                          child: SelectableText(
                            const JsonEncoder.withIndent('  ').convert(result),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(t.common.close),
                          ),
                        ],
                      ),
                    );
                  } catch (e) {
                    showInfoToast(t.plugin.executeFailed(error: e));
                  }
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

Future<String?> showPluginSettingInputDialog(
  BuildContext context, {
  required String title,
  required String initialValue,
  required bool obscure,
}) async {
  var value = initialValue;
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      scrollable: true,
      content: TextFormField(
        initialValue: initialValue,
        autofocus: true,
        obscureText: obscure,
        autocorrect: !obscure,
        enableSuggestions: !obscure,
        textInputAction: TextInputAction.done,
        onChanged: (next) => value = next,
        onFieldSubmitted: (next) => Navigator.of(context).pop(next),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(value),
          child: Text(t.common.save),
        ),
      ],
    ),
  );
}
