import 'package:zephyr/config/global/global.dart';
import 'package:zephyr/i18n/strings.g.dart';

class SyncRunResult {
  const SyncRunResult({
    this.newArchiveSynced = false,
    this.legacyArchiveImported = false,
    this.legacyCompatibilityRequested = false,
    this.legacyCompatibilityUpdated = false,
    this.newArchiveNeedsFollowup = false,
    this.runtimeReloadPending = false,
  });
  final bool newArchiveSynced,
      legacyArchiveImported,
      legacyCompatibilityRequested,
      legacyCompatibilityUpdated,
      newArchiveNeedsFollowup,
      runtimeReloadPending;
  bool get compatibilityIncomplete =>
      newArchiveSynced &&
      legacyCompatibilityRequested &&
      !legacyCompatibilityUpdated;
}

class LegacyArchiveAvailable implements Exception {
  const LegacyArchiveAvailable();
  @override
  String toString() => t.settings.legacyArchiveAvailable;
}

class LegacyArchiveReadOnly implements Exception {
  const LegacyArchiveReadOnly();
  @override
  String toString() => t.settings.legacyArchiveReadOnly;
}

class ArchiveRestoreFailed implements Exception {
  const ArchiveRestoreFailed();
  @override
  String toString() => t.settings.archiveRestoreFailed;
}

class LegacyCompatibilityFailed implements Exception {
  const LegacyCompatibilityFailed({this.legacyImported = false});
  final bool legacyImported;
  @override
  String toString() => t.settings.legacyCompatibilityFailed;
}

class SyncArchiveContext {
  const SyncArchiveContext._(this.legacy, this.readOnly);
  static const current = SyncArchiveContext._(false, false);
  static const legacyReadOnly = SyncArchiveContext._(true, true);
  final bool legacy, readOnly;
  static String get currentRoot => '${appName}_v2';
  static String get legacyRoot => '${appName}_v1';
  String get root => legacy ? legacyRoot : currentRoot;
}
