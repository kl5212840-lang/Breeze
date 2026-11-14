import 'package:zephyr/network/routing/routing_runtime_capture.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/page/video/video_download_resolution.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cbor/simple.dart' as cbor;
import 'package:zephyr/main.dart';
import 'package:zephyr/network/playback_trace.dart';
import 'package:zephyr/network/http/plugin/qjs_fetch_image_result.dart';
import 'package:zephyr/network/http/plugin/qjs_network_route.dart';
import 'package:zephyr/network/source_network_policy.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/service/download/download_cancel_signal.dart';
import 'package:zephyr/src/rust/api/qjs.dart';
import 'package:zephyr/src/rust/qjs.dart';

final _trackedRuntimesByGroup = QjsTaskRuntimeReferences();
final _networkRoutes = QjsNetworkRouteStore();
final Set<String> _runtimeInitDone = <String>{};
final _runtimePreparation = <String, Future<void>>{};
final _runtimeInitialization = <String, Future<void>>{};
final _sessionRuntimes = <String, Set<String>>{};
final _sessionCalls = <String, int>{};
final _sessionRetirementPending = <String>{};
final _retiringSessionRuntimes = <String, Future<void>>{};
final _sessionOperationKey = Object();

/// Uses the active chapter's pinned transport, rather than a newly selected
/// source route. System background sessions cannot reproduce a custom proxy.
Future<bool> downloadTaskUsesDirectNetwork(
  String source,
  String taskKey,
) async =>
    (await _networkRoutes.resolve(source, taskGroupKey: taskKey)).proxy.isEmpty;

int _sessionOperationOwner(String source) =>
    (Zone.current[_sessionOperationKey] as Map<String, int>?)?[source] ??
    pluginSessionWriteFence.generation(source);

void _requireSessionOwner(String source, int owner) {
  if (pluginSessionWriteFence.generation(source) != owner) {
    throw const PluginSessionChanged();
  }
}

void _requireCurrentSessionRuntime(String runtime) {
  final source = canonicalQjsSource(runtime);
  _requireSessionOwner(source, _sessionOperationOwner(source));
  if (!pluginSessionWriteFence.permits(source, runtime)) {
    throw const PluginSessionChanged();
  }
}

void _retainSessionRuntime(String runtime) =>
    _sessionCalls[runtime] = (_sessionCalls[runtime] ?? 0) + 1;

void _releaseSessionRuntime(String runtime) {
  final count = (_sessionCalls[runtime] ?? 1) - 1;
  if (count > 0) {
    _sessionCalls[runtime] = count;
  } else {
    _sessionCalls.remove(runtime);
  }
  unawaited(_retireSessionRuntimes(canonicalQjsSource(runtime)));
}

Future<void> _retireSessionRuntimes(String source) async {
  if (!_sessionRetirementPending.contains(source)) return;
  for (final runtime in {...?_sessionRuntimes[source]}) {
    if (pluginSessionWriteFence.permits(source, runtime) ||
        (_sessionCalls[runtime] ?? 0) > 0 ||
        _runtimePreparation.containsKey(runtime) ||
        _runtimeInitialization.containsKey(runtime))
      continue;
    if (_retiringSessionRuntimes.containsKey(runtime)) continue;
    final task = () async {
      try {
        // A retired VM is dropped only after host-tracked calls settle. Active
        // downloads retain their runtime and their successful result/bytes.
        if (await isQjsRuntimeInitialized(name: runtime)) {
          if ((_sessionCalls[runtime] ?? 0) > 0) return;
          await qjsDropRuntime(runtimeName: runtime);
        }
        _runtimeInitDone.remove(runtime);
        _sessionRuntimes[source]?.remove(runtime);
      } catch (_) {
        // A later lifecycle/dispatch retries retirement; never fail the new
        // account operation because old runtime disposal was unavailable.
      }
    }();
    _retiringSessionRuntimes[runtime] = task;
    await task;
    if (identical(_retiringSessionRuntimes[runtime], task)) {
      _retiringSessionRuntimes.remove(runtime);
    }
  }
  if ((_sessionRuntimes[source] ?? {}).every(
    (runtime) => pluginSessionWriteFence.permits(source, runtime),
  )) {
    _sessionRetirementPending.remove(source);
  }
}

