import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:zephyr/network/source_network_policy.dart';
import 'package:zephyr/network/sync/sync_service.dart'
    show runExclusiveStorageOperation;
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_hls_assets.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/service/download/download_admission.dart';
import 'package:zephyr/service/download/download_resource_lifecycle.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/service/plugin_account_identity.dart';

/// Reconciles system-owned HLS tasks with this device's exact download attempts.
/// Native owns the transfer and stages the offline package. Dart owns publication.
class VideoHlsRecovery {
  VideoHlsRecovery({
    required this.accountScope,
    required this.canUseDirectRoute,
    required this.wifiOnly,
    required this.onCapacityChanged,
  });

  static final instance = VideoHlsRecovery(
    accountScope: currentAccountScope,
    canUseDirectRoute: directRoute,
    wifiOnly: () => DownloadAdmission.instance.wifiOnly,
    onCapacityChanged: () {},
  );

  final String? Function(String) accountScope;
  final Future<bool> Function(String) canUseDirectRoute;
  final bool Function() wifiOnly;
  void Function() onCapacityChanged;
  final _owned = <String, Map<String, dynamic>>{};
  final _cancelling = <String>{};
  Future<void>? _working;
  bool _refreshAgain = false;

  static String? currentAccountScope(String source) {
    if (!SourceNetworkPolicies.supports(source) ||
        pluginSessionWriteFence.isChanging(source)) {
      return null;
    }
    try {
      final state = LocalPluginInstallationState.instance;
      final plugin = PluginRegistryService.I.getByUuid(source);
      if (plugin == null ||
          !plugin.isEnabled ||
          plugin.isDeleted ||
          state.isRemoved(source) ||
          state.isInstalling(source)) {
        return null;
      }
      return sha256
          .convert(
            utf8.encode(
              jsonEncode([
                'breeze.hls.recovery.v1',
                source,
                state.installationEpoch(source),
                plugin.version,
                PluginAccountIdentities.fingerprint(source),
              ]),
            ),
          )
          .toString();
    } catch (_) {
      return null;
    }
  }

