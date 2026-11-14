import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/main.dart' show eventBus;
import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/page/login/login_error_message.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/plugin_account_profiles.dart';
import 'package:zephyr/service/plugin_account_sync_coordinator.dart';
import 'package:zephyr/util/event/event.dart';
import 'package:zephyr/util/json/json_value.dart';

typedef PluginAccountCall =
    Future<Map<String, dynamic>> Function(
      String function,
      Map<String, dynamic> values,
    );

/// Only explicit adapters with a fresh server response can confirm a switch.
/// Other declared login schemes remain available through the existing login UI.
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
  bool get hasApiVerification =>
      bika.contains(source) || source == jm || source == copy;

  Future<PluginAccountAuthentication> verify({
    bool includeSummary = false,
  }) async {
    if (!hasApiVerification) throw const PluginAccountNeedsLogin();
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
      final response = await call(
        source == jm ? 'getUserProfileDetails' : 'getUserInfoBundle',
        const {},
      );
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
      PluginAccountIdentities.confirm(source, proof, generation: generation);
      return proof;
    } catch (error) {
      if (!ownsRequest()) throw const PluginSessionChanged();
      if (error is PluginLoginRequiredException) {
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
    if (loginResponseFailure(response) != null)
      throw const PluginAccountSwitchFailed();
    final data = asJsonMap(response['data']),
        extern = asJsonMap(asJsonMap(response['data'])['extern']);
    final avatar = asJsonMap(data['avatar']);
    final id =
        (source == jm
                ? data['accountId']
                : source == copy
                ? extern['userId']
                : avatar['id'])
            ?.toString()
            .trim() ??
        '';
    if (id.isEmpty ||
        id == 'me' ||
        source == jm && data['profileDataSource'] != 'serverUserEdit')
      throw const PluginAccountSwitchFailed();
    final label =
        (source == jm
                ? data['nickname']
                : source == copy
                ? extern['username']
                : extern['name'])
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
        'id': id,
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
    if (!hasApiVerification) throw const PluginAccountNeedsLogin();
    try {
      return await verify();
    } catch (error) {
      // A Copy connectivity failure or unusable member response cannot
      // establish that the saved session needs replacing.
      if (source == copy &&
          (error is! PluginLoginRequiredException ||
              error.payload.pluginId != source)) {
        rethrow;
      }
    }
    final bundle = profile.bundle,
        credentials = asJsonMap(bundle['account.credentials']);
    final account =
        (bundle['auth.account'] ??
                bundle['auth.username'] ??
                credentials['account'])
            ?.toString() ??
        '';
    final password =
        (bundle['auth.password'] ?? credentials['password'])?.toString() ?? '';
    if (account.isEmpty || password.isEmpty)
      throw const PluginAccountNeedsLogin();
    final login = await call('getLoginBundle', const {});
    final scheme = asJsonMap(login['scheme']),
        action = asJsonMap(asJsonMap(login['scheme'])['action']);
    final fn =
        (action['fnPath'] ?? scheme['submitFnPath'] ?? scheme['fnPath'])
            ?.toString() ??
        '';
    final fields = asJsonList(scheme['fields']).map(asJsonMap).toList();
    // Never synthesize captcha, hidden fields or unknown required form inputs.
    if (fn.isEmpty ||
        fields.isEmpty ||
        fields.any(
          (f) =>
              !const ['account', 'username', 'password'].contains(f['key']) ||
              !const ['text', 'password'].contains(f['kind']),
        ))
      throw const PluginAccountNeedsLogin();
    final values = {
      for (final f in fields)
        '${f['key']}': f['key'] == 'password' ? password : account,
    };
    final savedOrigin = credentials['origin'];
    final result = await call(fn, {
      ...values,
      'values': values,
      if (source == copy && savedOrigin is String)
        'savedCredentialOrigin': savedOrigin,
    });
    if (loginResponseFailure(result) != null)
      throw const PluginAccountSwitchFailed();
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
    PluginAccountAuthentication? proof;
    if (hasApiVerification) proof = await verify();
    await PluginAccountProfiles.rememberCurrent(
      source,
      label: proof?.label ?? '',
      serverIdentity: proof?.serverIdentity ?? '',
      select: proof != null,
      explicitSave: true,
    );
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