Future<T> runWithPluginSessionRuntimeCall<T>(
  String runtime,
  Future<T> Function() action,
) async {
  _requireCurrentSessionRuntime(runtime);
  _retainSessionRuntime(runtime);
  try {
    return await action();
  } finally {
    _releaseSessionRuntime(runtime);
  }
}

/// A script replacement changes ownership without touching persistent data.
/// Tracked calls can finish; their retired VM can no longer save source config.
void invalidateQjsRuntimeForPluginReplacement(String pluginId) {
  final source = normalizePluginId(pluginId);
  pluginSessionWriteFence.advance(source);
  _sessionRetirementPending.add(source);
  // Preparing the new VM (or explicit drop) retires old runtimes. Starting
  // disposal here would race the same lifecycle's initialize:false drop.
}

Future<T> runPluginSessionChange<T>(
  String source,
  Future<T> Function() action,
) async {
  source = normalizePluginId(source);
  _requireSessionOwner(source, _sessionOperationOwner(source));
  final inheritedOwner =
      (Zone.current[_sessionOperationKey] as Map<String, int>?)?[source];
  if (inheritedOwner != null) {
    // A profile switch owns the complete login + authenticated readback. A
    // nested declared login must not invalidate that same transaction owner.
    _requireSessionOwner(source, inheritedOwner);
    final result = await action();
    _requireSessionOwner(source, inheritedOwner);
    return result;
  }
  final owner = pluginSessionWriteFence.beginSessionChange(source);
  _sessionRetirementPending.add(source);
  try {
    final inherited = Zone.current[_sessionOperationKey] as Map<String, int>?;
    final result = await runZoned(
      action,
      zoneValues: {
        _sessionOperationKey: {...?inherited, source: owner},
      },
    );
    if (pluginSessionWriteFence.generation(source) != owner) {
      throw const PluginSessionChanged();
    }
    return result;
  } finally {
    // Seal the operation VM too: init can leave a detached login promise even
    // when the explicit clear/login call itself has already returned.
    pluginSessionWriteFence.seal(source, owner);
    _sessionRetirementPending.add(source);
    unawaited(_retireSessionRuntimes(source));
  }
}

bool _baseErrorStack = false;
int _playbackErrorStackUsers = 0;

/// Preserve the user's development/remote-log setting when a playback capture
/// temporarily enables JS stack traces. Overlapping attempts share ownership.
void setQjsBaseErrorStack({required bool enabled}) {
  _baseErrorStack = enabled;
  setQjsErrorStackEnabled(enabled: enabled || _playbackErrorStackUsers > 0);
}

String runtimeNameForPluginId(String pluginIdOrLegacy) =>
    normalizePluginId(pluginIdOrLegacy);

String normalizePluginId(String raw) => canonicalQjsSource(raw);

String _buildTaskGroupId(String pluginId, String taskGroupKey) =>
    '${normalizePluginId(pluginId)}::$taskGroupKey';

Future<T> runWithQjsTaskGroupNetwork<T>({
  required String pluginId,
  required String taskGroupKey,
  required Future<T> Function() action,
}) => SourceNetworkPolicies.supports(normalizePluginId(pluginId))
    ? _networkRoutes.runTaskGroup(
        source: normalizePluginId(pluginId),
        taskGroupKey: taskGroupKey,
        action: action,
      )
    : action();

/// Releases the route pinned by a caller-owned request group.
void releaseQjsTaskGroupNetwork(String source, String taskGroupKey) {
  _networkRoutes.releaseGroup(source, taskGroupKey);
}

