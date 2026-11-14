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
  final pageCount = (paging['pages'] as num?)?.toInt() ?? 0;
  return data['hasReachedMax'] == true ||
      paging['hasReachedMax'] == true ||
      (pageCount > 0 && page >= pageCount) ||
      isEmpty;
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
  final pages = (paging['pages'] as num?)?.toInt() ?? 0;
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
  const _DecodedPage(this.data, this.items);
  final Map<String, dynamic> data;
  final List<UnifiedComicListItem> items;
  int? get knownTotal => pluginListKnownTotal(data);
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
        if (state.status == PluginPagedComicListStatus.initial ||
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
      if (_cacheEnabled) {
        _collectionGeneration = boundary.generation;
        _collectionOwner = JmCollectionSnapshots.instance.accountScope(
          pluginId,
        );
        JmCollectionSnapshots.instance.clearSource(pluginId);
      }
      _resetSessionData(retry: !boundary.changing);
    });
    if (_cacheEnabled) {
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
          unawaited(_reads.cancel());
          _initialTask = null;
          _refreshTask = null;
          _refreshError = null;
          _restorePageIdentities();
          _safeEmit(event.state);
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
  bool get _cacheEnabled => privateCollection && jmSnapshotCache;
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
    _nextProbePage = 2;
    _restoredFromSnapshot = false;
    _paginationError = null;
    _initialTask = null;
    _paginationTask = null;
    _refreshTask = null;
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
    if (!_cacheEnabled || _snapshotKey == null || _snapshotGeneration == null)
      return;
    if (persist) {
      JmCollectionSnapshots.instance.write(
        _snapshotKey!,
        pluginId,
        _snapshotGeneration!,
        state,
        pageIdentities: _pageIdentities,
        cursorInvalid: false,
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
  String? _refreshError;
  Object? _paginationError;
  int _privateDataRevision = 0;
  bool _metadataActive = true;
  Map<int, List<String>> _pageIdentities = {};
  int _nextProbePage = 2;
  bool _restoredFromSnapshot = false;
  static List<String> _identities(Iterable<UnifiedComicListItem> rows) =>
      rows.map((item) => '${item.source}:${item.id}').toList();

  void _restorePageIdentities() {
    if (_snapshotKey != null) {
      final snapshots = JmCollectionSnapshots.instance;
      _pageIdentities = snapshots.pageIdentities(_snapshotKey!);
      _nextProbePage = snapshots.nextProbePage(_snapshotKey!);
      _requiresCollectionRebuild = snapshots.requiresRebuild(_snapshotKey!);
    }
  }

  void setMetadataActive(bool active) {
    if (_metadataActive == active) return;
    _metadataActive = active;
    if (active && _cacheEnabled && state.list.isNotEmpty)
      _saveSnapshot(persist: false);
  }

  bool get refreshing => _refreshTask != null;
  String? get refreshError => _refreshError;
  int get privateDataRevision => _privateDataRevision;

  @override
  Future<void> close() async {
    _requestEpoch++;
    _recovery.dispose();
    await _sessionSubscription?.cancel();
    await _identitySubscription?.cancel();
    await _snapshotSubscription?.cancel();
    await _commitSubscription?.cancel();
    await _reads.cancel();
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
    if (isClosed || automatic && !_readActive) return Future.value(false);
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
    unawaited(_reads.cancel());
    final epoch = ++_requestEpoch;
    final previous = state;
    final preserve =
        previous.status != PluginPagedComicListStatus.initial &&
        previous.status != PluginPagedComicListStatus.failure;
    final preservePaginationFailure = automatic && _requiresCollectionRebuild;
    _refreshError = null;
    if (!preservePaginationFailure) _safeEmit(previous.copyWith(result: ''));
    final task = _cacheEnabled && preserve
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

  Future<void> loadMore() async {
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
    await _appendPage();
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

  Future<void> _appendPage({bool automatic = false}) {
    final task = _fetchPage(
      page: state.page + 1,
      append: true,
      epoch: _requestEpoch,
      automatic: automatic,
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
    final readRevision = snapshots.revision(pluginId);
    final headRead = snapshots.beginHeadRead(_snapshotKey);
    final hadPaginationFailure =
        preservePaginationFailure &&
        previous.status == PluginPagedComicListStatus.loadingMoreFailure;
    try {
      final staged = <UnifiedComicListItem>[];
      final keys = <String>{};
      final pageIdentities = <int, List<String>>{};
      final head = await _readPage(1, epoch: epoch, automatic: automatic);
      final probed = <int, _DecodedPage>{1: head};
      if (_readWasSuperseded(epoch, readRevision, headRead)) return false;
      // Older snapshots did not record remote page boundaries. Rebuild their
      // loaded range once so later bounded middle-page checks are meaningful.
      final missingPageBoundaries =
          previous.page > 1 &&
          List.generate(
            previous.page,
            (i) => i + 1,
          ).any((p) => !_pageIdentities.containsKey(p));
      final headUnchanged =
          !_requiresCollectionRebuild &&
          !missingPageBoundaries &&
          head.knownTotal == previous.knownTotal &&
          head.items.length <= previous.list.length &&
          (_pageIdentities[1] == null ||
              _pageIdentities[1]!.length == head.items.length) &&
          !(_declaredEnd(head.data, 1) &&
              previous.list.length > head.items.length) &&
          (previous.page != 1 ||
              previous.hasReachedMax ==
                  (_declaredEnd(head.data, 1) ||
                      head.knownTotal != null &&
                          previous.list.length >= head.knownTotal!)) &&
          _samePublicPage(head.items, previous.list.take(head.items.length)) &&
          (head.items.isNotEmpty ||
              previous.list.isEmpty &&
                  (_declaredEnd(head.data, 1) || head.knownTotal == 0));
      if (headUnchanged) {
        // The selected sort's first page cannot prove that a middle page did
        // not change. Check one recorded page per visit, advancing through the
        // cached range, rather than rescanning every page on each entry.
        final candidates =
            _pageIdentities.keys
                .where((p) => p > 1 && p <= previous.page)
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
          probe = await _readPage(
            probePage,
            epoch: epoch,
            automatic: automatic,
          );
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
          if (hadPaginationFailure) {
            _recovery.failed(_paginationError ?? StateError(previous.result));
          } else {
            _recovery.succeeded();
          }
          _refreshError = null;
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
          return true;
        }
      }
      int? total;
      var reached = false, page = 0;
      do {
        page++;
        final decoded =
            probed[page] ??
            await _readPage(page, epoch: epoch, automatic: automatic);
        if (_readWasSuperseded(epoch, readRevision, headRead)) return false;
        pageIdentities[page] = _identities(decoded.items);
        total = decoded.knownTotal ?? total;
        final declared = _declaredEnd(decoded.data, page);
        var added = 0;
        for (final item in decoded.items) {
          if (keys.add('${item.source}:${item.id}')) {
            staged.add(item);
            added++;
          }
        }
        reached = declared || total != null && staged.length >= total;
        if (!reached && (decoded.items.isEmpty || added == 0))
          throw StateError(t.common.loadingFailed);
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
            remote,
          )) {
        _recovery.failed(StateError('网络数据尚未更新'));
        return false;
      }
      if (hadPaginationFailure && !reached) {
        _recovery.failed(_paginationError ?? StateError(previous.result));
      } else {
        _paginationError = null;
        _recovery.succeeded();
      }
      _refreshError = null;
      _requiresCollectionRebuild = false;
      _pageIdentities = pageIdentities;
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
      return true;
    } catch (error) {
      if (_readWasSuperseded(epoch, readRevision, headRead)) return false;
      if (error is _AutomaticReadPaused) {
        _recovery.invalidate();
        return false;
      }
      _recovery.failed(error);
      if (parseUnauthorizedPayload(error, fallbackPluginId: pluginId) != null) {
        _requestEpoch++;
        _privateDataRevision++;
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
        _refreshError = normalizeSearchErrorMessage(error);
        _safeEmit(
          previous.copyWith(
            status: hadPaginationFailure
                ? PluginPagedComicListStatus.loadingMoreFailure
                : PluginPagedComicListStatus.success,
            result: _refreshError!,
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
  }) async {
    if (automatic && !_readActive) throw const _AutomaticReadPaused();
    final generation = pluginSessionWriteFence.generation(pluginId);
    final resolvedFnPath = fnPath.trim();
    if (resolvedFnPath.isEmpty) throw StateError(t.common.loadingFailed);
    final pluginResponse = await (_requestPage != null
        ? _requestPage(
            pluginId,
            resolvedFnPath,
            coreBuilder(page),
            externBuilder(page),
          )
        : _reads.run(
            pluginId,
            (group) => callUnifiedComicPlugin(
              pluginId: pluginId,
              fnPath: resolvedFnPath,
              core: coreBuilder(page),
              extern: externBuilder(page),
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
    return _DecodedPage(data, nextItems);
  }

  Future<bool> _fetchPage({
    required int page,
    required bool append,
    required int epoch,
    bool preserveOnFailure = false,
    bool automatic = false,
    bool refresh = false,
  }) async {
    final snapshots = JmCollectionSnapshots.instance;
    final readRevision = snapshots.revision(pluginId);
    final headRead = append ? null : snapshots.beginHeadRead(_snapshotKey);
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
      );
      if (_readWasSuperseded(epoch, readRevision, headRead)) return false;
      final data = decoded.data, nextItems = decoded.items;
      final previousKeys = {
        for (final entry in currentList) '${entry.source}:${entry.id}',
      };
      final unique = <String>{};
      if (privateCollection &&
          append &&
          nextItems.isNotEmpty &&
          nextItems.every(
            (entry) => previousKeys.contains('${entry.source}:${entry.id}'),
          ) &&
          (!_cacheEnabled || !_declaredEnd(data, page))) {
        // A source repeating a page cannot keep a private snapshot filling
        // forever. Preserve its last good rows and offer the real retry state.
        throw StateError(t.common.loadingFailed);
      }
      final mergedList = [
        for (final entry in [if (append) ...currentList, ...nextItems])
          if (!privateCollection || unique.add('${entry.source}:${entry.id}'))
            entry,
      ];
      final total = decoded.knownTotal ?? (append ? state.knownTotal : null);
      final declaredEnd = _declaredEnd(data, page);
      if (_cacheEnabled &&
          nextItems.isEmpty &&
          !declaredEnd &&
          (total == null || mergedList.length < total))
        throw StateError(t.common.loadingFailed);
      final hasReachedMax = _cacheEnabled
          ? declaredEnd || total != null && mergedList.length >= total
          : pluginListPageHasReachedMax(
              data: data,
              page: page,
              isEmpty: nextItems.isEmpty,
            );

      final remote = state.copyWith(
        list: mergedList,
        knownTotal: total,
        page: page,
        hasReachedMax: hasReachedMax,
      );
      if (_snapshotKey != null &&
          !JmCollectionSnapshots.instance.acceptsRemoteState(
            _snapshotKey!,
            remote,
          )) {
        _recovery.failed(StateError('网络数据尚未更新'));
        return false;
      }
      _paginationError = null;
      _recovery.succeeded();
      if (!append) _requiresCollectionRebuild = false;
      _pageIdentities = {
        if (append) ..._pageIdentities,
        page: _identities(nextItems),
      };
      _safeEmit(
        state.copyWith(
          status: PluginPagedComicListStatus.success,
          list: mergedList,
          hasReachedMax: hasReachedMax,
          knownTotal: total,
          page: page,
          result: page.toString(),
        ),
      );
      _saveSnapshot(expectedRevision: readRevision, headRead: headRead);
      return true;
    } catch (e, stackTrace) {
      if (_readWasSuperseded(epoch, readRevision, headRead)) return false;
      if (e is _AutomaticReadPaused) {
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
      _recovery.failed(e);
      if (privateCollection &&
          parseUnauthorizedPayload(e, fallbackPluginId: pluginId) != null) {
        _requestEpoch++;
        if (_cacheEnabled) JmCollectionSnapshots.instance.clearSource(pluginId);
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
      if (preserveOnFailure) _refreshError = error;

      _safeEmit(
        state.copyWith(
          status: preserveOnFailure
              ? PluginPagedComicListStatus.success
              : currentList.isNotEmpty
              ? PluginPagedComicListStatus.loadingMoreFailure
              : PluginPagedComicListStatus.failure,
          list: currentList,
          result: error,
        ),
      );
      if (_cacheEnabled && currentList.isNotEmpty && !preserveOnFailure)
        _saveSnapshot();
      return false;
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
