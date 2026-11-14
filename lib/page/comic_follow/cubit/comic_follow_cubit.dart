import 'dart:convert';

import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart'
    show normalizePluginId;
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';

import 'package:bloc/bloc.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart'
    as normal;
import 'package:zephyr/page/comic_info/method/get_plugin_detail.dart'
    show sortChaptersByOrder;
import 'package:zephyr/page/comic_follow/cubit/comic_follow_state.dart';
import 'package:zephyr/page/comic_follow/cubit/comic_follow_sync.dart';
import 'package:zephyr/service/comic_follow/comic_follow_check_failure.dart';
import 'package:zephyr/service/comic_follow/comic_follow_service.dart';

export 'package:zephyr/page/comic_follow/cubit/comic_follow_state.dart';
export 'package:zephyr/service/comic_follow/comic_follow_check_failure.dart'
    show ComicFollowCheckFailure;

enum ComicFollowRefreshStatus {
  updated,
  partial,
  unchanged,
  incomplete,
  ignored,
}

enum _CheckResult { freshUpdate, changed, unchanged, failed, skipped }

typedef _BatchResult = ({int updateCount, ComicFollowRefreshStatus status});
typedef _BatchWork = ({
  Future<_BatchResult> result,
  void Function() includeRemaining,
  bool Function() isCurrent,
});
typedef _ItemWork = ({Future<_CheckResult> result, bool Function() isCurrent});
typedef _ChapterEvidence = ({
  int total,
  Set<String> latestIds,
  bool hasOrderedChapters,
  String readId,
  int? readPosition,
});

class ComicFollowCubit extends Cubit<ComicFollowState> {
  ComicFollowCubit({
    ComicFollowRepository? repository,
    DateTime Function()? now,
  }) : _repository = repository ?? ComicFollowService.instance,
       _now = now ?? DateTime.now,
       super(const ComicFollowState()) {
    loadFromDatabase();
  }

  final ComicFollowRepository _repository;
  final DateTime Function() _now;
  static const successCheckInterval = Duration(minutes: 15);
  static const automaticBatchLimit = 4;
  static const automaticBatchInterval = Duration(minutes: 1);
  final Map<String, _ItemWork> _inflight = {};
  final Map<String, int> _failures = {};
  final Map<String, int> _pendingUpdates = {};
  final _chapterEvidence = <String, _ChapterEvidence>{};
  final _deferredChecks = <String, DateTime>{};
  _BatchWork? _batchInFlight;
  final Set<Object> _pageCheckingOwners = Set<Object>.identity();
  final Object _legacyPageOwner = Object();
  Object? _applicationCheckingOwner;
  bool _applicationManaged = false, _applicationForeground = false;
  DateTime? _lastAutomaticBatchStarted;
  int _activityGeneration = 0, _dataGeneration = 0;

  bool isCheckDeferred(ComicFollow follow) =>
      _deferredChecks[follow.uniqueKey] == follow.createdAt;

  int get incompleteCheckCount => state.items
      .where(
        (item) =>
            !item.deleted && (item.lastCheckFailed || isCheckDeferred(item)),
      )
      .length;

  int? readChapterPositionFor(
    ComicFollow follow,
    UnifiedComicHistory? history,
  ) {
    final evidence = _chapterEvidence[follow.uniqueKey];
    if (history == null ||
        evidence == null ||
        !evidence.hasOrderedChapters ||
        evidence.total != follow.detectedChapterCount) {
      return null;
    }
    final id = history.chapterId.trim();
    if (evidence.latestIds.contains(id)) return evidence.total;
    return id == evidence.readId ? evidence.readPosition : null;
  }

  bool get _checkingActive => _applicationManaged
      ? _applicationForeground
      : _pageCheckingOwners.isNotEmpty;

