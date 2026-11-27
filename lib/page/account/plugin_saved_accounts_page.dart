import 'dart:async';
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/login_page.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/setting/common/plugin_account_avatar.dart';
import 'package:zephyr/page/donwload_task/view/download_swipe_actions.dart';
import 'package:zephyr/network/http/plugin/qjs_network_route.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';
import 'package:zephyr/page/video/omo_network.dart' show omoNetworkSource;
import 'package:zephyr/page/video/hanime_catalog_scope.dart';
import 'package:zephyr/page/video/video_page_route.dart';
import 'package:zephyr/service/plugin_account_authentication.dart';
import 'package:zephyr/service/plugin_account_profiles.dart';
import 'package:zephyr/service/plugin_account_sync_coordinator.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/widgets/native_view_occlusion.dart';
import 'package:zephyr/widgets/plugin_icon.dart';
import 'package:zephyr/widgets/work_list_divider.dart';
import 'package:zephyr/widgets/short_alert.dart';

const pluginSavedAccountsRouteName = 'breeze.source.saved-accounts';

typedef PluginAccountAddition =
    Future<void> Function(
      Future<void> Function() login,
      bool Function() canContinue,
    );

/// true means the existing source browser must be revealed for sign-in.
Future<bool> openPluginSavedAccounts(
  BuildContext context, {
  required String source,
  required Future<void> Function() onAddAccount,
  bool nativeLoginSupported = false,
  Future<void> Function(PluginAccountAddition)? onAddAccountWithSession,
  Future<void> Function(PluginAccountProfile)? onRecoverAccount,
  Future<void> Function()? prepareSession,
}) async {
  final route = videoPageRoute<bool>(
    settings: const RouteSettings(name: pluginSavedAccountsRouteName),
    builder: (_) => PluginSavedAccountsPage(
      source: source,
      nativeLoginSupported: nativeLoginSupported,
      onAddAccount: onAddAccount,
      onAddAccountWithSession: onAddAccountWithSession,
      onRecoverAccount: onRecoverAccount,
      prepareSession: prepareSession,
    ),
  );
  final completion = Navigator.of(context).push<bool>(route);
  NativeCompositionObserver.observeSharedDestination(context, route);
  return await completion == true;
}

class PluginSavedAccountsPage extends StatefulWidget {
  const PluginSavedAccountsPage({
    super.key,
    required this.source,
    required this.onAddAccount,
    this.nativeLoginSupported = false,
    this.onAddAccountWithSession,
    this.onRecoverAccount,
    this.prepareSession,
    this.authentication,
  });
  final String source;
  final bool nativeLoginSupported;
  final Future<void> Function() onAddAccount;
  final Future<void> Function(PluginAccountAddition)? onAddAccountWithSession;
  final Future<void> Function(PluginAccountProfile)? onRecoverAccount;

  /// Reconnect the source's own live store after a login window has closed.
  /// A retained identity receipt alone cannot capture or switch that store.
  final Future<void> Function()? prepareSession;
  final PluginAccountAuthenticationService? authentication;
  @override
  State<PluginSavedAccountsPage> createState() =>
      _PluginSavedAccountsPageState();
}

class _PluginSavedAccountsPageState extends State<PluginSavedAccountsPage> {
  List<PluginAccountProfile> _profiles = const [];
  String? _selected, _busy, _error, _unverified, _loginRequired;
  Future<void> Function()? _retry, _continueLogin;
  bool get _hasNativeLogin =>
      widget.nativeLoginSupported || _authentication.hasApiVerification;
  bool get _offerRetry => _retry != null || _continueLogin == null;
  bool _loading = true;
  bool _confirmingRemoval = false;
  final _openSwipe = ValueNotifier<String?>(null);
  int _epoch = 0;
  StreamSubscription<String>? _identitySubscription;
  PluginAccountAuthenticationService get _authentication =>
      widget.authentication ??
      PluginAccountAuthenticationService(widget.source);

