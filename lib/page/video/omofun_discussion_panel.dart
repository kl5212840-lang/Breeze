import 'package:zephyr/page/video/omo_network.dart';
import 'package:zephyr/page/video/video_thumbnail.dart';
import 'package:html/parser.dart' as html;
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';
import 'package:zephyr/page/video/omofun_account_page.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/util/json/json_value.dart';

Future<Uri?> showOmoDiscussionPanel(
  BuildContext context, {
  required OmoSiteClient client,
  required String vodId,
  required String episodeId,
  required Uri website,
  required Uri discussion,
  bool work = false,
  bool commentsOnly = true,
  Future<OmoNetworkContext?>? network,
}) => showVideoTaskSheet<Uri>(
  context: context,
  networkSource: omoNetworkSource,
  network: network,
  builder: (_) => OmoDiscussionPanel(
    client: client,
    vodId: vodId,
    episodeId: episodeId,
    website: website,
    discussion: discussion,
    work: work,
    commentsOnly: commentsOnly,
  ),
);

class OmoDiscussionPanel extends StatefulWidget {
  const OmoDiscussionPanel({
    super.key,
    required this.client,
    required this.vodId,
    required this.episodeId,
    required this.website,
    required this.discussion,
    this.work = false,
    this.commentsOnly = true,
    this.embedded = false,
    this.onWebsite,
  });
  final OmoSiteClient client;
  final String vodId, episodeId;
  final Uri website, discussion;
  final bool work, commentsOnly;
  final bool embedded;
  final ValueChanged<Uri>? onWebsite;
  @override
  State<OmoDiscussionPanel> createState() => _DiscussionPanelState();
}

