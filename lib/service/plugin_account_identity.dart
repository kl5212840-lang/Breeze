import 'dart:async';

import 'package:zephyr/network/http/plugin/qjs_network_route.dart';
import 'package:zephyr/network/sync/plugin_account_profiles_data.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';

class PluginAccountAuthentication {
  const PluginAccountAuthentication({
    required this.serverIdentity,
    this.label = '',
    String avatarUrl = '',
    this.origin = '',
    this.publicSummary = const {},
  }) : _requestAvatarUrl = avatarUrl;
  final String serverIdentity, label, origin;
  // A signed image URL belongs only to this in-memory authenticated receipt.
  final String _requestAvatarUrl;

  String get requestAvatarUrl {
    if (_requestAvatarUrl.length > 4096) return '';
    final uri = Uri.tryParse(_requestAvatarUrl);
    return uri != null &&
            uri.scheme == 'https' &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty &&
            !uri.hasFragment
        ? _requestAvatarUrl
        : '';
  }

  /// The portable projection must never contain temporary signed parameters.
  String get avatarUrl {
    final value = requestAvatarUrl;
    return value.isNotEmpty && !Uri.parse(value).hasQuery ? value : '';
  }

  final Map<String, dynamic> publicSummary;
  PluginAccountAuthentication atOrigin(String value) =>
      PluginAccountAuthentication(
        serverIdentity: serverIdentity,
        label: label,
        avatarUrl: _requestAvatarUrl,
        origin: value,
        publicSummary: publicSummary,
      );
  Map<String, dynamic> toUserInfo() => {
    ...publicSummary,
    'available': true,
    'hostVerified': true,
    'avatar': {
      ...?(publicSummary['avatar'] is Map
          ? Map<String, dynamic>.from(publicSummary['avatar'] as Map)
          : null),
      'id': serverIdentity,
      if (avatarUrl.isNotEmpty) 'url': avatarUrl,
    },
    'lines':
        publicSummary['lines'] is List &&
            (publicSummary['lines'] as List).isNotEmpty
        ? publicSummary['lines']
        : [if (label.isNotEmpty) label],
    'extern': {
      ...?(publicSummary['extern'] is Map
          ? Map<String, dynamic>.from(publicSummary['extern'] as Map)
          : null),
      'accountId': serverIdentity,
      'uid': serverIdentity,
    },
  };
  @override
  String toString() => 'PluginAccountAuthentication(private)';
}

class PluginAccountAuthenticationRejected implements Exception {
  const PluginAccountAuthenticationRejected();
  @override
  String toString() => 'Account authentication rejected';
}

class _ConfirmedIdentity {
  _ConfirmedIdentity(
    this.proof,
    this.generation,
    this.configuration,
    this.installation,
  );
  final PluginAccountAuthentication proof;
  final int generation, installation;
  final String configuration;
}

/// An in-memory receipt from a real authenticated server response, never a saved
/// avatar or token-derived guess. Every reader checks the same source/session
/// and exact active account group. A transport failure cannot revoke a receipt;
/// an actual authentication rejection or a changed session invalidates it.
abstract final class PluginAccountIdentities {
  static final _confirmed = <String, _ConfirmedIdentity>{};
  static final _changes = StreamController<String>.broadcast(sync: true);
  static StreamSubscription<PluginSessionBoundary>? _fence;
  static void _observe() {
    _fence ??= pluginSessionWriteFence.changes.listen(
      (event) => _changes.add(event.source),
    );
  }

  static Stream<String> get changes {
    _observe();
    return _changes.stream;
  }

  static String fingerprint(String source) {
    final data = readHostPluginConfiguration(source);
    final auth = <String, dynamic>{
      for (final entry in data.entries)
        if (entry.key.startsWith('auth.') &&
            !const [
              'auth.avatar',
              'auth.avatarUrl',
              'auth.nickname',
              'auth.profile',
              'auth.checkin',
            ].contains(entry.key))
          entry.key: entry.key == 'auth.userInfo' && entry.value is Map
              ? {
                  for (final key in const [
                    'uid',
                    'id',
                    'userId',
                    'token',
                    'jwt',
                    'jwttoken',
                    'authorization',
                  ])
                    if ((entry.value as Map).containsKey(key))
                      key: (entry.value as Map)[key],
                }
              : entry.value,
    };
    if (auth['auth.userInfo'] is Map && (auth['auth.userInfo'] as Map).isEmpty)
      auth.remove('auth.userInfo');
    final raw = data['account.backup'];
    final cookies =
        <Map<String, dynamic>>[
          if (raw is Map && raw['deleted'] != true && raw['cookies'] is List)
            for (final cookie in raw['cookies'] as List)
              if (cookie is Map)
                {
                  for (final key in const ['name', 'value', 'domain', 'path'])
                    if (cookie.containsKey(key)) key: cookie[key],
                },
        ]..sort(
          (a, b) => '${a['domain']}|${a['path']}|${a['name']}'.compareTo(
            '${b['domain']}|${b['path']}|${b['name']}',
          ),
        );
    return accountProfileDigest({
      'auth': auth,
      if (cookies.isNotEmpty)
        'web': {'origin': raw['origin'], 'cookies': cookies},
    });
  }

  static PluginAccountAuthentication? current(String source) {
    source = canonicalQjsSource(source);
    final value = _confirmed[source];
    if (value == null ||
        pluginSessionWriteFence.isChanging(source) ||
        pluginSessionWriteFence.generation(source) != value.generation)
      return null;
    final installation = LocalPluginInstallationState.instance;
    if (installation.installationEpoch(source) != value.installation ||
        installation.isInstalling(source) ||
        installation.isRemoved(source))
      return null;
    return fingerprint(source) == value.configuration ? value.proof : null;
  }

  static bool confirm(
    String source,
    PluginAccountAuthentication proof, {
    required int generation,
  }) {
    _observe();
    source = canonicalQjsSource(source);
    if (proof.serverIdentity.isEmpty ||
        pluginSessionWriteFence.isChanging(source) ||
        pluginSessionWriteFence.generation(source) != generation)
      return false;
    final installation = LocalPluginInstallationState.instance;
    if (installation.isInstalling(source) || installation.isRemoved(source))
      return false;
    final next = _ConfirmedIdentity(
      proof,
      generation,
      fingerprint(source),
      installation.installationEpoch(source),
    );
    final old = _confirmed[source];
    _confirmed[source] = next;
    if (old == null ||
        old.generation != generation ||
        old.configuration != next.configuration ||
        old.proof.serverIdentity != proof.serverIdentity ||
        old.proof.label != proof.label ||
        old.proof.requestAvatarUrl != proof.requestAvatarUrl ||
        accountProfileDigest(old.proof.publicSummary) !=
            accountProfileDigest(proof.publicSummary))
      _changes.add(source);
    return true;
  }

  static void reject(String source, {required int generation}) {
    source = canonicalQjsSource(source);
    if (pluginSessionWriteFence.generation(source) != generation) return;
    if (_confirmed.remove(source) != null) _changes.add(source);
  }

  /// Called after the database mutation, outside its write transaction.
  static void accountConfigurationChanged(String source) {
    _observe();
    _changes.add(canonicalQjsSource(source));
  }
}
