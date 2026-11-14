import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';

import 'package:zephyr/service/plugin_data_removal_models.dart';
export 'package:zephyr/service/plugin_data_removal_models.dart';

typedef PluginDataRemovalInspector =
    Future<PluginDataRemovalCounts?> Function(PluginDataRemovalChoice choice);

/// A confirmation only. Loading the preview and dismissing this route never
/// changes installation state, masks, personal records or files.
Future<PluginDataRemovalChoice?> showPluginDataRemovalDialog(
  BuildContext context, {
  required String pluginName,
  PluginDataRemovalCounts? counts,
  PluginDataRemovalInspector? inspect,
}) => showDialog<PluginDataRemovalChoice>(
  context: context,
  useRootNavigator: false,
  builder: (_) => _PluginDataRemovalDialog(
    pluginName: pluginName,
    counts: counts,
    inspect: inspect,
  ),
);

class _PluginDataRemovalDialog extends StatefulWidget {
  const _PluginDataRemovalDialog({
    required this.pluginName,
    required this.counts,
    required this.inspect,
  });
  final String pluginName;
  final PluginDataRemovalCounts? counts;
  final PluginDataRemovalInspector? inspect;
  @override
  State<_PluginDataRemovalDialog> createState() =>
      _PluginDataRemovalDialogState();
}

class _PluginDataRemovalDialogState extends State<_PluginDataRemovalDialog> {
  bool _cloudDelete = false,
      _includeDownloads = false,
      _checking = false,
      _inspected = false;
  PluginDataRemovalCounts? _counts;
  String? _error;
  int _inspection = 0;
  bool _closing = false;

  void _invalidateInspection() {
    _closing = true;
    _inspection++;
  }

  void _dismiss([PluginDataRemovalChoice? choice]) {
    if (_closing || !mounted || ModalRoute.of(context)?.isCurrent != true)
      return;
    _invalidateInspection();
    Navigator.of(context).pop(choice);
  }

  @override
  void dispose() {
    _invalidateInspection();
    super.dispose();
  }

  PluginDataRemovalChoice get _choice => PluginDataRemovalChoice(
    cloudDelete: _cloudDelete,
    includeDownloads: _includeDownloads,
  );

