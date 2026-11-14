import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:worker_manager/worker_manager.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';
import 'package:zephyr/page/search_result/bloc/search_bloc.dart';
import 'package:zephyr/page/search_result/method/get_plugin_result.dart';
import 'package:zephyr/page/search_result/models/bloc_state.dart';
import 'package:zephyr/page/search_result/models/unified_plugin_search.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'dart:async';
import 'dart:io';
import 'package:zephyr/service/read_recovery.dart';
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/service/download/download_cancel_signal.dart';
import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart';
import 'package:zephyr/network/source_network_policy.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/page/search_aggregate/aggregate_video_search.dart';
import 'package:zephyr/page/search_aggregate/aggregate_search_matching.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/method/copy_search_topic.dart';
import 'package:zephyr/page/search_result/view/source_list_categories.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/util/rust_loader.dart';
import 'package:zephyr/util/text/chinese_convert.dart';

enum AggregateSearchStatus { initial, loading, success, failure }

typedef AggregateCategoryPreview = ({
  String category,
  CopySearchTopic? topic,
  List<UnifiedComicListItem> items,
});

class AggregateComicPage {
  const AggregateComicPage(this.items, {this.paging, this.extern = const {}});

  final List<UnifiedComicListItem> items;
  final UnifiedPluginSearchPaging? paging;
  final Map<String, dynamic> extern;
}

const aggregateSearchPreviewLimit = 30;
const _maxPreviewRequests = 4;

class AggregateSearchState {
  const AggregateSearchState({
    this.status = AggregateSearchStatus.initial,
    this.results = const <String, List<dynamic>>{},
    this.errors = const <String, String>{},
    this.selectedSources = const <String, bool>{},
    this.refreshingSources = const <String>{},
    this.showHasResults = true,
    this.showErrors = false,
    this.notices = const {},
    this.pendingSources = const {},
    this.filteredCounts = const {},
    this.categoryPreviews = const {},
  });

  final AggregateSearchStatus status;
  final Map<String, List<dynamic>> results;
  final Map<String, String> errors;
  final Map<String, AggregateSourceNotice> notices;
  final Map<String, bool> selectedSources;
  final Set<String> refreshingSources;
  final Set<String> pendingSources;
  final Map<String, int> filteredCounts;
  final Map<String, AggregateCategoryPreview> categoryPreviews;
  final bool showHasResults;
  final bool showErrors;

  AggregateSearchState copyWith({
    AggregateSearchStatus? status,
    Map<String, List<dynamic>>? results,
    Map<String, String>? errors,
    Map<String, AggregateSourceNotice>? notices,
    Map<String, bool>? selectedSources,
    Set<String>? refreshingSources,
    Set<String>? pendingSources,
    Map<String, int>? filteredCounts,
    Map<String, AggregateCategoryPreview>? categoryPreviews,
    bool? showHasResults,
    bool? showErrors,
  }) {
    return AggregateSearchState(
      pendingSources: pendingSources ?? this.pendingSources,
      filteredCounts: filteredCounts ?? this.filteredCounts,
      categoryPreviews: categoryPreviews ?? this.categoryPreviews,
      status: status ?? this.status,
      results: results ?? this.results,
      errors: errors ?? this.errors,
      notices: notices ?? this.notices,
      selectedSources: selectedSources ?? this.selectedSources,
      refreshingSources: refreshingSources ?? this.refreshingSources,
      showHasResults: showHasResults ?? this.showHasResults,
      showErrors: showErrors ?? this.showErrors,
    );
  }
}

class _AggregateCancelled implements Exception {}

class _AggregateJob {
  _AggregateJob(this.source, this.group, this.generation);
  final String source, group;
  final int generation;
  final done = Completer<void>();
  final cancelledSignal = Completer<void>();
  bool started = false, cancelled = false, expired = false;
  bool previewPublished = false;
}