  /// Application foreground is authoritative once the mounted main navigation
  /// attaches its scheduler. Page visibility can never turn this owner off.
  void attachApplicationCheckingOwner(
    Object owner, {
    required bool foreground,
  }) {
    if (isClosed) return;
    final changedOwner = !identical(_applicationCheckingOwner, owner);
    final wasActive = _checkingActive;
    _applicationManaged = true;
    _applicationCheckingOwner = owner;
    _applicationForeground = foreground;
    if (changedOwner || wasActive != _checkingActive) {
      _activityGeneration++;
      if (!_checkingActive) _pendingUpdates.clear();
    }
  }

  bool isApplicationCheckingOwner(Object owner) =>
      !isClosed && identical(_applicationCheckingOwner, owner);

  void setApplicationCheckingForeground(Object owner, bool foreground) {
    if (!isApplicationCheckingOwner(owner) ||
        _applicationForeground == foreground) {
      return;
    }
    _applicationForeground = foreground;
    _activityGeneration++;
    if (!foreground) _pendingUpdates.clear();
  }

  void detachApplicationCheckingOwner(Object owner) {
    if (!isApplicationCheckingOwner(owner)) return;
    _applicationCheckingOwner = null;
    _applicationForeground = false;
    _activityGeneration++;
    _pendingUpdates.clear();
    // Keep application-managed gating after detach: an old page cannot revive
    // checks while its main navigation/scheduler is being disposed.
  }

  /// Used only for page/manual activity and standalone page hosts. With an
  /// application scheduler present, leaving a page has no effect on global I/O.
  void setPageCheckingActive(Object owner, bool active) {
    if (isClosed) return;
    final wasActive = _checkingActive;
    if (active) {
      _pageCheckingOwners.add(owner);
    } else {
      _pageCheckingOwners.remove(owner);
    }
    if (!_applicationManaged && wasActive != _checkingActive) {
      _activityGeneration++;
      if (!_checkingActive) _pendingUpdates.clear();
    }
  }

  /// Legacy standalone callers retain their own page lease, never the app lease.
  void setAutomaticCheckingActive(bool active) =>
      setPageCheckingActive(_legacyPageOwner, active);

  DateTime _nextCheck(ComicFollow follow) {
    final failures =
        _failures[follow.uniqueKey] ?? (follow.lastCheckFailed ? 1 : 0);
    final lastAttempt = state.lastAttempts[follow.uniqueKey];
    final failure = state.checkErrors[follow.uniqueKey];
    if (lastAttempt != null &&
        (failure == ComicFollowCheckFailure.pluginDisabled ||
            failure == ComicFollowCheckFailure.pluginMissing ||
            failure == ComicFollowCheckFailure.signInRequired ||
            failure == ComicFollowCheckFailure.notFound)) {
      return lastAttempt.add(successCheckInterval);
    }
    if (failures > 0 && lastAttempt == null) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    if (failures > 0 && lastAttempt != null) {
      final minutes = (1 << (failures - 1).clamp(0, 5).toInt())
          .clamp(1, 30)
          .toInt();
      return lastAttempt.add(Duration(minutes: minutes));
    }
    return follow.updateTime.add(successCheckInterval);
  }

  Duration get nextAutomaticCheckDelay {
    final now = _now().toUtc();
    var earliest = now.add(successCheckInterval);
    for (final item in state.items) {
      if (item.deleted) continue;
      final next = _nextCheck(item);
      if (next.isBefore(earliest)) earliest = next;
    }
    final minimum = _lastAutomaticBatchStarted?.add(automaticBatchInterval);
    if (minimum != null && minimum.isAfter(earliest)) earliest = minimum;
    final wait = earliest.difference(now);
    return wait < automaticBatchInterval ? automaticBatchInterval : wait;
  }

