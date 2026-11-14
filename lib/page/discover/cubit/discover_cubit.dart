import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/toast.dart';

typedef _PluginInfoKey = ({
  bool enabled,
  bool deleted,
  bool debug,
  String? debugUrl,
  String version,
  String script,
});

/// 单个插件 info 的加载状态。
class DiscoverPluginInfoState {
  const DiscoverPluginInfoState({this.loading = true, this.error, this.data});

  final bool loading;
  final String? error;
  final Map<String, dynamic>? data;

  DiscoverPluginInfoState copyWith({
    bool? loading,
    String? error,
    Map<String, dynamic>? data,
  }) {
    return DiscoverPluginInfoState(
      loading: loading ?? this.loading,
      error: error,
      data: data ?? this.data,
    );
  }
}

/// Discover 页状态：插件列表 + 每个插件的 info 加载状态 + 开关状态。
class DiscoverState {
  const DiscoverState({
    this.plugins = const {},
    this.infoStates = const {},
    this.pendingEnabled = const {},
  });

  final Map<String, PluginRuntimeState> plugins;
  final Map<String, DiscoverPluginInfoState> infoStates;
  final Map<String, bool> pendingEnabled;

  DiscoverState copyWith({
    Map<String, PluginRuntimeState>? plugins,
    Map<String, DiscoverPluginInfoState>? infoStates,
    Map<String, bool>? pendingEnabled,
  }) {
    return DiscoverState(
      plugins: plugins ?? this.plugins,
      infoStates: infoStates ?? this.infoStates,
      pendingEnabled: pendingEnabled ?? this.pendingEnabled,
    );
  }
}

class DiscoverCubit extends Cubit<DiscoverState> {
  DiscoverCubit({PluginRegistryService? service})
    : _service = service ?? PluginRegistryService.I,
      super(const DiscoverState()) {
    _subscription = _service.stream.listen((_) => _syncPluginsAndLoad());
    _syncPluginsAndLoad();
  }

  final PluginRegistryService _service;
  late final StreamSubscription<Map<String, PluginRuntimeState>> _subscription;

  final Map<String, ({_PluginInfoKey key, int sequence})> _requests = {};
  int _requestSequence = 0;
  final Map<String, _PluginInfoKey> _cacheKeys = {};
  final Map<String, Future<void>> _infoTasks = {};
  Future<bool>? _reloadTask;
  bool get refreshing => _reloadTask != null;
  final _retainedFailures = <String>{};
  String? get refreshError =>
      _retainedFailures.isEmpty ? null : t.common.loadingFailed;

  /// 当前默认插件源：优先已启用，否则取首个可见插件。
  String get currentFrom {
    final active = state.plugins.values.where((s) => s.isActive).toList();
    if (active.isNotEmpty) {
      return active.first.uuid;
    }
    final first = state.plugins.values.firstOrNull;
    return first?.uuid ?? '';
  }

  /// 切换插件启用状态。
  ///
  /// 开启时会初始化插件运行时并执行 [init]；关闭时会立即销毁当前运行时。
  Future<void> toggleEnabled(String uuid, bool enabled) async {
    if (isClosed || state.pendingEnabled.containsKey(uuid)) return;
    emit(
      state.copyWith(pendingEnabled: {...state.pendingEnabled, uuid: enabled}),
    );

    try {
      await _service.setEnabled(uuid, enabled);
    } catch (e) {
      showErrorToast(
        enabled
            ? t.discover.pluginEnableFailed(error: e)
            : t.discover.pluginCloseFailed(error: e),
      );
    } finally {
      if (!isClosed) {
        // Reconcile the displayed value and release the switch together. A
        // delayed registry stream event must not send the thumb back first.
        final remaining = {...state.pendingEnabled}..remove(uuid);
        _syncPluginsAndLoad(pendingEnabled: remaining);
      }
    }
  }

  /// 初始加载，与 [reload] 区别是不清空缓存，仅补齐缺失的 info。
  void load() => _syncPluginsAndLoad();

  /// 重新加载所有可见插件的 info。
  Future<bool> reload() {
    if (isClosed) {
      return Future.value(false);
    }
    final pending = _reloadTask;
    if (pending != null) {
      return pending;
    }
    final task = _reload();
    _reloadTask = task;
    return task.whenComplete(() {
      if (identical(_reloadTask, task)) {
        _reloadTask = null;
      }
    });
  }

  Future<bool> _reload() async {
    _retainedFailures.clear();
    _syncPluginsAndLoad();
    final expected = {
      for (final plugin in state.plugins.values)
        plugin.uuid: _pluginInfoCacheKey(plugin),
    };
    final retained = Map<String, DiscoverPluginInfoState>.from(
      state.infoStates,
    );
    for (final uuid in expected.keys) {
      retained[uuid] = (retained[uuid] ?? const DiscoverPluginInfoState())
          .copyWith(loading: retained[uuid]?.data == null);
    }
    emit(state.copyWith(infoStates: retained));
    await Future.wait([
      for (final uuid in expected.keys) _loadPluginInfo(uuid),
    ]);
    return !isClosed &&
        expected.entries.every((entry) {
          final current = _service.getByUuid(entry.key);
          final info = state.infoStates[entry.key];
          return current != null &&
              _pluginInfoCacheKey(current) == entry.value &&
              info?.loading == false &&
              info?.error == null &&
              !_retainedFailures.contains(entry.key);
        });
  }

  /// 强制重新加载指定插件的 info。
  Future<void> retryLoadInfo(String uuid) async {
    _requests.remove(uuid);
    _retainedFailures.remove(uuid);
    final infoStates = Map<String, DiscoverPluginInfoState>.from(
      state.infoStates,
    );
    infoStates[uuid] = (infoStates[uuid] ?? const DiscoverPluginInfoState())
        .copyWith(loading: infoStates[uuid]?.data == null);
    emit(state.copyWith(infoStates: infoStates));
    await _loadPluginInfo(uuid);
  }