class AggregateSearchCubit extends Cubit<AggregateSearchState> {
  AggregateSearchCubit(
    SearchEvent baseEvent, {
    Map<String, bool> initialSelectedSources = const {},
    AggregateVideoSearch? videoSearch,
    this.sourceSearch,
    this.comicSearch = _readAggregateComics,
    this.copyTopicLookup = resolveCopySearchTopic,
    Set<String>? availableSources,
    Map<String, Object> sourceDefinitions = const {},
  }) : _baseEvent = baseEvent,
       _videoSearch = videoSearch ?? AggregateVideoSearch(),
       _available = availableSources,
       super(AggregateSearchState(selectedSources: initialSelectedSources)) {
    _sourceDefinitions.addAll(sourceDefinitions);
    _instances.add(this);
    _recovery = ReadRecoveryController(
      source: 'aggregate-search',
      retry: retryFailedSources,
      notBefore: _nextRetryTime,
    );
    _session = pluginSessionWriteFence.changes.listen((boundary) {
      if (!(state.selectedSources[boundary.source] ?? false)) return;
      _retireSource(boundary.source, clear: true);
      if (!boundary.changing && _active) unawaited(_enqueue(boundary.source));
    });
    _networkChanges = SourceNetworkPolicies.changes.listen(_networkChanged);
  }
  SearchEvent _baseEvent;
  SearchEvent get baseEvent => _baseEvent;
  final AggregateVideoSearch _videoSearch;
  final Future<List<dynamic>> Function(String, SearchEvent)? sourceSearch;
  final Future<AggregateComicPage> Function(SearchEvent, String) comicSearch;
  final Future<CopySearchTopic?> Function(String, {String? taskGroupKey})
  copyTopicLookup;
  late final ReadRecoveryController _recovery;
  late final StreamSubscription<PluginSessionBoundary> _session;
  late final StreamSubscription<String> _networkChanges;
  Set<String>? _available;
  final _jobs = <String, _AggregateJob>{};
  final _queue = <_AggregateJob>[];
  final _retryAt = <String, DateTime>{};
  final _sourceDefinitions = <String, Object>{};
  static int _sequence = 0;
  static int _running = 0;
  static final _instances = <AggregateSearchCubit>{};
  bool _active = true;
  bool _eligible(String id) =>
      !isClosed &&
      (state.selectedSources[id] ?? false) &&
      (_available == null || _available!.contains(id)) &&
      !pluginSessionWriteFence.isChanging(id);
  bool _current(_AggregateJob job) =>
      !job.cancelled &&
      !job.expired &&
      _eligible(job.source) &&
      identical(_jobs[job.source], job) &&
      pluginSessionWriteFence.generation(job.source) == job.generation;

  Future<void> search() => Future.wait([
    for (final e in state.selectedSources.entries)
      if (e.value && _eligible(e.key)) _enqueue(e.key),
  ]).then((_) {});

  Future<void> applyKeywordScope(KeywordSearchScope scope) async {
    final searchState = baseEvent.searchStates;
    if (keywordSearchScope(searchState.pluginExtern) == scope) return;
    _baseEvent = baseEvent.copyWith(
      searchStates: searchState.copyWith(
        pluginExtern: changeKeywordSearchScope(searchState.pluginExtern, scope),
      ),
    );
    for (final id in _jobs.keys.toList()) {
      _retireSource(id);
    }
    _retryAt.clear();
    _emit(
      state.copyWith(
        results: const {},
        errors: const {},
        notices: const {},
        filteredCounts: const {},
        categoryPreviews: const {},
      ),
    );
    await search();
  }

  Future<void> _enqueue(String source) {
    if (!_eligible(source)) return Future.value();
    if (_retryAt[source]?.isAfter(DateTime.now()) == true)
      return Future.value();
    final existing = _jobs[source];
    if (existing != null && !existing.cancelled) return existing.done.future;
    final job = _AggregateJob(
      source,
      'aggregate-${++_sequence}',
      pluginSessionWriteFence.generation(source),
    );
    _jobs[source] = job;
    _queue.add(job);
    _publishPending();
    _drain();
    return job.done.future;
  }

  void _publishPending() {
    if (isClosed) return;
    final pending = _jobs.entries
        .where((e) => _current(e.value))
        .map((e) => e.key)
        .toSet();
    _emit(
      state.copyWith(
        pendingSources: pending,
        status: pending.isEmpty
            ? AggregateSearchStatus.success
            : AggregateSearchStatus.loading,
      ),
    );
  }

  void _drain() {
    while (!isClosed && _active && _running < 3 && _queue.isNotEmpty) {
      final job = _queue.removeAt(0);
      if (!_current(job)) {
        _finish(job);
        continue;
      }
      job.started = true;
      _running++;
      unawaited(_run(job));
    }
  }

