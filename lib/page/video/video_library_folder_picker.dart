import 'package:zephyr/page/search/widget/search_field_decoration.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_management_island.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_folder_visual.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/page/video/video_library_store.dart';

String videoLibraryError(Object error) {
  final text = error.toString();
  if (text.contains('folder_exists')) return t.videoLibrary.duplicateFolder;
  if (text.contains('folder_name_invalid')) return t.videoLibrary.nameInvalid;
  return t.videoLibrary.saveFailed;
}

Future<String?> videoFolderName(BuildContext context, {String initial = ''}) =>
    showDialog<String>(
      context: context,
      builder: (context) => MediaQuery(
        data: videoOverlayMedia(MediaQuery.of(context)),
        child: _FolderNameDialog(initial: initial),
      ),
    );

class _FolderNameDialog extends StatefulWidget {
  const _FolderNameDialog({required this.initial});
  final String initial;
  @override
  State<_FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<_FolderNameDialog> {
  late final _input = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _save() {
    if (_input.text.trim().isNotEmpty) {
      Navigator.pop(context, _input.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(
      widget.initial.isEmpty
          ? t.videoLibrary.newFolder
          : t.videoLibrary.renameFolder,
    ),
    content: TextField(
      key: const ValueKey('video-folder.name'),
      controller: _input,
      autofocus: true,
      maxLength: 60,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(labelText: t.videoLibrary.folderName),
      onSubmitted: (_) => _save(),
    ),
    actions: [
      TextButton(
        style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
        onPressed: () => Navigator.pop(context),
        child: Text(t.common.cancel),
      ),
      ValueListenableBuilder(
        valueListenable: _input,
        builder: (_, value, _) => TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
          onPressed: value.text.trim().isEmpty ? null : _save,
          child: Text(t.common.save),
        ),
      ),
    ],
  );
}

/// Assignment of existing favorites: move replaces memberships; copy adds them.
enum VideoFolderAssignment { move, copy }

Future<bool?> showVideoFolderPicker(
  BuildContext context, {
  required String source,
  ApiVideoItem? item,
  Set<String> itemKeys = const {},
  VideoFolderAssignment? assignment,
  List<ApiVideoItem> importItems = const [],
  ValueChanged<({int added, int existing})>? onImportSaved,
  VideoLibraryStore? store,
}) {
  if (assignment != null &&
      (itemKeys.isEmpty || item != null || importItems.isNotEmpty)) {
    throw ArgumentError(
      'Folder assignment requires existing favorite itemKeys only.',
    );
  }
  return showBookshelfManagementIsland<bool>(
    context: context,
    builder: (_) => _FolderPicker(
      source: source,
      item: item,
      itemKeys: itemKeys,
      assignment: assignment,
      importItems: importItems,
      onImportSaved: onImportSaved,
      store: store ?? VideoLibraryStore.shared,
    ),
  );
}

class _FolderPicker extends StatefulWidget {
  const _FolderPicker({
    required this.source,
    required this.item,
    required this.itemKeys,
    this.assignment,
    required this.importItems,
    this.onImportSaved,
    required this.store,
  });
  final String source;
  final ApiVideoItem? item;
  final Set<String> itemKeys;
  final VideoFolderAssignment? assignment;
  final List<ApiVideoItem> importItems;
  final ValueChanged<({int added, int existing})>? onImportSaved;
  final VideoLibraryStore store;
  @override
  State<_FolderPicker> createState() => _FolderPickerState();
}

class _FolderPickerState extends State<_FolderPicker> {
  VideoLibrarySnapshot? _snapshot;
  final _selected = <String>{};
  String _query = '';
  bool _unfiled = false;
  String? _error;
  bool _busy = false, _ready = false, _creating = false;
  final _name = TextEditingController();
  BookshelfManagementIslandScope? _island;
  bool get _adding => widget.item == null && widget.itemKeys.isNotEmpty;
  bool get _hasTarget => widget.assignment == VideoFolderAssignment.move
      ? _selected.isNotEmpty || _unfiled
      : !_adding || _selected.isNotEmpty;
  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _island = BookshelfManagementIslandScope.maybeOf(context);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _setBusy(bool value) {
    _island?.setBusy(value);
    if (mounted) setState(() => _busy = value);
  }

  void _finish(bool result) {
    if (!mounted) return;
    _setBusy(false);
    Navigator.pop(context, result);
  }

  Future<void> _read() async {
    try {
      final snapshot = await widget.store.read();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _error = null;
        if (!_ready && widget.item != null) {
          _selected.addAll(
            snapshot.foldersOf(
              VideoLibraryStore.itemKey(widget.source, widget.item!.id),
            ),
          );
        }
        _ready = true;
      });
    } catch (error) {
      if (mounted) setState(() => _error = videoLibraryError(error));
    }
  }

