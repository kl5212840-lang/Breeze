import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:zephyr/network/sync/sync_payload_compatibility.dart';

const pluginAccountProfilesKey = 'account.profiles';
bool isActivePluginAccountField(String key) =>
    key.startsWith('auth.') ||
    key == 'account.credentials' ||
    key == 'account.backup';

/// The declared login identity has precedence over an optional display alias.
String? pluginAccountBundleIdentity(Map<String, dynamic> data) {
  for (final key in ['auth.account', 'auth.username']) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  final credentials = data['account.credentials'];
  final value =
      credentials is Map &&
          credentials['version'] == 1 &&
          credentials['deleted'] != true
      ? credentials['account']
      : null;
  return value is String && value.trim().isNotEmpty ? value.trim() : null;
}

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List) return value.map(_canonical).toList();
  return value;
}

String accountProfileDigest(Object? value) =>
    sha256.convert(utf8.encode(jsonEncode(_canonical(value)))).toString();

/// Private transport data. Never stringify this object into a notice or log.
class PluginAccountProfile {
  const PluginAccountProfile({
    required this.id,
    required this.revision,
    required this.deleted,
    this.label = '',
    this.identity = '',
    this.origin = '',
    this.kind = 'stored',
    this.serverIdentity = '',
    this.avatarUrl = '',
    this.bundle = const {},
  });
  final String id, label, identity, origin, kind, serverIdentity, avatarUrl;
  final int revision;
  final bool deleted;
  final Map<String, dynamic> bundle;
  Map<String, dynamic> toJson() => {
    'revision': revision,
    'deleted': deleted,
    if (deleted) 'kind': kind,
    if (!deleted) ...{
      'label': label,
      'identity': identity,
      'origin': origin,
      'kind': kind,
      'serverIdentity': serverIdentity,
      if (avatarUrl.isNotEmpty) 'avatarUrl': avatarUrl,
      'bundle': bundle,
    },
  };
  @override
  String toString() => 'PluginAccountProfile(private)';
}

class PluginAccountProfilesData {
  const PluginAccountProfilesData(this.source, this.profiles);
  final String source;
  final Map<String, PluginAccountProfile> profiles;
  Map<String, dynamic> toJson() => {
    'version': 1,
    'source': source,
    'profiles': {
      for (final entry in profiles.entries) entry.key: entry.value.toJson(),
    },
  };
  @override
  String toString() => 'PluginAccountProfilesData(private)';

  static String idFor(
    String source,
    String identity,
    String origin, {
    String kind = 'stored',
  }) => accountProfileDigest([
    source,
    identity.trim(),
    kind == 'web' ? origin : '',
  ]);

