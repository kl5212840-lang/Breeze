import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_community_page.dart';
import 'package:zephyr/page/video/video_site_operations.dart';

class VideoPlaylistEditor extends StatefulWidget {
  const VideoPlaylistEditor({
    super.key,
    required this.initial,
    required this.operations,
    this.create = false,
    this.onLogin,
    this.onWebsite,
  });
  final Map<String, dynamic> initial;
  final VideoSiteOperations operations;
  final bool create;
  final VoidCallback? onLogin, onWebsite;
  @override
  State<VideoPlaylistEditor> createState() => _VideoPlaylistEditorState();
}

class _VideoPlaylistEditorState extends State<VideoPlaylistEditor> {
  final _key = GlobalKey<FormState>();
  late final _title = TextEditingController(
    text: widget.initial['title']?.toString() ?? '',
  );
  late final _description = TextEditingController(
    text: widget.initial['description']?.toString() ?? '',
  );
  bool _busy = false, _unconfirmed = false, _needsAdd = false;
  String? _createdId;
  String? _error;
  String? _status;
  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save({bool delete = false}) async {
    if (_busy ||
        _unconfirmed ||
        (!delete && _key.currentState?.validate() != true)) {
      return;
    }
    if (delete) {
      final accepted = await showAdaptiveDialog<bool>(
        context: context,
        builder: (context) => AlertDialog.adaptive(
          title: Text(t.videoCommunity.deletePlaylist),
          content: Text(t.videoCommunity.deletePlaylistPrompt),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t.common.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(t.common.delete),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.operations.run(
      delete
          ? 'deletePlaylist'
          : widget.create
          ? 'createPlaylist'
          : 'updatePlaylist',
      {'title': _title.text.trim(), 'description': _description.text},
    );
    if (!mounted) return;
    if (result['status'] == 'ok') {
      Navigator.pop(context, delete ? 'deleted' : 'updated');
    } else {
      setState(() {
        _busy = false;
        final id = result['createdId'];
        if (id is String && RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(id)) {
          _createdId = id;
        }
        _status = result['status']?.toString();
        _unconfirmed =
            _status == 'unconfirmed' || result['writeUnconfirmed'] == true;
        _error = videoOperationMessage(
          result['status']?.toString() ?? 'network',
        );
      });
    }
  }

  Future<void> _reconcileCreated() async {
    if (_busy || _createdId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.operations.run('reconcileCreatedPlaylist');
    if (!mounted) return;
    final lists = result['lists'];
    final item = lists is List
        ? lists
              .whereType<Map>()
              .where((value) => value['id'] == _createdId)
              .firstOrNull
        : null;
    if (result['status'] == 'ok' && item?['containsVideo'] == true) {
      Navigator.pop(context, 'updated');
      return;
    }
    setState(() {
      _busy = false;
      _needsAdd =
          result['status'] == 'ok' &&
          result['createdVerified'] == true &&
          item?['containsVideo'] == false;
      _status = result['status']?.toString();
      _error = _needsAdd
          ? t.videoCommunity.createdNotAdded
          : videoOperationMessage(_status ?? 'network');
    });
  }

  Future<void> _addToCreated() async {
    final id = _createdId;
    if (_busy || !_needsAdd || id == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.operations.setPlaylistMembership(id, true);
    if (!mounted) return;
    if (result.status.name == 'ok' &&
        result.value?.lists.any(
              (item) => item.id == id && item.containsVideo == true,
            ) ==
            true) {
      Navigator.pop(context, 'updated');
      return;
    }
    setState(() {
      _busy = false;
      _needsAdd = false;
      _status = result.status.name;
      _error = videoOperationMessage(_status!);
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.create
              ? t.videoCommunity.createPlaylist
              : t.videoCommunity.editPlaylist,
        ),
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _key,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  TextFormField(
                    controller: _title,
                    maxLength: 100,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: t.videoCommunity.playlistTitle,
                    ),
                    validator: (v) => v?.trim().isNotEmpty == true
                        ? null
                        : t.videoCommunity.required,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _description,
                    maxLength: 2000,
                    minLines: 3,
                    maxLines: 8,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: t.videoCommunity.playlistDescription,
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(liveRegion: true, child: Text(_error!)),
                          Wrap(
                            children: [
                              if (_createdId != null)
                                TextButton(
                                  onPressed: _busy ? null : _reconcileCreated,
                                  child: Text(t.videoCommunity.checkStatus),
                                ),
                              if (_needsAdd)
                                TextButton(
                                  onPressed: _busy ? null : _addToCreated,
                                  child: Text(
                                    t.videoCommunity.addToCreatedPlaylist,
                                  ),
                                ),
                              if (_status == 'login' && widget.onLogin != null)
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
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy || _unconfirmed ? null : _save,
                    child: Text(
                      _busy ? t.videoCommunity.submitting : t.common.save,
                    ),
                  ),
                  if (widget.initial['canDelete'] == true) ...[
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: _busy || _unconfirmed
                          ? null
                          : () => _save(delete: true),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      child: Text(t.videoCommunity.deletePlaylist),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
