import 'package:zephyr/page/source_shell/models/jm_account_read_cache.dart';
import 'package:zephyr/service/page_read_tasks.dart';
import 'package:zephyr/service/jm_list_like_counts.dart';
import 'package:zephyr/service/plugin_account_identity.dart';
import 'package:zephyr/service/read_recovery.dart';
import 'package:zephyr/page/comic_list/cubit/jm_collection_snapshots.dart';
import 'package:zephyr/page/comic_list/cubit/jm_collection_metadata.dart';
import 'package:zephyr/page/search_result/view/source_comic_search.dart';
import 'dart:async';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart'
    show ValueChanged, ValueListenable, ValueNotifier;
import 'package:zephyr/main.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/network/http/plugin/unified_plugin_envelope.dart';
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/page/comic_list/cubit/plugin_paged_comic_list_state.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/util/json/json_dispose.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';

typedef PluginPageCoreBuilder = Map<String, dynamic> Function(int page);
typedef PluginPageExternBuilder = Map<String, dynamic> Function(int page);
typedef PluginPageRequest =
    Future<Map<String, dynamic>> Function(
      String pluginId,
      String fnPath,
      Map<String, dynamic> core,
      Map<String, dynamic> extern,
    );

Future<Map<String, dynamic>> _requestPluginPage(
  String pluginId,
  String fnPath,
  Map<String, dynamic> core,
  Map<String, dynamic> extern, {
  bool notifyUnauthorized = true,
}) => callUnifiedComicPlugin(
  pluginId: pluginId,
  fnPath: fnPath,
  core: core,
  extern: extern,
  notifyUnauthorized: notifyUnauthorized,
);

Map<String, dynamic> _sanitizePluginItemMap(dynamic item) {
  return asJsonMap(replaceNestedNullList(asJsonMap(item)));
}

bool pluginListPageHasReachedMax({
  required Map<String, dynamic> data,
  required int page,
  required bool isEmpty,
}) {
  final paging = asJsonMap(data['paging']);
  final pageCount = intFromDynamic(paging['pages']);
  return data['hasReachedMax'] == true ||
      paging['hasReachedMax'] == true ||
      (pageCount > 0 && page >= pageCount) ||
      (isEmpty &&
          data['hasReachedMax'] != false &&
          paging['hasReachedMax'] != false &&
          pageCount <= page);
}

int? pluginListKnownTotal(Map<String, dynamic> data) {
  final raw = data['total'] ?? asJsonMap(data['paging'])['total'];
  if (raw is int && raw >= 0) return raw;
  if (raw is num && raw.isFinite && raw >= 0 && raw == raw.truncateToDouble())
    return raw.toInt();
  if (raw is String && RegExp(r'^\d{1,12}$').hasMatch(raw))
    return int.tryParse(raw);
  return null;
}

bool _declaredEnd(Map<String, dynamic> data, int page) {
  final paging = asJsonMap(data['paging']);
  final pages = intFromDynamic(paging['pages']);
  return data['hasReachedMax'] == true ||
      paging['hasReachedMax'] == true ||
      pages > 0 && page >= pages;
}

bool _samePublicPage(
  Iterable<UnifiedComicListItem> first,
  Iterable<UnifiedComicListItem> second,
) {
  final incoming = first.toList(), previous = second.toList();
  if (incoming.length != previous.length) return false;
  for (var index = 0; index < incoming.length; index++) {
    final row = incoming[index], old = previous[index];
    if (row.source != old.source || row.id != old.id) return false;
  }
  // Detail-enriched facets and signed cover URLs are not evidence that remote
  // collection membership changed. Known first-page metadata is merged below.
  return true;
}

class _DecodedPage {
  const _DecodedPage(this.data, this.items, {required this.numberedRequest});
  final Map<String, dynamic> data;
  final List<UnifiedComicListItem> items;
  final bool numberedRequest;
  int? get knownTotal => pluginListKnownTotal(data);

  int? reportedPageCount(int page) {
    if (!numberedRequest) return null;
    final paging = asJsonMap(data['paging']);
    final number = paging['page'] ?? data['page'];
    final count = int.tryParse('${paging['pages'] ?? ''}');
    if ((number != page && number != '$page') ||
        count == null ||
        count < page) {
      return null;
    }
    if ([
      paging['hasReachedMax'],
      data['hasReachedMax'],
    ].whereType<bool>().any((end) => end != (page == count))) {
      return null;
    }
    final total = knownTotal;
    if (page == 1 && count == 1 && total != null && total > items.length) {
      return null;
    }
    return count;
  }

  bool reportsPage(int page) => reportedPageCount(page) != null;
}

class _RefreshContinuation {
  _RefreshContinuation(this.revision, this.targetPage, this.pages);

  final int revision, targetPage;
  final Map<int, _DecodedPage> pages;
  final savedAt = DateTime.now();
}

