import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/page/plugin_store/models/cloud_plugin_item.dart';
import 'package:zephyr/plugin/plugin_host_compatibility.dart';
import 'package:zephyr/plugin/plugin_install_service.dart';
import 'package:zephyr/plugin/utils/plugin_cloud_download_utils.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/widgets/toast.dart';

typedef PluginStoreBatchFailure = ({String plugin, String reason});
typedef PluginStoreBatchResult = ({
  String message,
  List<PluginStoreBatchFailure> failures,
});

class PluginStoreState {
  const PluginStoreState({
    this.installing = false,
    this.installMessage = '',
    this.cloudLoading = false,
    this.cloudError = '',
    this.cloudPlugins = const <CloudPluginItem>[],
  });

  final bool installing;
  final String installMessage;
  final bool cloudLoading;
  final String cloudError;
  final List<CloudPluginItem> cloudPlugins;

  PluginStoreState copyWith({
    bool? installing,
    String? installMessage,
    bool? cloudLoading,
    String? cloudError,
    List<CloudPluginItem>? cloudPlugins,
  }) {
    return PluginStoreState(
      installing: installing ?? this.installing,
      installMessage: installMessage ?? this.installMessage,
      cloudLoading: cloudLoading ?? this.cloudLoading,
      cloudError: cloudError ?? this.cloudError,
      cloudPlugins: cloudPlugins ?? this.cloudPlugins,
    );
  }
}

class PluginStoreCubit extends Cubit<PluginStoreState> {
  PluginStoreCubit() : super(const PluginStoreState());

  int _catalogLoad = 0;

  Future<void> loadCloudPlugins() async {
    if (isClosed || state.installing) return;
    final request = ++_catalogLoad;
    bool current() => !isClosed && request == _catalogLoad;
    emit(state.copyWith(cloudLoading: true, cloudError: ''));

    try {
      final fallback = await readCloudPluginCatalogFallback();
      if (!current()) return;
      if (state.cloudPlugins.isEmpty) {
        final saved = _uniqueCatalogItems(
          asJsonList(
            jsonDecode(fallback),
          ).map((item) => CloudPluginItem.fromJson(asJsonMap(item))),
        );
        emit(state.copyWith(cloudPlugins: saved));
      }
      final catalog = await fetchCloudPluginListWithCdnFallback();
      if (!current()) return;
      final entries = _uniqueCatalogItems(
        catalog.entries.map(
          (entry) => CloudPluginItem.fromJson(
            entry.json,
            formalRelease: entry.formalRelease,
          ),
        ),
      );

      emit(
        state.copyWith(
          cloudPlugins: entries,
          cloudLoading: false,
          cloudError: '',
        ),
      );
    } catch (e, stackTrace) {
      if (!current()) return;
      logger.w('拉取云端插件列表失败', error: e, stackTrace: stackTrace);
      emit(
        state.copyWith(
          cloudLoading: false,
          cloudError: t.plugin.cloudPluginsLoadFailed(
            error: userFacingErrorMessage(e),
          ),
        ),
      );
    }
  }

  List<CloudPluginItem> _uniqueCatalogItems(Iterable<CloudPluginItem> items) {
    final seen = <String>{};
    return items.where((item) {
      final uuid = item.manifest.uuid.trim();
      return uuid.isNotEmpty && seen.add(uuid);
    }).toList();
  }

  Map<CloudPluginBatchAction, List<CloudPluginItem>> get cloudBatchCandidates {
    final candidates = {
      for (final action in CloudPluginBatchAction.values)
        action: <CloudPluginItem>[],
    };
    if (state.installing || state.cloudLoading) return candidates;

    for (final item in state.cloudPlugins) {
      final action = PluginInstallService.I.cloudBatchActionFor(item);
      if (action != null) candidates[action]!.add(item);
    }
    return candidates;
  }