  Future<void> _run(_AggregateJob job) async {
    Future<void>? work;
    try {
      work = sourceSearch != null
          ? sourceSearch!(job.source, baseEvent).then((items) {
              _commitPreview(
                job,
                items.take(aggregateSearchPreviewLimit).toList(),
                0,
              );
            })
          : _searchSingleSource(job.source, baseEvent, job: job);
      await (sourceSearch != null
              ? work
              : Future.any<void>([
                  work,
                  job.cancelledSignal.future.then<void>(
                    (_) => throw _AggregateCancelled(),
                  ),
                ]))
          .timeout(const Duration(seconds: 40));
      if (_current(job)) _retryAt.remove(job.source);
    } on AggregateSourceEntryRequired catch (entry) {
      if (_current(job))
        _emit(
          state.copyWith(
            notices: {...state.notices, job.source: entry.notice},
            errors: {...state.errors}..remove(job.source),
          ),
        );
    } catch (error) {
      if (_current(job)) {
        final failure = aggregateSearchFailure(error);
        if (failure == 'rateLimited') {
          _retryAt[job.source] = DateTime.now().add(readRetryAfterDelay(error));
        }
        if (!job.previewPublished) {
          _emit(
            state.copyWith(
              errors: {...state.errors, job.source: failure},
              notices: {...state.notices}..remove(job.source),
            ),
          );
        }
      }
      if (error is TimeoutException) {
        job.expired = true;
        if (sourceSearch == null) {
          await _cancelNative(job).catchError((Object _) {});
        }
      }
    } finally {
      // Admission follows physical completion, not merely timeout/UI retirement.
      if (work != null) await work.then<void>((_) {}, onError: (Object _) {});
      releaseQjsTaskGroupNetwork(job.source, job.group);
      clearDownloadCancelSignal(job.group);
      _running--;
      _finish(job);
      for (final owner in _instances.toList()) {
        owner._drain();
      }
      _updateRecovery();
    }
  }

  void _commitPreview(
    _AggregateJob job,
    List<dynamic> results,
    int filteredCount, {
    AggregateCategoryPreview? category,
  }) {
    if (!_current(job)) return;
    job.previewPublished = results.isNotEmpty || category != null;
    _emit(
      state.copyWith(
        results: {...state.results, job.source: results},
        errors: {...state.errors}..remove(job.source),
        notices: {...state.notices}..remove(job.source),
        filteredCounts: {...state.filteredCounts, job.source: filteredCount},
        categoryPreviews: {
          ...state.categoryPreviews,
          if (category != null) job.source: category,
        }..removeWhere((source, _) => source == job.source && category == null),
      ),
    );
  }

  Future<void> _cancelNative(_AggregateJob job) async {
    triggerDownloadCancelSignal(job.group);
    try {
      await cancelTrackedQjsTasks(
        pluginId: job.source,
        taskGroupKey: job.group,
      );
    } finally {
      if (!job.cancelledSignal.isCompleted) job.cancelledSignal.complete();
    }
  }

  void _finish(_AggregateJob job) {
    if (identical(_jobs[job.source], job)) _jobs.remove(job.source);
    if (!job.done.isCompleted) job.done.complete();
    _publishPending();
  }

  void _retireSource(String source, {bool clear = false}) {
    final job = _jobs.remove(source);
    if (job != null) {
      job.cancelled = true;
      if (!job.done.isCompleted) job.done.complete();
      if (!job.started) {
        _queue.remove(job);
        _finish(job);
      } else if (sourceSearch == null)
        unawaited(_cancelNative(job).catchError((Object _) {}));
    }
    if (clear) _retryAt.remove(source);
    if (clear)
      _emit(
        state.copyWith(
          results: {...state.results}..remove(source),
          errors: {...state.errors}..remove(source),
          notices: {...state.notices}..remove(source),
          filteredCounts: {...state.filteredCounts}..remove(source),
          categoryPreviews: {...state.categoryPreviews}..remove(source),
        ),
      );
    _publishPending();
  }

  Future<void> toggleSource(String source, bool enabled) =>
      applySelectedSources({...state.selectedSources, source: enabled});
  Future<void> applySelectedSources(Map<String, bool> selected) async {
    final previous = state.selectedSources;
    _emit(state.copyWith(selectedSources: Map<String, bool>.from(selected)));
    for (final id in previous.keys)
      if (!(selected[id] ?? false)) _retireSource(id, clear: true);
    await Future.wait([
      for (final e in selected.entries)
        if (e.value && !(previous[e.key] ?? false)) _enqueue(e.key),
    ]);
    _updateRecovery();
  }