class _DiscussionPanelState extends State<OmoDiscussionPanel> {
  late bool _work = !widget.commentsOnly && widget.work;
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _parent;
  ({
    List<Map<String, dynamic>> items,
    String? next,
    bool more,
    int offset,
    int unmapped,
    Object? error,
    double scroll,
  })?
  _rootThread;
  String? _next;
  bool _loading = true, _more = false;
  int _offset = 0, _epoch = 0, _unmapped = 0;
  Object? _error;
  final _liking = <String>{}, _uncertainLikes = <String>{};
  final _likeErrors = <String, Object>{};
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant OmoDiscussionPanel old) {
    super.didUpdateWidget(old);
    if (old.vodId != widget.vodId || old.episodeId != widget.episodeId) {
      _parent = null;
      _rootThread = null;
      _work = !widget.commentsOnly && widget.episodeId.isEmpty;
      _offset = 0;
      _load();
    }
  }

  void _open(Uri url) {
    if (widget.embedded) {
      widget.onWebsite?.call(url);
    } else {
      Navigator.pop(context, url);
    }
  }

  @override
  void dispose() {
    _epoch++;
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool append = false}) async {
    if (append && (_loading || !_more)) return;
    final epoch = ++_epoch;
    setState(() {
      _loading = true;
      _error = null;
      if (!append) _items = [];
    });
    try {
      final data = _work
          ? await widget.client.discussions(
              widget.vodId,
              pageUrl: append ? _next : null,
            )
          : await widget.client.comments(
              vodId: widget.vodId,
              episodeId: widget.episodeId,
              commentId: _parent?['id']?.toString(),
              offset: append ? _offset : 0,
            );
      if (!mounted || epoch != _epoch) return;
      final kind = _work
          ? 'discussions'
          : _parent == null
          ? 'comments'
          : 'replies';
      if (data['kind'] != kind) throw const OmoSiteException('unavailable');
      final rows = asJsonList(data['items'])
          .map(
            (value) => <String, dynamic>{
              ...asJsonMap(value),
              '_offset': append ? _offset : 0,
            },
          )
          .toList();
      setState(() {
        _items = {
          if (append)
            for (final r in _items) '${r['id']}': r,
          for (final r in rows) '${r['id']}': r,
        }.values.toList();
        final count = apiVideoInt(data['rawCount']);
        _offset = (append ? _offset : 0) + count;
        _more = data['hasMore'] == true && count > 0;
        _next = data['nextUrl']?.toString();
        _unmapped =
            (append ? _unmapped : 0) + apiVideoInt(data['unmappedCount']);
      });
      if (!append && _scroll.hasClients) _scroll.jumpTo(0);
    } catch (error) {
      if (mounted && epoch == _epoch) setState(() => _error = error);
    } finally {
      if (mounted && epoch == _epoch) setState(() => _loading = false);
    }
  }

  Future<void> _like(Map<String, dynamic> row) async {
    final id = row['id'].toString(), epoch = _epoch;
    if (_liking.contains(id)) return;
    final route = ModalRoute.of(context);
    bool ownsReadback() =>
        mounted && epoch == _epoch && route?.isActive != false;
    setState(() {
      _liking.add(id);
      _likeErrors.remove(id);
    });
    final wanted = row['liked'] != true;
    final refreshOnly = _uncertainLikes.contains(id) || row['liked'] is! bool;
    Object? writeError;
    try {
      if (!refreshOnly) {
        try {
          await widget.client.setCommentLike(id, wanted);
        } catch (error) {
          writeError = error;
        }
      }
      if (!ownsReadback()) return;
      // A timeout never triggers a second write. Read the current server state.
      final result = await widget.client.comments(
        vodId: widget.vodId,
        episodeId: widget.episodeId,
        commentId: _parent?['id']?.toString(),
        offset: apiVideoInt(row['_offset']),
      );
      if (!ownsReadback()) return;
      final current = asJsonList(result['items'])
          .map(asJsonMap)
          .where((value) => value['id'].toString() == id)
          .firstOrNull;
      if (current == null || current['liked'] is! bool) {
        throw const OmoSiteException('unconfirmed');
      }
      setState(() {
        _uncertainLikes.remove(id);
        final index = _items.indexWhere(
          (value) => value['id'].toString() == id,
        );
        if (index >= 0) _items[index] = {...current, '_offset': row['_offset']};
        if (!refreshOnly && current['liked'] != wanted) {
          _likeErrors[id] = writeError ?? const OmoSiteException('unconfirmed');
        }
      });
    } catch (error) {
      if (ownsReadback()) {
        setState(() {
          _uncertainLikes.add(id);
          _likeErrors[id] =
              writeError ??
              (error is OmoSiteException &&
                      const {
                        'signedOut',
                        'verification',
                        'notReady',
                        'permissionDenied',
                      }.contains(error.kind)
                  ? error
                  : const OmoSiteException('unconfirmed'));
        });
      }
    } finally {
      if (mounted && route?.isActive != false) {
        setState(() => _liking.remove(id));
      }
    }
  }

  void _openReplies(Map<String, dynamic> row) {
    setState(() {
      _rootThread ??= (
        items: _items,
        next: _next,
        more: _more,
        offset: _offset,
        unmapped: _unmapped,
        error: _error,
        scroll: _scroll.hasClients ? _scroll.offset : 0,
      );
      // Returning to a retained row after an unfinished write requires a
      // readback before another write can be offered.
      _uncertainLikes.addAll(_liking);
      _parent = row;
    });
    _load();
  }

  void _returnFromReplies() {
    final root = _rootThread;
    if (_parent == null || root == null) return;
    final epoch = ++_epoch;
    setState(() {
      _parent = null;
      _rootThread = null;
      _items = root.items;
      _next = root.next;
      _more = root.more;
      _offset = root.offset;
      _unmapped = root.unmapped;
      _error = root.error;
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || epoch != _epoch || !_scroll.hasClients) return;
      final position = _scroll.position;
      _scroll.jumpTo(
        root.scroll.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    });
  }

  void _section(bool work) {
    if (work == _work && _parent == null) return;
    setState(() {
      _work = work;
      _parent = null;
      _rootThread = null;
    });
    _load();
  }

  String _plain(Object? value) =>
      (html.parseFragment(apiVideoText(value, 10000)).text ?? '').trim();

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !widget.embedded || _parent == null,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && _parent != null) _returnFromReplies();
    },
    child: SizedBox(
      height: widget.embedded ? null : MediaQuery.sizeOf(context).height * .78,
      child: Column(
        children: [
          if (!widget.embedded || _parent != null)
            Row(
              children: [
                if (_parent != null)
                  IconButton(
                    tooltip: t.common.back,
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: _returnFromReplies,
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      _parent == null
                          ? t.videoCommunity.comments
                          : t.videoCommunity.replies,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                if (!widget.embedded)
                  IconButton(
                    tooltip: t.common.close,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
              ],
            ),
          if (_parent == null && !widget.commentsOnly)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    enabled: widget.episodeId.isNotEmpty,
                    label: Text(t.videoSource.episodeComments),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text(t.videoLibrary.workDiscussion),
                  ),
                ],
                selected: {_work},
                onSelectionChanged: (v) => _section(v.single),
              ),
            ),
          if (_loading) const LinearProgressIndicator(),
          if (!_loading && _items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  t.videoSource.loadedComments(count: _items.length),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          Expanded(
            child: _error != null && _items.isEmpty
                ? ApiVideoEmpty(
                    title: omoSiteError(_error),
                    action: TextButton(
                      onPressed: () => _load(),
                      child: Text(t.common.retry),
                    ),
                  )
                : !_loading && _items.isEmpty
                ? ApiVideoEmpty(title: t.videoSource.noDiscussion)
                : ListView.separated(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    itemCount: _items.length + 1,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 17, indent: 48),
                    itemBuilder: (_, index) {
                      if (index == _items.length) {
                        return Column(
                          children: [
                            if (_unmapped > 0)
                              Text(t.videoSource.siteListFallback),
                            if (_error != null) Text(omoSiteError(_error)),
                            if (_more)
                              TextButton(
                                onPressed: _loading
                                    ? null
                                    : () => _load(append: true),
                                child: Text(t.common.nextPage),
                              ),
                          ],
                        );
                      }
                      final row = _items[index], author = _plain(row['author']);
                      final replies = apiVideoInt(row['replies'], -1),
                          likes = apiVideoInt(row['likes'], -1);
                      final theme = Theme.of(context),
                          colors = theme.colorScheme;
                      final id = row['id'].toString(),
                          date = _plain(row['createdAt']);
                      final avatar = _plain(row['avatar']).isEmpty
                          ? null
                          : Uri.tryParse(_plain(row['avatar']));
                      final avatarUrl = avatar == null
                          ? ''
                          : widget.client.home.resolveUri(avatar).toString();
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipOval(
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: VideoThumbnail(
                                url: avatarUrl,
                                referrer: widget.client.home,
                                cacheWidth: 108,
                                retryOnTap: false,
                                placeholderIcon: Icons.person_outline_rounded,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (author.isNotEmpty)
                                  Text(
                                    author,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                SelectableText(
                                  _plain(row['text']),
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Wrap(
                                        spacing: 8,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            date.length >= 16
                                                ? date.substring(0, 16)
                                                : date,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color:
                                                      colors.onSurfaceVariant,
                                                ),
                                          ),
                                          if (!_work &&
                                              replies > 0 &&
                                              asJsonList(
                                                row['previewReplies'],
                                              ).isEmpty)
                                            TextButton(
                                              onPressed: () =>
                                                  _openReplies(row),
                                              style: TextButton.styleFrom(
                                                minimumSize: const Size(44, 44),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                    ),
                                              ),
                                              child: Text(
                                                t.videoSource.commentReplies(
                                                  count: replies,
                                                ),
                                                style:
                                                    theme.textTheme.bodySmall,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (_work)
                                      TextButton.icon(
                                        onPressed: () {
                                          final url = apiVideoHttps(
                                            row['url'],
                                            origin: widget.client.home,
                                          );
                                          if (url != null) _open(url);
                                        },
                                        icon: const Icon(
                                          Icons.forum_outlined,
                                          size: 18,
                                        ),
                                        label: Text(t.common.open),
                                      )
                                    else if (likes >= 0)
                                      Tooltip(
                                        message: _uncertainLikes.contains(id)
                                            ? t.common.retry
                                            : row['liked'] == true
                                            ? t.videoCommunity.liked
                                            : t.videoCommunity.like,
                                        child: TextButton.icon(
                                          key: ValueKey('omo-comment.like.$id'),
                                          style: TextButton.styleFrom(
                                            minimumSize: const Size(44, 44),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            foregroundColor:
                                                row['liked'] == true
                                                ? colors.primary
                                                : colors.onSurfaceVariant,
                                          ),
                                          onPressed: _liking.contains(id)
                                              ? null
                                              : () => _like(row),
                                          icon: _liking.contains(id)
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : Icon(
                                                  _uncertainLikes.contains(
                                                            id,
                                                          ) ||
                                                          row['liked'] is! bool
                                                      ? Icons.refresh_rounded
                                                      : row['liked'] == true
                                                      ? Icons.thumb_up_rounded
                                                      : Icons.thumb_up_outlined,
                                                  size: 18,
                                                ),
                                          label: Text('$likes'),
                                        ),
                                      ),
                                  ],
                                ),
                                if (!_work &&
                                    asJsonList(
                                      row['previewReplies'],
                                    ).isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Material(
                                      color: colors.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(10),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(10),
                                        onTap: () => _openReplies(row),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              for (final value in asJsonList(
                                                row['previewReplies'],
                                              ).take(2))
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 6,
                                                      ),
                                                  child: Text.rich(
                                                    TextSpan(
                                                      children: [
                                                        TextSpan(
                                                          text:
                                                              '${_plain(asJsonMap(value)['author'])}: ',
                                                          style: TextStyle(
                                                            color: colors
                                                                .onSurfaceVariant,
                                                          ),
                                                        ),
                                                        TextSpan(
                                                          text: _plain(
                                                            asJsonMap(
                                                              value,
                                                            )['text'],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: theme
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.copyWith(
                                                          height: 1.45,
                                                        ),
                                                  ),
                                                ),
                                              ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints(
                                                      minHeight: 32,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        t.videoSource
                                                            .commentReplies(
                                                              count: replies,
                                                            ),
                                                        style: TextStyle(
                                                          color: colors.primary,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Icon(
                                                      Icons
                                                          .chevron_right_rounded,
                                                      size: 18,
                                                      color: colors.primary,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (_likeErrors[id] != null)
                                  Text(
                                    (_likeErrors[id] is OmoSiteException &&
                                            (_likeErrors[id]
                                                        as OmoSiteException)
                                                    .sourceNotice
                                                    ?.isNotEmpty ==
                                                true)
                                        ? (_likeErrors[id] as OmoSiteException)
                                              .sourceNotice!
                                        : switch (_likeErrors[id]) {
                                            OmoSiteException(
                                              kind: 'permissionDenied',
                                            ) =>
                                              t.error.permissionDenied,
                                            OmoSiteException(
                                              kind: 'rejected',
                                            ) =>
                                              t.videoCommunity.rejected,
                                            OmoSiteException(
                                              kind: 'unconfirmed',
                                            ) =>
                                              t.videoSource.actionUnconfirmed,
                                            _ => omoSiteError(_likeErrors[id]),
                                          },
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colors.error,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextButton.icon(
                key: const ValueKey('omo-discussion-website'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                  minimumSize: const Size(44, 44),
                  textStyle: Theme.of(context).textTheme.labelMedium,
                ),
                onPressed: () =>
                    _open(_work ? widget.discussion : widget.website),
                icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                label: Text(
                  widget.commentsOnly
                      ? t.videoLibrary.openWebsite
                      : t.videoSource.continueDiscussion,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
