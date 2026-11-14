import 'package:zephyr/page/source_shell/source_settings_destination.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'dart:async';

import 'package:toastification/toastification.dart';
import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/router/router.gr.dart' as routes;
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/network/sync/plugin_config_merge.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/setting/global/global_setting.dart';
import 'package:zephyr/page/source_shell/models/source_shell_section.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';
import 'package:zephyr/page/source_shell/source_return_preferences.dart';
import 'package:zephyr/page/source_shell/view/source_shell_page.dart';
import 'package:zephyr/page/source_shell/widgets/bika_settings_content.dart';
import 'package:zephyr/page/source_shell/bika_access_lines.dart';
import 'package:zephyr/page/source_shell/widgets/bika_image_rendering_settings.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

import '../test_helper.dart';

Map<String, dynamic> _info() => {
  'name': '哔咔漫画',
  'function': [
    {'id': 'home', 'title': '首页'},
  ],
  'breezeExperience': {
    'profileTab': true,
    'bikaExperience': {
      'version': 1,
      'imageQualityVersion': 1,
      'appearanceKey': bikaExperienceAppearanceKey,
      'loadingArtwork': bikaExperienceArtwork,
    },
  },
};

Widget _body({
  String source = bikaPlusSourceId,
  Future<void> Function(String, String, dynamic)? save,
  Future<void> Function()? preferences,
  Future<void> Function(Map<String, dynamic>)? action,
  Future<void> Function(String)? signOut,
  BikaLineCall? imageQualityCall,
  VoidCallback? onSignedOut,
}) => SourceExperienceBoundary(
  source: source,
  builder: (_) => BikaSettingsContent(
    source: source,
    sourceName: '哔咔漫画',
    videoActions: [
      SourceShellAction(
        title: '电影',
        action: {
          'type': 'openVideoLibrary',
          'payload': {'source': source, 'url': 'https://fixture.example/'},
        },
      ),
    ],
    onOpenPreferences: preferences ?? () async {},
    onAction: action ?? (_) async {},
    savePreference: save ?? savePluginConfigValue,
    signOut: signOut ?? signOutBikaSource,
    imageQualityCall: imageQualityCall ?? callBikaAccessLines,
    onSignedOut: onSignedOut,
  ),
);

Future<void> _registerPlus(Map<String, dynamic> info, {String script = ''}) {
  final existing = objectbox.pluginInfoBox.getAll().where(
    (plugin) => plugin.uuid == bikaPlusSourceId,
  );
  final plugin = PluginInfo(
    uuid: bikaPlusSourceId,
    version: 'fixture',
    originScript: script,
    insertedAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    isEnabled: true,
    isDeleted: false,
    lastLoadSuccess: true,
    debug: false,
    getInfoJson: jsonEncode(info),
  )..id = existing.isEmpty ? 0 : existing.first.id;
  return PluginRegistryService.I.upsert(plugin);
}

Map<String, dynamic> _qualityBundle(String value, {bool supported = true}) => {
  'scheme': {
    'sections': [
      {
        'fields': [
          if (supported) {'key': 'image.quality', 'kind': 'select'},
        ],
      },
    ],
  },
  'data': {
    'values': {'image.quality': value},
  },
};

Finder _navigation() => find.byType(VideoNativeNavigation).evaluate().isEmpty
    ? find.byType(NavigationBar)
    : find.byType(VideoNativeNavigation);

Future<void> _tapDestination(WidgetTester tester, String title) =>
    tester.tap(find.descendant(of: _navigation(), matching: find.text(title)));

