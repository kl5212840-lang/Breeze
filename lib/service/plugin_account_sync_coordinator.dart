import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/service/plugin_account_profiles.dart';
import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/sync/plugin_account_projection.dart';
import 'package:zephyr/page/video/video_account_backup.dart';
import 'package:zephyr/page/video/video_account_credentials.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';

/// A cookie write/readback result is not evidence that a website accepted login.
enum AccountSessionRestoreResult { notPending, restored, cleared, failed }

class _AccountRegistration {
  _AccountRegistration(
    this.origin,
    this.service,
    this.authenticated,
    this.identity,
    this.continueLogin,
    this.installation,
  );
  final int installation;
  final Uri origin;
  final VideoAccountService service;
  final Future<bool> Function() authenticated;
  final Future<PluginAccountAuthentication?> Function()? identity;
  final Future<void> Function()? continueLogin;
}

class _AccountCapture {
  _AccountCapture(this.registration, this.generation, this.explicitSave);
  final _AccountRegistration? registration;
  final int generation;
  bool explicitSave;
  late final Future<void> task;
}

/// Global plugin sync owns account backup. Website cookies always use the
/// exact browser store supplied by the live source host, including on iOS.
class PluginAccountSyncCoordinator {
  PluginAccountSyncCoordinator._()
    : _enabled = (() => globalSetting.syncSetting.syncPlugins),
      _readConfiguration = ((source) =>
          loadPluginConfigValue<Map>(source, '', fallback: const {}));
  PluginAccountSyncCoordinator.forTesting({
    required Map Function(String source) readConfiguration,
    bool Function()? enabled,
  }) : _readConfiguration = readConfiguration,
       _enabled = enabled ?? (() => true);
  static final instance = PluginAccountSyncCoordinator._();
  static const pendingKey = 'breeze.local.account-session-restore.v1';
  final Map Function(String) _readConfiguration;
  final bool Function() _enabled;
  final _registrations = <String, _AccountRegistration>{};
  final _restoring = <String>{};
  final _restoreTasks =
      <
        String,
        ({
          _AccountRegistration? registration,
          Future<AccountSessionRestoreResult> task,
        })
      >{};
  final _capturing = <String, _AccountCapture>{};
  bool _live(String source, _AccountRegistration? registration) {
    final lifecycle = LocalPluginInstallationState.instance;
    return registration != null &&
        identical(_registrations[source], registration) &&
        registration.installation == lifecycle.installationEpoch(source) &&
        !lifecycle.isRemoved(source) &&
        !lifecycle.isInstalling(source);
  }

  PluginAccountAuthentication? confirmedProfileIdentity(String source) =>
      PluginAccountIdentities.current(source);

  /// Display identity is independent of whether portable cookies can be read
  /// or saved. Only the live source adapter performs the authenticated request.
  Future<PluginAccountAuthentication?> refreshCurrentIdentity(
    String source, {
    bool requireFresh = false,
  }) async {
    final registration = _registrations[source];
    if (registration?.identity == null || !_live(source, registration)) {
      if (requireFresh) throw const PluginAccountNeedsLogin();
      return PluginAccountIdentities.current(source);
    }
    final sessionSource = normalizePluginId(source);
    final beforeRestore = pluginSessionWriteFence.generation(sessionSource);
    final fingerprint = _fingerprint(source);
    if (pluginSessionWriteFence.isChanging(sessionSource)) {
      throw const PluginSessionChanged();
    }
    final restored = await restoreOnEntry(source);
    if (restored == AccountSessionRestoreResult.failed ||
        !_live(source, registration)) {
      throw StateError('Account session restore unavailable');
    }
    // An applied restore owns its begin and seal generations. A different
    // boundary during this read cannot authorize identity from the old visit.
    final mutated =
        restored == AccountSessionRestoreResult.restored ||
        restored == AccountSessionRestoreResult.cleared;
    final generation = beforeRestore + (mutated ? 2 : 0);
    bool current() =>
        _live(source, registration) &&
        !pluginSessionWriteFence.isChanging(sessionSource) &&
        pluginSessionWriteFence.generation(sessionSource) == generation &&
        _fingerprint(source) == fingerprint;
    if (!current()) throw const PluginSessionChanged();
    PluginAccountAuthentication? proof;
    try {
      proof = await registration!.identity!();
    } on PluginAccountAuthenticationRejected {
      if (!current()) throw const PluginSessionChanged();
      PluginAccountIdentities.reject(source, generation: generation);
      if (requireFresh) rethrow;
      return null;
    }
    if (!current()) throw const PluginSessionChanged();
    if (proof == null) {
      if (requireFresh) throw StateError('Account identity unavailable');
      return PluginAccountIdentities.current(source);
    }
    final sameSource = proof.atOrigin(registration.origin.origin);
    PluginAccountIdentities.confirm(source, sameSource, generation: generation);
    return sameSource;
  }