  /// 从数据库加载到全局内存状态
  Future<void> loadFromDatabase() async {
    _dataGeneration++;
    _pendingUpdates.clear();
    _chapterEvidence.clear();
    _deferredChecks.clear();
    if (state.items.isEmpty) {
      emit(state.copyWith(status: ComicFollowStatus.loading));
    }
    try {
      final items = _repository.listActiveFollows();
      final histories = _repository.listActiveHistories();
      _failures.clear();
      emit(
        state.copyWith(
          status: ComicFollowStatus.success,
          items: items,
          histories: histories,
          checkErrors: const {},
          lastAttempts: const {},
          revision: state.revision + 1,
        ),
      );
    } catch (e, s) {
      logger.e('加载追更列表失败', error: e, stackTrace: s);
      emit(state.copyWith(status: ComicFollowStatus.failure));
    }
  }

  String _uniqueKey(String source, String comicId) =>
      '${source.trim()}:${comicId.trim()}';

  bool isFollowing(String source, String comicId) {
    return _persistedFollow(source, comicId) != null;
  }

  ComicFollow? _persistedFollow(String source, String comicId) {
    final follow = _repository.getFollowByUniqueKey(
      _uniqueKey(source, comicId),
    );
    return follow == null || follow.deleted ? null : follow;
  }

  ComicFollow? getFollow(String source, String comicId) {
    final key = _uniqueKey(source, comicId);
    try {
      return state.items.firstWhere(
        (item) => item.uniqueKey == key && !item.deleted,
      );
    } on StateError {
      return null;
    }
  }

  void setFilter(ComicFollowFilter filter) {
    emit(state.copyWith(filter: filter));
  }

  void setSort(ComicFollowSort sort) {
    emit(state.copyWith(sort: sort));
  }

  Future<void> refreshHistories() async {
    final histories = _repository.listActiveHistories();
    var acknowledged = false;
    final items = state.items.map((item) {
      if (!state.hasUnreadUpdate(item) ||
          !_matchesLatestChapter(item, histories[item.uniqueKey])) {
        return item;
      }
      final read = _acknowledgeReadChapter(item);
      if (!identical(read, item)) acknowledged = true;
      return read;
    }).toList();
    emit(
      state.copyWith(
        histories: histories,
        items: items,
        revision: state.revision + (acknowledged ? 1 : 0),
      ),
    );
  }

  ComicFollow _acknowledgeReadChapter(ComicFollow item) {
    final stored = _repository.getFollowByUniqueKey(item.uniqueKey);
    if (stored == null || !_sameObservation(item, stored)) return item;
    final read = stored.copyWith(
      lastChapterCount: stored.detectedChapterCount,
      hasUpdate: false,
    );
    _repository.putFollow(read);
    _pendingUpdates.remove(item.uniqueKey);
    return read.copyWith(lastCheckFailed: item.lastCheckFailed);
  }