/// Creates a source's immutable runtime before any normal or one-shot I/O.
/// Runtime aliases resolve through the current visit; download scopes pin work.
Future<String> ensureQjsRuntimeReady({
  required String pluginId,
  String? runtimeName,
  SourceNetworkSnapshot? network,
  bool forceReload = false,
  bool initialize = true,
  int? sessionGeneration,
}) async {
  final source = normalizePluginId(pluginId);
  final owner = sessionGeneration ?? _sessionOperationOwner(source);
  _requireSessionOwner(source, owner);
  final snapshot = !SourceNetworkPolicies.supports(source)
      ? null
      : network ??
            await _networkRoutes.resolve(source, runtimeName: runtimeName);
  _requireSessionOwner(source, owner);
  final actual = pluginSessionWriteFence.runtime(
    source,
    snapshot?.runtimeName ?? runtimeName ?? source,
  );
  _sessionRuntimes.putIfAbsent(source, () => {}).add(actual);
  final existing = _runtimePreparation[actual];
  if (existing != null) {
    await existing;
    _requireSessionOwner(source, owner);
    if (forceReload) {
      return ensureQjsRuntimeReady(
        pluginId: source,
        runtimeName: runtimeName,
        network: snapshot,
        forceReload: true,
        initialize: initialize,
        sessionGeneration: owner,
      );
    }
    if (initialize && source != 'global' && !_shouldUseQjsCallOnce(source)) {
      await _runRuntimeInitIfNeeded(actual);
      _requireSessionOwner(source, owner);
    }
    return actual;
  }
  final operation = () async {
    final debug = _shouldUseQjsCallOnce(source);
    final ready = await isQjsRuntimeInitialized(name: actual);
    _requireSessionOwner(source, owner);
    String? currentBundle;
    if (ready && !debug && !forceReload) {
      try {
        currentBundle =
            jsonDecode(await qjsCurrentBundle(runtimeName: actual)) as String?;
      } catch (_) {}
      _requireSessionOwner(source, owner);
    }
    if (!ready || forceReload || (!debug && (currentBundle?.isEmpty ?? true))) {
      final script = debug || source == 'global'
          ? null
          : await loadQjsBundleJs(source);
      _requireSessionOwner(source, owner);
      await buildQjsRuntime(
        request: QjsRuntimeBuildRequest(
          runtimeName: actual,
          injectFilesystem: false,
          networkProxy: snapshot?.proxy,
          bundle: script == null
              ? null
              : QjsRuntimeBundleBuild(bundleName: actual, bundleJs: script),
        ),
      );
      _requireSessionOwner(source, owner);
      _runtimeInitDone.remove(actual);
    }
  }();
  _runtimePreparation[actual] = operation;
  try {
    await operation;
    _requireSessionOwner(source, owner);
  } finally {
    if (identical(_runtimePreparation[actual], operation)) {
      _runtimePreparation.remove(actual);
      unawaited(_retireSessionRuntimes(source));
    }
  }
  if (initialize && source != 'global' && !_shouldUseQjsCallOnce(source)) {
    await _runRuntimeInitIfNeeded(actual);
    _requireSessionOwner(source, owner);
  }
  return actual;
}

/// Explicit plugin disable/update/removal releases every known generation.
/// Saving network preferences does not invoke this and leaves active work alone.
Future<void> dropQjsRuntimesForPlugin(String pluginId) async {
  final source = normalizePluginId(pluginId);
  pluginSessionWriteFence.advance(source);
  _sessionRetirementPending.add(source);
  final names = {
    source,
    ..._networkRoutes.runtimeNames(source),
    ...?_sessionRuntimes[source],
  };
  for (final runtime in names) {
    final preparing = _runtimePreparation[runtime];
    if (preparing != null) {
      try {
        await preparing;
      } catch (_) {}
    }
    if (await isQjsRuntimeInitialized(name: runtime)) {
      await qjsDropRuntime(runtimeName: runtime);
    }
    _runtimeInitDone.remove(runtime);
    _sessionRuntimes[source]?.remove(runtime);
  }
}