int _selectedDestination(WidgetTester tester) =>
    switch (tester.widget(_navigation())) {
      VideoNativeNavigation(:final currentIndex) => currentIndex,
      NavigationBar(:final selectedIndex) => selectedIndex,
      _ => throw StateError('Unexpected source navigation'),
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    await PluginRegistryService.I.init();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SourceReturnPreferences.load();
    objectbox.pluginInfoBox.removeAll();
    objectbox.pluginConfigBox.removeAll();
    await PluginRegistryService.I.refreshFromDb();
    await PluginRegistryService.I.upsert(
      PluginInfo(
        uuid: bikaPlusSourceId,
        version: '0.1.2',
        originScript: '',
        insertedAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        isEnabled: true,
        isDeleted: false,
        lastLoadSuccess: true,
        debug: false,
        getInfoJson: jsonEncode(_info()),
      ),
    );
  });

  testWidgets(
    'formal Bika destination opens its existing settings tab without another More root',
    (tester) async {
      final info = _info();
      ((info['breezeExperience'] as Map)['bikaExperience'] as Map).remove(
        'imageQualityVersion',
      );
      await _registerPlus(info);
      final destination = sourceSettingsDestination(
        source: bikaPlusSourceId,
        sourceName: '哔咔＋',
        pluginInfo: info,
      );
      expect(destination, isA<SourceShellPage>());
      final shellPage = destination as SourceShellPage;
      expect(shellPage.initialSectionId, 'bikaSettings');
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: style,
          child: MaterialApp(home: destination),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BikaSettingsContent), findsOneWidget);
      final settingsContext = tester.element(find.byType(BikaSettingsContent));
      final retained = tester.state(find.byType(BikaSettingsContent));
      final more = tester.widget<NativeVideoMenu>(
        find
            .descendant(
              of: find.byType(SourceMoreButton),
              matching: find.byType(NativeVideoMenu),
            )
            .first,
      );
      expect(more.options.containsKey('__source_settings'), isFalse);
      expect(
        more.options.values,
        isNot(contains(t.sourceShell.settingsCenter)),
      );
      await _tapDestination(tester, '首页');
      await tester.pumpAndSettle();
      await openSourceSettings(settingsContext, source: bikaPlusSourceId);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(BikaSettingsContent)), same(retained));
      expect(find.byType(SourceShellPage), findsOneWidget);
      expect(
        _selectedDestination(tester),
        shellPage.sections.indexWhere((section) => section.sourceSettings),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'only the exact capable source receives the host settings destination',
    () {
      final known = SourceShellSection.fromPluginInfo(
        _info(),
        bikaPlusSourceId,
      );
      expect(known.map((s) => s.id), ['home', 'profile', 'bikaSettings']);
      expect(known.last.functionId, isNull);
      expect(known.last.scene, isNull);
      expect(known.last.actions, isEmpty);
      expect(known.any((s) => s.id == 'games'), isFalse);
      final plus = SourceShellSection.fromPluginInfo(_info(), bikaPlusSourceId);
      expect(plus.map((s) => s.id), ['home', 'profile', 'bikaSettings']);
      expect(plus[plus.length - 2].profile, isTrue);
      for (final source in ['other', '83d82c45-7da1-45ec-9663-f93887b71947']) {
        expect(
          SourceShellSection.fromPluginInfo(
            _info(),
            source,
          ).any((s) => s.sourceSettings),
          isFalse,
        );
      }
      final invalid = _info();
      (invalid['breezeExperience'] as Map)['bikaExperience'] = {'version': 2};
      expect(
        SourceShellSection.fromPluginInfo(
          invalid,
          bikaPlusSourceId,
        ).any((s) => s.sourceSettings),
        isFalse,
      );
    },
  );

  testWidgets(
    'Plus renders and saves image quality in its settings tab without a child page',
    (tester) async {
      await _registerPlus(_info());
      savePluginConfigValueSync(
        bikaPlusSourceId,
        bikaImageFilterQualityKey,
        'low',
      );
      var quality = 'original';
      final writes = <Map<String, dynamic>>[];
      Future<Map<String, dynamic>> qualityCall(
        String source,
        String function,
        Map<String, dynamic> core,
      ) async {
        expectSync(source, bikaPlusSourceId);
        if (function == 'saveSettings') {
          writes.add(core);
          quality = (core['values'] as Map)['image.quality'] as String;
          return {'ok': true};
        }
        return {
          'scheme': {
            'sections': [
              {
                'fields': [
                  {'key': 'image.quality', 'kind': 'select'},
                ],
              },
            ],
          },
          'data': {
            'values': {'image.quality': quality},
          },
        };
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _body(
              source: bikaPlusSourceId,
              imageQualityCall: qualityCall,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BikaImageRenderingSettingsPage), findsNothing);
      expect(find.byType(AppBar), findsNothing);
      final field = find.byKey(const ValueKey('bika-image-quality'));
      await tester.ensureVisible(field);
      tester.widget<SettingChoiceTile<String>>(field).onChanged('high');
      await tester.pumpAndSettle();
      expect(tester.widget<SettingChoiceTile<String>>(field).value, 'high');
      expect(ModalRoute.of(tester.element(field))!.isFirst, isTrue);
      expect(writes, [
        {
          'values': {'image.quality': 'high'},
        },
      ]);
      expect(
        loadPluginConfigValue<String>(
          '83d82c45-7da1-45ec-9663-f93887b71947',
          bikaImageFilterQualityKey,
          fallback: '',
        ),
        '',
      );
      expect(
        loadPluginConfigValue<String>(
          bikaPlusSourceId,
          bikaImageFilterQualityKey,
          fallback: '',
        ),
        'low',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'open Plus shell gains declared quality without a misleading rendering fallback',
    (tester) async {
      final oldInfo = _info();
      ((oldInfo['breezeExperience'] as Map)['bikaExperience'] as Map).remove(
        'imageQualityVersion',
      );
      await _registerPlus(oldInfo);
      await tester.pumpWidget(
        MaterialApp(
          home: SourceShellPage(
            source: bikaPlusSourceId,
            sourceName: '哔咔＋',
            sections: const [
              SourceShellSection.more(title: '首页', actions: []),
              SourceShellSection.profile(),
              SourceShellSection.settings(),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(NavigationDestination, t.discover.settings),
      );
      await tester.pumpAndSettle();
      final retained = tester.state(find.byType(BikaSettingsContent));
      expect(find.byKey(const ValueKey('bika-image-quality')), findsNothing);
      expect(
        find.byKey(const ValueKey('bika-image-filter-quality')),
        findsNothing,
      );
      expect(find.text(t.sourceShell.bikaNetworkTitle), findsOneWidget);

      await _registerPlus(_info(), script: 'quality-capable-bundle');
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(BikaSettingsContent)), same(retained));
      expect(find.byKey(const ValueKey('bika-image-quality')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('bika-image-filter-quality')),
        findsNothing,
      );
      expect(find.byType(AppBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final style in ['system', 'breeze']) {
    testWidgets(
      'Plus settings recover schema and fence a save when its bundle changes $style',
      (tester) async {
        await _registerPlus(_info(), script: 'missing-schema');
        final interfaceStyle = ValueNotifier(style);
        addTearDown(interfaceStyle.dispose);
        var supported = false, quality = 'original';
        final pendingWrite = Completer<Map<String, dynamic>>();
        final reads = <String>[];
        Future<Map<String, dynamic>> call(
          String source,
          String function,
          Map<String, dynamic> core,
        ) async {
          expectSync(source, bikaPlusSourceId);
          if (function == 'saveSettings') return pendingWrite.future;
          reads.add(quality);
          return _qualityBundle(quality, supported: supported);
        }

        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: interfaceStyle,
            child: MaterialApp(
              home: SettingPageShell(
                title: '哔咔＋',
                child: _body(source: bikaPlusSourceId, imageQualityCall: call),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final field = find.byKey(const ValueKey('bika-image-quality'));
        SettingChoiceTile<String> choice() => tester.widget(field);
        expect(choice().enabled, isFalse);
        expect(choice().error, isNotNull);
        supported = true;
        quality = 'medium';
        await _registerPlus(_info(), script: 'recovered-schema');
        await tester.pumpAndSettle();
        expect(choice().enabled, isTrue);
        expect(choice().value, 'medium');
        expect(choice().error, isNull);

        choice().onChanged('high');
        await tester.pump();
        expect(choice().enabled, isFalse);
        quality = 'low';
        await _registerPlus(_info(), script: 'replacement-bundle');
        await tester.pumpAndSettle();
        expect(choice().enabled, isTrue);
        expect(choice().value, 'low');
        final readCount = reads.length;
        pendingWrite.complete({'ok': true});
        await tester.pumpAndSettle();
        expect(reads, hasLength(readCount));
        expect(choice().value, 'low');
        expect(choice().enabled, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'BK sign-out cancellation never calls the session command or refresh callback',
    (tester) async {
      var calls = 0, refreshed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _body(
              signOut: (_) async {
                calls++;
              },
              onSignedOut: () {
                refreshed++;
              },
            ),
          ),
        ),
      );
      final before = objectbox.pluginConfigBox
          .getAll()
          .map((e) => e.config)
          .toList();
      await tester.ensureVisible(
        find.byKey(const ValueKey('bika-settings-logout')),
      );
      await tester.tap(find.byKey(const ValueKey('bika-settings-logout')));
      await tester.pumpAndSettle();
      expect(find.text(t.sourceShell.bikaLogoutMessage), findsOneWidget);
      expect(calls, 0);
      await tester.tap(find.widgetWithText(TextButton, t.common.cancel));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(refreshed, 0);
      expect(
        objectbox.pluginConfigBox.getAll().map((e) => e.config).toList(),
        before,
      );
    },
  );

  testWidgets(
    'BK sign-out confirms once and refreshes source state only after success',
    (tester) async {
      var calls = 0, refreshed = 0;
      final hold = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _body(
              signOut: (source) {
                expect(source, bikaPlusSourceId);
                calls++;
                return hold.future;
              },
              onSignedOut: () {
                refreshed++;
              },
            ),
          ),
        ),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('bika-settings-logout')),
      );
      await tester.tap(find.byKey(const ValueKey('bika-settings-logout')));
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.tap(
        find.widgetWithText(TextButton, t.sourceShell.bikaLogout),
      );
      await tester.pump();
      expect(calls, 1);
      expect(refreshed, 0);
      expect(
        tester
            .widget<ListTile>(
              find.byKey(const ValueKey('bika-settings-logout')),
            )
            .onTap,
        isNull,
      );
      hold.complete();
      await tester.pumpAndSettle();
      expect(refreshed, 1);
      expect(find.text(t.sourceShell.bikaLogoutDone), findsWidgets);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('bika-settings-login')),
        -250,
      );
      expect(find.byKey(const ValueKey('bika-settings-login')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'BK sign-out fails locally without claiming success, and a changed account invalidates confirmation',
    (tester) async {
      var calls = 0, refreshed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _body(
              signOut: (_) async {
                calls++;
                throw StateError('fixture failure');
              },
              onSignedOut: () {
                refreshed++;
              },
            ),
          ),
        ),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('bika-settings-logout')),
      );
      await tester.tap(find.byKey(const ValueKey('bika-settings-logout')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, t.sourceShell.bikaLogout),
      );
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(refreshed, 0);
      expect(find.text(t.sourceShell.bikaLogoutFailed), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('bika-settings-logout')));
      await tester.pumpAndSettle();
      pluginSessionWriteFence.advance(bikaPlusSourceId);
      await tester.tap(
        find.widgetWithText(TextButton, t.sourceShell.bikaLogout),
      );
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(refreshed, 0);
      expect(find.text(t.sourceShell.bikaLogoutStateChanged), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'BK-specific sign-out helper never invokes a different source',
    () async {
      await expectLater(
        signOutBikaSource('unrelated-source'),
        throwsA(isA<StateError>()),
      );
    },
  );

  testWidgets(
    'body has no nested chrome and its verified actions keep their callbacks',
    (tester) async {
      var preferences = 0;
      final actions = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _body(
              preferences: () async {
                preferences++;
              },
              action: (a) async {
                actions.add(a);
              },
            ),
          ),
        ),
      );
      expect(find.byType(AppBar), findsNothing);
      expect(objectbox.pluginConfigBox.getAll(), isEmpty);
      await tester.tap(find.byKey(const ValueKey('bika-settings-preferences')));
      expect(preferences, 1);
      expect(actions, isEmpty);
      expect(
        find.byKey(const ValueKey('bika-settings-video-电影')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('bika-settings-breeze')),
        findsOneWidget,
      );
      expect(find.text('${t.settings.cache} · Breeze'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  Map<String, dynamic> infoWithVideoAndRetiredGames() {
    final info = _info();
    final declaration =
        ((info['breezeExperience'] as Map)['bikaExperience'] as Map);
    declaration['gameListFunction'] = 'getGameListBundle';
    declaration['gameDetailFunction'] = 'getGameDetailsBundle';
    info['breezeVideoModules'] = [
      {
        'type': 'openVideoLibrary',
        'payload': {
          'title': '电影',
          'url': 'https://video.fixture/',
          'protocol': 2,
          'catalogFnPath': 'catalog',
          'detailFnPath': 'detail',
          'playbackFnPath': 'play',
        },
      },
    ];
    return info;
  }

  test('declared video remains available while retired games stay hidden', () {
    final info = infoWithVideoAndRetiredGames();
    final sections = SourceShellSection.fromPluginInfo(info, bikaPlusSourceId);
    expect(sections.map((s) => s.id), [
      'home',
      'video',
      'profile',
      'bikaSettings',
    ]);
    final unrelated = SourceShellSection.fromPluginInfo(info, 'unrelated');
    expect(unrelated.any((s) => s.bikaGames || s.sourceSettings), isFalse);
  });

  testWidgets(
    'same-version video metadata refresh keeps the open settings tab selected',
    (tester) async {
      final global = ValueNotifier<String>('breeze');
      addTearDown(global.dispose);
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: global,
          child: MaterialApp(
            home: SourceShellPage(
              source: bikaPlusSourceId,
              sourceName: '哔咔漫画',
              sections: SourceShellSection.fromPluginInfo(
                _info(),
                bikaPlusSourceId,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tapDestination(tester, t.discover.settings);
      await tester.pumpAndSettle();
      expect(_selectedDestination(tester), 2);
      final retained = tester.state(find.byType(BikaSettingsContent));
      final plugin = objectbox.pluginInfoBox.getAll().single;
      plugin.getInfoJson = jsonEncode(infoWithVideoAndRetiredGames());
      await PluginRegistryService.I.upsert(plugin);
      await tester.pumpAndSettle();
      final navigation = tester.widget<VideoNativeNavigation>(_navigation());
      expect(navigation.items, hasLength(4));
      expect(
        navigation.items.map((item) => item.label),
        isNot(contains(t.sourceShell.games)),
      );
      expect(tester.state(find.byType(BikaSettingsContent)), same(retained));
      expect(_selectedDestination(tester), 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'source appearance saves only its field and does not write a default or global style',
    (tester) async {
      final global = ValueNotifier<String>('system');
      addTearDown(global.dispose);
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: global,
          child: MaterialApp(home: Scaffold(body: _body())),
        ),
      );
      expect(objectbox.pluginConfigBox.getAll(), isEmpty);
      final tile = tester.widget<SettingChoiceTile<SourceExperienceStyle>>(
        find.byKey(const ValueKey('bika-settings-style')),
      );
      tile.onChanged(SourceExperienceStyle.original);
      await tester.pump();
      final configs = objectbox.pluginConfigBox.getAll();
      expect(configs, hasLength(1));
      expect(configs.single.name, bikaPlusSourceId);
      final config = jsonDecode(configs.single.config) as Map;
      final syncFields = config.remove(pluginConfigSyncFields) as Map;
      expect(syncFields.keys, [bikaExperienceAppearanceKey]);
      expect(config, {bikaExperienceAppearanceKey: 'original'});
      expect(global.value, 'system');
      expect(tester.takeException(), isNull);
      toastification.dismissAll(delayForAnimation: false);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      toastification.managers.clear();
    },
  );

  testWidgets(
    'failed source preference can retry and concurrent selections are single flight',
    (tester) async {
      final writes = <Completer<void>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _body(
              save: (source, field, value) {
                expectSync(source, bikaPlusSourceId);
                expectSync(field, bikaExperienceAppearanceKey);
                expectSync(value, 'original');
                final wait = Completer<void>();
                writes.add(wait);
                return wait.future.then(
                  (_) => savePluginConfigValue(source, field, value),
                );
              },
            ),
          ),
        ),
      );
      SettingChoiceTile<SourceExperienceStyle> tile() =>
          tester.widget(find.byKey(const ValueKey('bika-settings-style')));
      tile().onChanged(SourceExperienceStyle.original);
      tile().onChanged(SourceExperienceStyle.original);
      await tester.pump();
      expect(writes, hasLength(1));
      expect(tile().enabled, isFalse);
      writes.first.completeError(StateError('fixture save failure'));
      await tester.pump();
      expect(tile().error, t.error.saveFailed);
      expect(tile().enabled, isTrue);
      tile().onChanged(SourceExperienceStyle.original);
      await tester.pump();
      expect(writes, hasLength(2));
      writes.last.complete();
      await tester.pump();
      expect(tile().error, isNull);
      expect(tester.takeException(), isNull);
      toastification.dismissAll(delayForAnimation: false);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      toastification.managers.clear();
    },
  );

  for (final (host, style) in [
    ('navigator', 'system'),
    ('router', 'system'),
    ('navigator', 'breeze'),
    ('router', 'breeze'),
  ]) {
    testWidgets(
      '$host $style settings tab has one title and returns from the real appearance page',
      (tester) async {
        const source = bikaPlusSourceId;
        await _registerPlus(_info());
        final global = ValueNotifier<String>(style);
        addTearDown(global.dispose);
        final settings = GlobalSettingCubit();
        addTearDown(settings.close);
        final shell = SourceShellPage(
          source: source,
          sourceName: '哔咔漫画',
          sections: const [
            SourceShellSection.more(title: '首页', actions: []),
            SourceShellSection.profile(),
            SourceShellSection.settings(),
          ],
        );
        RootStackRouter? router;
        final Widget app;
        if (host == 'router') {
          router = RootStackRouter.build(
            routes: [
              NamedRouteDef(
                name: 'Home',
                path: '/',
                initial: true,
                builder: (_, _) => shell,
              ),
              NamedRouteDef(
                name: routes.GlobalSettingRoute.name,
                path: '/breeze-settings',
                builder: (_, _) => const GlobalSettingPage(),
              ),
            ],
          );
          addTearDown(router.dispose);
          app = MaterialApp.router(routerConfig: router.config());
        } else {
          app = MaterialApp(home: shell);
        }
        await tester.pumpWidget(
          BlocProvider.value(
            value: settings,
            child: AppInterfaceStyleScope(style: global, child: app),
          ),
        );
        await tester.pumpAndSettle();
        await _tapDestination(tester, t.discover.settings);
        await tester.pumpAndSettle();
        expect(find.byType(BikaSettingsContent), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);
        final bodyState = tester.state(find.byType(BikaSettingsContent));
        final settingsScroll = find
            .descendant(
              of: find.byType(BikaSettingsContent),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.drag(settingsScroll, const Offset(0, -500));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('bika-settings-breeze')),
        );
        // ensureVisible jumps the scroll position; the enlarged Plus section
        // still needs a frame before using the tile's updated hit coordinates.
        await tester.pumpAndSettle();
        final appSettings = find
            .byKey(const ValueKey('bika-settings-breeze'))
            .hitTestable();
        expect(appSettings, findsOneWidget);
        await tester.tap(appSettings);
        await tester.pumpAndSettle();
        expect(find.byType(GlobalSettingPage), findsOneWidget);
        expect(
          SourceExperienceScope.controlsStyleOf(
            tester.element(find.byType(GlobalSettingPage)),
          ),
          style,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(BikaSettingsContent)), same(bodyState));
        expect(find.byType(AppBar), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
