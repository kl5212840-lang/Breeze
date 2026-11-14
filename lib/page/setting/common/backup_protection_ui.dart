import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:sentry_flutter/sentry_flutter.dart' show SentryMask;
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/sync/backup_protection_manager.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/sync_service.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/video/video_page_route.dart';
import 'package:zephyr/service/backup_security/backup_security.dart';
import 'package:zephyr/util/get_path.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';

/// Keeps platform file picking/exporting injectable while all protection and
/// recovery checks continue through the production manager and crypto core.
class BackupProtectionUiDependencies {
  BackupProtectionUiDependencies({
    BackupProtectionManager? manager,
    Future<String?> Function()? pickRecoveryFile,
    Future<bool> Function(PendingBackupProtection pending)? saveRecoveryFile,
    ComicSyncRemoteAdapter? Function(GlobalSettingState state)? createAdapter,
  }) : manager = manager ?? BackupProtectionManager.shared,
       pickRecoveryFile = pickRecoveryFile ?? _pickRecoveryFile,
       saveRecoveryFile = saveRecoveryFile ?? _saveRecoveryFile,
       createAdapter = createAdapter ?? createSyncArchiveAdapter;

  final BackupProtectionManager manager;
  final Future<String?> Function() pickRecoveryFile;
  final Future<bool> Function(PendingBackupProtection pending) saveRecoveryFile;
  final ComicSyncRemoteAdapter? Function(GlobalSettingState state)
  createAdapter;
}

class BackupProtectionCancelled implements Exception {
  const BackupProtectionCancelled();
}

String backupProtectionError(Object error) {
  final code = error is BackupProtectionException ? error.code : '';
  if (code == 'unlock_failed' ||
      code == 'authentication_failed' ||
      code == 'invalid_recovery_file' ||
      code == 'invalid_recovery_code') {
    return t.backupSecurity.wrongFactor;
  }
  if (code == 'password_length') return t.backupSecurity.passwordRule;
  if (code == 'device_not_authorized' || code == 'device_storage_unavailable') {
    return t.backupSecurity.deviceUnavailable;
  }
  if (code.contains('unsupported') || code == 'invalid_header') {
    return t.backupSecurity.updateRequired;
  }
  if (code == 'backup_locked') return t.backupSecurity.locked;
  if (code == 'cloud_protection_transition_pending' ||
      code == 'disable_confirmation_required') {
    return t.backupSecurity.transitionHint;
  }
  return t.backupSecurity.failed;
}

Future<void> showBackupProtectionSettings(
  BuildContext context, {
  BackupProtectionUiDependencies? dependencies,
}) => Navigator.of(context).push<void>(
  videoPageRoute(
    builder: (_) => BlocProvider.value(
      value: context.read<GlobalSettingCubit>(),
      child: BackupProtectionSettingsPage(dependencies: dependencies),
    ),
    settings: const RouteSettings(name: 'breeze.settings.backup-protection'),
  ),
);

/// Reads only the local protection profile. Cloud inspection remains inside
/// the explicitly opened settings page, and returning refreshes the label.
class BackupProtectionSettingsTile extends StatefulWidget {
  const BackupProtectionSettingsTile({
    super.key,
    this.enabled = true,
    this.dependencies,
  });
  final bool enabled;
  final BackupProtectionUiDependencies? dependencies;

  @override
  State<BackupProtectionSettingsTile> createState() =>
      _BackupProtectionSettingsTileState();
}