  Future<PluginStoreBatchResult?> installCloudBatch(
    CloudPluginBatchAction action,
    List<CloudPluginItem> confirmedItems,
  ) async {
    if (isClosed || state.installing || state.cloudLoading) return null;

    final currentCatalog = state.cloudPlugins.toSet();
    final items = _uniqueCatalogItems(confirmedItems);
    if (items.isEmpty) return null;

    final updating = action == CloudPluginBatchAction.update;
    var succeeded = 0;
    var skipped = 0;
    final failures = <PluginStoreBatchFailure>[];
    for (final (index, item) in items.indexed) {
      if (!currentCatalog.contains(item)) {
        skipped++;
        continue;
      }
      if (!isClosed) {
        final progress = updating
            ? t.plugin.cloudBatchUpdating
            : t.plugin.cloudBatchInstalling;
        _beginInstall(
          progress(
            current: index + 1,
            total: items.length,
            name: item.displayName,
          ),
        );
      }
      try {
        await PluginInstallService.I.installFromCloud(
          item,
          batchAction: action,
        );
        succeeded++;
        if (updating) {
          showSuccessToast(t.plugin.cloudPluginUpdated(name: item.displayName));
        }
      } on PluginLifecycleChanged {
        skipped++;
      } catch (error, stackTrace) {
        logger.w(
          '批量处理云端插件失败: ${item.manifest.uuid}',
          error: error,
          stackTrace: stackTrace,
        );
        failures.add((
          plugin: item.displayName,
          reason: error is PluginHostCompatibilityException
              ? t.plugin.hostUpgradeRequired
              : normalizePluginInstallErrorMessage(error),
        ));
      }
    }

    final message = [
      if (succeeded > 0)
        updating
            ? t.plugin.cloudBatchUpdated(count: succeeded)
            : t.plugin.cloudBatchInstalled(count: succeeded),
      if (failures.isNotEmpty)
        t.plugin.cloudBatchFailed(count: failures.length),
      if (skipped > 0) t.plugin.cloudBatchSkipped(count: skipped),
    ].join(' · ');
    if (!isClosed) {
      emit(state.copyWith(installing: false, installMessage: ''));
    }
    if (failures.isEmpty && skipped == 0) {
      showSuccessToast(message);
    } else if (failures.isEmpty || isClosed) {
      showWarningToast(message);
    }
    return (
      message: message,
      failures: List<PluginStoreBatchFailure>.unmodifiable(failures),
    );
  }

  Future<void> installFromCloud(
    CloudPluginItem item, {
    bool reinstall = false,
  }) async {
    if (state.installing) {
      return;
    }
    _beginInstall(t.plugin.installingFromCloud(name: item.displayName));

    try {
      final message = await PluginInstallService.I.installFromCloud(
        item,
        reinstall: reinstall,
      );
      _reportInstallSuccess(message);
    } catch (e) {
      _reportInstallFailure(
        t.plugin.cloudDownloadFailed(
          error: normalizePluginInstallErrorMessage(e),
        ),
      );
    }
  }

  Future<void> installFromLocalBytes(
    List<int> bytes, {
    required String fileName,
  }) async {
    if (state.installing) {
      return;
    }
    _beginInstall(t.plugin.installingFromLocal);

    try {
      final message = await PluginInstallService.I.installFromLocalBytes(
        bytes,
        fileName: fileName,
      );
      _reportInstallSuccess(message);
    } catch (e) {
      _reportInstallFailure(
        t.plugin.readLocalPluginFailed(
          error: normalizePluginInstallErrorMessage(e),
        ),
      );
    }
  }

  Future<void> installFromNetworkUrl(String rawUrl) async {
    if (state.installing) {
      return;
    }
    _beginInstall(t.plugin.installingFromNetwork);

    try {
      final message = await PluginInstallService.I.installFromNetworkUrl(
        rawUrl,
      );
      _reportInstallSuccess(message);
    } catch (e) {
      _reportInstallFailure(
        t.plugin.networkDownloadFailed(
          error: normalizePluginInstallErrorMessage(e),
        ),
      );
    }
  }

  void _beginInstall(String message) {
    emit(state.copyWith(installing: true, installMessage: message));
  }

  void _reportInstallFailure(String message) {
    if (!isClosed) emit(state.copyWith(installing: false, installMessage: ''));
    showErrorToast(message);
  }

  void _reportInstallSuccess(String message) {
    if (!isClosed) emit(state.copyWith(installing: false, installMessage: ''));
    showSuccessToast(message);
  }
}
