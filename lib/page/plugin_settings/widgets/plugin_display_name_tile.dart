import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/plugin_settings/widgets/plugin_settings_sections.dart';
import 'package:zephyr/plugin/plugin_display_name.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/widgets/action_feedback.dart';

class PluginDisplayNameTile extends StatefulWidget {
  const PluginDisplayNameTile({
    super.key,
    required this.source,
    this.enabled = true,
  });
  final String source;
  final bool enabled;
  @override
  State<PluginDisplayNameTile> createState() => _PluginDisplayNameTileState();
}

class _PluginDisplayNameTileState extends State<PluginDisplayNameTile> {
  bool _editing = false;
  String get _original {
    final name =
        PluginRegistryService.I
            .getCachedPluginInfo(widget.source)?['name']
            ?.toString()
            .trim() ??
        '';
    return name.isEmpty ? widget.source : name;
  }

  Future<void> _edit() async {
    if (_editing || !widget.enabled) return;
    final source = widget.source;
    setState(() => _editing = true);
    try {
      final previous = readPluginDisplayName(source);
      await showDialog<void>(
        context: context,
        builder: (_) => _DisplayNameDialog(
          source: source,
          previous: previous,
          original: _original,
          canCommit: () => mounted && widget.enabled && widget.source == source,
        ),
      );
    } catch (_) {
      if (mounted) showErrorToast(t.pluginAppearance.saveFailed);
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  @override
  Widget build(BuildContext context) => PluginDisplayNameBuilder(
    source: widget.source,
    fallback: _original,
    builder: (context, name) => PluginSettingsFieldRow(
      key: const ValueKey('plugin-display-name-edit'),
      title: t.pluginAppearance.displayName,
      currentValue: name,
      trailing: const Icon(Icons.edit_outlined),
      onTap: widget.enabled && !_editing ? _edit : null,
    ),
  );
}

class _DisplayNameDialog extends StatefulWidget {
  const _DisplayNameDialog({
    required this.source,
    required this.previous,
    required this.original,
    required this.canCommit,
  });
  final String source, previous, original;
  final bool Function() canCommit;
  @override
  State<_DisplayNameDialog> createState() => _DisplayNameDialogState();
}

class _DisplayNameDialogState extends State<_DisplayNameDialog> {
  late final _text = TextEditingController(text: widget.previous);
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !widget.canCommit()) return;
    final name = _text.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name == widget.previous) {
      Navigator.of(context).pop();
      return;
    }
    if (name.runes.length > pluginDisplayNameMaximumLength) {
      setState(() => _error = t.pluginAppearance.displayNameTooLong);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await savePluginDisplayName(
        widget.source,
        name,
        expectedName: widget.previous,
      );
      if (mounted && widget.canCommit()) {
        showActionFeedback(context, t.common.saved);
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) setState(() => _error = t.pluginAppearance.saveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      scrollable: true,
      title: Text(t.pluginAppearance.displayNameEdit),
      content: TextField(
        key: const ValueKey('plugin-display-name-input'),
        controller: _text,
        autofocus: true,
        enabled: !_saving,
        maxLines: 1,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          hintText: widget.original,
          helperText: t.pluginAppearance.displayNameHint,
          helperMaxLines: 3,
          errorText: _error,
          errorMaxLines: 3,
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () => setState(() {
                  _text.clear();
                  _error = null;
                }),
          child: Text(t.pluginAppearance.displayNameOriginal),
        ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        TextButton(
          key: const ValueKey('plugin-display-name-save'),
          onPressed: _saving ? null : _save,
          child: Text(t.common.save),
        ),
      ],
    ),
  );
}