class PluginPagedComicListCubit extends Cubit<PluginPagedComicListState> {
  PluginPagedComicListCubit({
    required this.pluginId,
    required this.fnPath,
    required this.coreBuilder,
    required this.externBuilder,
    PluginPageRequest? requestPage,
    PluginPageRequest? requestDetail,
    this.privateCollection = false,
    this.jmSnapshotCache = false,
    this.refreshBudget = const Duration(seconds: 22),
  }) : _requestDetail =
           requestDetail ??
           ((id, fn, core, extern) => _requestPluginPage(
             id,
             fn,
             core,
             extern,
             notifyUnauthorized: false,
           )),
       _requestPage = requestPage,
       super(const PluginPagedComicListState()) {
    _recovery = ReadRecoveryController(
      source: pluginId,
      retry: () async {
        final jump = _failedPageJump;
        if (jump != null) {
          await jumpToSourcePage(jump, automatic: true);
        } else if (state.status == PluginPagedComicListStatus.initial ||
            state.status == PluginPagedComicListStatus.failure) {
          await loadInitial(automatic: true);
        } else if (state.status ==
                PluginPagedComicListStatus.loadingMoreFailure &&
            _refreshError == null &&
            !_requiresCollectionRebuild) {
          await retryLoadMore(automatic: true);
        } else {
          await refresh(automatic: true);
        }
      },
    );
    _sessionSubscription = pluginSessionWriteFence.changes.listen((boundary) {
      if (isClosed || boundary.source != pluginId) return;
      if (privateCollection) {
        _collectionGeneration = boundary.generation;
        _collectionOwner = JmCollectionSnapshots.instance.accountScope(
          pluginId,
        );
        if (_cacheEnabled) JmCollectionSnapshots.instance.clearSource(pluginId);
      }
      _resetSessionData(retry: !boundary.changing);
    });
    if (privateCollection) {
      _collectionGeneration = pluginSessionWriteFence.generation(pluginId);
      _collectionOwner = JmCollectionSnapshots.instance.accountScope(pluginId);
      _identitySubscription = PluginAccountIdentities.changes.listen((source) {
        if (isClosed ||
            source != pluginId ||
            _collectionGeneration !=
                pluginSessionWriteFence.generation(pluginId)) {
          return;
        }
        final owner = JmCollectionSnapshots.instance.accountScope(pluginId);
        if (owner == _collectionOwner) return;
        _collectionOwner = owner;
        _resetSessionData(retry: true);
      });
    }
    if (_cacheEnabled) {
      _commitSubscription = JmCollectionSnapshots.instance.commits.listen((
        commit,
      ) {
        if (isClosed ||
            commit.source != pluginId ||
            commit.generation != pluginSessionWriteFence.generation(pluginId) ||
            commit.account !=
                JmCollectionSnapshots.instance.accountScope(pluginId))
          return;
        // A first read has no cached row and receives no per-key change event.
        // The source commit still retires its pre-write result and reopens demand.
        if (state.status == PluginPagedComicListStatus.initial ||
            state.status == PluginPagedComicListStatus.failure) {
          _requestEpoch++;
          _initialTask = null;
          unawaited(_reads.cancel());
        }
        _recovery.invalidate();
      });
      _snapshotSubscription = JmCollectionSnapshots.instance.changes.listen((
        event,
      ) {
        if (isClosed ||
            event.key != _snapshotKey ||
            _snapshotGeneration != pluginSessionWriteFence.generation(pluginId))
          return;
        if (event.mutation) {
          _requestEpoch++;
          _refreshContinuation = null;
          unawaited(_reads.cancel());
          _initialTask = null;
          _refreshTask = null;
          _refreshError = null;
          if (!_numberedBrowseWindow) {
            _restorePageIdentities();
            _safeEmit(event.state);
          } else {
            _paginationTask = null;
            _requiresCollectionRebuild = true;
            if (state.status == PluginPagedComicListStatus.loadingMore) {
              _safeEmit(
                state.copyWith(status: PluginPagedComicListStatus.success),
              );
            }
          }
          if (_requiresCollectionRebuild) {
            _recovery.invalidate();
          }
        } else {
          _safeEmit(
            state.copyWith(
              list: mergeKnownSourceComicMetadata(state.list, event.state.list),
            ),
          );
        }
      });
    }
  }

  final String pluginId;
  final String fnPath;
  final PluginPageCoreBuilder coreBuilder;
  final PluginPageExternBuilder externBuilder;
  final PluginPageRequest? _requestPage;
  final PluginPageRequest _requestDetail;
  final _reads = PageReadTasks();
  final bool privateCollection, jmSnapshotCache;
  final Duration refreshBudget;
  static final _siteHistory = JmAccountReadCache<PluginPagedComicListState>();

  bool get _siteHistoryEnabled =>
      privateCollection && fnPath == 'getSiteWatchHistory';
  String? get _siteHistoryAccount => coreBuilder(1)['accountId']?.toString();
  bool get _cacheEnabled => privateCollection && jmSnapshotCache;
  bool get _exactJmTotal =>
      pluginId == JmListLikeCounts.source &&
      (fnPath == 'getCloudFavoriteData' || fnPath == 'getSiteWatchHistory');
  int? _collectionGeneration;
  String? _collectionOwner;
  String? _snapshotKey;
  int? _snapshotGeneration;

  bool _requiresCollectionRebuild = false;

  void _resetSessionData({required bool retry}) {
    _requestEpoch++;
    _recovery.reset();
    unawaited(_reads.cancel());
    _snapshotKey = null;
    _snapshotGeneration = null;
    _requiresCollectionRebuild = false;
    _pageIdentities = {};
    _resetNumberedBrowsing();
    _nextProbePage = 2;
    _restoredFromSnapshot = false;
    _paginationError = null;
    _initialTask = null;
    _paginationTask = null;
    _refreshTask = null;
    _refreshContinuation = null;
    _refreshError = null;
    _privateDataRevision++;
    _safeEmit(const PluginPagedComicListState());
    if (retry) _recovery.invalidate();
  }

  void _bindSnapshot() {
    _snapshotGeneration = pluginSessionWriteFence.generation(pluginId);
    try {
      _snapshotKey = JmCollectionSnapshots.instance.key(
        pluginId,
        fnPath,
        coreBuilder(1),
        externBuilder(1),
      );
    } catch (_) {
      _snapshotKey = null;
    }
  }

  void _saveSnapshot({
    bool persist = true,
    int? expectedRevision,
    int? headRead,
  }) {
    if (!_cacheEnabled ||
        _snapshotKey == null ||
        _snapshotGeneration == null ||
        _numberedBrowseWindow)
      return;
    if (persist) {
      JmCollectionSnapshots.instance.write(
        _snapshotKey!,
        pluginId,
        _snapshotGeneration!,
        state,
        pageIdentities: _pageIdentities,
        officialPages: _officialSourcePages,
        officialPageCount: sourcePageCount,
        cursorInvalid: _requiresCollectionRebuild,
        nextProbePage: _nextProbePage,
        expectedRevision: expectedRevision,
        headRead: headRead,
      );
    }
    final account = JmCollectionSnapshots.instance.accountScope(pluginId);
    if (account != null) {
      final generation = _snapshotGeneration;
      JmCollectionMetadata.instance.start(
        account: account,
        generation: generation!,
        rows: state.list,
        active: () => !isClosed && _metadataActive,
        current: () =>
            generation == pluginSessionWriteFence.generation(pluginId) &&
            !pluginSessionWriteFence.isChanging(pluginId) &&
            JmCollectionSnapshots.instance.accountScope(pluginId) == account,
        read: (id) => _requestDetail(pluginId, 'getComicDetail', {
          'comicId': id,
        }, const {}),
        onBatch: (updates) => JmCollectionSnapshots.instance.applyMetadata(
          pluginId,
          account,
          updates,
        ),
      );
    }
  }

  StreamSubscription<JmCollectionSnapshotChange>? _snapshotSubscription;
  StreamSubscription<JmCollectionCommit>? _commitSubscription;
  StreamSubscription<PluginSessionBoundary>? _sessionSubscription;
  StreamSubscription<String>? _identitySubscription;
  int _requestEpoch = 0;
  final _numberedWorkPages = <String, int>{};