Future<void> _runRuntimeInitIfNeeded(String runtimeName) {
  _requireCurrentSessionRuntime(runtimeName);
  if (_runtimeInitDone.contains(runtimeName)) return Future.value();
  return _runtimeInitialization.putIfAbsent(
    runtimeName,
    () => _initializeRuntime(runtimeName).whenComplete(() {
      _runtimeInitialization.remove(runtimeName);
      unawaited(_retireSessionRuntimes(canonicalQjsSource(runtimeName)));
    }),
  );
}

Future<void> _initializeRuntime(String runtimeName) async {
  _requireCurrentSessionRuntime(runtimeName);
  if (_runtimeInitDone.contains(runtimeName)) {
    return;
  }
  _retainSessionRuntime(runtimeName);
  try {
    await qjsTaskCall(
      runtimeName: runtimeName,
      taskGroupKey: '',
      isOnce: false,
      fnPath: 'init',
      argsJson: '{}',
    );
    _runtimeInitDone.add(runtimeName);
  } catch (e) {
    if (e.toString().contains('target is not function: init')) {
      _runtimeInitDone.add(runtimeName);
      return;
    }
    logger.w('插件 init 执行失败: $runtimeName', error: e);
    rethrow;
  } finally {
    _releaseSessionRuntime(runtimeName);
  }
}

