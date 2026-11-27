import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/network/http/plugin/unified_plugin_envelope.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/main.dart' show eventBus;
import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/page/login/login_error_message.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/service/plugin_account_profiles.dart';
import 'package:zephyr/service/plugin_account_response.dart';
import 'package:zephyr/service/plugin_account_sync_coordinator.dart';
import 'package:zephyr/util/event/event.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/util/json/json_value.dart';

typedef PluginAccountCall =
    Future<Map<String, dynamic>> Function(
      String function,
      Map<String, dynamic> values,
    );

/// Verifies both declared identities and sessions from older login bundles.
class PluginAccountAuthenticationService {
  PluginAccountAuthenticationService(this.source, {PluginAccountCall? call})
    : call =
          call ??
          ((fn, values) => callUnifiedComicPlugin(
            from: source,
            fnPath: fn,
            core: values,
            notifyUnauthorized: false,
          ));
  final String source;
  final PluginAccountCall call;
  static const bika = {'e9f18928-3ba8-4d86-a12e-b53a62f47933'};
  static const jm = '6886291b-f524-441c-844b-c2efae9899a9';
  static const copy = 'b28da416-f2d4-4208-a85e-8b4c7c648e48';
  static int _verifiedJmEndpoint = 0;

  // Collection snapshots retain the known account while My verifies the line.
  static PluginAccountAuthentication? currentJmProfileIdentity() =>
      _verifiedJmEndpoint == effectivePluginEndpointRevision(jm)
      ? PluginAccountIdentities.current(jm)
      : null;

  String? get _identityReader {
    if (source == jm) return 'getUserProfileDetails';
    if (bika.contains(source) || source == copy) return 'getUserInfoBundle';
    final declaration = asJsonMap(
      PluginRegistryService.I.getCachedPluginInfo(source)?['accountIdentity'],
    );
    final function = declaration['readFn'];
    return declaration['version'] == 1 &&
            function is String &&
            RegExp(r'^[A-Za-z][A-Za-z0-9_]{0,63}$').hasMatch(function) &&
            !isStandardPluginSessionChange(function)
        ? function
        : null;
  }

  bool get hasApiVerification => _identityReader != null;

  ({int generation, int installation, int endpoint}) get _accountScope => (
    generation: pluginSessionWriteFence.generation(source),
    installation: LocalPluginInstallationState.instance.installationEpoch(
      source,
    ),
    endpoint: pluginEndpointRevision(source),
  );

  Future<PluginAccountAuthentication> verify({
    bool includeSummary = false,
  }) async {
    final reader = _identityReader;
    if (reader == null) throw const PluginAccountNeedsLogin();
    if (isPluginEndpointUpdating(source)) throw const PluginSessionChanged();
    final generation = pluginSessionWriteFence.generation(source);
    final installation = LocalPluginInstallationState.instance
        .installationEpoch(source);
    final endpoint = pluginEndpointRevision(source);
    bool ownsRequest() =>
        pluginSessionWriteFence.generation(source) == generation &&
        LocalPluginInstallationState.instance.installationEpoch(source) ==
            installation &&
        pluginEndpointRevision(source) == endpoint;
    try {
      final response = await call(reader, const {});
      if (!ownsRequest()) throw const PluginSessionChanged();
      var proof = fromServerResponse(response);
      if (source == jm && includeSummary) {
        // The server useredit request establishes identity; the same-account
        // stored session may supplement fields that this endpoint omits.
        try {
          final summary = await call('getSettingsUserInfoBundle', const {});
          final data = asJsonMap(summary['data']);
          final avatar = asJsonMap(data['avatar']);
          final account = asJsonMap(data['extern']);
          final summaryId = (account['uid'] ?? avatar['id'])?.toString();
          if (summaryId == proof.serverIdentity && data['available'] != false) {
            final projected = _publicSummary(data, proof.serverIdentity);
            final lines = asJsonList(
              projected['lines'],
            ).whereType<String>().toList();
            proof = PluginAccountAuthentication(
              serverIdentity: proof.serverIdentity,
              label: proof.label,
              avatarUrl: avatar['url']?.toString() ?? '',
              publicSummary: {
                ...projected,
                'lines': [
                  if (proof.label.isNotEmpty) proof.label,
                  ...lines.where((line) => line != proof.label),
                ],
                'profileDataSource': 'verifiedIdentityStoredSummary',
              },
            );
          }
        } catch (_) {
          /* Optional display fields cannot invalidate fresh login. */
        }
      }
      if (!ownsRequest()) throw const PluginSessionChanged();
      final confirmed = PluginAccountIdentities.confirm(
        source,
        proof,
        generation: generation,
      );
      if (source == jm && confirmed) {
        _verifiedJmEndpoint = effectivePluginEndpointRevision(jm);
      }
      return proof;
    } catch (error) {
      if (!ownsRequest()) throw const PluginSessionChanged();
      if (error is PluginAccountNeedsLogin ||
          error is PluginLoginRequiredException &&
              error.payload.appliesTo(source)) {
        PluginAccountIdentities.reject(source, generation: generation);
      }
      rethrow;
    }
  }

