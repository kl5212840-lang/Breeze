import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_diagnostic_preferences.dart';
import 'package:zephyr/widgets/toast.dart';

class SourceDiagnosticToolsTile extends StatefulWidget {
  const SourceDiagnosticToolsTile({super.key, required this.source});

  final String source;

  @override
  State<SourceDiagnosticToolsTile> createState() =>
      _SourceDiagnosticToolsTileState();
}

class _SourceDiagnosticToolsTileState extends State<SourceDiagnosticToolsTile> {
  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;
  int _readEpoch = 0;

  @override
  void initState() {
    super.initState();
    SourceDiagnosticPreferences.changes.addListener(_changed);
    unawaited(_load());
  }

  void _changed() => unawaited(_load());

  Future<void> _load() async {
    final epoch = ++_readEpoch;
    final source = widget.source;
    final enabled = await SourceDiagnosticPreferences.enabled(source);
    if (!mounted || epoch != _readEpoch || source != widget.source) return;
    setState(() {
      _enabled = enabled;
      _loading = false;
    });
  }

  Future<void> _save(bool enabled) async {
    if (_saving || _loading) return;
    final source = widget.source;
    setState(() => _saving = true);
    try {
      await SourceDiagnosticPreferences.setEnabled(source, enabled);
      if (mounted && source == widget.source) {
        await _load();
      }
    } catch (_) {
      if (mounted && source == widget.source) {
        showErrorToast(t.sourceShell.diagnosticToolsSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void didUpdateWidget(covariant SourceDiagnosticToolsTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _enabled = false;
      _loading = true;
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _readEpoch++;
    SourceDiagnosticPreferences.changes.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
    key: ValueKey('source-diagnostic-tools.${widget.source}'),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    secondary: const Icon(Icons.bug_report_outlined),
    title: Text(t.sourceShell.diagnosticTools),
    subtitle: Text(t.sourceShell.diagnosticToolsDescription),
    value: _enabled,
    onChanged: _loading || _saving ? null : _save,
  );
}
