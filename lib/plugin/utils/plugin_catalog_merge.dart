import 'dart:convert';

import 'package:zephyr/plugin/utils/plugin_version_utils.dart';
import 'package:zephyr/plugin/utils/published_plugin_artifact.dart';
import 'package:zephyr/util/json/json_value.dart';

const personalPluginCatalogRepository = 'kl5212840-lang/Breeze-plugins';

/// Only these explicitly managed forks may replace a matching official UUID.
const managedPluginUuids = <String>{
  'e9f18928-3ba8-4d86-a12e-b53a62f47933',
  '6886291b-f524-441c-844b-c2efae9899a9',
  'b28da416-f2d4-4208-a85e-8b4c7c648e48',
  'f5387e66-9c58-4b8f-beb7-22a939f79e5d',
  '1e600cff-8ebe-4517-8aa4-6678aec46424',
};

List<dynamic>? decodeCloudPluginCatalog(
  String? payload, {
  bool allowEmpty = false,
}) {
  try {
    return _validateEntries(jsonDecode(payload ?? ''), allowEmpty: allowEmpty);
  } catch (_) {
    return null;
  }
}

List<dynamic>? _validateEntries(Object? decoded, {required bool allowEmpty}) {
  if (decoded is! List || (!allowEmpty && decoded.isEmpty)) return null;
  if (!decoded.every((entry) => cloudPluginUuid(entry).isNotEmpty)) return null;
  return decoded;
}

String cloudPluginUuid(Object? entry) {
  if (entry is! Map || entry['manifest'] is! Map) return '';
  return entry['manifest']['uuid']?.toString().trim() ?? '';
}

/// Independent source failures must never discard another usable catalog.
String mergeCloudPluginCatalogPayloads(
  String officialPayload,
  String? extraPayload,
) {
  final official = decodeCloudPluginCatalog(officialPayload);
  final extra = decodeCloudPluginCatalog(extraPayload);
  if (extra == null) return officialPayload;
  return jsonEncode(_mergeEntries(official ?? const [], extra));
}

List<dynamic> _mergeEntries(
  List<dynamic> official,
  List<dynamic> extra, {
  Set<Object?> authoritativeEntries = const {},
}) {
  final originals = {
    for (final entry in official) cloudPluginUuid(entry): entry,
  };
  final seen = <String>{};
  final independent = <dynamic>[];
  for (final entry in extra) {
    final uuid = cloudPluginUuid(entry);
    if (!seen.add(uuid)) continue;
    final original = originals[uuid];
    if (original != null) {
      if (!managedPluginUuids.contains(uuid)) continue;
      final oldVersion = original['manifest']['version']?.toString() ?? '';
      final newVersion = entry['manifest']['version']?.toString() ?? '';
      final sameChannel = original['repo'] == entry['repo'];
      independent.add(
        sameChannel &&
                !authoritativeEntries.contains(entry) &&
                compareVersion(oldVersion, newVersion) > 0
            ? original
            : entry,
      );
    } else {
      independent.add(entry);
    }
  }
  final overridden = independent.map(cloudPluginUuid).toSet();
  return [
    ...independent,
    ...official.where((entry) => !overridden.contains(cloudPluginUuid(entry))),
  ];
}

typedef CloudPluginCatalogEntry = ({
  Map<String, dynamic> json,
  FormalPluginRelease? formalRelease,
});

/// This proof comes from the live first-party v1 catalog. Ordinary catalog
/// JSON, cached rows, self-update indexes and local CJS cannot grant it.
class FormalPluginRelease {
  const FormalPluginRelease._({
    required this.uuid,
    required this.version,
    required this.updateUrl,
    required this.scriptSha256,
    required this.migrationFrom,
  });

  final String uuid;
  final String version;
  final String updateUrl;
  final String scriptSha256;
  final List<({String version, String hash})> migrationFrom;

  bool isConfirmedBy(Map<String, dynamic> index) =>
      index['releaseSeries'] == 1 &&
      index['uuid'] == uuid &&
      normalizePublishedPluginVersion(index['tag_name']?.toString() ?? '') ==
          version &&
      parsePublishedPluginSha256(index['scriptSha256']) == scriptSha256;

  void verifyTargetInfo(Map<String, dynamic> info) {
    if (info['releaseSeries'] != 1 ||
        info['uuid'] != uuid ||
        normalizePublishedPluginVersion(info['version']?.toString() ?? '') !=
            version ||
        _formalPluginIndex(info['updateUrl']) != updateUrl ||
        (info['npmName']?.toString().trim().isNotEmpty ?? false)) {
      throw StateError('插件更新通道与商店清单不一致，请刷新插件商店后重试');
    }
  }

