import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_folder_visual.dart';
import 'package:zephyr/page/video/video_interaction.dart';

class BookshelfFolderChoice {
  const BookshelfFolderChoice({
    required this.path,
    required this.name,
    required this.parentPath,
    this.selectable = true,
    this.browsable = true,
  });
  final String path, name, parentPath;
  final bool selectable, browsable;
}

/// One destination surface: selecting, expanding and creating stay in place.
/// Moving selects one target; copying can explicitly select several targets.
class BookshelfFolderPicker extends StatefulWidget {
  const BookshelfFolderPicker({
    super.key,
    required this.choices,
    required this.title,
    required this.onConfirmed,
    this.multiple = false,
    this.initialCreateParent = '',
    this.onCreate,
  });
  final List<BookshelfFolderChoice> choices;
  final String title, initialCreateParent;
  final bool multiple;
  final ValueChanged<Set<String>> onConfirmed;
  final Future<BookshelfFolderChoice> Function(String parent, String name)?
  onCreate;
  @override
  State<BookshelfFolderPicker> createState() => _BookshelfFolderPickerState();
}

class _BookshelfFolderPickerState extends State<BookshelfFolderPicker> {
  late final _choices = [...widget.choices];
  final _selected = <String>{}, _expanded = <String>{''};
  final _name = TextEditingController();
  bool _creating = false, _busy = false;
  String? _error;
  String get _createParent =>
      _selected.length == 1 ? _selected.single : widget.initialCreateParent;

  @override
  void initState() {
    super.initState();
    var path = widget.initialCreateParent;
    while (path.isNotEmpty) {
      _expanded.add(path);
      final slash = path.lastIndexOf('/');
      path = slash <= 0 ? '' : path.substring(0, slash);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _select(String path) => setState(() {
    if (_selected.contains(path)) {
      _selected.remove(path);
    } else {
      if (!widget.multiple) _selected.clear();
      _selected.add(path);
    }
  });

  Future<void> _create() async {
    if (_busy || widget.onCreate == null) return;
    final name = _name.text.trim();
    if (name.isEmpty || name.contains('/')) {
      setState(
        () => _error = name.isEmpty
            ? t.bookshelf.folderNameEmpty
            : t.bookshelf.folderNameSlash,
      );
      return;
    }
    final parent = _createParent;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final created = await widget.onCreate!(parent, name);
      if (!mounted) return;
      setState(() {
        _choices.add(created);
        _expanded.add(parent);
        if (!widget.multiple) _selected.clear();
        _selected.add(created.path);
        _creating = false;
        _name.clear();
      });
      FocusManager.instance.primaryFocus?.unfocus();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError
              ? error.message
              : error is ArgumentError
              ? '${error.message}'
              : t.common.failed,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Widget> _rows(String parent, int depth, Set<String> seen) {
    final values =
        _choices
            .where((v) => v.parentPath == parent && v.path != parent)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return [
      for (final item in values)
        if (!seen.contains(item.path)) ...[
          _row(item, depth),
          if (_expanded.contains(item.path))
            ..._rows(item.path, depth + 1, {...seen, item.path}),
        ],
    ];
  }

  Widget _row(BookshelfFolderChoice item, int depth) {
    final expanded = _expanded.contains(item.path);
    final children =
        item.path.isNotEmpty &&
        _choices.any((v) => v.parentPath == item.path && v.path != item.path);
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: (depth.clamp(0, 2) * 12).toDouble(),
      ),
      child: ListTile(
        key: ValueKey('shelf-folder.${item.path}'),
        minTileHeight: 48,
        contentPadding: EdgeInsets.zero,
        enabled: item.selectable || item.browsable,
        leading: children
            ? Semantics(
                expanded: expanded,
                child: IconButton(
                  key: ValueKey('shelf-folder.expand.${item.path}'),
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  tooltip: item.name,
                  onPressed: _busy || !item.browsable
                      ? null
                      : () => setState(() {
                          if (expanded) {
                            _expanded.remove(item.path);
                          } else {
                            _expanded.add(item.path);
                          }
                        }),
                  icon: VideoDisclosureIndicator(expanded: expanded, size: 20),
                ),
              )
            : BookshelfFolderIcon(selected: _selected.contains(item.path)),
        title: Text(item.name),
        subtitle: depth > 1 ? Text(item.path) : null,
        onTap: _busy || !item.selectable ? null : () => _select(item.path),
        trailing: SizedBox.square(
          dimension: 44,
          child: widget.multiple
              ? Checkbox(
                  value: _selected.contains(item.path),
                  onChanged: _busy || !item.selectable
                      ? null
                      : (_) => _select(item.path),
                )
              : Radio<String>(
                  value: item.path,
                  enabled: !_busy && item.selectable,
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: LayoutBuilder(
      builder: (context, limits) => ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: limits.maxHeight.clamp(0, 640),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: t.common.close,
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                key: const ValueKey('shelf-folder.scroll'),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: RadioGroup<String>(
                  groupValue: _selected.firstOrNull,
                  onChanged: (value) {
                    if (value != null && !_busy) _select(value);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.onCreate != null)
                        OutlinedButton.icon(
                          key: const ValueKey('shelf-folder.new'),
                          onPressed: _busy
                              ? null
                              : () => setState(() => _creating = !_creating),
                          icon: const Icon(
                            Icons.create_new_folder_outlined,
                            size: 20,
                          ),
                          label: Text(t.bookshelf.newFolder),
                        ),
                      if (_creating) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${t.bookshelf.newFolder} · ${_createParent.isEmpty ? t.common.root : _createParent}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          key: const ValueKey('shelf-folder.name'),
                          controller: _name,
                          autofocus: true,
                          enabled: !_busy,
                          maxLength: 60,
                          decoration: InputDecoration(
                            labelText: t.bookshelf.folderName,
                            errorText: _error,
                          ),
                          onSubmitted: (_) => _create(),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() => _creating = false),
                              child: Text(t.common.cancel),
                            ),
                            const Spacer(),
                            FilledButton(
                              onPressed: _busy ? null : _create,
                              child: _busy
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(t.bookshelf.newFolder),
                            ),
                          ],
                        ),
                      ],
                      if (_choices.any((v) => v.path.isEmpty))
                        _row(_choices.firstWhere((v) => v.path.isEmpty), 0),
                      ..._rows('', 0, {''}),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: Text(t.common.cancel),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('shelf-folder.confirm'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                      onPressed: _busy || _selected.isEmpty
                          ? null
                          : () {
                              final selected = Set<String>.from(_selected);
                              Navigator.pop(context);
                              widget.onConfirmed(selected);
                            },
                      child: Text(widget.title, textAlign: TextAlign.center),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
