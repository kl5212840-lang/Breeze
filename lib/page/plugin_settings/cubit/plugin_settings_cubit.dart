import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/service/plugin_account_authentication.dart';
import 'package:zephyr/service/plugin_account_profiles.dart';
import 'package:zephyr/service/plugin_account_sync_coordinator.dart';
import 'package:zephyr/page/video/video_account_backup.dart';
import 'package:zephyr/page/video/omo_network.dart' show omoNetworkSource;
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/plugin/plugin_login_capability.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/http/plugin/unified_plugin_envelope.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/page/plugin_settings/plugin_settings_action_policy.dart';

class PluginSettingsState {
  const PluginSettingsState({
    this.loading = true,
    this.hasLoadedSettings = false,
    this.error = '',
    this.sections = const <Map<String, dynamic>>[],
    this.actions = const <Map<String, dynamic>>[],
    this.values = const <String, dynamic>{},
    this.userInfo = const <String, dynamic>{},
    this.canShowUserInfo = false,
    this.loginSupported = false,
    this.accountProfilesSupported = false,
    this.loginTitle = '',
    this.loginSubtitle = '',
    this.detailSupported = false,
    this.loadingUserInfo = false,
    this.userInfoError = '',
    this.userInfoLoginRequired = false,
    this.isVideoSource = false,
    this.avatarRevision = 0,
  });

  final int avatarRevision;
  final bool loading;
  final bool hasLoadedSettings;

  // A successful empty schema is still loaded content. Nonempty sections also
  // identify preloaded states supplied by existing callers.
  bool get hasContent =>
      hasLoadedSettings ||
      sections.isNotEmpty ||
      actions.isNotEmpty ||
      canShowUserInfo ||
      loginSupported;

  final String error;
  final List<Map<String, dynamic>> sections;
  final List<Map<String, dynamic>> actions;
  final Map<String, dynamic> values;
  final Map<String, dynamic> userInfo;
  final bool canShowUserInfo;
  final bool loginSupported;
  final bool accountProfilesSupported;
  final String loginTitle;
  final String loginSubtitle;
  final bool detailSupported;
  final bool loadingUserInfo;
  final String userInfoError;
  final bool userInfoLoginRequired;
  final bool isVideoSource;
  PluginSettingsState copyWith({
    int? avatarRevision,
    bool? loading,
    bool? hasLoadedSettings,
    String? error,
    List<Map<String, dynamic>>? sections,
    List<Map<String, dynamic>>? actions,
    Map<String, dynamic>? values,
    Map<String, dynamic>? userInfo,
    bool? canShowUserInfo,
    bool? loginSupported,
    bool? accountProfilesSupported,
    String? loginTitle,
    String? loginSubtitle,
    bool? detailSupported,
    bool? loadingUserInfo,
    String? userInfoError,
    bool? userInfoLoginRequired,
    bool? isVideoSource,
  }) {
    return PluginSettingsState(
      avatarRevision: avatarRevision ?? this.avatarRevision,
      loading: loading ?? this.loading,
      hasLoadedSettings: hasLoadedSettings ?? this.hasLoadedSettings,
      error: error ?? this.error,
      sections: sections ?? this.sections,
      actions: actions ?? this.actions,
      values: values ?? this.values,
      userInfo: userInfo ?? this.userInfo,
      canShowUserInfo: canShowUserInfo ?? this.canShowUserInfo,
      loginSupported: loginSupported ?? this.loginSupported,
      accountProfilesSupported:
          accountProfilesSupported ?? this.accountProfilesSupported,
      loginTitle: loginTitle ?? this.loginTitle,
      loginSubtitle: loginSubtitle ?? this.loginSubtitle,
      detailSupported: detailSupported ?? this.detailSupported,
      loadingUserInfo: loadingUserInfo ?? this.loadingUserInfo,
      userInfoError: userInfoError ?? this.userInfoError,
      userInfoLoginRequired:
          userInfoLoginRequired ?? this.userInfoLoginRequired,
      isVideoSource: isVideoSource ?? this.isVideoSource,
    );
  }
}

