import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:zephyr/network/http/picture/picture.dart';
import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/service/download/download_admission.dart';
import 'package:zephyr/service/download/download_cancel_signal.dart';
import 'package:zephyr/service/download/image_download.dart';
import 'package:zephyr/service/download/ios_background_transfer.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/service/plugin_account_identity.dart';

const _maxPageBytes = 64 * 1024 * 1024;

final class _UnsupportedBackgroundImages implements Exception {
  const _UnsupportedBackgroundImages();
}

bool _publicImageOrigin(Uri uri) =>
    uri.scheme == 'https' &&
    uri.userInfo.isEmpty &&
    !uri.hasQuery &&
    !uri.hasFragment &&
    (!uri.hasPort || uri.port == 443) &&
    RegExp(
      r'^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,63}$',
    ).hasMatch(uri.host) &&
    !uri.host.endsWith('.localhost') &&
    !uri.host.endsWith('.local');

/// Optional request declarations. Old plug-ins and private/scripted requests
/// continue through fetchImageBytes. A declaration never changes chapter IDs.
Map<String, String>? comicBackgroundHeaders(DownloadImageJob job) {
  final declaration = job.extern['backgroundDownload'];
  if (declaration is! Map ||
      declaration['version'] != 1 ||
      declaration['credentialFree'] != true ||
      declaration['redirectPolicy'] != 'same-url')
    return null;
  final uri = Uri.tryParse(job.url);
  if (uri == null || !_publicImageOrigin(uri)) return null;
  final raw = declaration['headers'];
  if (raw is! Map || raw.length > 5) return null;
  const allowed = {
    'accept': 'Accept',
    'accept-language': 'Accept-Language',
    'user-agent': 'User-Agent',
    'referer': 'Referer',
    'x-requested-with': 'X-Requested-With',
  };
  final headers = <String, String>{};
  for (final entry in raw.entries) {
    final key = entry.key, value = entry.value;
    if (key is! String ||
        value is! String ||
        value.length > 2000 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(value))
      return null;
    final normalized = allowed[key.toLowerCase()];
    if (normalized == null || headers.containsKey(normalized)) return null;
    if (normalized == 'Referer') {
      final ref = Uri.tryParse(value);
      if (ref == null ||
          !_publicImageOrigin(ref) ||
          (ref.path.isNotEmpty && ref.path != '/'))
        return null;
    }
    headers[normalized] = value;
  }
  return headers;
}

