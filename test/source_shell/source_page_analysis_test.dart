import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_page_analysis.dart';
import 'package:zephyr/plugin/models/plugin_runtime_state.dart';

PluginRuntimeState runtime({bool loaded = true, String version = '3.2.1'}) =>
    PluginRuntimeState(
      uuid: 'test-source',
      version: version,
      originScript: 'private script cookie=session',
      isEnabled: true,
      isDeleted: false,
      debug: true,
      debugUrl: 'https://private.test/account',
      lastLoadSuccess: loaded,
      lastLoadError: 'private-account-secret',
      sortOrder: null,
      insertedAt: DateTime(2026),
      updatedAt: DateTime(2026),
      deletedAt: null,
    );

void main() {
  test(
    'unknown registration stays unknown rather than passing a network check',
    () {
      final result = sourcePageAnalysisResult(source: 'copy', state: null);
      expect(result.status, t.sourceShell.analysisRead);
      expect(result.report, contains('host_runtime_load: unknown'));
      expect(result.report, contains('network_check: not_performed'));
    },
  );

  test('known host loading never claims that page content loaded', () {
    final result = sourcePageAnalysisResult(source: 'bika', state: runtime());
    expect(result.report, contains('plugin_version: 3.2.1'));
    expect(result.report, contains('plugin_enabled: true'));
    expect(result.report, contains('host_runtime_load: success'));
    expect(result.report, contains('content_load: unknown'));
    expect(result.report, isNot(contains('private')));
    expect(result.report, isNot(contains('cookie')));
  });

  test(
    'reports emit fixed failure status and reject unsafe identifier metadata',
    () {
      final result = sourcePageAnalysisResult(
        source: 'email@example.test',
        state: runtime(loaded: false, version: 'https://private.test/token'),
      );
      expect(result.report, contains('host_runtime_load: failed'));
      expect(result.report, contains('source: unknown'));
      expect(result.report, contains('plugin_version: unknown'));
      expect(result.report, isNot(contains('private')));
      expect(result.report, isNot(contains('@')));
    },
  );
}