  int? reportedPageOf(UnifiedComicListItem entry) =>
      _numberedWorkPages['${entry.source}:${entry.id}'];
  late final ReadRecoveryController _recovery;
  bool _readActive = false;
  void setReadActive(bool active) {
    _readActive = active;
    _recovery.setActive(active);
    setMetadataActive(active);
  }

  Future<void>? _initialTask;
  Future<void>? _paginationTask;
  Future<bool>? _refreshTask;
  bool _refreshRequestedByUser = false;
  _RefreshContinuation? _refreshContinuation;
  String? _refreshError;
  Object? _paginationError;
  int _privateDataRevision = 0;
  bool _metadataActive = true;
  Map<int, List<String>> _pageIdentities = {};
  Set<int> _officialSourcePages = {};
  int _numberedRangeStart = 1;
  final _sourcePageCount = ValueNotifier<int?>(null);
  bool _numberedBrowseWindow = false;
  int? _failedPageJump;
  int? get failedPageJump => _failedPageJump;
  void _resetNumberedBrowsing() {
    _numberedRangeStart = 1;
    _numberedBrowseWindow = false;
    _failedPageJump = null;
    _sourcePageCount.value = null;
    _officialSourcePages = {};
    _numberedWorkPages.clear();
  }

  int get numberedRangeStart => _numberedRangeStart;
  int? get sourcePageCount => _sourcePageCount.value;
  ValueListenable<int?> get sourcePageCountChanges => _sourcePageCount;
  int? get firstVerifiedSourcePage =>
      sourcePageCount != null ||
          _officialSourcePages.contains(_numberedRangeStart)
      ? _numberedRangeStart
      : null;
  bool get hasVerifiedSourcePages =>
      sourcePageCount != null || _officialSourcePages.isNotEmpty;
  int _nextProbePage = 2;
  bool _restoredFromSnapshot = false;
  static List<String> _identities(Iterable<UnifiedComicListItem> rows) =>
      rows.map((item) => '${item.source}:${item.id}').toList();

  void _restorePageIdentities() {
    if (_snapshotKey != null) {
      final snapshots = JmCollectionSnapshots.instance;
      _pageIdentities = snapshots.pageIdentities(_snapshotKey!);
      _officialSourcePages = snapshots.officialPages(_snapshotKey!).toSet();
      _sourcePageCount.value = snapshots.officialPageCount(_snapshotKey!);
      _rebuildSourcePageLookup();
      _nextProbePage = snapshots.nextProbePage(_snapshotKey!);
      _requiresCollectionRebuild = snapshots.requiresRebuild(_snapshotKey!);
    }
  }

  void _rebuildSourcePageLookup() {
    _numberedWorkPages.clear();
    final seen = <String>{};
    for (final page in _pageIdentities.keys.toList()..sort()) {
      for (final id in _pageIdentities[page]!) {
        // If a duplicate was already visible on an earlier page, its first
        // occurrence owns provenance even when only a later page is certified.
        if (seen.add(id) && _officialSourcePages.contains(page)) {
          _numberedWorkPages[id] = page;
        }
      }
    }
  }

  void setMetadataActive(bool active) {
    if (_metadataActive == active) return;
    _metadataActive = active;
    if (active && _cacheEnabled && state.list.isNotEmpty)
      _saveSnapshot(persist: false);
  }

  bool get refreshing => _refreshTask != null;
  Future<void> waitForRefresh() async => await _refreshTask;
  String? get refreshError => _refreshError;
  int get privateDataRevision => _privateDataRevision;

  bool _showRetainedRefreshError(
    Object error,
    List<UnifiedComicListItem> retained,
  ) =>
      _refreshRequestedByUser ||
      retained.isEmpty ||
      !readFailureIsTransient(error);

  @override
  Future<void> close() async {
    _requestEpoch++;
    _recovery.dispose();
    await _sessionSubscription?.cancel();
    await _identitySubscription?.cancel();
    await _snapshotSubscription?.cancel();
    await _commitSubscription?.cancel();
    await _reads.cancel();
    _sourcePageCount.dispose();
    return super.close();
  }

  Future<void> loadInitial({bool automatic = false}) {
    if (isClosed || automatic && !_readActive) return Future.value();
    final pendingInitial = _initialTask;
    if (pendingInitial != null) return pendingInitial;
    final pendingRefresh = _refreshTask;
    if (pendingRefresh != null) return pendingRefresh.then((_) {});
    if (privateCollection && pluginSessionWriteFence.isChanging(pluginId)) {
      return Future<void>.value();
    }
    if (_siteHistoryEnabled &&
        state.status == PluginPagedComicListStatus.initial) {
      final saved = _siteHistory.read(pluginId, _siteHistoryAccount, fnPath);
      if (saved != null) {
        _safeEmit(saved.data);
        if (DateTime.now().difference(saved.time) >=
            const Duration(seconds: 45))
          _recovery.invalidate();
        return Future<void>.value();
      }
    }
    if (_cacheEnabled) {
      if (state.status == PluginPagedComicListStatus.success ||
          state.status == PluginPagedComicListStatus.loadingMore ||
          state.status == PluginPagedComicListStatus.loadingMoreFailure) {
        _saveSnapshot(persist: false);
        if (_snapshotKey != null &&
            !JmCollectionSnapshots.instance.isFresh(_snapshotKey!, pluginId) &&
            _readActive)
          unawaited(_checkCachedSnapshot(automatic: true));
        return Future<void>.value();
      }
      _bindSnapshot();
      if (state.status == PluginPagedComicListStatus.initial &&
          _snapshotKey != null) {
        final cached = JmCollectionSnapshots.instance.read(
          _snapshotKey!,
          pluginId,
        );
        if (cached != null) {
          _restoredFromSnapshot = true;
          _restorePageIdentities();
          _safeEmit(cached);
          if (JmCollectionSnapshots.instance.accountScope(pluginId) != null) {
            _saveSnapshot(persist: false);
            if (_readActive &&
                !JmCollectionSnapshots.instance.isFresh(
                  _snapshotKey!,
                  pluginId,
                ))
              unawaited(_checkCachedSnapshot(automatic: true));
          }
          return Future<void>.value();
        }
      }
    }
    _refreshError = null;
    final task = _cacheEnabled
        ? _restoreOrLoadInitial(++_requestEpoch, automatic: automatic)
        : _loadInitial(automatic: automatic);
    _initialTask = task;
    return task.whenComplete(() {
      if (identical(_initialTask, task)) {
        _initialTask = null;
      }
    });
  }

