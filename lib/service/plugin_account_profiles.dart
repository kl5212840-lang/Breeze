import 'package:zephyr/page/video/video_account_backup.dart';
import 'package:zephyr/page/video/video_account_credentials.dart';
import 'package:zephyr/service/plugin_account_identity.dart';
export 'package:zephyr/service/plugin_account_identity.dart';
import 'package:zephyr/main.dart' show eventBus;
import 'package:zephyr/util/event/event.dart';
import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart';
import 'package:zephyr/network/http/plugin/qjs_network_route.dart';
import 'package:zephyr/network/sync/plugin_account_profiles_data.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';

export 'package:zephyr/network/sync/plugin_account_profiles_data.dart';

class PluginAccountNeedsLogin implements Exception {
  const PluginAccountNeedsLogin();
}

class PluginAccountSwitchFailed implements Exception {
  const PluginAccountSwitchFailed();
  @override
  String toString() => 'Account switch was not confirmed';
}

/// Source-serialized host store. The selected id is device-only; cloud account
/// collection merges never force a live browser or another phone to switch.
abstract final class PluginAccountProfiles {
  static const selectedKey = 'breeze.local.account-profile-selection.v1';
  static final _operations = <String, Future<void>>{};
  static Future<T> _serial<T>(String source, Future<T> Function() action) {
    final prior = _operations[source];
    final done = Completer<void>();
    _operations[source] = done.future;
    Future<T> run() async {
      try {
        if (prior != null) await prior;
        return await action();
      } finally {
        if (identical(_operations[source], done.future))
          _operations.remove(source);
        done.complete();
      }
    }

    return run();
  }

  static PluginAccountProfilesData read(String source) {
    source = canonicalQjsSource(source);
    final configuration = readHostPluginConfiguration(source);
    validatePluginAccountProfilesConfiguration(configuration);
    final raw = configuration[pluginAccountProfilesKey];
    return PluginAccountProfilesData.parse(raw, source: source) ??
        PluginAccountProfilesData(source, const {});
  }

  static Map<String, dynamic> _active(String source) =>
      activePluginAccountSnapshot(readHostPluginConfiguration(source));
  static String? _account(Map<String, dynamic> data) =>
      pluginAccountBundleIdentity(data);

  static Future<void> _save(PluginAccountProfilesData data) async {
    PluginAccountProfilesData.parse(data.toJson(), source: data.source);
    await savePluginConfigValue(
      data.source,
      pluginAccountProfilesKey,
      data.toJson(),
    );
    if (accountProfileDigest(read(data.source).toJson()) !=
        accountProfileDigest(data.toJson())) {
      throw const PluginAccountSwitchFailed();
    }
  }

  static PluginAccountProfilesData _put(
    PluginAccountProfilesData data, {
    required String identity,
    required String label,
    required String origin,
    required String kind,
    required Map<String, dynamic> bundle,
    String serverIdentity = '',
    String avatarUrl = '',
    bool restoreDeleted = false,
  }) {
    final id = PluginAccountProfilesData.idFor(
      data.source,
      identity,
      origin,
      kind: kind,
    );
    final old = data.profiles[id];
    if (old?.deleted == true && !restoreDeleted) return data;
    if (serverIdentity.isEmpty) serverIdentity = old?.serverIdentity ?? '';
    if (avatarUrl.isEmpty) avatarUrl = old?.avatarUrl ?? '';
    if (label == identity && old?.label.isNotEmpty == true) label = old!.label;
    if (old != null &&
        !old.deleted &&
        old.label == label &&
        old.serverIdentity == serverIdentity &&
        old.avatarUrl == avatarUrl &&
        accountProfileDigest(old.bundle) == accountProfileDigest(bundle))
      return data;
    final now = DateTime.now().millisecondsSinceEpoch;
    return PluginAccountProfilesData(data.source, {
      ...data.profiles,
      id: PluginAccountProfile(
        id: id,
        revision: now > (old?.revision ?? 0) ? now : old!.revision + 1,
        deleted: false,
        identity: identity,
        label: label,
        origin: origin,
        kind: kind,
        serverIdentity: serverIdentity,
        avatarUrl: avatarUrl,
        bundle: bundle,
      ),
    });
  }