  void updateAvailableSources(Set<String> available) {
    _available = Set.of(available);
    _emit(
      state.copyWith(
        selectedSources: {
          ...state.selectedSources,
          for (final id in available)
            if (!state.selectedSources.containsKey(id)) id: false,
        },
      ),
    );
    for (final id in state.selectedSources.keys) {
      if (!available.contains(id)) _retireSource(id, clear: true);
    }
  }

  // Installation publishes only after its runtime is settled. The earlier
  // session boundary alone cannot prove that the replacement is ready.
  void updateSourceDefinitions(Map<String, Object> definitions) {
    for (final entry in definitions.entries) {
      final previous = _sourceDefinitions[entry.key];
      if (previous != null && previous != entry.value) {
        _retireSource(entry.key, clear: true);
        if (_active) unawaited(_enqueue(entry.key));
      }
    }
    _sourceDefinitions
      ..clear()
      ..addAll(definitions);
  }

  Future<void> refreshSource(String id) async {
    if (!_eligible(id)) return;
    _emit(state.copyWith(refreshingSources: {...state.refreshingSources, id}));
    await _enqueue(id);
    if (!isClosed)
      _emit(
        state.copyWith(
          refreshingSources: {...state.refreshingSources}..remove(id),
        ),
      );
  }

  Future<void> retryFailedSources() async {
    await Future.wait([
      for (final e in state.errors.entries.toList())
        if (_retryable(e.value) && _eligible(e.key)) _enqueue(e.key),
    ]);
  }

  bool _retryable(String code) =>
      const {'timeout', 'network', 'server', 'rateLimited'}.contains(code);
  DateTime? _nextRetryTime() {
    DateTime? earliest;
    final now = DateTime.now();
    for (final entry in state.errors.entries) {
      if (!_retryable(entry.value) || !_eligible(entry.key)) continue;
      final time = _retryAt[entry.key];
      if (time == null || !time.isAfter(now)) return null;
      if (earliest == null || time.isBefore(earliest)) earliest = time;
    }
    return earliest;
  }

  void _updateRecovery() {
    if (state.errors.values.any(_retryable))
      _recovery.failed(const SocketException('Search network unavailable'));
    else
      _recovery.succeeded();
  }

  void setReadActive(bool active) {
    final returning = active && !_active;
    _active = active;
    _recovery.setActive(active);
    if (!active) {
      for (final id in _jobs.keys.toList()) _retireSource(id);
    } else {
      for (final e in state.selectedSources.entries) {
        if (e.value &&
            !state.results.containsKey(e.key) &&
            !state.notices.containsKey(e.key) &&
            !state.errors.containsKey(e.key))
          unawaited(_enqueue(e.key));
      }
      if (returning) _recovery.trigger();
      _drain();
    }
  }

  void _networkChanged(String source) {
    if (isClosed || state.selectedSources[source] != true) return;
    _retireSource(source, clear: true);
    if (_active) unawaited(_enqueue(source));
  }

  void toggleHasResults(bool value) =>
      _emit(state.copyWith(showHasResults: value));
  void toggleShowErrors(bool value) => _emit(state.copyWith(showErrors: value));
  void _emit(AggregateSearchState next) {
    if (!isClosed) emit(next);
  }

  @override
  Future<void> close() async {
    _active = false;
    _instances.remove(this);
    _recovery.dispose();
    await _networkChanges.cancel();
    await _session.cancel();
    for (final id in _jobs.keys.toList()) _retireSource(id);
    return super.close();
  }