  Future<void> _restoreOrLoadInitial(
    int epoch, {
    bool automatic = false,
  }) async {
    final cached = _snapshotKey == null
        ? null
        : await JmCollectionSnapshots.instance.restore(_snapshotKey!, pluginId);
    if (isClosed || epoch != _requestEpoch) return;
    if (cached != null) {
      _restoredFromSnapshot = true;
      _restorePageIdentities();
      _safeEmit(cached);
      _saveSnapshot(persist: false);
      if (_readActive &&
          !JmCollectionSnapshots.instance.isFresh(_snapshotKey!, pluginId))
        unawaited(_checkCachedSnapshot(automatic: true));
      return;
    }
    await _loadInitial(automatic: automatic);
  }

  Future<bool> jumpToSourcePage(int page, {bool automatic = false}) {
    final count = sourcePageCount;
    if (isClosed ||
        automatic && !_readActive ||
        count == null ||
        page < 1 ||
        page > count ||
        pluginSessionWriteFence.isChanging(pluginId)) {
      return Future.value(false);
    }
    final epoch = ++_requestEpoch;
    _paginationTask = null;
    _refreshContinuation = null;
    if (!automatic) {
      _refreshError = null;
      _recovery.reset();
    }
    _refreshRequestedByUser = !automatic;
    _failedPageJump = null;
    unawaited(_reads.cancel());
    final task = _fetchPage(
      page: page,
      append: false,
      epoch: epoch,
      preserveOnFailure: true,
      numberedJump: true,
      automatic: automatic,
    );
    _refreshTask = task;
    return task.whenComplete(() {
      if (identical(_refreshTask, task)) _refreshTask = null;
    });
  }

  /// Call once when a cached cloud collection becomes visible again or the
  /// application resumes. It checks even warm content, coalesces in-flight work,
  /// respects failure backoff, and keeps the last good list visible.
  Future<bool> checkForUpdates({bool automatic = false}) {
    if (automatic && !_readActive) return Future.value(false);
    // Failed reads recover for every list, including uncached public sources.
    _recovery.trigger();
    if (!_cacheEnabled ||
        isClosed ||
        pluginSessionWriteFence.isChanging(pluginId))
      return Future.value(false);
    final initial = _initialTask;
    if (initial != null) {
      return initial.then((_) {
        if (isClosed ||
            !_restoredFromSnapshot ||
            pluginSessionWriteFence.isChanging(pluginId) ||
            (state.status != PluginPagedComicListStatus.success &&
                state.status != PluginPagedComicListStatus.loadingMoreFailure))
          return false;
        return _checkCachedSnapshot(automatic: automatic);
      });
    }
    if (state.status == PluginPagedComicListStatus.initial ||
        state.status == PluginPagedComicListStatus.failure)
      return Future.value(false);
    return _checkCachedSnapshot(automatic: automatic);
  }

  Future<bool> _checkCachedSnapshot({bool automatic = false}) {
    if (isClosed || automatic && (!_readActive || _failedPageJump != null)) {
      return Future.value(false);
    }
    final pagination = _paginationTask;
    if (pagination != null) {
      final generation = pluginSessionWriteFence.generation(pluginId);
      return pagination.then((_) {
        if (isClosed ||
            generation != pluginSessionWriteFence.generation(pluginId) ||
            pluginSessionWriteFence.isChanging(pluginId))
          return false;
        return _checkCachedSnapshot(automatic: automatic);
      });
    }
    final pending = _refreshTask;
    if (pending != null) return pending;
    if (_snapshotKey != null &&
        !JmCollectionSnapshots.instance.canCheck(_snapshotKey!))
      return Future.value(false);
    final epoch = ++_requestEpoch;
    final previous = state;
    _refreshRequestedByUser = !automatic;
    final task = _refreshSnapshot(
      epoch,
      previous,
      preservePaginationFailure: true,
      automatic: automatic,
    );
    _refreshTask = task;
    return task.whenComplete(() {
      if (identical(_refreshTask, task)) _refreshTask = null;
    });
  }

  Future<void> _loadInitial({bool automatic = false}) async {
    final epoch = ++_requestEpoch;
    _resetNumberedBrowsing();
    _pageIdentities = {};
    _restoredFromSnapshot = false;
    _safeEmit(
      state.copyWith(
        status: PluginPagedComicListStatus.initial,
        list: const <UnifiedComicListItem>[],
        hasReachedMax: false,
        page: 1,
        knownTotal: null,
        result: '',
      ),
    );
    await _fetchPage(
      page: 1,
      append: false,
      epoch: epoch,
      automatic: automatic,
    );
  }

  /// Re-read the current public request without discarding its last good page.
  /// No unadvertised force/cache parameter is added to a plugin's contract.
  Future<bool> refresh({bool automatic = false}) {
    if (automatic && !_readActive) return Future.value(false);
    if (privateCollection && pluginSessionWriteFence.isChanging(pluginId)) {
      return Future.value(false);
    }
    if (isClosed) {
      return Future.value(false);
    }
    final pending = _refreshTask;
    if (pending != null) {
      if (!automatic) _refreshRequestedByUser = true;
      return pending;
    }
    final initial = _initialTask;
    if (initial != null && state.status == PluginPagedComicListStatus.initial) {
      final epoch = _requestEpoch;
      return initial.then(
        (_) =>
            !isClosed &&
            epoch == _requestEpoch &&
            state.status == PluginPagedComicListStatus.success,
      );
    }
    if (!automatic) {
      _failedPageJump = null;
      _recovery.reset();
    }
    unawaited(_reads.cancel());
    final epoch = ++_requestEpoch;
    final previous = state;
    final preserve =
        previous.status != PluginPagedComicListStatus.initial &&
        previous.status != PluginPagedComicListStatus.failure;
    final preservePaginationFailure = automatic && _requiresCollectionRebuild;
    _refreshRequestedByUser = !automatic;
    if (!automatic) _refreshError = null;
    if (!preservePaginationFailure) _safeEmit(previous.copyWith(result: ''));
    final task =
        (_cacheEnabled || _exactJmTotal || _numberedBrowseWindow) && preserve
        ? _refreshSnapshot(
            epoch,
            previous,
            preservePaginationFailure: preservePaginationFailure,
            automatic: automatic,
          )
        : _fetchPage(
            page: 1,
            append: false,
            epoch: epoch,
            preserveOnFailure: preserve,
            automatic: automatic,
            refresh: !automatic,
          );
    _refreshTask = task;
    return task.whenComplete(() {
      if (identical(_refreshTask, task)) {
        _refreshTask = null;
      }
    });
  }

