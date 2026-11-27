import 'dart:convert';

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/page/plugin_store/models/cloud_plugin_item.dart';
import 'package:zephyr/page/plugin_store/widgets/cloud_plugin_card.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/plugin/utils/plugin_catalog_merge.dart';
import 'package:zephyr/plugin/utils/published_plugin_artifact.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import '../test_helper.dart';

const _uuid = '11111111-1111-4111-8111-111111111111';
CloudPluginItem _item({
  String name = 'Plugin fixture',
  String description = 'Feature description',
  String updateUrl = 'https://fixture.invalid/releases/latest',
}) => CloudPluginItem(
  repo: 'AuthorShouldStayHidden/Plugin-OnlyName',
  manifest: CloudPluginManifest(
    name: name,
    uuid: _uuid,
    iconUrl: '',
    describe: description,
    version: '0.1.0',
    home: 'https://example.test/',
    updateUrl: updateUrl,
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
    double width = 320,
    TextDirection direction = TextDirection.ltr,
    bool installing = false,
    String name = 'Plugin fixture',
    CloudPluginItem? item,
    VoidCallback? install,
    ValueChanged<String>? open,
    ValueChanged<String>? reinstall,
  }) async {
    tester.view.physicalSize = Size(width, 900);
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
            child: Directionality(textDirection: direction, child: child!),
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
        'store $style $brightness keeps a single install button at large text',
        (tester) async {
          await mount(tester, style: style, brightness: brightness, scale: 2);
          expect(find.textContaining('AuthorShouldStayHidden'), findsNothing);
          expect(find.textContaining('${t.plugin.author}:'), findsNothing);
          expect(find.text('Feature description'), findsOneWidget);
          expect(find.text(t.plugin.homepage), findsNothing);
          expect(find.text(t.plugin.githubRepo), findsNothing);
          final install = find.widgetWithText(FilledButton, t.plugin.install);
          final more = find.byTooltip(t.common.more);
          expect(install, findsOneWidget);
          expect(more, findsOneWidget);
          final bounds = tester.getRect(install);
          expect(bounds.height, greaterThanOrEqualTo(44));
          expect(tester.getSize(more).height, greaterThanOrEqualTo(44));
          final label = tester.getCenter(find.text(t.plugin.install));
          expect(label.dx, closeTo(bounds.center.dx, .5));
          expect(label.dy, closeTo(bounds.center.dy, .5));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }

  for (final (style, brightness, width, scale, direction) in [
    ('system', Brightness.light, 430.0, 1.0, TextDirection.ltr),
    ('breeze', Brightness.dark, 320.0, 2.0, TextDirection.rtl),
  ]) {
    testWidgets('long store descriptions disclose per card in $style', (
      tester,
    ) async {
      const description =
          'Read manga in several languages.\n\n'
          '- Browse series and translations.\n'
          '- Filter by language and status.\n'
          '- Check the latest available chapters.';
      var installs = 0;
      await mount(
        tester,
        style: style,
        brightness: brightness,
        width: width,
        scale: scale,
        direction: direction,
        item: _item(description: description),
        install: () => installs++,
      );

      final card = find.byType(CloudPluginCard);
      final details = find.text(description);
      final cloudVersion = find.text(t.plugin.cloudVersion(version: '0.1.0'));
      final install = find.widgetWithText(FilledButton, t.plugin.install);
      final expand = find.widgetWithText(
        TextButton,
        t.comicInfo.expandFullText,
      );
      final collapsedHeight = tester.getSize(card).height;
      final previewWidth = tester
          .renderObject<RenderParagraph>(details)
          .constraints
          .maxWidth;
      expect(tester.widget<Text>(details).maxLines, 2);
      expect(
        tester.renderObject<RenderParagraph>(details).didExceedMaxLines,
        isTrue,
      );
      expect(tester.getSize(expand).height, greaterThanOrEqualTo(44));

      await tester.tap(expand);
      await tester.pumpAndSettle();
      final expandedParagraph = tester.renderObject<RenderParagraph>(details);
      expect(expandedParagraph.constraints.maxWidth, greaterThan(previewWidth));
      expect(expandedParagraph.didExceedMaxLines, isFalse);
      expect(
        tester.getRect(cloudVersion).bottom,
        lessThan(tester.getRect(details).top),
      );
      expect(
        tester.getRect(install).bottom,
        lessThan(tester.getRect(details).top),
      );
      await tester.tap(install);
      expect(installs, 1);

      await tester.tap(find.widgetWithText(TextButton, t.comicInfo.collapse));
      await tester.pumpAndSettle();
      expect(tester.getSize(card).height, collapsedHeight);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the card action stays inline at regular width in RTL', (
    tester,
  ) async {
    await mount(tester, width: 430, direction: TextDirection.rtl);
    expect(find.text(t.comicInfo.expandFullText), findsNothing);
    final title = tester.getRect(find.text('Plugin fixture'));
    final install = tester.getRect(
      find.widgetWithText(FilledButton, t.plugin.install),
    );
    final more = tester.getRect(find.byTooltip(t.common.more));
    expect(install.top, closeTo(title.top, 2));
    expect(install.right, lessThan(title.left));
    expect(more.right, lessThan(install.left));
    expect(tester.takeException(), isNull);
  });

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
      final download = find.widgetWithText(FilledButton, t.plugin.install);
      final gesture = await tester.startGesture(tester.getCenter(download));
      await tester.pump();
      expect(installs, 0);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(installs, 1);
      await mount(tester, installing: true, install: () => installs++);
      expect(tester.widget<FilledButton>(download).onPressed, isNull);
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a listing without a download channel keeps install disabled', (
    tester,
  ) async {
    await mount(tester, item: _item(updateUrl: ''));
    final install = find.widgetWithText(FilledButton, t.plugin.install);
    expect(install, findsOneWidget);
    expect(tester.widget<FilledButton>(install).onPressed, isNull);
    expect(find.byTooltip(t.common.more), findsOneWidget);
  });

  testWidgets('latest installed plugin shows one version and a single status', (
    tester,
  ) async {
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
    expect(find.text('${t.plugin.alreadyLatest} · 0.1.0'), findsOneWidget);
    expect(find.textContaining(t.plugin.installed), findsNothing);
    expect(
      find.textContaining(t.plugin.cloudVersion(version: '0.1.0')),
      findsNothing,
    );
    expect(
      find.textContaining(t.plugin.localVersion(version: '0.1.0')),
      findsNothing,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, t.plugin.update),
          )
          .onPressed,
      isNull,
    );
    expect(installs, 0);
    expect(PluginRegistryService.I.getByUuid(_uuid)?.isEnabled, isFalse);
  });

  testWidgets(
    'card action and More remain aligned when install becomes update',
    (tester) async {
      const name = 'A deliberately long source name with translated variants';
      final item = _item(name: name);
      var attempts = 0;
      await mount(tester, scale: 2, item: item, install: () => attempts++);
      final action = find.byKey(const ValueKey('cloud-plugin-card.action'));
      final more = find.byTooltip(t.common.more);
      final actionBounds = tester.getRect(action);
      final moreBounds = tester.getRect(more);
      expect(
        tester.getCenter(action).dy,
        closeTo(tester.getCenter(more).dy, .5),
      );
      expect(moreBounds.left - actionBounds.right, closeTo(8, .5));
      expect(tester.widget<FilledButton>(action).onPressed, isNotNull);
      await tester.tap(action);
      expect(attempts, 1);

      await PluginRegistryService.I.upsert(
        PluginInfo(
          uuid: _uuid,
          version: '0.1.0',
          originScript: 'fixture',
          insertedAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          isEnabled: true,
          isDeleted: false,
          lastLoadSuccess: true,
          debug: false,
        ),
      );
      await mount(tester, scale: 2, item: item, install: () => attempts++);
      expect(find.text(t.plugin.update), findsOneWidget);
      expect(tester.widget<FilledButton>(action).onPressed, isNull);
      expect(tester.getRect(action), actionBounds);
      expect(tester.getRect(more), moreBounds);
      expect(
        tester.getCenter(action).dy,
        closeTo(tester.getCenter(more).dy, .5),
      );
      expect(find.text('${t.plugin.alreadyLatest} · 0.1.0'), findsOneWidget);
      expect(tester.takeException(), isNull);
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
    await tester.tap(find.widgetWithText(FilledButton, t.plugin.update));
    expect(installs, 1);

    await PluginRegistryService.I.upsert(old..originScript = 'other bundle');
    await mount(tester, item: item, install: () => installs++);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, t.plugin.update),
          )
          .onPressed,
      isNull,
    );
    expect(find.textContaining(t.plugin.localVersionNewer), findsOneWidget);
    expect(
      find.textContaining(t.plugin.localVersion(version: '0.1.11')),
      findsOneWidget,
    );
    expect(
      find.textContaining(t.plugin.cloudVersion(version: '0.1.2')),
      findsOneWidget,
    );
    expect(installs, 1);
  });

  testWidgets(
    'card More groups links and reinstall in a compact anchored menu',
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
          lastLoadSuccess: true,
          debug: false,
        ),
      );
      final item = CloudPluginItem.fromJson({
        'repo': 'other-owner/source',
        'manifest': {
          'uuid': _uuid,
          'version': '0.1.0',
          'updateUrl': 'https://fixture.invalid/releases/latest',
        },
      });
      String? selected;
      await mount(
        tester,
        item: item,
        reinstall: (version) => selected = version,
      );
      final more = find.byTooltip(t.common.more);
      expect(more, findsOneWidget);
      final menu = tester.widget<IconButton>(find.byType(IconButton));
      expect(
        menu.style?.minimumSize?.resolve({})?.height,
        greaterThanOrEqualTo(44),
      );
      expect(find.text('${t.plugin.alreadyLatest} · 0.1.0'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, t.plugin.update),
            )
            .onPressed,
        isNull,
      );
      final trigger = tester.getRect(find.byType(NativeVideoMenu));
      await tester.tap(more);
      await tester.pumpAndSettle();
      final surface = tester.getRect(
        find.byKey(const ValueKey('video-host-menu')),
      );
      expect(surface.top, closeTo(trigger.bottom + 6, 1));
      final expectedRight = trigger.right.clamp(16 + surface.width, 304);
      expect(surface.right, closeTo(expectedRight, 1));
      expect(surface.left, greaterThanOrEqualTo(16));
      expect(surface.right, lessThanOrEqualTo(304));
      expect(find.byType(UiKitView), findsNothing);
      expect(find.text(t.plugin.githubRepo), findsOneWidget);
      await tester.tap(find.text(t.pluginLifecycle.reinstall));
      await tester.pumpAndSettle();
      expect(selected, '0.1.0');

      final links = <String>[];
      await mount(
        tester,
        open: links.add,
        reinstall: (_) {},
        item: _item(updateUrl: ''),
      );
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(find.text(t.pluginLifecycle.reinstall), findsNothing);
      await tester.tap(find.text(t.plugin.homepage));
      await tester.pumpAndSettle();
      await tester.tap(more);
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.plugin.githubRepo));
      await tester.pumpAndSettle();
      expect(links, [
        'https://example.test/',
        'https://github.com/AuthorShouldStayHidden/Plugin-OnlyName',
      ]);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

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
        if (localVersion == '0.0.9') {
          expect(
            find.widgetWithText(FilledButton, t.plugin.update),
            findsOneWidget,
          );
        } else {
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, t.plugin.update),
                )
                .onPressed,
            isNull,
          );
          final status = localVersion == '0.1.0'
              ? t.plugin.alreadyLatest
              : t.plugin.localVersionNewer;
          expect(find.textContaining(status), findsOneWidget);
        }
        expect(find.text(t.pluginLifecycle.reinstall), findsNothing);
        final more = find.byTooltip(t.common.more);
        expect(more, findsOneWidget);
        await tester.tap(more);
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.pluginLifecycle.reinstall));
        await tester.pumpAndSettle();
        expect(selected, localVersion);

        if (localVersion == '0.1.0') {
          selected = null;
          await mount(
            tester,
            item: CloudPluginItem.fromJson(entry.json),
            reinstall: (version) => selected = version,
          );
          await tester.tap(find.byTooltip(t.common.more));
          await tester.pumpAndSettle();
          await tester.tap(find.text(t.pluginLifecycle.reinstall));
          await tester.pumpAndSettle();
          expect(selected, localVersion);
        }

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
