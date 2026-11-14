import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:zephyr/i18n/strings.g.dart';

enum PluginHostCompatibilityReason {
  invalidDeclaration,
  requirementsVersion,
  unknownRequirement,
  videoLibraryProtocol,
}

class PluginHostCapabilities {
  const PluginHostCapabilities({this.videoLibraryProtocols = const {1, 2}});
  final Set<int> videoLibraryProtocols;
  static const current = PluginHostCapabilities();
}

class PluginHostCompatibilityResult {
  PluginHostCompatibilityResult(Iterable<PluginHostCompatibilityReason> reasons)
    : reasons = Set.unmodifiable(reasons);
  final Set<PluginHostCompatibilityReason> reasons;
  bool get supported => reasons.isEmpty;
}

class PluginHostCompatibilityIssue {
  const PluginHostCompatibilityIssue({
    required this.uuid,
    required this.name,
    required this.version,
    required this.reasons,
  });
  final String uuid, name, version;
  final Set<PluginHostCompatibilityReason> reasons;
}

/// Ephemeral, local operation feedback. Never stores scripts, account config,
/// raw requirement values or remote errors, and never participates in backup.
class PluginHostCompatibilityNotices {
  PluginHostCompatibilityNotices._();
  static final instance = PluginHostCompatibilityNotices._();
  final issues = ValueNotifier<List<PluginHostCompatibilityIssue>>(const []);
  static const maxIssues = 2048;

  void record(PluginHostCompatibilityIssue issue) {
    final next =
        issues.value.where((value) => value.uuid != issue.uuid).toList()
          ..add(issue);
    issues.value = List.unmodifiable(
      next.length > maxIssues ? next.sublist(next.length - maxIssues) : next,
    );
  }

  void acknowledge(List<PluginHostCompatibilityIssue> snapshot) {
    issues.value = List.unmodifiable(
      issues.value.where(
        (issue) => !snapshot.any((seen) => identical(seen, issue)),
      ),
    );
  }

  List<PluginHostCompatibilityIssue> takePending() {
    final result = issues.value;
    issues.value = const [];
    return result;
  }
}

class PluginHostCompatibilityException implements Exception {
  const PluginHostCompatibilityException(this.issue);
  final PluginHostCompatibilityIssue issue;
  @override
  String toString() => t.plugin.hostUpgradeRequired;
}

abstract final class PluginHostCompatibility {
  /// Only explicit, versioned requirements and existing native video protocol
  /// declarations are checked. Missing legacy declarations remain compatible;
  /// no script is executed and no minimum SemVer is guessed from plugin names.
  static PluginHostCompatibilityResult checkInfo(
    Map info, {
    PluginHostCapabilities capabilities = PluginHostCapabilities.current,
  }) {
    final reasons = <PluginHostCompatibilityReason>{};
    void protocol(Object? value) {
      if (value is! int ||
          !capabilities.videoLibraryProtocols.contains(value)) {
        reasons.add(PluginHostCompatibilityReason.videoLibraryProtocol);
      }
    }

    if (info.containsKey('requirements')) {
      final requirements = info['requirements'];
      if (requirements is! Map) {
        reasons.add(PluginHostCompatibilityReason.invalidDeclaration);
      } else {
        if (requirements['version'] is! int || requirements['version'] != 1) {
          reasons.add(PluginHostCompatibilityReason.requirementsVersion);
        }
        if (requirements.keys.any(
          (key) => !const {'version', 'capabilities'}.contains(key),
        )) {
          reasons.add(PluginHostCompatibilityReason.unknownRequirement);
        }
        final declared = requirements['capabilities'];
        if (declared is! Map) {
          reasons.add(PluginHostCompatibilityReason.invalidDeclaration);
        } else {
          for (final entry in declared.entries) {
            if (entry.key == 'videoLibraryProtocol') {
              protocol(entry.value);
            } else {
              reasons.add(PluginHostCompatibilityReason.unknownRequirement);
            }
          }
        }
      }
    }
    final functions = info['function'];
    if (functions is List) {
      for (final function in functions) {
        if (function is! Map) continue;
        final action = function['action'];
        if (action is! Map || action['type'] != 'openVideoLibrary') continue;
        final payload = action['payload'];
        if (payload is Map && payload.containsKey('protocol'))
          protocol(payload['protocol']);
      }
    }
    // The existing getInfo reader also accepts {data:{uuid,...}}. Check both
    // declarations rather than letting a compatible wrapper hide an unknown one.
    final data = info['data'];
    if (data is Map) {
      final nested = Map<Object?, Object?>.from(data)..remove('data');
      reasons.addAll(checkInfo(nested, capabilities: capabilities).reasons);
    }
    return PluginHostCompatibilityResult(reasons);
  }

