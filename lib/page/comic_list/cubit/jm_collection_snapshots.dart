import 'package:zephyr/page/comic_list/cubit/jm_collection_metadata.dart';
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/comic_list/cubit/plugin_paged_comic_list_state.dart';
import 'package:zephyr/page/search_result/view/source_comic_search.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/plugin_account_identity.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';

class _Scope {
  const _Scope(
    this.source,
    this.account,
    this.folder, {
    this.canInsert = true,
    this.unfiltered = true,
  });
  final bool canInsert, unfiltered;
  final String source, folder;
  final String? account;
}

class _Snapshot {
  _Snapshot(
    this.scope,
    this.generation,
    this.state, {
    DateTime? checkedAt,
    this.pageIdentities = const {},
    this.cursorInvalid = false,
    this.nextProbePage = 2,
  }) : checkedAt = checkedAt ?? DateTime.now();
  final _Scope scope;
  final int generation;
  final PluginPagedComicListState state;
  final DateTime checkedAt;
  final Map<int, List<String>> pageIdentities;
  final bool cursorInvalid;
  final int nextProbePage;
}

class JmCollectionSnapshotChange {
  const JmCollectionSnapshotChange(
    this.key,
    this.state, {
    this.mutation = false,
    this.observation = false,
  });
  final String key;
  final PluginPagedComicListState state;
  final bool mutation, observation;
}

/// A confirmed site write, scoped to the account that performed it.
class JmCollectionCommit {
  const JmCollectionCommit({
    required this.source,
    required this.account,
    required this.generation,
    required this.id,
    required this.favorited,
    required this.previouslyFavorited,
    this.movedToFolder,
    this.addedToFolder,
    this.removedFromFolder,
  });
  final String source, account, id;
  final int generation;
  final bool favorited, previouslyFavorited;
  final String? movedToFolder, addedToFolder, removedFromFolder;
}

class _RecentCommit {
  _RecentCommit(this.commit)
    : expires = DateTime.now().add(const Duration(seconds: 30));
  final JmCollectionCommit commit;
  final DateTime expires;
}

class _CollectionHead {
  const _CollectionHead(
    this.scope,
    this.generation, {
    this.acceptedRead,
    this.previewIds,
    this.total,
  });

  final _Scope scope;
  final int generation;
  final int? acceptedRead, total;
  final List<String>? previewIds;
}

/// Account-bound, public collection snapshots. Credentials and raw API objects
/// never enter this device-only store. Generation fences in-flight work only.
class JmCollectionSnapshots {
  JmCollectionSnapshots._() {
    pluginSessionWriteFence.changes.listen(
      (event) => clearSource(event.source),
    );
    PluginAccountIdentities.changes.listen((source) {
      if (!_heads.values.any((head) => head.scope.source == source)) return;
      final account = accountScope(source);
      _heads.removeWhere(
        (_, head) =>
            head.scope.source == source && head.scope.account != account,
      );
    });
  }
  static final instance = JmCollectionSnapshots._();
  static const prefix = 'breeze.local.jm-collections.v2.';
  final _rows = LinkedHashMap<String, _Snapshot>();
  final _scopes = <String, _Scope>{};
  final _retryAfter = <String, DateTime>{};
  final _changes = StreamController<JmCollectionSnapshotChange>.broadcast(
    sync: true,
  );
  Stream<JmCollectionSnapshotChange> get changes => _changes.stream;
  final _revisions = <String, int>{};
  final _heads = LinkedHashMap<String, _CollectionHead>();
  int _headReadSerial = 0;
  final _recentCommits = <String, _RecentCommit>{};
  final _committedOperations = LinkedHashSet<String>();
  final _commits = StreamController<JmCollectionCommit>.broadcast(sync: true);
  Stream<JmCollectionCommit> get commits => _commits.stream;
  int revision(String source) => _revisions[source] ?? 0;

  /// Only successful first-page replies advance the exact query's receipt.
  int? beginHeadRead(String? key) =>
      _scopes[key]?.account == null ? null : ++_headReadSerial;

