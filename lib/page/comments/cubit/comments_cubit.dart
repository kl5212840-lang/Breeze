import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart'
    show normalizePluginId;
import 'package:zephyr/network/http/plugin/unified_plugin_envelope.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comments/model/model.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/util/json/json_value.dart';

part 'comments_cubit.freezed.dart';

@freezed
abstract class CommentsViewState with _$CommentsViewState {
  const factory CommentsViewState({
    @Default(<CommentItem>[]) List<CommentItem> topItems,
    @Default(<CommentItem>[]) List<CommentItem> items,
    @Default(false) bool loading,
    @Default(false) bool loadingMore,
    @Default(false) bool hasReachedMax,
    @Default(false) bool canCommentComic,
    @Default(false) bool canCommentReply,
    @Default(false) bool posting,
    @Default('lazy') String replyMode,
    @Default(1) int page,
    String? error,
    @Default(<String>{}) Set<String> expandedIds,
    @Default(<String, List<CommentItem>>{})
    Map<String, List<CommentItem>> replyItems,
    @Default(<String, bool>{}) Map<String, bool> replyLoading,
    @Default(<String, bool>{}) Map<String, bool> replyHasReachedMax,
    @Default(<String, int>{}) Map<String, int> replyPage,
    @Default('') String noticeMessage,
    @Default(0) int noticeId,
  }) = _CommentsViewState;
}

typedef CommentPluginCall =
    Future<Map<String, dynamic>> Function({
      required String from,
      required String fnPath,
      required Map<String, dynamic> core,
      required Map<String, dynamic> extern,
    });

class CommentsCubit extends Cubit<CommentsViewState> {
  CommentsCubit({
    required this.from,
    required this.comicId,
    CommentPluginCall? call,
  }) : _call =
           call ??
           (({
             required from,
             required fnPath,
             required core,
             required extern,
           }) => callUnifiedComicPlugin(
             from: from,
             fnPath: fnPath,
             core: core,
             extern: extern,
           )),
       super(const CommentsViewState()) {
    final source = normalizePluginId(from);
    _sessionChanges = pluginSessionWriteFence.changes.listen((boundary) {
      if (boundary.source != source || isClosed) return;
      _feedEpoch++;
      _replyErrors.clear();
      _replyPath = 'loadCommentReplies';
      _safeEmit(const CommentsViewState(loading: true));
      if (!boundary.changing) unawaited(loadInitial());
    });
  }

  late final StreamSubscription<PluginSessionBoundary> _sessionChanges;

  @override
  Future<void> close() async {
    _feedEpoch++;
    await _sessionChanges.cancel();
    await super.close();
  }

  final CommentPluginCall _call;
  final Map<String, String> _replyErrors = {};
  String? replyError(String id) => _replyErrors[id];
  int _feedEpoch = 0;
  int get feedGeneration => _feedEpoch;

  bool _ownsFeed(int epoch) => !isClosed && epoch == _feedEpoch;
  String _replyPath = 'loadCommentReplies';
  Future<void> retryReplies(CommentItem item) => _loadReplies(
    item: item,
    page: state.replyPage[item.id] ?? 1,
    reset: !state.replyItems.containsKey(item.id),
  );

  final String from;
  final String comicId;

  Future<void> loadInitial() async {
    if (isClosed) return;
    if (pluginSessionWriteFence.isChanging(normalizePluginId(from))) {
      _safeEmit(const CommentsViewState(loading: true));
      return;
    }
    final epoch = ++_feedEpoch;
    _replyErrors.clear();
    _safeEmit(
      state.copyWith(
        loading: true,
        loadingMore: false,
        canCommentComic: false,
        canCommentReply: false,
        error: null,
        page: 1,
        hasReachedMax: false,
        topItems: const <CommentItem>[],
        items: const <CommentItem>[],
        expandedIds: const <String>{},
        replyItems: const <String, List<CommentItem>>{},
        replyLoading: const <String, bool>{},
        replyHasReachedMax: const <String, bool>{},
        replyPage: const <String, int>{},
      ),
    );

    try {
      final feed = await _fetchPage(1);
      if (!_ownsFeed(epoch)) return;
      _safeEmit(
        state.copyWith(
          topItems: feed.topItems,
          items: feed.items,
          page: 2,
          hasReachedMax: feed.hasReachedMax,
          replyMode: feed.replyMode,
          canCommentComic: feed.canCommentComic,
          canCommentReply: feed.canCommentReply,
          loading: false,
        ),
      );
    } catch (e) {
      if (!_ownsFeed(epoch)) return;
      _safeEmit(
        state.copyWith(loading: false, error: normalizeSearchErrorMessage(e)),
      );
    }
  }