  Future<void> _searchSingleSource(
    String pluginId,
    SearchEvent searchEvent, {
    required _AggregateJob job,
  }) async {
    final search = searchEvent.searchStates;
    final extern = aggregateComicSearchExtern(search, pluginId);
    final titleOnly =
        explicitKeywordSearchScope(extern) == KeywordSearchScope.title;
    String? category;
    var canReadCopyTopic = false;
    final readVideoPage = await _videoSearch.prepare(
      pluginId,
      search.searchKeyword,
      taskGroupKey: job.group,
      current: () => _current(job),
      onComicMetadata: (metadata) {
        canReadCopyTopic =
            explicitKeywordSearchScope(extern) == KeywordSearchScope.all &&
            supportsCopyTopicSearch(pluginId, metadata);
        final experience = asJsonMap(metadata['breezeExperience']);
        category = aggregateDeclaredCategory(
          source: pluginId,
          query: search.searchKeyword,
          options: asJsonList(
            experience['searchQuickCategories'],
          ).whereType<String>(),
          extern: extern,
        );
      },
    );
    if (!_current(job)) throw _AggregateCancelled();
    if (readVideoPage != null) {
      await _searchVideoPreview(
        job,
        readVideoPage,
        search.searchKeyword,
        titleOnly: titleOnly,
      );
      return;
    }
    await _searchComicPreview(
      job,
      searchEvent.copyWith(
        page: 1,
        searchStates: search.copyWith(from: pluginId, pluginExtern: extern),
      ),
      category: category,
      canReadCopyTopic: canReadCopyTopic,
    );
  }

  Future<void> _searchVideoPreview(
    _AggregateJob job,
    AggregateVideoPageReader readPage,
    String query, {
    required bool titleOnly,
  }) async {
    final matchesTitle = titleOnly ? keywordTitleMatcher(query) : null;
    final masked = _maskedKeywords();
    final seenIds = <String>{};
    final cursors = <Map<String, dynamic>>[];
    Map<String, dynamic>? cursor;
    var visible = <ApiVideoItem>[];
    var filteredCount = 0;
    for (var page = 1; page <= _maxPreviewRequests; page++) {
      final result = await readPage(page, cursor);
      if (!_current(job)) throw _AggregateCancelled();
      if (result.page != page) throw const FormatException('Wrong result page');
      final items = result.items.where((item) => seenIds.add(item.id)).toList();
      final matches = items.where((item) {
        if (matchesTitle != null &&
            !matchesTitle([item.title, item.alternateTitle])) {
          return false;
        }
        return masked.isEmpty ||
            !masked.any(
              _normalizeMaskedTextF(
                [item.title, item.description, item.actors].join('\n'),
              ).contains,
            );
      }).toList();
      filteredCount += items.length - matches.length;
      if (matches.isNotEmpty) {
        visible = orderAggregateVideos([
          ...visible,
          ...matches,
        ], query).take(aggregateSearchPreviewLimit).toList();
      }
      if (visible.isNotEmpty && items.isNotEmpty) {
        _commitPreview(job, visible, filteredCount);
      }
      if (visible.length >= aggregateSearchPreviewLimit ||
          (result.items.isNotEmpty && items.isEmpty)) {
        break;
      }
      cursor = result.nextCursor;
      if (cursor?.isEmpty == true) cursor = null;
      // The source page uses pageCount as its terminal signal. A cursor can
      // drive pagination when there is no known page count.
      if (result.pageCount > 0 ? page >= result.pageCount : cursor == null) {
        break;
      }
      if (cursor != null) {
        if (cursors.any(
          (c) => const DeepCollectionEquality().equals(c, cursor),
        )) {
          break;
        }
        cursors.add(cursor);
      }
    }
    if (visible.isEmpty) _commitPreview(job, visible, filteredCount);
  }