  @override
  void initState() {
    super.initState();
    _identitySubscription = PluginAccountIdentities.changes.listen((source) {
      if (!mounted || source != widget.source || _loading) return;
      final proof = PluginAccountIdentities.current(source);
      final rows = PluginAccountProfiles.read(
        source,
      ).profiles.values.where((p) => !p.deleted).toList();
      final matching = proof == null
          ? const <PluginAccountProfile>[]
          : rows.where(proof.matchesProfile).toList();
      setState(() {
        _profiles = rows;
        if (proof == null) _unverified = _selected ?? _unverified;
        _selected = matching.length == 1 ? matching.single.id : null;
        if (proof != null) {
          _unverified = null;
          if (_loginRequired == _selected) _loginRequired = null;
        }
      });
    });
    _load();
  }

  @override
  void dispose() {
    _epoch++;
    _openSwipe.dispose();
    unawaited(_identitySubscription?.cancel());
    super.dispose();
  }

  Future<void> _load({bool verifyApi = true}) async {
    final epoch = ++_epoch;
    if (mounted)
      setState(() {
        _loading = true;
        _error = null;
        _retry = null;
        _continueLogin = null;
        _loginRequired = null;
      });
    try {
      // A fresh receipt can label the live account; cached summaries never
      // change the active selection.
      PluginAccountProfiles.read(widget.source);
      if (verifyApi) await widget.prepareSession?.call();
      if (!mounted || epoch != _epoch) return;
      final auth = _authentication;
      var proof = PluginAccountIdentities.current(widget.source);
      final generation = pluginSessionWriteFence.generation(widget.source);
      var loginRequired = false;
      if (_hasNativeLogin && verifyApi) {
        try {
          final isJm = widget.source == PluginAccountAuthenticationService.jm;
          final confirmedProof = auth.hasApiVerification
              ? proof != null && (!isJm || proof.requestAvatarUrl.isNotEmpty)
                    ? proof
                    : await auth.verify(includeSummary: isJm)
              : proof ?? await auth.verifyPreviouslySelectedLegacy();
          proof = confirmedProof;
          if (!mounted || epoch != _epoch) return;
          if (confirmedProof != null) {
            await PluginAccountProfiles.rememberVerifiedCurrent(
              widget.source,
              confirmedProof,
            );
          } else {
            await PluginAccountProfiles.rememberCurrent(widget.source);
          }
        } on PluginSessionChanged {
          proof = PluginAccountIdentities.current(widget.source);
        } catch (error) {
          loginRequired = _needsLogin(error);
          proof = PluginAccountIdentities.current(widget.source);
          await PluginAccountProfiles.rememberCurrent(widget.source);
        }
      } else if (verifyApi &&
          PluginAccountSyncCoordinator.instance.hasProfileAccess(
            widget.source,
          )) {
        final coordinator = PluginAccountSyncCoordinator.instance;
        try {
          proof ??= await coordinator.refreshCurrentIdentity(widget.source);
        } catch (_) {}
        if (!mounted || epoch != _epoch) return;
        if (proof != null) {
          try {
            await coordinator.captureAuthenticated(widget.source);
          } catch (_) {
            /* Backup does not undo identity. */
          }
        }
        proof = PluginAccountIdentities.current(widget.source);
      } else if (verifyApi && !auth.hasApiVerification) {
        await PluginAccountProfiles.rememberCurrent(widget.source);
      }
      final data = PluginAccountProfiles.read(widget.source);
      final selected = await PluginAccountProfiles.selected(widget.source);
      final confirmed =
          proof != null &&
          pluginSessionWriteFence.generation(widget.source) == generation;
      final matches = confirmed
          ? data.profiles.values
                .where((p) => !p.deleted && proof!.matchesProfile(p))
                .toList()
          : const <PluginAccountProfile>[];
      final actual = matches.any((profile) => profile.id == selected)
          ? selected
          : matches.length == 1
          ? matches.single.id
          : null;
      // A positive live identity with no saved session is a capture failure,
      // not evidence that the user has no account. Respect intentional removal.
      final removed =
          confirmed &&
          data.profiles.values.any(
            (profile) => profile.deleted && proof!.matchesProfile(profile),
          );
      final rows = data.profiles.values.where((p) => !p.deleted).toList()
        ..sort(
          (a, b) => a.id == selected
              ? -1
              : b.id == selected
              ? 1
              : a.label.compareTo(b.label) != 0
              ? a.label.compareTo(b.label)
              : a.id.compareTo(b.id),
        );
      if (!mounted || epoch != _epoch) return;
      setState(() {
        _profiles = rows;
        _selected = actual;
        _unverified = confirmed ? null : selected;
        _loginRequired = loginRequired && !confirmed ? selected : null;
        _loading = false;
        if (confirmed && actual == null && !removed)
          _error = t.plugin.userInfoLoadFailed;
      });
    } catch (_) {
      if (mounted && epoch == _epoch)
        setState(() {
          _loading = false;
          _error = t.plugin.userInfoLoadFailed;
        });
    }
  }