  Future<void> loadMore() async {
    if (isClosed || state.loadingMore || state.hasReachedMax || state.loading) {
      return;
    }
    final epoch = _feedEpoch;
    final page = state.page;
    _safeEmit(state.copyWith(loadingMore: true, error: null));

    try {
      final feed = await _fetchPage(page);
      if (!_ownsFeed(epoch)) return;
      _safeEmit(
        state.copyWith(
          items: <CommentItem>[...state.items, ...feed.items],
          page: page + 1,
          hasReachedMax: feed.hasReachedMax,
          loadingMore: false,
        ),
      );
    } catch (e) {
      if (!_ownsFeed(epoch)) return;
      _safeEmit(
        state.copyWith(
          loadingMore: false,
          error: normalizeSearchErrorMessage(e),
        ),
      );
    }
  }

  Future<bool> postComicComment(String content, {int? generation}) async {
    if (!state.canCommentComic) return false;
    return _submitCommentMutation(
      generation: generation,
      fnPath: 'postComment',
      core: {'comicId': comicId, 'content': content},
      extern: const <String, dynamic>{},
    );
  }

  Future<bool> postReply(
    CommentItem item,
    String content, {
    int? generation,
  }) async {
    if (!state.canCommentReply || !_hasParent(item.id)) return false;
    return _submitCommentMutation(
      generation: generation,
      fnPath: 'postCommentReply',
      core: {'comicId': comicId, 'commentId': item.id, 'content': content},
      extern: item.extern,
    );
  }

  bool _hasParent(String id) =>
      state.topItems.any((item) => item.id == id) ||
      state.items.any((item) => item.id == id);

  Future<void> toggleReplies(CommentItem item) async {
    if (isClosed || !_hasParent(item.id)) return;
    if (state.expandedIds.contains(item.id)) {
      final expandedIds = Set<String>.from(state.expandedIds)..remove(item.id);
      _safeEmit(state.copyWith(expandedIds: expandedIds));
      return;
    }

    final expandedIds = Set<String>.from(state.expandedIds)..add(item.id);
    _safeEmit(state.copyWith(expandedIds: expandedIds));

    if (state.replyMode == 'embedded') {
      if (state.replyItems.containsKey(item.id)) {
        return;
      }
      final replyItems = Map<String, List<CommentItem>>.from(state.replyItems)
        ..[item.id] = item.replies;
      final replyHasReachedMax = Map<String, bool>.from(
        state.replyHasReachedMax,
      )..[item.id] = true;
      _safeEmit(
        state.copyWith(
          replyItems: replyItems,
          replyHasReachedMax: replyHasReachedMax,
        ),
      );
      return;
    }

    if (state.replyItems.containsKey(item.id)) {
      return;
    }
    await _loadReplies(item: item, page: 1, reset: true);
  }

  Future<void> loadMoreReplies(CommentItem item) async {
    final nextPage = state.replyPage[item.id] ?? 1;
    await _loadReplies(item: item, page: nextPage, reset: false);
  }