  static PluginAccountProfilesData _snapshot(
    PluginAccountProfilesData data,
    Map<String, dynamic> active, {
    String? identity,
    String label = '',
    String? origin,
    String kind = 'stored',
    String serverIdentity = '',
    String avatarUrl = '',
    String? verifiedCredentialAccount,
    bool verifiedWebSession = false,
    bool restoreDeleted = false,
  }) {
    identity ??= _account(active);
    if (identity == null || identity.isEmpty) return data;
    final credentials = active['account.credentials'];
    final bundle = <String, dynamic>{
      for (final entry in active.entries)
        if (entry.key.startsWith('auth.') ||
            entry.key == 'account.credentials' &&
                credentials is Map &&
                (credentials['account'] == identity ||
                    credentials['account'] == verifiedCredentialAccount) ||
            entry.key == 'account.backup' &&
                (kind == 'web' || verifiedWebSession))
          entry.key: entry.value,
    };
    if (bundle.isEmpty) return data;
    final effectiveOrigin =
        origin ??
        (credentials is Map && credentials['account'] == identity
            ? credentials['origin'] as String?
            : null) ??
        '';
    return _put(
      data,
      identity: identity,
      label: label.isEmpty ? identity : label,
      origin: effectiveOrigin,
      kind: kind,
      bundle: bundle,
      serverIdentity: serverIdentity,
      avatarUrl: avatarUrl,
      restoreDeleted: restoreDeleted,
    );
  }

  static bool requiresWebLogin(PluginAccountProfile profile) =>
      profile.kind == 'web' &&
      profile.bundle['account.backup'] is Map &&
      profile.bundle['account.backup']['requiresLogin'] == true;

  /// Retain a real authenticated identity even when this site has no portable
  /// login payload. Empty cookies are an explicit unavailable-session marker,
  /// never a restored or authenticated browser session.
  static Future<void> rememberVerifiedWebIdentity(
    String source,
    PluginAccountAuthentication proof, {
    required String origin,
    required bool Function() canCommit,
    bool explicitSave = false,
    Map<String, dynamic>? verifiedCredentials,
  }) => _serial(source, () async {
    if (!canCommit()) throw const PluginSessionChanged();
    final data = read(source);
    final id = PluginAccountProfilesData.idFor(
      source,
      proof.serverIdentity,
      origin,
      kind: 'web',
    );
    final existing = data.profiles[id];
    final reusable =
        existing != null &&
            !existing.deleted &&
            VideoAccountBackup.parse(
                  existing.bundle['account.backup'],
                  Uri.parse(origin),
                  source: source,
                ) !=
                null
        ? existing.bundle
        : null;
    final credentials = VideoAccountCredentials.decode(
      verifiedCredentials,
      Uri.parse(origin),
    );
    final extern = proof.publicSummary['extern'];
    final next = _put(
      data,
      identity: proof.serverIdentity,
      label: proof.label,
      origin: origin,
      kind: 'web',
      serverIdentity: proof.serverIdentity,
      avatarUrl: proof.avatarUrl,
      restoreDeleted: explicitSave,
      bundle: {
        if (existing != null && !existing.deleted) ...existing.bundle,
        if (reusable == null)
          'account.backup': {
            'version': 1,
            'origin': origin,
            'cookies': [],
            'requiresLogin': true,
            'serverIdentity': proof.serverIdentity,
          },
        if (credentials != null &&
            extern is Map &&
            extern['username'] == credentials.account)
          'account.credentials': verifiedCredentials,
      },
    );
    await _save(next);
    if (!canCommit()) throw const PluginSessionChanged();
    if (next.profiles[id]?.deleted == false) await _select(source, id);
  });

