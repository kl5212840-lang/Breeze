import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_diagnostic_preferences.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/page/video/video_page_analysis.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';

/// A deliberately narrow host snapshot. Registration and script loading do not
/// establish whether the current page, its content, or its network loaded.
VideoPageAnalysisResult sourcePageAnalysisResult({
  required String source,
  required PluginRuntimeState? state,
}) {
  String safeIdentifier(String? value) =>
      value != null &&
          RegExp(r'^[A-Za-z0-9][A-Za-z0-9._+\-]{0,99}$').hasMatch(value)
      ? value
      : 'unknown';
  final version = safeIdentifier(state?.version);
  final load = state == null
      ? 'unknown'
      : state.lastLoadSuccess
      ? 'success'
      : state.lastLoadError?.isNotEmpty == true
      ? 'failed'
      : 'unknown';
  final fields = <String, String>{
    'scope': 'host_plugin_registry',
    'source': safeIdentifier(source),
    'plugin_version': version,
    'plugin_enabled': state?.isEnabled.toString() ?? 'unknown',
    'plugin_deleted': state?.isDeleted.toString() ?? 'unknown',
    'host_runtime_load': load,
    'content_load': 'unknown',
    'network_check': 'not_performed',
  };
  final report = fields.entries
      .map((field) => '${field.key}: ${field.value}')
      .join('\n');
  // The copied report uses fixed evidence labels so support can distinguish
  // host runtime status from unknown content/network status in any app locale.
  return VideoPageAnalysisResult(
    mode: t.plugin.management,
    page: t.sourceShell.analysisTitle,
    status: t.sourceShell.analysisRead,
    details: [
      '${t.sourceShell.analysisVersion}: $version',
      '${t.plugin.management}: ${state == null
          ? t.common.unknown
          : state.isEnabled
          ? t.common.enabled
          : t.common.disabled}',
      '${t.sourceShell.analysisRuntime}: ${load == 'success'
          ? t.common.success
          : load == 'failed'
          ? t.common.failed
          : t.common.unknown}',
      t.sourceShell.analysisLimit,
    ].join('\n'),
    report: report,
  );
}

Future<void> showSourcePageAnalysis(BuildContext context, String source) async {
  if (!await SourceDiagnosticPreferences.enabled(source) || !context.mounted) {
    return;
  }
  await showVideoTaskSheet<void>(
    context: context,
    builder: (_) => VideoPageAnalysis(
      analyze: () async {
        if (!await SourceDiagnosticPreferences.enabled(source)) {
          throw StateError('Diagnostics disabled');
        }
        return sourcePageAnalysisResult(
          source: source,
          state: PluginRegistryService.I.getByUuid(source),
        );
      },
      onCopy: (report) async {
        if (!await SourceDiagnosticPreferences.enabled(source)) {
          throw StateError('Diagnostics disabled');
        }
        await Clipboard.setData(ClipboardData(text: report));
      },
    ),
  );
}