  String _fingerprint(String source) {
    final configuration = _readConfiguration(source);
    dynamic canonical(dynamic value) {
      if (value is Map) {
        final keys = value.keys.map((key) => '$key').toList()..sort();
        return {for (final key in keys) key: canonical(value[key])};
      }
      if (value is List) return value.map(canonical).toList();
      return value;
    }

    return sha256
        .convert(
          utf8.encode(
            jsonEncode(
              canonical({
                for (final entry in configuration.entries)
                  if (isPluginAccountField('${entry.key}') &&
                      entry.key != pluginAccountProfilesKey)
                    '${entry.key}': entry.value,
              }),
            ),
          ),
        )
        .toString();
  }

  Future<Object> register({
    required String source,
    required Uri origin,
    required Map<String, dynamic> accountSync,
    required VideoAccountCall call,
    required VideoAccountCookies cookies,
    required Future<bool> Function() authenticated,
    Future<PluginAccountAuthentication?> Function()? identity,
    Future<void> Function()? continueLogin,
  }) async {
    if (source.trim().isEmpty ||
        origin.scheme != 'https' ||
        origin.host.isEmpty ||
        origin.userInfo.isNotEmpty ||
        !VideoAccountService.supported(accountSync, origin)) {
      throw ArgumentError('Unsupported account session source');
    }
    final registration = _AccountRegistration(
      origin,
      VideoAccountService(
        source: source,
        origin: origin,
        call: call,
        cookies: cookies,
        readFn: accountSync['readFn'] as String,
        saveFn: accountSync['saveFn'] as String,
        forgetFn: accountSync['forgetFn'] as String,
      ),
      authenticated,
      identity,
      continueLogin,
      LocalPluginInstallationState.instance.installationEpoch(source),
    );
    final previous = _registrations[source];
    _registrations[source] = registration;
    if (previous != null && !identical(previous.service.cookies, cookies)) {
      _closeCookieLease(previous);
    }
    return registration;
  }

  /// An explicitly adapted built-in host (for example Omo) can use the same
  /// plugin configuration store without pretending third-party capabilities.
  Future<Object> registerStoredSession({
    required String source,
    required Uri origin,
    required VideoAccountCookies cookies,
    required Future<bool> Function() authenticated,
    Future<PluginAccountAuthentication?> Function()? identity,
    Future<void> Function()? continueLogin,
  }) => register(
    source: source,
    origin: origin,
    cookies: cookies,
    authenticated: authenticated,
    identity: identity,
    continueLogin: continueLogin,
    accountSync: {
      'version': 1,
      'origin': origin.origin,
      'readFn': 'readHostAccount',
      'saveFn': 'saveHostAccount',
      'forgetFn': 'forgetHostAccount',
    },
    call: (function, arguments) async {
      if (function == 'readHostAccount') {
        return {
          'data': {
            'backup': loadPluginConfigValue<dynamic>(
              source,
              'account.backup',
              fallback: null,
            ),
          },
        };
      }
      if (function == 'saveHostAccount') {
        final snapshot = VideoAccountBackup.parse(
          arguments['backup'],
          origin,
          source: source,
        );
        if (snapshot == null) throw const FormatException('No account session');
        await savePluginConfigValue(
          source,
          'account.backup',
          snapshot.toJson(),
        );
      } else if (function == 'forgetHostAccount') {
        await savePluginConfigValue(source, 'account.backup', {
          'version': 1,
          'origin': origin.origin,
          'deleted': true,
        });
      } else {
        throw StateError('Unsupported host account operation');
      }
      return {
        'data': {'saved': true},
      };
    },
  );