  Future<void> loadMore({Duration? readBudget}) async {
    if (refreshing ||
        _cacheEnabled && _refreshError != null ||
        state.hasReachedMax ||
        state.status != PluginPagedComicListStatus.success) {
      return;
    }
    if (_requiresCollectionRebuild) {
      _recovery.invalidate();
      return;
    }

    _safeEmit(state.copyWith(status: PluginPagedComicListStatus.loadingMore));
    await _appendPage(readBudget: readBudget);
  }

  Future<void> retryLoadMore({bool automatic = false}) async {
    if (automatic && !_readActive) return;
    if (refreshing ||
        state.status != PluginPagedComicListStatus.loadingMoreFailure ||
        state.hasReachedMax) {
      return;
    }
    if (_requiresCollectionRebuild) {
      if (await refresh(automatic: automatic) && !isClosed) await loadMore();
      return;
    }
    _safeEmit(state.copyWith(status: PluginPagedComicListStatus.loadingMore));
    await _appendPage(automatic: automatic);
  }

  Future<void> _appendPage({bool automatic = false, Duration? readBudget}) {
    final task = _fetchPage(
      page: state.page + 1,
      append: true,
      epoch: _requestEpoch,
      automatic: automatic,
      readBudget: readBudget,
    ).then<void>((_) {});
    _paginationTask = task;
    return task.whenComplete(() {
      if (identical(_paginationTask, task)) _paginationTask = null;
    });
  }

  bool _readWasSuperseded(int epoch, int revision, int? headRead) {
    if (isClosed || epoch != _requestEpoch) return true;
    final snapshots = JmCollectionSnapshots.instance;
    if (!_cacheEnabled ||
        (revision == snapshots.revision(pluginId) &&
            snapshots.acceptsHeadRead(_snapshotKey, headRead))) {
      return false;
    }
    // A cold query has no snapshot row to receive an observation event.
    // Reopen its visible read demand after retiring the old response.
    _recovery.invalidate();
    return true;
  }