  static Future<bool> directRoute(String source) async {
    try {
      return (await SourceNetworkPolicies.resolve(source)).proxy.isEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> scopeForStart(String source) async =>
      await directRoute(source) ? currentAccountScope(source) : null;

  bool _policyMatches(Map<String, dynamic> receipt) =>
      accountScope(receipt['source'] as String) == receipt['recoveryScope'] &&
      wifiOnly() == receipt['wifiOnly'];

  static bool _token(Object? value) =>
      value is String && RegExp(r'^[A-Za-z0-9_-]{1,120}$').hasMatch(value);

  static Map<String, dynamic>? _validate(Object? raw) {
    if (raw is! Map) return null;
    final row = Map<String, dynamic>.from(raw);
    final source = row['source'], quality = row['quality'], url = row['url'];
    final page = url is String ? Uri.tryParse(url) : null;
    final scope = row['recoveryScope'],
        key = row['taskKey'],
        attempt = row['attempt'];
    if (source is! String ||
        source.isEmpty ||
        source.length > 200 ||
        quality is! String ||
        quality.length > 80 ||
        page == null ||
        key is! String ||
        key.isEmpty ||
        key.length > 2048 ||
        attempt is! int ||
        attempt <= 0 ||
        row['wifiOnly'] is! bool ||
        scope is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(scope) ||
        !_token(row['assetId']) ||
        !_token(row['generation']) ||
        !const {
          'running',
          'staged',
          'failed',
          'cancelled',
        }.contains(row['status'])) {
      return null;
    }
    try {
      if (VideoHlsAssets.identity(source, page, quality) != row['resourceId'])
        return null;
      return row;
    } on FormatException {
      return null;
    }
  }

  static Future<Object?> _native(String method, [Object? args]) =>
      VideoHlsAssets.channel
          .invokeMethod<Object?>(method, args)
          .timeout(const Duration(seconds: 3));

  static Future<void> acknowledge(Map binding) async {
    try {
      await _native('ackRecovery', {
        'assetId': binding['assetId'],
        'generation': binding['generation'],
        'resourceId': binding['resourceId'],
      });
    } catch (_) {
      // Native retains the receipt for the next scan.
    }
  }

  static Future<void> releaseLiveReceipt(Map binding) async {
    try {
      await _native('releaseRecovery', {
        'assetId': binding['assetId'],
        'generation': binding['generation'],
        'resourceId': binding['resourceId'],
      });
    } catch (_) {
      // A dead process has no live owner when native recovery next opens.
    }
  }

  Future<void> refresh() {
    if (!VideoHlsAssets.supported) return Future.value();
    if (_working case final pending?) {
      _refreshAgain = true;
      return pending;
    }
    return _working = _drain().whenComplete(() => _working = null);
  }

  Future<void> _drain() async {
    do {
      _refreshAgain = false;
      try {
        await _read();
      } catch (_) {
        // A failed bridge/read keeps native receipts available for replay.
      }
    } while (_refreshAgain);
  }

  Future<void> _read() async {
    final snapshot = await _native('recoverySnapshot');
    if (snapshot is! List) return;
    final tasks = await VideoExportRecords.readHlsRecoveryTasks();
    final next = <String, Map<String, dynamic>>{};
    for (final raw in snapshot) {
      final receipt = _validate(raw);
      if (receipt == null) continue;
      final key = receipt['taskKey'] as String;
      final row = tasks[key];
      final matches =
          row != null && VideoExportRecords.matchesHlsRecovery(row, receipt);
      final source = receipt['source'] as String;
      final policyMatches =
          _policyMatches(receipt) &&
          await canUseDirectRoute(source) &&
          _policyMatches(receipt);
      if (receipt['status'] == 'running') {
        if (matches && policyMatches && _inFlight(row['status'])) {
          next[key] = receipt;
        } else {
          await _native('cancelRecovery', VideoHlsAssets.binding(receipt));
        }
        continue;
      }
      await runExclusiveStorageOperation(() async {
        if (matches &&
            (receipt['status'] != 'staged' ||
                policyMatches && await canUseDirectRoute(source))) {
          final accepted = await VideoExportRecords.settleRecoveredHls(
            receipt,
            canPublish: () =>
                !_cancelling.contains(key) &&
                _policyMatches(receipt) &&
                DownloadResourceLifecycle.removing(
                      DownloadResourceLifecycle.video(
                        receipt['resourceId'] as String,
                      ),
                    ) ==
                    null,
            publish: () => VideoHlsAssets.commit(receipt),
          );
          if (accepted) {
            if (receipt['status'] == 'staged') VideoLocalResources.invalidate();
            await acknowledge(receipt);
            return;
          }
        }
        if (receipt['status'] == 'staged' && receipt['available'] != true) {
          await VideoHlsAssets.discard(receipt);
        }
        await acknowledge(receipt);
      });
    }
    _owned
      ..clear()
      ..addAll(next);
    final count = VideoExportRecords.recoveredHlsCount;
    VideoExportRecords.setRecoveredHlsTasks({
      for (final entry in _owned.entries)
        entry.key: entry.value['attempt'] as int,
    });
    if (count != _owned.length) onCapacityChanged();
  }

  static bool _inFlight(Object? status) =>
      const {'preparing', 'downloading', 'saving'}.contains(status);

  Future<void> cancel(String key, int? attempt) async {
    final receipt = _owned[key];
    if (receipt == null || attempt != null && receipt['attempt'] != attempt)
      return;
    await _cancelAndWait(receipt);
  }

  Future<void> _cancelAndWait(Map<String, dynamic> receipt) async {
    final key = receipt['taskKey'] as String;
    final binding = VideoHlsAssets.binding(receipt);
    _cancelling.add(key);
    try {
      await runExclusiveStorageOperation(() async {
        if (await _native('cancelRecovery', binding) != true) {
          throw StateError('Recovered download could not be cancelled');
        }
      });
      final deadline = Stopwatch()..start();
      while (deadline.elapsed < const Duration(seconds: 12)) {
        final snapshot = await _native('recoverySnapshot');
        if (snapshot is! List) throw StateError('Missing HLS task state');
        final running = snapshot.any(
          (entry) =>
              entry is Map &&
              entry['status'] == 'running' &&
              entry['resourceId'] == binding['resourceId'] &&
              entry['assetId'] == binding['assetId'] &&
              entry['generation'] == binding['generation'],
        );
        if (!running) {
          await refresh();
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      throw StateError('Recovered download is still cancelling');
    } finally {
      _cancelling.remove(key);
    }
  }

  Future<void> stopSource(String source) async {
    if (!VideoHlsAssets.supported) return;
    final Object? snapshot;
    try {
      snapshot = await _native('recoverySnapshot');
    } on MissingPluginException {
      return;
    }
    if (snapshot is! List) return;
    for (final entry in snapshot) {
      final receipt = _validate(entry);
      if (receipt?['source'] == source && receipt?['status'] == 'running') {
        await _cancelAndWait(receipt!);
      }
    }
  }
}
