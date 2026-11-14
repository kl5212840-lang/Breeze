import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

import '../test_helper.dart';

const _other = '83d82c45-7da1-45ec-9663-f93887b71947';

void _selectOriginal() => savePluginConfigValueSync(
  bikaPlusSourceId,
  bikaExperienceAppearanceKey,
  'original',
);

Map<String, dynamic> _info({
  Object version = 1,
  String key = bikaExperienceAppearanceKey,
  String artwork = bikaExperienceArtwork,
}) => {
  'breezeExperience': {
    'bikaExperience': {
      'version': version,
      'appearanceKey': key,
      'loadingArtwork': artwork,
    },
  },
};

Future<void> _install(
  String source, {
  Map<String, dynamic>? info,
  bool deleted = false,
}) async {
  var id = 0;
  for (final row in objectbox.pluginInfoBox.getAll()) {
    if (row.uuid == source) {
      id = row.id;
      break;
    }
  }
  await PluginRegistryService.I.upsert(
    PluginInfo(
      id: id,
      uuid: source,
      version: '0.1.1',
      originScript: '',
      insertedAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      isEnabled: true,
      isDeleted: deleted,
      lastLoadSuccess: true,
      debug: false,
      getInfoJson: jsonEncode(info ?? _info()),
    ),
  );
}

class _Seen {
  _Seen(BuildContext context)
    : data = SourceExperienceScope.maybeOf(context),
      theme = Theme.of(context),
      controls = SourceExperienceScope.controlsStyleOf(context);
  final SourceExperienceState? data;
  final ThemeData theme;
  final String controls;
}

class _Business extends StatefulWidget {
  const _Business({required this.started, required this.ended});
  final VoidCallback started, ended;
  @override
  State<_Business> createState() => _BusinessState();
}

class _BusinessState extends State<_Business> {
  @override
  void initState() {
    super.initState();
    widget.started();
  }