  Future<bool> _refreshSnapshot(
    int epoch,
    PluginPagedComicListState previous, {
    bool preservePaginationFailure = false,
    bool automatic = false,
  }) async {
    final snapshots = JmCollectionSnapshots.instance;
    final historyGeneration = _siteHistoryEnabled ? _siteHistory.generation : 0;
    final readRevision = snapshots.revision(pluginId);
    final firstPage = numberedRangeStart;
    final headRead = _numberedBrowseWindow
        ? null
        : snapshots.beginHeadRead(_snapshotKey);
    final hadPaginationFailure =
        preservePaginationFailure &&
        previous.status == PluginPagedComicListStatus.loadingMoreFailure;
    final elapsed = Stopwatch()..start();
    final probed = <int, _DecodedPage>{};
    Future<_DecodedPage> readPage(int page) async {
      final remaining = refreshBudget - elapsed.elapsed;
      if (remaining <= Duration.zero) {
        throw TimeoutException(t.common.loadingFailed);
      }
      final decoded = await _readPage(
        page,
        epoch: epoch,
        automatic: automatic,
        onVerifiedPageCount: page == firstPage
            ? (count) {
                if (elapsed.elapsed < refreshBudget &&
                    !_readWasSuperseded(epoch, readRevision, headRead)) {
                  _sourcePageCount.value = count;
                }
              }
            : null,
      ).timeout(remaining);
      if (_numberedBrowseWindow &&
          (!decoded.reportsPage(page) ||
              decoded.items.any((item) => item.source != pluginId))) {
        throw const FormatException('列表分页返回不一致，请重试');
      }
      return decoded;
    }

    try {
      final staged = <UnifiedComicListItem>[];
      final keys = <String>{};
      final pageIdentities = <int, List<String>>{};
      final officialPages = <int>{};
      final head = await readPage(firstPage);
      if (_readWasSuperseded(epoch, readRevision, headRead)) return false;
      final continuation = _refreshContinuation;
      final oldHead = continuation?.pages[firstPage];
      if (continuation != null &&
          continuation.revision == readRevision &&
          continuation.targetPage == previous.page &&
          DateTime.now().difference(continuation.savedAt) <
              const Duration(minutes: 2) &&
          oldHead != null &&
          oldHead.knownTotal == head.knownTotal &&
          _declaredEnd(oldHead.data, firstPage) ==
              _declaredEnd(head.data, firstPage) &&
          _samePublicPage(oldHead.items, head.items)) {
        probed.addAll(continuation.pages);
      } else {
        _refreshContinuation = null;
      }
      probed[firstPage] = head;
      // Older snapshots did not record remote page boundaries. Rebuild their
      // loaded range once so later bounded middle-page checks are meaningful.
      final missingPageBoundaries =
          previous.page > firstPage &&
          List.generate(
            previous.page - firstPage + 1,
            (i) => i + firstPage,
          ).any((p) => !_pageIdentities.containsKey(p));
      final headUnchanged =
          !_requiresCollectionRebuild &&
          !missingPageBoundaries &&
          head.knownTotal == previous.knownTotal &&
          head.items.length <= previous.list.length &&
          (_pageIdentities[firstPage] == null ||
              _pageIdentities[firstPage]!.length == head.items.length) &&
          !(_declaredEnd(head.data, firstPage) &&
              previous.list.length > head.items.length) &&
          (previous.page != firstPage ||
              previous.hasReachedMax ==
                  (_declaredEnd(head.data, firstPage) ||
                      head.knownTotal != null &&
                          previous.list.length >= head.knownTotal!)) &&
          _samePublicPage(head.items, previous.list.take(head.items.length)) &&
          (head.items.isNotEmpty ||
              previous.list.isEmpty &&
                  (_declaredEnd(head.data, firstPage) || head.knownTotal == 0));
      if (headUnchanged) {
        // The selected sort's first page cannot prove that a middle page did
        // not change. Check one recorded page per visit, advancing through the
        // cached range, rather than rescanning every page on each entry.
        final candidates =
            _pageIdentities.keys
                .where((p) => p > firstPage && p <= previous.page)
                .toList()
              ..sort();
        final probePage = candidates.isEmpty
            ? null
            : candidates.firstWhere(
                (p) => p >= _nextProbePage,
                orElse: () => candidates.first,
              );
        _DecodedPage? probe;
        var sameProbe = true;
        if (probePage != null) {
          probe = probed[probePage] ?? await readPage(probePage);
          probed[probePage] = probe;
          if (_readWasSuperseded(epoch, readRevision, headRead)) return false;
          final ids = _identities(probe.items),
              old = _pageIdentities[probePage]!;
          sameProbe =
              ids.length == old.length &&
              List.generate(
                ids.length,
                (i) => ids[i] == old[i],
              ).every((same) => same) &&
              probe.knownTotal == head.knownTotal &&
              !(_declaredEnd(probe.data, probePage) &&
                  probePage < previous.page) &&
              (probePage != previous.page ||
                  previous.hasReachedMax ==
                      (_declaredEnd(probe.data, probePage) ||
                          probe.knownTotal != null &&
                              previous.list.length >= probe.knownTotal!));
          _nextProbePage = probePage + 1;
        }
        if (sameProbe) {
          final headCount = head.reportedPageCount(firstPage);
          final probeCount = probePage == null
              ? null
              : probe?.reportedPageCount(probePage);
          if (_officialSourcePages.isNotEmpty ||
              headCount != null ||
              probeCount != null) {
            _sourcePageCount.value = probeCount ?? headCount;
            _pageIdentities = {
              ..._pageIdentities,
              firstPage: _identities(head.items),
            };
            _officialSourcePages.remove(firstPage);
            if (head.reportsPage(firstPage))
              _officialSourcePages.add(firstPage);
            if (probePage != null && probe != null) {
              _officialSourcePages.remove(probePage);
              if (probe.reportsPage(probePage)) {
                _officialSourcePages.add(probePage);
              }
            }
            _rebuildSourcePageLookup();
          }
          if (hadPaginationFailure) {
            _recovery.failed(_paginationError ?? StateError(previous.result));
          } else {
            _recovery.succeeded();
          }
          _refreshError = null;
          _refreshContinuation = null;
          final updates = [
            ...mergeKnownSourceComicMetadata(head.items, previous.list),
            if (probe != null)
              ...mergeKnownSourceComicMetadata(probe.items, previous.list),
          ];
          final byId = {
            for (final row in updates) '${row.source}:${row.id}': row,
          };
          _safeEmit(
            previous.copyWith(
              status: hadPaginationFailure
                  ? PluginPagedComicListStatus.loadingMoreFailure
                  : PluginPagedComicListStatus.success,
              list: [
                for (final row in previous.list)
                  byId['${row.source}:${row.id}'] ?? row,
              ],
              result: hadPaginationFailure ? previous.result : '',
            ),
          );
          _saveSnapshot(expectedRevision: readRevision, headRead: headRead);
          _saveSiteHistory(historyGeneration);
          return true;
        }
      }
      int? total;
      var reached = false, page = firstPage - 1;
      do {
        page++;
        final decoded = probed[page] ?? await readPage(page);
        if (_readWasSuperseded(epoch, readRevision, headRead)) return false;
        probed[page] = decoded;
        pageIdentities[page] = _identities(decoded.items);
        if (decoded.reportsPage(page)) {
          officialPages.add(page);
        }
        final pageTotal = decoded.knownTotal;
        if (_exactJmTotal &&
            total != null &&
            pageTotal != null &&
            total != pageTotal) {
          throw const FormatException('收藏总数已变化，请刷新后继续');
        }
        total = pageTotal ?? total;
        final declared = _declaredEnd(decoded.data, page);
        var added = 0;
        for (final item in decoded.items) {
          if (keys.add('${item.source}:${item.id}')) {
            staged.add(item);
            added++;
          }
        }
        if (_exactJmTotal &&
            (added != decoded.items.length ||
                total != null &&
                    (staged.length > total ||
                        firstPage == 1 &&
                            declared &&
                            staged.length != total))) {
          throw const FormatException('收藏分页返回不完整，请重试');
        }
        reached = declared || total != null && staged.length >= total;
        if ((!reached && decoded.items.isEmpty) ||
            (decoded.items.isNotEmpty && added == 0)) {
          throw const FormatException('列表分页返回不完整，请重试');
        }
      } while (!reached && page < previous.page);
      final remote = previous.copyWith(
        list: staged,
        knownTotal: total,
        page: page,
        hasReachedMax: reached,
      );
      if (_snapshotKey != null &&
          !JmCollectionSnapshots.instance.acceptsRemoteState(
            _snapshotKey!,
            firstPage == 1 ? remote : remote.copyWith(hasReachedMax: false),
          )) {
        throw StateError('网络数据尚未更新');
      }
      if (hadPaginationFailure && !reached) {
        _recovery.failed(_paginationError ?? StateError(previous.result));
      } else {
        _paginationError = null;
        _recovery.succeeded();
      }
      _refreshError = null;
      _refreshContinuation = null;
      _requiresCollectionRebuild = false;
      _pageIdentities = pageIdentities;
      if (_officialSourcePages.isNotEmpty || officialPages.isNotEmpty) {
        _sourcePageCount.value = head.reportedPageCount(firstPage);
        _officialSourcePages = officialPages;
        _rebuildSourcePageLookup();
      }
      _safeEmit(
        previous.copyWith(
          status: hadPaginationFailure && !reached
              ? PluginPagedComicListStatus.loadingMoreFailure
              : PluginPagedComicListStatus.success,
          list: staged,
          page: page,
          knownTotal: total,
          hasReachedMax: reached,
          result: hadPaginationFailure && !reached ? previous.result : '$page',
        ),
      );
      _saveSnapshot(expectedRevision: readRevision, headRead: headRead);
      _saveSiteHistory(historyGeneration);
      return true;
    } catch (error) {
      if (_readWasSuperseded(epoch, readRevision, headRead)) return false;
      final resumable =
          error is _AutomaticReadPaused || readFailureIsTransient(error);
      if (resumable && probed.isNotEmpty) {
        _refreshContinuation = _RefreshContinuation(
          readRevision,
          previous.page,
          probed,
        );
      } else if (!resumable) {
        _refreshContinuation = null;
      }
      if (error is TimeoutException) {
        _requestEpoch++;
        unawaited(_reads.cancel());
      }
      if (error is _AutomaticReadPaused) {
        _recovery.invalidate();
        return false;
      }
      _recovery.failed(error);
      if (parseUnauthorizedPayload(error, fallbackPluginId: pluginId) != null) {
        _requestEpoch++;
        _privateDataRevision++;
        _resetNumberedBrowsing();
        _refreshError = null;
        JmCollectionSnapshots.instance.clearSource(pluginId);
        _safeEmit(
          const PluginPagedComicListState().copyWith(
            status: PluginPagedComicListStatus.failure,
            result: normalizeSearchErrorMessage(error),
          ),
        );
      } else {
        if (_snapshotKey != null)
          JmCollectionSnapshots.instance.checkFailed(_snapshotKey!);
        final showError = _showRetainedRefreshError(error, previous.list);
        if (showError) _refreshError = normalizeSearchErrorMessage(error);
        _safeEmit(
          previous.copyWith(
            status: hadPaginationFailure
                ? PluginPagedComicListStatus.loadingMoreFailure
                : PluginPagedComicListStatus.success,
            result: showError ? _refreshError! : previous.result,
          ),
        );
      }
      return false;
    }
  }

