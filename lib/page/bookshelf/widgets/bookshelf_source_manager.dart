import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/service/bookshelf_source_preferences.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_management_island.dart';
import 'package:zephyr/plugin/plugin_display_name.dart';
import 'package:zephyr/widgets/breeze_switch.dart';

Future<void> showBookshelfSourceManager({
  required BuildContext context,
  required Map<String, String> sources,
  required BookshelfSourcePreferences initial,
  required Future<void> Function(BookshelfSourcePreferences) onSave,
  bool useDisplayNames = false,
}) => showBookshelfManagementIsland<void>(
  context: context,
  builder: (_) => BookshelfSourceManager(
    sources: sources,
    initial: initial,
    onSave: onSave,
    useDisplayNames: useDisplayNames,
  ),
);

class BookshelfSourceManager extends StatefulWidget {
  const BookshelfSourceManager({
    super.key,
    required this.sources,
    required this.initial,
    required this.onSave,
    this.useDisplayNames = false,
  });
  final Map<String, String> sources;
  final bool useDisplayNames;
  final BookshelfSourcePreferences initial;
  final Future<void> Function(BookshelfSourcePreferences) onSave;
  @override
  State<BookshelfSourceManager> createState() => _BookshelfSourceManagerState();
}

class _BookshelfSourceManagerState extends State<BookshelfSourceManager> {
  late BookshelfSourcePreferences _draft = widget.initial;
  late List<String> _order = _draft
      .arrange(widget.sources, includeHidden: true)
      .keys
      .toList();
  bool _saving = false;
  String? _error;
  ValueChanged<bool>? _setIslandBusy;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setIslandBusy = BookshelfManagementIslandScope.maybeOf(context)?.setBusy;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    _setIslandBusy?.call(true);
    try {
      await widget.onSave(_draft);
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
                  t.bookshelf.sourceLabels,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(
                key: const ValueKey('source-manager.reset'),
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                onPressed: _saving
                    ? null
                    : () => setState(() {
                        _draft = BookshelfSourcePreferences();
                        _order = widget.sources.keys.toList();
                      }),
                child: Text(t.bookshelf.sourceLabelsReset),
              ),
              IconButton(
                key: const ValueKey('source-manager.close'),
                tooltip: t.common.close,
                onPressed: _saving ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Flexible(
          child: CustomScrollView(
            key: const ValueKey('source-manager.scroll'),
            shrinkWrap: true,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    t.bookshelf.sourceLabelsHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              SliverReorderableList(
                itemCount: _order.length,
                onReorderItem: _saving
                    ? (_, _) {}
                    : (oldIndex, newIndex) => setState(() {
                        final id = _order.removeAt(oldIndex);
                        _order.insert(newIndex, id);
                        _draft = _draft.withKnownOrder(_order);
                      }),
                itemBuilder: (context, index) {
                  final id = _order[index];
                  final fallback = widget.sources[id]!;
                  final visible = !_draft.hidden.contains(id);
                  Widget row(String name) => Material(
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 4,
                              ),
                              child: Text(
                                name,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                          ),
                          Semantics(
                            label: '${t.bookshelf.sourceLabels}: $name',
                            child: SizedBox(
                              width: 56,
                              height: 48,
                              child: BreezeSwitch(
                                Switch.adaptive(
                                  key: ValueKey('source-manager.visible.$id'),
                                  value: visible,
                                  onChanged: _saving
                                      ? null
                                      : (value) => setState(
                                          () => _draft = _draft.withVisibility(
                                            id,
                                            value,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                          ReorderableDragStartListener(
                            key: ValueKey('source-manager.drag.$id'),
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
                  return KeyedSubtree(
                    key: ValueKey('source-manager.row.$id'),
                    child: widget.useDisplayNames
                        ? PluginDisplayNameBuilder(
                            source: id,
                            fallback: fallback,
                            builder: (_, name) => row(name),
                          )
                        : row(fallback),
                  );
                },
              ),
              if (_order.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(t.bookshelf.noFilterSource),
                  ),
                ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              TextButton(
                key: const ValueKey('source-manager.cancel'),
                onPressed: _saving ? null : () => Navigator.pop(context),
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                child: Text(t.common.cancel),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('source-manager.done'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(44, 44),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(t.common.done),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
