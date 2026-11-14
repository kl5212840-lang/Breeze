import 'dart:async';
import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/omo_network.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';
import 'package:zephyr/page/video/video_network_scope.dart';
import 'package:zephyr/page/video/video_site_access.dart';
import 'package:zephyr/page/video/video_site_browser.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/service/plugin_account_profiles.dart';
import 'package:zephyr/service/plugin_account_sync_coordinator.dart';
import 'package:zephyr/util/json/json_value.dart';

typedef PluginSettingsIdentityReader =
    Future<PluginAccountAuthentication?> Function();

/// Only the explicitly supported Omo account API gets a cold-settings reader.
/// Existing live source readers take precedence in the cubit. This reader never
/// captures/uploads accounts, signs in, or handles challenges. Its own lease
/// supports explicit switching and already-queued local account restores.
class PluginSettingsWebAccount extends StatefulWidget {
  const PluginSettingsWebAccount({
    super.key,
    required this.source,
    required this.builder,
  });
  final String source;
  final Widget Function(PluginSettingsIdentityReader? read) builder;
  @override
  State<PluginSettingsWebAccount> createState() =>
      _PluginSettingsWebAccountState();
}

class _PluginSettingsWebAccountState extends State<PluginSettingsWebAccount> {
  Uri? _home;
  bool _active = false;
  Object? _accountLease;
  late final int _installation;
  Future<OmoNetworkContext?>? _network;
  bool _ownsNetwork = false;
  final _document = Completer<InAppWebViewController>();
  Future<PluginAccountAuthentication?>? _pending;
  int _readEpoch = 0;
  @override
  void initState() {
    super.initState();
    _installation = LocalPluginInstallationState.instance.installationEpoch(
      widget.source,
    );
    if (widget.source != omoNetworkSource) return;
    final info = PluginRegistryService.I.getCachedPluginInfo(widget.source);
    for (final item in asJsonList(info?['function'])) {
      final action = asJsonMap(asJsonMap(item)['action']);
      if (action['type'] != 'openVideoLibrary') continue;
      final home = Uri.tryParse(
        asJsonMap(action['payload'])['url']?.toString() ?? '',
      );
      if (home != null &&
          home.scheme == 'https' &&
          home.host.isNotEmpty &&
          home.userInfo.isEmpty &&
          !home.hasQuery &&
          !home.hasFragment) {
        _home = home;
        break;
      }
    }
  }

  Future<PluginAccountAuthentication?> _read() {
    late final Future<PluginAccountAuthentication?> request;
    request = _pending ??= _readCurrent()
        .timeout(
          const Duration(seconds: 20),
          onTimeout: () {
            _readEpoch++;
            throw TimeoutException('Account identity read timed out');
          },
        )
        .whenComplete(() {
          if (identical(_pending, request)) _pending = null;
        });
    return request;
  }

  Future<PluginAccountAuthentication?> _readCurrent() async {
    final epoch = ++_readEpoch;
    final home = _home!;
    final source = widget.source;
    final generation = pluginSessionWriteFence.generation(source);
    final installation = LocalPluginInstallationState.instance
        .installationEpoch(source);
    bool current() =>
        mounted &&
        _installation == installation &&
        epoch == _readEpoch &&
        generation == pluginSessionWriteFence.generation(source) &&
        installation ==
            LocalPluginInstallationState.instance.installationEpoch(source);
    if (!_active) {
      final inherited = VideoNetworkScope.maybeOf(context);
      _ownsNetwork = inherited?.source != source || inherited?.network == null;
      _network = !_ownsNetwork
          ? inherited!.network
          : OmoNetworkContext.open(null, source: source, siteOrigins: [home]);
      setState(() => _active = true);
    }
    final web = await _document.future;
    if (!current()) throw const PluginSessionChanged();
    final coordinator = PluginAccountSyncCoordinator.instance;
    final lease = _accountLease;
    if (coordinator.hasProfileAccess(source) &&
        (lease == null || !coordinator.isRegistered(source, lease))) {
      return coordinator.refreshCurrentIdentity(source, requireFresh: true);
    }
    if (lease == null || !coordinator.isRegistered(source, lease)) {
      final cookies = videoSiteAccountCookies(web);
      if (cookies != null) {
        final registration = await coordinator.registerStoredSession(
          source: source,
          origin: home,
          cookies: cookies,
          identity: _readDocument,
          authenticated: () async => await _readDocument() != null,
        );
        if (!current()) {
          coordinator.unregister(source, registration);
          throw const PluginSessionChanged();
        }
        _accountLease = registration;
      }
    }
    if (!current()) throw const PluginSessionChanged();
    if (_accountLease != null) {
      return coordinator.refreshCurrentIdentity(source, requireFresh: true);
    }
    return _readDocument();
  }