  Future<_DecodedPage> _readPage(
    int page, {
    required int epoch,
    bool automatic = false,
    bool refresh = false,
    ValueChanged<int>? onVerifiedPageCount,
  }) async {
    if (automatic && !_readActive) throw const _AutomaticReadPaused();
    final generation = pluginSessionWriteFence.generation(pluginId);
    final resolvedFnPath = fnPath.trim();
    if (resolvedFnPath.isEmpty) throw StateError(t.common.loadingFailed);
    final core = coreBuilder(page);
    final extern = externBuilder(page);
    final pluginResponse = await (_requestPage != null
        ? _requestPage(pluginId, resolvedFnPath, core, extern)
        : _reads.run(
            pluginId,
            (group) => callUnifiedComicPlugin(
              pluginId: pluginId,
              fnPath: resolvedFnPath,
              core: core,
              extern: extern,
              notifyUnauthorized: !privateCollection,
              taskGroupKey: group,
              refresh: refresh,
            ),
          ));
    if (isClosed ||
        epoch != _requestEpoch ||
        generation != pluginSessionWriteFence.generation(pluginId))
      throw const PluginSessionChanged();
    requireSuccessfulPluginEnvelope(pluginResponse);
    final envelope = UnifiedPluginEnvelope.fromMap(pluginResponse);
    final data = envelope.data;
    requireSuccessfulPluginEnvelope(data);
    final paging = asJsonMap(data['paging']);
    for (final reported in [data['page'], paging['page']]) {
      if (reported != null && reported != page && reported != '$page') {
        throw const FormatException('列表分页返回不一致，请重试');
      }
    }
    if (privateCollection &&
        fnPath == 'getSiteWatchHistory' &&
        (envelope.source != pluginId ||
            data['accountId'] != core['accountId'])) {
      throw const PluginSessionChanged();
    }
    final source = envelope.source.trim().isNotEmpty
        ? envelope.source.trim()
        : pluginId;
    final raw = asJsonMap(data['raw']);
    final rows = [
      data['items'],
      raw['content'],
      raw['list'],
    ].whereType<List>().toList();
    if (rows.isEmpty || (data.containsKey('items') && data['items'] is! List)) {
      throw const FormatException('插件列表缺少有效作品列表');
    }
    // Legacy raw lists remain supported. A genuine empty list is a valid page,
    // while a missing list or an error envelope must not erase the last page.
    final items = rows.firstWhere(
      (list) => list.isNotEmpty,
      orElse: () => rows.first,
    );
    var nextItems = items.map((item) {
      if (item is! Map) {
        throw const FormatException('插件列表包含无效作品');
      }
      return unifiedComicFromPluginListMap(
        _sanitizePluginItemMap(item),
        source: source,
      );
    }).toList();

    const cursorFields = {
      'cursor',
      'nextCursor',
      'next_cursor',
      'previousCursor',
      'previous_cursor',
      'pageToken',
      'page_token',
      'nextPageToken',
      'next_page_token',
      'continuationToken',
      'continuation_token',
      'offset',
      'nextOffset',
    };
    final numberedRequest =
        (core['page'] == page || core['page'] == '$page') &&
        source == pluginId &&
        nextItems.every((item) => item.source == pluginId) &&
        ![data, paging, extern, core].any(
          (parameters) =>
              cursorFields.any((field) => parameters[field] != null),
        );
    if (onVerifiedPageCount != null) {
      final pageCount = _DecodedPage(
        data,
        nextItems,
        numberedRequest: numberedRequest,
      ).reportedPageCount(page);
      if (pageCount != null) onVerifiedPageCount(pageCount);
    }

    if (_cacheEnabled) {
      final account = JmCollectionSnapshots.instance.accountScope(pluginId);
      if (account != null)
        nextItems = await JmCollectionMetadata.instance.hydrate(
          account,
          nextItems,
          canApply: () =>
              !isClosed &&
              epoch == _requestEpoch &&
              JmCollectionSnapshots.instance.accountScope(pluginId) == account,
        );
      if (isClosed ||
          epoch != _requestEpoch ||
          generation != pluginSessionWriteFence.generation(pluginId))
        throw const PluginSessionChanged();
    }
    if (pluginId == JmListLikeCounts.source) {
      JmListLikeCounts.instance.remember(
        readJmListLikeCounts(data['raw'], {
          for (final row in nextItems)
            if (row.source == pluginId) row.id,
        }),
        generation: generation,
      );
    }
    return _DecodedPage(data, nextItems, numberedRequest: numberedRequest);
  }

