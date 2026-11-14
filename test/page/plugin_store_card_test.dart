import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/page/plugin_store/models/cloud_plugin_item.dart';
import 'package:zephyr/page/plugin_store/widgets/cloud_plugin_card.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/plugin/utils/plugin_catalog_merge.dart';
import 'package:zephyr/plugin/utils/published_plugin_artifact.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import '../test_helper.dart';

const _uuid = '11111111-1111-4111-8111-111111111111';
CloudPluginItem _item({String name = 'Plugin fixture'}) => CloudPluginItem(
  repo: 'AuthorShouldStayHidden/Plugin-OnlyName',
  manifest: CloudPluginManifest(
    name: name,
    uuid: _uuid,
    iconUrl: '',
    describe: 'Feature description',
    version: '0.1.0',
    home: 'https://example.test/',
    updateUrl: '',
    npmName: '',
    githubRepository: '',
  ),
);

void main() {
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    objectbox.pluginInfoBox.removeAll();
    await PluginRegistryService.I.init();
  });

  Future<void> mount(
    WidgetTester tester, {
    String style = 'breeze',
    Brightness brightness = Brightness.light,
    double scale = 1,
    bool installing = false,
    String name = 'Plugin fixture',
    CloudPluginItem? item,
    VoidCallback? install,
    ValueChanged<String>? open,
    ValueChanged<String>? reinstall,
  }) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final preference = ValueNotifier(style);
    addTearDown(preference.dispose);
    await tester.pumpWidget(
      AppInterfaceStyleScope(
        style: preference,
        child: MaterialApp(
          theme: ThemeData(brightness: brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: CloudPluginCard(
                item: item ?? _item(name: name),
                installing: installing,
                onOpenHome: open ?? (_) {},
                onInstall: install ?? () {},
                onReinstall: reinstall,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'store $style $brightness hides author/owner and centers actions at large text',
        (tester) async {
          await mount(tester, style: style, brightness: brightness, scale: 2);
          expect(find.textContaining('AuthorShouldStayHidden'), findsNothing);
          expect(find.textContaining('${t.plugin.author}:'), findsNothing);
          expect(find.text('Feature description'), findsOneWidget);
          final buttons = find.byType(OutlinedButton);
          expect(buttons, findsNWidgets(3));
          for (final button in buttons.evaluate()) {
            final finder = find.byWidget(button.widget);
            final text = find.descendant(
              of: finder,
              matching: find.byType(Text),
            );
            final bounds = tester.getRect(finder);
            expect(bounds.height, greaterThanOrEqualTo(44));
            expect(tester.getCenter(text).dx, closeTo(bounds.center.dx, .5));
            expect(tester.getCenter(text).dy, closeTo(bounds.center.dy, .5));
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }

  testWidgets(
    'missing name falls back to repository name without showing owner',
    (tester) async {
      await mount(tester, name: '');
      expect(find.text('Plugin-OnlyName'), findsOneWidget);
      expect(find.textContaining('AuthorShouldStayHidden'), findsNothing);
    },
  );

  testWidgets(
    'store installs once on release and disables actions while installing',
    (tester) async {
      var installs = 0;
      await mount(tester, install: () => installs++);
      final download = find.widgetWithText(OutlinedButton, t.plugin.download);
      final gesture = await tester.startGesture(tester.getCenter(download));
      await tester.pump();
      expect(installs, 0);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(installs, 1);
      await mount(tester, installing: true, install: () => installs++);
      for (final button in tester.widgetList<OutlinedButton>(
        find.byType(OutlinedButton),
      )) {
        expect(button.onPressed, isNull);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'latest installed plugin stays disabled and has no second install action',
    (tester) async {
      await PluginRegistryService.I.upsert(
        PluginInfo(
          uuid: _uuid,
          version: '0.1.0',
          originScript: 'fixture',
          insertedAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          isEnabled: false,
          isDeleted: false,
          deletedAt: null,
          lastLoadSuccess: true,
          lastLoadError: null,
          debug: false,
        ),
      );
      var installs = 0;
      await mount(tester, install: () => installs++);
      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, t.plugin.alreadyLatest),
      );
      expect(button.onPressed, isNull);
      expect(installs, 0);
      expect(PluginRegistryService.I.getByUuid(_uuid)?.isEnabled, isFalse);
    },
  );

  testWidgets('only the matching formal migration offers update', (
    tester,
  ) async {
    const uuid = 'e9f18928-3ba8-4d86-a12e-b53a62f47933';
    const oldScript = 'legacy release fixture';
    final row = {
      'repo': personalPluginCatalogRepository,
      'manifest': {
        'uuid': uuid,
        'version': '0.1.2',
        'updateUrl':
            'https://raw.githubusercontent.com/$personalPluginCatalogRepository/main/updates/v1/bika.json',
        'releaseSeries': 1,
        'scriptSha256': publishedPluginScriptSha256('formal release fixture'),
        'migrationFrom': [
          {
            'version': '0.1.11',
            'scriptSha256': publishedPluginScriptSha256(oldScript),
          },
        ],
      },
    };
    final catalog = await loadCloudPluginCatalog(
      official: () async => null,
      personal: () async => jsonEncode([row]),
      fallback: const CloudPluginCatalogSnapshot(),
    );
    final entry = catalog.entries.single;
    final item = CloudPluginItem.fromJson(
      entry.json,
      formalRelease: entry.formalRelease,
    );
    final old = PluginInfo(
      uuid: uuid,
      version: '0.1.11',
      originScript: oldScript,
      insertedAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      isEnabled: false,
      isDeleted: false,
      lastLoadSuccess: true,
      debug: false,
    );
    await PluginRegistryService.I.upsert(old);
    var installs = 0;
    await mount(tester, item: item, install: () => installs++);
    await tester.tap(
      find.widgetWithText(OutlinedButton, t.plugin.downloadUpdate),
    );
    expect(installs, 1);

    await PluginRegistryService.I.upsert(old..originScript = 'other bundle');
    await mount(tester, item: item, install: () => installs++);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, t.plugin.localVersionNewer),
          )
          .onPressed,
      isNull,
    );
    expect(installs, 1);
  });

  for (final localVersion in ['0.1.0', '0.1.8', '0.0.9']) {
    testWidgets(
      'a formal listing keeps the version action and puts reinstall in more ($localVersion)',
      (tester) async {
        final catalog = await loadCloudPluginCatalog(
          official: () async => null,
          personal: () async => jsonEncode([
            {
              'repo': personalPluginCatalogRepository,
              'manifest': {
                'name': 'Plugin fixture',
                'uuid': _uuid,
                'version': '0.1.0',
                'updateUrl':
                    'https://raw.githubusercontent.com/$personalPluginCatalogRepository/main/updates/v1/fixture.json',
                'releaseSeries': 1,
                'scriptSha256': publishedPluginScriptSha256('cloud fixture'),
              },
            },
          ]),
          fallback: const CloudPluginCatalogSnapshot(),
        );
        final entry = catalog.entries.single;
        final item = CloudPluginItem.fromJson(
          entry.json,
          formalRelease: entry.formalRelease,
        );
        await PluginRegistryService.I.upsert(
          PluginInfo(
            uuid: _uuid,
            version: localVersion,
            originScript: 'internal fixture',
            insertedAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            isEnabled: false,
            isDeleted: false,
            lastLoadSuccess: true,
            debug: false,
          ),
        );
        String? selected;
        await mount(
          tester,
          item: item,
          reinstall: (version) => selected = version,
        );
        final action = find.widgetWithText(
          OutlinedButton,
          switch (localVersion) {
            '0.1.0' => t.plugin.alreadyLatest,
            '0.1.8' => t.plugin.localVersionNewer,
            _ => t.plugin.downloadUpdate,
          },
        );
        expect(action, findsOneWidget);
        expect(
          tester.widget<OutlinedButton>(action).onPressed != null,
          localVersion == '0.0.9',
        );
        expect(find.text(t.pluginLifecycle.reinstall), findsNothing);
        final more = find.byTooltip(t.common.more);
        expect(more, findsOneWidget);
        await tester.tap(more);
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.pluginLifecycle.reinstall));
        await tester.pumpAndSettle();
        expect(selected, localVersion);

        await mount(
          tester,
          item: item,
          installing: true,
          reinstall: (_) {
            fail('A pending operation must disallow a second installation');
          },
        );
        expect(
          tester.widget<IconButton>(find.byType(IconButton)).onPressed,
          isNull,
        );
        expect(find.text(t.pluginLifecycle.reinstall), findsNothing);
      },
    );
  }
}
