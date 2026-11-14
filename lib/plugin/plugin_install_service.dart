import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/page/plugin_store/models/cloud_plugin_item.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/plugin/plugin_host_compatibility.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/plugin/utils/plugin_cloud_download_utils.dart';
import 'package:zephyr/plugin/utils/plugin_catalog_merge.dart';
import 'package:zephyr/plugin/utils/plugin_update_channel_utils.dart';
import 'package:zephyr/plugin/utils/plugin_version_utils.dart';
import 'package:zephyr/plugin/utils/published_plugin_artifact.dart';

const _blockedPluginUuid = kDebugMode
    ? ''
    : '00000000-0000-0000-0000-00000000e001';

bool allowsPluginInstallation(String uuid) => uuid != _blockedPluginUuid;

class PluginInstallService {
  PluginInstallService._();
  static final PluginInstallService I = PluginInstallService._();

  /// Downloads and installs a plugin from the cloud store.
  ///
  /// Returns a message like '安装成功' or '更新成功' on success, and throws
  /// on failure. The caller is responsible for showing UI feedback.
  Future<String> installFromCloud(
    CloudPluginItem item, {
    String? expectedUuid,
    bool reinstall = false,
  }) async {
    final pluginUuid = item.manifest.uuid.trim();
    if (pluginUuid.isEmpty) {
      throw StateError('云端插件清单缺少 uuid');
    }
    PluginHostCompatibility.requireCompatibleInfo(
      item.manifest.compatibilityMetadata,
      uuid: pluginUuid,
    );
    if (!allowsPluginInstallation(pluginUuid)) {
      throw StateError('请更换插件id');
    }
    if (expectedUuid != null &&
        expectedUuid.trim().isNotEmpty &&
        pluginUuid != expectedUuid.trim()) {
      throw StateError('插件 id 不一致，期望=${expectedUuid.trim()}, 实际=$pluginUuid');
    }
    final updateUrl = item.manifest.updateUrl.trim();
    final npmName = item.manifest.npmName.trim();
    if (updateUrl.isEmpty && npmName.isEmpty) {
      throw StateError('该插件未提供 updateUrl 或 npmName，无法下载');
    }

    final installation = _captureKnownInstallation(pluginUuid);
    final current = _findExistingPluginInfoByUuid(pluginUuid);
    final installed =
        current != null &&
        !current.isDeleted &&
        installation?.removedAt == null;
    var formal = item.formalRelease;
    if (reinstall &&
        (!installed ||
            !item.canReinstallFromCloud(
              parseGetInfoJson(current.getInfoJson),
            ))) {
      throw StateError(t.plugin.refreshBeforeCloudReinstall);
    }
    if (reinstall && formal == null && item.isFormalCloudListing) {
      // Bundled/cached rows can display the action. A new live catalogue
      // must certify exactly what the user saw before we download its code.
      final catalog = await fetchCloudPluginListWithCdnFallback();
      final version = normalizePublishedPluginVersion(item.manifest.version);
      final digest = parsePublishedPluginSha256(item.manifest.scriptSha256);
      formal = catalog.entries
          .map((entry) => entry.formalRelease)
          .whereType<FormalPluginRelease>()
          .where(
            (release) =>
                release.uuid == pluginUuid &&
                release.version == version &&
                release.updateUrl == updateUrl &&
                release.scriptSha256 == digest,
          )
          .firstOrNull;
      if (formal == null) {
        throw StateError(t.plugin.refreshBeforeCloudReinstall);
      }
    }
    PluginReleaseMigration? migration;
    if (installed && !reinstall) {
      migration = item.formalRelease?.migrationFor(
        installedUuid: pluginUuid,
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
              compareVersion(item.manifest.version, current.version) <= 0)) {
        throw StateError(t.plugin.localVersionNewer);
      }
    }
    final script = reinstall && formal != null
        ? await downloadFormalPluginRelease(formal)
        : migration == null
        ? await downloadFromJsdelivrOrGitHub(
            npmName: npmName,
            cloudVersion: item.manifest.version.trim(),
            updateUrl: updateUrl,
          )
        : await downloadFormalPluginMigration(migration);
    verifyPublishedPluginScript(script, item.manifest.scriptSha256);
    return _savePluginWithLease(
      script,
      sourceLabel: '云端组件: ${item.repo}',
      allowReplaceExisting: true,
      expectedUuid: pluginUuid,
      expectedVersion: item.manifest.version,
      expectedInstallation: installation,
      migration: migration,
      formalRelease: reinstall ? formal : null,
    );
  }

  /// Installs a plugin from local bytes (e.g. picked file).
  ///
  /// The file picker intentionally applies no suffix filter (see
  /// `pickPluginScriptFile`), so unsupported files (e.g. `.txt`, `.pdf`)
  /// must fail here with a friendly message instead of a cryptic QJS parse
  /// error. Files with an unknown suffix also go through a content fallback:
  /// Android's file_selector copies `content://` URIs to a temp path whose
  /// extension is derived from the (often generic) MIME type and may lose
  /// the original `.br` suffix, so brotli is retried by content and plain
  /// text carrying `getInfo` is still accepted.
  Future<String> installFromLocalBytes(
    List<int> bytes, {
    required String fileName,
    String? expectedUuid,
    bool allowReplaceExisting = false,
  }) async {
    final installation = _captureKnownInstallation(expectedUuid);
    final lowerName = fileName.toLowerCase();
    final knownExtension =
        lowerName.endsWith('.js') ||
        lowerName.endsWith('.cjs') ||
        lowerName.endsWith('.br');
    final script = knownExtension
        ? await decodePluginScriptFromBytes(
            bytes: bytes,
            shouldUseBrotli: lowerName.endsWith('.br'),
          )
        : await _decodeUnknownLocalPlugin(bytes, fileName: fileName);
    return _savePluginWithLease(
      script,
      sourceLabel: '本地文件: $fileName',
      allowReplaceExisting: allowReplaceExisting,
      expectedUuid: expectedUuid,
      expectedInstallation: installation,
    );
  }

  /// Installs a plugin from an arbitrary network URL.
  Future<String> installFromNetworkUrl(
    String rawUrl, {
    String? expectedUuid,
    bool allowReplaceExisting = false,
  }) async {
    final resolvedUrl = rawUrl.trim();
    if (resolvedUrl.isEmpty) {
      throw StateError('URL 不能为空');
    }

    final installation = _captureKnownInstallation(expectedUuid);
    final response = await downloadPluginAssetWithFallback(resolvedUrl);
    final script = await decodeDownloadedPluginScript(
      response: response,
      resolvedUrl: resolvedUrl,
    );
    return _savePluginWithLease(
      script,
      sourceLabel: '网络地址: $resolvedUrl',
      allowReplaceExisting: allowReplaceExisting,
      expectedUuid: expectedUuid,
      expectedInstallation: installation,
    );
  }

  /// Parses [script] and updates it, preserving an existing plugin's enabled state.
  ///
  /// Maintenance callers may set [initialize] to false to invalidate the old
  /// runtime without running init or refreshing metadata through the plugin
  /// runtime. The next normal plugin use initializes the new script.
  ///
  /// When [allowReplaceExisting] is false and the plugin already exists and is
  /// not deleted, a [StateError] is thrown.
  ///
  /// When [expectedUuid] is set, the script's uuid must match or install fails.
  Future<String> savePluginByScript(
    String script, {
    required String sourceLabel,
    bool allowReplaceExisting = false,
    String? expectedUuid,
    bool initialize = true,
  }) => _savePluginWithLease(
    script,
    sourceLabel: sourceLabel,
    allowReplaceExisting: allowReplaceExisting,
    expectedUuid: expectedUuid,
    initialize: initialize,
    expectedInstallation: _captureKnownInstallation(expectedUuid),
  );

  Future<String> _savePluginWithLease(
    String script, {
    required String sourceLabel,
    required bool allowReplaceExisting,
    required String? expectedUuid,
    String expectedVersion = '',
    bool initialize = true,
    required _InstallationRevision? expectedInstallation,
    PluginReleaseMigration? migration,
    FormalPluginRelease? formalRelease,
  }) async {
    // A download does not hold a lease. Once it completes, reject older
    // intent before protecting the actual install from concurrent removal.
    if (_captureKnownInstallation(expectedUuid) != expectedInstallation) {
      throw const PluginLifecycleChanged();
    }
    final source = expectedUuid?.trim() ?? '';
    final lease = source.isEmpty
        ? null
        : LocalPluginInstallationState.instance.beginExplicitInstallation(
            source,
          );
    try {
      return await _savePluginByScript(
        script,
        sourceLabel: sourceLabel,
        allowReplaceExisting: allowReplaceExisting,
        expectedUuid: expectedUuid,
        expectedVersion: expectedVersion,
        initialize: initialize,
        expectedInstallation: expectedInstallation,
        migration: migration,
        formalRelease: formalRelease,
      );
    } finally {
      lease?.release();
    }
  }

  _InstallationRevision? _captureKnownInstallation(String? expectedUuid) {
    final uuid = expectedUuid?.trim() ?? '';
    if (uuid.isEmpty) return null;
    final local = LocalPluginInstallationState.instance;
    return (
      epoch: local.installationEpoch(uuid),
      removedAt: local.removedAt(uuid),
      bundle: _bundleRevision(_findExistingPluginInfoByUuid(uuid)),
    );
  }

  Future<String> _savePluginByScript(
    String script, {
    required String sourceLabel,
    required bool allowReplaceExisting,
    required String? expectedUuid,
    required String expectedVersion,
    required bool initialize,
    required _InstallationRevision? expectedInstallation,
    PluginReleaseMigration? migration,
    FormalPluginRelease? formalRelease,
  }) async {
    final normalizedScript = script.trim();
    if (normalizedScript.isEmpty) {
      throw StateError('插件脚本内容为空，无法安装（$sourceLabel）');
    }

    final info = await callGetInfoByGlobalQjs(normalizedScript);
    final resolvedUuid = readUuidFromInfo(info);
    if (resolvedUuid.isEmpty) {
      throw StateError('getInfo 返回缺少 uuid');
    }
    if (!allowsPluginInstallation(resolvedUuid)) {
      throw StateError('请更换插件id');
    }
    final expected = expectedUuid?.trim() ?? '';
    if (expected.isNotEmpty && resolvedUuid != expected) {
      throw StateError('插件 id 不一致，期望=$expected, 实际=$resolvedUuid');
    }
    final version = readVersionFromInfo(info);
    verifyPublishedPluginVersion(version, expectedVersion);
    migration?.verifyTargetInfo(info);
    formalRelease?.verifyTargetInfo(info);
    PluginHostCompatibility.requireCompatibleInfo(
      info,
      uuid: resolvedUuid,
      version: version,
    );
    final getInfoJson = encodeGetInfoJson(info);
    if (expectedInstallation != null &&
        _captureKnownInstallation(resolvedUuid) != expectedInstallation) {
      throw const PluginLifecycleChanged();
    }

    final existing = PluginRegistryService.I.getByUuid(resolvedUuid);
    if (!allowReplaceExisting) {
      _validateUuidNotDuplicated(resolvedUuid);
    }

    final existingInfo = _findExistingPluginInfoByUuid(resolvedUuid);
    final reinstall = existingInfo?.isDeleted == true;
    final wallClock = DateTime.now().toUtc().millisecondsSinceEpoch;
    final installationClock = reinstall
        ? [
            wallClock,
            existingInfo!.updatedAt.toUtc().millisecondsSinceEpoch + 1,
            existingInfo.insertedAt.toUtc().millisecondsSinceEpoch + 1,
            (existingInfo.deletedAt?.toUtc().millisecondsSinceEpoch ?? 0) + 1,
          ].reduce((a, b) => a > b ? a : b)
        : wallClock;
    final now = DateTime.fromMillisecondsSinceEpoch(
      installationClock,
      isUtc: true,
    );
    final infoToSave = PluginInfo(
      id: existingInfo?.id ?? 0,
      uuid: resolvedUuid,
      version: version,
      originScript: normalizedScript,
      // A new installation after deletion is explicit user intent. Ordinary
      // updates retain their installation identity; runtime reads never move it.
      insertedAt: reinstall
          ? now
          : existingInfo?.insertedAt ?? existing?.insertedAt ?? now,
      updatedAt: now,
      isEnabled: existingInfo?.isDeleted == false
          ? existingInfo!.isEnabled
          : true,
      isDeleted: false,
      deletedAt: null,
      lastLoadSuccess: false,
      lastLoadError: null,
      sortOrder: existingInfo?.sortOrder ?? existing?.sortOrder,
      debug: existingInfo?.debug ?? existing?.debug ?? false,
      debugUrl: existingInfo?.debugUrl ?? existing?.debugUrl,
      getInfoJson: getInfoJson,
    );

    await PluginRegistryService.I.upsertAndSetEnabled(
      infoToSave,
      initialize: initialize,
      explicitInstallation: true,
      expectedInstallationEpoch: expectedInstallation?.epoch,
      matchesCurrentInstallation: expectedInstallation == null
          ? null
          : (current) =>
                _bundleRevision(current) == expectedInstallation.bundle,
    );

    // 安装/更新后再次刷新 getInfo（内存 + 持久化）。
    if (initialize && infoToSave.isEnabled) {
      try {
        final runtimeName = PluginRegistryService.I.resolveRuntimeName(
          resolvedUuid,
        );
        await PluginRegistryService.I.fetchPluginInfo(
          uuid: resolvedUuid,
          runtimeName: runtimeName,
        );
      } catch (e, st) {
        logger.w('安装后刷新 getInfo 失败: $resolvedUuid', error: e, stackTrace: st);
      }
    }

    if (reinstall) {
      // Runtime load/status callbacks use the wall clock. If it moved backwards,
      // retain the logical installation revision once those callbacks settle.
      final installed = _findExistingPluginInfoByUuid(resolvedUuid);
      if (installed != null &&
          !installed.isDeleted &&
          installed.originScript == normalizedScript &&
          installed.version == version &&
          installed.insertedAt.toUtc() == now &&
          installed.updatedAt.isBefore(now)) {
        installed.updatedAt = now;
        await PluginRegistryService.I.upsert(installed);
      }
    }
    return existing == null ? '安装成功' : '更新成功';
  }

  void _validateUuidNotDuplicated(String uuid) {
    final existing = PluginRegistryService.I.getByUuid(uuid);
    if (existing != null && !existing.isDeleted) {
      throw StateError('插件已存在，禁止重复安装: uuid=$uuid');
    }
  }

  PluginInfo? _findExistingPluginInfoByUuid(String uuid) {
    final query = objectbox.pluginInfoBox
        .query(PluginInfo_.uuid.equals(uuid))
        .build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }
}