  /// Bika/Copy's actual user-info request is authoritative. JM's cached card
  /// must instead be paired with its dedicated fresh useredit request.
  bool acceptFreshUserInfo(
    Map<String, dynamic> response, {
    required int generation,
  }) {
    if (!hasApiVerification || source == jm) return false;
    return PluginAccountIdentities.confirm(
      source,
      fromServerResponse(response),
      generation: generation,
    );
  }

  PluginAccountAuthentication fromServerResponse(
    Map<String, dynamic> response,
  ) {
    final data = readPluginAccountData(source, response);
    final extern = asJsonMap(data['extern']);
    final avatar = asJsonMap(data['avatar']);
    final id =
        (source == jm
                ? data['accountId']
                : source == copy
                ? extern['userId']
                : bika.contains(source)
                ? avatar['id']
                : data['accountId'])
            ?.toString()
            .trim() ??
        '';
    if (id.isEmpty ||
        id == 'me' ||
        data['available'] == false ||
        source == jm && data['profileDataSource'] != 'serverUserEdit')
      throw const PluginAccountSwitchFailed();
    final label =
        (source == jm
                ? data['nickname']
                : source == copy
                ? extern['username']
                : bika.contains(source)
                ? extern['name']
                : data['name'])
            ?.toString()
            .trim() ??
        '';
    final summary = _publicSummary(data, id);
    return PluginAccountAuthentication(
      serverIdentity: id,
      label: label,
      avatarUrl: avatar['url']?.toString() ?? '',
      publicSummary: summary,
    );
  }

  Map<String, dynamic> _publicSummary(Map<String, dynamic> data, String id) {
    final avatar = asJsonMap(data['avatar']);
    final extern = asJsonMap(data['extern']);
    final rawAvatar = avatar['url']?.toString() ?? '';
    final image = Uri.tryParse(rawAvatar);
    final safeAvatar =
        image != null &&
            image.scheme == 'https' &&
            image.host.isNotEmpty &&
            image.userInfo.isEmpty &&
            !image.hasQuery &&
            !image.hasFragment
        ? rawAvatar
        : '';
    final path = avatar['path'];
    return {
      if (data['title'] is String) 'title': data['title'],
      'lines': [
        for (final line in asJsonList(
          data['lines'],
        ).whereType<String>().take(6))
          line,
      ],
      'avatar': {
        if (id.isNotEmpty) 'id': id,
        if (safeAvatar.isNotEmpty) 'url': safeAvatar,
        if (path is String &&
            path.length <= 4096 &&
            image?.hasQuery != true &&
            !RegExp(r'[?#]|%3[fF]|%23').hasMatch(path))
          'path': path,
      },
      'extern': {
        for (final key in const [
          'name',
          'username',
          'accountName',
          'email',
          'membership',
          'points',
          'level',
          'title',
          'slogan',
          'exp',
          'experience',
          'coin',
          'nextLevelExperience',
          'checkedInDate',
          'checkinProof',
          'accountId',
          'userId',
          'uid',
        ])
          if (extern.containsKey(key)) key: extern[key],
      },
    };
  }