  Future<void> _newFolder() async {
    if (_busy) return;
    final name = _name.text.trim();
    if (name.isEmpty || name.length > 60) {
      setState(() => _error = t.videoLibrary.nameInvalid);
      return;
    }
    _setBusy(true);
    try {
      final id = await widget.store.createFolder(widget.source, name);
      if (!mounted) return;
      _selected.add(id);
      _unfiled = false;
      _creating = false;
      _name.clear();
      FocusManager.instance.primaryFocus?.unfocus();
      await _read();
    } catch (error) {
      if (mounted) setState(() => _error = videoLibraryError(error));
    } finally {
      if (mounted) _setBusy(false);
    }
  }

  Future<void> _save() async {
    if (_busy || !_ready || _creating || !_hasTarget) return;
    _setBusy(true);
    setState(() => _error = null);
    try {
      if (widget.assignment == VideoFolderAssignment.move) {
        await widget.store.assignFolders(widget.itemKeys, _selected);
      } else if (widget.assignment == VideoFolderAssignment.copy) {
        await widget.store.addToFolders(widget.itemKeys, _selected);
      } else if (widget.importItems.isNotEmpty) {
        final result = await widget.store.importFavorites(
          widget.source,
          widget.importItems,
          folderIds: _selected,
        );
        widget.onImportSaved?.call(result);
      } else if (widget.item case final item?) {
        await widget.store.setFavorite(
          widget.source,
          item,
          true,
          folderIds: _selected,
        );
      } else {
        await widget.store.addToFolders(widget.itemKeys, _selected);
      }
      _finish(true);
    } catch (error) {
      if (mounted) {
        _setBusy(false);
        setState(() => _error = videoLibraryError(error));
      }
    }
  }