  bool acceptsHeadRead(String? key, int? read) {
    final accepted = _heads[key]?.acceptedRead;
    return read == null || accepted == null || read >= accepted;
  }

  void _rememberHead(String key, _CollectionHead head) {
    _heads.remove(key);
    _heads[key] = head;
    while (_heads.length > 32) {
      _heads.remove(_heads.keys.first);
    }
  }

  Future<void>? _mutationTail;
  Future<void>? _diskTail;
  Future<void> _serial(Future<void> Function() action) {
    final next = (_diskTail ?? Future<void>.value())
        .catchError((Object _) {})
        .then((_) => action());
    final tail = next.then<void>((_) {}, onError: (Object _) {});
    _diskTail = tail;
    unawaited(
      tail.then((_) {
        if (identical(_diskTail, tail)) _diskTail = null;
      }),
    );
    return next.catchError((Object _) {});
  }

  String? accountScope(String source) {
    try {
      final installation = LocalPluginInstallationState.instance;
      if (installation.isRemoved(source) || installation.isInstalling(source))
        return null;
      final config = readHostPluginConfiguration(source);
      final account = config['auth.account'];
      final proof = PluginAccountIdentities.current(source);
      final uid = proof?.serverIdentity.trim() ?? '';
      if (uid.isEmpty || pluginSessionWriteFence.isChanging(source))
        return null;
      return sha256
          .convert(
            utf8.encode(
              jsonEncode([
                source,
                uid,
                account is String ? account.trim() : '',
              ]),
            ),
          )
          .toString();
    } catch (_) {
      return null;
    }
  }