  Future<PluginAccountAuthentication> authenticate(
    PluginAccountProfile profile,
  ) async {
    if (profile.kind == 'web' ||
        !hasApiVerification && profile.bundle['account.backup'] is Map)
      return PluginAccountSyncCoordinator.instance.activateProfile(
        source,
        profile,
      );
    if (!hasApiVerification) return _verifyLegacyProfile(profile);
    try {
      return await verify();
    } catch (error) {
      if (error is! PluginLoginRequiredException ||
          !error.payload.appliesTo(source)) {
        rethrow;
      }
    }
    final account = profile.identity;
    final password = PluginAccountProfiles.savedNativePassword(profile);
    if (account.isEmpty || password == null)
      throw const PluginAccountNeedsLogin();
    final scope = _accountScope;
    final login = await call('getLoginBundle', const {});
    if (scope != _accountScope || isPluginEndpointUpdating(source))
      throw const PluginSessionChanged();
    if (loginResponseFailure(login) != null)
      throw const PluginAccountNeedsLogin();
    requirePluginAccountResponseSource(source, login);
    final scheme = asJsonMap(login['scheme']),
        action = asJsonMap(asJsonMap(login['scheme'])['action']);
    final fn =
        (action['fnPath'] ?? scheme['submitFnPath'] ?? scheme['fnPath'])
            ?.toString() ??
        '';
    final fields = asJsonList(scheme['fields']).map(asJsonMap).toList();
    final identity = fields
        .where(
          (f) =>
              const ['account', 'username', 'email'].contains(f['key']) &&
              f['kind'] == 'text',
        )
        .firstOrNull;
    // Never synthesize captcha, hidden fields or unknown form inputs.
    if (fn.isEmpty ||
        fields.length != 2 ||
        identity == null ||
        !fields.any((f) => f['key'] == 'password' && f['kind'] == 'password'))
      throw const PluginAccountNeedsLogin();
    final values = {'${identity['key']}': account, 'password': password};
    final savedOrigin = asJsonMap(
      profile.bundle['account.credentials'],
    )['origin'];
    final result = await call(fn, {
      ...values,
      'values': values,
      if (source == copy && savedOrigin is String)
        'savedCredentialOrigin': savedOrigin,
    });
    if (scope != _accountScope || isPluginEndpointUpdating(source))
      throw const PluginSessionChanged();
    if (loginResponseFailure(result) != null)
      throw const PluginAccountSwitchFailed();
    readPluginAccountData(source, result);
    return verifyAfterLogin();
  }

  /// Captured immediately before the user's form actually submits.
  String? legacySession() =>
      legacyPluginAccountSession(readHostPluginConfiguration(source));

