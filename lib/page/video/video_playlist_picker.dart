import 'dart:async';

import 'package:zephyr/page/video/video_page_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_community_page.dart';
import 'package:zephyr/page/video/video_playlist_editor.dart';
import 'package:zephyr/page/video/video_site_action_models.dart';
import 'package:zephyr/page/video/video_site_operations.dart';

/// A focused collection task inside the playback route. Changes are shown only
/// after the operation reports a confirmed target value, including removals.
class VideoPlaylistPicker extends StatefulWidget {
  const VideoPlaylistPicker({
    super.key,
    required this.operations,
    required this.onLogin,
    required this.onClose,
    this.onWebsite,
    this.onChanged,
  });
  final VideoSiteOperations operations;
  final VoidCallback onLogin, onClose;
  final VoidCallback? onWebsite;
  final ValueChanged<bool?>? onChanged;
  @override
  State<VideoPlaylistPicker> createState() => _VideoPlaylistPickerState();
}

class _VideoPlaylistPickerState extends State<VideoPlaylistPicker> {
  final _lists = <String, VideoPlaylistChoice>{};
  final _uncertain = <String>{};
  bool _loading = false, _loaded = false, _creating = false, _canCreate = false;
  String? _writing, _error;
  VideoSiteStatus? _status;
  int? _nextPage;

  bool get _busy => _loading || _writing != null || _creating;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    unawaited(widget.operations.cancelRead());
    super.dispose();
  }

  void _report() {
    final values = _lists.values.toList();
    final selected = values.any(
      (item) => item.containsVideo == true && !_uncertain.contains(item.id),
    );
    final complete =
        _loaded &&
        _status == VideoSiteStatus.ok &&
        _nextPage == null &&
        _uncertain.isEmpty &&
        values.every((item) => item.containsVideo != null);
    widget.onChanged?.call(
      selected
          ? true
          : complete
          ? false
          : null,
    );
  }

  void _fail(VideoSiteStatus status) {
    _status = status;
    _error = videoOperationMessage(status.name);
    if (status == VideoSiteStatus.login || status == VideoSiteStatus.changed) {
      _lists.clear();
      _nextPage = null;
      _canCreate = false;
    }
  }

  Future<void> _load({int page = 1}) async {
    if (_loading || _writing != null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await widget.operations.readPlaylists(page: page);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.value case final value?
          when value.nextPage == null || value.nextPage! > page) {
        if (page == 1) _lists.clear();
        for (final item in value.lists) {
          _lists[item.id] = item;
        }
        _nextPage = value.nextPage;
        _canCreate = value.canCreate;
        _loaded = true;
        _status = VideoSiteStatus.ok;
      } else {
        _fail(
          result.status == VideoSiteStatus.ok
              ? VideoSiteStatus.unsupported
              : result.status,
        );
      }
    });
    _report();
  }

  Future<void> _change(VideoPlaylistChoice item, {bool? enabled}) async {
    if (_busy) return;
    final checkOnly = enabled == null || _uncertain.contains(item.id);
    setState(() {
      _writing = item.id;
      _error = null;
    });
    final result = checkOnly
        ? await widget.operations.readPlaylistMembership(item.id)
        : await widget.operations.setPlaylistMembership(item.id, enabled);
    if (!mounted) return;
    setState(() {
      _writing = null;
      final confirmed = result.value?.lists
          .where((value) => value.id == item.id)
          .firstOrNull;
      if (result.status == VideoSiteStatus.ok &&
          confirmed?.containsVideo != null) {
        _lists[item.id] = confirmed!;
        _uncertain.remove(item.id);
        _status = VideoSiteStatus.ok;
      } else {
        if (result.writeUnconfirmed) _uncertain.add(item.id);
        _fail(
          result.status == VideoSiteStatus.ok
              ? VideoSiteStatus.unconfirmed
              : result.status,
        );
      }
    });
    _report();
  }

  Future<void> _create() async {
    if (_busy) return;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      if (!_canCreate) {
        final result = await widget.operations.readInteraction(refresh: true);
        if (!mounted) return;
        if (result.value?.capability(VideoSiteAction.createPlaylist) !=
            VideoActionCapability.ready) {
          setState(
            () => _fail(
              result.status == VideoSiteStatus.ok
                  ? VideoSiteStatus.unsupported
                  : result.status,
            ),
          );
          return;
        }
      }
      if (!mounted) return;
      final result = await Navigator.of(context).push<String>(
        videoPageRoute(
          builder: (_) => VideoPlaylistEditor(
            operations: widget.operations,
            initial: const {},
            create: true,
            onLogin: widget.onLogin,
            onWebsite: widget.onWebsite,
          ),
        ),
      );
      if (mounted && result == 'updated') await _load();
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _writing == null,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t.videoCommunity.favoriteTo,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: t.common.close,
                onPressed: _writing == null ? widget.onClose : null,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: _busy ? null : _create,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: Text(t.videoCommunity.createPlaylist),
                  ),
                ),
              ),
              IconButton(
                tooltip: t.common.refresh,
                onPressed: _busy ? null : () => _load(),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(liveRegion: true, child: Text(_error!)),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: _busy ? null : () => _load(),
                            child: Text(t.common.retry),
                          ),
                          if (_status == VideoSiteStatus.login)
                            TextButton(
                              onPressed: widget.onLogin,
                              child: Text(t.videoCommunity.login),
                            ),
                          if (widget.onWebsite != null)
                            TextButton(
                              onPressed: widget.onWebsite,
                              child: Text(t.videoPlayback.backToWeb),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              if (_loaded && _lists.isEmpty && _error == null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 24,
                  ),
                  child: Text(t.videoCommunity.noPlaylists),
                ),
              for (final item in _lists.values)
                ListTile(
                  key: ValueKey('playlist-choice.${item.id}'),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  title: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    _uncertain.contains(item.id)
                        ? t.videoCommunity.checkResult
                        : item.containsVideo == true
                        ? t.videoCommunity.addedToPlaylist
                        : item.containsVideo == false
                        ? t.videoCommunity.notInPlaylist
                        : t.videoCommunity.readPlaylistState,
                  ),
                  onTap: _busy
                      ? null
                      : () => _change(
                          item,
                          enabled:
                              _uncertain.contains(item.id) ||
                                  item.containsVideo == null
                              ? null
                              : !item.containsVideo!,
                        ),
                  trailing: _writing == item.id
                      ? const SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      : _uncertain.contains(item.id) ||
                            item.containsVideo == null
                      ? IconButton(
                          tooltip: _uncertain.contains(item.id)
                              ? t.videoCommunity.checkResult
                              : t.videoCommunity.addToPlaylist,
                          onPressed: _busy
                              ? null
                              : () => _change(
                                  item,
                                  enabled: _uncertain.contains(item.id)
                                      ? null
                                      : true,
                                ),
                          icon: Icon(
                            _uncertain.contains(item.id)
                                ? Icons.refresh_rounded
                                : Icons.add_rounded,
                          ),
                        )
                      : Checkbox(
                          value: item.containsVideo,
                          onChanged: _busy
                              ? null
                              : (enabled) => _change(item, enabled: enabled),
                        ),
                ),
              if (_nextPage case final page?)
                Center(
                  child: TextButton(
                    onPressed: _busy ? null : () => _load(page: page),
                    child: Text(t.videoCommunity.loadMore),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