  bool isRegistered(String source, Object registration) =>
      registration is _AccountRegistration && _live(source, registration);

  void _closeCookieLease(_AccountRegistration registration) {
    final cookies = registration.service.cookies;
    if (cookies is VideoAccountCookieLifetime) {
      unawaited(
        (cookies as VideoAccountCookieLifetime)
            .closeAccountCookieAccess()
            .catchError((Object _) {}),
      );
    }
  }

  void unregister(String source, Object registration) {
    if (isRegistered(source, registration)) {
      final previous = _registrations.remove(source)!;
      _closeCookieLease(previous);
    }
  }

  /// Only positive, fresh site identity evidence can replace a saved session.
  /// Empty cookies, expired sessions, challenge pages and unavailable browsers
  /// retain their previous account backup; none represent an explicit logout.
  Future<void> captureAuthenticated(
    String source, {
    bool explicitSave = false,
  }) {
    if (!_enabled() && _registrations[source]?.identity == null)
      return Future.value();
    final registration = _registrations[source];
    final generation = pluginSessionWriteFence.generation(source);
    final pending = _capturing[source];
    if (pending != null) {
      if (identical(pending.registration, registration) &&
          pending.generation == generation) {
        pending.explicitSave = pending.explicitSave || explicitSave;
        return pending.task;
      }
      Future<void> retry() {
        // A queued request may save only its own still-current session. Never
        // carry an explicit-save decision over to a third account/visit.
        if (!identical(_registrations[source], registration) ||
            pluginSessionWriteFence.generation(source) != generation)
          return Future.value();
        return captureAuthenticated(source, explicitSave: explicitSave);
      }

      return pending.task.then<void>(
        (_) => retry(),
        onError: (Object _, StackTrace __) => retry(),
      );
    }
    final capture = _AccountCapture(registration, generation, explicitSave);
    _capturing[source] = capture;
    capture.task = _capture({source}, capture).whenComplete(() {
      if (identical(_capturing[source], capture)) _capturing.remove(source);
    });
    return capture.task;
  }

  Future<void> captureForUpload(Set<String> sources) async {
    for (final source in sources) {
      await captureAuthenticated(source);
    }
  }

