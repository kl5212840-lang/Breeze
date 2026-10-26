import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_account_backup.dart';

class VideoAccountPage extends StatefulWidget {
  const VideoAccountPage({
    super.key,
    required this.service,
    required this.backupCurrent,
    required this.onLogin,
    required this.onCloudSettings,
  });
  final VideoAccountService service;
  final Future<void> Function() backupCurrent;
  final VoidCallback onLogin;
  final Future<void> Function() onCloudSettings;
  @override
  State<VideoAccountPage> createState() => _VideoAccountPageState();
}

class _VideoAccountPageState extends State<VideoAccountPage> {
  bool _loading = true, _busy = false, _failed = false;
  VideoAccountBackup? _backup;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    try {
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
    }
  }

  Future<void> _run(
    String prompt,
    Future<void> Function() action,
    String done,
  ) async {
    if (_busy) return;
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
      await _read();
    } catch (error) {
      if (mounted) {
        setState(
          () => _notice = error is FormatException
              ? t.videoAccount.loginRequired
              : t.videoAccount.failed,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openCloud() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onCloudSettings();
      if (mounted) await _read();
    } catch (_) {
      if (mounted) setState(() => _notice = t.videoAccount.failed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        leading: const SourceBackButton(),
        title: Text(t.videoAccount.title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                SizedBox(
                  height: 2,
                  child: _busy ? const LinearProgressIndicator() : null,
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(t.videoAccount.scope),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(t.videoAccount.privacy),
                ),
                if (_failed)
                  ListTile(
                    title: Text(t.videoAccount.failed),
                    trailing: TextButton(
                      onPressed: _busy ? null : _read,
                      child: Text(t.common.retry),
                    ),
                  ),
                ListTile(
                  leading: const Icon(Icons.account_circle_outlined),
                  title: Text(
                    _backup?.name.isNotEmpty == true
                        ? _backup!.name
                        : _backup != null
                        ? t.videoAccount.saved
                        : t.videoAccount.empty,
                  ),
                ),
                if (_notice != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_notice!, semanticsLabel: _notice),
                  ),
                ListTile(
                  title: Text(t.videoAccount.login),
                  leading: const Icon(Icons.open_in_new),
                  onTap: _busy ? null : widget.onLogin,
                ),
                ListTile(
                  title: Text(t.videoAccount.backup),
                  leading: const Icon(Icons.save_outlined),
                  onTap: _busy
                      ? null
                      : () => _run(
                          t.videoAccount.backupPrompt,
                          widget.backupCurrent,
                          t.videoAccount.backupDone,
                        ),
                ),
                ListTile(
                  title: Text(t.videoAccount.restore),
                  leading: const Icon(Icons.restore),
                  onTap: _busy || _backup == null
                      ? null
                      : () => _run(
                          t.videoAccount.restorePrompt,
                          () => widget.service.restore(_backup!),
                          t.videoAccount.restored,
                        ),
                ),
                ListTile(
                  title: Text(t.videoAccount.forget),
                  leading: const Icon(Icons.delete_outline),
                  onTap: _busy
                      ? null
                      : () => _run(
                          t.videoAccount.forgetPrompt,
                          widget.service.forget,
                          t.videoAccount.forgotten,
                        ),
                ),
                const Divider(),
                ListTile(
                  title: Text(t.videoAccount.cloud),
                  leading: const Icon(Icons.cloud_sync_outlined),
                  onTap: _busy ? null : _openCloud,
                ),
              ],
            ),
    ),
  );
}
