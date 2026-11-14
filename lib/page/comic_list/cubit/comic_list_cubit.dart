import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/service/page_read_tasks.dart';
import 'package:zephyr/service/read_recovery.dart';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/network/http/plugin/unified_plugin_envelope.dart';
import 'package:zephyr/page/comic_list/cubit/comic_list_state.dart';
import 'package:zephyr/page/comic_list/models/comic_list_scene.dart';
import 'package:zephyr/page/comic_list/models/list_filter_bundle.dart';
import 'package:zephyr/page/comic_list/scene_filter/plugin_list_filter_schema.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';

export 'package:zephyr/page/comic_list/cubit/comic_list_state.dart';

class ComicListCubit extends Cubit<ComicListState> {
  ComicListCubit({
    this.initialScene,
    this.sceneSource,
    this.sceneBundleFnPath,
    this.sceneBundleFnPathFallback,
    this.observeSessionChanges = false,
  }) : super(const ComicListState()) {
    _recovery = ReadRecoveryController(
      source: initialScene?.from ?? sceneSource ?? '',
      retry: () async {
        if (state.scene == null || state.sceneError != null) {
          await reload();
        } else if (state.filterError != null || !state.hasResolvedFilter) {
          await loadFilter();
        }
      },
    );
    _sessionSubscription = pluginSessionWriteFence.changes.listen(
      _sessionChanged,
    );
    _init();
  }

  final ComicListScene? initialScene;
  final String? sceneSource;
  final String? sceneBundleFnPath;
  final String? sceneBundleFnPathFallback;
  final bool observeSessionChanges;
  StreamSubscription<PluginSessionBoundary>? _sessionSubscription;
  int _requestEpoch = 0;
  final _reads = PageReadTasks();
  late final ReadRecoveryController _recovery;
  void setReadActive(bool active) => _recovery.setActive(active);

  void _sessionChanged(PluginSessionBoundary boundary) {
    if (isClosed || boundary.source != state.currentFrom) return;
    _requestEpoch++;
    _recovery.reset();
    unawaited(_reads.cancel());
    _filterLoad = null;
    _sceneLoad = null;
    emit(
      ComicListState(
        currentFrom: state.currentFrom,
        sceneLoading: boundary.changing,
      ),
    );
    if (!boundary.changing) _recovery.invalidate();
  }

  @override
  Future<void> close() async {
    _requestEpoch++;
    _recovery.dispose();
    await _sessionSubscription?.cancel();
    await _reads.cancel();
    return super.close();
  }

  void _init() {
    final currentFrom = initialScene?.from ?? (sceneSource ?? '').trim();
    emit(state.copyWith(currentFrom: currentFrom));

    if (pluginSessionWriteFence.isChanging(currentFrom)) {
      emit(state.copyWith(sceneLoading: true));
      return;
    }

    if (currentFrom.isEmpty) {
      return;
    }

    if (initialScene != null) {
      emit(state.copyWith(scene: initialScene));
      _onSceneAvailable(currentFrom);
      return;
    }

    _loadScene(currentFrom);
  }

  Future<void> reload() async {
    final pending = _sceneLoad;
    if (pending != null) return pending;
    unawaited(_reads.cancel());
    _requestEpoch++;
    _filterLoad = null;
    final from = state.currentFrom;
    if (_sessionSubscription != null &&
        pluginSessionWriteFence.isChanging(from)) {
      emit(ComicListState(currentFrom: from, sceneLoading: true));
      return;
    }
    emit(
      state.copyWith(
        sceneLoading: false,
        sceneError: null,
        filterLoading: false,
        filterError: null,
      ),
    );

    if (from.isEmpty) {
      return;
    }

    if (initialScene != null) {
      emit(state.copyWith(scene: initialScene));
      _onSceneAvailable(from);
      return;
    }

    await _loadScene(from);
  }

  Future<void>? _sceneLoad;
  Future<void> _loadScene(String from) {
    final pending = _sceneLoad;
    if (pending != null) return pending;
    final task = _readScene(from);
    _sceneLoad = task;
    return task.whenComplete(() {
      if (identical(_sceneLoad, task)) _sceneLoad = null;
    });
  }

  Future<void> _readScene(String from) async {
    final epoch = _requestEpoch;
    final generation = pluginSessionWriteFence.generation(from);
    if (state.sceneLoading) {
      return;
    }

    emit(state.copyWith(sceneLoading: true, sceneError: null));

    try {
      final sceneFnPath = sceneBundleFnPath?.trim().isNotEmpty == true
          ? sceneBundleFnPath!.trim()
          : 'getComicListSceneBundle';

      Map<String, dynamic> response;
      try {
        response = await _reads.run(
          from,
          (group) => callUnifiedComicPlugin(
            from: from,
            fnPath: sceneFnPath,
            core: const <String, dynamic>{},
            extern: const <String, dynamic>{},
            taskGroupKey: group,
          ),
        );
      } catch (error) {
        if (isClosed ||
            epoch != _requestEpoch ||
            generation != pluginSessionWriteFence.generation(from))
          return;
        // A second function name cannot repair a failed connection; avoid
        // doubling the wait on an unstable Bika route.
        if (isTransientNetworkError(error) ||
            error is PluginLoginRequiredException)
          rethrow;
        final fallback = sceneBundleFnPathFallback?.trim() ?? '';
        if (fallback.isEmpty || fallback == sceneFnPath) {
          rethrow;
        }
        response = await _reads.run(
          from,
          (group) => callUnifiedComicPlugin(
            from: from,
            fnPath: fallback,
            core: const <String, dynamic>{},
            extern: const <String, dynamic>{},
            taskGroupKey: group,
          ),
        );
      }

      final envelope = UnifiedPluginEnvelope.fromMap(response);
      final sceneMap = asJsonMap(envelope.data['scene']);
      final loadedScene = ComicListScene.fromMap(
        sceneMap.isNotEmpty ? sceneMap : envelope.data,
      );

      if (isClosed ||
          epoch != _requestEpoch ||
          generation != pluginSessionWriteFence.generation(from)) {
        return;
      }

      emit(
        state.copyWith(
          scene: loadedScene,
          sceneLoading: false,
          sceneError: null,
        ),
      );
      _recovery.succeeded();
      _onSceneAvailable(from);
    } catch (e) {
      if (isClosed ||
          epoch != _requestEpoch ||
          generation != pluginSessionWriteFence.generation(from)) {
        return;
      }
      _recovery.failed(e);
      if (e is PluginLoginRequiredException) {
        emit(ComicListState(currentFrom: from, sceneError: e.toString()));
        return;
      }
      emit(
        state.copyWith(
          sceneError: normalizeSearchErrorMessage(e),
          sceneLoading: false,
        ),
      );
    }
  }

