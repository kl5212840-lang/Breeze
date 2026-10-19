import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zephyr/main.dart' as app;
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/page/comic_list/view/plugin_comic_grid_sliver.dart';
import 'package:zephyr/page/source_shell/view/source_shell_page.dart';
import 'package:zephyr/plugin/plugin_install_service.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/src/rust/api/qjs.dart';

const _fixtureName = 'copy_comic.bundle.cjs.br';
const _fixtureAsset = 'test/fixtures/copy_comic.bundle.cjs.br';
const _pluginUuid = 'b28da416-f2d4-4208-a85e-8b4c7c648e48';
const _simProxyUrl = String.fromEnvironment('SIM_PROXY_URL');
const _captureWaitSeconds = int.fromEnvironment(
  'SIM_CAPTURE_WAIT_SECONDS',
  defaultValue: 8,
);
const _probePluginNetwork = bool.fromEnvironment('SIM_PROBE_PLUGIN_NETWORK');
const _assertPluginContent = bool.fromEnvironment('SIM_ASSERT_PLUGIN_CONTENT');
const _skipScreenshots = bool.fromEnvironment('SIM_SKIP_SCREENSHOTS');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var attempt = 0; attempt < 30; attempt++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (finder.evaluate().isNotEmpty) return;
    }
    expect(finder, findsWidgets);
  }

  testWidgets('launch source and switch persistent sections', (tester) async {
    final testFlutterErrorHandler = FlutterError.onError;
    await app.main(const []);
    FlutterError.onError = testFlutterErrorHandler;
    await waitFor(tester, find.text('发现'));

    if (_simProxyUrl.isNotEmpty) {
      setHttpProxy(proxy: _simProxyUrl);
    }

    final fixture = await rootBundle.load(_fixtureAsset);
    await PluginInstallService.I.installFromLocalBytes(
      fixture.buffer.asUint8List(),
      fileName: _fixtureName,
      allowReplaceExisting: true,
    );
    expect(PluginRegistryService.I.getByUuid(_pluginUuid), isNotNull);

    if (_probePluginNetwork) {
      final result = await callUnifiedComicPlugin(
        pluginId: _pluginUuid,
        fnPath: 'getHomeRecommend',
        core: const {'page': 1},
      ).timeout(const Duration(seconds: 50));
      final data = result['data'];
      final count = data is Map && data['items'] is List
          ? (data['items'] as List).length
          : -1;
      // Diagnostic only: avoid logging comic titles or account information.
      print('SIM_PLUGIN_PROBE itemCount=$count');
      expect(count, greaterThanOrEqualTo(0));
    }

    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('发现').last);
    await waitFor(tester, find.text('启动'));
    if (!_skipScreenshots) {
      await binding.takeScreenshot('source-launcher');
    }

    await tester.tap(find.text('启动').first);
    await waitFor(tester, find.byType(SourceShellPage));
    final shell = tester.widget<SourceShellPage>(find.byType(SourceShellPage));
    expect(shell.sections.map((section) => section.title), <String>[
      '漫画推荐',
      '全新上架',
      '发现',
      '排行榜',
      '云端收藏',
    ]);
    if (_assertPluginContent) {
      await waitFor(tester, find.byType(PluginComicGridSliver));
      final grid = tester.widget<PluginComicGridSliver>(
        find.byType(PluginComicGridSliver).first,
      );
      print('SIM_HOME_GRID itemCount=${grid.entries.length}');
      expect(grid.entries, isNotEmpty);
    }
    await tester.pump(const Duration(milliseconds: 400));
    if (!_skipScreenshots) {
      await tester.runAsync(
        () =>
            Future<void>.delayed(const Duration(seconds: _captureWaitSeconds)),
      );
      await tester.pump();
      await binding.takeScreenshot('source-home');
    }

    await tester.tap(find.text('全新上架').last);
    await waitFor(tester, find.text('全新上架'));
    if (_assertPluginContent) {
      await waitFor(tester, find.byType(PluginComicGridSliver));
      final grid = tester.widget<PluginComicGridSliver>(
        find.byType(PluginComicGridSliver).first,
      );
      print('SIM_NEWEST_GRID itemCount=${grid.entries.length}');
      expect(grid.entries, isNotEmpty);
    }
    await tester.pump(const Duration(milliseconds: 400));
    if (!_skipScreenshots) {
      await tester.runAsync(
        () =>
            Future<void>.delayed(const Duration(seconds: _captureWaitSeconds)),
      );
      await tester.pump();
      await binding.takeScreenshot('source-newest');
    }
  });
}