String _hash(Object value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString();

/// Reads native staged bytes into the existing image validation/deobfuscation
/// and atomic chapter commit. Native never writes the published comic tree.
final class ComicBackgroundDownload {
  ComicBackgroundDownload._(this.binding, this._jobs, this._isCurrent) {
    _subscription = IosBackgroundTransfer.changes.listen((_) => _wake());
    _sessionSubscription = pluginSessionWriteFence.changes.listen((event) {
      if (event.source == binding['source']) _wake();
    });
    _registrySubscription = PluginRegistryService.I.stream.listen(
      (_) => _wake(),
    );
    DownloadAdmission.instance.addListener(_wake);
  }

  final Map<String, dynamic> binding;
  final List<DownloadImageJob> _jobs;
  final bool Function() _isCurrent;
  late final StreamSubscription<void> _subscription;
  late final StreamSubscription<PluginSessionBoundary> _sessionSubscription;
  late final StreamSubscription<Object?> _registrySubscription;
  Completer<void> _changed = Completer<void>();
  bool _closed = false;
  Future<void>? _closing;

  static String? currentScope(String source) {
    final state = LocalPluginInstallationState.instance;
    final plugin = PluginRegistryService.I.getByUuid(source);
    if (plugin == null ||
        !plugin.isActive ||
        state.isRemoved(source) ||
        state.isInstalling(source) ||
        pluginSessionWriteFence.isChanging(source))
      return null;
    return _hash([
      'comic-background-v1',
      source,
      state.installationEpoch(source),
      plugin.version,
      PluginAccountIdentities.fingerprint(source),
    ]);
  }

  static Future<ComicBackgroundDownload?> prepare({
    required DownloadTaskJson task,
    required List<DownloadImageJob> jobs,
    required int concurrency,
    required Future<void> Function() ensureTaskRunning,
  }) async {
    if (!IosBackgroundTransfer.supported || jobs.isEmpty || jobs.length > 500)
      return null;
    final headers = jobs.map(comicBackgroundHeaders).toList();
    if (headers.any((value) => value == null)) return null;
    final scope = currentScope(task.from);
    if (scope == null ||
        !(await downloadTaskUsesDirectNetwork(task.from, task.taskKey)))
      return null;
    await ensureTaskRunning();
    final pending = <DownloadImageJob>[];
    final pendingHeaders = <Map<String, String>>[];
    for (var i = 0; i < jobs.length; i++) {
      final job = jobs[i];
      if (await hasCommittedDownloadPage(
        from: task.from,
        path: job.path,
        cartoonId: job.cartoonId,
        chapterId: job.chapterId,
        storageChapterId: job.storageChapterId,
      ))
        continue;
      pending.add(job);
      pendingHeaders.add(headers[i]!);
    }
    await ensureTaskRunning();
    if (pending.isEmpty) {
      await cancelMatching(taskKey: task.taskKey);
      return null;
    }
    final wifiOnly = DownloadAdmission.instance.wifiOnly;
    final manifest = _hash([
      task.taskKey,
      for (var i = 0; i < pending.length; i++)
        [
          pending[i].path,
          pending[i].url,
          pending[i].chapterId,
          pending[i].storageChapterId,
          pendingHeaders[i],
        ],
    ]);
    final resource = _hash(['comic', task.taskKey]);
    bool current() =>
        !isDownloadCancelSignaled(task.taskKey) &&
        currentScope(task.from) == scope &&
        DownloadAdmission.instance.wifiOnly == wifiOnly;
    try {
      return await start(
        source: task.from,
        taskKey: task.taskKey,
        attempt: task.attempt,
        scope: scope,
        resourceId: resource,
        manifestId: manifest,
        wifiOnly: wifiOnly,
        jobs: pending,
        headers: pendingHeaders,
        concurrency: concurrency.clamp(1, 8),
        isCurrent: current,
      );
    } on MissingPluginException {
      return null;
    } on _UnsupportedBackgroundImages {
      // Native may decline a header/URL combination supported by the plug-in's
      // original transport. A rejected request was never allowed to publish.
      return null;
    }
  }

  static Future<ComicBackgroundDownload> start({
    required String source,
    required String taskKey,
    required int attempt,
    required String scope,
    required String resourceId,
    required String manifestId,
    required bool wifiOnly,
    required List<DownloadImageJob> jobs,
    required List<Map<String, String>> headers,
    required int concurrency,
    required bool Function() isCurrent,
  }) async {
    // The plan hash includes isolated page-generation paths. A deliberate new
    // download cannot adopt a deleted attempt merely because titles match.
    final snapshots = await IosBackgroundTransfer.snapshot();
    Map<String, dynamic>? retained;
    for (final row in snapshots.where(
      (row) => row['kind'] == 'comic' && row['taskKey'] == taskKey,
    )) {
      if (retained == null &&
          row['source'] == source &&
          row['scope'] == scope &&
          row['resourceId'] == resourceId &&
          row['manifestId'] == manifestId &&
          row['wifiOnly'] == wifiOnly &&
          const {'running', 'staged'}.contains(row['status'])) {
        retained = bindingOf(row);
      } else {
        await _cancelBinding(bindingOf(row));
      }
    }
    if (!isCurrent()) throw const DownloadTaskCancelledException();
    final binding =
        retained ??
        <String, dynamic>{
          'batchId': const Uuid().v4(),
          'kind': 'comic',
          'source': source,
          'scope': scope,
          'taskKey': taskKey,
          'attempt': attempt,
          'resourceId': resourceId,
          'manifestId': manifestId,
          'wifiOnly': wifiOnly,
        };
    final result = ComicBackgroundDownload._(binding, jobs, isCurrent);
    try {
      if (retained == null &&
          !await IosBackgroundTransfer.submit(binding, [
            for (var i = 0; i < jobs.length; i++)
              {
                'index': i,
                'url': jobs[i].url,
                'headers': headers[i],
                'maxBytes': _maxPageBytes,
                'redirectPolicy': 'same-url',
              },
          ], concurrency: concurrency)) {
        throw const _UnsupportedBackgroundImages();
      }
      if (!isCurrent()) throw const DownloadTaskCancelledException();
      return result;
    } catch (_) {
      await result.close();
      rethrow;
    }
  }

  static Map<String, dynamic> bindingOf(Map<String, dynamic> row) => {
    for (final key in const [
      'batchId',
      'kind',
      'source',
      'scope',
      'taskKey',
      'attempt',
      'resourceId',
      'manifestId',
      'wifiOnly',
    ])
      key: row[key],
  };

  void _wake() {
    final previous = _changed;
    _changed = Completer<void>();
    if (!previous.isCompleted) previous.complete();
  }

  Future<Uint8List> read(DownloadImageJob job) async {
    final index = _jobs.indexOf(job);
    if (index < 0) throw StateError('Page is not in the accepted manifest');
    while (!_closed && _isCurrent()) {
      final wait = _changed.future;
      final snapshot = await IosBackgroundTransfer.snapshot();
      if (_closed || !_isCurrent()) break;
      final row = snapshot
          .where((row) => row['batchId'] == binding['batchId'])
          .firstOrNull;
      final items = row?['items'];
      final item = items is List
          ? items
                .whereType<Map>()
                .where((item) => item['index'] == index)
                .firstOrNull
          : null;
      if (item?['status'] == 'staged') {
        final stage = await IosBackgroundTransfer.holdStage(binding, index);
        if (stage == null)
          throw const FileSystemException('Background image is unavailable');
        try {
          final file = File(stage.path);
          final bytes = await file.length();
          if (bytes <= 0 || bytes > _maxPageBytes)
            throw const DownloadPictureInvalidPayload(incomplete: false);
          final data = await file.readAsBytes();
          if (_closed || !_isCurrent()) break;
          return data;
        } finally {
          await stage.release();
        }
      }
      if (row == null ||
          const {'failed', 'cancelled'}.contains(item?['status']) ||
          const {'failed', 'cancelled'}.contains(row['status'])) {
        final reason = item?['reason'];
        if (reason == 'redirectRejected' || reason == 'mediaRejected') {
          throw const DownloadPictureInvalidPayload(incomplete: false);
        }
        throw DownloadPictureHttpException(
          job.url,
          switch (reason) {
            'timeout' => 'Request timed out',
            'network' => 'Network error',
            _ => 'Background image transfer did not complete',
          },
          statusCode: switch (item?['httpStatus']) {
            final int status when status >= 300 => status,
            _ => null,
          },
        );
      }
      await raceWithDownloadCancel(binding['taskKey'] as String, wait);
    }
    throw const DownloadTaskCancelledException();
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _closed = true;
    _wake();
    await _subscription.cancel();
    await _sessionSubscription.cancel();
    await _registrySubscription.cancel();
    DownloadAdmission.instance.removeListener(_wake);
    // Completed images have already passed the normal durable page writer.
    // Stop every remaining native writer before chapter/queue cleanup runs.
    try {
      await _cancelBinding(binding);
    } catch (_) {
      _closing = null;
      rethrow;
    }
  }

  static Future<void> _cancelBinding(Map<String, dynamic> binding) async {
    if (!await IosBackgroundTransfer.cancel(binding) ||
        !await IosBackgroundTransfer.ack(binding)) {
      throw const FileSystemException('Background image cleanup is incomplete');
    }
  }

  static Future<void> cancelMatching({String? taskKey, String? source}) async {
    if (!IosBackgroundTransfer.supported) return;
    for (final row in await _snapshotsIfSupported()) {
      if (row['kind'] == 'comic' &&
          (taskKey == null || row['taskKey'] == taskKey) &&
          (source == null || row['source'] == source)) {
        await _cancelBinding(bindingOf(row));
      }
    }
  }

  static Future<List<Map<String, dynamic>>> _snapshotsIfSupported() async {
    try {
      return await IosBackgroundTransfer.snapshot();
    } on MissingPluginException {
      return const [];
    }
  }

  /// Called before queue admission. Only identities still present and runnable
  /// may retain a daemon writer after recovery, restore, or a source change.
  static Future<void> reconcile(
    bool Function(Map<String, dynamic>) keep,
  ) async {
    if (!IosBackgroundTransfer.supported) return;
    for (final row in await _snapshotsIfSupported()) {
      if (row['kind'] == 'comic' && !keep(row)) {
        await _cancelBinding(bindingOf(row));
      }
    }
  }
}