  Future<void> _searchComicPreview(
    _AggregateJob job,
    SearchEvent event, {
    required String? category,
    required bool canReadCopyTopic,
  }) async {
    final search = event.searchStates;
    final extern = search.pluginExtern;
    final blocked = aggregateBlockedCategories(extern);
    final masked = _maskedKeywords();
    final matchesTitle = needsLoadedTitleMatch(search.from, extern)
        ? keywordTitleMatcher(search.searchKeyword)
        : null;
    final preserveOrder = hasExplicitAggregateComicSearch(extern);
    final seenIds = <String>{};
    var visible = <UnifiedComicListItem>[];
    AggregateCategoryPreview? categoryPreview;
    var filteredCount = 0;
    var requests = 0;

    int getPreviewCount() =>
        visible.length + (categoryPreview?.items.length ?? 0);
    void publish() =>
        _commitPreview(job, visible, filteredCount, category: categoryPreview);

    var next = event;
    while (requests < _maxPreviewRequests) {
      requests++;
      final result = await comicSearch(next, job.group);
      if (!_current(job)) throw _AggregateCancelled();
      final paging = result.paging;
      if (paging?.reportedPage case final reported?
          when reported != next.page) {
        throw const FormatException('Wrong result page');
      }
      final items = result.items.where((item) => seenIds.add(item.id)).toList();
      final candidates = matchesTitle == null
          ? items
          : items.where((item) => matchesTitle([item.title])).toList();
      final matches = await _visibleComics(candidates, blocked, masked);
      if (!_current(job)) throw _AggregateCancelled();
      filteredCount += items.length - matches.length;
      if (matches.isNotEmpty) {
        final combined = [...visible, ...matches];
        visible =
            (preserveOrder
                    ? combined
                    : orderAggregateComics(combined, search.searchKeyword))
                .take(
                  aggregateSearchPreviewLimit -
                      (categoryPreview?.items.length ?? 0),
                )
                .toList();
      }
      if (visible.isNotEmpty && items.isNotEmpty) publish();
      if (next.page == 1 && canReadCopyTopic) {
        requests++;
        CopySearchTopic? topic;
        try {
          topic = await copyTopicLookup(
            search.searchKeyword,
            taskGroupKey: job.group,
          );
        } catch (_) {
          // Exact topics are optional alongside the regular keyword results.
        }
        if (!_current(job)) throw _AggregateCancelled();
        if (topic != null) {
          var topicItems = <UnifiedComicListItem>[];
          final remaining = aggregateSearchPreviewLimit - visible.length;
          if (remaining > 0) {
            requests++;
            try {
              final topicResult = await comicSearch(
                event.copyWith(
                  searchStates: copyTopicSearchState(search, topic),
                ),
                job.group,
              );
              if (_current(job) &&
                  (topicResult.paging?.reportedPage ?? 1) == 1) {
                final fresh = topicResult.items
                    .where((item) => seenIds.add(item.id))
                    .toList();
                final matches = await _visibleComics(fresh, blocked, masked);
                filteredCount += fresh.length - matches.length;
                topicItems = matches.take(remaining).toList();
              }
            } catch (_) {
              // Keep the independently resolved directory available to open.
            }
          }
          if (!_current(job)) throw _AggregateCancelled();
          categoryPreview = (
            category: topic.label,
            topic: topic,
            items: topicItems,
          );
          publish();
        }
      }
      if (getPreviewCount() >= aggregateSearchPreviewLimit) break;

      // An exact declared Bika category already has a separate continuation.
      // Give that single preview read room within the same per-source budget.
      if (next.page == 1 && category != null) {
        requests++;
        final categoryResult = await comicSearch(
          event.copyWith(
            searchStates: aggregateCategorySearch(
              search,
              search.from,
              category,
            ),
          ),
          job.group,
        );
        if (!_current(job)) throw _AggregateCancelled();
        if (categoryResult.paging?.reportedPage case final reported?
            when reported != 1) {
          throw const FormatException('Wrong result page');
        }
        final categoryItems = categoryResult.items
            .where(
              (item) =>
                  aggregateComicHasCategory(item, category) &&
                  seenIds.add(item.id),
            )
            .toList();
        final matches = await _visibleComics(categoryItems, blocked, masked);
        if (!_current(job)) throw _AggregateCancelled();
        filteredCount += categoryItems.length - matches.length;
        if (matches.isNotEmpty) {
          categoryPreview = (
            category: category,
            topic: null,
            items: matches
                .take(aggregateSearchPreviewLimit - visible.length)
                .toList(),
          );
        }
        if (getPreviewCount() > 0) publish();
      }

      if (getPreviewCount() >= aggregateSearchPreviewLimit ||
          (result.items.isNotEmpty && items.isEmpty) ||
          paging?.canContinueFrom(next.page) != true) {
        break;
      }
      next = next.copyWith(
        page: next.page + 1,
        searchStates: search.copyWith(pluginExtern: result.extern),
      );
    }
    if (getPreviewCount() == 0) publish();
  }

  List<String> _maskedKeywords() {
    final keywords =
        objectbox.userSettingBox.get(1)?.globalSetting.maskedKeywords ??
        const <String>[];
    return keywords
        .where((keyword) => keyword.trim().isNotEmpty)
        .map((keyword) => _normalizeMaskedTextF(keyword.trim()))
        .where((keyword) => keyword.isNotEmpty)
        .toList();
  }