/// 统一执行插件 JS 任务,返回原始字节。
///
/// 内部按需走常驻 bundle(非 once)或一次性 debug 池(once,`bundleUrl`/`bundleJs` 二选一),
/// 并维护取消用的 runtime 跟踪。
Future<T> _runQjsTask<T>({
  required String pluginId,
  required String fnPath,
  required String argsJson,
  String? runtimeName,
  String? taskGroupKey,
  bool requireCurrentResult = false,
  required Future<T> Function({
    required String runtimeName,
    required String taskGroupKey,
    required bool isOnce,
    String? bundleJs,
    String? bundleUrl,
    required String fnPath,
    required String argsJson,
  })
  call,
}) async {
  if (taskGroupKey != null && taskGroupKey.isNotEmpty) {
    if (isDownloadCancelSignaled(taskGroupKey)) {
      throw const DownloadTaskCancelledException();
    }
  }

  final normalizedPluginId = normalizePluginId(pluginId);
  final resolvedPluginId = normalizedPluginId.isNotEmpty
      ? normalizedPluginId
      : normalizePluginId(runtimeName ?? '');
  if (resolvedPluginId.isEmpty) {
    throw StateError('pluginId/runtimeName 不能为空');
  }
  final resolvedFnPath = fnPath.trim();
  if (resolvedFnPath.isEmpty) {
    throw StateError('fnPath 不能为空: pluginId=$resolvedPluginId');
  }

  final sessionOwner = _sessionOperationOwner(resolvedPluginId);
  _requireSessionOwner(resolvedPluginId, sessionOwner);
  final candidateOwner = VideoDownloadResolutionOwner.current;
  final resolutionOwner =
      candidateOwner != null &&
          canonicalQjsSource(candidateOwner.source) == resolvedPluginId
      ? candidateOwner
      : null;
  resolutionOwner?.check();
  final group =
      resolutionOwner?.token ??
      (taskGroupKey?.isNotEmpty == true
          ? taskGroupKey
          : _networkRoutes.currentTaskGroup(resolvedPluginId));
  PlaybackTrace.note(
    resolvedPluginId,
    'qjs_route',
    'resolve fn=$resolvedFnPath',
  );
  final network = !SourceNetworkPolicies.supports(resolvedPluginId)
      ? null
      : await _networkRoutes.resolve(
          resolvedPluginId,
          runtimeName: runtimeName,
          taskGroupKey: group,
        );
  _requireSessionOwner(resolvedPluginId, sessionOwner);
  PlaybackTrace.note(
    resolvedPluginId,
    'qjs_runtime',
    'prepare; proxy=${network?.proxy.isNotEmpty == true}',
  );
  final resolvedRuntimeName = await ensureQjsRuntimeReady(
    pluginId: resolvedPluginId,
    runtimeName: runtimeName,
    network: network,
    sessionGeneration: sessionOwner,
  );
  _requireSessionOwner(resolvedPluginId, sessionOwner);
  resolutionOwner?.check();
  if (group != null && group.isNotEmpty && isDownloadCancelSignaled(group)) {
    throw const DownloadTaskCancelledException();
  }

  final useCallOnce = _shouldUseQjsCallOnce(resolvedPluginId);
  PlaybackTrace.note(
    resolvedPluginId,
    'qjs_runtime',
    'ready; once=$useCallOnce',
  );
  final debugBundleUrl = useCallOnce
      ? loadQjsDebugBundleUrl(resolvedPluginId)
      : null;
  final bundleJs = useCallOnce && debugBundleUrl == null
      ? await loadQjsBundleJs(resolvedPluginId)
      : null;

  // QJS 结果通过 FRB 返回，避免 Dart 与 Rust 共享堆内存。
  _requireSessionOwner(resolvedPluginId, sessionOwner);
  if (!pluginSessionWriteFence.permits(resolvedPluginId, resolvedRuntimeName)) {
    throw const PluginSessionChanged();
  }
  resolutionOwner?.check();
  if (group != null && group.isNotEmpty && isDownloadCancelSignaled(group)) {
    throw const DownloadTaskCancelledException();
  }
  final removeResolutionCancel = resolutionOwner?.onCancel(() async {
    if (group == null) return;
    triggerDownloadCancelSignal(group);
    await cancelTrackedQjsTasks(
      pluginId: resolvedPluginId,
      taskGroupKey: group,
    );
  });
  if (resolutionOwner != null && group != null) {
    resolutionOwner.onClose(() {
      _networkRoutes.releaseGroup(resolvedPluginId, group);
      clearDownloadCancelSignal(group);
    });
  }
  _retainSessionRuntime(resolvedRuntimeName);
  final waitFuture =
      Future<T>.sync(
        () => call(
          runtimeName: resolvedRuntimeName,
          taskGroupKey: group ?? '',
          isOnce: useCallOnce,
          bundleJs: bundleJs,
          bundleUrl: debugBundleUrl,
          fnPath: resolvedFnPath,
          argsJson: argsJson,
        ),
      ).whenComplete(() async {
        try {
          await collectRoutingRuntimeDomains(
            source: resolvedPluginId,
            runtime: resolvedRuntimeName,
          );
        } finally {
          removeResolutionCancel?.call();
          _releaseSessionRuntime(resolvedRuntimeName);
        }
      });
  PlaybackTrace.note(
    resolvedPluginId,
    'qjs_dispatch',
    'submitted fn=$resolvedFnPath',
  );

  var didUntrack = false;
  void untrackOnce() {
    if (didUntrack) return;
    didUntrack = true;
    if (group != null && group.isNotEmpty) {
      _trackedRuntimesByGroup.release(
        _buildTaskGroupId(resolvedPluginId, group),
        resolvedRuntimeName,
      );
    }
  }

  if (group != null && group.isNotEmpty) {
    _trackedRuntimesByGroup.retain(
      _buildTaskGroupId(resolvedPluginId, group),
      resolvedRuntimeName,
    );
  }

  unawaited(
    waitFuture.then<void>((_) {}).catchError((_) {}).whenComplete(untrackOnce),
  );
  // 注意：不要在 try/finally 里 return Future（会触发
  // unawaited_return_in_try_block）。untrack 已由上面的 whenComplete 在
  // future 完成时统一处理；空 taskGroupKey 时 untrackOnce 本身也是 no-op。
  final T result;
  try {
    result = await (group != null && group.isNotEmpty
        ? raceWithDownloadCancel(group, waitFuture)
        : waitFuture);
  } catch (error, stack) {
    if (requireCurrentResult && error is! DownloadTaskCancelledException) {
      _requireSessionOwner(resolvedPluginId, sessionOwner);
    }
    PlaybackTrace.error(resolvedPluginId, 'qjs_dispatch', error, stack);
    rethrow;
  }
  if (requireCurrentResult)
    _requireSessionOwner(resolvedPluginId, sessionOwner);
  PlaybackTrace.note(resolvedPluginId, 'qjs_dispatch', 'completed');
  return result;
}

