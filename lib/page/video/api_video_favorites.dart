import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/sync/sync_service.dart';
import 'package:zephyr/network/sync/video_library_sync.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/page/video/video_library_folder_picker.dart';
import 'package:zephyr/page/video/video_library_store.dart';

class ApiVideoFavorites extends StatefulWidget {
  const ApiVideoFavorites({
    super.key,
    required this.source,
    required this.mode,
    required this.onOpen,
    this.store,
    this.repository,
    this.active = true,
    this.compact = false,
  });
  final String source;
  final ApiVideoView mode;
  final Future<void> Function(ApiVideoItem) onOpen;
  final VideoLibraryStore? store;
  final ApiVideoRepository? repository;
  final bool active;
  final bool compact;
  @override
  State<ApiVideoFavorites> createState() => _ApiVideoFavoritesState();
}

class _ApiVideoFavoritesState extends State<ApiVideoFavorites> {
  VideoLibraryStore get _store => widget.store ?? VideoLibraryStore.shared;
  VideoLibrarySnapshot? _snapshot;
  final _input = TextEditingController();
  final _searchFocus = FocusNode();
  final _selected = <String>{};
  String? _folder;
  String _query = '', _type = '', _sort = 'recent';
  bool _failed = false, _selecting = false, _working = false, _syncing = false;
  int _readEpoch = 0;
  bool _checking = false;
  @override
  void initState() {
    super.initState();
    _store.addListener(_read);
    _searchFocus.addListener(_focusChanged);
    _read();
    if (widget.active) unawaited(_checkUpdates());
  }