class _BackupProtectionSettingsTileState
    extends State<BackupProtectionSettingsTile> {
  late final _dependencies =
      widget.dependencies ?? BackupProtectionUiDependencies();
  BackupProtectionMode? _mode;
  bool _loading = true, _opening = false, _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      await _dependencies.manager.load();
      if (mounted) setState(() => _mode = _dependencies.manager.mode);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open() async {
    if (_opening || _loading || !widget.enabled) return;
    if (_failed) {
      await _load();
      return;
    }
    setState(() => _opening = true);
    try {
      await showBackupProtectionSettings(context, dependencies: _dependencies);
    } finally {
      if (mounted) {
        setState(() => _opening = false);
        await _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) => TouchHoverIntent(
    identity: 'backup-protection.settings-entry',
    builder: (context, hover) => ListTile(
      hoverColor: hover.hoverColor(),
      leading: const Icon(Icons.enhanced_encryption_outlined),
      title: Text(t.backupSecurity.title),
      subtitle: Text(
        _loading
            ? t.backupSecurity.working
            : _failed
            ? t.backupSecurity.readFailed
            : _mode == BackupProtectionMode.passwordProtected
            ? t.backupSecurity.protected
            : t.backupSecurity.standard,
      ),
      trailing: const Icon(Icons.chevron_right),
      enabled: widget.enabled,
      onTap: widget.enabled && !_loading && !_opening ? _open : null,
    ),
  );
}

/// Null means the user selected standard exports; cancellation can never
/// accidentally turn a protected export into a plaintext file.
Future<BackupProtectionSession?> resolveFileBackupProtection(
  BuildContext context, {
  BackupProtectionUiDependencies? dependencies,
}) async {
  final services = dependencies ?? BackupProtectionUiDependencies();
  final manager = services.manager;
  await manager.load();
  if (manager.mode == BackupProtectionMode.standard) return null;
  if (manager.session != null) return manager.session;
  try {
    await manager.unlock(useTrustedDevice: true);
    return manager.session;
  } on BackupProtectionException {
    /* Ask for another factor below. */
  }
  if (!context.mounted ||
      !await unlockCloudBackupProtection(context, dependencies: services)) {
    throw const BackupProtectionCancelled();
  }
  return manager.session;
}

Future<bool> unlockCloudBackupProtection(
  BuildContext context, {
  BackupProtectionUiDependencies? dependencies,
}) async {
  final services = dependencies ?? BackupProtectionUiDependencies();
  final manager = services.manager;
  await manager.load();
  final profile = manager.profile;
  if (profile == null || !context.mounted) return false;
  final session = await _unlock(
    context,
    profile,
    persist: true,
    dependencies: services,
  );
  return session != null;
}

/// Legacy protected archives are resolved from the operation that needs them.
Future<T?> retryWithLegacyBackupAccess<T>(
  BuildContext context,
  Future<T> Function() operation, {
  BackupProtectionUiDependencies? dependencies,
}) async {
  final handled = <String>{};
  while (context.mounted) {
    try {
      return await operation();
    } on BackupProtectionException catch (error) {
      if (!handled.add(error.code)) rethrow;
      if (error.code == 'backup_locked') {
        if (!context.mounted ||
            !await unlockCloudBackupProtection(
              context,
              dependencies: dependencies,
            )) {
          return null;
        }
      } else if (error.code == 'cloud_protection_transition_pending') {
        if (!context.mounted ||
            !await _continueLegacyCloudProtection(context, dependencies)) {
          return null;
        }
      } else {
        rethrow;
      }
    }
  }
  return null;
}

Future<bool> _continueLegacyCloudProtection(
  BuildContext context,
  BackupProtectionUiDependencies? dependencies,
) async {
  final services = dependencies ?? BackupProtectionUiDependencies();
  final adapter = services.createAdapter(
    context.read<GlobalSettingCubit>().state,
  );
  if (adapter == null) {
    throw const BackupProtectionException(
      'cloud_protection_transition_pending',
    );
  }
  final status = await services.manager.inspectCloud(adapter);
  if (!context.mounted) return false;
  if (!status.transitionPending && !status.cleanupPending) return true;
  final disable = status.transitionOperation == 'disable';
  final confirmed = await _confirm(
    context,
    disable ? t.backupSecurity.disableTitle : t.backupSecurity.resume,
    disable ? t.backupSecurity.disableHint : t.backupSecurity.transitionHint,
  );
  if (!confirmed || !context.mounted) return false;
  final needsFactor =
      status.transitionOperation != 'preparing' && !status.cleanupPending;
  if (needsFactor &&
      !services.manager.isUnlocked &&
      !await unlockCloudBackupProtection(context, dependencies: services)) {
    return false;
  }
  if (!context.mounted) return false;
  await services.manager.resumeCloudTransition(
    adapter,
    approveDisable: disable,
  );
  return true;
}

/// An imported file may belong to a different backup. Never replace the active
/// cloud profile while unlocking it; the caller owns/disposes this session.
Future<BackupProtectionSession?> unlockFileBackupProtection(
  BuildContext context,
  BackupProtectionProfile profile, {
  BackupProtectionUiDependencies? dependencies,
}) => _unlock(
  context,
  profile,
  persist: false,
  dependencies: dependencies ?? BackupProtectionUiDependencies(),
);

Future<BackupProtectionSession?> _unlock(
  BuildContext context,
  BackupProtectionProfile profile, {
  required bool persist,
  required BackupProtectionUiDependencies dependencies,
}) async {
  final manager = dependencies.manager;
  try {
    return persist
        ? await manager.unlock(profile: profile, useTrustedDevice: true)
        : await manager.service.unlockProfile(profile, useTrustedDevice: true);
  } on BackupProtectionException {
    /* Manual recovery remains available. */
  }
  if (!context.mounted) return null;
  return Navigator.of(context).push<BackupProtectionSession>(
    videoPageRoute(
      builder: (_) => SentryMask(
        _UnlockBackupPage(
          profile: profile,
          persist: persist,
          dependencies: dependencies,
        ),
      ),
      settings: const RouteSettings(name: 'breeze.settings.backup-unlock'),
    ),
  );
}

class BackupProtectionSettingsPage extends StatefulWidget {
  const BackupProtectionSettingsPage({super.key, this.dependencies});
  final BackupProtectionUiDependencies? dependencies;
  @override
  State<BackupProtectionSettingsPage> createState() =>
      _BackupProtectionSettingsPageState();
}

class _BackupProtectionSettingsPageState
    extends State<BackupProtectionSettingsPage> {
  late final _dependencies =
      widget.dependencies ?? BackupProtectionUiDependencies();
  BackupProtectionManager get _manager => _dependencies.manager;
  CloudBackupProtectionStatus? _cloud;
  bool _cloudConfigured = false, _modeLoaded = false;
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _perform(_refresh);
  }

  Future<void> _refresh() async {
    await _manager.load();
    if (!mounted) return;
    _modeLoaded = true;
    final adapter = _dependencies.createAdapter(
      context.read<GlobalSettingCubit>().state,
    );
    _cloudConfigured = adapter != null;
    _cloud = adapter == null ? null : await _manager.inspectCloud(adapter);
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (mounted) {
      setState(() {
        _busy = true;
        _error = null;
      });
    }
    try {
      await action();
    } on BackupProtectionCancelled {
      /* No mutation after cancellation. */
    } catch (error) {
      if (mounted) _error = backupProtectionError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final protected = _manager.mode == BackupProtectionMode.passwordProtected;
    final cloudProtected =
        _cloud?.mode == BackupProtectionMode.passwordProtected;
    Widget row(
      String id,
      IconData icon,
      String title,
      VoidCallback onTap, {
      String? value,
    }) => TouchHoverIntent(
      identity: id,
      builder: (context, hover) => ListTile(
        hoverColor: hover.hoverColor(),
        leading: Icon(icon),
        title: Text(title),
        trailing: value == null ? const Icon(Icons.chevron_right) : Text(value),
        onTap: _busy ? null : onTap,
      ),
    );
    return PopScope(
      canPop: !_busy,
      child: SettingPageShell(
        grouped: true,
        title: t.backupSecurity.title,
        child: ListView(
          children: [
            if (_busy)
              const LinearProgressIndicator(key: ValueKey('protection.busy')),
            SettingNote.section(
              t.backupSecurity.scopeHint,
              key: const ValueKey('protection.scope'),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            ),
            SettingSection(
              title: t.backupSecurity.mode,
              footer: _modeLoaded && !protected
                  ? t.backupSecurity.standardHint
                  : null,
              children: [
                SettingChoiceTile<bool>(
                  key: const ValueKey('protection.mode'),
                  leading: const Icon(Icons.enhanced_encryption_outlined),
                  title: t.backupSecurity.mode,
                  value: protected,
                  enabled: !_busy && _modeLoaded,
                  displayValue: _modeLoaded
                      ? null
                      : _busy
                      ? t.backupSecurity.working
                      : t.backupSecurity.readFailed,
                  items: {
                    false: t.backupSecurity.standard,
                    true: t.backupSecurity.protected,
                  },
                  onChanged: (value) {
                    if (value != protected) {
                      _perform(value ? _enable : _disable);
                    }
                  },
                ),
              ],
            ),
            if (!_busy && !_cloudConfigured && _error == null)
              SettingNote.section(
                t.backupSecurity.cloudNotConfigured,
                key: const ValueKey('protection.cloud-unconfigured'),
              ),
            if (_cloud != null)
              SettingSection(
                title: t.settings.sync,
                children: [
                  ListTile(
                    leading: const Icon(Icons.cloud_outlined),
                    title: Text(t.backupSecurity.cloudStatus),
                    trailing: FlexibleTextLabel(
                      _cloud!.transitionPending
                          ? t.backupSecurity.pending
                          : cloudProtected
                          ? t.backupSecurity.protected
                          : t.backupSecurity.standard,
                    ),
                  ),
                  if (_cloud!.transitionPending || _cloud!.cleanupPending)
                    row(
                      'protection.resume',
                      Icons.sync,
                      t.backupSecurity.resume,
                      () => _perform(_resume),
                    ),
                  if (protected &&
                      !cloudProtected &&
                      !_cloud!.transitionPending)
                    row(
                      'protection.enableCloud',
                      Icons.lock_outline,
                      t.backupSecurity.enableCloud,
                      () => _perform(_protectCloud),
                    ),
                ],
              ),
            if (protected)
              SettingSection(
                title: t.backupSecurity.recovery,
                footer: t.backupSecurity.recoveryHint,
                children: [
                  row(
                    'protection.unlock',
                    Icons.lock_open,
                    _manager.isUnlocked
                        ? t.backupSecurity.lock
                        : t.backupSecurity.unlock,
                    () => _perform(() async {
                      if (_manager.isUnlocked) {
                        _manager.lock();
                      } else {
                        await unlockCloudBackupProtection(
                          context,
                          dependencies: _dependencies,
                        );
                      }
                    }),
                  ),
                  row(
                    'protection.password',
                    Icons.password,
                    t.backupSecurity.changePassword,
                    () => _perform(_changePassword),
                  ),
                  row(
                    'protection.forget',
                    Icons.phonelink_erase,
                    t.backupSecurity.forgetDevice,
                    () => _perform(_forgetDevice),
                  ),
                ],
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  key: const ValueKey('protection.error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _enable() async {
    final password = await _password(context);
    if (password == null || !mounted) return;
    final pending = await _manager.create(password);
    try {
      if (!mounted) return;
      final confirmed = await Navigator.of(context).push<bool>(
        videoPageRoute(
          builder: (_) => SentryMask(
            _SaveRecoveryPage(pending: pending, dependencies: _dependencies),
          ),
          settings: const RouteSettings(
            name: 'breeze.settings.backup-recovery',
          ),
        ),
      );
      if (confirmed != true || !mounted) return;
      await _protectCloud();
    } finally {
      pending.dispose();
    }
  }

  Future<void> _protectCloud() async {
    if (!_manager.isUnlocked &&
        !await unlockCloudBackupProtection(
          context,
          dependencies: _dependencies,
        )) {
      return;
    }
    if (!mounted) return;
    final adapter = _dependencies.createAdapter(
      context.read<GlobalSettingCubit>().state,
    );
    if (adapter != null) {
      await _manager.enableCloud(adapter);
      await _refresh();
    }
  }

  Future<void> _disable() async {
    if (!await _confirm(
      context,
      t.backupSecurity.disableTitle,
      t.backupSecurity.disableHint,
    )) {
      return;
    }
    if (!mounted ||
        (!_manager.isUnlocked &&
            !await unlockCloudBackupProtection(
              context,
              dependencies: _dependencies,
            ))) {
      return;
    }
    if (!mounted) return;
    final adapter = _dependencies.createAdapter(
      context.read<GlobalSettingCubit>().state,
    );
    if (adapter != null &&
        _cloud?.mode == BackupProtectionMode.passwordProtected) {
      await _manager.disableCloud(adapter);
    }
    await _manager.useStandardFileBackups();
    if (mounted) await _refresh();
  }

  Future<void> _resume() async {
    final disable = _cloud?.transitionOperation == 'disable';
    final needsFactor =
        _cloud?.transitionOperation != 'preparing' &&
        _cloud?.cleanupPending != true;
    if (disable &&
        !await _confirm(
          context,
          t.backupSecurity.disableTitle,
          t.backupSecurity.disableHint,
        )) {
      return;
    }
    if (!mounted ||
        (needsFactor &&
            !_manager.isUnlocked &&
            !await unlockCloudBackupProtection(
              context,
              dependencies: _dependencies,
            ))) {
      return;
    }
    if (!mounted) return;
    final adapter = _dependencies.createAdapter(
      context.read<GlobalSettingCubit>().state,
    );
    if (adapter != null) {
      await _manager.resumeCloudTransition(adapter, approveDisable: disable);
      await _refresh();
    }
  }

  Future<void> _changePassword() async {
    if (!_manager.isUnlocked &&
        !await unlockCloudBackupProtection(
          context,
          dependencies: _dependencies,
        )) {
      return;
    }
    if (!mounted) return;
    final password = await _password(context);
    if (password == null || !mounted) return;
    final adapter = _dependencies.createAdapter(
      context.read<GlobalSettingCubit>().state,
    );
    if (adapter != null &&
        _cloud?.mode == BackupProtectionMode.passwordProtected) {
      await _manager.changeCloudPassword(adapter, password);
      await _refresh();
    } else {
      await _manager.changeLocalPassword(password);
    }
    if (mounted) showSuccessToast(t.backupSecurity.passwordChanged);
  }

  Future<void> _forgetDevice() async {
    if (!await _confirm(
      context,
      t.backupSecurity.forgetDevice,
      t.backupSecurity.forgetHint,
    )) {
      return;
    }
    final profile = _manager.profile;
    if (profile == null) return;
    await _manager.service.deviceKeys.deleteKey(profile.archiveId);
    _manager.lock();
  }
}

/// Bound trailing values independently of platform font metrics and long locales.
class FlexibleTextLabel extends StatelessWidget {
  const FlexibleTextLabel(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxWidth: MediaQuery.sizeOf(context).width * .42,
    ),
    child: Text(
      label,
      maxLines: 2,
      textAlign: TextAlign.end,
      style: Theme.of(context).textTheme.bodyMedium,
    ),
  );
}

Future<bool> _confirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        constraints: const BoxConstraints(maxWidth: 520),
        scrollable: true,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.common.confirm),
          ),
        ],
      ),
    ) ??
    false;

Future<String?> _password(BuildContext context) =>
    Navigator.of(context).push<String>(
      videoPageRoute(
        builder: (_) => const SentryMask(_PasswordPage()),
        settings: const RouteSettings(name: 'breeze.settings.backup-password'),
      ),
    );

class _PasswordPage extends StatefulWidget {
  const _PasswordPage();
  @override
  State<_PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<_PasswordPage> {
  final _password = TextEditingController(), _repeat = TextEditingController();
  String? _error;
  bool _submitted = false;
  @override
  void dispose() {
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SettingPageShell(
    title: t.backupSecurity.setPassword,
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(t.backupSecurity.passwordRule),
        const SizedBox(height: 20),
        TextField(
          key: const ValueKey('protection.password'),
          controller: _password,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          maxLength: 256,
          decoration: InputDecoration(labelText: t.backupSecurity.password),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('protection.passwordRepeat'),
          controller: _repeat,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: t.backupSecurity.repeatPassword,
          ),
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 24),
        FilledButton(
          key: const ValueKey('protection.passwordConfirm'),
          onPressed: _submit,
          child: Text(t.common.confirm),
        ),
      ],
    ),
  );
  void _submit() {
    if (_submitted) return;
    final valid = _password.text.runes.length >= 10;
    if (!valid || _password.text != _repeat.text) {
      setState(
        () => _error = valid
            ? t.backupSecurity.passwordMismatch
            : t.backupSecurity.passwordRule,
      );
      return;
    }
    _submitted = true;
    Navigator.pop(context, _password.text);
  }
}

class _UnlockBackupPage extends StatefulWidget {
  const _UnlockBackupPage({
    required this.profile,
    required this.persist,
    required this.dependencies,
  });
  final BackupProtectionUiDependencies dependencies;
  final BackupProtectionProfile profile;
  final bool persist;
  @override
  State<_UnlockBackupPage> createState() => _UnlockBackupPageState();
}

class _UnlockBackupPageState extends State<_UnlockBackupPage> {
  final _value = TextEditingController();
  bool _recovery = false,
      _busy = false,
      _trust = false,
      _supportsDevice = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    widget.dependencies.manager.service.deviceKeys.isSupported().then((value) {
      if (mounted) {
        setState(() {
          _supportsDevice = value;
          _trust = value;
        });
      }
    });
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SettingPageShell(
      title: t.backupSecurity.unlock,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(t.backupSecurity.unlockHint),
          const SizedBox(height: 20),
          SettingChoiceTile<bool>(
            key: const ValueKey('protection.unlockMethod'),
            title: t.backupSecurity.unlockWith,
            value: _recovery,
            enabled: !_busy,
            items: {
              false: t.backupSecurity.password,
              true: t.backupSecurity.recoveryCode,
            },
            onChanged: (value) => setState(() {
              _recovery = value;
              _value.clear();
              _error = null;
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('protection.unlockValue'),
            controller: _value,
            obscureText: !_recovery,
            enableSuggestions: false,
            autocorrect: false,
            enabled: !_busy,
            maxLines: _recovery ? 4 : 1,
            maxLength: _recovery ? 256 : 256,
            decoration: InputDecoration(
              labelText: _recovery
                  ? t.backupSecurity.recoveryCode
                  : t.backupSecurity.password,
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_supportsDevice && widget.persist)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _trust,
              title: Text(t.backupSecurity.trustDevice),
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _trust = value ?? false),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('protection.unlockConfirm'),
            onPressed: _busy ? null : () => _submit(),
            child: Text(
              _busy ? t.backupSecurity.working : t.backupSecurity.unlock,
            ),
          ),
          TextButton(
            key: const ValueKey('protection.openRecovery'),
            onPressed: _busy ? null : _openRecoveryFile,
            child: Text(t.backupSecurity.useRecoveryFile),
          ),
        ],
      ),
    ),
  );
  Future<void> _openRecoveryFile() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    String? contents;
    try {
      contents = await widget.dependencies.pickRecoveryFile();
    } catch (error) {
      if (mounted) setState(() => _error = backupProtectionError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (contents != null && mounted) await _submit(file: contents);
  }

  Future<void> _submit({String? file}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    BackupProtectionSession? session;
    try {
      final manager = widget.dependencies.manager;
      if (widget.persist) {
        session = await manager.unlock(
          profile: widget.profile,
          password: file == null && !_recovery ? _value.text : null,
          recoveryCode: file == null && _recovery ? _value.text : null,
          recoveryFile: file,
          trustDevice: _trust,
        );
      } else {
        session = await manager.service.unlockProfile(
          widget.profile,
          password: file == null && !_recovery ? _value.text : null,
          recoveryCode: file == null && _recovery ? _value.text : null,
          recoveryFile: file,
        );
      }
      if (mounted) {
        Navigator.pop(context, session);
      } else if (!widget.persist) {
        session.dispose();
      }
    } catch (error) {
      if (mounted) setState(() => _error = backupProtectionError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _SaveRecoveryPage extends StatefulWidget {
  const _SaveRecoveryPage({required this.pending, required this.dependencies});
  final BackupProtectionUiDependencies dependencies;
  final PendingBackupProtection pending;
  @override
  State<_SaveRecoveryPage> createState() => _SaveRecoveryPageState();
}

class _SaveRecoveryPageState extends State<_SaveRecoveryPage> {
  final _confirmCode = TextEditingController();
  bool _verify = false, _busy = false, _trust = false, _supportsDevice = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    widget.dependencies.manager.service.deviceKeys.isSupported().then((v) {
      if (mounted) {
        setState(() {
          _supportsDevice = v;
          _trust = v;
        });
      }
    });
  }

  @override
  void dispose() {
    _confirmCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SettingPageShell(
      title: t.backupSecurity.recovery,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(t.backupSecurity.recoveryHint),
          const SizedBox(height: 20),
          if (!_verify) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                widget.pending.recoveryCode,
                key: const ValueKey('protection.recoveryCode'),
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontFamily: 'monospace'),
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(text: widget.pending.recoveryCode),
                          );
                          if (mounted) {
                            showSuccessToast(t.backupSecurity.copied);
                          }
                        },
                  icon: const Icon(Icons.copy),
                  label: Text(t.backupSecurity.copyCode),
                ),
                TextButton.icon(
                  key: const ValueKey('protection.saveRecovery'),
                  onPressed: _busy ? null : _save,
                  icon: const Icon(Icons.save_alt),
                  label: Text(t.backupSecurity.saveRecoveryFile),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('protection.savedContinue'),
              onPressed: _busy ? null : () => setState(() => _verify = true),
              child: Text(t.backupSecurity.savedContinue),
            ),
          ] else ...[
            TextField(
              key: const ValueKey('protection.verifyRecovery'),
              controller: _confirmCode,
              minLines: 3,
              maxLines: 5,
              autocorrect: false,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: t.backupSecurity.verifyCode,
              ),
            ),
            if (_supportsDevice)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _trust,
                title: Text(t.backupSecurity.trustDevice),
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _trust = v ?? false),
              ),
            const SizedBox(height: 20),
            FilledButton(
              key: const ValueKey('protection.verifyConfirm'),
              onPressed: _busy ? null : _confirmSaved,
              child: Text(_busy ? t.backupSecurity.working : t.common.confirm),
            ),
            TextButton(
              onPressed: _busy ? null : () => setState(() => _verify = false),
              child: Text(t.backupSecurity.showCode),
            ),
          ],
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
  );
  Future<void> _confirmSaved() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.dependencies.manager.confirmSetup(
        widget.pending,
        _confirmCode.text,
        trustDevice: _trust,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = backupProtectionError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.dependencies.saveRecoveryFile(widget.pending);
    } on BackupProtectionCancelled {
      // Returning from the platform picker leaves setup pending.
    } catch (_) {
      if (mounted) setState(() => _error = t.backupSecurity.saveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

Future<String?> _pickRecoveryFile() async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'Breeze recovery',
        extensions: ['breezerecovery', 'json'],
        uniformTypeIdentifiers: ['public.data'],
      ),
    ],
  );
  if (file == null) return null;
  if (await file.length() > 4096) {
    throw const BackupProtectionException('invalid_recovery_file');
  }
  return file.readAsString();
}

Future<bool> _saveRecoveryFile(PendingBackupProtection pending) async {
  if (Platform.isIOS || Platform.isAndroid) {
    final directory = await Directory(
      p.join(await getCachePath(), 'recovery-export'),
    ).create(recursive: true);
    final file = File(
      p.join(
        directory.path,
        'Breeze-${DateTime.now().microsecondsSinceEpoch}.breezerecovery',
      ),
    );
    try {
      await file.writeAsString(pending.recoveryFile, flush: true);
      final result = await const MethodChannel(
        'breeze/backup_security',
      ).invokeMethod<String>('exportFile', {'path': file.path});
      if (result == 'saved') return true;
      if (result == 'cancelled') return false;
      throw const BackupProtectionException('recovery_export_failed');
    } finally {
      if (await file.exists()) await file.delete();
    }
  }
  final location = await getSaveLocation(
    suggestedName: 'Breeze.breezerecovery',
  );
  if (location == null) return false;
  await File(location.path).writeAsString(pending.recoveryFile, flush: true);
  return true;
}