typedef _BundleRevision = ({
  int id,
  int installedAt,
  String version,
  String script,
  bool deleted,
});

_BundleRevision? _bundleRevision(PluginInfo? info) => info == null
    ? null
    : (
        id: info.id,
        installedAt: info.insertedAt.millisecondsSinceEpoch,
        version: info.version,
        script: info.originScript,
        deleted: info.isDeleted,
      );

typedef _InstallationRevision = ({
  int epoch,
  int? removedAt,
  _BundleRevision? bundle,
});

/// Decodes local [bytes] whose file name carries no supported suffix.
///
/// Tries brotli decode first (covers `.br` files renamed by Android's
/// `content://` copy), then falls back to plain UTF-8 text carrying
/// `getInfo`. Anything else reports [unsupportedLocalFileType] instead of
/// leaking a QJS parse error.
Future<String> _decodeUnknownLocalPlugin(
  List<int> bytes, {
  required String fileName,
}) async {
  String? script;
  try {
    script = await decodePluginScriptFromBytes(
      bytes: bytes,
      shouldUseBrotli: true,
    );
  } catch (_) {
    script = null;
  }
  script ??= utf8.decode(bytes, allowMalformed: true);
  if (script.trim().isEmpty || !_looksLikePluginScript(script)) {
    throw StateError(t.plugin.unsupportedLocalFileType(fileName: fileName));
  }
  return script;
}

/// True when [script] smells like a plugin bundle: declares `getInfo`.
bool _looksLikePluginScript(String script) {
  return script.contains('getInfo');
}