  @override
  void dispose() {
    widget.ended();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Text('retained business');
}

Widget _host({
  required ValueNotifier<String> global,
  required Widget home,
  ThemeData? theme,
}) => AppInterfaceStyleScope(
  style: global,
  child: MaterialApp(
    theme: theme ?? ThemeData.light(),
    home: Scaffold(body: home),
  ),
);

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 50; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    if (ready()) return;
  }
  expect(
    ready(),
    isTrue,
    reason: 'A real source config/registry change must reach its boundary',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    await PluginRegistryService.I.init();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalPluginInstallationState.instance.reload();
    objectbox.pluginInfoBox.removeAll();
    objectbox.pluginConfigBox.removeAll();
    await PluginRegistryService.I.refreshFromDb();
    await _install(bikaPlusSourceId);
  });

  test(
    'declaration requires the exact canonical source and all versioned fields',
    () {
      expect(
        supportsBikaExperienceDeclaration(bikaPlusSourceId, _info()),
        isTrue,
      );
      expect(
        supportsBikaExperienceDeclaration(
          '($bikaPlusSourceId.breeze-session.7)',
          _info(),
        ),
        isTrue,
      );
      for (final bad in [
        null,
        {},
        _info(version: '1'),
        _info(version: 1.0),
        _info(version: 2),
        _info(key: 'controlsStyle'),
        _info(artwork: 'other'),
      ]) {
        expect(
          supportsBikaExperienceDeclaration(bikaPlusSourceId, bad),
          isFalse,
        );
      }
      expect(supportsBikaExperienceDeclaration(_other, _info()), isFalse);
      expect(
        supportsBikaExperienceDeclaration(
          'plugin_info_${bikaPlusSourceId.replaceAll('-', '_')}',
          _info(),
        ),
        isFalse,
      );
    },
  );

  testWidgets(
    'Plus follows global by default and can switch to Original and back',
    (tester) async {
      final global = ValueNotifier('system');
      addTearDown(global.dispose);
      late _Seen seen;
      await tester.pumpWidget(
        _host(
          global: global,
          home: SourceExperienceBoundary(
            source: bikaPlusSourceId,
            builder: (context) {
              seen = _Seen(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen.controls, 'system');
      expect(seen.data!.style, SourceExperienceStyle.follow);
      expect(objectbox.pluginConfigBox.getAll(), isEmpty);
      _selectOriginal();
      await _until(tester, () => seen.data!.isOriginal);
      expect(seen.controls, 'breeze');
      savePluginConfigValueSync(
        bikaPlusSourceId,
        bikaExperienceAppearanceKey,
        'follow',
      );
      await _until(
        tester,
        () => seen.data!.style == SourceExperienceStyle.follow,
      );
      expect(seen.controls, 'system');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'pure parsing and player resolver cannot introduce a third preference',
    () {
      for (final value in [null, '', 'system', 'breeze', true, 1, {}]) {
        expect(
          parseSourceExperienceStyle(value),
          SourceExperienceStyle.original,
        );
      }
      expect(
        parseSourceExperienceStyle('follow'),
        SourceExperienceStyle.follow,
      );
      expect(
        resolveSourceControlsStyle(
          source: bikaPlusSourceId,
          pluginInfo: _info(),
          preference: 'original',
          globalStyle: 'system',
        ),
        'breeze',
      );
      expect(
        resolveSourceControlsStyle(
          source: bikaPlusSourceId,
          pluginInfo: _info(),
          preference: 'follow',
          globalStyle: 'system',
        ),
        'system',
      );
      expect(
        resolveSourceControlsStyle(
          source: _other,
          pluginInfo: _info(),
          preference: 'original',
          globalStyle: 'system',
        ),
        'system',
      );
    },
  );

  testWidgets(
    'default Follow is synchronous and never creates a config or revision',
    (tester) async {
      final global = ValueNotifier('system');
      addTearDown(global.dispose);
      final seen = <String, _Seen>{};
      await tester.pumpWidget(
        _host(
          global: global,
          home: Column(
            children: [
              Builder(
                builder: (context) {
                  seen['app'] = _Seen(context);
                  return const SizedBox();
                },
              ),
              SourceExperienceBoundary(
                source: bikaPlusSourceId,
                builder: (context) {
                  seen['bk'] = _Seen(context);
                  return const SizedBox();
                },
              ),
            ],
          ),
        ),
      );
      expect(seen['bk']!.data!.enabled, isTrue);
      expect(seen['bk']!.data!.style, SourceExperienceStyle.follow);
      expect(seen['bk']!.controls, 'system');
      expect(global.value, 'system');
      expect(seen['bk']!.theme, seen['app']!.theme);
      expect(identical(seen['bk']!.data!.applicationStyle, global), isTrue);
      expect(objectbox.pluginConfigBox.count(), 0);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(objectbox.pluginConfigBox.count(), 0);
    },
  );

  testWidgets(
    'follow tracks global changes and config switching retains business state',
    (tester) async {
      _selectOriginal();
      final global = ValueNotifier('system');
      addTearDown(global.dispose);
      late _Seen seen;
      var starts = 0, ends = 0;
      await tester.pumpWidget(
        _host(
          global: global,
          home: SourceExperienceBoundary(
            source: bikaPlusSourceId,
            builder: (context) {
              seen = _Seen(context);
              return _Business(started: () => starts++, ended: () => ends++);
            },
          ),
        ),
      );
      expect(starts, 1);
      expect(seen.data!.isOriginal, isTrue);
      await savePluginConfigValue(
        bikaPlusSourceId,
        bikaExperienceAppearanceKey,
        'follow',
      );
      await _until(
        tester,
        () => seen.data!.style == SourceExperienceStyle.follow,
      );
      expect(seen.controls, 'system');
      global.value = 'breeze';
      await tester.pump();
      expect(seen.controls, 'breeze');
      await savePluginConfigValue(
        bikaPlusSourceId,
        bikaExperienceAppearanceKey,
        'original',
      );
      await _until(tester, () => seen.data!.isOriginal);
      global.value = 'system';
      await tester.pump();
      expect(seen.controls, 'breeze');
      expect(global.value, 'system');
      expect(starts, 1);
      expect(ends, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(ends, 1);
    },
  );

  testWidgets(
    'nested same source is not double tinted; another source restores app theme and notifier',
    (tester) async {
      _selectOriginal();
      final global = ValueNotifier('system');
      addTearDown(global.dispose);
      final seen = <String, _Seen>{};
      await _install(_other);
      await tester.pumpWidget(
        _host(
          global: global,
          home: Column(
            children: [
              Builder(
                builder: (context) {
                  seen['app'] = _Seen(context);
                  return const SizedBox();
                },
              ),
              SourceExperienceBoundary(
                source: bikaPlusSourceId,
                builder: (context) {
                  seen['outer'] = _Seen(context);
                  return Column(
                    children: [
                      SourceExperienceBoundary(
                        source: '($bikaPlusSourceId.breeze-session.2)',
                        builder: (context) {
                          seen['same'] = _Seen(context);
                          return const SizedBox();
                        },
                      ),
                      SourceExperienceBoundary(
                        source: _other,
                        builder: (context) {
                          seen['other'] = _Seen(context);
                          return const SizedBox();
                        },
                      ),
                      SourceExperienceBoundary(
                        source: '',
                        builder: (context) {
                          seen['global'] = _Seen(context);
                          return const SizedBox();
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      );
      expect(seen['outer']!.data!.isOriginal, isTrue);
      expect(seen['outer']!.theme, seen['same']!.theme);
      expect(seen['same']!.data!.source, bikaPlusSourceId);
      for (final label in ['other', 'global']) {
        expect(seen[label]!.data!.isOriginal, isFalse);
        expect(seen[label]!.theme, seen['app']!.theme);
        expect(seen[label]!.controls, 'system');
        expect(identical(seen[label]!.data!.applicationStyle, global), isTrue);
      }
      global.value = 'breeze';
      await tester.pump();
      expect(seen['other']!.controls, 'breeze');
      expect(objectbox.pluginConfigBox.count(), 1);
    },
  );

  testWidgets(
    'global theme changes preserve brightness and reset base through nested boundaries',
    (tester) async {
      _selectOriginal();
      final global = ValueNotifier('system');
      addTearDown(global.dispose);
      final theme = ValueNotifier(ThemeData.light());
      addTearDown(theme.dispose);
      late _Seen bk, reset;
      await tester.pumpWidget(
        ValueListenableBuilder<ThemeData>(
          valueListenable: theme,
          builder: (_, data, __) => _host(
            global: global,
            theme: data,
            home: SourceExperienceBoundary(
              source: bikaPlusSourceId,
              builder: (_) => Column(
                children: [
                  Builder(
                    builder: (context) {
                      bk = _Seen(context);
                      return const SizedBox();
                    },
                  ),
                  SourceExperienceBoundary(
                    source: _other,
                    builder: (context) {
                      reset = _Seen(context);
                      return const SizedBox();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      theme.value = ThemeData.dark();
      await tester.pumpAndSettle();
      expect(bk.theme.brightness, Brightness.dark);
      expect(reset.theme.brightness, Brightness.dark);
      expect(reset.theme.colorScheme, theme.value.colorScheme);
      expect(bk.theme, isNot(reset.theme));
    },
  );

  testWidgets(
    'source config restores directly and unrelated plugin writes do not rebuild its business',
    (tester) async {
      final global = ValueNotifier('system');
      addTearDown(global.dispose);
      late _Seen seen;
      var builds = 0;
      await tester.pumpWidget(
        _host(
          global: global,
          home: SourceExperienceBoundary(
            source: bikaPlusSourceId,
            builder: (context) {
              builds++;
              seen = _Seen(context);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = builds;
      await savePluginConfigValue(
        _other,
        bikaExperienceAppearanceKey,
        'follow',
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      expect(builds, before);
      objectbox.pluginConfigBox.put(
        PluginConfig(
          name: bikaPlusSourceId,
          config: jsonEncode({bikaExperienceAppearanceKey: 'original'}),
        ),
      );
      await _until(tester, () => seen.data!.isOriginal);
      expect(seen.controls, 'breeze');
      final rows = objectbox.pluginConfigBox.getAll();
      final bk = rows.singleWhere((row) => row.name == bikaPlusSourceId);
      bk.config = jsonEncode({bikaExperienceAppearanceKey: 'breeze'});
      objectbox.pluginConfigBox.put(bk);
      await _until(
        tester,
        () => seen.data!.style == SourceExperienceStyle.follow,
      );
      expect(seen.controls, 'system');
      expect(jsonDecode(objectbox.pluginConfigBox.get(bk.id)!.config), {
        bikaExperienceAppearanceKey: 'breeze',
      }); // invalid value is not rewritten
    },
  );

  testWidgets(
    'registry removal and declaration restoration re-read without touching config',
    (tester) async {
      final global = ValueNotifier('system');
      addTearDown(global.dispose);
      late _Seen seen;
      await tester.pumpWidget(
        _host(
          global: global,
          home: SourceExperienceBoundary(
            source: bikaPlusSourceId,
            builder: (context) {
              seen = _Seen(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen.data!.enabled, isTrue);
      expect(seen.data!.style, SourceExperienceStyle.follow);
      await _install(bikaPlusSourceId, deleted: true);
      await _until(tester, () => !seen.data!.enabled);
      expect(seen.controls, 'system');
      await _install(bikaPlusSourceId, info: _info(version: 2));
      await tester.pump();
      expect(seen.data!.enabled, isFalse);
      await _install(bikaPlusSourceId);
      await _until(tester, () => seen.data!.enabled);
      expect(seen.data!.style, SourceExperienceStyle.follow);
      expect(objectbox.pluginConfigBox.count(), 0);
    },
  );

  testWidgets(
    'local removal and explicit installation restore disable and restore capability',
    (tester) async {
      final global = ValueNotifier('system');
      addTearDown(global.dispose);
      late _Seen seen;
      await tester.pumpWidget(
        _host(
          global: global,
          home: SourceExperienceBoundary(
            source: bikaPlusSourceId,
            builder: (context) {
              seen = _Seen(context);
              return const SizedBox();
            },
          ),
        ),
      );
      // These are real persisted writes on a process-wide serial tail, created
      // outside testWidgets. Keep creation and completion in one real IO zone
      // rather than transferring the serial tail into the widget clock.
      await tester.runAsync(
        () =>
            LocalPluginInstallationState.instance.markRemoved(bikaPlusSourceId),
      );
      await tester.pump();
      expect(seen.data!.enabled, isFalse);
      await tester.runAsync(
        () => LocalPluginInstallationState.instance
            .completeExplicitInstallation(bikaPlusSourceId),
      );
      await tester.pump();
      expect(seen.data!.enabled, isTrue);
    },
  );

  testWidgets(
    'widget source replacement resets branding and closes old observers',
    (tester) async {
      _selectOriginal();
      final global = ValueNotifier('system');
      addTearDown(global.dispose);
      final source = ValueNotifier(bikaPlusSourceId);
      addTearDown(source.dispose);
      late _Seen seen;
      await tester.pumpWidget(
        ValueListenableBuilder<String>(
          valueListenable: source,
          builder: (_, value, __) => _host(
            global: global,
            home: SourceExperienceBoundary(
              source: value,
              builder: (context) {
                seen = _Seen(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(seen.data!.isOriginal, isTrue);
      source.value = _other;
      await tester.pump();
      expect(seen.data!.source, _other);
      expect(seen.data!.isOriginal, isFalse);
      await savePluginConfigValue(
        bikaPlusSourceId,
        bikaExperienceAppearanceKey,
        'follow',
      );
      await tester.pump();
      expect(seen.data!.source, _other);
      await tester.pumpWidget(const SizedBox.shrink());
      await savePluginConfigValue(
        bikaPlusSourceId,
        bikaExperienceAppearanceKey,
        'original',
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