  Future<void> addOrUpdateFollow({
    required String source,
    required String comicId,
    required normal.NormalComicAllInfo info,
    int? lastChapterCount,
  }) async {
    final now = _now().toUtc();
    final key = _uniqueKey(source, comicId);
    final comicInfo = info.comicInfo;
    final detected = lastChapterCount ?? info.eps.length;
    final latest = sortChaptersByOrder(
      info.eps,
      (episode) => episode.order,
    ).lastOrNull;
    final latestChapterTitle = latest == null ? '' : latest.name;

    // 直接从数据库查询，避免仅依赖内存状态导致重复插入违反唯一约束
    final existing = _repository.getFollowByUniqueKey(key);
    ComicFollow follow;
    if (existing != null) {
      final restartedAt = existing.deleted
          ? _nextFollowEditTime(now, existing.updatedAt)
          : null;
      follow = existing.copyWith(
        source: source.trim(),
        comicId: comicId.trim(),
        title: comicInfo.title,
        description: comicInfo.description,
        cover: jsonEncode(comicInfo.cover.toJson()),
        creator: jsonEncode(comicInfo.creator.toJson()),
        titleMeta: jsonEncode(
          comicInfo.titleMeta.map((e) => e.toJson()).toList(),
        ),
        metadata: jsonEncode(
          comicInfo.metadata.map((e) => e.toJson()).toList(),
        ),
        lastChapterCount: detected,
        detectedChapterCount: detected,
        detectedChapterTitle: latestChapterTitle,
        hasUpdate: false,
        lastCheckFailed: false,
        updateTime: now,
        deleted: false,
        createdAt: restartedAt ?? existing.createdAt,
        updatedAt: restartedAt ?? now,
      );
    } else {
      follow = ComicFollow(
        uniqueKey: key,
        source: source.trim(),
        comicId: comicId.trim(),
        title: comicInfo.title,
        description: comicInfo.description,
        cover: jsonEncode(comicInfo.cover.toJson()),
        creator: jsonEncode(comicInfo.creator.toJson()),
        titleMeta: jsonEncode(
          comicInfo.titleMeta.map((e) => e.toJson()).toList(),
        ),
        metadata: jsonEncode(
          comicInfo.metadata.map((e) => e.toJson()).toList(),
        ),
        lastChapterCount: detected,
        detectedChapterCount: detected,
        detectedChapterTitle: latestChapterTitle,
        hasUpdate: false,
        lastCheckFailed: false,
        updateTime: now,
        deleted: false,
        createdAt: now,
        updatedAt: now,
        schemaVersion: 1,
      );
    }

    _repository.putFollow(follow);
    _failures.remove(follow.uniqueKey);
    _pendingUpdates.remove(follow.uniqueKey);
    _chapterEvidence.remove(follow.uniqueKey);
    _deferredChecks.remove(follow.uniqueKey);

    final newItems = List<ComicFollow>.from(state.items);
    final index = newItems.indexWhere(
      (item) => item.uniqueKey == follow.uniqueKey,
    );
    if (index >= 0) {
      newItems[index] = follow;
    } else {
      newItems.add(follow);
    }
    emit(
      state.copyWith(
        status: ComicFollowStatus.success,
        items: newItems,
        checkErrors: {...state.checkErrors}..remove(follow.uniqueKey),
        lastAttempts: {...state.lastAttempts}..remove(follow.uniqueKey),
        revision: state.revision + 1,
      ),
    );
  }

  /// 进在线详情即确认：把当前线上总数记为已确认基线并清掉红点。
  ///
  /// [onlineChapterCount]/[onlineLatestTitle] 必须来自**在线详情**
  /// （`PluginComicDetailSource.eps`），下载快照/本地记录不要传——
  /// 那是已下载数，语义不对，只增不减的守卫也救不了。
  /// 无需同步（未追更/已删除/数没变大）时返回 null。
  ComicFollow? syncFollowFromDetailAndPersist({
    required String source,
    required String comicId,
    required int onlineChapterCount,
    required String onlineLatestTitle,
  }) {
    final updated = resolveFollowSyncFromDetail(
      follow: _persistedFollow(source, comicId),
      onlineChapterCount: onlineChapterCount,
      onlineLatestTitle: onlineLatestTitle,
      now: _now().toUtc(),
    );
    if (updated == null) return null;
    _repository.putFollow(updated);
    _failures.remove(updated.uniqueKey);
    _pendingUpdates.remove(updated.uniqueKey);
    _chapterEvidence.remove(updated.uniqueKey);
    _deferredChecks.remove(updated.uniqueKey);
    final newItems = List<ComicFollow>.from(state.items);
    final index = newItems.indexWhere(
      (item) => item.uniqueKey == updated.uniqueKey,
    );
    if (index >= 0) {
      newItems[index] = updated;
    } else {
      newItems.add(updated);
    }
    emit(
      state.copyWith(
        items: newItems,
        revision: state.revision + 1,
        checkErrors: {...state.checkErrors}..remove(updated.uniqueKey),
        lastAttempts: {...state.lastAttempts}..remove(updated.uniqueKey),
      ),
    );
    return updated;
  }