  Future<bool> _fetchPage({
    required int page,
    required bool append,
    required int epoch,
    bool preserveOnFailure = false,
    bool automatic = false,
    bool refresh = false,
    bool numberedJump = false,
    Duration? readBudget,
  }) async {
    final snapshots = JmCollectionSnapshots.instance;
    final historyGeneration = _siteHistoryEnabled ? _siteHistory.generation : 0;
    final readRevision = snapshots.revision(pluginId);
    final rangeStart = numberedJump ? page : numberedRangeStart;
    final headRead = append || numberedJump || _numberedBrowseWindow
        ? null
        : snapshots.beginHeadRead(_snapshotKey);
    final currentList = append || preserveOnFailure
        ? state.list
        : const <UnifiedComicListItem>[];
    final resolvedFnPath = fnPath.trim();

    try {
      if (resolvedFnPath.isEmpty) {
        throw StateError('插件列表请求缺少 fnPath: pluginId=$pluginId');
      }
      final decoded = await _readPage(
        page,
        epoch: epoch,
        automatic: automatic,
        refresh: refresh,
      ).timeout(readBudget ?? refreshBudget);
      if (_readWasSuperseded(epoch, readRevision, headRead)) return false;
      final data = decoded.data, nextItems = decoded.items;
      if ((numberedJump || _numberedBrowseWindow) &&
          (!decoded.reportsPage(page) ||
              nextItems.any((item) => item.source != pluginId))) {
        throw const FormatException('列表分页返回不一致，请重试');
      }
      final previousKeys = {
        for (final entry in currentList) '${entry.source}:${entry.id}',
      };
      final unique = <String>{};
      if (append &&
          nextItems.isNotEmpty &&
          nextItems.every(
            (entry) => previousKeys.contains('${entry.source}:${entry.id}'),
          )) {
        if (_exactJmTotal && _cacheEnabled) _requiresCollectionRebuild = true;
        throw const FormatException('列表分页返回重复数据，请重试');
      }
      var mergedList = [
        for (final entry in [if (append) ...currentList, ...nextItems])
          if (unique.add('${entry.source}:${entry.id}')) entry,
      ];
      final total = decoded.knownTotal ?? (append ? state.knownTotal : null);
      final declaredEnd = _declaredEnd(data, page);
      if (_exactJmTotal &&
          (mergedList.length !=
                  (append ? currentList.length : 0) + nextItems.length ||
              total != null &&
                  (mergedList.length > total ||
                      rangeStart == 1 &&
                          declaredEnd &&
                          mergedList.length != total) ||
              append &&
                  state.knownTotal != null &&
                  total != state.knownTotal)) {
        if (append && _cacheEnabled) _requiresCollectionRebuild = true;
        throw const FormatException('收藏分页返回不完整，请重试');
      }
      if (_cacheEnabled &&
          nextItems.isEmpty &&
          !declaredEnd &&
          (total == null || mergedList.length < total))
        throw StateError(t.common.loadingFailed);
      var hasReachedMax = _cacheEnabled || _exactJmTotal
          ? declaredEnd || total != null && mergedList.length >= total
          : pluginListPageHasReachedMax(
              data: data,
              page: page,
              isEmpty: nextItems.isEmpty,
            );
      var acceptedPage = page;
      final keepTail =
          !_cacheEnabled &&
          !_exactJmTotal &&
          preserveOnFailure &&
          state.page > 1 &&
          !hasReachedMax &&
          total == state.knownTotal &&
          nextItems.length == _pageIdentities[1]?.length &&
          _samePublicPage(nextItems, currentList.take(nextItems.length));
      if (keepTail) {
        mergedList = [
          ...mergeKnownSourceComicMetadata(nextItems, currentList),
          ...currentList.skip(nextItems.length),
        ];
        acceptedPage = state.page;
        hasReachedMax = state.hasReachedMax;
      }

      final remote = state.copyWith(
        list: mergedList,
        knownTotal: total,
        page: acceptedPage,
        hasReachedMax: hasReachedMax,
      );
      if (_snapshotKey != null &&
          !JmCollectionSnapshots.instance.acceptsRemoteState(
            _snapshotKey!,
            rangeStart == 1 ? remote : remote.copyWith(hasReachedMax: false),
          )) {
        throw StateError('网络数据尚未更新');
      }
      _paginationError = null;
      _recovery.succeeded();
      if (!append) {
        _requiresCollectionRebuild = false;
        _refreshError = null;
      }
      _pageIdentities = {
        if (append || keepTail) ..._pageIdentities,
        page: _identities(nextItems),
      };
      if (_officialSourcePages.isNotEmpty || decoded.reportsPage(page)) {
        _numberedBrowseWindow = _numberedBrowseWindow || numberedJump;
        _numberedRangeStart = rangeStart;
        _sourcePageCount.value = decoded.reportedPageCount(page);
        _officialSourcePages = {
          if (append || keepTail)
            ..._officialSourcePages.where((entry) => entry != page),
          if (decoded.reportsPage(page)) page,
        };
        _rebuildSourcePageLookup();
      } else if (!privateCollection) {
        if (!append && !keepTail) _numberedWorkPages.clear();
        if (keepTail)
          _numberedWorkPages.removeWhere((_, value) => value == page);
        if (data['page'] != null || asJsonMap(data['paging'])['page'] != null) {
          for (final entry in nextItems) {
            final key = '${entry.source}:${entry.id}';
            if (!append || !previousKeys.contains(key)) {
              _numberedWorkPages.putIfAbsent(key, () => page);
            }
          }
        }
      }
      _safeEmit(
        state.copyWith(
          status: PluginPagedComicListStatus.success,
          list: mergedList,
          hasReachedMax: hasReachedMax,
          knownTotal: total,
          page: acceptedPage,
          result: acceptedPage.toString(),
        ),
      );
      _saveSiteHistory(historyGeneration);
      _saveSnapshot(expectedRevision: readRevision, headRead: headRead);
      return true;
    } catch (e, stackTrace) {
      if (_readWasSuperseded(epoch, readRevision, headRead)) return false;
      if (e is TimeoutException) {
        _requestEpoch++;
        unawaited(_reads.cancel());
      }
      if (e is _AutomaticReadPaused) {
        if (numberedJump) _failedPageJump = page;
        _recovery.invalidate();
        if (append)
          _safeEmit(
            state.copyWith(
              status: PluginPagedComicListStatus.loadingMoreFailure,
            ),
          );
        return false;
      }
      if (append) _paginationError = e;
      if (numberedJump) _failedPageJump = page;
      _recovery.failed(e);
      if (privateCollection &&
          parseUnauthorizedPayload(e, fallbackPluginId: pluginId) != null) {
        _requestEpoch++;
        _resetNumberedBrowsing();
        if (_cacheEnabled) JmCollectionSnapshots.instance.clearSource(pluginId);
        if (_siteHistoryEnabled) {
          _siteHistory.remove(pluginId, _siteHistoryAccount, fnPath);
        }
        _privateDataRevision++;
        _refreshError = null;
        _safeEmit(
          state.copyWith(
            status: PluginPagedComicListStatus.failure,
            list: const [],
            knownTotal: null,
            hasReachedMax: false,
            page: 1,
            result: normalizeSearchErrorMessage(e),
          ),
        );
        return false;
      }
      logger.e(e, stackTrace: stackTrace);
      final error = normalizeSearchErrorMessage(e);
      final showError =
          !preserveOnFailure || _showRetainedRefreshError(e, currentList);
      if (preserveOnFailure && showError) _refreshError = error;

      _safeEmit(
        state.copyWith(
          status: preserveOnFailure
              ? PluginPagedComicListStatus.success
              : append
              ? PluginPagedComicListStatus.loadingMoreFailure
              : PluginPagedComicListStatus.failure,
          list: currentList,
          result: showError ? error : state.result,
        ),
      );
      if (_cacheEnabled && currentList.isNotEmpty && !preserveOnFailure)
        _saveSnapshot();
      return false;
    }
  }

  void _saveSiteHistory(int generation) {
    if (_siteHistoryEnabled &&
        !_numberedBrowseWindow &&
        state.list.length <= 120) {
      _siteHistory.write(
        pluginId,
        _siteHistoryAccount,
        fnPath,
        state,
        generation,
      );
    }
  }

  void _safeEmit(PluginPagedComicListState nextState) {
    if (isClosed) {
      return;
    }
    emit(nextState);
  }
}

class _AutomaticReadPaused implements Exception {
  const _AutomaticReadPaused();
}