  Future<PluginAccountAuthentication> verifyNativeLogin(
    Map<String, dynamic> result, {
    required String account,
    required String? previousSession,
  }) async {
    if (hasApiVerification) return verifyAfterLogin();
    requirePluginAccountResponseSource(source, result);
    final data = UnifiedPluginEnvelope.fromMap(result).data;
    final confirmedSubmit = [
      result,
      data,
    ].any((fields) => fields['ok'] == true || fields['success'] == true);
    final session = legacySession();
    if (session == null) throw const PluginAccountNeedsLogin();
    final scope = _accountScope;
    Future<PluginAccountAuthentication> read() => _readLegacyIdentity(
      account,
      boundSession: confirmedSubmit && session != previousSession
          ? session
          : null,
    );
    try {
      return await read();
    } catch (error) {
      if (!isTransientNetworkError(error)) rethrow;
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (scope != _accountScope || session != legacySession())
      throw const PluginSessionChanged();
    return read();
  }

  Future<PluginAccountAuthentication> _verifyLegacyProfile(
    PluginAccountProfile profile, {
    bool locallySelected = false,
  }) {
    return _readLegacyIdentity(
      profile.identity,
      expectedId: profile.serverIdentity,
      boundSession: locallySelected
          ? legacyPluginAccountSession(profile.bundle)
          : null,
    );
  }

  Future<PluginAccountAuthentication?> verifyPreviouslySelectedLegacy() async {
    final scope = _accountScope;
    final selected = await PluginAccountProfiles.selected(source);
    if (scope != _accountScope) throw const PluginSessionChanged();
    final target = PluginAccountProfiles.read(source).profiles[selected];
    if (target == null || target.kind == 'web') return null;
    try {
      final proof = await _verifyLegacyProfile(target, locallySelected: true);
      if (!PluginAccountIdentities.confirm(
        source,
        proof,
        generation: scope.generation,
      ))
        throw const PluginSessionChanged();
      return proof;
    } on PluginLoginRequiredException {
      PluginAccountIdentities.reject(source, generation: scope.generation);
      rethrow;
    }
  }

  Future<PluginAccountAuthentication> _readLegacyIdentity(
    String account, {
    String expectedId = '',
    String? boundSession,
  }) async {
    if (isPluginEndpointUpdating(source)) throw const PluginSessionChanged();
    final scope = _accountScope;
    final configuration = readHostPluginConfiguration(source);
    final session = legacyPluginAccountSession(configuration);
    if (session == null ||
        pluginAccountBundleIdentity(configuration) != account)
      throw const PluginAccountNeedsLogin();
    late final Map<String, dynamic> response;
    try {
      response = await call('getUserInfoBundle', const {});
    } catch (error) {
      final reason = quickJsErrorMessage(error) ?? '';
      if (reason.contains('function path not found') ||
          reason.contains('target is not function')) {
        throw const PluginAccountNeedsLogin();
      }
      rethrow;
    } finally {
      if (scope != _accountScope ||
          session != legacySession() ||
          pluginAccountBundleIdentity(readHostPluginConfiguration(source)) !=
              account)
        throw const PluginSessionChanged();
    }
    final data = readPluginAccountData(source, response);
    final ext = asJsonMap(data['extern']);
    final avatar = asJsonMap(data['avatar']);
    final serverId =
        <Object?>[
              data['accountId'],
              data['userId'],
              ext['accountId'],
              ext['userId'],
              ext['uid'],
            ]
            .where((value) => value is String || value is int)
            .map((value) => value.toString().trim())
            .firstWhere(
              (v) =>
                  v.isNotEmpty &&
                  v.length <= 300 &&
                  !const {
                    'me',
                    '0',
                    'avatar',
                    'guest',
                    'null',
                    'undefined',
                  }.contains(v),
              orElse: () => '',
            );
    final returnedLogin = [
      data['account'],
      data['username'],
      ext['account'],
      ext['username'],
    ].whereType<String>().map((v) => v.trim()).firstOrNull;
    final title = data['title'] is String
        ? (data['title'] as String).trim()
        : '';
    final readableSummary =
        asJsonMap(response['scheme'])['type'] == 'userInfo' &&
        (title.isNotEmpty ||
            avatar['url']?.toString().isNotEmpty == true ||
            asJsonList(
              data['lines'],
            ).whereType<String>().any((line) => line.trim().isNotEmpty));
    if (data['available'] == false ||
        expectedId.isNotEmpty && serverId != expectedId ||
        returnedLogin != null &&
            returnedLogin.isNotEmpty &&
            returnedLogin != account ||
        !(serverId.isNotEmpty && serverId == expectedId ||
            returnedLogin == account ||
            readableSummary && boundSession == session)) {
      throw const PluginAccountNeedsLogin();
    }
    return PluginAccountAuthentication(
      serverIdentity: serverId,
      loginIdentity: account,
      label: title.isNotEmpty && title.length <= 300 ? title : account,
      avatarUrl: avatar['url']?.toString() ?? '',
      publicSummary: _publicSummary(data, serverId),
    );
  }

  /// User info is a read. A dropped response must never repeat a password
  /// submission or allow an unverified account to become the active profile.
  Future<PluginAccountAuthentication> verifyAfterLogin() async {
    final scope = _accountScope;
    try {
      return await verify();
    } catch (error) {
      if (!isTransientNetworkError(error) &&
          !(source == copy &&
              quickJsErrorMessage(error) == '无法读取拷贝账号资料，请稍后重试')) {
        rethrow;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (scope != _accountScope) throw const PluginSessionChanged();
    return verify();
  }

  Future<void> signOut() async {
    PluginAccountProfiles.read(
      source,
    ); // Preflight before touching credentials/cookies.
    final wasChanging = pluginSessionWriteFence.isChanging(source);
    await runPluginSessionChange(source, () async {
      if (hasApiVerification && source != copy) {
        final result = await call('clearPluginSession', const {});
        if (result['ok'] != true) throw const PluginAccountSwitchFailed();
      } else {
        final coordinator = PluginAccountSyncCoordinator.instance;
        final backup = readHostPluginConfiguration(source)['account.backup'];
        if (coordinator.hasProfileAccess(source)) {
          // The live site's session exists independently of whether a portable
          // backup could be saved. Explicit sign out must clear that exact store.
          await coordinator.signOutProfile(source);
        } else if (backup is Map && backup['deleted'] != true) {
          throw const PluginAccountNeedsLogin();
        }
      }
      replaceActivePluginAccount(source, const {});
    });
    if (!wasChanging) eventBus.fire(PluginAccountSignedOut(source));
  }

  Future<void> rememberLogin() async {
    if (hasApiVerification) {
      final proof = await verify();
      await PluginAccountProfiles.rememberVerifiedCurrent(
        source,
        proof,
        explicitSave: true,
      );
    } else {
      await PluginAccountProfiles.rememberCurrent(source, explicitSave: true);
    }
  }

  Future<void> switchToWithLogin(
    String id, {
    required Future<void> Function() login,
    bool Function()? canContinue,
  }) async {
    if (hasApiVerification) return switchTo(id);
    await PluginAccountProfiles.switchTo(
      source,
      id,
      authenticate: (profile) =>
          PluginAccountSyncCoordinator.instance.activateCredentials(
            source,
            profile,
            login: login,
            canContinue: canContinue,
          ),
    );
    eventBus.fire(PluginLoginSucceeded(source));
  }

  Future<void> switchTo(String id) async {
    await PluginAccountProfiles.switchTo(
      source,
      id,
      authenticate: authenticate,
    );
    eventBus.fire(PluginLoginSucceeded(source));
  }
}
