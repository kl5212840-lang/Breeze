import 'dart:async';
import 'dart:convert';

import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';

import 'package:zephyr/main.dart';
import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart';
import 'package:zephyr/network/http/plugin/qjs_network_route.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/object_box.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/plugin/models/plugin_runtime_state.dart';
import 'package:zephyr/plugin/plugin_host_compatibility.dart';
import 'package:zephyr/src/rust/api/qjs.dart';
import 'package:zephyr/src/rust/qjs.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/service/download/download_queue_manager.dart';
import 'package:zephyr/page/video/video_download.dart';
import 'package:zephyr/network/sync/sync_service.dart'
    show runExclusiveStorageOperation;
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:zephyr/plugin/models/plugin_runtime_state.dart';

class PluginRegistryService {
  PluginRegistryService._();

  static final PluginRegistryService I = PluginRegistryService._();

  final Map<String, PluginRuntimeState> _states = {};
  final _streamController =
      StreamController<Map<String, PluginRuntimeState>>.broadcast();
  ObjectBox? _objectbox;
  final Map<String, Map<String, dynamic>> _pluginInfoCache = {};
  final Set<String> _pluginInitDone = <String>{};
  final Set<String> _explicitInstallations = {};
  final Map<String, ({int depth, PluginRuntimeState? previous})>
  _publicationHolds = {};

  Stream<Map<String, PluginRuntimeState>> get stream =>
      _streamController.stream;

  Map<String, PluginRuntimeState> get snapshot {
    final published = Map<String, PluginRuntimeState>.from(_states);
    for (final entry in _publicationHolds.entries) {
      final previous = entry.value.previous;
      if (previous == null) {
        published.remove(entry.key);
      } else {
        published[entry.key] = previous;
      }
    }
    return Map.unmodifiable(published);
  }

  PluginRuntimeState? getByUuid(String uuid) {
    final key = canonicalQjsSource(uuid),
        state = _states[canonicalQjsSource(uuid)];
    if (state != null &&
        !_explicitInstallations.contains(key) &&
        LocalPluginInstallationState.instance.isRemoved(key)) {
      return state.copyWith(isDeleted: true, isEnabled: false);
    }
    return state;
  }

  bool isLocallyRemoved(String uuid) =>
      LocalPluginInstallationState.instance.isRemoved(canonicalQjsSource(uuid));

  Future<void> reloadLocalInstallationState() async {
    await LocalPluginInstallationState.instance.reload();
    await refreshFromDb();
  }

