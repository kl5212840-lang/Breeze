import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/service/sync_connection_transfer.dart';
import 'package:zephyr/widgets/interface_symbol.dart';
import 'package:zephyr/widgets/toast.dart';

class SyncConnectionTransferActions extends StatefulWidget {
  const SyncConnectionTransferActions({
    super.key,
    required this.serviceType,
    required this.readDraft,
    required this.readDraftVersion,
    required this.onImport,
    this.enabled = true,
  });

  final SyncServiceType serviceType;
  final SyncConnectionConfig? Function() readDraft;
  final Object? Function() readDraftVersion;
  final ValueChanged<SyncConnectionConfig> onImport;
  final bool enabled;

  @override
  State<SyncConnectionTransferActions> createState() =>
      _SyncConnectionTransferActionsState();
}

class _SyncConnectionTransferActionsState
    extends State<SyncConnectionTransferActions> {
  bool _busy = false;

  bool _isCurrent(SyncServiceType service) =>
      widget.enabled &&
      widget.serviceType == service &&
      (ModalRoute.isCurrentOf(context) ?? true);

  Future<void> _run(Future<void> Function() action) async {
    if (!widget.enabled || _busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    final service = widget.serviceType;
    final version = widget.readDraftVersion();
    final draft = widget.readDraft();
    if (draft == null || !draft.isComplete) {
      showErrorToast(t.webdavSync.configCodeIncomplete, context: context);
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: Text(t.webdavSync.copyConfigCode),
        content: Text(t.webdavSync.copyConfigCodePrompt),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(t.common.copy),
          ),
        ],
      ),
    );
    if (!mounted || accepted != true || !_isCurrent(service)) return;
    if (widget.readDraftVersion() != version) {
      showErrorToast(t.webdavSync.configChanged, context: context);
      return;
    }
    try {
      await Clipboard.setData(ClipboardData(text: draft.encode()));
      if (mounted && _isCurrent(service)) {
        showSuccessToast(t.webdavSync.configCodeCopied, context: context);
      }
    } on SyncConnectionTransferException {
      if (mounted && _isCurrent(service)) {
        showErrorToast(t.webdavSync.configCodeIncomplete, context: context);
      }
    } catch (_) {
      if (mounted && _isCurrent(service)) {
        showErrorToast(
          t.webdavSync.configCodeClipboardFailed,
          context: context,
        );
      }
    }
  }

  Future<void> _import() async {
    final service = widget.serviceType;
    final version = widget.readDraftVersion();
    ClipboardData? clipboard;
    try {
      clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    } catch (_) {
      if (mounted && _isCurrent(service)) {
        showErrorToast(
          t.webdavSync.configCodeClipboardFailed,
          context: context,
        );
      }
      return;
    }
    if (!mounted || !_isCurrent(service)) return;

    if (widget.readDraftVersion() != version) {
      showErrorToast(t.webdavSync.configChanged, context: context);
      return;
    }
    final SyncConnectionConfig imported;
    try {
      imported = SyncConnectionConfig.decode(
        clipboard?.text ?? '',
        expectedType: service,
      );
    } on SyncConnectionTransferException catch (error) {
      final text = error.issue == SyncConnectionTransferIssue.wrongService
          ? t.webdavSync.configCodeWrongService(service: service.label)
          : t.webdavSync.configCodeInvalid;
      showErrorToast(text, context: context);
      return;
    }
    FocusScope.of(context).unfocus();
    widget.onImport(imported);
    showSuccessToast(t.webdavSync.configCodeImported, context: context);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !_busy;
    final style = TextButton.styleFrom(minimumSize: const Size(44, 44));
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      children: [
        TextButton.icon(
          key: const ValueKey('sync-config.copy'),
          style: style,
          onPressed: enabled ? () => _run(_copy) : null,
          icon: const InterfaceSymbol(
            symbol: 'doc.on.doc',
            fallback: Icons.content_copy_rounded,
            size: 18,
          ),
          label: Text(t.webdavSync.copyConfigCode),
        ),
        TextButton.icon(
          key: const ValueKey('sync-config.import'),
          style: style,
          onPressed: enabled ? () => _run(_import) : null,
          icon: const InterfaceSymbol(
            symbol: 'clipboard',
            fallback: Icons.content_paste_rounded,
            size: 18,
          ),
          label: Text(t.webdavSync.importConfigCode),
        ),
      ],
    );
  }
}
