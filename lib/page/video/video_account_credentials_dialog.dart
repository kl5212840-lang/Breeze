import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_account_credentials.dart';

/// The route owns the editors until its exit transition has unmounted them.
Future<bool?> showVideoAccountCredentialsDialog(
  BuildContext context, {
  required VideoAccountCredentials? initial,
  required Future<void> Function(String account, String password) onSave,
  required Future<void> Function() onDelete,
}) => showDialog<bool>(
  context: context,
  useRootNavigator: true,
  builder: (_) =>
      _CredentialsDialog(initial: initial, onSave: onSave, onDelete: onDelete),
);

class _CredentialsDialog extends StatefulWidget {
  const _CredentialsDialog({
    required this.initial,
    required this.onSave,
    required this.onDelete,
  });
  final VideoAccountCredentials? initial;
  final Future<void> Function(String account, String password) onSave;
  final Future<void> Function() onDelete;
  @override
  State<_CredentialsDialog> createState() => _CredentialsDialogState();
}

class _CredentialsDialogState extends State<_CredentialsDialog> {
  late final _account = TextEditingController(
    text: widget.initial?.account ?? '',
  );
  late final _password = TextEditingController(
    text: widget.initial?.password ?? '',
  );
  bool _busy = false, _closing = false, _writing = false;
  String? _error;

  bool get _canAct =>
      mounted &&
      !_busy &&
      !_closing &&
      ModalRoute.of(context)?.isCurrent == true;

  @override
  void dispose() {
    _account.dispose();
    _password.dispose();
    super.dispose();
  }

  void _cancel() {
    if (!_canAct) return;
    _closing = true;
    Navigator.pop(context, false);
  }

  Future<void> _save() async {
    if (!_canAct || _account.text.trim().isEmpty || _password.text.isEmpty) {
      return;
    }
    final account = _account.text.trim(), password = _password.text;
    setState(() {
      _busy = true;
      _writing = true;
      _error = null;
    });
    try {
      await widget.onSave(account, password);
      if (!mounted) return;
      _closing = true;
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _writing = false;
          _error = t.error.saveFailed;
        });
      }
    }
  }

  Future<void> _delete() async {
    if (!_canAct) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        useRootNavigator: true,
        builder: (_) => const _DeleteCredentialsConfirmation(),
      );
      if (!mounted) return;
      if (confirmed != true) {
        setState(() => _busy = false);
        return;
      }
      setState(() => _writing = true);
      await widget.onDelete();
      if (!mounted) return;
      _closing = true;
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _writing = false;
          _error = t.error.saveFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      scrollable: true,
      title: Text(t.videoCommunity.credentials),
      content: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('video-credentials.account'),
              controller: _account,
              enabled: !_busy,
              autofillHints: const [AutofillHints.username],
              decoration: InputDecoration(labelText: t.webdavSync.username),
            ),
            TextField(
              key: const ValueKey('video-credentials.password'),
              controller: _password,
              enabled: !_busy,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(labelText: t.videoCommunity.password),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_writing)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
      actions: [
        if (widget.initial != null)
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            key: const ValueKey('video-credentials.delete'),
            onPressed: _busy ? null : _delete,
            child: Text(t.common.delete),
          ),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
          key: const ValueKey('video-credentials.cancel'),
          onPressed: _busy ? null : _cancel,
          child: Text(t.common.cancel),
        ),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
          key: const ValueKey('video-credentials.save'),
          onPressed: _busy ? null : _save,
          child: Text(t.common.save),
        ),
      ],
    ),
  );
}

class _DeleteCredentialsConfirmation extends StatefulWidget {
  const _DeleteCredentialsConfirmation();
  @override
  State<_DeleteCredentialsConfirmation> createState() =>
      _DeleteCredentialsConfirmationState();
}

class _DeleteCredentialsConfirmationState
    extends State<_DeleteCredentialsConfirmation> {
  bool _closing = false;
  void _finish(bool confirmed) {
    if (_closing || ModalRoute.of(context)?.isCurrent != true) return;
    _closing = true;
    Navigator.pop(context, confirmed);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(t.videoCommunity.deleteSavedLoginTitle),
    content: Text(t.videoCommunity.deleteSavedLoginPrompt),
    actions: [
      TextButton(
        style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
        onPressed: () => _finish(false),
        child: Text(t.common.cancel),
      ),
      TextButton(
        style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
        onPressed: () => _finish(true),
        child: Text(t.common.delete),
      ),
    ],
  );
}
