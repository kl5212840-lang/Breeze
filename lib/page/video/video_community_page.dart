import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'dart:async';

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
    this.inline = false,
  });
  final VideoSiteOperations operations;
  final VoidCallback onLogin;
  final VoidCallback? onWebsite;
  final String? replyId, replyTitle;
  final bool embedded, editing, inline;

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
  final Set<String> _expandedReplies = {};
  int _requestEpoch = 0;
  bool get _editing =>
      widget.editing || MediaQuery.viewInsetsOf(context).bottom > 0;

  @override
  void initState() {
    super.initState();
    _restoreDraft();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant VideoCommunityPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.operations == widget.operations &&
        oldWidget.replyId == widget.replyId) {
      return;
    }
    _requestEpoch++;
    _posting = _loadingMore = _canPost = false;
    _nextOffset = null;
    _revision = _postGate = _status = null;
    _items = const [];
    _expandedReplies.clear();
    _restoreDraft();
    unawaited(_load());
  }

  void _restoreDraft() {
    final draft = widget.operations.commentDraft(widget.replyId);
    _text.text = draft.text;
    _blockedText = draft.unconfirmed ? draft.text : null;
  }

  bool _ownsRequest(int epoch, VideoSiteOperations operations) =>
      mounted && epoch == _requestEpoch && operations == widget.operations;

  @override
  void dispose() {
    _requestEpoch++;
    _text.dispose();
    super.dispose();
  }

  void _retainDraft(String text) {
    if (_blockedText case final blocked?) {
      if (text.trim() == blocked.trim()) return;
      _blockedText = null;
      if (mounted && _status == 'unconfirmed') {
        setState(() {
          _status = null;
          _error = null;
        });
      }
    }
    widget.operations.retainCommentDraft(widget.replyId, text);
  }

  Future<void> _load() async {
    if (_posting || _loadingMore) return;
    final epoch = ++_requestEpoch;
    setState(() {
      _loading = true;
      _error = null;
    });
    final operations = widget.operations;
    final replyId = widget.replyId;
    while (operations.busy) {
      await operations.whenIdle;
      if (!_ownsRequest(epoch, operations)) return;
    }
    if (!_ownsRequest(epoch, operations)) return;
    final result = await operations.readComments(replyId: replyId);
    if (!_ownsRequest(epoch, operations)) return;
    if (!operations.ownsCommentSession) {
      _invalidateCommentSession();
      return;
    }
    setState(() {
      _loading = false;
      _status = result.status.name;
      if (result.value case final thread?) {
        if (_blockedText case final blocked?) {
          final draft = widget.operations.commentDraft(widget.replyId);
          if (!draft.unconfirmed &&
              (draft.text.isEmpty || draft.text.trim() == blocked.trim())) {
            _blockedText = null;
            if (draft.text.isEmpty) _text.clear();
          }
        }
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
    final epoch = _requestEpoch;
    final offset = _nextOffset;
    if (_loading || _posting || _loadingMore || offset == null) return;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    final operations = widget.operations;
    final replyId = widget.replyId;
    final revision = _revision;
    while (operations.busy) {
      await operations.whenIdle;
      if (!_ownsRequest(epoch, operations)) return;
    }
    if (!_ownsRequest(epoch, operations)) return;
    final result = await operations.readComments(
      replyId: replyId,
      offset: offset,
      revision: revision,
    );
    if (!_ownsRequest(epoch, operations)) return;
    if (!operations.ownsCommentSession) {
      _invalidateCommentSession();
      return;
    }
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

  void _invalidateCommentSession() {
    setState(() {
      _loading = _loadingMore = _posting = _canPost = false;
      _items = const [];
      _nextOffset = null;
      _expandedReplies.clear();
      _blockedText = null;
      _text.clear();
      _status = 'changed';
      _error = videoOperationMessage('changed');
    });
  }

  Future<void> _post() async {
    final operations = widget.operations;
    final epoch = _requestEpoch;
    final text = _text.text.trim();
    if (_loading ||
        _loadingMore ||
        _posting ||
        !_canPost ||
        !operations.ownsCommentSession ||
        _blockedText != null ||
        text.isEmpty ||
        text.length > 5000) {
      return;
    }
    setState(() {
      _posting = true;
      _error = null;
    });
    final submitted = _text.text;
    final result = await operations.submitComment(
      submitted,
      replyId: widget.replyId,
    );
    if (!_ownsRequest(epoch, operations)) return;
    if (!operations.ownsCommentSession) {
      _invalidateCommentSession();
      return;
    }
    setState(() {
      _posting = false;
      _status = result.status.name;
      if (result.value case final thread?) {
        _blockedText = null;
        if (_text.text == submitted) _text.clear();
        _items = thread.items;
        _nextOffset = thread.nextOffset;
        _revision = thread.revision;
        _canPost = thread.canPost;
        _postGate = thread.postGate;
      } else {
        if (result.writeUnconfirmed && _text.text == submitted) {
          _blockedText = submitted;
        }
        _error = videoOperationMessage(_status ?? 'network');
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.inline
      ? _body(context)
      : Scaffold(
          appBar: widget.embedded
              ? null
              : AppBar(
                  leading: const SourceBackButton(),
                  title: Text(widget.replyTitle ?? t.videoCommunity.comments),
                  actions: [
                    IconButton(
                      tooltip: t.common.refresh,
                      onPressed: _loading || _loadingMore || _posting
                          ? null
                          : _load,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
          body: _body(context),
        );

  Widget _threadContent(Widget child) =>
      widget.inline ? child : Expanded(child: child);

  Widget _refreshable(Widget list) => widget.embedded && !widget.inline
      ? RefreshIndicator(
          onRefresh: () async {
            if (!_loading && !_loadingMore && !_posting && !_editing) {
              await _load();
            }
          },
          child: list,
        )
      : list;

  Widget _body(BuildContext context) => SafeArea(
    top: false,
    bottom: !widget.inline,
    child: LayoutBuilder(
      builder: (context, constraints) => Column(
        mainAxisSize: widget.inline ? MainAxisSize.min : MainAxisSize.max,
        children: [
          if (widget.inline)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  widget.replyTitle ?? t.videoCommunity.replies,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
          if (_loading) const LinearProgressIndicator(),
          _threadContent(
            _items.isEmpty && !_loading && _error == null
                ? Center(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          widget.replyId == null
                              ? t.videoCommunity.noComments
                              : t.videoCommunity.noReplies,
                        ),
                        if (widget.embedded && !widget.inline)
                          IconButton(
                            tooltip: t.common.refresh,
                            onPressed: _posting || _editing ? null : _load,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                      ],
                    ),
                  )
                : _refreshable(
                    ListView.separated(
                      shrinkWrap: widget.inline,
                      physics: widget.inline
                          ? const NeverScrollableScrollPhysics()
                          : widget.embedded
                          ? const AlwaysScrollableScrollPhysics()
                          : null,
                      padding: widget.inline
                          ? const EdgeInsetsDirectional.only(
                              start: 8,
                              bottom: 6,
                            )
                          : const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      itemCount:
                          _items.length +
                          (_error == null ? 0 : 1) +
                          (_nextOffset == null ? 0 : 1),
                      separatorBuilder: (_, _) =>
                          const Divider(height: 17, indent: 48),
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
                        return Builder(
                          builder: (itemContext) => Row(
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    SelectableText(item.text),
                                    if (item.time.isNotEmpty ||
                                        item.id.isNotEmpty)
                                      Wrap(
                                        spacing: 8,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          if (item.time.isNotEmpty)
                                            Text(
                                              item.time,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          if (item.id.isNotEmpty &&
                                              !_expandedReplies.contains(
                                                item.id,
                                              ))
                                            TextButton(
                                              key: ValueKey(
                                                'video-comment-replies.${item.id}',
                                              ),
                                              style: TextButton.styleFrom(
                                                minimumSize: const Size(44, 44),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                    ),
                                              ),
                                              onPressed:
                                                  _posting || _loadingMore
                                                  ? null
                                                  : () => setState(() {
                                                      if (!_expandedReplies.add(
                                                        item.id,
                                                      ))
                                                        _expandedReplies.remove(
                                                          item.id,
                                                        );
                                                    }),
                                              child: Text(
                                                t.videoCommunity.viewReplies,
                                              ),
                                            ),
                                        ],
                                      ),
                                    if (_expandedReplies.contains(item.id)) ...[
                                      VideoCommunityPage(
                                        key: ValueKey(
                                          'video-inline-replies.${item.id}',
                                        ),
                                        operations: widget.operations,
                                        onLogin: widget.onLogin,
                                        onWebsite: widget.onWebsite,
                                        replyId: item.id,
                                        replyTitle: t.videoCommunity.replies,
                                        embedded: true,
                                        inline: true,
                                      ),
                                      Align(
                                        alignment:
                                            AlignmentDirectional.centerEnd,
                                        child: TextButton(
                                          key: ValueKey(
                                            'video-comment-replies.${item.id}',
                                          ),
                                          style: TextButton.styleFrom(
                                            minimumSize: const Size(44, 44),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                            ),
                                          ),
                                          onPressed: _posting || _loadingMore
                                              ? null
                                              : () {
                                                  unawaited(
                                                    Scrollable.ensureVisible(
                                                      itemContext,
                                                      alignmentPolicy:
                                                          ScrollPositionAlignmentPolicy
                                                              .keepVisibleAtStart,
                                                    ),
                                                  );
                                                  setState(
                                                    () => _expandedReplies
                                                        .remove(item.id),
                                                  );
                                                },
                                          child: Text(
                                            t.comments.collapseReplies,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
          if (!widget.inline &&
              !_loading &&
              !_canPost &&
              _error == null &&
              _postGate != null)
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
                maxHeight: widget.inline
                    ? 260
                    : constraints.maxHeight * (_editing ? .9 : .6),
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
                          onChanged: _retainDraft,
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
  );
}