  @override
  void initState() {
    super.initState();
    _counts = widget.counts;
    _inspected = _counts != null;
    if (_counts == null && widget.inspect != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refresh(_choice);
      });
    }
  }

  Future<void> _refresh(
    PluginDataRemovalChoice choice, {
    bool confirm = false,
  }) async {
    if (_checking || _closing || !mounted) return;
    final inspect = widget.inspect;
    final previous = _counts;
    final generation = ++_inspection;
    setState(() {
      _cloudDelete = choice.cloudDelete;
      _includeDownloads = choice.includeDownloads;
      _error = null;
      _checking = inspect != null;
      if (inspect != null) _inspected = false;
    });
    if (inspect == null) {
      if (confirm) _dismiss(choice);
      return;
    }
    try {
      final counts = await inspect(choice);
      if (!mounted || _closing || generation != _inspection) return;
      if (counts == null) {
        _dismiss();
        return;
      }
      setState(() {
        _counts = counts;
        _checking = false;
        _inspected = true;
      });
      if (confirm) {
        if (previous == null || !previous.sameAs(counts)) {
          setState(() => _error = t.pluginLifecycle.changed);
        } else {
          _dismiss(choice);
        }
      }
    } catch (error) {
      if (!mounted || _closing || generation != _inspection) return;
      setState(() {
        _checking = false;
        _error = error is PluginDataRemovalInspectionFailure
            ? error.message
            : t.common.loadingFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final notes = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant);
    return PopScope<PluginDataRemovalChoice>(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _invalidateInspection();
      },
      child: AlertDialog(
        scrollable: true,
        title: Text(t.pluginLifecycle.purgeTitle),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.pluginName,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(t.pluginLifecycle.purgeConfirm),
              const SizedBox(height: 12),
              RadioGroup<bool>(
                groupValue: _cloudDelete,
                onChanged: (value) {
                  if (!_checking && value != null) {
                    _refresh(
                      PluginDataRemovalChoice(
                        cloudDelete: value,
                        includeDownloads: _includeDownloads,
                      ),
                    );
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final cloud in [false, true])
                      TouchHoverIntent(
                        identity: 'plugin-data-removal.scope.$cloud',
                        builder: (context, hover) => RadioListTile<bool>(
                          value: cloud,
                          enabled: !_checking,
                          hoverColor: hover.hoverColor(),
                          overlayColor: hover.overlayColor(null),
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            cloud
                                ? t.pluginLifecycle.cloudAlso
                                : t.pluginLifecycle.localOnly,
                          ),
                          subtitle: _cloudDelete != cloud
                              ? null
                              : Text(
                                  cloud
                                      ? t.pluginLifecycle.cloudAlsoHint
                                      : t.pluginLifecycle.localOnlyHint,
                                  style: notes,
                                ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TouchHoverIntent(
                identity: 'plugin-data-removal.downloads',
                builder: (context, hover) => CheckboxListTile(
                  value: _includeDownloads,
                  hoverColor: hover.hoverColor(),
                  overlayColor: hover.overlayColor(null),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(t.pluginLifecycle.includeDownloads),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_counts != null)
                        Text(
                          t.pluginLifecycle.downloads(
                            count: _counts!.downloads,
                          ),
                          style: notes,
                        ),
                      if (!_includeDownloads)
                        Text(t.pluginLifecycle.keepDownloadsHint, style: notes),
                    ],
                  ),
                  onChanged: _checking
                      ? null
                      : (value) => _refresh(
                          PluginDataRemovalChoice(
                            cloudDelete: _cloudDelete,
                            includeDownloads: value == true,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              if (_checking)
                LinearProgressIndicator(semanticsLabel: t.common.loading),
              if (_error != null)
                Text(_error!, style: TextStyle(color: colors.error)),
              if (_error != null && widget.inspect != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TouchHoverIntent(
                    identity: 'plugin-data-removal.retry',
                    builder: (context, hover) => TextButton(
                      style: ButtonStyle(
                        overlayColor: hover.overlayColor(null),
                      ),
                      onPressed: _checking ? null : () => _refresh(_choice),
                      child: Text(t.common.retry),
                    ),
                  ),
                ),
              if (_counts != null)
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    for (final line in [
                      t.pluginLifecycle.favorites(count: _counts!.favorites),
                      t.pluginLifecycle.history(count: _counts!.history),
                      t.pluginLifecycle.follows(count: _counts!.follows),
                      t.pluginLifecycle.settings(count: _counts!.settings),
                      t.pluginLifecycle.images(count: _counts!.images),
                    ])
                      Text(line, style: notes),
                  ],
                ),
              const SizedBox(height: 12),
              Text(t.pluginLifecycle.siteUnaffected, style: notes),
              const SizedBox(height: 4),
              Text(t.pluginLifecycle.websiteSignInNotice, style: notes),
            ],
          ),
        ),
        actions: [
          TouchHoverIntent(
            identity: 'plugin-data-removal.cancel',
            builder: (context, hover) => TextButton(
              style: ButtonStyle(overlayColor: hover.overlayColor(null)),
              onPressed: _dismiss,
              child: Text(t.common.cancel),
            ),
          ),
          TouchHoverIntent(
            identity: 'plugin-data-removal.confirm',
            builder: (context, hover) => TextButton(
              onPressed: _checking || _counts == null || !_inspected
                  ? null
                  : () => _refresh(_choice, confirm: true),
              style: TextButton.styleFrom(
                foregroundColor: colors.error,
              ).copyWith(overlayColor: hover.overlayColor(null)),
              child: Text(t.pluginLifecycle.purge),
            ),
          ),
        ],
      ),
    );
  }
}