  Future<bool> _submitCommentMutation({
    required int? generation,
    required String fnPath,
    required Map<String, dynamic> core,
    required Map<String, dynamic> extern,
  }) async {
    final epoch = _feedEpoch;
    final source = normalizePluginId(from);
    final session = pluginSessionWriteFence.generation(source);
    if (!_ownsFeed(generation ?? epoch) ||
        state.posting ||
        state.loading ||
        pluginSessionWriteFence.isChanging(source) ||
        (core['content'] as String).trim().isEmpty) {
      return false;
    }
    bool ownsSession() =>
        !isClosed && pluginSessionWriteFence.generation(source) == session;

    _safeEmit(state.copyWith(posting: true));
    try {
      final response = await _call(
        from: from,
        fnPath: fnPath,
        core: core,
        extern: extern,
      );
      if (!ownsSession()) return false;
      requireSuccessfulPluginEnvelope(response);
      final data = UnifiedPluginEnvelope.fromMap(response).data;
      requireSuccessfulPluginEnvelope(data);
      final parent = core['commentId'] as String?;
      final mode = parent == null ? 'postComment' : 'postReply';
      final hint = asJsonMap(data['insertHint']);
      final reportedParent = data['parentId']?.toString();
      final hintedParent = hint['targetCommentId']?.toString();
      if (data['ok'] != true ||
          data['mode'] != mode ||
          (parent == null
              ? reportedParent?.isNotEmpty == true ||
                    hintedParent?.isNotEmpty == true
              : reportedParent != parent ||
                    hintedParent != null && hintedParent != parent)) {
        throw const FormatException('Comment submission was not confirmed');
      }
      if (!_ownsFeed(epoch)) return true;

      final applied =
          hint['needsRefetch'] != true && _applyMutation(data, hint, parent);
      if (!applied) {
        final restoreThread =
            parent != null && state.expandedIds.contains(parent);
        final refresh = loadInitial();
        final refreshedEpoch = _feedEpoch;
        await refresh;
        if (!_ownsFeed(refreshedEpoch)) return true;
        if (restoreThread) {
          final thread = [
            ...state.topItems,
            ...state.items,
          ].where((item) => item.id == parent).firstOrNull;
          if (thread != null) await toggleReplies(thread);
        }
        if (!_ownsFeed(refreshedEpoch)) return true;
      }
      _emitNotice(t.comments.postSuccess);
      return true;
    } catch (e) {
      if (ownsSession() && _ownsFeed(epoch)) {
        _emitNotice(
          t.comments.postFailed(error: normalizeSearchErrorMessage(e)),
        );
      }
      return false;
    } finally {
      if (ownsSession()) _safeEmit(state.copyWith(posting: false));
    }
  }

  bool _applyMutation(
    Map<String, dynamic> data,
    Map<String, dynamic> hint,
    String? parent,
  ) {
    final createdMap = asJsonMap(data['created']);
    if (createdMap.isEmpty) return false;
    final created = CommentItem.fromMap(createdMap);
    if (created.id.isEmpty) return false;
    final strategy = hint['strategy'];
    if (parent == null && strategy == 'prependAfterTop') {
      _safeEmit(
        state.copyWith(
          items: [
            created,
            ...state.items.where((item) => item.id != created.id),
          ],
        ),
      );
      return true;
    }
    if (parent == null ||
        strategy != 'prepend' ||
        !_hasParent(parent) ||
        state.replyLoading[parent] == true) {
      return false;
    }
    final current = state.replyItems[parent];
    if (current == null) return false;
    final alreadyPresent = current.any((item) => item.id == created.id);
    _safeEmit(
      state.copyWith(
        topItems: alreadyPresent
            ? state.topItems
            : _bumpReplyCount(state.topItems, parent),
        items: alreadyPresent
            ? state.items
            : _bumpReplyCount(state.items, parent),
        replyItems: {
          ...state.replyItems,
          parent: [created, ...current.where((item) => item.id != created.id)],
        },
      ),
    );
    return true;
  }

  List<CommentItem> _bumpReplyCount(
    List<CommentItem> source,
    String commentId,
  ) {
    final next = List<CommentItem>.from(source);
    for (var i = 0; i < next.length; i++) {
      if (next[i].id == commentId) {
        next[i] = next[i].copyWith(replyCount: next[i].replyCount + 1);
        break;
      }
    }
    return next;
  }

  Future<Map<String, dynamic>> _readReplies(
    CommentItem item,
    int page,
    int epoch,
  ) async {
    final path = _replyPath;
    final core = {'comicId': comicId, 'commentId': item.id, 'page': page};
    try {
      return await _call(
        from: from,
        fnPath: path,
        core: core,
        extern: item.extern,
      );
    } catch (error) {
      if (!_ownsFeed(epoch) ||
          path != 'loadCommentReplies' ||
          !(error.toString().contains(
                'function path not found: loadCommentReplies; missing segment=loadCommentReplies;',
              ) ||
              error.toString().contains(
                'target is not function: loadCommentReplies; targetType=undefined;',
              )))
        rethrow;
      final result = await _call(
        from: from,
        fnPath: 'getCommentReplies',
        core: core,
        extern: item.extern,
      );
      if (_ownsFeed(epoch)) _replyPath = 'getCommentReplies';
      return result;
    }
  }