  static FormalPluginRelease? _read(Object? entry) {
    final item = asJsonMap(entry);
    final manifest = asJsonMap(item['manifest']);
    final uuid = cloudPluginUuid(item);
    final version = normalizePublishedPluginVersion(
      manifest['version']?.toString() ?? '',
    );
    final url = _formalPluginIndex(manifest['updateUrl']);
    final hash = parsePublishedPluginSha256(manifest['scriptSha256']);
    if (item['repo'] != personalPluginCatalogRepository ||
        manifest['releaseSeries'] != 1 ||
        (manifest['npmName']?.toString().trim().isNotEmpty ?? false) ||
        version.isEmpty ||
        url == null ||
        hash == null) {
      return null;
    }
    return FormalPluginRelease._(
      uuid: uuid,
      version: version,
      updateUrl: url,
      scriptSha256: hash,
      migrationFrom: List.unmodifiable(_readMigrationFingerprints(manifest)),
    );
  }

  PluginReleaseMigration? migrationFor({
    required String installedUuid,
    required String installedVersion,
    required String Function() scriptFingerprint,
  }) {
    if (installedUuid != uuid || !managedPluginUuids.contains(uuid)) {
      return null;
    }
    final version = normalizePublishedPluginVersion(installedVersion);
    final candidates = migrationFrom.where((old) => old.version == version);
    if (candidates.isEmpty) return null;
    final fingerprint = scriptFingerprint();
    if (fingerprint == scriptSha256 ||
        !candidates.any((old) => old.hash == fingerprint)) {
      return null;
    }
    return PluginReleaseMigration._(this, version, fingerprint);
  }
}

class PluginReleaseMigration {
  const PluginReleaseMigration._(this.release, this.oldVersion, this.oldHash);

  final FormalPluginRelease release;
  final String oldVersion;
  final String oldHash;

  bool isConfirmedBy(Map<String, dynamic> index) =>
      release.isConfirmedBy(index) &&
      _readMigrationFingerprints(
        index,
      ).contains((version: oldVersion, hash: oldHash));

  void verifyTargetInfo(Map<String, dynamic> info) =>
      release.verifyTargetInfo(info);
}

Iterable<({String version, String hash})> _readMigrationFingerprints(
  Map<String, dynamic> data,
) sync* {
  for (final value in asJsonList(data['migrationFrom'])) {
    final entry = asJsonMap(value);
    final version = normalizePublishedPluginVersion(
      entry['version']?.toString() ?? '',
    );
    final hash = parsePublishedPluginSha256(entry['scriptSha256']);
    if (version.isNotEmpty && hash != null) {
      yield (version: version, hash: hash);
    }
  }
}

String? _formalPluginIndex(Object? value) {
  final url = value is String ? value.trim() : '';
  return RegExp(
        '^https://raw\\.githubusercontent\\.com/$personalPluginCatalogRepository/main/updates/v1/[a-z0-9-]+\\.json\$',
      ).hasMatch(url)
      ? url
      : null;
}

bool requiresFormalPluginRelease(String updateUrl) =>
    _formalPluginIndex(updateUrl) != null;

/// An installed formal CJS identifies its channel in getInfo. Keep that
/// channel when the merged catalog falls back to a legacy or upstream entry.
bool preservesFormalPluginChannel({
  required Map<String, dynamic>? installedInfo,
  required String updateUrl,
  required String npmName,
}) {
  if (installedInfo?['releaseSeries'] != 1) return true;
  final installedIndex = _formalPluginIndex(installedInfo?['updateUrl']);
  return installedIndex == null ||
      (npmName.trim().isEmpty && updateUrl.trim() == installedIndex);
}

class CloudPluginCatalogSnapshot {
  const CloudPluginCatalogSnapshot({
    this.official = const [],
    this.personal = const [],
    this.personalVersioned = false,
  }) : _liveVersioned = false;

  const CloudPluginCatalogSnapshot._loaded(
    this._liveVersioned, {
    required this.official,
    required this.personal,
    required this.personalVersioned,
  });

  final List<dynamic> official;
  final List<dynamic> personal;
  final bool personalVersioned;
  final bool _liveVersioned;