  /// 内存缓存未命中时，从 DB 持久化的 `getInfoJson` 兜底水合。
  ///
  /// `updateDebugConfig`/`setEnabled`/`upsert`/同步等路径都会清内存缓存，
  /// 但清完后并不一定触发 `fetchPluginInfo`（调试走 once-call 直读
  /// debug bundle，不经过缓存），导致名字显示回退成 uuid。
  /// 这里用上次持久化的 getInfo 补上，各调用方（详情页/书架/搜索）
  /// 无需改动。
  Map<String, dynamic>? getCachedPluginInfo(String uuid) {
    final cached = _pluginInfoCache[uuid];
    if (cached != null) {
      return cached;
    }
    final persisted = readPersistedGetInfoJson(uuid);
    if (persisted.isEmpty) {
      return null;
    }
    try {
      final decoded = requireJsonMap(jsonDecode(persisted));
      _pluginInfoCache[uuid] = decoded;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  Future<void> init() async {
    _objectbox = objectbox;
    await refreshFromDb();
  }

  Future<void> refreshFromDb() async {
    final objectbox = _objectbox;
    if (objectbox == null) {
      return;
    }

    await LocalPluginInstallationState.instance.load();
    final list = objectbox.pluginInfoBox.getAll();
    _states
      ..clear()
      ..addEntries(list.map((item) => MapEntry(item.uuid, _toState(item))));
    _emit();
  }

  Future<void> reconcileAfterExternalSync({
    Map<String, PluginRuntimeState>? previousSnapshot,
  }) async {
    final previous = Map<String, PluginRuntimeState>.from(
      previousSnapshot ?? snapshot,
    );
    logger.d('[plugin-sync] reconcile_start previous=${previous.length}');

    await refreshFromDb();

    final current = snapshot;
    final affected = <String>{...previous.keys, ...current.keys}.where((uuid) {
      final before = previous[uuid];
      final after = current[uuid];
      if (before == null || after == null) {
        return true;
      }
      return before.version != after.version ||
          before.originScript != after.originScript ||
          before.isEnabled != after.isEnabled ||
          before.isDeleted != after.isDeleted ||
          before.debug != after.debug ||
          before.debugUrl != after.debugUrl;
    }).toList();
    logger.d(
      '[plugin-sync] reconcile_diff current=${current.length} '
      'affected=${affected.length} uuids=${affected.join(',')}',
    );

    // The refreshed registry already prevents new chapters from starting.
    // Pause live chapters before any runtime drop can surface as cancellation.
    final stoppingDownloads = <Future<void>>[];
    for (final uuid in affected) {
      final plugin = current[uuid];
      if (previous[uuid]?.isActive == true &&
          plugin != null &&
          !plugin.isEnabled &&
          !plugin.isDeleted) {
        stoppingDownloads.add(
          DownloadQueueManager.instance
              .stopSourceRetainingFiles(uuid, disabling: true)
              .catchError((Object e, StackTrace st) {
                logger.w('同步禁用插件时暂停下载失败: $uuid', error: e, stackTrace: st);
              }),
        );
      }
    }

    for (final uuid in affected) {
      _pluginInfoCache.remove(uuid);
      _pluginInitDone.remove(uuid);

      try {
        await dropQjsRuntimesForPlugin(uuid);
      } catch (e, st) {
        logger.w('同步后清理插件 runtime 失败: $uuid', error: e, stackTrace: st);
      }
    }
    if (stoppingDownloads.isNotEmpty) await Future.wait(stoppingDownloads);

    for (final uuid in affected) {
      final plugin = current[uuid];
      if (plugin == null || !plugin.isActive) {
        continue;
      }

      final runtimeName = resolveRuntimeName(uuid);
      try {
        await ensurePluginRuntimeReady(plugin, runtimeName: runtimeName);
        await runPluginInitIfNeeded(plugin, runtimeName: runtimeName);
      } catch (e, st) {
        logger.w('同步后重建插件 runtime 失败: $uuid', error: e, stackTrace: st);
      }
    }
    logger.d(
      '[plugin-sync] reconcile_done active=${current.values.where((e) => e.isActive).length}',
    );
  }

  Future<void> initializeGlobalRuntime() async {
    const globalRuntimeName = 'global';
    final ready = await isQjsRuntimeInitialized(name: globalRuntimeName);
    if (!ready) {
      await buildQjsRuntime(
        request: const QjsRuntimeBuildRequest(
          runtimeName: globalRuntimeName,
          injectFilesystem: false,
        ),
      );
    }
  }

  Future<void> initializeActivePluginRuntimes() async {
    final plugins = updateCheckTargets()
        .where((plugin) => !_pluginInitDone.contains(plugin.uuid))
        .toList();
    if (plugins.isEmpty) {
      return;
    }

    await Future.wait(
      plugins.map((plugin) async {
        final runtimeName = resolveRuntimeName(plugin.uuid);
        try {
          await ensurePluginRuntimeReady(plugin, runtimeName: runtimeName);
          await runPluginInitIfNeeded(plugin, runtimeName: runtimeName);
        } catch (e, st) {
          logger.w(
            '插件 runtime 初始化失败: ${plugin.uuid}',
            error: e,
            stackTrace: st,
          );
        }
      }),
      eagerError: false,
    );
  }

  Future<void> warmupPluginInfos() async {
    await initializeGlobalRuntime();
    final plugins = _states.values.where((item) => !item.isDeleted).toList();
    await Future.wait(
      plugins.map((plugin) async {
        final runtimeName = resolveRuntimeName(plugin.uuid);
        try {
          await fetchPluginInfo(uuid: plugin.uuid, runtimeName: runtimeName);
        } catch (e) {
          await updateLoadResult(
            plugin.uuid,
            success: false,
            error: e.toString(),
          );
        }
      }),
      eagerError: false,
    );
  }

  Future<Map<String, dynamic>> fetchPluginInfo({
    required String uuid,
    required String runtimeName,
  }) async {
    final plugin = _states[uuid];
    if (plugin == null || plugin.isDeleted) {
      throw StateError('插件不可用: $uuid');
    }

    final onceRuntimeName = await ensureQjsRuntimeReady(
      pluginId: uuid,
      runtimeName: runtimeName,
      initialize: false,
    );
    final bundleUrl = plugin.debug ? plugin.debugUrl?.trim() : null;
    final bundleJs = bundleUrl?.isNotEmpty == true
        ? null
        : await loadQjsBundleJs(uuid);
    final bytes = await runWithPluginSessionRuntimeCall(
      onceRuntimeName,
      () => qjsTaskCall(
        runtimeName: onceRuntimeName,
        taskGroupKey: '',
        isOnce: true,
        bundleJs: bundleJs,
        bundleUrl: bundleUrl?.isNotEmpty == true ? bundleUrl : null,
        fnPath: 'getInfo',
        argsJson: '{}',
      ),
    );
    final raw = utf8.decode(bytes, allowMalformed: true);
    final decoded = requireJsonMap(jsonDecode(raw));
    // A released runtime can finish after a replacement has been installed.
    // Commit metadata together, only while it still belongs to this bundle.
    final current = _states[uuid];
    if (current == null || !_sameInfoSource(plugin, current)) {
      return decoded;
    }
    final found = _objectbox?.pluginInfoBox
        .query(PluginInfo_.uuid.equals(uuid))
        .build()
        .findFirst();
    if (found != null) {
      found.getInfoJson = jsonEncode(decoded);
      found.lastLoadSuccess = true;
      found.lastLoadError = null;
      found.updatedAt = DateTime.now().toUtc();
      _objectbox!.pluginInfoBox.put(found);
      _states[uuid] = _toState(found);
    }
    _pluginInfoCache[uuid] = decoded;
    _emit(uuid: uuid);
    return decoded;
  }

  bool _sameInfoSource(PluginRuntimeState a, PluginRuntimeState b) =>
      a.originScript == b.originScript &&
      a.version == b.version &&
      a.debug == b.debug &&
      a.debugUrl == b.debugUrl &&
      a.isEnabled == b.isEnabled &&
      a.isDeleted == b.isDeleted;

  /// 持久化 getInfo JSON 字符串到 ObjectBox（不清理 runtime / 内存 cache）。
  Future<void> persistGetInfoJson(String uuid, String getInfoJson) async {
    final objectbox = _objectbox;
    if (objectbox == null) {
      return;
    }
    final found = objectbox.pluginInfoBox
        .query(PluginInfo_.uuid.equals(uuid))
        .build()
        .findFirst();
    if (found == null) {
      return;
    }
    final normalized = getInfoJson.trim();
    if (found.getInfoJson == normalized) {
      return;
    }
    found.getInfoJson = normalized;
    // 仅缓存元数据，不改 updatedAt，避免触发无意义的同步冲突。
    objectbox.pluginInfoBox.put(found);
  }

  /// 读取已持久化的 getInfo JSON 字符串。
  String readPersistedGetInfoJson(String uuid) {
    final objectbox = _objectbox;
    if (objectbox == null) {
      return '';
    }
    final found = objectbox.pluginInfoBox
        .query(PluginInfo_.uuid.equals(uuid))
        .build()
        .findFirst();
    return found?.getInfoJson.trim() ?? '';
  }

  List<PluginRuntimeState> activePlugins() {
    return _states.values.where((item) => item.isActive).toList()
      ..sort((a, b) => a.insertedAt.compareTo(b.insertedAt));
  }

  /// 按用户自定义顺序返回插件；旧记录或新插件回退到安装时间。
  List<PluginRuntimeState> sortPlugins(Iterable<PluginRuntimeState> plugins) {
    final result = plugins.toList();
    result.sort(_comparePluginOrder);
    return result;
  }

  List<PluginRuntimeState> orderedPlugins({bool includeDeleted = false}) {
    return sortPlugins(
      _states.values.where((plugin) => includeDeleted || !plugin.isDeleted),
    );
  }

  Future<void> reorderPlugins(List<String> orderedUuids) async {
    final objectbox = _objectbox;
    if (objectbox == null) {
      return;
    }

    final visible = orderedPlugins();
    final visibleByUuid = <String, PluginRuntimeState>{
      for (final plugin in visible) plugin.uuid: plugin,
    };
    final normalizedUuids = <String>[];
    final seen = <String>{};
    for (final uuid in orderedUuids) {
      if (visibleByUuid.containsKey(uuid) && seen.add(uuid)) {
        normalizedUuids.add(uuid);
      }
    }
    for (final plugin in visible) {
      if (seen.add(plugin.uuid)) {
        normalizedUuids.add(plugin.uuid);
      }
    }

    final infos = objectbox.pluginInfoBox.getAll();
    final infoByUuid = <String, PluginInfo>{
      for (final info in infos)
        if (!info.isDeleted && info.uuid.trim().isNotEmpty) info.uuid: info,
    };
    final now = DateTime.now().toUtc();
    var changed = false;
    for (var index = 0; index < normalizedUuids.length; index++) {
      final info = infoByUuid[normalizedUuids[index]];
      if (info == null || info.sortOrder == index) {
        continue;
      }
      info.sortOrder = index;
      info.updatedAt = now;
      objectbox.pluginInfoBox.put(info);
      _states[info.uuid] = _toState(info);
      changed = true;
    }
    if (changed) {
      _emit();
    }
  }

  Future<void> resetPluginOrder() async {
    final objectbox = _objectbox;
    if (objectbox == null) {
      return;
    }

    final infos = objectbox.pluginInfoBox
        .getAll()
        .where((info) => !info.isDeleted && info.sortOrder != null)
        .toList();
    if (infos.isEmpty) {
      return;
    }

    final now = DateTime.now().toUtc();
    for (final info in infos) {
      info.sortOrder = null;
      info.updatedAt = now;
      objectbox.pluginInfoBox.put(info);
      _states[info.uuid] = _toState(info);
    }
    _emit();
  }

  List<PluginRuntimeState> updateCheckTargets() {
    return activePlugins();
  }

  Future<void> runForUpdateTargets(
    Future<void> Function(PluginRuntimeState plugin) task,
  ) async {
    final targets = updateCheckTargets();
    for (final plugin in targets) {
      await task(plugin);
    }
  }

  List<String> getEnabledUuids() {
    return _states.values
        .where((item) => item.isEnabled && !item.isDeleted)
        .map((item) => item.uuid)
        .toList();
  }

  int getActivePluginCount() {
    return _states.values.where((item) => item.isActive).length;
  }

  bool isAnyPluginEnabled() {
    return _states.values.any((item) => item.isActive);
  }

  List<PluginRuntimeState> getSortedActivePlugins() {
    return activePlugins();
  }

  Future<void> upsert(PluginInfo info, {bool notify = true}) async {
    final objectbox = _objectbox;
    if (objectbox == null) {
      return;
    }

    objectbox.pluginInfoBox.put(info);
    _states[info.uuid] = _toState(info);
    _pluginInfoCache.remove(info.uuid);
    _pluginInitDone.remove(info.uuid);
    if (notify) _emit(uuid: info.uuid);
  }

  /// Installs a replacement and settles its runtime before publishing it.
  /// The hold starts synchronously, before upsert can yield to stream listeners.
  Future<void> upsertAndSetEnabled(
    PluginInfo info, {
    bool initialize = true,
    bool explicitInstallation = false,
    int? expectedInstallationEpoch,
    bool Function(PluginInfo?)? matchesCurrentInstallation,
  }) async {
    // Reject unsupported replacements before leases, runtime ownership or
    // publication change. Deleted metadata is permitted by the shared check.
    PluginHostCompatibility.requireCompatiblePluginInfo(info.toJson());
    final local = LocalPluginInstallationState.instance;
    final installLease = explicitInstallation
        ? local.beginExplicitInstallation(info.uuid)
        : null;
    Future<void> install() async {
      if (expectedInstallationEpoch != null &&
          local.installationEpoch(info.uuid) != expectedInstallationEpoch) {
        throw const PluginLifecycleChanged();
      }
      final box = _objectbox;
      if (box == null) throw StateError('Plugin registry is unavailable');
      final wasRemoved = isLocallyRemoved(info.uuid);
      final previous = box.pluginInfoBox
          .getAll()
          .where((row) => row.uuid == info.uuid)
          .firstOrNull;
      // A silent update can replace the bundle without changing the install
      // epoch. Compare the candidate's original target inside the write queue.
      if (matchesCurrentInstallation?.call(previous) == false) {
        throw const PluginLifecycleChanged();
      }
      final ownedNames = _buildPluginConfigNameCandidates(info.uuid);
      final previousConfigs = box.pluginConfigBox
          .getAll()
          .where((row) => ownedNames.contains(row.name.trim()))
          .toList();
      final before = <String, dynamic>{}, expected = <String, dynamic>{};
      Future<void> beforePreferenceWrite(Map<String, dynamic> updates) async {
        final prefs = await SharedPreferences.getInstance();
        for (final entry in updates.entries) {
          before.putIfAbsent(entry.key, () => prefs.get(entry.key));
          expected[entry.key] = entry.value;
        }
      }

      _holdPublication(info.uuid);
      try {
        if (wasRemoved && !explicitInstallation) {
          throw StateError('Plugin is not installed on this device');
        }
        if (explicitInstallation) _explicitInstallations.add(info.uuid);
        if (previous != null &&
            (previous.originScript != info.originScript ||
                previous.version != info.version)) {
          invalidateQjsRuntimeForPluginReplacement(info.uuid);
        }
        await upsert(info, notify: false);
        await setEnabled(info.uuid, info.isEnabled, initialize: initialize);
        if (explicitInstallation) {
          // Installation does not undo a separately confirmed personal-data
          // clear. Record/config tombstones and device data masks remain until
          // the user explicitly restores data; only installation is changed.
          await local.completeExplicitInstallation(
            info.uuid,
            beforeWrite: beforePreferenceWrite,
          );
          final current = box.pluginInfoBox
              .getAll()
              .where((row) => row.uuid == info.uuid)
              .firstOrNull;
          if (current != null) _states[info.uuid] = _toState(current);
        }
      } catch (_) {
        // Both store updates and explicit installs must restore the last
        // published script/config when preparing the replacement fails.
        try {
          await dropQjsRuntimesForPlugin(info.uuid);
        } catch (_) {}
        box.store.runInTransaction(TxMode.write, () {
          box.pluginInfoBox.removeMany(
            box.pluginInfoBox
                .getAll()
                .where((row) => row.uuid == info.uuid)
                .map((row) => row.id)
                .toList(),
          );
          if (previous != null) box.pluginInfoBox.put(previous);
          box.pluginConfigBox.removeMany(
            box.pluginConfigBox
                .getAll()
                .where((row) => ownedNames.contains(row.name.trim()))
                .map((row) => row.id)
                .toList(),
          );
          box.pluginConfigBox.putMany(previousConfigs);
        });
        final prefs = await SharedPreferences.getInstance();
        for (final entry in before.entries) {
          if (jsonEncode(prefs.get(entry.key)) !=
              jsonEncode(expected[entry.key])) {
            continue;
          }
          final bool saved = switch (entry.value) {
            null => await prefs.remove(entry.key),
            String v => await prefs.setString(entry.key, v),
            bool v => await prefs.setBool(entry.key, v),
            int v => await prefs.setInt(entry.key, v),
            double v => await prefs.setDouble(entry.key, v),
            List v => await prefs.setStringList(entry.key, v.cast<String>()),
            _ => false,
          };
          if (!saved) {
            throw StateError('Plugin installation rollback was not saved');
          }
        }
        await local.reload();
        if (before.isNotEmpty) {
          await PortablePreferences.notifyRestored(keys: before.keys.toSet());
        }
        _explicitInstallations.remove(info.uuid);
        _pluginInfoCache.remove(info.uuid);
        _pluginInitDone.remove(info.uuid);
        if (previous != null) {
          _states[info.uuid] = _toState(previous);
        } else {
          _states.remove(info.uuid);
        }
        rethrow;
      } finally {
        _explicitInstallations.remove(info.uuid);
        _releasePublication(info.uuid);
      }
    }

    try {
      if (explicitInstallation) {
        await runExclusiveStorageOperation(install);
      } else {
        await install();
      }
    } finally {
      installLease?.release();
    }
  }

  Future<void> setEnabled(
    String uuid,
    bool enabled, {
    bool initialize = true,
  }) async {
    final objectbox = _objectbox;
    if (objectbox == null) {
      return;
    }
    if (isLocallyRemoved(uuid) && !_explicitInstallations.contains(uuid)) {
      throw StateError('Plugin is not installed on this device');
    }
    final found = objectbox.pluginInfoBox
        .query(PluginInfo_.uuid.equals(uuid))
        .build()
        .findFirst();
    if (found == null) {
      return;
    }
    _holdPublication(uuid);
    try {
      found.isEnabled = enabled;
      found.updatedAt = DateTime.now().toUtc();
      objectbox.pluginInfoBox.put(found);
      _states[uuid] = _toState(found);
      _pluginInfoCache.remove(uuid);
      _pluginInitDone.remove(uuid);
      final runtimeName = resolveRuntimeName(uuid);
      if (enabled && initialize) {
        await ensurePluginRuntimeReady(
          _states[uuid]!,
          runtimeName: runtimeName,
        );
        await runPluginInitIfNeeded(_states[uuid]!, runtimeName: runtimeName);
        try {
          await fetchPluginInfo(uuid: uuid, runtimeName: runtimeName);
        } catch (e, st) {
          logger.w('启用插件后刷新 info 失败: $uuid', error: e, stackTrace: st);
        }
      } else {
        Future<void> dropRuntime() async {
          try {
            await dropQjsRuntimesForPlugin(uuid);
          } catch (e, st) {
            logger.w('禁用插件时释放 runtime 失败: $uuid', error: e, stackTrace: st);
          }
        }

        await Future.wait([
          if (!enabled)
            DownloadQueueManager.instance.stopSourceRetainingFiles(
              uuid,
              disabling: true,
            ),
          dropRuntime(),
        ]);
      }
    } finally {
      _releasePublication(uuid);
    }
  }

  Future<void> updateLoadResult(
    String uuid, {
    required bool success,
    String? error,
  }) async {
    final objectbox = _objectbox;
    if (objectbox == null) {
      return;
    }
    final found = objectbox.pluginInfoBox
        .query(PluginInfo_.uuid.equals(uuid))
        .build()
        .findFirst();
    if (found == null) {
      return;
    }
    found.lastLoadSuccess = success;
    found.lastLoadError = error;
    found.updatedAt = DateTime.now().toUtc();
    objectbox.pluginInfoBox.put(found);
    _states[uuid] = _toState(found);
    _emit(uuid: uuid);
  }

  Future<void> updateDebugConfig(
    String uuid, {
    required bool debug,
    String? debugUrl,
  }) async {
    final objectbox = _objectbox;
    if (objectbox == null) {
      return;
    }
    final found = objectbox.pluginInfoBox
        .query(PluginInfo_.uuid.equals(uuid))
        .build()
        .findFirst();
    if (found == null) {
      return;
    }
    found.debug = debug;
    found.debugUrl = debugUrl?.trim().isEmpty == true ? null : debugUrl?.trim();
    found.updatedAt = DateTime.now().toUtc();
    objectbox.pluginInfoBox.put(found);
    _states[uuid] = _toState(found);
    _pluginInitDone.remove(uuid);
    _emit(uuid: uuid);
    // 用 debug bundle / DB bundle 后台刷新 getInfo（内存 + getInfoJson），
    // 让详情页/书架/搜索的插件名跟上调试中的脚本；不阻塞返回，
    // 失败时保留旧名字（getCachedPluginInfo 会用 persisted getInfo 兜底）。
    unawaited(() async {
      try {
        await fetchPluginInfo(uuid: uuid, runtimeName: uuid);
      } catch (e, st) {
        logger.w('调试配置更新后刷新 getInfo 失败: $uuid', error: e, stackTrace: st);
      }
    }());
  }

  /// Personal-data clearing is independent of installation. Temporarily refuse
  /// new source work, settle workers, then let the journal owner change data.
  /// Neither success nor failure changes this device's installation marker.
  Future<T> withStoppedRuntime<T>(
    String uuid, {
    required int expectedInstallationEpoch,
    required Future<T> Function() action,
  }) async {
    final box = _objectbox;
    if (box == null) throw StateError('Plugin registry is unavailable');
    final local = LocalPluginInstallationState.instance;
    void guard() {
      if (local.installationEpoch(uuid) != expectedInstallationEpoch ||
          local.isInstalling(uuid)) {
        throw const PluginLifecycleChanged();
      }
    }

    guard();
    _holdPublication(uuid);
    local.beginRemoval(uuid);
    try {
      await DownloadQueueManager.instance.stopSourceRetainingFiles(uuid);
      await VideoSystemDownload.stopSource(uuid);
      return await runExclusiveStorageOperation(() async {
        guard();
        await dropQjsRuntimesForPlugin(uuid);
        guard();
        _pluginInfoCache.remove(uuid);
        _pluginInitDone.remove(uuid);
        return action();
      });
    } finally {
      local.endRemoval(uuid);
      final current = box.pluginInfoBox
          .getAll()
          .where((row) => row.uuid == uuid)
          .firstOrNull;
      if (current != null) _states[uuid] = _toState(current);
      _releasePublication(uuid);
    }
  }

  Future<void> deletePlugin(
    String uuid, {
    int? expectedInstallationEpoch,
  }) async {
    final objectbox = _objectbox;
    if (objectbox == null) {
      return;
    }
    final found = objectbox.pluginInfoBox
        .query(PluginInfo_.uuid.equals(uuid))
        .build()
        .findFirst();
    if (found == null) {
      throw StateError('插件不存在: $uuid');
    }

    final local = LocalPluginInstallationState.instance;
    final epoch = local.installationEpoch(uuid);
    if ((expectedInstallationEpoch != null &&
            epoch != expectedInstallationEpoch) ||
        local.isInstalling(uuid)) {
      throw const PluginLifecycleChanged();
    }
    _holdPublication(uuid);
    local.beginRemoval(uuid);
    try {
      await DownloadQueueManager.instance.stopSourceRetainingFiles(uuid);
      await VideoSystemDownload.stopSource(uuid);
      await runExclusiveStorageOperation(() async {
        if (local.installationEpoch(uuid) != epoch ||
            local.isInstalling(uuid)) {
          throw const PluginLifecycleChanged();
        }
        await dropQjsRuntimesForPlugin(uuid);
        if (local.installationEpoch(uuid) != epoch ||
            local.isInstalling(uuid)) {
          throw const PluginLifecycleChanged();
        }
        await local.markRemoved(
          uuid,
          revision: found.updatedAt.millisecondsSinceEpoch,
          expectedEpoch: epoch,
        );
      });
      final latest = objectbox.pluginInfoBox.get(found.id) ?? found;
      _states[uuid] = _toState(latest);
      _pluginInfoCache.remove(uuid);
      _pluginInitDone.remove(uuid);
    } finally {
      local.endRemoval(uuid);
      final latest = objectbox.pluginInfoBox.get(found.id);
      if (latest != null) _states[uuid] = _toState(latest);
      _releasePublication(uuid);
    }
  }

  Set<String> _buildPluginConfigNameCandidates(String uuid) {
    final candidates = <String>{};
    for (final raw in <String>{uuid, resolveRuntimeName(uuid)}) {
      for (final normalized in _normalizePluginNameCandidates(raw)) {
        candidates.add(normalized);
        candidates.add('($normalized)');
        final onceRuntime = 'plugin_info_${normalized.replaceAll('-', '_')}';
        candidates.add(onceRuntime);
        candidates.add('($onceRuntime)');
      }
    }
    return candidates.where((item) => item.trim().isNotEmpty).toSet();
  }

  Set<String> _normalizePluginNameCandidates(String raw) {
    final names = <String>{};
    var value = raw.trim();
    if (value.isEmpty) {
      return names;
    }
    names.add(value);

    while (value.length >= 2 && value.startsWith('(') && value.endsWith(')')) {
      value = value.substring(1, value.length - 1).trim();
      if (value.isEmpty) {
        break;
      }
      names.add(value);
    }

    return names;
  }

  String resolveRuntimeName(String uuid) => canonicalQjsSource(uuid);

  Future<void> ensurePluginRuntimeReady(
    PluginRuntimeState plugin, {
    required String runtimeName,
  }) async {
    await ensureQjsRuntimeReady(
      pluginId: plugin.uuid,
      runtimeName: runtimeName,
      forceReload: true,
      initialize: false,
    );
    _pluginInitDone.remove(plugin.uuid);
  }

  Future<void> runPluginInitIfNeeded(
    PluginRuntimeState plugin, {
    required String runtimeName,
  }) async {
    if (_pluginInitDone.contains(plugin.uuid)) {
      return;
    }

    final generation = pluginSessionWriteFence.generation(plugin.uuid);
    bool ownsCurrentBundle() {
      final current = _states[plugin.uuid];
      return current != null &&
          _sameInfoSource(plugin, current) &&
          pluginSessionWriteFence.generation(plugin.uuid) == generation;
    }

    // Preserve asynchronous startup, but never let an old init own a new
    // script's status or start work after its replacement has been installed.
    Future(() async {
      if (!ownsCurrentBundle()) return;
      try {
        await ensureQjsRuntimeReady(
          pluginId: plugin.uuid,
          runtimeName: runtimeName,
          sessionGeneration: generation,
        );
        if (!ownsCurrentBundle()) return;
        _pluginInitDone.add(plugin.uuid);
        await updateLoadResult(plugin.uuid, success: true, error: null);
      } catch (e) {
        if (!ownsCurrentBundle()) return;
        final err = e.toString();
        if (err.contains('target is not function: init')) {
          _pluginInitDone.add(plugin.uuid);
          logger.w('插件未实现 init，已跳过: ${plugin.uuid}');
          return;
        }
        await updateLoadResult(
          plugin.uuid,
          success: false,
          error: 'init 执行失败: $e',
        );
        logger.w('插件 init 执行失败: ${plugin.uuid}', error: e);
      }
    }).catchError((e) {
      logger.w('插件 init 异步执行失败: ${plugin.uuid}', error: e);
    });
  }

  PluginRuntimeState _toState(PluginInfo item) {
    final removedHere =
        !_explicitInstallations.contains(item.uuid) &&
        LocalPluginInstallationState.instance.isRemoved(item.uuid);
    return PluginRuntimeState(
      uuid: item.uuid,
      version: item.version,
      originScript: item.originScript,
      isEnabled: item.isEnabled && !removedHere,
      isDeleted: item.isDeleted || removedHere,
      debug: item.debug,
      debugUrl: item.debugUrl,
      lastLoadSuccess: item.lastLoadSuccess,
      lastLoadError: item.lastLoadError,
      sortOrder: item.sortOrder,
      insertedAt: item.insertedAt,
      updatedAt: item.updatedAt,
      deletedAt: item.deletedAt,
    );
  }

  void _holdPublication(String uuid) {
    final held = _publicationHolds[uuid];
    _publicationHolds[uuid] = (
      depth: (held?.depth ?? 0) + 1,
      previous: held == null ? _states[uuid] : held.previous,
    );
  }

  void _releasePublication(String uuid) {
    final held = _publicationHolds[uuid]!;
    if (held.depth > 1) {
      _publicationHolds[uuid] = (
        depth: held.depth - 1,
        previous: held.previous,
      );
      return;
    }
    _publicationHolds.remove(uuid);
    _emit(uuid: uuid);
  }

  void _emit({String? uuid}) {
    if (uuid != null && _publicationHolds.containsKey(uuid)) return;
    _streamController.add(snapshot);
  }

  int _comparePluginOrder(PluginRuntimeState a, PluginRuntimeState b) {
    final aOrder = a.sortOrder;
    final bOrder = b.sortOrder;
    if (aOrder != null && bOrder != null && aOrder != bOrder) {
      return aOrder.compareTo(bOrder);
    }
    if (aOrder != null && bOrder == null) {
      return -1;
    }
    if (aOrder == null && bOrder != null) {
      return 1;
    }

    final insertedCompare = a.insertedAt.compareTo(b.insertedAt);
    if (insertedCompare != 0) {
      return insertedCompare;
    }
    return a.uuid.compareTo(b.uuid);
  }
}