  Future<void> _loadReplies({
    required CommentItem item,
    required int page,
    required bool reset,
  }) async {
    if (isClosed ||
        !_hasParent(item.id) ||
        state.replyLoading[item.id] == true) {
      return;
    }
    if (!reset && (state.replyHasReachedMax[item.id] == true)) {
      return;
    }

    final epoch = _feedEpoch;
    _replyErrors.remove(item.id);
    final replyLoading = Map<String, bool>.from(state.replyLoading)
      ..[item.id] = true;
    _safeEmit(state.copyWith(replyLoading: replyLoading));

    try {
      final response = await _readReplies(item, page, epoch);
      if (!_ownsFeed(epoch)) return;
      final envelope = UnifiedPluginEnvelope.fromMap(response);
      final data = envelope.data;
      if (data['items'] is! List ||
          data['commentId'] != null &&
              data['commentId'].toString() != item.id) {
        throw const FormatException('Reply response does not match its parent');
      }
      final items = asJsonList(
        data['items'],
      ).map(asJsonMap).map(CommentItem.fromMap).toList();
      final paging = asJsonMap(data['paging']);
      final hasReachedMax = paging['hasReachedMax'] == true;

      final current = reset
          ? const <CommentItem>[]
          : (state.replyItems[item.id] ?? const <CommentItem>[]);

      final replyItems = Map<String, List<CommentItem>>.from(state.replyItems)
        ..[item.id] = <CommentItem>[...current, ...items];
      final nextReplyLoading = Map<String, bool>.from(state.replyLoading)
        ..[item.id] = false;
      final replyHasReachedMax = Map<String, bool>.from(
        state.replyHasReachedMax,
      )..[item.id] = hasReachedMax;
      final replyPage = Map<String, int>.from(state.replyPage)
        ..[item.id] = page + 1;

      _safeEmit(
        state.copyWith(
          replyItems: replyItems,
          replyLoading: nextReplyLoading,
          replyHasReachedMax: replyHasReachedMax,
          replyPage: replyPage,
        ),
      );
    } catch (_) {
      if (!_ownsFeed(epoch)) return;
      _replyErrors[item.id] = t.common.loadingFailed;
      final nextReplyLoading = Map<String, bool>.from(state.replyLoading)
        ..[item.id] = false;
      _safeEmit(state.copyWith(replyLoading: nextReplyLoading));
    }
  }

  Future<_CommentFeed> _fetchPage(int page) async {
    final response = await _call(
      from: from,
      fnPath: 'getCommentFeed',
      core: {'comicId': comicId, 'page': page},
      extern: const <String, dynamic>{},
    );
    final envelope = UnifiedPluginEnvelope.fromMap(response);
    final data = envelope.data;
    final topItems = asJsonList(
      data['topItems'],
    ).map(asJsonMap).map(CommentItem.fromMap).toList();
    final items = asJsonList(
      data['items'],
    ).map(asJsonMap).map(CommentItem.fromMap).toList();
    final paging = asJsonMap(data['paging']);
    return _CommentFeed(
      topItems: topItems,
      items: items,
      replyMode: data['replyMode']?.toString() ?? 'lazy',
      canCommentComic: asJsonMap(data['canComment'])['comic'] == true,
      canCommentReply: asJsonMap(data['canComment'])['reply'] == true,
      hasReachedMax: paging['hasReachedMax'] == true,
    );
  }

  void _emitNotice(String message) {
    _safeEmit(
      state.copyWith(noticeMessage: message, noticeId: state.noticeId + 1),
    );
  }

  void _safeEmit(CommentsViewState nextState) {
    if (isClosed) {
      return;
    }
    emit(nextState);
  }
}

class _CommentFeed {
  const _CommentFeed({
    required this.topItems,
    required this.items,
    required this.replyMode,
    required this.canCommentComic,
    required this.canCommentReply,
    required this.hasReachedMax,
  });

  final List<CommentItem> topItems;
  final List<CommentItem> items;
  final String replyMode;
  final bool canCommentComic;
  final bool canCommentReply;
  final bool hasReachedMax;
}