/// 调用插件函数,返回 JSON 字符串。
Future<String> executeQjsCall({
  required String pluginId,
  required String fnPath,
  required String argsJson,
  String? runtimeName,
  String? taskGroupKey,
  bool sessionChange = false,
  bool requireCurrentResult = false,
}) {
  Future<String> invoke() => _executeQjsCall(
    pluginId: pluginId,
    fnPath: fnPath,
    argsJson: argsJson,
    runtimeName: runtimeName,
    taskGroupKey: taskGroupKey,
    requireCurrentResult: requireCurrentResult,
  );
  return sessionChange || isStandardPluginSessionChange(fnPath)
      ? runPluginSessionChange(pluginId, invoke)
      : invoke();
}

Future<String> _executeQjsCall({
  required String pluginId,
  required String fnPath,
  required String argsJson,
  required bool requireCurrentResult,
  String? runtimeName,
  String? taskGroupKey,
}) async {
  final capture = PlaybackTrace.isCapturing(normalizePluginId(pluginId));
  if (capture) {
    _playbackErrorStackUsers++;
    setQjsErrorStackEnabled(enabled: true);
  }
  try {
    final bytes = await _runQjsTask<Uint8List>(
      pluginId: pluginId,
      fnPath: fnPath,
      argsJson: argsJson,
      runtimeName: runtimeName,
      taskGroupKey: taskGroupKey,
      requireCurrentResult: requireCurrentResult,
      call: qjsTaskCall,
    );
    return utf8.decode(bytes, allowMalformed: true);
  } finally {
    if (capture) {
      _playbackErrorStackUsers--;
      setQjsErrorStackEnabled(
        enabled: _baseErrorStack || _playbackErrorStackUsers > 0,
      );
    }
  }
}

/// 调用插件函数,返回原始字节(如图片)。
Future<Uint8List> executeQjsFetchImageBytes({
  required String pluginId,
  required String fnPath,
  required String argsJson,
  String? runtimeName,
  String? taskGroupKey,
}) => _runQjsTask<Uint8List>(
  pluginId: pluginId,
  fnPath: fnPath,
  argsJson: argsJson,
  runtimeName: runtimeName,
  taskGroupKey: taskGroupKey,
  call: qjsTaskCall,
);

/// 调用插件图片函数，并解码 Rust reqwest 返回的 CBOR 结果信息。
Future<QjsFetchImageHttpResult> executeQjsFetchImageResult({
  required String pluginId,
  required String fnPath,
  required String argsJson,
  String? runtimeName,
  String? taskGroupKey,
}) async {
  final encoded = await _runQjsTask<Uint8List>(
    pluginId: pluginId,
    fnPath: fnPath,
    argsJson: argsJson,
    runtimeName: runtimeName,
    taskGroupKey: taskGroupKey,
    call: qjsFetchImage,
  );
  return QjsFetchImageHttpResult.fromCbor(cbor.cbor.decode(encoded));
}

bool _shouldUseQjsCallOnce(String pluginId) {
  // return true;
  final normalized = normalizePluginId(pluginId);
  final state = PluginRegistryService.I.getByUuid(normalized);
  return state?.debug == true;
}

