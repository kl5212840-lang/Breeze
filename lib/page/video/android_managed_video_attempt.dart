import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:zephyr/network/source_network_policy.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/service/plugin_account_identity.dart';

/// The Android process can retain an MP4 writer across Flutter engine detach.
/// The public task and attempt identify it independently of its signed URL.
class AndroidManagedVideoAttempt {
  const AndroidManagedVideoAttempt._({
    required this.taskKey,
    required this.attempt,
    required this.resourceId,
    required this.source,
    required this.video,
    required this.quality,
    required this.scope,
  });

  static const channel = MethodChannel('breeze.video.download');
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static String? keyFor(String? taskKey, int? attempt) =>
      supported && taskKey != null && attempt != null && attempt > 0
      ? _digest([taskKey, attempt])
      : null;

  static String _digest(List<Object?> parts) =>
      sha256.convert(utf8.encode(jsonEncode(parts))).toString();

  /// Only the opaque scope crosses the native channel and it lives in memory.
  static String? scopeFor(String source) {
    if (!supported || source.isEmpty) return null;
    if (!SourceNetworkPolicies.supports(source)) return _digest([source]);
    try {
      final installation = LocalPluginInstallationState.instance;
      final plugin = PluginRegistryService.I.getByUuid(source);
      if (plugin == null ||
          plugin.isDeleted ||
          installation.isRemoved(source) ||
          installation.isInstalling(source)) {
        return null;
      }
      return _digest([
        source,
        installation.installationEpoch(source),
        plugin.version,
        PluginAccountIdentities.fingerprint(source),
      ]);
    } catch (_) {
      return null;
    }
  }

  static AndroidManagedVideoAttempt? interrupted(Map<String, dynamic> row) {
    if (!supported ||
        row['status'] != 'interrupted' ||
        (row['format'] ?? 'mp4') != 'mp4') {
      return null;
    }
    final taskKey = row['key'],
        attempt = row['attempt'],
        source = row['source'];
    final url = row['url'],
        quality = row['quality'],
        resourceId = row['resourceId'];
    if (taskKey is! String ||
        taskKey.isEmpty ||
        attempt is! int ||
        attempt <= 0 ||
        source is! String ||
        source.isEmpty ||
        url is! String ||
        quality is! String ||
        quality.isEmpty ||
        resourceId is! String ||
        !VideoLocalResources.validId(resourceId)) {
      return null;
    }
    final video = videoPlaybackIdentity(Uri.tryParse(url) ?? Uri());
    if (video == null ||
        video.toString() != url ||
        VideoLocalResources.identity(source, video, quality) != resourceId) {
      return null;
    }
    final scope = scopeFor(source);
    if (scope == null) return null;
    return AndroidManagedVideoAttempt._(
      taskKey: taskKey,
      attempt: attempt,
      resourceId: resourceId,
      source: source,
      video: video,
      quality: quality,
      scope: scope,
    );
  }

  final String taskKey, resourceId, source, quality, scope;
  final int attempt;
  final Uri video;
  String get transferKey => keyFor(taskKey, attempt)!;
  bool get scopeIsCurrent => scopeFor(source) == scope;

  Map<String, String> get _identity => {
    'managedId': resourceId,
    'transferKey': transferKey,
    'scope': scope,
  };

  Future<String?> status() async {
    try {
      return await channel.invokeMethod<String>('status', _identity);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<Object?> attach(String id) =>
      channel.invokeMethod<Object?>('attach', {..._identity, 'id': id});

  Future<void> cancel() async {
    try {
      await channel.invokeMethod<void>('cancel', {
        'transferKey': transferKey,
        'scope': scope,
      });
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}
