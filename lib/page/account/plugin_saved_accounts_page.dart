import 'dart:async';
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/donwload_task/view/download_swipe_actions.dart';
import 'package:zephyr/network/http/plugin/qjs_network_route.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';
import 'package:zephyr/page/video/video_page_route.dart';
import 'package:zephyr/service/plugin_account_authentication.dart';
import 'package:zephyr/service/plugin_account_profiles.dart';
import 'package:zephyr/service/plugin_account_sync_coordinator.dart';
import 'package:zephyr/widgets/native_view_occlusion.dart';
import 'package:zephyr/widgets/plugin_icon.dart';
import 'package:zephyr/widgets/work_list_divider.dart';

const pluginSavedAccountsRouteName = 'breeze.source.saved-accounts';

/// true means the existing source browser must be revealed for sign-in.
Future<bool> openPluginSavedAccounts(
  BuildContext context, {
  required String source,
  required Future<void> Function() onAddAccount,
  Future<void> Function()? prepareSession,
}) async {
  final route = videoPageRoute<bool>(
    settings: const RouteSettings(name: pluginSavedAccountsRouteName),
    builder: (_) => PluginSavedAccountsPage(
      source: source,
      onAddAccount: onAddAccount,
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
    this.prepareSession,
    this.authentication,
  });
  final String source;
  final Future<void> Function() onAddAccount;

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
  String? _selected, _busy, _error, _unverified, _copyLoginRequired;
  Future<void> Function()? _retry;
  bool get _isCopy => widget.source == PluginAccountAuthenticationService.copy;
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
          : rows
                .where(
                  (p) =>
                      p.serverIdentity == proof.serverIdentity &&
                      (p.kind != 'web' ||
                          proof.origin.isEmpty ||
                          p.origin == proof.origin),
                )
                .toList();
      setState(() {
        _profiles = rows;
        if (proof == null) _unverified = _selected ?? _unverified;
        _selected = matching.length == 1 ? matching.single.id : null;
        if (proof != null) {
          _unverified = null;
          if (_copyLoginRequired == _selected) _copyLoginRequired = null;
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
        _copyLoginRequired = null;
      });
    try {
      // Read compatibility data without replacing it. A fresh, explicit adapter
      // can label the live account; cached summaries never select an account.
      PluginAccountProfiles.read(widget.source);
      if (verifyApi) await widget.prepareSession?.call();
      if (!mounted || epoch != _epoch) return;
      final auth = _authentication;
      var proof = PluginAccountIdentities.current(widget.source);
      final generation = pluginSessionWriteFence.generation(widget.source);
      var loginRequired = false;
      if (auth.hasApiVerification && verifyApi) {
        try {
          final confirmedProof = proof ?? await auth.verify();
          proof = confirmedProof;
          if (!mounted || epoch != _epoch) return;
          await PluginAccountProfiles.rememberCurrent(
            widget.source,
            label: confirmedProof.label,
            serverIdentity: confirmedProof.serverIdentity,
            avatarUrl: confirmedProof.avatarUrl,
            select: true,
          );
          PluginAccountIdentities.confirm(
            widget.source,
            confirmedProof,
            generation: generation,
          );
        } catch (error) {
          loginRequired = _isCopy && _copyNeedsLogin(error);
          proof = PluginAccountIdentities.current(widget.source);
          await PluginAccountProfiles.rememberCurrent(widget.source);
        }
      } else if (!auth.hasApiVerification &&
          PluginAccountSyncCoordinator.instance.hasProfileAccess(
            widget.source,
          )) {
        final coordinator = PluginAccountSyncCoordinator.instance;
        try {
          proof ??= await coordinator.refreshCurrentIdentity(widget.source);
        } catch (_) {}
        try {
          await coordinator.captureAuthenticated(widget.source);
        } catch (_) {
          /* Backup does not undo identity. */
        }
        proof = PluginAccountIdentities.current(widget.source);
      } else if (!auth.hasApiVerification) {
        await PluginAccountProfiles.rememberCurrent(widget.source);
      }
      final data = PluginAccountProfiles.read(widget.source);
      final selected = await PluginAccountProfiles.selected(widget.source);
      final confirmed =
          proof != null &&
          pluginSessionWriteFence.generation(widget.source) == generation;
      final matches = confirmed
          ? data.profiles.values
                .where(
                  (p) =>
                      !p.deleted &&
                      p.serverIdentity == proof!.serverIdentity &&
                      (p.kind != 'web' ||
                          proof.origin.isEmpty ||
                          p.origin == proof.origin),
                )
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
            (profile) =>
                profile.deleted &&
                profile.serverIdentity == proof!.serverIdentity,
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
        _copyLoginRequired = loginRequired && !confirmed ? selected : null;
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

  bool _copyNeedsLogin(Object error) =>
      error is PluginAccountNeedsLogin ||
      error is PluginLoginRequiredException &&
          error.payload.pluginId == widget.source;

  Future<void> _run(
    String id,
    Future<void> Function() action, {
    bool switching = false,
  }) async {
    if (_busy != null) return;
    _openSwipe.value = null;
    setState(() {
      _busy = id;
      _error = null;
    });
    try {
      await action();
      if (mounted) await _load();
    } catch (error) {
      if (mounted) {
        final copySwitch = _isCopy && switching;
        await _load(verifyApi: !copySwitch);
        if (mounted) {
          setState(() {
            if (copySwitch) _retry = () => _run(id, action, switching: true);
            if (copySwitch && _copyNeedsLogin(error)) {
              _copyLoginRequired = id;
              _error = t.navigation.needLoginTitle;
            } else if (copySwitch && isTransientNetworkError(error)) {
              _error = t.login.networkUnavailable;
            } else {
              _error = copySwitch
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

  Future<void> _switch(PluginAccountProfile profile) async {
    try {
      await _authentication.switchTo(profile.id);
    } catch (error) {
      if (error is! PluginAccountNeedsLogin &&
          error is! PluginAccountAuthenticationRejected)
        rethrow;
      if (_authentication.hasApiVerification || !mounted) rethrow;
      final epoch = _epoch;
      await _authentication.switchToWithLogin(
        profile.id,
        canContinue: () => mounted && _epoch == epoch,
        login: () async {
          try {
            await widget.onAddAccount();
          } finally {
            if (mounted && _epoch == epoch) await widget.prepareSession?.call();
          }
          if (!mounted || _epoch != epoch) throw const PluginSessionChanged();
        },
      );
    }
  }

  Future<void> _add() async {
    final coordinator = PluginAccountSyncCoordinator.instance;
    if (coordinator.hasProfileLogin(widget.source)) {
      Navigator.of(context).pop(true);
      return;
    }
    await _run('add', widget.onAddAccount);
  }

  Future<void> _remove(PluginAccountProfile profile) async {
    if (_busy != null || _confirmingRemoval) return;
    final source = canonicalQjsSource(widget.source);
    final generation = pluginSessionWriteFence.generation(source);
    final current = PluginAccountProfiles.isCurrent(source, profile.id);
    final colors = Theme.of(context).colorScheme;
    _confirmingRemoval = true;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t.accountProfiles.removeTitle),
          scrollable: true,
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
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t.common.cancel),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: colors.error),
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
                      TextButton(
                        key: const ValueKey('saved-account-retry'),
                        onPressed: _busy == null ? _retry ?? _load : null,
                        child: Text(t.common.retry),
                      ),
                      if (_retry == null || _copyLoginRequired != null)
                        TextButton(
                          onPressed: _busy == null ? _add : null,
                          child: Text(t.accountProfiles.continueLogin),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          if (_busy != null)
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
    return WorkListRow(
      divided: !selected,
      startInset: 68,
      inset: 12,
      child: DownloadSwipeActions(
        rowKey: 'saved-account-${profile.id}',
        openRow: _openSwipe,
        exposeActions: true,
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
            leading: ClipOval(
              child: SizedBox.square(
                dimension: 40,
                child: PluginIcon(
                  url: profile.avatarUrl,
                  placeholder: CircleAvatar(
                    child: Text(label.isEmpty ? '?' : label.characters.first),
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
                  : profile.id == _copyLoginRequired
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