  void _onSceneAvailable(String from) {
    final request = state.scene?.body.request;
    if (_sessionSubscription == null &&
        (request?.fnPath == 'getCloudFavoriteData' ||
            request?.extern['source'] == 'cloudFavorite')) {
      _sessionSubscription = pluginSessionWriteFence.changes.listen(
        _sessionChanged,
      );
    }
    final validationError = _validateScene(state.scene);
    if (validationError != null) {
      _recovery.failed(StateError(validationError));
      emit(state.copyWith(sceneError: validationError));
      return;
    }

    if (!state.requiresFilter || state.hasResolvedFilter) _recovery.succeeded();
    if (state.requiresFilter &&
        !state.hasResolvedFilter &&
        !state.filterLoading) {
      _loadFilter(from);
    }
  }

  String? _validateScene(ComicListScene? scene) {
    final request = scene?.body.request;
    if (request == null) {
      return t.comicList.missingListConfig;
    }
    if (request.fnPath.trim().isEmpty) {
      return t.comicList.missingFnPath;
    }
    return null;
  }

  Future<void> loadFilter() async {
    if (state.currentFrom.isEmpty) {
      return;
    }
    await _loadFilter(state.currentFrom);
  }

  Future<void>? _filterLoad;

  Future<void> _loadFilter(String from) {
    final pending = _filterLoad;
    if (pending != null) return pending;
    final task = _readFilter(from);
    _filterLoad = task;
    return task.whenComplete(() {
      if (identical(_filterLoad, task)) _filterLoad = null;
    });
  }

  Future<void> _readFilter(String from) async {
    final epoch = _requestEpoch;
    final generation = pluginSessionWriteFence.generation(from);
    final filterRequest = state.scene?.filter;
    if (filterRequest == null || state.filterLoading) {
      return;
    }

    emit(state.copyWith(filterLoading: true, filterError: null));

    try {
      final response = await _reads.run(
        from,
        (group) => callUnifiedComicPlugin(
          from: from,
          fnPath: filterRequest.fnPath,
          core: filterRequest.core,
          extern: filterRequest.extern,
          taskGroupKey: group,
        ),
      );
      final envelope = UnifiedPluginEnvelope.fromMap(response);
      final bundle = _parseFilterBundle(envelope);

      if (isClosed ||
          epoch != _requestEpoch ||
          generation != pluginSessionWriteFence.generation(from)) {
        return;
      }

      _recovery.succeeded();
      _applyFilterBundle(bundle, state.filterSelections);
    } catch (e) {
      if (isClosed ||
          epoch != _requestEpoch ||
          generation != pluginSessionWriteFence.generation(from)) {
        return;
      }
      _recovery.failed(e);
      if (e is PluginLoginRequiredException) {
        emit(ComicListState(currentFrom: from, sceneError: e.toString()));
        return;
      }
      emit(
        state.copyWith(
          filterError: normalizeSearchErrorMessage(e),
          filterLoading: false,
        ),
      );
    }
  }

  void applyFilterSelections(Map<String, String> selections) {
    final bundle = state.filterBundle;
    if (bundle == null) {
      return;
    }
    _applyFilterBundle(bundle, selections);
  }

  void _applyFilterBundle(
    ListFilterBundle bundle,
    Map<String, String> selections,
  ) {
    final resolved = bundle.scheme.resolve(
      requestedSelections: selections,
      defaultSelections: bundle.defaultSelections,
    );

    emit(
      state.copyWith(
        filterBundle: bundle,
        filterSelections: resolved.selections,
        resolvedUiParams: resolved.params,
        resolvedFilterCore: resolved.core,
        resolvedFilterExtern: resolved.extern,
        filterLoading: false,
        filterError: null,
      ),
    );
  }

  ListFilterBundle _parseFilterBundle(UnifiedPluginEnvelope envelope) {
    final values = asJsonMap(envelope.data['values']);
    final defaults = <String, String>{};
    values.forEach((key, value) {
      defaults[key] = value?.toString() ?? '';
    });

    return ListFilterBundle(
      scheme: PluginListFilterSchema.fromMap(envelope.scheme),
      defaultSelections: defaults,
    );
  }
}
