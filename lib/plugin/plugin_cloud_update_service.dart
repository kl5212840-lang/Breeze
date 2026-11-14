import 'dart:async';

import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/sync_service.dart'
    show runExclusiveStorageOperation;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/plugin/models/cloud_plugin_manifest_internal.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/plugin/plugin_host_compatibility.dart';
import 'package:zephyr/plugin/utils/plugin_catalog_merge.dart';
import 'package:zephyr/plugin/utils/plugin_cloud_download_utils.dart';
import 'package:zephyr/plugin/utils/plugin_update_channel_utils.dart';
import 'package:zephyr/plugin/utils/plugin_version_utils.dart';
import 'package:zephyr/plugin/utils/published_plugin_artifact.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';

class PluginCloudUpdateService {
  PluginCloudUpdateService._();
  static final PluginCloudUpdateService I = PluginCloudUpdateService._();

  bool _silentCloudUpdateScheduled = false;
  Timer? _silentCloudUpdateTimer;
  bool _silentCloudUpdateRunning = false;

  void scheduleSilentCloudUpdate({
    Duration delay = const Duration(minutes: 5),
  }) {
    if (_silentCloudUpdateScheduled) {
      return;
    }
    _silentCloudUpdateScheduled = true;
    _silentCloudUpdateTimer?.cancel();
    _silentCloudUpdateTimer = Timer(delay, () {
      unawaited(runSilentCloudUpdateOnce());
    });
  }

  Future<void> runSilentCloudUpdateOnce() async {
    if (_silentCloudUpdateRunning) {
      return;
    }
    _silentCloudUpdateRunning = true;
    try {
      await silentUpdateFromCloud();
    } catch (e, st) {
      logger.w('静默更新插件失败', error: e, stackTrace: st);
    } finally {
      _silentCloudUpdateRunning = false;
    }
  }

  /// 静默自动更新：
  /// - 在云端列表中的插件：只走列表 version / 下载坐标
  /// - 不在列表中的插件：只走自身 npmName / updateUrl
  /// 两条路径互不回退。
  Future<void> silentUpdateFromCloud() async {
    final localPlugins = PluginRegistryService.I.snapshot.values
        .where((item) => !item.isDeleted)
        .map(_captureUpdateTarget)
        .toList();
    if (localPlugins.isEmpty) {
      return;
    }

    var cloudByUuid = <String, CloudPluginCatalogItem>{};
    try {
      final cloudItems = await _fetchCloudPluginCatalog();
      cloudByUuid = {
        for (final item in cloudItems)
          if (item.manifest.uuid.trim().isNotEmpty)
            item.manifest.uuid.trim(): item,
      };
    } catch (e, st) {
      logger.w('静默更新拉取云端列表失败，将全部尝试自身更新通道', error: e, stackTrace: st);
    }

    final inList = <_PluginUpdateTarget>[];
    final outList = <_PluginUpdateTarget>[];
    for (final target in localPlugins) {
      if (cloudByUuid.containsKey(target.local.uuid)) {
        inList.add(target);
      } else {
        outList.add(target);
      }
    }

    var updatedCount = 0;

    for (final target in inList) {
      final uuid = target.local.uuid;
      final cloud = cloudByUuid[uuid];
      if (cloud == null) {
        continue;
      }
      try {
        final updated = await _tryUpdateFromCloudCatalog(
          target: target,
          cloud: cloud,
        );
        if (updated) {
          updatedCount++;
        }
      } catch (e, st) {
        logger.w('插件静默更新失败(列表): $uuid', error: e, stackTrace: st);
      }
    }

    if (outList.isNotEmpty) {
      final results = await Future.wait(
        outList.map((target) async {
          try {
            return await _tryUpdateFromSelfChannel(
              target: target,
              sourceLabel: '静默更新(自身通道)',
            );
          } catch (e, st) {
            logger.w(
              '插件静默更新失败(自身通道): ${target.local.uuid}',
              error: e,
              stackTrace: st,
            );
            return false;
          }
        }),
        eagerError: false,
      );
      updatedCount += results.where((ok) => ok).length;
    }

    if (updatedCount > 0) {
      logger.i('静默更新完成，共更新 $updatedCount 个插件');
    }
  }

