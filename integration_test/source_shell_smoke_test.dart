import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zephyr/main.dart' as app;
import 'package:zephyr/plugin/plugin_install_service.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';

const _fixtureName = 'copy_comic.bundle.cjs.br';
const _fixtureAsset = 'test/fixtures/copy_comic.bundle.cjs.br';
const _pluginUuid = 'b28da416-f2d4-4208-a85e-8b4c7c648e48';

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

    final fixture = await rootBundle.load(_fixtureAsset);
    await PluginInstallService.I.installFromLocalBytes(
      fixture.buffer.asUint8List(),
      fileName: _fixtureName,
      allowReplaceExisting: true,
    );
    expect(PluginRegistryService.I.getByUuid(_pluginUuid), isNotNull);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('发现').last);
    await waitFor(tester, find.text('启动'));
    await binding.takeScreenshot('source-launcher');

    await tester.tap(find.text('启动').first);
    await waitFor(tester, find.text('漫画推荐'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 8)),
    );
    await tester.pump();
    await binding.takeScreenshot('source-home');

    await tester.tap(find.text('全新上架').last);
    await waitFor(tester, find.text('全新上架'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 8)),
    );
    await tester.pump();
    await binding.takeScreenshot('source-newest');
  });
}
