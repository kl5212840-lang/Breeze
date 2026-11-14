import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:worker_manager/worker_manager.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart'
    show normalizePluginId;
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search_result/method/get_plugin_result.dart';
import 'package:zephyr/page/search_result/models/bloc_state.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/page_read_tasks.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/util/event/event.dart';
import 'package:zephyr/util/rust_loader.dart';
import 'package:zephyr/util/text/chinese_convert.dart';

import 'package:zephyr/page/search_result/models/models.dart';

part 'search_bloc.freezed.dart';
part 'search_bloc.g.dart';
part 'search_event.dart';
part 'search_state.dart';

Map<String, dynamic> _asWorkerMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}

String _normalizeMaskedText(String text) {
  final lower = text.toLowerCase();
  try {
    return t2s(lower);
  } catch (_) {
    return lower;
  }
}

Future<List<Map<String, dynamic>>> filterShieldedComicJsonList(
  Map<String, dynamic> payload,
) async {
  await initRustLib(silent: true);
  final comics = ((payload['comics'] as List?) ?? const <dynamic>[])
      .whereType<Map>()
      .map((entry) => _asWorkerMap(entry))
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
  for (final entry in comics) {
    final comic = _asWorkerMap(entry['comic']);
    final metadata = ((comic['metadata'] as List?) ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => _asWorkerMap(item))
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

    final allText = _normalizeMaskedText(
      [
        comic['title']?.toString() ?? '',
        comic['subtitle']?.toString() ?? '',
        ...valueNames,
      ].join('\n'),
    );

    final blocked = maskedKeywords.any(allText.contains);
    if (!blocked) {
      visible.add(entry);
    }
  }
  return visible;
}

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc() : super(SearchState()) {
    on<SearchEvent>(_scheduleSearch);
    _sessionChanges = pluginSessionWriteFence.changes.listen(_sessionChanged);
  }

  final _reads = PageReadTasks();
  late final StreamSubscription<PluginSessionBoundary> _sessionChanges;
  bool _busy = false;
  SearchEvent? _initialQuery;
  SearchEvent? _pendingReplacement;
  Future<void>? _replacementCancellation;
  int _queryRevision = 0;

  @override
  void add(SearchEvent event) {
    super.add(event);
    if (event.status == SearchStatus.initial) _initialQuery = event;
  }

  void _sessionChanged(PluginSessionBoundary boundary) {
    final query = _initialQuery;
    if (query == null ||
        isClosed ||
        normalizePluginId(query.searchStates.from) != boundary.source) {
      return;
    }
    blocState = BlocState();
    add(query.copyWith(page: 1));
  }

  @override
  Future<void> close() {
    unawaited(_sessionChanges.cancel());
    _queryRevision++;
    _pendingReplacement = null;
    unawaited(_reads.cancel());
    return super.close();
  }

  // Wait for native cancellation before admitting the latest replacement.
  // Pagination callbacks for the superseded query can be discarded.
  Future<void> _scheduleSearch(
    SearchEvent event,
    Emitter<SearchState> emit,
  ) async {
    if (isClosed) return;
    if (event.status == SearchStatus.initial) _queryRevision++;
    if (_busy) {
      if (event.status == SearchStatus.initial) {
        _pendingReplacement = event;
        _replacementCancellation ??= _reads.cancel();
      }
      return;
    }
    _busy = true;
    try {
      SearchEvent? next = event;
      while (next != null && !isClosed && !emit.isDone) {
        await _fetchComicList(next, emit, _queryRevision);
        final cancellation = _replacementCancellation;
        if (cancellation != null) {
          await cancellation;
          // Let the event stream deliver replacements already queued this turn.
          await Future<void>.delayed(Duration.zero);
          _replacementCancellation = null;
        }
        next = _pendingReplacement;
        _pendingReplacement = null;
      }
    } finally {
      _busy = false;
    }
  }

  var blocState = BlocState();

  Future<void> _fetchComicList(
    SearchEvent event,
    Emitter<SearchState> emit,
    int revision,
  ) async {
    final source = normalizePluginId(event.searchStates.from);
    final generation = pluginSessionWriteFence.generation(source);
    bool current() =>
        !isClosed &&
        !emit.isDone &&
        revision == _queryRevision &&
        generation == pluginSessionWriteFence.generation(source) &&
        !pluginSessionWriteFence.isChanging(source);
    if (event.status == SearchStatus.initial) {
      emit(state.copyWith(status: SearchStatus.initial));
    }
    if (!current()) return;

    if (event.status == SearchStatus.loadingMore &&
        (blocState.hasReachedMax || event.page <= blocState.pagesCount)) {
      return;
    }
    // Work on a request snapshot; obsolete completions cannot mutate the
    // accepted cursor, accumulated items or plugin pagination extern.
    var result = event.status == SearchStatus.initial
        ? BlocState()
        : BlocState(
            hasReachedMax: blocState.hasReachedMax,
            pagesCount: blocState.pagesCount,
            totalPages: blocState.totalPages,
            totalResults: blocState.totalResults,
            comics: blocState.comics,
            visibleComics: blocState.visibleComics,
            pluginExtern: blocState.pluginExtern,
            maskedKeywordsFingerprint: blocState.maskedKeywordsFingerprint,
          );

    if (event.status == SearchStatus.loadingMore) {
      emit(
        state.copyWith(
          status: SearchStatus.loadingMore,
          comics: blocState.visibleComics,
          hasReachedMax: blocState.hasReachedMax,
          searchEvent: event,
        ),
      );
    }

    try {
      final previousRawCount = result.comics.length;
      result = await _reads.run(
        event.searchStates.from,
        (group) => getPluginSearchResult(
          event,
          result,
          taskGroupKey: group,
          notifyUnauthorized: false,
        ),
      );
      if (!current()) return;
      final (maskedKeywords, fingerprint) = _loadMaskedKeywords();

      if (fingerprint != result.maskedKeywordsFingerprint) {
        result.visibleComics = await _filterShieldedComicsByWorker(
          result.comics,
          maskedKeywords,
        );
        result.maskedKeywordsFingerprint = fingerprint;
      } else {
        final appended = result.comics.skip(previousRawCount).toList();
        final filteredAppended = await _filterShieldedComicsByWorker(
          appended,
          maskedKeywords,
        );
        if (filteredAppended.isNotEmpty) {
          result.visibleComics = [...result.visibleComics, ...filteredAppended];
        }
      }

      if (!current()) return;
      blocState = result;
      emit(
        state.copyWith(
          status: SearchStatus.success,
          comics: result.visibleComics,
          hasReachedMax: result.hasReachedMax,
          currentPage: result.pagesCount,
          totalPages: result.totalPages,
          totalResults: result.totalResults,
          searchEvent: event.copyWith(
            page: result.pagesCount,
            searchStates: event.searchStates.copyWith(
              pluginExtern: result.pluginExtern,
            ),
          ),
        ),
      );
    } catch (e, s) {
      if (!current()) return;
      if (e is PluginLoginRequiredException) {
        eventBus.fire(
          NeedLogin(from: e.payload.pluginId, message: e.payload.message),
        );
      }
      logger.e(e, stackTrace: s);
      if (event.status == SearchStatus.loadingMore &&
          blocState.comics.isNotEmpty) {
        emit(
          state.copyWith(
            status: SearchStatus.getMoreFailure,
            comics: blocState.visibleComics,
            searchEvent: event,
            result: normalizeSearchErrorMessage(e),
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          status: SearchStatus.failure,
          searchEvent: event,
          result: normalizeSearchErrorMessage(e),
        ),
      );
    }
  }

  (List<String>, String) _loadMaskedKeywords() {
    final settings = objectbox.userSettingBox.get(1)!.globalSetting;
    final maskedKeywords = settings.maskedKeywords
        .where((keyword) => keyword.trim().isNotEmpty)
        .map((keyword) => _normalizeMaskedText(keyword.trim()))
        .where((keyword) => keyword.isNotEmpty)
        .toSet()
        .toList();
    maskedKeywords.sort();
    return (maskedKeywords, maskedKeywords.join('\u0001'));
  }

  List<ComicNumber> _filterShieldedComicsFallback(
    List<ComicNumber> comics,
    List<String> maskedKeywords,
  ) {
    if (comics.isEmpty || maskedKeywords.isEmpty) {
      return comics;
    }
    return comics.where((comic) {
      final data = comic.comic;
      final allText = _normalizeMaskedText(
        [
          data.title,
          data.subtitle,
          ...data.metadata.expand((item) => item.value),
        ].join('\n'),
      );

      final containsKeyword = maskedKeywords.any(allText.contains);

      return !containsKeyword;
    }).toList();
  }

  Future<List<ComicNumber>> _filterShieldedComicsByWorker(
    List<ComicNumber> comics,
    List<String> maskedKeywords,
  ) async {
    if (comics.isEmpty || maskedKeywords.isEmpty) {
      return comics;
    }

    final payload = <String, dynamic>{
      'comics': comics.map((item) => item.toJson()).toList(),
      'maskedKeywords': maskedKeywords,
    };

    try {
      final filtered = await workerManager.execute<List<Map<String, dynamic>>>(
        () => filterShieldedComicJsonList(payload),
      );
      return filtered.map(ComicNumber.fromJson).toList();
    } catch (e, s) {
      logger.w('search shield filter fallback to main isolate', error: e);
      logger.d(s);
      return _filterShieldedComicsFallback(comics, maskedKeywords);
    }
  }
}