  void _focusChanged() {
    if (mounted) {
      setState(() {
        if (_searchFocus.hasFocus) {
          _selecting = false;
          _selected.clear();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant ApiVideoFavorites oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) unawaited(_checkUpdates());
  }

  Future<void> _checkUpdates({bool force = false}) async {
    final repository = widget.repository;
    if (repository == null || _checking) return;
    setState(() => _checking = true);
    try {
      final snapshot = await _store.read();
      final now = DateTime.now().millisecondsSinceEpoch;
      final ids = snapshot
          .itemsFor(widget.source)
          .where(
            (e) =>
                snapshot.follows(e.key) &&
                (force ||
                    now -
                            apiVideoInt(
                              snapshot.tracking[e.key]?.data['checkedAt'],
                            ) >
                        const Duration(minutes: 10).inMilliseconds),
          )
          .map((e) => e.item.id)
          .toList();
      if (ids.isEmpty) {
        if (force) _message(t.videoLibrary.followHint);
        return;
      }
      for (var offset = 0; offset < ids.length; offset += 20) {
        if (!mounted || !widget.active) return;
        final batch = ids.skip(offset).take(20).toList();
        final items = await repository.items(batch);
        await _store.observeItems(
          widget.source,
          items,
          missing: batch.toSet().difference(items.map((e) => e.id).toSet()),
        );
      }
      if (force) _message(t.videoLibrary.updateCheckDone);
    } catch (_) {
      if (force) _message(t.videoLibrary.updateCheckFailed);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  void dispose() {
    _readEpoch++;
    _store.removeListener(_read);
    _input.dispose();
    _searchFocus.removeListener(_focusChanged);
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _read() async {
    final epoch = ++_readEpoch;
    try {
      final snapshot = await _store.read();
      if (!mounted || epoch != _readEpoch) return;
      setState(() {
        _snapshot = snapshot;
        _failed = false;
        if (_folder != null &&
            !const {
              '__unfiled',
              '__following',
              '__updates',
            }.contains(_folder) &&
            snapshot.folders[_folder]?.deleted != false) {
          _folder = null;
        }
        final live = snapshot
            .itemsFor(widget.source)
            .map((e) => e.item.id)
            .toSet();
        _selected.removeWhere((id) => !live.contains(id));
      });
    } catch (_) {
      if (mounted && epoch == _readEpoch) setState(() => _failed = true);
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _newFolder() async {
    final name = await videoFolderName(context);
    if (name == null || !mounted) return;
    try {
      final id = await _store.createFolder(widget.source, name);
      if (mounted) setState(() => _folder = id);
    } catch (error) {
      _message(videoLibraryError(error));
    }
  }

  Future<void> _manageFolders() async {
    await showVideoTaskSheet<void>(
      context: context,
      builder: (_) => _FolderManager(source: widget.source, store: _store),
    );
  }

  Future<void> _classify() async {
    final keys = _selected
        .map((id) => VideoLibraryStore.itemKey(widget.source, id))
        .toSet();
    if (keys.isEmpty) return;
    final saved = await showVideoFolderPicker(
      context,
      source: widget.source,
      itemKeys: keys,
      store: _store,
    );
    if (saved == true && mounted) {
      setState(() {
        _selecting = false;
        _selected.clear();
      });
    }
  }

  Future<void> _remove() async {
    if (_selected.isEmpty || _working) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(t.videoLibrary.removeSelected),
        content: Text(t.videoLibrary.batchRemoveHint(count: _selected.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(t.common.remove),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _working = true);
    try {
      await _store.removeFavorites(
        _selected
            .map((id) => VideoLibraryStore.itemKey(widget.source, id))
            .toSet(),
      );
      if (mounted) {
        setState(() {
          _selecting = false;
          _selected.clear();
        });
      }
    } catch (error) {
      _message(videoLibraryError(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _sync() async {
    final state = context.read<GlobalSettingCubit>().state,
        adapter = createSyncAdapter(context.read<GlobalSettingCubit>().state);
    if (adapter == null || _syncing || !isSyncServiceConfigured(state)) return;
    setState(() => _syncing = true);
    try {
      await VideoLibrarySync.run(adapter, store: _store);
      _message(t.videoLibrary.syncDone);
    } catch (_) {
      _message(t.videoLibrary.syncFailed);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact || _searchFocus.hasFocus;
    if (_snapshot == null) {
      return ApiVideoEmpty(
        title: _failed ? t.common.loadingFailed : t.common.loading,
        action: _failed
            ? TextButton(onPressed: _read, child: Text(t.common.retry))
            : null,
      );
    }
    final snapshot = _snapshot!, all = snapshot.itemsFor(widget.source);
    final folders = snapshot.foldersFor(widget.source);
    final q = _query.trim().toLowerCase();
    final rows =
        all.where((e) {
          final folderIds = snapshot.foldersOf(e.key);
          return (_folder == null ||
                  (_folder == '__following'
                      ? snapshot.follows(e.key)
                      : _folder == '__updates'
                      ? snapshot.newEpisodes(e.key) > 0
                      : _folder == '__unfiled'
                      ? folderIds.isEmpty
                      : folderIds.contains(_folder))) &&
              (_type.isEmpty || e.item.typeName == _type) &&
              (q.isEmpty ||
                  '${e.item.title} ${e.item.alternateTitle} ${e.item.genres} ${e.item.area} ${e.item.language} ${e.item.actors} ${e.item.directors} ${e.item.writers} ${e.item.description}'
                      .toLowerCase()
                      .contains(q));
        }).toList()..sort(
          (a, b) => switch (_sort) {
            'title' => a.item.title.compareTo(b.item.title),
            'year' => b.item.year.compareTo(a.item.year),
            _ => b.clock.compareTo(a.clock),
          },
        );
    final types =
        all
            .map((e) => e.item.typeName)
            .where((x) => x.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final configured = context.select<GlobalSettingCubit?, bool>(
      (c) => c != null && isSyncServiceConfigured(c.state),
    );
    Widget chip(String? id, String label, int count) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text('$label $count'),
        selected: _folder == id,
        chipAnimationStyle: VideoMotion.chip(context),
        onSelected: (_) => setState(() {
          _folder = id;
          _selecting = false;
          _selected.clear();
        }),
      ),
    );
    return Column(
      children: [
        if (!compact)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t.videoLibrary.favorites,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: t.videoLibrary.newFolder,
                  onPressed: _working ? null : _newFolder,
                  icon: const Icon(Icons.create_new_folder_outlined),
                ),
                IconButton(
                  tooltip: t.videoLibrary.chooseFolders,
                  onPressed: _manageFolders,
                  icon: const Icon(Icons.folder_open_outlined),
                ),
                IconButton(
                  tooltip: _selecting
                      ? t.common.cancel
                      : t.videoLibrary.batchSelect,
                  onPressed: all.isEmpty
                      ? null
                      : () => setState(() {
                          _selecting = !_selecting;
                          _selected.clear();
                        }),
                  icon: Icon(
                    _selecting ? Icons.close : Icons.checklist_rounded,
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _input,
            focusNode: _searchFocus,
            onTapOutside: (_) => _searchFocus.unfocus(),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: t.videoLibrary.searchFavoritesHint,
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: t.common.clear,
                      onPressed: () {
                        _input.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
            onChanged: (value) => setState(() {
              _query = value;
              _selected.clear();
            }),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              chip(null, t.videoLibrary.all, all.length),
              chip(
                '__following',
                t.videoLibrary.following,
                all.where((e) => snapshot.follows(e.key)).length,
              ),
              chip(
                '__updates',
                t.videoLibrary.hasUpdates,
                all.where((e) => snapshot.newEpisodes(e.key) > 0).length,
              ),
              chip(
                '__unfiled',
                t.videoLibrary.unfiled,
                all.where((e) => snapshot.foldersOf(e.key).isEmpty).length,
              ),
              for (final e in folders.entries)
                chip(
                  e.key,
                  '${e.value.data['name']}',
                  all
                      .where((x) => snapshot.foldersOf(x.key).contains(e.key))
                      .length,
                ),
            ],
          ),
        ),
        if (!compact)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selecting
                        ? t.videoLibrary.selectedCount(count: _selected.length)
                        : t.videoLibrary.results(count: rows.length),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (types.isNotEmpty)
                  NativeVideoMenu(
                    label: _type.isEmpty ? t.videoLibrary.allTypes : _type,
                    tooltip: t.videoLibrary.categories,
                    selected: _type,
                    width: 108,
                    options: {
                      '': t.videoLibrary.allTypes,
                      for (final type in types) type: type,
                    },
                    onSelected: (value) => setState(() {
                      _type = value;
                      _selected.clear();
                    }),
                  ),
                NativeVideoMenu(
                  label: t.videoLibrary.sort,
                  tooltip: t.videoLibrary.sort,
                  selected: _sort,
                  width: 80,
                  options: {
                    'recent': t.videoLibrary.recentAdded,
                    'title': t.videoLibrary.titleOrder,
                    'year': t.videoLibrary.yearOrder,
                  },
                  onSelected: (value) => setState(() => _sort = value),
                ),
                if (widget.repository != null)
                  IconButton(
                    tooltip: _checking
                        ? t.videoLibrary.checkingUpdates
                        : t.videoLibrary.checkUpdates,
                    onPressed: _checking
                        ? null
                        : () => _checkUpdates(force: true),
                    icon: Icon(
                      _checking
                          ? Icons.hourglass_top_rounded
                          : Icons.update_rounded,
                    ),
                  ),
              ],
            ),
          ),
        if (_selecting && !compact)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: rows.isEmpty
                      ? null
                      : () => setState(
                          () => _selected.addAll(rows.map((e) => e.item.id)),
                        ),
                  child: Text(t.videoLibrary.selectAll),
                ),
                TextButton.icon(
                  onPressed: _selected.isEmpty || _working ? null : _classify,
                  icon: const Icon(Icons.drive_file_move_outline),
                  label: Text(t.videoLibrary.classify),
                ),
                TextButton.icon(
                  onPressed: _selected.isEmpty || _working ? null : _remove,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(t.videoLibrary.removeSelected),
                ),
              ],
            ),
          ),
        Expanded(
          child: rows.isEmpty
              ? ApiVideoEmpty(
                  title: all.isEmpty
                      ? t.videoLibrary.favoritesEmpty
                      : t.videoLibrary.noResults,
                  message: all.isEmpty
                      ? t.videoLibrary.favoritesEmptyHint
                      : t.videoLibrary.noResultsHint,
                  icon: Icons.bookmark_border_rounded,
                )
              : ApiVideoCollection(
                  key: ValueKey('favorite.$_folder.$_query.$_type.$_sort'),
                  items: rows.map((e) => e.item).toList(),
                  badges: {
                    for (final row in rows)
                      if (snapshot.newEpisodes(row.key) > 0)
                        row.item.id: t.videoLibrary.newEpisodes(
                          count: snapshot.newEpisodes(row.key),
                        ),
                  },
                  mode: widget.mode,
                  storageKey: '${widget.source}.favorites.$_folder',
                  selected: _selected,
                  selecting: _selecting,
                  onOpen: (item) {
                    if (_selecting) {
                      setState(() {
                        _selected.contains(item.id)
                            ? _selected.remove(item.id)
                            : _selected.add(item.id);
                      });
                    } else {
                      unawaited(widget.onOpen(item));
                    }
                  },
                  onLongPress: (item) => setState(() {
                    _selecting = true;
                    _selected.add(item.id);
                  }),
                ),
        ),
        if (!compact)
          ListTile(
            dense: true,
            leading: const Icon(Icons.cloud_sync_outlined, size: 22),
            title: Text(
              configured
                  ? t.videoLibrary.syncNote
                  : t.videoLibrary.syncLocalOnly,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            onTap: () => context.pushRoute(const SyncSettingRoute()),
            trailing: configured
                ? IconButton(
                    tooltip: _syncing
                        ? t.videoLibrary.syncing
                        : t.videoLibrary.syncNow,
                    onPressed: _syncing ? null : _sync,
                    icon: Icon(
                      _syncing ? Icons.hourglass_top_rounded : Icons.sync,
                    ),
                  )
                : const Icon(Icons.chevron_right, size: 20),
          ),
      ],
    );
  }
}

class _FolderManager extends StatefulWidget {
  const _FolderManager({required this.source, required this.store});
  final String source;
  final VideoLibraryStore store;
  @override
  State<_FolderManager> createState() => _FolderManagerState();
}

class _FolderManagerState extends State<_FolderManager> {
  VideoLibrarySnapshot? _snapshot;
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    try {
      final value = await widget.store.read();
      if (mounted) setState(() => _snapshot = value);
    } catch (error) {
      if (mounted) setState(() => _error = videoLibraryError(error));
    }
  }

  Future<void> _rename(String id, String current) async {
    final value = await videoFolderName(context, initial: current);
    if (value == null || !mounted) return;
    await _change(() => widget.store.renameFolder(id, value));
  }

  Future<void> _delete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(t.videoLibrary.deleteFolder),
        content: Text(t.videoLibrary.folderDeleteHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(t.common.delete),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _change(() => widget.store.deleteFolder(id));
    }
  }

  Future<void> _change(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await _read();
    } catch (error) {
      if (mounted) setState(() => _error = videoLibraryError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final e
                    in (_snapshot?.foldersFor(widget.source).entries ??
                        <MapEntry<String, VideoLibraryEntry>>[]))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder_outlined),
                    title: Text('${e.value.data['name']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: t.videoLibrary.renameFolder,
                          onPressed: _busy
                              ? null
                              : () => _rename(e.key, '${e.value.data['name']}'),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: t.videoLibrary.deleteFolder,
                          onPressed: _busy ? null : () => _delete(e.key),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                if (_snapshot?.foldersFor(widget.source).isEmpty == true)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(t.videoLibrary.folderEmpty),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