  Future<void> removeFollow(String source, String comicId) async {
    final existing = _persistedFollow(source, comicId);
    if (existing == null) {
      return;
    }
    final now = _nextFollowEditTime(_now().toUtc(), existing.updatedAt);
    final removed = existing.copyWith(deleted: true, updatedAt: now);
    _repository.putFollow(removed);
    _failures.remove(removed.uniqueKey);
    _pendingUpdates.remove(removed.uniqueKey);
    _chapterEvidence.remove(removed.uniqueKey);
    _deferredChecks.remove(removed.uniqueKey);

    final newItems = state.items
        .where((item) => item.uniqueKey != removed.uniqueKey || item.deleted)
        .toList();
    emit(
      state.copyWith(
        items: newItems,
        revision: state.revision + 1,
        checkErrors: {...state.checkErrors}..remove(removed.uniqueKey),
        lastAttempts: {...state.lastAttempts}..remove(removed.uniqueKey),
      ),
    );
  }

  // ObjectBox stores these timestamps at millisecond precision. An explicit
  // removal/re-follow still has to order after the previous edit if taps share
  // a millisecond or the device clock went backwards.
  static DateTime _nextFollowEditTime(DateTime now, DateTime previous) {
    if (now.millisecondsSinceEpoch > previous.millisecondsSinceEpoch) {
      return now;
    }
    return DateTime.fromMillisecondsSinceEpoch(
      previous.millisecondsSinceEpoch + 1,
      isUtc: true,
    );
  }

  /// 全部标为已读：把每条的 lastChapterCount 对齐到 detectedChapterCount，
  /// 清掉未读徽标。不碰 detected 数据，只是确认“我看到了当前最新”。
  Future<void> markAllAsRead() async {
    final now = _now().toUtc();
    final displayed = {for (final item in state.items) item.uniqueKey: item};
    final newItems = _repository.listActiveFollows().map((item) {
      final previous = displayed[item.uniqueKey];
      final failed =
          previous != null &&
          previous.lastCheckFailed &&
          _sameObservation(previous, item);
      if (!state.hasUnreadUpdate(item)) {
        return failed ? item.copyWith(lastCheckFailed: true) : item;
      }
      final marked = item.copyWith(
        lastChapterCount: item.detectedChapterCount,
        hasUpdate: false,
        lastCheckFailed: failed,
        updatedAt: _nextFollowEditTime(now, item.updatedAt),
      );
      _repository.putFollow(marked);
      _pendingUpdates.remove(marked.uniqueKey);
      return marked;
    }).toList();
    emit(state.copyWith(items: newItems, revision: state.revision + 1));
  }

  /// Explicit refresh finishes the whole list, reusing a running automatic batch.
  Future<int> checkUpdates() async =>
      (await _checkBatch(onlyDue: false)).updateCount;

  Future<ComicFollowRefreshStatus> checkUpdatesForRefresh() async =>
      (await _checkBatch(onlyDue: false)).status;

  /// Background entry points are inert unless a foreground follow page owns a lease.
  Future<int> checkDueUpdates() async =>
      (await _checkBatch(onlyDue: true)).updateCount;