  Future<List<UnifiedComicListItem>> _visibleComics(
    List<UnifiedComicListItem> candidates,
    Set<String> blocked,
    List<String> normalizedMaskedKeywords,
  ) async {
    final comics = filterEntriesByBlockedCategories(candidates, blocked);
    if (comics.isEmpty || normalizedMaskedKeywords.isEmpty) return comics;

    final payload = <String, dynamic>{
      'comics': comics.map((c) => c.toJson()).toList(),
      'maskedKeywords': normalizedMaskedKeywords,
    };

    try {
      final filtered = await workerManager.execute<List<Map<String, dynamic>>>(
        () => _filterAggregateComics(payload),
      );
      return filtered
          .map((json) => UnifiedComicListItem.fromJson(json))
          .toList();
    } catch (_) {
      return comics.where((comic) {
        final allText = _normalizeMaskedTextF(
          [
            comic.title,
            comic.subtitle,
            ...comic.metadata.expand((item) => item.value),
          ].join('\n'),
        );
        return !normalizedMaskedKeywords.any(allText.contains);
      }).toList();
    }
  }
}

Future<AggregateComicPage> _readAggregateComics(
  SearchEvent event,
  String group,
) async {
  late final UnifiedPluginSearchPaging paging;
  final result = await getPluginSearchResult(
    event,
    BlocState(),
    taskGroupKey: group,
    notifyUnauthorized: false,
    onPaging: (value) => paging = value,
  );
  return AggregateComicPage(
    result.comics.map((entry) => entry.comic).toList(),
    paging: paging,
    extern: result.pluginExtern,
  );
}

Future<List<Map<String, dynamic>>> _filterAggregateComics(
  Map<String, dynamic> payload,
) async {
  await initRustLib(silent: true);
  final comics = ((payload['comics'] as List?) ?? const <dynamic>[])
      .whereType<Map>()
      .map((entry) => _asWorkerMapF(entry))
      .toList();
  final maskedKeywords =
      ((payload['maskedKeywords'] as List?) ?? const <dynamic>[])
          .map((entry) => entry.toString().trim())
          .where((entry) => entry.isNotEmpty)
          .toList();

  if (comics.isEmpty || maskedKeywords.isEmpty) {
    return comics;
  }

  final visible = <Map<String, dynamic>>[];
  for (final comic in comics) {
    final metadata = ((comic['metadata'] as List?) ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => _asWorkerMapF(item))
        .toList();

    final valueNames = <String>[];
    for (final meta in metadata) {
      final values = (meta['value'] as List?) ?? const <dynamic>[];
      for (final val in values) {
        if (val is Map) {
          final name = val['name']?.toString() ?? '';
          if (name.isNotEmpty) {
            valueNames.add(name);
          }
        } else {
          final name = val.toString().trim();
          if (name.isNotEmpty) {
            valueNames.add(name);
          }
        }
      }
    }

    final allText = _normalizeMaskedTextF(
      [
        comic['title']?.toString() ?? '',
        comic['subtitle']?.toString() ?? '',
        ...valueNames,
      ].join('\n'),
    );

    final blocked = maskedKeywords.any(allText.contains);
    if (!blocked) {
      visible.add(comic);
    }
  }
  return visible;
}

Map<String, dynamic> _asWorkerMapF(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}

String _normalizeMaskedTextF(String text) {
  final lower = text.toLowerCase();
  try {
    return t2s(lower);
  } catch (_) {
    return lower;
  }
}

/// Stable product feedback never exposes bundle IDs, plugin paths or raw URLs.
String aggregateSearchFailure(Object error) {
  final text = error.toString().toLowerCase();
  if (error is PluginLoginRequiredException) return 'login';
  if (text.contains('login required') ||
      text.contains('unauthorized') ||
      text.contains('需要登录') ||
      text.contains('未登录') ||
      text.contains('登录已过期'))
    return 'login';
  if (error is FormatException) return 'format';
  if (text.contains('429')) return 'rateLimited';
  if (RegExp(r'http[^0-9]*5[0-9]{2}').hasMatch(text)) return 'server';
  if (error is SocketException ||
      readFailureIsTransient(error) && error is! TimeoutException)
    return 'network';
  if (error is TimeoutException ||
      text.contains('timeout') ||
      text.contains('timed out')) {
    return 'timeout';
  }
  if (text.contains('verification') ||
      text.contains('captcha') ||
      text.contains('challenge') ||
      text.contains('验证')) {
    return 'verification';
  }
  return 'unavailable';
}