String? loadQjsDebugBundleUrl(String pluginId) {
  final normalizedPluginId = normalizePluginId(pluginId);
  if (normalizedPluginId.isEmpty) {
    throw StateError('pluginId 不能为空');
  }
  final runtimeState = PluginRegistryService.I.getByUuid(normalizedPluginId);
  if (runtimeState == null || runtimeState.isDeleted) {
    throw StateError('plugin_not_found:$normalizedPluginId');
  }
  if (!runtimeState.debug) {
    return null;
  }
  final bundleUrl = runtimeState.debugUrl?.trim() ?? '';
  return bundleUrl.isEmpty ? null : bundleUrl;
}

Future<void> cancelTrackedQjsTasks({
  required String pluginId,
  required String taskGroupKey,
}) async {
  final normalizedPluginId = normalizePluginId(pluginId);
  final groupId = _buildTaskGroupId(normalizedPluginId, taskGroupKey);
  final runtimeNames = _trackedRuntimesByGroup.take(groupId);
  if (runtimeNames.isEmpty) {
    logger.d(
      '取消 QJS 任务组: $groupId -> no_tracked_tasks, fallback_runtime_cancel',
    );
    runtimeNames.addAll({
      ..._networkRoutes.runtimeNames(normalizedPluginId),
      ...?_sessionRuntimes[normalizedPluginId],
    });
    if (runtimeNames.isEmpty && normalizedPluginId.isNotEmpty) {
      runtimeNames.add(normalizedPluginId);
    }
  }

  var cancelledCount = 0;
  var notFoundCount = 0;
  final failedTaskIds = <String>[];

  await Future.wait(
    runtimeNames.map((runtimeName) async {
      try {
        final result = await qjsCancelTasksByGroup(
          runtimeName: runtimeName,
          taskGroupKey: taskGroupKey,
        );

        if (result.cancelled == 0 &&
            result.notFound == 0 &&
            result.failedRuntimeGroups.isEmpty) {
          notFoundCount += 1;
          logger.d('取消 QJS 任务组未找到: $runtimeName/$taskGroupKey');
          return;
        }

        final cancelled = result.cancelled;
        final notFound = result.notFound;
        cancelledCount += cancelled;
        notFoundCount += notFound;

        logger.d(
          '取消 QJS 任务组结果: $runtimeName/$taskGroupKey -> cancelled=$cancelled, not_found=$notFound',
        );

        if (result.failedRuntimeGroups.isNotEmpty) {
          failedTaskIds.addAll(
            result.failedRuntimeGroups.map(
              (group) => '$runtimeName/$taskGroupKey:$group',
            ),
          );
        }
      } catch (e) {
        failedTaskIds.add('$runtimeName/$taskGroupKey:${e.toString()}');
        logger.w('取消 QJS 任务组失败: $runtimeName/$taskGroupKey', error: e);
      }
    }),
  );

  logger.d(
    '取消 QJS 任务组结果: $groupId -> cancelled=$cancelledCount, not_found=$notFoundCount, failed=${failedTaskIds.length}',
  );

  if (failedTaskIds.isNotEmpty) {
    throw Exception('取消 QJS 任务组失败: ${failedTaskIds.join('; ')}');
  }
}

Future<String> loadQjsBundleJs(String pluginId) async {
  final normalizedPluginId = normalizePluginId(pluginId);
  if (normalizedPluginId.isEmpty) {
    throw StateError('pluginId 不能为空');
  }
  final runtimeState = PluginRegistryService.I.getByUuid(normalizedPluginId);
  if (runtimeState == null || runtimeState.isDeleted) {
    throw StateError('plugin_not_found:$normalizedPluginId');
  }
  if (!runtimeState.debug) {
    final dbBundle = runtimeState.originScript;
    if (dbBundle.trim().isNotEmpty) {
      return dbBundle;
    }
    throw StateError('bundle_js_missing_db:$normalizedPluginId');
  }

  // Debug URLs are fetched by Rust only after its generation has been built
  // with the explicit snapshot; never use fetchDirect here.
  final dbBundle = runtimeState.originScript;
  if (dbBundle.trim().isNotEmpty) return dbBundle;
  throw StateError('bundle_js不能为空: $normalizedPluginId');
}