  bool _needsLogin(Object error) =>
      error is PluginAccountNeedsLogin ||
      error is PluginAccountAuthenticationRejected ||
      error is PluginLoginRequiredException &&
          error.payload.appliesTo(widget.source);

  Future<void> _run(
    String id,
    Future<void> Function() action, {
    bool switching = false,
  }) async {
    if (_busy != null) return;
    _openSwipe.value = null;
    final previousError = _error;
    setState(() {
      _busy = id;
      _error = null;
    });
    try {
      await action();
      if (mounted) await _load();
    } catch (error) {
      if (mounted) {
        if (error is PluginAccountLoginCancelled) {
          if (_loading) {
            // Adding an account can invalidate the first list load.
            await _load();
          } else {
            setState(() => _error = previousError);
          }
          return;
        }
        await _load(verifyApi: !switching);
        if (mounted) {
          setState(() {
            final nativeSwitch = switching && _hasNativeLogin;
            final customRecovery = switching ? widget.onRecoverAccount : null;
            final networkFailure = isTransientNetworkError(error);
            final needsLogin = nativeSwitch && _needsLogin(error);
            if ((nativeSwitch || customRecovery != null) && !needsLogin) {
              _retry = () => _run(id, action, switching: true);
            }
            if (customRecovery != null || nativeSwitch && !networkFailure) {
              final target = _profiles.where((p) => p.id == id).firstOrNull;
              final recover =
                  customRecovery ??
                  (nativeSwitch ? _recoverNativeAccount : null);
              if (target != null && recover != null) {
                _continueLogin = () =>
                    _run(id, () => recover(target), switching: true);
              }
            }
            if (needsLogin) {
              _loginRequired = id;
              _error = t.navigation.needLoginTitle;
            } else if (switching && networkFailure) {
              _error = t.login.networkUnavailable;
            } else {
              _error = nativeSwitch && _continueLogin == null
                  ? t.plugin.userInfoLoadFailed
                  : t.accountProfiles.switchFailed;
            }
          });
        }
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _recoverNativeAccount(PluginAccountProfile profile) async {
    if (!await openPluginAccountLoginForm(
      context,
      source: widget.source,
      username: profile.identity,
      savedAccount: (id: profile.id, revision: profile.revision),
    )) {
      throw const PluginAccountLoginCancelled();
    }
  }

  Future<void> _switch(PluginAccountProfile profile) async {
    try {
      await _authentication.switchTo(profile.id);
    } catch (error) {
      if (error is! PluginAccountNeedsLogin &&
          error is! PluginAccountAuthenticationRejected)
        rethrow;
      if (_hasNativeLogin || !mounted) rethrow;
      await _switchWithLogin(profile.id);
    }
  }

  Future<void> _switchWithLogin(String id) {
    final epoch = _epoch;
    bool current() => mounted && _epoch == epoch;
    return _authentication.switchToWithLogin(
      id,
      canContinue: current,
      login: () async {
        try {
          final recover = widget.onRecoverAccount;
          final target = _profiles
              .where((profile) => profile.id == id)
              .firstOrNull;
          if (recover != null && target != null) {
            await recover(target);
          } else {
            await widget.onAddAccount();
          }
        } finally {
          if (current()) await widget.prepareSession?.call();
        }
        if (!current()) throw const PluginSessionChanged();
      },
    );
  }

  Future<void> _add() async {
    if (_busy != null) return;
    final coordinator = PluginAccountSyncCoordinator.instance;
    if (coordinator.hasProfileLogin(widget.source)) {
      Navigator.of(context).pop(true);
      return;
    }
    final hanime =
        widget.source == hanimeSourceId &&
        widget.onAddAccountWithSession != null;
    if (widget.source != omoNetworkSource && !hanime) {
      await _run('add', widget.onAddAccount);
      return;
    }
    final source = widget.source;
    _epoch++;
    Future<void> add(
      Future<void> Function() login,
      bool Function() canContinue,
    ) async {
      if (!coordinator.hasProfileAccess(source)) {
        await widget.prepareSession?.call();
      }
      var opened = false;
      try {
        await coordinator.addAccount(
          source,
          login: () {
            opened = true;
            return login();
          },
          reconnect: hanime ? widget.prepareSession : null,
          canContinue: canContinue,
        );
      } catch (error) {
        if (!hanime ||
            opened ||
            !canContinue() ||
            (error is! PluginAccountNeedsLogin &&
                error is! PluginAccountIdentityUnavailable))
          rethrow;
        // A background reader may be unavailable while the user can still
        // complete the site's login or verification in a visible browser.
        await login();
      }
    }

    await _run('add', () {
      final open = widget.onAddAccountWithSession;
      return open == null ? add(widget.onAddAccount, () => mounted) : open(add);
    });
  }

  Future<void> _remove(PluginAccountProfile profile) async {
    if (_busy != null || _confirmingRemoval) return;
    final source = canonicalQjsSource(widget.source);
    final generation = pluginSessionWriteFence.generation(source);
    final current = PluginAccountProfiles.isCurrent(source, profile.id);
    _confirmingRemoval = true;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => ShortAlert(
          title: Text(t.accountProfiles.removeTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text(
                _accountLabel(profile),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                current
                    ? t.accountProfiles.removeCurrentConfirm
                    : t.accountProfiles.removeConfirm,
              ),
            ],
          ),
          actions: [
            ShortAlertAction(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t.common.cancel),
            ),
            ShortAlertAction(
              destructive: true,
              onPressed: () => Navigator.pop(context, true),
              child: Text(t.common.delete),
            ),
          ],
        ),
      );
      if (confirmed != true ||
          !mounted ||
          canonicalQjsSource(widget.source) != source)
        return;
      await _run(
        profile.id,
        () => PluginAccountProfiles.delete(
          source,
          profile.id,
          expectedRevision: profile.revision,
          expectedCurrent: current,
          expectedGeneration: generation,
          signOutCurrent: _authentication.signOut,
        ),
      );
    } finally {
      _confirmingRemoval = false;
    }
  }

  String _accountLabel(PluginAccountProfile profile) =>
      profile.label.trim().isEmpty ? profile.identity : profile.label.trim();

  @override
  Widget build(BuildContext context) => SourceExperienceBoundary(
    source: widget.source,
    builder: (context) => SettingPageShell(
      title: t.accountProfiles.title,
      leading: TapRegion(
        groupId: _openSwipe,
        child: SourceBackButton(
          onPressed: () {
            _openSwipe.value = null;
            unawaited(Navigator.of(context).maybePop());
          },
        ),
      ),
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  t.accountProfiles.cloudHint,
                  style: _supportingStyle(context),
                ),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (!_loading && _profiles.isEmpty && _error == null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(t.accountProfiles.empty),
                ),
              for (final profile in _profiles) _accountRow(context, profile),
              if (_profiles.isNotEmpty) const SizedBox(height: 16),
              ListTile(
                key: const ValueKey('saved-account-add'),
                leading: const Icon(Icons.person_add_outlined),
                title: Text(t.accountProfiles.add),
                onTap: _busy == null ? _add : null,
              ),
              if (_selected != null)
                ListTile(
                  key: const ValueKey('saved-account-sign-out'),
                  leading: const Icon(Icons.logout),
                  title: Text(t.accountProfiles.logout),
                  subtitle: Text(t.accountProfiles.logoutHint),
                  onTap: _busy == null
                      ? () => _run('logout', _authentication.signOut)
                      : null,
                ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  t.accountProfiles.verificationHint,
                  style: _supportingStyle(context),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      if (_offerRetry)
                        TextButton(
                          key: const ValueKey('saved-account-retry'),
                          onPressed: _busy == null ? _retry ?? _load : null,
                          child: Text(t.common.retry),
                        ),
                      if (_continueLogin != null || _retry == null)
                        TextButton(
                          onPressed: _busy == null
                              ? _continueLogin ?? _add
                              : null,
                          child: Text(t.accountProfiles.continueLogin),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          if (_busy != null && !_loading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    ),
  );

  TextStyle? _supportingStyle(BuildContext context) => Theme.of(context)
      .textTheme
      .bodySmall
      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

  Widget _accountRow(BuildContext context, PluginAccountProfile profile) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selected = profile.id == _selected;
    final label = _accountLabel(profile);
    final isJm = widget.source == PluginAccountAuthenticationService.jm;
    final webPortrait =
        profile.kind == 'web' || widget.source == omoNetworkSource;
    final current = selected
        ? PluginAccountIdentities.current(widget.source)
        : null;
    final receipt = current?.matchesProfile(profile) == true ? current : null;
    final requestAvatar = receipt?.requestAvatarUrl ?? '';
    return WorkListRow(
      divided: !selected,
      startInset: 68,
      inset: 12,
      child: DownloadSwipeActions(
        rowKey: 'saved-account-${profile.id}',
        openRow: _openSwipe,
        exposeActions: true,
        groupSecondaryActions: false,
        swipeActionIds: const ['delete'],
        actionVersion: (profile.revision, selected),
        actions: [
          if (_busy == null && !_loading)
            (
              id: 'delete',
              label: t.accountProfiles.removeTitle,
              icon: Icons.delete_outline,
              run: () => unawaited(_remove(profile)),
            ),
        ],
        child: Material(
          color: selected
              ? colors.primary.withValues(alpha: .06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            minTileHeight: 68,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            key: ValueKey('saved-account-${profile.id}'),
            leading:
                isJm ||
                    webPortrait ||
                    requestAvatar.isNotEmpty ||
                    profile.avatarUrl.isNotEmpty
                ? PluginAccountAvatar(
                    source: widget.source,
                    identity: profile.serverIdentity.isNotEmpty
                        ? profile.serverIdentity
                        : profile.identity,
                    url: requestAvatar.isEmpty
                        ? profile.avatarUrl
                        : requestAvatar,
                    path:
                        asJsonMap(
                          receipt?.publicSummary['avatar'],
                        )['path']?.toString() ??
                        '',
                    origin: profile.origin,
                    size: 40,
                  )
                : ClipOval(
                    child: SizedBox.square(
                      dimension: 40,
                      child: PluginIcon(
                        url: profile.avatarUrl,
                        placeholder: CircleAvatar(
                          child: Text(
                            label.isEmpty ? '?' : label.characters.first,
                          ),
                        ),
                      ),
                    ),
                  ),
            title: Text(label, style: theme.textTheme.titleMedium),
            subtitle: Text(
              profile.id == _selected
                  ? PluginAccountProfiles.requiresWebLogin(profile)
                        ? t.accountProfiles.currentNeedsLogin
                        : t.accountProfiles.current
                  : profile.id == _loginRequired
                  ? t.accountProfiles.savedSignInRequired
                  : profile.serverIdentity.isEmpty ||
                        profile.id == _unverified ||
                        PluginAccountProfiles.requiresWebLogin(profile)
                  ? t.accountProfiles.needsVerification
                  : t.accountProfiles.saved,
              style: theme.textTheme.bodySmall?.copyWith(
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
            ),
            trailing: selected
                ? Icon(Icons.check, color: colors.primary)
                : null,
            onTap: _busy != null || _loading || selected
                ? null
                : () =>
                      _run(profile.id, () => _switch(profile), switching: true),
          ),
        ),
      ),
    );
  }
}
