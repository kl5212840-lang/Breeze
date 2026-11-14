import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_management_island.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';

Future<void> showPluginOrderDialog(BuildContext context) async {
  await showBookshelfManagementIsland<void>(
    context: context,
    builder: (_) => PluginOrderDialog(
      initialPlugins: PluginRegistryService.I.orderedPlugins(),
    ),
  );
}

class PluginOrderDialog extends StatefulWidget {
  const PluginOrderDialog({
    super.key,
    required this.initialPlugins,
    this.onSave,
    this.onReset,
  });
  final List<PluginRuntimeState> initialPlugins;
  final Future<void> Function(List<String>)? onSave;
  final Future<void> Function()? onReset;
  @override
  State<PluginOrderDialog> createState() => _PluginOrderDialogState();
}

class _PluginOrderDialogState extends State<PluginOrderDialog> {
  late final List<PluginRuntimeState> _plugins = [...widget.initialPlugins];
  bool _saving = false;
  String? _error;
  ValueChanged<bool>? _setIslandBusy;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setIslandBusy = BookshelfManagementIslandScope.maybeOf(context)?.setBusy;
  }

  Future<void> _write({bool reset = false}) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    _setIslandBusy?.call(true);
    try {
      if (reset) {
        await (widget.onReset?.call() ??
            PluginRegistryService.I.resetPluginOrder());
      } else {
        final ids = _plugins.map((plugin) => plugin.uuid).toList();
        await (widget.onSave?.call(ids) ??
            PluginRegistryService.I.reorderPlugins(ids));
      }
      if (mounted) {
        _setIslandBusy?.call(false);
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        _setIslandBusy?.call(false);
        setState(() {
          _saving = false;
          _error = t.error.saveFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t.discover.customOrder,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                key: const ValueKey('plugin-order.close'),
                tooltip: t.common.close,
                onPressed: _saving ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Flexible(
          child: CustomScrollView(
            key: const ValueKey('plugin-order.scroll'),
            shrinkWrap: true,
            slivers: [
              SliverReorderableList(
                itemCount: _plugins.length,
                onReorderItem: _saving
                    ? (_, _) {}
                    : (oldIndex, newIndex) => setState(() {
                        final plugin = _plugins.removeAt(oldIndex);
                        _plugins.insert(newIndex, plugin);
                      }),
                itemBuilder: (context, index) {
                  final plugin = _plugins[index];
                  final name =
                      PluginRegistryService.I
                          .getCachedPluginInfo(plugin.uuid)?['name']
                          ?.toString()
                          .trim() ??
                      '';
                  return Material(
                    key: ValueKey(plugin.uuid),
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    name.isEmpty ? plugin.uuid : name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
                                  ),
                                  if (!plugin.isActive)
                                    Text(
                                      t.discover.disabled,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            ),
                          ),
                          ReorderableDragStartListener(
                            key: ValueKey('plugin-order.drag.${plugin.uuid}'),
                            index: index,
                            enabled: !_saving,
                            child: Tooltip(
                              message: t.bookshelf.reorderSources,
                              child: const SizedBox.square(
                                dimension: 44,
                                child: Icon(
                                  Icons.drag_handle_rounded,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              if (_plugins.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(t.common.empty),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      key: const ValueKey('plugin-order.reset'),
                      onPressed: _saving ? null : () => _write(reset: true),
                      child: Text(t.discover.resetOrder),
                    ),
                  ),
                ),
              ),
              if (_error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              TextButton(
                key: const ValueKey('plugin-order.cancel'),
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: Text(t.common.cancel),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('plugin-order.save'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(44, 44),
                  ),
                  onPressed: _saving ? null : () => _write(),
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(t.common.apply),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