  static Object? _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }

  String key(
    String source,
    String function,
    Map<String, dynamic> core,
    Map<String, dynamic> extern,
  ) {
    _revisions.putIfAbsent(source, () => 0);
    final account = accountScope(source);
    final key = sha256
        .convert(
          utf8.encode(
            jsonEncode(
              _canonical([
                source,
                account ?? pluginSessionWriteFence.generation(source),
                function.trim(),
                core,
                extern,
              ]),
            ),
          ),
        )
        .toString();
    final parameters = {...core, ...extern};
    bool onlyKnown(Set<String> keys) => parameters.entries.every(
      (entry) =>
          keys.contains(entry.key) ||
          entry.key == 'source' && entry.value == 'cloudFavorite',
    );
    const pagingKeys = {'page', 'limit', 'pageSize', 'folderId'};
    _scopes[key] = _Scope(
      source,
      account,
      (core['folderId'] ?? extern['folderId'] ?? '').toString(),
      canInsert: onlyKnown(pagingKeys),
      unfiltered: onlyKnown({...pagingKeys, 'order', 'ordering', 'sort'}),
    );
    return key;
  }

  PluginPagedComicListState? read(String key, String source) {
    final row = _rows.remove(key);
    if (row == null ||
        row.scope.source != source ||
        row.generation != pluginSessionWriteFence.generation(source) ||
        pluginSessionWriteFence.isChanging(source) ||
        row.scope.account != accountScope(source))
      return null;
    _rows[key] = row;
    return row.state;
  }

  /// A short warm return does not re-read every remote page. Explicit refresh
  /// remains available; stale snapshots are displayed while checked in back.
  bool isFresh(String key, String source) {
    final row = _rows[key];
    return row != null &&
        row.scope.source == source &&
        !row.cursorInvalid &&
        row.generation == pluginSessionWriteFence.generation(source) &&
        row.scope.account == accountScope(source) &&
        DateTime.now().difference(row.checkedAt) < const Duration(minutes: 2);
  }

  bool canCheck(String key) =>
      !(_retryAfter[key]?.isAfter(DateTime.now()) ?? false);

  void checkFailed(String key) {
    _retryAfter[key] = DateTime.now().add(const Duration(minutes: 2));
    while (_retryAfter.length > 32) _retryAfter.remove(_retryAfter.keys.first);
  }

  /// Recorded remote page boundaries, distinct from a merely partial index.
  Map<int, List<String>> pageIdentities(String key) =>
      _rows[key]?.pageIdentities ?? const {};

  bool requiresRebuild(String key) => _rows[key]?.cursorInvalid ?? false;

  int nextProbePage(String key) => _rows[key]?.nextProbePage ?? 2;

  static Map<int, List<String>> _decodePageIdentities(Object? raw) {
    if (raw is! Map || raw.length > 8000) return const {};
    final pages = <int, List<String>>{};
    var count = 0;
    for (final entry in raw.entries) {
      final page = int.tryParse(entry.key.toString());
      final ids = entry.value;
      if (page == null ||
          page < 1 ||
          ids is! List ||
          ids.any((id) => id is! String) ||
          (count += ids.length) > 8000)
        return const {};
      pages[page] = ids.cast<String>();
    }
    return pages;
  }

  Future<PluginPagedComicListState?> restore(String key, String source) async {
    final scope = _scopes[key];
    if (scope == null || scope.account == null) return null;
    final generation = pluginSessionWriteFence.generation(source);
    final readRevision = revision(source);
    await flush();
    try {
      final prefs = await SharedPreferences.getInstance();
      final text = prefs.getString('$prefix$key');
      final state = text == null ? null : _decode(text, scope);
      if (state == null ||
          accountScope(source) != scope.account ||
          generation != pluginSessionWriteFence.generation(source) ||
          readRevision != revision(source))
        return null;
      final raw = jsonDecode(text!) as Map;
      _remember(
        key,
        _Snapshot(
          scope,
          pluginSessionWriteFence.generation(source),
          state,
          pageIdentities: _decodePageIdentities(raw['pageIdentities']),
          cursorInvalid: raw['cursorInvalid'] == true,
          nextProbePage: raw['nextProbePage'] as int? ?? 2,
          checkedAt: DateTime.fromMillisecondsSinceEpoch(
            raw['savedAt'] as int? ?? 0,
          ),
        ),
      );
      return state;
    } catch (_) {
      return null;
    }
  }

  PluginPagedComicListState? _decode(String text, _Scope scope) {
    if (text.length > 4 * 1024 * 1024) return null;
    final raw = jsonDecode(text);
    if (raw is! Map ||
        raw['version'] != 1 ||
        raw['source'] != scope.source ||
        raw['account'] != scope.account ||
        raw['list'] is! List ||
        (raw['list'] as List).length > 8000 ||
        raw['page'] is! int ||
        raw['page'] < 1)
      return null;
    final rows = (raw['list'] as List)
        .map(
          (m) => UnifiedComicListItem.fromJson(
            Map<String, dynamic>.from(m as Map),
          ),
        )
        .toList();
    if (rows.any((e) => e.source != scope.source || e.id.isEmpty)) return null;
    return PluginPagedComicListState(
      list: rows,
      page: raw['page'] as int,
      hasReachedMax: raw['complete'] == true,
      knownTotal: raw['total'] is int && raw['total'] >= 0
          ? raw['total'] as int
          : null,
      status: raw['failed'] == true
          ? PluginPagedComicListStatus.loadingMoreFailure
          : PluginPagedComicListStatus.success,
    );
  }

  Map<String, dynamic> _publicRow(UnifiedComicListItem row) {
    final cover = Uri.tryParse(row.cover.url);
    final safeCover =
        cover != null &&
            const {'https', 'http'}.contains(cover.scheme) &&
            cover.userInfo.isEmpty &&
            !cover.hasQuery &&
            !cover.hasFragment
        ? row.cover.url
        : '';
    return row
        .copyWith(
          cover: row.cover.copyWith(url: safeCover, extern: const {}),
          metadata: [
            for (final m in row.metadata)
              m.copyWith(
                value: m.value.where((v) => v is String || v is num).toList(),
              ),
          ],
          raw: {
            if (row.raw['description'] is String)
              'description': row.raw['description'],
          },
          extern: const {},
        )
        .toJson();
  }

  void _remember(String key, _Snapshot row) {
    _rows.remove(key);
    _rows[key] = row;
    while (_rows.length > 8) _rows.remove(_rows.keys.first);
  }

  void write(
    String key,
    String source,
    int generation,
    PluginPagedComicListState state, {
    DateTime? checkedAt,
    Map<int, List<String>>? pageIdentities,
    bool? cursorInvalid,
    int? nextProbePage,
    int? expectedRevision,
    int? headRead,
  }) {
    if (expectedRevision != null && expectedRevision != revision(source))
      return;
    if (generation != pluginSessionWriteFence.generation(source) ||
        pluginSessionWriteFence.isChanging(source) ||
        state.list.length > 8000)
      return;
    final scope = _scopes[key] ?? _Scope(source, null, '');
    if (scope.source != source ||
        scope.account != accountScope(source) ||
        !acceptsHeadRead(key, headRead))
      return;
    if (headRead != null) {
      _rememberHead(
        key,
        _CollectionHead(scope, generation, acceptedRead: headRead),
      );
    }
    final stamp = checkedAt ?? DateTime.now();
    if (checkedAt == null) _retryAfter.remove(key);
    final previous = _rows[key];
    final identities =
        pageIdentities ??
        previous?.pageIdentities ??
        const <int, List<String>>{};
    final invalid = cursorInvalid ?? previous?.cursorInvalid ?? false;
    final probePage = nextProbePage ?? previous?.nextProbePage ?? 2;
    _remember(
      key,
      _Snapshot(
        scope,
        generation,
        state,
        checkedAt: stamp,
        pageIdentities: identities,
        cursorInvalid: invalid,
        nextProbePage: probePage,
      ),
    );
    if (scope.account == null) return;
    final text = jsonEncode({
      'version': 1,
      'source': source,
      'account': scope.account,
      'folder': scope.folder,
      'canInsert': scope.canInsert,
      'unfiltered': scope.unfiltered,
      'savedAt': stamp.millisecondsSinceEpoch,
      'pageIdentities': {
        for (final entry in identities.entries) '${entry.key}': entry.value,
      },
      'cursorInvalid': invalid,
      'nextProbePage': probePage,
      'page': state.page,
      'complete': state.hasReachedMax,
      'total': state.knownTotal,
      'failed': state.status == PluginPagedComicListStatus.loadingMoreFailure,
      'list': state.list.map(_publicRow).toList(),
    });
    if (text.length > 4 * 1024 * 1024) return;
    unawaited(
      _serial(() async {
        if (scope.account != accountScope(source) ||
            generation != pluginSessionWriteFence.generation(source))
          return;
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.setString('$prefix$key', text)) return;
        final keys = prefs
            .getKeys()
            .where((e) => e.startsWith(prefix))
            .toList();
        keys.sort((a, b) {
          int stamp(String k) {
            try {
              return (jsonDecode(prefs.getString(k)!) as Map)['savedAt'] as int;
            } catch (_) {
              return 0;
            }
          }

          return stamp(b).compareTo(stamp(a));
        });
        // Keep more request variants on disk than in memory. Switching among
        // folders and sorts must not evict the same account after eight visits.
        var bytes = 0;
        for (var index = 0; index < keys.length; index++) {
          bytes += utf8.encode(prefs.getString(keys[index]) ?? '').length;
          if (index >= 32 || bytes > 16 * 1024 * 1024)
            await prefs.remove(keys[index]);
        }
      }),
    );
  }

  void applyMetadata(
    String source,
    String account,
    Map<String, List<UnifiedComicMetadata>> updates,
  ) {
    if (accountScope(source) != account) return;
    for (final e in _rows.entries.toList()) {
      final row = e.value;
      if (row.scope.source != source || row.scope.account != account) continue;
      final list = mergeKnownSourceComicMetadata(row.state.list, [
        for (final item in row.state.list)
          if (updates[item.id] case final metadata?)
            item.copyWith(
              metadata: metadata,
              raw: {'metadata': metadata.map((m) => m.toJson()).toList()},
            ),
      ]);
      final next = row.state.copyWith(list: list);
      write(e.key, source, row.generation, next, checkedAt: row.checkedAt);
      _changes.add(JmCollectionSnapshotChange(e.key, next));
    }
  }

  /// Reject a briefly stale site read that contradicts a confirmed write.
  /// This is a bounded read fence, never a queue that replays site writes.
  bool acceptsRemoteState(String key, PluginPagedComicListState remote) {
    final scope = _scopes[key];
    if (scope == null) return true;
    _recentCommits.removeWhere(
      (_, row) => !row.expires.isAfter(DateTime.now()),
    );
    for (final recent in _recentCommits.values) {
      final commit = recent.commit;
      if (commit.source != scope.source ||
          commit.account != scope.account ||
          commit.generation != pluginSessionWriteFence.generation(scope.source))
        continue;
      final contains = remote.list.any(
        (item) => item.source == scope.source && item.id == commit.id,
      );
      final global = scope.folder.isEmpty;
      final removed =
          !commit.favorited ||
          !global &&
              (commit.removedFromFolder == scope.folder ||
                  commit.movedToFolder != null &&
                      commit.movedToFolder != scope.folder);
      final added =
          commit.favorited &&
          scope.unfiltered &&
          (global ||
              commit.movedToFolder == scope.folder ||
              commit.addedToFolder == scope.folder) &&
          commit.removedFromFolder != scope.folder;
      if (removed && contains || added && remote.hasReachedMax && !contains)
        return false;
      final local = _rows[key]?.state;
      if (global &&
          scope.unfiltered &&
          local?.knownTotal != null &&
          remote.knownTotal != null &&
          (commit.favorited
              ? remote.knownTotal! < local!.knownTotal!
              : remote.knownTotal! > local!.knownTotal!))
        return false;
    }
    return true;
  }

  /// A profile response proves only its exact first-page query. Retain loaded
  /// pages and filters; changed observations invalidate their boundaries rather
  /// than replacing an entire list with a profile preview.
  Future<PluginPagedComicListState?> observePreview({
    required String key,
    required String source,
    required int generation,
    required int expectedRevision,
    required List<UnifiedComicListItem> items,
    required int? total,
    int? headRead,
  }) async {
    final scope = _scopes[key];
    if (scope == null || scope.source != source) return null;
    final account = scope.account;
    bool current() =>
        generation == pluginSessionWriteFence.generation(source) &&
        !pluginSessionWriteFence.isChanging(source) &&
        account == accountScope(source) &&
        expectedRevision == revision(source) &&
        acceptsHeadRead(key, headRead);
    if (!current()) return null;
    final previous = read(key, source) ?? await restore(key, source);
    if (!current()) return null;
    final remote = PluginPagedComicListState(
      status: PluginPagedComicListStatus.success,
      list: items,
      knownTotal: total,
      hasReachedMax: total != null && total == items.length,
    );
    if (!acceptsRemoteState(key, remote)) return previous;

    final remembered = _heads[key];
    final observed =
        remembered?.generation == generation &&
            remembered?.scope.account == account
        ? remembered
        : null;
    final newHead = items.map((item) => '${item.source}:${item.id}').toList();
    final oldHead =
        observed?.previewIds ??
        _rows[key]?.pageIdentities[1] ??
        previous?.list
            .take(items.isEmpty ? 1 : items.length)
            .map((item) => '${item.source}:${item.id}')
            .toList();
    final oldTotal = observed?.total ?? previous?.knownTotal;
    if (account != null) {
      // A verified preview is newer evidence than the retained paged range.
      // Keep the comparison separately so a repeated observation does not
      // dirty every variant again while that range awaits its own refresh.
      _rememberHead(
        key,
        _CollectionHead(
          scope,
          generation,
          acceptedRead: headRead ?? observed?.acceptedRead,
          previewIds: newHead,
          total: total ?? oldTotal,
        ),
      );
    }
    if (previous == null) {
      write(
        key,
        source,
        generation,
        remote,
        expectedRevision: expectedRevision,
        pageIdentities: {1: newHead},
        cursorInvalid: false,
      );
    }
    final headChanged =
        oldHead != null &&
        !const ListEquality<String>().equals(oldHead, newHead);
    final countChanged =
        total != null &&
        (oldTotal != null
            ? total != oldTotal
            : previous != null &&
                  (previous.hasReachedMax
                      ? total != previous.list.length
                      : total < previous.list.length));
    if (headChanged || countChanged) {
      final observedRevision = expectedRevision + 1;
      _revisions[source] = observedRevision;
      // Other sorts/filters cannot inherit this response as fresh. All variants
      // remain readable and are checked on demand, including unmounted caches.
      await _invalidateObservedScope(
        source,
        account,
        generation,
        observedRevision,
      );
      if (generation != pluginSessionWriteFence.generation(source) ||
          pluginSessionWriteFence.isChanging(source) ||
          account != accountScope(source) ||
          observedRevision != revision(source) ||
          !acceptsHeadRead(key, headRead))
        return null;
    }
    return remote;
  }

  Future<void> _invalidateObservedScope(
    String source,
    String? account,
    int generation,
    int observedRevision,
  ) async {
    await flush();
    if (generation != pluginSessionWriteFence.generation(source) ||
        account != accountScope(source) ||
        observedRevision != revision(source))
      return;
    final prefs = await SharedPreferences.getInstance();
    final variants = Map<String, _Snapshot>.from(_rows);
    for (final storageKey in prefs.getKeys().where(
      (key) => key.startsWith(prefix),
    )) {
      try {
        final text = prefs.getString(storageKey)!;
        final raw = jsonDecode(text) as Map;
        if (raw['source'] != source || raw['account'] != account) continue;
        final key = storageKey.substring(prefix.length);
        final scope =
            _scopes[key] ??
            _Scope(
              source,
              account,
              raw['folder']?.toString() ?? '',
              canInsert: raw['canInsert'] == true,
              unfiltered: raw['unfiltered'] == true || raw['canInsert'] == true,
            );
        _scopes[key] = scope;
        final state = _decode(text, scope);
        if (state != null)
          variants.putIfAbsent(
            key,
            () => _Snapshot(
              scope,
              generation,
              state,
              pageIdentities: _decodePageIdentities(raw['pageIdentities']),
              nextProbePage: raw['nextProbePage'] as int? ?? 2,
            ),
          );
      } catch (_) {}
    }
    if (generation != pluginSessionWriteFence.generation(source) ||
        account != accountScope(source) ||
        observedRevision != revision(source))
      return;
    for (final entry in variants.entries) {
      final row = entry.value;
      if (row.scope.source != source || row.scope.account != account) continue;
      _retryAfter.remove(entry.key);
      write(
        entry.key,
        source,
        generation,
        row.state,
        checkedAt: DateTime.fromMillisecondsSinceEpoch(0),
        cursorInvalid: true,
        pageIdentities: row.pageIdentities,
        nextProbePage: row.nextProbePage,
      );
      _changes.add(
        JmCollectionSnapshotChange(
          entry.key,
          row.state,
          mutation: true,
          observation: true,
        ),
      );
    }
    await flush();
  }

  Future<void> mutate({
    required String source,
    required String account,
    required int generation,
    required String id,
    required bool favorited,
    required bool previouslyFavorited,
    UnifiedComicListItem? item,
    String? movedToFolder,
    String? addedToFolder,
    String? removedFromFolder,
    String? operationId,
  }) {
    if (accountScope(source) != account ||
        generation != pluginSessionWriteFence.generation(source) ||
        pluginSessionWriteFence.isChanging(source))
      return Future.value();
    if (operationId != null) {
      final identity = '$source:$account:$generation:$id:$operationId';
      if (!_committedOperations.add(identity))
        return _mutationTail ?? Future.value();
      while (_committedOperations.length > 128)
        _committedOperations.remove(_committedOperations.first);
    }
    _heads.removeWhere((_, head) => head.scope.source == source);
    _revisions[source] = revision(source) + 1;
    final commit = JmCollectionCommit(
      source: source,
      account: account,
      generation: generation,
      id: id,
      favorited: favorited,
      previouslyFavorited: previouslyFavorited,
      movedToFolder: movedToFolder,
      addedToFolder: addedToFolder,
      removedFromFolder: removedFromFolder,
    );
    _recentCommits['$source:$id'] = _RecentCommit(commit);
    while (_recentCommits.length > 128)
      _recentCommits.remove(_recentCommits.keys.first);
    final task = (_mutationTail ?? Future<void>.value())
        .catchError((Object _) {})
        .then((_) => _applyCommit(commit, item));
    final tail = task.then<void>((_) {}, onError: (Object _) {});
    _mutationTail = tail;
    unawaited(
      tail.then((_) {
        if (identical(_mutationTail, tail)) _mutationTail = null;
      }),
    );
    return task;
  }

  Future<void> _applyCommit(
    JmCollectionCommit commit,
    UnifiedComicListItem? item,
  ) async {
    final source = commit.source, account = commit.account, id = commit.id;
    final generation = commit.generation;
    final favorited = commit.favorited,
        previouslyFavorited = commit.previouslyFavorited;
    final movedToFolder = commit.movedToFolder,
        addedToFolder = commit.addedToFolder,
        removedFromFolder = commit.removedFromFolder;
    await flush();
    final prefs = await SharedPreferences.getInstance();
    if (accountScope(source) != account ||
        generation != pluginSessionWriteFence.generation(source))
      return;
    // Stage all disk variants separately from the eight resident snapshots;
    // otherwise hydrating them into the LRU drops older variants before patching.
    final snapshots = Map<String, _Snapshot>.from(_rows);
    // Include unmounted folder snapshots; mutations must survive app restart.
    for (final storageKey in prefs.getKeys().where(
      (e) => e.startsWith(prefix),
    )) {
      try {
        final text = prefs.getString(storageKey)!;
        final raw = jsonDecode(text) as Map;
        if (raw['source'] != source || raw['account'] != account) continue;
        final key = storageKey.substring(prefix.length);
        final scope = _Scope(
          source,
          account,
          raw['folder']?.toString() ?? '',
          canInsert: raw['canInsert'] == true,
          unfiltered: raw['unfiltered'] == true || raw['canInsert'] == true,
        );
        _scopes[key] = scope;
        final state = _decode(text, scope);
        if (state != null && !snapshots.containsKey(key))
          snapshots[key] = _Snapshot(
            scope,
            generation,
            state,
            pageIdentities: _decodePageIdentities(raw['pageIdentities']),
            cursorInvalid: raw['cursorInvalid'] == true,
            nextProbePage: raw['nextProbePage'] as int? ?? 2,
            checkedAt: DateTime.fromMillisecondsSinceEpoch(
              raw['savedAt'] as int? ?? 0,
            ),
          );
      } catch (_) {}
    }
    for (final e in snapshots.entries) {
      final row = e.value;
      if (row.scope.source != source || row.scope.account != account) continue;
      final list = [...row.state.list];
      final oldIndex = list.indexWhere((e) => e.id == id && e.source == source);
      final global = row.scope.folder.isEmpty;
      final belongs =
          favorited &&
          (global ||
              movedToFolder == row.scope.folder ||
              addedToFolder == row.scope.folder) &&
          removedFromFolder != row.scope.folder;
      final shouldRemove =
          !favorited ||
          removedFromFolder != null &&
              !global &&
              removedFromFolder == row.scope.folder ||
          movedToFolder != null && !global && movedToFolder != row.scope.folder;
      var delta = 0;
      if (shouldRemove && oldIndex >= 0) {
        list.removeAt(oldIndex);
        delta = -1;
      }
      if (belongs &&
          row.scope.canInsert &&
          oldIndex < 0 &&
          item != null &&
          item.source == source &&
          item.id == id) {
        list.insert(0, item);
        delta = 1;
      }
      if (!global &&
          belongs &&
          row.scope.unfiltered &&
          oldIndex < 0 &&
          row.state.hasReachedMax)
        delta = 1;
      if (global && row.scope.unfiltered)
        delta = favorited == previouslyFavorited ? 0 : (favorited ? 1 : -1);
      final uncertainMembership =
          !row.scope.unfiltered && favorited && oldIndex < 0 ||
          belongs && !global && oldIndex < 0 && !row.state.hasReachedMax ||
          shouldRemove &&
              oldIndex < 0 &&
              !row.state.hasReachedMax &&
              (!global || !row.scope.unfiltered);
      final unknownFolder =
          favorited &&
          !global &&
          movedToFolder == null &&
          addedToFolder == null &&
          removedFromFolder != row.scope.folder;
      final total =
          uncertainMembership || unknownFolder || row.state.knownTotal == null
          ? null
          : (row.state.knownTotal! + delta).clamp(0, 1 << 31).toInt();
      final missingAddedRow =
          belongs &&
          oldIndex < 0 &&
          (!row.scope.canInsert ||
              item == null ||
              item.source != source ||
              item.id != id);
      var next = row.state.copyWith(
        list: list,
        knownTotal: total,
        status: PluginPagedComicListStatus.success,
        hasReachedMax:
            row.state.hasReachedMax && !missingAddedRow && !unknownFolder,
      );
      // A partial page cursor shifts after any membership change, even when
      // the changed row can be patched immediately. Complete indexes remain
      // locally usable; their page boundaries are rebuilt from fixed-size pages.
      final membershipChanged = oldIndex >= 0 && shouldRemove || delta != 0;
      final invalid =
          row.cursorInvalid ||
          missingAddedRow ||
          unknownFolder ||
          membershipChanged && !row.state.hasReachedMax;
      var identities = row.pageIdentities;
      if (membershipChanged && row.state.hasReachedMax && !invalid) {
        final size = identities[1]?.length ?? 0;
        final fixed =
            size > 0 &&
            identities.entries.every(
              (e) => e.key == row.state.page || e.value.length == size,
            );
        identities = fixed
            ? {
                for (var p = 1; (p - 1) * size < list.length; p++)
                  p: list
                      .skip((p - 1) * size)
                      .take(size)
                      .map((item) => '${item.source}:${item.id}')
                      .toList(),
              }
            : const {};
        if (fixed)
          next = next.copyWith(
            page: identities.isEmpty ? 1 : identities.length,
          );
      }
      // A confirmed commit opens a new read opportunity even after an older
      // network failure; it must not inherit that failure's retry cooldown.
      _retryAfter.remove(e.key);
      write(
        e.key,
        source,
        generation,
        next,
        pageIdentities: identities,
        cursorInvalid: invalid,
        nextProbePage: row.nextProbePage,
        checkedAt: invalid
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : row.checkedAt,
      );
      _changes.add(JmCollectionSnapshotChange(e.key, next, mutation: true));
    }
    await flush();
    if (accountScope(source) == account &&
        generation == pluginSessionWriteFence.generation(source))
      _commits.add(commit);
  }

  Future<void> clearDisk({String? source}) async {
    final accounts = <String>{
      for (final row in _rows.values)
        if ((source == null || row.scope.source == source) &&
            row.scope.account != null)
          row.scope.account!,
    };
    if (source == null)
      clear();
    else
      clearSource(source);
    await flush();
    final prefs = await SharedPreferences.getInstance();
    for (final key
        in prefs.getKeys().where((key) => key.startsWith(prefix)).toList()) {
      try {
        final raw = jsonDecode(prefs.getString(key)!) as Map;
        if (source != null && raw['source'] != source) continue;
        if (raw['account'] is String) accounts.add(raw['account'] as String);
      } catch (_) {
        if (source != null) continue;
      }
      await prefs.remove(key);
    }
    await JmCollectionMetadata.instance.clearDisk(
      source: source,
      accounts: accounts,
    );
  }

  Future<void> flush() async {
    await _diskTail;
  }

  void clearSource(String source) {
    _rows.removeWhere((_, row) => row.scope.source == source);
    _heads.removeWhere((_, head) => head.scope.source == source);
    _retryAfter.removeWhere((key, _) => _scopes[key]?.source == source);
    _recentCommits.removeWhere((_, row) => row.commit.source == source);
    _committedOperations.removeWhere((key) => key.startsWith('$source:'));
    _revisions[source] = revision(source) + 1;
  }

  void clear() {
    _rows.clear();
    _heads.clear();
    _scopes.clear();
    _retryAfter.clear();
    _recentCommits.clear();
    _committedOperations.clear();
    // Do not reset revisions: an in-flight old read may still complete.
    for (final source in _revisions.keys.toList())
      _revisions[source] = revision(source) + 1;
  }
}
