import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_hls_assets.dart';
import 'package:zephyr/service/local_import_recovery.dart';

/// This bridge never accepts a URL or path. Android currently has no local
/// frame API; it keeps the ordinary source poster or play placeholder.
abstract final class VideoLocalPoster {
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static const _mp4 = MethodChannel('breeze.video.download');
  static Future<void>? _pending;
  static String binding(Map<String, dynamic> row) => jsonEncode([
    row['resourceId'],
    row['source'],
    row['url'],
    row['quality'],
    row['format'] ?? 'mp4',
    row['taskKey'],
    row['at'],
    row['bytes'],
    row['assetId'],
    row['generation'],
  ]);

  static Future<Map<String, dynamic>?> current(
    Map<String, dynamic> requested,
  ) async {
    final id = requested['resourceId'];
    if (id is! String || !VideoLocalResources.validId(id)) return null;
    LocalImportRecovery.requireRecovered();
    final row = requested['format'] == 'hls'
        ? (await VideoHlsAssets.read())
              .where((row) => row['resourceId'] == id)
              .firstOrNull
        : await VideoLocalResources.readMp4PosterResource(id);
    if (row == null ||
        !const ['mp4', 'hls'].contains(row['format'] ?? 'mp4') ||
        row['available'] != true ||
        row['filePresent'] != true ||
        row['source'] != requested['source'] ||
        row['url'] != requested['url'] ||
        row['quality'] != requested['quality'] ||
        (row['format'] ?? 'mp4') != (requested['format'] ?? 'mp4'))
      return null;
    if (row['format'] == 'hls' &&
        (row['assetId'] != requested['assetId'] ||
            row['generation'] != requested['generation']))
      return null;
    return row;
  }

  static Future<bool> capture(
    Map<String, dynamic> row, {
    required Future<bool> Function() begin,
    required Future<void> Function(Uint8List) consume,
  }) {
    if (!supported) return Future.value(false);
    final previous = _pending;
    final result = () async {
      if (previous != null) await previous;
      ManagedVideoReadLease? lease;
      try {
        final fresh = await current(row);
        if (fresh == null || binding(fresh) != binding(row)) return false;
        final id = row['resourceId'] as String;
        final hls = row['format'] == 'hls';
        Map<String, dynamic> arguments;
        if (hls) {
          final checked = VideoHlsAssets.validateRow(row);
          lease = VideoLocalResources.acquireHlsReadLease(id);
          arguments = {
            'resourceId': id,
            'assetId': checked['assetId'],
            'generation': checked['generation'],
          };
        } else {
          final file = await VideoLocalResources.file(id);
          if (!await file.exists()) return false;
          lease = VideoLocalResources.acquireReadLease(Uri.file(file.path), id);
          arguments = {'resourceId': id};
        }
        if (!await begin()) return false;
        final value = await (hls ? VideoHlsAssets.channel : _mp4)
            .invokeMethod<Uint8List>('poster', arguments)
            .timeout(const Duration(seconds: 8));
        if (value == null || value.isEmpty || value.length > 1024 * 1024)
          return false;
        final latest = await current(row);
        if (latest == null || binding(latest) != binding(row)) return false;
        await consume(value);
        return true;
      } on MissingPluginException {
        return false;
      } on PlatformException {
        return false;
      } on TimeoutException {
        return false;
      } on FileSystemException {
        return false;
      } catch (_) {
        return false;
      } finally {
        lease?.release();
      }
    }();
    final done = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _pending = done;
    done.then((_) {
      if (identical(_pending, done)) _pending = null;
    });
    return result;
  }
}
