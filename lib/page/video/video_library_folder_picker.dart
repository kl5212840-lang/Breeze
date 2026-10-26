import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
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
        onPressed: () => Navigator.pop(context),
        child: Text(t.common.cancel),
      ),
      ValueListenableBuilder(
        valueListenable: _input,
        builder: (_, value, _) => TextButton(
          onPressed: value.text.trim().isEmpty ? null : _save,
          child: Text(t.common.save),
        ),
      ),
    ],
  );
}

Future<bool?> showVideoFolderPicker(
  BuildContext context, {
  required String source,
  ApiVideoItem? item,
  Set<String> itemKeys = const {},
  VideoLibraryStore? store,
}) => showVideoTaskSheet<bool>(
  context: context,
  builder: (_) => _FolderPicker(
    source: source,
    item: item,
    itemKeys: itemKeys,
    store: store ?? VideoLibraryStore.shared,
  ),
);

class _FolderPicker extends StatefulWidget {
  const _FolderPicker({
    required this.source,
    required this.item,
    required this.itemKeys,
    required this.store,
  });
  final String source;
  final ApiVideoItem? item;
  final Set<String> itemKeys;
  final VideoLibraryStore store;
  @override
  State<_FolderPicker> createState() => _FolderPickerState();
}

class _FolderPickerState extends State<_FolderPicker> {
  VideoLibrarySnapshot? _snapshot;
  final _selected = <String>{};
  String _query = '';
  String? _error;
  bool _busy = false, _ready = false;
  @override
  void initState() {
    super.initState();
    _read();
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
    final name = await videoFolderName(context);
    if (name == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final id = await widget.store.createFolder(widget.source, name);
      _selected.add(id);
      await _read();
    } catch (error) {
      if (mounted) setState(() => _error = videoLibraryError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy || !_ready) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.item case final item?) {
        await widget.store.setFavorite(
          widget.source,
          item,
          true,
          folderIds: _selected,
        );
      } else {
        await widget.store.assignFolders(widget.itemKeys, _selected);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = videoLibraryError(error);
        });
      }
    }
  }

  Future<void> _remove() async {
    if (_busy || widget.item == null) return;
    setState(() => _busy = true);
    try {
      await widget.store.setFavorite(widget.source, widget.item!, false);
      if (mounted) Navigator.pop(context, false);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = videoLibraryError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final folders =
        _snapshot
            ?.foldersFor(widget.source)
            .entries
            .where(
              (e) => '${e.value.data['name']}'.toLowerCase().contains(
                _query.toLowerCase(),
              ),
            )
            .toList() ??
        [];
    return PopScope(
      canPop: !_busy,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.videoLibrary.chooseFolders,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: t.common.close,
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(
              t.videoLibrary.folderSaveHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: t.videoLibrary.folderName,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: _snapshot == null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error ?? t.common.loading),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final e in folders)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text('${e.value.data['name']}'),
                            value: _selected.contains(e.key),
                            onChanged: _busy
                                ? null
                                : (value) => setState(() {
                                    value == true
                                        ? _selected.add(e.key)
                                        : _selected.remove(e.key);
                                  }),
                          ),
                        if (folders.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(t.videoLibrary.folderEmpty),
                          ),
                      ],
                    ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (widget.item != null &&
                _snapshot?.contains(widget.source, widget.item!.id) == true)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _busy ? null : _remove,
                  icon: const Icon(Icons.star_border_rounded),
                  label: Text(t.videoLibrary.removeFavorite),
                ),
              ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _busy ? null : _newFolder,
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: Text(t.videoLibrary.newFolder),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _busy || !_ready ? null : _save,
                  child: Text(_busy ? t.common.loading : t.common.save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
