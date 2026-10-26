import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'dart:async';

import 'package:zephyr/page/video/video_page_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_site_operations.dart';
import 'package:zephyr/page/video/video_site_action_models.dart';
import 'package:zephyr/page/video/video_thumbnail.dart';

String videoOperationMessage(String status) => switch (status) {
  'login' => t.videoCommunity.loginRequired,
  'verification' => t.videoCommunity.verificationRequired,
  'unconfirmed' => t.videoCommunity.unconfirmed,
  'changed' => t.videoCommunity.pageChanged,
  'unsupported' => t.videoCommunity.unsupported,
  'busy' => t.videoCommunity.busy,
  'stale' => t.videoCommunity.commentsChanged,
  'rejected' || 'invalid' => t.videoCommunity.rejected,
  _ => t.videoCommunity.network,
};

class VideoCommunityPage extends StatefulWidget {
  const VideoCommunityPage({
    super.key,
    required this.operations,
    required this.onLogin,
    this.onWebsite,
    this.replyId,
    this.replyTitle,
    this.embedded = false,
    this.editing = false,
  });
  final VideoSiteOperations operations;
  final VoidCallback onLogin;
  final VoidCallback? onWebsite;
  final String? replyId, replyTitle;
  final bool embedded, editing;

  @override
  State<VideoCommunityPage> createState() => _VideoCommunityPageState();
}

class _VideoCommunityPageState extends State<VideoCommunityPage> {
  final _text = TextEditingController();
  bool _loading = true, _posting = false, _canPost = false;
  bool _loadingMore = false;
  int? _nextOffset;
  String? _revision, _blockedText, _postGate;
  String? _error, _status;
  List<VideoSiteComment> _items = const [];
  bool get _editing =>
      widget.editing || MediaQuery.viewInsetsOf(context).bottom > 0;

  @override
  void initState() {
    super.initState();
    final draft = widget.operations.commentDraft(widget.replyId);
    _text.text = draft.text;
    _blockedText = draft.unconfirmed ? draft.text : null;
    _text.addListener(_retainDraft);
    unawaited(_load());
  }

  @override
  void dispose() {
    widget.operations.retainCommentDraft(
      widget.replyId,
      _text.text,
      unconfirmed: _blockedText != null,
    );
    _text.removeListener(_retainDraft);
    _text.dispose();
    super.dispose();
  }

  void _retainDraft() {
    if (_blockedText != null && _text.text != _blockedText) {
      _blockedText = null;
      if (mounted && _status == 'unconfirmed') {
        setState(() {
          _status = null;
          _error = null;
        });
      }
    }
    widget.operations.retainCommentDraft(
      widget.replyId,
      _text.text,
      unconfirmed: _blockedText != null,
    );
  }

  Future<void> _load() async {
    if (_posting || _loadingMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await widget.operations.readComments(
      replyId: widget.replyId,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _status = result.status.name;
      if (result.value case final thread?) {
        _items = thread.items;
        _canPost = thread.canPost;
        _postGate = thread.postGate;
        _nextOffset = thread.nextOffset;
        _revision = thread.revision;
        if (_blockedText != null) {
          _status = 'unconfirmed';
          _error = videoOperationMessage('unconfirmed');
        }
      } else {
        _error = videoOperationMessage(_status ?? 'network');
      }
    });
  }

  Future<void> _loadMore() async {
    final offset = _nextOffset;
    if (_loading || _posting || _loadingMore || offset == null) return;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    final result = await widget.operations.readComments(
      replyId: widget.replyId,
      offset: offset,
      revision: _revision,
    );
    if (!mounted) return;
    setState(() {
      _loadingMore = false;
      if (result.value case final thread?
          when thread.revision == _revision &&
              (thread.nextOffset == null || thread.nextOffset! > offset)) {
        _items = [..._items, ...thread.items];
        _nextOffset = thread.nextOffset;
        _canPost = thread.canPost;
        _postGate = thread.postGate;
        _status = _blockedText != null ? 'unconfirmed' : 'ok';
        _error = _status == 'ok' ? null : videoOperationMessage(_status!);
      } else {
        _status = result.status == VideoSiteStatus.ok
            ? 'stale'
            : result.status.name;
        _error = videoOperationMessage(_status!);
      }
    });
  }

