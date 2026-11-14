import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
// Exercise the existing launcher boundary without opening an actual website.
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/source_shell/source_website.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';

import '../test_helper.dart';

class _Launcher extends UrlLauncherPlatform {
  @override
  Null get linkDelegate => null;

  final launches = <({String url, PreferredLaunchMode mode})>[];
  bool opens = true;
  bool throws = false;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launches.add((url: url, mode: options.mode));
    if (throws) throw PlatformException(code: 'fixture_unavailable');
    return opens;
  }
}

const _declaredSource = 'official-site-fixture';
const _repoSource = 'plugin-repo-fixture';
const _official = 'https://comics.example.invalid/zh/';
final _fixtureIds = <String, int>{};

Future<void> _metadata(String source, Map<String, dynamic> metadata) async {
  final info = PluginInfo(
    id: _fixtureIds[source] ?? 0,
    uuid: source,
    version: '1.0.0',
    originScript: '',
    insertedAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    isEnabled: true,
    isDeleted: false,
    lastLoadSuccess: true,
    debug: false,
    getInfoJson: jsonEncode(metadata),
  );
  await PluginRegistryService.I.upsert(info);
  _fixtureIds[source] = info.id;
}

Widget _surface(
  String source, {
  bool showSettings = true,
  List<SourceMenuAction> actions = const [],
}) => MaterialApp(
  home: Scaffold(
    appBar: AppBar(
      actions: [
        SourceMoreButton(
          source: source,
          showSettings: showSettings,
          actions: actions,
        ),
      ],
    ),
    body: const Text('Current source content'),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Launcher launcher;

  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    await PluginRegistryService.I.init();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  setUp(() async {
    launcher = _Launcher();
    final original = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = original);
    await _metadata(_declaredSource, {
      'websiteUrl': _official,
      'home': 'https://github.com/example/plugin',
      // These are deliberately different and must never become the website.
      'updateUrl': 'https://api.github.com/repos/example/plugin/releases',
      'accountUrl': 'https://comics.example.invalid/account',
      'currentUrl': 'https://comics.example.invalid/comic/123',
    });
    await _metadata(_repoSource, {'home': 'https://github.com/example/plugin'});
  });

  test(
    'metadata accepts explicit website declarations, not ambiguous legacy home',
    () {
      expect(sourceOfficialWebsite(_declaredSource), Uri.parse(_official));
      for (final key in ['websiteUrl', 'officialWebsiteUrl']) {
        expect(
          officialWebsiteFromPluginInfo({
            key: _official,
            'home': 'https://site.example.invalid/',
          }),
          Uri.parse(_official),
        );
        expect(
          officialWebsiteFromPluginInfo({
            'breezeExperience': {key: _official},
          }),
          Uri.parse(_official),
        );
      }
      expect(
        officialWebsiteFromPluginInfo({
          'home': 'https://site.example.invalid/',
        }),
        isNull,
      );
      expect(
        validatedSourceWebsite(' http://site.example.invalid/ '),
        Uri.parse('http://site.example.invalid/'),
      );
    },
  );

  test(
    'missing declarations and repository/update/account URLs stay hidden',
    () {
      expect(sourceOfficialWebsite(_repoSource), isNull);
      expect(sourceOfficialWebsite('unknown-source-fixture'), isNull);
      expect(officialWebsiteFromPluginInfo(null), isNull);
      expect(
        officialWebsiteFromPluginInfo({
          'updateUrl': _official,
          'accountUrl': _official,
          'currentUrl': _official,
        }),
        isNull,
      );
      for (final host in [
        'github.com',
        'api.github.com',
        'raw.githubusercontent.com',
        'gitlab.com',
        'gitee.com',
        'bitbucket.org',
        'codeberg.org',
      ]) {
        expect(
          officialWebsiteFromPluginInfo({
            'websiteUrl': 'https://$host/project',
          }),
          isNull,
          reason: host,
        );
      }
    },
  );

  test(
    'reviewed Bika URL wins over an installed lookalike declaration',
    () async {
      const bika = 'e9f18928-3ba8-4d86-a12e-b53a62f47933';
      await _metadata(bika, {
        'websiteUrl': 'https://picacomic.example.invalid/',
      });
      expect(
        sourceOfficialWebsite(bika),
        Uri.parse('https://www.picacomic.com/'),
      );
      expect(
        sourceOfficialWebsite('b6161c72-031e-4383-9ea0-4ca8fa4231b6'),
        isNull,
      );
    },
  );

  test('only absolute HTTP URLs without user credentials are accepted', () {
    for (final value in <Object?>[
      null,
      12,
      '',
      '/comic/1',
      '//site.example.invalid/',
      'file:///tmp/page',
      'javascript:alert(1)',
      'mailto:user@example.invalid',
      'https:',
      'https://',
      'https://user:password@site.example.invalid/',
      'https://user@site.example.invalid/',
    ]) {
      expect(validatedSourceWebsite(value), isNull, reason: '$value');
    }
  });

  for (final showSettings in [false, true]) {
    testWidgets('personal settings has one entry showSettings=$showSettings', (
      tester,
    ) async {
      var sourceOpened = 0;
      await tester.pumpWidget(
        _surface(
          _declaredSource,
          showSettings: showSettings,
          actions: [
            SourceMenuAction(
              id: 'settings',
              label: 'Source settings fixture',
              icon: Icons.tune,
              symbol: 'slider.horizontal.3',
              onSelected: () => sourceOpened++,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final menu = tester.widget<NativeVideoMenu>(find.byType(NativeVideoMenu));
      expect(menu.options.containsKey('__source_settings'), showSettings);
      if (!showSettings) return;
      menu.onSelected('__source_settings');
      await tester.pumpAndSettle();
      expect(
        sourceOpened,
        1,
        reason: 'the menu opens the formal target directly, without a hub',
      );
      expect(find.text(t.sourceShell.appSettings), findsNothing);
      expect(find.text('Current source content'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('More opens the declared website externally and retains source', (
    tester,
  ) async {
    await tester.pumpWidget(_surface(_declaredSource));
    await tester.tap(find.byTooltip(t.sourceShell.navigationActions));
    await tester.pumpAndSettle();
    expect(find.text(t.sourceShell.openOfficialWebsite), findsOneWidget);
    expect(find.text(t.sourceShell.exitPlugin), findsOneWidget);
    await tester.tap(find.text(t.sourceShell.openOfficialWebsite));
    await tester.pumpAndSettle();
    expect(launcher.launches, [
      (url: _official, mode: PreferredLaunchMode.externalApplication),
    ]);
    expect(find.text('Current source content'), findsOneWidget);
    expect(find.text(t.sourceShell.exitPlugin), findsNothing);
  });

  testWidgets('source without an official website still offers explicit exit', (
    tester,
  ) async {
    await tester.pumpWidget(_surface(_repoSource));
    await tester.tap(find.byTooltip(t.sourceShell.navigationActions));
    await tester.pumpAndSettle();
    expect(find.text(t.sourceShell.openOfficialWebsite), findsNothing);
    expect(find.text(t.sourceShell.exitPlugin), findsOneWidget);
    expect(launcher.launches, isEmpty);
  });

  testWidgets(
    'native More uses the same website action and keeps tools opt-in',
    (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (_) async => null,
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          null,
        ),
      );
      await tester.pumpWidget(_surface(_declaredSource));
      await tester.pumpAndSettle();
      final menu = tester.widget<NativeVideoMenu>(find.byType(NativeVideoMenu));
      expect(menu.options.values, [
        t.sourceShell.openOfficialWebsite,
        t.discover.settings,
        t.sourceShell.exitPlugin,
      ]);
      expect(menu.optionIcons.keys, containsAll(menu.options.keys));
      menu.onSelected(
        menu.options.entries
            .singleWhere(
              (entry) => entry.value == t.sourceShell.openOfficialWebsite,
            )
            .key,
      );
      await tester.pumpAndSettle();
      expect(launcher.launches.single.url, _official);
      expect(
        launcher.launches.single.mode,
        PreferredLaunchMode.externalApplication,
      );
      expect(find.text('Current source content'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  for (final throws in [false, true]) {
    testWidgets(
      'launcher ${throws ? 'exception' : 'refusal'} preserves source and reports failure',
      (tester) async {
        launcher.opens = false;
        launcher.throws = throws;
        await tester.pumpWidget(_surface(_declaredSource));
        await tester.tap(find.byTooltip(t.sourceShell.navigationActions));
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.sourceShell.openOfficialWebsite));
        await tester.pumpAndSettle();
        expect(
          find.text(t.plugin.cannotOpenLink(url: _official)),
          findsOneWidget,
        );
        expect(find.text('Current source content'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