  /// Saving a form does not claim the site has accepted it or change selection.
  static Future<void> rememberCredentials(
    String source,
    Map<String, dynamic> credentials,
  ) {
    source = canonicalQjsSource(source);
    return _serial(source, () async {
      final data = read(source);
      if (credentials['version'] != 1 ||
          credentials['deleted'] == true ||
          credentials['account'] is! String ||
          credentials['origin'] is! String)
        return;
      final id = PluginAccountProfilesData.idFor(
        source,
        credentials['account'] as String,
        credentials['origin'] as String,
      );
      final previous = data.profiles[id];
      await _save(
        _put(
          data,
          identity: credentials['account'] as String,
          label: credentials['account'] as String,
          origin: credentials['origin'] as String,
          kind: 'password',
          bundle: {...?previous?.bundle, 'account.credentials': credentials},
          restoreDeleted: true,
        ),
      );
    });
  }

  /// Used only after an explicit save or a successful authenticated readback.
  /// Legacy fields remain untouched and readable by single-account clients.
  static Future<void> rememberCurrent(
    String source, {
    String? identity,
    String label = '',
    String? origin,
    String kind = 'stored',
    String serverIdentity = '',
    String avatarUrl = '',
    String? verifiedCredentialAccount,
    bool verifiedWebSession = false,
    bool select = false,
    bool explicitSave = false,
    bool Function()? canCommit,
  }) {
    source = canonicalQjsSource(source);
    return _serial(source, () async {
      if (canCommit?.call() == false) throw const PluginSessionChanged();
      final before = read(source), active = _active(source);
      final next = _snapshot(
        before,
        active,
        identity: identity,
        label: label,
        origin: origin,
        kind: kind,
        serverIdentity: serverIdentity,
        avatarUrl: avatarUrl,
        verifiedCredentialAccount: verifiedCredentialAccount,
        verifiedWebSession: verifiedWebSession,
        restoreDeleted: explicitSave,
      );
      await _save(next);
      if (canCommit?.call() == false) throw const PluginSessionChanged();
      if (select && next.profiles.isNotEmpty) {
        final chosenIdentity = identity ?? _account(active);
        final chosen = next.profiles.values
            .where(
              (profile) =>
                  !profile.deleted &&
                  profile.identity == chosenIdentity &&
                  (origin == null || profile.origin == origin),
            )
            .firstOrNull;
        if (chosen != null) await _select(source, chosen.id);
      }
    });
  }

  static PluginAccountProfilesData _snapshotBeforeChange(
    String source,
    PluginAccountProfilesData data,
    Map<String, dynamic> active,
    String? selection,
  ) {
    final previous = data.profiles[selection];
    // current() validates source, account fingerprint, generation and install.
    // Only an exact already-confirmed bundle can bypass the legacy snapshot;
    // newly edited credentials still need their own unverified capture.
    final proof = PluginAccountIdentities.current(source);
    if (previous != null &&
        !previous.deleted &&
        proof != null &&
        _matchesProof(previous, proof) &&
        (previous.origin.isEmpty ||
            proof.origin.isEmpty ||
            previous.origin == proof.origin) &&
        accountProfileDigest(previous.bundle) == accountProfileDigest(active)) {
      return data;
    }
    return _snapshot(data, active);
  }