  /// 插件设置「同步」：固定走 npm / updateUrl 自身通道。
  ///
  /// 返回是否实际下载并应用了新版本。
  Future<bool> syncPluginFromSelfChannel(String uuid) async {
    final local = PluginRegistryService.I.getByUuid(uuid);
    if (local == null || local.isDeleted) {
      throw StateError('插件不存在或已删除');
    }

    return _tryUpdateFromSelfChannel(
      target: _captureUpdateTarget(local),
      sourceLabel: '手动同步',
      forceWhenSameVersion: false,
    );
  }

  Future<bool> _tryUpdateFromCloudCatalog({
    required _PluginUpdateTarget target,
    required CloudPluginCatalogItem cloud,
  }) async {
    final local = target.local;
    final updateUrl = cloud.manifest.updateUrl.trim();
    final npmName = cloud.manifest.npmName.trim();
    if (updateUrl.isEmpty && npmName.isEmpty) {
      return false;
    }
    final current = _requireCurrentUpdateTarget(target);
    final migration = cloud.formalRelease?.migrationFor(
      installedUuid: current.uuid,
      installedVersion: current.version,
      scriptFingerprint: () =>
          publishedPluginScriptSha256(current.originScript),
    );
    if (migration == null &&
        (!preservesFormalPluginChannel(
              installedInfo: parseGetInfoJson(current.getInfoJson),
              updateUrl: updateUrl,
              npmName: npmName,
            ) ||
            !_shouldUpdateVersion(
              localVersion: local.version,
              remoteVersion: cloud.manifest.version,
            ))) {
      return false;
    }

    PluginHostCompatibility.requireCompatibleInfo(
      cloud.manifest.compatibilityMetadata,
      uuid: local.uuid,
      version: cloud.manifest.version,
    );
    final payload = await _downloadCloudPluginUpdateWithRetry(
      repo: cloud.repo,
      updateUrl: updateUrl,
      expectedUuid: local.uuid,
      cloudVersion: cloud.manifest.version,
      scriptSha256: cloud.manifest.scriptSha256,
      npmName: npmName,
      sourceLabel: '静默更新: ${cloud.repo}',
      migration: migration,
    );
    return _applyPluginUpdate(
      target: target,
      payload: payload,
      migration: migration,
    );
  }

  Future<bool> _tryUpdateFromSelfChannel({
    required _PluginUpdateTarget target,
    required String sourceLabel,
    bool forceWhenSameVersion = false,
  }) async {
    final local = target.local;
    final channel = await _resolveSelfUpdateChannel(target);
    final npmName = channel.npmName;
    final updateUrl = channel.updateUrl;
    if (npmName.isEmpty && updateUrl.isEmpty) {
      logger.d('插件无更新通道，跳过: ${local.uuid}');
      return false;
    }

    final remoteVersion = await fetchSelfChannelLatestVersion(
      npmName: npmName,
      updateUrl: updateUrl,
    );
    _requireCurrentUpdateTarget(target);
    if (!forceWhenSameVersion &&
        !_shouldUpdateVersion(
          localVersion: local.version,
          remoteVersion: remoteVersion,
        )) {
      return false;
    }

    final payload = await _downloadSelfChannelUpdateWithRetry(
      expectedUuid: local.uuid,
      npmName: npmName,
      updateUrl: updateUrl,
      remoteVersion: remoteVersion,
      sourceLabel: sourceLabel,
    );
    return _applyPluginUpdate(target: target, payload: payload);
  }