  Future<_BatchResult> _checkBatch({required bool onlyDue}) {
    const ignored = (updateCount: 0, status: ComicFollowRefreshStatus.ignored);
    if (isClosed || !_checkingActive) return Future.value(ignored);
    final generation = _activityGeneration;
    final dataGeneration = _dataGeneration;
    bool active() =>
        !isClosed &&
        _checkingActive &&
        generation == _activityGeneration &&
        dataGeneration == _dataGeneration;
    final current = _batchInFlight;
    if (current != null) {
      if (current.isCurrent()) {
        if (!onlyDue) current.includeRemaining();
        return current.result;
      }
      // Don't let an obsolete batch satisfy a fresh pull after resume/restore.
      // Wait for its current transport to settle before starting new work.
      return current.result.then(
        (_) => active() ? _checkBatch(onlyDue: onlyDue) : ignored,
      );
    }
    final now = _now().toUtc();
    if (onlyDue &&
        _lastAutomaticBatchStarted != null &&
        now.difference(_lastAutomaticBatchStarted!) < automaticBatchInterval) {
      return Future.value(ignored);
    }
    final itemCount = state.items.where((item) => !item.deleted).length;
    final candidates =
        state.items
            .where(
              (item) =>
                  !item.deleted && (!onlyDue || !_nextCheck(item).isAfter(now)),
            )
            .toList()
          ..sort((a, b) => _nextCheck(a).compareTo(_nextCheck(b)));
    final selected = onlyDue
        ? candidates.take(automaticBatchLimit).toList()
        : candidates;
    if (selected.isEmpty) return Future.value(ignored);
    if (onlyDue) _lastAutomaticBatchStarted = now;
    var completeScope = selected.length == itemCount;
    void includeRemaining() {
      if (completeScope || !active()) return;
      final scheduled = selected.map((item) => item.uniqueKey).toSet();
      selected.addAll(
        state.items.where(
          (item) => !item.deleted && !scheduled.contains(item.uniqueKey),
        ),
      );
      completeScope = true;
    }

    late final Future<_BatchResult> batch;
    final attemptsAtStart = state.lastAttempts;
    batch = Future<_BatchResult>(() async {
      var updateCount = 0;
      var changed = false, failed = false, skipped = false;
      var next = 0;
      final consecutiveSourceFailures = <String, int>{};
      try {
        do {
          while (active() && next < selected.length) {
            final row = selected[next++];
            final source = normalizePluginId(row.source);
            // Two transport/service failures are enough for one bulk pass.
            // Leave remaining rows untouched and let other plugins continue.
            // Explicit row retry always bypasses this batch guard.
            if ((consecutiveSourceFailures[source] ?? 0) >= 2 &&
                _inflight[row.uniqueKey]?.isCurrent() != true) {
              if (state.lastAttempts[row.uniqueKey] ==
                  attemptsAtStart[row.uniqueKey]) {
                _deferredChecks[row.uniqueKey] = row.createdAt;
                failed = true;
              }
              continue;
            }
            final result = await _checkSingleUpdate(row, canContinue: active);
            final failure = state.checkErrors[row.uniqueKey];
            if (result == _CheckResult.failed &&
                (failure == ComicFollowCheckFailure.network ||
                    failure == ComicFollowCheckFailure.sourceUnavailable)) {
              consecutiveSourceFailures.update(
                source,
                (n) => n + 1,
                ifAbsent: () => 1,
              );
            } else if (result != _CheckResult.skipped) {
              consecutiveSourceFailures.remove(source);
            }
            switch (result) {
              case _CheckResult.freshUpdate:
                updateCount++;
                changed = true;
              case _CheckResult.changed:
                changed = true;
              case _CheckResult.failed:
                failed = true;
              case _CheckResult.skipped:
                skipped = true;
              case _CheckResult.unchanged:
                break;
            }
          }
          if (active()) await _flushUpdateNotifications(canDeliver: active);
          // A pull can extend the list even while notifications are finishing.
        } while (active() && next < selected.length);
        final status = !active()
            ? ComicFollowRefreshStatus.ignored
            : failed
            ? (changed
                  ? ComicFollowRefreshStatus.partial
                  : ComicFollowRefreshStatus.incomplete)
            : skipped || !completeScope
            ? ComicFollowRefreshStatus.ignored
            : changed
            ? ComicFollowRefreshStatus.updated
            : ComicFollowRefreshStatus.unchanged;
        return (updateCount: updateCount, status: status);
      } finally {
        if (identical(_batchInFlight?.result, batch)) _batchInFlight = null;
        _publishChecking();
      }
    });
    _batchInFlight = (
      result: batch,
      includeRemaining: includeRemaining,
      isCurrent: active,
    );
    _publishChecking();
    return batch;
  }

  Future<bool> checkUpdateForItem(ComicFollow follow) async {
    final generation = _activityGeneration;
    bool active() =>
        !isClosed && _checkingActive && generation == _activityGeneration;
    if (!active()) return false;
    final fresh = await _checkSingleUpdate(follow, canContinue: active);
    if (active() && _batchInFlight == null) {
      await _flushUpdateNotifications(canDeliver: active);
    }
    return fresh == _CheckResult.freshUpdate;
  }

