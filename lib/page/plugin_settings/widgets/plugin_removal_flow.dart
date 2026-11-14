import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';

/// Only three outcomes: keep data, delete local, delete local plus Breeze cloud.
class PluginRemovalScope {
  const PluginRemovalScope({this.local = false, this.cloud = false})
    : assert(!cloud || local);
  final bool local, cloud;
}

Future<PluginRemovalScope?> showPluginRemovalScope(
  BuildContext context, {
  required String pluginName,
}) => showDialog<PluginRemovalScope>(
  context: context,
  useRootNavigator: false,
  builder: (_) => _ScopeDialog(pluginName: pluginName),
);

class _ScopeDialog extends StatefulWidget {
  const _ScopeDialog({required this.pluginName});
  final String pluginName;
  @override
  State<_ScopeDialog> createState() => _ScopeDialogState();
}

class _ScopeDialogState extends State<_ScopeDialog> {
  bool local = false, cloud = false;
  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(t.pluginLifecycle.chooseDeleteTitle(name: widget.pluginName)),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.pluginLifecycle.keepDataDescription),
          CheckboxListTile(
            key: const ValueKey('plugin-remove-local'),
            contentPadding: EdgeInsets.zero,
            title: Text(t.pluginLifecycle.deleteLocalData),
            subtitle: Text(t.pluginLifecycle.deleteLocalDataHint),
            value: local,
            onChanged: (value) => setState(() {
              local = value == true;
              if (!local) cloud = false;
            }),
          ),
          CheckboxListTile(
            key: const ValueKey('plugin-remove-cloud'),
            contentPadding: EdgeInsets.zero,
            title: Text(t.pluginLifecycle.deleteCloudData),
            subtitle: Text(t.pluginLifecycle.deleteCloudDataHint),
            value: cloud,
            onChanged: (value) => setState(() {
              cloud = value == true;
              if (cloud) local = true;
            }),
          ),
          Text(t.pluginLifecycle.siteUnaffected),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(t.common.cancel),
      ),
      FilledButton(
        key: const ValueKey('plugin-remove-next'),
        onPressed: () => Navigator.pop(
          context,
          PluginRemovalScope(local: local, cloud: cloud),
        ),
        child: Text(t.common.next),
      ),
    ],
  );
}

Future<bool> confirmPluginRemoval(
  BuildContext context, {
  required String pluginName,
  required PluginRemovalScope scope,
}) async =>
    await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: Text(t.pluginLifecycle.deleteConfirmTitle(name: pluginName)),
        content: Text(
          scope.cloud
              ? '${t.pluginLifecycle.deleteCloudConfirm}\n\n${t.pluginLifecycle.siteUnaffected}'
              : scope.local
              ? t.pluginLifecycle.deleteLocalConfirm
              : t.pluginLifecycle.removeConfirm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            key: const ValueKey('plugin-remove-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialog).colorScheme.error,
              foregroundColor: Theme.of(dialog).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(t.common.delete),
          ),
        ],
      ),
    ) ==
    true;