class PluginSettingsCubit extends Cubit<PluginSettingsState> {
  PluginSettingsCubit({
    this.includeAccount = true,
    this.includeLogin = true,
    String? userInfoFunction,
    this.readWebIdentity,
  }) : userInfoFunction = userInfoFunction?.trim().isNotEmpty == true
           ? userInfoFunction!.trim()
           : 'getUserInfoBundle',
       _hasExplicitUserInfo = userInfoFunction?.trim().isNotEmpty == true,
       super(const PluginSettingsState()) {
    _identitySubscription = PluginAccountIdentities.changes.listen((source) {
      if (source == _source && !isClosed && includeAccount)
        _readConfirmedIdentity();
    });
    _endpointSubscription = settingsPluginEndpointChanges.listen((change) {
      final source = change.source;
      if (!includeAccount ||
          source != _source ||
          isClosed ||
          pluginSessionWriteFence.isChanging(source))
        return;
      _userInfoEpoch++;
      _userInfoRequest = null;
      if (change.refresh) {
        unawaited(loadUserInfo(source));
      } else if (state.loadingUserInfo) {
        emit(state.copyWith(loadingUserInfo: false));
      }
    });
  }

  final Future<PluginAccountAuthentication?> Function()? readWebIdentity;
  Future<void>? _userInfoRequest;
  String? _requestSource;
  int? _requestGeneration, _requestInstallation;
  final bool includeAccount;
  final bool includeLogin;
  final String userInfoFunction;
  final bool _hasExplicitUserInfo;
  int _loadEpoch = 0, _userInfoEpoch = 0;
  String? _source;
  late final StreamSubscription<String> _identitySubscription;
  late final StreamSubscription<({String source, bool refresh})>
  _endpointSubscription;
  bool _schemaUserInfo = false;
  void _readConfirmedIdentity() {
    final source = _source;
    if (source == null || isClosed) return;
    final proof = PluginAccountIdentities.current(source);
    if (proof != null) {
      final info = proof.toUserInfo();
      if ((info['lines'] as List).isEmpty)
        info['lines'] = [t.videoSource.signedIn];
      emit(
        state.copyWith(
          canShowUserInfo: true,
          userInfo: info,
          userInfoError: '',
          userInfoLoginRequired: false,
          loadingUserInfo: false,
        ),
      );
    } else if (state.userInfo['hostVerified'] == true) {
      emit(
        state.copyWith(
          canShowUserInfo: _schemaUserInfo,
          userInfo: const {},
          userInfoError: '',
          loadingUserInfo: false,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _identitySubscription.cancel();
    await _endpointSubscription.cancel();
    return super.close();
  }

  Future<void> load(
    String from, {
    bool refreshAvatar = false,
    bool refreshAccount = true,
  }) async {
    final sameSource = _source == from;
    _source = from;
    final epoch = ++_loadEpoch;
    if (refreshAccount || !sameSource) {
      _userInfoEpoch++;
      _userInfoRequest = null;
    }
    emit(
      state.copyWith(
        loading: true,
        error: '',
        avatarRevision: state.avatarRevision + (refreshAvatar ? 1 : 0),
      ),
    );

    try {
      final settingsResponse = await callUnifiedComicPlugin(
        from: from,
        fnPath: 'getSettingsBundle',
        notifyUnauthorized: false,
        core: const <String, dynamic>{},
        extern: const <String, dynamic>{},
      );
      final settingsEnvelope = UnifiedPluginEnvelope.fromMap(settingsResponse);
      final settingsSections = asJsonList(
        settingsEnvelope.scheme['sections'],
      ).map((item) => asJsonMap(item)).toList();
      final values = asJsonMap(settingsEnvelope.data['values']);
      final canShowUserInfo =
          includeAccount &&
          (_hasExplicitUserInfo ||
              settingsEnvelope.data['canShowUserInfo'] == true);
      _schemaUserInfo = canShowUserInfo;
      final loginSupported =
          includeAccount &&
          includeLogin &&
          await resolvePluginLoginSupported(
            from,
            settingsData: settingsEnvelope.data,
          );

      List<Map<String, dynamic>> actions = const [];
      try {
        final capabilityResponse = await callUnifiedComicPlugin(
          from: from,
          fnPath: 'getCapabilitiesBundle',
          notifyUnauthorized: false,
          core: const <String, dynamic>{},
          extern: const <String, dynamic>{},
        );
        final capabilityEnvelope = UnifiedPluginEnvelope.fromMap(
          capabilityResponse,
        );
        actions = asJsonList(capabilityEnvelope.scheme['actions'])
            .map((item) => asJsonMap(item))
            .where(isUserFacingPluginSettingsAction)
            .toList();
      } catch (_) {}

      if (isClosed || epoch != _loadEpoch) return;
      emit(
        state.copyWith(
          loading: false,
          loadingUserInfo: refreshAccount ? false : state.loadingUserInfo,
          hasLoadedSettings: true,
          isVideoSource: settingsEnvelope.data['mediaType'] == 'video',
          error: '',
          sections: settingsSections,
          values: values,
          userInfo: sameSource ? state.userInfo : const <String, dynamic>{},
          canShowUserInfo: refreshAccount
              ? canShowUserInfo
              : state.canShowUserInfo,
          loginSupported: loginSupported,
          accountProfilesSupported:
              includeAccount &&
              (loginSupported ||
                  from == omoNetworkSource ||
                  (() {
                    final config = asJsonMap(
                      settingsEnvelope.data['accountSync'],
                    );
                    final origin = Uri.tryParse(
                      config['origin']?.toString() ?? '',
                    );
                    return origin != null &&
                        VideoAccountService.supported(config, origin);
                  })()),
          loginTitle: _resolveLoginText(settingsEnvelope.data['loginTitle']),
          loginSubtitle: _resolveLoginText(
            settingsEnvelope.data['loginSubtitle'],
          ),
          detailSupported: settingsEnvelope.data['canShowDetail'] == true,
          userInfoError: refreshAccount ? '' : state.userInfoError,
          userInfoLoginRequired: refreshAccount
              ? false
              : state.userInfoLoginRequired,
          actions: actions,
        ),
      );

      if (refreshAccount) {
        _readConfirmedIdentity();
        if (canShowUserInfo || state.accountProfilesSupported)
          await loadUserInfo(from);
      }
    } catch (e) {
      if (isClosed || epoch != _loadEpoch) {
        return;
      }
      emit(
        state.copyWith(loading: false, error: normalizeSearchErrorMessage(e)),
      );
    }
  }

  /// 登录入口文案：插件可经 `loginTitle` / `loginSubtitle` 自定义，空白回退宿主默认。
  String _resolveLoginText(dynamic value) => value?.toString().trim() ?? '';

  Future<void> loadUserInfo(String from) {
    if (!includeAccount ||
        from != _source ||
        isClosed ||
        isPluginEndpointUpdating(from)) {
      return Future.value();
    }
    final generation = pluginSessionWriteFence.generation(from);
    final installation = LocalPluginInstallationState.instance
        .installationEpoch(from);
    if (_requestSource == from &&
        _requestGeneration == generation &&
        _requestInstallation == installation &&
        _userInfoRequest != null) {
      return _userInfoRequest!;
    }
    _requestSource = from;
    _requestGeneration = generation;
    _requestInstallation = installation;
    late final Future<void> request;
    request = _loadUserInfo(from, generation, installation).whenComplete(() {
      if (identical(_userInfoRequest, request)) _userInfoRequest = null;
    });
    return _userInfoRequest = request;
  }

  Future<void> _loadUserInfo(
    String from,
    int generation,
    int installation,
  ) async {
    final epoch = ++_userInfoEpoch;
    final fingerprint = PluginAccountIdentities.fingerprint(from);
    final endpoint = pluginEndpointRevision(from);
    bool current() =>
        !isClosed &&
        from == _source &&
        epoch == _userInfoEpoch &&
        generation == pluginSessionWriteFence.generation(from) &&
        installation ==
            LocalPluginInstallationState.instance.installationEpoch(from) &&
        endpoint == pluginEndpointRevision(from) &&
        fingerprint == PluginAccountIdentities.fingerprint(from);
    emit(
      state.copyWith(
        loadingUserInfo: true,
        userInfoError: '',
        canShowUserInfo: state.canShowUserInfo || readWebIdentity != null,
      ),
    );
    try {
      final authentication = PluginAccountAuthenticationService(from);
      final coordinator = PluginAccountSyncCoordinator.instance;
      if (authentication.hasApiVerification ||
          coordinator.hasProfileAccess(from) ||
          readWebIdentity != null) {
        // A receipt can render immediately, but is never a substitute for this
        // refresh's authenticated server request.
        final proof = authentication.hasApiVerification
            ? await authentication.verify(includeSummary: true)
            : coordinator.hasProfileAccess(from)
            ? await coordinator.refreshCurrentIdentity(from, requireFresh: true)
            : await readWebIdentity!();
        if (!current()) return;
        if (proof != null) {
          PluginAccountIdentities.confirm(from, proof, generation: generation);
          _readConfirmedIdentity();
          return;
        }
        if (!_schemaUserInfo) {
          emit(state.copyWith(loadingUserInfo: false));
          return;
        }
      } else if (!_schemaUserInfo) {
        emit(state.copyWith(loadingUserInfo: false));
        return;
      }
      final response = await callUnifiedComicPlugin(
        from: from,
        fnPath: userInfoFunction,
        notifyUnauthorized: false,
        core: const <String, dynamic>{},
        extern: const <String, dynamic>{},
      );
      final envelope = UnifiedPluginEnvelope.fromMap(response);
      if (!current()) return;
      emit(
        state.copyWith(
          userInfo: asJsonMap(envelope.data),
          loadingUserInfo: false,
          userInfoError: '',
          userInfoLoginRequired: false,
        ),
      );
    } catch (error) {
      if (!current()) return;
      final rejected =
          error is PluginLoginRequiredException ||
          error is PluginAccountAuthenticationRejected;
      if (rejected)
        PluginAccountIdentities.reject(from, generation: generation);
      emit(
        state.copyWith(
          loadingUserInfo: false,
          canShowUserInfo:
              state.canShowUserInfo || !rejected && state.userInfo.isNotEmpty,
          userInfo: rejected ? const {} : null,
          userInfoLoginRequired: rejected,
          userInfoError: rejected
              ? t.navigation.needLoginTitle
              : from == PluginAccountAuthenticationService.copy &&
                    isTransientNetworkError(error)
              ? t.login.networkUnavailable
              : t.plugin.userInfoLoadFailed,
        ),
      );
    } finally {
      if (!isClosed && epoch == _userInfoEpoch && state.loadingUserInfo) {
        emit(state.copyWith(loadingUserInfo: false));
      }
    }
  }

  void resetAfterPersonalDataClear() {
    _loadEpoch++;
    _userInfoEpoch++;
    if (!isClosed) {
      emit(
        state.copyWith(
          loading: false,
          hasLoadedSettings: true,
          values: const {},
          userInfo: const {},
          canShowUserInfo: false,
          loadingUserInfo: false,
          userInfoError: '',
          userInfoLoginRequired: false,
          error: '',
        ),
      );
    }
  }

  void saveFieldValue(String key, dynamic value) {
    if (key.isEmpty) {
      return;
    }
    emit(
      state.copyWith(
        values: Map<String, dynamic>.from(state.values)..[key] = value,
      ),
    );
  }
}