  static PluginAccountProfilesData? parse(Object? raw, {String? source}) {
    if (raw == null) return null;
    if (raw is! Map || raw['version'] != 1)
      throw const SyncCompatibilityException();
    SyncPayloadCompatibility.keys(raw, const ['version', 'source', 'profiles']);
    final owner = raw['source'], rows = raw['profiles'];
    if (owner is! String ||
        owner.isEmpty ||
        owner.length > 200 ||
        (source != null && owner != source) ||
        rows is! Map ||
        rows.length > 1024 ||
        utf8.encode(jsonEncode(raw)).length > 2 * 1024 * 1024) {
      throw const SyncCompatibilityException();
    }
    final profiles = <String, PluginAccountProfile>{};
    for (final entry in rows.entries) {
      final id = entry.key, value = entry.value;
      if (id is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(id) ||
          value is! Map) {
        throw const SyncCompatibilityException();
      }
      SyncPayloadCompatibility.keys(value, const [
        'revision',
        'deleted',
        'label',
        'identity',
        'origin',
        'kind',
        'serverIdentity',
        'avatarUrl',
        'bundle',
      ]);
      final revision = value['revision'];
      if (revision is! int ||
          revision < 0 ||
          revision >= 8640000000000000 ||
          value['deleted'] is! bool) {
        throw const SyncCompatibilityException();
      }
      if (value['deleted'] == true) {
        final kind = value['kind'] ?? 'stored';
        if (!const ['stored', 'password', 'web'].contains(kind))
          throw const SyncCompatibilityException();
        profiles[id] = PluginAccountProfile(
          id: id,
          revision: revision,
          deleted: true,
          kind: kind as String,
        );
        continue;
      }
      final identity = value['identity'],
          label = value['label'],
          origin = value['origin'],
          kind = value['kind'],
          bundle = value['bundle'];
      if (identity is! String ||
          identity.trim().isEmpty ||
          identity.length > 300 ||
          label is! String ||
          label.length > 300 ||
          origin is! String ||
          kind is! String ||
          !const {'password', 'web', 'stored'}.contains(kind) ||
          bundle is! Map ||
          bundle.isEmpty ||
          bundle.keys.any(
            (key) => key is! String || !isActivePluginAccountField(key),
          ) ||
          id != idFor(owner, identity, origin, kind: kind))
        throw const SyncCompatibilityException();
      if (origin.isNotEmpty) {
        final uri = Uri.tryParse(origin);
        if (uri == null ||
            uri.scheme != 'https' ||
            uri.userInfo.isNotEmpty ||
            uri.origin != origin ||
            uri.host.isEmpty ||
            uri.port != 443) {
          throw const SyncCompatibilityException();
        }
      }
      for (final field in ['account.credentials', 'account.backup']) {
        if (bundle.containsKey(field) &&
            (bundle[field] is! Map || bundle[field]['version'] != 1)) {
          throw const SyncCompatibilityException();
        }
      }
      final avatarUrl = value['avatarUrl'] ?? '';
      final avatar = avatarUrl is String && avatarUrl.isNotEmpty
          ? Uri.tryParse(avatarUrl)
          : null;
      if (avatarUrl is! String ||
          avatarUrl.length > 4096 ||
          avatarUrl.isNotEmpty &&
              (avatar == null ||
                  avatar.scheme != 'https' ||
                  avatar.host.isEmpty ||
                  avatar.userInfo.isNotEmpty ||
                  avatar.hasQuery ||
                  avatar.hasFragment))
        throw const SyncCompatibilityException();
      if (kind != 'web' &&
          pluginAccountBundleIdentity(Map<String, dynamic>.from(bundle)) !=
              identity.trim())
        throw const SyncCompatibilityException();
      if (kind == 'web' &&
          (origin.isEmpty ||
              bundle['account.backup'] is! Map ||
              bundle['account.backup']['origin'] != origin))
        throw const SyncCompatibilityException();
      final serverIdentity = value['serverIdentity'] ?? '';
      if (serverIdentity is! String || serverIdentity.length > 300)
        throw const SyncCompatibilityException();
      final copied = jsonDecode(jsonEncode(bundle)) as Map<String, dynamic>;
      profiles[id] = PluginAccountProfile(
        id: id,
        revision: revision,
        deleted: false,
        identity: identity,
        label: label,
        origin: origin,
        kind: kind,
        serverIdentity: serverIdentity,
        avatarUrl: avatarUrl,
        bundle: Map.unmodifiable(copied),
      );
    }
    if (profiles.values.where((p) => !p.deleted).length > 64)
      throw const SyncCompatibilityException();
    return PluginAccountProfilesData(owner, Map.unmodifiable(profiles));
  }
}

void validatePluginAccountProfilesConfiguration(Map<String, dynamic> data) {
  if (data.containsKey(pluginAccountProfilesKey)) {
    if (data[pluginAccountProfilesKey] == null)
      throw const SyncCompatibilityException();
    PluginAccountProfilesData.parse(data[pluginAccountProfilesKey]);
  }
}

/// Account records merge independently. An absent record is never a deletion,
/// including an older client writing back a snapshot it does not understand.
Map<String, dynamic> mergePluginAccountProfiles(Object local, Object remote) {
  final left = PluginAccountProfilesData.parse(local)!,
      right = PluginAccountProfilesData.parse(remote)!;
  if (left.source != right.source) throw const SyncCompatibilityException();
  final rows = {...left.profiles};
  for (final entry in right.profiles.entries) {
    final old = rows[entry.key], next = entry.value;
    if (old == null ||
        next.revision > old.revision ||
        next.revision == old.revision &&
            (next.deleted && !old.deleted ||
                next.deleted == old.deleted &&
                    accountProfileDigest(
                          next.toJson(),
                        ).compareTo(accountProfileDigest(old.toJson())) >
                        0)) {
      rows[entry.key] = next;
    }
  }
  final merged = PluginAccountProfilesData(left.source, rows).toJson();
  PluginAccountProfilesData.parse(merged);
  return merged;
}