  Future<void> _capture(Set<String> sources, _AccountCapture capture) async {
    for (final source in sources) {
      final registration = _registrations[source];
      if (registration == null ||
          !_live(source, registration) ||
          _restoring.contains(source) ||
          pluginSessionWriteFence.isChanging(source))
        continue;
      final generation = pluginSessionWriteFence.generation(source);
      final fingerprint = _fingerprint(source);
      bool current() =>
          _live(source, registration) &&
          pluginSessionWriteFence.generation(source) == generation &&
          _fingerprint(source) == fingerprint;

      VideoAccountBackup? beforeCookies;
      if (registration.identity != null) {
        try {
          beforeCookies = VideoAccountBackup.parse(
            {
              'version': 1,
              'origin': registration.origin.origin,
              'cookies': await registration.service.cookies.read(
                registration.origin,
              ),
            },
            registration.origin,
            source: source,
          );
        } catch (_) {
          /* Identity is still readable. */
        }
      }
      final proof = registration.identity == null
          ? null
          : await refreshCurrentIdentity(source, requireFresh: true);
      if (registration.identity != null
          ? proof == null
          : !await registration.authenticated())
        continue;
      if (!current()) continue;
      final credentials = VideoAccountCredentials.decode(
        _readConfiguration(source)['account.credentials'],
        registration.origin,
      );
      final account = proof?.publicSummary['extern'];
      final tiedCredentials =
          credentials != null &&
          account is Map &&
          account['username'] == credentials.account;
      final known = proof == null
          ? const <PluginAccountProfile>[]
          : PluginAccountProfiles.read(source).profiles.values
                .where(
                  (row) =>
                      !row.deleted &&
                      row.serverIdentity == proof.serverIdentity &&
                      row.origin == registration.origin.origin &&
                      (row.kind == 'web' ||
                          tiedCredentials &&
                              row.identity == credentials.account),
                )
                .toList();
      final selected = proof == null
          ? null
          : await PluginAccountProfiles.selected(source);
      final matched =
          known.where((row) => row.id == selected).firstOrNull ??
          (known.length == 1 ? known.single : null);
      final identity =
          matched?.identity ??
          (tiedCredentials ? credentials.account : proof?.serverIdentity ?? '');
      final kind = matched?.kind ?? (tiedCredentials ? 'password' : 'web');
      if (!current()) continue;
      List<Map<String, dynamic>> currentCookies;
      try {
        currentCookies = await registration.service.cookies.read(
          registration.origin,
        );
      } catch (_) {
        currentCookies = const [];
      }
      final snapshot = VideoAccountBackup.parse(
        {
          'version': 1,
          'origin': registration.origin.origin,
          'name': proof?.label ?? '',
          if (proof != null)
            'profileId': PluginAccountProfilesData.idFor(
              source,
              identity,
              registration.origin.origin,
              kind: kind,
            ),
          'cookies': currentCookies,
        },
        registration.origin,
        source: source,
      );
      if (snapshot == null && tiedCredentials && proof != null && current()) {
        if (matched != null &&
            PluginAccountProfiles.requiresWebLogin(matched)) {
          await PluginAccountProfiles.rememberVerifiedWebIdentity(
            source,
            proof,
            origin: registration.origin.origin,
            canCommit: current,
            explicitSave: capture.explicitSave,
            verifiedCredentials: Map<String, dynamic>.from(
              _readConfiguration(source)['account.credentials'] as Map,
            ),
          );
        } else {
          await PluginAccountProfiles.rememberCurrent(
            source,
            canCommit: current,
            identity: credentials.account,
            serverIdentity: proof.serverIdentity,
            label: proof.label,
            origin: registration.origin.origin,
            kind: 'password',
            select: true,
            explicitSave: capture.explicitSave,
            verifiedCredentialAccount: credentials.account,
          );
        }
      }
      if (snapshot == null && !tiedCredentials && proof != null && current()) {
        await PluginAccountProfiles.rememberVerifiedWebIdentity(
          source,
          proof,
          origin: registration.origin.origin,
          canCommit: current,
          explicitSave: capture.explicitSave,
        );
      }
      if (snapshot == null ||
          !current() ||
          registration.identity != null &&
              (beforeCookies == null ||
                  beforeCookies.sessionFingerprint !=
                      snapshot.sessionFingerprint))
        continue;
      final saved = await registration.service.read();
      if (!current()) continue;

      if (saved == null ||
          saved.sessionFingerprint != snapshot.sessionFingerprint ||
          saved.profileId != snapshot.profileId)
        await registration.service.saveSnapshot(
          snapshot,
          beforeSave: () {
            if (!current())
              throw StateError('Account session changed during backup');
          },
        );
      if (proof != null &&
          _live(source, registration) &&
          pluginSessionWriteFence.generation(source) == generation) {
        PluginAccountIdentities.confirm(
          source,
          proof.atOrigin(registration.origin.origin),
          generation: generation,
        );
        final savedFingerprint = _fingerprint(source);
        await PluginAccountProfiles.rememberCurrent(
          source,
          canCommit: () =>
              _live(source, registration) &&
              pluginSessionWriteFence.generation(source) == generation &&
              _fingerprint(source) == savedFingerprint,
          identity: identity,
          serverIdentity: proof.serverIdentity,
          label: proof.label,
          origin: registration.origin.origin,
          kind: kind,
          verifiedCredentialAccount: tiedCredentials
              ? credentials.account
              : null,
          verifiedWebSession: tiedCredentials,
          select: true,
          explicitSave: capture.explicitSave,
        );
        if (_live(source, registration) &&
            pluginSessionWriteFence.generation(source) == generation)
          PluginAccountIdentities.confirm(
            source,
            proof.atOrigin(registration.origin.origin),
            generation: generation,
          );
      }
    }
  }

  Uri? profileOrigin(String source) => _live(source, _registrations[source])
      ? _registrations[source]?.origin
      : null;
  bool hasProfileLogin(String source) =>
      _live(source, _registrations[source]) &&
      _registrations[source]?.continueLogin != null;
  Future<void> continueProfileLogin(String source) async {
    final registration = _registrations[source];
    if (registration?.continueLogin == null || !_live(source, registration))
      throw const PluginAccountNeedsLogin();
    await registration!.continueLogin!();
  }