  static PluginHostCompatibilityResult checkStoredInfo(
    String raw, {
    PluginHostCapabilities capabilities = PluginHostCapabilities.current,
  }) {
    if (raw.trim().isEmpty) return PluginHostCompatibilityResult(const []);
    try {
      final value = jsonDecode(raw);
      if (value is Map) return checkInfo(value, capabilities: capabilities);
    } catch (_) {
      /* A malformed explicit metadata record cannot prove support. */
    }
    return PluginHostCompatibilityResult(const [
      PluginHostCompatibilityReason.invalidDeclaration,
    ]);
  }

  static String _label(Object? raw, String fallback) {
    if (raw is! String || raw.trim().isEmpty) return fallback;
    final value = raw.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '').trim();
    return value.length > 160 ? value.substring(0, 160) : value;
  }

  static PluginHostCompatibilityIssue _issue(
    Map info,
    PluginHostCompatibilityResult result, {
    String? uuid,
    String? version,
  }) {
    final id = _label(uuid ?? info['uuid'], 'plugin');
    final data = info['data'];
    return PluginHostCompatibilityIssue(
      uuid: id,
      name: _label(info['name'] ?? (data is Map ? data['name'] : null), id),
      version: _label(version ?? info['version'], ''),
      reasons: result.reasons,
    );
  }

  static void requireCompatibleInfo(Map info, {String? uuid, String? version}) {
    final result = checkInfo(info);
    if (result.supported) return;
    final issue = _issue(info, result, uuid: uuid, version: version);
    PluginHostCompatibilityNotices.instance.record(issue);
    throw PluginHostCompatibilityException(issue);
  }

  /// True means only this installation/update must be skipped. The caller must
  /// keep account config, favorites and records out of this filter.
  static PluginHostCompatibilityIssue? unsupportedPluginInfo(Map row) {
    if (row['isDeleted'] == true) return null;
    final raw = row['getInfoJson'];
    final result = checkStoredInfo(raw is String ? raw : '');
    if (result.supported) return null;
    Map info = const {};
    try {
      final value = jsonDecode(raw as String);
      if (value is Map) info = value;
    } catch (_) {}
    return _issue(
      info,
      result,
      uuid: row['uuid'] is String ? row['uuid'] as String : null,
      version: row['version'] is String ? row['version'] as String : null,
    );
  }

  static bool reportSkippedPluginInfo(Map row) {
    final issue = unsupportedPluginInfo(row);
    if (issue == null) return false;
    PluginHostCompatibilityNotices.instance.record(issue);
    return true;
  }

  static void requireCompatiblePluginInfo(Map row) {
    final issue = unsupportedPluginInfo(row);
    if (issue == null) return;
    PluginHostCompatibilityNotices.instance.record(issue);
    throw PluginHostCompatibilityException(issue);
  }

  /// Full replacement clears PluginInfo, so retain the current same-source
  /// script for skipped candidates. Other data tables are deliberately absent.
  static List<dynamic> projectRestoredPluginInfos(
    List<dynamic> incoming,
    List<dynamic> local,
  ) {
    final retained = <String, Map>{
      for (final row in local)
        if (row is Map && row['uuid'] is String) row['uuid'] as String: row,
    };
    return [
      for (final row in incoming)
        if (row is! Map || !reportSkippedPluginInfo(row))
          row
        else if (retained[row['uuid']] != null)
          <String, dynamic>{
            ...Map<String, dynamic>.from(retained[row['uuid']]!),
            'id': 0,
          },
    ];
  }
}