  Future<_SelfUpdateChannel> _resolveSelfUpdateChannel(
    _PluginUpdateTarget target,
  ) async {
    final found = _requireCurrentUpdateTarget(target);
    final uuid = found.uuid;
    Map<String, dynamic>? info = parseGetInfoJson(found.getInfoJson);

    final script = found.originScript.trim();
    if (info == null && script.isNotEmpty) {
      try {
        info = await callGetInfoByGlobalQjs(script);
        _requireCurrentUpdateTarget(target);
        await PluginRegistryService.I.persistGetInfoJson(
          uuid,
          encodeGetInfoJson(info),
        );
      } on PluginLifecycleChanged {
        rethrow;
      } catch (e, st) {
        logger.w('刷新 getInfo 缓存失败: $uuid', error: e, stackTrace: st);
      }
    }

    if (info == null) {
      return const _SelfUpdateChannel(npmName: '', updateUrl: '');
    }
    return _SelfUpdateChannel(
      npmName: readNpmNameFromInfo(info),
      updateUrl: readUpdateUrlFromInfo(info),
    );
  }

  Future<List<CloudPluginCatalogItem>> _fetchCloudPluginCatalog() async {
    final catalog = await fetchCloudPluginListWithCdnFallback();
    return catalog.entries
        .map(
          (entry) => CloudPluginCatalogItem.fromJson(
            entry.json,
            formalRelease: entry.formalRelease,
          ),
        )
        .where((item) => item.manifest.uuid.trim().isNotEmpty)
        .toList();
  }

  bool _shouldUpdateVersion({
    required String localVersion,
    required String remoteVersion,
  }) {
    return compareVersion(remoteVersion, localVersion) > 0;
  }

  Future<_PluginUpdatePayload> _downloadCloudPluginUpdateWithRetry({
    required String repo,
    required String updateUrl,
    required String expectedUuid,
    required String cloudVersion,
    required String scriptSha256,
    required String npmName,
    required String sourceLabel,
    required PluginReleaseMigration? migration,
  }) async {
    return _downloadWithRetry(
      expectedUuid: expectedUuid,
      download: () => _downloadAndVerify(
        expectedUuid: expectedUuid,
        npmName: npmName,
        remoteVersion: cloudVersion,
        updateUrl: updateUrl,
        sourceLabel: sourceLabel,
        publishedVersion: cloudVersion,
        publishedSha256: scriptSha256,
        migration: migration,
      ),
    );
  }

  Future<_PluginUpdatePayload> _downloadSelfChannelUpdateWithRetry({
    required String expectedUuid,
    required String npmName,
    required String updateUrl,
    required String remoteVersion,
    required String sourceLabel,
  }) async {
    return _downloadWithRetry(
      expectedUuid: expectedUuid,
      download: () => _downloadAndVerify(
        expectedUuid: expectedUuid,
        npmName: npmName,
        remoteVersion: remoteVersion,
        updateUrl: updateUrl,
        sourceLabel: sourceLabel,
        publishedVersion: _versionedSelfChannel(updateUrl, npmName)
            ? remoteVersion
            : '',
      ),
    );
  }