  /// Keep the old compatibility group recoverable until a declared login and
  /// its fresh server readback settle under one source owner.
  static Future<T> submitLogin<T>(
    String source, {
    required Future<T> Function() submit,
    Future<PluginAccountAuthentication?> Function()? verify,
  }) {
    source = canonicalQjsSource(source);
    return _serial(source, () async {
      final data = read(source), before = _active(source);
      final oldSelection = await selected(source);
      await _save(_snapshotBeforeChange(source, data, before, oldSelection));
      PluginAccountAuthentication? receipt;
      int? settledGeneration;
      String? settledConfiguration;
      final result = await runPluginSessionChange(source, () async {
        final generation = pluginSessionWriteFence.generation(source);
        final installation = LocalPluginInstallationState.instance;
        final lifecycle = installation.installationEpoch(source);
        bool current() =>
            pluginSessionWriteFence.generation(source) == generation &&
            installation.installationEpoch(source) == lifecycle &&
            !installation.isInstalling(source) &&
            !installation.isRemoved(source);
        try {
          final result = await submit();
          final proof = await verify?.call();
          if (!current()) throw const PluginSessionChanged();
          final next = _snapshot(
            read(source),
            _active(source),
            label: proof?.label ?? '',
            serverIdentity: proof?.serverIdentity ?? '',
            avatarUrl: proof?.avatarUrl ?? '',
            restoreDeleted: true,
          );
          await _save(next);
          if (!current()) throw const PluginSessionChanged();
          final identity = _account(_active(source));
          final chosen = next.profiles.values
              .where((p) => !p.deleted && p.identity == identity)
              .firstOrNull;
          if (proof != null && chosen != null) {
            await _select(source, chosen.id);
            receipt = proof;
            settledGeneration = generation + 1;
            settledConfiguration = PluginAccountIdentities.fingerprint(source);
          }
          return result;
        } catch (_) {
          if (current()) {
            final actual = _active(source);
            replaceActivePluginAccount(
              source,
              before,
              expectedDigest: accountProfileDigest(actual),
              expectedGeneration: generation,
            );
            await _select(source, oldSelection);
          }
          rethrow;
        }
      });
      if (receipt != null &&
          PluginAccountIdentities.fingerprint(source) == settledConfiguration)
        PluginAccountIdentities.confirm(
          source,
          receipt!,
          generation: settledGeneration!,
        );
      return result;
    });
  }

  static String? _localSelection(SharedPreferences prefs, String source) {
    final raw = prefs.getString(selectedKey);
    if (raw == null) return null;
    return (jsonDecode(raw) as Map)[source] as String?;
  }

  static Future<String?> selected(String source) async {
    source = canonicalQjsSource(source);
    final prefs = await SharedPreferences.getInstance();
    try {
      final id = _localSelection(prefs, source);
      if (id == null) return null;
      final profile = read(source).profiles[id];
      return profile != null &&
              !profile.deleted &&
              _isCurrent(profile, _active(source), source: source)
          ? profile.id
          : null;
    } catch (_) {
      return null;
    }
  }