  void _syncPluginsAndLoad({Map<String, bool>? pendingEnabled}) {
    final snapshot = _service.snapshot;
    final visiblePlugins = _service.sortPlugins(
      snapshot.values.where((plugin) => !plugin.isDeleted),
    );
    final plugins = <String, PluginRuntimeState>{
      for (final plugin in visiblePlugins) plugin.uuid: plugin,
    };

    final newInfoStates = Map<String, DiscoverPluginInfoState>.from(
      state.infoStates,
    );
    final newCacheKeys = <String, _PluginInfoKey>{};

    for (final entry in plugins.entries) {
      final uuid = entry.key;
      final pluginState = entry.value;
      final cacheKey = _pluginInfoCacheKey(pluginState);
      final previousCacheKey = _cacheKeys[uuid];

      final contextChanged =
          previousCacheKey != null && previousCacheKey != cacheKey;
      final bundleChanged =
          previousCacheKey != null && !_sameBundle(previousCacheKey, cacheKey);
      final pendingWithoutData =
          _requests.containsKey(uuid) && newInfoStates[uuid]?.data == null;
      if (contextChanged) _requests.remove(uuid);
      // An enabled switch invalidates pending runtime work, but the displayed
      // metadata still describes the same bundle and keeps the card stable.
      if (bundleChanged || (contextChanged && pendingWithoutData)) {
        newInfoStates.remove(uuid);
      }
      newCacheKeys[uuid] = cacheKey;

      if (!newInfoStates.containsKey(uuid) &&
          _requests[uuid]?.key != cacheKey) {
        // Persisted getInfo belongs to the previous bundle after an update.
        final cached = bundleChanged
            ? null
            : _service.getCachedPluginInfo(uuid);
        if (cached != null) {
          newInfoStates[uuid] = DiscoverPluginInfoState(
            loading: false,
            data: cached,
          );
          // Show the persisted title immediately, then verify it against the
          // installed bundle. A prior app session may have stored an old name.
          if (previousCacheKey == null) _loadPluginInfo(uuid);
        } else {
          newInfoStates[uuid] = const DiscoverPluginInfoState(loading: true);
          _loadPluginInfo(uuid);
        }
      }
    }

    // 清理已删除插件的 info 状态。
    for (final uuid in state.infoStates.keys.toList()) {
      if (!plugins.containsKey(uuid)) {
        _requests.remove(uuid);
        _retainedFailures.remove(uuid);
        newInfoStates.remove(uuid);
      }
    }

    _cacheKeys
      ..clear()
      ..addAll(newCacheKeys);

    emit(
      state.copyWith(
        plugins: plugins,
        infoStates: newInfoStates,
        pendingEnabled: pendingEnabled,
      ),
    );
  }

  Future<void> _loadPluginInfo(String uuid) {
    final plugin = _service.getByUuid(uuid);
    if (plugin == null || plugin.isDeleted || isClosed) {
      return Future.value();
    }
    if (_requests[uuid]?.key == _pluginInfoCacheKey(plugin)) {
      return _infoTasks[uuid] ?? Future.value();
    }
    final task = _readPluginInfo(uuid);
    _infoTasks[uuid] = task;
    return task.whenComplete(() {
      if (identical(_infoTasks[uuid], task)) {
        _infoTasks.remove(uuid);
      }
    });
  }

  Future<void> _readPluginInfo(String uuid) async {
    final plugin = _service.getByUuid(uuid);
    if (plugin == null || plugin.isDeleted) return;
    final key = _pluginInfoCacheKey(plugin);
    if (_requests[uuid]?.key == key) return;
    final request = (key: key, sequence: ++_requestSequence);
    _requests[uuid] = request;
    bool isCurrent() {
      final current = _service.getByUuid(uuid);
      return !isClosed &&
          _requests[uuid] == request &&
          current != null &&
          _pluginInfoCacheKey(current) == key;
    }

    try {
      final data = await _service.fetchPluginInfo(
        uuid: uuid,
        runtimeName: uuid,
      );
      if (isCurrent()) {
        final infoStates = Map<String, DiscoverPluginInfoState>.from(
          state.infoStates,
        )..[uuid] = DiscoverPluginInfoState(loading: false, data: data);
        emit(state.copyWith(infoStates: infoStates));
      }
    } catch (e) {
      if (!isCurrent()) return;
      final pluginState = _service.getByUuid(uuid);
      if (pluginState?.debug == true) {
        showErrorToast(t.discover.pluginDebugLoadFailed(error: e));
      }
      if (isCurrent()) {
        final retained = state.infoStates[uuid]?.data;
        if (retained != null) _retainedFailures.add(uuid);
        final infoStates =
            Map<String, DiscoverPluginInfoState>.from(state.infoStates)
              ..[uuid] = DiscoverPluginInfoState(
                loading: false,
                error: retained == null ? e.toString() : null,
                data: retained,
              );
        emit(state.copyWith(infoStates: infoStates));
      }
    } finally {
      if (_requests[uuid] == request) _requests.remove(uuid);
    }
  }

  bool _sameBundle(_PluginInfoKey a, _PluginInfoKey b) =>
      a.deleted == b.deleted &&
      a.debug == b.debug &&
      a.debugUrl == b.debugUrl &&
      a.version == b.version &&
      a.script == b.script;

  _PluginInfoKey _pluginInfoCacheKey(PluginRuntimeState state) => (
    enabled: state.isEnabled,
    deleted: state.isDeleted,
    debug: state.debug,
    debugUrl: state.debugUrl,
    version: state.version,
    script: state.originScript,
  );

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