  bool hasProfileAccess(String source) =>
      _live(source, _registrations[source]) &&
      _registrations[source]?.identity != null;

  /// Apply only to the currently registered exact source store. A failed fresh
  /// identity check restores the old cookie values only if our candidate is
  /// still the live value; a newer login/visit must never be overwritten.
  Future<PluginAccountAuthentication> activateProfile(
    String source,
    PluginAccountProfile profile,
  ) async {
    final registration = _registrations[source];
    if (registration == null ||
        !_live(source, registration) ||
        registration.identity == null ||
        profile.origin != registration.origin.origin)
      throw const PluginAccountNeedsLogin();
    final snapshot = VideoAccountBackup.parse(
      profile.bundle['account.backup'],
      registration.origin,
      source: source,
    );
    if (snapshot == null) throw const PluginAccountNeedsLogin();
    final generation = pluginSessionWriteFence.generation(source);
    bool current() =>
        _live(source, registration) &&
        pluginSessionWriteFence.generation(source) == generation;
    final before = VideoAccountBackup.parse(
      {
        'version': 1,
        'origin': registration.origin.origin,
        'cookies': await registration.service.cookies.read(registration.origin),
      },
      registration.origin,
      source: source,
    );
    if (!current()) throw const PluginSessionChanged();
    try {
      await registration.service.restore(snapshot, canApply: current);
      final proof = await registration.identity!();
      if (!current()) throw const PluginSessionChanged();
      if (proof == null ||
          proof.serverIdentity !=
              (profile.serverIdentity.isNotEmpty
                  ? profile.serverIdentity
                  : profile.identity))
        throw const PluginAccountSwitchFailed();
      return proof.atOrigin(registration.origin.origin);
    } catch (_) {
      if (current()) {
        final actual = VideoAccountBackup.parse(
          {
            'version': 1,
            'origin': registration.origin.origin,
            'cookies': await registration.service.cookies.read(
              registration.origin,
            ),
          },
          registration.origin,
          source: source,
        );
        if (current() &&
            actual != null &&
            actual.sessionFingerprint == snapshot.sessionFingerprint) {
          if (before != null)
            await registration.service.restore(before, canApply: current);
          else
            await registration.service.clearSession(canApply: current);
        }
      }
      rethrow;
    }
  }