  Future<_PluginUpdatePayload> _downloadWithRetry({
    required String expectedUuid,
    required Future<_PluginUpdatePayload> Function() download,
  }) async {
    const maxAttempts = 3;
    Object? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await download();
      } catch (e, st) {
        lastError = e;
        final isNetworkError = isNetworkRetryableError(e);
        if (!isNetworkError) {
          rethrow;
        }
        if (attempt >= maxAttempts) {
          break;
        }
        logger.w(
          '插件更新网络错误，准备重试($attempt/$maxAttempts): $expectedUuid',
          error: e,
          stackTrace: st,
        );
        await Future.delayed(Duration(milliseconds: 400 * attempt));
      }
    }

    throw StateError('插件更新网络错误，重试次数用尽: $expectedUuid, error: $lastError');
  }

  bool _versionedSelfChannel(String url, String npmName) =>
      npmName.isNotEmpty ||
      (Uri.tryParse(url)?.path.contains('/updates/v1/') ?? false);

  Future<_PluginUpdatePayload> _downloadAndVerify({
    required String expectedUuid,
    required String npmName,
    required String remoteVersion,
    required String updateUrl,
    required String sourceLabel,
    String publishedVersion = '',
    String publishedSha256 = '',
    PluginReleaseMigration? migration,
  }) async {
    final script = migration == null
        ? await downloadPluginFromSelfChannel(
            npmName: npmName,
            updateUrl: updateUrl,
            remoteVersion: remoteVersion,
          )
        : await downloadFormalPluginMigration(migration);
    verifyPublishedPluginScript(script, publishedSha256);

    final info = await callGetInfoByGlobalQjs(script);
    final resolvedUuid = readUuidFromInfo(info);
    if (resolvedUuid != expectedUuid) {
      throw StateError('更新脚本 uuid 不匹配，期望=$expectedUuid, 实际=$resolvedUuid');
    }
    final resolvedVersion = readVersionFromInfo(info);
    verifyPublishedPluginVersion(resolvedVersion, publishedVersion);
    migration?.verifyTargetInfo(info);
    // Catalog declarations are only an early check; downloaded metadata is
    // always checked again before replacing an installed script.
    PluginHostCompatibility.requireCompatibleInfo(
      info,
      uuid: resolvedUuid,
      version: resolvedVersion,
    );

    return _PluginUpdatePayload(
      uuid: resolvedUuid,
      version: resolvedVersion.isNotEmpty ? resolvedVersion : remoteVersion,
      script: script,
      sourceLabel: sourceLabel,
      getInfoJson: encodeGetInfoJson(info),
    );
  }

  _PluginUpdateTarget _captureUpdateTarget(PluginRuntimeState local) => (
    local: local,
    epoch: LocalPluginInstallationState.instance.installationEpoch(local.uuid),
  );

  PluginInfo _requireCurrentUpdateTarget(_PluginUpdateTarget target) {
    final local = target.local;
    final installation = LocalPluginInstallationState.instance;
    if (installation.isRemoved(local.uuid) ||
        installation.installationEpoch(local.uuid) != target.epoch) {
      throw const PluginLifecycleChanged();
    }
    final query = objectbox.pluginInfoBox
        .query(PluginInfo_.uuid.equals(local.uuid))
        .build();
    try {
      final found = query.findFirst();
      if (found == null ||
          found.isDeleted ||
          found.insertedAt.millisecondsSinceEpoch !=
              local.insertedAt.millisecondsSinceEpoch ||
          found.version != local.version ||
          found.originScript != local.originScript) {
        throw const PluginLifecycleChanged();
      }
      return found;
    } finally {
      query.close();
    }
  }

  Future<bool> _applyPluginUpdate({
    required _PluginUpdateTarget target,
    required _PluginUpdatePayload payload,
    PluginReleaseMigration? migration,
  }) => runExclusiveStorageOperation(() async {
    // Removal, explicit installation and sync can commit during network I/O.
    // Validate inside the same storage queue as those writes.
    final found = _requireCurrentUpdateTarget(target);
    if (migration == null &&
        !_shouldUpdateVersion(
          localVersion: found.version,
          remoteVersion: payload.version,
        )) {
      return false;
    }
    final toSave = PluginInfo(
      id: found.id,
      uuid: payload.uuid,
      version: payload.version,
      originScript: payload.script,
      insertedAt: found.insertedAt,
      updatedAt: DateTime.now().toUtc(),
      isEnabled: found.isEnabled,
      isDeleted: false,
      deletedAt: null,
      lastLoadSuccess: false,
      lastLoadError: null,
      sortOrder: found.sortOrder,
      debug: found.debug,
      debugUrl: found.debugUrl,
      getInfoJson: payload.getInfoJson,
    );
    await PluginRegistryService.I.upsertAndSetEnabled(toSave);
    return true;
  });
}

typedef _PluginUpdateTarget = ({PluginRuntimeState local, int epoch});

class _SelfUpdateChannel {
  const _SelfUpdateChannel({required this.npmName, required this.updateUrl});

  final String npmName;
  final String updateUrl;
}

class _PluginUpdatePayload {
  const _PluginUpdatePayload({
    required this.uuid,
    required this.version,
    required this.script,
    required this.sourceLabel,
    required this.getInfoJson,
  });

  final String uuid;
  final String version;
  final String script;
  final String sourceLabel;
  final String getInfoJson;
}