  /// Identifies the local current account for an explicit recovery visit.
  /// Saved account ordering and public display names do not identify a login.
  static Future<String?> currentLoginHint(
    String source, {
    String? legacySessionKey,
    Uri? origin,
  }) async {
    source = canonicalQjsSource(source);
    final generation = pluginSessionWriteFence.generation(source);
    final installation = LocalPluginInstallationState.instance;
    final epoch = installation.installationEpoch(source);
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = _localSelection(prefs, source);
      if (pluginSessionWriteFence.isChanging(source) ||
          generation != pluginSessionWriteFence.generation(source) ||
          installation.installationEpoch(source) != epoch ||
          installation.isInstalling(source) ||
          installation.isRemoved(source)) {
        return null;
      }
      final active = _active(source);
      if (id != null) {
        final profile = read(source).profiles[id];
        if (profile == null ||
            profile.deleted ||
            !_isCurrent(profile, active, source: source)) {
          return null;
        }
        if (profile.kind == 'web') {
          if (origin == null ||
              !VideoAccountCredentials.validOrigin(origin) ||
              profile.origin != origin.origin) {
            return null;
          }
          final saved = VideoAccountCredentials.decode(
            profile.bundle['account.credentials'],
            origin,
          );
          final current = VideoAccountCredentials.decode(
            active['account.credentials'],
            origin,
          );
          return saved?.account == current?.account
              ? _usableLoginName(saved?.account)
              : null;
        }
        final name = _usableLoginName(_account(profile.bundle));
        return origin == null && name == profile.identity ? name : null;
      }
      // Older API sessions can predate the device-only selection ID. Require
      // their original login field and the known active session field.
      final legacySession = active[legacySessionKey];
      if (origin != null ||
          legacySession is! String ||
          legacySession.trim().isEmpty ||
          const {'null', 'undefined'}.contains(legacySession.trim())) {
        return null;
      }
      final account = active['auth.account'];
      final username = active['auth.username'];
      return _usableLoginName(
        account is String && account.trim().isNotEmpty
            ? account
            : username is String
            ? username
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  static String? _usableLoginName(String? raw) {
    final value = raw?.trim() ?? '';
    return value.isEmpty ||
            value.length > 300 ||
            const {'null', 'undefined'}.contains(value) ||
            RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)
        ? null
        : value;
  }

  static Future<void> _select(String source, String? id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(selectedKey);
    final map = raw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    if (id == null) {
      map.remove(source);
    } else {
      map[source] = id;
    }
    if (!await prefs.setString(selectedKey, jsonEncode(map)))
      throw const PluginAccountSwitchFailed();
  }

  static bool isCurrent(String source, String id) {
    final profile = read(source).profiles[id];
    return profile != null &&
        !profile.deleted &&
        _isCurrent(profile, _active(source), source: source);
  }

  static bool _matchesProof(
    PluginAccountProfile profile,
    PluginAccountAuthentication proof,
  ) =>
      profile.serverIdentity.isNotEmpty &&
      profile.serverIdentity == proof.serverIdentity &&
      (profile.kind != 'web' ||
          proof.origin.isEmpty ||
          profile.origin == proof.origin);
  static bool _isCurrent(
    PluginAccountProfile profile,
    Map<String, dynamic> active, {
    String? source,
  }) {
    final proof = source == null
        ? null
        : PluginAccountIdentities.current(source);
    if (proof != null) return _matchesProof(profile, proof);
    if (profile.kind != 'web') return _account(active) == profile.identity;
    final one = active['account.backup'],
        two = profile.bundle['account.backup'];
    return one is Map &&
        two is Map &&
        one['deleted'] != true &&
        _sameWebSession(one, two, profile.origin, source: source);
  }

  static bool _sameWebSession(
    Object? first,
    Object? second,
    String origin, {
    String? source,
  }) {
    final uri = Uri.tryParse(origin);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return false;
    final one = VideoAccountBackup.parse(first, uri, source: source),
        two = VideoAccountBackup.parse(second, uri, source: source);
    return one != null &&
        two != null &&
        one.sessionFingerprint == two.sessionFingerprint;
  }

  /// Removing the active saved account requires an explicit local sign-out
  /// action; deleting another saved account never changes the live session.
  static Future<void> delete(
    String source,
    String id, {
    Future<void> Function()? signOutCurrent,
    int? expectedRevision,
    bool? expectedCurrent,
    int? expectedGeneration,
  }) {
    source = canonicalQjsSource(source);
    return _serial(source, () async {
      final data = read(source), old = data.profiles[id];
      if (old == null || old.deleted) return false;
      final isCurrent = _isCurrent(old, _active(source), source: source);
      if ((expectedRevision != null && old.revision != expectedRevision) ||
          (expectedCurrent != null && isCurrent != expectedCurrent) ||
          (expectedGeneration != null &&
              (pluginSessionWriteFence.generation(source) !=
                      expectedGeneration ||
                  pluginSessionWriteFence.isChanging(source)))) {
        throw const PluginSessionChanged();
      }
      if (isCurrent) {
        if (signOutCurrent == null) throw const PluginAccountNeedsLogin();
        await runPluginSessionChange(source, () async {
          await signOutCurrent();
          if (_isCurrent(old, _active(source), source: source))
            throw const PluginAccountSwitchFailed();
        });
      }
      final current = read(source), latest = current.profiles[id];
      if (latest == null || latest.deleted) return isCurrent;
      if (expectedRevision != null && latest.revision != expectedRevision) {
        throw const PluginSessionChanged();
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      await _save(
        PluginAccountProfilesData(source, {
          ...current.profiles,
          id: PluginAccountProfile(
            id: id,
            revision: now > latest.revision ? now : latest.revision + 1,
            deleted: true,
            kind: latest.kind,
          ),
        }),
      );
      if (isCurrent) await _select(source, null);
      return isCurrent;
    }).then((wasCurrent) {
      if (wasCurrent) eventBus.fire(PluginAccountSignedOut(source));
    });
  }

  static Future<void> switchTo(
    String source,
    String id, {
    required Future<PluginAccountAuthentication> Function(PluginAccountProfile)
    authenticate,
  }) {
    source = canonicalQjsSource(source);
    return _serial(source, () async {
      var data = read(source);
      final target = data.profiles[id];
      if (target == null || target.deleted)
        throw const PluginAccountSwitchFailed();
      final installation = LocalPluginInstallationState.instance;
      final lifecycle = installation.installationEpoch(source);
      final before = _active(source), previousSelected = await selected(source);
      // Preserve a previous account before attempting any replacement.
      data = _snapshotBeforeChange(source, data, before, previousSelected);
      await _save(data);
      PluginAccountAuthentication? receipt;
      int? settledGeneration;
      String? settledConfiguration;
      await runPluginSessionChange(source, () async {
        final generation = pluginSessionWriteFence.generation(source);
        bool current() =>
            pluginSessionWriteFence.generation(source) == generation &&
            installation.installationEpoch(source) == lifecycle &&
            !installation.isInstalling(source) &&
            !installation.isRemoved(source);
        if (!current()) throw const PluginSessionChanged();
        replaceActivePluginAccount(
          source,
          target.bundle,
          expectedDigest: accountProfileDigest(before),
          expectedGeneration: generation,
        );
        try {
          final confirmed = await authenticate(target);
          if (!current()) throw const PluginSessionChanged();
          if (confirmed.serverIdentity.isEmpty ||
              target.serverIdentity.isNotEmpty &&
                  confirmed.serverIdentity != target.serverIdentity) {
            throw const PluginAccountSwitchFailed();
          }
          final active = _active(source);
          if (target.kind != 'web' && _account(active) != target.identity)
            throw const PluginAccountSwitchFailed();
          final fresh = _put(
            read(source),
            identity: target.identity,
            label: confirmed.label.isEmpty ? target.label : confirmed.label,
            origin: target.origin,
            kind: target.kind,
            bundle: active,
            serverIdentity: confirmed.serverIdentity,
            avatarUrl: confirmed.avatarUrl,
          );
          await _save(fresh);
          if (!current() || read(source).profiles[id]?.deleted != false)
            throw const PluginSessionChanged();
          await _select(source, id);
          receipt = confirmed;
          settledGeneration = generation + 1;
          settledConfiguration = PluginAccountIdentities.fingerprint(source);
        } catch (_) {
          // Never log out the old server session. Restore only this operation's
          // compatibility fields, and never overwrite a newer session owner.
          if (current()) {
            final actual = _active(source);
            if (_account(actual) == target.identity || target.kind == 'web') {
              replaceActivePluginAccount(
                source,
                before,
                expectedDigest: accountProfileDigest(actual),
                expectedGeneration: generation,
              );
              await _select(source, previousSelected);
            }
          }
          rethrow;
        }
      });
      if (receipt != null &&
          PluginAccountIdentities.fingerprint(source) == settledConfiguration)
        PluginAccountIdentities.confirm(
          source,
          receipt!,
          generation: settledGeneration!,
        );
    });
  }
}