  Future<void> _remove() async {
    if (_busy || widget.item == null) return;
    _setBusy(true);
    try {
      await widget.store.setFavorite(widget.source, widget.item!, false);
      _finish(false);
    } catch (error) {
      if (mounted) {
        _setBusy(false);
        setState(() => _error = videoLibraryError(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allFolders = _snapshot?.foldersFor(widget.source) ?? {};
    final folders = allFolders.entries
        .where(
          (entry) => '${entry.value.data['name']}'.toLowerCase().contains(
            _query.toLowerCase(),
          ),
        )
        .toList();
    return PopScope(
      canPop: !_busy,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.assignment == VideoFolderAssignment.move
                        ? t.bookshelf.moveTo
                        : widget.assignment == VideoFolderAssignment.copy
                        ? t.bookshelf.copyTo
                        : _adding
                        ? t.bookshelf.addToFolder
                        : t.videoLibrary.chooseFolders,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const ValueKey('video-folder.close'),
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  tooltip: t.common.close,
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Flexible(
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              key: const ValueKey('video-folder.scroll'),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.assignment != VideoFolderAssignment.move)
                    Text(
                      _adding
                          ? t.videoLibrary.addFoldersHint
                          : widget.importItems.isEmpty
                          ? t.videoLibrary.folderSaveHint
                          : t.videoSource.importFolderHint(
                              count: widget.importItems.length,
                            ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 12),
                  if (allFolders.length > 5 || _query.isNotEmpty) ...[
                    SearchFieldSurface(
                      child: TextField(
                        key: const ValueKey('video-folder.search'),
                        enabled: !_busy,
                        decoration: searchFieldDecoration(
                          context,
                          hintText: t.videoLibrary.folderName,
                        ),
                        onChanged: (value) => setState(() => _query = value),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (!_creating)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: OutlinedButton.icon(
                        key: const ValueKey('video-folder.new'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(44, 44),
                        ),
                        onPressed: _busy || !_ready
                            ? null
                            : () => setState(() {
                                _creating = true;
                                _error = null;
                              }),
                        icon: const Icon(
                          Icons.create_new_folder_outlined,
                          size: 20,
                        ),
                        label: Text(t.videoLibrary.newFolder),
                      ),
                    )
                  else ...[
                    TextField(
                      key: const ValueKey('video-folder.new-name'),
                      controller: _name,
                      autofocus: true,
                      enabled: !_busy,
                      maxLength: 60,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: t.videoLibrary.folderName,
                      ),
                      onSubmitted: (_) => _newFolder(),
                    ),
                    Row(
                      children: [
                        TextButton(
                          key: const ValueKey('video-folder.cancel-create'),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 44),
                          ),
                          onPressed: _busy
                              ? null
                              : () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  setState(() {
                                    _creating = false;
                                    _name.clear();
                                    _error = null;
                                  });
                                },
                          child: Text(t.common.cancel),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            key: const ValueKey('video-folder.create'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(44, 44),
                            ),
                            onPressed: _busy ? null : _newFolder,
                            child: Text(t.common.create),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (widget.assignment == VideoFolderAssignment.move)
                    ListTile(
                      key: const ValueKey('video-folder.unfiled'),
                      contentPadding: EdgeInsets.zero,
                      minTileHeight: 56,
                      leading: BookshelfFolderIcon(selected: _unfiled),
                      title: Text(t.videoLibrary.unfiled),
                      onTap: _busy || !_ready ? null : _toggleUnfiled,
                      trailing: SizedBox.square(
                        dimension: 44,
                        child: Checkbox(
                          value: _unfiled,
                          onChanged: _busy || !_ready
                              ? null
                              : (_) => _toggleUnfiled(),
                        ),
                      ),
                    ),
                  if (_snapshot == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(_error ?? t.common.loading),
                    )
                  else if (folders.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        _query.isEmpty
                            ? t.common.empty
                            : t.videoLibrary.noResults,
                      ),
                    )
                  else
                    for (final entry in folders)
                      ListTile(
                        key: ValueKey('video-folder.option.${entry.key}'),
                        contentPadding: EdgeInsets.zero,
                        minTileHeight: 56,
                        leading: BookshelfFolderIcon(
                          selected: _selected.contains(entry.key),
                        ),
                        title: Text('${entry.value.data['name']}'),
                        onTap: _busy ? null : () => _toggle(entry.key),
                        trailing: SizedBox.square(
                          dimension: 44,
                          child: Checkbox(
                            value: _selected.contains(entry.key),
                            onChanged: _busy ? null : (_) => _toggle(entry.key),
                          ),
                        ),
                      ),
                  if (_error != null && _snapshot != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (_snapshot == null && _error != null)
                    TextButton(
                      onPressed: _busy ? null : _read,
                      child: Text(t.common.retry),
                    ),
                  if (widget.item != null &&
                      _snapshot?.contains(widget.source, widget.item!.id) ==
                          true) ...[
                    const Divider(height: 24),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, 44),
                        ),
                        onPressed: _busy ? null : _remove,
                        icon: const Icon(Icons.star_border_rounded),
                        label: Text(t.videoLibrary.removeFavorite),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                TextButton(
                  key: const ValueKey('video-folder.cancel'),
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: Text(t.common.cancel),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('video-folder.save'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(44, 44),
                    ),
                    onPressed: _busy || !_ready || _creating || !_hasTarget
                        ? null
                        : _save,
                    child: Text(
                      _busy ? t.common.loading : t.common.save,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleUnfiled() => setState(() {
    _unfiled = !_unfiled;
    _selected.clear();
  });

  void _toggle(String id) => setState(() {
    _unfiled = false;
    _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
  });
}