  Future<void> _flushUpdateNotifications({
    required bool Function() canDeliver,
  }) async {
    final dataGeneration = _dataGeneration;
    ComicFollowState? checkedState;
    var current = <String, ComicFollow>{};
    bool stillUnread(String key, int count) {
      if (!canDeliver() || dataGeneration != _dataGeneration) return false;
      final snapshot = state;
      if (!identical(checkedState, snapshot)) {
        checkedState = snapshot;
        current = {for (final row in snapshot.items) row.uniqueKey: row};
      }
      final row = current[key];
      return row != null &&
          !row.deleted &&
          snapshot.hasUnreadUpdate(row) &&
          row.detectedChapterCount == count &&
          !_hasReadLatestChapter(row);
    }

    final updates = <String, int>{};
    for (final entry in _pendingUpdates.entries) {
      if (stillUnread(entry.key, entry.value)) {
        updates[entry.key] = entry.value;
      }
    }
    _pendingUpdates.clear();
    if (updates.isNotEmpty) {
      await _repository.notifyUpdate(
        updates.length,
        updates: updates,
        canDeliver: stillUnread,
      );
    }
  }

  bool _hasReadLatestChapter(ComicFollow row) {
    final evidence = _chapterEvidence[row.uniqueKey];
    if (evidence == null ||
        evidence.latestIds.isEmpty ||
        evidence.total != row.detectedChapterCount) {
      return false;
    }
    final history = _repository.getActiveHistoryByUniqueKey(row.uniqueKey);
    return evidence.latestIds.contains(history?.chapterId.trim());
  }

  bool _matchesLatestChapter(ComicFollow row, UnifiedComicHistory? history) {
    final evidence = _chapterEvidence[row.uniqueKey];
    return evidence != null &&
        evidence.total == row.detectedChapterCount &&
        evidence.latestIds.contains(history?.chapterId.trim());
  }

  void _publishChecking() {
    if (isClosed) return;
    emit(
      state.copyWith(
        checkingKeys: Set.unmodifiable(_inflight.keys),
        isCheckingUpdates: _batchInFlight != null || _inflight.isNotEmpty,
      ),
    );
  }

  Future<_CheckResult> _checkSingleUpdate(
    ComicFollow requested, {
    required bool Function() canContinue,
  }) {
    final key = requested.uniqueKey;
    final shared = _inflight[key];
    if (shared != null && shared.isCurrent()) return shared.result;
    final follow = _repository.getFollowByUniqueKey(key);
    if (follow == null || follow.deleted) {
      return Future.value(_CheckResult.skipped);
    }
    final source = normalizePluginId(follow.source);
    final session = pluginSessionWriteFence.generation(source);
    final dataGeneration = _dataGeneration;
    bool ownsRequest() =>
        canContinue() &&
        dataGeneration == _dataGeneration &&
        !pluginSessionWriteFence.isChanging(source) &&
        session == pluginSessionWriteFence.generation(source);
    if (!ownsRequest()) {
      return Future.value(_CheckResult.skipped);
    }
    if (shared != null) {
      return shared.result.then(
        (_) => ownsRequest()
            ? _checkSingleUpdate(requested, canContinue: canContinue)
            : _CheckResult.skipped,
      );
    }
    late final Future<_CheckResult> work;
    work = _performCheck(follow, canContinue: ownsRequest).whenComplete(() {
      if (identical(_inflight[key]?.result, work)) _inflight.remove(key);
      _publishChecking();
    });
    _inflight[key] = (result: work, isCurrent: ownsRequest);
    _publishChecking();
    return work;
  }

