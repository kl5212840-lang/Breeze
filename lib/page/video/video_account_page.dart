import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_account_backup.dart';
import 'package:zephyr/widgets/toast.dart';

class VideoAccountPage extends StatefulWidget {
  const VideoAccountPage({
    super.key,
    required this.service,
    required this.backupCurrent,
    required this.onLogin,
    required this.onCloudSettings,
    this.hasSavedCredentials,
  });
  final VideoAccountService service;
  final Future<void> Function() backupCurrent;
  final VoidCallback onLogin;
  final Future<void> Function() onCloudSettings;

  /// Reads only presence; account names and passwords never enter this page.
  final bool Function()? hasSavedCredentials;
  @override
  State<VideoAccountPage> createState() => _VideoAccountPageState();
}

class _VideoAccountPageState extends State<VideoAccountPage> {
  bool _loading = true, _busy = false, _failed = false, _reading = false;
  VideoAccountBackup? _backup;
  bool _hasSavedCredentials = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    if (_reading) return;
    setState(() => _reading = true);
    try {
      final hasSavedCredentials = widget.hasSavedCredentials?.call() ?? false;
      if (mounted) {
        setState(() => _hasSavedCredentials = hasSavedCredentials);
      }
      final backup = await widget.service.read();
      if (mounted) {
        setState(() {
          _backup = backup;
          _loading = false;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _run(
    String prompt,
    Future<void> Function() action,
    String done,
  ) async {
    if (_busy || _reading) return;
    setState(() => _busy = true);
    try {
      final confirmed = await showAdaptiveDialog<bool>(
        context: context,
        builder: (context) => AlertDialog.adaptive(
          title: Text(t.videoAccount.title),
          scrollable: true,
          content: Text(prompt),
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
      );
      if (!mounted || confirmed != true) return;
      await action();
      if (!mounted) return;
      setState(() => _notice = done);
      showSuccessToast(done);
      await _read();
    } catch (error) {
      if (mounted) {
        final message = error is FormatException
            ? t.videoAccount.loginRequired
            : t.videoAccount.failed;
        setState(() => _notice = message);
        showErrorToast(message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openCloud() async {
    if (_busy || _reading) return;
    setState(() => _busy = true);
    try {
      await widget.onCloudSettings();
      if (mounted) await _read();
    } catch (_) {
      if (mounted) {
        setState(() => _notice = t.videoAccount.failed);
        showErrorToast(t.videoAccount.failed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SettingPageShell(
      title: t.videoAccount.title,
      grouped: true,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                SizedBox(
                  height: 2,
                  child: _busy || _reading
                      ? const LinearProgressIndicator()
                      : null,
                ),
                if (_notice != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Semantics(liveRegion: true, child: Text(_notice!)),
                  ),
                SettingSection(
                  title: t.videoAccount.recoveryDetailsSection,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.account_circle_outlined),
                      title: Text(
                        _hasSavedCredentials
                            ? t.videoAccount.recoveryDetailsSaved
                            : t.videoAccount.recoveryDetailsEmpty,
                      ),
                      subtitle: Text(t.videoAccount.recoveryDetailsHint),
                    ),
                    ListTile(
                      title: Text(t.videoAccount.login),
                      subtitle: Text(t.videoAccount.recoveryLoginHint),
                      leading: const Icon(Icons.open_in_new),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _busy ? null : widget.onLogin,
                    ),
                  ],
                ),
                SettingSection(
                  title: t.videoAccount.recoverySessionSection,
                  footer: t.videoAccount.privacy,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.restore),
                      title: Text(
                        _failed
                            ? t.videoAccount.recoveryReadFailed
                            : _backup != null
                            ? _backup!.name.trim().isNotEmpty
                                  ? _backup!.name
                                  : t.videoAccount.saved
                            : t.videoAccount.empty,
                      ),
                      subtitle: _failed
                          ? null
                          : Text(t.videoAccount.recoverySessionHint),
                      trailing: _failed
                          ? TextButton(
                              onPressed: _busy || _reading ? null : _read,
                              child: Text(t.common.retry),
                            )
                          : null,
                    ),
                    ListTile(
                      title: Text(t.videoAccount.restore),
                      leading: const Icon(Icons.restore),
                      onTap: _busy || _reading || _failed || _backup == null
                          ? null
                          : () => _run(
                              t.videoAccount.restorePrompt,
                              () => widget.service.restore(_backup!),
                              t.videoAccount.restored,
                            ),
                    ),
                    ListTile(
                      title: Text(t.videoAccount.backup),
                      leading: const Icon(Icons.save_outlined),
                      onTap: _busy || _reading
                          ? null
                          : () => _run(
                              t.videoAccount.backupPrompt,
                              widget.backupCurrent,
                              t.videoAccount.backupDone,
                            ),
                    ),
                    ListTile(
                      title: Text(t.videoAccount.forget),
                      leading: const Icon(Icons.delete_outline),
                      onTap: _busy || _reading
                          ? null
                          : () => _run(
                              t.videoAccount.forgetPrompt,
                              widget.service.forget,
                              t.videoAccount.forgotten,
                            ),
                    ),
                  ],
                ),
                SettingSection(
                  title: t.videoAccount.recoveryCloudSection,
                  footer: t.videoAccount.scope,
                  children: [
                    ListTile(
                      title: Text(t.videoAccount.cloud),
                      leading: const Icon(Icons.cloud_sync_outlined),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _busy || _reading ? null : _openCloud,
                    ),
                  ],
                ),
              ],
            ),
    ),
  );
}
