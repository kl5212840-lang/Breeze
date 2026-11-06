import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:zephyr/plugin/utils/plugin_version_utils.dart';

/// Public versions restart only in an explicitly published release series.
/// Unrecognised local builds never cross a series boundary automatically.
abstract final class PluginReleasePolicy {
  static int series(Map<String, dynamic> info) {
    final value = info['releaseSeries'];
    return value is int && value >= 0 ? value : 0;
  }

  static String scriptDigest(String script) =>
      sha256.convert(utf8.encode(script.trim())).toString();

  /// Ordering for catalog snapshots, which do not represent installed scripts.
  static int compareCatalog(
    Map<String, dynamic> remote,
    Map<String, dynamic> local,
  ) {
    final generation = series(remote).compareTo(series(local));
    if (generation != 0) return generation;
    return compareVersion(
      '${remote['version'] ?? ''}',
      '${local['version'] ?? ''}',
    );
  }

  static bool canUpgrade({
    required String uuid,
    required String localVersion,
    required String localScript,
    required Map<String, dynamic> localInfo,
    required Map<String, dynamic> remoteInfo,
  }) {
    if (remoteInfo['uuid']?.toString() != uuid) return false;
    final localSeries = series(localInfo);
    final remoteSeries = series(remoteInfo);
    if (remoteSeries < localSeries) return false;
    if (remoteSeries == localSeries) {
      return compareVersion('${remoteInfo['version'] ?? ''}', localVersion) > 0;
    }
    // This migration covers the five identified public legacy bundles only.
    if (localSeries != 0 || remoteSeries != 1 || localScript.trim().isEmpty) {
      return false;
    }
    final allowed = remoteInfo['migrationFrom'];
    if (allowed is! List) return false;
    final digest = scriptDigest(localScript);
    return allowed.whereType<Map>().any(
      (entry) =>
          entry['version'] == localVersion && entry['scriptSha256'] == digest,
    );
  }

  /// Check decoded script integrity before executing getInfo in the runtime.
  static void verifyScript(String script, Map<String, dynamic> expected) {
    final digest = expected['scriptSha256'];
    if (series(expected) > 0 &&
        (digest is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(digest))) {
      throw StateError('插件更新缺少有效的文件校验信息');
    }
    if (digest is String &&
        digest.isNotEmpty &&
        scriptDigest(script) != digest) {
      throw StateError('插件文件校验失败，已保留本机版本');
    }
  }

  static void verifyInfo(
    Map<String, dynamic> actual,
    Map<String, dynamic> expected,
  ) {
    if (actual['uuid'] != expected['uuid'] ||
        series(actual) != series(expected) ||
        compareVersion(
              '${actual['version'] ?? ''}',
              '${expected['version'] ?? ''}',
            ) !=
            0) {
      throw StateError('插件信息与更新目录不一致，已保留本机版本');
    }
  }
}