  Future<_CheckResult> _performCheck(
    ComicFollow follow, {
    required bool Function() canContinue,
  }) async {
    ComicFollowDetection? detection;
    try {
      detection = await _repository.detectChapter(
        follow,
        canContinue: canContinue,
      );
    } catch (error) {
      detection = ComicFollowDetection.failed(
        classifyComicFollowCheckFailure(error).reason,
      );
    }
    if (!canContinue() || detection == null) return _CheckResult.skipped;
    // Re-read before committing: removal, re-follow, cloud reload and online
    // detail/read changes all supersede a snapshot captured before the request.
    final current = _repository.getFollowByUniqueKey(follow.uniqueKey);
    if (current == null || !_sameObservation(follow, current)) {
      return _CheckResult.skipped;
    }
    final items = [...state.items];
    final index = items.indexWhere(
      (item) => item.uniqueKey == follow.uniqueKey,
    );
    if (index < 0) return _CheckResult.skipped;
    final now = _now().toUtc();
    final detected = detection.chapterCount;
    final errors = {...state.checkErrors};
    final attempts = {...state.lastAttempts, follow.uniqueKey: now};
    var histories = state.histories;
    ComicFollow updated;
    if (detected == null) {
      _failures.update(follow.uniqueKey, (n) => n + 1, ifAbsent: () => 1);
      errors[follow.uniqueKey] =
          detection.failure ?? ComicFollowCheckFailure.unknown;
      // Keep the last successful observation and its time on an unsuccessful check.
      updated = current.copyWith(lastCheckFailed: true);
    } else {
      final history = _repository.getActiveHistoryByUniqueKey(
        current.uniqueKey,
      );
      final readId = history?.chapterId.trim() ?? '';
      final readPosition = detection.positionOf(readId);
      final latestIds = detection.latestChapterIds;
      final readThroughLatest = latestIds.contains(readId);
      final acknowledged =
          readThroughLatest && detected > current.lastChapterCount
          ? detected
          : current.lastChapterCount;
      updated = current.copyWith(
        lastChapterCount: acknowledged,
        detectedChapterCount: detected,
        detectedChapterTitle: detection.latestChapterTitle,
        hasUpdate: detected > acknowledged,
        lastCheckFailed: false,
        updateTime: now,
      );
      _repository.putFollow(updated);
      _failures.remove(follow.uniqueKey);
      errors.remove(follow.uniqueKey);
      _chapterEvidence[follow.uniqueKey] = (
        total: detected,
        latestIds: latestIds,
        hasOrderedChapters: detection.hasOrderedChapters,
        readId: readId,
        readPosition: readPosition,
      );
      histories = {...histories, follow.uniqueKey: ?history};
      if (history == null) histories.remove(follow.uniqueKey);
    }
    _deferredChecks.remove(follow.uniqueKey);
    items[index] = updated;
    emit(
      state.copyWith(
        items: items,
        histories: histories,
        checkErrors: errors,
        lastAttempts: attempts,
        revision: state.revision + 1,
      ),
    );
    if (detected == null) return _CheckResult.failed;
    if (detected > current.detectedChapterCount &&
        state.hasUnreadUpdate(updated)) {
      _pendingUpdates[updated.uniqueKey] = updated.detectedChapterCount;
      return _CheckResult.freshUpdate;
    }
    return detected != current.detectedChapterCount ||
            updated.detectedChapterTitle != current.detectedChapterTitle ||
            updated.hasUpdate != current.hasUpdate
        ? _CheckResult.changed
        : _CheckResult.unchanged;
  }

  static bool _sameObservation(ComicFollow expected, ComicFollow current) =>
      !current.deleted &&
      current.id == expected.id &&
      current.createdAt == expected.createdAt &&
      current.updatedAt == expected.updatedAt &&
      current.updateTime == expected.updateTime &&
      current.lastChapterCount == expected.lastChapterCount &&
      current.detectedChapterCount == expected.detectedChapterCount &&
      current.detectedChapterTitle == expected.detectedChapterTitle;

  @override
  Future<void> close() {
    _pendingUpdates.clear();
    _applicationManaged = true;
    _applicationForeground = false;
    _applicationCheckingOwner = null;
    _pageCheckingOwners.clear();
    _activityGeneration++;
    return super.close();
  }
}