  Future<PluginAccountAuthentication?> _readDocument() async {
    final source = widget.source, home = _home!;
    final epoch = _readEpoch;
    final generation = pluginSessionWriteFence.generation(source);
    bool current() =>
        mounted &&
        epoch == _readEpoch &&
        generation == pluginSessionWriteFence.generation(source) &&
        _installation ==
            LocalPluginInstallationState.instance.installationEpoch(source);
    final web = await _document.future;
    if (!current()) throw const PluginSessionChanged();
    final raw = await videoBrowserReadAsync(
      web,
      '(async (operation, parameters, origin) => {$omoSiteRequestScript})'
      '("account",{"includeProfile":true},${jsonEncode(home.origin)})',
    ).timeout(const Duration(seconds: 15));
    if (!current()) throw const PluginSessionChanged();
    final value = asJsonMap(raw is String ? jsonDecode(raw) : raw);
    if (value['kind'] == 'signedOut')
      throw const PluginAccountAuthenticationRejected();
    if (value['kind'] != 'account') throw const OmoSiteException('unavailable');
    final account = OmoSiteAccount.fromJson(
      asJsonMap(value['account']),
      home: home,
    );
    if (account.id.isEmpty) throw const OmoSiteException('unavailable');
    return PluginAccountAuthentication(
      serverIdentity: account.id,
      label: account.name,
      origin: home.origin,
      avatarUrl: account.avatar?.toString() ?? '',
      publicSummary: {
        'lines': [
          account.name,
          if (account.group.isNotEmpty) account.group,
          if (account.points != null)
            '${t.omoAccount.points}: ${account.points}',
        ],
        'extern': {
          if (account.loginName != null) 'username': account.loginName,
          if (account.email != null) 'email': account.email,
          if (account.points != null) 'points': account.points,
        },
      },
    );
  }

  @override
  void dispose() {
    _readEpoch++;
    final lease = _accountLease;
    if (lease != null)
      PluginAccountSyncCoordinator.instance.unregister(widget.source, lease);
    if (!_document.isCompleted && _pending != null)
      _document.completeError(const PluginSessionChanged());
    if (_ownsNetwork && _network != null)
      unawaited(
        _network!.then<void>((value) async {
          await value?.close();
        }, onError: (Object _) {}),
      );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.builder(_home == null ? null : _read),
      if (_active)
        Offstage(
          child: SizedBox(
            width: 1,
            height: 1,
            child: FutureBuilder<OmoNetworkContext?>(
              future: _network,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done ||
                    snapshot.hasError)
                  return const SizedBox.shrink();
                return VideoSiteBrowser(
                  home: _home!,
                  source: widget.source,
                  networkContext: snapshot.data?.token,
                  configuration: InAppWebView(
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      domStorageEnabled: true,
                    ),
                    onWebViewCreated: (web) async {
                      try {
                        await web.loadUrl(
                          urlRequest: URLRequest(url: WebUri(_home.toString())),
                        );
                      } catch (_) {
                        /* The bounded reader reports failure, not logout. */
                      }
                    },
                    onLoadStop: (web, uri) {
                      if (mounted &&
                          uri?.origin == _home?.origin &&
                          !_document.isCompleted)
                        _document.complete(web);
                    },
                    shouldOverrideUrlLoading: (_, action) async =>
                        allowVideoSiteNavigation(
                          _home!,
                          Uri.tryParse(action.request.url?.toString() ?? ''),
                          isMainFrame: action.isForMainFrame,
                        )
                        ? NavigationActionPolicy.ALLOW
                        : NavigationActionPolicy.CANCEL,
                  ),
                );
              },
            ),
          ),
        ),
    ],
  );
}