  Future<void> _post() async {
    final text = _text.text.trim();
    if (_loading ||
        _loadingMore ||
        _posting ||
        _blockedText != null ||
        text.isEmpty ||
        text.length > 5000) {
      return;
    }
    setState(() {
      _posting = true;
      _error = null;
    });
    final result = await widget.operations.submitComment(
      text,
      replyId: widget.replyId,
    );
    if (!mounted) return;
    setState(() {
      _posting = false;
      _status = result.status.name;
      if (result.value case final thread?) {
        _blockedText = null;
        _text.clear();
        _items = thread.items;
        _nextOffset = thread.nextOffset;
        _revision = thread.revision;
        _canPost = thread.canPost;
        _postGate = thread.postGate;
      } else {
        if (result.writeUnconfirmed) {
          _blockedText = _text.text;
          widget.operations.retainCommentDraft(
            widget.replyId,
            _text.text,
            unconfirmed: true,
          );
        }
        _error = videoOperationMessage(_status ?? 'network');
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.embedded
        ? null
        : AppBar(
            leading: const SourceBackButton(),
            title: Text(widget.replyTitle ?? t.videoCommunity.comments),
            actions: [
              IconButton(
                tooltip: t.common.refresh,
                onPressed: _loading || _loadingMore || _posting ? null : _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
    body: SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            if (widget.embedded)
              SizedBox(
                height: _editing ? 0 : null,
                child: _editing
                    ? const SizedBox.shrink()
                    : Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: IconButton(
                          tooltip: t.common.refresh,
                          onPressed: _loading || _loadingMore || _posting
                              ? null
                              : _load,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ),
              ),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: _items.isEmpty && !_loading && _error == null
                  ? Center(
                      child: Text(
                        widget.replyId == null
                            ? t.videoCommunity.noComments
                            : t.videoCommunity.noReplies,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount:
                          _items.length +
                          (_error == null ? 0 : 1) +
                          (_nextOffset == null ? 0 : 1),
                      separatorBuilder: (_, _) => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(),
                      ),
                      itemBuilder: (context, index) {
                        if (_error != null && index == 0) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(liveRegion: true, child: Text(_error!)),
                              Wrap(
                                children: [
                                  TextButton(
                                    onPressed: _posting || _loadingMore
                                        ? null
                                        : _load,
                                    child: Text(t.common.retry),
                                  ),
                                  if (_status == 'login')
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
                          );
                        }
                        final itemIndex = index - (_error == null ? 0 : 1);
                        if (itemIndex == _items.length) {
                          return Center(
                            child: TextButton.icon(
                              key: const ValueKey('video-comments-more'),
                              onPressed:
                                  _loadingMore || _posting || _status == 'stale'
                                  ? null
                                  : _loadMore,
                              icon: _loadingMore
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.expand_more_rounded),
                              label: Text(t.videoCommunity.loadMore),
                            ),
                          );
                        }
                        final item = _items[itemIndex];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipOval(
                              child: SizedBox(
                                width: 36,
                                height: 36,
                                child: VideoThumbnail(
                                  url: item.avatar,
                                  referrer: widget.operations.page,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.author,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                  if (item.time.isNotEmpty)
                                    Text(
                                      item.time,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  const SizedBox(height: 6),
                                  SelectableText(item.text),
                                  if (item.id.isNotEmpty)
                                    TextButton(
                                      onPressed: _posting || _loadingMore
                                          ? null
                                          : () => Navigator.of(context)
                                                .push<void>(
                                                  videoPageRoute(
                                                    builder: (_) =>
                                                        VideoCommunityPage(
                                                          operations:
                                                              widget.operations,
                                                          onLogin:
                                                              widget.onLogin,
                                                          onWebsite:
                                                              widget.onWebsite,
                                                          replyId: item.id,
                                                          replyTitle: t
                                                              .videoCommunity
                                                              .replies,
                                                        ),
                                                  ),
                                                ),
                                      child: Text(t.videoCommunity.viewReplies),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            if (!_loading && !_canPost && _error == null && _postGate != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(switch (_postGate) {
                        'siteVerification' =>
                          t.videoCommunity.postVerificationOnly,
                        'login' => t.videoCommunity.loginToPost,
                        _ => t.videoCommunity.publishingUnavailable,
                      }, style: Theme.of(context).textTheme.bodySmall),
                    ),
                    if (_postGate == 'login')
                      TextButton(
                        onPressed: widget.onLogin,
                        child: Text(t.videoCommunity.login),
                      )
                    else if (widget.onWebsite != null)
                      TextButton(
                        onPressed: widget.onWebsite,
                        child: Text(t.videoPlayback.backToWeb),
                      ),
                  ],
                ),
              ),
            if (_canPost)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * (_editing ? .9 : .6),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: SingleChildScrollView(
                          child: TextField(
                            controller: _text,
                            enabled: !_posting,
                            minLines: 1,
                            maxLines: 4,
                            maxLength: 5000,
                            decoration: InputDecoration(
                              labelText: t.videoCommunity.writeComment,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: FilledButton(
                          onPressed:
                              _loading ||
                                  _loadingMore ||
                                  _posting ||
                                  _blockedText != null ||
                                  const {
                                    'unconfirmed',
                                    'login',
                                    'verification',
                                    'changed',
                                  }.contains(_status)
                              ? null
                              : _post,
                          child: Text(
                            _posting
                                ? t.videoCommunity.submitting
                                : t.videoCommunity.post,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