  /// Explicit saved-credential continuation. The ordinary login UI may renew
  /// its registration, but it cannot change this operation's session epoch.
  /// No server logout is issued, and no cached identity can confirm success.
  Future<PluginAccountAuthentication> activateCredentials(
    String source,
    PluginAccountProfile profile, {
    required Future<void> Function() login,
    bool Function()? canContinue,
  }) async {
    final initial = _registrations[source];
    if (initial == null ||
        !_live(source, initial) ||
        initial.identity == null ||
        profile.origin != initial.origin.origin ||
        (VideoAccountCredentials.decode(
                  profile.bundle['account.credentials'],
                  initial.origin,
                ) ==
                null &&
            !PluginAccountProfiles.requiresWebLogin(profile)))
      throw const PluginAccountNeedsLogin();
    var registration = initial;
    final origin = registration.origin;
    final generation = pluginSessionWriteFence.generation(source);
    final installation = registration.installation;
    bool current() =>
        pluginSessionWriteFence.generation(source) == generation &&
        LocalPluginInstallationState.instance.installationEpoch(source) ==
            installation &&
        _live(source, registration) &&
        registration.origin.origin == origin.origin;
    void guard() {
      if (!current() || canContinue?.call() == false)
        throw const PluginSessionChanged();
    }

    final before = VideoAccountBackup.parse(
      {
        'version': 1,
        'origin': origin.origin,
        'cookies': await registration.service.cookies.read(origin),
      },
      origin,
      source: source,
    );
    guard();
    // Do not destroy a current session whose allowed cookies cannot be restored.
    if (before == null) {
      PluginAccountAuthentication? previous;
      try {
        previous = await registration.identity!();
      } on PluginAccountAuthenticationRejected {
        /* Already signed out. */
      }
      guard();
      if (previous != null) throw const PluginAccountNeedsLogin();
    }
    try {
      await registration.service.clearSession(canApply: current);
      guard();
      await login();
      // The login route closes its own lease. Its caller reconnects the source
      // reader before returning here; lock all further IO to that new lease.
      final resumed = _registrations[source];
      if (resumed == null || resumed.origin.origin != origin.origin)
        throw const PluginSessionChanged();
      registration = resumed;
      guard();
      if (registration.identity == null) throw const PluginAccountNeedsLogin();
      final beforeIdentity = VideoAccountBackup.parse(
        {
          'version': 1,
          'origin': origin.origin,
          'cookies': await registration.service.cookies.read(origin),
        },
        origin,
        source: source,
      );
      final proof = await registration.identity!();
      guard();
      final loginName = proof?.publicSummary['extern'];
      final matches = profile.serverIdentity.isNotEmpty
          ? proof?.serverIdentity == profile.serverIdentity
          : loginName is Map && loginName['username'] == profile.identity;
      if (proof == null || !matches) throw const PluginAccountSwitchFailed();
      final snapshot = VideoAccountBackup.parse(
        {
          'version': 1,
          'origin': origin.origin,
          'name': proof.label,
          'cookies': await registration.service.cookies.read(origin),
        },
        origin,
        source: source,
      );
      guard();
      if (snapshot != null) {
        if (beforeIdentity == null ||
            beforeIdentity.sessionFingerprint != snapshot.sessionFingerprint)
          throw const PluginSessionChanged();
        // A verified switch owns the host transaction. Ordinary host writes
        // correctly remain blocked while that same session boundary is open.
        final active = activePluginAccountSnapshot(
          readHostPluginConfiguration(source),
        );
        guard();
        replaceActivePluginAccount(
          source,
          {...active, 'account.backup': snapshot.toJson()},
          expectedDigest: accountProfileDigest(active),
          expectedGeneration: generation,
        );
        guard();
        final persisted = VideoAccountBackup.parse(
          readHostPluginConfiguration(source)['account.backup'],
          origin,
          source: source,
        );
        if (persisted?.sessionFingerprint != snapshot.sessionFingerprint)
          throw const PluginAccountSwitchFailed();
      }
      return proof.atOrigin(origin.origin);
    } catch (_) {
      // Reconnect only the same-source store; a newer account epoch/installation
      // or disposed origin owns its own state and must never be rolled back.
      final resumed = _registrations[source];
      if (resumed != null && resumed.origin.origin == origin.origin)
        registration = resumed;
      if (current()) {
        if (before != null) {
          await registration.service.restore(before, canApply: current);
        } else {
          await registration.service.clearSession(canApply: current);
        }
      }
      rethrow;
    }
  }

  Future<void> signOutProfile(String source) async {
    final registration = _registrations[source];
    if (registration == null || !_live(source, registration))
      throw const PluginAccountNeedsLogin();
    final generation = pluginSessionWriteFence.generation(source);
    bool current() =>
        _live(source, registration) &&
        pluginSessionWriteFence.generation(source) == generation;
    await registration.service.clearSession(canApply: current);
    if (!current()) throw const PluginSessionChanged();
  }

  /// Called only after a user-requested global restore committed plugin data.
  /// These device-only hashes neither contain cookies nor cross the cloud.
  Future<void> markRestorePending(Set<String> sources) async {
    final fingerprints = {
      for (final source in sources) source: _fingerprint(source),
    };
    final preferences = await SharedPreferences.getInstance();
    final pending = _pending(preferences)..addAll(fingerprints);
    if (!await preferences.setString(pendingKey, jsonEncode(pending))) {
      throw StateError('Account restore could not be scheduled');
    }
  }

