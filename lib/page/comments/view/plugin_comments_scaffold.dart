import 'dart:async';
import 'package:zephyr/widgets/picture_bloc/picture_recovery_region.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/page/comments/cubit/cubit.dart';
import 'package:zephyr/page/comments/model/model.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/type/pipe.dart';
import 'package:zephyr/util/text/chinese_convert.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/widgets/picture_bloc/bloc/picture_bloc.dart';
import 'package:zephyr/widgets/picture_bloc/models/picture_info.dart';

@RoutePage(name: 'PluginCommentsScaffoldRoute')
class PluginCommentsScaffold extends StatefulWidget {
  const PluginCommentsScaffold({
    super.key,
    required this.from,
    required this.comicId,
    required this.comicTitle,
    this.pluginCall,
  });

  final String from;
  final String comicId;
  final String comicTitle;
  final CommentPluginCall? pluginCall;

  @override
  State<PluginCommentsScaffold> createState() => _PluginCommentsScaffoldState();
}

class _PluginCommentsScaffoldState extends State<PluginCommentsScaffold> {
  final ScrollController _scrollController = ScrollController();
  CommentsCubit? _commentsCubit;
  bool _composerOpen = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CommentsCubit(
        from: widget.from,
        comicId: widget.comicId,
        call: widget.pluginCall,
      )..loadInitial(),
      child: BlocListener<CommentsCubit, CommentsViewState>(
        listenWhen: (previous, current) =>
            previous.noticeId != current.noticeId &&
            current.noticeMessage.trim().isNotEmpty &&
            (!_composerOpen || current.noticeMessage == t.comments.postSuccess),
        listener: (context, state) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.noticeMessage)));
        },
        child: BlocBuilder<CommentsCubit, CommentsViewState>(
          builder: (context, state) {
            final cubit = context.read<CommentsCubit>();
            _commentsCubit = cubit;
            return Scaffold(
              appBar: AppBar(
                leading: const SourceBackButton(),
                title: Text(widget.comicTitle),
                actions: [SourceMoreButton(source: widget.from)],
              ),
              body: _buildBody(state, cubit),
              floatingActionButtonLocation:
                  context.watch<GlobalSettingCubit>().state.leftHandModeEnabled
                  ? FloatingActionButtonLocation.startFloat
                  : FloatingActionButtonLocation.endFloat,
              floatingActionButton: state.canCommentComic
                  ? FloatingActionButton(
                      heroTag: null,
                      onPressed: state.posting
                          ? null
                          : () => _postComicComment(cubit),
                      child: const Icon(Icons.comment),
                    )
                  : null,
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(CommentsViewState state, CommentsCubit cubit) {
    if (state.loading) {
      return _wrapBodyContent(const Center(child: CircularProgressIndicator()));
    }
    if (state.error != null && state.topItems.isEmpty && state.items.isEmpty) {
      return _wrapBodyContent(
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.error!),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: cubit.loadInitial,
                child: Text(t.comments.retry),
              ),
            ],
          ),
        ),
      );
    }

    final merged = <CommentItem>[...state.topItems, ...state.items];
    if (merged.isEmpty) {
      return _wrapBodyContent(Center(child: Text(t.comments.noComments)));
    }

    final count =
        merged.length + (state.loadingMore || !state.hasReachedMax ? 1 : 0);
    return _wrapBodyContent(
      ListView.separated(
        controller: _scrollController,
        itemCount: count,
        separatorBuilder: (_, _) => const Padding(
          padding: EdgeInsets.only(left: 68, right: 16),
          child: Divider(height: 1, thickness: 0.3),
        ),
        itemBuilder: (context, index) {
          if (index >= merged.length) {
            if (state.loadingMore) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (state.hasReachedMax) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: FilledButton.tonalIcon(
                  onPressed: cubit.loadMore,
                  icon: const Icon(Icons.expand_more_rounded),
                  label: Text(t.comments.loadMore),
                ),
              ),
            );
          }

          final item = merged[index];
          return KeyedSubtree(
            key: ValueKey(
              'comment_${item.id}_${index}_${item.avatarUrl}_${item.avatarPath}',
            ),
            child: Builder(
              builder: (itemContext) => _buildCommentCell(
                item,
                anchorContext: itemContext,
                cubit: cubit,
                state: state,
                isReply: false,
                keySeed: '$index',
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _wrapBodyContent(Widget child) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width >= 1200
        ? 24.0
        : width >= 900
        ? 16.0
        : 8.0;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          child: child,
        ),
      ),
    );
  }

  Widget _buildCommentCell(
    CommentItem item, {
    required CommentsCubit cubit,
    required CommentsViewState state,
    required bool isReply,
    required String keySeed,
    BuildContext? anchorContext,
  }) {
    final replies = state.replyItems[item.id] ?? const <CommentItem>[];
    final isExpanded = state.expandedIds.contains(item.id);
    final canExpand = item.replyCount > 0 || item.replies.isNotEmpty;
    final loadingReplies = state.replyLoading[item.id] == true;
    final replyError = cubit.replyError(item.id);
    final hasReachedMaxReplies = state.replyHasReachedMax[item.id] == true;

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: isReply ? 56 : 16,
        right: 16,
        top: 8,
        bottom: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(item, keySeed: keySeed, isReply: isReply),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.authorName.let(convertChineseForDisplay),
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      item.content.let(convertChineseForDisplay),
                      style: textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        fontSize: 14,
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (item.createdAt.isNotEmpty)
                                Text(
                                  item.createdAt,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              if (!isReply && canExpand && !isExpanded)
                                TextButton(
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(44, 44),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                  ),
                                  onPressed: () => cubit.toggleReplies(item),
                                  child: Text(
                                    t.comments.replyCount(
                                      count: item.replyCount,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (state.canCommentReply && !isReply)
                          IconButton(
                            tooltip: t.comments.postReply,
                            onPressed: state.posting
                                ? null
                                : () => _postReply(cubit, item),
                            icon: const Icon(Icons.reply_rounded, size: 18),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isReply && isExpanded) ...[
            if (loadingReplies)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            for (var i = 0; i < replies.length; i++)
              KeyedSubtree(
                key: ValueKey(
                  'reply_${item.id}_${replies[i].id}_${i}_${replies[i].avatarUrl}_${replies[i].avatarPath}',
                ),
                child: _buildCommentCell(
                  replies[i],
                  cubit: cubit,
                  state: state,
                  isReply: true,
                  keySeed: '$keySeed-$i',
                ),
              ),
            if (replyError != null && !loadingReplies)
              Padding(
                padding: const EdgeInsets.only(left: 48, right: 16, bottom: 8),
                child: TextButton.icon(
                  key: ValueKey('comment-replies-retry.${item.id}'),
                  onPressed: () => cubit.retryReplies(item),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text('$replyError · ${t.common.retry}'),
                ),
              ),
            if (replies.isEmpty && !loadingReplies && replyError == null)
              Padding(
                padding: const EdgeInsets.only(left: 48, right: 16, bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    t.comments.noReplies,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            if (!hasReachedMaxReplies && !loadingReplies && replyError == null)
              Padding(
                padding: const EdgeInsets.only(left: 48, right: 16, bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => cubit.loadMoreReplies(item),
                    child: Text(t.comments.loadMoreReplies),
                  ),
                ),
              ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                key: ValueKey('comment-replies-collapse.${item.id}'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                onPressed: () {
                  // Keep the parent in view before removing a long reply block.
                  if (anchorContext != null) {
                    unawaited(
                      Scrollable.ensureVisible(
                        anchorContext,
                        alignmentPolicy:
                            ScrollPositionAlignmentPolicy.keepVisibleAtStart,
                      ),
                    );
                  }
                  cubit.toggleReplies(item);
                },
                child: Text(t.comments.collapseReplies),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(
    CommentItem item, {
    required String keySeed,
    bool isReply = false,
  }) {
    final size = isReply ? 28.0 : 40.0;
    if (item.avatarUrl.trim().isEmpty && item.avatarPath.trim().isEmpty) {
      return CircleAvatar(
        radius: size / 2,
        child: Icon(Icons.person, size: size * 0.6),
      );
    }
    final pictureInfo = PictureInfo(
      from: widget.from,
      url: item.avatarUrl,
      path: item.avatarPath,
      cartoonId: item.id,
      pictureType: PictureType.user,
    );
    return SizedBox(
      width: size,
      height: size,
      child: BlocProvider(
        key: ValueKey(pictureInfo),
        create: (_) =>
            PictureBloc(initiallyActive: false)..add(GetPicture(pictureInfo)),
        child: BlocBuilder<PictureBloc, PictureLoadState>(
          builder: (context, state) {
            return PictureRecoveryRegion(
              bloc: context.read<PictureBloc>(),
              child: Builder(
                builder: (context) {
                  switch (state.status) {
                    case PictureLoadStatus.initial:
                      return CircleAvatar(
                        radius: size / 2,
                        child: Icon(Icons.person, size: size * 0.6),
                      );
                    case PictureLoadStatus.success:
                      if (pictureInfo.url.contains('nopic-Male.gif')) {
                        return ClipOval(
                          child: Image.asset(
                            'asset/image/assets/default_cover.png',
                            width: size,
                            height: size,
                            fit: BoxFit.cover,
                          ),
                        );
                      }
                      return GestureDetector(
                        onTap: () => context.pushRoute(
                          FullRouteImageRoute(imagePath: state.imagePath!),
                        ),
                        child: ClipOval(
                          child: SizedBox(
                            width: size,
                            height: size,
                            child: Image.file(
                              File(state.imagePath!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, error, _) {
                                unawaited(
                                  context
                                      .read<PictureBloc>()
                                      .reportDecodeFailure(
                                        error,
                                        imagePath: state.imagePath,
                                      ),
                                );
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                      );
                    case PictureLoadStatus.failure:
                      if (state.result.toString().contains('404')) {
                        return ClipOval(
                          child: Image.asset(
                            'asset/image/assets/default_cover.png',
                            width: size,
                            height: size,
                            fit: BoxFit.cover,
                          ),
                        );
                      }
                      return InkWell(
                        onTap: () {
                          context.read<PictureBloc>().add(
                            GetPicture(pictureInfo),
                          );
                        },
                        child: CircleAvatar(
                          radius: size / 2,
                          child: Icon(Icons.refresh),
                        ),
                      );
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _postComicComment(CommentsCubit cubit) => _openInputDialog(
    cubit: cubit,
    title: t.comments.postComment,
    hint: t.comments.postCommentHint,
    send: (text, generation) =>
        cubit.postComicComment(text, generation: generation),
  );

  Future<void> _postReply(CommentsCubit cubit, CommentItem item) =>
      _openInputDialog(
        cubit: cubit,
        title: t.comments.postReply,
        hint: t.comments.postReplyHint,
        send: (text, generation) =>
            cubit.postReply(item, text, generation: generation),
      );

  Future<void> _openInputDialog({
    required CommentsCubit cubit,
    required String title,
    required String hint,
    required Future<bool> Function(String, int) send,
  }) async {
    if (_composerOpen) return;
    _composerOpen = true;
    final generation = cubit.feedGeneration;
    var draft = '';
    var sending = false;
    String? failure;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, update) => PopScope(
            canPop: !sending,
            child: AlertDialog(
              scrollable: true,
              title: Text(title),
              content: TextField(
                enabled: !sending,
                minLines: 2,
                maxLines: 5,
                onChanged: (value) => update(() => draft = value),
                decoration: InputDecoration(
                  hintText: hint,
                  errorText: failure,
                  errorMaxLines: 4,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: sending
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: Text(t.comments.cancel),
                ),
                ElevatedButton(
                  onPressed: sending || draft.trim().isEmpty
                      ? null
                      : () async {
                          if (!mounted || cubit.isClosed) return;
                          update(() {
                            sending = true;
                            failure = null;
                          });
                          final noticeId = cubit.state.noticeId;
                          final success = await send(draft.trim(), generation);
                          if (!mounted || !context.mounted) return;
                          if (success) {
                            Navigator.pop(dialogContext);
                          } else {
                            update(() {
                              sending = false;
                              failure = cubit.state.noticeId == noticeId
                                  ? t.videoCommunity.publishingUnavailable
                                  : cubit.state.noticeMessage;
                            });
                          }
                        },
                  child: sending
                      ? Text(t.videoCommunity.submitting)
                      : Text(t.comments.confirm),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      _composerOpen = false;
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.offset;
    if (current >= max * 0.9) {
      _commentsCubit?.loadMore();
    }
  }
}