  Iterable<CloudPluginCatalogEntry> get entries {
    final trusted = Map<Object?, FormalPluginRelease>.identity();
    if (_liveVersioned) {
      final counts = <String, int>{};
      for (final entry in personal) {
        counts.update(
          cloudPluginUuid(entry),
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
      for (final entry in personal) {
        if (counts[cloudPluginUuid(entry)] != 1) continue;
        final release = FormalPluginRelease._read(entry);
        if (release != null) trusted[entry] = release;
      }
    }
    return _mergeEntries(
      official,
      personal,
      authoritativeEntries: trusted.keys.toSet(),
    ).map((entry) => (json: asJsonMap(entry), formalRelease: trusted[entry]));
  }

  String get payload => jsonEncode(entries.map((entry) => entry.json).toList());

  String toCacheJson() => jsonEncode({
    'official': official,
    'personal': personal,
    'personalVersioned': personalVersioned,
  });

  static CloudPluginCatalogSnapshot? fromCacheJson(String? raw) {
    try {
      final decoded = jsonDecode(raw ?? '');
      if (decoded is! Map) return null;
      final official = _validateEntries(decoded['official'], allowEmpty: true);
      final personal = _validateEntries(decoded['personal'], allowEmpty: true);
      final versioned = decoded['personalVersioned'];
      if (official == null || personal == null || versioned is! bool) {
        return null;
      }
      return CloudPluginCatalogSnapshot(
        official: official,
        personal: personal,
        personalVersioned: versioned,
      );
    } catch (_) {
      return null;
    }
  }

  /// Older clients cached the merged list. Recover catalogue ownership once
  /// from the repository of each entry, including new UUIDs from our repo.
  factory CloudPluginCatalogSnapshot.fromLegacyCache({
    required String? combined,
    required String bundled,
  }) {
    bool isPersonal(dynamic entry) {
      final repo =
          (entry as Map)['repo']?.toString().trim().toLowerCase() ?? '';
      return repo == personalPluginCatalogRepository.toLowerCase() ||
          (repo.isEmpty && managedPluginUuids.contains(cloudPluginUuid(entry)));
    }

    final saved = decodeCloudPluginCatalog(combined) ?? const [];
    final bundledEntries = decodeCloudPluginCatalog(bundled) ?? const [];
    final bundledVersions = {
      for (final entry in bundledEntries)
        if (FormalPluginRelease._read(entry) case final release?)
          release.uuid: release.version,
    };
    return CloudPluginCatalogSnapshot(
      official: saved.where((entry) => !isPersonal(entry)).toList(),
      personal: _mergeEntries(
        bundledEntries,
        saved.where((entry) {
          if (!isPersonal(entry)) return false;
          final bundledVersion = bundledVersions[cloudPluginUuid(entry)];
          if (bundledVersion == null ||
              FormalPluginRelease._read(entry) != null) {
            return true;
          }
          final version =
              asJsonMap(entry['manifest'])['version']?.toString() ?? '';
          return compareVersion(version, bundledVersion) > 0;
        }).toList(),
      ),
    );
  }
}

/// Both requests start together. Invalid HTML/JSON and timeouts are source-local.
Future<CloudPluginCatalogSnapshot> loadCloudPluginCatalog({
  required Future<String?> Function() official,
  required Future<String?> Function() personal,
  Future<String?> Function()? legacyPersonal,
  required CloudPluginCatalogSnapshot fallback,
  Duration timeout = const Duration(seconds: 12),
}) async {
  Future<List<dynamic>?> read(
    Future<String?> Function() request, {
    bool allowEmpty = false,
    Duration? budget,
  }) async {
    try {
      final value = await request().timeout(budget ?? timeout);
      return decodeCloudPluginCatalog(value, allowEmpty: allowEmpty);
    } catch (_) {
      return null;
    }
  }

  Future<({List<dynamic> entries, bool versioned})?> readPersonal() async {
    final legacy = fallback.personalVersioned ? null : legacyPersonal;
    final elapsed = Stopwatch()..start();
    final versioned = await read(
      personal,
      allowEmpty: true,
      budget: legacy == null
          ? timeout
          : Duration(microseconds: timeout.inMicroseconds * 2 ~/ 3),
    );
    if (versioned != null) return (entries: versioned, versioned: true);
    final remaining = timeout - elapsed.elapsed;
    if (legacy == null || remaining <= Duration.zero) return null;
    final entries = await read(legacy, budget: remaining);
    return entries == null ? null : (entries: entries, versioned: false);
  }

  final pendingOfficial = read(official);
  final pendingPersonal = readPersonal();
  final freshOfficial = await pendingOfficial;
  final freshPersonal = await pendingPersonal;
  if (freshOfficial == null && freshPersonal == null) {
    throw StateError('插件目录暂不可用，已保留可用目录');
  }
  return CloudPluginCatalogSnapshot._loaded(
    freshPersonal?.versioned == true,
    official: freshOfficial ?? fallback.official,
    personal: freshPersonal?.entries ?? fallback.personal,
    personalVersioned: freshPersonal?.versioned ?? fallback.personalVersioned,
  );
}
