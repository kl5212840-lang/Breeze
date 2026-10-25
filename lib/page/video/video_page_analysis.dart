import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';

class VideoPageAnalysisResult {
  const VideoPageAnalysisResult({
    required this.mode,
    required this.page,
    required this.status,
    required this.report,
  });
  final String mode, page, status, report;
}

/// Opened only by an explicit user action. Analysis reads a bounded metadata
/// snapshot; copying is a separate action and never reruns the analysis.
class VideoPageAnalysis extends StatefulWidget {
  const VideoPageAnalysis({
    super.key,
    required this.analyze,
    required this.onCopy,
  });
  final Future<VideoPageAnalysisResult> Function() analyze;
  final Future<void> Function(String) onCopy;
  @override
  State<VideoPageAnalysis> createState() => _VideoPageAnalysisState();
}

class _VideoPageAnalysisState extends State<VideoPageAnalysis> {
  VideoPageAnalysisResult? _result;
  bool _busy = true,
      _failed = false,
      _copying = false,
      _copied = false,
      _copyFailed = false;
  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    setState(() {
      _busy = true;
      _failed = false;
      _result = null;
      _copied = false;
      _copyFailed = false;
    });
    try {
      final result = await widget.analyze();
      if (mounted) setState(() => _result = result);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    final result = _result;
    if (result == null || _copying) return;
    setState(() {
      _copying = true;
      _copyFailed = false;
    });
    try {
      await widget.onCopy(result.report);
      if (mounted) setState(() => _copied = true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _copyFailed = true;
          _copied = false;
        });
      }
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  Widget _row(String title, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                t.videoPlayback.pageAnalysis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: t.common.close,
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_busy) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 16),
          Text(t.videoPlayback.analysisRunning),
        ] else if (_failed)
          Text(t.videoPlayback.analysisFailed)
        else if (_result case final result?) ...[
          _row(t.videoPlayback.analysisMode, result.mode),
          _row(t.videoPlayback.analysisPage, result.page),
          _row(t.videoPlayback.analysisState, result.status),
          const SizedBox(height: 12),
          Text(
            t.videoPlayback.analysisScope,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (_copyFailed)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(t.videoPlayback.analysisCopyFailed),
          ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton.icon(
              onPressed: _busy ? null : _analyze,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: Text(t.videoPlayback.analyzeAgain),
            ),
            FilledButton.icon(
              onPressed: _busy || _result == null || _copying ? null : _copy,
              icon: Icon(
                _copied ? Icons.check_rounded : Icons.copy_all_outlined,
                size: 20,
              ),
              label: Text(
                _copied
                    ? t.videoPlayback.analysisCopied
                    : t.videoPlayback.copyDiagnostic,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