  Map<String, dynamic> _pending(SharedPreferences preferences) {
    final raw = preferences.getString(pendingKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
  }

  Future<bool> _consume(
    SharedPreferences preferences,
    String source,
    String fingerprint,
  ) async {
    final pending = _pending(preferences);
    if (pending[source] != fingerprint) return false;
    pending.remove(source);
    if (!await preferences.setString(pendingKey, jsonEncode(pending))) {
      throw StateError('Account restore status could not be saved');
    }
    return true;
  }

  Future<AccountSessionRestoreResult> restoreOnEntry(String source) {
    final pending = _restoreTasks[source];
    if (pending != null) {
      if (identical(pending.registration, _registrations[source]))
        return pending.task;
      return pending.task.then((_) => restoreOnEntry(source));
    }
    late final Future<AccountSessionRestoreResult> task;
    task = _restoreOnEntry(source).whenComplete(() {
      if (identical(_restoreTasks[source]?.task, task))
        _restoreTasks.remove(source);
    });
    _restoreTasks[source] = (registration: _registrations[source], task: task);
    return task;
  }

  Future<AccountSessionRestoreResult> _restoreOnEntry(String source) async {
    final registration = _registrations[source];
    final sessionSource = normalizePluginId(source);
    if (!_enabled() ||
        registration == null ||
        !_live(source, registration) ||
        pluginSessionWriteFence.isChanging(sessionSource) ||
        !_restoring.add(source)) {
      return AccountSessionRestoreResult.notPending;
    }
    final generation = pluginSessionWriteFence.generation(sessionSource);
    try {
      final preferences = await SharedPreferences.getInstance();
      final fingerprint = _pending(preferences)[source];
      if (fingerprint is! String) return AccountSessionRestoreResult.notPending;
      bool sameAccount(int owner) =>
          pluginSessionWriteFence.generation(sessionSource) == owner &&
          _fingerprint(source) == fingerprint;
      bool current(int owner) =>
          _live(source, registration) && sameAccount(owner);

      if (!sameAccount(generation)) {
        await _consume(preferences, source, fingerprint);
        return AccountSessionRestoreResult.notPending;
      }
      if (!_live(source, registration)) {
        return AccountSessionRestoreResult.notPending;
      }
      final VideoAccountBackup? snapshot;
      final bool deleted;
      try {
        snapshot = await registration.service.read();
        if (!current(generation)) return AccountSessionRestoreResult.notPending;
        // Only a versioned, explicit deletion may clear this device's session.
        // Absence/expiry never represents an account deletion.
        deleted = snapshot == null && await registration.service.isDeleted();
      } finally {
        if (!sameAccount(generation)) {
          await _consume(preferences, source, fingerprint);
        }
      }
      if (!current(generation)) return AccountSessionRestoreResult.notPending;
      // Keep the intent during the read-only preflight so a replacement browser
      // can claim it. Consume before mutation to avoid replay over a new login.
      if (!await _consume(preferences, source, fingerprint) ||
          snapshot == null && !deleted) {
        return AccountSessionRestoreResult.notPending;
      }
      if (!current(generation)) return AccountSessionRestoreResult.notPending;
      // The settings commit and this exact WebKit store mutation can happen
      // on different visits. Fence the cookie operation itself.
      return await runPluginSessionChange(sessionSource, () async {
        final owner = pluginSessionWriteFence.generation(sessionSource);
        bool canApply() => current(owner);
        if (snapshot == null) {
          await registration.service.clearSession(canApply: canApply);
          return AccountSessionRestoreResult.cleared;
        }
        await registration.service.restore(snapshot, canApply: canApply);
        return AccountSessionRestoreResult.restored;
      });
    } catch (_) {
      return AccountSessionRestoreResult.failed;
    } finally {
      _restoring.remove(source);
    }
  }

  /// Explicit logout for a built-in host after its website confirmed success.
  Future<void> recordStoredSignOut(String source, Uri origin) async {
    await savePluginConfigValue(source, 'account.backup', {
      'version': 1,
      'origin': origin.origin,
      'deleted': true,
    });
    final preferences = await SharedPreferences.getInstance();
    final fingerprint = _pending(preferences)[source];
    if (fingerprint is String) await _consume(preferences, source, fingerprint);
  }

  /// User-confirmed successful sign out. Passive signedOut/CF observations must
  /// never call this: they are device failures, not portable account deletions.
  Future<void> recordSignOut(String source, {Object? lease}) async {
    final registration = _registrations[source];
    if (registration == null ||
        lease != null && !identical(lease, registration))
      return;
    await registration.service.forget();
    final preferences = await SharedPreferences.getInstance();
    final fingerprint = _pending(preferences)[source];
    if (fingerprint is String) await _consume(preferences, source, fingerprint);
  }
}
